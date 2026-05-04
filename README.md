# iptables routing inside Docker — experiment

Demonstrates iptables DNAT **inside a container's own network namespace** (no `--network host`, no `--privileged`).

`curl 127.0.0.1:6000` runs inside the **curl-router** container. An iptables OUTPUT rule redirects that traffic to `host.docker.internal:6001`, which is forwarded by Docker to the **hello-server** container.

```
[curl-router container]  --cap-add=NET_ADMIN
  curl http://127.0.0.1:6000
        │
        │  iptables OUTPUT DNAT (inside container netns only)
        │  127.0.0.1:6000 → host.docker.internal:6001
        ▼
[Docker host] -p 6001:6001
        ▼
[hello-server container]  → "Hello World"
```

---

## Prerequisites

- Docker Engine (Linux) **or** Docker Desktop (WSL2/macOS)
- Tested with `ubuntu:24.04` base images

---

## Build the images

```bash
# From the repo root

docker build -t hello-server ./hello-server
docker build -t curl-router  ./curl-router
```

---

## Run the experiment

### 1. Start the hello-server

```bash
docker run -d --name hello-server -p 6001:6001 hello-server
```

Verify it is up:

```bash
curl http://localhost:6001
# Hello World
```

### 2. Run the curl-router

```bash
docker run --rm --name curl-router \
  --cap-add=NET_ADMIN \
  --sysctl net.ipv4.conf.all.route_localnet=1 \
  --add-host=host.docker.internal:host-gateway \
  curl-router
```

The container will:
1. Resolve `host.docker.internal` to the Docker host gateway IP
2. Apply a `net.ipv4.conf.lo.route_localnet=1` sysctl (inside its own netns)
3. Insert an iptables OUTPUT DNAT rule: `127.0.0.1:6000 → <host-gateway>:6001`
4. Run `curl -v http://127.0.0.1:6000` and print the response

Expected output (abbreviated):

```
Resolved host.docker.internal -> 172.17.0.1
...
iptables OUTPUT DNAT rule applied:
...
Sending request to http://127.0.0.1:6000 ...
----------------------------------------------
* Connected to 127.0.0.1 (127.0.0.1) port 6000
...
Hello World
```

### 3. Verify no host rules were added

On the host / WSL terminal — the host iptables are untouched:

```bash
sudo iptables -t nat -L OUTPUT -n -v
# No curl-router rules here
```

---

## Cleanup

```bash
docker stop hello-server
docker rm   hello-server
docker rmi  hello-server curl-router
```

---

## How it works

| Concept | Detail |
|---|---|
| `--cap-add=NET_ADMIN` | Grants iptables write access inside the container netns only |
| `--sysctl net.ipv4.conf.all.route_localnet=1` | Set at container creation time (network-ns sysctl, no `--privileged` needed). Without this, the kernel refuses to route packets sourced from `127.0.0.1` out via `eth0` after DNAT, causing the connection to hang |
| `--add-host=host.docker.internal:host-gateway` | Injects the Docker host gateway IP — works on Linux Docker Engine and Docker Desktop |
| OUTPUT chain DNAT | Intercepts locally-originated TCP connections to `127.0.0.1:6000` before they leave the container |
| `-p 6001:6001` | Publishes hello-server port on the Docker host so `host.docker.internal:6001` reaches it |

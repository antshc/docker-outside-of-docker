# Docker-outside-of-Docker (DooD) — build image experiment

Demonstrates building and running a container **from inside a container** by mounting the host Docker socket (no `--network host`, no `--privileged`).

The **builder** container contains only the Docker CLI. It connects to the host Docker daemon via `/var/run/docker.sock`, builds a Python HTTP "Hello World" server image from the mounted workspace, starts it, and inspects its logs — all without a daemon of its own.

```
[builder container]  docker:27-cli
  /app/build-and-run.sh
        │
        │  docker build -t hello-server /workspace/hello-server
        │  docker run -d --name dood-hello-server -p 6001:6001 hello-server
        │
        │  -v /var/run/docker.sock:/var/run/docker.sock
        ▼
[Docker host daemon]
        │
        │  builds hello-dotnet image
        │  runs hello-dotnet container
        ▼
[hello-dotnet container]  → "Hello, World!"
```

---

## Prerequisites

- Docker Engine (Linux) **or** Docker Desktop (WSL2/macOS)
- Tested with `docker:27-cli` and `mcr.microsoft.com/dotnet/sdk:8.0`

---

## Build the images

```bash
# From build-image/
docker build -t dood-builder ./builder
```

---

## Run the experiment

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$(pwd)/workspace:/workspace" \
  dood-builder
```

The builder container will:
1. Connect to the host Docker daemon via the mounted socket
2. Build the `hello-server` image using the source files in `/workspace/hello-server`
3. Start a container from the freshly built image (detached, port 6001)
4. Print the server logs and stop the container

Expected output:

```
=== Building hello-server image via Docker socket ===
...
Successfully tagged hello-server:latest

=== Running hello-server container ===
Waiting for server to start...
Container logs:
127.0.0.1 - - [..] "GET / HTTP/1.1" 200 -
dood-hello-server
```

---

## Verify the image was created on the host

On the host / WSL terminal — the image is now available to the host daemon:

```bash
docker images hello-server
# REPOSITORY     TAG       IMAGE ID       CREATED         SIZE
# hello-server   latest    ...
```

---

## Cleanup

```bash
docker rmi hello-server dood-builder
```

---

## How it works

| Concept | Detail |
|---|---|
| `-v /var/run/docker.sock:/var/run/docker.sock` | Gives the builder container access to the host Docker daemon — no daemon runs inside the container |
| `-v "$(pwd)/workspace:/workspace"` | Mounts only the source workspace; the builder script is baked into the image |
| `docker:27-cli` base image | Alpine-based image containing only the Docker CLI — purpose-built for DooD scenarios |
| `ubuntu:24.04` + `python3` | Single-stage image — no compilation step needed for the Python server |
| No `--privileged`, no `--network host` | The builder needs no elevated host access beyond the socket mount |

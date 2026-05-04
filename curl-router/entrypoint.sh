#!/bin/bash
set -e

# Resolve host.docker.internal IP injected by --add-host=host.docker.internal:host-gateway
HOST_DOCKER_IP=$(getent hosts host.docker.internal | awk '{ print $1 }')

if [ -z "$HOST_DOCKER_IP" ]; then
    echo "ERROR: host.docker.internal could not be resolved." >&2
    echo "Make sure to run with --add-host=host.docker.internal:host-gateway" >&2
    exit 1
fi

echo "Resolved host.docker.internal -> $HOST_DOCKER_IP"

# Verify route_localnet is set (must be pre-set via --sysctl at docker run time,
# because /proc/sys is read-only inside the container even with NET_ADMIN).
ROUTE_LOCALNET=$(cat /proc/sys/net/ipv4/conf/all/route_localnet 2>/dev/null || echo 0)
if [ "$ROUTE_LOCALNET" != "1" ]; then
    echo "WARNING: net.ipv4.conf.all.route_localnet is not 1 (got: $ROUTE_LOCALNET)." >&2
    echo "Re-run with --sysctl net.ipv4.conf.all.route_localnet=1" >&2
    exit 1
fi
echo "net.ipv4.conf.all.route_localnet = $ROUTE_LOCALNET (OK)"

# Add OUTPUT DNAT rule inside THIS container's network namespace only.
# Traffic from curl 127.0.0.1:6000 will be redirected to host.docker.internal:6001.
iptables -t nat -A OUTPUT \
    -p tcp \
    -d 127.0.0.1 --dport 6000 \
    -j DNAT --to-destination "${HOST_DOCKER_IP}:6001"

# Also needed so the kernel accepts the redirected packet coming back.
iptables -t nat -A POSTROUTING \
    -p tcp \
    -d "${HOST_DOCKER_IP}" --dport 6001 \
    -j MASQUERADE

echo ""
echo "iptables OUTPUT DNAT rule applied:"
iptables -t nat -L OUTPUT -n -v
echo ""
echo "Sending request to http://127.0.0.1:6000 ..."
echo "----------------------------------------------"
curl -v http://127.0.0.1:6000
echo ""
echo "----------------------------------------------"
echo "Done."

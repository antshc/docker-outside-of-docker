#!/bin/sh
set -e

echo "=== Building hello-server image via Docker socket ==="
docker build -t hello-server /workspace/hello-server

echo ""
echo "=== Running hello-server container ==="
docker run -d --name dood-hello-server -p 6001:6001 hello-server

echo "Waiting for server to start..."
sleep 1

echo "Container logs:"
docker logs dood-hello-server

# docker stop dood-hello-server
# docker rm   dood-hello-server

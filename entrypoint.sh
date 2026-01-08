#!/bin/bash

NPM_REGISTRY=${NPM_REGISTRY:-https://registry.npmjs.org/}
echo "Setting npm registry to ${NPM_REGISTRY}"
npm config set registry "$NPM_REGISTRY"

# Handle HTTP_PROXY and HTTPS_PROXY environment variables
if [ -n "$HTTP_PROXY" ]; then
  echo "Setting HTTP proxy to ${HTTP_PROXY}"
  npm config set proxy "$HTTP_PROXY"
  export HTTP_PROXY="$HTTP_PROXY"
fi

if [ -n "$HTTPS_PROXY" ]; then
  echo "Setting HTTPS proxy to ${HTTPS_PROXY}"
  npm config set https-proxy "$HTTPS_PROXY"
  export HTTPS_PROXY="$HTTPS_PROXY"
fi

echo "Using REQUEST_TIMEOUT: $REQUEST_TIMEOUT"

# Fix powermem infer default value (disable intelligent mode to avoid memory deletion bug)
# powermem is installed dynamically by uvx, so we need to find its location
POWERMEM_MEMORY=$(find /root/.cache -path "*/powermem/core/memory.py" 2>/dev/null | head -1)
if [ -n "$POWERMEM_MEMORY" ] && [ -f "$POWERMEM_MEMORY" ]; then
  sed -i 's/infer: bool = True/infer: bool = False/' "$POWERMEM_MEMORY"
  echo "Fixed powermem infer default to False"
fi

# Auto-start Docker daemon if Docker is installed
if command -v dockerd >/dev/null 2>&1; then
  echo "Docker daemon detected, starting dockerd..."
  
  # Create docker directory if it doesn't exist
  mkdir -p /var/lib/docker
  
  # Start dockerd in the background
  dockerd --host=unix:///var/run/docker.sock --storage-driver=vfs > /var/log/dockerd.log 2>&1 &
  
  # Wait for Docker daemon to be ready
  echo "Waiting for Docker daemon to be ready..."
  TIMEOUT=15
  ELAPSED=0
  while ! docker info >/dev/null 2>&1; do
    if [ $ELAPSED -ge $TIMEOUT ]; then
      echo "WARNING: Docker daemon failed to start within ${TIMEOUT} seconds"
      echo "Check /var/log/dockerd.log for details"
      break
    fi
    sleep 1
    ELAPSED=$((ELAPSED + 1))
  done
  
  if docker info >/dev/null 2>&1; then
    echo "Docker daemon started successfully"
  fi
fi

exec "$@"

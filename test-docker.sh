#!/bin/bash
# Test Docker connection for claude-squad

echo "Testing Docker connection..."

# Set DOCKER_HOST for macOS Docker Desktop
export DOCKER_HOST="unix://$HOME/.docker/run/docker.sock"

echo "DOCKER_HOST set to: $DOCKER_HOST"

# Test Docker connection
docker version > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Docker daemon is accessible"
else
    echo "✗ Docker daemon is not accessible"
    exit 1
fi

# Check if claudesquad/enhanced:latest image exists
if docker image inspect claudesquad/enhanced:latest > /dev/null 2>&1; then
    echo "✓ Docker image claudesquad/enhanced:latest exists"
else
    echo "✗ Docker image claudesquad/enhanced:latest not found"
fi

echo ""
echo "To run claude-squad with Docker, use:"
echo "export DOCKER_HOST=\"unix://\$HOME/.docker/run/docker.sock\""
echo "./claude-squad --docker --program claude"
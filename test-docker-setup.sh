#!/bin/bash
# ABOUTME: Test Docker setup for claude-squad
# ABOUTME: Verifies Docker is working and containers can be created

echo "🔧 Testing Docker setup for claude-squad..."
echo ""

# Test 1: Docker is running
echo "1. Testing Docker daemon..."
if docker info >/dev/null 2>&1; then
    echo "✅ Docker daemon is running"
else
    echo "❌ Docker daemon is not running"
    echo "Please start Docker Desktop and try again"
    exit 1
fi

# Test 2: Can create basic container
echo "2. Testing container creation..."
if docker run --rm hello-world >/dev/null 2>&1; then
    echo "✅ Container creation works"
else
    echo "❌ Container creation failed"
    echo "Check Docker permissions and try again"
    exit 1
fi

# Test 3: Test Node.js image (base for claude-squad)
echo "3. Testing Node.js image..."
if docker run --rm node:20-slim node --version >/dev/null 2>&1; then
    echo "✅ Node.js image works"
else
    echo "❌ Node.js image failed"
    echo "Check internet connection and try again"
    exit 1
fi

# Test 4: Check if claude-squad image exists
echo "4. Checking for claude-squad image..."
if docker images | grep -q "claudesquad/enhanced"; then
    echo "✅ claude-squad image exists"
    echo "Image info:"
    docker images | grep "claudesquad/enhanced"
else
    echo "ℹ️  claude-squad image not found (will be built on first run)"
fi

# Test 5: Test basic container with mounts
echo "5. Testing container with volume mounts..."
TEST_DIR="/tmp/claude-squad-test"
mkdir -p "$TEST_DIR"
echo "test content" > "$TEST_DIR/test.txt"

if docker run --rm -v "$TEST_DIR:/workspace" node:20-slim cat /workspace/test.txt >/dev/null 2>&1; then
    echo "✅ Volume mounting works"
else
    echo "❌ Volume mounting failed"
    echo "Check Docker settings for file sharing"
    exit 1
fi

# Cleanup
rm -rf "$TEST_DIR"

echo ""
echo "🎉 Docker setup is working correctly!"
echo "You can now run claude-squad with:"
echo "  ./claude-squad --program claude"
echo ""
echo "For debug logs, use:"
echo "  ./run-debug.sh --program claude"
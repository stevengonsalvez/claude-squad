#!/bin/bash
# ABOUTME: Check syntax of specific problematic files

echo "Checking syntax of session/docker/docker.go..."

# Check just the docker.go file
if go build -o /tmp/docker-test session/docker/docker.go; then
    echo "✅ docker.go syntax is valid"
    rm -f /tmp/docker-test
else
    echo "❌ docker.go has syntax errors"
    exit 1
fi

# Check the entire session/docker package
echo "Checking session/docker package..."
if go build -o /tmp/session-docker ./session/docker/; then
    echo "✅ session/docker package builds successfully"
    rm -f /tmp/session-docker
else
    echo "❌ session/docker package has issues"
    exit 1
fi

# Check full build
echo "Checking full project build..."
if go build -o /tmp/claude-squad-test; then
    echo "✅ Full project builds successfully"
    rm -f /tmp/claude-squad-test
else
    echo "❌ Full project build failed"
    exit 1
fi

echo "🎉 All syntax checks passed!"
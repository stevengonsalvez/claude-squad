#!/bin/bash
# ABOUTME: Test script to validate compilation and report any errors

echo "Testing claude-squad compilation..."

# Clean any previous builds
echo "Cleaning previous builds..."
go clean -cache

# Attempt to build
echo "Building claude-squad..."
if go build -o claude-squad -v; then
    echo "✅ Build successful!"
    echo "Binary size: $(ls -lh claude-squad | awk '{print $5}')"
    echo "Binary created: $(ls -la claude-squad)"
else
    echo "❌ Build failed!"
    exit 1
fi

# Test basic functionality
echo "Testing basic functionality..."
if ./claude-squad --help >/dev/null 2>&1; then
    echo "✅ Basic functionality test passed!"
else
    echo "❌ Basic functionality test failed!"
    exit 1
fi

echo "🎉 All tests passed! claude-squad is ready to use."
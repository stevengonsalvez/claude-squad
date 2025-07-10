#!/bin/bash
# ABOUTME: Run claude-squad with debug logging enabled
# ABOUTME: Shows detailed logs to help troubleshoot container issues

echo "🔍 Running claude-squad with debug logging..."
echo "This will show detailed logs to help troubleshoot issues."
echo ""

# Build with debug info
echo "Building claude-squad with debug info..."
go build -o claude-squad

# Set environment variables for debug logging
export DOCKER_BUILDKIT=1
export DOCKER_CLI_HINTS=false

# Run with debug logging
echo "Starting claude-squad with debug logging..."
echo "Press Ctrl+C to stop"
echo ""

# Run claude-squad with the provided arguments
./claude-squad "$@" 2>&1 | while IFS= read -r line; do
    echo "[$(date '+%H:%M:%S')] $line"
done
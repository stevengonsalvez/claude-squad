# Debugging claude-squad Docker Issues

## Common Error: "error getting container logs: invalid container name or ID: value is empty"

This error occurs when the container ID is empty, which can happen for several reasons:

### 1. Quick Diagnosis

Run the debug version to see what's happening:

```bash
# Build and run with debug logging
chmod +x run-debug.sh
./run-debug.sh --program claude
```

### 2. Check Docker Setup

First, verify Docker is working:

```bash
# Test Docker setup
chmod +x test-docker-setup.sh
./test-docker-setup.sh
```

### 3. Check Prerequisites

**Claude Authentication:**
```bash
# Check if Claude is authenticated
ls -la ~/.claude/.credentials.json

# If not found, authenticate
claude
```

**Git Configuration:**
```bash
# Check git config
git config --global --get user.name
git config --global --get user.email

# If not set, configure
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

**Repository Check:**
```bash
# Make sure you're in a git repository
git status
```

### 4. Common Causes and Solutions

**Cause 1: Container fails to start**
```bash
# Check Docker logs
docker logs $(docker ps -a -q --filter "name=claudesquad_" | head -1)

# Check if image exists
docker images | grep claudesquad
```

**Cause 2: Container ID not set during creation**
- The container creation might be failing
- Check the debug logs for "Creating Docker container" messages

**Cause 3: Container gets cleaned up before logs are captured**
- The container might be auto-removing on failure
- Check for "Failed to start container" messages

### 5. Debug Steps

**Step 1: Enable verbose logging**
```bash
# Rebuild with debug info
go build -o claude-squad

# Run with debug logging
./run-debug.sh --program claude 2>&1 | tee debug.log
```

**Step 2: Check container lifecycle**
```bash
# Watch containers in real-time
watch -n 1 'docker ps -a --filter "name=claudesquad_"'
```

**Step 3: Manual container test**
```bash
# Try creating a container manually
docker run -it --rm \
  -v $(pwd):/workspace \
  -v ~/.claude:/home/claude-user/.claude \
  -v ~/.gitconfig:/home/claude-user/.gitconfig:ro \
  node:20-slim bash

# Inside container, test basic functionality
claude --version
```

### 6. Log Analysis

Look for these patterns in the debug logs:

**Container Creation:**
```
[12:34:56] Starting Docker container: claudesquad_sessionname with program: claude
[12:34:56] Creating Docker container with name: claudesquad_sessionname
[12:34:56] Created container with ID: abc123...
```

**Container Start:**
```
[12:34:56] Starting container: abc123...
[12:34:56] Container abc123... started successfully, restoring state...
```

**Log Capture:**
```
[12:34:56] Capturing output for container ID: abc123... (name: claudesquad_sessionname)
```

### 7. Environment Variables

Set these for better debugging:

```bash
# Enable Docker debug mode
export DOCKER_BUILDKIT=1
export DOCKER_CLI_HINTS=false

# Set GitHub token for git operations
export GITHUB_TOKEN=ghp_your_token_here

# Run claude-squad
./claude-squad --program claude
```

### 8. Manual Container Inspection

If containers are being created but failing:

```bash
# List all containers (including stopped)
docker ps -a --filter "name=claudesquad_"

# Inspect a specific container
docker inspect <container_id>

# Check container logs
docker logs <container_id>

# Execute into a running container
docker exec -it <container_id> bash
```

### 9. Clean State Reset

If nothing works, reset everything:

```bash
# Stop all claude-squad containers
docker stop $(docker ps -q --filter "name=claudesquad_")

# Remove all claude-squad containers
docker rm $(docker ps -aq --filter "name=claudesquad_")

# Remove claude-squad images
docker rmi claudesquad/enhanced:latest

# Clean claude-squad state
./claude-squad reset

# Start fresh
./claude-squad --program claude
```

### 10. File an Issue

If the problem persists, collect this information:

```bash
# System info
echo "OS: $(uname -a)"
echo "Docker: $(docker version --format '{{.Client.Version}}')"
echo "Go: $(go version)"
echo "Git: $(git --version)"

# Docker info
docker info

# Container logs
docker logs $(docker ps -a -q --filter "name=claudesquad_" | head -1)

# Debug log
./run-debug.sh --program claude 2>&1 | head -100
```

## Expected Behavior

When working correctly, you should see:

1. **Container Creation**: "Creating Docker container with name: claudesquad_..."
2. **Container Start**: "Starting container: abc123..."
3. **Success**: Container runs and you can interact with Claude
4. **Logs**: "Capturing output for container ID: abc123..."

The container should stay running and you should be able to attach to it for interactive use.
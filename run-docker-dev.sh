#!/bin/bash
# ABOUTME: Launch Claude Squad development container with full authentication and mounts

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🐳 Launching Claude Squad Development Container...${NC}"

# Get current git config
GIT_NAME=$(git config --global user.name 2>/dev/null || echo "")
GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")

if [ -z "$GIT_NAME" ]; then
    echo -e "${YELLOW}⚠️  Git user.name not configured${NC}"
    read -p "Enter your name: " GIT_NAME
fi

if [ -z "$GIT_EMAIL" ]; then
    echo -e "${YELLOW}⚠️  Git user.email not configured${NC}"
    read -p "Enter your email: " GIT_EMAIL
fi

# Get GitHub token if gh is authenticated
GH_TOKEN=""
if command -v gh &> /dev/null && gh auth status &> /dev/null 2>&1; then
    GH_TOKEN=$(gh auth token 2>/dev/null || echo "")
    if [ -n "$GH_TOKEN" ]; then
        echo -e "${GREEN}✓ GitHub CLI authenticated${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  GitHub CLI not authenticated (gh auth login)${NC}"
fi

# Check for API keys
if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo -e "${YELLOW}⚠️  ANTHROPIC_API_KEY not set${NC}"
fi

# Create workspace directory if it doesn't exist
mkdir -p "$(pwd)/workspace"

# Prepare mount options
MOUNT_OPTS=""

# Claude configuration
if [ -d "$HOME/.claude" ]; then
    MOUNT_OPTS="$MOUNT_OPTS -v $HOME/.claude:/home/user/.claude"
    echo -e "${GREEN}✓ Mounting ~/.claude${NC}"
fi

# Git configuration
if [ -f "$HOME/.gitconfig" ]; then
    MOUNT_OPTS="$MOUNT_OPTS -v $HOME/.gitconfig:/home/user/.gitconfig:ro"
    echo -e "${GREEN}✓ Mounting ~/.gitconfig${NC}"
fi

# Git credentials
if [ -f "$HOME/.git-credentials" ]; then
    MOUNT_OPTS="$MOUNT_OPTS -v $HOME/.git-credentials:/home/user/.git-credentials:ro"
    echo -e "${GREEN}✓ Mounting ~/.git-credentials${NC}"
fi

# SSH keys
if [ -d "$HOME/.ssh" ]; then
    MOUNT_OPTS="$MOUNT_OPTS -v $HOME/.ssh:/home/user/.ssh:ro"
    echo -e "${GREEN}✓ Mounting ~/.ssh${NC}"
fi

# GitHub CLI config
if [ -d "$HOME/.config/gh" ]; then
    MOUNT_OPTS="$MOUNT_OPTS -v $HOME/.config/gh:/home/user/.config/gh:ro"
    echo -e "${GREEN}✓ Mounting ~/.config/gh${NC}"
fi

# Docker socket
if [ -S "/var/run/docker.sock" ]; then
    MOUNT_OPTS="$MOUNT_OPTS -v /var/run/docker.sock:/var/run/docker.sock"
    echo -e "${GREEN}✓ Mounting Docker socket${NC}"
fi

echo -e "${BLUE}🚀 Starting container...${NC}"

# Run container with all mounts and auth
docker run -it --rm \
  --name claude-squad-dev \
  -v "$(pwd)/workspace:/workspace" \
  $MOUNT_OPTS \
  -e GIT_USER_NAME="$GIT_NAME" \
  -e GIT_USER_EMAIL="$GIT_EMAIL" \
  -e GITHUB_TOKEN="$GH_TOKEN" \
  -e ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY}" \
  -e OPENAI_API_KEY="${OPENAI_API_KEY}" \
  -e GOOGLE_API_KEY="${GOOGLE_API_KEY}" \
  -p 3000-3020:3000-3020 \
  -p 8000-8020:8000-8020 \
  -p 9000-9020:9000-9020 \
  claude-squad:dev "$@"
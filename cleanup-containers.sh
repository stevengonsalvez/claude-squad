#!/bin/bash
# ABOUTME: Clean up all Claude Squad Docker containers

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🧹 Claude Squad Container Cleanup${NC}"

# List running Claude Squad containers
RUNNING_CONTAINERS=$(docker ps --filter name=claude-squad --format "{{.Names}}" | grep -v "^$" || true)
if [ -n "$RUNNING_CONTAINERS" ]; then
    echo -e "${YELLOW}⚠️  Stopping running containers:${NC}"
    echo "$RUNNING_CONTAINERS" | sed 's/^/  /'
    docker stop $(docker ps -q --filter name=claude-squad) 2>/dev/null || true
    echo -e "${GREEN}✓ Stopped${NC}"
fi

# List all Claude Squad containers (including stopped)
ALL_CONTAINERS=$(docker ps -a --filter name=claude-squad --format "{{.Names}}" | grep -v "^$" || true)
if [ -n "$ALL_CONTAINERS" ]; then
    echo -e "${YELLOW}🗑️  Removing containers:${NC}"
    echo "$ALL_CONTAINERS" | sed 's/^/  /'
    docker rm -f $(docker ps -aq --filter name=claude-squad) 2>/dev/null || true
    echo -e "${GREEN}✓ Removed${NC}"
else
    echo -e "${GREEN}✓ No Claude Squad containers found${NC}"
fi

echo -e "${BLUE}🎉 Cleanup complete!${NC}"
#!/bin/bash
# ABOUTME: Quick start script for enhanced claude-squad
# ABOUTME: Builds binary, sets up Docker environment, and provides usage guidance

set -e

echo "🚀 claude-squad Enhanced Docker Setup"
echo "======================================"

# Step 1: Clean up old Docker setup
echo "🧹 Cleaning up old Docker setup..."
rm -rf docker/images/ 2>/dev/null || true
chmod +x docker/scripts/startup.sh docker/install-mcp-servers.sh docker/setup-enhanced.sh docker/create-default-mcp-config.sh 2>/dev/null || true

# Remove old Docker images
echo "🗑️  Removing old Docker images..."
docker rmi claudesquad/claude:latest claudesquad/aider:latest claudesquad/gemini:latest 2>/dev/null || true

# Step 2: Build the binary
echo "🔨 Building claude-squad binary..."
go build -o claude-squad

# Step 3: Set up enhanced environment
echo "⚙️  Setting up enhanced Docker environment..."
./docker/setup-enhanced.sh

# Step 4: Usage guidance
echo ""
echo "✅ Setup complete! Here's how to use claude-squad:"
echo ""
echo "Basic usage:"
echo "  ./claude-squad --program claude"
echo "  ./claude-squad --program gemini"
echo ""
echo "With GitHub token (recommended):"
echo "  GITHUB_TOKEN=ghp_xxx ./claude-squad --program claude"
echo ""
echo "With both GitHub and Gemini:"
echo "  GITHUB_TOKEN=ghp_xxx GOOGLE_AI_STUDIO_API_KEY=your_key ./claude-squad --program claude"
echo ""
echo "Custom Docker image:"
echo "  ./claude-squad --docker-image myrepo/custom:latest --program claude"
echo ""
echo "📚 For more info, see:"
echo "  - docker/README.md - Complete Docker setup guide"
echo "  - .claude/docker.md - Technical documentation"
echo ""
echo "🎯 Quick test (make sure you're in a git repository):"
echo "  ./claude-squad --program claude"
echo ""
echo "💡 Pro tip: Set environment variables in your shell profile:"
echo "  echo 'export GITHUB_TOKEN=ghp_your_token' >> ~/.bashrc"
echo "  echo 'export GOOGLE_AI_STUDIO_API_KEY=your_key' >> ~/.bashrc"
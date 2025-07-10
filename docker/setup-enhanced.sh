#!/bin/bash
# ABOUTME: Setup script for enhanced claude-squad Docker environment
# ABOUTME: Creates config directories and default MCP servers configuration

set -e

echo "Setting up enhanced claude-squad environment..."

# Create claude-squad config directory
CONFIG_DIR="$HOME/.claude-squad"
mkdir -p "$CONFIG_DIR"

# Create default MCP servers configuration
MCP_CONFIG_FILE="$CONFIG_DIR/mcp-servers.txt"
if [ ! -f "$MCP_CONFIG_FILE" ]; then
    cat > "$MCP_CONFIG_FILE" << 'EOF'
# MCP Server Configuration File for claude-squad
# Each line should contain a complete claude mcp add or claude mcp add-json command
# Use ${VAR_NAME} for environment variable substitution
# Lines starting with # are comments and will be ignored

# Context7 - Up-to-date documentation and code examples from source
claude mcp add -s user --transport sse context7 https://mcp.context7.com/sse

# Add more MCP servers below as needed
# Example formats:
# claude mcp add -s user <name> -- <command> <args>
# claude mcp add-json <name> -s user '{"command":"...","args":[...],"env":{...}}'

# Popular MCP servers you can add:
# Filesystem access
# claude mcp add -s user filesystem -- npx -y @modelcontextprotocol/server-filesystem

# GitHub integration (requires GITHUB_TOKEN)
# claude mcp add-json github -s user '{"command":"npx","args":["-y","@modelcontextprotocol/server-github"],"env":{"GITHUB_TOKEN":"${GITHUB_TOKEN}"}}'

# Browser automation
# claude mcp add -s user browser -- npx -y @modelcontextprotocol/server-browser

# Memory/knowledge base
# claude mcp add -s user memory -- npx -y @modelcontextprotocol/server-memory
EOF
    echo "✓ Created MCP servers configuration: $MCP_CONFIG_FILE"
else
    echo "✓ MCP servers configuration already exists: $MCP_CONFIG_FILE"
fi

# Check for Claude authentication
if [ -f "$HOME/.claude/.credentials.json" ]; then
    echo "✓ Claude authentication found"
elif [ -f "$HOME/.claude.json" ]; then
    echo "✓ Claude authentication found (legacy location)"
else
    echo "⚠️  Claude authentication not found"
    echo "   Run 'claude' and complete authentication before using claude-squad"
fi

# Check for Gemini authentication
if [ -d "$HOME/.gemini" ]; then
    echo "✓ Gemini directory found"
    if [ -f "$HOME/.gemini/oauth_credentials.json" ]; then
        echo "✓ Gemini OAuth credentials found"
    else
        echo "ℹ️  Gemini OAuth not configured (will use API key if set)"
    fi
else
    echo "ℹ️  Gemini not configured (optional)"
fi

# Check for git configuration
if git config --global --get user.name >/dev/null 2>&1 && git config --global --get user.email >/dev/null 2>&1; then
    echo "✓ Git configuration found"
    echo "   Name: $(git config --global --get user.name)"
    echo "   Email: $(git config --global --get user.email)"
else
    echo "⚠️  Git configuration incomplete"
    echo "   Run: git config --global user.name \"Your Name\""
    echo "   Run: git config --global user.email \"your.email@example.com\""
fi

# Environment variables info
echo ""
echo "📋 Environment Variables (optional):"
echo "   GITHUB_TOKEN - For git operations and GitHub MCP server"
echo "   GOOGLE_AI_STUDIO_API_KEY - For Gemini CLI (if not using OAuth)"
echo ""
echo "💡 Set these in your shell profile or pass them when running claude-squad"
echo ""
echo "🚀 Setup complete! You can now run claude-squad with enhanced Docker support."
echo ""
echo "Example usage:"
echo "   claude-squad --program claude"
echo "   claude-squad --program gemini" 
echo "   GITHUB_TOKEN=ghp_xxx claude-squad --program claude"
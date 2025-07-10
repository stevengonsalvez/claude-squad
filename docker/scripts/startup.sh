#!/bin/bash
# ABOUTME: Startup script for claude-squad Docker container with MCP server support
# ABOUTME: Supports both Claude Code and Gemini CLI with PAT-based git authentication

# Load environment variables if they exist
echo "Initializing claude-squad container..."

# Install user's MCP servers if configuration file exists and is mounted
USER_MCP_CONFIG="$HOME/.claude/mcp-servers.txt"
if [ -f "$USER_MCP_CONFIG" ]; then
    echo "Installing user's MCP servers from $USER_MCP_CONFIG"
    # Create a temporary install script that uses the user's config
    cp /app/install-mcp-servers.sh /tmp/install-user-mcp-servers.sh
    sed -i "s|/app/mcp-servers.txt|$USER_MCP_CONFIG|g" /tmp/install-user-mcp-servers.sh
    chmod +x /tmp/install-user-mcp-servers.sh
    /tmp/install-user-mcp-servers.sh
else
    echo "No user MCP configuration found, using default setup"
fi

# Configure git credential helper for GITHUB_TOKEN
if [ -n "$GITHUB_TOKEN" ]; then
    echo "✓ Configuring git authentication with GitHub token"
    git config --global credential.helper '!f() { echo "username=git"; echo "password=$GITHUB_TOKEN"; }; f'
    git config --global credential.https://github.com.username git
else
    echo "No GITHUB_TOKEN found - git operations will use existing host configuration"
fi

# Check for existing Claude authentication
if [ -f "$HOME/.claude/.credentials.json" ]; then
    echo "✓ Found existing Claude authentication"
else
    echo "No existing Claude authentication found - you will need to log in"
    echo "Your login will be saved for future sessions"
fi

# Determine which AI CLI to start based on arguments or environment
AI_CLI="claude"  # Default to Claude
AI_ARGS="--dangerously-skip-permissions"

# Check if user wants to use Gemini CLI
if [[ "$1" == "--gemini" ]] || [[ "$AI_CLI_PREFERENCE" == "gemini" ]]; then
    AI_CLI="gemini"
    # Remove --gemini flag from arguments if present
    if [[ "$1" == "--gemini" ]]; then
        shift
    fi
    # Set Gemini-specific arguments
    AI_ARGS="--yolo"  # Equivalent to --dangerously-skip-permissions
    echo "Starting Gemini CLI..."
    
    # Check authentication methods in order of preference
    if [ -f "$HOME/.gemini/oauth_credentials.json" ]; then
        echo "✓ Found Gemini OAuth credentials"
    elif [ -n "$GOOGLE_AI_STUDIO_API_KEY" ]; then
        echo "✓ Using Gemini API key from environment"
    else
        echo "WARNING: No Gemini authentication found"
        echo "You need either:"
        echo "  1. OAuth: Run 'gemini auth' on your host system first"
        echo "  2. API Key: Set GOOGLE_AI_STUDIO_API_KEY in environment"
    fi
else
    echo "Starting Claude Code..."
fi

# Change to workspace directory
cd /workspace

# Start the selected AI CLI
exec $AI_CLI $AI_ARGS "$@"
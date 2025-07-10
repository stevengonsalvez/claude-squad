# Enhanced Docker Setup for claude-squad

This directory contains the enhanced Docker setup that integrates claude-docker's powerful features into claude-squad's session management system.

## What's Changed

### From Simple to Enhanced
- **Before**: Separate Docker images for claude, aider, gemini
- **After**: Single enhanced image (`claudesquad/enhanced:latest`) with Claude Code + Gemini CLI + MCP servers

### Key Features Added
1. **Dual AI Support**: Switch between Claude Code and Gemini CLI per session
2. **MCP Server Integration**: Context7 for documentation, extensible via config file
3. **PAT-based Git Authentication**: Uses GITHUB_TOKEN instead of SSH keys
4. **Persistent Authentication**: Mount ~/.claude and ~/.gemini for auth persistence
5. **User Configuration**: Customizable MCP servers via ~/.claude-squad/mcp-servers.txt

## Architecture

### Mounting Strategy
```
Host                          Container
----                          ---------
Git worktree                  /workspace
~/.claude/                    /home/claude-user/.claude/
~/.gemini/                    /home/claude-user/.gemini/
~/.gitconfig                  /home/claude-user/.gitconfig (read-only)
~/.claude-squad/mcp-servers.txt  /home/claude-user/.claude/mcp-servers.txt (read-only)
```

### Environment Variables
- `GITHUB_TOKEN`: For git authentication and GitHub MCP server
- `GOOGLE_AI_STUDIO_API_KEY`: Fallback for Gemini if OAuth not configured
- `AI_CLI_PREFERENCE`: Auto-set based on program selection

### Program Selection
- `claude` or `claude --flags` → Starts Claude Code
- `gemini` or `gemini --flags` → Starts Gemini CLI with --gemini flag
- Both share the same enhanced container image

## Files Structure

```
docker/
├── Dockerfile                 # Enhanced Docker image definition
├── scripts/
│   └── startup.sh            # Container initialization script
├── mcp-servers.txt           # Default MCP server configuration
├── install-mcp-servers.sh    # MCP server installation script
├── setup-enhanced.sh         # User setup script
└── README.md                 # This file
```

## Setup and Usage

### 1. Initial Setup
```bash
# Run the setup script to create config directories
./docker/setup-enhanced.sh

# Remove old docker images (one-time cleanup)
bash remove-old-images.sh
```

### 2. Configure MCP Servers
Edit `~/.claude-squad/mcp-servers.txt` to add or remove MCP servers:
```bash
# Context7 is included by default
claude mcp add -s user --transport sse context7 https://mcp.context7.com/sse

# Add GitHub integration (requires GITHUB_TOKEN)
claude mcp add-json github -s user '{"command":"npx","args":["-y","@modelcontextprotocol/server-github"],"env":{"GITHUB_TOKEN":"${GITHUB_TOKEN}"}}'
```

### 3. Set Environment Variables (Optional)
```bash
export GITHUB_TOKEN=ghp_your_token_here
export GOOGLE_AI_STUDIO_API_KEY=your_api_key
```

### 4. Run claude-squad
```bash
# Use Claude Code
./claude-squad --program claude

# Use Gemini CLI  
./claude-squad --program gemini

# With environment variables
GITHUB_TOKEN=ghp_xxx ./claude-squad --program claude

# Custom Docker image
./claude-squad --docker-image myrepo/custom:latest --program claude
```

## Authentication Setup

### Claude Code
1. Install Claude Code: `npm install -g @anthropic-ai/claude-code`
2. Authenticate: Run `claude` and complete login
3. Credentials are stored in `~/.claude/` and automatically mounted

### Gemini CLI (Optional)
**Option 1: OAuth (Recommended)**
1. Install Gemini CLI: `npm install -g @google/gemini-cli`  
2. Authenticate: Run `gemini auth`
3. Credentials are stored in `~/.gemini/` and automatically mounted

**Option 2: API Key**
1. Get API key from Google AI Studio
2. Set environment variable: `export GOOGLE_AI_STUDIO_API_KEY=your_key`

### Git Authentication
1. Create GitHub Personal Access Token with repo permissions
2. Set environment variable: `export GITHUB_TOKEN=ghp_your_token`
3. Git operations will use this token automatically

## Session Isolation

Each claude-squad session gets:
- **Isolated git worktree**: Separate working directory
- **Isolated conversation history**: Claude/Gemini track context per directory  
- **Shared authentication**: All sessions use the same auth credentials
- **Shared MCP servers**: All sessions have access to the same MCP tools

## Troubleshooting

### Image Build Issues
- Ensure you have Docker installed and running
- Check that git user.name and user.email are configured
- The first build will take several minutes to install MCP servers

### Authentication Issues
- For Claude: Ensure `~/.claude/.credentials.json` exists
- For Gemini: Either `~/.gemini/oauth_credentials.json` or `GOOGLE_AI_STUDIO_API_KEY`
- For Git: Ensure `GITHUB_TOKEN` is set

### MCP Server Issues
- Check `~/.claude-squad/mcp-servers.txt` for syntax errors
- Ensure required environment variables are set
- MCP servers are installed on first container start

## Benefits Over Original Setup

1. **Simplified Management**: One image instead of three
2. **Enhanced Capabilities**: MCP servers provide powerful development tools
3. **Better Authentication**: No SSH key management required
4. **Flexible Configuration**: Easy to add/remove MCP servers
5. **Dual AI Support**: Switch between Claude and Gemini seamlessly
6. **Persistent State**: Conversations and auth survive container restarts
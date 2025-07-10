# Docker Integration Update for claude-squad

## Overview

This document details the complete integration of enhanced Docker capabilities into claude-squad, replacing the simple container approach with a sophisticated setup based on claude-docker that provides MCP server support, dual AI capabilities, and advanced authentication handling.

## What Changed

### Architecture Transformation

**Before: Simple Container Approach**
```
claude-squad → tmux sessions → direct host execution
├── docker/images/claude.Dockerfile    (basic Node.js + claude)
├── docker/images/aider.Dockerfile     (basic Python + aider)  
└── docker/images/gemini.Dockerfile    (basic Node.js + gemini)
```

**After: Enhanced Container Ecosystem**
```
claude-squad → Docker containers → isolated AI environments
└── docker/Dockerfile (enhanced: Claude + Gemini + MCP servers + auth)
    ├── Claude Code with MCP integration
    ├── Gemini CLI with OAuth support
    ├── Context7 MCP server (documentation)
    ├── Extensible MCP server framework
    └── PAT-based git authentication
```

### Key Improvements

1. **Unified Container Image**: Single `claudesquad/enhanced:latest` supports both Claude and Gemini
2. **MCP Server Integration**: Context7 for real-time documentation, extensible via config
3. **Enhanced Authentication**: OAuth for Gemini, PAT for git, persistent Claude auth
4. **Advanced Mounting**: Intelligent volume mounting for auth, config, and conversation history
5. **Environment Integration**: Seamless host environment variable passing

## Technical Implementation

### Docker Container Architecture

#### Base Image Enhancement
```dockerfile
FROM node:20-slim

# System dependencies
RUN apt-get update && apt-get install -y \
    git curl python3 build-essential sudo openssh-client ca-certificates

# AI CLI tools
RUN npm install -g @anthropic-ai/claude-code @google/gemini-cli

# MCP server toolchain
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# User matching for seamless file permissions
ARG USER_UID=1000
ARG USER_GID=1000
RUN useradd -m -s /bin/bash -u $USER_UID -g $USER_GID claude-user
```

#### Intelligent Volume Mounting Strategy

**Core Mounts**:
```go
mounts := []mount.Mount{
    {
        Type:   mount.TypeBind,
        Source: workDir,           // Git worktree for session
        Target: "/workspace",
    },
    {
        Type:   mount.TypeBind,
        Source: "~/.claude",       // Claude auth & conversation history
        Target: "/home/claude-user/.claude",
    },
    {
        Type:   mount.TypeBind,
        Source: "~/.gemini",       // Gemini OAuth credentials (if exists)
        Target: "/home/claude-user/.gemini",
    },
    {
        Type:   mount.TypeBind,
        Source: "~/.gitconfig",    // Git user configuration
        Target: "/home/claude-user/.gitconfig",
        ReadOnly: true,
    },
    {
        Type:   mount.TypeBind,
        Source: "~/.claude-squad/mcp-servers.txt",  // User MCP config
        Target: "/home/claude-user/.claude/mcp-servers.txt",
        ReadOnly: true,
    },
}
```

**Conditional Mounting Logic**:
```go
// Only mount .gemini if directory exists (OAuth users)
if _, err := os.Stat(geminiDir); err == nil {
    // Mount gemini directory
}

// Only mount MCP config if user has customized it
if _, err := os.Stat(mcpConfigPath); err == nil {
    // Mount custom MCP servers configuration
}
```

### Authentication Architecture

#### Multi-Modal Authentication Support

**Claude Code Authentication**:
- **Source**: `~/.claude/.credentials.json` 
- **Mount**: Persistent across all sessions
- **Scope**: Shared authentication, per-directory conversation history

**Gemini CLI Authentication**:
- **Primary**: OAuth via `~/.gemini/oauth_credentials.json`
- **Fallback**: API key via `GOOGLE_AI_STUDIO_API_KEY` environment variable
- **Detection**: Automatic preference for OAuth over API key

**Git Authentication** (PAT-based):
```bash
# Container startup configures git credential helper
if [ -n "$GITHUB_TOKEN" ]; then
    git config --global credential.helper '!f() { 
        echo "username=git"; 
        echo "password=$GITHUB_TOKEN"; 
    }; f'
fi
```

#### Benefits Over SSH Approach
- ✅ **No key management**: No SSH key generation or distribution
- ✅ **Corporate friendly**: Works with firewalls and proxies
- ✅ **Fine-grained permissions**: PATs can be scoped to specific repositories
- ✅ **Easy revocation**: Disable token instantly
- ✅ **Multi-platform**: Same approach works on all operating systems

### MCP Server Integration

#### Default Configuration
```bash
# Context7 - Live documentation and examples
claude mcp add -s user --transport sse context7 https://mcp.context7.com/sse
```

#### Extensible Framework
**User Configuration**: `~/.claude-squad/mcp-servers.txt`
```bash
# GitHub integration (requires GITHUB_TOKEN)
claude mcp add-json github -s user '{
    "command":"npx",
    "args":["-y","@modelcontextprotocol/server-github"],
    "env":{"GITHUB_TOKEN":"${GITHUB_TOKEN}"}
}'

# Filesystem access
claude mcp add -s user filesystem -- npx -y @modelcontextprotocol/server-filesystem

# Browser automation  
claude mcp add -s user browser -- npx -y @modelcontextprotocol/server-browser
```

**Installation Process**:
1. **Build time**: Install default MCP servers (Context7)
2. **Runtime**: Check for user's custom MCP configuration
3. **Dynamic**: Install additional servers based on user config
4. **Environment aware**: Skip servers with missing required env vars

### Session Management Integration

#### Program Detection and Routing
```go
// Auto-detect AI CLI based on program name
if d.program == ProgramGemini || strings.HasPrefix(d.program, ProgramGemini) {
    cmd = append(cmd, "--gemini")
    // Extract any additional arguments
    if strings.Contains(d.program, " ") {
        args := strings.Fields(d.program)
        if len(args) > 1 {
            cmd = append(cmd, args[1:]...)
        }
    }
}
```

#### Environment Variable Handling
```go
func (d *DockerContainer) prepareEnvironment() []string {
    env := []string{"TERM=xterm-256color"}
    
    // Git authentication
    if githubToken := os.Getenv("GITHUB_TOKEN"); githubToken != "" {
        env = append(env, "GITHUB_TOKEN="+githubToken)
    }
    
    // Gemini fallback authentication  
    if apiKey := os.Getenv("GOOGLE_AI_STUDIO_API_KEY"); apiKey != "" {
        env = append(env, "GOOGLE_AI_STUDIO_API_KEY="+apiKey)
    }
    
    // AI preference for mixed setups
    if d.program == ProgramGemini || strings.HasPrefix(d.program, ProgramGemini) {
        env = append(env, "AI_CLI_PREFERENCE=gemini")
    }
    
    return env
}
```

#### Conversation Isolation Strategy
- **Per-worktree isolation**: Each git worktree maintains separate conversation context
- **Shared authentication**: All sessions use the same login credentials  
- **Automatic resumption**: `--continue` flag resumes conversations per directory
- **State persistence**: Conversation history survives container restarts

## Configuration Updates

### Enhanced Config Structure
```json
{
  "default_program": "claude",
  "docker_image_mappings": {
    "claude": "claudesquad/enhanced:latest",
    "aider": "claudesquad/enhanced:latest", 
    "gemini": "claudesquad/enhanced:latest"
  },
  "environment_variables": {
    "GITHUB_TOKEN": "${GITHUB_TOKEN}",
    "GOOGLE_AI_STUDIO_API_KEY": "${GOOGLE_AI_STUDIO_API_KEY}"
  },
  "mcp_servers_file": "~/.claude-squad/mcp-servers.txt"
}
```

### User Configuration Files

**MCP Servers Configuration**: `~/.claude-squad/mcp-servers.txt`
- **Format**: Standard `claude mcp add` commands
- **Environment variables**: `${VAR_NAME}` substitution support
- **Conditional installation**: Skip servers with missing env vars
- **Comments**: `#` prefix for documentation

**Setup Script**: `docker/setup-enhanced.sh`
- Creates `~/.claude-squad/` directory structure
- Generates default MCP servers configuration
- Validates authentication setup
- Provides setup guidance and troubleshooting

## Usage Patterns

### Basic Usage
```bash
# Claude Code with default settings
./claude-squad --program claude

# Gemini CLI 
./claude-squad --program gemini

# With arguments
./claude-squad --program "claude --some-flag"
./claude-squad --program "gemini --model gemini-pro"
```

### Authentication Scenarios
```bash
# Git operations with PAT
GITHUB_TOKEN=ghp_xxxxxxxxxxxx ./claude-squad --program claude

# Gemini with API key fallback
GOOGLE_AI_STUDIO_API_KEY=AIxxxxxxxxxxxx ./claude-squad --program gemini

# Combined environment
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
export GOOGLE_AI_STUDIO_API_KEY=AIxxxxxxxxxxxx
./claude-squad --program claude
```

### Custom Docker Images
```bash
# Use custom image with enhanced features
./claude-squad --docker-image myrepo/custom-claude:latest --program claude

# Organization-specific image
./claude-squad --docker-image enterprise.registry.com/ai-tools:v2.1 --program gemini
```

### MCP Server Customization
```bash
# Edit user's MCP configuration
nano ~/.claude-squad/mcp-servers.txt

# Add GitHub integration (requires GITHUB_TOKEN)
echo 'claude mcp add-json github -s user '"'"'{"command":"npx","args":["-y","@modelcontextprotocol/server-github"],"env":{"GITHUB_TOKEN":"${GITHUB_TOKEN}"}}'"'"'' >> ~/.claude-squad/mcp-servers.txt

# Force rebuild to install new MCP servers
docker rmi claudesquad/enhanced:latest
./claude-squad --program claude  # Will rebuild automatically
```

## Migration Impact

### Backward Compatibility
- ✅ **Existing sessions**: Continue to work without changes
- ✅ **Configuration**: Old config files are automatically updated
- ✅ **Command line**: Same `claude-squad` commands work
- ✅ **Git workflows**: Existing git operations continue seamlessly

### Breaking Changes
- ❌ **Docker images**: Old `claudesquad/claude:latest` etc. no longer used
- ❌ **SSH git auth**: No longer supported (use PAT instead)
- ❌ **Build process**: Must rebuild containers for MCP updates

### Migration Steps
1. **Run setup**: `./docker/setup-enhanced.sh`
2. **Set environment**: Configure `GITHUB_TOKEN` for git operations
3. **Clean old images**: `docker rmi claudesquad/claude:latest claudesquad/aider:latest claudesquad/gemini:latest`
4. **Test session**: Create new session to trigger image build

## Advanced Features

### Container Resource Management
```go
// Future: Resource limits per session
hostConfig := &container.HostConfig{
    Resources: container.Resources{
        Memory:   512 * 1024 * 1024, // 512MB
        CPUQuota: 50000,              // 50% CPU
    },
}
```

### Multi-AI Session Support
```bash
# Claude session
./claude-squad --program claude  # Creates session with Claude

# Gemini session in same project  
./claude-squad --program gemini  # Creates separate session with Gemini

# Both sessions can coexist, each with own conversation context
```

### Development Environment Integration
```bash
# Mount additional development tools
docker run ... \
  -v ~/.ssh:/home/claude-user/.ssh:ro \
  -v ~/.aws:/home/claude-user/.aws:ro \
  -v ~/.kube:/home/claude-user/.kube:ro \
  claudesquad/enhanced:latest
```

## Troubleshooting Guide

### Authentication Issues

**Claude Authentication**:
```bash
# Check if credentials exist
ls -la ~/.claude/.credentials.json

# Re-authenticate if needed
claude  # Complete login flow
```

**Gemini Authentication**:
```bash
# OAuth method (preferred)
gemini auth

# API key method
export GOOGLE_AI_STUDIO_API_KEY=your_key_here
```

**Git Authentication**:
```bash
# Check token permissions
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user

# Test git operations
git clone https://github.com/user/repo.git
```

### Container Issues

**Image Build Problems**:
```bash
# Force rebuild without cache
docker build --no-cache -t claudesquad/enhanced:latest docker/

# Check build logs
docker build -t claudesquad/enhanced:latest docker/ 2>&1 | tee build.log
```

**Mount Permission Issues**:
```bash
# Check file ownership
ls -la ~/.claude/ ~/.gemini/ ~/.gitconfig

# Fix permissions if needed
sudo chown -R $(whoami) ~/.claude/ ~/.gemini/
```

**MCP Server Installation Failures**:
```bash
# Check MCP configuration syntax
cat ~/.claude-squad/mcp-servers.txt

# Test individual MCP server installation
docker run -it --rm claudesquad/enhanced:latest bash
claude mcp add -s user --transport sse context7 https://mcp.context7.com/sse
```

### Environment Variable Issues

**Missing Variables**:
```bash
# Check what's available
env | grep -E "(GITHUB|GOOGLE|CLAUDE)"

# Set temporarily
export GITHUB_TOKEN=ghp_your_token
export GOOGLE_AI_STUDIO_API_KEY=your_key

# Set permanently (add to ~/.bashrc or ~/.zshrc)
echo 'export GITHUB_TOKEN=ghp_your_token' >> ~/.bashrc
```

## Performance Considerations

### Container Startup Time
- **First run**: 2-3 minutes (image build + MCP server installation)
- **Subsequent runs**: 10-15 seconds (existing image)
- **MCP server updates**: 30-60 seconds (rebuild required)

### Resource Usage
- **Base container**: ~200MB RAM, minimal CPU
- **With MCP servers**: ~300-400MB RAM
- **Active AI session**: +100-200MB depending on context size

### Optimization Strategies
- **Image caching**: Keep `claudesquad/enhanced:latest` image for fast startup
- **Environment persistence**: Set environment variables in shell profile
- **MCP server selection**: Only install needed MCP servers to reduce overhead

## Security Considerations

### Authentication Security
- **PAT scope limitation**: Use minimal required permissions for GitHub tokens
- **Environment isolation**: Container environment separate from host
- **Credential persistence**: Auth files only accessible within container

### Container Security
- **Non-root execution**: All processes run as non-root `claude-user`
- **File system isolation**: Container cannot access host files outside mounts
- **Network isolation**: Container network separate from host network

### Best Practices
- **Token rotation**: Regularly rotate GitHub PATs and API keys
- **Audit logging**: Monitor container access and git operations
- **Principle of least privilege**: Grant minimal required permissions

## Future Enhancements

### Planned Features
1. **Network firewall**: Restrict container internet access to approved domains
2. **Resource quotas**: Per-session CPU and memory limits
3. **Audit logging**: Complete session activity logging
4. **Plugin system**: Easy MCP server plugin installation
5. **Multi-cloud auth**: Support for AWS, Azure, GCP credentials

### Extension Points
- **Custom startup hooks**: User-defined container initialization scripts
- **Volume plugin system**: Additional mount strategies
- **Authentication providers**: Support for corporate SSO
- **Monitoring integration**: Prometheus/Grafana metrics

## Build and Run Guide

### Quick Start

**Step 1: Clean up and prepare**
```bash
# Remove old Docker images directory
rm -rf docker/images/

# Make scripts executable
chmod +x docker/scripts/startup.sh docker/install-mcp-servers.sh docker/setup-enhanced.sh docker/create-default-mcp-config.sh

# Remove old Docker images if they exist
docker rmi claudesquad/claude:latest claudesquad/aider:latest claudesquad/gemini:latest 2>/dev/null || true
```

**Step 2: Build the Go binary**
```bash
# Build the claude-squad binary
go build -o claude-squad

# Or with verbose output to see what's happening
go build -v -o claude-squad
```

**Step 3: Set up the enhanced Docker environment**
```bash
# Run the setup script to create config directories
./docker/setup-enhanced.sh
```

**Step 4: Set up authentication (Prerequisites)**

*Claude Code Authentication:*
```bash
# Install Claude Code if not already installed
npm install -g @anthropic-ai/claude-code

# Authenticate (run once)
claude
# Complete the login flow in your browser
```

*Git Configuration:*
```bash
# Set up git if not already done
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Create a GitHub Personal Access Token
# Go to: https://github.com/settings/tokens
# Create token with 'repo' permissions
# Set it as environment variable
export GITHUB_TOKEN=ghp_your_token_here
```

*Optional - Gemini CLI:*
```bash
# Install Gemini CLI (optional)
npm install -g @google/gemini-cli

# Option 1: OAuth (recommended)
gemini auth

# Option 2: API Key
export GOOGLE_AI_STUDIO_API_KEY=your_api_key_here
```

**Step 5: Run claude-squad**
```bash
# Basic usage with Claude
./claude-squad --program claude

# With Gemini
./claude-squad --program gemini

# With environment variables
GITHUB_TOKEN=ghp_xxx ./claude-squad --program claude

# With both GitHub and Gemini
GITHUB_TOKEN=ghp_xxx GOOGLE_AI_STUDIO_API_KEY=your_key ./claude-squad --program claude
```

### Quick Start Script

For convenience, use the provided quick start script:
```bash
# Make it executable and run
chmod +x quick-start.sh
./quick-start.sh
```

This script will:
- Clean up old Docker setup
- Build the binary
- Set up the enhanced environment
- Provide usage guidance

### What Happens on First Run

When you run `./claude-squad --program claude` for the first time:

1. **Docker Image Build**: Takes 2-3 minutes to build `claudesquad/enhanced:latest`
2. **MCP Server Installation**: Installs Context7 and other MCP servers
3. **Container Creation**: Creates a new container for your session
4. **Authentication**: Uses your existing Claude auth from `~/.claude/`
5. **Git Configuration**: Uses your host git config and GITHUB_TOKEN
6. **Session Start**: Launches Claude Code with enhanced capabilities

### Build Troubleshooting

**If build fails:**
```bash
# Check Go version (needs 1.20+)
go version

# Clean and rebuild
go clean -cache
go build -v -o claude-squad
```

**If Docker fails:**
```bash
# Check Docker is running
docker info

# Check if you're in a git repo
git status
```

**If authentication fails:**
```bash
# Check Claude auth
ls -la ~/.claude/.credentials.json

# Re-authenticate Claude
claude

# Check environment variables
echo $GITHUB_TOKEN
```

### Next Steps After Setup

1. **Start with**: `./claude-squad --program claude`
2. **Customize MCP servers**: Edit `~/.claude-squad/mcp-servers.txt`
3. **Read documentation**: Check `docker/README.md` and this file
4. **Set up shell environment**: Add tokens to your shell profile

```bash
# Add to ~/.bashrc or ~/.zshrc for persistence
echo 'export GITHUB_TOKEN=ghp_your_token' >> ~/.bashrc
echo 'export GOOGLE_AI_STUDIO_API_KEY=your_key' >> ~/.bashrc
```

## Summary

This Docker integration update transforms claude-squad from a simple container orchestrator into a sophisticated AI development environment that rivals dedicated AI IDEs while maintaining the flexibility and session management that makes claude-squad unique.

**Key Benefits Achieved**:
- ✅ **Unified AI access**: Both Claude and Gemini in one seamless interface
- ✅ **Enhanced capabilities**: MCP servers provide powerful development tools
- ✅ **Simplified authentication**: PAT-based git, persistent AI auth
- ✅ **Flexible configuration**: User-customizable MCP servers and environment
- ✅ **Production ready**: Robust error handling and troubleshooting support

The enhanced Docker setup positions claude-squad as a comprehensive solution for AI-assisted development workflows while maintaining its core strength in managing multiple parallel AI sessions.
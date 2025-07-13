# 🐳 Docker Usage Guide for Claude Squad

## 🚀 Quick Start

### 1. Navigate to Your Project Repository
```bash
# Go to the git repository you want to work on
cd /path/to/your/project

# Verify it's a git repository
git status
```

### 2. Run Claude Squad in Docker
```bash
# From your project directory, run:
/path/to/claude-squad/run-docker-dev-auth.sh

# Or copy the script to your PATH and run:
run-docker-dev-auth.sh
```

## 📋 What You'll See

```
🐳 Claude Squad Development Container (Auth-Ready)
📋 Host User Info:
  User: stevengonsalvez (UID: 504, GID: 20)
✓ Found ~/.claude directory
✓ Claude OAuth credentials found (config.json)
✓ GitHub token available
✓ Git repository: /Users/stevengonsalvez/my-project
🚀 Starting container with host user mapping...

Claude Squad Container Ready!
Git Author: steven gonsalvez <steven.gonsalvez@gmail.com>
Working Directory: /Users/stevengonsalvez/my-project
```

## 🛠️ Features Available in Container

### ✅ **AI Assistant Management**
- Claude Squad TUI with multiple agent sessions
- Your Claude Pro OAuth credentials (no API key needed)
- GitHub integration with your token

### ✅ **Development Environment**
- Full language support (Node.js, Python, Go, Rust, Java, Ruby, PHP)
- All package managers and build tools
- Docker-in-Docker capability
- Your SSH keys for git operations

### ✅ **Git Integration**
- Your repository mounted at the same path
- Git config automatically set up
- SSH keys available for private repos
- GitHub CLI authenticated

## 🎯 **Usage Examples**

### Start Claude Squad TUI
```bash
# Inside container (default behavior)
claude-squad
```

### Use AI Assistant Tools
```bash
# Start Aider for AI pair programming
aider

# Use Claude CLI (if you have it installed on host)
claude "Help me refactor this function"
```

### Run Development Tasks
```bash
# Install dependencies
npm install
# or
pip install -r requirements.txt

# Run tests
npm test
# or  
pytest

# Build project
npm run build
# or
go build
```

### Use GitHub CLI
```bash
# Create a pull request
gh pr create --title "My feature" --body "Description"

# Check issues
gh issue list

# Clone other repos
gh repo clone owner/repo
```

## 🔧 **Troubleshooting**

### "Not in a git repository" Error
```bash
# Make sure you're in a git repository root
cd /path/to/your/project
git status

# Then run the script
/path/to/claude-squad/run-docker-dev-auth.sh
```

### "No Claude OAuth credentials found"
```bash
# On your host machine (not in container)
claude auth login
# Follow the browser authentication flow

# Then restart the container
./run-docker-dev-auth.sh
```

### "No GitHub token"
```bash
# Authenticate GitHub CLI on host
gh auth login

# Or set token manually
export GITHUB_TOKEN="your_token_here"
./run-docker-dev-auth.sh
```

## 📁 **Directory Structure**

When you run from `/Users/stevengonsalvez/my-project`:

```
Container View:
/Users/stevengonsalvez/my-project/  ← Your project (mounted)
/Users/stevengonsalvez/.claude/     ← Claude config (mounted)
/Users/stevengonsalvez/.ssh/        ← SSH keys (mounted read-only)
```

Your project directory is mounted at the exact same path in the container, so all relative paths work correctly.

## 🎉 **Ready to Code!**

The container provides a complete, isolated development environment with:
- Your Claude Pro access via OAuth
- Your GitHub authentication  
- Your SSH keys and git config
- All development tools pre-installed
- Docker access for container operations

Happy coding with Claude Squad! 🚀
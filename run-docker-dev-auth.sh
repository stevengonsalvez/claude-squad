#!/bin/bash
# ABOUTME: Launch Claude Squad with proper user mapping for OAuth credential access

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🐳 Claude Squad Development Container (Auth-Ready)${NC}"

# Get host user info
HOST_UID=$(id -u)
HOST_GID=$(id -g)
HOST_USER=$(whoami)

echo -e "${BLUE}📋 Host User Info:${NC}"
echo -e "  User: $HOST_USER (UID: $HOST_UID, GID: $HOST_GID)"

# Check Claude directory and OAuth credentials
if [ -d "$HOME/.claude" ]; then
    echo -e "${GREEN}✓ Found ~/.claude directory${NC}"
    
    # Check for various Claude credential files
    CRED_FOUND=false
    for cred_file in "config.json" "oauth_token" "session.json" "credentials.json"; do
        if [ -r "$HOME/.claude/$cred_file" ]; then
            echo -e "${GREEN}✓ Claude OAuth credentials found ($cred_file)${NC}"
            CRED_FOUND=true
            break
        fi
    done
    
    if [ "$CRED_FOUND" = false ]; then
        echo -e "${YELLOW}⚠️  No Claude OAuth credentials found - you may need to run 'claude auth login' first${NC}"
    fi
else
    echo -e "${RED}✗ No ~/.claude directory found${NC}"
    echo -e "${YELLOW}  Run 'claude auth login' on your host first${NC}"
fi

# GitHub token
GH_TOKEN="${GITHUB_TOKEN:-}"
if [ -z "$GH_TOKEN" ] && command -v gh &> /dev/null && gh auth status &> /dev/null 2>&1; then
    GH_TOKEN=$(gh auth token 2>/dev/null || echo "")
fi

if [ -n "$GH_TOKEN" ]; then
    echo -e "${GREEN}✓ GitHub token available${NC}"
else
    echo -e "${YELLOW}⚠️  No GitHub token (set GITHUB_TOKEN or use 'gh auth login')${NC}"
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}✗ Not in a git repository${NC}"
    echo -e "${YELLOW}  Please run this script from the root of the git repository you want to work on${NC}"
    echo -e "${YELLOW}  Example: cd /path/to/your/project && $HOME/path/to/claude-squad/run-docker-dev-auth.sh${NC}"
    exit 1
fi

GIT_ROOT=$(git rev-parse --show-toplevel)
PROJECT_NAME=$(basename "$GIT_ROOT")
CONTAINER_NAME="claude-squad-${PROJECT_NAME}-$(echo $GIT_ROOT | md5sum | cut -c1-8)"

echo -e "${GREEN}✓ Git repository: $GIT_ROOT${NC}"
echo -e "${GREEN}✓ Project: $PROJECT_NAME${NC}"
echo -e "${BLUE}✓ Container name: $CONTAINER_NAME${NC}"

# Check for existing containers and offer to clean up
EXISTING_CONTAINERS=$(docker ps -a --filter name=claude-squad --format "{{.Names}}" | grep -v "^$" || true)
if [ -n "$EXISTING_CONTAINERS" ]; then
    echo -e "${YELLOW}⚠️  Found existing Claude Squad containers:${NC}"
    echo "$EXISTING_CONTAINERS" | sed 's/^/  /'
    echo -e "${BLUE}💡 Run this to clean them up: docker rm -f \$(docker ps -aq --filter name=claude-squad)${NC}"
    echo ""
fi

# Create Claude Squad data directories with proper ownership
echo -e "${BLUE}📁 Setting up Claude Squad data directories...${NC}"
mkdir -p ~/.claude-squad ~/.config/claude-squad ~/.local/share/claude-squad
mkdir -p "/tmp/claude-squad-$PROJECT_NAME"
chmod 755 "/tmp/claude-squad-$PROJECT_NAME" 2>/dev/null || true
echo -e "${GREEN}✓ Claude Squad directories ready${NC}"

echo -e "${BLUE}🚀 Starting container with host user mapping...${NC}"

# Check if debug mode is requested
DEBUG_MODE=false
if [ "$1" = "debug" ]; then
    DEBUG_MODE=true
    echo -e "${YELLOW}🔍 Debug mode enabled - will run tmux diagnostics${NC}"
    shift # Remove 'debug' from arguments
fi

# Run container as host user to access OAuth creds
docker run -it --rm \
  --name "$CONTAINER_NAME" \
  --user $HOST_UID:$HOST_GID \
  -v ~/.claude:$HOME/.claude \
  -v ~/.claude-squad:$HOME/.claude-squad \
  -v ~/.config/claude-squad:$HOME/.config/claude-squad \
  -v ~/.local/share/claude-squad:$HOME/.local/share/claude-squad \
  -v /tmp/claude-squad-$PROJECT_NAME:/tmp/claude-squad \
  -v ~/.gitconfig:$HOME/.gitconfig-host:ro \
  -v ~/.ssh:$HOME/.ssh:ro \
  -v "$GIT_ROOT:$GIT_ROOT" \
  -w "$GIT_ROOT" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /etc/passwd:/etc/passwd:ro \
  -v /etc/group:/etc/group:ro \
  -v /tmp/tmux-$HOST_UID:/tmp/tmux-$HOST_UID \
  -v "$(dirname "$0")/debug-tmux-claude-squad.sh:/debug-tmux-claude-squad.sh:ro" \
  -e HOME=$HOME \
  -e USER=$HOST_USER \
  -e GITHUB_TOKEN="$GITHUB_TOKEN" \
  -e GIT_USER_NAME="${GIT_USER_NAME:-$(git config user.name 2>/dev/null || echo $HOST_USER)}" \
  -e GIT_USER_EMAIL="${GIT_USER_EMAIL:-$(git config user.email 2>/dev/null || echo $HOST_USER@localhost)}" \
  -p 3000-3020:3000-3020 \
  -p 8000-8020:8000-8020 \
  --entrypoint="" \
  claude-squad:dev bash -c "
    # Set up git config properly for worktrees
    git config --global user.name '${GIT_USER_NAME:-$(git config user.name 2>/dev/null || echo $HOST_USER)}' 2>/dev/null || true
    git config --global user.email '${GIT_USER_EMAIL:-$(git config user.email 2>/dev/null || echo $HOST_USER@localhost)}' 2>/dev/null || true
    git config --global init.defaultBranch main 2>/dev/null || true
    git config --global pull.rebase true 2>/dev/null || true
    git config --global core.autocrlf input 2>/dev/null || true
    git config --global safe.directory '*' 2>/dev/null || true
    
    # Fix user setup for proper ownership
    echo 'Setting up container user...'
    # Ensure Claude Squad directories have correct ownership
    chown -R \$(id -u):\$(id -g) $HOME/.claude-squad $HOME/.config/claude-squad $HOME/.local/share/claude-squad 2>/dev/null || true
    
    # Fix Claude Squad configuration for container environment
    echo 'Configuring Claude Squad for container...'
    
    # Backup existing config and create a fresh container-compatible one
    if [ -f $HOME/.claude-squad/config.json ]; then
      cp $HOME/.claude-squad/config.json $HOME/.claude-squad/config.json.host-backup
      echo 'Backed up host config to config.json.host-backup'
    fi
    
    # Create a container-specific config
    mkdir -p $HOME/.claude-squad
    cat > $HOME/.claude-squad/config.json << 'EOF'
{
  \"default_program\": \"/bin/bash\",
  \"auto_yes\": false,
  \"daemon_poll_interval\": 1000,
  \"branch_prefix\": \"container/\"
}
EOF
    echo 'Created container-specific Claude Squad config with /bin/bash as default program'
    
    # Fix tmux socket permissions for Claude Squad
    echo 'Setting up tmux for Claude Squad...'
    export TMUX_TMPDIR=/tmp/tmux-\$(id -u)
    mkdir -p /tmp/tmux-\$(id -u)
    chmod 755 /tmp/tmux-\$(id -u)
    
    # Kill any existing tmux server that might have wrong permissions
    pkill -f tmux 2>/dev/null || true
    
    # Set tmux environment variables
    export TERM=xterm-256color
    export COLORTERM=truecolor
    
    # Set up environment variables as backup
    export GIT_AUTHOR_NAME='${GIT_USER_NAME:-$(git config user.name 2>/dev/null || echo $HOST_USER)}'
    export GIT_AUTHOR_EMAIL='${GIT_USER_EMAIL:-$(git config user.email 2>/dev/null || echo $HOST_USER@localhost)}'
    export GIT_COMMITTER_NAME='\$GIT_AUTHOR_NAME'
    export GIT_COMMITTER_EMAIL='\$GIT_AUTHOR_EMAIL'
    
    # Set up GitHub CLI if token is provided
    if [ -n '$GH_TOKEN' ]; then
      echo '$GH_TOKEN' | gh auth login --with-token 2>/dev/null || true
    fi
    
    # Ensure git repository is properly configured
    if [ -d .git ]; then
      # Make sure the repository is not considered unsafe
      git config --global --add safe.directory \$(pwd) 2>/dev/null || true
      # Set up worktree directory with proper permissions
      mkdir -p worktrees 2>/dev/null || true
      chmod 755 worktrees 2>/dev/null || true
    fi
    
    echo 'Claude Squad Container Ready!'
    echo 'Git Author: '\$GIT_AUTHOR_NAME' <'\$GIT_AUTHOR_EMAIL'>'
    echo 'Working Directory: \$(pwd)'
    echo 'Git Status: \$(git status --porcelain | wc -l) changes'
    echo 'Home Directory: '$HOME''
    echo 'User: \$(whoami) (UID: \$(id -u), GID: \$(id -g))'
    
    # Check Claude Squad directories
    echo ''
    echo 'Claude Squad Directories:'
    for dir in '$HOME/.claude-squad' '$HOME/.config/claude-squad' '$HOME/.local/share/claude-squad' '/tmp/claude-squad'; do
      if [ -d \"\$dir\" ]; then
        echo \"  ✓ \$dir (\$(ls -ld \"\$dir\" | awk '{print \$1, \$3, \$4}'))\"
      else
        echo \"  ✗ \$dir (missing)\"
        mkdir -p \"\$dir\" 2>/dev/null || echo \"    Failed to create \$dir\"
      fi
    done
    echo ''
    
    # Start claude-squad or run provided command
    if [ '$DEBUG_MODE' = 'true' ]; then
      echo 'Running tmux debug diagnostics...'
      /debug-tmux-claude-squad.sh
    elif [ \$# -eq 0 ]; then
      claude-squad
    else
      \$*
    fi
  " -- "$@"
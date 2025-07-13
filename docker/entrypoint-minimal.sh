#!/bin/bash
# ABOUTME: Minimal entrypoint script for Claude Squad - basic initialization for lightweight container

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Minimal git setup
setup_git() {
    if [ -n "$GIT_USER_NAME" ]; then
        git config --global user.name "$GIT_USER_NAME"
    else
        git config --global user.name "Claude Squad User"
    fi
    
    if [ -n "$GIT_USER_EMAIL" ]; then
        git config --global user.email "$GIT_USER_EMAIL"
    else
        git config --global user.email "user@claudesquad.local"
    fi
    
    git config --global init.defaultBranch main
    log_success "Git configured"
}

# Basic SSH setup
setup_ssh() {
    if [ -d "/home/user/.ssh" ] && [ "$(ls -A /home/user/.ssh 2>/dev/null)" ]; then
        chmod 700 /home/user/.ssh
        find /home/user/.ssh -type f -name "id_*" -not -name "*.pub" -exec chmod 600 {} \; 2>/dev/null || true
        log_success "SSH keys configured"
    fi
}

# Verify minimal tools
verify_tools() {
    local tools=("git" "tmux" "gh" "claude-squad")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_warning "Missing tool: $tool"
        fi
    done
    log_success "Tool verification complete"
}

# Minimal banner
print_banner() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}              ${GREEN}Claude Squad (Minimal)${NC}              ${BLUE}║${NC}"
    echo -e "${BLUE}╠═══════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC} Workspace: ${YELLOW}$WORKSPACE_DIR${NC}                         ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} Available: claude-squad, git, tmux, gh       ${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Main function
main() {
    log_info "Starting Claude Squad minimal container..."
    
    setup_git
    setup_ssh
    verify_tools
    print_banner
    
    log_success "Minimal container ready!"
    
    # Execute the command
    if [ $# -eq 0 ]; then
        exec /bin/bash
    else
        exec "$@"
    fi
}

main "$@"
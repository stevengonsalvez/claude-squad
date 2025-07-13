#!/bin/bash
# ABOUTME: Container entrypoint script for Claude Squad - initializes git config, SSH, and development environment

set -e

# Colors for output
RED='\033[0;31m'
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

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Initialize git configuration if environment variables are provided
setup_git() {
    log_info "Setting up Git configuration..."
    
    if [ -n "$GIT_USER_NAME" ]; then
        git config --global user.name "$GIT_USER_NAME"
        log_success "Git user.name set to: $GIT_USER_NAME"
    else
        log_warning "GIT_USER_NAME not set, using default"
        git config --global user.name "Claude Squad User"
    fi
    
    if [ -n "$GIT_USER_EMAIL" ]; then
        git config --global user.email "$GIT_USER_EMAIL"
        log_success "Git user.email set to: $GIT_USER_EMAIL"
    else
        log_warning "GIT_USER_EMAIL not set, using default"
        git config --global user.email "user@claudesquad.local"
    fi
    
    # Set up some sensible git defaults
    git config --global init.defaultBranch main
    git config --global pull.rebase true
    git config --global core.autocrlf input
    log_success "Git configuration complete"
}

# Set up SSH agent if SSH keys are mounted
setup_ssh() {
    log_info "Setting up SSH..."
    
    if [ -d "/home/user/.ssh" ] && [ "$(ls -A /home/user/.ssh 2>/dev/null)" ]; then
        # Fix permissions on SSH directory and keys
        chmod 700 /home/user/.ssh
        find /home/user/.ssh -type f -name "id_*" -not -name "*.pub" -exec chmod 600 {} \;
        find /home/user/.ssh -type f -name "*.pub" -exec chmod 644 {} \;
        
        # Start SSH agent and add keys
        eval "$(ssh-agent -s)"
        for key in /home/user/.ssh/id_*; do
            if [ -f "$key" ] && [[ "$key" != *.pub ]]; then
                ssh-add "$key" 2>/dev/null || log_warning "Could not add SSH key: $key"
            fi
        done
        log_success "SSH setup complete"
    else
        log_warning "No SSH keys found in /home/user/.ssh"
    fi
}

# Verify required tools are available
verify_tools() {
    log_info "Verifying required tools..."
    
    local tools=("git" "tmux" "gh" "claude-squad")
    local missing_tools=()
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -eq 0 ]; then
        log_success "All required tools are available"
    else
        log_error "Missing required tools: ${missing_tools[*]}"
        exit 1
    fi
}

# Check Docker socket access for Docker-in-Docker
check_docker() {
    log_info "Checking Docker access..."
    
    if [ -S "/var/run/docker.sock" ]; then
        if docker version &> /dev/null; then
            log_success "Docker access confirmed"
        else
            log_warning "Docker socket present but access failed - check permissions"
        fi
    else
        log_warning "Docker socket not mounted - Docker-in-Docker unavailable"
    fi
}

# Set up AI assistant tools
setup_ai_tools() {
    log_info "Setting up AI assistant tools..."
    
    # Check for API keys
    if [ -n "$ANTHROPIC_API_KEY" ]; then
        log_success "Anthropic API key configured"
    else
        log_warning "ANTHROPIC_API_KEY not set - Claude may not work"
    fi
    
    if [ -n "$OPENAI_API_KEY" ]; then
        log_success "OpenAI API key configured"
    else
        log_warning "OPENAI_API_KEY not set - OpenAI tools may not work"
    fi
    
    # Verify AI tools are available
    local ai_tools=("aider")
    for tool in "${ai_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_success "$tool is available"
        else
            log_warning "$tool is not available"
        fi
    done
}

# Create workspace structure
setup_workspace() {
    log_info "Setting up workspace..."
    
    # Ensure workspace directory exists and is writable
    if [ ! -d "$WORKSPACE_DIR" ]; then
        mkdir -p "$WORKSPACE_DIR"
    fi
    
    # Create common development directories
    mkdir -p "$WORKSPACE_DIR"/{projects,tmp,logs}
    
    # Set up tmux configuration for better claude-squad experience
    cat > /home/user/.tmux.conf << 'EOF'
# Claude Squad optimized tmux configuration
set -g default-terminal "screen-256color"
set -g mouse on
set -g history-limit 10000

# Status bar
set -g status-bg colour234
set -g status-fg colour137
set -g status-left '#[fg=colour233,bg=colour241,bold] #S '
set -g status-right '#[fg=colour233,bg=colour241,bold] %d/%m #[fg=colour233,bg=colour245,bold] %H:%M:%S '

# Window status
setw -g window-status-current-format '#[fg=colour81,bg=colour238,bold] #I#[fg=colour250]:#[fg=colour255]#W#[fg=colour50]#F '
setw -g window-status-format '#[fg=colour138,bg=colour235] #I#[fg=colour250]:#[fg=colour250]#W#[fg=colour244]#F '
EOF
    
    log_success "Workspace setup complete"
}

# Print banner with container information
print_banner() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}                              ${GREEN}Claude Squad Container${NC}                              ${BLUE}║${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC} Workspace: ${YELLOW}$WORKSPACE_DIR${NC}                                                    ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} User: ${YELLOW}$(whoami)${NC}                                                               ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} Default Program: ${YELLOW}${CS_DEFAULT_PROGRAM:-claude}${NC}                                                ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}                                                                              ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} Available Commands:                                                          ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}   • ${GREEN}claude-squad${NC} - Start Claude Squad TUI                                  ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}   • ${GREEN}claude${NC} - Claude CLI (if configured)                                ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}   • ${GREEN}aider${NC} - AI pair programming assistant                              ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}   • ${GREEN}gh${NC} - GitHub CLI                                                    ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}   • ${GREEN}docker${NC} - Docker CLI (with socket access)                          ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Set up GitHub CLI authentication
setup_github_auth() {
    log_info "Setting up GitHub authentication..."
    
    # Check if gh config is mounted
    if [ -d "/home/user/.config/gh" ] && [ -f "/home/user/.config/gh/hosts.yml" ]; then
        log_success "GitHub CLI configuration found (mounted)"
    elif [ -n "$GITHUB_TOKEN" ]; then
        # Configure gh with token
        echo "$GITHUB_TOKEN" | gh auth login --with-token 2>/dev/null
        log_success "GitHub CLI authenticated with token"
    else
        log_warning "No GitHub authentication found - gh commands may require login"
    fi
    
    # Set up git credential helper
    if [ -f "/home/user/.git-credentials" ]; then
        git config --global credential.helper store
        log_success "Git credentials configured"
    fi
}

# Main initialization
main() {
    log_info "Starting Claude Squad container initialization..."
    
    setup_git
    setup_ssh
    setup_github_auth
    verify_tools
    check_docker
    setup_ai_tools
    setup_workspace
    
    print_banner
    
    log_success "Container initialization complete!"
    
    # Execute the command passed to the container
    if [ $# -eq 0 ]; then
        log_info "No command specified, starting interactive shell"
        exec /bin/bash
    else
        log_info "Executing command: $*"
        exec "$@"
    fi
}

# Run main function with all arguments
main "$@"
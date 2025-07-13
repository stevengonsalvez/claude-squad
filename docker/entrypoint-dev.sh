#!/bin/bash
# ABOUTME: Development entrypoint script for Claude Squad - comprehensive initialization for full development container

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

log_dev() {
    echo -e "${PURPLE}[DEV]${NC} $1"
}

# Enhanced git configuration
setup_git() {
    log_info "Setting up Git configuration for development..."
    
    # Check if .gitconfig is writable (not mounted read-only)
    if [ -w "$HOME/.gitconfig" ] 2>/dev/null || [ ! -f "$HOME/.gitconfig" ]; then
        # Can write to global config
        if [ -n "$GIT_USER_NAME" ]; then
            git config --global user.name "$GIT_USER_NAME"
            log_success "Git user.name set to: $GIT_USER_NAME"
        else
            log_warning "GIT_USER_NAME not set, using default"
            git config --global user.name "Claude Squad Developer"
        fi
        
        if [ -n "$GIT_USER_EMAIL" ]; then
            git config --global user.email "$GIT_USER_EMAIL"
            log_success "Git user.email set to: $GIT_USER_EMAIL"
        else
            log_warning "GIT_USER_EMAIL not set, using default"
            git config --global user.email "dev@claudesquad.local"
        fi
        
        # Enhanced git configuration for development
        git config --global init.defaultBranch main 2>/dev/null || true
        git config --global pull.rebase true 2>/dev/null || true
        git config --global core.autocrlf input 2>/dev/null || true
        git config --global core.editor vim 2>/dev/null || true
        git config --global merge.tool vimdiff 2>/dev/null || true
        git config --global diff.tool vimdiff 2>/dev/null || true
        git config --global alias.st status 2>/dev/null || true
        git config --global alias.co checkout 2>/dev/null || true
        git config --global alias.br branch 2>/dev/null || true
        git config --global alias.ci commit 2>/dev/null || true
        git config --global alias.unstage 'reset HEAD --' 2>/dev/null || true
        git config --global alias.last 'log -1 HEAD' 2>/dev/null || true
        git config --global alias.visual '!gitk' 2>/dev/null || true
        
        log_success "Enhanced Git configuration complete"
    else
        # .gitconfig is read-only (mounted from host)
        log_success "Using host Git configuration (read-only mount)"
        
        # Show current git config
        local current_name=$(git config user.name 2>/dev/null || echo "Not set")
        local current_email=$(git config user.email 2>/dev/null || echo "Not set")
        log_info "Current Git user: $current_name <$current_email>"
        
        # Set up local git config in container if needed
        if [ -n "$GIT_USER_NAME" ] && [ "$current_name" != "$GIT_USER_NAME" ]; then
            export GIT_AUTHOR_NAME="$GIT_USER_NAME"
            export GIT_COMMITTER_NAME="$GIT_USER_NAME"
            log_info "Set GIT_AUTHOR_NAME to: $GIT_USER_NAME"
        fi
        
        if [ -n "$GIT_USER_EMAIL" ] && [ "$current_email" != "$GIT_USER_EMAIL" ]; then
            export GIT_AUTHOR_EMAIL="$GIT_USER_EMAIL"
            export GIT_COMMITTER_EMAIL="$GIT_USER_EMAIL"
            log_info "Set GIT_AUTHOR_EMAIL to: $GIT_USER_EMAIL"
        fi
    fi
}

# Enhanced SSH setup
setup_ssh() {
    log_info "Setting up SSH for development..."
    
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
        log_success "SSH setup complete with agent running"
    else
        log_warning "No SSH keys found in /home/user/.ssh"
    fi
}

# Verify development tools
verify_dev_tools() {
    log_info "Verifying development tools..."
    
    local core_tools=("git" "tmux" "gh" "claude-squad")
    local dev_tools=("node" "npm" "python3" "pip3" "go" "cargo" "java" "ruby" "php")
    local ai_tools=("aider")
    
    log_dev "Checking core tools..."
    for tool in "${core_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_success "✓ $tool is available"
        else
            log_error "✗ $tool is missing"
        fi
    done
    
    log_dev "Checking development tools..."
    for tool in "${dev_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            version=$(${tool} --version 2>/dev/null | head -n1 || echo "unknown")
            log_success "✓ $tool ($version)"
        else
            log_warning "✗ $tool not available"
        fi
    done
    
    log_dev "Checking AI tools..."
    for tool in "${ai_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_success "✓ $tool is available"
        else
            log_warning "✗ $tool not available"
        fi
    done
}

# Enhanced Docker check
check_docker() {
    log_info "Checking Docker and container tools..."
    
    if [ -S "/var/run/docker.sock" ]; then
        if docker version &> /dev/null; then
            docker_version=$(docker --version)
            log_success "✓ Docker access confirmed: $docker_version"
            
            # Check for Docker Compose
            if docker compose version &> /dev/null; then
                compose_version=$(docker compose version)
                log_success "✓ Docker Compose available: $compose_version"
            fi
        else
            log_warning "Docker socket present but access failed - check permissions"
        fi
    else
        log_warning "Docker socket not mounted - Docker-in-Docker unavailable"
    fi
    
    # Check other container tools
    if command -v podman &> /dev/null; then
        log_success "✓ Podman available as Docker alternative"
    fi
}

# Enhanced AI tools setup
setup_ai_tools() {
    log_info "Setting up AI assistant tools..."
    
    # Check for API keys
    if [ -n "$ANTHROPIC_API_KEY" ]; then
        log_success "✓ Anthropic API key configured"
    else
        log_warning "ANTHROPIC_API_KEY not set - Claude may not work"
    fi
    
    if [ -n "$OPENAI_API_KEY" ]; then
        log_success "✓ OpenAI API key configured"
    else
        log_warning "OPENAI_API_KEY not set - OpenAI tools may not work"
    fi
    
    if [ -n "$GOOGLE_API_KEY" ]; then
        log_success "✓ Google API key configured"
    else
        log_warning "GOOGLE_API_KEY not set - Gemini may not work"
    fi
    
    # Configure Aider if available
    if command -v aider &> /dev/null; then
        log_success "✓ Aider configured and ready"
        
        # Create aider config directory
        mkdir -p /home/user/.config/aider
        
        # Basic aider configuration
        cat > /home/user/.config/aider/config.yml << 'EOF'
# Aider configuration for Claude Squad development container
editor: vim
git: true
pretty: true
stream: true
EOF
    fi
}

# Enhanced workspace setup
setup_workspace() {
    log_info "Setting up development workspace..."
    
    # Ensure workspace directory exists and is writable
    if [ ! -d "$WORKSPACE_DIR" ]; then
        mkdir -p "$WORKSPACE_DIR"
    fi
    
    # Create comprehensive development directory structure
    mkdir -p "$WORKSPACE_DIR"/{projects,tmp,logs,docs,scripts,config}
    
    # Create development-specific subdirectories
    mkdir -p "$WORKSPACE_DIR"/projects/{frontend,backend,fullstack,ml,data,mobile}
    mkdir -p "$WORKSPACE_DIR"/tmp/{downloads,builds,cache}
    mkdir -p "$WORKSPACE_DIR"/logs/{development,testing,deployment}
    
    # Set up enhanced tmux configuration for development
    cat > /home/user/.tmux.conf << 'EOF'
# Claude Squad Development tmux configuration
set -g default-terminal "screen-256color"
set -g mouse on
set -g history-limit 50000

# Status bar with development info
set -g status-bg colour234
set -g status-fg colour137
set -g status-left-length 50
set -g status-right-length 50
set -g status-left '#[fg=colour233,bg=colour241,bold] #S #[fg=colour241,bg=colour235,nobold] '
set -g status-right '#[fg=colour233,bg=colour241,bold] %Y-%m-%d %H:%M #[fg=colour233,bg=colour245,bold] DEV '

# Window status
setw -g window-status-current-format '#[fg=colour81,bg=colour238,bold] #I#[fg=colour250]:#[fg=colour255]#W#[fg=colour50]#F '
setw -g window-status-format '#[fg=colour138,bg=colour235] #I#[fg=colour250]:#[fg=colour250]#W#[fg=colour244]#F '

# Development key bindings
bind-key r source-file ~/.tmux.conf \; display-message "Config reloaded!"
bind-key | split-window -h
bind-key - split-window -v

# Pane navigation
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R
EOF
    
    # Set up vim configuration for development
    cat > /home/user/.vimrc << 'EOF'
" Claude Squad Development vim configuration
set number
set relativenumber
set autoindent
set smartindent
set tabstop=4
set shiftwidth=4
set expandtab
set hlsearch
set incsearch
set ignorecase
set smartcase
syntax on
set background=dark
set ruler
set showcmd
set wildmenu
set scrolloff=5
set encoding=utf-8

" Development key mappings
nnoremap <F5> :!clear && make<CR>
nnoremap <F6> :!clear && npm test<CR>
nnoremap <F7> :!clear && python3 %<CR>
nnoremap <F8> :!clear && go run %<CR>
EOF
    
    log_success "Development workspace setup complete"
}

# Print enhanced development banner
print_dev_banner() {
    echo ""
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}                        ${GREEN}Claude Squad Development Container${NC}                    ${PURPLE}║${NC}"
    echo -e "${PURPLE}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC} Workspace: ${YELLOW}$WORKSPACE_DIR${NC}                                                    ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC} User: ${YELLOW}$(whoami)${NC} | Shell: ${YELLOW}$SHELL${NC}                                                 ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC} Default Program: ${YELLOW}${CS_DEFAULT_PROGRAM:-claude}${NC}                                                ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}                                                                              ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC} ${CYAN}AI Assistant Tools:${NC}                                                        ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}   • ${GREEN}claude-squad${NC} - Multi-agent TUI manager                              ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}   • ${GREEN}claude${NC} - Claude CLI (if configured)                                ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}   • ${GREEN}aider${NC} - AI pair programming assistant                              ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}                                                                              ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC} ${CYAN}Development Languages:${NC}                                                    ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}   • ${GREEN}Node.js${NC} + npm/yarn/pnpm | ${GREEN}Python${NC} + pip/poetry/uv | ${GREEN}Go${NC} + modules      ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}   • ${GREEN}Rust${NC} + cargo | ${GREEN}Java${NC} + maven/gradle | ${GREEN}Ruby${NC} + bundler | ${GREEN}PHP${NC} + composer ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}                                                                              ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC} ${CYAN}Container Tools:${NC} docker, podman | ${CYAN}Version Control:${NC} git, gh              ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC} ${CYAN}Databases:${NC} sqlite3, psql, mysql, redis | ${CYAN}Editors:${NC} vim, nano, emacs    ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Development Quick Start:${NC}"
    echo -e "  ${GREEN}claude-squad${NC}           - Start multi-agent TUI"
    echo -e "  ${GREEN}aider${NC}                  - Start AI pair programming"
    echo -e "  ${GREEN}cd /workspace/projects${NC} - Navigate to project directory"
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
    log_info "Starting Claude Squad development container initialization..."
    
    setup_git
    setup_ssh
    setup_github_auth
    verify_dev_tools
    check_docker
    setup_ai_tools
    setup_workspace
    
    print_dev_banner
    
    log_success "Development container initialization complete!"
    log_info "Ready for AI-powered development workflows 🚀"
    
    # Execute the command passed to the container
    if [ $# -eq 0 ]; then
        log_info "No command specified, starting interactive development shell"
        exec /bin/bash
    else
        log_info "Executing command: $*"
        exec "$@"
    fi
}

# Run main function with all arguments
main "$@"
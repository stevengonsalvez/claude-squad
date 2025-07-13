# ABOUTME: Multi-stage Dockerfile for Claude Squad - builds Go binary and creates runtime container with AI assistant tools
# Supports Docker-in-Docker and full development environment for AI coding assistants

# Build stage
FROM golang:1.23-alpine AS builder

WORKDIR /build

# Copy go mod files first for better layer caching
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o claude-squad .

# Runtime stage
FROM ubuntu:22.04

# Install system dependencies and tools
RUN apt-get update && apt-get install -y \
    # Core system tools
    git \
    curl \
    wget \
    ca-certificates \
    gnupg \
    lsb-release \
    build-essential \
    software-properties-common \
    # tmux is essential for claude-squad
    tmux \
    # SSH client for git operations
    openssh-client \
    # Text editors
    vim \
    nano \
    # Process management
    htop \
    procps \
    # Network tools
    netcat-openbsd \
    # Clean up
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CLI for Docker-in-Docker support
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js (latest LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g yarn pnpm \
    && rm -rf /var/lib/apt/lists/*

# Install Python 3 and pip
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Install uv (fast Python package manager)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.cargo/bin:$PATH"

# Install Claude CLI
RUN curl -fsSL https://claude.ai/claude.deb -o claude.deb \
    || echo "Claude CLI not available via deb, will need manual installation"

# Install Aider
RUN pip3 install aider-chat

# Create non-root user
RUN groupadd --gid 1000 user \
    && useradd --uid 1000 --gid user --shell /bin/bash --create-home user

# Add user to docker group for Docker socket access
RUN groupadd docker || true \
    && usermod -aG docker user

# Set up workspace directory
RUN mkdir -p /workspace \
    && chown -R user:user /workspace

# Copy claude-squad binary from builder
COPY --from=builder /build/claude-squad /usr/local/bin/claude-squad
RUN chmod +x /usr/local/bin/claude-squad

# Copy entrypoint script
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Switch to non-root user
USER user
WORKDIR /workspace

# Set up user environment
RUN mkdir -p /home/user/.config /home/user/.local/bin /home/user/.ssh

# Environment variables
ENV HOME=/home/user
ENV USER=user
ENV SHELL=/bin/bash
ENV WORKSPACE_DIR=/workspace
ENV CS_DEFAULT_PROGRAM=claude

# Expose common development ports
EXPOSE 3000-9000

# Default entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Default command runs claude-squad
CMD ["claude-squad"]
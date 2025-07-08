# ABOUTME: Dockerfile for running Claude Code in a container
# Provides a containerized environment with claude pre-installed

FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    python3 \
    python3-pip \
    openssh-client \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js (required for claude)
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y nodejs

# Install claude globally
RUN npm install -g @anthropics/claude

# Create workspace directory
RUN mkdir -p /workspace

# Set working directory
WORKDIR /workspace

# Set up git config (will be overridden by user's config)
RUN git config --global user.email "claude@example.com" && \
    git config --global user.name "Claude"

# Set terminal environment
ENV TERM=xterm-256color

# Entry point is claude
ENTRYPOINT ["claude"]
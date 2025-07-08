# ABOUTME: Dockerfile for running Gemini CLI in a container
# Provides a containerized environment with gemini pre-installed

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
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install Go (needed for gemini CLI)
RUN wget -O go.tar.gz https://go.dev/dl/go1.21.0.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go.tar.gz && \
    rm go.tar.gz

# Add Go to PATH
ENV PATH="/usr/local/go/bin:${PATH}"

# Install gemini CLI
RUN go install github.com/google-gemini/gemini-cli@latest

# Add Go bin to PATH
ENV PATH="/root/go/bin:${PATH}"

# Create workspace directory
RUN mkdir -p /workspace

# Set working directory
WORKDIR /workspace

# Set up git config (will be overridden by user's config)
RUN git config --global user.email "gemini@example.com" && \
    git config --global user.name "Gemini"

# Set terminal environment
ENV TERM=xterm-256color

# Entry point is gemini
ENTRYPOINT ["gemini-cli"]
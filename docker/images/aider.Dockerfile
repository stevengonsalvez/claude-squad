# ABOUTME: Dockerfile for running Aider in a container
# Provides a containerized environment with aider pre-installed

FROM python:3.11-slim

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    openssh-client \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install aider
RUN pip install aider-chat

# Create workspace directory
RUN mkdir -p /workspace

# Set working directory
WORKDIR /workspace

# Set up git config (will be overridden by user's config)
RUN git config --global user.email "aider@example.com" && \
    git config --global user.name "Aider"

# Set terminal environment
ENV TERM=xterm-256color

# Entry point is aider
ENTRYPOINT ["aider"]
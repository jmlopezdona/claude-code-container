# Python Dockerfile for Claude Code
# Extends the base Claude Code image with Python development tools

FROM claude-code-base:latest

# Switch back to root to install packages
USER root

# Install Python and development tools
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Create python alias and upgrade pip
RUN ln -sf /usr/bin/python3 /usr/bin/python \
    && python -m pip install --upgrade pip

# Switch back to non-root user
USER node

# Working directory and entrypoint are inherited from base image
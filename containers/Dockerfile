# Base Dockerfile for Claude Code
# Inherits from OpenAI Codex Universal image

FROM ghcr.io/openai/codex-universal:latest

ARG GIT_USER_NAME_ARG="Claude Docker User"
ARG GIT_USER_EMAIL_ARG="claude-docker@example.com"

# Environment variables that will be used by scripts
# Note: These are generic values. For real commits, specify your own values
ENV GIT_USER_NAME=${GIT_USER_NAME_ARG}
ENV GIT_USER_EMAIL=${GIT_USER_EMAIL_ARG}
ENV CLAUDE_YOLO_MODE="false"
ENV GIT_REPO_URL=""
# Git host domain (e.g: github.com) - Required if using SSH
ENV GIT_HOST_DOMAIN=""
# CODEX_ENV_* variables can be set during docker run or in docker-compose to select language versions
# e.g., CODEX_ENV_PYTHON_VERSION=3.11

# The codex-universal image already includes:
# - git, curl, bash, jq, ca-certificates, sudo, openssh-client
# - Node.js (multiple versions selectable via CODEX_ENV_NODE_VERSION, defaults to a recent one)
# - GitHub CLI (gh)
# - Python (multiple versions selectable via CODEX_ENV_PYTHON_VERSION)
# - And other languages like Go, Rust, Swift, Java, etc.

# Install claude-code CLI globally using the Node.js provided by codex-universal
# The codex-universal entrypoint likely sets up PATH, so npm should be available.
# We run as root to install global npm packages.
USER root
RUN npm install -g @anthropic-ai/claude-code

# Create a non-root user 'node' (UID 1000) for compatibility and security
# This matches the previous setup and is good for volume permissions on macOS with Colima.
# The codex-universal image runs as root by default.
RUN useradd -m -s /bin/bash -u 1000 node \
    && echo "node ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create necessary directories and set permissions for the 'node' user
# /workspace is the default workdir in codex-universal
RUN mkdir -p /home/node/.ssh \
    && mkdir -p /tmp/ssh_key \
    && chown -R node:node /home/node \
    && chown -R node:node /tmp/ssh_key \
    && chown -R node:node /workspace

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Switch to non-root user 'node'
USER node

# WORKDIR is already /workspace in codex-universal, but setting it explicitly for clarity
WORKDIR /workspace

# The entrypoint.sh from this project will handle Claude Code specific setup
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# Empty CMD so that by default 'claude' runs interactively if no args are passed
CMD []
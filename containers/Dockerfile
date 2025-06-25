# Base Dockerfile for Claude Code

FROM node:18-slim

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

RUN apt-get update && apt-get install -y \
    git \
    curl \
    bash \
    jq \
    ca-certificates \
    sudo \
    openssh-client

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code

# Use existing 'node' user (UID/GID 1000) compatible with Colima on macOS
# Create necessary directories with correct permissions
RUN mkdir -p /workspace \
    && mkdir -p /home/node/.ssh \
    && mkdir -p /tmp/ssh_key \
    && chown -R node:node /workspace \
    && chown -R node:node /home/node \
    && chown -R node:node /tmp/ssh_key

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Switch to non-root user
USER node

WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# Empty CMD so that by default 'claude' runs interactively if no args are passed
CMD []
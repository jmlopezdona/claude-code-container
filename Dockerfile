# Dockerfile Base para Claude Code

FROM node:18-slim

ARG GIT_USER_NAME_ARG="Claude Docker User"
ARG GIT_USER_EMAIL_ARG="claude-docker@example.com"

# Variables de entorno que usarán los scripts
ENV GIT_USER_NAME=${GIT_USER_NAME_ARG}
ENV GIT_USER_EMAIL=${GIT_USER_EMAIL_ARG}
ENV CLAUDE_YOLO_MODE="false"
ENV GIT_REPO_URL=""
# Dominio del host git (ej: github.com) - Obligatorio si se usa SSH
ENV GIT_HOST_DOMAIN=""

RUN apt-get update && apt-get install -y \
    git \
    curl \
    bash \
    jq \
    ca-certificates \
    sudo \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code

RUN mkdir -p /workspace \
    && mkdir -p /root/.ssh \
    && mkdir -p /tmp/ssh_key

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# CMD vacío para que por defecto se ejecute 'claude' interactivamente si no se pasan args
CMD []
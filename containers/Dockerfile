# Base Dockerfile for Claude Code
# This Dockerfile consolidates the features from openai/codex-universal and adds claude-code specifics.

FROM ubuntu:24.04

ENV LANG="C.UTF-8"
ENV HOME=/root
ENV DEBIAN_FRONTEND=noninteractive

### BASE SYSTEM PACKAGES ###
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        binutils \
        sudo \
        build-essential \
        bzr \
        curl \
        default-libmysqlclient-dev \
        dnsutils \
        gettext \
        git \
        git-lfs \
        gnupg2 \
        inotify-tools \
        iputils-ping \
        jq \
        libbz2-dev \
        libc6 \
        libc6-dev \
        libcurl4-openssl-dev \
        libdb-dev \
        libedit2 \
        libffi-dev \
        libgcc-13-dev \
        libgcc1 \
        libgdbm-compat-dev \
        libgdbm-dev \
        libgdiplus \
        libgssapi-krb5-2 \
        liblzma-dev \
        libncurses-dev \
        libncursesw5-dev \
        libnss3-dev \
        libpq-dev \
        libpsl-dev \
        libpython3-dev \
        libreadline-dev \
        libsqlite3-dev \
        libssl-dev \
        libstdc++-13-dev \
        libunwind8 \
        libuuid1 \
        libxml2-dev \
        libz3-dev \
        make \
        moreutils \
        netcat-openbsd \
        openssh-client \
        pkg-config \
        protobuf-compiler \
        python3-pip \
        ripgrep \
        rsync \
        software-properties-common \
        sqlite3 \
        swig3.0 \
        tk-dev \
        tzdata \
        unixodbc-dev \
        unzip \
        uuid-dev \
        xz-utils \
        zip \
        zlib1g \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

### PYTHON ###
ARG PYENV_VERSION=v2.5.5
ARG PYTHON_VERSION=3.11.12

ENV PYENV_ROOT=/root/.pyenv
ENV PATH=$PYENV_ROOT/bin:$PATH
RUN git -c advice.detachedHead=0 clone --branch ${PYENV_VERSION} --depth 1 https://github.com/pyenv/pyenv.git "${PYENV_ROOT}" \
    && echo 'export PYENV_ROOT="$HOME/.pyenv"' >> /etc/profile \
    && echo 'export PATH="$PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH"' >> /etc/profile \
    && echo 'eval "$(pyenv init - bash)"' >> /etc/profile \
    && cd ${PYENV_ROOT} && src/configure && make -C src \
    && pyenv install 3.10.14 \
    && pyenv install 3.11.9 \
    && pyenv install 3.12.4 \
    && pyenv install 3.13-dev \
    && pyenv global ${PYTHON_VERSION}

ENV PIPX_BIN_DIR=/root/.local/bin
ENV PATH=$PIPX_BIN_DIR:$PATH
RUN apt-get update && apt-get install -y pipx \
    && rm -rf /var/lib/apt/lists/* \
    && pipx install poetry uv \
    && for pyv_dir in $(ls ${PYENV_ROOT}/versions/); do \
        echo "Installing common packages for Python in $pyv_dir"; \
        ${PYENV_ROOT}/versions/$pyv_dir/bin/pip install --no-cache-dir --upgrade pip ruff black mypy pyright isort; \
    done
ENV UV_NO_PROGRESS=1

### NODE ###
ARG NVM_VERSION=v0.40.2
ARG NODE_VERSION=20

ENV NVM_DIR=/root/.nvm
ENV COREPACK_DEFAULT_TO_LATEST=0
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0
ENV COREPACK_ENABLE_AUTO_PIN=0
ENV COREPACK_ENABLE_STRICT=0
RUN git -c advice.detachedHead=0 clone --branch ${NVM_VERSION} --depth 1 https://github.com/nvm-sh/nvm.git "${NVM_DIR}" \
    && echo 'source $NVM_DIR/nvm.sh' >> /etc/profile \
    && echo "prettier\neslint\ntypescript" > $NVM_DIR/default-packages \
    && . $NVM_DIR/nvm.sh \
    && nvm install 18 \
    && nvm install 20 \
    && nvm install 22 \
    && nvm alias default $NODE_VERSION \
    && corepack enable \
    && corepack install -g yarn pnpm npm

### BUN ###
ARG BUN_VERSION=1.2.14

ENV BUN_INSTALL=/root/.bun
ENV PATH="$BUN_INSTALL/bin:$PATH"
RUN mkdir -p "$BUN_INSTALL/bin" \
    && curl -L --fail "https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-linux-x64-baseline.zip" \
        -o /tmp/bun.zip \
    && unzip -q /tmp/bun.zip -d "$BUN_INSTALL/bin" \
    && mv "$BUN_INSTALL/bin/bun-linux-x64-baseline/bun" "$BUN_INSTALL/bin/bun" \
    && chmod +x "$BUN_INSTALL/bin/bun" \
    && rm -rf "$BUN_INSTALL/bin/bun-linux-x64-baseline" /tmp/bun.zip \
    && echo 'export BUN_INSTALL=/root/.bun' >> /etc/profile \
    && echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> /etc/profile

### JAVA ###
ARG JAVA_VERSION=21
ARG GRADLE_VERSION=8.14
ARG GRADLE_DOWNLOAD_SHA256=61ad310d3c7d3e5da131b76bbf22b5a4c0786e9d892dae8c1658d4b484de3caa

ENV GRADLE_HOME=/opt/gradle
RUN apt-get update && apt-get install -y --no-install-recommends \
        openjdk-${JAVA_VERSION}-jdk \
    && rm -rf /var/lib/apt/lists/* \
    && curl -LO "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" \
    && echo "${GRADLE_DOWNLOAD_SHA256} *gradle-${GRADLE_VERSION}-bin.zip" | sha256sum --check - \
    && unzip gradle-${GRADLE_VERSION}-bin.zip \
    && rm gradle-${GRADLE_VERSION}-bin.zip \
    && mv "gradle-${GRADLE_VERSION}" "${GRADLE_HOME}/" \
    && ln -s "${GRADLE_HOME}/bin/gradle" /usr/bin/gradle

### SWIFT ###
ARG SWIFT_VERSION=5.10

# Install Swift dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    binutils \
    git \
    gnupg2 \
    libc6-dev \
    libcurl4-openssl-dev \
    libedit2 \
    libgcc-12-dev \
    libpython3-dev \
    libsqlite3-0 \
    libstdc++-12-dev \
    libxml2-dev \
    libz3-dev \
    pkg-config \
    tzdata \
    unzip \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Install swiftly and Swift
RUN mkdir /tmp/swiftly \
    && cd /tmp/swiftly \
    && SWIFTLY_ARCH=$(uname -m) \
    && if [ "$SWIFTLY_ARCH" = "x86_64" ]; then SWIFTLY_ARCH_NAME="x86_64"; else SWIFTLY_ARCH_NAME=$SWIFTLY_ARCH; fi \
    && curl -L https://github.com/swift-server/swiftly/releases/download/v1.0.0-alpha.5/swiftly-${SWIFTLY_ARCH_NAME}.tar.gz -o swiftly.tar.gz \
    && tar zxf swiftly.tar.gz \
    && ./swiftly-${SWIFTLY_ARCH_NAME}/swiftly init --quiet-shell-followup -y \
    && echo '. ~/.local/share/swiftly/env.sh' >> /etc/profile \
    && bash -lc "swiftly install --use ${SWIFT_VERSION}" \
    && rm -rf /tmp/swiftly

### RUBY ###
RUN apt-get update && apt-get install -y --no-install-recommends \
        ruby-full \
    && rm -rf /var/lib/apt/lists/* \
    && gem install bundler rails

### RUST ###
ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
ENV PATH=/usr/local/cargo/bin:$PATH
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
        sh -s -- -y --default-toolchain stable --profile minimal --no-modify-path \
    && rustup show

### GO ###
ARG GO_VERSION=1.22.5
ARG GO_DOWNLOAD_SHA256_AMD64=c1f08949970d9c16384c14a80ca99940f6a41468c0a13411689ba0a46acd28f5
ARG GO_DOWNLOAD_SHA256_ARM64=f856c817f8bbc68921a178108757a602182a4a875573265309074d7604970033 # Updated for 1.22.5 arm64

ENV PATH=/usr/local/go/bin:$HOME/go/bin:$PATH
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then \
        GO_DOWNLOAD_SHA256=$GO_DOWNLOAD_SHA256_AMD64; \
        GO_ARCH_NAME="amd64"; \
    elif [ "$ARCH" = "arm64" ]; then \
        GO_DOWNLOAD_SHA256=$GO_DOWNLOAD_SHA256_ARM64; \
        GO_ARCH_NAME="arm64"; \
    else \
        echo "Unsupported architecture: $ARCH"; exit 1; \
    fi && \
    mkdir /tmp/go \
    && cd /tmp/go \
    && curl -LO https://dl.google.com/go/go${GO_VERSION}.linux-${GO_ARCH_NAME}.tar.gz \
    && echo "${GO_DOWNLOAD_SHA256} *go${GO_VERSION}.linux-${GO_ARCH_NAME}.tar.gz" | sha256sum --check - \
    && tar -C /usr/local -xzf go${GO_VERSION}.linux-${GO_ARCH_NAME}.tar.gz \
    && rm -rf /tmp/go

### BAZEL ###
RUN BAZEL_ARCH=$(dpkg --print-architecture) && \
    if [ "$BAZEL_ARCH" = "amd64" ]; then BAZEL_ARCH_NAME="amd64"; elif [ "$BAZEL_ARCH" = "arm64" ]; then BAZEL_ARCH_NAME="arm64"; else echo "Unsupported Bazel arch: $BAZEL_ARCH"; exit 1; fi && \
    curl -L --fail https://github.com/bazelbuild/bazelisk/releases/download/v1.20.0/bazelisk-linux-${BAZEL_ARCH_NAME} -o /usr/local/bin/bazelisk \
    && chmod +x /usr/local/bin/bazelisk \
    && ln -s /usr/local/bin/bazelisk /usr/local/bin/bazel

### LLVM / CLANG ###
RUN apt-get update && apt-get install -y --no-install-recommends \
        lsb-release \
        wget \
        software-properties-common \
        gnupg \
    && rm -rf /var/lib/apt/lists/* \
    && wget https://apt.llvm.org/llvm.sh -O /tmp/llvm.sh \
    && chmod +x /tmp/llvm.sh \
    && /tmp/llvm.sh 18 all \
    && rm /tmp/llvm.sh

### CLAUDE-CODE SPECIFIC SETUP ###

ARG GIT_USER_NAME_ARG="Claude Docker User"
ARG GIT_USER_EMAIL_ARG="claude-docker@example.com"

# Environment variables that will be used by scripts
ENV GIT_USER_NAME=${GIT_USER_NAME_ARG}
ENV GIT_USER_EMAIL=${GIT_USER_EMAIL_ARG}
ENV CLAUDE_YOLO_MODE="false"
ENV GIT_REPO_URL=""
# Git host domain (e.g: github.com) - Required if using SSH
ENV GIT_HOST_DOMAIN=""

# APP_LANG_* variables for language version selection by setup_claude.sh
ENV APP_LANG_PYTHON_VERSION=""
ENV APP_LANG_NODE_VERSION=""
ENV APP_LANG_RUST_VERSION=""
ENV APP_LANG_GO_VERSION=""
ENV APP_LANG_SWIFT_VERSION=""

# Install claude-code CLI using the Node.js managed by NVM
# Run as root to install global npm packages.
# Ensure NVM is sourced for this RUN command
RUN . $NVM_DIR/nvm.sh && nvm use default && npm install -g @anthropic-ai/claude-code

# Create a non-root user 'node' (UID 1000) for compatibility and security
RUN useradd -m -s /bin/bash -u 1000 node \
    && echo "node ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create necessary directories and set permissions for the 'node' user
RUN mkdir -p /home/node/.ssh \
    && mkdir -p /tmp/ssh_key \
    && mkdir -p /workspace \
    && chown -R node:node /home/node \
    && chown -R node:node /tmp/ssh_key \
    && chown -R node:node /workspace

# Copy setup and entrypoint scripts
COPY setup_claude.sh /opt/claude/setup_claude.sh
RUN chmod +x /opt/claude/setup_claude.sh

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Switch to non-root user 'node'
USER node
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD []

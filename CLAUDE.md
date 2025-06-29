# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **containerized development environment** for Claude Code, based on `ghcr.io/openai/codex-universal:latest`. It provides secure, isolated execution with full Git integration, multi-language support (Python, Node.js, Go, Rust, Swift, Java, etc.), and persistent configuration for Claude Code and other tools like `gh`. The project uses a single image strategy (`claude-code-base`).

## Core Architecture

### Single Image Strategy
- **`claude-code-base`**: The primary and only image, inherits from `ghcr.io/openai/codex-universal:latest`. It adds the Claude Code CLI and specific entrypoint logic for Git/SSH configuration. This image is multi-language by nature. Language versions are selected at runtime via `CODEX_ENV_*` environment variables.

### Key Technical Decisions
- **Leverage `codex-universal`**: Utilizes a feature-rich, multi-language base image maintained by OpenAI.
- **Language Versioning via Environment Variables**: Uses `CODEX_ENV_*` variables (e.g., `CODEX_ENV_PYTHON_VERSION`) to select language runtimes provided by `codex-universal`.
- **Non-root execution** (`node` user, UID/GID 1000) for macOS Colima compatibility, security, and proper YOLO mode operation.
- **Persistent configuration** via volume mounting (`~/.claude-code-container` on host maps to `/home/node` in container) for Claude Code, Git, `gh` CLI, etc.
- **Environment variable configuration** (`.env` file) for flexible and secure setup.
- **Simplified Build Process**: Single image `claude-code-base` simplifies building and maintenance.

## Essential Commands

### Building The Image
The `build.sh` script now only builds `claude-code-base`.
```bash
# Build claude-code-base:latest
./build.sh

# Build with a custom tag
./build.sh -t v1.0.0

# Using Docker Compose (builds the 'claude-code' service)
docker-compose build
```

### Running Containers
Use the `claude-code` service defined in `docker-compose.yml`.
```bash
# Interactive mode (most common)
# Define CODEX_ENV_PYTHON_VERSION="3.11" (or other languages) in .env
docker-compose run --rm claude-code

# Autonomous mode with prompt
# Set CODEX_ENV_GO_VERSION in .env if working with Go, for example
docker-compose run --rm claude-code "Analyze this Go codebase"

# With custom workspace and specific Python version
WORKSPACE_DIR=/path/to/project CODEX_ENV_PYTHON_VERSION=3.12 docker-compose run --rm claude-code
```

### Development Setup
```bash
# First time setup
cp .env.example .env
# Edit .env with your values (Git config, GH_TOKEN, desired CODEX_ENV_* versions etc.)
mkdir -p ~/.claude-code-container # For persistent config

# Verify GitHub CLI authentication (if GH_TOKEN is set in .env)
docker-compose run --rm claude-code bash -c "gh auth status"

# Check Python version (if CODEX_ENV_PYTHON_VERSION is set in .env)
docker-compose run --rm claude-code python --version
```

## Configuration System

### Key Environment Variables (.env)
- `GIT_USER_NAME` / `GIT_USER_EMAIL`: Required for Git commits.
- `GIT_HOST_DOMAIN`: Git server domain (e.g., `github.com`) for SSH and `gh`.
- `CLAUDE_CONFIG_DIR`: Host directory for persistent configuration (default: `~/.claude-code-container`).
- `GH_TOKEN`: Optional, GitHub Personal Access Token for `gh` CLI.
- `CLAUDE_YOLO_MODE=true`: Optional, to enable dangerous operations.
- `GIT_REPO_URL`: Optional, to auto-clone a repository.
- `CODEX_ENV_PYTHON_VERSION`: e.g., "3.11"
- `CODEX_ENV_NODE_VERSION`: e.g., "20"
- `CODEX_ENV_GO_VERSION`: e.g., "1.22"
- `CODEX_ENV_RUST_VERSION`: e.g., "1.87.0"
- `CODEX_ENV_SWIFT_VERSION`: e.g., "6.1"
*(Refer to `codex-universal` docs for all supported versions and tools)*

## Container Startup Process (`entrypoint.sh`)

The `codex-universal` base image has its own entrypoint (`/entrypoint.sh`) and setup script (`/opt/codex/bin/setup-universal.sh`) that first configures the selected language environments based on `CODEX_ENV_*` variables.
After that, this project's `/usr/local/bin/entrypoint.sh` runs and performs:

1. **SSH Configuration**: Copies mounted keys, configures `known_hosts`.
2. **GitHub CLI Authentication**: Auto-login with `GH_TOKEN` if provided.
3. **Git Global Setup**: Configures user identity and safe directories.
4. **Workspace Preparation**: Auto-clones repo if `GIT_REPO_URL` is set and workspace is empty.
5. **Claude Code Execution**: Applies YOLO mode and executes `claude` with passed arguments.

## Volume Architecture

### Critical Volume Mounts (defined in `docker-compose.yml` for the `claude-code` service)
- `${CLAUDE_CONFIG_DIR}:/home/node`: **Persistent configuration** for Claude, Git, gh, shell history, etc.
- `${WORKSPACE_DIR}:/workspace`: Project workspace.
- `${SSH_KEY_DIR}:/tmp/ssh_key:ro`: SSH keys (read-only).

### Configuration Persistence
The `/home/node` volume mount is crucial. It persists:
- Claude Code credentials (`.claude/`, `.claude.json`).
- GitHub CLI auth (`.config/gh/`).
- Git global config (`.gitconfig`).
- Shell history (`.bash_history`, etc.).
- Potentially other tool configurations stored in `/home/node`.

## Working with Different Languages

- Set the appropriate `CODEX_ENV_<LANGUAGE>_VERSION` in your `.env` file.
- Example for a Python 3.11 project:
  ```dotenv
  # in .env
  CODEX_ENV_PYTHON_VERSION=3.11
  ```
- Example for a Go 1.22 project:
  ```dotenv
  # in .env
  CODEX_ENV_GO_VERSION=1.22
  ```
- The `codex-universal` image comes with many tools pre-installed (e.g., `poetry`, `ruff` for Python; `yarn`, `pnpm` for Node).

## Troubleshooting Common Issues

### Claude Code Requesting Login Every Time
**Problem**: Missing or misconfigured persistent configuration volume.
**Solution**: Ensure `CLAUDE_CONFIG_DIR` is correctly set in `.env` and the volume mount in `docker-compose.yml` (`~/.claude-code-container:/home/node`) is active for the `claude-code` service. Ensure `~/.claude-code-container` exists on the host.

### Incorrect Language Version
**Problem**: Desired language version is not active.
**Solution**: Verify `CODEX_ENV_<LANGUAGE>_VERSION` is correctly set in `.env` (or passed via `-e` for `docker run`). Check `codex-universal` documentation for supported versions. Restart container (e.g. `docker-compose down && docker-compose run --rm claude-code`) if `.env` was changed.

### Git Operations Failing
**Problem**: Missing or misconfigured Git identity.
**Solution**: Verify `GIT_USER_NAME` and `GIT_USER_EMAIL` in `.env`.

### SSH Authentication Issues
**Problem**: Missing `GIT_HOST_DOMAIN` or incorrect SSH key path.
**Solution**: Set `GIT_HOST_DOMAIN` (e.g., `github.com`) and verify `SSH_KEY_DIR` in `.env`. Ensure the key file (e.g., `id_rsa`) is present in the mounted SSH directory.

## File Structure Context

- `containers/Dockerfile`: Defines the single `claude-code-base` image, inheriting from `ghcr.io/openai/codex-universal:latest`.
- `containers/entrypoint.sh`: Custom entrypoint for Claude Code setup (SSH, Git, gh, claude execution).
- `docker-compose.yml`: Service orchestration for the single `claude-code` service. Defines volumes and environment variables (including `CODEX_ENV_*`).
- `build.sh`: Simplified script for building the `claude-code-base` image.
- `.env.example`: Template for `.env` file, includes `CODEX_ENV_*` variables.
- `README.md`: Main user documentation.

## Development Workflow Integration

### Typical Usage Patterns
1. **Multi-Language Projects**: Use the `claude-code` service and set `CODEX_ENV_*` variables in `.env` as needed for the specific language/version.
2. **Local Development**: Mount existing project directory into `/workspace`.
3. **Repository Analysis**: Use `GIT_REPO_URL` for automatic cloning.
4. **Interactive Sessions**: Use `docker-compose run --rm claude-code`.
5. **Autonomous Tasks**: Pass prompts directly to `docker-compose run --rm claude-code "prompt"`.
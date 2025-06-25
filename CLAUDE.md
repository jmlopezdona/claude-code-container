# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **containerized development environment** for Claude Code that provides secure, isolated execution with full Git integration and persistent configuration. The project uses a multi-image Docker architecture with environment-based configuration.

## Core Architecture

### Multi-Image Strategy
- **Base Image** (`claude-code-base`): Core environment with Node.js + Claude Code CLI + GitHub CLI
- **Python Image** (`claude-code-python`): Extends base with Python 3.11 + development tools
- **Layered Dependencies**: Python image builds on base image

### Key Technical Decisions
- **Non-root execution** (UID/GID 1000) for macOS Colima compatibility and security
- **Persistent configuration** via volume mounting to avoid repeated Claude Code login
- **Environment variable configuration** for flexible, secure setup
- **Multi-host Git support** for enterprise environments

## Essential Commands

### Building Images
```bash
# Build all images (recommended)
./build.sh

# Build specific image with custom tag
./build.sh -b python -t dev

# Using Docker Compose
docker-compose build
docker-compose build claude-python
```

### Running Containers
```bash
# Interactive mode (most common)
docker-compose run --rm claude-python

# Autonomous mode with prompt
docker-compose run --rm claude-python "Analyze this codebase"

# With custom workspace
WORKSPACE_DIR=/path/to/project docker-compose run --rm claude-python
```

### Development Setup
```bash
# First time setup
cp .env.example .env
# Edit .env with your values
mkdir -p ~/.claude-code-container

# Verify GitHub CLI authentication
docker-compose run --rm claude-python bash -c "gh auth status"
```

## Configuration System

### Required Environment Variables (.env)
- `GIT_USER_NAME` / `GIT_USER_EMAIL` - Required for Git commits
- `GIT_HOST_DOMAIN` - Git server domain (e.g., github.com)
- `CLAUDE_CONFIG_DIR` - Persistent configuration directory (default: ~/.claude-code-container)

### Optional Variables
- `GH_TOKEN` - GitHub Personal Access Token (auto-authenticates GitHub CLI)
- `CLAUDE_YOLO_MODE=true` - Enable dangerous operations
- `GIT_REPO_URL` - Auto-clone repository if workspace empty
- `WORKSPACE_DIR` - Local directory to mount (default: ./workspace)
- `SSH_KEY_DIR` - SSH keys location (default: ~/.ssh)

## Container Startup Process (entrypoint.sh)

The startup sequence performs critical initialization:

1. **SSH Configuration** - Copies mounted keys, configures known_hosts
2. **GitHub CLI Authentication** - Auto-login with GH_TOKEN if provided  
3. **Git Global Setup** - Configures user identity and safe directories
4. **Workspace Preparation** - Auto-clones repo if specified and workspace empty
5. **Claude Code Execution** - Applies YOLO mode and executes with arguments

## Volume Architecture

### Critical Volume Mounts
- `${CLAUDE_CONFIG_DIR}:/home/node` - **Persistent Claude Code configuration**
- `${WORKSPACE_DIR}:/workspace` - Project workspace
- `${SSH_KEY_DIR}:/tmp/ssh_key:ro` - SSH keys (read-only)

### Configuration Persistence
The `/home/node` volume mount persists:
- Claude Code credentials (`.claude/`, `.claude.json`)
- GitHub CLI auth (`.config/gh/`)
- Git global config (`.gitconfig`)

## Working with Private Repositories

### SSH Setup Requirements
1. Mount SSH key directory to `/tmp/ssh_key:ro`
2. Set `GIT_HOST_DOMAIN` to your Git server
3. Ensure `GIT_USER_NAME` and `GIT_USER_EMAIL` are configured for commits

### GitHub CLI Integration
- Set `GH_TOKEN` in .env for automatic authentication
- Supports GitHub Enterprise via `GIT_HOST_DOMAIN`
- Auth state persists across container sessions

## Security Considerations

### Non-root Architecture
- Containers run as `node` user (UID/GID 1000)
- Enables YOLO mode while maintaining security
- Compatible with macOS Docker alternatives (Colima)

### Sensitive Data Handling
- `.env` file is gitignored
- SSH keys mounted read-only
- No secrets embedded in images
- Configuration stored on host filesystem

## Troubleshooting Common Issues

### Claude Code Requesting Login Every Time
**Problem**: Missing persistent configuration volume
**Solution**: Ensure `CLAUDE_CONFIG_DIR` volume mount exists in docker-compose.yml

### Git Operations Failing
**Problem**: Missing or misconfigured Git identity
**Solution**: Verify `GIT_USER_NAME` and `GIT_USER_EMAIL` in .env

### SSH Authentication Issues
**Problem**: Missing `GIT_HOST_DOMAIN` or incorrect SSH key path
**Solution**: Set `GIT_HOST_DOMAIN=github.com` and verify `SSH_KEY_DIR` path

### Permission Errors on macOS
**Problem**: Volume mount permission mismatch
**Solution**: Project uses UID/GID 1000 for Colima compatibility (no action needed)

## File Structure Context

- `containers/Dockerfile` - Base image definition
- `containers/python/Dockerfile` - Python variant 
- `containers/entrypoint.sh` - Container initialization logic
- `docker-compose.yml` - Service orchestration with volume mounts
- `build.sh` - Automated build script with dependency management
- `.env.example` - Configuration template with documentation

## Development Workflow Integration

### Typical Usage Patterns
1. **Local Development**: Mount existing project directory as workspace
2. **Repository Analysis**: Use `GIT_REPO_URL` for automatic cloning
3. **Interactive Sessions**: Use docker-compose for persistent configuration
4. **Autonomous Tasks**: Pass prompts directly to container for one-off operations

### YOLO Mode Considerations
- Only enable `CLAUDE_YOLO_MODE=true` for trusted operations
- Docker isolation provides safety layer
- Non-root execution limits potential damage
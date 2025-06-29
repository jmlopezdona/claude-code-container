# Claude Code Container (Self-Contained & Multi-Language)

This document describes how to build and use a Docker image to run Claude Code securely and configurably. The solution now builds a self-contained image based on `ubuntu:24.04`, integrating the multi-language capabilities previously inherited from `codex-universal`. This provides greater control over the environment. It allows working with Git repositories (public and private via SSH), mounting local workspaces, activating Claude Code's YOLO mode, and persisting Claude Code's initial configuration.

## 1. Purpose

The goal is to provide an isolated, reproducible, and multi-language environment for Claude Code that:
- Includes a comprehensive set of development tools (Python, Node.js, Go, Rust, Swift, Java, Ruby, Bun, Bazel, etc.), built directly into the image.
- Offers full control over the base image and installed dependencies.
- Protects the host system from potentially dangerous operations (especially in YOLO mode).
- Facilitates configuration for interacting with Git repositories.
- Allows choosing between a mounted local workspace or cloning a Git repository.
- **Persists Claude Code's initial configuration (login, API keys, editor preferences) between sessions.**

## 2. Prerequisites

- **Docker:** You must have Docker installed and running on your system.
- **SSH Key:** To interact with private Git repositories using SSH, an SSH private key is required.
- **Claude Code Subscription or Anthropic API KEY:** Required for Claude Code initial configuration.
- **Configuration Directory on Host:** An empty directory on your host system where Claude Code's persistent configuration will be saved. Example: `~/.claude-code-container`.

## 2.1. Environment Configuration

This project uses environment variables for configuration. Before using the containers:

1. **Copy the environment template:**
   ```bash
   cp .env.example .env
   ```

2. **Edit the `.env` file** with your actual values:
   ```bash
   nano .env  # or your preferred editor
   ```

3. **Key variables to configure (see `.env.example` for full list and details):**
   - `GIT_USER_NAME` and `GIT_USER_EMAIL`: Required for Git commits.
   - `GIT_HOST_DOMAIN`: Required for SSH authentication (e.g., github.com).
   - `WORKSPACE_DIR`: Local directory to mount as workspace (default: ./workspace).
   - `CLAUDE_CONFIG_DIR`: Directory for persistent Claude Code configuration (default: ~/.claude-code-container).
   - `SSH_KEY_DIR`: Directory containing SSH keys (default: ~/.ssh).
   - `CLAUDE_YOLO_MODE`: Set to `true` only if you want to enable dangerous operations.
   - `GIT_REPO_URL`: Optional, for automatic repository cloning.
   - `GH_TOKEN`: Optional, your GitHub Personal Access Token for `gh` CLI authentication.
   - `APP_LANG_PYTHON_VERSION`: Optional, specify Python version (e.g., "3.10.14", "3.11.9", "3.12.4").
   - `APP_LANG_NODE_VERSION`: Optional, specify Node.js version (e.g., "18", "20", "22").
   - (and similar `APP_LANG_*` for Go, Rust, Swift - see section 5 for details)

**Note:** The `.env` file is ignored by Git to protect your sensitive information.

## 3. Building the Docker Image

### 3.1. Core Changes & Single Image Strategy

The project now uses a single Docker image named `claude-code-base` (the service in `docker-compose.yml` is named `claude-code`). This image is built from `ubuntu:24.04` and includes multiple versions of Python, Node.js, Go, Rust, Swift, Java, Ruby, Bun, Bazel and common development tools, directly in its Dockerfile.

The `claude-code-base` image layers the Claude Code CLI and project-specific configurations. Language versions can be selected at runtime using `APP_LANG_*` environment variables.

### 3.2. Build Options

#### Option 1: Using the Build Script (Recommended)

The build script `./build.sh` builds the `claude-code-base` image. It no longer pulls a specific upstream base image like `codex-universal` as all dependencies are defined in the local Dockerfile.

```bash
# Build claude-code-base:latest
./build.sh

# Build claude-code-base with a custom tag
./build.sh -t v1.0.0

# Build with a custom image name and tag
./build.sh -n my-claude-app -t dev
```

#### Option 2: Using Docker Compose (Recommended for development)

The `docker-compose.yml` file now defines a single service, `claude-code`.

```bash
# Build the claude-code service (which builds the claude-code-base image)
docker-compose build claude-code
# or simply:
docker-compose build

# Run the service (requires .env file for GIT_USER_NAME, etc., and optionally APP_LANG_* vars)
docker-compose run --rm claude-code "My prompt for Claude"
# Example for a Python project (set APP_LANG_PYTHON_VERSION in .env or pass it)
# APP_LANG_PYTHON_VERSION=3.11.9 docker-compose run --rm claude-code "Analyze this Python code"
```

#### Option 3: Manual Docker Build

```bash
# The Dockerfile builds from ubuntu:24.04. Docker will pull it if not available locally.
# Build the claude-code-base image
docker build -t claude-code-base:latest containers/
```

## 4. Claude Code Configuration Persistence

Claude Code may require initial interactive configuration (login, API key, preferences). To avoid repeating this process with each container run, it's recommended to persist Claude Code's configuration directory using a Docker volume.

Based on analysis, Claude Code saves its configuration in multiple files within the `/home/node` directory in the container (the user inside the container is `node`, UID 1000), including `/home/node/.claude/` and `/home/node/.claude.json`.

**Procedure:**

1.  **Create a directory on your host system** to store this configuration (if you haven't already). This directory should be empty the first time or contain previous configuration.
    ```bash
    mkdir -p ~/.claude-code-container
    ```

2.  **First Run (Initial Configuration):**
    Run the container mounting this directory from the host to the non-root user's home directory (`/home/node`).
    ```bash
    docker run --rm -it \
        -v ~/.claude-code-container:/home/node \
        -v "/path/to/your/project:/workspace" \
        -e GIT_USER_NAME="Your Name" \
        -e GIT_USER_EMAIL="your@email.com" \
    claude-code-base # Use the new base image name
    ```
    - During this session, perform the interactive configuration that Claude Code requests (login, API key, etc.).
    - The resulting configuration files (`.claude.json`, `.claude/`, `.gitconfig`, etc.) will be saved in `~/.claude-code-container` on your host machine.

3.  **Subsequent Runs:**
    In all future runs, simply mount the same directory again. Claude Code will find its configuration and shouldn't ask for it again.
    ```bash
    docker run --rm -it \
        -v ~/.claude-code-container:/home/node \
        -v "/path/to/your/project:/workspace" \
        -e GIT_USER_NAME="Your Name" \
        -e GIT_USER_EMAIL="your@email.com" \
        claude-code-base "My prompt for Claude" # Use the new base image name
    ```

**Important about Persistent Configuration Security!**
The `~/.claude-code-container` directory (or whichever you choose) on your host will now contain sensitive information like your Anthropic credentials or API keys.
- **Protect this directory on your host system appropriately.**
- **Don't include this directory in Git repositories** if it contains secrets. Add it to your `.gitignore`.
- The `claude-code-base` Docker image itself will not contain these secrets, which is a good security practice. The secrets reside on your local filesystem, managed through the volume.

## 5. Configurable Environment Variables

You can configure the container's behavior using the following environment variables (e.g., in your `.env` file or with `docker run -e VARIABLE=value ...`):

### Core Claude Container Variables:
- **`GIT_USER_NAME`**: Username for Git commits. Example: `"Your Name"`. (Required for commits)
- **`GIT_USER_EMAIL`**: Email for Git commits. Example: `"your@email.com"`. (Required for commits)
- **`CLAUDE_YOLO_MODE`**: (Optional) Set to `"true"` to activate Claude Code's YOLO mode (`--dangerously-skip-permissions`). Default is `"false"`.
- **`GIT_REPO_URL`**: (Optional) URL of the Git repository to clone if the workspace (`/workspace`) is empty.
- **`GIT_HOST_DOMAIN`**: (Required if using SSH or `gh` CLI with a non-github.com host) The Git server domain (e.g., `"github.com"`, `"gitlab.com"`).
- **`GH_TOKEN`**: (Optional) Your GitHub Personal Access Token (PAT) to authenticate the GitHub CLI (`gh`). `gh` is pre-installed in the image.

### Language Versioning (Self-Contained Image):
The image includes multiple language runtimes. Specify desired versions using these environment variables in your `.env` file or during `docker run`.
- **`APP_LANG_PYTHON_VERSION`**: e.g., "3.10.14", "3.11.9", "3.12.4" (see Dockerfile for installed versions).
- **`APP_LANG_NODE_VERSION`**: e.g., "18", "20", "22" (see Dockerfile for installed NVM versions).
- **`APP_LANG_RUST_VERSION`**: e.g., "stable", or a specific version like "1.75.0" (if installed via `rustup toolchain install`).
- **`APP_LANG_GO_VERSION`**: e.g., "1.22.5" (the version installed in Dockerfile). Switching Go versions typically requires rebuilding the image or manually installing another version within a running container.
- **`APP_LANG_SWIFT_VERSION`**: e.g., "5.10" (see Dockerfile for installed Swift version).
*Refer to the `containers/Dockerfile` and `containers/setup_claude.sh` for details on installed languages and version management capabilities.*

### Host-Side Variables (for `docker-compose` or scripts, not directly used by container logic):
- `WORKSPACE_DIR`: Local directory to mount as workspace (default: `./workspace` in `docker-compose.yml`).
- `CLAUDE_CONFIG_DIR`: Directory for persistent Claude Code configuration (default: `~/.claude-code-container` in `docker-compose.yml`).
- `SSH_KEY_DIR`: Directory containing SSH keys (default: `~/.ssh` in `docker-compose.yml`).


### When to Use Key Variables

| Use Case | GIT_USER_NAME | GIT_USER_EMAIL | GIT_HOST_DOMAIN | SSH Keys | `APP_LANG_*` |
|----------|---------------|----------------|-----------------|----------|--------------|
| Read-only (clone/pull) | Optional | Optional | Yes (if SSH) | Yes (if private repo) | As needed |
| Write (commit/push) | **Required** | **Required** | Yes (if SSH) | Yes | As needed |
| Local work without Git | Not needed | Not needed | Not needed | Not needed | As needed |
| Specific Language Version | Optional | Optional | Optional | Optional | **Required** |


## 6. Execution Modes

The Claude Code container can be run in two main ways.

### 6.1. Interactive Mode

Claude Code starts and waits for your commands directly in the terminal. Use the `claude-code` service defined in `docker-compose.yml`.

**Examples:**

```bash
# Using docker-compose (recommended - uses .env file automatically)
# Set desired APP_LANG_* variables in your .env file (e.g., APP_LANG_PYTHON_VERSION="3.11.9")
docker-compose run --rm claude-code

# Or with docker run, specifying the image claude-code-base:latest
# Example: Running claude-code-base and specifying Python 3.11.9
docker run --rm -it \
    -v "${CLAUDE_CONFIG_DIR:-~/.claude-code-container}:/home/node" \
    -v "${WORKSPACE_DIR:-./workspace}:/workspace" \
    -v "${SSH_KEY_DIR:-~/.ssh}:/tmp/ssh_key:ro" \
    --env-file .env \
    -e APP_LANG_PYTHON_VERSION="3.11.9" \
    claude-code-base:latest
```

### 6.2. Autonomous Mode (Non-Interactive)

You pass a prompt or command directly to Claude Code, and the container will close once the task is complete.

**Examples:**

```bash
# Using docker-compose (recommended)
# Ensure .env has APP_LANG_PYTHON_VERSION if the prompt is for a Python script, etc.
docker-compose run --rm claude-code "Help me optimize this Python script"

# Or with docker run
docker run --rm \
    -v "${CLAUDE_CONFIG_DIR:-~/.claude-code-container}:/home/node" \
    -v "${WORKSPACE_DIR:-./workspace}:/workspace" \
    -v "${SSH_KEY_DIR:-~/.ssh}:/tmp/ssh_key:ro" \
    --env-file .env \
    -e APP_LANG_PYTHON_VERSION="3.11.9" \ # Example for a Python script
    claude-code-base:latest "Help me optimize this Python script"
```

## 7. Use Cases and Detailed `docker run` Commands

Make sure to include the configuration volume mount (`-v ~/.claude-code-container:/home/node`) in most commands if you want the configuration to load. Use `claude-code-base:latest` as the image name when using `docker run`.

### 7.1. Working with a Local Workspace

```bash
# Example for a Python 3.12.4 project (set in .env or pass -e)
docker run --rm -it \
    -v ~/.claude-code-container:/home/node \
    -v "$(pwd)/my_local_project:/workspace" \
    -e GIT_USER_NAME="My Name" \
    -e GIT_USER_EMAIL="my@email.com" \
    -e APP_LANG_PYTHON_VERSION="3.12.4" \
    claude-code-base:latest

# Example for a Go project (using the default Go 1.22.5 installed in the image)
docker run --rm -it \
    -v ~/.claude-code-container:/home/node \
    -v "$(pwd)/my_go_project:/workspace" \
    -e GIT_USER_NAME="My Name" \
    -e GIT_USER_EMAIL="my@email.com" \
    claude-code-base:latest
```
(Replace `$(pwd)/my_local_project` with the path to your project).

### 7.2. Clone a Public Git Repository

```bash
docker run --rm -it \
    -v ~/.claude-code-container:/home/node \
    -e GIT_REPO_URL="https://github.com/someuser/some-public-repo.git" \
    -e GIT_USER_NAME="My Name" \
    -e GIT_USER_EMAIL="my@email.com" \
    claude-code-base:latest "analyze the project structure"
```

### 7.3. Clone/Work with a Private Repository using SSH

Mount your SSH private key (read-only is good practice) and specify the `GIT_HOST_DOMAIN`.

**For read-only (clone/pull):**
```bash
docker run --rm -it \
    -v ~/.claude-code-container:/home/node \
    -v ~/.ssh/id_rsa_github:/tmp/ssh_key/id_rsa:ro \
    -v "$(pwd)/my_private_project:/workspace" \
    -e GIT_HOST_DOMAIN="github.com" \
    -e GIT_REPO_URL="git@github.com:your_user/your_private_repo.git" \
    claude-code-base:latest
```

**For write operations (commit/push):**
```bash
docker run --rm -it \
    -v ~/.claude-code-container:/home/node \
    -v ~/.ssh/id_rsa_github:/tmp/ssh_key/id_rsa:ro \
    -v "$(pwd)/my_private_project:/workspace" \
    -e GIT_HOST_DOMAIN="github.com" \
    -e GIT_USER_NAME="My Name" \
    -e GIT_USER_EMAIL="my@email.com" \
    -e GIT_REPO_URL="git@github.com:your_user/your_private_repo.git" \
    claude-code-base:latest
```

**Notes about SSH and Git:**
- **SSH Keys**: Provide authentication (permission to access the repository).
- **`user.name`/`user.email`**: Provide identification (who makes the commits).
- The `entrypoint.sh` will copy the mounted key to `~/.ssh/id_rsa` inside the container.
- `GIT_HOST_DOMAIN` is crucial for adding the host to `known_hosts`.
- **Without `user.name`/`user.email`**: Commits will fail with Git error.

### 7.4. Activate YOLO Mode

Set `CLAUDE_YOLO_MODE="true"`.

```bash
docker run --rm -it \
    -v ~/.claude-code-container:/home/node \
    -v "$(pwd)/my_local_project:/workspace" \
    -e GIT_USER_NAME="My Name" \
    -e GIT_USER_EMAIL="my@email.com" \
    -e CLAUDE_YOLO_MODE="true" \
    claude-code-base:latest "delete all .log files"
```
**Use YOLO mode with extreme caution, especially with write access to your files!**

### 7.5. Using GitHub CLI (`gh`)

If you have provided a `GH_TOKEN` in your `.env` file (or directly via `-e GH_TOKEN=your_token`), the GitHub CLI (`gh`, pre-installed in `codex-universal`) will be authenticated automatically.

```bash
# Example: Create a pull request (assuming you are in a git repo with changes)
# Use docker-compose to easily pick up .env variables
docker-compose run --rm claude-code bash -c "git add . && git commit -m 'feat: new feature' && gh pr create --fill"

# Or with docker run
docker run --rm -it \
    -v ~/.claude-code-container:/home/node \
    -v "$(pwd)/my_local_project:/workspace" \
    --env-file .env \ # .env should contain GH_TOKEN, GIT_USER_NAME, GIT_USER_EMAIL
    claude-code-base:latest bash -c "git add . && git commit -m 'feat: new feature' && gh pr create --fill"

# Example: List issues
docker-compose run --rm claude-code gh issue list
```
- Remember to set `GIT_HOST_DOMAIN` if you are using `gh` with a GitHub Enterprise instance.
- The `gh` configuration (including authentication) is stored in `/home/node/.config/gh` within the container and will be persisted on your host via the `~/.claude-code-container` volume mount.

## 8. Important Notes and Additional Considerations

- **Multi-Language Support**: The `claude-code-base` image is built with support for Python, Node.js, Go, Rust, Swift, Java, Ruby, Bun, and Bazel. Configure specific versions using `APP_LANG_*` environment variables (e.g., `APP_LANG_PYTHON_VERSION="3.11.9"`, `APP_LANG_NODE_VERSION="20"`). Refer to the `containers/Dockerfile` and `containers/setup_claude.sh` for installed versions and capabilities.
- **Volume Permissions:** The image uses a non-root user (`node`) with UID/GID 1000, compatible with Colima on macOS. This enables the use of Claude Code's YOLO mode while maintaining R/W access to mounted volumes.
- **SSH Key Security:**
  - Mount the SSH key as a read-only file (`:ro`) for better security.
  - Use dedicated SSH keys with minimal necessary privileges.
  - Never include SSH keys directly in your `Dockerfile`.
- **Modifying `entrypoint.sh` or `setup_claude.sh`:** If you need more complex logic or different language setups, you can extend these scripts.
- **Technology Stack Simplification & Control:** The project uses a single primary image: `claude-code-base`, built from `ubuntu:24.04`. This provides full control over the included tools and versions. For different languages or versions, configure this single image using `APP_LANG_*` environment variables and the `setup_claude.sh` script.

### Important Note for macOS Users with Colima and Volume Permissions

The image uses a non-root user (`node`) with UID/GID 1000, which is compatible with Colima's default configuration on macOS. This addresses potential volume permissions problem and Claude Code's YOLO mode restriction.

**Advantages of Non-Root User with UID 1000:**
- ✅ Full R/W access to volumes mounted from macOS via Colima
- ✅ Compatibility with Claude Code's YOLO mode (requires non-root user)
- ✅ Better security by not running as root
- ✅ Persistent configuration in `/home/node` instead of `/root`

**Colima Configuration:**
By default, Colima mounts host directories with UID/GID 1000 permissions, perfectly matching our `node` user. No additional configuration required.

# Secure and Configurable Claude Code Execution with Docker

This document describes how to build and use a Docker image to run Claude Code securely and configurably. The solution allows working with Git repositories (public and private via SSH), mounting local workspaces, activating Claude Code's YOLO mode, and persisting Claude Code's initial configuration to avoid repeating it.

## 1. Purpose

The goal is to provide an isolated and reproducible environment for Claude Code that:
- Protects the host system from potentially dangerous operations (especially in YOLO mode).
- Simplifies dependency management (Node.js, Claude Code CLI, Git, etc.).
- Facilitates configuration for interacting with Git repositories.
- Allows choosing between a mounted local workspace or cloning a Git repository.
- **Persists Claude Code's initial configuration (login, API keys, editor preferences) between sessions.**

## 2. Prerequisites

- **Docker:** You must have Docker installed and running on your system.
- **SSH Key:** To interact with private Git repositories using SSH, an SSH private key is required.
- **Claude Code Subscription or Anthropic API KEY** Required for Claude Code initial configuration
- **Configuration Directory on Host:** An empty directory on your host system where Claude Code's persistent configuration will be saved. Example: `~/.claude-code-container`.

## 3. Building the Docker Image

1. Save the `Dockerfile` and `entrypoint.sh` files (provided earlier) in an empty directory.
2. Open a terminal in that directory.
3. Run the following command to build the image. You can change `claude-code-container` to your preferred name and tag:
   ```bash
   docker build -t claude-code-container .
   ```

## 4. Claude Code Configuration Persistence

Claude Code may require initial interactive configuration (login, API key, preferences). To avoid repeating this process with each container run, it's recommended to persist Claude Code's configuration directory using a Docker volume.

Based on analysis, Claude Code saves its configuration in multiple files within the `/home/node` directory in the container, including `/home/node/.claude/` and `/home/node/.claude.json`.

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
        claude-code-container
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
        claude-code-container "My prompt for Claude"
    ```

**Important about Persistent Configuration Security!**
The `~/.claude-code-container` directory (or whichever you choose) on your host will now contain sensitive information like your Anthropic credentials or API keys.
- **Protect this directory on your host system appropriately.**
- **Don't include this directory in Git repositories** if it contains secrets. Add it to your `.gitignore`.
- The `claude-code-container` Docker image itself will not contain these secrets, which is a good security practice. The secrets reside on your local filesystem, managed through the volume.

## 5. Configurable Environment Variables

You can configure the container's behavior using the following environment variables when running `docker run -e VARIABLE=value ...`:

### Git Variables (Important for Commits)
- **`GIT_USER_NAME`**: Username for Git commits. Example: `"Your Name"`.
  - **Required for commits**: Without this variable, Git cannot create commits
  - **SSH Authentication**: SSH keys allow access, but Git still needs to know who you are
  - If not specified, a generic value is used (not recommended for real commits)
- **`GIT_USER_EMAIL`**: Email for Git commits. Example: `"your@email.com"`.
  - **Required for commits**: Git requires email to identify the author
  - **Recommendation**: Use the same email associated with your GitHub/GitLab account

### Behavior Variables
- **`CLAUDE_YOLO_MODE`**: (Optional) Set to `"true"` to activate Claude Code's YOLO mode (`--dangerously-skip-permissions`). Default is `"false"` (safe mode).
- **`GIT_REPO_URL`**: (Optional) URL of the Git repository to clone if the workspace (`/workspace`) is empty. Example: `"https://github.com/user/repo.git"` or `"git@github.com:user/repo.git"`.
- **`GIT_HOST_DOMAIN`**: (Required if using SSH) The Git server domain for `ssh-keyscan`. Example: `"github.com"`, `"gitlab.com"`.

### When to Use Each Variable

| Use Case | GIT_USER_NAME | GIT_USER_EMAIL | GIT_HOST_DOMAIN | SSH Keys |
|----------|---------------|----------------|-----------------|----------|
| Read-only (clone/pull) | Optional | Optional | Yes (if SSH) | Yes (if private repo) |
| Write (commit/push) | **Required** | **Required** | Yes (if SSH) | Yes |
| Local work without Git | Not needed | Not needed | Not needed | Not needed |

## 6. Execution Modes

The Claude Code container can be run in two main ways:

### 6.1. Interactive Mode

Claude Code starts and waits for your commands directly in the terminal.

**Example (with persistent configuration):**
```bash
docker run --rm -it \
    -v ~/.claude-code-container:/home/node \
    -v "$(pwd)/my_local_project:/workspace" \
    -e GIT_USER_NAME="Your Name" \
    -e GIT_USER_EMAIL="your@email.com" \
    claude-code-container
```

### 6.2. Autonomous Mode (Non-Interactive)

You pass a prompt or command directly to Claude Code, and the container will close once the task is complete.

**Example (with persistent configuration):**
```bash
docker run --rm \
    -v ~/.claude-code-container:/home/node \
    -v "$(pwd)/my_local_project:/workspace" \
    -e GIT_USER_NAME="Your Name" \
    -e GIT_USER_EMAIL="your@email.com" \
    claude-code-container "Summarize the README.md file"
```

## 7. Use Cases and Detailed `docker run` Commands

Make sure to include the configuration volume mount (`-v ~/.claude-code-container:/home/node`) in most commands if you want the configuration to load.

### 7.1. Working with a Local Workspace

```bash
docker run --rm -it \
    -v ~/.claude-code-container:/home/node \
    -v "$(pwd)/my_local_project:/workspace" \
    -e GIT_USER_NAME="My Name" \
    -e GIT_USER_EMAIL="my@email.com" \
    claude-code-container
```
(Replace `$(pwd)/my_local_project` with the path to your project).

### 7.2. Clone a Public Git Repository

```bash
docker run --rm -it \
    -v ~/.claude-code-container:/home/node \
    -e GIT_REPO_URL="https://github.com/someuser/some-public-repo.git" \
    -e GIT_USER_NAME="My Name" \
    -e GIT_USER_EMAIL="my@email.com" \
    claude-code-container "analyze the project structure"
```

### 7.3. Clone/Work with a Private Repository using SSH

Mount your SSH private key (read-only is good practice) and specify the `GIT_HOST_DOMAIN`.

**For read-only (clone/pull):**
```bash
# Read-only - GIT_USER_NAME and GIT_USER_EMAIL optional
docker run --rm -it \
    -v ~/.claude-code-container:/home/node \
    -v ~/.ssh/id_rsa_github:/tmp/ssh_key/id_rsa:ro \
    -v "$(pwd)/my_private_project:/workspace" \
    -e GIT_HOST_DOMAIN="github.com" \
    -e GIT_REPO_URL="git@github.com:your_user/your_private_repo.git" \
    claude-code-container
```

**For write operations (commit/push):**
```bash
# Write operations - GIT_USER_NAME and GIT_USER_EMAIL REQUIRED
docker run --rm -it \
    -v ~/.claude-code-container:/home/node \
    -v ~/.ssh/id_rsa_github:/tmp/ssh_key/id_rsa:ro \
    -v "$(pwd)/my_private_project:/workspace" \
    -e GIT_HOST_DOMAIN="github.com" \
    -e GIT_USER_NAME="My Name" \
    -e GIT_USER_EMAIL="my@email.com" \
    -e GIT_REPO_URL="git@github.com:your_user/your_private_repo.git" \
    claude-code-container
```

**Notes about SSH and Git:**
- **SSH Keys**: Provide authentication (permission to access the repository)
- **user.name/user.email**: Provide identification (who makes the commits)
- The `entrypoint.sh` will copy the mounted key to `~/.ssh/id_rsa` inside the container
- `GIT_HOST_DOMAIN` is crucial for adding the host to `known_hosts`
- **Without user.name/user.email**: Commits will fail with Git error

### 7.4. Activate YOLO Mode

Set `CLAUDE_YOLO_MODE="true"`.

```bash
docker run --rm -it \
    -v ~/.claude-code-container:/home/node \
    -v "$(pwd)/my_local_project:/workspace" \
    -e GIT_USER_NAME="My Name" \
    -e GIT_USER_EMAIL="my@email.com" \
    -e CLAUDE_YOLO_MODE="true" \
    claude-code-container "delete all .log files"
```
**Use YOLO mode with extreme caution, especially with write access to your files!**

## 8. Important Notes and Additional Considerations

- **Volume Permissions:** The image uses a non-root user (`node`) with UID/GID 1000, compatible with Colima on macOS. This enables the use of Claude Code's YOLO mode while maintaining R/W access to mounted volumes.
- **SSH Key Security:**
  - Mount the SSH key as a read-only file (`:ro`) for better security.
  - Use dedicated SSH keys with minimal necessary privileges.
  - Never include SSH keys directly in your `Dockerfile`.
- **Modifying `entrypoint.sh`:** If you need more complex logic, you can extend the `entrypoint.sh`.
- **Technology Stack:** This base Dockerfile is designed for documentation tasks or projects that don't require specific build tools. For projects with specific needs (Python, Java, Node.js with project dependencies, etc.), you'll need to create specialized Dockerfiles that build from this base (`FROM claude-code-container`) and install additional tools and dependencies.

### Important Note for macOS Users with Colima and Volume Permissions

The image uses a non-root user (`node`) with UID/GID 1000, which is compatible with Colima's default configuration on macOS. This solves both the volume permissions problem and Claude Code's YOLO mode restriction.

**Advantages of Non-Root User with UID 1000:**
- ✅ Full R/W access to volumes mounted from macOS via Colima
- ✅ Compatibility with Claude Code's YOLO mode (requires non-root user)
- ✅ Better security by not running as root
- ✅ Persistent configuration in `/home/node` instead of `/root`

**Colima Configuration:**
By default, Colima mounts host directories with UID/GID 1000 permissions, perfectly matching our `node` user. No additional configuration required.

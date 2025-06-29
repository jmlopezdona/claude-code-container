#!/bin/bash
set -e # Exit immediately if a command fails

echo "--- Initializing Claude Code Environment ---"

# Run the language setup script as root if possible, or with sudo.
# This should happen before any user-specific setup.
if [ "$(id -u)" -eq 0 ]; then
    echo "Running setup_claude.sh as root..."
    /opt/claude/setup_claude.sh
else
    echo "Attempting to run setup_claude.sh with sudo (current user: $(whoami))..."
    if sudo /opt/claude/setup_claude.sh; then
        echo "setup_claude.sh completed successfully with sudo."
    else
        echo "Warning: setup_claude.sh failed or sudo is not available. Language versions might not be configured as expected."
    fi
fi
echo "--- Language setup complete. Continuing as user $(whoami) ---"


PROJECT_DIR="/workspace"
USER_SSH_DIR="$HOME/.ssh"
# Fixed path where the user is expected to mount their private SSH key
MOUNTED_SSH_KEY_FILE="/tmp/ssh_key/id_rsa" 
FINAL_SSH_KEY_PATH="$USER_SSH_DIR/id_rsa"

echo "--- Starting Entrypoint for Claude Code ---"

# --- 0. SSH Configuration ---
mkdir -p "$USER_SSH_DIR"
chmod 700 "$USER_SSH_DIR"

CONFIGURED_SSH=false
SSH_METHOD=""

# Priority 1: Key mounted at fixed path
if [ -f "$MOUNTED_SSH_KEY_FILE" ]; then
    echo "SSH key detected mounted at: $MOUNTED_SSH_KEY_FILE"
    if [ -s "$MOUNTED_SSH_KEY_FILE" ]; then # Check if file has content
        cp "$MOUNTED_SSH_KEY_FILE" "$FINAL_SSH_KEY_PATH"
        chmod 600 "$FINAL_SSH_KEY_PATH"
        CONFIGURED_SSH=true
        SSH_METHOD="mounted"
    else
        echo "Warning: File $MOUNTED_SSH_KEY_FILE is empty. SSH will not be configured from this file."
    fi
else
    echo "Info: No SSH key provided mounted at $MOUNTED_SSH_KEY_FILE."
    echo "Git operations requiring SSH authentication may fail."
fi

if [ "$CONFIGURED_SSH" = true ]; then
    if [ -z "$GIT_HOST_DOMAIN" ]; then
        echo "Error: SSH key configured (method: $SSH_METHOD), but GIT_HOST_DOMAIN variable is empty."
        echo "GIT_HOST_DOMAIN is required to configure known_hosts and avoid manual prompts."
        exit 1
    fi
    echo "Adding $GIT_HOST_DOMAIN to known_hosts..."
    # Clean known_hosts to avoid duplicates or conflicts on restart
    touch "$USER_SSH_DIR/known_hosts"
    ssh-keyscan -t rsa "$GIT_HOST_DOMAIN" > "$USER_SSH_DIR/known_hosts"
    chmod 644 "$USER_SSH_DIR/known_hosts"
    echo "SSH configuration completed for $GIT_HOST_DOMAIN."
fi

# --- 1. GitHub CLI Authentication ---
if [ -n "$GH_TOKEN" ]; then
    echo "GH_TOKEN environment variable found."
    # Check if gh is already authenticated
    if gh auth status &>/dev/null; then
        echo "GitHub CLI is already authenticated."
    else
        echo "Authenticating GitHub CLI with GH_TOKEN..."
        echo "$GH_TOKEN" | gh auth login --with-token --hostname "$GIT_HOST_DOMAIN"
        if gh auth status &>/dev/null; then
            echo "GitHub CLI authenticated successfully."
        else
            echo "Warning: GitHub CLI authentication failed. Check GH_TOKEN and permissions."
        fi
    fi
else
    echo "Info: GH_TOKEN not provided. GitHub CLI will not be automatically authenticated."
    echo "      You may need to run 'gh auth login' manually if gh commands fail."
fi

# --- 2. Configure Git Global ---
cd "$PROJECT_DIR"

# Check if Git configuration already exists
EXISTING_GIT_NAME=$(git config --global user.name 2>/dev/null || echo "")
EXISTING_GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")

# Configure Git only if variables are specified or no previous configuration exists
if [ -n "$GIT_USER_NAME" ] && [ "$GIT_USER_NAME" != "Claude Docker User" ]; then
    echo "Setting git user.name to: $GIT_USER_NAME"
    git config --global user.name "$GIT_USER_NAME"
elif [ -z "$EXISTING_GIT_NAME" ] && [ -n "$GIT_USER_NAME" ]; then
    echo "Using default git user.name: $GIT_USER_NAME"
    echo "⚠️  WARNING: Using generic configuration. For real commits, specify GIT_USER_NAME."
    git config --global user.name "$GIT_USER_NAME"
elif [ -n "$EXISTING_GIT_NAME" ]; then
    echo "Using existing Git configuration - user.name: $EXISTING_GIT_NAME"
fi

if [ -n "$GIT_USER_EMAIL" ] && [ "$GIT_USER_EMAIL" != "claude-docker@example.com" ]; then
    echo "Setting git user.email to: $GIT_USER_EMAIL"
    git config --global user.email "$GIT_USER_EMAIL"
elif [ -z "$EXISTING_GIT_EMAIL" ] && [ -n "$GIT_USER_EMAIL" ]; then
    echo "Using default git user.email: $GIT_USER_EMAIL"
    echo "⚠️  WARNING: Using generic configuration. For real commits, specify GIT_USER_EMAIL."
    git config --global user.email "$GIT_USER_EMAIL"
elif [ -n "$EXISTING_GIT_EMAIL" ]; then
    echo "Using existing Git configuration - user.email: $EXISTING_GIT_EMAIL"
fi

# Configure working directory as safe for Git
# This prevents "dubious ownership" error in mounted volumes
echo "Configuring working directory as safe for Git..."
git config --global --add safe.directory /workspace
git config --global --add safe.directory '*'

# Configure default branch as 'main' instead of 'master'
git config --global init.defaultBranch main

# Final warning if there's no valid Git configuration
FINAL_GIT_NAME=$(git config --global user.name 2>/dev/null || echo "")
FINAL_GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")
if [ -z "$FINAL_GIT_NAME" ] || [ -z "$FINAL_GIT_EMAIL" ]; then
    echo "⚠️  WARNING: Incomplete Git configuration. Commits will fail without user.name and user.email."
    echo "   Specify GIT_USER_NAME and GIT_USER_EMAIL for write operations."
fi

# --- 3. Prepare Workspace ---
if [ -n "$GIT_REPO_URL" ]; then
    echo "GIT_REPO_URL specified: $GIT_REPO_URL"
    if [ "$(ls -A .)" ]; then # Check if current directory (PROJECT_DIR) has content
        echo "Warning: Working directory $PROJECT_DIR is not empty. Repository will not be cloned."
    else
        echo "Working directory $PROJECT_DIR is empty. Cloning repository..."
        git clone --depth 1 "$GIT_REPO_URL" . # Clone into current directory (PROJECT_DIR)
        echo "Repository cloned."
    fi
else
    echo "No GIT_REPO_URL specified."
    if [ "$(ls -A .)" ]; then
        echo "Workspace ($PROJECT_DIR) contains files - using mounted/existing directory."
    else
        echo "Workspace ($PROJECT_DIR) is empty - will be used as empty working directory."
    fi
fi

# --- 4. Determine arguments for Claude Code (YOLO Mode) ---
CLAUDE_COMMAND_ARGS=()
if [ "$CLAUDE_YOLO_MODE" = "true" ] || [ "$CLAUDE_YOLO_MODE" = "TRUE" ]; then
    echo "YOLO Mode is ENABLED."
    CLAUDE_COMMAND_ARGS+=("--dangerously-skip-permissions") # Adjust if the actual flag is different
else
    echo "YOLO Mode is DISABLED."
fi

# --- 5. Execute Claude Code ---
TARGET_COMMAND_ARGS=("${CLAUDE_COMMAND_ARGS[@]}")
# If arguments are passed to 'docker run ... my-image [claude_arguments]', they are added here
if [ "$#" -gt 0 ]; then
    TARGET_COMMAND_ARGS+=("$@")
fi

echo "Executing command: claude ${TARGET_COMMAND_ARGS[*]}"
echo "----------------------------------------------"
# Use 'exec' so that the claude process replaces the bash script.
exec claude "${TARGET_COMMAND_ARGS[@]}"
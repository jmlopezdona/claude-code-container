#!/bin/bash --login

set -euo pipefail

# These variables are expected to be set in the Dockerfile or via `docker run -e`
# e.g., APP_LANG_PYTHON_VERSION="3.10"

echo "Configuring language runtimes for Claude Code Environment..."

# Source NVM for Node.js version management, if not already available
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Source Pyenv for Python version management, if not already available
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi

# Source Swiftly for Swift version management
[ -f "$HOME/.local/share/swiftly/env.sh" ] && source "$HOME/.local/share/swiftly/env.sh"


if [ -n "${APP_LANG_PYTHON_VERSION:-}" ]; then
    echo "# Python: Setting to ${APP_LANG_PYTHON_VERSION}"
    if pyenv versions --bare | grep -q "^${APP_LANG_PYTHON_VERSION}$"; then
        pyenv global "${APP_LANG_PYTHON_VERSION}"
        echo "# Python: Successfully set to $(python --version)"
    else
        echo "# Python: Version ${APP_LANG_PYTHON_VERSION} not found. Available versions:"
        pyenv versions
    fi
fi

if [ -n "${APP_LANG_NODE_VERSION:-}" ]; then
    echo "# Node.js: Setting to ${APP_LANG_NODE_VERSION}"
    if nvm list "${APP_LANG_NODE_VERSION}" > /dev/null 2>&1; then
        nvm alias default "${APP_LANG_NODE_VERSION}"
        nvm use default # nvm use will also install if the version is known but not installed
        echo "# Node.js: Successfully set to $(node --version)"
        # Ensure corepack shims are up-to-date for the selected Node version
        corepack enable
        corepack install -g yarn pnpm npm
    else
        echo "# Node.js: Version ${APP_LANG_NODE_VERSION} not available or not installed via NVM. Available versions:"
        nvm ls
    fi
fi

if [ -n "${APP_LANG_RUST_VERSION:-}" ]; then
    current_rust_version=$(rustc --version | awk '{print $2}')
    echo "# Rust: Requested ${APP_LANG_RUST_VERSION} (Current: ${current_rust_version})"
    if [ "${current_rust_version}" != "${APP_LANG_RUST_VERSION}" ]; then
        echo "# Rust: Switching to ${APP_LANG_RUST_VERSION}"
        if rustup toolchain list | grep -q "^${APP_LANG_RUST_VERSION}"; then
            rustup default "${APP_LANG_RUST_VERSION}"
            echo "# Rust: Successfully set to $(rustc --version | awk '{print $2}')"
        else
            echo "# Rust: Toolchain ${APP_LANG_RUST_VERSION} not installed. Attempting to install."
            if rustup toolchain install --no-self-update "${APP_LANG_RUST_VERSION}"; then
                 rustup default "${APP_LANG_RUST_VERSION}"
                 echo "# Rust: Successfully installed and set to $(rustc --version | awk '{print $2}')"
            else
                echo "# Rust: Failed to install toolchain ${APP_LANG_RUST_VERSION}. Current versions:"
                rustup toolchain list
            fi
        fi
    else
        echo "# Rust: Already using ${APP_LANG_RUST_VERSION}"
    fi
fi

if [ -n "${APP_LANG_GO_VERSION:-}" ]; then
    current_go_version_full=$(go version 2>/dev/null || echo "go0.0.0") # Get full version string e.g. go1.22.5
    current_go_version=$(echo "$current_go_version_full" | awk '{print $3}' | sed 's/go//') # Extract 1.22.5
    requested_go_version_full="go${APP_LANG_GO_VERSION}"

    echo "# Go: Requested ${APP_LANG_GO_VERSION} (Current: ${current_go_version})"

    if [ "${current_go_version_full}" != "${requested_go_version_full}" ]; then
        echo "# Go: Switching to ${APP_LANG_GO_VERSION}"
        # Go versions are typically installed side-by-side, not switched globally like pyenv/nvm.
        # The Dockerfile installs a specific version. If a different one is needed,
        # it would typically require installing it and adjusting PATH.
        # This script will primarily report the version. Advanced switching might need Dockerfile rebuild.
        if command -v "go${APP_LANG_GO_VERSION}" > /dev/null 2>&1; then
           echo "# Go: Version go${APP_LANG_GO_VERSION} is available. To use it, you might need to adjust your PATH or use 'go${APP_LANG_GO_VERSION} <command>'."
           echo "# Go: Current default Go version: $(go version)"
        else
            echo "# Go: Version go${APP_LANG_GO_VERSION} is not found. The Dockerfile installed $(go version)."
            echo "# Go: To use a different Go version, you may need to rebuild the Docker image with the desired version."
        fi
    else
        echo "# Go: Already configured for ${APP_LANG_GO_VERSION} (Default is $(go version))"
    fi
fi

if [ -n "${APP_LANG_SWIFT_VERSION:-}" ]; then
    current_swift_version=$(swift --version 2>/dev/null | awk -F'version ' '{print $2}' | awk '{print $1}' || echo "0.0")
    echo "# Swift: Requested ${APP_LANG_SWIFT_VERSION} (Current: ${current_swift_version})"
    if [ "${current_swift_version}" != "${APP_LANG_SWIFT_VERSION}" ]; then
        echo "# Swift: Switching to ${APP_LANG_SWIFT_VERSION}"
        if swiftly list | grep -q "${APP_LANG_SWIFT_VERSION}"; then
            if swiftly use "${APP_LANG_SWIFT_VERSION}"; then
                echo "# Swift: Successfully set to $(swift --version | awk -F'version ' '{print $2}' | awk '{print $1}')"
            else
                echo "# Swift: Failed to switch to ${APP_LANG_SWIFT_VERSION}. Installed versions:"
                swiftly list
            fi
        else
            echo "# Swift: Version ${APP_LANG_SWIFT_VERSION} not installed. Attempting to install."
            if swiftly install "${APP_LANG_SWIFT_VERSION}"; then
                 swiftly use "${APP_LANG_SWIFT_VERSION}"
                 echo "# Swift: Successfully installed and set to $(swift --version | awk -F'version ' '{print $2}' | awk '{print $1}')"
            else
                echo "# Swift: Failed to install or use version ${APP_LANG_SWIFT_VERSION}. Installed versions:"
                swiftly list
            fi
        fi
    else
        echo "# Swift: Already using ${APP_LANG_SWIFT_VERSION}"
    fi
fi

echo "Language runtime configuration complete."

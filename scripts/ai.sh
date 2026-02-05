#!/usr/bin/env bash
# AI coding assistants: Claude Code, pi

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Phase 1: Set up repos and queue packages for batch install
collect_ai() {
    info "=== AI Coding Assistants Setup (collecting packages) ==="

    if [ "$PKG_MANAGER" = "apt" ]; then
        # Set up NodeSource repo for Node.js 20.x LTS
        if [ ! -f /etc/apt/sources.list.d/nodesource.list ]; then
            info "Adding NodeSource apt repository..."
            curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        fi
        queue_pkg nodejs
    elif [ "$PKG_MANAGER" = "pacman" ]; then
        queue_pkg nodejs npm
    fi
}

# Phase 3: Post-install configuration
setup_ai() {
    echo ""
    info "=== AI Coding Assistants Setup (configuring) ==="
    echo ""

    # Install Claude Code
    if has_cmd claude; then
        success "Claude Code already installed"
    else
        info "Installing Claude Code..."
        curl -fsSL https://claude.ai/install.sh | bash
        success "Claude Code installed"
    fi

    # Install pi
    if has_cmd pi; then
        success "pi already installed"
    else
        if ! has_cmd npm; then
            warn "npm is required to install pi. Skipping."
        else
            info "Installing pi..."
            # Use user-owned directory for global packages (avoids sudo)
            if [[ "$(npm config get prefix)" == /usr* ]]; then
                mkdir -p "$HOME/.local"
                npm config set prefix "$HOME/.local"
            fi
            export PATH="$HOME/.local/bin:$PATH"

            npm install -g @mariozechner/pi-coding-agent
            success "pi installed"
        fi
    fi

    success "AI coding assistants setup complete!"
}

# Run standalone if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    detect_os
    collect_ai
    system_update
    install_queued_packages
    setup_ai
fi

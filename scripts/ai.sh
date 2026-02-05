#!/usr/bin/env bash
# AI coding assistants: Claude Code, pi

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

install_nodejs() {
    info "Installing Node.js..."

    if has_cmd node; then
        local node_version
        node_version=$(node --version | sed 's/v//' | cut -d. -f1)
        if [ "$node_version" -ge 18 ]; then
            success "Node.js $(node --version) already installed"
            return
        else
            warn "Node.js version $(node --version) is too old, upgrading..."
        fi
    fi

    if [ "$PKG_MANAGER" = "apt" ]; then
        # Install Node.js 20.x LTS via NodeSource
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        apt_install nodejs
    elif [ "$PKG_MANAGER" = "pacman" ]; then
        pacman_install nodejs npm
    fi

    success "Node.js $(node --version) installed"
}

install_claude_code() {
    info "Installing Claude Code..."

    if has_cmd claude; then
        success "Claude Code already installed"
        return
    fi

    # Native installer (recommended, no Node.js required)
    curl -fsSL https://claude.ai/install.sh | bash

    success "Claude Code installed"
}

install_pi() {
    info "Installing pi..."

    if has_cmd pi; then
        success "pi already installed"
        return
    fi

    # Requires Node.js/npm
    if ! has_cmd npm; then
        error "npm is required to install pi. Please install Node.js first."
    fi

    npm install -g @mariozechner/pi-coding-agent

    success "pi installed"
}

# Main
main() {
    echo ""
    info "=== AI Coding Assistants Setup ==="
    echo ""

    [ -z "$PKG_MANAGER" ] && detect_os

    install_nodejs
    install_claude_code
    install_pi

    success "AI coding assistants setup complete!"
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

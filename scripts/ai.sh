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

    local dotfiles_dir
    dotfiles_dir="$(get_dotfiles_dir)"

    link_pi_path() {
        local source_path="$1"
        local target_path="$2"

        if [ ! -e "$source_path" ]; then
            return 0
        fi

        mkdir -p "$(dirname "$target_path")"

        if [ -L "$target_path" ]; then
            local current_target
            current_target="$(readlink "$target_path")"
            if [ "$current_target" = "$source_path" ]; then
                return 0
            fi
            rm -f "$target_path"
        elif [ -e "$target_path" ]; then
            local backup_path="${target_path}.backup-$(date +%Y%m%d%H%M%S)"
            warn "Backing up existing pi config: $target_path -> $backup_path"
            mv "$target_path" "$backup_path"
        fi

        ln -s "$source_path" "$target_path"
    }

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

            npm install -g --ignore-scripts @earendil-works/pi-coding-agent
            success "pi installed"
        fi
    fi

    # Link pi config and local extensions from this dotfiles repo.
    # Do not link auth.json, sessions, cache, trust.json, or installed npm/git package dirs.
    if [ -d "$dotfiles_dir/config/pi/agent" ]; then
        info "Linking pi config..."
        link_pi_path "$dotfiles_dir/config/pi/agent/settings.json" "$HOME/.pi/agent/settings.json"
        link_pi_path "$dotfiles_dir/config/pi/agent/models.json" "$HOME/.pi/agent/models.json"
        link_pi_path "$dotfiles_dir/config/pi/agent/extensions" "$HOME/.pi/agent/extensions"
        link_pi_path "$dotfiles_dir/config/pi/agent/prompts" "$HOME/.pi/agent/prompts"
        link_pi_path "$dotfiles_dir/config/pi/agent/skills" "$HOME/.pi/agent/skills"
        link_pi_path "$dotfiles_dir/config/pi/agent/themes" "$HOME/.pi/agent/themes"
        success "Linked pi config"

        if has_cmd pi; then
            info "Installing/updating pi extension packages from settings.json..."
            if pi update --extensions; then
                success "pi extension packages are installed"
            else
                warn "Could not install/update pi extension packages. You can retry with: pi update --extensions"
            fi
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

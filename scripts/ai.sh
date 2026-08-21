#!/usr/bin/env bash
# AI coding tools: Herdr, Claude Code, pi

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Phase 1: Set up repos and queue packages for batch install
collect_ai() {
    info "=== AI Coding Tools Setup (collecting packages) ==="

    if [ "$PKG_MANAGER" = "apt" ]; then
        # Herdr's hunkdiff plugin requires Node.js 22.12 or newer.
        if ! has_cmd node || ! node -e '
            const [major, minor] = process.versions.node.split(".").map(Number);
            process.exit(major > 22 || (major === 22 && minor >= 12) ? 0 : 1);
        '; then
            info "Adding NodeSource repository for Node.js 22.x..."
            curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
        fi
        queue_pkg nodejs
    elif [ "$PKG_MANAGER" = "pacman" ]; then
        queue_pkg nodejs npm
    fi
}

# Phase 3: Post-install configuration
setup_ai() {
    echo ""
    info "=== AI Coding Tools Setup (configuring) ==="
    echo ""

    local dotfiles_dir
    dotfiles_dir="$(get_dotfiles_dir)"

    link_config_path() {
        local source_path="$1"
        local target_path="$2"
        local config_name="$3"

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
            warn "Backing up existing $config_name config: $target_path -> $backup_path"
            mv "$target_path" "$backup_path"
        fi

        ln -s "$source_path" "$target_path"
    }

    # Install Herdr
    if has_cmd herdr; then
        success "Herdr already installed"
    else
        info "Installing Herdr..."
        curl -fsSL https://herdr.dev/install.sh | sh
        success "Herdr installed"
    fi

    # Link Herdr config without replacing its runtime state, logs, or sockets.
    if [ -f "$dotfiles_dir/config/herdr/config.toml" ]; then
        info "Linking Herdr config..."
        link_config_path \
            "$dotfiles_dir/config/herdr/config.toml" \
            "$HOME/.config/herdr/config.toml" \
            "Herdr"
        success "Linked Herdr config"
    fi

    # Install declared Herdr plugins and link their configs without touching plugin runtime state.
    local herdr_plugins_dir="$dotfiles_dir/config/herdr/plugins"
    if [ -d "$herdr_plugins_dir" ]; then
        local installed_plugins
        installed_plugins="$(herdr plugin list 2>/dev/null || true)"

        local plugin_dir plugin_id plugin_source plugin_config_dir
        for plugin_dir in "$herdr_plugins_dir"/*; do
            [ -d "$plugin_dir" ] || continue
            plugin_id="$(basename "$plugin_dir")"

            if [ -f "$plugin_dir/source" ]; then
                plugin_source="$(<"$plugin_dir/source")"
                if printf '%s\n' "$installed_plugins" | grep -Fq -- "- $plugin_id "; then
                    success "Herdr plugin already installed: $plugin_id"
                else
                    info "Installing Herdr plugin: $plugin_source"
                    herdr plugin install --yes "$plugin_source"
                    success "Installed Herdr plugin: $plugin_id"
                fi
            fi

            if [ -f "$plugin_dir/config.toml" ]; then
                plugin_config_dir="$(herdr plugin config-dir "$plugin_id")"
                info "Linking Herdr plugin config: $plugin_id"
                link_config_path \
                    "$plugin_dir/config.toml" \
                    "$plugin_config_dir/config.toml" \
                    "Herdr plugin $plugin_id"
                success "Linked Herdr plugin config: $plugin_id"
            fi
        done
    fi

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
        link_config_path "$dotfiles_dir/config/pi/agent/settings.json" "$HOME/.pi/agent/settings.json" "pi"
        link_config_path "$dotfiles_dir/config/pi/agent/models.json" "$HOME/.pi/agent/models.json" "pi"
        link_config_path "$dotfiles_dir/config/pi/agent/extensions" "$HOME/.pi/agent/extensions" "pi"
        link_config_path "$dotfiles_dir/config/pi/agent/prompts" "$HOME/.pi/agent/prompts" "pi"
        link_config_path "$dotfiles_dir/config/pi/agent/skills" "$HOME/.pi/agent/skills" "pi"
        link_config_path "$dotfiles_dir/config/pi/agent/themes" "$HOME/.pi/agent/themes" "pi"
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

    success "AI coding tools setup complete!"
}

# Run standalone if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    detect_os
    collect_ai
    system_update
    install_queued_packages
    setup_ai
fi

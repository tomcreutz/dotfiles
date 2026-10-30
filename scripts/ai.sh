#!/usr/bin/env bash
# AI coding tools: Herdr, Claude Code, pi

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Phase 1: Set up repos and queue packages for batch install
collect_ai() {
    info "=== AI Coding Tools Setup (collecting packages) ==="

    if [ "$PKG_MANAGER" = "apt" ]; then
        # pi requires Node.js 22.19 or newer (Ubuntu's default is too old).
        if ! has_cmd node || ! node -e '
            const [major, minor] = process.versions.node.split(".").map(Number);
            process.exit(major > 22 || (major === 22 && minor >= 19) ? 0 : 1);
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

    # Herdr app (`herdr-app`) plus herdr-core (`hc`), which runs the terminals.
    # The installer puts the app in ~/.local/share/herdr-app and both commands
    # in ~/.local/bin. Both update themselves afterwards, so an existing install
    # is left alone.
    if [ -x "$HOME/.local/bin/herdr-app" ] || has_cmd herdr-app; then
        success "Herdr already installed"
    else
        info "Installing Herdr..."
        curl -fsSL https://releases.herdr.dev/app/install.sh | sh
        success "Herdr installed"
    fi

    # Link personal Herdr app files. ~/.config/herdr-app also holds files Herdr
    # rewrites on every start (shipped layouts/mods, AGENTS.md, icons, state),
    # so only items that exist in this repo are linked, one by one.
    local herdr_src="$dotfiles_dir/config/herdr-app"
    local herdr_home="$HOME/.config/herdr-app"
    if [ -d "$herdr_src" ]; then
        info "Linking Herdr config..."
        local item
        for item in settings.json keys.json programs.json; do
            link_config_path "$herdr_src/$item" "$herdr_home/$item" "Herdr"
        done
        for item in "$herdr_src"/layouts/*.json "$herdr_src"/themes/*.json; do
            [ -e "$item" ] || continue
            link_config_path "$item" "$herdr_home/${item#"$herdr_src"/}" "Herdr"
        done
        for item in "$herdr_src"/mods/*/; do
            [ -d "$item" ] || continue
            item="${item%/}"
            link_config_path "$item" "$herdr_home/mods/$(basename "$item")" "Herdr"
        done
        success "Linked Herdr config"
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

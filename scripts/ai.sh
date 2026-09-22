#!/usr/bin/env bash
# AI coding tools: Orca, Claude Code, pi

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

    # Orca's Linux AppImage self-updates; do not overwrite an existing install.
    # The Orca CLI (`orca`) is separate from the GUI executable.
    if [ -x "$HOME/Applications/Orca.AppImage" ] || has_cmd orca-ide; then
        success "Orca already installed"
    else
        local appimage_name app_dir appimage_tmp
        case "$(uname -m)" in
            x86_64) appimage_name="orca-linux.AppImage" ;;
            aarch64|arm64) appimage_name="orca-linux-arm64.AppImage" ;;
            *) error "No Orca AppImage available for architecture: $(uname -m)" ;;
        esac
        app_dir="$HOME/Applications"
        mkdir -p "$app_dir"
        appimage_tmp="$(mktemp "$app_dir/.orca.XXXXXX.AppImage")"
        info "Downloading Orca AppImage..."
        if ! curl -fL --retry 3 -o "$appimage_tmp" \
            "https://github.com/stablyai/orca/releases/latest/download/$appimage_name"; then
            rm -f "$appimage_tmp"
            error "Could not download Orca AppImage"
        fi
        chmod +x "$appimage_tmp"
        mv "$appimage_tmp" "$app_dir/Orca.AppImage"
        success "Orca installed at $app_dir/Orca.AppImage"
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

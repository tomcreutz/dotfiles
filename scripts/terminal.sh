#!/usr/bin/env bash
# Terminal setup: alacritty, zellij, fonts

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

install_alacritty() {
    info "Installing alacritty..."

    if has_cmd alacritty; then
        success "alacritty already installed"
        return
    fi

    pkg_install alacritty
    success "alacritty installed"
}

install_zellij() {
    info "Installing zellij..."

    if has_cmd zellij; then
        success "zellij already installed"
        return
    fi

    if [ "$PKG_MANAGER" = "apt" ]; then
        # Zellij not in default Ubuntu repos, install from GitHub releases
        info "Installing zellij from GitHub releases..."
        ZELLIJ_VERSION=$(curl -s https://api.github.com/repos/zellij-org/zellij/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
        curl -Lo /tmp/zellij.tar.gz "https://github.com/zellij-org/zellij/releases/download/${ZELLIJ_VERSION}/zellij-x86_64-unknown-linux-musl.tar.gz"
        sudo tar -xzf /tmp/zellij.tar.gz -C /usr/local/bin
        rm /tmp/zellij.tar.gz
    elif [ "$PKG_MANAGER" = "pacman" ]; then
        pacman_install zellij
    fi

    success "zellij installed"
}

install_fonts() {
    info "Installing JetBrainsMono Nerd Font..."

    FONT_DIR="$HOME/.local/share/fonts"
    mkdir -p "$FONT_DIR"

    # Check if font already exists
    if ls "$FONT_DIR"/JetBrainsMono* &> /dev/null 2>&1 || ls /usr/share/fonts/**/JetBrainsMono* &> /dev/null 2>&1; then
        success "JetBrainsMono Nerd Font already installed"
        return
    fi

    if [ "$PKG_MANAGER" = "pacman" ]; then
        # On Arch, install from repos
        if has_cmd paru; then
            paru -S --noconfirm --needed ttf-jetbrains-mono-nerd
        elif has_cmd yay; then
            yay -S --noconfirm --needed ttf-jetbrains-mono-nerd
        else
            pacman_install ttf-jetbrains-mono-nerd
        fi
    else
        # Download from GitHub for other distros
        apt_install unzip fontconfig
        FONT_VERSION="v3.3.0"
        curl -Lo /tmp/JetBrainsMono.zip "https://github.com/ryanoasis/nerd-fonts/releases/download/${FONT_VERSION}/JetBrainsMono.zip"
        unzip -o /tmp/JetBrainsMono.zip -d "$FONT_DIR"
        rm /tmp/JetBrainsMono.zip
        fc-cache -fv
    fi

    success "JetBrainsMono Nerd Font installed"
}

link_terminal_configs() {
    local dotfiles_dir="$(get_dotfiles_dir)"
    local config_dir="$HOME/.config"

    mkdir -p "$config_dir"

    # Alacritty
    if [ -d "$dotfiles_dir/alacritty" ]; then
        info "Linking alacritty config..."
        rm -rf "$config_dir/alacritty"
        ln -sf "$dotfiles_dir/alacritty" "$config_dir/alacritty"
        success "Linked alacritty config"
    fi

    # Zellij
    if [ -d "$dotfiles_dir/zellij" ]; then
        info "Linking zellij config..."
        rm -rf "$config_dir/zellij"
        ln -sf "$dotfiles_dir/zellij" "$config_dir/zellij"
        success "Linked zellij config"
    fi
}

# Main
main() {
    echo ""
    info "=== Terminal Setup ==="
    echo ""

    [ -z "$PKG_MANAGER" ] && detect_os

    install_fonts
    install_alacritty
    install_zellij
    link_terminal_configs

    success "Terminal setup complete!"
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

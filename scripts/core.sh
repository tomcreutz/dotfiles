#!/usr/bin/env bash
# Core shell setup: zsh, oh-my-zsh, essential CLI tools

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

install_zsh() {
    info "Installing zsh..."

    if has_cmd zsh; then
        success "zsh already installed"
    else
        pkg_install zsh
        success "zsh installed"
    fi
}

install_oh_my_zsh() {
    info "Installing Oh My Zsh..."

    if [ -d "$HOME/.oh-my-zsh" ]; then
        success "Oh My Zsh already installed"
    else
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        success "Oh My Zsh installed"
    fi

    # Install zsh plugins
    ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    # zsh-autosuggestions
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
        info "Installing zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
        success "zsh-autosuggestions installed"
    else
        success "zsh-autosuggestions already installed"
    fi

    # zsh-syntax-highlighting
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
        info "Installing zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
        success "zsh-syntax-highlighting installed"
    else
        success "zsh-syntax-highlighting already installed"
    fi
}

link_zsh_config() {
    local dotfiles_dir="$(get_dotfiles_dir)"

    if [ -f "$dotfiles_dir/zsh/.zshrc" ]; then
        info "Linking .zshrc..."
        ln -sf "$dotfiles_dir/zsh/.zshrc" "$HOME/.zshrc"
        success "Linked .zshrc"
    fi
}

set_default_shell() {
    if [ "$SHELL" = "$(which zsh)" ]; then
        success "zsh is already the default shell"
        return
    fi

    info "Setting zsh as default shell..."
    chsh -s "$(which zsh)"
    success "zsh set as default shell (restart terminal to take effect)"
}

install_core_packages() {
    info "Installing core packages..."

    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt update
        apt_install git curl wget
    elif [ "$PKG_MANAGER" = "pacman" ]; then
        sudo pacman -Syu --noconfirm
        pacman_install git curl wget
    fi

    success "Core packages installed"
}

# Main
main() {
    echo ""
    info "=== Core Shell Setup ==="
    echo ""

    [ -z "$PKG_MANAGER" ] && detect_os

    install_core_packages
    install_zsh
    install_oh_my_zsh
    link_zsh_config
    set_default_shell

    success "Core setup complete!"
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

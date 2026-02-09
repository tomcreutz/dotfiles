#!/usr/bin/env bash
# Core shell setup: zsh, oh-my-zsh, essential CLI tools

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Phase 1: Queue packages for batch install
collect_core() {
    info "=== Core Shell Setup (collecting packages) ==="
    queue_pkg git curl wget zsh
}

# Phase 3: Post-install configuration
setup_core() {
    echo ""
    info "=== Core Shell Setup (configuring) ==="
    echo ""

    # Install Oh My Zsh
    if [ -d "$HOME/.oh-my-zsh" ]; then
        success "Oh My Zsh already installed"
    else
        info "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        success "Oh My Zsh installed"
    fi

    # Install zsh plugins
    ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
        info "Installing zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
        success "zsh-autosuggestions installed"
    else
        success "zsh-autosuggestions already installed"
    fi

    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
        info "Installing zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
        success "zsh-syntax-highlighting installed"
    else
        success "zsh-syntax-highlighting already installed"
    fi

    # Link .zshrc
    local dotfiles_dir="$(get_dotfiles_dir)"
    if [ -f "$dotfiles_dir/config/zsh/.zshrc" ]; then
        info "Linking .zshrc..."
        ln -sf "$dotfiles_dir/config/zsh/.zshrc" "$HOME/.zshrc"
        success "Linked .zshrc"
    fi

    # Set default shell
    local zsh_path
    zsh_path="$(which zsh)"

    if [ "$SHELL" = "$zsh_path" ]; then
        success "zsh is already the default shell"
    elif grep -q "^$(whoami):" /etc/passwd 2>/dev/null; then
        info "Setting zsh as default shell..."
        chsh -s "$zsh_path"
        success "zsh set as default shell (log out and back in to take effect)"
    else
        warn "Cannot use chsh (LDAP/domain account - user not in /etc/passwd)"
        info "zsh will be used automatically via your terminal emulator config"
    fi

    success "Core setup complete!"
}

# Run standalone if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    detect_os
    collect_core
    system_update
    install_queued_packages
    setup_core
fi

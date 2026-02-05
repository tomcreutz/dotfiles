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

    if [ -f "$dotfiles_dir/config/zsh/.zshrc" ]; then
        info "Linking .zshrc..."
        ln -sf "$dotfiles_dir/config/zsh/.zshrc" "$HOME/.zshrc"
        success "Linked .zshrc"
    fi
}

set_default_shell() {
    local zsh_path
    zsh_path="$(which zsh)"

    if [ "$SHELL" = "$zsh_path" ]; then
        success "zsh is already the default shell"
        return
    fi

    info "Setting zsh as default shell..."

    # Check if user exists in local /etc/passwd (not LDAP/domain)
    if grep -q "^$(whoami):" /etc/passwd 2>/dev/null; then
        chsh -s "$zsh_path"
        success "zsh set as default shell (restart terminal to take effect)"
    else
        # LDAP/domain user - chsh won't work, add zsh exec to login profile
        warn "Cannot use chsh (LDAP/domain account - user not in /etc/passwd)"
        info "Adding zsh auto-start to login profile as workaround..."

        local bashrc_file="$HOME/.bashrc"
        local zsh_exec_block="
# Auto-start zsh for LDAP/domain users (set NOZSH=1 to disable)
if [ -z \"\$NOZSH\" ] && [ \"\$TERM\" = \"xterm\" -o \"\$TERM\" = \"xterm-256color\" -o \"\$TERM\" = \"screen\" ] && type zsh &>/dev/null; then
    export SHELL=\"$zsh_path\"
    if shopt -q login_shell; then
        exec zsh -l
    else
        exec zsh
    fi
fi"

        if grep -q "Auto-start zsh" "$bashrc_file" 2>/dev/null; then
            success "zsh auto-start already configured in $bashrc_file"
        else
            echo "$zsh_exec_block" >> "$bashrc_file"
            success "Added zsh auto-start to $bashrc_file (restart terminal to take effect)"
        fi
    fi
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

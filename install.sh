#!/usr/bin/env bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_LIKE=$ID_LIKE
    else
        error "Cannot detect OS. /etc/os-release not found."
    fi

    case "$OS" in
        ubuntu|debian)
            PKG_MANAGER="apt"
            ;;
        arch|cachyos|endeavouros|manjaro)
            PKG_MANAGER="pacman"
            ;;
        *)
            # Check ID_LIKE for derivatives
            if [[ "$OS_LIKE" == *"ubuntu"* ]] || [[ "$OS_LIKE" == *"debian"* ]]; then
                PKG_MANAGER="apt"
            elif [[ "$OS_LIKE" == *"arch"* ]]; then
                PKG_MANAGER="pacman"
            else
                error "Unsupported OS: $OS. Supported: Ubuntu/Debian, Arch/CachyOS"
            fi
            ;;
    esac

    info "Detected OS: $OS (using $PKG_MANAGER)"
}

# Check if command exists
has_cmd() {
    command -v "$1" &> /dev/null
}

# Install packages based on OS
install_packages() {
    info "Installing packages..."

    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt update
        sudo apt install -y git curl zsh alacritty unzip fontconfig

        # Zellij not in default Ubuntu repos, install from GitHub releases
        if ! has_cmd zellij; then
            info "Installing zellij from GitHub releases..."
            ZELLIJ_VERSION=$(curl -s https://api.github.com/repos/zellij-org/zellij/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
            curl -Lo /tmp/zellij.tar.gz "https://github.com/zellij-org/zellij/releases/download/${ZELLIJ_VERSION}/zellij-x86_64-unknown-linux-musl.tar.gz"
            sudo tar -xzf /tmp/zellij.tar.gz -C /usr/local/bin
            rm /tmp/zellij.tar.gz
            success "Zellij installed"
        fi

    elif [ "$PKG_MANAGER" = "pacman" ]; then
        # Check for AUR helper (paru preferred, fallback to yay)
        AUR_HELPER=""
        if has_cmd paru; then
            AUR_HELPER="paru"
        elif has_cmd yay; then
            AUR_HELPER="yay"
        fi

        # Install from official repos
        sudo pacman -Syu --noconfirm --needed git curl zsh alacritty zellij
    fi

    success "Packages installed"
}

# Install Nerd Font
install_font() {
    info "Installing JetBrainsMono Nerd Font..."

    FONT_DIR="$HOME/.local/share/fonts"
    mkdir -p "$FONT_DIR"

    if ls "$FONT_DIR"/JetBrainsMono* &> /dev/null || ls /usr/share/fonts/**/JetBrainsMono* &> /dev/null 2>&1; then
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
            sudo pacman -S --noconfirm --needed ttf-jetbrains-mono-nerd
        fi
    else
        # Download from GitHub for other distros
        FONT_VERSION="v3.3.0"
        curl -Lo /tmp/JetBrainsMono.zip "https://github.com/ryanoasis/nerd-fonts/releases/download/${FONT_VERSION}/JetBrainsMono.zip"
        unzip -o /tmp/JetBrainsMono.zip -d "$FONT_DIR"
        rm /tmp/JetBrainsMono.zip
        fc-cache -fv
    fi

    success "JetBrainsMono Nerd Font installed"
}

# Install Oh My Zsh
install_oh_my_zsh() {
    info "Installing Oh My Zsh..."

    if [ -d "$HOME/.oh-my-zsh" ]; then
        success "Oh My Zsh already installed"
    else
        # Install Oh My Zsh (unattended)
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

# Clone or update dotfiles
setup_dotfiles() {
    DOTFILES_DIR="$HOME/.dotfiles"
    DOTFILES_REPO="https://github.com/YOUR_USERNAME/dotfiles.git"  # TODO: Update this URL

    # If running from curl pipe, clone the repo
    if [ ! -d "$DOTFILES_DIR" ]; then
        if [ -d "$(dirname "$0")/alacritty" ] 2>/dev/null; then
            # Running from local directory
            DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
            info "Using local dotfiles at $DOTFILES_DIR"
        else
            info "Cloning dotfiles repository..."
            git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
        fi
    else
        info "Dotfiles already exist at $DOTFILES_DIR"
    fi

    echo "$DOTFILES_DIR"
}

# Create symlinks for config files
link_configs() {
    local dotfiles_dir="$1"

    info "Linking config files..."

    CONFIG_DIR="$HOME/.config"
    mkdir -p "$CONFIG_DIR"

    # Alacritty
    if [ -d "$dotfiles_dir/alacritty" ]; then
        rm -rf "$CONFIG_DIR/alacritty"
        ln -sf "$dotfiles_dir/alacritty" "$CONFIG_DIR/alacritty"
        success "Linked alacritty config"
    fi

    # Zellij
    if [ -d "$dotfiles_dir/zellij" ]; then
        rm -rf "$CONFIG_DIR/zellij"
        ln -sf "$dotfiles_dir/zellij" "$CONFIG_DIR/zellij"
        success "Linked zellij config"
    fi

    # Zsh config (if exists)
    if [ -f "$dotfiles_dir/zsh/.zshrc" ]; then
        ln -sf "$dotfiles_dir/zsh/.zshrc" "$HOME/.zshrc"
        success "Linked .zshrc"
    fi
}

# Set zsh as default shell
set_default_shell() {
    if [ "$SHELL" = "$(which zsh)" ]; then
        success "Zsh is already the default shell"
        return
    fi

    info "Setting zsh as default shell..."
    chsh -s "$(which zsh)"
    success "Zsh set as default shell (restart terminal to take effect)"
}

# Main installation
main() {
    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║       Dotfiles Installation Script       ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""

    detect_os
    install_packages
    install_font
    install_oh_my_zsh

    # Determine dotfiles location
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd 2>/dev/null || echo "")"

    if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/alacritty" ]; then
        DOTFILES_DIR="$SCRIPT_DIR"
    else
        DOTFILES_DIR=$(setup_dotfiles)
    fi

    link_configs "$DOTFILES_DIR"
    set_default_shell

    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║         Installation Complete!           ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""
    info "Please restart your terminal or run: exec zsh"
    info "Then start alacritty to use your new setup!"
    echo ""
}

main "$@"

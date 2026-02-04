#!/usr/bin/env bash
# Common functions and variables used by all install scripts

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

# Check if command exists
has_cmd() {
    command -v "$1" &> /dev/null
}

# Detect OS and set PKG_MANAGER
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

    export OS PKG_MANAGER
    info "Detected OS: $OS (using $PKG_MANAGER)"
}

# Install packages with apt
apt_install() {
    sudo apt install -y "$@"
}

# Install packages with pacman
pacman_install() {
    sudo pacman -S --noconfirm --needed "$@"
}

# Install packages (auto-detect package manager)
pkg_install() {
    if [ "$PKG_MANAGER" = "apt" ]; then
        apt_install "$@"
    elif [ "$PKG_MANAGER" = "pacman" ]; then
        pacman_install "$@"
    fi
}

# Get the dotfiles directory (where this repo is located)
get_dotfiles_dir() {
    if [ -n "$DOTFILES_DIR" ]; then
        echo "$DOTFILES_DIR"
    else
        echo "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    fi
}

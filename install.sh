#!/usr/bin/env bash
#
# Dotfiles installation script
# Usage:
#   ./install.sh           # Install everything
#   ./install.sh core      # Install only core (zsh, oh-my-zsh)
#   ./install.sh terminal  # Install only terminal (alacritty, zellij, fonts)
#   ./install.sh dev       # Install only dev tools (gh, etc.)
#
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR

# Source common functions
source "$DOTFILES_DIR/scripts/common.sh"

# Available modules
MODULES=(core terminal dev apps ai)

show_help() {
    echo ""
    echo "Dotfiles Installation Script"
    echo ""
    echo "Usage: ./install.sh [module...]"
    echo ""
    echo "Modules:"
    echo "  core      - zsh, oh-my-zsh, essential CLI tools"
    echo "  terminal  - alacritty, zellij, fonts"
    echo "  dev       - GitHub CLI, Docker, development tools"
    echo "  apps      - Google Chrome, Spotify, desktop apps"
    echo "  ai        - Claude Code, pi (AI coding assistants)"
    echo "  all       - Install everything (default)"
    echo ""
    echo "Examples:"
    echo "  ./install.sh              # Install all modules"
    echo "  ./install.sh core         # Install only core"
    echo "  ./install.sh core dev     # Install core and dev"
    echo ""
}

run_module() {
    local module="$1"
    local script="$DOTFILES_DIR/scripts/${module}.sh"

    if [ -f "$script" ]; then
        source "$script"
        main
    else
        error "Module not found: $module"
    fi
}

# Main
main() {
    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║       Dotfiles Installation Script       ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""

    # Parse arguments
    local modules_to_run=()

    if [ $# -eq 0 ] || [ "$1" = "all" ]; then
        modules_to_run=("${MODULES[@]}")
    elif [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        show_help
        exit 0
    else
        modules_to_run=("$@")
    fi

    # Detect OS once
    detect_os
    echo ""

    # Run selected modules
    for module in "${modules_to_run[@]}"; do
        run_module "$module"
        echo ""
    done

    echo "╔══════════════════════════════════════════╗"
    echo "║         Installation Complete!           ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""
    info "Please restart your terminal or run: exec zsh"
    echo ""
}

main "$@"

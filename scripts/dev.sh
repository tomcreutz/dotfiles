#!/usr/bin/env bash
# Development tools: github-cli, docker, language toolchains, etc.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

install_github_cli() {
    info "Installing GitHub CLI..."

    if has_cmd gh; then
        success "GitHub CLI already installed"
        return
    fi

    if [ "$PKG_MANAGER" = "apt" ]; then
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt update
        apt_install gh
    elif [ "$PKG_MANAGER" = "pacman" ]; then
        pacman_install github-cli
    fi

    success "GitHub CLI installed"
}

install_docker() {
    info "Installing Docker..."

    if has_cmd docker; then
        success "Docker already installed"
    else
        if [ "$PKG_MANAGER" = "apt" ]; then
            # Install dependencies
            apt_install ca-certificates gnupg

            # Add Docker's official GPG key
            sudo install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
            sudo chmod a+r /etc/apt/keyrings/docker.gpg

            # Add the repository
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

            sudo apt update
            apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        elif [ "$PKG_MANAGER" = "pacman" ]; then
            pacman_install docker docker-compose
        fi

        success "Docker installed"
    fi

    # Post-install setup
    info "Configuring Docker..."

    # Add user to docker group
    if ! groups "$USER" | grep -q docker; then
        sudo usermod -aG docker "$USER"
        success "Added $USER to docker group (re-login required)"
    else
        success "User already in docker group"
    fi

    # Enable and start Docker service
    if ! systemctl is-enabled docker &> /dev/null; then
        sudo systemctl enable docker
        success "Docker service enabled"
    fi

    if ! systemctl is-active docker &> /dev/null; then
        sudo systemctl start docker
        success "Docker service started"
    else
        success "Docker service already running"
    fi
}

# Add more dev tools here as needed:
# install_node() { ... }
# install_rust() { ... }

# Main
main() {
    echo ""
    info "=== Development Tools Setup ==="
    echo ""

    [ -z "$PKG_MANAGER" ] && detect_os

    install_github_cli
    install_docker

    success "Development tools setup complete!"
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

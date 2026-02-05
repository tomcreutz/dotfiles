#!/usr/bin/env bash
# Development tools: github-cli, docker, language toolchains, etc.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Phase 1: Set up repos and queue packages for batch install
collect_dev() {
    info "=== Development Tools Setup (collecting packages) ==="

    if [ "$PKG_MANAGER" = "apt" ]; then
        # Set up GitHub CLI repo
        if [ ! -f /etc/apt/sources.list.d/github-cli.list ]; then
            info "Adding GitHub CLI apt repository..."
            curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
            sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        fi

        # Set up Docker repo
        if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
            info "Adding Docker apt repository..."
            sudo install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
            sudo chmod a+r /etc/apt/keyrings/docker.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        fi

        queue_pkg gh ca-certificates gnupg docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    elif [ "$PKG_MANAGER" = "pacman" ]; then
        queue_pkg github-cli docker docker-compose docker-buildx
    fi
}

# Phase 3: Post-install configuration
setup_dev() {
    echo ""
    info "=== Development Tools Setup (configuring) ==="
    echo ""

    # Docker post-install setup
    if has_cmd docker; then
        info "Configuring Docker..."

        # Add user to docker group
        if ! groups "$USER" | grep -q docker; then
            sudo usermod -aG docker "$USER"
            success "Added $USER to docker group (re-login required)"
        else
            success "User already in docker group"
        fi

        # On nftables systems (CachyOS/Arch), configure Docker to use nftables backend
        if [ ! -f /etc/docker/daemon.json ]; then
            sudo mkdir -p /etc/docker
            echo '{ "firewall-backend": "nftables" }' | sudo tee /etc/docker/daemon.json > /dev/null
            success "Configured Docker to use nftables backend"
        fi

        # Enable IP forwarding (required by Docker networking)
        if [ "$(sysctl -n net.ipv4.ip_forward 2>/dev/null)" != "1" ]; then
            sudo sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1
        fi
        if [ ! -f /etc/sysctl.d/docker.conf ]; then
            echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/docker.conf > /dev/null
            success "IP forwarding enabled"
        fi

        # Ensure containerd is running
        sudo systemctl unmask containerd.service 2>/dev/null || true
        if ! systemctl is-active containerd &> /dev/null; then
            sudo systemctl enable --now containerd.service
            success "containerd service started"
        fi

        # Enable and start Docker service
        if ! systemctl is-enabled docker &> /dev/null; then
            sudo systemctl enable docker
            success "Docker service enabled"
        fi

        if ! systemctl is-active docker &> /dev/null; then
            if ! sudo systemctl start docker; then
                warn "Docker failed on first attempt, clearing network state and retrying..."
                sudo rm -rf /var/lib/docker/network
                if ! sudo systemctl start docker; then
                    warn "Docker failed to start. Recent logs:"
                    journalctl -xeu docker.service --no-pager -n 15 2>/dev/null || true
                    return
                fi
            fi
            success "Docker service started"
        else
            success "Docker service already running"
        fi
    fi

    success "Development tools setup complete!"
}

# Run standalone if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    detect_os
    collect_dev
    system_update
    install_queued_packages
    setup_dev
fi

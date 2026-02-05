#!/usr/bin/env bash
# Desktop applications: browsers, media, productivity, etc.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Phase 1: Set up repos and queue packages for batch install
collect_apps() {
    info "=== Desktop Applications Setup (collecting packages) ==="

    if [ "$PKG_MANAGER" = "apt" ]; then
        # Set up Spotify repo
        if [ ! -f /etc/apt/sources.list.d/spotify.list ]; then
            info "Adding Spotify apt repository..."
            curl -sS https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
            echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list
        fi

        # Set up Element repo
        if [ ! -f /etc/apt/sources.list.d/element-io.list ]; then
            info "Adding Element apt repository..."
            sudo wget -O /usr/share/keyrings/element-io-archive-keyring.gpg https://packages.element.io/debian/element-io-archive-keyring.gpg
            echo "deb [signed-by=/usr/share/keyrings/element-io-archive-keyring.gpg] https://packages.element.io/debian/ default main" | sudo tee /etc/apt/sources.list.d/element-io.list
        fi

        queue_pkg spotify-client element-desktop gimp

    elif [ "$PKG_MANAGER" = "pacman" ]; then
        queue_pkg gimp
        queue_aur google-chrome spotify obsidian element-desktop zoom
    fi
}

# Phase 3: Post-install configuration (apt .deb installs that bypass repos)
setup_apps() {
    echo ""
    info "=== Desktop Applications Setup (configuring) ==="
    echo ""

    if [ "$PKG_MANAGER" = "apt" ]; then
        # Google Chrome (.deb download)
        if ! has_cmd google-chrome-stable && ! has_cmd google-chrome; then
            info "Installing Google Chrome..."
            curl -fsSL -o /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
            sudo apt install -y /tmp/google-chrome.deb
            rm /tmp/google-chrome.deb
            success "Google Chrome installed"
        else
            success "Google Chrome already installed"
        fi

        # Obsidian (.deb download)
        if ! has_cmd obsidian; then
            info "Installing Obsidian..."
            local latest_url
            latest_url=$(curl -s https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest | grep "browser_download_url.*amd64.deb" | cut -d '"' -f 4)
            curl -fsSL -o /tmp/obsidian.deb "$latest_url"
            sudo apt install -y /tmp/obsidian.deb
            rm /tmp/obsidian.deb
            success "Obsidian installed"
        else
            success "Obsidian already installed"
        fi

        # Zoom (.deb download)
        if ! has_cmd zoom; then
            info "Installing Zoom..."
            curl -fsSL -o /tmp/zoom.deb https://zoom.us/client/latest/zoom_amd64.deb
            sudo apt install -y /tmp/zoom.deb
            rm /tmp/zoom.deb
            success "Zoom installed"
        else
            success "Zoom already installed"
        fi
    fi

    success "Desktop applications setup complete!"
}

# Run standalone if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    detect_os
    collect_apps
    system_update
    install_queued_packages
    setup_apps
fi

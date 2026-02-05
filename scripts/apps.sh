#!/usr/bin/env bash
# Desktop applications: browsers, media, productivity, etc.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

install_google_chrome() {
    info "Installing Google Chrome..."

    if has_cmd google-chrome-stable || has_cmd google-chrome; then
        success "Google Chrome already installed"
        return
    fi

    if [ "$PKG_MANAGER" = "apt" ]; then
        curl -fsSL -o /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
        sudo apt install -y /tmp/google-chrome.deb
        rm /tmp/google-chrome.deb
    elif [ "$PKG_MANAGER" = "pacman" ]; then
        # Chrome is in AUR, requires AUR helper
        if has_cmd paru; then
            paru -S --noconfirm --needed google-chrome
        elif has_cmd yay; then
            yay -S --noconfirm --needed google-chrome
        else
            warn "Google Chrome requires an AUR helper (paru or yay). Skipping."
            return
        fi
    fi

    success "Google Chrome installed"
}

install_spotify() {
    info "Installing Spotify..."

    if has_cmd spotify; then
        success "Spotify already installed"
        return
    fi

    if [ "$PKG_MANAGER" = "apt" ]; then
        curl -sS https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
        echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list
        sudo apt update
        apt_install spotify-client
    elif [ "$PKG_MANAGER" = "pacman" ]; then
        # Spotify is in AUR
        if has_cmd paru; then
            paru -S --noconfirm --needed spotify
        elif has_cmd yay; then
            yay -S --noconfirm --needed spotify
        else
            warn "Spotify requires an AUR helper (paru or yay). Skipping."
            return
        fi
    fi

    success "Spotify installed"
}

install_obsidian() {
    info "Installing Obsidian..."

    if has_cmd obsidian; then
        success "Obsidian already installed"
        return
    fi

    if [ "$PKG_MANAGER" = "apt" ]; then
        # Download latest .deb from GitHub releases
        local latest_url
        latest_url=$(curl -s https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest | grep "browser_download_url.*amd64.deb" | cut -d '"' -f 4)
        curl -fsSL -o /tmp/obsidian.deb "$latest_url"
        sudo apt install -y /tmp/obsidian.deb
        rm /tmp/obsidian.deb
    elif [ "$PKG_MANAGER" = "pacman" ]; then
        # Obsidian is in AUR
        if has_cmd paru; then
            paru -S --noconfirm --needed obsidian
        elif has_cmd yay; then
            yay -S --noconfirm --needed obsidian
        else
            warn "Obsidian requires an AUR helper (paru or yay). Skipping."
            return
        fi
    fi

    success "Obsidian installed"
}

install_element() {
    info "Installing Element..."

    if has_cmd element-desktop; then
        success "Element already installed"
        return
    fi

    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo wget -O /usr/share/keyrings/element-io-archive-keyring.gpg https://packages.element.io/debian/element-io-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/element-io-archive-keyring.gpg] https://packages.element.io/debian/ default main" | sudo tee /etc/apt/sources.list.d/element-io.list
        sudo apt update
        apt_install element-desktop
    elif [ "$PKG_MANAGER" = "pacman" ]; then
        # Element is in AUR
        if has_cmd paru; then
            paru -S --noconfirm --needed element-desktop
        elif has_cmd yay; then
            yay -S --noconfirm --needed element-desktop
        else
            warn "Element requires an AUR helper (paru or yay). Skipping."
            return
        fi
    fi

    success "Element installed"
}

install_zoom() {
    info "Installing Zoom..."

    if has_cmd zoom; then
        success "Zoom already installed"
        return
    fi

    if [ "$PKG_MANAGER" = "apt" ]; then
        curl -fsSL -o /tmp/zoom.deb https://zoom.us/client/latest/zoom_amd64.deb
        sudo apt install -y /tmp/zoom.deb
        rm /tmp/zoom.deb
    elif [ "$PKG_MANAGER" = "pacman" ]; then
        # Zoom is in AUR
        if has_cmd paru; then
            paru -S --noconfirm --needed zoom
        elif has_cmd yay; then
            yay -S --noconfirm --needed zoom
        else
            warn "Zoom requires an AUR helper (paru or yay). Skipping."
            return
        fi
    fi

    success "Zoom installed"
}

install_gimp() {
    info "Installing GIMP..."

    if has_cmd gimp; then
        success "GIMP already installed"
        return
    fi

    if [ "$PKG_MANAGER" = "apt" ]; then
        apt_install gimp
    elif [ "$PKG_MANAGER" = "pacman" ]; then
        pacman_install gimp
    fi

    success "GIMP installed"
}

# Main
main() {
    echo ""
    info "=== Desktop Applications Setup ==="
    echo ""

    [ -z "$PKG_MANAGER" ] && detect_os

    install_google_chrome
    install_spotify
    install_obsidian
    install_element
    install_zoom
    install_gimp

    success "Desktop applications setup complete!"
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

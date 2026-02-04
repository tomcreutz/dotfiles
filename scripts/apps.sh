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

# Main
main() {
    echo ""
    info "=== Desktop Applications Setup ==="
    echo ""

    [ -z "$PKG_MANAGER" ] && detect_os

    install_google_chrome
    install_spotify

    success "Desktop applications setup complete!"
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

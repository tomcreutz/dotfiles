#!/usr/bin/env bash
# Fresh CachyOS Hyprland + Noctalia setup. Existing KDE systems should use the
# recovery-aware migration under migrations/cachyos-hyprland instead.

HYPRLAND_MODULE_ENABLED=false

collect_hyprland() {
    [ "$OS" = "cachyos" ] || return 0
    HYPRLAND_MODULE_ENABLED=true

    # CachyOS's installer may already have installed the bundle; --needed keeps
    # this idempotent. SilentSDDM is standalone and does not pull in Plasma.
    queue_pkg cachyos-hypr-noctalia sddm alacritty kate kcalc kwallet kwallet-pam
    queue_aur sddm-silent-theme
}

hyprland_profile() {
    case "$(hostnamectl --static 2>/dev/null || hostname)" in
        tomlaptop) printf 'tomlaptop\n' ;;
        *) printf 'generic\n' ;;
    esac
}

link_hyprland_config() {
    local name="$1" backup_root="$2"
    local source="$DOTFILES_DIR/config/$name"
    local target="$HOME/.config/$name"

    if [ -L "$target" ] && [ "$(readlink -f "$target")" = "$(readlink -f "$source")" ]; then
        success "$name config is already linked"
        return
    fi

    if [ -e "$target" ] || [ -L "$target" ]; then
        mkdir -p "$backup_root"
        mv "$target" "$backup_root/$name"
        warn "Moved existing $target to $backup_root/$name"
    fi

    ln -s "$source" "$target"
    success "Linked $target -> $source"
}

setup_hyprland() {
    $HYPRLAND_MODULE_ENABLED || return 0

    if ! pacman -Qq sddm-silent-theme &>/dev/null ||
       [ ! -f /usr/share/sddm/themes/silent/Main.qml ]; then
        error "SilentSDDM was not installed. Install an AUR helper, then rerun: ./install.sh hyprland"
    fi

    local profile backup_root
    profile="$(hyprland_profile)"
    backup_root="$HOME/.local/state/dotfiles/backups/hyprland-$(date +%Y%m%d-%H%M%S)"

    install -m 0644 \
        "$DOTFILES_DIR/migrations/cachyos-hyprland/profiles/$profile/machine.lua" \
        "$DOTFILES_DIR/config/hypr/config/machine.lua"
    install -m 0644 \
        "$DOTFILES_DIR/migrations/cachyos-hyprland/profiles/$profile/uwsm-env" \
        "$DOTFILES_DIR/config/uwsm/env.local"

    mkdir -p "$HOME/.config"
    link_hyprland_config hypr "$backup_root"
    link_hyprland_config noctalia "$backup_root"
    link_hyprland_config uwsm "$backup_root"

    sudo install -Dm 0644 "$DOTFILES_DIR/config/sddm/10-dotfiles-theme.conf" \
        /etc/sddm.conf.d/10-dotfiles-theme.conf

    if systemctl is-enabled --quiet sddm.service; then
        success "SDDM is enabled"
    elif [ ! -e /etc/systemd/system/display-manager.service ]; then
        sudo systemctl enable sddm.service
        success "Enabled SDDM"
    else
        warn "Another display manager is enabled; SilentSDDM is installed but inactive"
    fi

    success "Configured fresh CachyOS Hyprland profile: $profile"
    info "SilentSDDM's default preset will be used at the next SDDM start"
}

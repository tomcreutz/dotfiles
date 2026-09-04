#!/usr/bin/env bash
# Two-phase migration of an existing CachyOS desktop to Hyprland + Noctalia.
set -euo pipefail

MIGRATION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$MIGRATION_DIR/../.." && pwd)"
STATE_ROOT="$HOME/.local/state/dotfiles/migrations/cachyos-hyprland"
TARGETS=(.config/hypr .config/noctalia .config/uwsm)

info() { printf '\033[0;34m[INFO]\033[0m %s\n' "$*"; }
success() { printf '\033[0;32m[OK]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*" >&2; }
die() { printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
Usage:
  ./migrate.sh prepare [--profile tomlaptop|tom-desktop|generic]
  ./migrate.sh apply [--profile tomlaptop|tom-desktop|generic]
  ./migrate.sh verify

prepare  Creates and verifies a root snapshot plus a separate home-config
         recovery archive. Reboot-testing the Limine snapshot is recommended
         before apply.
apply    Installs the CachyOS bundle if needed, generates the selected machine
         profile, and links the managed configs. Plasma is retained.
verify   Checks package, profile, and config-link state after apply.
EOF
}

default_profile() {
    case "$(hostnamectl --static 2>/dev/null || hostname)" in
        tomlaptop)  printf 'tomlaptop\n' ;;
        tom-desktop) printf 'tom-desktop\n' ;;
        *)           printf 'generic\n' ;;
    esac
}

parse_profile() {
    PROFILE=""
    while (( $# > 0 )); do
        case "$1" in
            --profile)
                (( $# >= 2 )) || die "--profile requires a value"
                PROFILE="$2"
                shift 2
                ;;
            *) die "Unknown argument: $1" ;;
        esac
    done
    PROFILE="${PROFILE:-$(default_profile)}"
    [ -d "$MIGRATION_DIR/profiles/$PROFILE" ] || die "Unknown profile: $PROFILE"
}

require_cachyos() {
    # shellcheck disable=SC1091
    . /etc/os-release
    [ "${ID:-}" = "cachyos" ] || die "This migration supports CachyOS only"
    command -v pacman >/dev/null || die "pacman is required"
}

latest_state() {
    local latest="$STATE_ROOT/latest"
    [ -L "$latest" ] || die "No prepared recovery state found; run prepare first"
    readlink -f "$latest"
}

prepare() {
    parse_profile "$@"
    require_cachyos

    local stamp state list snapshot_id
    stamp="$(date +%Y%m%d-%H%M%S)"
    state="$STATE_ROOT/$stamp"
    mkdir -p "$state"

    printf '%s\n' "$PROFILE" > "$state/profile"
    pacman -Qq > "$state/packages-all.txt"
    pacman -Qqe > "$state/packages-explicit.txt"
    cp /etc/fstab "$state/fstab"

    # /home is a separate subvolume on the current CachyOS installation, so a
    # root snapshot cannot restore these user-level configuration paths.
    list="$state/home-config-files.list"
    : > "$list"
    : > "$state/home-config-absent.list"
    local target
    for target in "${TARGETS[@]}"; do
        if [ -e "$HOME/$target" ] || [ -L "$HOME/$target" ]; then
            printf '%s\0' "$target" >> "$list"
        else
            printf '%s\n' "$target" >> "$state/home-config-absent.list"
        fi
    done
    tar --acls --xattrs -cpf "$state/home-config.tar" -C "$HOME" \
        --null --files-from="$list"
    tar -tf "$state/home-config.tar" > "$state/home-config-archive.txt"

    command -v snapper >/dev/null || die "snapper is required for root recovery"
    info "Creating an important root snapshot (sudo required)..."
    snapshot_id="$(sudo snapper -c root create --type single \
        --description "Before KDE to Hyprland migration ($stamp)" \
        --cleanup-algorithm number --userdata important=yes --print-number)"
    printf '%s\n' "$snapshot_id" > "$state/root-snapshot-id"
    sudo snapper -c root list | awk -v id="$snapshot_id" '$1 == id { found=1 } END { exit !found }' \
        || die "Snapper did not list the new snapshot $snapshot_id"

    if systemctl is-enabled --quiet limine-snapper-sync.service; then
        success "Limine snapshot synchronization is enabled"
    else
        warn "limine-snapper-sync.service is not enabled; boot-menu recovery is not verified"
    fi

    ln -sfn "$state" "$STATE_ROOT/latest"
    success "Recovery state prepared at $state"
    info "Root snapshot ID: $snapshot_id"
    warn "Before apply, reboot and confirm snapshot $snapshot_id appears in Limine's Snapshots menu"
    warn "Copy $state to external storage to cover complete disk failure"
}

link_managed_config() {
    local name="$1" state="$2"
    local source="$DOTFILES_DIR/config/$name"
    local target="$HOME/.config/$name"

    if [ -L "$target" ] && [ "$(readlink -f "$target")" = "$(readlink -f "$source")" ]; then
        success "$name config is already linked"
        return
    fi

    if [ -e "$target" ] || [ -L "$target" ]; then
        mkdir -p "$state/replaced-home-config"
        mv "$target" "$state/replaced-home-config/$name"
        warn "Moved the existing $target into the recovery state"
    fi
    ln -s "$source" "$target"
    success "Linked $target -> $source"
}

apply() {
    parse_profile "$@"
    require_cachyos
    local state
    state="$(latest_state)"

    if [ -f "$state/profile" ] && [ "$(<"$state/profile")" != "$PROFILE" ]; then
        die "Prepared profile $(<"$state/profile") does not match requested profile $PROFILE"
    fi

    local packages=(alacritty kate kcalc kwallet kwallet-pam)
    if ! pacman -Qq cachyos-hypr-noctalia &>/dev/null; then
        info "Installing the official CachyOS Hyprland + Noctalia bundle..."
        warn "Pacman will replace cachyos-kde-settings, but Plasma remains installed"
        packages+=(cachyos-hypr-noctalia)
    else
        success "cachyos-hypr-noctalia is already installed"
    fi
    # Always use -Syu so this never creates an unsupported partial Arch update.
    sudo pacman -Syu --needed "${packages[@]}"

    if ! pacman -Qq sddm-silent-theme &>/dev/null; then
        info "Installing the standalone SilentSDDM theme..."
        if command -v paru &>/dev/null; then
            paru -S --needed sddm-silent-theme
        elif command -v yay &>/dev/null; then
            yay -S --needed sddm-silent-theme
        else
            die "SilentSDDM requires sddm-silent-theme from the AUR; install paru or yay first"
        fi
    else
        success "sddm-silent-theme is already installed"
    fi
    sudo install -Dm 0644 "$DOTFILES_DIR/config/sddm/10-dotfiles-theme.conf" \
        /etc/sddm.conf.d/10-dotfiles-theme.conf

    if ! command -v google-chrome-stable &>/dev/null; then
        if command -v paru &>/dev/null; then
            paru -S --needed google-chrome
        elif command -v yay &>/dev/null; then
            yay -S --needed google-chrome
        else
            warn "Google Chrome is configured but not installed; install it or change BROWSER"
        fi
    fi

    install -m 0644 "$MIGRATION_DIR/profiles/$PROFILE/machine.lua" \
        "$DOTFILES_DIR/config/hypr/config/machine.lua"
    install -m 0644 "$MIGRATION_DIR/profiles/$PROFILE/uwsm-env" \
        "$DOTFILES_DIR/config/uwsm/env.local"

    mkdir -p "$HOME/.config"
    link_managed_config hypr "$state"
    link_managed_config noctalia "$state"
    link_managed_config uwsm "$state"

    success "Applied profile: $PROFILE"
    info "Reboot, then select 'Hyprland (UWSM)' in SDDM"
    warn "Do not remove Plasma until the validation checklist passes"
}

verify() {
    require_cachyos
    local failed=0 name
    pacman -Qq cachyos-hypr-noctalia hyprland noctalia uwsm \
        xdg-desktop-portal-hyprland sddm-silent-theme >/dev/null || failed=1
    for name in hypr noctalia uwsm; do
        if [ ! -L "$HOME/.config/$name" ] || \
           [ "$(readlink -f "$HOME/.config/$name")" != "$(readlink -f "$DOTFILES_DIR/config/$name")" ]; then
            warn "$HOME/.config/$name is not linked to the managed config"
            failed=1
        fi
    done
    [ -f "$DOTFILES_DIR/config/hypr/config/machine.lua" ] || failed=1
    [ -f "$DOTFILES_DIR/config/uwsm/env.local" ] || failed=1
    if [ ! -f /usr/share/sddm/themes/silent/Main.qml ] ||
       [ ! -f /etc/sddm.conf.d/10-dotfiles-theme.conf ] ||
       ! grep -qx 'Current=silent' /etc/sddm.conf.d/10-dotfiles-theme.conf; then
        warn "SDDM is not configured to use SilentSDDM"
        failed=1
    fi
    (( failed == 0 )) || die "Migration verification failed"
    success "Migration files and packages are in place"
}

command="${1:-}"
[ -n "$command" ] || { usage; exit 2; }
shift
case "$command" in
    prepare) prepare "$@" ;;
    apply) apply "$@" ;;
    verify) verify "$@" ;;
    -h|--help|help) usage ;;
    *) usage; die "Unknown command: $command" ;;
esac

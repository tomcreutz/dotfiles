#!/usr/bin/env bash
# Restore only the home configuration captured by migrate.sh prepare.
# System packages/root are restored separately through the Limine snapshot.
set -euo pipefail

STATE_ROOT="$HOME/.local/state/dotfiles/migrations/cachyos-hyprland"
state="${1:-$STATE_ROOT/latest}"
state="$(readlink -f "$state")"
[ -d "$state" ] || { echo "Recovery state not found: $state" >&2; exit 1; }
[ -f "$state/home-config.tar" ] || { echo "Missing home-config.tar" >&2; exit 1; }

for target in .config/hypr .config/noctalia .config/uwsm; do
    rm -rf "$HOME/$target"
done

tar --acls --xattrs -xpf "$state/home-config.tar" -C "$HOME"
printf 'Restored pre-migration home configuration from %s\n' "$state"

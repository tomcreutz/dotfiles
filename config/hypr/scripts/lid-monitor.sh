#!/usr/bin/env bash
# Manage a laptop panel without breaking undocked lid-close/suspend behavior.
set -euo pipefail

panel="${1:?internal panel is required}"
mode="${2:-preferred}"
scale="${3:-1}"
action="${4:?expected close or open}"

case "$action" in
    close)
        # `hyprctl monitors -j` lists active monitors. Disable the panel only
        # when another output can take over its workspaces and windows.
        external_count="$({ hyprctl monitors -j || printf '[]'; } | python3 -c '
import json, sys
panel = sys.argv[1]
try:
    monitors = json.load(sys.stdin)
except json.JSONDecodeError:
    monitors = []
print(sum(m.get("name") != panel for m in monitors))
' "$panel")"
        if (( external_count > 0 )); then
            hyprctl keyword monitor "$panel,disable"
        fi
        ;;
    open)
        # `auto` lets Hyprland place the panel beside an attached dock monitor
        # rather than recreating a potentially overlapping fixed layout.
        hyprctl keyword monitor "$panel,$mode,auto,$scale"
        ;;
    *)
        printf 'Unknown lid action: %s\n' "$action" >&2
        exit 2
        ;;
esac

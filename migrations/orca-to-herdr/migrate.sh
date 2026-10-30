#!/usr/bin/env bash
# One-time cleanup: remove Orca and the old Herdr TUI (v0.x, `herdr`) together
# with everything they installed into agent configs. The new Herdr app
# (`herdr-app` + herdr-core/`hc`) is installed by `./install.sh ai`.
#
# Idempotent: safe to run again; missing items are skipped.
set -euo pipefail

info() { printf '\033[0;34m[INFO]\033[0m %s\n' "$*"; }
success() { printf '\033[0;32m[OK]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*" >&2; }

remove() {
    local path
    for path in "$@"; do
        if [ -e "$path" ] || [ -L "$path" ]; then
            rm -rf -- "$path"
            success "Removed $path"
        fi
    done
}

rmdir_if_empty() {
    local dir
    for dir in "$@"; do
        [ -d "$dir" ] && rmdir --ignore-fail-on-non-empty -- "$dir" 2>/dev/null || true
    done
}

stop_processes() {
    if pgrep -f 'Orca\.AppImage|orca-ide|/orcad' >/dev/null 2>&1; then
        info "Stopping Orca..."
        pkill -f 'Orca\.AppImage|orca-ide|/orcad' || true
        sleep 2
    fi
    if command -v herdr >/dev/null 2>&1 && pgrep -x herdr >/dev/null 2>&1; then
        info "Stopping the old Herdr TUI server..."
        herdr server stop >/dev/null 2>&1 || pkill -x herdr || true
        sleep 1
    fi
}

remove_orca() {
    info "Removing Orca..."
    remove \
        "$HOME/Applications/Orca.AppImage" \
        "$HOME/.config/orca" \
        "$HOME/.cache/orca" \
        "$HOME/.cache/orca-updater" \
        "$HOME/.orca"
    rmdir_if_empty "$HOME/Applications"

    local entry
    for entry in "$HOME"/.local/share/applications/*[Oo]rca*.desktop; do
        [ -e "$entry" ] && remove "$entry"
    done
    if [ -L "$HOME/.local/bin/orca" ]; then
        remove "$HOME/.local/bin/orca"
    fi

    # Orca's OpenCode status plugins (OpenCode itself is not managed here).
    local opencode="$HOME/.config/opencode"
    if [ -d "$opencode/plugins" ]; then
        for entry in "$opencode"/plugins/orca-*; do
            [ -e "$entry" ] && remove "$entry"
        done
    fi
    if [ -f "$opencode/tui.json" ] && command -v jq >/dev/null 2>&1; then
        local tmp
        tmp="$(mktemp)"
        jq '.plugin |= map(select(test("orca") | not)) | if .plugin == [] then del(.plugin) else . end' \
            "$opencode/tui.json" >"$tmp"
        if [ "$(jq -c . "$tmp")" = "{}" ]; then
            rm -f "$tmp"
            remove "$opencode/tui.json"
        else
            mv "$tmp" "$opencode/tui.json"
            success "Removed Orca plugin from $opencode/tui.json"
        fi
    fi
    rmdir_if_empty "$opencode/plugins" "$opencode"
}

remove_herdr_tui() {
    info "Removing the old Herdr TUI..."
    if [ -x "$HOME/.local/bin/herdr" ]; then
        remove "$HOME/.local/bin/herdr"
    fi
    remove \
        "$HOME/.config/herdr" \
        "$HOME/.local/state/herdr" \
        "$HOME/.claude/hooks/herdr-agent-state.sh"
    rmdir_if_empty "$HOME/.claude/hooks"
}

# Orca registers Claude Code hooks for every event, and the old Herdr TUI
# registered a SessionStart hook. Drop exactly those; keep everything else.
clean_claude_hooks() {
    local settings="$HOME/.claude/settings.json"
    [ -f "$settings" ] || return 0
    if ! command -v jq >/dev/null 2>&1; then
        warn "jq missing; remove Orca/Herdr hooks from $settings manually"
        return 0
    fi
    if ! grep -q -e 'ORCA_' -e 'herdr-agent-state' "$settings"; then
        return 0
    fi

    local backup tmp
    backup="$settings.backup-$(date +%Y%m%d%H%M%S)"
    tmp="$(mktemp)"
    cp "$settings" "$backup"
    jq '
      def foreign: (.command // "") | test("ORCA_|\\.orca/agent-hooks|herdr-agent-state");
      if .hooks then
        .hooks |= (
          with_entries(.value |= (map(.hooks |= map(select(foreign | not)))
                                  | map(select(.hooks | length > 0))))
          | with_entries(select(.value | length > 0))
        )
        | if .hooks == {} then del(.hooks) else . end
      else . end
    ' "$settings" >"$tmp"
    mv "$tmp" "$settings"
    success "Removed Orca/Herdr hooks from $settings (backup: $backup)"
}

stop_processes
remove_orca
remove_herdr_tui
clean_claude_hooks
success "Orca and the old Herdr TUI are gone. Install the Herdr app with: ./install.sh ai"

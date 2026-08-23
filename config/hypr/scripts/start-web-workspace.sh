#!/usr/bin/env bash
# Start Chrome before Obsidian so the browser becomes the first full-width
# column in workspace 1 and Obsidian is the next column to its right.
set -u

uwsm app -t service -- google-chrome-stable

for _ in $(seq 1 100); do
    if hyprctl clients -j 2>/dev/null | grep -q '"class": "google-chrome"'; then
        break
    fi
    sleep 0.1
done

exec uwsm app -t service -- obsidian

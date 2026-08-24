#!/usr/bin/env bash
# Initialize the UWSM/D-Bus environment and unlock KWallet with the password
# captured by SDDM before Noctalia or Element can activate an encrypted-storage
# backend and trigger a second password prompt.
set -u

dbus-update-activation-environment --systemd --all

if [ -n "${PAM_KWALLET5_LOGIN:-}" ] && [ -x /usr/lib/pam_kwallet_init ]; then
    timeout 5 /usr/lib/pam_kwallet_init || true

    # Credential delivery is asynchronous. Wait briefly for KWallet to own its
    # D-Bus name before clients request encrypted storage.
    for _ in $(seq 1 50); do
        busctl --user status org.kde.kwalletd6 >/dev/null 2>&1 && break
        sleep 0.1
    done
fi

uwsm app -t service -- noctalia
uwsm app -t service -- "$HOME/.config/hypr/scripts/start-web-workspace.sh"
uwsm app -t service -- alacritty --class Herdr -e "$HOME/.local/bin/herdr"
uwsm app -t service -- thunderbird
exec uwsm app -t service -- element-desktop --password-store=kwallet6

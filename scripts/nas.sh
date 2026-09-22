#!/usr/bin/env bash
# NAS shares: CIFS tooling, local credentials, mount point, and managed fstab entry.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

collect_nas() {
    info "=== NAS Share Setup (collecting packages) ==="
    queue_pkg cifs-utils
}

nas_credentials_exist() {
    local path="$1"
    [ -f "$path" ] || sudo test -f "$path" 2>/dev/null
}

find_existing_nas_credentials() {
    local preferred="$1"
    local candidate

    # The latter two paths were used by earlier manual setup instructions.
    # Reuse them in place so an existing secret is never read or overwritten.
    for candidate in \
        "$preferred" \
        "/etc/samba/credentials/nas-datasets" \
        "$HOME/.config/samba/nas-credentials"; do
        if nas_credentials_exist "$candidate"; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

create_nas_credentials() {
    local destination="$1"
    local username password password_confirmation credentials_tmp

    info "No existing NAS credentials file was found."
    while [ -z "${username:-}" ]; do
        IFS= read -r -p "NAS SMB username: " username
    done

    while true; do
        IFS= read -r -s -p "NAS SMB password: " password
        echo ""
        IFS= read -r -s -p "Confirm NAS SMB password: " password_confirmation
        echo ""

        if [ -z "$password" ]; then
            warn "Password cannot be empty"
        elif [ "$password" != "$password_confirmation" ]; then
            warn "Passwords do not match; try again"
        else
            break
        fi
    done

    credentials_tmp="$(mktemp)"
    chmod 600 "$credentials_tmp"
    printf 'username=%s\npassword=%s\n' "$username" "$password" > "$credentials_tmp"
    unset password password_confirmation

    if ! sudo install -D -o root -g root -m 0600 \
        "$credentials_tmp" "$destination"; then
        rm -f "$credentials_tmp"
        error "Could not install NAS credentials at $destination"
    fi
    rm -f "$credentials_tmp"

    success "Created local credentials file: $destination"
}

render_nas_fstab_entry() {
    local template="$1"
    local credentials_file="$2"

    sed \
        -e "s|{{SHARE}}|$NAS_DATASETS_SHARE|g" \
        -e "s|{{MOUNT_POINT}}|$NAS_DATASETS_MOUNT_POINT|g" \
        -e "s|{{CREDENTIALS_FILE}}|$credentials_file|g" \
        -e "s|{{UID}}|$(id -u)|g" \
        -e "s|{{GID}}|$(id -g)|g" \
        -e "s|{{SMB_VERSION}}|$NAS_DATASETS_SMB_VERSION|g" \
        "$template"
}

install_nas_fstab_entry() {
    local entry="$1"
    local begin_marker="# BEGIN dotfiles: nas-datasets"
    local end_marker="# END dotfiles: nas-datasets"
    local current_fstab new_fstab backup_path

    current_fstab="$(mktemp)"
    new_fstab="$(mktemp)"
    sudo cat /etc/fstab > "$current_fstab"

    # Remove a previous managed block and adopt any older, unmarked entry for
    # this mount point. Every other fstab line is retained byte-for-byte.
    awk \
        -v begin="$begin_marker" \
        -v end="$end_marker" \
        -v mount_point="$NAS_DATASETS_MOUNT_POINT" '
            $0 == begin { in_managed_block = 1; next }
            $0 == end { in_managed_block = 0; next }
            in_managed_block { next }
            $0 !~ /^[[:space:]]*#/ && $2 == mount_point { next }
            { print }
        ' "$current_fstab" > "$new_fstab"

    # Ensure the managed block starts on a new line without accumulating blank
    # lines on repeated installer runs.
    if [ -s "$new_fstab" ] && [ "$(tail -c 1 "$new_fstab" | wc -l)" -eq 0 ]; then
        printf '\n' >> "$new_fstab"
    fi
    printf '%s\n%s\n%s\n' "$begin_marker" "$entry" "$end_marker" >> "$new_fstab"

    if cmp -s "$current_fstab" "$new_fstab"; then
        success "NAS datasets fstab entry is already current"
        rm -f "$current_fstab" "$new_fstab"
        return 0
    fi

    if has_cmd findmnt && ! findmnt --verify --tab-file "$new_fstab" >/dev/null; then
        rm -f "$current_fstab" "$new_fstab"
        error "Generated fstab did not pass findmnt validation"
    fi

    backup_path="/etc/fstab.dotfiles-backup-$(date +%Y%m%d%H%M%S)"
    sudo cp -a /etc/fstab "$backup_path"
    sudo install -o root -g root -m 0644 "$new_fstab" /etc/fstab
    rm -f "$current_fstab" "$new_fstab"

    success "Installed NAS datasets entry in /etc/fstab"
    info "Previous fstab saved as $backup_path"
}

setup_nas() {
    echo ""
    info "=== NAS Share Setup (configuring) ==="
    echo ""

    local dotfiles_dir config_file fstab_template credentials_file fstab_entry automount_unit
    dotfiles_dir="$(get_dotfiles_dir)"
    config_file="$dotfiles_dir/config/nas/datasets.conf"
    fstab_template="$dotfiles_dir/config/nas/datasets.fstab"

    [ -f "$config_file" ] || error "Missing NAS config: $config_file"
    [ -f "$fstab_template" ] || error "Missing NAS fstab template: $fstab_template"

    # This tracked file contains only non-secret values.
    source "$config_file"
    : "${NAS_DATASETS_SHARE:?Missing NAS_DATASETS_SHARE}"
    : "${NAS_DATASETS_MOUNT_POINT:?Missing NAS_DATASETS_MOUNT_POINT}"
    : "${NAS_DATASETS_CREDENTIALS_FILE:?Missing NAS_DATASETS_CREDENTIALS_FILE}"
    : "${NAS_DATASETS_SMB_VERSION:?Missing NAS_DATASETS_SMB_VERSION}"

    if credentials_file="$(find_existing_nas_credentials "$NAS_DATASETS_CREDENTIALS_FILE")"; then
        success "Keeping existing NAS credentials file: $credentials_file"
    else
        credentials_file="$NAS_DATASETS_CREDENTIALS_FILE"
        create_nas_credentials "$credentials_file"
    fi

    sudo install -d -m 0755 "$NAS_DATASETS_MOUNT_POINT"
    fstab_entry="$(render_nas_fstab_entry "$fstab_template" "$credentials_file")"
    install_nas_fstab_entry "$fstab_entry"

    if has_cmd systemctl && has_cmd systemd-escape; then
        sudo systemctl daemon-reload
        automount_unit="$(systemd-escape --path --suffix=automount "$NAS_DATASETS_MOUNT_POINT")"
        if mountpoint -q "$NAS_DATASETS_MOUNT_POINT"; then
            success "NAS datasets share is already mounted at $NAS_DATASETS_MOUNT_POINT"
        elif sudo systemctl start "$automount_unit"; then
            success "NAS datasets automount is active at $NAS_DATASETS_MOUNT_POINT"
        else
            warn "Could not start $automount_unit; it will be retried after reboot"
        fi
    fi

    success "NAS share setup complete!"
}

# Run standalone if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    detect_os
    collect_nas
    system_update
    install_queued_packages
    setup_nas
fi

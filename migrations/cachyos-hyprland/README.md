# CachyOS KDE → Hyprland + Noctalia migration

This is a one-time migration for an existing CachyOS KDE installation. It is
not part of the normal dotfile installer. On a fresh OS installation, select
CachyOS's Hyprland + Noctalia desktop option and run `./install.sh hyprland`
instead; that module applies the managed profile and standalone SilentSDDM
without assuming Plasma was ever installed.

Available profiles:

- `tomlaptop`: ThinkPad T490, German keyboard, Intel compositor GPU, internal
  `eDP-1` panel, NVIDIA MX250 available for application offload
- `tom-desktop`: Ryzen 5 5600X, AMD Radeon RX 9070, and the LG ultrawide on
  `DP-2` at 3840×1600, 144 Hz, scale 1; additional outputs are automatic
- `generic`: automatic monitor selection and no forced GPU; safe fallback for
  an unknown CachyOS machine

Shared application defaults are Alacritty, Dolphin, Google Chrome, Kate, and
KCalc. Numbered workspaces use the Omarchy-style bindings.

The configuration started from `cachyos-hypr-noctalia` 1.2.5 and Noctalia v5.

## Why the session says “Hyprland (UWSM)”

UWSM means **Universal Wayland Session Manager**. Hyprland can run without it,
but the CachyOS configuration is built around it. UWSM wraps the compositor in
systemd user units and handles:

- session environment variables, including the selected compositor GPU
- XDG autostart applications
- propagating the Wayland/session environment to systemd and D-Bus services
- launching applications in appropriate systemd scopes with `uwsm app --`
- orderly application and compositor shutdown

It is therefore not a graphical shell or a second compositor. Noctalia is the
shell; Hyprland is the compositor; UWSM manages their login session lifecycle.
The managed keybindings use `uwsm app --`, so choose **Hyprland (UWSM)** in
SDDM rather than a non-UWSM Hyprland entry.

## 1. Prepare and verify recovery

This machine uses separate Btrfs subvolumes for `/` and `/home`. A root Snapper
snapshot alone does **not** back up the Hyprland/Noctalia user configuration.
The preparation phase therefore creates both:

1. an important Snapper snapshot of `/`, verified in Snapper; and
2. a tar archive of the affected paths in `/home`, plus installed-package
   manifests.

Run:

```bash
cd ~/dotfiles/migrations/cachyos-hyprland
./migrate.sh prepare   # auto-selects tomlaptop or tom-desktop by hostname
# Override detection or use the safe fallback if needed:
./migrate.sh prepare --profile generic
```

Recovery data is written below:

```text
~/.local/state/dotfiles/migrations/cachyos-hyprland/<timestamp>/
```

Both current CachyOS machines have Limine, `limine-snapper-sync`, Snapper, and
`snap-pac` installed. They also use separate Btrfs subvolumes for `/` and
`/home`. To verify boot recovery rather than merely assuming it works:

1. Note the snapshot ID printed by `prepare`.
2. Reboot before applying the migration.
3. Confirm that ID appears in Limine's **Snapshots** menu.
4. Ideally boot it once and confirm the existing Plasma system starts in
   read-only snapshot mode, then reboot into the normal system.

This gives a tested rollback path for software/configuration failure. It cannot
guarantee recovery from SSD failure, damaged EFI data, or loss of the entire
Btrfs filesystem because both copies are on the same disk. Copy the timestamped
recovery directory to external storage before continuing if those cases must be
covered.

## 2. Apply the migration

After testing recovery:

```bash
./migrate.sh apply
```

This performs a full update, ensures the selected applications are installed,
and adds the official `cachyos-hypr-noctalia` bundle only when it is missing.
If CachyOS installed the bundle with the OS, it is reused. The script then
generates the selected machine profile and links only:

- `~/.config/hypr`
- `~/.config/noctalia`
- `~/.config/uwsm`

Existing paths are moved into the timestamped recovery directory first. The
script deliberately does not copy all of `/etc/skel`, which could overwrite
KDE, GTK, Dolphin, and MIME settings.

The bundle conflicts with `cachyos-kde-settings`. Pacman may remove that preset
package, but it does not remove Plasma or the existing user KDE configuration.
That preset selected Breeze, which otherwise disappears with `plasma-desktop`
on fresh non-Plasma systems. The migration installs the standalone
`sddm-silent-theme` package and `/etc/sddm.conf.d/10-dotfiles-theme.conf`, using
SilentSDDM's default preset while keeping the Hyprland UWSM and Plasma session
choices available. SilentSDDM uses Qt6 but does not depend on Plasma; installing
it requires CachyOS's usual `paru` helper or another AUR helper such as `yay`.

Verify the applied files with:

```bash
./migrate.sh verify
```

Then reboot and select **Hyprland (UWSM)** in SDDM.

## Keybindings

| Action | Binding |
|---|---|
| Terminal | `Ctrl+Alt+T` or `Super+Return` |
| Launcher | `Super+Space` |
| Noctalia settings | `Super+Z` |
| Focus workspace 1–6 | `Super+1` … `Super+6` |
| Move window to workspace 1–6 | `Super+Shift+1` … `Super+Shift+6` |
| Close window | `Super+Q` |
| Lock | `Super+L` |
| Exit/session menu | `Super+Alt+C` |

`Ctrl+Alt+T` has no conflict in the CachyOS Hyprland bindings.

## Workspaces and login applications

| Workspace | Layout | Purpose | Applications started at login |
|---|---|---|---|
| 1 `web` | scrolling | Browser / research | Google Chrome, Obsidian |
| 2 `agents` | scrolling | Herdr / agents | Alacritty running Herdr |
| 3 `code` | scrolling | IDE / other work | — |
| 4 `chat` | master | Communication | Thunderbird, Element |
| 5 `misc` | dwindle | Miscellaneous | — |
| 6 `game` | default + fullscreen rules | Gaming | — |

All six workspaces are persistent and their short labels are visible in
Noctalia. Detected games are routed to workspace 6 and made fullscreen by the
existing game window rules; fullscreen is a window state, not a workspace
layout.

The applications above start from the `hyprland.start` hook in
`config/hypr/config/autostart.lua`, using `uwsm-app` in the same general style
as Omarchy Quattro. Workspace window rules place them after they appear. The
special `Herdr` Alacritty class routes only the login terminal to workspace 2;
normal terminals still open on the current workspace. Chrome starts before
Obsidian and both receive full-monitor-width scrolling columns, so `Super+Left`
and `Super+Right` reveal one application at a time.

Element is launched with `--password-store=kwallet6` because Electron cannot
infer the installed KWallet backend when the desktop identifier is `Hyprland`.
Before Noctalia or Element starts, `start-session-apps.sh` passes the login
password captured by SDDM's `pam_kwallet` module to KWallet. Plasma normally
performs that step through a KDE-only autostart service; doing it explicitly
prevents a second wallet password prompt in Hyprland while retaining encrypted
storage. Auto-unlock also requires the `kdewallet` password to match the account
login password; if it was changed independently, use KWalletManager once to
align it.

This is deterministic autostart, not complete desktop-session restoration.
Hyprland, Noctalia, UWSM, and Omarchy Quattro do not reconstruct every previous
window and its application contents after reboot. Instead:

- Chrome can restore tabs when **Settings → On startup → Continue where you
  left off** is enabled.
- Obsidian, Thunderbird, and Element retain their own application state.
- Starting `herdr` attaches to its persistent Herdr session.

Community Hyprland session-restoration tools exist, but they mostly record
application commands, workspace placement, and geometry. They cannot recover
unsaved content and can be unreliable with Electron or single-instance apps,
so none is enabled for the initial migration.

## Mouse and touchpad settings

Edit per-device sensitivity, acceleration, and natural scrolling in
`config/hypr/config/inputs.lua`; device names and machine-specific sensitivity
values live in the active machine profile. Find exact names with
`hyprctl devices`. Both machine profiles configure the shared MX Master when
its Bolt receiver is present; the laptop additionally configures only its
touchpad. Unrelated pointer devices keep the global fallback settings.

## Laptop docking and lid behavior

The laptop profile has one explicit rule for `eDP-1` and a catch-all rule for
USB-C/DisplayPort/HDMI outputs. External outputs therefore start in their
preferred mode with automatic placement instead of relying on a connector name
that may change between docks. This also covers the shared LG ultrawide: its
connector name can differ when video travels through the laptop's USB-C
DisplayPort-alt-mode path instead of directly from the desktop GPU. Keeping
`preferred` is intentional because the laptop/dock link may negotiate a lower
maximum refresh rate than the desktop's direct DisplayPort connection.

The `Lid Switch` bindings call
`~/.config/hypr/scripts/lid-monitor.sh`:

- **Close:** disable `eDP-1` only if another active monitor is already present.
  Hyprland moves its workspaces/windows to the remaining output. If undocked,
  the script leaves the panel configured and systemd's normal lid-suspend
  behavior remains available.
- **Open:** re-enable `eDP-1` with automatic placement, avoiding a fixed layout
  that overlaps the dock monitor.

For the reliable docking sequence, connect the USB-C dock and wait for its
monitor to appear before closing the lid. After first login, verify both names:

```bash
hyprctl monitors all
hyprctl devices        # switch should be named “Lid Switch”
```

Some firmware reports the `switch:on`/`switch:off` directions or switch name
differently. Test once before relying on closed-lid operation. If the event is
reversed, swap the `close` and `open` actions in `config/hypr/config/monitors.lua`.
Do not set `HandleLidSwitch=ignore` globally: doing so would also disable normal
undocked suspend behavior. The default `HandleLidSwitchDocked=ignore` works with
the conditional Hyprland handling.

## Why `xhost` is started

The CachyOS baseline runs:

```text
xhost +SI:localuser:root
```

This permits only the local root account—not every local user or remote host—to
connect to XWayland. It supports intentionally launched root GUI/X11 tools. It
was initially removed to reduce unnecessary X access, but has been restored to
stay compatible with the CachyOS defaults. It can be removed from
`config/hypr/config/autostart.lua` if root GUI applications are never used.

## Machine GPU behavior

### Laptop: Intel/NVIDIA PRIME offload

Aquamarine automatically selects Intel for the **compositor** because it is the
only KMS-capable GPU; the MX250 exposes no display connectors on the laptop.
The profile intentionally leaves `AQ_DRM_DEVICES` unset. Its PCI by-path name
contains colons, which this Aquamarine version mistakes for device-list
separators. Automatic selection avoids that startup failure without disabling
NVIDIA.

Normal applications use Intel by default. NVIDIA offload is explicit rather
than automatic in the general case:

```bash
prime-run application [arguments...]
```

For example, a Steam game's launch options can use:

```text
prime-run %command%
```

`prime-run` sets NVIDIA's PRIME render-offload environment variables for that
process. `switcheroo-control` is also installed and running; applications or
launchers that expose a “Launch using Discrete Graphics Card” action use the
same idea. If no such action is shown in Noctalia, use `prime-run` directly.
Do not globally enable the sample NVIDIA `GBM_BACKEND` variables: that would
force the entire session toward NVIDIA rather than offloading selected apps.

### Desktop: AMD Radeon

The desktop has one KMS-capable GPU, an AMD Radeon RX 9070, so Aquamarine's
automatic GPU selection is deterministic. Its profile intentionally leaves
`AQ_DRM_DEVICES` and driver overrides unset; the normal `amdgpu` and RADV stack
needs no NVIDIA-style session variables. The LG ultrawide advertises a 48–144
Hz adaptive-sync range. The shared Hyprland configuration enables VRR, so check
for flicker and game compatibility during validation; Plasma currently has VRR
disabled for this output.

## Validate before removing Plasma

Keep Plasma for several boots and verify:

- launcher, bar, notifications, lock, logout, suspend, and resume
- clipboard history after reboot (KWallet is installed)
- screenshots and screen sharing in Chrome, Zoom, and Element
- on the laptop: undocked lid close, dock detection, closed-lid use, reopening
  the lid, Intel default rendering, and `prime-run` for an NVIDIA application
- on the desktop: `DP-2` at 3840×1600 around 144 Hz and scale 1, AMD rendering,
  adaptive sync in games, and any additionally connected display
- the machine's applicable Wi-Fi/Ethernet, Bluetooth, audio, microphone, and
  media keys

Useful diagnostics:

```bash
hyprctl configerrors
hyprctl monitors all
systemctl --user --failed
journalctl --user -b -p warning
systemctl --user status xdg-desktop-portal.service \
  xdg-desktop-portal-hyprland.service
```

If Hyprland fails, return to SDDM and select Plasma.

## Roll back

For a session/configuration problem, select Plasma in SDDM first. To restore
the pre-migration user paths:

```bash
cd ~/dotfiles/migrations/cachyos-hyprland
./restore-home-config.sh
```

To restore the package/root state, boot the recorded snapshot from Limine's
**Snapshots** menu. It boots read-only and offers **Restore now**; follow the
confirmation prompts and reboot. Then run `restore-home-config.sh` because the
root snapshot does not include `/home`.

## Remove Plasma only after validation

Keep SDDM and KDE libraries required by Dolphin, Kate, KCalc, and KWallet.
Preview the installed Plasma-group removal set:

```bash
pacman -Qqg plasma |
  grep -vxE '^(kde-cli-tools|kwallet-pam|plasma-activities)$' |
  tee /tmp/plasma-removal.txt
xargs -r pacman -Rsp --print-format '%n' < /tmp/plasma-removal.txt
```

If the transaction is acceptable:

```bash
sudo xargs -r pacman -Rns -- < /tmp/plasma-removal.txt
```

Do not remove `sddm`, `dolphin`, `kate`, `kcalc`, `kwallet`, `kwallet-pam`,
`kde-cli-tools`, or anything required by `cachyos-hypr-noctalia`.

## Updating the managed defaults

CachyOS updates `/etc/skel`; it does not overwrite this repository. Compare
upstream changes before merging them:

```bash
meld /etc/skel/.config/hypr ~/dotfiles/config/hypr
meld /etc/skel/.config/noctalia ~/dotfiles/config/noctalia
```

Noctalia v5 is currently a beta package on this system. Review CachyOS and
Noctalia release notes before adopting major configuration changes.

## References

- [CachyOS Hyprland migration and configuration](https://wiki.cachyos.org/configuration/desktop_environments/hyprland/)
- [CachyOS Btrfs snapshot recovery](https://wiki.cachyos.org/configuration/btrfs_snapshots/)
- [Hyprland: systemd startup with UWSM](https://wiki.hypr.land/Useful-Utilities/Systemd-start/)
- [Hyprland switch bindings](https://wiki.hypr.land/Configuring/Basics/Binds/)
- [Hyprland multi-GPU configuration](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Multi-GPU/)

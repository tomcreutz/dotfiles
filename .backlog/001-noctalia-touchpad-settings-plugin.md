# 001 — Noctalia touchpad settings plugin

| Field | Value |
|---|---|
| Status | `planned` |
| Priority | medium |
| Created | 2026-08-23 |
| Owner | unassigned |
| Target | Noctalia v5 plugin API 24+, Hyprland 0.56+ |

## Objective

Add a local Noctalia plugin that lets the user change Hyprland touchpad
sensitivity from **Noctalia Settings → Plugins**, applies changes immediately,
and restores the setting after login, compositor reload, or touchpad hotplug.
Do not change the TrackPoint or external mice.

## Upstream research

Searched the current `noctalia-dev/noctalia` GitHub repository across open and
closed issues and pull requests for `touchpad`, `trackpad`, `libinput`,
`mouse sensitivity`, `pointer speed`, `input devices`, `input settings`, and
`accel_profile` on 2026-08-23.

No issue or PR was found for configuring compositor-level touchpad sensitivity.
Related results are different problems:

- [Issue #3911](https://github.com/noctalia-dev/noctalia/issues/3911) — slow
  touchpad/TrackPoint scrolling inside Noctalia Settings; open.
- [Issue #1331](https://github.com/noctalia-dev/noctalia/issues/1331) — older
  report of slow scrolling inside Noctalia Settings; closed.
- [PR #3482](https://github.com/noctalia-dev/noctalia/pull/3482) — wheel and
  touchpad scroll-event quantization for Noctalia widgets; closed.

The former `noctalia-dev/noctalia-shell` repository is retired; target the
current `noctalia-dev/noctalia` v5 plugin API.

## Product boundary

A plugin can declare typed settings that Noctalia renders under
**Settings → Plugins**. It cannot add a native top-level **Input Devices** page.
A native page would require an upstream Noctalia feature or fork.

Noctalia cannot dynamically hide a plugin's declarative settings page based on
hardware. To keep it absent on machines without a touchpad, only enable the
plugin when setup detects one. The service must still perform its own runtime
detection and safely do nothing if no touchpad exists.

## Proposed user experience

Initial scope:

- Plugin name: **Touchpad Settings**
- One `double` sensitivity control with range `-1.0` to `1.0`, default `0.0`
- Description explaining that negative values are slower and positive values
  are faster
- Changes take effect without logging out
- The plugin is enabled automatically only on machines with a touchpad

Keep the first version intentionally narrow. Acceleration profile,
natural scrolling, tap-to-click, disable-while-typing, and scroll factor can be
added later after the sensitivity path is proven.

## Architecture

### Tracked files

Create the plugin in the dotfiles, for example:

```text
config/noctalia/plugins/touchpad-settings/
├── plugin.toml
├── service.luau
└── translations/
    └── en.json
```

Use plugin id `tom/touchpad-settings` unless the implementer finds an existing
local naming convention.

Register `~/.config/noctalia/plugins` as a Noctalia `path` source, or install an
idempotent symlink into `$XDG_DATA_HOME/noctalia/plugins`. Prefer the path-source
workflow documented for Noctalia v5 so files remain owned by this repository.
Do not edit Noctalia's generated/runtime plugin copies.

### Manifest

Use the oldest compatible API that provides all required behavior. API 24 is a
suitable current baseline because it supports argument-array subprocess calls.
Declare:

- `hyprctl` as a dependency
- one plugin-level `double` setting named `sensitivity`
- `min = -1.0`, `max = 1.0`, `default = 0.0`
- a headless `[[service]]` entry
- English label and description translation keys

No custom QML is needed; use Noctalia v5's generated settings control.

### Service behavior

The service should:

1. Run `hyprctl devices -j` asynchronously.
2. Decode the JSON with Noctalia's JSON API.
3. Inspect pointer devices and select names containing `touchpad` or `trackpad`
   case-insensitively. Do not treat `trackpoint`, generic `elan`, or every mouse
   as a touchpad.
4. Read the typed value with `noctalia.getConfig("sensitivity")` and validate it
   is finite and within `[-1.0, 1.0]` even though the generated UI enforces the
   range.
5. Apply each detected touchpad with an argument-array subprocess equivalent to:

   ```bash
   hyprctl eval 'hl.device({ name = "DEVICE", sensitivity = VALUE })'
   ```

6. Escape the device name correctly before embedding it in Lua. Values from
   hardware names must never be concatenated unescaped into executable code.
7. Apply immediately at service startup and from `onConfigChanged()`.
8. Poll `hyprctl devices -j` at a modest interval (suggested: 3–5 seconds), with
   an in-flight guard so checks cannot overlap.
9. Compare each device's reported `defaultSpeed` with the desired value and only
   reapply when they differ. This recovers from Hyprland config reloads and
   touchpad hotplug without continuously issuing `hyprctl eval` calls.
10. Log a concise message when no touchpad is present; do not show recurring
    desktop notifications.
11. Log command errors with enough detail to diagnose a stale/missing Hyprland
    IPC environment, but keep retrying on the next interval.

Use `noctalia.runAsync({ ... }, callback)` rather than a shell command string.
No root privileges are required.

### Source of truth

The Noctalia plugin setting is the source of truth. The service reapplies it on
startup and whenever Hyprland reports a different speed. Do not also add a
fixed sensitivity value to `config/hypr/config/inputs.lua`, because a second
source of truth would cause reload-order conflicts.

The current global `accel_profile = "flat"` remains unchanged. The plugin must
only set per-touchpad sensitivity in its first version.

### Hardware-aware enablement

Extend the applicable migration/setup path to detect `ID_INPUT_TOUCHPAD=1`
through udev/sysfs. If detected:

1. Register the dotfiles plugin source idempotently.
2. Enable `tom/touchpad-settings` once Noctalia IPC is available.

If no touchpad is detected, leave the plugin installed/discoverable but
disabled. Runtime detection remains mandatory because devices and setup-time
environments can differ.

Do not modify Noctalia's state TOML directly. Use its documented plugin IPC or
show a one-time post-login command when Noctalia is not running during setup.

## Implementation steps

1. Re-read the current Noctalia v5 plugin manifest, entry-script, runtime API,
   and local path-source documentation before coding; beta APIs can change.
2. Confirm the installed Noctalia API range and exact plugin-source IPC syntax.
3. Scaffold `plugin.toml`, `service.luau`, and English translations.
4. Implement bounded value validation, device-name escaping, asynchronous
   detection, in-flight protection, and conditional application.
5. Run `noctalia plugins lint` against the plugin directory.
6. Register the local path source and enable the plugin in the live session.
7. Verify the sensitivity control appears under Settings → Plugins.
8. Test immediate application and persistence/recovery scenarios below.
9. Add idempotent plugin registration/enablement to the Hyprland migration or
   setup flow, guarded by touchpad detection.
10. Document plugin behavior, location, generated-state boundaries, and manual
    recovery in `migrations/cachyos-hyprland/README.md`.
11. Update this backlog item with implementation notes and set status to `done`
    only after every acceptance criterion passes.

## Acceptance criteria

- [ ] Noctalia displays a sensitivity control from `-1.0` to `1.0` under the
      plugin's settings.
- [ ] Changing the control changes the touchpad speed within one second.
- [ ] The ThinkPad device `synps/2-synaptics-touchpad` is detected.
- [ ] The `tpps/2-elan-trackpoint` speed remains unchanged.
- [ ] External mouse speeds remain unchanged.
- [ ] The chosen value survives a Noctalia restart and a logout/login.
- [ ] The chosen value is restored after `hyprctl reload` resets device config.
- [ ] A newly connected/recreated touchpad receives the setting automatically.
- [ ] With no touchpad, the service remains healthy, emits no recurring
      notification, and changes no pointer device.
- [ ] Missing Hyprland IPC produces a useful log entry and later recovers.
- [ ] The plugin passes `noctalia plugins lint`.
- [ ] Lua/Hyprland configuration verification and `git diff --check` pass.
- [ ] Setup is idempotent and does not edit generated Noctalia plugin copies or
      Noctalia state files directly.

## Manual validation commands

Run these from the active Hyprland/UWSM environment:

```bash
hyprctl devices -j | jq '.mice'
noctalia plugins lint ~/.config/noctalia/plugins/touchpad-settings
noctalia msg plugins list
journalctl --user -b | rg -i 'noctalia|touchpad-settings|hyprctl'
```

Record the touchpad and TrackPoint `defaultSpeed` values before and after moving
the slider. Reload Hyprland, then confirm the service restores only the
touchpad value.

## Risks and mitigations

- **Noctalia beta API changes:** target the installed API, lint, and keep plugin
  logic small.
- **False device detection:** match explicit `touchpad`/`trackpad` names and
  validate on both the ThinkPad touchpad and TrackPoint. Add udev-backed mapping
  later if hardware without those tokens is encountered.
- **Command injection through device names:** use argument-array process calls
  and an explicit Lua-string escaping function.
- **Conflicting configuration:** keep sensitivity out of static Hyprland config
  while the plugin owns it.
- **Compositor reload resets runtime values:** compare reported speed during the
  polling loop and reapply only on mismatch.
- **Noctalia unavailable during migration:** defer enablement to a documented
  post-login step rather than writing internal state files.

## Optional upstream follow-up

After the local plugin is validated, consider opening a Noctalia feature request
for a compositor-capability API or native input-device settings. Link the tested
plugin as a concrete prototype. Do not block the local implementation on an
upstream feature.

# Dotfiles

Personal dotfiles for Arch Linux (CachyOS) and Ubuntu systems.

## Quick Install

```bash
git clone https://github.com/tomcreutz/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

## Modular Installation

Install specific modules only:

```bash
./install.sh core      # zsh, oh-my-zsh, plugins
./install.sh terminal  # alacritty, zellij, fonts
./install.sh dev       # GitHub CLI, Docker, dev tools
./install.sh apps      # Chrome, Spotify, desktop apps
./install.sh ai        # Herdr, Claude Code, pi (AI coding tools)
./install.sh hyprland  # Fresh CachyOS Hyprland + Noctalia configuration
./install.sh all       # Everything (default)

# Multiple modules
./install.sh core terminal
```

## What's Included

### Core (`scripts/core.sh`)
- **zsh** - Shell
- **oh-my-zsh** - Zsh framework
- **zsh-autosuggestions** - Fish-like autosuggestions
- **zsh-syntax-highlighting** - Syntax highlighting

### Terminal (`scripts/terminal.sh`)
- **alacritty** - GPU-accelerated terminal (Snap on Ubuntu/Debian for a current release)
- **zellij** - Terminal multiplexer
- **JetBrainsMono Nerd Font** - Programming font with icons

### Dev Tools (`scripts/dev.sh`)
- **GitHub CLI** (`gh`) - GitHub from the command line
- **Docker** - Container runtime (includes docker-compose, post-install setup)

### Desktop Apps (`scripts/apps.sh`)
- **Google Chrome** - Web browser
- **Spotify** - Music streaming
- **Obsidian** - Note-taking and knowledge base
- **Element** - Matrix chat client
- **Zoom** - Video conferencing
- **GIMP** - Image editor
- **Thunderbird** - Email client

### Hyprland Desktop (`scripts/hyprland.sh`)
- Reuses CachyOS's Hyprland + Noctalia bundle from a fresh OS installation
- Links the managed Hyprland, Noctalia, and UWSM configurations
- Generates the matching laptop or generic machine profile
- Installs standalone SilentSDDM with its default preset; Plasma is not required

### AI Coding Tools (`scripts/ai.sh`)
- **Herdr** - Agent runtime, with zsh configured for new panes
  - Installs declared plugins and links their configs from `config/herdr/plugins/`
  - Includes `jhochenbaum/herdr-hunk-diff` with automatic review opening
- **Claude Code** - Anthropic's AI coding assistant CLI
- **pi** - AI coding agent (pi.dev)
  - Links shared config from `config/pi/agent/`
  - Installs extension packages listed in `config/pi/agent/settings.json`
  - Does **not** sync secrets or state (`auth.json`, `sessions/`, `cache/`, `trust.json`, installed `npm/`/`git/` package caches)

## Desktop migrations

Desktop-environment changes are one-time migrations rather than normal dotfile
installation modules. For moving an existing CachyOS KDE system to Hyprland and
Noctalia, see [`migrations/cachyos-hyprland/`](migrations/cachyos-hyprland/).
A fresh CachyOS installation should use CachyOS's Hyprland + Noctalia installer
option, then run `./install.sh hyprland`. The module installs SilentSDDM from the
AUR using `paru` or `yay`, links the desktop configs, and does not require a
prior Plasma installation.

## Structure

```
dotfiles/
├── install.sh          # Main installer
├── scripts/
│   ├── common.sh       # Shared functions
│   ├── core.sh         # Shell setup
│   ├── terminal.sh     # Terminal apps
│   ├── dev.sh          # Dev tools
│   ├── apps.sh         # Desktop apps
│   ├── ai.sh           # AI coding tools
│   └── hyprland.sh     # Fresh CachyOS Hyprland/Noctalia setup
├── migrations/
│   └── cachyos-hyprland/ # Existing KDE system migration
└── config/
    ├── alacritty/      # Alacritty config
    ├── herdr/          # Herdr config
    ├── pi/             # pi settings, models, extensions, prompts, skills, themes
    ├── hypr/           # Hyprland Lua configuration
    ├── noctalia/       # Noctalia v5 configuration
    ├── uwsm/           # Wayland session environment
    ├── zellij/         # Zellij config
    └── zsh/            # Zsh config
```

## Supported Systems

- **Arch Linux** / CachyOS / EndeavourOS / Manjaro (pacman/paru/yay)
- **Ubuntu** / Debian (apt)

## TODO

- [ ] **Consider migrating to [chezmoi](https://www.chezmoi.io/)** for advanced features:
  - Secret management via password managers (1Password, Bitwarden, pass)
  - Machine-specific config templating
  - Encrypted file support
  - Built-in diff/merge tools

  Current shell-based approach is simple and dependency-free, but chezmoi would
  provide better secret handling and cross-machine configuration management.

## License

MIT

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
./install.sh ai        # Claude Code, pi (AI assistants)
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
- **alacritty** - GPU-accelerated terminal
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

### AI Coding Assistants (`scripts/ai.sh`)
- **Claude Code** - Anthropic's AI coding assistant CLI
- **pi** - AI coding agent (pi.dev)

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
│   └── ai.sh           # AI coding assistants
└── config/
    ├── alacritty/      # Alacritty config
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

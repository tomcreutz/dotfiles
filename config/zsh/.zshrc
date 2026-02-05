# Path to oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Theme (robbyrussell is the default, agnoster is popular with nerd fonts)
ZSH_THEME="robbyrussell"

# Plugins
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    command-not-found
    history
    sudo
)

# Load oh-my-zsh
source $ZSH/oh-my-zsh.sh

# User configuration

# Preferred editor
export EDITOR='vim'

# Aliases
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'

# Zellij aliases
alias zj='zellij'
alias zja='zellij attach'
alias zjl='zellij list-sessions'

# History settings
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE

# Better directory navigation
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS

# Case insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Load local config if exists (loaded early so it can set ZELLIJ_AUTO_START=0)
[ -f ~/.zshrc.local ] && source ~/.zshrc.local

# Auto-start zellij
# - First terminal: creates session "main"
# - Additional terminals: shows session picker (attach or create new)
# - Skipped in VSCode, when already in zellij, or non-interactive shells
# - Disable by setting ZELLIJ_AUTO_START=0 in ~/.zshrc.local
if [[ "$ZELLIJ_AUTO_START" != "0" ]] && [[ -z "$ZELLIJ" ]] && command -v zellij &>/dev/null && [[ -o interactive ]] && [[ "$TERM_PROGRAM" != "vscode" ]]; then
    if [[ -z "$(zellij list-sessions 2>/dev/null)" ]]; then
        zellij attach -c main
    else
        zellij
    fi
fi

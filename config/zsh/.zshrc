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

# npm global packages in user directory (avoids sudo for npm install -g)
export npm_config_prefix="$HOME/.local"
export PATH="$HOME/.local/bin:$PATH"

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
# Skipped when:
#   - Already inside zellij ($ZELLIJ is set)
#   - Non-interactive shell
#   - Inside VSCode terminal
#   - SSH from localhost (prevents recursion)
#   - Zellij not installed
#   - ZELLIJ_AUTO_START=0 in ~/.zshrc.local
#
# Set ZELLIJ_AUTO_EXIT=true to exit shell when zellij exits
_zellij_auto_start() {
    [[ "$ZELLIJ_AUTO_START" == "0" ]] && return
    [[ -n "$ZELLIJ" ]] && return
    [[ ! -o interactive ]] && return
    command -v zellij &>/dev/null || return
    [[ "$TERM_PROGRAM" == "vscode" ]] && return

    # Skip SSH from localhost (prevents infinite recursion)
    if [[ -n "$SSH_CONNECTION" ]]; then
        local ssh_source="${SSH_CONNECTION%% *}"
        [[ "$ssh_source" == "127."* || "$ssh_source" == "::1" ]] && return
    fi

    if [[ "${ZELLIJ_AUTO_EXIT:-false}" == "true" ]]; then
        exec zellij
    else
        zellij
    fi
}
_zellij_auto_start
unset -f _zellij_auto_start

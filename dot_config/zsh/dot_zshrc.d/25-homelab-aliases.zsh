# ██╗  ██╗ ██████╗ ███╗   ███╗███████╗██╗      █████╗ ██████╗
# ██║  ██║██╔═══██╗████╗ ████║██╔════╝██║     ██╔══██╗██╔══██╗
# ███████║██║   ██║██╔████╔██║█████╗  ██║     ███████║██████╔╝
# ██╔══██║██║   ██║██║╚██╔╝██║██╔══╝  ██║     ██╔══██║██╔══██╗
# ██║  ██║╚██████╔╝██║ ╚═╝ ██║███████╗███████╗██║  ██║██████╔╝
# ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═════╝
# Minimal aliases for homelab and remote shells.
#

[[ "${ZSH_HOMELAB_MINIMAL:-0}" == 1 ]] || return 0

# Listing; 80-eza.zsh replaces these with eza-backed functions when available.
alias ls='ls --color=auto'
alias l='ls -CF'
alias ll='ls -lh'
alias la='ls -lah'
alias lt='ls -lahtr'

alias grep='grep --color=auto'
alias h='history'
alias path='print -l ${(s/:/)PATH}'

# Safety defaults.
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Navigation.
alias cdp='cd "$PROJECTS"'
alias dots='cd "$DOTFILES"'
alias homelab='cd "${HOMELAB:-$HOME/homelab}"'

# Chezmoi.
alias czs='chezmoi status'
alias czd='chezmoi diff'
alias czdr='chezmoi apply --dry-run --verbose'
alias cza='chezmoi apply'
alias cze='chezmoi edit'
alias czcd='cd "$(chezmoi source-path)"'

# Git.
alias g='git'
alias ga='git add'
alias gaa='git add --all'
alias gb='git branch'
alias gbd='git branch --delete'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gc='git commit --verbose'
alias gcmsg='git commit --message'
alias gd='git diff'
alias gds='git diff --staged'
alias gf='git fetch'
alias gl='git pull'
alias gp='git push'
alias gst='git status'
alias gss='git status --short'
alias gsb='git status --short --branch'
alias gsw='git switch'
alias gswc='git switch --create'

# Mise.
alias miseup='mise up && mise prune --yes'

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

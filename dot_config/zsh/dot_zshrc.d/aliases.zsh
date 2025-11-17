# ███████╗███████╗██╗  ██╗
# ╚══███╔╝██╔════╝██║  ██║
#   ███╔╝ ███████╗███████║
#  ███╔╝  ╚════██║██╔══██║
# ███████╗███████║██║  ██║
# ╚══════╝╚══════╝╚═╝  ╚═╝
# Z Shell - powerful command interpreter.
#

#!/usr/bin/env zsh

#############
#  Aliases  #
#############

# List declared aliases, functions, paths
alias paths='echo -e ${PATH//:/\\n}'
alias aliases='alias | sed "s/=.*//"'
alias functions='declare -f | grep "^[a-z].* ()" | sed "s/{$//"'

# Navigate to projects root
alias cdp='cd /home/rmiller/projects'

# Quick navigation to repos
alias cdn='cd $HOME/projects/ndn'
alias cdapi='cd $HOME/projects/api-gateway'
alias cdcdn='cd $HOME/projects/cdn-service'

# Run command in all repos
function dhgitall() {
    for dir in /home/rmiller/projects/*/; do
        (cd "$dir" && echo "=== $(basename $dir) ===" && git "$@")
    done
}

# Has package
alias has='curl -sL https://git.io/_has | bash -s '

# CD Shortcuts
alias dh='cd $DHSPACE'
alias dots='cd $DOTFILES'
alias notes='cd ~/vaults/'

# Edit configs
alias nrc='${=EDITOR} $XDG_CONFIG_HOME/nvim/init.lua'
alias vrc='${=EDITOR} $XDG_CONFIG_HOME/vim/vimrc'
alias wrc='${=EDITOR} $XDG_CONFIG_HOME/wezterm/wezterm.lua'
alias zrc='${=EDITOR} ${ZDOTDIR:-$HOME}/.zshrc'
alias zenv='${=EDITOR} $HOME/.zshenv'
alias zpro='${=EDITOR} ${ZDOTDIR:-$HOME}/.zprofile'

# Edit aliases
alias aliasrc='${=EDITOR} $ZDOTDIR/.zshrc.d/aliases.zsh'

# Mac
alias macupdate='sudo softwareupdate -i -a'

# Brew
alias brewupdate='brew update && brew upgrade && brew cleanup'

# Mise
alias miseupdate='mise up'

# ASDF
alias asdfplugadd='cut -d" " -f1 $ASDF_DEFAULT_TOOL_VERSIONS_FILENAME|xargs -i asdf plugin add  {}'
alias asdfupdate='asdf update --head && asdf plugin update --all'

# Zplug
alias zplugupdate='zplug update && zplug install && zplug clean && zplug clear'

# ZSH
alias ztrace="zsh -ixc : 2>&1"
alias ztime="time ZSH_DEBUG=1 zsh -i -c exit"
alias zbench='$XDG_DATA_HOME/zsh-bench/zsh-bench'

# LDE
alias ldelog='lde logs -ftall '

# Stow
alias stowdir='stow --no-folding --dotfiles --verbose=1 -R -t ~ '
alias unstowdir='stow --verbose=1 -D '

# Nvim
alias vi='${=EDITOR}'
alias vim='${=EDITOR}'

# Git
alias gg='git grep -E'

# SSH
alias rotatekeys='source $HOME/ssh-key-manager.sh && rotate_keys'
alias displaykeys='source $HOME/ssh-key-manager.sh && display_public_keys'

# Arduino
alias ard='arduino-cli'
alias ardc='arduino-cloud-cli'

# Wget
alias wget='wget --hsts-file=$XDG_CACHE_HOME/wget/wget-hsts'

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

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
alias notes='cd ~/notes'

# Chezmoi
alias czs='chezmoi status'                          # what's changed
alias czd='chezmoi diff'                            # preview changes
alias czdr='chezmoi apply --dry-run --verbose'      # dry run with detail
alias cza='chezmoi apply'                           # apply changes
alias cze='chezmoi edit'                            # edit a managed file
alias czcd='cd $(chezmoi source-path)'              # jump to source dir

# Edit configs
alias nrc='${=EDITOR} $XDG_CONFIG_HOME/nvim/init.lua'
alias vrc='${=EDITOR} $XDG_CONFIG_HOME/vim/vimrc'
alias wrc='${=EDITOR} $XDG_CONFIG_HOME/wezterm/wezterm.lua'
alias strc='${=EDITOR} $XDG_CONFIG_HOME/starship/starship.toml'
alias zrc='${=EDITOR} ${ZDOTDIR:-$HOME}/.zshrc'
alias zenv='${=EDITOR} $HOME/.zshenv'
alias zpro='${=EDITOR} ${ZDOTDIR:-$HOME}/.zprofile'

# Edit aliases
alias aliasrc='${=EDITOR} $ZDOTDIR/.zshrc.d/aliases.zsh'

# Mac
alias macup='sudo softwareupdate -i -a'

# Brew
alias brewup='brew update && brew upgrade && brew cleanup'

# Mise
alias miseup='mise up && mise prune --yes'

# ASDF
alias asdfplugadd='cut -d" " -f1 $ASDF_DEFAULT_TOOL_VERSIONS_FILENAME|xargs -i asdf plugin add  {}'
alias asdfup='asdf update --head && asdf plugin update --all'

# Zplug
alias zplugup='zplug update && zplug install && zplug clean && zplug clear'

# ZSH
alias ztrace="zsh -ixc : 2>&1"
alias ztime="time ZSH_DEBUG=1 zsh -i -c exit"
alias zbench='$XDG_DATA_HOME/zsh-bench/zsh-bench'

# LDE
alias ldelog='lde logs -ftall '

# Obsidian / Notes (requires obsidian CLI: Settings → General → Command line interface)
alias n='obsidian'                                 # obsidian CLI
alias nd='obsidian daily'
alias nt='obsidian tasks daily'                    # list today's tasks
alias ntags='obsidian tags counts'                 # all tags with frequency
alias norphans='obsidian orphans'                  # notes with no backlinks
alias nunresolved='obsidian unresolved'            # broken wikilinks
alias nhome='obsidian open file=HOME'              # open home dashboard
alias ninbox='obsidian open file="00 Inbox"'       # open inbox

# Nvim
vi() { ${=EDITOR} "$@" }
vim() { ${=EDITOR} "$@" }

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

# Build (parallel)
alias make="make -j$(nproc)"
alias ninja="ninja -j$(nproc)"
alias nj="ninja"

# Arch/Pacman
alias update="sudo pacman -Syu"
alias rmpkg="sudo pacman -Rsn"
alias cleanch="sudo pacman -Scc"
alias fixpacman="sudo rm /var/lib/pacman/db.lck"
alias cleanup='sudo pacman -Rsn $(pacman -Qtdq)'

# Journalctl errors
alias jctl="journalctl -p 3 -xb"

# Recent installed packages
alias rip="expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -200 | nl"

# XDG compliance
alias svn="svn --config-dir \${XDG_CONFIG_HOME:-\$HOME/.config}/subversion"

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

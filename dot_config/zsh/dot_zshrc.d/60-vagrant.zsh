# ███████╗███████╗██╗  ██╗
# ╚══███╔╝██╔════╝██║  ██║
#   ███╔╝ ███████╗███████║
#  ███╔╝  ╚════██║██╔══██║
# ███████╗███████║██║  ██║
# ╚══════╝╚══════╝╚═╝  ╚═╝
# Z Shell - powerful command interpreter.
#

#!/usr/bin/env zsh

(( $+commands[vagrant] )) || return 1

export ZSH_THEME_VAGRANT_PROMPT_PREFIX="%{$fg_bold[blue]%}["
export ZSH_THEME_VAGRANT_PROMPT_SUFFIX="%{$fg_bold[blue]%}]%{$reset_color%} "
export ZSH_THEME_VAGRANT_PROMPT_RUNNING="%{$fg_no_bold[green]%}●"
export ZSH_THEME_VAGRANT_PROMPT_POWEROFF="%{$fg_no_bold[red]%}●"
export ZSH_THEME_VAGRANT_PROMPT_SUSPENDED="%{$fg_no_bold[yellow]%}●"
export ZSH_THEME_VAGRANT_PROMPT_NOT_CREATED="%{$fg_no_bold[white]%}○"

vagrant_prompt_info() {
  # check if this is a vagrant environment
  if [[ ! -f vagrantfile ]]; then
    return
  fi

  if (( $+commands[starship] )); then
    # get the vagrant state
    local state
    state=$(vagrant status --machine-readable | awk -f, '$3 == "state-human-short" { print $4 }')

    # map the state to symbols
    case "$state" in
      running)
        echo "󰄾 running"
        ;;
      poweroff)
        echo "󰤄 powered off"
        ;;
      "not created")
        echo " not created"
        ;;
      *)
        echo "󰘔 unknown"
        ;;
    esac
    return
  fi

  local vm_states vm_state
  vm_states=(${(f)"$(vagrant status 2> /dev/null | sed -nE 's/^[^ ]* *([[:alnum:] ]*) \([[:alnum:]_]+\)$/\1/p')"})
  printf '%s' $ZSH_THEME_VAGRANT_PROMPT_PREFIX
  for vm_state in $vm_states; do
    case "$vm_state" in
      running) printf '%s' $ZSH_THEME_VAGRANT_PROMPT_RUNNING ;;
      "not running"|poweroff) printf '%s' $ZSH_THEME_VAGRANT_PROMPT_POWEROFF ;;
      paused|saved|suspended) printf '%s' $ZSH_THEME_VAGRANT_PROMPT_SUSPENDED ;;
      "not created") printf '%s' $ZSH_THEME_VAGRANT_PROMPT_NOT_CREATED ;;
    esac
  done
  printf '%s' $ZSH_THEME_VAGRANT_PROMPT_SUFFIX
}

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

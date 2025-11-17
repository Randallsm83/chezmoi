# ███████╗███████╗██╗  ██╗
# ╚══███╔╝██╔════╝██║  ██║
#   ███╔╝ ███████╗███████║
#  ███╔╝  ╚════██║██╔══██║
# ███████╗███████║██║  ██║
# ╚══════╝╚══════╝╚═╝  ╚═╝
# Z Shell - powerful command interpreter.
#

#!/usr/bin/env zsh

export STARSHIP_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/starship/starship.toml"
export STARSHIP_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/starship"

eval "$(starship init zsh)"

(( $+commands[starship] )) || return 1

if [[ ! -f "$ZSH_CACHE_DIR/completions/_starship" ]]; then
  typeset -g -A _comps
  autoload -Uz _starship
  _comps[starship]=_starship
fi

starship completions zsh >| "$ZSH_CACHE_DIR/completions/_starship" &|

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

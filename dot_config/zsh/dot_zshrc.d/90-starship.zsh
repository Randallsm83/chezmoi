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

# Check if starship exists BEFORE trying to init
# Avoid Windows path pollution from /mnt/*
if (( $+commands[starship] )) && [[ "$(command -v starship)" != /mnt/* ]]; then
  eval "$(starship init zsh)"
else
  return 0
fi

# Generate completions if starship is available and cache dir exists
if (( $+commands[starship] )) && [[ -n "$ZSH_CACHE_DIR" ]]; then
  [[ -d "$ZSH_CACHE_DIR/completions" ]] || mkdir -p "$ZSH_CACHE_DIR/completions"
  if [[ ! -f "$ZSH_CACHE_DIR/completions/_starship" ]]; then
    typeset -g -A _comps
    autoload -Uz _starship
    _comps[starship]=_starship
  fi
  starship completions zsh >| "$ZSH_CACHE_DIR/completions/_starship" &|
fi

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

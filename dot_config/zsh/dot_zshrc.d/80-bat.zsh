#!/usr/bin/env zsh

export BAT_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/bat"

(( $+commands[bat] )) || return 1

if [[ ! -f "$ZSH_CACHE_DIR/completions/_bat" ]]; then
  typeset -g -A _comps
  autoload -Uz _bat
  _comps[bat]=_bat
fi

bat --completion zsh >| "$ZSH_CACHE_DIR/completions/_bat" &|

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#

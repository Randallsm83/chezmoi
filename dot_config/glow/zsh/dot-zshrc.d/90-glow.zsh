#!/usr/bin/env zsh

(( $+commands[glow] )) || return 1

if [[ ! -f "$ZSH_CACHE_DIR/completions/_glow" ]]; then
  typeset -g -A _comps
  autoload -Uz _glow
  _comps[glow]=_glow
fi

glow completion zsh >| "$ZSH_CACHE_DIR/completions/_glow" &|

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

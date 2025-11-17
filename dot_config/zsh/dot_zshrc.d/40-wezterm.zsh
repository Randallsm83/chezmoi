#!/usr/bin/env zsh

[[ -x "${XDG_CONFIG_HOME:-$HOME/.config}/wezterm/wezterm.sh" ]] && source "${XDG_CONFIG_HOME:-$HOME/.config}/wezterm/wezterm.sh"

(( $+commands[wezterm] )) || return 1

if [[ ! -f "$ZSH_CACHE_DIR/completions/_wezterm" ]]; then
  typeset -g -A _comps
  autoload -Uz _wezterm
  _comps[wezterm]=_wezterm
fi

wezterm shell-completion --shell zsh >| "$ZSH_CACHE_DIR/completions/_wezterm" &|

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

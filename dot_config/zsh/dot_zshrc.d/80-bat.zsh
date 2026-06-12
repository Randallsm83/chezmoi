# ██████╗  █████╗ ████████╗
# ██╔══██╗██╔══██╗╚══██╔══╝
# ██████╔╝███████║   ██║
# ██╔══██╗██╔══██║   ██║
# ██████╔╝██║  ██║   ██║
# ╚═════╝ ╚═╝  ╚═╝   ╚═╝
# A cat(1) clone with wings.
#

#!/usr/bin/env zsh

export BAT_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/bat"

(( $+commands[bat] )) || return 1

_bat_comp="$ZSH_CACHE_DIR/completions/_bat"
if [[ ! -f "$_bat_comp" ]]; then
  typeset -g -A _comps
  autoload -Uz _bat
  _comps[bat]=_bat
fi

if [[ ! -s "$_bat_comp" || "${commands[bat]}" -nt "$_bat_comp" ]]; then
  bat --completion zsh >| "$_bat_comp" &|
fi
unset _bat_comp

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#

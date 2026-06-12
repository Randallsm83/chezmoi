# ██████╗ ██╗██████╗  ██████╗ ██████╗ ███████╗██████╗
# ██╔══██╗██║██╔══██╗██╔════╝ ██╔══██╗██╔════╝██╔══██╗
# ██████╔╝██║██████╔╝██║  ███╗██████╔╝█████╗  ██████╔╝
# ██╔══██╗██║██╔═══╝ ██║   ██║██╔══██╗██╔══╝  ██╔═══╝
# ██║  ██║██║██║     ╚██████╔╝██║  ██║███████╗██║
# ╚═╝  ╚═╝╚═╝╚═╝      ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝
# Line-oriented search tool that recursively searches.
#

#!/usr/bin/env zsh

_ripgreprc="${XDG_CONFIG_HOME:-$HOME/.config}/ripgrep/ripgreprc"
[[ -f "$_ripgreprc" ]] && export RIPGREP_CONFIG_PATH="$_ripgreprc"
export ENV_DIRS="$ENV_DIRS:${_ripgreprc:h}"
unset _ripgreprc

(( $+commands[rg] )) || return 1

_rg_comp="$ZSH_CACHE_DIR/completions/_rg"
if [[ ! -f "$_rg_comp" ]]; then
  typeset -g -A _comps
  autoload -Uz _rg
  _comps[rg]=_rg
fi

if [[ ! -s "$_rg_comp" || "${commands[rg]}" -nt "$_rg_comp" ]]; then
  rg --generate complete-zsh >| "$_rg_comp" &|
fi
unset _rg_comp

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

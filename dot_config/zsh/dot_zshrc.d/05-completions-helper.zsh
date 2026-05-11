#  ██████╗ ██████╗ ███╗   ███╗██████╗ ██╗     ███████╗████████╗██╗ ██████╗ ███╗   ██╗███████╗
# ██╔════╝██╔═══██╗████╗ ████║██╔══██╗██║     ██╔════╝╚══██╔══╝██║██╔═══██╗████╗  ██║██╔════╝
# ██║     ██║   ██║██╔████╔██║██████╔╝██║     █████╗     ██║   ██║██║   ██║██╔██╗ ██║███████╗
# ██║     ██║   ██║██║╚██╔╝██║██╔═══╝ ██║     ██╔══╝     ██║   ██║██║   ██║██║╚██╗██║╚════██║
# ╚██████╗╚██████╔╝██║ ╚═╝ ██║██║     ███████╗███████╗   ██║   ██║╚██████╔╝██║ ╚████║███████║
#  ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═╝     ╚══════╝╚══════╝   ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝
# Shell completion definitions.
#

#!/usr/bin/env zsh
# Shared helpers for generating/caching zsh completion files under
# $ZSH_COMPLETION_DIR (see 10-dirs.zsh for where that's defined).
#
# Two helpers are provided, both async (`&|`) so they never block shell
# startup and both idempotent (guarded on command existence + cache file
# presence). First use pre-registers the completion with compinit so it's
# live in the current shell without waiting for the async write.
#
# Usage:
#   _gen_completion_runtime <cmd> <args...>
#       Runs `<cmd> <args...>` and writes stdout to
#       $ZSH_COMPLETION_DIR/_<cmd>. Use for tools that self-print their
#       zsh completion (bat, rg, gh, mise, delta, ...).
#
#   _gen_completion_upstream <cmd> <url>
#       curl -fsSL the URL to $ZSH_COMPLETION_DIR/_<cmd> if the file is
#       missing. Use for tools that don't self-print (eza, fd, ...).

# Defensive fallback in case 10-dirs.zsh hasn't run yet (e.g. reordering).
: ${ZSH_CACHE_DIR:="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"}
: ${ZSH_COMPLETION_DIR:="$ZSH_CACHE_DIR/completions"}

# Ensure _comps is populated for <name> (harmless if compinit already did it).
_gen_completion_register() {
  local name="$1"
  typeset -g -A _comps
  [[ -n "${_comps[$name]-}" ]] && return 0
  autoload -Uz "_$name" 2>/dev/null
  _comps[$name]="_$name"
}

_gen_completion_runtime() {
  emulate -L zsh
  local name="$1"; shift
  (( $+commands[$name] )) || return 0
  local outfile="$ZSH_COMPLETION_DIR/_$name"
  [[ -d "$ZSH_COMPLETION_DIR" ]] || mkdir -p "$ZSH_COMPLETION_DIR"
  _gen_completion_register "$name"
  "$name" "$@" >| "$outfile" 2>/dev/null &|
}

_gen_completion_upstream() {
  emulate -L zsh
  local name="$1" url="$2"
  (( $+commands[$name] )) || return 0
  local outfile="$ZSH_COMPLETION_DIR/_$name"
  [[ -d "$ZSH_COMPLETION_DIR" ]] || mkdir -p "$ZSH_COMPLETION_DIR"
  _gen_completion_register "$name"
  [[ -f "$outfile" ]] && return 0
  (( $+commands[curl] )) || return 0
  ( curl -fsSL "$url" -o "$outfile" 2>/dev/null ) &|
}

return 0

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#

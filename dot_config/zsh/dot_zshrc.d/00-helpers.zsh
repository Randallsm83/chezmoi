# ██╗  ██╗███████╗██╗     ██████╗ ███████╗██████╗ ███████╗
# ██║  ██║██╔════╝██║     ██╔══██╗██╔════╝██╔══██╗██╔════╝
# ███████║█████╗  ██║     ██████╔╝█████╗  ██████╔╝███████╗
# ██╔══██║██╔══╝  ██║     ██╔═══╝ ██╔══╝  ██╔══██╗╚════██║
# ██║  ██║███████╗███████╗██║     ███████╗██║  ██║███████║
# ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝     ╚══════╝╚═╝  ╚═╝╚══════╝
# Internal helper utilities.
#

# Helper Functions
# OS detection utilities for use in other config files

# Check if running on macOS
is-macos() {
  [[ "$OSTYPE" == darwin* ]]
}

# Check if running in WSL
is-wsl() {
  [[ -n "$WSL_DISTRO_NAME" ]] || grep -qi microsoft /proc/version 2>/dev/null
}

# Source a tool's shell-init output from a version-keyed cache, regenerating
# only when the tool binary is newer than the cache. Avoids a subprocess spawn
# on every interactive startup while still tracking upstream init output (same
# contract as a bare `eval "$(<tool> init zsh)"`, just cached). Mirrors the
# long-standing fzf integration cache.
#   Usage: zsh_cache_eval <cache-name> <command> [args...]
# The command is resolved via $commands (no fork) and skipped if absent.
zsh_cache_eval() {
  local name=$1; shift
  local bin=${commands[$1]}
  [[ -n "$bin" ]] || return 0
  local cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/init/${name}.zsh"
  if [[ ! -s "$cache" || "$bin" -nt "$cache" ]]; then
    [[ -d "${cache:h}" ]] || mkdir -p "${cache:h}"
    "$@" >| "$cache" 2>/dev/null
    zcompile "$cache"
  elif [[ ! -f "$cache.zwc" || "$cache" -nt "$cache.zwc" ]]; then
    zcompile "$cache"
  fi
  source "$cache"
}
# Starship-specific variant of zsh_cache_eval that inlines the continuation
# prompt into the cached init script. `starship init zsh` otherwise emits
# `PROMPT2="$(starship prompt --continuation)"`, which spawns Starship once at
# source time on every shell. The continuation prompt is static for a given
# Starship binary + config, so we can precompute it when (re)building the cache
# and source the same final script thereafter.
zsh_cache_starship_init() {
  local bin=${commands[starship]}
  [[ -n "$bin" ]] || return 0
  local cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/init/starship-init-inline.zsh"
  local needs_regen=0
  if [[ ! -s "$cache" || "$bin" -nt "$cache" ]]; then
    needs_regen=1
  elif [[ -n "${STARSHIP_CONFIG:-}" && -f "$STARSHIP_CONFIG" && "$STARSHIP_CONFIG" -nt "$cache" ]]; then
    needs_regen=1
  fi
  if (( needs_regen )); then
    [[ -d "${cache:h}" ]] || mkdir -p "${cache:h}"
    local prompt2 escaped line
    prompt2="$("$bin" prompt --continuation 2>/dev/null)"
    escaped=${prompt2//\\/\\\\}
    escaped=${escaped//\"/\\\"}
    "$bin" init zsh 2>/dev/null | while IFS= read -r line; do
      if [[ "$line" == PROMPT2=* ]]; then
        print -r -- "PROMPT2=\"$escaped\""
      else
        print -r -- "$line"
      fi
    done >| "$cache"
    zcompile "$cache"
  elif [[ ! -f "$cache.zwc" || "$cache" -nt "$cache.zwc" ]]; then
    zcompile "$cache"
  fi
  source "$cache"
}

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

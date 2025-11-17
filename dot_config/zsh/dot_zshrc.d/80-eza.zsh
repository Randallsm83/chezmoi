# ███████╗███████╗██╗  ██╗
# ╚══███╔╝██╔════╝██║  ██║
#   ███╔╝ ███████╗███████║
#  ███╔╝  ╚════██║██╔══██║
# ███████╗███████║██║  ██║
# ╚══════╝╚══════╝╚═╝  ╚═╝
# Z Shell - powerful command interpreter.
#

#!/usr/bin/env zsh
# eza integration with layered config support

[[ $TERM == 'dumb' ]] && return 1

# Ensure LS_COLORS is loaded from vivid if generated
: ${XDG_CONFIG_HOME:=${HOME}/.config}
if [ -z "$LS_COLORS" ] && [ -f "$XDG_CONFIG_HOME/lscolors/${VIVID_THEME:-one-dark}.txt" ]; then
  export LS_COLORS="$(< "$XDG_CONFIG_HOME/lscolors/${VIVID_THEME:-one-dark}.txt")"
fi

_has() { command -v "$1" >/dev/null 2>&1; }

_eza_flags_file() {
  local base="$XDG_CONFIG_HOME/eza"
  for f in "flags.${HOST}.txt" "flags.zsh.txt" "flags.local.txt" "flags.txt"; do
    [ -f "$base/$f" ] && { printf '%s' "$base/$f"; return; }
  done
  printf '%s' "$base/flags.txt"
}

_eza_build_flags() {
  local f="$(_eza_flags_file)"
  local flags=()
  if [ -f "$f" ]; then
    # Read flags, skip comments and empty lines
    while IFS= read -r line; do
      [[ "$line" =~ ^[[:space:]]*# ]] && continue
      [[ -z "${line//[[:space:]]/}" ]] && continue
      flags+=("$line")
    done < "$f"
  fi
  [ -n "$EZA_DISABLE_GDF" ] && flags=(${flags:#--group-directories-first})
  [ -n "$EZA_FLAGS_EXTRA" ] && flags+=(${=EZA_FLAGS_EXTRA})
  echo "${(j: :)flags}"
}

if _has eza; then
  ls() { command eza $(_eza_build_flags) -- "$@"; }
  ll() { command eza $(_eza_build_flags) -l -- "$@"; }
  la() { command eza $(_eza_build_flags) -la -- "$@"; }
  lt() { command eza $(_eza_build_flags) --tree -- "$@"; }
else
  print "eza not found. Install with mise: mise use -g cargo:eza" >&2
  return 1
fi

return 0

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#

# Modern Rust-based replacements for traditional Unix tools
# These shadow the legacy command names so muscle memory works
# Use `command <original>` to bypass (e.g. `command find`)
#

#!/usr/bin/env zsh

# =============================================================================
# Rust CLI Shadow Aliases
# =============================================================================
# Each alias only activates if the Rust tool is installed

# sed -> sd
(( $+commands[sd] )) && alias sed=sd

# du -> dust
(( $+commands[dust] )) && alias du=dust

# find -> fd
(( $+commands[fd] )) && alias find=fd

# diff -> delta
(( $+commands[delta] )) && alias diff=delta

# cloc/sloccount -> tokei
(( $+commands[tokei] )) && alias cloc=tokei

# time/bench -> hyperfine
if (( $+commands[hyperfine] )); then
  alias bench=hyperfine
fi

# http/https -> xh
if (( $+commands[xh] )); then
  alias http=xh
  alias https='xh --https'
fi

# compress/decompress -> ouch
if (( $+commands[ouch] )); then
  alias compress='ouch compress'
  alias decompress='ouch decompress'
fi

# tldr -> tealdeer (binary is already named tldr)
(( $+commands[tldr] )) && alias help=tldr

# ps -> procs
(( $+commands[procs] )) && alias ps=procs

# =============================================================================
# Inventory Function
# =============================================================================

# List all installed Rust CLI alternatives and what they replace
function rust-tools() {
  local -a tools
  tools=(
    'bat:cat:bat'
    'ripgrep:grep:rg'
    'fd:find:fd'
    'eza:ls:eza'
    'delta:diff:delta'
    'zoxide:cd:zoxide'
    'vivid:dircolors:vivid'
    'tealdeer:tldr/man:tldr'
    'navi:cheatsheets:navi'
    'sd:sed:sd'
    'dust:du:dust'
    'procs:ps/top:procs'
    'hyperfine:time/benchmark:hyperfine'
    'just:make (tasks):just'
    'tokei:cloc/sloccount:tokei'
    'ouch:tar/zip/compress:ouch'
    'xh:curl (HTTP):xh'
  )

  local installed=0
  local total=${#tools}

  for entry in "${tools[@]}"; do
    local name="${entry%%:*}"
    local rest="${entry#*:}"
    local replaces="${rest%%:*}"
    local binary="${rest#*:}"

    if (( $+commands[$binary] )); then
      printf '\033[32m✓ %-22s → %-22s (%s)\033[0m\n' "$name" "$replaces" "$binary"
      (( installed++ ))
    else
      printf '\033[31m✗ %-22s → %-22s (%s)\033[0m\n' "$name" "$replaces" "$binary"
    fi
  done

  echo ""
  printf '\033[36m%d/%d Rust alternatives installed\033[0m\n' "$installed" "$total"
}

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 e

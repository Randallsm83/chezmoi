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
# (( $+commands[sd] )) && alias sed=sd  # sd is NOT drop-in for sed (different syntax)

# du -> dust
# (( $+commands[dust] )) && alias du=dust  # dust is NOT drop-in for du (different flags)

# find -> fd
# (( $+commands[fd] )) && alias find=fd  # fd is NOT drop-in for find (different syntax)

# diff -> delta
# (( $+commands[delta] )) && alias diff=delta  # delta is NOT drop-in for diff

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
# (( $+commands[procs] )) && alias ps=procs  # procs is NOT drop-in for ps

# =============================================================================
# Inventory Function
# =============================================================================

# Check if a command is active as an alias, function, or the binary itself
_rust_cmd_active() {
  local cmd=$1 binary=$2
  [[ "$cmd" == "$binary" ]] && (( $+commands[$binary] )) && return 0
  (( $+aliases[$cmd] )) && return 0
  (( $+functions[$cmd] )) && return 0
  return 1
}

# List all installed Rust CLI alternatives and what they replace
# Format: 'pkg_name:replaces:binary:invoke_cmds'
# invoke_cmds: comma-separated commands that invoke the tool
#   green = alias/function active, red = not yet configured
#   empty = use binary name directly (no aliases set up)
function rust-tools() {
  local -a tools=(
    'bat:cat:bat:cat'
    'ripgrep:grep:rg:'
    'fd:find:fd:'
    'eza:ls:eza:ls,ll,la,lt'
    'delta:diff:delta:'
    'zoxide:cd:zoxide:z'
    'vivid:dircolors:vivid:'
    'tealdeer:tldr/man:tldr:tldr,help'
    'navi:cheatsheets:navi:'
    'sd:sed:sd:'
    'dust:du:dust:'
    'procs:ps/top:procs:'
    'hyperfine:time/benchmark:hyperfine:bench'
    'just:make (tasks):just:'
    'tokei:cloc/sloccount:tokei:cloc'
    'ouch:tar/zip/compress:ouch:compress,decompress'
    'xh:curl (HTTP):xh:http,https'
  )

  local installed=0
  local total=${#tools}

  for entry in "${tools[@]}"; do
    local name="${entry%%:*}"
    local rest="${entry#*:}"
    local replaces="${rest%%:*}"
    local rest2="${rest#*:}"
    local binary="${rest2%%:*}"
    local invoke_str="${rest2#*:}"

    if (( $+commands[$binary] )); then
      printf '\033[32m✓\033[0m %-22s → %-22s \033[90m(%s)\033[0m' "$name" "$replaces" "$binary"
      (( installed++ ))
      if [[ -n "$invoke_str" ]]; then
        local invoke_cmds=(${(s:,:)invoke_str})
        printf '  '
        for cmd in "${invoke_cmds[@]}"; do
          if _rust_cmd_active "$cmd" "$binary"; then
            printf '\033[32m%s\033[0m ' "$cmd"
          else
            printf '\033[31m%s\033[0m ' "$cmd"
          fi
        done
      fi
    else
      printf '\033[31m✗\033[0m %-22s → %-22s \033[90m(%s)\033[0m' "$name" "$replaces" "$binary"
    fi
    printf '\n'
  done

  echo ""
  printf '\033[36m%d/%d Rust alternatives installed\033[0m\n' "$installed" "$total"
  printf '\033[90mInvoke: \033[32mgreen\033[90m = active alias, \033[31mred\033[90m = not configured\033[0m\n'
}

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 e

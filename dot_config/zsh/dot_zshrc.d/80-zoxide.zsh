# Smarter cd command - learns your habits
# https://github.com/ajeetdsouza/zoxide
#

#!/usr/bin/env zsh

(( $+commands[zoxide] )) || return 1

# =============================================================================
# Environment Configuration (XDG compliant)
# =============================================================================

export _ZO_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zoxide"
[[ -d "$_ZO_DATA_DIR" ]] || mkdir -p "$_ZO_DATA_DIR"

# Echo the matched directory before navigating (0 = off, 1 = on)
export _ZO_ECHO=0

# Directories to exclude from database (colon-separated on Unix)
export _ZO_EXCLUDE_DIRS="$HOME:/tmp:/var/tmp"

# Maximum total age of entries in database (default: 10000)
export _ZO_MAXAGE=10000

# Resolve symlinks before adding to database (0 = off, 1 = on)
export _ZO_RESOLVE_SYMLINKS=0

# =============================================================================
# Fzf Integration
# =============================================================================

if (( $+commands[fzf] )); then
  export _ZO_FZF_OPTS="${FZF_DEFAULT_OPTS} --height=40% --layout=reverse --border --info=inline --preview='command ls -1A --color=always {2..}' --preview-window=right:50%:wrap"
fi

# =============================================================================
# Initialization - replaces cd with zoxide
# =============================================================================

eval "$(zoxide init zsh --cmd cd)"

# =============================================================================
# Helper Functions
# =============================================================================

# Clean up stale entries (directories that no longer exist)
function zclean() {
  (( $+commands[zoxide] )) || { echo "zoxide is not installed" >&2; return 1; }

  local removed=0
  while IFS= read -r dir; do
    if [[ ! -d "$dir" ]]; then
      zoxide remove "$dir"
      echo "Removed: $dir"
      (( removed++ ))
    fi
  done < <(zoxide query --list)

  if (( removed == 0 )); then
    echo "No stale entries found."
  else
    echo "\nRemoved $removed stale entries."
  fi
}

# Show zoxide statistics
function zstats() {
  (( $+commands[zoxide] )) || { echo "zoxide is not installed" >&2; return 1; }

  local db_path="$_ZO_DATA_DIR/db.zo"
  if [[ -f "$db_path" ]]; then
    local db_size=$(du -h "$db_path" | cut -f1)
    echo "Database: $db_path"
    echo "Size: $db_size"
  fi

  echo "\nTop 15 directories by frecency:"
  zoxide query --list --score | head -15
}

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et


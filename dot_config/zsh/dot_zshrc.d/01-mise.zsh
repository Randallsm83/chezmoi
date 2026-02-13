# Early mise initialization for WSL
# Sets env vars BEFORE config discovery - actual activation in 50-mise.zsh
if [[ -n "$WSL_DISTRO_NAME" ]] || grep -qiE "(microsoft|wsl)" /proc/version 2>/dev/null; then
  export MISE_DATA_DIR="$HOME/.local/share/mise"
  export MISE_CONFIG_DIR="$HOME/.config/mise"
  export MISE_CACHE_DIR="$HOME/.cache/mise"
  export MISE_STATE_DIR="$HOME/.local/state/mise"
  # CRITICAL: early-init settings - must be env vars, NOT in mise.toml
  export MISE_IGNORED_CONFIG_PATHS="/mnt/c:/mnt/d"
  export MISE_CEILING_PATHS="/mnt"
  # cd to HOME if starting in /mnt/* (Windows filesystem is very slow)
  [[ "$PWD" == /mnt/* ]] && cd "$HOME"
fi

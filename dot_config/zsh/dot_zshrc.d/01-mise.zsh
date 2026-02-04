# ███████╗███████╗██╗  ██╗
# ╚══███╔╝██╔════╝██║  ██║
#   ███╔╝ ███████╗███████║
#  ███╔╝  ╚════██║██╔══██║
# ███████╗███████║██║  ██║
# ╚══════╝╚══════╝╚═╝  ╚═╝
# Z Shell - powerful command interpreter.
#

#!/usr/bin/env zsh

# Initialize mise (formerly rtx)
# In WSL, ensure we use Linux paths, not Windows paths via /mnt/c
if [[ -n "$WSL_DISTRO_NAME" ]] || grep -qiE "(microsoft|wsl)" /proc/version 2>/dev/null; then
  export MISE_DATA_DIR="$HOME/.local/share/mise"
  export MISE_CONFIG_DIR="$HOME/.config/mise"
  export MISE_CACHE_DIR="$HOME/.cache/mise"
  export MISE_STATE_DIR="$HOME/.local/state/mise"
fi

if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

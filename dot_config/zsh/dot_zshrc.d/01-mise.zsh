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
# Set mise directories explicitly to prevent reading Windows config via WSL interop
export MISE_DATA_DIR="$HOME/.local/share/mise"
export MISE_CACHE_DIR="$HOME/.cache/mise"
export MISE_CONFIG_DIR="$HOME/.config/mise"
export MISE_GLOBAL_CONFIG_FILE="$HOME/.config/mise/config.toml"

# Check direct path first since PATH may not include ~/.local/bin yet
if [[ -x "$HOME/.local/bin/mise" ]]; then
  eval "$("$HOME/.local/bin/mise" activate zsh)"
elif command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

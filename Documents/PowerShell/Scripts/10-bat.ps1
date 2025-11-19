#  ██████╗  █████╗ ████████╗
# ██╔════╝ ██╔══██╗╚══██╔══╝
# ██║  ███╗███████║   ██║
# ██║   ██║██╔══██║   ██║
# ╚██████╔╝██║  ██║   ██║
#  ╚═════╝ ╚═╝  ╚═╝   ╚═╝
# A cat(1) clone with wings.
# https://github.com/sharkdp/bat

# Bat Configuration for PowerShell

# Set bat config directory (XDG compliant)
$env:BAT_CONFIG_DIR = "$env:USERPROFILE\.config\bat"

# Set bat theme to match onedark
$env:BAT_THEME = "OneHalfDark"

# Set bat style (line numbers, git changes)
$env:BAT_STYLE = "numbers,changes,header"

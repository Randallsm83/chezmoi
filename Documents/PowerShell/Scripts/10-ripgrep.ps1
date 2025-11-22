# ██████╗ ██╗██████╗  ██████╗ ██████╗ ███████╗██████╗
# ██╔══██╗██║██╔══██╗██╔════╝ ██╔══██╗██╔════╝██╔══██╗
# ██████╔╝██║██████╔╝██║  ███╗██████╔╝█████╗  ██████╔╝
# ██╔══██╗██║██╔═══╝ ██║   ██║██╔══██╗██╔══╝  ██╔═══╝
# ██║  ██║██║██║     ╚██████╔╝██║  ██║███████╗██║
# ╚═╝  ╚═╝╚═╝╚═╝      ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝
# ripgrep recursively searches directories for a regex pattern.
# https://github.com/BurntSushi/ripgrep

# Ripgrep Configuration for PowerShell

# Set ripgrep config path (XDG compliant)
$env:RIPGREP_CONFIG_PATH = "$env:USERPROFILE\.config\ripgrep\ripgreprc"

# vim: ts=2 sts=2 sw=2 et

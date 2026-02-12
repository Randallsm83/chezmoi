# ███████╗████████╗ █████╗ ██████╗ ███████╗██╗  ██╗██╗██████╗
# ██╔════╝╚══██╔══╝██╔══██╗██╔══██╗██╔════╝██║  ██║██║██╔══██╗
# ███████╗   ██║   ███████║██████╔╝███████╗███████║██║██████╔╝
# ╚════██║   ██║   ██╔══██║██╔══██╗╚════██║██╔══██║██║██╔═══╝
# ███████║   ██║   ██║  ██║██║  ██║███████║██║  ██║██║██║
# ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝╚═╝
# The minimal, blazing-fast, and infinitely customizable prompt.
# https://starship.rs

# =============================================================================
# Starship Environment Configuration (XDG compliant)
# =============================================================================

# Config file location - XDG compliant path
$env:STARSHIP_CONFIG = "$env:XDG_CONFIG_HOME\starship\starship.toml"

# Cache directory for starship
$env:STARSHIP_CACHE = "$env:XDG_CACHE_HOME\starship"

# Ensure cache directory exists
if (-not (Test-Path $env:STARSHIP_CACHE)) {
    New-Item -ItemType Directory -Path $env:STARSHIP_CACHE -Force | Out-Null
}

# =============================================================================
# Initialization
# =============================================================================

if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}

# vim: ts=2 sts=2 sw=2 et

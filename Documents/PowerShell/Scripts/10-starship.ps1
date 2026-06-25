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
    # Skip starship in Warp - conflicts with Warp's shell integration.
    # Also skip redirected/non-interactive shells; starship errors under
    # TERM=dumb and those shells do not render a prompt anyway.
    if ($env:TERM_PROGRAM -ne 'WarpTerminal' `
            -and $Host.Name -eq 'ConsoleHost' `
            -and -not [Console]::IsOutputRedirected `
            -and $env:TERM -ne 'dumb') {
        Invoke-Expression (&starship init powershell)
    }
}

# vim: ts=2 sts=2 sw=2 et

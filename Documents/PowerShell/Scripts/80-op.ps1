# ██╗██████╗  █████╗ ███████╗███████╗██╗    ██╗ ██████╗ ██████╗ ██████╗
# ███║██╔══██╗██╔══██╗██╔════╝██╔════╝██║    ██║██╔═══██╗██╔══██╗██╔══██╗
# ╚██║██████╔╝███████║███████╗███████╗██║ █╗ ██║██║   ██║██████╔╝██║  ██║
#  ██║██╔═══╝ ██╔══██║╚════██║╚════██║██║███╗██║██║   ██║██╔══██╗██║  ██║
#  ██║██║     ██║  ██║███████║███████║╚███╔███╔╝╚██████╔╝██║  ██║██████╔╝
#  ╚═╝╚═╝     ╚═╝  ╚═╝╚══════╝╚══════╝ ╚══╝╚══╝  ╚═════╝ ╚═╝  ╚═╝╚═════╝
# 1Password CLI

# Check if op (1Password CLI) is available
if (-not (Get-Command op -ErrorAction SilentlyContinue)) {
    return
}

# Load 1Password CLI plugins if they exist
$opPluginsFile = "$env:XDG_CONFIG_HOME\op\plugins.sh"
if (Test-Path $opPluginsFile) {
    # Note: This would need to be a PowerShell version of the plugins
    # The .sh file is for bash/zsh, so this is just a placeholder
    # Write-Verbose "1Password plugins file found at $opPluginsFile"
}

# vim: ts=2 sts=2 sw=2 et

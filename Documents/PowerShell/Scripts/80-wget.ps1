# ██╗    ██╗ ██████╗ ███████╗████████╗
# ██║    ██║██╔════╝ ██╔════╝╚══██╔══╝
# ██║ █╗ ██║██║  ███╗█████╗     ██║
# ██║███╗██║██║   ██║██╔══╝     ██║
# ╚███╔███╔╝╚██████╔╝███████╗   ██║
#  ╚══╝╚══╝  ╚═════╝ ╚══════╝   ╚═╝
# GNU Wget - network downloader

# Check if wget is available
if (-not (Get-Command wget -ErrorAction SilentlyContinue)) {
    return
}

# XDG-compliant paths for wget
$env:WGETRC = "$env:XDG_CONFIG_HOME\wget\wgetrc"
$env:WGET_HSTS = "$env:XDG_CACHE_HOME\wget\wget-hsts"

# Ensure wget cache directory exists
$wgetCacheDir = "$env:XDG_CACHE_HOME\wget"
if (-not (Test-Path $wgetCacheDir)) {
    New-Item -ItemType Directory -Path $wgetCacheDir -Force | Out-Null
}

# vim: ts=2 sts=2 sw=2 et

#!/usr/bin/env pwsh
# Install 1Password CLI before chezmoi reads source state
# This ensures `onepassword` template function works

# Exit if already installed
if (Get-Command op -ErrorAction SilentlyContinue) {
    exit 0
}

Write-Host "Installing 1Password CLI..." -ForegroundColor Cyan

# Try scoop first (preferred on Windows)
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    scoop install 1password-cli
    exit 0
}

# Fallback to winget
if (Get-Command winget -ErrorAction SilentlyContinue) {
    winget install --id AgileBits.1Password.CLI --silent
    exit 0
}

# If neither available, warn and exit
Write-Warning "Could not install 1Password CLI: scoop and winget not found"
exit 1

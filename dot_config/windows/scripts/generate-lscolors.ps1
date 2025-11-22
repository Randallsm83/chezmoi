#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generate LS_COLORS using vivid for eza

.DESCRIPTION
    Creates a persistent LS_COLORS file from vivid theme generator
    so shell sessions don't need to recompute on every launch.

.PARAMETER Theme
    Vivid theme name (default: one-dark)

.EXAMPLE
    .\generate-lscolors.ps1
    .\generate-lscolors.ps1 -Theme gruvbox-dark
#>

param(
    [string]$Theme = $env:VIVID_THEME ?? 'one-dark'
)

$ErrorActionPreference = 'Stop'

# Ensure XDG config directory
$xdgConfigHome = $env:XDG_CONFIG_HOME
if (-not $xdgConfigHome) {
    $xdgConfigHome = Join-Path $env:USERPROFILE '.config'
}

$lscolorsDir = Join-Path $xdgConfigHome 'lscolors'
$outputFile = Join-Path $lscolorsDir "$Theme.txt"

# Create directory if needed
if (-not (Test-Path $lscolorsDir)) {
    New-Item -ItemType Directory -Force -Path $lscolorsDir | Out-Null
}

# Check for vivid
$vivid = Get-Command vivid -ErrorAction SilentlyContinue

if (-not $vivid) {
    Write-Host "vivid not found; skipping LS_COLORS generation" -ForegroundColor Yellow
    Write-Host "Install with: scoop install vivid" -ForegroundColor Gray
    exit 0
}

# Generate LS_COLORS
Write-Host "Generating LS_COLORS for theme: $Theme" -ForegroundColor Cyan

try {
    $content = & $vivid.Source generate $Theme
    Set-Content -Path $outputFile -Value $content -NoNewline
    Write-Host "✓ Generated: $outputFile" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to generate LS_COLORS: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# vim: ts=2 sts=2 sw=2 et

#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Add ASCII art headers to config files

.DESCRIPTION
    This script adds ASCII art headers (like the BAT config) to all config files
    in the dotfiles repository. Uses the ANSI Shadow font style for consistency.

.PARAMETER DryRun
    Preview changes without modifying files

.PARAMETER ConfigDir
    Path to config directory (default: dot_config)

.EXAMPLE
    .\add-ascii-headers.ps1 -DryRun
    Preview what would be added

.EXAMPLE
    .\add-ascii-headers.ps1
    Add headers to all config files
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [string]$ConfigDir = "$PSScriptRoot\..\dot_config"
)

$ErrorActionPreference = "Stop"

# ASCII art mapping for common package names (ANSI Shadow style)
$asciiArt = @{
    'bat' = @"
# ██████╗  █████╗ ████████╗
# ██╔══██╗██╔══██╗╚══██╔══╝
# ██████╔╝███████║   ██║
# ██╔══██╗██╔══██║   ██║
# ██████╔╝██║  ██║   ██║
# ╚═════╝ ╚═╝  ╚═╝   ╚═╝
"@
    'git' = @"
#  ██████╗ ██╗████████╗
# ██╔════╝ ██║╚══██╔══╝
# ██║  ███╗██║   ██║
# ██║   ██║██║   ██║
# ╚██████╔╝██║   ██║
#  ╚═════╝ ╚═╝   ╚═╝
"@
    'nvim' = @"
# ███╗   ██╗██╗   ██╗██╗███╗   ███╗
# ████╗  ██║██║   ██║██║████╗ ████║
# ██╔██╗ ██║██║   ██║██║██╔████╔██║
# ██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║
# ██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║
# ╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝
"@
    'zsh' = @"
# ███████╗███████╗██╗  ██╗
# ╚══███╔╝██╔════╝██║  ██║
#   ███╔╝ ███████╗███████║
#  ███╔╝  ╚════██║██╔══██║
# ███████╗███████║██║  ██║
# ╚══════╝╚══════╝╚═╝  ╚═╝
"@
    'starship' = @"
# ███████╗████████╗ █████╗ ██████╗ ███████╗██╗  ██╗██╗██████╗
# ██╔════╝╚══██╔══╝██╔══██╗██╔══██╗██╔════╝██║  ██║██║██╔══██╗
# ███████╗   ██║   ███████║██████╔╝███████╗███████║██║██████╔╝
# ╚════██║   ██║   ██╔══██║██╔══██╗╚════██║██╔══██║██║██╔═══╝
# ███████║   ██║   ██║  ██║██║  ██║███████║██║  ██║██║██║
# ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝╚═╝
"@
    'wezterm' = @"
# ██╗    ██╗███████╗███████╗████████╗███████╗██████╗ ███╗   ███╗
# ██║    ██║██╔════╝╚══███╔╝╚══██╔══╝██╔════╝██╔══██╗████╗ ████║
# ██║ █╗ ██║█████╗    ███╔╝    ██║   █████╗  ██████╔╝██╔████╔██║
# ██║███╗██║██╔══╝   ███╔╝     ██║   ██╔══╝  ██╔══██╗██║╚██╔╝██║
# ╚███╔███╔╝███████╗███████╗   ██║   ███████╗██║  ██║██║ ╚═╝ ██║
#  ╚══╝╚══╝ ╚══════╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝
"@
    'mise' = @"
# ███╗   ███╗██╗███████╗███████╗
# ████╗ ████║██║██╔════╝██╔════╝
# ██╔████╔██║██║███████╗█████╗
# ██║╚██╔╝██║██║╚════██║██╔══╝
# ██║ ╚═╝ ██║██║███████║███████╗
# ╚═╝     ╚═╝╚═╝╚══════╝╚══════╝
"@
    'eza' = @"
# ███████╗███████╗ █████╗
# ██╔════╝╚══███╔╝██╔══██╗
# █████╗    ███╔╝ ███████║
# ██╔══╝   ███╔╝  ██╔══██║
# ███████╗███████╗██║  ██║
# ╚══════╝╚══════╝╚═╝  ╚═╝
"@
    'ripgrep' = @"
# ██████╗ ██╗██████╗  ██████╗ ██████╗ ███████╗██████╗
# ██╔══██╗██║██╔══██╗██╔════╝ ██╔══██╗██╔════╝██╔══██╗
# ██████╔╝██║██████╔╝██║  ███╗██████╔╝█████╗  ██████╔╝
# ██╔══██╗██║██╔═══╝ ██║   ██║██╔══██╗██╔══╝  ██╔═══╝
# ██║  ██║██║██║     ╚██████╔╝██║  ██║███████╗██║
# ╚═╝  ╚═╝╚═╝╚═╝      ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝
"@
    'direnv' = @"
# ██████╗ ██╗██████╗ ███████╗███╗   ██╗██╗   ██╗
# ██╔══██╗██║██╔══██╗██╔════╝████╗  ██║██║   ██║
# ██║  ██║██║██████╔╝█████╗  ██╔██╗ ██║██║   ██║
# ██║  ██║██║██╔══██╗██╔══╝  ██║╚██╗██║╚██╗ ██╔╝
# ██████╔╝██║██║  ██║███████╗██║ ╚████║ ╚████╔╝
# ╚═════╝ ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝  ╚═══╝
"@
    'fzf' = @"
# ███████╗███████╗███████╗
# ██╔════╝╚══███╔╝██╔════╝
# █████╗    ███╔╝ █████╗
# ██╔══╝   ███╔╝  ██╔══╝
# ██║     ███████╗██║
# ╚═╝     ╚══════╝╚═╝
"@
    'vivid' = @"
# ██╗   ██╗██╗██╗   ██╗██╗██████╗
# ██║   ██║██║██║   ██║██║██╔══██╗
# ██║   ██║██║██║   ██║██║██║  ██║
# ╚██╗ ██╔╝██║╚██╗ ██╔╝██║██║  ██║
#  ╚████╔╝ ██║ ╚████╔╝ ██║██████╔╝
#   ╚═══╝  ╚═╝  ╚═══╝  ╚═╝╚═════╝
"@
    'wget' = @"
# ██╗    ██╗ ██████╗ ███████╗████████╗
# ██║    ██║██╔════╝ ██╔════╝╚══██╔══╝
# ██║ █╗ ██║██║  ███╗█████╗     ██║
# ██║███╗██║██║   ██║██╔══╝     ██║
# ╚███╔███╔╝╚██████╔╝███████╗   ██║
#  ╚══╝╚══╝  ╚═════╝ ╚══════╝   ╚═╝
"@
    'sqlite3' = @"
# ███████╗ ██████╗ ██╗     ██╗████████╗███████╗██████╗
# ██╔════╝██╔═══██╗██║     ██║╚══██╔══╝██╔════╝╚════██╗
# ███████╗██║   ██║██║     ██║   ██║   █████╗   █████╔╝
# ╚════██║██║▄▄ ██║██║     ██║   ██║   ██╔══╝   ╚═══██╗
# ███████║╚██████╔╝███████╗██║   ██║   ███████╗██████╔╝
# ╚══════╝ ╚══▀▀═╝ ╚══════╝╚═╝   ╚═╝   ╚══════╝╚═════╝
"@
    'npm' = @"
# ███╗   ██╗██████╗ ███╗   ███╗
# ████╗  ██║██╔══██╗████╗ ████║
# ██╔██╗ ██║██████╔╝██╔████╔██║
# ██║╚██╗██║██╔═══╝ ██║╚██╔╝██║
# ██║ ╚████║██║     ██║ ╚═╝ ██║
# ╚═╝  ╚═══╝╚═╝     ╚═╝     ╚═╝
"@
    'fd' = @"
# ███████╗██████╗
# ██╔════╝██╔══██╗
# █████╗  ██║  ██║
# ██╔══╝  ██║  ██║
# ██║     ██████╔╝
# ╚═╝     ╚═════╝
"@
    'warp' = @"
# ██╗    ██╗ █████╗ ██████╗ ██████╗
# ██║    ██║██╔══██╗██╔══██╗██╔══██╗
# ██║ █╗ ██║███████║██████╔╝██████╔╝
# ██║███╗██║██╔══██║██╔══██╗██╔═══╝
# ╚███╔███╔╝██║  ██║██║  ██║██║
#  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝
"@
    'vim' = @"
# ██╗   ██╗██╗███╗   ███╗
# ██║   ██║██║████╗ ████║
# ██║   ██║██║██╔████╔██║
# ╚██╗ ██╔╝██║██║╚██╔╝██║
#  ╚████╔╝ ██║██║ ╚═╝ ██║
#   ╚═══╝  ╚═╝╚═╝     ╚═╝
"@
    'asdf' = @"
#  █████╗ ███████╗██████╗ ███████╗
# ██╔══██╗██╔════╝██╔══██╗██╔════╝
# ███████║███████╗██║  ██║█████╗
# ██╔══██║╚════██║██║  ██║██╔══╝
# ██║  ██║███████║██████╔╝██║
# ╚═╝  ╚═╝╚══════╝╚═════╝ ╚═╝
"@
    'homebrew' = @"
# ██╗  ██╗ ██████╗ ███╗   ███╗███████╗██████╗ ██████╗ ███████╗██╗    ██╗
# ██║  ██║██╔═══██╗████╗ ████║██╔════╝██╔══██╗██╔══██╗██╔════╝██║    ██║
# ███████║██║   ██║██╔████╔██║█████╗  ██████╔╝██████╔╝█████╗  ██║ █╗ ██║
# ██╔══██║██║   ██║██║╚██╔╝██║██╔══╝  ██╔══██╗██╔══██╗██╔══╝  ██║███╗██║
# ██║  ██║╚██████╔╝██║ ╚═╝ ██║███████╗██████╔╝██║  ██║███████╗╚███╔███╔╝
# ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚═════╝ ╚═╝  ╚═╝╚══════╝ ╚══╝╚══╝
"@
    'tinted-theming' = @"
# ████████╗██╗███╗   ██╗████████╗███████╗██████╗
# ╚══██╔══╝██║████╗  ██║╚══██╔══╝██╔════╝██╔══██╗
#    ██║   ██║██╔██╗ ██║   ██║   █████╗  ██║  ██║
#    ██║   ██║██║╚██╗██║   ██║   ██╔══╝  ██║  ██║
#    ██║   ██║██║ ╚████║   ██║   ███████╗██████╔╝
#    ╚═╝   ╚═╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝╚═════╝
"@
    'windows' = @"
# ██╗    ██╗██╗███╗   ██╗██████╗  ██████╗ ██╗    ██╗███████╗
# ██║    ██║██║████╗  ██║██╔══██╗██╔═══██╗██║    ██║██╔════╝
# ██║ █╗ ██║██║██╔██╗ ██║██║  ██║██║   ██║██║ █╗ ██║███████╗
# ██║███╗██║██║██║╚██╗██║██║  ██║██║   ██║██║███╗██║╚════██║
# ╚███╔███╔╝██║██║ ╚████║██████╔╝╚██████╔╝╚███╔███╔╝███████║
#  ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝╚═════╝  ╚═════╝  ╚══╝╚══╝ ╚══════╝
"@
}

function Get-PackageDescription {
    param([string]$Package)
    
    $descriptions = @{
        'bat' = 'A cat(1) clone with wings.'
        'git' = 'Distributed version control system.'
        'nvim' = 'Hyperextensible Vim-based text editor.'
        'zsh' = 'Z Shell - powerful command interpreter.'
        'starship' = 'The minimal, blazing-fast, and infinitely customizable prompt.'
        'wezterm' = 'GPU-accelerated cross-platform terminal emulator.'
        'mise' = 'Polyglot tool version manager.'
        'eza' = 'A modern, maintained replacement for ls.'
        'ripgrep' = 'Line-oriented search tool that recursively searches.'
        'direnv' = 'Environment switcher for the shell.'
        'fzf' = 'Command-line fuzzy finder.'
        'vivid' = 'LS_COLORS generator.'
        'wget' = 'Network downloader.'
        'sqlite3' = 'Serverless SQL database engine.'
        'npm' = 'Node package manager.'
        'fd' = 'A simple, fast and user-friendly alternative to find.'
        'warp' = 'The terminal for the 21st century.'
        'vim' = 'Vi IMproved - enhanced vi editor.'
        'asdf' = 'Extendable version manager (deprecated, use mise).'
        'homebrew' = 'The Missing Package Manager for macOS (or Linux).'
        'tinted-theming' = 'Base16 and Base24 color scheme manager.'
        'windows' = 'Windows-specific configurations.'
    }
    
    return $descriptions[$Package]
}

function Add-HeaderToFile {
    param(
        [string]$FilePath,
        [string]$PackageName,
        [string]$AsciiArt,
        [bool]$IsDryRun
    )
    
    $content = Get-Content -Path $FilePath -Raw
    
    # Check if file already has ASCII art header
    if ($content -match '███') {
        Write-Host "  ⏭️  Skipping (already has header): $FilePath" -ForegroundColor Yellow
        return
    }
    
    # Get package description
    $description = Get-PackageDescription -Package $PackageName
    
    # Build header
    $header = "$AsciiArt`n"
    if ($description) {
        $header += "# $description`n"
    }
    $header += "#`n`n"
    
    # Determine comment style based on file extension
    $ext = [System.IO.Path]::GetExtension($FilePath)
    
    if ($IsDryRun) {
        Write-Host "  ✓ Would add header to: $FilePath" -ForegroundColor Cyan
        Write-Host $header -ForegroundColor Gray
        return
    }
    
    # Add header to file
    $newContent = $header + $content
    Set-Content -Path $FilePath -Value $newContent -NoNewline
    
    Write-Host "  ✓ Added header to: $FilePath" -ForegroundColor Green
}

function Process-ConfigDirectory {
    param(
        [string]$Path,
        [bool]$IsDryRun
    )
    
    # Get all config directories
    $configDirs = Get-ChildItem -Path $Path -Directory
    
    foreach ($dir in $configDirs) {
        $packageName = $dir.Name
        
        # Skip if no ASCII art defined
        if (-not $asciiArt.ContainsKey($packageName)) {
            Write-Host "⏭️  Skipping $packageName (no ASCII art defined)" -ForegroundColor Gray
            continue
        }
        
        Write-Host "`n📦 Processing $packageName..." -ForegroundColor Cyan
        
        # Find config files (including shell scripts and templates)
        $configFiles = Get-ChildItem -Path $dir.FullName -File -Recurse | 
            Where-Object { $_.Extension -in @('.conf', '.config', '', '.toml', '.yaml', '.yml', '.json', '.bash', '.zsh', '.sh', '.tmpl') }
        
        foreach ($file in $configFiles) {
            Add-HeaderToFile -FilePath $file.FullName -PackageName $packageName -AsciiArt $asciiArt[$packageName] -IsDryRun $IsDryRun
        }
    }
}

# Main execution
Write-Host "`n╔═══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Add ASCII Art Headers to Config Files  ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════╝`n" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "🔍 DRY RUN MODE - No files will be modified`n" -ForegroundColor Yellow
}

Process-ConfigDirectory -Path $ConfigDir -IsDryRun $DryRun

Write-Host "`n✅ Complete!" -ForegroundColor Green

# vim: ts=2 sts=2 sw=2 et

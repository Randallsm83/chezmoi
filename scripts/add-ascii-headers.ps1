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
    # Replace an existing ASCII-art header if the file already has one. Without
    # this, files that already start with `# ███...` are skipped untouched
    # (which is how wrong/legacy headers got stuck in place).
    [switch]$Force,
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
    'aliases' = @"
#  █████╗ ██╗     ██╗ █████╗ ███████╗███████╗███████╗
# ██╔══██╗██║     ██║██╔══██╗██╔════╝██╔════╝██╔════╝
# ███████║██║     ██║███████║███████╗█████╗  ███████╗
# ██╔══██║██║     ██║██╔══██║╚════██║██╔══╝  ╚════██║
# ██║  ██║███████╗██║██║  ██║███████║███████╗███████║
# ╚═╝  ╚═╝╚══════╝╚═╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝
"@
    'functions' = @"
# ███████╗██╗   ██╗███╗   ██╗ ██████╗████████╗██╗ ██████╗ ███╗   ██╗███████╗
# ██╔════╝██║   ██║████╗  ██║██╔════╝╚══██╔══╝██║██╔═══██╗████╗  ██║██╔════╝
# █████╗  ██║   ██║██╔██╗ ██║██║        ██║   ██║██║   ██║██╔██╗ ██║███████╗
# ██╔══╝  ██║   ██║██║╚██╗██║██║        ██║   ██║██║   ██║██║╚██╗██║╚════██║
# ██║     ╚██████╔╝██║ ╚████║╚██████╗   ██║   ██║╚██████╔╝██║ ╚████║███████║
# ╚═╝      ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝   ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝
"@
    'helpers' = @"
# ██╗  ██╗███████╗██╗     ██████╗ ███████╗██████╗ ███████╗
# ██║  ██║██╔════╝██║     ██╔══██╗██╔════╝██╔══██╗██╔════╝
# ███████║█████╗  ██║     ██████╔╝█████╗  ██████╔╝███████╗
# ██╔══██║██╔══╝  ██║     ██╔═══╝ ██╔══╝  ██╔══██╗╚════██║
# ██║  ██║███████╗███████╗██║     ███████╗██║  ██║███████║
# ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝     ╚══════╝╚═╝  ╚═╝╚══════╝
"@
    'history' = @"
# ██╗  ██╗██╗███████╗████████╗ ██████╗ ██████╗ ██╗   ██╗
# ██║  ██║██║██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗╚██╗ ██╔╝
# ███████║██║███████╗   ██║   ██║   ██║██████╔╝ ╚████╔╝
# ██╔══██║██║╚════██║   ██║   ██║   ██║██╔══██╗  ╚██╔╝
# ██║  ██║██║███████║   ██║   ╚██████╔╝██║  ██║   ██║
# ╚═╝  ╚═╝╚═╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝   ╚═╝
"@
    'completions' = @"
#  ██████╗ ██████╗ ███╗   ███╗██████╗ ██╗     ███████╗████████╗██╗ ██████╗ ███╗   ██╗███████╗
# ██╔════╝██╔═══██╗████╗ ████║██╔══██╗██║     ██╔════╝╚══██╔══╝██║██╔═══██╗████╗  ██║██╔════╝
# ██║     ██║   ██║██╔████╔██║██████╔╝██║     █████╗     ██║   ██║██║   ██║██╔██╗ ██║███████╗
# ██║     ██║   ██║██║╚██╔╝██║██╔═══╝ ██║     ██╔══╝     ██║   ██║██║   ██║██║╚██╗██║╚════██║
# ╚██████╗╚██████╔╝██║ ╚═╝ ██║██║     ███████╗███████╗   ██║   ██║╚██████╔╝██║ ╚████║███████║
#  ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═╝     ╚══════╝╚══════╝   ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝
"@
    'paths' = @"
# ██████╗  █████╗ ████████╗██╗  ██╗███████╗
# ██╔══██╗██╔══██╗╚══██╔══╝██║  ██║██╔════╝
# ██████╔╝███████║   ██║   ███████║███████╗
# ██╔═══╝ ██╔══██║   ██║   ██╔══██║╚════██║
# ██║     ██║  ██║   ██║   ██║  ██║███████║
# ╚═╝     ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝
"@
    'python' = @"
# ██████╗ ██╗   ██╗████████╗██╗  ██╗ ██████╗ ███╗   ██╗
# ██╔══██╗╚██╗ ██╔╝╚══██╔══╝██║  ██║██╔═══██╗████╗  ██║
# ██████╔╝ ╚████╔╝    ██║   ███████║██║   ██║██╔██╗ ██║
# ██╔═══╝   ╚██╔╝     ██║   ██╔══██║██║   ██║██║╚██╗██║
# ██║        ██║      ██║   ██║  ██║╚██████╔╝██║ ╚████║
# ╚═╝        ╚═╝      ╚═╝   ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
"@
    'node' = @"
# ███╗   ██╗ ██████╗ ██████╗ ███████╗
# ████╗  ██║██╔═══██╗██╔══██╗██╔════╝
# ██╔██╗ ██║██║   ██║██║  ██║█████╗
# ██║╚██╗██║██║   ██║██║  ██║██╔══╝
# ██║ ╚████║╚██████╔╝██████╔╝███████╗
# ╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚══════╝
"@
    'ruby' = @"
# ██████╗ ██╗   ██╗██████╗ ██╗   ██╗
# ██╔══██╗██║   ██║██╔══██╗╚██╗ ██╔╝
# ██████╔╝██║   ██║██████╔╝ ╚████╔╝
# ██╔══██╗██║   ██║██╔══██╗  ╚██╔╝
# ██║  ██║╚██████╔╝██████╔╝   ██║
# ╚═╝  ╚═╝ ╚═════╝ ╚═════╝    ╚═╝
"@
    'rust' = @"
# ██████╗ ██╗   ██╗███████╗████████╗
# ██╔══██╗██║   ██║██╔════╝╚══██╔══╝
# ██████╔╝██║   ██║███████╗   ██║
# ██╔══██╗██║   ██║╚════██║   ██║
# ██║  ██║╚██████╔╝███████║   ██║
# ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝
"@
    'golang' = @"
#  ██████╗  ██████╗ ██╗      █████╗ ███╗   ██╗ ██████╗
# ██╔════╝ ██╔═══██╗██║     ██╔══██╗████╗  ██║██╔════╝
# ██║  ███╗██║   ██║██║     ███████║██╔██╗ ██║██║  ███╗
# ██║   ██║██║   ██║██║     ██╔══██║██║╚██╗██║██║   ██║
# ╚██████╔╝╚██████╔╝███████╗██║  ██║██║ ╚████║╚██████╔╝
#  ╚═════╝  ╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝
"@
    'lua' = @"
# ██╗     ██╗   ██╗ █████╗
# ██║     ██║   ██║██╔══██╗
# ██║     ██║   ██║███████║
# ██║     ██║   ██║██╔══██║
# ███████╗╚██████╔╝██║  ██║
# ╚══════╝ ╚═════╝ ╚═╝  ╚═╝
"@
    'perl' = @"
# ██████╗ ███████╗██████╗ ██╗
# ██╔══██╗██╔════╝██╔══██╗██║
# ██████╔╝█████╗  ██████╔╝██║
# ██╔═══╝ ██╔══╝  ██╔══██╗██║
# ██║     ███████╗██║  ██║███████╗
# ╚═╝     ╚══════╝╚═╝  ╚═╝╚══════╝
"@
    'php' = @"
# ██████╗ ██╗  ██╗██████╗
# ██╔══██╗██║  ██║██╔══██╗
# ██████╔╝███████║██████╔╝
# ██╔═══╝ ██╔══██║██╔═══╝
# ██║     ██║  ██║██║
# ╚═╝     ╚═╝  ╚═╝╚═╝
"@
    'bun' = @"
# ██████╗ ██╗   ██╗███╗   ██╗
# ██╔══██╗██║   ██║████╗  ██║
# ██████╔╝██║   ██║██╔██╗ ██║
# ██╔══██╗██║   ██║██║╚██╗██║
# ██████╔╝╚██████╔╝██║ ╚████║
# ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝
"@
    'nvm' = @"
# ███╗   ██╗██╗   ██╗███╗   ███╗
# ████╗  ██║██║   ██║████╗ ████║
# ██╔██╗ ██║██║   ██║██╔████╔██║
# ██║╚██╗██║╚██╗ ██╔╝██║╚██╔╝██║
# ██║ ╚████║ ╚████╔╝ ██║ ╚═╝ ██║
# ╚═╝  ╚═══╝  ╚═══╝  ╚═╝     ╚═╝
"@
    '1password' = @"
#  ██╗██████╗  █████╗ ███████╗███████╗██╗    ██╗ ██████╗ ██████╗ ██████╗
# ███║██╔══██╗██╔══██╗██╔════╝██╔════╝██║    ██║██╔═══██╗██╔══██╗██╔══██╗
# ╚██║██████╔╝███████║███████╗███████╗██║ █╗ ██║██║   ██║██████╔╝██║  ██║
#  ██║██╔═══╝ ██╔══██║╚════██║╚════██║██║███╗██║██║   ██║██╔══██╗██║  ██║
#  ██║██║     ██║  ██║███████║███████║╚███╔███╔╝╚██████╔╝██║  ██║██████╔╝
#  ╚═╝╚═╝     ╚═╝  ╚═╝╚══════╝╚══════╝ ╚══╝╚══╝  ╚═════╝ ╚═╝  ╚═╝╚═════╝
"@
    'op' = @"
#  ██████╗ ██████╗
# ██╔═══██╗██╔══██╗
# ██║   ██║██████╔╝
# ██║   ██║██╔═══╝
# ╚██████╔╝██║
#  ╚═════╝ ╚═╝
"@
    'zoxide' = @"
# ███████╗ ██████╗ ██╗  ██╗██╗██████╗ ███████╗
# ╚══███╔╝██╔═══██╗╚██╗██╔╝██║██╔══██╗██╔════╝
#   ███╔╝ ██║   ██║ ╚███╔╝ ██║██║  ██║█████╗
#  ███╔╝  ██║   ██║ ██╔██╗ ██║██║  ██║██╔══╝
# ███████╗╚██████╔╝██╔╝ ██╗██║██████╔╝███████╗
# ╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝╚═════╝ ╚══════╝
"@
    'thefuck' = @"
# ████████╗██╗  ██╗███████╗███████╗██╗   ██╗ ██████╗██╗  ██╗
# ╚══██╔══╝██║  ██║██╔════╝██╔════╝██║   ██║██╔════╝██║ ██╔╝
#    ██║   ███████║█████╗  █████╗  ██║   ██║██║     █████╔╝
#    ██║   ██╔══██║██╔══╝  ██╔══╝  ██║   ██║██║     ██╔═██╗
#    ██║   ██║  ██║███████╗██║     ╚██████╔╝╚██████╗██║  ██╗
#    ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝      ╚═════╝  ╚═════╝╚═╝  ╚═╝
"@
    'topgrade' = @"
# ████████╗ ██████╗ ██████╗  ██████╗ ██████╗  █████╗ ██████╗ ███████╗
# ╚══██╔══╝██╔═══██╗██╔══██╗██╔════╝ ██╔══██╗██╔══██╗██╔══██╗██╔════╝
#    ██║   ██║   ██║██████╔╝██║  ███╗██████╔╝███████║██║  ██║█████╗
#    ██║   ██║   ██║██╔═══╝ ██║   ██║██╔══██╗██╔══██║██║  ██║██╔══╝
#    ██║   ╚██████╔╝██║     ╚██████╔╝██║  ██║██║  ██║██████╔╝███████╗
#    ╚═╝    ╚═════╝ ╚═╝      ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝
"@
    'iterm2' = @"
# ██╗████████╗███████╗██████╗ ███╗   ███╗██████╗
# ██║╚══██╔══╝██╔════╝██╔══██╗████╗ ████║╚════██╗
# ██║   ██║   █████╗  ██████╔╝██╔████╔██║ █████╔╝
# ██║   ██║   ██╔══╝  ██╔══██╗██║╚██╔╝██║██╔═══╝
# ██║   ██║   ███████╗██║  ██║██║ ╚═╝ ██║███████╗
# ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝
"@
    'vscode' = @"
# ██╗   ██╗███████╗ ██████╗ ██████╗ ██████╗ ███████╗
# ██║   ██║██╔════╝██╔════╝██╔═══██╗██╔══██╗██╔════╝
# ██║   ██║███████╗██║     ██║   ██║██║  ██║█████╗
# ╚██╗ ██╔╝╚════██║██║     ██║   ██║██║  ██║██╔══╝
#  ╚████╔╝ ███████║╚██████╗╚██████╔╝██████╔╝███████╗
#   ╚═══╝  ╚══════╝ ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝
"@
    'zed' = @"
# ███████╗███████╗██████╗
# ╚══███╔╝██╔════╝██╔══██╗
#   ███╔╝ █████╗  ██║  ██║
#  ███╔╝  ██╔══╝  ██║  ██║
# ███████╗███████╗██████╔╝
# ╚══════╝╚══════╝╚═════╝
"@
    'opencode' = @"
#  ██████╗ ██████╗ ███████╗███╗   ██╗ ██████╗ ██████╗ ██████╗ ███████╗
# ██╔═══██╗██╔══██╗██╔════╝████╗  ██║██╔════╝██╔═══██╗██╔══██╗██╔════╝
# ██║   ██║██████╔╝█████╗  ██╔██╗ ██║██║     ██║   ██║██║  ██║█████╗
# ██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║██║     ██║   ██║██║  ██║██╔══╝
# ╚██████╔╝██║     ███████╗██║ ╚████║╚██████╗╚██████╔╝██████╔╝███████╗
#  ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝
"@
    'scoop' = @"
# ███████╗ ██████╗ ██████╗  ██████╗ ██████╗
# ██╔════╝██╔════╝██╔═══██╗██╔═══██╗██╔══██╗
# ███████╗██║     ██║   ██║██║   ██║██████╔╝
# ╚════██║██║     ██║   ██║██║   ██║██╔═══╝
# ███████║╚██████╗╚██████╔╝╚██████╔╝██║
# ╚══════╝ ╚═════╝ ╚═════╝  ╚═════╝ ╚═╝
"@
    'winget' = @"
# ██╗    ██╗██╗███╗   ██╗ ██████╗ ███████╗████████╗
# ██║    ██║██║████╗  ██║██╔════╝ ██╔════╝╚══██╔══╝
# ██║ █╗ ██║██║██╔██╗ ██║██║  ███╗█████╗     ██║
# ██║███╗██║██║██║╚██╗██║██║   ██║██╔══╝     ██║
# ╚███╔███╔╝██║██║ ╚████║╚██████╔╝███████╗   ██║
#  ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚══════╝   ╚═╝
"@
    'docker' = @"
# ██████╗  ██████╗  ██████╗██╗  ██╗███████╗██████╗
# ██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗
# ██║  ██║██║   ██║██║     █████╔╝ █████╗  ██████╔╝
# ██║  ██║██║   ██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗
# ██████╔╝╚██████╔╝╚██████╗██║  ██╗███████╗██║  ██║
# ╚═════╝  ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
"@
    'gh' = @"
#  ██████╗ ██╗  ██╗
# ██╔════╝ ██║  ██║
# ██║  ███╗███████║
# ██║   ██║██╔══██║
# ╚██████╔╝██║  ██║
#  ╚═════╝ ╚═╝  ╚═╝
"@
    'gitlab' = @"
#  ██████╗ ██╗████████╗██╗      █████╗ ██████╗
# ██╔════╝ ██║╚══██╔══╝██║     ██╔══██╗██╔══██╗
# ██║  ███╗██║   ██║   ██║     ███████║██████╔╝
# ██║   ██║██║   ██║   ██║     ██╔══██║██╔══██╗
# ╚██████╔╝██║   ██║   ███████╗██║  ██║██████╔╝
#  ╚═════╝ ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═════╝
"@
    'arduino' = @"
#  █████╗ ██████╗ ██████╗ ██╗   ██╗██╗███╗   ██╗ ██████╗
# ██╔══██╗██╔══██╗██╔══██╗██║   ██║██║████╗  ██║██╔═══██╗
# ███████║██████╔╝██║  ██║██║   ██║██║██╔██╗ ██║██║   ██║
# ██╔══██║██╔══██╗██║  ██║██║   ██║██║██║╚██╗██║██║   ██║
# ██║  ██║██║  ██║██████╔╝╚██████╔╝██║██║ ╚████║╚██████╔╝
# ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝  ╚═════╝ ╚═╝╚═╝  ╚═══╝ ╚═════╝
"@
    'vagrant' = @"
# ██╗   ██╗ █████╗  ██████╗ ██████╗  █████╗ ███╗   ██╗████████╗
# ██║   ██║██╔══██╗██╔════╝ ██╔══██╗██╔══██╗████╗  ██║╚══██╔══╝
# ██║   ██║███████║██║  ███╗██████╔╝███████║██╔██╗ ██║   ██║
# ╚██╗ ██╔╝██╔══██║██║   ██║██╔══██╗██╔══██║██║╚██╗██║   ██║
#  ╚████╔╝ ██║  ██║╚██████╔╝██║  ██║██║  ██║██║ ╚████║   ██║
#   ╚═══╝  ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝
"@
    'rdock' = @"
# ██████╗ ██████╗  ██████╗  ██████╗██╗  ██╗
# ██╔══██╗██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝
# ██████╔╝██║  ██║██║   ██║██║     █████╔╝
# ██╔══██╗██║  ██║██║   ██║██║     ██╔═██╗
# ██║  ██║██████╔╝╚██████╔╝╚██████╗██║  ██╗
# ╚═╝  ╚═╝╚═════╝  ╚═════╝  ╚═════╝╚═╝  ╚═╝
"@
    'tinty' = @"
# ████████╗██╗███╗   ██╗████████╗██╗   ██╗
# ╚══██╔══╝██║████╗  ██║╚══██╔══╝╚██╗ ██╔╝
#    ██║   ██║██╔██╗ ██║   ██║    ╚████╔╝
#    ██║   ██║██║╚██╗██║   ██║     ╚██╔╝
#    ██║   ██║██║ ╚████║   ██║      ██║
#    ╚═╝   ╚═╝╚═╝  ╚═══╝   ╚═╝      ╚═╝
"@
    'pastel' = @"
# ██████╗  █████╗ ███████╗████████╗███████╗██╗
# ██╔══██╗██╔══██╗██╔════╝╚══██╔══╝██╔════╝██║
# ██████╔╝███████║███████╗   ██║   █████╗  ██║
# ██╔═══╝ ██╔══██║╚════██║   ██║   ██╔══╝  ██║
# ██║     ██║  ██║███████║   ██║   ███████╗███████╗
# ╚═╝     ╚═╝  ╚═╝╚══════╝   ╚═╝   ╚══════╝╚══════╝
"@
    'pure' = @"
# ██████╗ ██╗   ██╗██████╗ ███████╗
# ██╔══██╗██║   ██║██╔══██╗██╔════╝
# ██████╔╝██║   ██║██████╔╝█████╗
# ██╔═══╝ ██║   ██║██╔══██╗██╔══╝
# ██║     ╚██████╔╝██║  ██║███████╗
# ╚═╝      ╚═════╝ ╚═╝  ╚═╝╚══════╝
"@
    'spaceduck' = @"
# ███████╗██████╗  █████╗  ██████╗███████╗██████╗ ██╗   ██╗ ██████╗██╗  ██╗
# ██╔════╝██╔══██╗██╔══██╗██╔════╝██╔════╝██╔══██╗██║   ██║██╔════╝██║ ██╔╝
# ███████╗██████╔╝███████║██║     █████╗  ██║  ██║██║   ██║██║     █████╔╝
# ╚════██║██╔═══╝ ██╔══██║██║     ██╔══╝  ██║  ██║██║   ██║██║     ██╔═██╗
# ███████║██║     ██║  ██║╚██████╗███████╗██████╔╝╚██████╔╝╚██████╗██║  ██╗
# ╚══════╝╚═╝     ╚═╝  ╚═╝ ╚═════╝╚══════╝╚═════╝  ╚═════╝  ╚═════╝╚═╝  ╚═╝
"@
    'chezmoi' = @"
#  ██████╗██╗  ██╗███████╗███████╗███╗   ███╗ ██████╗ ██╗
# ██╔════╝██║  ██║██╔════╝╚══███╔╝████╗ ████║██╔═══██╗██║
# ██║     ███████║█████╗    ███╔╝ ██╔████╔██║██║   ██║██║
# ██║     ██╔══██║██╔══╝   ███╔╝  ██║╚██╔╝██║██║   ██║██║
# ╚██████╗██║  ██║███████╗███████╗██║ ╚═╝ ██║╚██████╔╝██║
#  ╚═════╝╚═╝  ╚═╝╚══════╝╚══════╝╚═╝     ╚═╝ ╚═════╝ ╚═╝
"@
}

function Get-EffectiveExtension {
    # Resolve a file's effective config-format extension, even when chezmoi
    # template wrappers (.tmpl) or local-only variants (.disabled, .example,
    # etc.) hide the real extension. E.g. foo.lua.tmpl -> .lua, bar.toml.example
    # -> .toml. This lets us pick the right comment style downstream.
    param([string]$Path)
    $ext = [System.IO.Path]::GetExtension($Path).ToLower()
    if ($ext -in @('.tmpl', '.example', '.disabled', '.disabled2', '.off')) {
        $base = [System.IO.Path]::GetFileNameWithoutExtension($Path)
        $inner = [System.IO.Path]::GetExtension($base).ToLower()
        if ($inner) { return $inner }
    }
    return $ext
}

function Get-CommentPrefix {
    # Pick a single-line comment prefix for the given effective extension.
    # Returns the punctuation only ('#', '--', '//'); a trailing space is
    # added by the caller where appropriate.
    param([string]$EffectiveExt)
    switch ($EffectiveExt.ToLower()) {
        '.lua'   { return '--' }
        default  { return '#' }
    }
}

function ConvertTo-CommentedArt {
    # The art literals in `$asciiArt` are stored with a leading '# ' on every
    # line. For languages that don't use '#' for comments we re-prefix each
    # line in place. Lines that are just '#' become just the new prefix.
    param([string]$Art, [string]$Prefix)
    if ($Prefix -eq '#') { return $Art }
    $lines = $Art -split "(?:`r`n|`n)"
    $out = foreach ($l in $lines) {
        if ($l -match '^# ?(.*)$') {
            $rest = $Matches[1]
            if ($rest.Length -gt 0) { "$Prefix $rest" } else { $Prefix }
        } else {
            $l
        }
    }
    return ($out -join "`n")
}

function Get-PackageNameForFile {
    # Pick the most specific ASCII art for a file. Filename stem wins over
    # the parent directory name so that e.g. dot_config/zsh/dot_zshrc.d/40-wezterm.zsh
    # gets the wezterm art instead of zsh.
    param(
        [string]$FilePath,
        [string]$DirPackageName,
        [hashtable]$ArtMap
    )

    $stem = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
    # Strip chezmoi attribute prefixes (dot_, private_, encrypted_, etc.) and
    # leading numeric ordering prefixes like "25-" or "00_".
    $stem = $stem -replace '^(dot|private|encrypted|empty|executable|once|run|symlink|create|modify|remove|exact)_', ''
    $stem = $stem -replace '^[0-9]+[-_]', ''

    # Try the whole stem first, then peel trailing ".something" or "-something"
    # segments to find a match. This handles both:
    #   - aliases-ndn        -> aliases
    #   - golang.zsh         -> golang   (after the outer .tmpl already stripped)
    #   - 1password-setup-op -> 1password
    # Prefer stripping dot-suffixes first (inner template type, e.g. `.zsh`,
    # `.lua`) before hyphen-suffixes so language helpers like 70-golang.zsh.tmpl
    # resolve to 'golang' instead of falling all the way back to the zsh dir.
    $candidate = $stem
    while ($candidate) {
        if ($ArtMap.ContainsKey($candidate)) { return $candidate }
        if ($candidate -match '\.') {
            $candidate = $candidate -replace '\.[^.]+$', ''
            continue
        }
        if ($candidate -match '-') {
            $candidate = $candidate -replace '-[^-]+$', ''
            continue
        }
        break
    }

    # Fallback: the directory name (legacy behaviour).
    return $DirPackageName
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
        'aliases' = 'Shorter command aliases.'
        'functions' = 'Custom shell functions.'
        'helpers' = 'Internal helper utilities.'
        'history' = 'Shell history configuration.'
        'completions' = 'Shell completion definitions.'
        'paths' = 'PATH and environment paths.'
        'python' = 'Python language tooling.'
        'node' = 'Node.js runtime and tooling.'
        'ruby' = 'Ruby language tooling.'
        'rust' = 'Rust language tooling.'
        'golang' = 'Go language tooling.'
        'lua' = 'Lua language tooling.'
        'perl' = 'Perl language tooling.'
        'php' = 'PHP language tooling.'
        'bun' = 'Fast JavaScript runtime and toolkit.'
        'nvm' = 'Node Version Manager.'
        '1password' = '1Password secret manager and SSH agent.'
        'op' = '1Password CLI.'
        'zoxide' = 'A smarter cd command.'
        'thefuck' = 'Magnificent app that corrects previous console command.'
        'topgrade' = 'Upgrade all the things.'
        'iterm2' = 'macOS terminal replacement.'
        'vscode' = 'Visual Studio Code editor.'
        'zed' = 'High-performance multiplayer code editor.'
        'opencode' = 'AI coding agent built for the terminal.'
        'scoop' = 'Windows command-line installer.'
        'winget' = 'Windows Package Manager.'
        'docker' = 'Container platform.'
        'gh' = 'GitHub command-line tool.'
        'gitlab' = 'GitLab command-line tool (glab).'
        'arduino' = 'Arduino microcontroller toolchain.'
        'vagrant' = 'Portable development environments.'
        'rdock' = 'Rdock display and dashboard tool.'
        'tinty' = 'Tinted-theming CLI for base16/base24.'
        'pastel' = 'Generate, analyze, convert and manipulate colors.'
        'pure' = 'Pure prompt for zsh.'
        'spaceduck' = 'Spaceduck color theme.'
        'chezmoi' = 'Manage your dotfiles across multiple machines.'
    }
    
    return $descriptions[$Package]
}

function Add-HeaderToFile {
    param(
        [string]$FilePath,
        [string]$PackageName,
        [string]$AsciiArt,
        [bool]$IsDryRun,
        [bool]$ForceReplace
    )

    $content = Get-Content -Path $FilePath -Raw
    if ($null -eq $content) { $content = '' }

    $effExt = Get-EffectiveExtension -Path $FilePath
    $prefix = Get-CommentPrefix -EffectiveExt $effExt

    # Detect any leading ASCII art header in *any* supported comment style
    # (#, --, //). We tolerate leading blank lines and at most a small run of
    # plain comment lines before the art block (handles wezterm.lua.tmpl,
    # which used to have a wrong '#' header stacked on top of the original
    # '--' header).
    $detectPattern = '\A(?:\r?\n)*(?:(?:#|--|//)[^\r\n]*\r?\n)*(?:(?:#|--|//)[^\r\n]*█[^\r\n]*\r?\n)+'
    $stripPattern  = '\A(?:\r?\n)*(?:(?:#|--|//)[^\r\n]*\r?\n)*?(?:(?:#|--|//)[^\r\n]*█[^\r\n]*\r?\n)+(?:(?:#|--|//)[^\r\n]*\r?\n)*(?:\r?\n)*'

    $hasHeader = $content -match $detectPattern

    if ($hasHeader -and -not $ForceReplace) {
        Write-Host "  ⏭️  Skipping (already has header, use -Force to replace): $FilePath" -ForegroundColor Yellow
        return
    }

    if ($hasHeader) {
        # Iteratively strip stacked legacy header blocks until stable, so a
        # mixed file (e.g. wrong '#' art followed by original '--' art) ends
        # up with no header at the top before we re-add the right one.
        while ($true) {
            $next = [regex]::Replace($content, $stripPattern, '')
            if ($next -eq $content) { break }
            $content = $next
        }
    }

    $art         = ConvertTo-CommentedArt -Art $AsciiArt -Prefix $prefix
    $description = Get-PackageDescription -Package $PackageName
    $header      = "$art`n"
    if ($description) { $header += "$prefix $description`n" }
    $header += "$prefix`n`n"

    $verb = if ($hasHeader) { 'Replaced' } else { 'Added' }

    if ($IsDryRun) {
        Write-Host "  ✓ Would $($verb.ToLower()) header in: $FilePath (package=$PackageName, style='$prefix')" -ForegroundColor Cyan
        return
    }

    $newContent = $header + $content
    Set-Content -Path $FilePath -Value $newContent -NoNewline -Encoding utf8
    Write-Host "  ✓ $verb header in: $FilePath (package=$PackageName, style='$prefix')" -ForegroundColor Green
}

function Process-ConfigDirectory {
    param(
        [string]$Path,
        [bool]$IsDryRun,
        [bool]$ForceReplace
    )

    $configDirs = Get-ChildItem -Path $Path -Directory

    foreach ($dir in $configDirs) {
        # Strip chezmoi attribute prefixes from the directory name too, so
        # dirs like 'private_op' or 'encrypted_keys' resolve to a known
        # package ('op', 'keys') instead of getting skipped.
        $dirPackageName = $dir.Name -replace '^(dot|private|encrypted|empty|executable|once|run|symlink|create|modify|remove|exact)_', ''

        # Skip the directory entirely only if it has neither a directory-level
        # art nor any filename-derivable art. We can't know that without
        # walking the files; cheaper to walk and per-file fall back to skip.
        $dirHasArt = $asciiArt.ContainsKey($dirPackageName)

        Write-Host "`n📦 Processing $dirPackageName..." -ForegroundColor Cyan

        $configFiles = Get-ChildItem -Path $dir.FullName -File -Recurse |
            Where-Object { $_.Extension -in @(
                '.conf', '.config', '', '.toml', '.yaml', '.yml',
                '.bash', '.zsh', '.sh', '.tmpl',
                '.ps1', '.lua', '.py', '.dircolors', '.env',
                '.zsh-syntax-theme', '.example'
            ) -and $_.Name -notmatch '\.(json|jsonc)(\.tmpl)?$' }

        foreach ($file in $configFiles) {
            $pkg = Get-PackageNameForFile -FilePath $file.FullName -DirPackageName $dirPackageName -ArtMap $asciiArt
            if (-not $asciiArt.ContainsKey($pkg)) {
                if ($dirHasArt) { $pkg = $dirPackageName }
                else {
                    Write-Host "  ⏭️  Skipping (no matching art): $($file.FullName)" -ForegroundColor DarkGray
                    continue
                }
            }
            Add-HeaderToFile -FilePath $file.FullName -PackageName $pkg -AsciiArt $asciiArt[$pkg] -IsDryRun $IsDryRun -ForceReplace $ForceReplace
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

Process-ConfigDirectory -Path $ConfigDir -IsDryRun $DryRun -ForceReplace $Force

Write-Host "`n✅ Complete!" -ForegroundColor Green

# vim: ts=2 sts=2 sw=2 et

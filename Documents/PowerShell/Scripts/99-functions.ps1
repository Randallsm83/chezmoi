# PowerShell Utility Functions
# Moved from inline profile definitions

# ================================================================================================
# Profile Management
# ================================================================================================

<#
.SYNOPSIS
    Reload the PowerShell profile.
#>
function Reload-Profile {
    . $PROFILE
    Write-Host "Profile reloaded!" -ForegroundColor Green
}
Set-Alias -Name reload -Value Reload-Profile

<#
.SYNOPSIS
    Edit the PowerShell profile.
#>
function Edit-Profile {
    if (Get-Command nvim -ErrorAction SilentlyContinue) {
        nvim $PROFILE
    } else {
        notepad $PROFILE
    }
}
Set-Alias -Name ep -Value Edit-Profile

# ================================================================================================
# File System Utilities
# ================================================================================================

<#
.SYNOPSIS
    Touch command - create file or update timestamp.
#>
# touch - skip if uutils-coreutils provides touch.exe
if (-not $env:__UUTILS_COREUTILS) {
    function touch {
        param([string]$file)
        if (Test-Path $file) {
            (Get-Item $file).LastWriteTime = Get-Date
        } else {
            New-Item -ItemType File -Path $file | Out-Null
        }
    }
}

<#
.SYNOPSIS
    Make directory and change into it.
#>
function mkcd {
    param([string]$path)
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    Set-Location $path
}

# ================================================================================================
# Directory Navigation
# ================================================================================================

function .. { Set-Location .. }
function ... { Set-Location ..\..\.. }
function .... { Set-Location ..\..\..\.. }

# ================================================================================================
# Tool Replacements
# ================================================================================================

# Neovim shortcuts
if (Get-Command nvim -ErrorAction SilentlyContinue) {
    function vim { & nvim $args }
    function vi { & nvim $args }
}

# bat (better cat) — handled in 99-aliases.ps1

# pip (Python package installer)
# On Windows with mise, pip is not shimmed, so use python -m pip
if (Get-Command python -ErrorAction SilentlyContinue) {
    function pip { & python -m pip $args }
}

# ================================================================================================
# Terminal Integration
# ================================================================================================

<#
.SYNOPSIS
    OSC7 terminal integration for WezTerm.
#>
function Set-EnvVar {
    $p = $executionContext.SessionState.Path.CurrentLocation
    $osc7 = ""
    if ($p.Provider.Name -eq "FileSystem") {
        $ansi_escape = [char]27
        $provider_path = $p.ProviderPath -Replace "\\", "/"
        $osc7 = "$ansi_escape]7;file://${env:COMPUTERNAME}/${provider_path}${ansi_escape}\"
    }
    $env:OSC7=$osc7
}
New-Alias -Name 'Set-PoshContext' -Value 'Set-EnvVar' -Scope Global -Force

# ================================================================================================
# Unix-like Command Aliases
# ================================================================================================

Set-Alias -Name grep -Value Select-String -ErrorAction SilentlyContinue
# which is defined as a function in 99-aliases.ps1
Set-Alias -Name ps -Value Get-Process -ErrorAction SilentlyContinue
Set-Alias -Name kill -Value Stop-Process -ErrorAction SilentlyContinue

# Replace built-in scoop search (if scoop-search is available)
if (Get-Command scoop-search -ErrorAction SilentlyContinue) {
    try {
        Invoke-Expression (&scoop-search --hook)
    } catch {}
}

# ================================================================================================
# Backfilled from zsh 25-functions.zsh
# ================================================================================================

function up {
    param([int]$Count = 1)
    $path = '../' * $Count
    Set-Location $path
}

function sshkeygen {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Comment
    )
    ssh-keygen -t ed25519 -f "$HOME/.ssh/$Name" -C $Comment
}

function Show-AnsiColors16 {
    for ($i = 0; $i -lt 16; $i++) {
        Write-Host -NoNewline "$([char]27)[48;5;${i}m  $([char]27)[0m"
        Write-Host -NoNewline "$([char]27)[38;5;${i}m$('{0,4}' -f $i)$([char]27)[0m "
        if (($i + 1) % 8 -eq 0) { Write-Host }
    }
}
Set-Alias -Name 16colors -Value Show-AnsiColors16

function Show-AnsiColors256 {
    for ($i = 0; $i -lt 256; $i++) {
        Write-Host -NoNewline "$([char]27)[48;5;${i}m  $([char]27)[0m"
        Write-Host -NoNewline "$([char]27)[38;5;${i}m$('{0,4}' -f $i)$([char]27)[0m "
        if (($i + 1) % 8 -eq 0) { Write-Host }
    }
}
Set-Alias -Name 256colors -Value Show-AnsiColors256

# -------------------------------------------------------------------------------------------------
# vim: ft=ps1 sw=4 ts=4 et
# -------------------------------------------------------------------------------------------------

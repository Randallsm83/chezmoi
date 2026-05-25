#Requires -Version 7.0
<#
.SYNOPSIS
    Dotfiles health check (Windows counterpart to scripts/healthcheck.sh).

.DESCRIPTION
    Validates dotfiles configuration and tool availability on Windows.
    Mirrors the section structure of healthcheck.sh:

      - Chezmoi:  version / source-path / status / uncommitted source diff / unmanaged count
      - Tools:    git, curl, wget, scoop, mise, winget, gsudo, op
      - Mise:     version / doctor / outdated / list (truncated)
      - Shell:    pwsh version, profile presence + bytes
      - Git:      version, user.name, user.email, SSH key count
      - Disk:     ~/scoop, ~/.local/share/mise, ~/.cache, %USERPROFILE%\.local\state\chezmoi\backups, chezmoi source
      - Services: Unbound, 1Password agent pipe, Developer Mode, Caddy root cert

    Many checks will report Warning on a fresh box — that's expected. The
    script is read-only; it never mutates state.

.NOTES
    Author: Randall
    Status helper shape copied from bootstrap.ps1:79-108 so output is
    consistent across the two scripts.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'

# ============================================================================
# Helper Functions
# ============================================================================

function Write-Status {
    <#
    .SYNOPSIS
        Write formatted status message with colored icon. Shape matches
        bootstrap.ps1:79-108 so output is consistent across scripts.
    #>
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Type = 'Info'
    )
    $colors  = @{ Info = 'Cyan'; Success = 'Green'; Warning = 'Yellow'; Error = 'Red' }
    $symbols = @{ Info = 'i';    Success = 'OK';    Warning = '!';      Error = 'X'   }
    Write-Host "[$($symbols[$Type])] " -ForegroundColor $colors[$Type] -NoNewline
    Write-Host $Message
}

function Write-SectionHeader {
    param([Parameter(Mandatory)][string]$Title)
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor DarkGray
    Write-Host "  $Title" -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor DarkGray
}

function Test-CommandExists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Get-FolderSizeGB {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try {
        $bytes = (Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        if ($null -eq $bytes) { return 0 }
        return [math]::Round($bytes / 1GB, 2)
    } catch {
        return $null
    }
}

# ============================================================================
# Check Functions
# ============================================================================

function Test-Chezmoi {
    Write-SectionHeader 'Chezmoi Configuration'

    if (-not (Test-CommandExists chezmoi)) {
        Write-Status 'chezmoi not found in PATH' -Type Error
        return
    }

    $version = (chezmoi --version 2>$null | Select-Object -First 1)
    Write-Status "chezmoi installed: $version" -Type Success

    $sourceDir = chezmoi source-path 2>$null
    if ($sourceDir -and (Test-Path -LiteralPath $sourceDir)) {
        Write-Status "Source directory: $sourceDir" -Type Success
    } else {
        Write-Status "Source directory not found: $sourceDir" -Type Warning
        return
    }

    # Uncommitted-source-changes count
    Push-Location $sourceDir
    try {
        $changes = (git status --porcelain 2>$null | Measure-Object).Count
        if ($changes -gt 0) {
            Write-Status "$changes uncommitted changes in source directory" -Type Warning
        } else {
            Write-Status "No uncommitted changes" -Type Success
        }
    } finally {
        Pop-Location
    }

    # `chezmoi status` summary (lines = files needing apply)
    $statusLines = (chezmoi status 2>$null | Where-Object { $_ } | Measure-Object).Count
    if ($statusLines -gt 0) {
        Write-Status "$statusLines files differ from source state (run 'chezmoi apply')" -Type Warning
    } else {
        Write-Status "chezmoi state matches source" -Type Success
    }

    # Unmanaged count
    $unmanaged = (chezmoi unmanaged 2>$null | Where-Object { $_ } | Measure-Object).Count
    Write-Status "$unmanaged unmanaged files in home directory" -Type Info
}

function Test-Tools {
    Write-SectionHeader 'Essential Tools'
    $tools = @('git', 'curl', 'wget', 'scoop', 'mise', 'winget', 'gsudo', 'op')
    foreach ($tool in $tools) {
        if (Test-CommandExists $tool) {
            Write-Status "$tool installed" -Type Success
        } else {
            Write-Status "$tool not found" -Type Warning
        }
    }
}

function Test-Mise {
    Write-SectionHeader 'Mise Package Manager'

    if (-not (Test-CommandExists mise)) {
        Write-Status 'mise not found' -Type Error
        return
    }

    $version = (mise --version 2>$null | Select-Object -First 1)
    Write-Status "mise installed: $version" -Type Success

    Write-Status 'Running mise doctor...' -Type Info
    # Doctor's output is large; surface just the checkbox lines (cross-platform unicode).
    mise doctor 2>&1 | Select-String -Pattern '(?i)(error|warning|ok|version|active|installed)' |
        Select-Object -First 12 | ForEach-Object { Write-Host "    $_" }

    $outdated = (mise outdated 2>$null | Where-Object { $_ } | Measure-Object).Count
    if ($outdated -gt 0) {
        Write-Status "$outdated tools have updates available (run: mise upgrade)" -Type Warning
    } else {
        Write-Status 'All tools up to date' -Type Success
    }

    Write-Status 'Installed runtimes (first 20):' -Type Info
    mise list 2>$null | Select-Object -First 20 | ForEach-Object { Write-Host "    $_" }
}

function Test-Shell {
    Write-SectionHeader 'Shell Configuration'

    $pwshVer = $PSVersionTable.PSVersion
    Write-Status "PowerShell version: $pwshVer" -Type Success

    $profilePath = $PROFILE.CurrentUserAllHosts
    if (Test-Path -LiteralPath $profilePath) {
        $bytes = (Get-Item -LiteralPath $profilePath).Length
        Write-Status "Profile: $profilePath ($bytes bytes)" -Type Success
    } else {
        Write-Status "Profile not found: $profilePath" -Type Warning
    }

    $hostProfile = $PROFILE.CurrentUserCurrentHost
    if (Test-Path -LiteralPath $hostProfile) {
        $bytes = (Get-Item -LiteralPath $hostProfile).Length
        Write-Status "Host profile: $hostProfile ($bytes bytes)" -Type Success
    } else {
        Write-Status "Host profile not found: $hostProfile" -Type Warning
    }
}

function Test-Git {
    Write-SectionHeader 'Git Configuration'

    if (-not (Test-CommandExists git)) {
        Write-Status 'git not found' -Type Error
        return
    }

    Write-Status (git --version 2>$null) -Type Success

    $userName  = git config --global user.name  2>$null
    $userEmail = git config --global user.email 2>$null
    if ($userName)  { Write-Status "Name:  $userName"  -Type Success } else { Write-Status 'user.name not configured'  -Type Warning }
    if ($userEmail) { Write-Status "Email: $userEmail" -Type Success } else { Write-Status 'user.email not configured' -Type Warning }

    $sshDir = Join-Path $HOME '.ssh'
    if (Test-Path -LiteralPath $sshDir) {
        $keyCount = (Get-ChildItem -LiteralPath $sshDir -Filter 'id_*' -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notlike '*.pub' } | Measure-Object).Count
        Write-Status "$keyCount SSH keys found in ~/.ssh" -Type Info
    } else {
        Write-Status '~/.ssh does not exist' -Type Warning
    }
}

function Test-DiskUsage {
    Write-SectionHeader 'Disk Usage'

    $paths = [ordered]@{
        'scoop'             = Join-Path $HOME 'scoop'
        'mise data'         = Join-Path $HOME '.local\share\mise'
        'XDG cache'         = Join-Path $HOME '.cache'
        # XDG-compliant chezmoi backup dir; rule: %USERPROFILE%\.local\state\…, NOT %LOCALAPPDATA%.
        'chezmoi backups'   = Join-Path $HOME '.local\state\chezmoi\backups'
        'chezmoi source'    = (chezmoi source-path 2>$null)
    }

    foreach ($name in $paths.Keys) {
        $p = $paths[$name]
        if (-not $p) {
            Write-Status "$($name): path not resolved" -Type Warning
            continue
        }
        if (-not (Test-Path -LiteralPath $p)) {
            Write-Status "$($name): not present ($p)" -Type Info
            continue
        }
        $sizeGB = Get-FolderSizeGB -Path $p
        if ($null -eq $sizeGB) {
            Write-Status "$($name): $p (size unknown — access denied?)" -Type Warning
        } else {
            Write-Status "$($name): $sizeGB GB ($p)" -Type Info
        }
    }
}

function Test-ServiceState {
    Write-SectionHeader 'Service State'

    # Unbound service (DoT-forwarding stub resolver)
    $unbound = Get-Service -Name unbound -ErrorAction SilentlyContinue
    if ($unbound) {
        if ($unbound.Status -eq 'Running') {
            Write-Status "Unbound service: $($unbound.Status) ($($unbound.StartType))" -Type Success
        } else {
            Write-Status "Unbound service: $($unbound.Status) ($($unbound.StartType))" -Type Warning
        }
    } else {
        Write-Status 'Unbound service: not installed' -Type Info
    }

    # 1Password SSH agent named pipe
    $opAgentPipe = '\\.\pipe\openssh-ssh-agent'
    try {
        if (Test-Path -LiteralPath $opAgentPipe -ErrorAction SilentlyContinue) {
            Write-Status '1Password SSH agent pipe: present' -Type Success
        } else {
            Write-Status '1Password SSH agent pipe: missing (\\.\\pipe\\openssh-ssh-agent)' -Type Warning
        }
    } catch {
        Write-Status '1Password SSH agent pipe: probe failed' -Type Warning
    }

    # Developer Mode (registry)
    try {
        $devModeKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
        $val = Get-ItemProperty -Path $devModeKey -Name 'AllowDevelopmentWithoutDevLicense' -ErrorAction SilentlyContinue
        if ($val -and $val.AllowDevelopmentWithoutDevLicense -eq 1) {
            Write-Status 'Developer Mode: enabled' -Type Success
        } else {
            Write-Status 'Developer Mode: disabled (symlinks require admin)' -Type Warning
        }
    } catch {
        Write-Status 'Developer Mode: probe failed' -Type Warning
    }

    # Caddy root cert (HKLM\ROOT certificate store)
    try {
        $caddyCert = Get-ChildItem -Path Cert:\LocalMachine\Root -ErrorAction SilentlyContinue |
            Where-Object { $_.Subject -match 'Caddy Local Authority' }
        if ($caddyCert) {
            Write-Status "Caddy root cert: trusted ($($caddyCert.Subject))" -Type Success
        } else {
            Write-Status 'Caddy root cert: not present in LocalMachine\Root' -Type Info
        }
    } catch {
        Write-Status 'Caddy root cert: probe requires admin' -Type Warning
    }
}

# ============================================================================
# Main
# ============================================================================

Write-Host ""
Write-Host "============================================" -ForegroundColor White
Write-Host "    Dotfiles Health Check (Windows) v2.0    " -ForegroundColor White
Write-Host "============================================" -ForegroundColor White

Test-Chezmoi
Test-Tools
Test-Mise
Test-Shell
Test-Git
Test-DiskUsage
Test-ServiceState

Write-SectionHeader 'Summary'
Write-Status 'Health check complete!' -Type Info
Write-Status "For updates, run: chezmoi update" -Type Info
Write-Status "For mise updates, run: mise upgrade" -Type Info
Write-Host ""

# vim: ts=2 sts=2 sw=2 et

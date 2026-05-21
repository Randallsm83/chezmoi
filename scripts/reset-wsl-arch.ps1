#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Reset and bootstrap Arch Linux WSL instance with chezmoi dotfiles.

.DESCRIPTION
    Automates the complete workflow for resetting a WSL Arch Linux instance:
      1. Unregisters (terminates) the existing WSL distribution.
      2. Installs a fresh Arch Linux instance from the WSL repository.
      3. Refreshes archlinux-keyring (handles stale distro images).
      4. Installs a minimal toolchain so chezmoi can run (sudo, base-devel,
         git, curl, zsh, plus build deps for compiling Python from source).
      5. Creates the WSL user (matches the Windows username, lowercased)
         with passwordless sudo and zsh as the login shell.
      6. Seeds a complete /etc/wsl.conf (systemd, metadata mount, interop,
         resolv.conf control). systemd lives in /etc/wsl.conf, NOT
         ~/.wslconfig.
      7. Bootstraps chezmoi from GitHub over HTTPS (no SSH dependency on a
         fresh box that has neither a key nor a known_hosts entry).

    The script is designed to be hands-off: pass -Force (or set $env:CI to
    "true") to skip the destructive-confirmation prompt. Every native
    command checks $LASTEXITCODE, so install failures surface immediately
    instead of cascading into misleading readiness errors.

.PARAMETER DistroName
    Name of the WSL distribution to reset. Default: "archlinux".

.PARAMETER SkipBootstrap
    Only unregister and install WSL without running the chezmoi bootstrap.

.PARAMETER ChezmoiRepo
    GitHub repository for chezmoi dotfiles. Default: "Randallsm83/chezmoi".

.PARAMETER ChezmoiBranch
    Branch to use for chezmoi initialization. Default: "main".

.PARAMETER WslUser
    Linux username to create. Default: $env:USERNAME.ToLower().

.PARAMETER Force
    Skip the destructive-confirmation prompt. Set automatically when
    $env:CI -eq "true".

.EXAMPLE
    .\reset-wsl-arch.ps1
    Reset 'archlinux' with all defaults (still prompts for confirmation).

.EXAMPLE
    .\reset-wsl-arch.ps1 -Force
    Fully hands-off reset and bootstrap.

.EXAMPLE
    .\reset-wsl-arch.ps1 -ChezmoiBranch dev -Force
    Reset and bootstrap from the 'dev' branch (the branch reliably crosses
    the wsl.exe boundary — old script silently dropped it).

.NOTES
    Author: Randall
    Prerequisites:
      - WSL2 must be installed and enabled on Windows.
      - The Microsoft-Store-hosted 'archlinux' distro must be reachable
        (the script verifies via `wsl --list --online`).
      - Internet connection required.

    Duration: ~10-15 minutes for a complete reset + bootstrap.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Position = 0)]
    [string]$DistroName = "archlinux",

    [Parameter()]
    [switch]$SkipBootstrap,

    [Parameter()]
    [string]$ChezmoiRepo = "Randallsm83/chezmoi",

    [Parameter()]
    [string]$ChezmoiBranch = "main",

    [Parameter()]
    [ValidatePattern('^[a-z_][a-z0-9_-]{0,31}$')]
    [string]$WslUser = $env:USERNAME.ToLower(),

    [Parameter()]
    [Alias("Yes", "Unattended")]
    [switch]$Force
)

# ============================================================================
# Configuration
# ============================================================================

$ErrorActionPreference = "Stop"
# pwsh 7.3+ — make native commands honor $ErrorActionPreference so failed
# wsl/pacman/curl invocations actually throw instead of returning quietly
# with a non-zero exit code that the next happy-path log line ignores.
$PSNativeCommandUseErrorActionPreference = $true

$BootstrapUrl = "https://raw.githubusercontent.com/$ChezmoiRepo/$ChezmoiBranch/setup.sh"
$LogFile = Join-Path $env:TEMP "wsl-reset-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

if ($env:CI -eq "true") { $Force = $true }

# ============================================================================
# Logging helpers
# ============================================================================
# Renamed from Write-Warning/Write-Error to avoid shadowing built-in cmdlets
# that other modules (and the PowerShell host's own error-handling pipeline)
# may transitively call.

function Write-LogLine {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -Path $LogFile -Value "[$timestamp] $Message"
    Write-Host $Message -ForegroundColor $Color
}

function Write-Step    { param([string]$Message) Write-LogLine "`n▶ $Message" "Cyan" }
function Write-Ok      { param([string]$Message) Write-LogLine "✓ $Message" "Green" }
function Write-Warn    { param([string]$Message) Write-LogLine "⚠ $Message" "Yellow" }
function Write-Fail    { param([string]$Message) Write-LogLine "✗ $Message" "Red" }
function Write-Info    { param([string]$Message) Write-LogLine "  $Message" "Gray" }

# ============================================================================
# WSL helpers
# ============================================================================

function Test-WSLInstalled {
    try {
        $null = wsl.exe --version 2>&1
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

function Test-WSLDistroExists {
    param([string]$Distro)
    # `wsl --list --quiet` emits UTF-16LE on some Windows builds; rely on
    # the case-insensitive match rather than -contains for portability.
    $distros = (wsl.exe --list --quiet) 2>$null
    return [bool]($distros | Where-Object { $_ -and ($_.Trim() -ieq $Distro) })
}

function Test-WSLDistroAvailable {
    param([string]$Distro)
    $online = (wsl.exe --list --online) 2>$null
    return [bool]($online | Where-Object { $_ -match "^\s*$([regex]::Escape($Distro))\b" })
}

function Wait-ForWSLReady {
    param(
        [string]$Distro,
        [int]$MaxAttempts = 30,
        [int]$DelaySeconds = 2
    )

    Write-Step "Waiting for WSL instance '$Distro' to be ready..."
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            $result = (wsl.exe -d $Distro -- echo "ready") 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0 -and $result -match "ready") {
                Write-Ok "WSL instance ready (attempt $attempt/$MaxAttempts)"
                return $true
            }
        }
        catch {
            # Suppress and retry — `wsl.exe` exits non-zero while the VM warms up.
        }
        Start-Sleep -Seconds $DelaySeconds
    }
    Write-Fail "WSL instance did not become ready after $($MaxAttempts * $DelaySeconds)s"
    return $false
}

function Invoke-WslRoot {
    <#
        Runs a bash one-liner inside the distro as root. Errors throw because
        $PSNativeCommandUseErrorActionPreference is enabled at the top of the
        script — callers should wrap in try/catch when they need to recover.
    #>
    param(
        [Parameter(Mandatory)] [string]$Distro,
        [Parameter(Mandatory)] [string]$Bash
    )
    wsl.exe -d $Distro -u root -- bash -lc $Bash
}

# ============================================================================
# Main
# ============================================================================

function Main {
    Write-LogLine "`n╔═══════════════════════════════════════════════════════╗" "Cyan"
    Write-LogLine "║   Arch Linux WSL Reset & Bootstrap                    ║" "Cyan"
    Write-LogLine "╚═══════════════════════════════════════════════════════╝`n" "Cyan"
    Write-Info "Log file:       $LogFile"
    Write-Info "Distro:         $DistroName"
    Write-Info "WSL user:       $WslUser"
    Write-Info "Chezmoi repo:   $ChezmoiRepo (branch: $ChezmoiBranch)"
    Write-Info "Force:          $Force"
    Write-Info "SkipBootstrap:  $SkipBootstrap"

    # ----------------------------------------------------------------------
    # Preflight
    # ----------------------------------------------------------------------
    if (-not (Test-WSLInstalled)) {
        Write-Fail "WSL is not installed or not properly configured."
        Write-Info "Install with: wsl --install"
        exit 1
    }
    Write-Ok "WSL is installed"

    # Ensure new VMs default to WSL2 (systemd needs WSL2).
    Write-Step "Ensuring default WSL version is 2..."
    wsl.exe --set-default-version 2 | Out-Null
    Write-Ok "WSL default version set to 2"

    if (-not (Test-WSLDistroAvailable $DistroName)) {
        Write-Warn "'$DistroName' is not in ``wsl --list --online``. Running ``wsl --update`` first."
        wsl.exe --update | Out-Null
        if (-not (Test-WSLDistroAvailable $DistroName)) {
            Write-Fail "'$DistroName' still unavailable after ``wsl --update``. Reboot may be required."
            exit 1
        }
    }
    Write-Ok "'$DistroName' is available for install"

    # ----------------------------------------------------------------------
    # Confirmation
    # ----------------------------------------------------------------------
    $distroExists = Test-WSLDistroExists $DistroName
    if ($distroExists) {
        Write-Warn "This will DELETE ALL DATA in the '$DistroName' WSL instance."
        if (-not $Force) {
            if (-not $PSCmdlet.ShouldProcess($DistroName, "Unregister and reinstall WSL distro")) {
                Write-LogLine "`nOperation cancelled by user" "Yellow"
                exit 0
            }
            $confirmation = Read-Host "Continue? (y/N)"
            if ($confirmation -notmatch '^[yY]$') {
                Write-LogLine "`nOperation cancelled by user" "Yellow"
                exit 0
            }
        }
        else {
            Write-Info "-Force / `$env:CI=true detected — skipping confirmation"
        }

        Write-Step "Unregistering existing '$DistroName'..."
        wsl.exe --unregister $DistroName
        Write-Ok "'$DistroName' unregistered"
    }
    else {
        Write-Info "No existing '$DistroName' instance found"
    }

    # ----------------------------------------------------------------------
    # Install
    # ----------------------------------------------------------------------
    Write-Step "Installing fresh '$DistroName'..."
    Write-Info "(This may take several minutes)"
    wsl.exe --install $DistroName --no-launch
    Write-Ok "'$DistroName' installed"

    if (-not (Wait-ForWSLReady -Distro $DistroName)) {
        Write-Fail "Aborting — distro never came up. See $LogFile"
        exit 1
    }

    # ----------------------------------------------------------------------
    # Keyring refresh (avoids PGP failures on stale distro images)
    # ----------------------------------------------------------------------
    Write-Step "Refreshing archlinux-keyring..."
    $keyringBash = @'
set -euo pipefail
pacman-key --init
pacman-key --populate archlinux
pacman -Sy --noconfirm archlinux-keyring
'@
    try {
        Invoke-WslRoot -Distro $DistroName -Bash $keyringBash
        Write-Ok "Keyring refreshed"
    }
    catch {
        Write-Fail "Failed to refresh archlinux-keyring: $($_.Exception.Message)"
        Write-Info "Full log: $LogFile"
        exit 1
    }

    # ----------------------------------------------------------------------
    # Base packages (just enough for chezmoi to take over)
    #
    # Includes Python stdlib build deps (bzip2/xz/tk/sqlite/ncurses/gdbm)
    # so that the source-compiled Python landed by `mise install python`
    # actually has bz2/lzma/sqlite3/tkinter/curses/dbm.gnu modules.
    # ----------------------------------------------------------------------
    Write-Step "Installing base packages..."
    $basePackages = @(
        "sudo", "base-devel", "git", "curl", "wget", "unzip", "zip",
        "openssl", "readline", "zlib", "libyaml", "libffi", "zsh",
        # Python stdlib build deps
        "bzip2", "xz", "tk", "sqlite", "ncurses", "gdbm",
        # 1Password SSH agent bridge from WSL to Windows
        "socat"
    ) -join " "
    $installBash = "pacman -Syu --noconfirm $basePackages"
    try {
        Invoke-WslRoot -Distro $DistroName -Bash $installBash
        Write-Ok "Base packages installed"
    }
    catch {
        Write-Fail "Failed to install base packages: $($_.Exception.Message)"
        Write-Info "Full log: $LogFile"
        exit 1
    }

    # ----------------------------------------------------------------------
    # User creation + login shell
    # ----------------------------------------------------------------------
    Write-Step "Creating user '$WslUser' with zsh as login shell..."
    # Single-quote the bash here-string so PowerShell does not interpolate
    # $-prefixed shell variables; PS values are injected via a `-c` arg list.
    $userBash = @"
set -euo pipefail
useradd -m -G wheel -s /bin/zsh '$WslUser'
passwd -d '$WslUser'
mkdir -p /etc/sudoers.d
printf '%s ALL=(ALL) NOPASSWD:ALL\n' '$WslUser' > /etc/sudoers.d/'$WslUser'
chmod 440 /etc/sudoers.d/'$WslUser'
# Belt-and-suspenders: ensure /usr/bin/zsh is in /etc/shells in case a
# later chezmoi-driven chsh runs and PAM rejects an unlisted shell.
grep -qx /usr/bin/zsh /etc/shells || echo /usr/bin/zsh >> /etc/shells
"@
    try {
        Invoke-WslRoot -Distro $DistroName -Bash $userBash
        Write-Ok "User '$WslUser' created with zsh login shell + passwordless sudo"
    }
    catch {
        Write-Fail "Failed to create user: $($_.Exception.Message)"
        exit 1
    }

    # ----------------------------------------------------------------------
    # /etc/wsl.conf — complete configuration (NOT just [user])
    # ----------------------------------------------------------------------
    Write-Step "Writing /etc/wsl.conf with full configuration..."
    $wslConfBash = @"
set -euo pipefail
cat > /etc/wsl.conf <<'__WSL_CONF__'
# Managed by scripts/reset-wsl-arch.ps1 (initial seed).
# chezmoi reconciles drift via run_onchange_after_05_wsl_conf.sh.tmpl.

[user]
default=$WslUser

[boot]
# systemd MUST live in /etc/wsl.conf, not ~/.wslconfig. The .wslconfig
# [boot] section only accepts ``command=`` per the WSL docs.
systemd=true

[automount]
enabled=true
options="metadata,umask=22,fmask=11"
mountFsTab=true

[network]
generateResolvConf=false
hostname=$DistroName

[interop]
enabled=true
appendWindowsPath=false
__WSL_CONF__
"@
    try {
        Invoke-WslRoot -Distro $DistroName -Bash $wslConfBash
        Write-Ok "/etc/wsl.conf seeded"
    }
    catch {
        Write-Fail "Failed to write /etc/wsl.conf: $($_.Exception.Message)"
        exit 1
    }

    # ----------------------------------------------------------------------
    # Restart so the new user + wsl.conf take effect, then re-probe.
    # ----------------------------------------------------------------------
    Write-Step "Restarting WSL to apply user + wsl.conf..."
    wsl.exe --terminate $DistroName
    Start-Sleep -Seconds 2
    if (-not (Wait-ForWSLReady -Distro $DistroName)) {
        Write-Fail "WSL did not come back up after terminate"
        exit 1
    }

    # ----------------------------------------------------------------------
    # Bootstrap chezmoi (HTTPS — fresh box has no SSH key/known_hosts)
    # ----------------------------------------------------------------------
    if (-not $SkipBootstrap) {
        Write-Step "Bootstrapping chezmoi from $ChezmoiRepo#$ChezmoiBranch..."
        Write-Info "(setup.sh will install mise, runtimes, packages; ~10 minutes)"
        # Interpolate REPO/BRANCH directly so setup.sh sees them — env vars
        # set on the Windows side do NOT cross the wsl.exe boundary without
        # an explicit $env:WSLENV mapping. Inline interpolation is simpler.
        $bootstrapBash = "REPO='$ChezmoiRepo' BRANCH='$ChezmoiBranch' curl -fsSL '$BootstrapUrl' | bash"
        try {
            wsl.exe -d $DistroName -- bash -lc $bootstrapBash
            Write-Ok "Chezmoi bootstrap completed"
        }
        catch {
            Write-Fail "Chezmoi bootstrap failed: $($_.Exception.Message)"
            Write-Info "Retry manually with:"
            Write-Info "  wsl -d $DistroName -- bash -c `"REPO='$ChezmoiRepo' BRANCH='$ChezmoiBranch' curl -fsSL '$BootstrapUrl' | bash`""
            exit 1
        }
    }
    else {
        Write-Warn "Skipping chezmoi bootstrap (-SkipBootstrap)"
    }

    # ----------------------------------------------------------------------
    # Summary
    # ----------------------------------------------------------------------
    Write-LogLine "`n╔═══════════════════════════════════════════════════════╗" "Green"
    Write-LogLine "║          Setup Complete! 🎉                           ║" "Green"
    Write-LogLine "╚═══════════════════════════════════════════════════════╝`n" "Green"
    Write-Info "Log file: $LogFile"
    Write-LogLine "Next steps:" "White"
    Write-LogLine "  1. Launch WSL:  wsl -d $DistroName" "White"
    Write-LogLine "  2. Verify:      chezmoi doctor && starship --version && mise --version" "White"
    Write-LogLine "  3. Re-apply:    chezmoi apply  # should be no-op (zero drift)" "White"
    if ($SkipBootstrap) {
        Write-LogLine "`nBootstrap manually with:" "Yellow"
        Write-LogLine "  wsl -d $DistroName -- bash -c `"REPO='$ChezmoiRepo' BRANCH='$ChezmoiBranch' curl -fsSL '$BootstrapUrl' | bash`"`n" "Yellow"
    }
}

try {
    Main
}
catch {
    Write-Fail "Unexpected error: $($_.Exception.Message)"
    Write-Info "Full log: $LogFile"
    exit 1
}

# vim: ts=2 sts=2 sw=2 et

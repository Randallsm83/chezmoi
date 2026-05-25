#Requires -Version 5.1
<#
.SYNOPSIS
    Bootstrap script for dotfiles setup on Windows
    
.DESCRIPTION
    This script will:
    1. Install chezmoi (via scoop or winget)
    2. Initialize chezmoi and apply dotfiles from repository
    3. Install scoop if needed
    4. Configure XDG environment variables
    5. Trigger package installation via chezmoi run scripts
    
.PARAMETER Repository
    GitHub repository (default: Randallsm83/chezmoi)
    
.PARAMETER Branch
    Branch to clone (default: main)
    
.PARAMETER WhatIf
    Show what would be done without making changes

.PARAMETER UseSSH
    Clone the chezmoi source repository via SSH (git@github.com:Repo.git)
    instead of the default HTTPS URL. SSH requires keys to already be loaded
    in an agent (1Password SSH agent, etc.). When this switch is set and the
    SSH clone fails, the script automatically retries via HTTPS so fresh
    machines without keys still succeed.

.EXAMPLE
    # One-command install from GitHub (production)
    iwr -useb https://raw.githubusercontent.com/Randallsm83/chezmoi/main/bootstrap.ps1 | iex
    
.EXAMPLE
    # Local install
    .\bootstrap.ps1
    
.EXAMPLE
    # Test mode
    .\bootstrap.ps1 -WhatIf
    
.EXAMPLE
    # Custom repository or branch
    .\bootstrap.ps1 -Repository "youruser/dotfiles" -Branch "develop"
    
.EXAMPLE
    # Restore from a scoop export (installs scoop, imports packages, then chezmoi)
    .\bootstrap.ps1 -ScoopExport .\scoop-export.json
    
.EXAMPLE
    # Restore from both exports
    .\bootstrap.ps1 -ScoopExport .\scoop-export.json -WingetExport .\winget-export.json
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Repository = "Randallsm83/chezmoi",
    [string]$Branch = "main",
    [switch]$SkipPackages,
    [switch]$UseSSH,
    [string]$ScoopExport,
    [string]$WingetExport
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# ============================================================================
# Configuration
# ============================================================================

$Script:Stats = @{
    StartTime = Get-Date
    ChezmoiInstalled = $false
    ScoopInstalled = $false
    PackagesInstalled = 0
    ConfigsApplied = $false
    PreflightPassed = $false
    DevModeEnabled = $false
    OnePasswordAvailable = $false
}

# ============================================================================
# Helper Functions
# ============================================================================

function Write-Status {
    <#
    .SYNOPSIS
        Write formatted status message with colored icon
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Type = 'Info'
    )
    
    $colors = @{
        Info = 'Cyan'
        Success = 'Green'
        Warning = 'Yellow'
        Error = 'Red'
    }
    
    $symbols = @{
        Info = 'ℹ'
        Success = '✓'
        Warning = '⚠'
        Error = '✗'
    }
    
    Write-Host "$($symbols[$Type]) " -ForegroundColor $colors[$Type] -NoNewline
    Write-Host $Message
}

function Test-CommandExists {
    <#
    .SYNOPSIS
        Test if a command is available in PATH
    #>
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Write-Progress {
    <#
    .SYNOPSIS
        Show progress bar with step information
    #>
    param(
        [int]$Step,
        [int]$TotalSteps,
        [string]$Activity,
        [string]$Status
    )
    
    $percentComplete = ($Step / $TotalSteps) * 100
    Microsoft.PowerShell.Utility\Write-Progress -Activity $Activity -Status "$Status (Step $Step of $TotalSteps)" -PercentComplete $percentComplete
}

function Test-DeveloperMode {
    <#
    .SYNOPSIS
        Check if Windows Developer Mode is enabled
    .DESCRIPTION
        Developer Mode is required for creating symlinks without elevation.
        Checks the registry key that controls this setting.
    #>
    try {
        $devModeKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
        $allowDevelopmentWithoutDevLicense = Get-ItemProperty -Path $devModeKey -Name 'AllowDevelopmentWithoutDevLicense' -ErrorAction SilentlyContinue
        
        if ($null -ne $allowDevelopmentWithoutDevLicense -and $allowDevelopmentWithoutDevLicense.AllowDevelopmentWithoutDevLicense -eq 1) {
            return $true
        }
        return $false
    } catch {
        return $false
    }
}

function Enable-DeveloperMode {
    <#
    .SYNOPSIS
        Enable Windows Developer Mode (requires elevation)
    #>
    Write-Status "Attempting to enable Developer Mode..." -Type Info
    Write-Status "This requires administrator privileges" -Type Warning
    
    try {
        # Check if running as admin
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if (-not $isAdmin) {
            Write-Status "Please run PowerShell as Administrator to enable Developer Mode" -Type Error
            Write-Host ""
            Write-Host "  To enable manually:"
            Write-Host "  1. Open Settings > Privacy & Security > For developers"
            Write-Host "  2. Enable 'Developer Mode'"
            Write-Host "  3. Restart this script"
            Write-Host ""
            return $false
        }
        
        # Enable Developer Mode via registry
        $devModeKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
        if (-not (Test-Path $devModeKey)) {
            New-Item -Path $devModeKey -Force | Out-Null
        }
        Set-ItemProperty -Path $devModeKey -Name 'AllowDevelopmentWithoutDevLicense' -Value 1 -Type DWord
        
        Write-Status "Developer Mode enabled successfully" -Type Success
        return $true
    } catch {
        Write-Status "Failed to enable Developer Mode: $_" -Type Error
        return $false
    }
}

function Test-OnePasswordCLI {
    <#
    .SYNOPSIS
        Check if 1Password CLI is available and authenticated
    #>
    if (-not (Test-CommandExists op)) {
        return @{
            Available = $false
            Authenticated = $false
            Message = '1Password CLI not installed'
        }
    }
    
    # Test if authenticated by trying to list items
    try {
        $null = op item list --format=json 2>$null
        return @{
            Available = $true
            Authenticated = $true
            Message = '1Password CLI available and authenticated'
        }
    } catch {
        return @{
            Available = $true
            Authenticated = $false
            Message = '1Password CLI installed but not authenticated'
        }
    }
}

# ============================================================================
# Pre-flight Validation
# ============================================================================

function Invoke-PreflightChecks {
    <#
    .SYNOPSIS
        Perform pre-flight validation before bootstrap
    .DESCRIPTION
        Checks system requirements and provides clear guidance for missing prerequisites
    #>
    Write-Host ""
    Write-Status "Running pre-flight checks..." -Type Info
    Write-Host ""
    
    $allPassed = $true
    
    # Check 1: PowerShell version
    Write-Host "  [1/5] PowerShell version..." -NoNewline
    if ($PSVersionTable.PSVersion.Major -ge 5) {
        Write-Host " ✓" -ForegroundColor Green
    } else {
        Write-Host " ✗" -ForegroundColor Red
        Write-Status "PowerShell 5.1 or later required" -Type Error
        $allPassed = $false
    }
    
    # Check 2: Developer Mode (required for symlinks)
    Write-Host "  [2/5] Developer Mode..." -NoNewline
    if (Test-DeveloperMode) {
        Write-Host " ✓" -ForegroundColor Green
        $Script:Stats.DevModeEnabled = $true
    } else {
        Write-Host " ⚠" -ForegroundColor Yellow
        Write-Host ""
        Write-Status "Developer Mode is NOT enabled" -Type Warning
        Write-Status "Chezmoi uses symlinks which require Developer Mode on Windows" -Type Info
        Write-Host ""
        
        $response = Read-Host "  Would you like to enable Developer Mode now? (y/N)"
        if ($response -eq 'y' -or $response -eq 'Y') {
            if (Enable-DeveloperMode) {
                $Script:Stats.DevModeEnabled = $true
            } else {
                Write-Status "Cannot continue without Developer Mode" -Type Error
                Write-Status "Chezmoi will fall back to copy mode (less efficient)" -Type Warning
            }
        } else {
            Write-Status "Continuing without Developer Mode" -Type Warning
            Write-Status "Symlinks will not work - chezmoi will use copy mode" -Type Info
        }
    }
    
    # Check 3: Internet connectivity
    Write-Host "  [3/5] Internet connectivity..." -NoNewline
    try {
        $null = Invoke-WebRequest -Uri "https://github.com" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        Write-Host " ✓" -ForegroundColor Green
    } catch {
        Write-Host " ✗" -ForegroundColor Red
        Write-Status "Cannot reach github.com" -Type Error
        $allPassed = $false
    }
    
    # Check 4: Package manager availability
    Write-Host "  [4/5] Package manager..." -NoNewline
    if ((Test-CommandExists scoop) -or (Test-CommandExists winget)) {
        Write-Host " ✓" -ForegroundColor Green
    } else {
        Write-Host " ⚠" -ForegroundColor Yellow
        Write-Status "Neither scoop nor winget found (will install scoop)" -Type Info
    }
    
    # Check 5: 1Password CLI (optional but recommended)
    Write-Host "  [5/5] 1Password CLI..." -NoNewline
    $opStatus = Test-OnePasswordCLI
    if ($opStatus.Authenticated) {
        Write-Host " ✓" -ForegroundColor Green
        $Script:Stats.OnePasswordAvailable = $true
    } elseif ($opStatus.Available) {
        Write-Host " ⚠" -ForegroundColor Yellow
        Write-Status "$($opStatus.Message)" -Type Warning
        Write-Status "You'll need to authenticate: op signin" -Type Info
    } else {
        Write-Host " -" -ForegroundColor Gray
        Write-Status "Optional: 1Password CLI not installed (secrets management unavailable)" -Type Info
    }
    
    Write-Host ""
    
    if ($allPassed) {
        Write-Status "Pre-flight checks passed!" -Type Success
        $Script:Stats.PreflightPassed = $true
        return $true
    } else {
        Write-Status "Some pre-flight checks failed" -Type Error
        return $false
    }
}

# ============================================================================
# Scoop Import (from export file)
# ============================================================================

function Import-ScoopExport {
    <#
    .SYNOPSIS
        Bulk-install packages from a scoop export JSON file
    .DESCRIPTION
        Uses 'scoop import' to restore all buckets and apps from an export.
        Requires scoop to already be installed.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ExportFile
    )
    
    if (-not (Test-Path $ExportFile)) {
        Write-Status "Scoop export file not found: $ExportFile" -Type Error
        return $false
    }
    
    if (-not (Test-CommandExists scoop)) {
        Write-Status "Scoop not installed yet - cannot import" -Type Error
        return $false
    }
    
    Write-Status "Importing packages from scoop export..." -Type Info
    
    try {
        $export = Get-Content $ExportFile -Raw | ConvertFrom-Json
        $appCount = ($export.apps | Measure-Object).Count
        $bucketCount = ($export.buckets | Measure-Object).Count
        Write-Status "Found $appCount apps across $bucketCount buckets" -Type Info
        
        scoop import $ExportFile
        
        Write-Status "Scoop import complete ($appCount apps)" -Type Success
        return $true
    } catch {
        Write-Status "Scoop import failed: $_" -Type Error
        Write-Status "Chezmoi will install remaining packages via feature flags" -Type Warning
        return $false
    }
}

function Import-WingetExport {
    <#
    .SYNOPSIS
        Bulk-install packages from a winget export JSON file
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ExportFile
    )
    
    if (-not (Test-Path $ExportFile)) {
        Write-Status "Winget export file not found: $ExportFile" -Type Error
        return $false
    }
    
    if (-not (Test-CommandExists winget)) {
        Write-Status "Winget not available - cannot import" -Type Error
        return $false
    }
    
    Write-Status "Importing packages from winget export..." -Type Info
    
    try {
        winget import --import-file $ExportFile --accept-package-agreements --accept-source-agreements --ignore-unavailable
        
        Write-Status "Winget import complete" -Type Success
        return $true
    } catch {
        Write-Status "Winget import failed: $_" -Type Error
        Write-Status "Chezmoi will install remaining packages via feature flags" -Type Warning
        return $false
    }
}

# ============================================================================
# Chezmoi Installation
# ============================================================================

function Install-Chezmoi {
    <#
    .SYNOPSIS
        Install chezmoi via scoop (preferred) or winget (fallback)
    #>
    Write-Status "Checking chezmoi installation..." -Type Info
    
    if (Test-CommandExists chezmoi) {
        Write-Status "chezmoi is already installed" -Type Success
        $Script:Stats.ChezmoiInstalled = $true
        return $true
    }
    
    Write-Status "Installing chezmoi..." -Type Info
    
    # Try scoop first (preferred for CLI tools - no admin required)
    if (Test-CommandExists scoop) {
        Write-Status "Using scoop to install chezmoi..." -Type Info
        try {
            scoop install chezmoi
            $Script:Stats.ChezmoiInstalled = $true
            Write-Status "chezmoi installed via scoop" -Type Success
            return $true
        } catch {
            Write-Status "Scoop installation failed: $_" -Type Warning
        }
    }
    
    # Fallback to winget
    if (Test-CommandExists winget) {
        Write-Status "Using winget to install chezmoi..." -Type Info
        try {
            winget install --id twpayne.chezmoi --source winget --accept-package-agreements --accept-source-agreements
            $Script:Stats.ChezmoiInstalled = $true
            Write-Status "chezmoi installed via winget" -Type Success
            
            # Refresh PATH to make chezmoi available
            $env:PATH = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            return $true
        } catch {
            Write-Status "Winget installation failed: $_" -Type Error
            return $false
        }
    }
    
    Write-Status "No package manager found (scoop or winget required)" -Type Error
    return $false
}

# ============================================================================
# Scoop Installation
# ============================================================================

function Install-Scoop {
    <#
    .SYNOPSIS
        Install scoop package manager if not present
    .DESCRIPTION
        Scoop is used for CLI tools on Windows (no admin required)
    #>
    if (Test-CommandExists scoop) {
        Write-Status "scoop is already installed" -Type Success
        $Script:Stats.ScoopInstalled = $true
        return $true
    }
    
    Write-Status "Installing scoop..." -Type Info
    
    try {
        # Check and set execution policy if restricted
        $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
        if ($currentPolicy -eq 'Restricted') {
            Write-Status "Setting execution policy to RemoteSigned..." -Type Info
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        }
        
        # Install scoop from official source
        Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
        
        $Script:Stats.ScoopInstalled = $true
        Write-Status "scoop installed successfully" -Type Success
        return $true
    } catch {
        Write-Status "Failed to install scoop: $_" -Type Error
        return $false
    }
}

# ============================================================================
# Chezmoi Initialization
# ============================================================================

function Initialize-Chezmoi {
    <#
    .SYNOPSIS
        Initialize chezmoi from GitHub repository and apply dotfiles
    .DESCRIPTION
        Clones the repository to chezmoi's default source dir
        (~/.local/share/chezmoi) and applies all configs.

        Defaults to HTTPS so fresh machines without an SSH key still work.
        Pass -UseSSH to attempt SSH first (faster + uses the 1Password SSH
        agent); on SSH failure, falls back to HTTPS automatically. This
        mirrors the unix bootstrap pattern in setup.sh (USE_SSH=1).
    #>
    param(
        [string]$Repo,
        [string]$Branch,
        [switch]$UseSSH
    )

    Write-Status "Initializing chezmoi from $Repo..." -Type Info

    # Build candidate URLs. If $Repo is already a full URL (http(s):// or
    # git@), respect it as-is and skip the fallback dance — the user told us
    # exactly what they want.
    $hasExplicitUrl = $Repo -match '^(https?://|git@)'
    $sshUrl   = if ($hasExplicitUrl) { $Repo } else { "git@github.com:$Repo.git" }
    $httpsUrl = if ($hasExplicitUrl) { $Repo } else { "https://github.com/$Repo.git" }

    # Try-clone helper. chezmoi exits non-zero on clone failure but doesn't
    # throw a PowerShell terminating error, so we inspect $LASTEXITCODE
    # rather than relying on try/catch alone.
    function Invoke-ChezmoiInit {
        param([string]$Url, [string]$BranchName, [string]$Label)
        Write-Status "Cloning via $Label ($Url)..." -Type Info
        try {
            $global:LASTEXITCODE = 0
            chezmoi init --apply --branch $BranchName $Url
            return ($LASTEXITCODE -eq 0)
        } catch {
            Write-Status "chezmoi init via $Label threw: $_" -Type Warning
            return $false
        }
    }

    # Initialize chezmoi from repository and apply all configs
    # This will:
    # 1. Clone repository to chezmoi's default source dir (~/.local/share/chezmoi)
    # 2. Run any run_once_before scripts
    # 3. Apply all dotfiles
    # 4. Run any run_once scripts (package installation)
    if ($UseSSH) {
        if (Invoke-ChezmoiInit -Url $sshUrl -BranchName $Branch -Label 'SSH') {
            $Script:Stats.ConfigsApplied = $true
            Write-Status "Dotfiles applied successfully (SSH)" -Type Success
            return $true
        }
        if ($hasExplicitUrl) {
            # Caller passed an explicit URL — don't second-guess it.
            Write-Status "chezmoi init failed for $sshUrl" -Type Error
            return $false
        }
        Write-Status "SSH clone failed; falling back to HTTPS" -Type Warning
    }

    if (Invoke-ChezmoiInit -Url $httpsUrl -BranchName $Branch -Label 'HTTPS') {
        $Script:Stats.ConfigsApplied = $true
        Write-Status "Dotfiles applied successfully (HTTPS)" -Type Success
        if (-not $hasExplicitUrl) {
            Write-Status "To switch the chezmoi source remote to SSH later: chezmoi git remote set-url origin $sshUrl" -Type Info
        }
        return $true
    }

    Write-Status "chezmoi init failed for both SSH and HTTPS" -Type Error
    return $false
}

# ============================================================================
# Environment Configuration
# ============================================================================

function Set-EnvironmentVariables {
    <#
    .SYNOPSIS
        Configure XDG Base Directory specification environment variables
    .DESCRIPTION
        Sets up XDG_CONFIG_HOME, XDG_DATA_HOME, XDG_STATE_HOME, XDG_CACHE_HOME
        for Windows following the same structure as Unix systems
    #>
    Write-Status "Configuring XDG environment variables..." -Type Info
    
    $xdgVars = @{
        'XDG_CONFIG_HOME' = "$env:USERPROFILE\.config"
        'XDG_DATA_HOME' = "$env:USERPROFILE\.local\share"
        'XDG_STATE_HOME' = "$env:USERPROFILE\.local\state"
        'XDG_CACHE_HOME' = "$env:USERPROFILE\.cache"
    }
    
    foreach ($var in $xdgVars.GetEnumerator()) {
        # Set for current user (persistent)
        [Environment]::SetEnvironmentVariable($var.Key, $var.Value, 'User')
        # Set for current session
        Set-Item -Path "env:$($var.Key)" -Value $var.Value
        
        # Create directory if it doesn't exist
        if (-not (Test-Path $var.Value)) {
            New-Item -ItemType Directory -Path $var.Value -Force | Out-Null
        }
    }
    
    Write-Status "XDG environment variables configured" -Type Success
}

# ============================================================================
# Main Execution
# ============================================================================

function Main {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║      Dotfiles Bootstrap (Windows)        ║" -ForegroundColor Cyan
    Write-Host "║              Version 2.0.0                ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════╝" -ForegroundColor Cyan
    
    $totalSteps = 5
    
    # Step 0: Pre-flight validation
    Write-Progress -Step 0 -TotalSteps $totalSteps -Activity "Bootstrap" -Status "Running pre-flight checks"
    if (-not (Invoke-PreflightChecks)) {
        Write-Status "Pre-flight checks failed - please fix the issues above" -Type Error
        Microsoft.PowerShell.Utility\Write-Progress -Activity "Bootstrap" -Completed
        exit 1
    }
    
    # Step 1: Configure XDG environment (do this early)
    Write-Progress -Step 1 -TotalSteps $totalSteps -Activity "Bootstrap" -Status "Setting up XDG environment"
    Set-EnvironmentVariables
    
    # Step 2: Install scoop (needed for chezmoi and packages)
    Write-Progress -Step 2 -TotalSteps $totalSteps -Activity "Bootstrap" -Status "Setting up package manager"
    if (-not $SkipPackages) {
        Install-Scoop | Out-Null
    } else {
        Write-Status "Skipping package manager setup (--SkipPackages specified)" -Type Info
    }
    
    # Step 2b: Import from exports if provided
    if ($ScoopExport) {
        Write-Progress -Step 2 -TotalSteps $totalSteps -Activity "Bootstrap" -Status "Importing scoop packages"
        Import-ScoopExport -ExportFile $ScoopExport
    }
    if ($WingetExport) {
        Write-Progress -Step 2 -TotalSteps $totalSteps -Activity "Bootstrap" -Status "Importing winget packages"
        Import-WingetExport -ExportFile $WingetExport
    }
    
    # Step 3: Install chezmoi (via scoop if available, winget fallback)
    Write-Progress -Step 3 -TotalSteps $totalSteps -Activity "Bootstrap" -Status "Installing chezmoi"
    if (-not (Install-Chezmoi)) {
        Write-Status "Bootstrap failed: Could not install chezmoi" -Type Error
        Microsoft.PowerShell.Utility\Write-Progress -Activity "Bootstrap" -Completed
        exit 1
    }
    
    # Step 4: Initialize chezmoi and apply dotfiles
    Write-Progress -Step 4 -TotalSteps $totalSteps -Activity "Bootstrap" -Status "Applying dotfiles configuration"
    Write-Host ""
    Write-Status "This will clone the repository and apply all configurations..." -Type Info
    Write-Status "Package installation scripts will run automatically" -Type Info
    Write-Host ""
    
    if (-not (Initialize-Chezmoi -Repo $Repository -Branch $Branch -UseSSH:$UseSSH)) {
        Write-Status "Bootstrap failed: Could not apply dotfiles" -Type Error
        Microsoft.PowerShell.Utility\Write-Progress -Activity "Bootstrap" -Completed
        exit 1
    }
    
    # Step 5: Finalize
    Write-Progress -Step 5 -TotalSteps $totalSteps -Activity "Bootstrap" -Status "Finalizing setup"
    Microsoft.PowerShell.Utility\Write-Progress -Activity "Bootstrap" -Completed
    
    # Summary
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║          Bootstrap Complete! 🎉           ║" -ForegroundColor Green
    Write-Host "╚═══════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    
    # Show statistics
    Write-Status "Bootstrap Statistics:" -Type Info
    Write-Host "  • Pre-flight passed: $($Script:Stats.PreflightPassed)"
    Write-Host "  • Developer Mode: $(if ($Script:Stats.DevModeEnabled) { 'Enabled' } else { 'Disabled' })"
    Write-Host "  • 1Password available: $(if ($Script:Stats.OnePasswordAvailable) { 'Yes' } else { 'No' })"
    Write-Host "  • Chezmoi installed: $($Script:Stats.ChezmoiInstalled)"
    Write-Host "  • Scoop installed: $($Script:Stats.ScoopInstalled)"
    Write-Host "  • Configs applied: $($Script:Stats.ConfigsApplied)"
    
    $elapsed = (Get-Date) - $Script:Stats.StartTime
    Write-Host "  • Total time: $($elapsed.TotalSeconds.ToString('F2'))s"
    
    Write-Host ""
    Write-Status "Next steps:" -Type Info
    Write-Host "  1. Restart your terminal to load new configs"
    Write-Host "  2. Run: chezmoi diff (to see applied changes)"
    Write-Host "  3. Run: chezmoi edit --apply <file> (to modify configs)"
    
    if (-not $Script:Stats.DevModeEnabled) {
        Write-Host ""
        Write-Status "Recommendation: Enable Developer Mode for better performance" -Type Warning
        Write-Host "  Settings > Privacy & Security > For developers > Developer Mode"
    }
    
    if (-not $Script:Stats.OnePasswordAvailable) {
        Write-Host ""
        Write-Status "Optional: Install 1Password CLI for secrets management" -Type Info
        Write-Host "  scoop install 1password-cli"
        Write-Host "  Then run: op signin"
    }
    
    Write-Host ""
}

# Run main function (unless dot-sourced)
if ($MyInvocation.InvocationName -ne '.') {
    Main
}

# vim: ts=2 sts=2 sw=2 et

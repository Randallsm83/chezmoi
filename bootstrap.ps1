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
    GitHub repository (default: Randallsm83/dotfiles)
    
.PARAMETER Branch
    Branch to clone (default: main)
    
.PARAMETER WhatIf
    Show what would be done without making changes
    
.EXAMPLE
    # One-command install from GitHub (production)
    iwr -useb https://raw.githubusercontent.com/Randallsm83/dotfiles/main/bootstrap.ps1 | iex
    
.EXAMPLE
    # Local install
    .\bootstrap.ps1
    
.EXAMPLE
    # Test mode
    .\bootstrap.ps1 -WhatIf
    
.EXAMPLE
    # Custom repository or branch
    .\bootstrap.ps1 -Repository "youruser/dotfiles" -Branch "develop"
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Repository = "Randallsm83/dotfiles",
    [string]$Branch = "main",
    [switch]$SkipPackages
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
        Clones the repository to ~/.local/share/chezmoi and applies all configs
    #>
    param(
        [string]$Repo,
        [string]$Branch
    )
    
    Write-Status "Initializing chezmoi from $Repo..." -Type Info
    
    # Convert shorthand to full GitHub URL if needed
    $repoUrl = if ($Repo -notmatch '^https?://') {
        "https://github.com/$Repo.git"
    } else {
        $Repo
    }
    
    try {
        # Initialize chezmoi from repository and apply all configs
        # This will:
        # 1. Clone repository to ~/.local/share/chezmoi
        # 2. Run any run_once_before scripts
        # 3. Apply all dotfiles
        # 4. Run any run_once scripts (package installation)
        chezmoi init --apply --branch $Branch $repoUrl
        
        $Script:Stats.ConfigsApplied = $true
        Write-Status "Dotfiles applied successfully" -Type Success
        return $true
    } catch {
        Write-Status "Failed to initialize chezmoi: $_" -Type Error
        return $false
    }
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
    Write-Host "╚═══════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    # Step 1: Install chezmoi
    if (-not (Install-Chezmoi)) {
        Write-Status "Bootstrap failed: Could not install chezmoi" -Type Error
        exit 1
    }
    
    # Step 2: Install scoop (if needed for packages)
    if (-not $SkipPackages) {
        Install-Scoop | Out-Null
    }
    
    # Step 3: Initialize chezmoi and apply dotfiles
    # This will trigger package installation scripts automatically
    if (-not (Initialize-Chezmoi -Repo $Repository -Branch $Branch)) {
        Write-Status "Bootstrap failed: Could not apply dotfiles" -Type Error
        exit 1
    }
    
    # Step 4: Configure XDG environment variables
    Set-EnvironmentVariables
    
    # Summary
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║          Bootstrap Complete! 🎉           ║" -ForegroundColor Green
    Write-Host "╚═══════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Status "Chezmoi installed: $($Script:Stats.ChezmoiInstalled)" -Type Info
    Write-Status "Scoop installed: $($Script:Stats.ScoopInstalled)" -Type Info
    Write-Status "Configs applied: $($Script:Stats.ConfigsApplied)" -Type Info
    
    $elapsed = (Get-Date) - $Script:Stats.StartTime
    Write-Status "Total time: $($elapsed.TotalSeconds.ToString('F2'))s" -Type Info
    
    Write-Host ""
    Write-Status "Next steps:" -Type Info
    Write-Host "  1. Restart your terminal to load new configs"
    Write-Host "  2. Run: chezmoi diff (to see applied changes)"
    Write-Host "  3. Run: chezmoi edit --apply <file> (to modify configs)"
    Write-Host ""
    Write-Status "Package installation runs automatically via chezmoi scripts" -Type Info
    Write-Host ""
}

# Run main function (unless dot-sourced)
if ($MyInvocation.InvocationName -ne '.') {
    Main
}

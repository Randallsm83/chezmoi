#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Reset and bootstrap Arch Linux WSL instance with chezmoi dotfiles

.DESCRIPTION
    This script automates the complete workflow for resetting a WSL Arch Linux instance:
    1. Unregisters (terminates) the existing WSL distribution
    2. Installs a fresh Arch Linux instance from the WSL repository
    3. Bootstraps the new instance with chezmoi dotfiles from GitHub
    
    The chezmoi bootstrap will install and configure:
    - mise (package and runtime manager)
    - CLI tools (ripgrep, fd, bat, eza, delta, starship, zoxide, etc.)
    - Language runtimes (Node.js, Python, Ruby, Go, Rust, Lua, Bun, Deno)
    - Neovim with LazyVim configuration
    - Zsh with starship prompt
    - 1Password SSH agent integration
    - All dotfiles from the chezmoi repository

.PARAMETER DistroName
    Name of the WSL distribution to reset. Default: "archlinux"

.PARAMETER SkipBootstrap
    If specified, only unregister and install WSL without running the chezmoi bootstrap

.PARAMETER ChezmoisRepo
    GitHub repository for chezmoi dotfiles. Default: "Randallsm83/dotfiles-redux"

.PARAMETER ChezmoiBranch
    Branch to use for chezmoi initialization. Default: "main"

.EXAMPLE
    .\reset-wsl-arch.ps1
    Reset the 'archlinux' WSL distribution with default settings

.EXAMPLE
    .\reset-wsl-arch.ps1 -DistroName "archlinux" -SkipBootstrap
    Only reset the WSL instance without running chezmoi bootstrap

.EXAMPLE
    .\reset-wsl-arch.ps1 -ChezmoiBranch "dev"
    Reset and bootstrap from the 'dev' branch of the chezmoi repository

.NOTES
    Author: Randall
    Prerequisites:
    - WSL2 must be installed and enabled on Windows
    - Internet connection required for downloading packages
    - 1Password with SSH agent configured (optional but recommended)
    
    Duration: ~10-15 minutes for complete setup
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$DistroName = "archlinux",
    
    [Parameter()]
    [switch]$SkipBootstrap,
    
    [Parameter()]
    [string]$ChezmoisRepo = "Randallsm83/dotfiles",
    
    [Parameter()]
    [string]$ChezmoiBranch = "main"
)

# ============================================================================
# Configuration
# ============================================================================

$ErrorActionPreference = "Stop"
$BootstrapUrl = "https://raw.githubusercontent.com/$ChezmoisRepo/$ChezmoiBranch/setup.sh"

# ============================================================================
# Helper Functions
# ============================================================================

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Step {
    param([string]$Message)
    Write-ColorOutput "`n▶ $Message" "Cyan"
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput "✓ $Message" "Green"
}

function Write-Warning {
    param([string]$Message)
    Write-ColorOutput "⚠ $Message" "Yellow"
}

function Write-Error {
    param([string]$Message)
    Write-ColorOutput "✗ $Message" "Red"
}

function Test-WSLInstalled {
    try {
        $null = wsl --version
        return $true
    }
    catch {
        return $false
    }
}

function Test-WSLDistroExists {
    param([string]$Distro)
    
    $distros = wsl --list --quiet
    return $distros -contains $Distro
}

function Wait-ForWSLReady {
    param([string]$Distro)
    
    Write-Step "Waiting for WSL instance to be ready..."
    $maxAttempts = 30
    $attempt = 0
    
    while ($attempt -lt $maxAttempts) {
        try {
            $result = wsl -d $Distro echo "ready" 2>&1
            if ($result -match "ready") {
                Write-Success "WSL instance is ready"
                return $true
            }
        }
        catch {
            # Ignore errors during wait
        }
        
        Start-Sleep -Seconds 2
        $attempt++
    }
    
    Write-Warning "WSL instance may not be fully ready, but continuing..."
    return $false
}

# ============================================================================
# Main Execution
# ============================================================================

function Main {
    Write-ColorOutput "`n╔═══════════════════════════════════════════════════════╗" "Cyan"
    Write-ColorOutput "║   Arch Linux WSL Reset & Bootstrap                   ║" "Cyan"
    Write-ColorOutput "╚═══════════════════════════════════════════════════════╝`n" "Cyan"
    
    # Verify WSL is installed
    if (-not (Test-WSLInstalled)) {
        Write-Error "WSL is not installed or not properly configured"
        Write-ColorOutput "Please install WSL using: wsl --install"
        exit 1
    }
    Write-Success "WSL is installed and available"
    
    # Check if distro exists
    $distroExists = Test-WSLDistroExists $DistroName
    
    if ($distroExists) {
        Write-Step "Terminating existing WSL instance: $DistroName"
        Write-Warning "This will DELETE ALL DATA in the WSL instance"
        
        $confirmation = Read-Host "Continue? (y/N)"
        if ($confirmation -ne "y" -and $confirmation -ne "Y") {
            Write-ColorOutput "Operation cancelled by user"
            exit 0
        }
        
        try {
            wsl --unregister $DistroName
            Write-Success "WSL instance '$DistroName' unregistered successfully"
        }
        catch {
            Write-Error "Failed to unregister WSL instance: $_"
            exit 1
        }
    }
    else {
        Write-ColorOutput "No existing WSL instance named '$DistroName' found"
    }
    
    # Install fresh Arch Linux instance
    Write-Step "Installing fresh Arch Linux WSL instance..."
    Write-ColorOutput "This may take several minutes..."
    
    try {
        wsl --install $DistroName --no-launch
        Write-Success "Arch Linux WSL installed successfully"
    }
    catch {
        Write-Error "Failed to install Arch Linux WSL: $_"
        Write-ColorOutput "You may need to run this script as Administrator"
        exit 1
    }
    
    # Wait for WSL to be ready
    Wait-ForWSLReady $DistroName
    
    # Create default user account
    Write-Step "Creating default user account..."
    $username = $env:USERNAME.ToLower()
    Write-ColorOutput "Using Windows username: $username"
    
    try {
        # Create user with home directory and sudo access
        wsl -d $DistroName -u root bash -c @"
set -e
useradd -m -G wheel -s /bin/bash $username
passwd -d $username
mkdir -p /etc/sudoers.d
echo '$username ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$username
chmod 440 /etc/sudoers.d/$username
"@
        Write-Success "User '$username' created successfully"
    }
    catch {
        Write-Error "Failed to create user account: $_"
        exit 1
    }
    
    # Configure default WSL user
    Write-Step "Configuring default WSL user..."
    try {
        wsl -d $DistroName -u root bash -c "echo -e '[user]\ndefault=$username' > /etc/wsl.conf"
        Write-Success "Default user set to '$username'"
        
        # Restart WSL to apply wsl.conf changes
        Write-Step "Restarting WSL to apply user configuration..."
        wsl --terminate $DistroName
        Start-Sleep -Seconds 2
        Wait-ForWSLReady $DistroName
    }
    catch {
        Write-Error "Failed to configure default user: $_"
        exit 1
    }
    
    # Bootstrap with chezmoi (unless skipped)
    if (-not $SkipBootstrap) {
        Write-Step "Bootstrapping with chezmoi dotfiles..."
        Write-ColorOutput "Repository: $ChezmoisRepo"
        Write-ColorOutput "Branch: $ChezmoiBranch"
        Write-ColorOutput "This will take 10-15 minutes (installing packages and compiling tools)...`n"
        
        try {
            # Set environment variables for the bootstrap script
            $env:REPO = $ChezmoisRepo
            $env:BRANCH = $ChezmoiBranch
            
            # Run bootstrap script in WSL
            wsl -d $DistroName bash -c "curl -fsSL $BootstrapUrl | bash"
            
            Write-Success "Chezmoi bootstrap completed successfully"
        }
        catch {
            Write-Error "Chezmoi bootstrap failed: $_"
            Write-ColorOutput "You can manually run the bootstrap later with:"
            Write-ColorOutput "  wsl -d $DistroName bash -c `"curl -fsSL $BootstrapUrl | bash`""
            exit 1
        }
    }
    else {
        Write-Warning "Skipping chezmoi bootstrap (use -SkipBootstrap:$false to enable)"
    }
    
    # Summary
    Write-ColorOutput "`n╔═══════════════════════════════════════════════════════╗" "Green"
    Write-ColorOutput "║          Setup Complete! 🎉                          ║" "Green"
    Write-ColorOutput "╚═══════════════════════════════════════════════════════╝`n" "Green"
    
    Write-ColorOutput "Next steps:"
    Write-ColorOutput "  1. Launch WSL:     wsl -d $DistroName"
    Write-ColorOutput "  2. Verify setup:   starship --version, mise --version, nvim --version"
    Write-ColorOutput "  3. Use zsh shell:  exec zsh`n"
    
    if ($SkipBootstrap) {
        Write-ColorOutput "Manual bootstrap: wsl -d $DistroName bash -c `"curl -fsSL $BootstrapUrl | bash`"`n"
    }
}

# Run main function
try {
    Main
}
catch {
    Write-Error "Unexpected error: $_"
    exit 1
}

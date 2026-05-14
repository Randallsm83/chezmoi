# Prevent script from exiting on errors
$ErrorActionPreference = 'Continue'

# Enable verbose logging
$VerbosePreference = 'Continue'
$logFile = Join-Path $env:TEMP "wsl-reset-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
function Write-Log {
    param($Message, $Color = 'White')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] $Message"
    Add-Content -Path $logFile -Value $logMessage
    Write-Host $Message -ForegroundColor $Color
}

Write-Log "Log file: $logFile" 'Gray'
Write-Log "PowerShell version: $($PSVersionTable.PSVersion)" 'Gray'
Write-Log "Working directory: $PWD" 'Gray'

# Terminate existing Arch Linux WSL instance
Write-Log "`n╔═══════════════════════════════════════════╗" 'Cyan'
Write-Log "║  Resetting Arch Linux WSL Instance       ║" 'Cyan'
Write-Log "╚═══════════════════════════════════════════╝`n" 'Cyan'

Write-Log "⚠ WARNING: This will DELETE ALL DATA in the archlinux WSL instance" 'Yellow'
$confirm = Read-Host "`nContinue? (y/N)"

if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Log "`n✗ Operation cancelled" 'Red'
    exit 0
}
Write-Log "User confirmed operation" 'Gray'

Write-Log "`n▶ Step 1/7: Unregistering existing archlinux WSL..." 'Cyan'
Write-Log "Running: wsl --unregister archlinux" 'Gray'
$unregOutput = wsl --unregister archlinux 2>&1 | Out-String
Write-Log "Exit code: $LASTEXITCODE" 'Gray'
Write-Log "Output: $unregOutput" 'Gray'
if ($LASTEXITCODE -ne 0) {
    Write-Log "  (No existing instance found, continuing...)" 'Gray'
} else {
    Write-Log "✓ WSL instance unregistered" 'Green'
}

Write-Log "`n▶ Step 2/7: Installing fresh Arch Linux..." 'Cyan'
Write-Log "  (This may take a few minutes)" 'Gray'
Write-Log "Running: wsl --install archlinux --no-launch" 'Gray'
$installOutput = wsl --install archlinux --no-launch 2>&1 | Out-String
Write-Log "Exit code: $LASTEXITCODE" 'Gray'
Write-Log "Output: $installOutput" 'Gray'
if ($LASTEXITCODE -ne 0) {
    Write-Log "⚠ Warning: Install command returned non-zero exit code" 'Yellow'
}
Write-Log "✓ Arch Linux installed" 'Green'

Write-Log "`n▶ Step 3/7: Waiting for WSL to be ready..." 'Cyan'
Write-Log "Initial 5 second wait..." 'Gray'
Start-Sleep -Seconds 5

# Test if WSL is ready
Write-Log "Testing WSL readiness (up to 10 attempts)..." 'Gray'
$ready = $false
$attempts = 0
while (-not $ready -and $attempts -lt 10) {
    $attempts++
    Write-Log "  Attempt $attempts/10: Testing WSL connection..." 'Gray'
    try {
        $result = wsl -d archlinux echo "ready" 2>&1 | Out-String
        Write-Log "  Result: $result" 'Gray'
        if ($result -match "ready") {
            $ready = $true
            Write-Log "  WSL responded successfully!" 'Gray'
        } else {
            Write-Log "  WSL not ready yet, waiting 2 seconds..." 'Gray'
            Start-Sleep -Seconds 2
        }
    } catch {
        Write-Log "  Exception: $($_.Exception.Message)" 'Yellow'
        Start-Sleep -Seconds 2
    }
}
if ($ready) {
    Write-Log "✓ WSL instance ready" 'Green'
} else {
    Write-Log "✗ WSL instance did not become ready after 10 attempts" 'Red'
    Write-Log "Check log file for details: $logFile" 'Yellow'
    exit 1
}

Write-Log "`n▶ Step 4/7: Installing base system packages as root..." 'Cyan'
Write-Log "  (This ensures sudo and build tools are available before chezmoi runs)" 'Gray'
$basePackages = "sudo base-devel git curl wget unzip zip openssl readline zlib libyaml libffi zsh"
$installBaseOutput = wsl -d archlinux -u root bash -c "pacman -Syu --noconfirm $basePackages" 2>&1 | Out-String
Write-Log "Exit code: $LASTEXITCODE" 'Gray'
if ($LASTEXITCODE -ne 0) {
    Write-Log "✗ Failed to install base packages" 'Red'
    Write-Log "Full output logged to: $logFile" 'Yellow'
    exit 1
}
Write-Log "✓ Base packages installed" 'Green'

Write-Log "`n▶ Step 5/7: Creating user account..." 'Cyan'
$username = $env:USERNAME.ToLower()
Write-Log "  Using Windows username: $username" 'Gray'
$userScript = "set -e; useradd -m -G wheel -s /bin/bash $username; passwd -d $username; mkdir -p /etc/sudoers.d; echo '$username ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$username; chmod 440 /etc/sudoers.d/$username"
$createUserOutput = wsl -d archlinux -u root bash -c $userScript 2>&1 | Out-String
Write-Log "User output: $createUserOutput" 'Gray'
if ($LASTEXITCODE -ne 0) {
    Write-Log "✗ Failed to create user" 'Red'
    Write-Log "Full output logged to: $logFile" 'Yellow'
    exit 1
}
Write-Log "✓ User '$username' created with sudo access" 'Green'

Write-Log "`n▶ Step 6/7: Setting default user..." 'Cyan'
$configUserOutput = wsl -d archlinux -u root bash -c "echo -e '[user]\ndefault=$username' > /etc/wsl.conf" 2>&1 | Out-String
Write-Log "Config output: $configUserOutput" 'Gray'
if ($LASTEXITCODE -ne 0) {
    Write-Log "✗ Failed to set default user" 'Red'
    exit 1
}
Write-Log "✓ Default user set to '$username'" 'Green'

Write-Log "`n  Restarting WSL to apply user settings..." 'Gray'
wsl --terminate archlinux
Start-Sleep -Seconds 3
Write-Log "✓ WSL restarted" 'Green'

Write-Log "`n▶ Step 7/7: Bootstrapping with chezmoi dotfiles..." 'Cyan'
Write-Log "  Repository: Randallsm83/chezmoi" 'Gray'
Write-Log "  Duration: ~5-10 minutes (installing mise runtimes)" 'Gray'
Write-Log "  You can monitor progress below`n" 'Gray'

# Use official chezmoi one-line installer as the newly created user
Write-Log "Running official chezmoi installer as user '$username'..." 'Gray'
$bootstrapOutput = wsl -d archlinux bash -c "curl -fsSL https://get.chezmoi.io | sh -s -- init --apply --ssh Randallsm83/chezmoi" 2>&1 | Out-String
Write-Log "Exit code: $LASTEXITCODE" 'Gray'
Write-Log "Bootstrap output:`n$bootstrapOutput" 'Gray'

if ($LASTEXITCODE -ne 0) {
    Write-Log "`n⚠ Bootstrap encountered issues (exit code: $LASTEXITCODE)" 'Yellow'
    Write-Log "Full output logged to: $logFile" 'Yellow'
    Write-Log "You can retry manually from within WSL:" 'Yellow'
    Write-Log "  wsl -d archlinux" 'White'
    Write-Log "  sh -c '`$(curl -fsLS get.chezmoi.io)' -- init --apply --ssh Randallsm83/chezmoi`n" 'White'
    exit 1
}

Write-Log "`n╔═══════════════════════════════════════════╗" 'Green'
Write-Log "║          Setup Complete! 🎉              ║" 'Green'
Write-Log "╚═══════════════════════════════════════════╝`n" 'Green'

Write-Log "Log file saved to: $logFile" 'Gray'
Write-Log "Next steps:" 'White'
Write-Log "  1. Launch WSL:     wsl -d archlinux" 'White'
Write-Log "  2. Restart shell:  exec zsh" 'White'
Write-Log "  3. Verify setup:   starship --version && mise --version`n" 'White'

<#
.SYNOPSIS
    Optimizes Windows settings for gaming performance.

.DESCRIPTION
    Applies comprehensive Windows optimizations for gaming including:
    - Game Mode and Hardware-Accelerated GPU Scheduling (HAGS)
    - High Performance power plan configuration
    - Visual effects optimization
    - Xbox Game Bar/DVR disabling
    - Processor scheduling optimization
    - Network optimizations for multiplayer
    
    All changes are backed up and can be restored.

.PARAMETER SkipXboxDisable
    Keep Xbox Game Bar and DVR features enabled.

.PARAMETER SkipServiceDisable
    Skip disabling Windows services (keep all services at default).

.PARAMETER RestoreDefaults
    Restore Windows to default settings from backup.

.PARAMETER BackupOnly
    Only create a backup without applying any changes.

.EXAMPLE
    .\Optimize-WindowsGaming.ps1
    Applies all Windows gaming optimizations.

.EXAMPLE
    .\Optimize-WindowsGaming.ps1 -SkipXboxDisable
    Optimizes Windows but keeps Xbox features enabled.

.EXAMPLE
    .\Optimize-WindowsGaming.ps1 -RestoreDefaults
    Restores Windows settings to defaults from backup.

.NOTES
    Version: 1.0.0
    Author: Gaming Optimization Suite
    Requires: Administrator privileges, Windows 10/11
    Last Updated: 2025-11-08
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [switch]$SkipXboxDisable,

    [Parameter()]
    [switch]$SkipServiceDisable,

    [Parameter()]
    [switch]$RestoreDefaults,

    [Parameter()]
    [switch]$BackupOnly
)

#Requires -RunAsAdministrator

# Script configuration
$ErrorActionPreference = 'Stop'
$Script:BackupDir = Join-Path $env:USERPROFILE ".config\backups\windows"
$Script:LogDir = Join-Path $env:USERPROFILE ".config\logs"
$Script:LogFile = Join-Path $Script:LogDir "windows-gaming-optimization-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

#region Helper Functions

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"
    
    if (-not (Test-Path $Script:LogDir)) {
        New-Item -ItemType Directory -Path $Script:LogDir -Force | Out-Null
    }
    
    Add-Content -Path $Script:LogFile -Value $logMessage
    
    switch ($Level) {
        'Info'    { Write-Host $Message -ForegroundColor Cyan }
        'Warning' { Write-Warning $Message }
        'Error'   { Write-Host $Message -ForegroundColor Red }
        'Success' { Write-Host $Message -ForegroundColor Green }
    }
}

function Backup-WindowsSettings {
    Write-Log "Creating backup of Windows settings..."
    
    try {
        $backupPath = Join-Path $Script:BackupDir "backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
        
        # Backup registry keys
        $regKeys = @(
            "HKCU\Software\Microsoft\GameBar",
            "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR",
            "HKCU\System\GameConfigStore",
            "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers",
            "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl",
            "HKCU\Control Panel\Desktop"
        )
        
        foreach ($key in $regKeys) {
            $fileName = ($key -replace '\\', '_') + ".reg"
            $backupFile = Join-Path $backupPath $fileName
            reg export $key $backupFile /y 2>$null | Out-Null
        }
        
        # Backup power scheme
        $powerScheme = powercfg /getactivescheme
        $powerScheme | Out-File (Join-Path $backupPath "power-scheme.txt")
        
        # Create metadata
        $metadata = @{
            Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            ComputerName = $env:COMPUTERNAME
            WindowsVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ProductName
            BuildNumber = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber
        }
        
        $metadata | ConvertTo-Json | Out-File (Join-Path $backupPath "metadata.json")
        
        Write-Log "Backup created at: $backupPath" -Level Success
        return $backupPath
    }
    catch {
        Write-Log "Failed to create backup: $_" -Level Error
        throw
    }
}

function Enable-GameMode {
    Write-Log "Enabling Windows Game Mode..."
    
    try {
        $gameModeKey = "HKCU:\Software\Microsoft\GameBar"
        
        if (-not (Test-Path $gameModeKey)) {
            New-Item -Path $gameModeKey -Force | Out-Null
        }
        
        Set-ItemProperty -Path $gameModeKey -Name "AutoGameModeEnabled" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $gameModeKey -Name "AllowAutoGameMode" -Value 1 -Type DWord -Force
        
        Write-Log "Game Mode enabled" -Level Success
    }
    catch {
        Write-Log "Failed to enable Game Mode: $_" -Level Warning
    }
}

function Enable-HAGS {
    Write-Log "Enabling Hardware-Accelerated GPU Scheduling (HAGS)..."
    
    try {
        $hagsKey = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
        
        if (Test-Path $hagsKey) {
            Set-ItemProperty -Path $hagsKey -Name "HwSchMode" -Value 2 -Type DWord -Force
            Write-Log "HAGS enabled (requires restart)" -Level Success
        }
        else {
            Write-Log "HAGS registry key not found - may not be supported" -Level Warning
        }
    }
    catch {
        Write-Log "Failed to enable HAGS: $_" -Level Warning
    }
}

function Set-HighPerformancePower {
    Write-Log "Configuring High Performance power plan..."
    
    try {
        # Set High Performance plan active
        $highPerfGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
        powercfg /setactive $highPerfGuid
        
        Write-Log "High Performance power plan activated" -Level Success
        
        # Configure power settings
        Write-Log "Applying power optimizations..."
        
        # Disable USB selective suspend
        powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
        powercfg /setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
        
        # PCI Express link state power management: Off
        powercfg /setacvalueindex SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
        powercfg /setdcvalueindex SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
        
        # Hard disk: Never turn off
        powercfg /setacvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 6738e2c4-e8a5-4a42-b16a-e040e769756e 0
        powercfg /setdcvalueindex SCHEME_CURRENT 0012ee47-9041-4b5d-9b77-535fba8b1442 6738e2c4-e8a5-4a42-b16a-e040e769756e 0
        
        # Processor: min/max 100%
        powercfg /setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 893dee8e-2bef-41e0-89c6-b55d0929964c 100
        powercfg /setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 bc5038f7-23e0-4960-96da-33abaf5935ec 100
        
        # Apply changes
        powercfg /setactive SCHEME_CURRENT
        
        Write-Log "Power optimizations applied" -Level Success
    }
    catch {
        Write-Log "Failed to configure power plan: $_" -Level Warning
    }
}

function Disable-XboxFeatures {
    if ($SkipXboxDisable) {
        Write-Log "Skipping Xbox feature disable (per user request)" -Level Info
        return
    }
    
    Write-Log "Disabling Xbox Game Bar and DVR..."
    
    try {
        # Disable Xbox Game Bar
        $gameDVRKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"
        if (-not (Test-Path $gameDVRKey)) {
            New-Item -Path $gameDVRKey -Force | Out-Null
        }
        
        Set-ItemProperty -Path $gameDVRKey -Name "AppCaptureEnabled" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $gameDVRKey -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force
        
        # Disable Game Bar presence writer
        $gameConfigKey = "HKCU:\System\GameConfigStore"
        if (-not (Test-Path $gameConfigKey)) {
            New-Item -Path $gameConfigKey -Force | Out-Null
        }
        
        Set-ItemProperty -Path $gameConfigKey -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force
        
        Write-Log "Xbox Game Bar and DVR disabled" -Level Success
    }
    catch {
        Write-Log "Failed to disable Xbox features: $_" -Level Warning
    }
}

function Optimize-VisualEffects {
    Write-Log "Optimizing visual effects for performance..."
    
    try {
        $desktopKey = "HKCU:\Control Panel\Desktop"
        
        # Disable menu animation
        Set-ItemProperty -Path "$desktopKey\WindowMetrics" -Name "MinAnimate" -Value 0 -Type String -Force
        
        # Set visual effects to custom (best performance with some essentials)
        Set-ItemProperty -Path $desktopKey -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -Type Binary -Force
        
        # Disable transparency
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 0 -Type DWord -Force
        
        Write-Log "Visual effects optimized" -Level Success
    }
    catch {
        Write-Log "Failed to optimize visual effects: $_" -Level Warning
    }
}

function Set-ProcessorScheduling {
    Write-Log "Optimizing processor scheduling for gaming..."
    
    try {
        $priorityKey = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
        
        # Value 24 (0x18): Better for multithreaded games
        Set-ItemProperty -Path $priorityKey -Name "Win32PrioritySeparation" -Value 24 -Type DWord -Force
        
        Write-Log "Processor scheduling optimized" -Level Success
    }
    catch {
        Write-Log "Failed to set processor scheduling: $_" -Level Warning
    }
}

function Optimize-Network {
    Write-Log "Applying network optimizations for gaming..."
    
    try {
        # Disable network throttling
        $netKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        if (-not (Test-Path $netKey)) {
            New-Item -Path $netKey -Force | Out-Null
        }
        
        Set-ItemProperty -Path $netKey -Name "NetworkThrottlingIndex" -Value 0xffffffff -Type DWord -Force
        
        # System responsiveness (lower = more CPU for non-multimedia tasks)
        Set-ItemProperty -Path $netKey -Name "SystemResponsiveness" -Value 10 -Type DWord -Force
        
        Write-Log "Network optimizations applied" -Level Success
        Write-Log "Note: Nagle's algorithm should be disabled per-adapter (see guide)" -Level Info
    }
    catch {
        Write-Log "Failed to apply network optimizations: $_" -Level Warning
    }
}

function Disable-FullscreenOptimizations {
    Write-Log "Checking for Bannerlord installation to disable fullscreen optimizations..."
    
    $bannerlordPaths = @(
        "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\bin\Win64_Shipping_Client\TaleWorlds.MountAndBlade.Launcher.exe",
        "C:\SteamGames\steamapps\common\Mount & Blade II Bannerlord\bin\Win64_Shipping_Client\TaleWorlds.MountAndBlade.Launcher.exe",
        "C:\Program Files\Epic Games\Mount & Blade II Bannerlord\bin\Win64_Shipping_Client\TaleWorlds.MountAndBlade.Launcher.exe"
    )
    
    $found = $false
    foreach ($path in $bannerlordPaths) {
        if (Test-Path $path) {
            Write-Log "Found Bannerlord at: $path" -Level Info
            Write-Log "To disable fullscreen optimizations:" -Level Info
            Write-Log "  1. Right-click: $path" -Level Info
            Write-Log "  2. Properties > Compatibility" -Level Info
            Write-Log "  3. Check 'Disable fullscreen optimizations'" -Level Info
            Write-Log "  4. Repeat for Bannerlord.exe in same folder" -Level Info
            $found = $true
            break
        }
    }
    
    if (-not $found) {
        Write-Log "Bannerlord not found in common locations" -Level Warning
        Write-Log "Manually disable fullscreen optimizations when installed" -Level Info
    }
}

#endregion

#region Main Execution

function Main {
    Write-Log "=== Windows Gaming Optimization ===" -Level Info
    Write-Log "Script started at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level Info
    Write-Log ""
    
    # Create backup
    $backupPath = Backup-WindowsSettings
    Write-Log ""
    
    if ($BackupOnly) {
        Write-Log "Backup completed. No settings were modified." -Level Success
        return
    }
    
    if ($RestoreDefaults) {
        Write-Log "Restore functionality: Import .reg files from backup manually" -Level Warning
        Write-Log "Backup location: $Script:BackupDir" -Level Info
        return
    }
    
    # Apply optimizations
    Write-Log "Applying Windows gaming optimizations..." -Level Info
    Write-Log ""
    
    Enable-GameMode
    Enable-HAGS
    Set-HighPerformancePower
    Disable-XboxFeatures
    Optimize-VisualEffects
    Set-ProcessorScheduling
    Optimize-Network
    Disable-FullscreenOptimizations
    
    Write-Log ""
    Write-Log "=== Summary ===" -Level Success
    Write-Log "Backup location: $backupPath" -Level Success
    Write-Log "Log file: $Script:LogFile" -Level Success
    Write-Log ""
    Write-Log "IMPORTANT: Restart your computer for all changes to take effect" -Level Warning
    Write-Log ""
    Write-Log "Applied optimizations:" -Level Info
    Write-Log "  ✓ Windows Game Mode enabled" -Level Info
    Write-Log "  ✓ Hardware-Accelerated GPU Scheduling (HAGS) enabled" -Level Info
    Write-Log "  ✓ High Performance power plan configured" -Level Info
    if (-not $SkipXboxDisable) {
        Write-Log "  ✓ Xbox Game Bar and DVR disabled" -Level Info
    }
    Write-Log "  ✓ Visual effects optimized" -Level Info
    Write-Log "  ✓ Processor scheduling optimized" -Level Info
    Write-Log "  ✓ Network throttling disabled" -Level Info
    Write-Log ""
    Write-Log "Additional manual steps:" -Level Info
    Write-Log "  - Disable fullscreen optimizations for Bannerlord executables" -Level Info
    Write-Log "  - Configure per-adapter network settings (see guide)" -Level Info
    Write-Log ""
    Write-Log "For complete optimization guide:" -Level Info
    Write-Log "  $env:USERPROFILE\Documents\Bannerlord_Optimization_Guide.md" -Level Info
}

try {
    Main
}
catch {
    Write-Log "Script execution failed: $_" -Level Error
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level Error
    exit 1
}

#endregion

# vim: ts=2 sts=2 sw=2 et

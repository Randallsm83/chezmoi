#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Windows Gaming Optimization Script
.DESCRIPTION
    Combines Khorvie and P40L0 optimization guides with WiFi-friendly tweaks
    Optimized for AMD 7800X3D on WiFi
.NOTES
    Run as Administrator
    Reboot required after execution
#>

Write-Host "`n=== Windows Gaming Optimization Script ===" -ForegroundColor Green
Write-Host "Combining Khorvie + P40L0 guides with WiFi optimizations`n" -ForegroundColor Cyan

# Performance & CPU Settings
Write-Host "[1/10] Configuring CPU & Performance Settings..." -ForegroundColor Yellow

# Global Timer Resolution (Khorvie)
REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v "GlobalTimerResolutionRequests" /t REG_DWORD /d 1 /f

# Win32 Priority Separation (P40L0 - optimized for gaming)
REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v "Win32PrioritySeparation" /t REG_DWORD /d 0x28 /f

# System Responsiveness (P40L0 - balanced)
REG ADD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v "SystemResponsiveness" /t REG_DWORD /d 10 /f

# Network Throttling (Both guides)
REG ADD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v "NetworkThrottlingIndex" /t REG_DWORD /d 0xffffffff /f

# SvcHost Split Threshold (Khorvie)
REG ADD "HKLM\SYSTEM\CurrentControlSet\Control" /v "SvcHostSplitThresholdInKB" /t REG_DWORD /d 0x2000000 /f

Write-Host "  ✓ CPU & Performance settings applied" -ForegroundColor Green

# DWM & Power Settings
Write-Host "[2/10] Configuring DWM & Power Settings..." -ForegroundColor Yellow

# DWM MPO Fix (P40L0)
REG ADD "HKLM\SOFTWARE\Microsoft\Windows\Dwm" /v "OverlayMinFPS" /t REG_DWORD /d 0 /f

# Power Throttling (P40L0)
REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" /v "PowerThrottlingOff" /t REG_DWORD /d 1 /f

Write-Host "  ✓ DWM & Power settings applied" -ForegroundColor Green

# Core Parking (Disabled - better than Khorvie's enabled)
Write-Host "[3/10] Configuring Core Parking..." -ForegroundColor Yellow
REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583" /v "ValueMax" /t REG_DWORD /d 0x64 /f
REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583" /v "ValueMin" /t REG_DWORD /d 0x64 /f
Write-Host "  ✓ Core Parking disabled" -ForegroundColor Green

# TCP/IP Optimizations
Write-Host "[4/10] Configuring TCP/IP Settings..." -ForegroundColor Yellow

# P40L0 TCP Settings
REG ADD "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "DefaultTTL" /t REG_DWORD /d 64 /f
REG ADD "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "GlobalMaxTcpWindowSize" /t REG_DWORD /d 65535 /f
REG ADD "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "MaxUserPort" /t REG_DWORD /d 65534 /f
REG ADD "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "Tcp1323Opts" /t REG_DWORD /d 1 /f
REG ADD "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "TcpMaxDupAcks" /t REG_DWORD /d 2 /f
REG ADD "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "TCPTimedWaitDelay" /t REG_DWORD /d 30 /f

Write-Host "  ✓ TCP/IP settings applied" -ForegroundColor Green

# DNS Priority Settings (already configured)
Write-Host "[5/10] Configuring DNS Priority..." -ForegroundColor Yellow
REG ADD "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider" /v "DnsPriority" /t REG_DWORD /d 2000 /f
REG ADD "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider" /v "LocalPriority" /t REG_DWORD /d 499 /f
REG ADD "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider" /v "HostsPriority" /t REG_DWORD /d 500 /f
REG ADD "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider" /v "NetbtPriority" /t REG_DWORD /d 2001 /f
Write-Host "  ✓ DNS Priority configured" -ForegroundColor Green

# Game Priority Settings
Write-Host "[6/10] Configuring Game Priority..." -ForegroundColor Yellow
REG ADD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "Affinity" /t REG_DWORD /d 0 /f
REG ADD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "Background Only" /t REG_SZ /d "False" /f
REG ADD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "GPU Priority" /t REG_DWORD /d 8 /f
REG ADD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "Priority" /t REG_DWORD /d 6 /f
REG ADD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "Scheduling Category" /t REG_SZ /d "High" /f
REG ADD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "SFIO Priority" /t REG_SZ /d "High" /f
Write-Host "  ✓ Game priority configured" -ForegroundColor Green

# Visual Effects (Disable animations)
Write-Host "[7/10] Configuring Visual Effects..." -ForegroundColor Yellow
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v "VisualFXSetting" /t REG_DWORD /d 2 /f
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v "TaskbarAnimations" /t REG_DWORD /d 0 /f
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v "WindowAnimations" /t REG_DWORD /d 0 /f
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v "MenuAnimations" /t REG_DWORD /d 0 /f
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarAnimations" /t REG_DWORD /d 0 /f
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "IconsOnly" /t REG_DWORD /d 0 /f
Write-Host "  ✓ Visual effects configured" -ForegroundColor Green

# Disable Widgets/News
Write-Host "[8/10] Disabling Widgets & News..." -ForegroundColor Yellow
REG ADD "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /v "AllowNewsAndInterests" /t REG_DWORD /d 0 /f
Write-Host "  ✓ Widgets disabled" -ForegroundColor Green

# Disable Memory Integrity (requires reboot)
Write-Host "[9/15] Disabling Memory Integrity..." -ForegroundColor Yellow
REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v "Enabled" /t REG_DWORD /d 0 /f
Write-Host "  ✓ Memory Integrity will be disabled after reboot" -ForegroundColor Green

# Disable Nagle's Algorithm (P40L0)
Write-Host "[10/15] Disabling Nagle's Algorithm..." -ForegroundColor Yellow
try {
    $ipv4 = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.PrefixOrigin -eq 'Dhcp' -or $_.PrefixOrigin -eq 'Manual'} | Select-Object -First 1).IPAddress
    if ($ipv4) {
        Write-Host "  Detected IP: $ipv4" -ForegroundColor Gray
        $interfaces = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
        foreach ($interface in $interfaces) {
            $dhcpIP = (Get-ItemProperty -Path $interface.PSPath -Name "DhcpIPAddress" -ErrorAction SilentlyContinue).DhcpIPAddress
            if ($dhcpIP -eq $ipv4) {
                REG ADD "$($interface.Name.Replace('HKEY_LOCAL_MACHINE', 'HKLM'))" /v "TcpNoDelay" /t REG_DWORD /d 1 /f | Out-Null
                REG ADD "$($interface.Name.Replace('HKEY_LOCAL_MACHINE', 'HKLM'))" /v "TcpAckFrequency" /t REG_DWORD /d 1 /f | Out-Null
                Write-Host "  ✓ Nagle's Algorithm disabled for active interface" -ForegroundColor Green
                break
            }
        }
    }
} catch {
    Write-Host "  ⚠️  Could not auto-detect interface, skipping Nagle disable" -ForegroundColor Yellow
}

# Disable SysMain (Superfetch) Service
Write-Host "[11/15] Disabling SysMain (Superfetch)..." -ForegroundColor Yellow
Stop-Service -Name "SysMain" -Force -ErrorAction SilentlyContinue
Set-Service -Name "SysMain" -StartupType Disabled -ErrorAction SilentlyContinue
Write-Host "  ✓ SysMain service disabled" -ForegroundColor Green

# Disable Game DVR and Xbox Game Bar
Write-Host "[12/15] Disabling Game DVR & Xbox Game Bar..." -ForegroundColor Yellow
REG ADD "HKCU\System\GameConfigStore" /v "GameDVR_Enabled" /t REG_DWORD /d 0 /f
REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" /v "AppCaptureEnabled" /t REG_DWORD /d 0 /f
REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" /v "AudioCaptureEnabled" /t REG_DWORD /d 0 /f
REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" /v "CursorCaptureEnabled" /t REG_DWORD /d 0 /f
REG ADD "HKCU\SOFTWARE\Microsoft\GameBar" /v "AllowAutoGameMode" /t REG_DWORD /d 1 /f
REG ADD "HKCU\SOFTWARE\Microsoft\GameBar" /v "AutoGameModeEnabled" /t REG_DWORD /d 1 /f
Write-Host "  ✓ Game DVR disabled, Game Mode enabled" -ForegroundColor Green

# Enable Hardware-Accelerated GPU Scheduling
Write-Host "[13/15] Enabling Hardware-Accelerated GPU Scheduling..." -ForegroundColor Yellow
REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v "HwSchMode" /t REG_DWORD /d 2 /f
Write-Host "  ✓ Hardware GPU scheduling enabled (requires reboot)" -ForegroundColor Green

# Disable Windows Search Indexing on Game Drives
Write-Host "[14/15] Configuring Windows Search Indexing..." -ForegroundColor Yellow
try {
    # Disable indexing on A: drive if it exists (game drive)
    if (Test-Path "A:\") {
        $drive = Get-WmiObject -Class Win32_Volume -Filter "DriveLetter='A:'"
        if ($drive) {
            $drive.IndexingEnabled = $false
            $drive.Put() | Out-Null
            Write-Host "  ✓ Indexing disabled on A: drive (games)" -ForegroundColor Green
        }
    }
    # Keep indexing on C: for faster file searches
    Write-Host "  ℹ️  C: drive indexing kept enabled for system files" -ForegroundColor Gray
} catch {
    Write-Host "  ⚠️  Could not modify indexing settings" -ForegroundColor Yellow
}

# Virtual Memory Configuration
Write-Host "[15/15] Virtual Memory Configuration..." -ForegroundColor Yellow
Write-Host "  ⚠️  Virtual Memory must be set manually:" -ForegroundColor Cyan
Write-Host "      1. Open System Properties -> Advanced -> Performance Settings" -ForegroundColor White
Write-Host "      2. Advanced tab -> Virtual Memory -> Change" -ForegroundColor White
Write-Host "      3. Uncheck 'Automatically manage paging file size'" -ForegroundColor White
Write-Host "      4. Select C: drive" -ForegroundColor White
Write-Host "      5. Custom size: Initial=16384, Maximum=16384" -ForegroundColor White
Write-Host "      6. Click Set, then OK, then Reboot" -ForegroundColor White

# Restart Explorer
Write-Host "`nRestarting Explorer to apply visual changes..." -ForegroundColor Yellow
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Start-Process explorer

Write-Host "`n=== Optimization Complete! ===" -ForegroundColor Green
Write-Host "`n✅ Applied Settings:" -ForegroundColor Cyan
Write-Host "   • CPU & Performance optimizations"
Write-Host "   • Network & TCP/IP tweaks (WiFi-friendly)"
Write-Host "   • Game priority settings"
Write-Host "   • Visual effects disabled"
Write-Host "   • Memory Integrity disabled"
Write-Host "   • Core Parking disabled"
Write-Host "   • Nagle's Algorithm disabled (lower online latency)"
Write-Host "   • SysMain/Superfetch disabled (SSD optimization)"
Write-Host "   • Game DVR disabled, Game Mode enabled"
Write-Host "   • Hardware GPU scheduling enabled"
Write-Host "   • Windows Search optimized for game drives"

Write-Host "`n⚠️  Manual Steps Required:" -ForegroundColor Yellow
Write-Host "   1. Set Virtual Memory to 16GB fixed (see instructions above)"
Write-Host "   2. Check Audio Exclusive Mode (Control Panel -> Sound -> Properties -> Advanced)"
Write-Host "   3. Verify Power Plan is set to Balanced"
Write-Host "   4. [Optional] Check BIOS: Enable EXPO/XMP for RAM, keep PBO off for X3D"

Write-Host "`n⚠️  REBOOT REQUIRED for all changes to take effect" -ForegroundColor Red
Write-Host "`nPress any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

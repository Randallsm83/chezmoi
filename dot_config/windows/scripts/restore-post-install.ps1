<#
.SYNOPSIS
    Post-reinstall Windows 11 configuration script.

.DESCRIPTION
    One-time setup script to run AFTER fresh Windows 11 install + chezmoi bootstrap.
    Applies:
      1. Registry tweaks (Explorer, Mouse, Keyboard, GameDVR, UAC)
      2. Power plan settings (Balanced w/ non-default tweaks)
      3. USB & NIC power management (disable "allow turn off to save power")
      4. Windows Features (WSL, VirtualMachinePlatform, NetFx3)
      5. Scheduled tasks (FanControl, MSIAfterburner, OpenRGB, Rdock, UtilCacheCleaner, uwd2)
      6. uwd2 download (Universal Watermark Disabler 2)
      7. Ethernet NIC advanced settings (Realtek 2.5GbE)
      8. Gaming/performance tweaks (MMCSS, HAGS, power throttling, WSearch disable)
      9. TCP/Network stack optimization
     10. NVIDIA DRS profile import

    Run elevated (as administrator) after chezmoi bootstrap completes.
    Safe to re-run — idempotent where possible.

.NOTES
    Deployed by chezmoi to: ~/.config/windows/scripts/restore-post-install.ps1
    Run once after reinstall, then forget about it.
    Reference XMLs: ~/.config/windows/scheduled-tasks/
    Requires: Administrator privileges, Windows 11
#>

#Requires -RunAsAdministrator
$ErrorActionPreference = 'Continue'

# ============================================================================
# Configuration — adjust these paths if they differ after reinstall
# ============================================================================

$Config = @{
    # Scheduled task executables
    FanControlExe     = "$env:USERPROFILE\scoop\apps\fancontrol\current\FanControl.exe"
    MSIAfterburnerExe = "$env:USERPROFILE\scoop\apps\msiafterburner\current\MSIAfterburner.exe"
    OpenRGBExe        = "$env:USERPROFILE\.local\bin\OpenRGB\OpenRGB.exe"
    OpenRGBArgs       = '--startminimized --profile "Space"'
    RdockExe          = "$env:USERPROFILE\projects\rdock\target\release\rdock.exe"
    UtilCacheCleanerCmd = "Import-Module CacheCleaner; Clear-Cache"
    Uwd2Exe           = "$env:USERPROFILE\.local\bin\uwd2.exe"
    FlowLauncherExe   = "$env:USERPROFILE\scoop\apps\flow-launcher\current\Flow.Launcher.exe"
    ISLCExe           = "$env:USERPROFILE\scoop\apps\islc\current\Intelligent standby list cleaner ISLC.exe"

    # uwd2 download (GitHub releases)
    Uwd2Repo          = "machineonamission/uwd2"
    Uwd2Dest          = "$env:USERPROFILE\.local\bin"
}

# ============================================================================
# Helpers
# ============================================================================

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "=== $Title ===" -ForegroundColor Cyan
}

function Write-Done {
    param([string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Skip {
    param([string]$Message)
    Write-Host "  [SKIP] $Message" -ForegroundColor Yellow
}

function Write-Fail {
    param([string]$Message)
    Write-Host "  [FAIL] $Message" -ForegroundColor Red
}

function New-LogonTask {
    param(
        [string]$Name,
        [string]$Exe,
        [string]$Arguments,
        [string]$WorkingDirectory,
        [switch]$AdminGroup,
        [switch]$SkipExeCheck
    )

    if (-not $SkipExeCheck -and -not (Test-Path $Exe)) {
        Write-Skip "$Name — exe not found: $Exe"
        return
    }

    # Remove existing task if present
    Unregister-ScheduledTask -TaskName $Name -Confirm:$false -ErrorAction SilentlyContinue

    $actionParams = @{ Execute = $Exe }
    if ($Arguments) { $actionParams.Argument = $Arguments }
    if ($WorkingDirectory) { $actionParams.WorkingDirectory = $WorkingDirectory }
    $action = New-ScheduledTaskAction @actionParams

    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $settings = New-ScheduledTaskSettingsSet `
        -ExecutionTimeLimit (New-TimeSpan) `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -MultipleInstances IgnoreNew

    if ($AdminGroup) {
        $principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Administrators" -RunLevel Highest
    } else {
        $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
    }

    try {
        Register-ScheduledTask -TaskName $Name -Action $action -Trigger $trigger `
            -Settings $settings -Principal $principal | Out-Null
        Write-Done "$Name"
    } catch {
        Write-Fail "${Name}: $_"
    }
}

# ============================================================================
# 1. Registry Tweaks
# ============================================================================
Write-Section "Registry Tweaks"

# Explorer: show hidden files, show extensions, compact mode, launch to This PC
try {
    $explorerKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $explorerKey -Name "HideFileExt" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $explorerKey -Name "Hidden" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $explorerKey -Name "UseCompactMode" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $explorerKey -Name "LaunchTo" -Value 1 -Type DWord -Force
    Write-Done "Explorer: hidden files ON, extensions ON, compact mode, launch to This PC"
} catch { Write-Fail "Explorer: $_" }

# Mouse: acceleration OFF, speed=0, thresholds=0, sensitivity=10
try {
    Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Value "0" -Force
    Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Value "0" -Force
    Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Value "0" -Force
    Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseSensitivity" -Value "10" -Force
    Write-Done "Mouse: acceleration OFF, sensitivity=10"
} catch { Write-Fail "Mouse: $_" }

# Keyboard: repeat delay=short (1), repeat rate=fast (31)
try {
    Set-ItemProperty -Path "HKCU:\Control Panel\Keyboard" -Name "KeyboardDelay" -Value "1" -Force
    Set-ItemProperty -Path "HKCU:\Control Panel\Keyboard" -Name "KeyboardSpeed" -Value "31" -Force
    Write-Done "Keyboard: delay=1 (short), speed=31 (fast)"
} catch { Write-Fail "Keyboard: $_" }

# Game Mode: ON
try {
    $gameModeKey = "HKCU:\Software\Microsoft\GameBar"
    if (-not (Test-Path $gameModeKey)) { New-Item -Path $gameModeKey -Force | Out-Null }
    Set-ItemProperty -Path $gameModeKey -Name "AutoGameModeEnabled" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $gameModeKey -Name "AllowAutoGameMode" -Value 1 -Type DWord -Force
    Write-Done "Game Mode: ON"
} catch { Write-Fail "Game Mode: $_" }

# Game DVR: disable captures
try {
    $gameDVRKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"
    if (-not (Test-Path $gameDVRKey)) { New-Item -Path $gameDVRKey -Force | Out-Null }
    Set-ItemProperty -Path $gameDVRKey -Name "AppCaptureEnabled" -Value 0 -Type DWord -Force
    Write-Done "Game DVR: captures OFF"
} catch { Write-Fail "Game DVR: $_" }

# UAC: no dimming for admin consent
try {
    $uacKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    Set-ItemProperty -Path $uacKey -Name "ConsentPromptBehaviorAdmin" -Value 0 -Type DWord -Force
    Write-Done "UAC: ConsentPromptBehaviorAdmin=0 (no dimming)"
} catch { Write-Fail "UAC: $_" }

# ============================================================================
# 2. Power Plan (Balanced — non-default tweaks)
# ============================================================================
Write-Section "Power Plan Settings (Balanced)"

try {
    # Hard disk: never turn off (AC)
    powercfg /setacvalueindex SCHEME_CURRENT SUB_DISK DISKIDLE 0
    # Desktop slideshow: paused
    powercfg /setacvalueindex SCHEME_CURRENT 0d7dbae2-4294-402a-ba8e-26777e8488cd 309dce9b-bef4-4119-9921-a851fb12f0f4 1
    # Wireless adapter: Maximum Performance (AC)
    powercfg /setacvalueindex SCHEME_CURRENT 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 0
    # Sleep after: 1 hour (3600s) on AC
    powercfg /setacvalueindex SCHEME_CURRENT SUB_SLEEP STANDBYIDLE 3600
    # Hibernate: never
    powercfg /setacvalueindex SCHEME_CURRENT SUB_SLEEP HIBERNATEIDLE 0
    # Wake timers: disabled (AC)
    powercfg /setacvalueindex SCHEME_CURRENT SUB_SLEEP RTCWAKE 0
    # USB selective suspend: DISABLED
    powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
    # PCI Express ASPM: Off (AC & DC)
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0
    powercfg /setdcvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0
    # Display off: 1 hour (3600s) on AC
    powercfg /setacvalueindex SCHEME_CURRENT SUB_VIDEO VIDEOIDLE 3600
    # Adaptive brightness: Off
    powercfg /setacvalueindex SCHEME_CURRENT SUB_VIDEO ADAPTBRIGHT 0
    # Video playback: performance bias
    powercfg /setacvalueindex SCHEME_CURRENT 9596fb26-9850-41fd-ac3e-f7c3c00afd4b 10778347-1370-4ee0-8bbd-33bdacaade49 1
    powercfg /setacvalueindex SCHEME_CURRENT 9596fb26-9850-41fd-ac3e-f7c3c00afd4b 34c7b99f-9a6d-4b3c-8dc7-b6693b78cef4 0
    # Apply
    powercfg /setactive SCHEME_CURRENT
    Write-Done "Power plan: all Balanced tweaks applied"
} catch { Write-Fail "Power plan: $_" }

# ============================================================================
# 3. USB & NIC Power Management
# ============================================================================
Write-Section "USB & NIC Power Management"

# Disable "Allow the computer to turn off this device" on ALL USB devices
try {
    $usbCount = 0
    Get-PnpDevice -Class USB -Status OK |
        ForEach-Object {
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($_.InstanceId)"
            Set-ItemProperty -Path $regPath -Name 'PnPCapabilities' -Value 24 -Type DWord -ErrorAction SilentlyContinue

            # Also disable selective suspend / idle power in Device Parameters
            $dpPath = "$regPath\Device Parameters"
            if (Test-Path $dpPath) {
                Set-ItemProperty -Path $dpPath -Name 'EnhancedPowerManagementEnabled' -Value 0 -Type DWord -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $dpPath -Name 'AllowIdleIrpInD3' -Value 0 -Type DWord -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $dpPath -Name 'SelectiveSuspendEnabled' -Value 0 -Type DWord -ErrorAction SilentlyContinue
            }
            $usbCount++
        }
    Write-Done "USB: PnPCapabilities=24 + Device Parameters on $usbCount devices"

    # Disable via CIM (unchecks the Device Manager checkbox immediately)
    $cimCount = 0
    Get-CimInstance -Namespace root\wmi -ClassName MSPower_DeviceEnable |
        Where-Object { $_.InstanceName -match 'USB|PCI\\VEN_1022' } |
        ForEach-Object {
            if ($_.Enable) {
                Set-CimInstance -InputObject $_ -Property @{ Enable = $false }
                $cimCount++
            }
        }
    Write-Done "USB: CIM power disable on $cimCount devices"
} catch { Write-Fail "USB power management: $_" }

# Disable on ALL physical network adapters
try {
    $nicCount = 0
    Get-PnpDevice -Class Net -Status OK |
        Where-Object { $_.FriendlyName -notmatch 'WAN Miniport|Kernel Debug|Bluetooth' } |
        ForEach-Object {
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($_.InstanceId)"
            Set-ItemProperty -Path $regPath -Name 'PnPCapabilities' -Value 24 -Type DWord
            $nicCount++
        }
    Write-Done "NIC: PnPCapabilities=24 on $nicCount adapters"
} catch { Write-Fail "NIC power management: $_" }

# ============================================================================
# 4. Windows Features (DISM)
# ============================================================================
Write-Section "Windows Features"

@('VirtualMachinePlatform', 'Microsoft-Windows-Subsystem-Linux', 'NetFx3') | ForEach-Object {
    try {
        $state = (Get-WindowsOptionalFeature -Online -FeatureName $_ -ErrorAction SilentlyContinue).State
        if ($state -eq 'Enabled') {
            Write-Skip "$_ (already enabled)"
        } else {
            dism /online /enable-feature /featurename:$_ /all /norestart 2>&1 | Out-Null
            Write-Done "$_"
        }
    } catch { Write-Fail "${_}: $_" }
}

# ============================================================================
# 5. Scheduled Tasks
# ============================================================================
Write-Section "Scheduled Tasks"

# FanControl — scoop-installed, logon trigger, highest privilege
New-LogonTask -Name "FanControl" -Exe $Config.FanControlExe

# MSI Afterburner — scoop-installed, silent start
New-LogonTask -Name "MSIAfterburner" -Exe $Config.MSIAfterburnerExe -Arguments "/s"

# OpenRGB — ~/.local/bin, start minimized with Space profile
New-LogonTask -Name "OpenRGB" -Exe $Config.OpenRGBExe -Arguments $Config.OpenRGBArgs

# Rdock — project build output
New-LogonTask -Name "Rdock" -Exe $Config.RdockExe

# Flow Launcher — scoop-installed, logon trigger
New-LogonTask -Name "FlowLauncher" -Exe $Config.FlowLauncherExe

# ISLC — scoop-installed, logon trigger (timer resolution / standby list cleaner)
New-LogonTask -Name "ISLC" -Exe $Config.ISLCExe

# UtilCacheCleaner — admin group, uses CacheCleaner PS module
Unregister-ScheduledTask -TaskName "UtilCacheCleaner" -Confirm:$false -ErrorAction SilentlyContinue
try {
    $action = New-ScheduledTaskAction `
        -Execute "$env:SystemRoot\System32\conhost.exe" `
        -Argument "--headless pwsh.exe -WindowStyle Hidden -NoProfile -NonInteractive -Command `"$($Config.UtilCacheCleanerCmd)`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan) -MultipleInstances IgnoreNew
    $principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Administrators" -RunLevel Highest
    Register-ScheduledTask -TaskName "UtilCacheCleaner" -Action $action -Trigger $trigger `
        -Settings $settings -Principal $principal | Out-Null
    Write-Done "UtilCacheCleaner (CacheCleaner module)"
} catch { Write-Fail "UtilCacheCleaner: $_" }

# ============================================================================
# 6. Download uwd2 (Universal Watermark Disabler 2) + startup task
# ============================================================================
Write-Section "uwd2 (Universal Watermark Disabler 2)"

$uwd2Path = $Config.Uwd2Exe
if (Test-Path $uwd2Path) {
    Write-Skip "uwd2.exe already present at $uwd2Path"
} else {
    try {
        New-Item -ItemType Directory -Path $Config.Uwd2Dest -Force | Out-Null
        # Get latest release asset URL from GitHub
        $releaseApi = "https://api.github.com/repos/$($Config.Uwd2Repo)/releases/latest"
        $release = Invoke-RestMethod -Uri $releaseApi -UseBasicParsing
        $asset = $release.assets | Where-Object { $_.name -match '\.exe$' } | Select-Object -First 1
        if ($asset) {
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $uwd2Path -UseBasicParsing
            Write-Done "uwd2.exe downloaded to $($Config.Uwd2Dest)"
        } else {
            Write-Fail "uwd2: no .exe asset found in latest release"
        }
    } catch { Write-Fail "uwd2 download: $_" }
}

# Create uwd2 logon task (uwd2 doesn't persist between restarts)
if (Test-Path $uwd2Path) {
    New-LogonTask -Name "uwd2" -Exe $uwd2Path -SkipExeCheck
}

# ============================================================================
# 7. Ethernet NIC Advanced Settings (Realtek Gaming 2.5GbE)
# ============================================================================
# WARNING: Driver updates reset these to power-saving defaults — re-run after driver update
Write-Section "Ethernet NIC Advanced Settings"

try {
    $nic = Get-NetAdapter | Where-Object { $_.InterfaceDescription -match 'Realtek' }
    if (-not $nic) {
        Write-Skip "No Realtek adapter found"
    } else {
        $n = $nic.Name

        # Power saving features OFF (-NoRestart to batch changes, single restart at end)
        Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*EEE' -RegistryValue 0 -NoRestart              # Energy-Efficient Ethernet
        Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword 'AdvancedEEE' -RegistryValue 0 -NoRestart       # Advanced EEE
        Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword 'EnableGreenEthernet' -RegistryValue 0 -NoRestart  # Green Ethernet
        Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword 'GigaLite' -RegistryValue 0 -NoRestart          # Gigabit Lite
        Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword 'PowerSavingMode' -RegistryValue 0 -NoRestart   # Power Saving Mode

        # Performance tuning
        Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*FlowControl' -RegistryValue 0 -NoRestart      # Flow Control OFF
        Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*InterruptModeration' -RegistryValue 0 -NoRestart  # Interrupt Moderation OFF
        Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*ReceiveBuffers' -RegistryValue 2048 -NoRestart    # Receive Buffers (default 1024)
        Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*TransmitBuffers' -RegistryValue 1024 -NoRestart   # Transmit Buffers (default 512)

        # Wake features OFF
        Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*WakeOnMagicPacket' -RegistryValue 0 -NoRestart
        Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword '*WakeOnPattern' -RegistryValue 0 -NoRestart
        Set-NetAdapterAdvancedProperty -Name $n -RegistryKeyword 'S5WakeOnLan' -RegistryValue 0 -NoRestart       # Shutdown Wake-On-Lan

        # Apply all NIC changes with a single adapter restart
        Restart-NetAdapter -Name $n

        # Keep defaults: Jumbo Frame disabled, Speed Auto-Negotiation, offloads enabled

        # Disable IPv6 on adapter
        Disable-NetAdapterBinding -Name $n -ComponentId ms_tcpip6 -ErrorAction SilentlyContinue

        # Set DNS to Cloudflare
        Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ServerAddresses @('1.1.1.1', '1.0.0.1')

        Write-Done "Realtek NIC: power saving OFF, buffers up, wake OFF, IPv6 OFF, DNS=Cloudflare"
    }
} catch { Write-Fail "Ethernet NIC: $_" }

# ============================================================================
# 8. Gaming / Performance Tweaks
# ============================================================================
Write-Section "Gaming / Performance Tweaks"

try {
    # MMCSS: disable network throttling, reserve 10% CPU for non-multimedia
    $mmcssKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    if (-not (Test-Path $mmcssKey)) { New-Item -Path $mmcssKey -Force | Out-Null }
    Set-ItemProperty -Path $mmcssKey -Name 'NetworkThrottlingIndex' -Value 0xFFFFFFFF -Type DWord -Force
    Set-ItemProperty -Path $mmcssKey -Name 'SystemResponsiveness' -Value 10 -Type DWord -Force
    Write-Done "MMCSS: NetworkThrottling OFF, SystemResponsiveness=10"
} catch { Write-Fail "MMCSS: $_" }

try {
    # HAGS (Hardware-Accelerated GPU Scheduling)
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name 'HwSchMode' -Value 2 -Type DWord -Force
    Write-Done "HAGS: enabled (HwSchMode=2)"
} catch { Write-Fail "HAGS: $_" }

try {
    # Game MMCSS task priorities
    $gamesKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
    if (-not (Test-Path $gamesKey)) { New-Item -Path $gamesKey -Force | Out-Null }
    Set-ItemProperty -Path $gamesKey -Name 'Affinity' -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $gamesKey -Name 'Background Only' -Value 'False' -Force
    Set-ItemProperty -Path $gamesKey -Name 'GPU Priority' -Value 8 -Type DWord -Force
    Set-ItemProperty -Path $gamesKey -Name 'Priority' -Value 6 -Type DWord -Force
    Set-ItemProperty -Path $gamesKey -Name 'Scheduling Category' -Value 'High' -Force
    Set-ItemProperty -Path $gamesKey -Name 'SFIO Priority' -Value 'High' -Force
    Write-Done "Game MMCSS: GPU Priority=8, Scheduling=High, SFIO=High"
} catch { Write-Fail "Game MMCSS: $_" }

try {
    # Disable power throttling
    $ptKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling"
    if (-not (Test-Path $ptKey)) { New-Item -Path $ptKey -Force | Out-Null }
    Set-ItemProperty -Path $ptKey -Name 'PowerThrottlingOff' -Value 1 -Type DWord -Force
    Write-Done "Power throttling: OFF"
} catch { Write-Fail "Power throttling: $_" }

try {
    # Disable Windows Search Indexing service (using Everything via Flow Launcher)
    $wsearch = Get-Service -Name 'WSearch' -ErrorAction SilentlyContinue
    if ($wsearch) {
        Stop-Service -Name 'WSearch' -Force -ErrorAction SilentlyContinue
        Set-Service -Name 'WSearch' -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Done "Windows Search (WSearch): service disabled (using Everything)"
    } else {
        Write-Skip "WSearch service not found"
    }
} catch { Write-Fail "Windows Search: $_" }

# ============================================================================
# 9. TCP / Network Stack Optimization
# ============================================================================
Write-Section "TCP / Network Stack"

try {
    # Disable Nagle's algorithm on the Realtek interface (reduces latency)
    $nic = Get-NetAdapter | Where-Object { $_.InterfaceDescription -match 'Realtek' }
    if ($nic) {
        $ifPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($nic.InterfaceGuid)"
        Set-ItemProperty -Path $ifPath -Name 'TcpAckFrequency' -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $ifPath -Name 'TCPNoDelay' -Value 1 -Type DWord -Force
        Write-Done "Nagle: disabled on $($nic.Name) (TcpAckFrequency=1, TCPNoDelay=1)"
    }

    # Global TCP parameters
    $tcpParams = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
    Set-ItemProperty -Path $tcpParams -Name 'Tcp1323Opts' -Value 1 -Type DWord -Force            # Window scaling only
    Set-ItemProperty -Path $tcpParams -Name 'GlobalMaxTcpWindowSize' -Value 65535 -Type DWord -Force
    Set-ItemProperty -Path $tcpParams -Name 'MaxUserPort' -Value 65534 -Type DWord -Force
    Set-ItemProperty -Path $tcpParams -Name 'TcpTimedWaitDelay' -Value 30 -Type DWord -Force      # Faster socket reuse
    Write-Done "TCP params: Tcp1323Opts=1, MaxWindow=65535, MaxUserPort=65534, TWDelay=30"

    # Netsh TCP global settings
    netsh int tcp set global rss=enabled 2>&1 | Out-Null
    netsh int tcp set global rsc=disabled 2>&1 | Out-Null
    netsh int tcp set global fastopen=enabled 2>&1 | Out-Null
    netsh int tcp set global timestamps=disabled 2>&1 | Out-Null
    netsh int tcp set global ecncapability=disabled 2>&1 | Out-Null
    netsh int tcp set global autotuninglevel=normal 2>&1 | Out-Null
    netsh int tcp set global pacingprofile=off 2>&1 | Out-Null
    Write-Done "TCP global: RSS on, RSC off, FastOpen on, Timestamps off, ECN off, Pacing off"
} catch { Write-Fail "TCP/Network: $_" }

# ============================================================================
# 10. NVIDIA Driver Profile (manual import via NPI)
# ============================================================================
Write-Section "NVIDIA DRS Profile"

$nipFile = Join-Path $env:USERPROFILE '.config\windows\nvidia-drs-base-profile.nip'
if (Test-Path $nipFile) {
    $npi = Get-Command nvidiaProfileInspector.exe -ErrorAction SilentlyContinue
    if ($npi) {
        try {
            # NPI CLI: pass .nip file path directly + -silentImport to suppress dialog
            # NPI imports the profile and exits without opening the GUI
            Start-Process -FilePath $npi.Source -ArgumentList "`"$nipFile`" -silentImport" -Wait -ErrorAction Stop
            Write-Done "NVIDIA DRS profile imported from $nipFile"
        } catch {
            Write-Skip "NPI import failed — open NPI manually and File > Import: $nipFile"
        }
    } else {
        Write-Skip "nvidia-profile-inspector not found — install via scoop, then import: $nipFile"
    }
} else {
    Write-Skip "No NPI profile found at $nipFile"
}

# ============================================================================
# Summary
# ============================================================================

Write-Host ""
Write-Host "=== Post-Install Restore Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "  REBOOT REQUIRED for:" -ForegroundColor Yellow
Write-Host "    - USB/NIC power management changes" -ForegroundColor Yellow
Write-Host "    - Windows Features (WSL, VirtualMachinePlatform)" -ForegroundColor Yellow
Write-Host "    - TCP/Nagle registry changes" -ForegroundColor Yellow
Write-Host "    - HAGS, power throttling, Win32PrioritySeparation" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Manual steps remaining:" -ForegroundColor Cyan
Write-Host "    - Taskbar: left-align, disable Task View, disable widgets"
Write-Host "    - Display: 240Hz, per-monitor scaling"
Write-Host "    - Developer Mode: Settings > Privacy & Security > For Developers"
Write-Host "    - Rename PC: Settings > System > About"
Write-Host "    - Re-run Ethernet NIC section after any Realtek driver update"
Write-Host ""

# vim: ts=4 sts=4 sw=4 et

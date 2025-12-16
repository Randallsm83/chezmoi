<#
.SYNOPSIS
    GamePerformanceOptimizer - A PowerShell module to optimize game performance by configuring security exclusions.

.DESCRIPTION
    This module provides functions to add/remove Windows Defender exclusions and disable Control Flow Guard (CFG)
    for games, improving performance while maintaining system security for non-game applications.

.NOTES
    Author: GamePerformanceOptimizer
    Version: 1.0.0
    Requires: PowerShell 5.1+, Windows Defender, Administrator privileges
#>

#region Helper Functions

function Test-Administrator {
    <#
    .SYNOPSIS
        Checks if the current PowerShell session is running with administrator privileges.
    #>
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-SteamLibraries {
    <#
    .SYNOPSIS
        Retrieves all Steam library folders from the Steam installation.
    #>
    $libraries = @()
    
    try {
        $steamPath = Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "SteamPath" -ErrorAction SilentlyContinue | 
                     Select-Object -ExpandProperty SteamPath
        
        if ($steamPath) {
            $steamPath = $steamPath -replace '/', '\'
            $libraries += $steamPath
            
            # Parse libraryfolders.vdf
            $libraryFile = Join-Path $steamPath "steamapps\libraryfolders.vdf"
            if (Test-Path $libraryFile) {
                $content = Get-Content $libraryFile -Raw
                
                # Match paths in VDF format: "path"		"D:\\SteamLibrary"
                $pathMatches = [regex]::Matches($content, '"path"\s+"([^"]+)"')
                foreach ($match in $pathMatches) {
                    $libPath = $match.Groups[1].Value -replace '\\\\', '\'
                    if ((Test-Path $libPath) -and ($libPath -notin $libraries)) {
                        $libraries += $libPath
                    }
                }
            }
        }
    }
    catch {
        Write-Verbose "Error reading Steam libraries: $_"
    }
    
    return $libraries
}

function Find-GameExecutable {
    <#
    .SYNOPSIS
        Attempts to auto-detect the game executable location.
    
    .PARAMETER GameName
        The name of the game executable (with or without .exe extension).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$GameName
    )
    
    # Normalize game name
    $gameExe = if ($GameName -notmatch '\.exe$') { "$GameName.exe" } else { $GameName }
    $gameNameOnly = $GameName -replace '\.exe$', ''
    
    Write-Verbose "Searching for: $gameExe"
    
    # Search locations
    $searchPaths = @()
    
    # Steam libraries
    $steamLibs = Get-SteamLibraries
    foreach ($lib in $steamLibs) {
        $steamApps = Join-Path $lib "steamapps\common"
        if (Test-Path $steamApps) {
            $searchPaths += $steamApps
        }
    }
    
    # Epic Games
    $epicManifests = "$env:ProgramData\Epic\EpicGamesLauncher\Data\Manifests"
    if (Test-Path $epicManifests) {
        Get-ChildItem "$epicManifests\*.item" -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $manifest = Get-Content $_.FullName -Raw | ConvertFrom-Json
                if ($manifest.InstallLocation -and (Test-Path $manifest.InstallLocation)) {
                    $searchPaths += $manifest.InstallLocation
                }
            }
            catch {
                Write-Verbose "Error reading Epic manifest: $_"
            }
        }
    }
    
    # GOG Galaxy
    $gogPath = "C:\GOG Games"
    if (Test-Path $gogPath) {
        $searchPaths += $gogPath
    }
    
    # Xbox Game Pass
    $xboxPaths = @(
        "C:\XboxGames",
        "A:\XboxGames",
        "B:\XboxGames",
        "D:\XboxGames",
        "E:\XboxGames"
    )
    foreach ($xboxPath in $xboxPaths) {
        if (Test-Path $xboxPath) {
            $searchPaths += $xboxPath
        }
    }
    
    # Common game installation directories
    $commonPaths = @(
        "C:\Program Files",
        "C:\Program Files (x86)",
        "D:\Games",
        "E:\Games",
        "F:\Games",
        "G:\Games"
    )
    $searchPaths += $commonPaths | Where-Object { Test-Path $_ }
    
    # Search for the executable
    foreach ($basePath in $searchPaths) {
        Write-Verbose "Searching in: $basePath"
        
        # Search recursively with depth limit for performance
        $found = Get-ChildItem -Path $basePath -Filter $gameExe -Recurse -ErrorAction SilentlyContinue -Depth 3 |
                 Select-Object -First 1
        
        if ($found) {
            Write-Verbose "Found: $($found.FullName)"
            return $found.FullName
        }
    }
    
    # Fallback: Use file picker
    Write-Host "Game not found automatically. Please select the game executable manually." -ForegroundColor Yellow
    
    Add-Type -AssemblyName System.Windows.Forms
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Filter = "Executable Files (*.exe)|*.exe|All Files (*.*)|*.*"
    $openFileDialog.Title = "Select $gameNameOnly executable"
    $openFileDialog.InitialDirectory = "C:\Program Files"
    
    if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $openFileDialog.FileName
    }
    
    return $null
}

function Get-ShaderCachePath {
    <#
    .SYNOPSIS
        Detects shader cache paths for a game.
    
    .PARAMETER GamePath
        The full path to the game executable.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$GamePath
    )
    
    $cachePaths = @()
    $gameDir = Split-Path $GamePath -Parent
    
    # Check for Steam shader cache
    $steamLibs = Get-SteamLibraries
    foreach ($steamPath in $steamLibs) {
        if ($GamePath -like "$steamPath*") {
            # Try to extract AppID from the path
            # Typical path: C:\SteamLibrary\steamapps\common\GameName\...
            $appManifests = Join-Path $steamPath "steamapps"
            
            # Look for appmanifest files
            Get-ChildItem "$appManifests\appmanifest_*.acf" -ErrorAction SilentlyContinue | ForEach-Object {
                $content = Get-Content $_.FullName -Raw
                # Check if this manifest's install dir matches our game
                if ($content -match '"installdir"\s+"([^"]+)"') {
                    $installDir = $matches[1]
                    $fullInstallPath = Join-Path "$appManifests\common" $installDir
                    
                    if ($GamePath -like "$fullInstallPath*") {
                        # Extract AppID from filename: appmanifest_<appid>.acf
                        if ($_.Name -match 'appmanifest_(\d+)\.acf') {
                            $appId = $matches[1]
                            $shaderCache = Join-Path $steamPath "steamapps\shadercache\$appId"
                            if (Test-Path $shaderCache) {
                                $cachePaths += $shaderCache
                            }
                        }
                    }
                }
            }
        }
    }
    
    # Check for per-game cache folders
    $cacheNames = @("cache", "shadercache", "ShaderCache", "Shaders", "shaders")
    foreach ($cacheName in $cacheNames) {
        $cachePath = Join-Path $gameDir $cacheName
        if (Test-Path $cachePath) {
            $cachePaths += $cachePath
        }
    }
    
    return $cachePaths | Select-Object -Unique
}

function Set-ProcessPriorityRegistry {
    <#
    .SYNOPSIS
        Sets process priority via Image File Execution Options registry.
    
    .PARAMETER ProcessName
        The name of the process (exe name).
    
    .PARAMETER CpuPriorityClass
        CPU priority class (1=Idle, 2=Normal, 3=High, 4=Realtime). Default: 3 (High)
    
    .PARAMETER IoPriority
        I/O priority (0=VeryLow, 1=Low, 2=Normal, 3=High). Default: 3 (High)
    
    .PARAMETER PagePriority
        Memory page priority (1-5, higher is better). Default: 5
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProcessName,
        
        [Parameter()]
        [int]$CpuPriorityClass = 3,
        
        [Parameter()]
        [int]$IoPriority = 3,
        
        [Parameter()]
        [int]$PagePriority = 5
    )
    
    $ifeoPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$ProcessName"
    $perfOptionsPath = "$ifeoPath\PerfOptions"
    
    try {
        # Create IFEO key if it doesn't exist
        if (-not (Test-Path $ifeoPath)) {
            New-Item -Path $ifeoPath -Force | Out-Null
            Write-Verbose "Created IFEO key for $ProcessName"
        }
        
        # Create PerfOptions subkey if it doesn't exist
        if (-not (Test-Path $perfOptionsPath)) {
            New-Item -Path $perfOptionsPath -Force | Out-Null
            Write-Verbose "Created PerfOptions subkey for $ProcessName"
        }
        
        # Set priority values
        Set-ItemProperty -Path $perfOptionsPath -Name "CpuPriorityClass" -Value $CpuPriorityClass -Type DWord -Force
        Set-ItemProperty -Path $perfOptionsPath -Name "IoPriority" -Value $IoPriority -Type DWord -Force
        Set-ItemProperty -Path $perfOptionsPath -Name "PagePriority" -Value $PagePriority -Type DWord -Force
        
        return $true
    }
    catch {
        Write-Verbose "Failed to set priority registry for $ProcessName : $_"
        return $false
    }
}

function Remove-ProcessPriorityRegistry {
    <#
    .SYNOPSIS
        Removes process priority settings from Image File Execution Options registry.
    
    .PARAMETER ProcessName
        The name of the process (exe name).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProcessName
    )
    
    $ifeoPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$ProcessName"
    $perfOptionsPath = "$ifeoPath\PerfOptions"
    
    try {
        if (Test-Path $perfOptionsPath) {
            Remove-Item -Path $perfOptionsPath -Recurse -Force
            Write-Verbose "Removed PerfOptions for $ProcessName"
            
            # Check if IFEO key is now empty (no other subkeys/values) and remove if so
            $ifeoKey = Get-Item -Path $ifeoPath -ErrorAction SilentlyContinue
            if ($ifeoKey) {
                $subKeys = Get-ChildItem -Path $ifeoPath -ErrorAction SilentlyContinue
                $values = $ifeoKey.GetValueNames() | Where-Object { $_ -ne "" }
                
                if (($null -eq $subKeys -or $subKeys.Count -eq 0) -and ($null -eq $values -or $values.Count -eq 0)) {
                    Remove-Item -Path $ifeoPath -Force
                    Write-Verbose "Removed empty IFEO key for $ProcessName"
                }
            }
            
            return $true
        }
        else {
            Write-Verbose "No PerfOptions found for $ProcessName"
            return $false
        }
    }
    catch {
        Write-Verbose "Failed to remove priority registry for $ProcessName : $_"
        return $false
    }
}

function Get-ProcessPriorityRegistry {
    <#
    .SYNOPSIS
        Gets process priority settings from Image File Execution Options registry.
    
    .PARAMETER ProcessName
        The name of the process (exe name).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProcessName
    )
    
    $perfOptionsPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$ProcessName\PerfOptions"
    
    if (Test-Path $perfOptionsPath) {
        try {
            $props = Get-ItemProperty -Path $perfOptionsPath -ErrorAction Stop
            return [PSCustomObject]@{
                ProcessName = $ProcessName
                CpuPriorityClass = $props.CpuPriorityClass
                IoPriority = $props.IoPriority
                PagePriority = $props.PagePriority
            }
        }
        catch {
            return $null
        }
    }
    return $null
}

#endregion

#region Public Functions

function Add-GameSecurityExclusion {
    <#
    .SYNOPSIS
        Adds Windows Defender exclusions and disables CFG for a game to improve performance.
    
    .DESCRIPTION
        This function adds the game executable, game folder, and shader cache folders to Windows Defender
        exclusions, and disables Control Flow Guard (CFG) for the game process. This can significantly
        improve game performance by reducing security scanning overhead.
    
    .PARAMETER GameName
        The name of the game executable (with or without .exe extension).
    
    .PARAMETER GamePath
        Optional. The full path to the game executable. If not provided, the function will attempt to
        auto-detect the game location.
    
    .PARAMETER WhatIf
        Shows what would happen if the command runs without actually making changes.
    
    .EXAMPLE
        Add-GameSecurityExclusion -GameName "Cyberpunk2077.exe" -Verbose
        
        Adds exclusions for Cyberpunk 2077 with auto-detection and verbose output.
    
    .EXAMPLE
        Add-GameSecurityExclusion -GameName "Cyberpunk2077" -GamePath "D:\Games\Cyberpunk 2077\bin\x64\Cyberpunk2077.exe"
        
        Adds exclusions for Cyberpunk 2077 using a manually specified path.
    
    .EXAMPLE
        Add-GameSecurityExclusion -GameName "EldenRing" -WhatIf
        
        Previews what exclusions would be added without actually making changes.
    
    .NOTES
        Requires: Administrator privileges
        Platform: Windows 10/11
        Dependencies: Windows Defender, ProcessMitigations module
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$GameName,
        
        [Parameter()]
        [string]$GamePath
    )
    
    # Check administrator privileges
    if (-not (Test-Administrator)) {
        throw "This function requires administrator privileges. Please run PowerShell as Administrator."
    }
    
    # Normalize game name
    $gameExe = if ($GameName -notmatch '\.exe$') { "$GameName.exe" } else { $GameName }
    $gameNameOnly = $GameName -replace '\.exe$', ''
    
    Write-Host "`n=== Adding Security Exclusions for $gameNameOnly ===" -ForegroundColor Cyan
    
    # Find game executable
    if (-not $GamePath) {
        Write-Host "Auto-detecting game location..." -ForegroundColor Yellow
        $GamePath = Find-GameExecutable -GameName $gameNameOnly
        
        if (-not $GamePath) {
            throw "Game executable not found and no path was provided manually."
        }
    }
    
    if (-not (Test-Path $GamePath)) {
        throw "Game executable not found at: $GamePath"
    }
    
    Write-Host "Game found: $GamePath" -ForegroundColor Green
    
    # Extract game folder and actual exe name
    $gameFolder = Split-Path $GamePath -Parent
    $actualExe = Split-Path $GamePath -Leaf
    Write-Verbose "Game folder: $gameFolder"
    Write-Verbose "Actual executable: $actualExe"
    
    # Use actual exe name for process exclusion, not the search name
    $gameExe = $actualExe
    
    # Get shader cache paths
    $shaderCaches = Get-ShaderCachePath -GamePath $GamePath
    if ($shaderCaches.Count -gt 0) {
        Write-Host "Shader cache(s) found: $($shaderCaches.Count)" -ForegroundColor Green
        $shaderCaches | ForEach-Object { Write-Verbose "  - $_" }
    }
    else {
        Write-Warning "No shader cache folders detected for this game."
    }
    
    # Add Windows Defender exclusions
    Write-Host "`nAdding Windows Defender exclusions..." -ForegroundColor Cyan
    
    try {
        # Exclusion: Process
        if ($PSCmdlet.ShouldProcess($gameExe, "Add Defender process exclusion")) {
            try {
                Add-MpPreference -ExclusionProcess $gameExe -ErrorAction Stop
                Write-Host "  [✓] Process exclusion added: $gameExe" -ForegroundColor Green
            }
            catch {
                if ($_.Exception.Message -like "*already exists*") {
                    Write-Warning "  [!] Process exclusion already exists: $gameExe"
                }
                else {
                    throw
                }
            }
        }
        
        # Exclusion: Game folder
        if ($PSCmdlet.ShouldProcess($gameFolder, "Add Defender path exclusion")) {
            try {
                Add-MpPreference -ExclusionPath $gameFolder -ErrorAction Stop
                Write-Host "  [✓] Path exclusion added: $gameFolder" -ForegroundColor Green
            }
            catch {
                if ($_.Exception.Message -like "*already exists*") {
                    Write-Warning "  [!] Path exclusion already exists: $gameFolder"
                }
                else {
                    throw
                }
            }
        }
        
        # Exclusion: Shader caches
        foreach ($cachePath in $shaderCaches) {
            if ($PSCmdlet.ShouldProcess($cachePath, "Add Defender path exclusion")) {
                try {
                    Add-MpPreference -ExclusionPath $cachePath -ErrorAction Stop
                    Write-Host "  [✓] Shader cache exclusion added: $cachePath" -ForegroundColor Green
                }
                catch {
                    if ($_.Exception.Message -like "*already exists*") {
                        Write-Warning "  [!] Shader cache exclusion already exists: $cachePath"
                    }
                    else {
                        throw
                    }
                }
            }
        }
    }
    catch {
        Write-Error "Failed to add Defender exclusions: $_"
        return
    }
    
    # Disable Control Flow Guard (CFG)
    Write-Host "`nDisabling Control Flow Guard (CFG)..." -ForegroundColor Cyan
    
    try {
        if ($PSCmdlet.ShouldProcess($gameExe, "Disable CFG")) {
            Set-ProcessMitigation -Name $gameExe -Disable CFG -ErrorAction Stop
            Write-Host "  [✓] CFG disabled for: $gameExe" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to disable CFG: $_"
        return
    }
    
    # Set process priority via registry
    Write-Host "`nSetting process priority (High CPU, High I/O, Normal Page)..." -ForegroundColor Cyan
    
    try {
        if ($PSCmdlet.ShouldProcess($gameExe, "Set process priority via registry")) {
            $result = Set-ProcessPriorityRegistry -ProcessName $gameExe -CpuPriorityClass 3 -IoPriority 3 -PagePriority 5
            if ($result) {
                Write-Host "  [✓] Process priority set for: $gameExe" -ForegroundColor Green
            }
            else {
                Write-Warning "  [!] Could not set process priority for: $gameExe"
            }
        }
    }
    catch {
        Write-Warning "Failed to set process priority: $_"
    }
    
    Write-Host "`n=== Exclusions added successfully! ===" -ForegroundColor Green
    Write-Host "Game performance should be improved. Restart the game if it's currently running." -ForegroundColor Yellow
}

function Remove-GameSecurityExclusion {
    <#
    .SYNOPSIS
        Removes Windows Defender exclusions and re-enables CFG for a game.
    
    .DESCRIPTION
        This function removes all security exclusions that were added for a game, restoring
        default Windows security settings. Use this to undo the changes made by Add-GameSecurityExclusion.
    
    .PARAMETER GameName
        The name of the game executable (with or without .exe extension).
    
    .PARAMETER GamePath
        Optional. The full path to the game executable. If not provided, the function will attempt to
        auto-detect the game location.
    
    .PARAMETER WhatIf
        Shows what would happen if the command runs without actually making changes.
    
    .EXAMPLE
        Remove-GameSecurityExclusion -GameName "Cyberpunk2077.exe" -Verbose
        
        Removes exclusions for Cyberpunk 2077 with verbose output.
    
    .EXAMPLE
        Remove-GameSecurityExclusion -GameName "EldenRing" -WhatIf
        
        Previews what exclusions would be removed without actually making changes.
    
    .NOTES
        Requires: Administrator privileges
        Platform: Windows 10/11
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$GameName,
        
        [Parameter()]
        [string]$GamePath
    )
    
    # Check administrator privileges
    if (-not (Test-Administrator)) {
        throw "This function requires administrator privileges. Please run PowerShell as Administrator."
    }
    
    # Normalize game name
    $gameExe = if ($GameName -notmatch '\.exe$') { "$GameName.exe" } else { $GameName }
    $gameNameOnly = $GameName -replace '\.exe$', ''
    
    Write-Host "`n=== Removing Security Exclusions for $gameNameOnly ===" -ForegroundColor Cyan
    
    # Find game executable if path not provided
    if (-not $GamePath) {
        Write-Host "Auto-detecting game location..." -ForegroundColor Yellow
        $GamePath = Find-GameExecutable -GameName $gameNameOnly
        
        if (-not $GamePath) {
            Write-Warning "Game executable not found. Will only remove process-based exclusions."
        }
    }
    
    $gameFolder = $null
    $shaderCaches = @()
    
    if ($GamePath -and (Test-Path $GamePath)) {
        Write-Host "Game found: $GamePath" -ForegroundColor Green
        $gameFolder = Split-Path $GamePath -Parent
        $shaderCaches = Get-ShaderCachePath -GamePath $GamePath
    }
    
    # Remove Windows Defender exclusions
    Write-Host "`nRemoving Windows Defender exclusions..." -ForegroundColor Cyan
    
    try {
        # Remove process exclusion
        if ($PSCmdlet.ShouldProcess($gameExe, "Remove Defender process exclusion")) {
            try {
                Remove-MpPreference -ExclusionProcess $gameExe -ErrorAction Stop
                Write-Host "  [✓] Process exclusion removed: $gameExe" -ForegroundColor Green
            }
            catch {
                if ($_.Exception.Message -like "*does not exist*" -or $_.Exception.Message -like "*not found*") {
                    Write-Warning "  [!] Process exclusion not found: $gameExe"
                }
                else {
                    throw
                }
            }
        }
        
        # Remove game folder exclusion
        if ($gameFolder -and $PSCmdlet.ShouldProcess($gameFolder, "Remove Defender path exclusion")) {
            try {
                Remove-MpPreference -ExclusionPath $gameFolder -ErrorAction Stop
                Write-Host "  [✓] Path exclusion removed: $gameFolder" -ForegroundColor Green
            }
            catch {
                if ($_.Exception.Message -like "*does not exist*" -or $_.Exception.Message -like "*not found*") {
                    Write-Warning "  [!] Path exclusion not found: $gameFolder"
                }
                else {
                    throw
                }
            }
        }
        
        # Remove shader cache exclusions
        foreach ($cachePath in $shaderCaches) {
            if ($PSCmdlet.ShouldProcess($cachePath, "Remove Defender path exclusion")) {
                try {
                    Remove-MpPreference -ExclusionPath $cachePath -ErrorAction Stop
                    Write-Host "  [✓] Shader cache exclusion removed: $cachePath" -ForegroundColor Green
                }
                catch {
                    if ($_.Exception.Message -like "*does not exist*" -or $_.Exception.Message -like "*not found*") {
                        Write-Warning "  [!] Shader cache exclusion not found: $cachePath"
                    }
                    else {
                        throw
                    }
                }
            }
        }
    }
    catch {
        Write-Error "Failed to remove Defender exclusions: $_"
        return
    }
    
    # Re-enable Control Flow Guard (CFG)
    Write-Host "`nRe-enabling Control Flow Guard (CFG)..." -ForegroundColor Cyan
    
    try {
        if ($PSCmdlet.ShouldProcess($gameExe, "Re-enable CFG")) {
            # Check if process has any mitigations set
            $mitigation = Get-ProcessMitigation -Name $gameExe -ErrorAction SilentlyContinue
            
            if ($mitigation) {
                Set-ProcessMitigation -Name $gameExe -Reset -ErrorAction Stop
                Write-Host "  [✓] CFG re-enabled for: $gameExe" -ForegroundColor Green
            }
            else {
                Write-Host "  [✓] No custom mitigations found for: $gameExe (CFG already at system default)" -ForegroundColor Gray
            }
        }
    }
    catch {
        Write-Error "Failed to re-enable CFG: $_"
        return
    }
    
    # Remove process priority settings
    Write-Host "`nRemoving process priority settings..." -ForegroundColor Cyan
    
    try {
        if ($PSCmdlet.ShouldProcess($gameExe, "Remove process priority registry settings")) {
            $result = Remove-ProcessPriorityRegistry -ProcessName $gameExe
            if ($result) {
                Write-Host "  [✓] Process priority settings removed for: $gameExe" -ForegroundColor Green
            }
            else {
                Write-Host "  [✓] No process priority settings found for: $gameExe" -ForegroundColor Gray
            }
        }
    }
    catch {
        Write-Warning "Failed to remove process priority settings: $_"
    }
    
    Write-Host "`n=== Exclusions removed successfully! ===" -ForegroundColor Green
}

function Get-GameSecurityExclusion {
    <#
    .SYNOPSIS
        Lists all Windows Defender exclusions and CFG-disabled processes.
    
    .DESCRIPTION
        This function retrieves and displays all current Windows Defender exclusions (processes and paths)
        and lists processes that have Control Flow Guard (CFG) disabled.
    
    .PARAMETER GameName
        Optional. Filter results to show only exclusions related to a specific game.
    
    .PARAMETER Detailed
        Optional. Show detailed information including full paths and timestamps.
    
    .EXAMPLE
        Get-GameSecurityExclusion
        
        Lists all current security exclusions.
    
    .EXAMPLE
        Get-GameSecurityExclusion -GameName "Cyberpunk2077"
        
        Lists exclusions specific to Cyberpunk 2077.
    
    .EXAMPLE
        Get-GameSecurityExclusion -Detailed
        
        Lists all exclusions with detailed information.
    
    .NOTES
        Platform: Windows 10/11
        Note: Some information (Defender exclusions) requires Administrator privileges.
              Process priority settings can be viewed without elevation.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$GameName,
        
        [Parameter()]
        [switch]$Detailed
    )
    
    $isAdmin = Test-Administrator
    
    Write-Host "`n=== Security Exclusions Report ===" -ForegroundColor Cyan
    
    # Get Windows Defender preferences (requires admin)
    $prefs = $null
    if ($isAdmin) {
        try {
            $prefs = Get-MpPreference -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to retrieve Windows Defender preferences: $_"
        }
    }
    else {
        Write-Host "(Run as Administrator to see Defender exclusions)" -ForegroundColor DarkGray
    }
    
    # Filter by game name if specified
    $processFilter = if ($GameName) { 
        if ($GameName -notmatch '\.exe$') { "$GameName.exe" } else { $GameName }
    }
    else { 
        "*" 
    }
    
    # Display Process Exclusions
    if ($prefs) {
        Write-Host "`n--- Process Exclusions ---" -ForegroundColor Yellow
        $processes = $prefs.ExclusionProcess
        
        if ($processes -and $processes.Count -gt 0) {
            $filteredProcesses = $processes | Where-Object { $_ -like $processFilter }
            
            if ($filteredProcesses) {
                $filteredProcesses | ForEach-Object {
                    Write-Host "  • $_" -ForegroundColor White
                }
                Write-Host "Total: $($filteredProcesses.Count)" -ForegroundColor Gray
            }
            else {
                Write-Host "  No process exclusions found matching '$GameName'" -ForegroundColor Gray
            }
        }
        else {
            Write-Host "  No process exclusions configured" -ForegroundColor Gray
        }
        
        # Display Path Exclusions
        Write-Host "`n--- Path Exclusions ---" -ForegroundColor Yellow
        $paths = $prefs.ExclusionPath
        
        if ($paths -and $paths.Count -gt 0) {
            $filteredPaths = if ($GameName) {
                $paths | Where-Object { $_ -like "*$($GameName -replace '\.exe$', '')*" }
            }
            else {
                $paths
            }
            
            if ($filteredPaths) {
                $filteredPaths | ForEach-Object {
                    Write-Host "  • $_" -ForegroundColor White
                }
                Write-Host "Total: $($filteredPaths.Count)" -ForegroundColor Gray
            }
            else {
                if ($GameName) {
                    Write-Host "  No path exclusions found matching '$GameName'" -ForegroundColor Gray
                }
                else {
                    Write-Host "  No path exclusions configured" -ForegroundColor Gray
                }
            }
        }
        else {
            Write-Host "  No path exclusions configured" -ForegroundColor Gray
        }
    }
    
    # Display CFG-disabled processes (requires admin for Get-ProcessMitigation)
    if ($isAdmin) {
        Write-Host "`n--- Control Flow Guard (CFG) Disabled ---" -ForegroundColor Yellow
        
        try {
            $ifeoPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"
            $cfgDisabled = @()
            
            if (Test-Path $ifeoPath) {
                $processKeys = Get-ChildItem $ifeoPath -ErrorAction SilentlyContinue
                
                foreach ($key in $processKeys) {
                    $processName = $key.PSChildName
                    
                    # Filter by game name if specified
                    if ($GameName -and $processName -notlike $processFilter) {
                        continue
                    }
                    
                    try {
                        $mitigation = Get-ProcessMitigation -Name $processName -ErrorAction SilentlyContinue
                        if ($mitigation -and $mitigation.CFG -and $mitigation.CFG.Enable -eq "OFF") {
                            $cfgDisabled += $processName
                        }
                    }
                    catch {
                        Write-Verbose "Could not check CFG status for $processName"
                    }
                }
            }
            
            if ($cfgDisabled.Count -gt 0) {
                $cfgDisabled | ForEach-Object {
                    Write-Host "  • $_" -ForegroundColor White
                }
                Write-Host "Total: $($cfgDisabled.Count)" -ForegroundColor Gray
            }
            else {
                if ($GameName) {
                    Write-Host "  No processes found with CFG disabled matching '$GameName'" -ForegroundColor Gray
                }
                else {
                    Write-Host "  No processes have CFG explicitly disabled" -ForegroundColor Gray
                }
            }
        }
        catch {
            Write-Warning "Failed to retrieve CFG information: $_"
        }
    }
    
    # Display process priority settings
    Write-Host "`n--- Process Priority Settings ---" -ForegroundColor Yellow
    
    try {
        $ifeoPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"
        $prioritySettings = @()
        
        if (Test-Path $ifeoPath) {
            $processKeys = Get-ChildItem $ifeoPath -ErrorAction SilentlyContinue
            
            foreach ($key in $processKeys) {
                $processName = $key.PSChildName
                
                # Filter by game name if specified
                if ($GameName -and $processName -notlike $processFilter) {
                    continue
                }
                
                $priority = Get-ProcessPriorityRegistry -ProcessName $processName
                if ($priority) {
                    $prioritySettings += $priority
                }
            }
        }
        
        if ($prioritySettings.Count -gt 0) {
            $cpuPriorityNames = @{ 1 = "Idle"; 2 = "Normal"; 3 = "High"; 4 = "Realtime" }
            $ioPriorityNames = @{ 0 = "VeryLow"; 1 = "Low"; 2 = "Normal"; 3 = "High" }
            
            $prioritySettings | ForEach-Object {
                $cpuName = $cpuPriorityNames[$_.CpuPriorityClass]
                $ioName = $ioPriorityNames[$_.IoPriority]
                Write-Host "  • $($_.ProcessName) - CPU: $cpuName, I/O: $ioName, Page: $($_.PagePriority)" -ForegroundColor White
            }
            Write-Host "Total: $($prioritySettings.Count)" -ForegroundColor Gray
        }
        else {
            if ($GameName) {
                Write-Host "  No process priority settings found matching '$GameName'" -ForegroundColor Gray
            }
            else {
                Write-Host "  No process priority settings configured" -ForegroundColor Gray
            }
        }
    }
    catch {
        Write-Warning "Failed to retrieve process priority information: $_"
    }
    
    Write-Host ""
}

function Add-ShaderCacheExclusion {
    <#
    .SYNOPSIS
        Adds Windows Defender exclusions for AMD and NVIDIA shader cache directories.
    
    .DESCRIPTION
        This function adds permanent Windows Defender exclusions for the global AMD DxCache
        and NVIDIA shader cache directories. These caches are used by graphics drivers and
        excluding them can improve gaming performance.
    
    .PARAMETER WhatIf
        Shows what would happen if the command runs without actually making changes.
    
    .EXAMPLE
        Add-ShaderCacheExclusion -Verbose
        
        Adds shader cache exclusions with verbose output.
    
    .EXAMPLE
        Add-ShaderCacheExclusion -WhatIf
        
        Previews what shader cache exclusions would be added.
    
    .NOTES
        Requires: Administrator privileges
        Platform: Windows 10/11
        Caches: AMD DxCache, NVIDIA NV_Cache
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()
    
    # Check administrator privileges
    if (-not (Test-Administrator)) {
        throw "This function requires administrator privileges. Please run PowerShell as Administrator."
    }
    
    Write-Host "`n=== Adding Shader Cache Exclusions ===" -ForegroundColor Cyan
    
    # Define shader cache paths
    $cachePaths = @(
        # AMD Shader Caches
        @{
            Name = "AMD DX9 Cache"
            Path = Join-Path $env:LOCALAPPDATA "AMD\DX9Cache"
        },
        @{
            Name = "AMD DirectX Cache"
            Path = Join-Path $env:LOCALAPPDATA "AMD\DxCache"
        },
        @{
            Name = "AMD DXC Cache"
            Path = Join-Path $env:LOCALAPPDATA "AMD\DxcCache"
        },
        @{
            Name = "AMD OpenGL Cache"
            Path = Join-Path $env:LOCALAPPDATA "AMD\OglCache"
        },
        @{
            Name = "AMD Vulkan Cache"
            Path = Join-Path $env:LOCALAPPDATA "AMD\VkCache"
        },
        @{
            Name = "AMD DirectX Cache (Low)"
            Path = Join-Path $env:LOCALAPPDATA "..\LocalLow\AMD\DxCache"
        },
        
        # NVIDIA Shader Caches
        @{
            Name = "NVIDIA DirectX Cache"
            Path = Join-Path $env:LOCALAPPDATA "NVIDIA\DXCache"
        },
        @{
            Name = "NVIDIA OpenGL Cache"
            Path = Join-Path $env:LOCALAPPDATA "NVIDIA\GLCache"
        },
        @{
            Name = "NVIDIA Cache (Temp)"
            Path = Join-Path $env:LOCALAPPDATA "Temp\NVIDIA Corporation\NV_Cache"
        },
        @{
            Name = "NVIDIA DirectX Cache (Low)"
            Path = Join-Path $env:LOCALAPPDATA "..\LocalLow\NVIDIA\DXCache"
        },
        @{
            Name = "NVIDIA Cache (ProgramData)"
            Path = Join-Path $env:ProgramData "NVIDIA Corporation\NV_Cache"
        }
    )
    
    $added = 0
    $skipped = 0
    
    # Get current exclusions
    try {
        $currentExclusions = (Get-MpPreference).ExclusionPath
    }
    catch {
        Write-Error "Failed to retrieve current exclusions: $_"
        return
    }
    
    foreach ($cache in $cachePaths) {
        $cachePath = $cache.Path
        $cacheName = $cache.Name
        
        # Check if path exists
        if (-not (Test-Path $cachePath)) {
            Write-Warning "  [!] $cacheName not found at: $cachePath"
            continue
        }
        
        # Check if already excluded
        if ($currentExclusions -contains $cachePath) {
            Write-Host "  [✓] $cacheName already excluded: $cachePath" -ForegroundColor Gray
            $skipped++
            continue
        }
        
        # Add exclusion
        if ($PSCmdlet.ShouldProcess($cachePath, "Add Defender path exclusion")) {
            try {
                Add-MpPreference -ExclusionPath $cachePath -ErrorAction Stop
                Write-Host "  [✓] $cacheName exclusion added: $cachePath" -ForegroundColor Green
                $added++
            }
            catch {
                Write-Error "  [✗] Failed to add $cacheName exclusion: $_"
            }
        }
    }
    
    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "  Added: $added" -ForegroundColor Green
    Write-Host "  Skipped (already excluded): $skipped" -ForegroundColor Gray
    
    if ($added -gt 0) {
        Write-Host "`nShader cache exclusions configured successfully!" -ForegroundColor Green
    }
}

function Add-BulkGameExclusions {
    <#
    .SYNOPSIS
        Automatically adds security exclusions for all games found in Steam and Xbox Game Pass directories.
    
    .DESCRIPTION
        This function scans Steam and Xbox Game Pass installation directories for game executables
        and adds Windows Defender exclusions and disables CFG for each game found. It looks for
        common game executable patterns and adds exclusions for the game folders and shader caches.
    
    .PARAMETER SteamPath
        Optional. Path to Steam games directory. Defaults to C:\SteamGames\steamapps\common
    
    .PARAMETER XboxPath
        Optional. Path to Xbox games directory. Defaults to C:\XboxGames
    
    .PARAMETER WhatIf
        Shows what would happen without actually making changes.
    
    .EXAMPLE
        Add-BulkGameExclusions -Verbose
        
        Scans default Steam and Xbox directories and adds exclusions for all games found.
    
    .EXAMPLE
        Add-BulkGameExclusions -SteamPath "D:\SteamGames\steamapps\common" -WhatIf
        
        Previews what exclusions would be added for games in a custom Steam directory.
    
    .NOTES
        Requires: Administrator privileges
        Platform: Windows 10/11
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string]$SteamPath = "C:\SteamGames\steamapps\common",
        
        [Parameter()]
        [string]$XboxPath = "C:\XboxGames"
    )
    
    # Check administrator privileges
    if (-not (Test-Administrator)) {
        throw "This function requires administrator privileges. Please run PowerShell as Administrator."
    }
    
    Write-Host "`n=== Bulk Game Exclusions ===" -ForegroundColor Cyan
    Write-Host "Scanning for games...`n" -ForegroundColor Yellow
    
    $gameExecutables = @()
    
    # Scan Steam directory
    if (Test-Path $SteamPath) {
        Write-Host "Scanning Steam games: $SteamPath" -ForegroundColor Cyan
        
        # Get all game folders
        $gameFolders = Get-ChildItem -Path $SteamPath -Directory -ErrorAction SilentlyContinue
        
        foreach ($folder in $gameFolders) {
            # Look for executables (common patterns for game launchers)
            $exeFiles = Get-ChildItem -Path $folder.FullName -Filter "*.exe" -Recurse -ErrorAction SilentlyContinue -Depth 3 |
                        Where-Object { 
                            $_.Name -notlike "*unins*" -and 
                            $_.Name -notlike "*installer*" -and
                            $_.Name -notlike "*crash*" -and
                            $_.Name -notlike "*report*" -and
                            $_.Name -notlike "*redist*" -and
                            $_.Name -notlike "*vcredist*" -and
                            $_.Name -notlike "*directx*" -and
                            $_.Name -notlike "*UnityCrashHandler*"
                        }
            
            if ($exeFiles) {
                # Prefer game launcher or main exe based on common naming
                $mainExe = $exeFiles | Where-Object { 
                    $_.Name -match "launcher|game|^($($folder.Name))" 
                } | Select-Object -First 1
                
                if (-not $mainExe) {
                    # If no obvious launcher, pick the first exe in the root or bin folder
                    $mainExe = $exeFiles | Where-Object {
                        $_.Directory.Name -in @($folder.Name, 'bin', 'Bin', 'Binaries')
                    } | Select-Object -First 1
                }
                
                if (-not $mainExe) {
                    # Last resort: just pick first exe found
                    $mainExe = $exeFiles | Select-Object -First 1
                }
                
                if ($mainExe) {
                    $gameExecutables += [PSCustomObject]@{
                        Name = $folder.Name
                        Path = $mainExe.FullName
                        Source = "Steam"
                    }
                }
            }
        }
        
        Write-Host "  Found $($gameExecutables.Count) Steam games" -ForegroundColor Green
    }
    else {
        Write-Warning "Steam path not found: $SteamPath"
    }
    
    # Scan Xbox Game Pass directory
    if (Test-Path $XboxPath) {
        Write-Host "Scanning Xbox games: $XboxPath" -ForegroundColor Cyan
        
        $xboxFolders = Get-ChildItem -Path $XboxPath -Directory -ErrorAction SilentlyContinue
        $xboxCount = 0
        
        foreach ($folder in $xboxFolders) {
            # Xbox games often have Content subfolder
            $contentPath = Join-Path $folder.FullName "Content"
            $searchPath = if (Test-Path $contentPath) { $contentPath } else { $folder.FullName }
            
            $exeFiles = Get-ChildItem -Path $searchPath -Filter "*.exe" -Recurse -ErrorAction SilentlyContinue -Depth 3 |
                        Where-Object { 
                            $_.Name -notlike "*unins*" -and 
                            $_.Name -notlike "*installer*" -and
                            $_.Name -notlike "*crash*" -and
                            $_.Name -notlike "*report*" -and
                            $_.Name -notlike "*redist*"
                        }
            
            if ($exeFiles) {
                $mainExe = $exeFiles | Where-Object { 
                    $_.Name -match "launcher|game|helper" 
                } | Select-Object -First 1
                
                if (-not $mainExe) {
                    $mainExe = $exeFiles | Select-Object -First 1
                }
                
                if ($mainExe) {
                    $gameExecutables += [PSCustomObject]@{
                        Name = $folder.Name
                        Path = $mainExe.FullName
                        Source = "Xbox"
                    }
                    $xboxCount++
                }
            }
        }
        
        Write-Host "  Found $xboxCount Xbox games" -ForegroundColor Green
    }
    else {
        Write-Warning "Xbox path not found: $XboxPath"
    }
    
    if ($gameExecutables.Count -eq 0) {
        Write-Warning "No games found in specified directories."
        return
    }
    
    Write-Host "`nTotal games found: $($gameExecutables.Count)" -ForegroundColor Cyan
    Write-Host "Adding exclusions...`n" -ForegroundColor Yellow
    
    $successCount = 0
    $failCount = 0
    $skippedCount = 0
    
    foreach ($game in $gameExecutables) {
        Write-Host "[$($game.Source)] $($game.Name)" -ForegroundColor White
        
        try {
            # Extract paths
            $gameFolder = Split-Path $game.Path -Parent
            $gameExe = Split-Path $game.Path -Leaf
            
            # Check if already excluded
            $currentExclusions = (Get-MpPreference).ExclusionPath
            if ($currentExclusions -contains $gameFolder) {
                Write-Host "  [⊘] Already excluded" -ForegroundColor Gray
                $skippedCount++
                continue
            }
            
            if ($PSCmdlet.ShouldProcess($game.Name, "Add security exclusions")) {
                # Add process exclusion
                try {
                    Add-MpPreference -ExclusionProcess $gameExe -ErrorAction Stop
                    Write-Verbose "  Process: $gameExe"
                }
                catch {
                    if ($_.Exception.Message -notlike "*already exists*") {
                        throw
                    }
                }
                
                # Add folder exclusion
                Add-MpPreference -ExclusionPath $gameFolder -ErrorAction Stop
                Write-Verbose "  Folder: $gameFolder"
                
                # Add shader cache exclusions
                $shaderCaches = Get-ShaderCachePath -GamePath $game.Path
                foreach ($cache in $shaderCaches) {
                    try {
                        Add-MpPreference -ExclusionPath $cache -ErrorAction Stop
                        Write-Verbose "  Cache: $cache"
                    }
                    catch {
                        if ($_.Exception.Message -notlike "*already exists*") {
                            Write-Verbose "  Cache failed: $cache"
                        }
                    }
                }
                
                # Disable CFG
                try {
                    Set-ProcessMitigation -Name $gameExe -Disable CFG -ErrorAction Stop
                    Write-Verbose "  CFG disabled: $gameExe"
                }
                catch {
                    Write-Verbose "  CFG disable failed (may not be needed)"
                }
                
                # Set process priority
                try {
                    $priorityResult = Set-ProcessPriorityRegistry -ProcessName $gameExe -CpuPriorityClass 3 -IoPriority 3 -PagePriority 5
                    if ($priorityResult) {
                        Write-Verbose "  Priority set: $gameExe"
                    }
                }
                catch {
                    Write-Verbose "  Priority set failed: $gameExe"
                }
                
                Write-Host "  [✓] Exclusions added" -ForegroundColor Green
                $successCount++
            }
        }
        catch {
            Write-Host "  [✗] Failed: $_" -ForegroundColor Red
            $failCount++
        }
    }
    
    # Summary
    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "  Total games: $($gameExecutables.Count)" -ForegroundColor White
    Write-Host "  Successfully added: $successCount" -ForegroundColor Green
    Write-Host "  Already excluded: $skippedCount" -ForegroundColor Gray
    Write-Host "  Failed: $failCount" -ForegroundColor Red
    
    if ($successCount -gt 0) {
        Write-Host "`nBulk exclusions completed successfully!" -ForegroundColor Green
    }
}

#endregion

function Set-GameProcessPriority {
    <#
    .SYNOPSIS
        Sets process priority for a game via Image File Execution Options registry.
    
    .DESCRIPTION
        This function configures Windows to automatically set CPU priority, I/O priority,
        and memory page priority for a game process whenever it starts. This is done via
        the Image File Execution Options\PerfOptions registry keys.
    
    .PARAMETER GameName
        The name of the game executable (with or without .exe extension).
    
    .PARAMETER CpuPriority
        CPU priority class. Valid values: Idle, BelowNormal, Normal, AboveNormal, High, Realtime.
        Default: High
    
    .PARAMETER IoPriority
        I/O priority. Valid values: VeryLow, Low, Normal, High.
        Default: High
    
    .PARAMETER PagePriority
        Memory page priority (1-5, higher is better).
        Default: 5
    
    .PARAMETER WhatIf
        Shows what would happen without actually making changes.
    
    .EXAMPLE
        Set-GameProcessPriority -GameName "eldenring.exe"
        
        Sets high CPU and I/O priority for Elden Ring.
    
    .EXAMPLE
        Set-GameProcessPriority -GameName "Cyberpunk2077" -CpuPriority AboveNormal -IoPriority Normal
        
        Sets above-normal CPU priority and normal I/O priority for Cyberpunk 2077.
    
    .NOTES
        Requires: Administrator privileges
        Platform: Windows 10/11
        
        CPU Priority Classes:
        - Idle (1): Lowest priority, runs only when system is idle
        - BelowNormal: Lower than normal
        - Normal (2): Default Windows priority
        - AboveNormal: Higher than normal
        - High (3): High priority, recommended for games
        - Realtime (4): Highest priority, use with caution
        
        I/O Priority:
        - VeryLow (0): Background I/O
        - Low (1): Low priority I/O
        - Normal (2): Standard I/O priority
        - High (3): High priority I/O, recommended for games
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$GameName,
        
        [Parameter()]
        [ValidateSet('Idle', 'BelowNormal', 'Normal', 'AboveNormal', 'High', 'Realtime')]
        [string]$CpuPriority = 'High',
        
        [Parameter()]
        [ValidateSet('VeryLow', 'Low', 'Normal', 'High')]
        [string]$IoPriority = 'High',
        
        [Parameter()]
        [ValidateRange(1, 5)]
        [int]$PagePriority = 5
    )
    
    # Check administrator privileges
    if (-not (Test-Administrator)) {
        throw "This function requires administrator privileges. Please run PowerShell as Administrator."
    }
    
    # Normalize game name
    $gameExe = if ($GameName -notmatch '\.exe$') { "$GameName.exe" } else { $GameName }
    $gameNameOnly = $GameName -replace '\.exe$', ''
    
    # Convert string priorities to numeric values
    $cpuPriorityMap = @{
        'Idle' = 1
        'BelowNormal' = 1  # Windows maps this to Idle in IFEO
        'Normal' = 2
        'AboveNormal' = 2  # Windows maps this to Normal in IFEO, use High instead
        'High' = 3
        'Realtime' = 4
    }
    
    $ioPriorityMap = @{
        'VeryLow' = 0
        'Low' = 1
        'Normal' = 2
        'High' = 3
    }
    
    $cpuValue = $cpuPriorityMap[$CpuPriority]
    $ioValue = $ioPriorityMap[$IoPriority]
    
    Write-Host "`n=== Setting Process Priority for $gameNameOnly ===" -ForegroundColor Cyan
    Write-Host "  CPU Priority: $CpuPriority ($cpuValue)" -ForegroundColor White
    Write-Host "  I/O Priority: $IoPriority ($ioValue)" -ForegroundColor White
    Write-Host "  Page Priority: $PagePriority" -ForegroundColor White
    
    try {
        if ($PSCmdlet.ShouldProcess($gameExe, "Set process priority via registry")) {
            $result = Set-ProcessPriorityRegistry -ProcessName $gameExe -CpuPriorityClass $cpuValue -IoPriority $ioValue -PagePriority $PagePriority
            
            if ($result) {
                Write-Host "`n[✓] Process priority configured successfully!" -ForegroundColor Green
                Write-Host "Priority settings will be applied automatically when $gameExe starts." -ForegroundColor Yellow
            }
            else {
                Write-Error "Failed to set process priority for $gameExe"
            }
        }
    }
    catch {
        Write-Error "Failed to set process priority: $_"
    }
}

function Remove-GameProcessPriority {
    <#
    .SYNOPSIS
        Removes process priority settings for a game.
    
    .DESCRIPTION
        This function removes the Image File Execution Options\PerfOptions registry keys
        that were set for a game, returning it to default Windows priority handling.
    
    .PARAMETER GameName
        The name of the game executable (with or without .exe extension).
    
    .PARAMETER WhatIf
        Shows what would happen without actually making changes.
    
    .EXAMPLE
        Remove-GameProcessPriority -GameName "eldenring.exe"
        
        Removes priority settings for Elden Ring.
    
    .NOTES
        Requires: Administrator privileges
        Platform: Windows 10/11
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$GameName
    )
    
    # Check administrator privileges
    if (-not (Test-Administrator)) {
        throw "This function requires administrator privileges. Please run PowerShell as Administrator."
    }
    
    # Normalize game name
    $gameExe = if ($GameName -notmatch '\.exe$') { "$GameName.exe" } else { $GameName }
    $gameNameOnly = $GameName -replace '\.exe$', ''
    
    Write-Host "`n=== Removing Process Priority for $gameNameOnly ===" -ForegroundColor Cyan
    
    try {
        if ($PSCmdlet.ShouldProcess($gameExe, "Remove process priority registry settings")) {
            $result = Remove-ProcessPriorityRegistry -ProcessName $gameExe
            
            if ($result) {
                Write-Host "[✓] Process priority settings removed for $gameExe" -ForegroundColor Green
            }
            else {
                Write-Host "[✓] No process priority settings found for $gameExe" -ForegroundColor Gray
            }
        }
    }
    catch {
        Write-Error "Failed to remove process priority: $_"
    }
}

#endregion

# Export module members
Export-ModuleMember -Function @(
    'Add-GameSecurityExclusion',
    'Remove-GameSecurityExclusion',
    'Get-GameSecurityExclusion',
    'Add-ShaderCacheExclusion',
    'Add-BulkGameExclusions',
    'Set-GameProcessPriority',
    'Remove-GameProcessPriority'
)

# vim: ts=2 sts=2 sw=2 et

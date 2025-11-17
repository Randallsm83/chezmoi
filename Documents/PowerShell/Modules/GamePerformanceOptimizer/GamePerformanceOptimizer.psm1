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
    
    # Extract game folder
    $gameFolder = Split-Path $GamePath -Parent
    Write-Verbose "Game folder: $gameFolder"
    
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
            Set-ProcessMitigation -Name $gameExe -Remove -ErrorAction Stop
            Write-Host "  [✓] CFG re-enabled for: $gameExe" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to re-enable CFG: $_"
        return
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
        Requires: Administrator privileges
        Platform: Windows 10/11
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$GameName,
        
        [Parameter()]
        [switch]$Detailed
    )
    
    # Check administrator privileges
    if (-not (Test-Administrator)) {
        throw "This function requires administrator privileges. Please run PowerShell as Administrator."
    }
    
    Write-Host "`n=== Security Exclusions Report ===" -ForegroundColor Cyan
    
    # Get Windows Defender preferences
    try {
        $prefs = Get-MpPreference -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to retrieve Windows Defender preferences: $_"
        return
    }
    
    # Filter by game name if specified
    $processFilter = if ($GameName) { 
        if ($GameName -notmatch '\.exe$') { "$GameName.exe" } else { $GameName }
    }
    else { 
        "*" 
    }
    
    # Display Process Exclusions
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
    
    # Display CFG-disabled processes
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
        @{
            Name = "AMD DxCache"
            Path = Join-Path $env:LOCALAPPDATA "AMD\DxCache"
        },
        @{
            Name = "NVIDIA Shader Cache"
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

#endregion

# Export module members
Export-ModuleMember -Function @(
    'Add-GameSecurityExclusion',
    'Remove-GameSecurityExclusion',
    'Get-GameSecurityExclusion',
    'Add-ShaderCacheExclusion'
)

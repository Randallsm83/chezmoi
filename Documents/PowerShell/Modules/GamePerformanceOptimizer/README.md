# GamePerformanceOptimizer

A PowerShell module to optimize game performance by configuring Windows Defender exclusions and disabling Control Flow Guard (CFG) for games.

## Overview

This module automates the process of adding security exclusions for games, which can significantly improve performance by reducing antivirus scanning overhead. It automatically detects games from Steam, Epic Games, and GOG Galaxy installations.

## Features

✅ **Automatic Game Detection**
- Detects games from Steam libraries (with multi-library support)
- Scans Epic Games Launcher installations
- Finds GOG Galaxy games
- Searches common installation directories
- File picker fallback for manual selection

✅ **Comprehensive Exclusions**
- Windows Defender process exclusions
- Game folder path exclusions
- Shader cache exclusions (per-game and global)
- Control Flow Guard (CFG) disable/enable

✅ **Shader Cache Support**
- Auto-detects Steam shader cache folders
- Per-game shader cache detection
- Permanent AMD DxCache and NVIDIA NV_Cache exclusions

✅ **Safety Features**
- Full `-WhatIf` support for previewing changes
- Administrator privilege checking
- Error handling for existing exclusions
- Undo functionality with `Remove-GameSecurityExclusion`

✅ **Comprehensive Reporting**
- List all Windows Defender exclusions
- Show CFG-disabled processes
- Filter by specific game name
- Summary statistics

## Requirements

- **PowerShell**: 5.1 or higher (PowerShell 7+ recommended)
- **Platform**: Windows 10/11
- **Privileges**: Administrator rights (required for all operations)
- **Dependencies**: 
  - Windows Defender (`Defender` module)
  - `ProcessMitigations` module
  - `System.Windows.Forms` assembly

## Installation

The module is already installed at:
```
C:\Users\Randall\Documents\PowerShell\Modules\GamePerformanceOptimizer\
```

### Manual Installation

If you need to install on another machine:

1. Copy the `GamePerformanceOptimizer` folder to:
   - **Current User**: `$HOME\Documents\PowerShell\Modules\`
   - **All Users**: `C:\Program Files\PowerShell\Modules\`

2. Verify installation:
   ```powershell
   Get-Module -ListAvailable GamePerformanceOptimizer
   ```

## Usage

### Import the Module

```powershell
Import-Module GamePerformanceOptimizer
```

### Add Game Exclusions

#### With Auto-Detection
```powershell
# Auto-detect game location
Add-GameSecurityExclusion -GameName "Cyberpunk2077.exe" -Verbose

# Works without .exe extension too
Add-GameSecurityExclusion -GameName "Cyberpunk2077"
```

#### With Manual Path
```powershell
Add-GameSecurityExclusion -GameName "Cyberpunk2077" `
    -GamePath "D:\Games\Cyberpunk 2077\bin\x64\Cyberpunk2077.exe"
```

#### Preview Changes (WhatIf)
```powershell
# See what would be changed without making changes
Add-GameSecurityExclusion -GameName "EldenRing" -WhatIf
```

### Remove Game Exclusions

```powershell
# Remove all exclusions for a game
Remove-GameSecurityExclusion -GameName "Cyberpunk2077.exe" -Verbose

# Preview removal
Remove-GameSecurityExclusion -GameName "EldenRing" -WhatIf
```

### List Current Exclusions

```powershell
# List all exclusions
Get-GameSecurityExclusion

# Filter by specific game
Get-GameSecurityExclusion -GameName "Cyberpunk2077"

# Detailed view
Get-GameSecurityExclusion -Detailed
```

### Add Shader Cache Exclusions

```powershell
# Add permanent exclusions for AMD and NVIDIA shader caches
Add-ShaderCacheExclusion -Verbose

# Preview what would be added
Add-ShaderCacheExclusion -WhatIf
```

## Functions

### `Add-GameSecurityExclusion`

Adds Windows Defender exclusions and disables CFG for a game.

**Parameters:**
- `GameName` (Required): Game executable name (with or without .exe)
- `GamePath` (Optional): Full path to game executable
- `WhatIf`: Preview changes without applying
- `Verbose`: Show detailed progress

**What it does:**
1. Auto-detects game location (or uses provided path)
2. Adds Windows Defender process exclusion for the game executable
3. Adds Windows Defender path exclusion for the game folder
4. Detects and adds exclusions for shader cache folders
5. Disables Control Flow Guard (CFG) for the game process

### `Remove-GameSecurityExclusion`

Removes all security exclusions for a game.

**Parameters:**
- `GameName` (Required): Game executable name
- `GamePath` (Optional): Full path to game executable
- `WhatIf`: Preview changes without applying
- `Verbose`: Show detailed progress

**What it does:**
1. Removes Windows Defender process exclusion
2. Removes Windows Defender path exclusions
3. Removes shader cache exclusions
4. Re-enables Control Flow Guard (CFG)

### `Get-GameSecurityExclusion`

Lists all current security exclusions.

**Parameters:**
- `GameName` (Optional): Filter by specific game
- `Detailed`: Show detailed information

**What it shows:**
- All Windows Defender process exclusions
- All Windows Defender path exclusions
- All processes with CFG disabled
- Summary counts

### `Add-ShaderCacheExclusion`

Adds permanent exclusions for shader cache directories.

**Parameters:**
- `WhatIf`: Preview changes without applying
- `Verbose`: Show detailed progress

**What it does:**
- Adds exclusion for AMD DxCache: `%LOCALAPPDATA%\AMD\DxCache`
- Adds exclusion for NVIDIA cache: `%ProgramData%\NVIDIA Corporation\NV_Cache`

## Examples

### Example 1: Add Exclusions for Cyberpunk 2077

```powershell
# Run as Administrator
Add-GameSecurityExclusion -GameName "Cyberpunk2077" -Verbose
```

**Output:**
```
=== Adding Security Exclusions for Cyberpunk2077 ===
Auto-detecting game location...
Game found: C:\SteamGames\steamapps\common\Cyberpunk 2077\bin\x64\Cyberpunk2077.exe
Shader cache(s) found: 1

Adding Windows Defender exclusions...
  [✓] Process exclusion added: Cyberpunk2077.exe
  [✓] Path exclusion added: C:\SteamGames\steamapps\common\Cyberpunk 2077\bin\x64
  [✓] Shader cache exclusion added: C:\SteamGames\steamapps\shadercache\1091500

Disabling Control Flow Guard (CFG)...
  [✓] CFG disabled for: Cyberpunk2077.exe

=== Exclusions added successfully! ===
Game performance should be improved. Restart the game if it's currently running.
```

### Example 2: Check Current Exclusions

```powershell
Get-GameSecurityExclusion -GameName "Cyberpunk2077"
```

**Output:**
```
=== Security Exclusions Report ===

--- Process Exclusions ---
  • Cyberpunk2077.exe
Total: 1

--- Path Exclusions ---
  • C:\SteamGames\steamapps\common\Cyberpunk 2077\bin\x64
  • C:\SteamGames\steamapps\shadercache\1091500
Total: 2

--- Control Flow Guard (CFG) Disabled ---
  • Cyberpunk2077.exe
Total: 1
```

### Example 3: Add Shader Cache Exclusions

```powershell
Add-ShaderCacheExclusion -Verbose
```

**Output:**
```
=== Adding Shader Cache Exclusions ===
  [✓] AMD DxCache exclusion added: C:\Users\Randall\AppData\Local\AMD\DxCache
  [✓] NVIDIA Shader Cache exclusion added: C:\ProgramData\NVIDIA Corporation\NV_Cache

=== Summary ===
  Added: 2
  Skipped (already excluded): 0

Shader cache exclusions configured successfully!
```

### Example 4: Preview Changes Before Applying

```powershell
Add-GameSecurityExclusion -GameName "EldenRing" -WhatIf
```

**Output:**
```
What if: Performing the operation "Add Defender process exclusion" on target "eldenring.exe".
What if: Performing the operation "Add Defender path exclusion" on target "D:\Games\ELDEN RING\Game".
What if: Performing the operation "Disable CFG" on target "eldenring.exe".
```

## How It Works

### Game Auto-Detection

1. **Steam Detection:**
   - Reads Steam installation path from registry
   - Parses `libraryfolders.vdf` to find all library locations
   - Searches in `<library>\steamapps\common\` for game folders

2. **Epic Games Detection:**
   - Scans manifest files in `%ProgramData%\Epic\EpicGamesLauncher\Data\Manifests\`
   - Extracts `InstallLocation` from JSON manifests

3. **GOG Galaxy Detection:**
   - Checks registry for GOG installations
   - Searches default path `C:\GOG Games\`

4. **Fallback:**
   - Searches common directories (`C:\Program Files`, `D:\Games`, etc.)
   - Opens file picker dialog if not found

### Shader Cache Detection

1. **Steam Shader Cache:**
   - Extracts AppID from Steam manifest files
   - Checks `<SteamPath>\steamapps\shadercache\<AppID>\`

2. **Per-Game Cache:**
   - Searches game directory for folders named:
     - `cache`
     - `shadercache`
     - `ShaderCache`
     - `Shaders`

## Performance Impact

Adding these exclusions can improve game performance by:

- **Reducing stuttering** caused by real-time antivirus scanning
- **Faster game loading** times
- **Smoother gameplay** during asset streaming
- **Reduced CPU overhead** from security checks

**Note:** These changes only affect the specified game. System security for other applications remains intact.

## Security Considerations

⚠️ **Important Security Notes:**

1. **Only add exclusions for trusted games** from legitimate sources
2. **Do not add exclusions for pirated software** (security risk)
3. **Review exclusions periodically** using `Get-GameSecurityExclusion`
4. **Remove exclusions** for games you no longer play
5. **Keep Windows Defender active** for non-game files

## Troubleshooting

### "This function requires administrator privileges"

**Solution:** Run PowerShell as Administrator:
```powershell
# Right-click PowerShell icon → "Run as Administrator"
```

### Game not auto-detected

**Solution 1:** Specify the path manually:
```powershell
Add-GameSecurityExclusion -GameName "GameName" -GamePath "C:\Path\To\Game.exe"
```

**Solution 2:** Use the file picker dialog when prompted

### Module not found

**Solution:** Verify module location:
```powershell
$env:PSModulePath -split ';'
Get-Module -ListAvailable GamePerformanceOptimizer
```

### Exclusion already exists

This is a **warning**, not an error. The exclusion is already configured and will be skipped.

## Compatibility

- ✅ Windows 10 (version 1809+)
- ✅ Windows 11
- ✅ PowerShell 5.1
- ✅ PowerShell 7.x
- ✅ Windows Defender
- ✅ Third-party antivirus with Windows Defender coexistence

## Uninstall

To remove the module:

```powershell
Remove-Item "$HOME\Documents\PowerShell\Modules\GamePerformanceOptimizer" -Recurse -Force
```

To remove all exclusions before uninstalling:

```powershell
# Remove exclusions for each game
Remove-GameSecurityExclusion -GameName "Game1"
Remove-GameSecurityExclusion -GameName "Game2"
```

## Support

For issues, questions, or feature requests, please review the code or modify the module to suit your needs.

## License

This module is provided as-is for personal use.

## Version History

### v1.0.0 (2025-01-17)
- Initial release
- Add-GameSecurityExclusion function
- Remove-GameSecurityExclusion function
- Get-GameSecurityExclusion function
- Add-ShaderCacheExclusion function
- Auto-detection for Steam, Epic Games, GOG
- Steam multi-library support
- Shader cache auto-detection
- Full -WhatIf support
- Comprehensive error handling

---

**Made with ❤️ for better gaming performance**

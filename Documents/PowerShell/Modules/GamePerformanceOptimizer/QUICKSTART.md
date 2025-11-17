# Quick Start Guide - GamePerformanceOptimizer

## TL;DR

```powershell
# 1. Open PowerShell as Administrator
# 2. Import the module
Import-Module GamePerformanceOptimizer

# 3. Add exclusions for your game (it will auto-detect the location)
Add-GameSecurityExclusion -GameName "Cyberpunk2077" -Verbose

# 4. (Optional) Add shader cache exclusions permanently
Add-ShaderCacheExclusion -Verbose
```

## Common Usage Patterns

### For Cyberpunk 2077

```powershell
# With auto-detection
Add-GameSecurityExclusion -GameName "Cyberpunk2077" -Verbose

# Check what was added
Get-GameSecurityExclusion -GameName "Cyberpunk2077"

# To remove later
Remove-GameSecurityExclusion -GameName "Cyberpunk2077"
```

### For Elden Ring

```powershell
Add-GameSecurityExclusion -GameName "eldenring" -Verbose
```

### For any Steam game

```powershell
# The module will search your Steam libraries automatically
Add-GameSecurityExclusion -GameName "YourGame.exe" -Verbose
```

### Preview before applying

```powershell
# Use -WhatIf to see what would change
Add-GameSecurityExclusion -GameName "GameName" -WhatIf
```

### View all current exclusions

```powershell
Get-GameSecurityExclusion
```

### Add permanent shader cache exclusions (AMD/NVIDIA)

```powershell
# This only needs to be done once
Add-ShaderCacheExclusion -Verbose
```

## How to Run PowerShell as Administrator

### Method 1: Start Menu
1. Press Windows key
2. Type "PowerShell"
3. Right-click "Windows PowerShell" or "PowerShell 7"
4. Click "Run as Administrator"

### Method 2: Windows Terminal
1. Right-click Windows Terminal icon
2. Select "Run as Administrator"

### Method 3: From PowerShell
```powershell
# Launch a new admin PowerShell session
Start-Process pwsh -Verb RunAs
```

## Troubleshooting

### Error: "This function requires administrator privileges"

**Solution:** You need to run PowerShell as Administrator (see above).

### Error: "Game not found"

**Solution 1:** The module will prompt you with a file picker - browse to your game's .exe file.

**Solution 2:** Specify the path manually:
```powershell
Add-GameSecurityExclusion -GameName "GameName" -GamePath "C:\Path\To\Game.exe"
```

### Warning: "Exclusion already exists"

This is **normal** - it means the exclusion is already configured. No action needed.

### How to undo everything

```powershell
# Remove exclusions for a specific game
Remove-GameSecurityExclusion -GameName "GameName" -Verbose
```

## Best Practices

1. **Test with -WhatIf first** to see what will change:
   ```powershell
   Add-GameSecurityExclusion -GameName "GameName" -WhatIf
   ```

2. **Use -Verbose** to see detailed progress:
   ```powershell
   Add-GameSecurityExclusion -GameName "GameName" -Verbose
   ```

3. **Check current state** before making changes:
   ```powershell
   Get-GameSecurityExclusion -GameName "GameName"
   ```

4. **Only add trusted games** from legitimate sources (Steam, Epic, GOG, etc.)

5. **Review periodically** what exclusions you have:
   ```powershell
   Get-GameSecurityExclusion
   ```

6. **Remove exclusions** for games you've uninstalled:
   ```powershell
   Remove-GameSecurityExclusion -GameName "OldGame"
   ```

## Performance Benefits

After adding exclusions, you should notice:
- ✅ Reduced stuttering during gameplay
- ✅ Faster game loading times
- ✅ Smoother asset streaming
- ✅ Lower CPU usage from security scanning

**Note:** Restart the game after adding exclusions for best results.

## What Gets Excluded?

For each game, the module excludes:
1. **Game executable** (e.g., `Cyberpunk2077.exe`)
2. **Game folder** (e.g., `C:\Games\Cyberpunk 2077\`)
3. **Shader cache folders** (if found)
4. **CFG disabled** for the game process

Your system security remains active for all other files and applications.

## Example Session

```powershell
PS C:\> Import-Module GamePerformanceOptimizer

PS C:\> Add-GameSecurityExclusion -GameName "Cyberpunk2077" -Verbose

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

PS C:\> Get-GameSecurityExclusion -GameName "Cyberpunk2077"

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

## Questions?

Check the full README.md for comprehensive documentation, or use PowerShell's built-in help:

```powershell
Get-Help Add-GameSecurityExclusion -Full
Get-Help Remove-GameSecurityExclusion -Examples
Get-Help Get-GameSecurityExclusion -Detailed
Get-Help Add-ShaderCacheExclusion -Full
```

---

**Happy Gaming! 🎮**

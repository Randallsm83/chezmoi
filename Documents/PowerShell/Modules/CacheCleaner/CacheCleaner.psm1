# Enhanced Cache Cleaning Function for PowerShell Profile
# Version 2.0 - Self-contained with colorized output and improved error handling
function Clear-Cache {
    [CmdletBinding()]
    param()

    # Statistics tracking
    $Stats = @{
        TotalDirectories = 0
        ClearedDirectories = 0
        SkippedDirectories = 0
        ErrorDirectories = 0
        FilesRemoved = 0
        FilesSkipped = 0
        SpaceFreed = 0
    }

    # Helper function: Check if running with elevated privileges
    function Test-IsElevated {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    # Helper function: Format file size in human-readable format
    function Format-FileSize {
        param([long]$Size)

        if ($Size -gt 1GB) {
            return "{0:N2} GB" -f ($Size / 1GB)
        } elseif ($Size -gt 1MB) {
            return "{0:N2} MB" -f ($Size / 1MB)
        } elseif ($Size -gt 1KB) {
            return "{0:N2} KB" -f ($Size / 1KB)
        } else {
            return "$Size bytes"
        }
    }

    # Helper function: Print formatted header
    function Write-Header {
        param([string]$Title)

        $separator = "=" * 80
        Write-Host "`n$separator" -ForegroundColor Cyan
        Write-Host " $Title" -ForegroundColor White -BackgroundColor DarkBlue
        Write-Host "$separator" -ForegroundColor Cyan
    }

    # Helper function: Print section header
    function Write-Section {
        param([string]$Title)

        $line = "-" * 60
        Write-Host "`n$line" -ForegroundColor DarkCyan
        Write-Host " $Title" -ForegroundColor Cyan
        Write-Host "$line" -ForegroundColor DarkCyan
    }

    # Helper function: Print status message with consistent formatting
    function Write-Status {
        param(
            [string]$Message,
            [string]$Status, # "Success", "Warning", "Error", "Info", "Skip"
            [string]$Details = ""
        )

        $timestamp = Get-Date -Format "HH:mm:ss"

        switch ($Status) {
            "Success" {
                Write-Host "[$timestamp] " -ForegroundColor DarkGray -NoNewline
                Write-Host "✓ " -ForegroundColor Green -NoNewline
                Write-Host $Message -ForegroundColor White
                if ($Details) { Write-Host "   └─ $Details" -ForegroundColor DarkGreen }
            }
            "Warning" {
                Write-Host "[$timestamp] " -ForegroundColor DarkGray -NoNewline
                Write-Host "⚠ " -ForegroundColor Yellow -NoNewline
                Write-Host $Message -ForegroundColor White
                if ($Details) { Write-Host "   └─ $Details" -ForegroundColor DarkYellow }
            }
            "Error" {
                Write-Host "[$timestamp] " -ForegroundColor DarkGray -NoNewline
                Write-Host "✗ " -ForegroundColor Red -NoNewline
                Write-Host $Message -ForegroundColor White
                if ($Details) { Write-Host "   └─ $Details" -ForegroundColor DarkRed }
            }
            "Info" {
                Write-Host "[$timestamp] " -ForegroundColor DarkGray -NoNewline
                Write-Host "ℹ " -ForegroundColor Cyan -NoNewline
                Write-Host $Message -ForegroundColor White
                if ($Details) { Write-Host "   └─ $Details" -ForegroundColor DarkCyan }
            }
            "Skip" {
                Write-Host "[$timestamp] " -ForegroundColor DarkGray -NoNewline
                Write-Host "- " -ForegroundColor DarkYellow -NoNewline
                Write-Host $Message -ForegroundColor Gray
                if ($Details) { Write-Host "   └─ $Details" -ForegroundColor DarkGray }
            }
        }
    }

    # Helper function to safely clear directory contents
    function Clear-DirectoryContents {
        param(
            [string]$Path,
            [string]$Description,
            [string]$Category = "General"
        )

        $Stats.TotalDirectories++

        try {
            if (-not (Test-Path -Path $Path -PathType Container)) {
                Write-Status "Skipping $Description" "Skip" "Directory not found: $Path"
                $Stats.SkippedDirectories++
                return
            }

            Write-Status "Cleaning $Description..." "Info" "→ $Path"

            # Get directory size before cleanup
            $sizeBefore = 0
            try {
                $sizeBefore = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
                              Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                if (-not $sizeBefore) { $sizeBefore = 0 }
            } catch {
                $sizeBefore = 0
            }

            # Get all items in the directory
            $items = @()
            try {
                $items = Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue
            } catch {
                Write-Status "Failed to enumerate items in $Description" "Error" $_.Exception.Message
                $Stats.ErrorDirectories++
                return
            }

            if ($items.Count -eq 0) {
                Write-Status "$Description already clean" "Success" "0 items found"
                $Stats.ClearedDirectories++
                return
            }

            $removedCount = 0
            $skippedCount = 0
            $errors = @()

            foreach ($item in $items) {
                try {
                    # Check if file is in use
                    if ($item.PSIsContainer) {
                        Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
                    } else {
                        # For files, try to check if they're locked
                        $stream = $null
                        try {
                            $stream = [System.IO.File]::Open($item.FullName, 'Open', 'Write')
                            $stream.Close()
                            Remove-Item -Path $item.FullName -Force -ErrorAction Stop
                        } catch [System.UnauthorizedAccessException] {
                            throw $_
                        } catch [System.IO.IOException] {
                            # File might be in use
                            $skippedCount++
                            $errors += "File in use: $($item.Name)"
                            continue
                        } finally {
                            if ($stream) { $stream.Dispose() }
                        }
                    }
                    $removedCount++
                    $Stats.FilesRemoved++
                } catch [System.UnauthorizedAccessException] {
                    $skippedCount++
                    $Stats.FilesSkipped++
                    if (-not $isElevated -and $item.FullName -like "*System*") {
                        $errors += "Access denied (requires admin): $($item.Name)"
                    } else {
                        $errors += "Access denied: $($item.Name)"
                    }
                } catch {
                    $skippedCount++
                    $Stats.FilesSkipped++
                    $errors += "$($item.Name): $($_.Exception.Message)"
                }
            }

            # Calculate space freed
            $sizeAfter = 0
            try {
                $sizeAfter = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
                             Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                if (-not $sizeAfter) { $sizeAfter = 0 }
            } catch {
                $sizeAfter = 0
            }

            $spaceFreed = $sizeBefore - $sizeAfter
            $Stats.SpaceFreed += $spaceFreed

            # Report results
            if ($removedCount -gt 0) {
                $details = "$removedCount items removed"
                if ($spaceFreed -gt 0) {
                    $details += ", $(Format-FileSize $spaceFreed) freed"
                }
                if ($skippedCount -gt 0) {
                    $details += ", $skippedCount items skipped"
                }
                Write-Status "$Description cleaned successfully" "Success" $details
                $Stats.ClearedDirectories++
            } else {
                Write-Status "$Description could not be cleaned" "Warning" "$skippedCount items could not be removed"
                $Stats.ErrorDirectories++
            }

            # Show detailed errors if any (but limit to avoid spam unless -Verbose)
            if ($errors.Count -gt 0) {
                $showAll = $VerbosePreference -eq 'Continue' -or $errors.Count -le 5
                $errorsToShow = if ($showAll) { $errors } else { $errors | Select-Object -First 5 }
                foreach ($err in $errorsToShow) {
                    Write-Host "      $err" -ForegroundColor DarkRed
                }
                if (-not $showAll) {
                    Write-Host "      ... and $($errors.Count - 5) more errors (use -Verbose to show all)" -ForegroundColor DarkRed
                }
            }

        } catch {
            Write-Status "Failed to clean $Description" "Error" $_.Exception.Message
            $Stats.ErrorDirectories++
        }
    }

    # Main execution starts here
    Write-Header "CACHE CLEANING UTILITY"

    # Check privilege level
    $isElevated = Test-IsElevated
    if ($isElevated) {
        Write-Status "Running with Administrator privileges" "Success"
    } else {
        Write-Status "Running with standard user privileges" "Warning" "Some system directories may be inaccessible"
    }

    Write-Host "`nStarting cache cleanup process..." -ForegroundColor Cyan
    $startTime = Get-Date

    # Define all cache targets for progress tracking
    $CacheTargets = @(
        # System Temp Directories
        @{ Section = "SYSTEM TEMPORARY DIRECTORIES"; Path = "C:\Temp"; Description = "System Temp (C:\Temp)"; Category = "System" }
        @{ Path = "$env:SystemRoot\Temp"; Description = "Windows Temp"; Category = "System" }
        # User Temp Directories
        @{ Section = "USER TEMPORARY DIRECTORIES"; Path = "$env:TEMP"; Description = "User Temp"; Category = "User" }
        # Graphics Driver Cache - DirectX
        @{ Section = "GRAPHICS DRIVER CACHE"; Path = "$env:LOCALAPPDATA\D3DSCache"; Description = "DirectX Shader Cache"; Category = "Graphics" }
        # NVIDIA
        @{ Path = "$env:USERPROFILE\AppData\LocalLow\NVIDIA\PerDriverVersion\DXCache"; Description = "NVIDIA PerDriverVersion DXCache"; Category = "Graphics" }
        @{ Path = "$env:USERPROFILE\AppData\LocalLow\NVIDIA\DXCache"; Description = "NVIDIA LocalLow DXCache"; Category = "Graphics" }
        @{ Path = "$env:LOCALAPPDATA\NVIDIA\DXCache"; Description = "NVIDIA Local DXCache"; Category = "Graphics" }
        @{ Path = "$env:LOCALAPPDATA\NVIDIA\GLCache"; Description = "NVIDIA GLCache"; Category = "Graphics" }
        @{ Path = "$env:LOCALAPPDATA\NVIDIA Corporation\NV_Cache"; Description = "NVIDIA NV_Cache"; Category = "Graphics" }
        @{ Path = "$env:LOCALAPPDATA\NVIDIA Corporation\NvTmRep"; Description = "NVIDIA NvTmRep"; Category = "Graphics" }
        @{ Path = "$env:ProgramData\NVIDIA Corporation\NV_Cache"; Description = "NVIDIA NV_Cache (System)"; Category = "Graphics" }
        @{ Path = "$env:ProgramData\NVIDIA Corporation\NvTelemetry"; Description = "NVIDIA NvTelemetry"; Category = "Graphics" }
        # AMD
        @{ Path = "$env:LOCALAPPDATA\AMD\GLCache"; Description = "AMD GLCache"; Category = "Graphics" }
        @{ Path = "$env:LOCALAPPDATA\AMD\DxCache"; Description = "AMD DxCache"; Category = "Graphics" }
        @{ Path = "$env:LOCALAPPDATA\AMD\DxcCache"; Description = "AMD DxcCache"; Category = "Graphics" }
        @{ Path = "$env:LOCALAPPDATA\AMD\Dx9Cache"; Description = "AMD Dx9Cache"; Category = "Graphics" }
        @{ Path = "$env:LOCALAPPDATA\AMD\VkCache"; Description = "AMD VkCache"; Category = "Graphics" }
        # Intel
        @{ Path = "$env:USERPROFILE\AppData\LocalLow\Intel\ShaderCache"; Description = "Intel ShaderCache"; Category = "Graphics" }
        # Browser Cache
        @{ Section = "BROWSER CACHE"; Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"; Description = "Google Chrome Cache"; Category = "Browser" }
        @{ Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache"; Description = "Google Chrome Code Cache"; Category = "Browser" }
        @{ Path = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles\*\cache2"; Description = "Firefox Cache"; Category = "Browser" }
        @{ Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"; Description = "Microsoft Edge Cache"; Category = "Browser" }
        @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\INetCache"; Description = "Internet Explorer Cache"; Category = "Browser" }
        @{ Path = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cache"; Description = "Brave Cache"; Category = "Browser" }
        @{ Path = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Code Cache"; Description = "Brave Code Cache"; Category = "Browser" }
        # Game Launcher & Client Cache
        @{ Section = "GAME LAUNCHER CACHE"; Path = "$env:USERPROFILE\AppData\Local\Steam\htmlcache"; Description = "Steam HTML Cache"; Category = "Games" }
        @{ Path = "$env:LOCALAPPDATA\EpicGamesLauncher\Saved\webcache"; Description = "Epic Games Launcher Cache"; Category = "Games" }
        @{ Path = "$env:USERPROFILE\AppData\Roaming\Origin"; Description = "Origin Cache"; Category = "Games" }
        @{ Path = "$env:LOCALAPPDATA\Battle.net"; Description = "Battle.net Cache"; Category = "Games" }
        @{ Path = "$env:APPDATA\discord\Cache"; Description = "Discord Cache"; Category = "Communication" }
        @{ Path = "$env:APPDATA\discord\Code Cache"; Description = "Discord Code Cache"; Category = "Communication" }
        # Game-Specific Cache
        @{ Section = "GAME-SPECIFIC CACHE"; Path = "$env:USERPROFILE\AppData\Local\Larian Studios\Baldur's Gate 3\LevelCache"; Description = "Baldur's Gate 3 LevelCache"; Category = "Games" }
        @{ Path = "$env:USERPROFILE\Documents\My Games\Rocket League\TAGame\Cache"; Description = "Rocket League Cache"; Category = "Games" }
        # Development Tools Cache
        @{ Section = "DEVELOPMENT TOOLS CACHE"; Path = "$env:LOCALAPPDATA\Microsoft\VisualStudio\*\ComponentModelCache"; Description = "Visual Studio Component Cache"; Category = "Development" }
        @{ Path = "$env:APPDATA\Code\User\workspaceStorage"; Description = "VS Code Workspace Storage"; Category = "Development" }
        @{ Path = "$env:APPDATA\Code\logs"; Description = "VS Code Logs"; Category = "Development" }
        @{ Path = "$env:APPDATA\npm-cache"; Description = "NPM Cache"; Category = "Development" }
        @{ Path = "$env:LOCALAPPDATA\Yarn\Cache"; Description = "Yarn Cache"; Category = "Development" }
        @{ Path = "$env:LOCALAPPDATA\pip\Cache"; Description = "Python PIP Cache"; Category = "Development" }
        # Application Cache
        @{ Section = "APPLICATION CACHE"; Path = "$env:APPDATA\Spotify\Storage"; Description = "Spotify Cache"; Category = "Media" }
        @{ Path = "$env:LOCALAPPDATA\Spotify\Storage"; Description = "Spotify Local Storage"; Category = "Media" }
        # Package Manager Cache
        @{ Section = "PACKAGE MANAGER CACHE"; Path = "$env:USERPROFILE\scoop\cache"; Description = "Scoop Package Cache"; Category = "Development" }
        @{ Path = "$env:LOCALAPPDATA\go-build"; Description = "Go Build Cache"; Category = "Development" }
        @{ Path = "$env:LOCALAPPDATA\mise\cache"; Description = "Mise Cache"; Category = "Development" }
        # System Cache
        @{ Section = "SYSTEM CACHE"; Path = "$env:SystemRoot\Prefetch"; Description = "Windows Prefetch"; Category = "System" }
        @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db"; Description = "Windows Thumbnail Cache"; Category = "System" }
        @{ Path = "$env:SystemRoot\SoftwareDistribution\Download"; Description = "Windows Update Cache"; Category = "System" }
        @{ Path = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalCache"; Description = "Microsoft Store Cache"; Category = "System" }
    )

    $totalTargets = $CacheTargets.Count
    $currentTarget = 0

    foreach ($target in $CacheTargets) {
        $currentTarget++

        # Print section header when entering a new section
        if ($target.Section) {
            Write-Section $target.Section
        }

        # Update PowerShell progress bar
        $pct = [math]::Round(($currentTarget / $totalTargets) * 100)
        Write-Progress -Activity "Cache Cleanup" `
            -Status "[$currentTarget/$totalTargets] $($target.Description)" `
            -PercentComplete $pct `
            -CurrentOperation $target.Path

        Clear-DirectoryContents -Path $target.Path -Description "[$currentTarget/$totalTargets] $($target.Description)" -Category $target.Category
    }

    Write-Progress -Activity "Cache Cleanup" -Completed

    # Command-based cache cleanup (tools that manage their own store)
    Write-Section "COMMAND-BASED CACHE CLEANUP"
    $startCmdSize = $Stats.SpaceFreed

    if (Get-Command pnpm -ErrorAction SilentlyContinue) {
        Write-Status "Pruning pnpm store..." "Info"
        pnpm store prune 2>$null | Out-Null
        Write-Status "pnpm store pruned" "Success"
    }
    if (Get-Command mise -ErrorAction SilentlyContinue) {
        Write-Status "Clearing mise cache..." "Info"
        mise cache clear 2>$null | Out-Null
        Write-Status "mise cache cleared" "Success"
    }

    # Final Summary
    $endTime = Get-Date
    $duration = $endTime - $startTime

    Write-Header "CLEANUP SUMMARY"

    Write-Host "Execution Time: " -ForegroundColor Cyan -NoNewline
    Write-Host "$($duration.ToString('mm\:ss'))" -ForegroundColor White

    Write-Host "Total Directories Processed: " -ForegroundColor Cyan -NoNewline
    Write-Host $Stats.TotalDirectories -ForegroundColor White

    Write-Host "Successfully Cleaned: " -ForegroundColor Green -NoNewline
    Write-Host $Stats.ClearedDirectories -ForegroundColor White

    Write-Host "Skipped (Not Found): " -ForegroundColor DarkYellow -NoNewline
    Write-Host $Stats.SkippedDirectories -ForegroundColor White

    Write-Host "Errors/Warnings: " -ForegroundColor Red -NoNewline
    Write-Host $Stats.ErrorDirectories -ForegroundColor White

    Write-Host "Files Removed: " -ForegroundColor Green -NoNewline
    Write-Host $Stats.FilesRemoved -ForegroundColor White

    Write-Host "Files Skipped: " -ForegroundColor Yellow -NoNewline
    Write-Host $Stats.FilesSkipped -ForegroundColor White

    if ($Stats.SpaceFreed -gt 0) {
        Write-Host "Approximate Space Freed: " -ForegroundColor Cyan -NoNewline
        Write-Host (Format-FileSize $Stats.SpaceFreed) -ForegroundColor White
    }

    if ($Stats.FilesSkipped -gt 0 -and -not $isElevated) {
        Write-Host "`nTip: Run as Administrator to access more system files" -ForegroundColor Yellow
    }

    Write-Host "`nCache cleanup completed!" -ForegroundColor Green -BackgroundColor DarkGreen
    Write-Host "=" * 80 -ForegroundColor Cyan
}

Export-ModuleMember -Function Clear-Cache

# vim: ts=2 sts=2 sw=2 et

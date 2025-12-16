# Enhanced Cache Cleaning Function for PowerShell Profile
# Version 2.0 - Self-contained with colorized output and improved error handling
function Clear-Cache {
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
        # First try the standard check
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            return $true
        }
        # Fallback: test actual write access to a protected directory (works with sudo)
        try {
            $testPath = "$env:SystemRoot\Temp\.elevation_test_$PID"
            [System.IO.File]::Create($testPath).Dispose()
            Remove-Item $testPath -Force -ErrorAction SilentlyContinue
            return $true
        } catch {
            return $false
        }
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

            Write-Status "Cleaning $Description..." "Info"

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

            # Show detailed errors if any (but limit to avoid spam)
            if ($errors.Count -gt 0 -and $errors.Count -le 5) {
                foreach ($error in $errors) {
                    Write-Host "      $error" -ForegroundColor DarkRed
                }
            } elseif ($errors.Count -gt 5) {
                Write-Host "      ... and $($errors.Count - 5) more errors (use -Verbose for details)" -ForegroundColor DarkRed
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

    # System Temp Directories
    Write-Section "SYSTEM TEMPORARY DIRECTORIES"
    Clear-DirectoryContents -Path "C:\Temp" -Description "System Temp (C:\Temp)" -Category "System"
    Clear-DirectoryContents -Path "$env:SystemRoot\Temp" -Description "Windows Temp" -Category "System"

    # User Temp Directories
    Write-Section "USER TEMPORARY DIRECTORIES"
    Clear-DirectoryContents -Path "$env:TEMP" -Description "User Temp" -Category "User"

    # Graphics Driver Cache
    Write-Section "GRAPHICS DRIVER CACHE"
    Clear-DirectoryContents -Path "$env:USERPROFILE\AppData\LocalLow\NVIDIA\PerDriverVersion\DXCache" -Description "NVIDIA PerDriverVersion DXCache" -Category "Graphics"
    Clear-DirectoryContents -Path "$env:USERPROFILE\AppData\LocalLow\NVIDIA\DXCache" -Description "NVIDIA LocalLow DXCache" -Category "Graphics"
    Clear-DirectoryContents -Path "$env:USERPROFILE\AppData\Local\NVIDIA\DXCache" -Description "NVIDIA Local DXCache" -Category "Graphics"
    Clear-DirectoryContents -Path "$env:USERPROFILE\AppData\Local\AMD\DxCache" -Description "AMD DxCache" -Category "Graphics"
    Clear-DirectoryContents -Path "$env:USERPROFILE\AppData\Local\AMD\DxcCache" -Description "AMD DxcCache" -Category "Graphics"

    # Browser Cache
    Write-Section "BROWSER CACHE"
    Clear-DirectoryContents -Path "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache" -Description "Google Chrome Cache" -Category "Browser"
    Clear-DirectoryContents -Path "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache" -Description "Google Chrome Code Cache" -Category "Browser"
    Clear-DirectoryContents -Path "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles\*\cache2" -Description "Firefox Cache" -Category "Browser"
    Clear-DirectoryContents -Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache" -Description "Microsoft Edge Cache" -Category "Browser"
    Clear-DirectoryContents -Path "$env:LOCALAPPDATA\Microsoft\Windows\INetCache" -Description "Internet Explorer Cache" -Category "Browser"
    Clear-DirectoryContents -Path "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cache" -Description "Brave Cache" -Category "Browser"
    Clear-DirectoryContents -Path "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Code Cache" -Description "Brave Code Cache" -Category "Browser"

    # Game Launcher & Client Cache
    Write-Section "GAME LAUNCHER CACHE"
    Clear-DirectoryContents -Path "$env:USERPROFILE\AppData\Local\Steam\htmlcache" -Description "Steam HTML Cache" -Category "Games"
    Clear-DirectoryContents -Path "$env:LOCALAPPDATA\EpicGamesLauncher\Saved\webcache" -Description "Epic Games Launcher Cache" -Category "Games"
    Clear-DirectoryContents -Path "$env:USERPROFILE\AppData\Roaming\Origin" -Description "Origin Cache" -Category "Games"
    Clear-DirectoryContents -Path "$env:LOCALAPPDATA\Battle.net" -Description "Battle.net Cache" -Category "Games"
    Clear-DirectoryContents -Path "$env:APPDATA\discord\Cache" -Description "Discord Cache" -Category "Communication"
    Clear-DirectoryContents -Path "$env:APPDATA\discord\Code Cache" -Description "Discord Code Cache" -Category "Communication"

    # Game-Specific Cache
    Write-Section "GAME-SPECIFIC CACHE"
    Clear-DirectoryContents -Path "$env:USERPROFILE\AppData\Local\Larian Studios\Baldur's Gate 3\LevelCache" -Description "Baldur's Gate 3 LevelCache" -Category "Games"
    Clear-DirectoryContents -Path "$env:USERPROFILE\Documents\My Games\Rocket League\TAGame\Cache" -Description "Rocket League Cache" -Category "Games"

    # Development Tools Cache
    Write-Section "DEVELOPMENT TOOLS CACHE"
    Clear-DirectoryContents -Path "$env:LOCALAPPDATA\Microsoft\VisualStudio\*\ComponentModelCache" -Description "Visual Studio Component Cache" -Category "Development"
    Clear-DirectoryContents -Path "$env:APPDATA\Code\User\workspaceStorage" -Description "VS Code Workspace Storage" -Category "Development"
    Clear-DirectoryContents -Path "$env:APPDATA\Code\logs" -Description "VS Code Logs" -Category "Development"
    Clear-DirectoryContents -Path "$env:APPDATA\npm-cache" -Description "NPM Cache" -Category "Development"
    Clear-DirectoryContents -Path "$env:LOCALAPPDATA\Yarn\Cache" -Description "Yarn Cache" -Category "Development"
    Clear-DirectoryContents -Path "$env:LOCALAPPDATA\pip\Cache" -Description "Python PIP Cache" -Category "Development"

    # Application Cache
    Write-Section "APPLICATION CACHE"
    Clear-DirectoryContents -Path "$env:APPDATA\Spotify\Storage" -Description "Spotify Cache" -Category "Media"
    Clear-DirectoryContents -Path "$env:LOCALAPPDATA\Spotify\Storage" -Description "Spotify Local Storage" -Category "Media"

    # System Cache
    Write-Section "SYSTEM CACHE"
    Clear-DirectoryContents -Path "$env:SystemRoot\Prefetch" -Description "Windows Prefetch" -Category "System"
    Clear-DirectoryContents -Path "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Description "Windows Thumbnail Cache" -Category "System"
    Clear-DirectoryContents -Path "$env:SystemRoot\SoftwareDistribution\Download" -Description "Windows Update Cache" -Category "System"
    Clear-DirectoryContents -Path "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalCache" -Description "Microsoft Store Cache" -Category "System"

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

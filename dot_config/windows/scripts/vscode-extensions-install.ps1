#Requires -Version 5.1
<#
.SYNOPSIS
    Install VS Code extensions from extensions.txt

.DESCRIPTION
    Reads the extensions.txt file and installs each extension using the VS Code CLI.
    Skips extensions that are already installed.

.EXAMPLE
    .\extensions-install.ps1
    Install all extensions listed in extensions.txt
#>

$ErrorActionPreference = 'Stop'

$extensionsFile = Join-Path $PSScriptRoot 'extensions.txt'

if (-not (Test-Path $extensionsFile)) {
    Write-Error "extensions.txt not found at $extensionsFile"
    exit 1
}

# Check if code command is available
if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
    Write-Error "VS Code CLI 'code' not found in PATH. Please ensure VS Code is installed and 'code' is in your PATH."
    exit 1
}

# Read extensions list
$extensions = Get-Content $extensionsFile | Where-Object { $_ -and $_ -notmatch '^\s*#' }

Write-Host "Found $($extensions.Count) extensions to install" -ForegroundColor Cyan

$installed = 0
$skipped = 0
$failed = 0

foreach ($extension in $extensions) {
    $extension = $extension.Trim()
    
    if (-not $extension) {
        continue
    }
    
    Write-Host "Installing: $extension" -ForegroundColor Yellow
    
    try {
        # Check if already installed
        $existing = code --list-extensions | Where-Object { $_ -eq $extension }
        
        if ($existing) {
            Write-Host "  Already installed, skipping" -ForegroundColor Gray
            $skipped++
            continue
        }
        
        # Install extension
        code --install-extension $extension --force | Out-Null
        Write-Host "  Installed successfully" -ForegroundColor Green
        $installed++
    }
    catch {
        Write-Host "  Failed to install: $($_.Exception.Message)" -ForegroundColor Red
        $failed++
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Extension Installation Complete" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Installed: $installed" -ForegroundColor Green
Write-Host "Skipped (already installed): $skipped" -ForegroundColor Yellow
if ($failed -gt 0) {
    Write-Host "Failed: $failed" -ForegroundColor Red
}
Write-Host ""

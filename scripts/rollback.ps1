#Requires -Version 7.0
param(
    [string]$Timestamp
)

function Write-ColorOutput {
    param([string]$Message,[string]$Type = "Info")
    $symbol = switch ($Type) {
        "Success" { "✓"; $color = "Green" }
        "Warning" { "⚠"; $color = "Yellow" }
        "Error" { "✗"; $color = "Red" }
        default { "ℹ"; $color = "Cyan" }
    }
    Write-Host "$symbol " -ForegroundColor $color -NoNewline
    Write-Host $Message
}

$BackupDir = "$env:LOCALAPPDATA\chezmoi\backups"

function Get-LatestBackup {
    Get-ChildItem $BackupDir -Directory | Sort-Object CreationTime -Descending | Select-Object -First 1
}

if (-not $Timestamp) {
    Write-ColorOutput "Available backups:" -Type Info
    Get-ChildItem $BackupDir -Directory | Sort-Object CreationTime -Descending | ForEach-Object {
        Write-Host "  $($_.Name)"
        $meta = Join-Path $_.FullName 'metadata.txt'
        if (Test-Path $meta) { Get-Content $meta | ForEach-Object { "    $_" } }
        Write-Host ""
    }
    Write-ColorOutput "Usage: .\rollback.ps1 <timestamp|latest>" -Type Info
    exit 0
}

if ($Timestamp -eq 'latest') {
    $latest = Get-LatestBackup
    if (-not $latest) { Write-ColorOutput "No backups found" -Type Error; exit 1 }
    $Timestamp = $latest.Name
}

$BackupPath = Join-Path $BackupDir $Timestamp
if (-not (Test-Path $BackupPath)) { Write-ColorOutput "Backup not found: $BackupPath" -Type Error; exit 1 }

Write-ColorOutput "Restoring from: $BackupPath" -Type Info
$meta = Join-Path $BackupPath 'metadata.txt'
if (Test-Path $meta) { Get-Content $meta }

Write-ColorOutput "This will overwrite current files with backup contents" -Type Warning
$confirm = Read-Host "Continue? (y/N)"
if ($confirm -notin @('y','Y')) { Write-ColorOutput "Rollback cancelled" -Type Info; exit 0 }

Get-ChildItem $BackupPath -Recurse -File | Where-Object { $_.Name -ne 'metadata.txt' } | ForEach-Object {
    $relPath = $_.FullName.Substring($BackupPath.Length + 1)
    $target = Join-Path $env:USERPROFILE $relPath
    New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
    Copy-Item $_.FullName $target -Force
    Write-ColorOutput "Restored: $relPath" -Type Success
}

Write-ColorOutput "Rollback complete!" -Type Success
Write-ColorOutput "You may want to run: chezmoi diff" -Type Warning

# vim: ts=2 sts=2 sw=2 et

#Requires -Version 7.0
param(
    [string]$Timestamp
)

# ----------------------------------------------------------------------------
# Logging helpers
# ----------------------------------------------------------------------------
# Canonical body lives in `.chezmoitemplates/ps-logging` and is included into
# chezmoi-rendered .ps1.tmpl scripts via `{{ template "ps-logging" . }}`. We
# keep an inlined verbatim copy here because rollback.ps1 is intentionally
# self-contained (it must run even when chezmoi cannot or templates aren't
# rendered). Update both sites in lockstep.

function Get-StatusLogFile {
    [CmdletBinding()]
    param()
    $stateRoot = if ($env:XDG_STATE_HOME) { $env:XDG_STATE_HOME }
    else { Join-Path $HOME '.local\state' }
    $logDir = Join-Path $stateRoot 'dotfiles\logs'
    try {
        if (-not (Test-Path -LiteralPath $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force -ErrorAction Stop | Out-Null
        }
    } catch {
        return $null
    }
    $scriptLeaf =
        if ($PSCommandPath) { [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath) }
        elseif ($MyInvocation -and $MyInvocation.ScriptName) { [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.ScriptName) }
        else { 'rollback' }
    Join-Path $logDir ("$scriptLeaf.log")
}

function Write-Status {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')][string]$Type = 'Info',
        [string]$LogFile
    )
    $colors  = @{ Info = 'Cyan';  Success = 'Green';   Warning = 'Yellow'; Error = 'Red' }
    $symbols = @{ Info = "$([char]0x2139)"; Success = "$([char]0x2713)"; Warning = "$([char]0x26A0)"; Error = "$([char]0x2717)" }
    Write-Host "$($symbols[$Type]) " -ForegroundColor $colors[$Type] -NoNewline
    Write-Host $Message
    if (-not $LogFile) { $LogFile = Get-StatusLogFile }
    if ($LogFile) {
        $timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fff'
        try { Add-Content -LiteralPath $LogFile -Value "[$timestamp] [$Type] $Message" -ErrorAction Stop }
        catch { }
    }
}

$BackupDir = if ($env:XDG_STATE_HOME) {
    Join-Path $env:XDG_STATE_HOME 'chezmoi\backups'
} else {
    Join-Path $HOME '.local\state\chezmoi\backups'
}

function Get-LatestBackup {
    Get-ChildItem $BackupDir -Directory | Sort-Object CreationTime -Descending | Select-Object -First 1
}

if (-not $Timestamp) {
    Write-Status "Available backups:" -Type Info
    Get-ChildItem $BackupDir -Directory | Sort-Object CreationTime -Descending | ForEach-Object {
        Write-Host "  $($_.Name)"
        $meta = Join-Path $_.FullName 'metadata.txt'
        if (Test-Path $meta) { Get-Content $meta | ForEach-Object { "    $_" } }
        Write-Host ""
    }
    Write-Status "Usage: .\rollback.ps1 <timestamp|latest>" -Type Info
    exit 0
}

if ($Timestamp -eq 'latest') {
    $latest = Get-LatestBackup
    if (-not $latest) { Write-Status "No backups found" -Type Error; exit 1 }
    $Timestamp = $latest.Name
}

$BackupPath = Join-Path $BackupDir $Timestamp
if (-not (Test-Path $BackupPath)) { Write-Status "Backup not found: $BackupPath" -Type Error; exit 1 }

Write-Status "Restoring from: $BackupPath" -Type Info
$meta = Join-Path $BackupPath 'metadata.txt'
if (Test-Path $meta) { Get-Content $meta }

Write-Status "This will overwrite current files with backup contents" -Type Warning
$confirm = Read-Host "Continue? (y/N)"
if ($confirm -notin @('y','Y')) { Write-Status "Rollback cancelled" -Type Info; exit 0 }

Get-ChildItem $BackupPath -Recurse -File | Where-Object { $_.Name -ne 'metadata.txt' } | ForEach-Object {
    $relPath = $_.FullName.Substring($BackupPath.Length + 1)
    $target = Join-Path $env:USERPROFILE $relPath
    New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
    Copy-Item $_.FullName $target -Force
    Write-Status "Restored: $relPath" -Type Success
}

Write-Status "Rollback complete!" -Type Success
Write-Status "You may want to run: chezmoi diff" -Type Warning

# vim: ts=2 sts=2 sw=2 et

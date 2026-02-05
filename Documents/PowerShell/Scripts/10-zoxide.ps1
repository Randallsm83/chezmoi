# ███████╗ ██████╗ ██╗  ██╗██╗██████╗ ███████╗
# ╚══███╔╝██╔═══██╗╚██╗██╔╝██║██╔══██╗██╔════╝
#   ███╔╝ ██║   ██║ ╚███╔╝ ██║██║  ██║█████╗
#  ███╔╝  ██║   ██║ ██╔██╗ ██║██║  ██║██╔══╝
# ███████╗╚██████╔╝██╔╝ ╚██╗██║██████╔╝███████╗
# ╚══════╝ ╚═════╝ ╚═╝   ╚═╝╚═╝╚═════╝ ╚══════╝
# Smarter cd command - learns your habits
# https://github.com/ajeetdsouza/zoxide

# =============================================================================
# Zoxide Environment Configuration (XDG compliant)
# =============================================================================

# Data directory - where zoxide stores its database
$env:_ZO_DATA_DIR = "$env:XDG_DATA_HOME\zoxide"

# Ensure data directory exists
if (-not (Test-Path $env:_ZO_DATA_DIR)) {
    New-Item -ItemType Directory -Path $env:_ZO_DATA_DIR -Force | Out-Null
}

# Echo the matched directory before navigating (0 = off, 1 = on)
$env:_ZO_ECHO = "0"

# Directories to exclude from database (semicolon-separated on Windows)
$env:_ZO_EXCLUDE_DIRS = @(
    "$HOME"
    "$env:TEMP"
    "$env:TMP"
    "$HOME\AppData\Local\Temp"
    "C:\Windows"
    "C:\Windows\System32"
) -join ";"

# Maximum total age of entries in database (default: 10000)
# Higher = keep more history, Lower = more aggressive pruning
$env:_ZO_MAXAGE = "10000"

# Resolve symlinks before adding to database (0 = off, 1 = on)
$env:_ZO_RESOLVE_SYMLINKS = "0"

# =============================================================================
# Fzf Integration
# =============================================================================
# When using `zi` (interactive mode), these options customize fzf appearance

if (Get-Command fzf -ErrorAction SilentlyContinue) {
    # Inherit FZF_DEFAULT_OPTS if set, add zoxide-specific options
    $zoxideFzfOpts = @(
        "--height=40%"
        "--layout=reverse"
        "--border"
        "--info=inline"
        "--preview='if (Test-Path {2..}) { eza --color=always --icons --group-directories-first {2..} } else { Write-Host `"Directory not found`" }'"
        "--preview-window=right:50%:wrap"
    ) -join " "

    $env:_ZO_FZF_OPTS = $zoxideFzfOpts
}

# =============================================================================
# Initialization
# =============================================================================
# Note: Main profile handles basic init. This ensures env vars are set first.

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    # Initialize with 'z' and 'zi' commands
    Invoke-Expression (& zoxide init powershell | Out-String)
}

# =============================================================================
# Helper Functions
# =============================================================================

# Clean up stale entries (directories that no longer exist)
function Invoke-ZoxideClean {
    <#
    .SYNOPSIS
    Removes entries from zoxide database for directories that no longer exist.
    #>
    if (-not (Get-Command zoxide -ErrorAction SilentlyContinue)) {
        Write-Warning "zoxide is not installed"
        return
    }

    $removed = 0
    zoxide query --list | ForEach-Object {
        if (-not (Test-Path $_)) {
            zoxide remove $_
            Write-Host "Removed: $_" -ForegroundColor Yellow
            $removed++
        }
    }

    if ($removed -eq 0) {
        Write-Host "No stale entries found." -ForegroundColor Green
    } else {
        Write-Host "`nRemoved $removed stale entries." -ForegroundColor Cyan
    }
}

# Show zoxide statistics
function Get-ZoxideStats {
    <#
    .SYNOPSIS
    Display zoxide database statistics and top directories.
    #>
    if (-not (Get-Command zoxide -ErrorAction SilentlyContinue)) {
        Write-Warning "zoxide is not installed"
        return
    }

    $dbPath = Join-Path $env:_ZO_DATA_DIR "db.zo"
    if (Test-Path $dbPath) {
        $dbSize = (Get-Item $dbPath).Length
        Write-Host "Database: $dbPath" -ForegroundColor Cyan
        Write-Host "Size: $([math]::Round($dbSize / 1KB, 2)) KB" -ForegroundColor Cyan
    }

    Write-Host "`nTop 15 directories by frecency:" -ForegroundColor Green
    zoxide query --list --score | Select-Object -First 15 | ForEach-Object {
        $parts = $_ -split '\s+', 2
        $score = $parts[0]
        $path = $parts[1]
        Write-Host ("{0,8:N1}  {1}" -f [double]$score, $path)
    }
}

# Aliases for convenience
Set-Alias -Name zclean -Value Invoke-ZoxideClean
Set-Alias -Name zstats -Value Get-ZoxideStats

# vim: ts=2 sts=2 sw=2 et

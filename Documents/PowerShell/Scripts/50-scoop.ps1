# ███████╗ ██████╗ ██████╗  ██████╗ ██████╗
# ██╔════╝██╔════╝██╔═══██╗██╔═══██╗██╔══██╗
# ███████╗██║     ██║   ██║██║   ██║██████╔╝
# ╚════██║██║     ██║   ██║██║   ██║██╔═══╝
# ███████║╚██████╗╚██████╔╝╚██████╔╝██║
# ╚══════╝ ╚═════╝ ╚═════╝ ╚═════╝ ╚═╝
# A command-line installer for Windows
# https://scoop.sh/

# =================================================================================================
# Scoop Configuration
# =================================================================================================

# Check if scoop is installed
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    return
}

# Scoop directories (XDG-like paths)
$env:SCOOP = "$env:USERPROFILE\scoop"
$env:SCOOP_GLOBAL = "C:\ProgramData\scoop"

# Scoop cache (XDG compliant)
$env:SCOOP_CACHE = "$env:XDG_CACHE_HOME\scoop"

# =================================================================================================
# Scoop build environment
# =================================================================================================
# Note: CLI tools are already in PATH via scoop shims
# This section adds lib/include paths for building native extensions

$scoopApps = "$env:SCOOP\apps"

# Helper function to add library paths
function Add-LibraryPaths {
    param([string]$LibDir)
    if (Test-Path $LibDir) {
        $env:LIB = if ($env:LIB) { "$LibDir;$env:LIB" } else { $LibDir }
        $env:CMAKE_LIBRARY_PATH = if ($env:CMAKE_LIBRARY_PATH) { "$LibDir;$env:CMAKE_LIBRARY_PATH" } else { $LibDir }
    }
}

# Helper function to add include paths
function Add-IncludePaths {
    param([string]$IncludeDir)
    if (Test-Path $IncludeDir) {
        $env:INCLUDE = if ($env:INCLUDE) { "$IncludeDir;$env:INCLUDE" } else { $IncludeDir }
        $env:CMAKE_INCLUDE_PATH = if ($env:CMAKE_INCLUDE_PATH) { "$IncludeDir;$env:CMAKE_INCLUDE_PATH" } else { $IncludeDir }
    }
}

# Helper function to setup a scoop app's environment
function Set-ScoopAppEnvironment {
    param([string]$AppName)
    
    $appCurrent = Join-Path $scoopApps "$AppName\current"
    if (-not (Test-Path $appCurrent)) { return }
    
    # Add library paths
    $libDir = Join-Path $appCurrent "lib"
    if (Test-Path $libDir) {
        Add-LibraryPaths $libDir
    }
    
    # Add include paths
    $includeDir = Join-Path $appCurrent "include"
    if (Test-Path $includeDir) {
        Add-IncludePaths $includeDir
    }
}

# =================================================================================================
# Configure scoop-installed tools
# =================================================================================================

# SQLite
Set-ScoopAppEnvironment "sqlite"

# Lua/LuaJIT/LuaRocks
Set-ScoopAppEnvironment "lua"
# lua51 removed from scoop: its env_set breaks NVIDIA App OPS Lua runtime
Set-ScoopAppEnvironment "luajit"

# Curl (if needed for native extensions)
Set-ScoopAppEnvironment "curl"

# Cygwin - provides Unix tools on Windows
$cygwinRoot = Join-Path $scoopApps "cygwin\current"
if (Test-Path $cygwinRoot) {
    # Cygwin bin is already in PATH via scoop shim, just add lib/include
    $cygwinLib = Join-Path $cygwinRoot "lib"
    $cygwinInclude = Join-Path $cygwinRoot "usr\include"
    
    if (Test-Path $cygwinLib) { Add-LibraryPaths $cygwinLib }
    if (Test-Path $cygwinInclude) { Add-IncludePaths $cygwinInclude }
}

# =================================================================================================
# CMake configuration
# =================================================================================================
if ($env:CMAKE_LIBRARY_PATH) {
    $env:CMAKE_PREFIX_PATH = if ($env:CMAKE_PREFIX_PATH) {
        "$env:CMAKE_LIBRARY_PATH;$env:CMAKE_PREFIX_PATH"
    } else {
        $env:CMAKE_LIBRARY_PATH
    }
}

# Set CMAKE_INSTALL_PREFIX to local XDG data directory
$env:CMAKE_INSTALL_PREFIX = $env:XDG_DATA_HOME

# =================================================================================================
# Scoop reparse-trust auto-repair (Windows 11 Insider workaround)
# =================================================================================================
# Recent Windows 11 Insider builds block enumeration through reparse points
# (junctions/symbolic links) whose link itself is owned by a non-admin user,
# returning "untrusted mount point" (Win32 error 448). Scoop creates per-app
# `current` junctions and per-version `persist` junctions as the user, so any
# install/update/uninstall/reset/cleanup/reinstall leaves new junctions in the
# blocked state. The wrapper below runs `scoop` and, after a mutating
# subcommand, recreates any user-owned reparse points under Administrators
# ownership via gsudo + mklink, after which they enumerate normally.
#
# Manual repair: run `Repair-ScoopReparseTrust` at any time.

$script:_scoopTrustedOwners = @(
    'BUILTIN\Administrators',
    'NT AUTHORITY\SYSTEM',
    'NT SERVICE\TrustedInstaller'
)

# Resolve the real `scoop` shim once so the wrapper below doesn't recurse
# into itself.
$script:_realScoop = $null
$_scoopResolved = Get-Command scoop -All -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandType -in 'Application','ExternalScript' } |
    Select-Object -First 1
if ($_scoopResolved) { $script:_realScoop = $_scoopResolved.Source }

# Worker script (runs elevated). Co-located in lib/.
$script:_scoopTrustWorker = Join-Path $PSScriptRoot 'lib\Repair-ScoopReparseTrust.ps1'

function Get-ScoopUntrustedReparsePoint {
    [CmdletBinding()]
    param([string]$ScoopRoot = $env:SCOOP)

    if (-not $ScoopRoot) { $ScoopRoot = Join-Path $HOME 'scoop' }
    if (-not (Test-Path -LiteralPath $ScoopRoot)) { return @() }

    $results = New-Object System.Collections.Generic.List[object]
    $queue   = New-Object System.Collections.Generic.Queue[string]
    foreach ($d in 'apps','modules') {
        $p = Join-Path $ScoopRoot $d
        if (Test-Path -LiteralPath $p) { $queue.Enqueue($p) }
    }

    while ($queue.Count -gt 0) {
        $dir = $queue.Dequeue()
        $entries = $null
        try { $entries = [IO.Directory]::EnumerateDirectories($dir) } catch { continue }
        foreach ($entry in $entries) {
            $info = $null
            try { $info = [IO.DirectoryInfo]::new($entry) } catch { continue }
            $isReparse = ($info.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
            if ($isReparse) {
                $owner = $null
                try { $owner = (Get-Acl -LiteralPath $entry -ErrorAction Stop).Owner } catch {}
                if ($owner -and $script:_scoopTrustedOwners -notcontains $owner) {
                    $gi = $null
                    try { $gi = Get-Item -LiteralPath $entry -Force -ErrorAction Stop } catch {}
                    if ($gi -and $gi.Target) {
                        $results.Add([pscustomobject]@{
                            Path     = $entry
                            LinkType = $gi.LinkType
                            Target   = $gi.Target
                            Owner    = $owner
                        }) | Out-Null
                    }
                }
                # Don't descend into reparse points (would error).
            } else {
                $queue.Enqueue($entry)
            }
        }
    }
    , $results.ToArray()
}

function Repair-ScoopReparseTrust {
    [CmdletBinding()]
    param(
        [string]$ScoopRoot = $env:SCOOP,
        [switch]$Quiet
    )

    $candidates = Get-ScoopUntrustedReparsePoint -ScoopRoot $ScoopRoot
    if (-not $candidates -or $candidates.Count -eq 0) { return }

    if (-not (Test-Path -LiteralPath $script:_scoopTrustWorker)) {
        Write-Warning "[scoop-trust] Worker script not found: $script:_scoopTrustWorker"
        return
    }

    if (-not (Get-Command gsudo -ErrorAction SilentlyContinue)) {
        Write-Warning "[scoop-trust] $($candidates.Count) untrusted Scoop reparse point(s) found, but gsudo is unavailable. Install gsudo or run 'Repair-ScoopReparseTrust' from an elevated session."
        return
    }

    if (-not $Quiet) {
        Write-Host ("[scoop-trust] Repairing {0} untrusted Scoop reparse point(s)..." -f $candidates.Count) -ForegroundColor Yellow
    }

    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("scoop-trust-{0}.json" -f [Guid]::NewGuid())
    try {
        $candidates | ConvertTo-Json -Depth 3 -Compress | Set-Content -LiteralPath $tmp -Encoding UTF8
        & gsudo --wait pwsh -NoProfile -File $script:_scoopTrustWorker -InputJson $tmp
    } finally {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }

    if (-not $Quiet) {
        Write-Host "[scoop-trust] Done." -ForegroundColor Green
    }
}

# Subcommands that mutate Scoop's reparse-point layout. Read-only commands
# (list, search, info, status, prefix, which, config, etc.) are not wrapped.
$script:_scoopMutatingSubcommands = @(
    'install','update','uninstall','reset','reinstall','cleanup','hold','unhold','bucket','import'
)

if ($script:_realScoop) {
    function scoop {
        [CmdletBinding()]
        param(
            [Parameter(ValueFromRemainingArguments = $true, Position = 0)]
            [string[]]$ScoopArgs
        )

        & $script:_realScoop @ScoopArgs
        $exit = $LASTEXITCODE

        $sub = $null
        foreach ($a in $ScoopArgs) {
            if ($a -and -not $a.StartsWith('-')) { $sub = $a; break }
        }

        if ($sub -and ($script:_scoopMutatingSubcommands -contains $sub)) {
            try { Repair-ScoopReparseTrust } catch {
                Write-Warning "[scoop-trust] Repair failed: $($_.Exception.Message)"
            }
        }

        $global:LASTEXITCODE = $exit
    }
}

# vim: ts=2 sts=2 sw=2 et

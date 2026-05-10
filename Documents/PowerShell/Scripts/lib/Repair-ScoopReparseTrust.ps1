# Shared library + dual-mode script for Scoop reparse-trust repair.
#
# Modes:
#   . <thisFile>                                # dot-source: defines functions only
#   pwsh -File <thisFile> -Repair               # full repair (auto-elevates via gsudo)
#   pwsh -File <thisFile> -InputJson <path>     # elevated worker (called by Repair-ScoopReparseTrust)
#
# Used by:
#   - Documents/PowerShell/Scripts/50-scoop.ps1 (runtime profile, dot-source)
#   - .chezmoiscripts/run_after_00_repair_scoop_shims_windows.ps1.tmpl (-Repair)
#
# Background:
#   Recent Windows 11 Insider builds reject enumeration through reparse points
#   (junctions/symlinks) whose link is owned by a non-admin user, raising Win32
#   error 448 "untrusted mount point". Scoop creates per-app `current` and
#   per-version `persist` junctions as the user, so any install/update leaves
#   them blocked. Recreating them under Administrators ownership makes them
#   trusted again.
[CmdletBinding(DefaultParameterSetName = 'Source')]
param(
    [Parameter(ParameterSetName = 'Worker', Mandatory)]
    [string]$InputJson,

    [Parameter(ParameterSetName = 'Repair', Mandatory)]
    [switch]$Repair,

    [Parameter(ParameterSetName = 'Repair')]
    [string]$ScoopRoot,

    [Parameter(ParameterSetName = 'Repair')]
    [switch]$Quiet,

    # Optional ordered list of scoop apps to re-claim shim names for after the
    # reparse-trust repair (last app wins for any shim collision). Defaults to
    # $script:ScoopShimWinnerDefault when omitted.
    [Parameter(ParameterSetName = 'Repair')]
    [string[]]$Winners
)

# Default ordered "shim winners" list. Earlier entries are reset first so later
# entries' shims win on name collisions. Tweak in chezmoi data or override via
# `Repair-ScoopReparseTrust -Winners @(...)` / `-File ... -Repair -Winners ...`.
$script:ScoopShimWinnerDefault = @(
    'cygwin'
    'gzip'
    'dd'
    'curl'
    'wget'
    'uutils-coreutils'
)

# Capture the path of THIS script so functions can self-reference it for
# elevated relaunches even when invoked from other scopes.
$script:_scoopTrustScriptPath = $PSCommandPath

$script:_scoopTrustedOwners = @(
    'BUILTIN\Administrators',
    'NT AUTHORITY\SYSTEM',
    'NT SERVICE\TrustedInstaller'
)

function Test-IsElevated {
    [CmdletBinding()]
    param()
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $pr = [Security.Principal.WindowsPrincipal]::new($id)
    return $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

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
                            Target   = @($gi.Target)[0]
                            Owner    = $owner
                        }) | Out-Null
                    }
                }
                # Don't descend into reparse points (would error on untrusted ones).
            } else {
                $queue.Enqueue($entry)
            }
        }
    }
    , $results.ToArray()
}

# Internal: takes an array of entry objects and recreates each link under the
# current (assumed-elevated) principal so it ends up Administrators-owned.
function Invoke-ScoopReparseTrustWorker {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [object[]]$Entries)

    $ok = 0
    $fail = 0

    foreach ($e in $Entries) {
        $path   = $e.Path
        $type   = $e.LinkType
        $target = @($e.Target)[0]

        try {
            if (-not $target -or -not (Test-Path -LiteralPath $target)) {
                Write-Warning "Skipping ${path}: target missing or empty."
                continue
            }
            $cur = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
            if (-not $cur) { continue }
            if (-not ($cur.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                continue
            }

            # Clear ReadOnly on the LINK itself. cmd's `attrib -R` follows the
            # reparse point and modifies the target instead; .NET SetAttributes
            # operates on the link.
            [IO.File]::SetAttributes($path, [IO.FileAttributes]::Directory)

            Remove-Item -LiteralPath $path -Force

            switch ($type) {
                'Junction'     { & cmd /c "mklink /J `"$path`" `"$target`"" | Out-Null }
                'SymbolicLink' { & cmd /c "mklink /D `"$path`" `"$target`"" | Out-Null }
                default {
                    Write-Warning "Skipping ${path}: unsupported LinkType '$type'."
                    continue
                }
            }

            if (Test-Path -LiteralPath $path) { $ok++ } else { $fail++ }
        } catch {
            $fail++
            Write-Warning "Failed ${path}: $($_.Exception.Message)"
        }
    }

    if ($fail -gt 0) {
        Write-Warning "[scoop-trust] worker: $ok succeeded, $fail failed."
    }
}

function Repair-ScoopReparseTrust {
    [CmdletBinding()]
    param(
        [string]$ScoopRoot = $env:SCOOP,
        [switch]$Quiet
    )

    $candidates = Get-ScoopUntrustedReparsePoint -ScoopRoot $ScoopRoot
    if (-not $candidates -or $candidates.Count -eq 0) { return }

    if (-not $Quiet) {
        Write-Host ("[scoop-trust] Repairing {0} untrusted Scoop reparse point(s)..." -f $candidates.Count) -ForegroundColor Yellow
    }

    if (Test-IsElevated) {
        # Already elevated — do the work directly.
        Invoke-ScoopReparseTrustWorker -Entries $candidates
    } else {
        # Elevate via gsudo and call ourselves with -InputJson.
        if (-not (Get-Command gsudo -ErrorAction SilentlyContinue)) {
            Write-Warning "[scoop-trust] gsudo not available; cannot elevate. Install gsudo or run 'Repair-ScoopReparseTrust' from an elevated session."
            return
        }
        if (-not $script:_scoopTrustScriptPath -or -not (Test-Path -LiteralPath $script:_scoopTrustScriptPath)) {
            Write-Warning "[scoop-trust] Cannot resolve own script path for elevated relaunch."
            return
        }

        $tmp = Join-Path ([IO.Path]::GetTempPath()) ("scoop-trust-{0}.json" -f [Guid]::NewGuid())
        try {
            $candidates | ConvertTo-Json -Depth 3 -Compress | Set-Content -LiteralPath $tmp -Encoding UTF8
            & gsudo --wait pwsh -NoProfile -File $script:_scoopTrustScriptPath -InputJson $tmp
        } finally {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    if (-not $Quiet) {
        Write-Host "[scoop-trust] Done." -ForegroundColor Green
    }
}

# Internal: returns the BaseNames of *.shim files in $shimsDir whose `path = ...`
# value resolves anywhere under apps\<app>\ (case-insensitive). Matching by app
# dir rather than just `current\` is necessary because some scoop manifests
# (e.g. uutils-coreutils) write the resolved version path into shim files
# instead of routing through the `current` junction.
function Get-ScoopShimsOwnedByApp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$ShimsDir,
        [Parameter(Mandatory)] [string]$AppDir
    )
    if (-not (Test-Path -LiteralPath $ShimsDir)) { return @() }
    $pattern = $AppDir.TrimEnd('\') + '\*'
    $owned = Get-ChildItem -LiteralPath $ShimsDir -Filter '*.shim' -File -ErrorAction SilentlyContinue |
        Where-Object {
            $line = (Get-Content -LiteralPath $_.FullName -ErrorAction SilentlyContinue) |
                Where-Object { $_ -match '^\s*path\s*=' } | Select-Object -First 1
            if (-not $line) { return $false }
            $val = ($line -split '=', 2)[1].Trim().Trim('"')
            $val -like $pattern
        } | Select-Object -ExpandProperty BaseName
    , @($owned)
}

# Re-asserts deterministic shim ownership for collision-prone scoop apps. Runs
# `scoop reset` for each app in order; the LAST entry in the list wins for any
# shim name it shares with an earlier entry. Skips apps that aren't installed.
#
# Idempotency: a per-app cache at
#   $env:LOCALAPPDATA\chezmoi\scoop-shim-winners.json
# records, for each successful reset, the app's `current` junction target and
# the list of *.shim BaseNames that resolved under apps\<app>\current\ at that
# moment. On subsequent calls, if the cached target matches and every cached
# shim still points at this app, the reset is skipped — which also stops
# `scoop reset` from re-creating the `current` junction user-owned and
# triggering Repair-ScoopReparseTrust on every chezmoi apply.
function Set-ScoopShimWinners {
    [CmdletBinding()]
    param(
        [string[]]$Winners = $script:ScoopShimWinnerDefault,
        [string]$ScoopRoot = $env:SCOOP,
        [switch]$Quiet
    )

    if (-not $Winners -or $Winners.Count -eq 0) { return }
    if (-not $ScoopRoot) { $ScoopRoot = Join-Path $HOME 'scoop' }
    $appsDir  = Join-Path $ScoopRoot 'apps'
    $shimsDir = Join-Path $ScoopRoot 'shims'
    if (-not (Test-Path -LiteralPath $appsDir)) { return }

    $scoopCmd = Get-Command scoop -All -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandType -in 'Application','ExternalScript' } |
        Select-Object -First 1
    if (-not $scoopCmd) {
        Write-Warning "[scoop-trust] scoop executable not on PATH; skipping shim winner reset."
        return
    }

    # ── Cache load ─────────────────────────────────────────────────────────────────
    $cacheDir  = Join-Path $env:LOCALAPPDATA 'chezmoi'
    $cacheFile = Join-Path $cacheDir 'scoop-shim-winners.json'
    if (-not (Test-Path -LiteralPath $cacheDir)) {
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
    }
    $cache = @{}
    if (Test-Path -LiteralPath $cacheFile) {
        try {
            $cache = Get-Content -LiteralPath $cacheFile -Raw | ConvertFrom-Json -AsHashtable
            if ($null -eq $cache) { $cache = @{} }
        } catch { $cache = @{} }
    }

    $applied      = New-Object System.Collections.Generic.List[string]
    $cacheChanged = $false

    foreach ($app in $Winners) {
        if (-not $app) { continue }
        $appDir = Join-Path $appsDir $app
        if (-not (Test-Path -LiteralPath $appDir)) { continue }
        $cur = Join-Path $appDir 'current'

        # Resolve the current target so the cache invalidates on app updates.
        $target = $null
        $info = Get-Item -LiteralPath $cur -Force -ErrorAction SilentlyContinue
        if ($info) { $target = @($info.Target)[0] }

        # Decide whether the cache says we can skip.
        $skip  = $false
        $entry = $cache[$app]
        if ($entry -and $entry.target -eq $target) {
            $cachedShims = @($entry.shims)
            if ($cachedShims.Count -eq 0) {
                # App produces no shims we can track; trust the target match alone.
                $skip = $true
            } else {
                $owned = Get-ScoopShimsOwnedByApp -ShimsDir $shimsDir -AppDir $appDir
                $stillWinning = $true
                foreach ($n in $cachedShims) {
                    if ($owned -notcontains $n) { $stillWinning = $false; break }
                }
                if ($stillWinning) { $skip = $true }
            }
        }

        if ($skip) {
            Write-Verbose "[scoop-trust] $app shims already winning (cache hit); skipping reset."
            continue
        }

        if (-not $Quiet) {
            Write-Host "[scoop-trust] Resetting shim ownership: $app" -ForegroundColor DarkCyan
        }
        & $scoopCmd.Source reset $app *>&1 | Out-Null
        $applied.Add($app) | Out-Null

        # Refresh the cache entry from the on-disk truth after the reset.
        $ownedAfter = Get-ScoopShimsOwnedByApp -ShimsDir $shimsDir -AppDir $appDir
        $cache[$app] = @{ target = $target; shims = @($ownedAfter) }
        $cacheChanged = $true
    }

    if ($cacheChanged) {
        try {
            $cache | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $cacheFile -Encoding UTF8
        } catch {
            Write-Warning "[scoop-trust] Failed to write cache file: $($_.Exception.Message)"
        }
    }

    if (-not $Quiet -and $applied.Count -gt 0) {
        Write-Host ("[scoop-trust] Shim winners asserted (last wins): {0}" -f ($applied -join ' → ')) -ForegroundColor Green
    }
}

# === Top-level script dispatch =====================================================
switch ($PSCmdlet.ParameterSetName) {
    'Worker' {
        if (-not (Test-Path -LiteralPath $InputJson)) {
            throw "Input JSON missing: $InputJson"
        }
        $entries = Get-Content -LiteralPath $InputJson -Raw | ConvertFrom-Json
        if ($entries -isnot [System.Collections.IEnumerable] -or $entries -is [string]) {
            $entries = @($entries)
        }
        if ($entries) {
            Invoke-ScoopReparseTrustWorker -Entries $entries
        }
    }
    'Repair' {
        Repair-ScoopReparseTrust -ScoopRoot $ScoopRoot -Quiet:$Quiet
        $winnerList = if ($PSBoundParameters.ContainsKey('Winners')) { $Winners } else { $script:ScoopShimWinnerDefault }
        Set-ScoopShimWinners -Winners $winnerList -ScoopRoot $ScoopRoot -Quiet:$Quiet
    }
    default { }   # 'Source' — only define functions, do nothing else.
}

# vim: ft=ps1 sw=4 ts=4 et

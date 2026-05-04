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

# Re-asserts deterministic shim ownership for collision-prone scoop apps. Runs
# `scoop reset` for each app in order; the LAST entry in the list wins for any
# shim name it shares with an earlier entry. Skips apps that aren't installed.
function Set-ScoopShimWinners {
    [CmdletBinding()]
    param(
        [string[]]$Winners = $script:ScoopShimWinnerDefault,
        [string]$ScoopRoot = $env:SCOOP,
        [switch]$Quiet
    )

    if (-not $Winners -or $Winners.Count -eq 0) { return }
    if (-not $ScoopRoot) { $ScoopRoot = Join-Path $HOME 'scoop' }
    $appsDir = Join-Path $ScoopRoot 'apps'
    if (-not (Test-Path -LiteralPath $appsDir)) { return }

    $scoopCmd = Get-Command scoop -All -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandType -in 'Application','ExternalScript' } |
        Select-Object -First 1
    if (-not $scoopCmd) {
        Write-Warning "[scoop-trust] scoop executable not on PATH; skipping shim winner reset."
        return
    }

    $applied = New-Object System.Collections.Generic.List[string]
    foreach ($app in $Winners) {
        if (-not $app) { continue }
        if (-not (Test-Path -LiteralPath (Join-Path $appsDir $app))) { continue }
        if (-not $Quiet) {
            Write-Host "[scoop-trust] Resetting shim ownership: $app" -ForegroundColor DarkCyan
        }
        & $scoopCmd.Source reset $app *>&1 | Out-Null
        $applied.Add($app) | Out-Null
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

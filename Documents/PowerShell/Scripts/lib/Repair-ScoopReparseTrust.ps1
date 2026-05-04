# Elevated worker for Repair-ScoopReparseTrust (see ../50-scoop.ps1).
#
# Reads a JSON manifest of reparse points to recreate, clears ReadOnly on the
# link (not the target) using .NET, removes the link, and recreates it via
# `mklink` so the new link is owned by the elevated principal (Administrators)
# and therefore trusted by the Win11 Insider untrusted-mount-point check.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputJson
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $InputJson)) {
    throw "Input JSON missing: $InputJson"
}

$entries = Get-Content -LiteralPath $InputJson -Raw | ConvertFrom-Json
if (-not $entries) { return }
# ConvertFrom-Json returns a single object for one-element arrays; normalize.
if ($entries -isnot [System.Collections.IEnumerable] -or $entries -is [string]) {
    $entries = @($entries)
}

$ok = 0
$fail = 0

foreach ($e in $entries) {
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
        # reparse point and modifies the target instead; .NET's SetAttributes
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

# vim: ft=ps1 sw=4 ts=4 et

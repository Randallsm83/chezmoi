# Shared library + dual-mode script for repairing mise's recursive npm-global
# shims on Windows.
#
# Modes:
#   . <thisFile>                                # dot-source: defines functions only
#   pwsh -File <thisFile> -Repair               # full repair (runs in current user)
#   pwsh -File <thisFile> -Repair -DryRun       # report what would change
#
# Used by:
#   - Documents/PowerShell/Scripts/50-mise.ps1 (runtime profile, dot-source)
#   - .chezmoiscripts/run_after_05_repair_mise_lsp_shims_windows.ps1.tmpl (-Repair)
#
# Background:
#   mise's Windows .exe shims for npm-global tools (anything `npm install -g`'d
#   into the managed node) call `mise x -- <toolname>`. On Windows, mise's tool
#   resolution falls through to PATH and finds the shim again, producing
#   infinite recursion that spawns thousands of processes until the machine
#   chokes.
#
#   The fix replaces each affected .exe shim with a tiny .cmd wrapper that
#   bypasses `mise x` and CALLs the real npm-global .cmd in the node install
#   directory directly. The node install path is baked into the wrapper at
#   repair time so the wrapper has no runtime dependency on `mise` being on
#   PATH (important for editor/LSP launches and other non-interactive callers).
#
#   Candidates are auto-discovered by enumerating .cmd files in the current
#   `mise where node` install dir. Node-distribution tools (npm/npx/yarn/etc.)
#   are explicitly skipped via $script:MiseLspShimSkip — only LSP-class tools
#   that demonstrably recurse under `mise x` are wrapped.
#
# Re-run after:
#   - `mise reshim` / `mise install` / `mise use` (regenerates broken .exe shims)
#   - `npm install -g <pkg>` (adds new npm-global .cmd files)
#   - node version upgrade (baked path becomes stale)
#   Use the `mise-reshim` PowerShell function to do reshim + repair in one step.
#
# Idempotency:
#   - If the .cmd shim already matches the expected wrapper content (including
#     the baked node path), nothing is written.
#   - Original .exe / unix-style / .disabled shims are moved aside to .bak
#     on first run; .bak files are never overwritten on subsequent runs.
[CmdletBinding(DefaultParameterSetName = 'Source')]
param(
    [Parameter(ParameterSetName = 'Repair', Mandatory)]
    [switch]$Repair,

    [Parameter(ParameterSetName = 'Repair')]
    [switch]$DryRun,

    [Parameter(ParameterSetName = 'Repair')]
    [switch]$Quiet
)

$script:_miseRepairScriptPath = $PSCommandPath

# Tools to skip even when their .cmd shows up in node's install dir.
# Node-distribution tools (npm/npx/corepack/yarn/etc.) either work with mise's
# existing shim or have their own resolution quirks we shouldn't intervene in.
# Only wrap things that demonstrably recurse — the LSP class of tools.
$script:MiseLspShimSkip = @(
    'npm', 'npx', 'corepack',
    'yarn', 'yarnpkg',
    'pnpm', 'pnpx',
    'tsc', 'tsserver',
    'neovim-node-host',
    'perlnavigator'
)

function Get-MiseNodeInstallDir {
    [CmdletBinding()]
    param()
    $mise = Get-Command mise -ErrorAction SilentlyContinue
    if (-not $mise) { return $null }
    $out = & mise where node 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $out) { return $null }
    $dir = ($out | Select-Object -First 1).Trim()
    if (-not $dir -or -not (Test-Path -LiteralPath $dir)) { return $null }
    return $dir
}

function Get-MiseShimDir {
    [CmdletBinding()]
    param()
    $candidates = @(
        $env:MISE_DATA_DIR
        (Join-Path $env:XDG_DATA_HOME 'mise')
        (Join-Path $HOME '.local\share\mise')
    ) | Where-Object { $_ }
    foreach ($base in $candidates) {
        $shimDir = Join-Path $base 'shims'
        if (Test-Path -LiteralPath $shimDir) { return $shimDir }
    }
    return $null
}

function Get-MiseLspWrapperBody {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ToolName,
        [Parameter(Mandatory)][string]$NodeDir
    )
    # Minimal @ECHO OFF .cmd wrapper that CALLs the real npm-global .cmd file
    # at an absolute path baked in at repair time. Bypasses `mise x` (which
    # recurses) and does NOT require `mise` on PATH at runtime — so the wrapper
    # works in non-interactive contexts (editors, scheduled tasks, scripts).
    # On node version upgrade, re-run the repair lib (or `mise-reshim`) to
    # regenerate wrappers with the new install path.
    @"
@ECHO OFF
CALL "$NodeDir\$ToolName.cmd" %*
"@
}

function Repair-MiseLspShims {
    [CmdletBinding()]
    param(
        [switch]$DryRun,
        [switch]$Quiet
    )

    $shimDir = Get-MiseShimDir
    if (-not $shimDir) {
        if (-not $Quiet) { Write-Verbose '[mise-lsp] No mise shims dir found; nothing to do.' }
        return
    }

    $nodeDir = Get-MiseNodeInstallDir
    if (-not $nodeDir) {
        if (-not $Quiet) { Write-Verbose '[mise-lsp] No mise-managed node install found; nothing to do.' }
        return
    }

    $npmCmds = Get-ChildItem -LiteralPath $nodeDir -Filter '*.cmd' -File -ErrorAction SilentlyContinue
    if (-not $npmCmds) { return }

    $changed = 0
    $skipped = 0

    foreach ($npmCmd in $npmCmds) {
        $tool = [IO.Path]::GetFileNameWithoutExtension($npmCmd.Name)
        if ($script:MiseLspShimSkip -contains $tool) { continue }

        $cmdPath  = Join-Path $shimDir "$tool.cmd"
        $exePath  = Join-Path $shimDir "$tool.exe"
        $unixPath = Join-Path $shimDir $tool
        $disabled = "$exePath.disabled"

        $expected = (Get-MiseLspWrapperBody -ToolName $tool -NodeDir $nodeDir) -replace "`r`n", "`n"

        $current = $null
        if (Test-Path -LiteralPath $cmdPath) {
            $current = ([IO.File]::ReadAllText($cmdPath)) -replace "`r`n", "`n"
        }

        if ($current -eq $expected) {
            $skipped++
            continue
        }

        if ($DryRun) {
            if (-not $Quiet) { Write-Host "[mise-lsp] WOULD repair: $tool" -ForegroundColor Yellow }
            $changed++
            continue
        }

        # Move aside originals on first run only (preserve .bak across re-runs).
        foreach ($orig in @($exePath, $unixPath, $disabled)) {
            if (Test-Path -LiteralPath $orig) {
                $bak = "$orig.bak"
                if (-not (Test-Path -LiteralPath $bak)) {
                    try { Move-Item -LiteralPath $orig -Destination $bak -Force -ErrorAction Stop }
                    catch { Write-Warning "[mise-lsp] Failed to back up ${orig}: $($_.Exception.Message)" }
                } else {
                    # .bak already exists; just remove the unwanted current file.
                    try { Remove-Item -LiteralPath $orig -Force -ErrorAction Stop } catch {}
                }
            }
        }

        try {
            # ASCII, no BOM, LF — Windows .cmd interpreter handles LF fine and
            # this keeps the file diff-friendly.
            $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
            [IO.File]::WriteAllText($cmdPath, $expected, $utf8NoBom)
            $changed++
            if (-not $Quiet) { Write-Host "[mise-lsp] Repaired: $tool" -ForegroundColor Green }
        } catch {
            Write-Warning "[mise-lsp] Failed to write ${cmdPath}: $($_.Exception.Message)"
        }
    }

    if (-not $Quiet) {
        if ($DryRun) {
            Write-Host ("[mise-lsp] would repair {0} shim(s); {1} already current." -f $changed, $skipped) -ForegroundColor Cyan
        } elseif ($changed -gt 0) {
            # When chained after `mise reshim`, $skipped is always 0 because
            # mise reshim deletes our .cmd wrappers and regenerates the broken
            # .exe/unix shims it owns. The repair pass then has full work to
            # do. When called standalone (no reshim first), repeat invocations
            # report `$changed = 0` thanks to the content-match short-circuit.
            $detail = if ($skipped -eq 0) {
                'regenerated from scratch (likely after a mise reshim)'
            } else {
                "$skipped already current"
            }
            Write-Host ("[mise-lsp] Repaired {0} npm-global LSP shim(s); {1}." -f $changed, $detail) -ForegroundColor Cyan
        } elseif ($skipped -gt 0) {
            Write-Host ("[mise-lsp] All {0} npm-global LSP shim(s) already current." -f $skipped) -ForegroundColor DarkGray
        }
    }
}

# Dual-mode entry: when run as a script with -Repair, perform the work.
if ($PSCmdlet -and $PSCmdlet.ParameterSetName -eq 'Repair') {
    Repair-MiseLspShims -DryRun:$DryRun -Quiet:$Quiet
}

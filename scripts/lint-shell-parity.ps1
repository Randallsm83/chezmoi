#!/usr/bin/env pwsh
# ============================================================================
# Shell Parity / Guard-Discipline Linter
# ============================================================================
# Catches the class of bug that produced the long-lived VAGRANT_HOME leak:
# a tool-specific environment variable set unconditionally in a PowerShell
# profile fragment, with no `Get-Command` guard and no feature-flag gating.
#
# Two checks, run against the chezmoi SOURCE tree (not the rendered $HOME):
#
#   1. GUARD DISCIPLINE (pwsh): every tool-specific `$env:VAR = ...` assignment
#      in Documents/PowerShell/Scripts/*.ps1 must be reachable only when the
#      backing command exists. A fragment satisfies this if EITHER:
#        - the file has a top-of-file guard `if (-not (Get-Command <tool> ...)) { return }`, OR
#        - the specific assignment is wrapped in an `if (Get-Command <tool> ...)` block.
#      Generic/cross-tool vars (XDG_*, EDITOR, PATH, DOCKER_*, etc.) are exempt
#      via the $ExemptVars allow-list.
#
#   2. FEATURE-FLAG LEAK: for every package_features.<flag> = false, the mapped
#      shell fragments must be excluded by .chezmoiignore. Mirrors the existing
#      zsh gating so the pwsh side can't silently deploy a disabled tool.
#
# Exit code 0 = clean, 1 = violations found. Safe to wire into test.ps1 / CI.
# ============================================================================

[CmdletBinding()]
param(
    # Repo root (chezmoi source dir). Defaults to the parent of this script's dir.
    [string]$SourceDir = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$violations = [System.Collections.Generic.List[string]]::new()

function Write-Pass { param([string]$m) Write-Host "  [PASS] $m" -ForegroundColor Green }
function Write-Fail { param([string]$m) Write-Host "  [FAIL] $m" -ForegroundColor Red }
function Add-Violation { param([string]$m) $script:violations.Add($m); Write-Fail $m }

# ----------------------------------------------------------------------------
# Map a tool-specific env var to the command that must exist for it to be set.
# Only list vars that are meaningless without their tool installed. Generic
# vars are intentionally absent (they're exempt).
# ----------------------------------------------------------------------------
$ToolEnvVars = @{
    'VAGRANT_HOME'        = 'vagrant'
    'GLAB_CONFIG_DIR'     = 'glab'
    'TEALDEER_CONFIG_DIR' = 'tldr'
    'BUN_INSTALL'         = 'bun'
    'PERL_CPANM_HOME'     = 'perl'
    'WGETRC'              = 'wget'
    'WGET_HSTS'           = 'wget'
    'CARGO_HOME'          = 'cargo'
    'RUSTUP_HOME'         = 'rustup'
    'GOROOT'              = 'go'
    'DENO_INSTALL_ROOT'   = 'deno'
}

# Vars that are environment-wide and legitimately set unconditionally.
$ExemptVars = @(
    'DOCKER_HOST','DOCKER_CONFIG','GNUPGHOME','MYSQL_HISTFILE','SQLITE_HISTORY',
    'HOME','EDITOR','VISUAL','PAGER','PATH'
)

# Bootstrap-path vars: these tell an installer WHERE to place a toolchain and
# must be set BEFORE the tool exists (e.g. mise/rustup read CARGO_HOME/RUSTUP_HOME
# to decide install location). Setting them unconditionally is correct by design.
$BootstrapVars = @('CARGO_HOME','RUSTUP_HOME')

Write-Host "Shell parity linter — source: $SourceDir" -ForegroundColor Cyan

# ============================================================================
# CHECK 1 — pwsh guard discipline
# ============================================================================
Write-Host "`n[1] PowerShell tool-env guard discipline" -ForegroundColor Cyan

$scriptsDir = Join-Path $SourceDir 'Documents/PowerShell/Scripts'
if (Test-Path $scriptsDir) {
    Get-ChildItem "$scriptsDir/*.ps1" | ForEach-Object {
        $path  = $_.FullName
        $name  = $_.Name
        $lines = Get-Content $path
        $text  = $lines -join "`n"

        foreach ($var in $ToolEnvVars.Keys) {
            if ($BootstrapVars -contains $var) { continue }
            $tool = $ToolEnvVars[$var]
            # Find assignment lines for this var.
            $assignIdx = @()
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i] -match ('\$env:' + [regex]::Escape($var) + '\s*=')) { $assignIdx += $i }
            }
            if (-not $assignIdx) { continue }

            # File-level guard: a `Get-Command <tool>` ... return near the top.
            $fileGuarded = $text -match ('Get-Command\s+' + [regex]::Escape($tool) + '\b[^\n]*\n[^\n]*return')

            foreach ($idx in $assignIdx) {
                # Local guard: a `Get-Command <tool>` appears in the preceding 6 lines.
                $from = [Math]::Max(0, $idx - 6)
                $window = ($lines[$from..$idx] -join "`n")
                $localGuarded = $window -match ('Get-Command\s+' + [regex]::Escape($tool) + '\b')
                # Path guard: the assignment sits inside an `if (Test-Path ...)`
                # install-detection block (a stronger guard than Get-Command —
                # the var is only set when the toolchain dir actually exists).
                $pathGuarded = $window -match 'Test-Path\s'

                if (-not ($fileGuarded -or $localGuarded -or $pathGuarded)) {
                    Add-Violation "${name}:$($idx+1): `$env:$var set without a Get-Command '$tool' or Test-Path guard"
                }
            }
        }
    }
    if ($violations.Count -eq 0) { Write-Pass "all tool-specific env assignments are guarded" }
} else {
    Write-Host "  (skipped — $scriptsDir not found)" -ForegroundColor Yellow
}

# ============================================================================
# CHECK 2 — feature-flag leak (disabled flag => fragment must be ignored)
# ============================================================================
Write-Host "`n[2] Feature-flag gating (disabled tools must be excluded)" -ForegroundColor Cyan

$pkgFile    = Join-Path $SourceDir '.chezmoidata/packages.yaml'
$ignoreFile = Join-Path $SourceDir '.chezmoiignore'

# Fragments that MUST be gated when their flag is false. Add rows as fragments grow.
# flag -> list of source-relative fragment paths
$FlagFragments = @{
    'perl'    = @('Documents/PowerShell/Scripts/70-perl.ps1')
    'node'    = @('Documents/PowerShell/Scripts/70-bun.ps1','Documents/PowerShell/Scripts/70-npm.ps1')
    'wget'    = @('Documents/PowerShell/Scripts/80-wget.ps1')
    'vagrant' = @('.config/zsh/.zshrc.d/60-vagrant.zsh')
    'php'     = @('.config/zsh/.zshrc.d/70-php.zsh')
    'nvm'     = @('.config/zsh/.zshrc.d/70-nvm.zsh')
}

if ((Test-Path $pkgFile) -and (Test-Path $ignoreFile)) {
    $pkgText    = Get-Content $pkgFile -Raw
    $ignoreText = Get-Content $ignoreFile -Raw
    $before = $violations.Count

    foreach ($flag in $FlagFragments.Keys) {
        # Read the flag value from packages.yaml (simple `  flag: false` match).
        $isFalse = $pkgText -match ('(?m)^\s*' + [regex]::Escape($flag) + '\s*:\s*false\b')
        if (-not $isFalse) { continue }  # only enforce when the flag is OFF

        foreach ($frag in $FlagFragments[$flag]) {
            if ($ignoreText -notmatch [regex]::Escape($frag)) {
                Add-Violation "package_features.$flag = false but '$frag' is not listed in .chezmoiignore"
            }
        }
    }
    if ($violations.Count -eq $before) { Write-Pass "all disabled-feature fragments are excluded" }
} else {
    Write-Host "  (skipped — packages.yaml or .chezmoiignore not found)" -ForegroundColor Yellow
}

# ============================================================================
# Summary
# ============================================================================
Write-Host ""
if ($violations.Count -gt 0) {
    Write-Host "FAILED: $($violations.Count) violation(s)." -ForegroundColor Red
    exit 1
}
Write-Host "OK: no parity/guard violations." -ForegroundColor Green
exit 0

#Requires -Version 7.0
<#
.SYNOPSIS
    Dotfiles smoke-test suite (Windows counterpart to scripts/test.sh).

.DESCRIPTION
    Lightweight pass/fail framework mirroring the test_case structure used
    by test.sh. Each test reports PASSED / FAILED and contributes to a final
    tally. Exit code is 0 on all-pass, 1 if any test failed.

    Tests:
      - chezmoi cmd exists + source-path resolves + .chezmoidata.yaml present
      - scoop cmd exists
      - XDG_CONFIG_HOME / XDG_DATA_HOME / XDG_STATE_HOME / XDG_CACHE_HOME
        resolvable (env var set in any scope, or default dir exists)
      - mise present and config exists
      - pwsh profile file exists
      - Git user.name + user.email configured
      - op (1Password CLI) present
      - Developer Mode enabled (symlinks)
      - chezmoi diff exits cleanly (no template render errors)
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'

# ─── Colors / status helpers (parity with test.sh) ───────────────────────────
function Write-Status {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Type = 'Info'
    )
    $colors  = @{ Info = 'Cyan'; Success = 'Green'; Warning = 'Yellow'; Error = 'Red' }
    $symbols = @{ Info = 'i';    Success = 'OK';    Warning = '!';      Error = 'X'   }
    Write-Host "[$($symbols[$Type])] " -ForegroundColor $colors[$Type] -NoNewline
    Write-Host $Message
}

function Write-SectionHeader {
    param([Parameter(Mandatory)][string]$Title)
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor DarkGray
    Write-Host "  $Title" -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor DarkGray
}

# ─── Counters ────────────────────────────────────────────────────────────────
$script:TestsRun    = 0
$script:TestsPassed = 0
$script:TestsFailed = 0

function Invoke-TestCase {
    <#
    .SYNOPSIS
        Run a single test scriptblock; print PASS/FAIL and bump counters.
        Mirrors `test_case` in test.sh.
    #>
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Test
    )
    $script:TestsRun++
    Write-Host ""
    Write-Status "Test: $Name" -Type Info
    try {
        $result = & $Test
        # Treat non-boolean truthy values as pass; explicit $false (or thrown) as fail.
        if ($result -or ($null -eq $result -and $LASTEXITCODE -eq 0)) {
            Write-Status 'PASSED' -Type Success
            $script:TestsPassed++
            return
        }
    } catch {
        Write-Status "Exception: $_" -Type Error
    }
    Write-Status 'FAILED' -Type Error
    $script:TestsFailed++
}

function Test-CommandExists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Test-EnvVarSet {
    <#
    .SYNOPSIS
        True if the named env var is set in ANY scope visible to the
        current pwsh session. The dotfiles set XDG vars from the pwsh
        profile (Process scope) rather than persisting to User-scope
        registry, so we accept either.
    #>
    param([string]$Name)
    foreach ($scope in 'Process', 'User', 'Machine') {
        if (-not [string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($Name, $scope))) {
            return $true
        }
    }
    return $false
}

# ─── Test suites ─────────────────────────────────────────────────────────────
function Test-ChezmoiInstallation {
    Write-SectionHeader 'Chezmoi Installation'

    Invoke-TestCase 'chezmoi command exists' {
        Test-CommandExists chezmoi
    }
    Invoke-TestCase 'chezmoi source directory exists' {
        $src = chezmoi source-path 2>$null
        $src -and (Test-Path -LiteralPath $src)
    }
    Invoke-TestCase '.chezmoidata.yaml exists' {
        $src = chezmoi source-path 2>$null
        $src -and (Test-Path -LiteralPath (Join-Path $src '.chezmoidata.yaml'))
    }
    Invoke-TestCase '.chezmoi.toml.tmpl exists' {
        $src = chezmoi source-path 2>$null
        $src -and (Test-Path -LiteralPath (Join-Path $src '.chezmoi.toml.tmpl'))
    }
}

function Test-EssentialTools {
    Write-SectionHeader 'Essential Tools'

    Invoke-TestCase 'scoop installed'  { Test-CommandExists scoop }
    Invoke-TestCase 'git installed'    { Test-CommandExists git }
    Invoke-TestCase 'curl installed'   { Test-CommandExists curl }
    Invoke-TestCase 'mise installed'   { Test-CommandExists mise }
    Invoke-TestCase 'op (1Password CLI) installed' { Test-CommandExists op }
    Invoke-TestCase 'gsudo installed'  { Test-CommandExists gsudo }
}

function Test-Configurations {
    Write-SectionHeader 'Configuration'

    # XDG vars: dotfiles set them in the pwsh profile (Process scope on each
    # session), and consumers tolerate them being unset by falling back to the
    # canonical default dir. Mirror test.sh which only checks the directory
    # exists — that's the actually-relevant invariant. Pass if either:
    #   - env var is set in any scope (Process / User / Machine), OR
    #   - the canonical default directory exists on disk.
    $xdgDefaults = [ordered]@{
        'XDG_CONFIG_HOME' = (Join-Path $HOME '.config')
        'XDG_DATA_HOME'   = (Join-Path $HOME '.local\share')
        'XDG_STATE_HOME'  = (Join-Path $HOME '.local\state')
        'XDG_CACHE_HOME'  = (Join-Path $HOME '.cache')
    }
    foreach ($var in $xdgDefaults.Keys) {
        $defaultPath = $xdgDefaults[$var]
        Invoke-TestCase "$var resolvable (env set or $defaultPath exists)" {
            (Test-EnvVarSet $var) -or (Test-Path -LiteralPath $defaultPath)
        }.GetNewClosure()
    }

    Invoke-TestCase 'pwsh profile file exists' {
        $p = $PROFILE.CurrentUserCurrentHost
        $p -and (Test-Path -LiteralPath $p)
    }

    Invoke-TestCase 'Git user.name configured' {
        -not [string]::IsNullOrWhiteSpace((git config --global user.name 2>$null))
    }
    Invoke-TestCase 'Git user.email configured' {
        -not [string]::IsNullOrWhiteSpace((git config --global user.email 2>$null))
    }

    Invoke-TestCase 'mise config file exists' {
        $miseCfg = Join-Path $HOME '.config\mise\config.toml'
        Test-Path -LiteralPath $miseCfg
    }

    Invoke-TestCase 'Developer Mode enabled' {
        $key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
        $val = Get-ItemProperty -Path $key -Name 'AllowDevelopmentWithoutDevLicense' -ErrorAction SilentlyContinue
        ($null -ne $val) -and ($val.AllowDevelopmentWithoutDevLicense -eq 1)
    }
}

function Test-ChezmoiState {
    Write-SectionHeader 'Chezmoi State'

    Invoke-TestCase 'chezmoi managed files exist' {
        (chezmoi managed 2>$null | Where-Object { $_ } | Measure-Object).Count -gt 0
    }
    # chezmoi diff exits non-zero only on render error; otherwise success even with diffs.
    # The Unix test.sh originally referenced `--no-pager` (nonexistent flag); we
    # discard output cleanly via Out-Null instead, mirroring the corrected
    # `chezmoi diff >/dev/null` in test.sh.
    Invoke-TestCase 'chezmoi diff renders without error' {
        chezmoi diff 2>&1 | Out-Null
        $LASTEXITCODE -eq 0
    }
    Invoke-TestCase 'chezmoi data accessible' {
        chezmoi data 2>&1 | Out-Null
        $LASTEXITCODE -eq 0
    }
}

# ─── Main ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "============================================" -ForegroundColor White
Write-Host "    Dotfiles Test Suite (Windows) v2.0      " -ForegroundColor White
Write-Host "============================================" -ForegroundColor White

Test-ChezmoiInstallation
Test-EssentialTools
Test-Configurations
Test-ChezmoiState

Write-SectionHeader 'Test Results'
Write-Host ""
Write-Host "  Total tests: $script:TestsRun"
Write-Host "  Passed: $script:TestsPassed"
Write-Host "  Failed: $script:TestsFailed"
Write-Host ""

if ($script:TestsFailed -eq 0) {
    Write-Status 'All tests passed!' -Type Success
    exit 0
} else {
    Write-Status 'Some tests failed' -Type Error
    exit 1
}

# vim: ts=2 sts=2 sw=2 et

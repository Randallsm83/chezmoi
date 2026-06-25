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
    Invoke-TestCase '.chezmoidata/ directory exists with split data files' {
        # wave-d split the monolithic .chezmoidata.yaml into
        # .chezmoidata/{theme,packages,ssh,dns,fonts,mcp}.yaml so any one of
        # them being present is sufficient (chezmoi merges every *.yaml in
        # that directory into the same root data namespace at apply time).
        $src = chezmoi source-path 2>$null
        if (-not $src) { return $false }
        $dir = Join-Path $src '.chezmoidata'
        (Test-Path -LiteralPath $dir) -and ((Get-ChildItem $dir -Filter '*.yaml' -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0)
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
    Invoke-TestCase 'mpmise command available without profile' { Test-CommandExists mpmise }
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

function Test-ShellParityLint {
    Write-SectionHeader 'Shell Parity Lint'

    # Guards against the VAGRANT_HOME class of bug: unguarded tool env vars in
    # pwsh fragments and disabled-feature fragments that aren't .chezmoiignore'd.
    Invoke-TestCase 'lint-shell-parity.ps1 passes' {
        $linter = Join-Path $PSScriptRoot 'lint-shell-parity.ps1'
        if (-not (Test-Path -LiteralPath $linter)) { return $false }
        & pwsh -NoProfile -File $linter | Out-Null
        $LASTEXITCODE -eq 0
    }
}


function Test-ThemeIntegration {
    Write-SectionHeader 'Theme Integration'

    Invoke-TestCase 'OMP config renders active chezmoi theme' {
        $activeTheme = (chezmoi execute-template '{{ .theme.name }}' 2>$null | Out-String).Trim()
        $ompTheme = (chezmoi execute-template '{{ index .theme_mappings.omp .theme.name }}' 2>$null | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($activeTheme) -or [string]::IsNullOrWhiteSpace($ompTheme)) { return $false }

        $rendered = (chezmoi cat '~/.omp/agent/config.yml' 2>$null | Out-String)
        ($rendered -match '(?ms)^theme:\s+dark:\s*"?'+ [regex]::Escape($ompTheme) + '"?\s*$')
    }

    Invoke-TestCase 'OMP theme generators exist for Windows and Unix' {
        $src = chezmoi source-path 2>$null
        if (-not $src) { return $false }
        (Test-Path -LiteralPath (Join-Path $src '.chezmoiscripts\run_onchange_generate_omp_themes_windows.ps1.tmpl')) -and
            (Test-Path -LiteralPath (Join-Path $src '.chezmoiscripts\run_onchange_generate_omp_themes.sh.tmpl'))
    }

    Invoke-TestCase 'OMP theme generator renders kanagawa and spaceduck' {
        $src = chezmoi source-path 2>$null
        if (-not $src) { return $false }
        $generator = Join-Path $src '.chezmoiscripts\run_onchange_generate_omp_themes_windows.ps1.tmpl'
        if (-not (Test-Path -LiteralPath $generator)) { return $false }
        $rendered = (Get-Content -LiteralPath $generator -Raw | chezmoi execute-template 2>$null | Out-String)
        ($rendered -match 'New-OmpTheme\s+`') -and
            ($rendered -match '-Name "kanagawa"') -and
            ($rendered -match '-Name "spaceduck"')
    }

    Invoke-TestCase 'generated OMP kanagawa and spaceduck themes satisfy OMP color schema' {
        $requiredColors = @(
            'accent', 'border', 'borderAccent', 'borderMuted', 'success', 'error', 'warning', 'muted', 'dim',
            'text', 'thinkingText', 'selectedBg', 'userMessageBg', 'userMessageText', 'customMessageBg',
            'customMessageText', 'customMessageLabel', 'toolPendingBg', 'toolSuccessBg', 'toolErrorBg',
            'toolTitle', 'toolOutput', 'mdHeading', 'mdLink', 'mdLinkUrl', 'mdCode', 'mdCodeBlock',
            'mdCodeBlockBorder', 'mdQuote', 'mdQuoteBorder', 'mdHr', 'mdListBullet', 'toolDiffAdded',
            'toolDiffRemoved', 'toolDiffContext', 'syntaxComment', 'syntaxKeyword', 'syntaxFunction',
            'syntaxVariable', 'syntaxString', 'syntaxNumber', 'syntaxType', 'syntaxOperator', 'syntaxPunctuation',
            'thinkingOff', 'thinkingMinimal', 'thinkingLow', 'thinkingMedium', 'thinkingHigh', 'thinkingXhigh',
            'bashMode', 'pythonMode', 'statusLineBg', 'statusLineSep', 'statusLineModel', 'statusLinePath',
            'statusLineGitClean', 'statusLineGitDirty', 'statusLineContext', 'statusLineSpend', 'statusLineStaged',
            'statusLineDirty', 'statusLineUntracked', 'statusLineOutput', 'statusLineCost', 'statusLineSubagents'
        )

        foreach ($themeName in @('kanagawa', 'spaceduck')) {
            $themePath = Join-Path $HOME ".omp\agent\themes\$themeName.json"
            if (-not (Test-Path -LiteralPath $themePath)) { return $false }

            $themeJson = Get-Content -LiteralPath $themePath -Raw | ConvertFrom-Json -AsHashtable
            foreach ($requiredColor in $requiredColors) {
                if (-not $themeJson.colors.ContainsKey($requiredColor)) { return $false }
            }
            if ($themeJson.colors.Keys.Count -ne $requiredColors.Count) { return $false }

            foreach ($colorValue in $themeJson.colors.Values) {
                if ($colorValue -is [int] -or $colorValue -is [long]) {
                    if ($colorValue -lt 0 -or $colorValue -gt 255) { return $false }
                    continue
                }
                if ($colorValue -isnot [string]) { return $false }
                if ($colorValue -eq '' -or $colorValue.StartsWith('#')) { continue }
                if (-not $themeJson.vars.ContainsKey($colorValue)) { return $false }
            }
        }

        $true
    }
}

function Test-DnsSafety {
    Write-SectionHeader 'DNS Safety'

    Invoke-TestCase 'Windows NRPT routes do not include localhost catch-all' {
        $rendered = (chezmoi execute-template '{{ range $profile, $cfg := .vpn_dns_routes }}{{ range $cfg.domains }}{{ if and (eq . "") (eq $cfg.nameserver "127.0.0.1") }}unsafe{{ end }}{{ end }}{{ end }}' 2>$null | Out-String).Trim()
        $rendered -ne 'unsafe'
    }

    Invoke-TestCase 'unbound service.conf uses loopback recursion without root forward-zone' {
        $src = chezmoi source-path 2>$null
        if (-not $src) { return $false }
        $template = Join-Path $src 'unbound\service.conf.tmpl'
        if (-not (Test-Path -LiteralPath $template)) { return $false }
        $text = Get-Content -LiteralPath $template -Raw
        $listensOnLocalhost = $text -match '(?m)^[ \t]*interface:[ \t]+127\.0\.0\.1(?:@53)?[ \t]*(?:#.*)?$'
        $hasRootForwardZone = $text -match '(?m)^[ \t]*forward-zone:[ \t]*(?:#.*)?(?:\r?\n[ \t]+[^\r\n]*)*?\r?\n[ \t]+name:[ \t]*"\."[ \t]*(?:#.*)?$'
        $listensOnLocalhost -and -not $hasRootForwardZone
    }

    Invoke-TestCase 'local unbound resolves public DNS' {
        try {
            $result = Resolve-DnsName -Server 127.0.0.1 -Name 'cloudflare.com' -Type A -DnsOnly -QuickTimeout -ErrorAction Stop
            @($result | Where-Object { $_.Type -eq 'A' -and $_.IPAddress }).Count -gt 0
        } catch {
            $false
        }
    }

    Invoke-TestCase 'active Windows adapters use local unbound DNS' {
        $physical = Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
            Where-Object { $_.Status -eq 'Up' -and $_.InterfaceAlias -notmatch '^(Tailscale|vEthernet|Loopback)' }
        $tunnels = Get-NetAdapter -ErrorAction SilentlyContinue |
            Where-Object { $_.Status -eq 'Up' -and $_.InterfaceAlias -match '^ProtonVPN( TUN)?$' }
        $targetAdapters = @($physical) + @($tunnels)
        if ($targetAdapters.Count -eq 0) { return $false }

        foreach ($adapter in $targetAdapters) {
            $servers = @((Get-DnsClientServerAddress -InterfaceAlias $adapter.InterfaceAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses)
            if ($servers.Count -ne 1 -or $servers[0] -ne '127.0.0.1') { return $false }
        }

        $true
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
Test-ShellParityLint
Test-ThemeIntegration
Test-DnsSafety

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

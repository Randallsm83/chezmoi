# ██╗  ██╗███████╗ █████╗ ██╗  ████████╗██╗  ██╗ ██████╗██╗  ██╗
# ██║  ██║██╔════╝██╔══██╗██║  ╚══██╔══╝██║  ██║██╔════╝██║ ██╔╝
# ███████║█████╗  ███████║██║     ██║   ███████║██║     █████╔╝
# ██╔══██║██╔══╝  ██╔══██║██║     ██║   ██╔══██║██║     ██╔═██╗
# ██║  ██║███████╗██║  ██║███████╗██║   ██║  ██║╚██████╗██║  ██╗
# ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝   ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
# Auth health check — one command to verify the credential landscape:
# 1Password CLI + agent, GitHub (gh), GitLab (glab) per host, DH PAT file,
# mise secrets.env materialization. Side-effect free; opt-in network validation.

<#
.SYNOPSIS
    Reports auth health across 1Password, SSH agent, GitHub, GitLab, and the DH PAT/mise bundle.

.DESCRIPTION
    Each check prints [ok] / [warn] / [fail] with a one-line reason. Fast and read-only by
    default. Pass -Validate to also exercise network endpoints (1P agent signing, gitlab.com
    SSH handshake, DH PAT API check). Returns the result objects so it composes with pipelines.

.PARAMETER Validate
    Run network-bound checks: ssh -T git@gitlab.com, GitLab API user lookup with the DH PAT.
    Skipped by default to keep the function snappy and offline-safe.

.PARAMETER Quiet
    Suppress per-check output; only print failures + the final summary.

.PARAMETER PassThru
    Emit the result objects to the pipeline. Without this switch, the function only writes
    the colored log/summary to the host so output isn't duplicated in an interactive shell.

.EXAMPLE
    auth-health
    # Fast offline check.

.EXAMPLE
    auth-health -Validate
    # Includes network validation.

.EXAMPLE
    auth-health -PassThru -Quiet | Where-Object Status -ne 'ok'
    # Pipeline-friendly: only the not-OK results.
#>
function Test-AuthHealth {
    [CmdletBinding()]
    param(
        [switch] $Validate,
        [switch] $Quiet,
        [switch] $PassThru
    )

    $results = [System.Collections.Generic.List[object]]::new()
    $g     = $PSStyle.Foreground.BrightGreen
    $y     = $PSStyle.Foreground.BrightYellow
    $r     = $PSStyle.Foreground.BrightRed
    $d     = $PSStyle.Foreground.BrightBlack
    $reset = $PSStyle.Reset

    function _emit {
        param([string]$Name, [string]$Status, [string]$Detail)
        $results.Add([pscustomobject]@{ Name = $Name; Status = $Status; Detail = $Detail })
        if ($Quiet -and $Status -eq 'ok') { return }
        $tag = switch ($Status) {
            'ok'   { "${g}[ok]  ${reset}" }
            'warn' { "${y}[warn]${reset}" }
            'fail' { "${r}[fail]${reset}" }
        }
        Write-Host ("$tag {0,-26} $d{1}$reset" -f $Name, $Detail)
    }

    # ── 1Password CLI signed in ────────────────────────────────────────────
    if (Get-Command op -ErrorAction SilentlyContinue) {
        $u = & op whoami 2>$null
        if ($LASTEXITCODE -eq 0 -and $u) {
            $acct = ($u | Select-String 'URL|Email' | ForEach-Object { $_.Line.Trim() }) -join '; '
            if (-not $acct) { $acct = ($u -join ' ').Trim() }
            _emit '1Password CLI' 'ok' $acct
        } else {
            _emit '1Password CLI' 'fail' 'not signed in (run: op signin)'
        }
    } else {
        _emit '1Password CLI' 'warn' 'op not on PATH'
    }

    # ── 1P SSH agent pipe ──────────────────────────────────────────────────
    $pipe = '\\.\pipe\openssh-ssh-agent'
    if (Test-Path $pipe) {
        _emit '1P SSH agent pipe' 'ok' $pipe
    } else {
        _emit '1P SSH agent pipe' 'fail' "not reachable ($pipe)"
    }

    # ── Keys loaded into agent ─────────────────────────────────────────────
    if (Get-Command ssh-add -ErrorAction SilentlyContinue) {
        $keys = & ssh-add -l 2>$null
        if ($LASTEXITCODE -eq 0 -and $keys) {
            $count = ($keys | Measure-Object).Count
            _emit 'SSH agent keys' 'ok' "$count loaded"
        } else {
            _emit 'SSH agent keys' 'fail' 'agent reachable but ssh-add returned no keys'
        }
    } else {
        _emit 'SSH agent keys' 'warn' 'ssh-add not on PATH'
    }

    # ── SSH handshake to gitlab.com (network) ──────────────────────────────
    if ($Validate) {
        if (Get-Command ssh -ErrorAction SilentlyContinue) {
            $sshOut = & ssh -T -o ConnectTimeout=5 -o BatchMode=yes git@gitlab.com 2>&1
            $first  = (($sshOut | Select-Object -First 1) -as [string]).Trim()
            if ($sshOut -match 'Welcome to GitLab') {
                _emit 'ssh git@gitlab.com' 'ok' $first
            } else {
                _emit 'ssh git@gitlab.com' 'fail' $first
            }
        }
    }

    # ── GitHub via gh ──────────────────────────────────────────────────────
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        $ghOut = & gh auth status 2>&1
        if ($LASTEXITCODE -eq 0) {
            $u = ($ghOut | Select-String 'account ' | Select-Object -First 1).Line
            _emit 'gh (GitHub)' 'ok' (([string]$u).Trim())
        } else {
            _emit 'gh (GitHub)' 'fail' 'not logged in (run: gh auth login)'
        }
    } else {
        _emit 'gh (GitHub)' 'warn' 'gh not on PATH'
    }

    # ── GitLab via glab — per host ─────────────────────────────────────────
    if (Get-Command glab -ErrorAction SilentlyContinue) {
        foreach ($h in @('gitlab.com', 'git.dreamhost.com')) {
            # For dreamhost, glab needs explicit host + token from the PAT file.
            $envBackup = @{}
            $envOverride = @{}
            if ($h -eq 'git.dreamhost.com') {
                $tokFile = "$env:USERPROFILE\.config\gitlab\token"
                if (Test-Path $tokFile) {
                    $envOverride['GITLAB_TOKEN'] = (Get-Content $tokFile -Raw).Trim()
                    $envOverride['GITLAB_HOST']  = $h
                }
            }
            foreach ($k in $envOverride.Keys) {
                $envBackup[$k] = [Environment]::GetEnvironmentVariable($k, 'Process')
                [Environment]::SetEnvironmentVariable($k, $envOverride[$k], 'Process')
            }
            try {
                $glOut = & glab auth status --hostname $h 2>&1
                if ($LASTEXITCODE -eq 0) {
                    _emit "glab ($h)" 'ok' 'authenticated'
                } else {
                    $hint = if ($h -eq 'git.dreamhost.com') { 'rotate ~/.config/gitlab/token via scott/scripts/gitlab-auth.ps1' } else { 'glab auth login -h gitlab.com' }
                    _emit "glab ($h)" 'fail' $hint
                }
            } finally {
                foreach ($k in $envBackup.Keys) {
                    [Environment]::SetEnvironmentVariable($k, $envBackup[$k], 'Process')
                }
            }
        }
    } else {
        _emit 'glab (GitLab)' 'warn' 'glab not on PATH'
    }

    # ── DH GitLab PAT file ─────────────────────────────────────────────────
    $patFile = "$env:USERPROFILE\.config\gitlab\token"
    if (Test-Path $patFile) {
        $age = [int]((New-TimeSpan -Start (Get-Item $patFile).LastWriteTime -End (Get-Date)).TotalDays)
        _emit 'DH PAT file' 'ok' "${age}d old at $patFile"

        if ($Validate) {
            $tok = (Get-Content $patFile -Raw).Trim()
            try {
                $u = Invoke-RestMethod -Uri 'https://git.dreamhost.com/api/v4/user' `
                    -Headers @{ 'PRIVATE-TOKEN' = $tok } -ErrorAction Stop -TimeoutSec 8
                _emit 'DH PAT API check' 'ok' "user=$($u.username)"
            } catch {
                _emit 'DH PAT API check' 'fail' '401 / network err — rotate via scott gitlab-auth.ps1'
            }
        }
    } else {
        _emit 'DH PAT file' 'warn' "missing ($patFile)"
    }

    # ── DH secrets.env (mise _.file consumer) ──────────────────────────────
    $envFile = "$env:USERPROFILE\.config\dh\secrets.env"
    if (Test-Path $envFile) {
        $val = (Select-String -Path $envFile -Pattern '^DH_GITLAB_TOKEN=(.+)$' | Select-Object -First 1)
        if ($val -and $val.Matches[0].Groups[1].Value.Trim().Length -gt 10) {
            _emit 'mise secrets.env' 'ok' 'DH_GITLAB_TOKEN populated'
        } else {
            _emit 'mise secrets.env' 'fail' 'DH_GITLAB_TOKEN empty — chezmoi apply --init'
        }
    } else {
        _emit 'mise secrets.env' 'warn' "missing ($envFile) — chezmoi apply"
    }

    # ── Summary ────────────────────────────────────────────────────────────
    $by = $results | Group-Object Status
    $okCount   = ($by | Where-Object Name -eq 'ok'  ).Count
    $warnCount = ($by | Where-Object Name -eq 'warn').Count
    $failCount = ($by | Where-Object Name -eq 'fail').Count
    Write-Host ""
    Write-Host ("Summary: ${g}{0} ok${reset}  ${y}{1} warn${reset}  ${r}{2} fail${reset}" -f $okCount, $warnCount, $failCount)

    if ($PassThru) { return $results }
}

Set-Alias -Name auth-health -Value Test-AuthHealth -Scope Global

# vim: ts=2 sts=2 sw=2 et

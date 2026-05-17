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
    Run extra network-bound checks: ssh -T git@gitlab.com handshake.
    A quick DH-PAT-vs-API ping always runs (single request, ~200ms) because
    file existence isn't enough — a stale token on disk is the most common
    failure mode and worth catching automatically.

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

    # ── DH GitLab PAT file (validate via API by default; cheap, ~200ms) ────────
    # We do this BEFORE the glab check so we can tell the user the right fix.
    # IMPORTANT: distinguish *why* the call failed before recommending rotation —
    # a network/DNS/timeout failure is NOT evidence the token is bad, and telling
    # the user to rotate in that case sends them down the wrong path.
    #   auth (401/403)             → rotate via scott gitlab-auth.ps1
    #   network/timeout/dns/5xx    → fix connectivity (VPN, DNS, upstream); DO NOT rotate
    #   ok                         → register with glab if it's unaware
    $patFile   = "$env:USERPROFILE\.config\gitlab\token"
    $patStatus = 'missing'   # one of: ok | auth | network | upstream | other | missing
    if (Test-Path $patFile) {
        $age = [int]((New-TimeSpan -Start (Get-Item $patFile).LastWriteTime -End (Get-Date)).TotalDays)
        $tok = (Get-Content $patFile -Raw).Trim()
        try {
            $u = Invoke-RestMethod -Uri 'https://git.dreamhost.com/api/v4/user' `
                -Headers @{ 'PRIVATE-TOKEN' = $tok } -ErrorAction Stop -TimeoutSec 4
            _emit 'DH PAT file' 'ok' "${age}d old, user=$($u.username)"
            $patStatus = 'ok'
        } catch {
            $ex     = $_.Exception
            $status = $null
            if ($ex.Response -and $ex.Response.StatusCode) {
                $status = [int]$ex.Response.StatusCode
            }
            if ($status) {
                switch ($status) {
                    401     { $patStatus = 'auth';     $detail = '401 unauthorized' }
                    403     { $patStatus = 'auth';     $detail = '403 forbidden (scopes?)' }
                    default {
                        if ($status -ge 500) { $patStatus = 'upstream'; $detail = "$status upstream error" }
                        else                 { $patStatus = 'other';    $detail = "HTTP $status" }
                    }
                }
            } else {
                $inner = $ex
                while ($inner.InnerException) { $inner = $inner.InnerException }
                $msg = "$($inner.GetType().Name): $($inner.Message)"
                if     ($msg -match 'timed out|TaskCanceled|timeout')                { $patStatus = 'network'; $detail = 'request timed out' }
                elseif ($msg -match 'No such host|name or service not known|resolve'){ $patStatus = 'network'; $detail = 'DNS lookup failed for git.dreamhost.com' }
                elseif ($msg -match 'actively refused|refused|unreachable|connect') { $patStatus = 'network'; $detail = 'connection failed' }
                else                                                                { $patStatus = 'network'; $detail = $msg }
            }
            $remedy = switch ($patStatus) {
                'auth'     { 'rotate via scott/scripts/gitlab-auth.ps1' }
                'upstream' { 'GitLab upstream issue — retry later (do NOT rotate)' }
                'network'  { 'check VPN/network/DNS — do NOT rotate until reachable' }
                default    { 'investigate — do NOT rotate until verified' }
            }
            _emit 'DH PAT file' 'fail' "$detail — $remedy"
        }
    } else {
        _emit 'DH PAT file' 'warn' "missing ($patFile)"
    }

    # ── GitLab via glab — per host ──────────────────────────────────────
    # IMPORTANT: glab honors $env:GITLAB_TOKEN / $env:GITLAB_HOST regardless of
    # --hostname, so a stray DH PAT in the calling shell will silently poison
    # the gitlab.com check. We always sanitize both vars per iteration, only
    # re-injecting the DH PAT for the dreamhost host.
    if (Get-Command glab -ErrorAction SilentlyContinue) {
        $hostsToCheck = @('gitlab.com', 'git.dreamhost.com')
        $envKeys      = @('GITLAB_TOKEN', 'GITLAB_HOST')
        foreach ($h in $hostsToCheck) {
            $envBackup = @{}
            foreach ($k in $envKeys) {
                $envBackup[$k] = [Environment]::GetEnvironmentVariable($k, 'Process')
                [Environment]::SetEnvironmentVariable($k, $null, 'Process')
            }
            if ($h -eq 'git.dreamhost.com' -and (Test-Path $patFile)) {
                [Environment]::SetEnvironmentVariable('GITLAB_TOKEN', (Get-Content $patFile -Raw).Trim(), 'Process')
                [Environment]::SetEnvironmentVariable('GITLAB_HOST',  $h, 'Process')
            }
            try {
                $glOut = & glab auth status --hostname $h 2>&1
                if ($LASTEXITCODE -eq 0) {
                    _emit "glab ($h)" 'ok' 'authenticated'
                } else {
                    $hint = if ($h -eq 'git.dreamhost.com') {
                        switch ($patStatus) {
                            'ok'       { 'register existing PAT: `glab auth login -h git.dreamhost.com --token (Get-Content ~/.config/gitlab/token -Raw).Trim() --stdin`' }
                            'auth'     { 'rotate PAT first (DH PAT file check above), then re-register with glab' }
                            'network'  { 'DH GitLab unreachable (see DH PAT file check) — fix network/VPN first' }
                            'upstream' { 'DH GitLab upstream error (see DH PAT file check) — retry later' }
                            'missing'  { 'no PAT on disk — run scott/scripts/gitlab-auth.ps1, then register with glab' }
                            default    { 'see DH PAT file check above before changing anything' }
                        }
                    } else {
                        'glab auth login -h gitlab.com'
                    }
                    _emit "glab ($h)" 'fail' $hint
                }
            } finally {
                foreach ($k in $envKeys) {
                    [Environment]::SetEnvironmentVariable($k, $envBackup[$k], 'Process')
                }
            }
        }
    } else {
        _emit 'glab (GitLab)' 'warn' 'glab not on PATH'
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

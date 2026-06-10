# ██╗██████╗  █████╗ ███████╗███████╗██╗    ██╗ ██████╗ ██████╗ ██████╗
# ███║██╔══██╗██╔══██╗██╔════╝██╔════╝██║    ██║██╔═══██╗██╔══██╗██╔══██╗
# ╚██║██████╔╝███████║███████╗███████╗██║ █╗ ██║██║   ██║██████╔╝██║  ██║
#  ██║██╔═══╝ ██╔══██║╚════██║╚════██║██║███╗██║██║   ██║██╔══██╗██║  ██║
#  ██║██║     ██║  ██║███████║███████║╚███╔███╔╝╚██████╔╝██║  ██║██████╔╝
#  ╚═╝╚═╝     ╚═╝  ╚═╝╚══════╝╚══════╝ ╚══╝╚══╝  ╚═════╝ ╚═╝  ╚═╝╚═════╝
# 1Password CLI

# Check if op (1Password CLI) is available
if (-not (Get-Command op -ErrorAction SilentlyContinue)) {
    return
}

# Load 1Password CLI plugins if they exist
$opPluginsFile = "$env:XDG_CONFIG_HOME\op\plugins.sh"
if (Test-Path $opPluginsFile) {
    # Note: This would need to be a PowerShell version of the plugins
    # The .sh file is for bash/zsh, so this is just a placeholder
    # Write-Verbose "1Password plugins file found at $opPluginsFile"
}

# How long a successful whoami probe is trusted before we re-verify. The
# desktop app silently invalidates the CLI session after periods of
# inactivity (and on biometric policy changes); a permanent cache would
# leave the user staring at downstream "authorization timeout" errors
# until they opened a fresh shell. 5 minutes is short enough to recover
# from drift quickly and long enough to amortize the whoami round-trip
# across bursts of opr invocations.
$script:__OP_ENSURE_TTL = [TimeSpan]::FromMinutes(5)

# After `op signin` exits 0 the desktop app's CLI session sometimes
# isn't ready to resolve secrets yet (the handshake completes async).
# Poll whoami for up to this long before declaring failure.
$script:__OP_SETTLE_WINDOW = [TimeSpan]::FromSeconds(15)
$script:__OP_SETTLE_INTERVAL = [TimeSpan]::FromMilliseconds(500)

<#
.SYNOPSIS
    Run `op` with arguments and return a structured result capturing
    stdout, stderr, and exit code. Never throws on non-zero exit.
.DESCRIPTION
    Helper for op-probing functions that need to inspect stderr to
    classify failure modes (app not running vs not authorized vs
    timeout). PowerShell's native `&` swallows stderr unless you go
    through `2>&1`, but doing so loses the stdout/stderr distinction
    we need. Calling `op` via a System.Diagnostics.Process gives clean
    separation.
.OUTPUTS
    [pscustomobject] @{ Stdout=string; Stderr=string; ExitCode=int }
#>
function Invoke-OpRaw {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string[]] $OpArgs)

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = (Get-Command op -ErrorAction Stop).Source
    foreach ($a in $OpArgs) { [void]$psi.ArgumentList.Add($a) }
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute        = $false
    $psi.CreateNoWindow         = $true

    $proc = [System.Diagnostics.Process]::Start($psi)
    # Read both streams concurrently to avoid deadlocking when one
    # buffer fills before the child exits (rare for op, but cheap to
    # guard against).
    $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
    $stderrTask = $proc.StandardError.ReadToEndAsync()
    $proc.WaitForExit()
    [pscustomobject]@{
        Stdout   = $stdoutTask.Result
        Stderr   = $stderrTask.Result
        ExitCode = $proc.ExitCode
    }
}

<#
.SYNOPSIS
    Classify an `op` failure based on its stderr text.
.DESCRIPTION
    Returns one of: 'ok', 'not-installed', 'app-not-running',
    'not-authorized', 'vault-locked', 'authorization-timeout',
    'unknown'. Higher layers map this to actionable messages.
#>
function Get-OpFailureKind {
    [CmdletBinding()]
    param([Parameter(Mandatory)][int] $ExitCode, [string] $Stderr)

    if ($ExitCode -eq 0) { return 'ok' }
    $s = ($Stderr ?? '').ToLowerInvariant()
    if ($s -match 'cannot connect to 1password app' -or $s -match 'is the 1password app running') { return 'app-not-running' }
    if ($s -match 'authorization timeout')                                                       { return 'authorization-timeout' }
    if ($s -match 'account is not signed in' -or $s -match 'no account specified')               { return 'not-authorized' }
    if ($s -match 'vault.+locked'    -or $s -match 'unlock 1password')                           { return 'vault-locked' }
    return 'unknown'
}

<#
.SYNOPSIS
    Wait up to $script:__OP_SETTLE_WINDOW for the desktop-integration
    session to come up.
.DESCRIPTION
    Used after a successful `op signin` to ride out the brief window
    where the desktop app has accepted the authorization but hasn't
    fully wired the CLI session yet. Probes via `op vault list` rather
    than `op whoami` because, with desktop-app CLI integration enabled,
    whoami does NOT engage the auto-auth path on a cold subprocess and
    returns "account is not signed in" even when every other op command
    would succeed via biometric / Windows Hello unlock. `op vault list`
    is the cheapest no-secret call that round-trips through the
    integration's unlock path. Returns $true if the probe succeeded
    within the window, $false otherwise.
#>
function Wait-OpReady {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    $deadline = (Get-Date).Add($script:__OP_SETTLE_WINDOW)
    do {
        $r = Invoke-OpRaw -OpArgs @('vault', 'list')
        if ($r.ExitCode -eq 0) { return $true }
        Start-Sleep -Milliseconds $script:__OP_SETTLE_INTERVAL.TotalMilliseconds
    } while ((Get-Date) -lt $deadline)
    return $false
}

<#
.SYNOPSIS
    Idempotent 1Password CLI sign-in with TTL caching, settle-wait, and
    real diagnostics on failure.
.DESCRIPTION
    With the desktop-app CLI integration enabled, an unlocked vault is
    necessary but not sufficient: `op` also needs a per-binary CLI
    authorization handshake. Until that handshake exists, every `op`
    call returns "account is not signed in" even while the desktop app
    is unlocked. Running `op signin` triggers the desktop app's
    "Authorize 1Password CLI" prompt (biometric / Windows Hello).

    Improvements over the original implementation:
      - **TTL cache** ($script:__OP_ENSURE_TTL, 5 min). The original's
        process-permanent cache hid downstream failures when the
        desktop app silently invalidated the session.
      - **Settle wait**. After `op signin` exits 0, Wait-OpReady polls
        the integration-aware probe for up to 15 s, fixing the
        "succeed-but-no-session" race.
      - **Stderr-aware errors**. On failure the warning carries the
        actual op error message ("cannot connect to 1Password app",
        "authorization timeout", etc.) plus a fix hint specific to that
        failure mode.
      - **-Force**. Bypass the cache and re-verify from scratch.
        Exposed via the `op-refresh` alias.
      - **-AllowDesktopAuth**. Skip the non-interactive guard. Use this
        when stdin is closed (pam hook, MCP connector, scheduled task)
        but the desktop app's biometric / Windows Hello prompt can
        still answer for the user — the prompt is system-modal and
        does NOT consume stdin.

    Flow:
      1. Short-circuit if OP_SERVICE_ACCOUNT_TOKEN is set (headless).
      2. If cached within TTL and not -Force, return $true.
      3. Probe `op vault list`. If it exits 0, cache and return.
      4. If stdin is redirected and -AllowDesktopAuth was NOT passed,
         bail without prompting (CI / scripts that can't see a TTY
         prompt).
      5. Otherwise run `op signin`; on exit 0, Wait-OpReady; on exit
         non-zero, surface stderr + fix hint.
.PARAMETER Quiet
    Suppress the "signing in..." notice on the first sign-in of the
    session. Used by shell-startup wiring.
.PARAMETER Force
    Bypass the TTL cache and re-verify even if a recent probe succeeded.
.PARAMETER AllowDesktopAuth
    Allow the signin attempt even when stdin is redirected. Safe on
    macOS / Windows where the 1Password desktop app delivers the unlock
    prompt as a system-modal dialog rather than via stdin. The pam
    [hooks].before_resolve entry passes this so the hook can actually
    auto-authorize from a daemon spawned with stdin closed.
.OUTPUTS
    [bool] $true when op is signed in (or assumed signed in via
    OP_SERVICE_ACCOUNT_TOKEN); $false otherwise.
#>
function Invoke-OpEnsure {
    [CmdletBinding()]
    [OutputType([bool])]
    param([switch] $Quiet, [switch] $Force, [switch] $AllowDesktopAuth)

    # Service-account flow needs no interactive sign-in.
    if ($env:OP_SERVICE_ACCOUNT_TOKEN) {
        $script:__OP_ENSURED_AT = Get-Date
        return $true
    }

    if (-not (Get-Command op -ErrorAction SilentlyContinue)) {
        Write-Warning 'op CLI not on PATH; install 1Password CLI to use opr.'
        return $false
    }

    # TTL cache: a recent successful probe counts as still-signed-in.
    if (-not $Force -and $script:__OP_ENSURED_AT) {
        if ((Get-Date) - $script:__OP_ENSURED_AT -lt $script:__OP_ENSURE_TTL) {
            return $true
        }
    }

    # Cheap probe first so the common already-signed-in case stays
    # fast. `op vault list` (not `op whoami`) because on Windows /
    # macOS with desktop-app CLI integration enabled, whoami does NOT
    # engage the auto-auth path on a cold subprocess and returns
    # "account is not signed in" even when every other op command
    # would succeed via biometric / Windows Hello unlock. `vault list`
    # round-trips through the integration's unlock path on a warm
    # session and is fast; same cost as whoami but actually
    # representative of whether downstream `op read` calls will work.
    $probe = Invoke-OpRaw -OpArgs @('vault', 'list')
    if ($probe.ExitCode -eq 0) {
        $script:__OP_ENSURED_AT = Get-Date
        return $true
    }

    # Non-interactive: don't hang on a TTY prompt the caller can't
    # see. Skipped when -AllowDesktopAuth is passed because the
    # desktop app's unlock prompt is system-modal (biometric / Windows
    # Hello / Touch ID) and does not read stdin at all — a hook spawned
    # with stdin closed can still answer the prompt successfully.
    if (-not $AllowDesktopAuth -and [System.Console]::IsInputRedirected) {
        $kind = Get-OpFailureKind -ExitCode $probe.ExitCode -Stderr $probe.Stderr
        Write-Warning "op not signed in (non-interactive, kind=$kind). stderr: $($probe.Stderr.Trim())"
        return $false
    }

    # If we already know the desktop app isn't running, there's no
    # point launching signin — it would just fail the same way.
    $kind = Get-OpFailureKind -ExitCode $probe.ExitCode -Stderr $probe.Stderr
    if ($kind -eq 'app-not-running') {
        Write-Warning '1Password desktop app is not running. Launch it (and unlock) before running opr.'
        return $false
    }

    if (-not $Quiet) {
        Write-Host '1Password: authorizing CLI (approve the prompt in the desktop app)...' -ForegroundColor DarkGray
    }

    $signin = Invoke-OpRaw -OpArgs @('signin')
    if ($signin.ExitCode -eq 0 -and (Wait-OpReady)) {
        $script:__OP_ENSURED_AT = Get-Date
        return $true
    }

    $kind = Get-OpFailureKind -ExitCode $signin.ExitCode -Stderr $signin.Stderr
    $hint = switch ($kind) {
        'app-not-running'        { 'launch (and unlock) the 1Password desktop app.' }
        'authorization-timeout'  { 'approve the "Authorize 1Password CLI" prompt within the timeout next time, then re-run.' }
        'not-authorized'         { 'enable Settings -> Developer -> Integrate with 1Password CLI in the desktop app.' }
        'vault-locked'           { 'unlock the 1Password desktop app.' }
        default                  { 'check that the desktop app is running, unlocked, and has CLI integration enabled.' }
    }
    $tail = ($signin.Stderr.Trim() | Select-Object -First 1)
    if (-not $tail) { $tail = $probe.Stderr.Trim() }
    Write-Warning ("op signin failed (kind=$kind): $tail. To fix: $hint Run 'op-refresh' once corrected.")
    return $false
}
Set-Alias -Name op-ensure -Value Invoke-OpEnsure -Scope Global

<#
.SYNOPSIS
    Force a fresh 1Password CLI sign-in, bypassing the TTL cache.
.DESCRIPTION
    Wrapper for `Invoke-OpEnsure -Force`. Use this after fixing whatever
    the previous Invoke-OpEnsure warning told you was broken (desktop
    app launched, CLI integration enabled, vault unlocked, etc.) — it
    re-runs the probe + signin + settle loop without needing a fresh
    shell.
#>
function Invoke-OpRefresh { [CmdletBinding()] param() Invoke-OpEnsure -Force }
Set-Alias -Name op-refresh -Value Invoke-OpRefresh -Scope Global

<#
.SYNOPSIS
    Print a one-shot diagnostic of the current 1Password CLI state.
.DESCRIPTION
    Helpful when opr fails and you want to know why before re-running.
    Runs `op vault list` (the integration-aware probe) and reports:
    CLI installed?, signed-in state, account email if available via
    `op whoami` (best-effort, doesn't influence the signed-in
    determination), classified failure kind otherwise, the underlying
    stderr line, and the cache freshness.
#>
function Get-OpStatus {
    [CmdletBinding()]
    param()
    $opCmd = Get-Command op -ErrorAction SilentlyContinue
    if (-not $opCmd) {
        [pscustomobject]@{ State='not-installed'; OpPath=$null; Detail='op CLI not on PATH' }
        return
    }
    $r = Invoke-OpRaw -OpArgs @('vault', 'list')
    if ($r.ExitCode -eq 0) {
        $cacheAge = if ($script:__OP_ENSURED_AT) { ((Get-Date) - $script:__OP_ENSURED_AT).ToString('mm\:ss') } else { 'uncached' }
        # whoami is best-effort here: if the integration is wired but
        # whoami still fails (the cold-CLI-handshake case we work
        # around above), we still report signed-in based on the
        # vault-list result. The account field becomes empty rather
        # than blocking the diagnostic.
        $w = Invoke-OpRaw -OpArgs @('whoami')
        $acct = if ($w.ExitCode -eq 0) {
            ($w.Stdout.Trim() -split "`n" | Where-Object { $_ -match 'URL|Email' }) -join '; '
        } else { '<whoami unavailable; vault list succeeded>' }
        [pscustomobject]@{
            State    = 'signed-in'
            OpPath   = $opCmd.Source
            Account  = $acct
            CacheAge = $cacheAge
        }
        return
    }
    [pscustomobject]@{
        State  = 'not-signed-in'
        OpPath = $opCmd.Source
        Kind   = Get-OpFailureKind -ExitCode $r.ExitCode -Stderr $r.Stderr
        Detail = ($r.Stderr.Trim() -split "`n")[0]
    }
}
Set-Alias -Name op-status -Value Get-OpStatus -Scope Global

<#
.SYNOPSIS
    Run a CLI with secrets injected via `op run --env-file=~/.config/op/<tool>.env`.

.DESCRIPTION
    Generic wrapper for tools that consume credentials via env vars. The
    env-file is a list of `VAR=op://Vault/Item/field` references; `op run`
    resolves them at process spawn into the child's environment only.

    Behaviour:
      - Calls Invoke-OpEnsure first so a locked vault doesn't silently
        return placeholder values.
      - Falls back to running the tool directly (with a single warning
        on stderr) when the env file is missing, so tools without
        secret config still work.

.PARAMETER Tool
    The executable to run (e.g. 'claude', 'opencode'). The env file is
    looked up at $HOME\.config\op\$Tool.env. `.exe` is appended on
    Windows if the bare name isn't directly on PATH.

.PARAMETER Args
    Remaining arguments are passed straight through to the tool.

.EXAMPLE
    opr claude -- chat
    # Reads ~/.config/op/claude.env, resolves ANTHROPIC_API_KEY etc. from
    # 1Password, exec's `claude chat` with those env vars set.
#>
function Invoke-OpRun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $Tool,
        [Parameter(ValueFromRemainingArguments)]
        [string[]] $RemainingArgs
    )

    $envFile = Join-Path $HOME ".config/op/$Tool.env"
    # `op run` execs the wrapped command itself rather than going through
    # a shell, so it does NOT honor Windows PATHEXT. Passing the bare
    # name 'pam' fails with `cannot run executable found relative to
    # current directory` because op only finds 'pam.exe'. Resolve the
    # command to its absolute Source path (Get-Command resolves PATH +
    # PATHEXT correctly) and hand that to op so the exec is unambiguous.
    $resolved = Get-Command $Tool -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $resolved) { $resolved = Get-Command "$Tool.exe" -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1 }
    if (-not $resolved) {
        Write-Warning "opr: '$Tool' not found on PATH (and neither is '$Tool.exe')."
        return
    }
    $exe = if ($resolved.Source) { $resolved.Source } else { $resolved.Name }

    if (Test-Path $envFile) {
        # When we'd inject secrets, refuse to proceed under an unsigned
        # session — otherwise `op run` will fail with a less obvious
        # error after pam (or whatever tool) has already spawned and
        # logged its own startup noise. Surface the actionable warning
        # from Invoke-OpEnsure first so the user sees one clear cause.
        if (-not (Invoke-OpEnsure -Quiet)) {
            Write-Warning "opr: not signed in to 1Password CLI — skipping secret injection for $exe. Fix the cause above and run 'op-refresh', or run $exe directly to skip secrets entirely."
            return
        }
        & op run --env-file=$envFile --no-masking -- $exe @RemainingArgs
    } else {
        Write-Warning "opr: no env file at $envFile - running $exe without secret injection"
        & $exe @RemainingArgs
    }
}
Set-Alias -Name opr -Value Invoke-OpRun -Scope Global

# vim: ts=2 sts=2 sw=2 et

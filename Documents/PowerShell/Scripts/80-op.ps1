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

<#
.SYNOPSIS
    Idempotent 1Password CLI sign-in. Returns $true when `op` is usable
    for secret reads (whoami succeeds), $false otherwise.

.DESCRIPTION
    With the desktop-app CLI integration enabled, an unlocked vault is
    necessary but not sufficient: `op` also needs a per-binary CLI
    authorization handshake. Until that handshake exists, every `op`
    call returns "account is not signed in" even while the desktop app
    is unlocked. Running `op signin` triggers the desktop app's
    "Authorize 1Password CLI" prompt (biometric / Windows Hello), and
    on success a session is established that persists across shells.

    Flow:
      1. Short-circuit if we've already verified op in this shell.
      2. Short-circuit if OP_SERVICE_ACCOUNT_TOKEN is set (headless).
      3. Probe `op whoami`. If it exits 0, we're done.
      4. If stdin is redirected (CI, scripts), bail without prompting.
      5. Otherwise run `op signin` once and re-check via whoami.
         Stdout is discarded because integration-mode signin does not
         emit `OP_SESSION_*` exports we'd need to eval.

    Caching: once whoami succeeds in this shell, subsequent calls are
    no-ops thanks to a process-scoped $Global:__OP_ENSURED sentinel. A
    failed signin is NOT cached so a later desktop unlock + retry can
    succeed without spawning a new shell.

.PARAMETER Quiet
    Suppress the "signing in..." notice on the first sign-in of the
    session. Used by shell-startup wiring so a fresh prompt doesn't
    print chatter when the handshake is already cached.

.OUTPUTS
    [bool] $true when op is signed in (or assumed signed in via
    OP_SERVICE_ACCOUNT_TOKEN); $false otherwise.
#>
function Invoke-OpEnsure {
    [CmdletBinding()]
    [OutputType([bool])]
    param([switch] $Quiet)

    if ($Global:__OP_ENSURED) { return $true }

    # Service-account flow needs no interactive sign-in.
    if ($env:OP_SERVICE_ACCOUNT_TOKEN) {
        $Global:__OP_ENSURED = $true
        return $true
    }

    if (-not (Get-Command op -ErrorAction SilentlyContinue)) {
        return $false
    }

    # Cheap probe: op whoami exits 0 only when the desktop vault is
    # unlocked AND the CLI has an authorized session.
    $null = & op whoami 2>$null
    if ($LASTEXITCODE -eq 0) {
        $Global:__OP_ENSURED = $true
        return $true
    }

    # Stdin redirected => non-interactive context. Don't hang waiting
    # for a desktop prompt the user can't see.
    if ([System.Console]::IsInputRedirected) {
        return $false
    }

    if (-not $Quiet) {
        Write-Host '1Password: authorizing CLI (approve in desktop app)...' -ForegroundColor DarkGray
    }

    # `op signin` with desktop integration raises the "Authorize 1Password
    # CLI" prompt in the desktop app. Stdout is discarded because in
    # integration mode it's empty; in legacy mode it would be the
    # `export OP_SESSION_*=...` syntax we don't want leaking into the
    # shell. We capture the signin's own exit code immediately so we
    # don't confuse it with the prior whoami failure.
    & op signin 2>$null | Out-Null
    $signinExit = $LASTEXITCODE

    if ($signinExit -eq 0) {
        # Re-probe rather than trusting the signin exit code alone: the
        # handshake can succeed-but-yield-no-session in edge cases.
        $null = & op whoami 2>$null
        if ($LASTEXITCODE -eq 0) {
            $Global:__OP_ENSURED = $true
            return $true
        }
    }

    Write-Warning 'op signin failed; secrets-dependent commands will fail until 1Password CLI access is authorized.'
    return $false
}
Set-Alias -Name op-ensure -Value Invoke-OpEnsure -Scope Global

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
    $exe = $Tool
    if (-not (Get-Command $exe -ErrorAction SilentlyContinue) -and (Get-Command "$Tool.exe" -ErrorAction SilentlyContinue)) {
        $exe = "$Tool.exe"
    }

    if (Test-Path $envFile) {
        [void](Invoke-OpEnsure -Quiet)
        & op run --env-file=$envFile --no-masking -- $exe @RemainingArgs
    } else {
        Write-Warning "opr: no env file at $envFile - running $exe without secret injection"
        & $exe @RemainingArgs
    }
}
Set-Alias -Name opr -Value Invoke-OpRun -Scope Global

# vim: ts=2 sts=2 sw=2 et

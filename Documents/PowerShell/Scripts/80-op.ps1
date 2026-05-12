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
    Idempotent 1Password CLI sign-in. Returns $true when `op` is usable for
    secret reads (whoami succeeds), $false otherwise.

.DESCRIPTION
    Solves the recurring "agent ready but vault locked" failure where
    `ssh-add -l` enumerates keys from the 1Password SSH agent but signing
    requests fail because the vault is locked. After op-ensure succeeds,
    signing works too, because both flows depend on the same desktop-app
    unlock state.

    Caching: once op whoami succeeds in this shell, subsequent calls are
    no-ops thanks to a process-scoped $Global:__OP_ENSURED sentinel.

    Headless: if OP_SERVICE_ACCOUNT_TOKEN is set, op derives auth from it
    and needs no sign-in. We honor that by short-circuiting straight to
    success on the Pi and other non-GUI hosts.

    Non-interactive: if stdin is redirected (CI, scripts) we never prompt
    for sign-in; we just report that op isn't ready and let the caller
    decide how to fail.

.PARAMETER Quiet
    Suppress the "signing in..." notice on the first sign-in of the
    session. Useful for shell-startup wiring.

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
    # unlocked and the CLI has a session.
    $null = & op whoami 2>$null
    if ($LASTEXITCODE -eq 0) {
        $Global:__OP_ENSURED = $true
        return $true
    }

    # Stdin redirected => non-interactive context. Don't hang on a prompt.
    if ([System.Console]::IsInputRedirected) {
        return $false
    }

    if (-not $Quiet) {
        Write-Host '1Password: signing in (vault locked)...' -ForegroundColor DarkGray
    }

    # `op signin` with the desktop app integration triggers a biometric /
    # master-password prompt and finishes in ~1s on success. We don't pin
    # an account because the user has exactly one configured here; op
    # picks it automatically. The redirect to Out-Null is intentional:
    # op writes shell-export syntax to stdout when not running in a
    # `Invoke-Expression $(op signin)` pattern, and we don't need that
    # because the desktop app integration sets the session for us.
    & op signin 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $Global:__OP_ENSURED = $true
        return $true
    }

    Write-Warning 'op signin failed; secrets-dependent commands will fail until you unlock 1Password.'
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

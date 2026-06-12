# ███████╗██╗   ██╗███╗   ██╗ ██████╗████████╗██╗ ██████╗ ███╗   ██╗███████╗
# ██╔════╝██║   ██║████╗  ██║██╔════╝╚══██╔══╝██║██╔═══██╗████╗  ██║██╔════╝
# █████╗  ██║   ██║██╔██╗ ██║██║        ██║   ██║██║   ██║██╔██╗ ██║███████╗
# ██╔══╝  ██║   ██║██║╚██╗██║██║        ██║   ██║██║   ██║██║╚██╗██║╚════██║
# ██║     ╚██████╔╝██║ ╚████║╚██████╗   ██║   ██║╚██████╔╝██║ ╚████║███████║
# ╚═╝      ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝   ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝
# Lazy loader for the user's helper functions.
#
# The actual function definitions live in `lib/99-functions-body.ps1`. Parsing
# that 47KB file on every shell start cost ~240ms even when nothing was used.
# Instead we register a tiny STUB for each function name. The first time any
# stub is invoked, the full body is dot-sourced (which redefines all functions
# globally), the stub is replaced by the real one, and the call is re-issued.
# All subsequent calls hit the real function with zero overhead.
#
# Cache: a "globalized" copy of the body (function defs prefixed with `global:`)
# is generated under $XDG_CACHE_HOME so dot-sourcing from inside a function
# scope still installs the real definitions at global scope. The cache is
# regenerated when the source body file's mtime changes.

$bodyFile = Join-Path $PSScriptRoot "lib\99-functions-body.ps1"
if (-not (Test-Path $bodyFile)) { return }

$xdgCacheHome = if ($env:XDG_CACHE_HOME) { $env:XDG_CACHE_HOME } else { Join-Path $HOME '.cache' }
$funcsCacheDir = Join-Path $xdgCacheHome "powershell"
$funcsCacheFile = Join-Path $funcsCacheDir "99-functions-global.ps1"
if (-not (Test-Path $funcsCacheDir)) {
    New-Item -ItemType Directory -Path $funcsCacheDir -Force | Out-Null
}

# Rebuild the globalized cache when the source body is newer than the cache.
$funcsRebuild = -not (Test-Path $funcsCacheFile)
if (-not $funcsRebuild) {
    if ((Get-Item $bodyFile).LastWriteTime -gt (Get-Item $funcsCacheFile).LastWriteTime) {
        $funcsRebuild = $true
    }
}

if ($funcsRebuild) {
    $bodyContent = Get-Content -Raw -Path $bodyFile -Encoding utf8
    # Inject `global:` scope qualifier on function declarations so they end up
    # in global scope even when the cache file is dot-sourced from inside the
    # stub function's local scope. Allow leading whitespace so functions
    # defined inside `if (Test-CommandExists 'X') { ... }` guard blocks (which
    # are still executed at dot-source time) also get globalized — otherwise
    # they remain scoped to the guard block and vanish.
    $globalized = [regex]::Replace(
        $bodyContent,
        '(?m)^(\s*)function\s+([A-Za-z_][A-Za-z0-9_\-]*)',
        '${1}function global:$2'
    )
    Set-Content -Path $funcsCacheFile -Value $globalized -Encoding utf8
}

# Extract function names from the source body (used to create stubs).
# Match optionally-indented declarations to pick up conditionally-defined
# functions inside `if (...) { function foo { ... } }` blocks.
$funcNames = @(
    Select-String -Path $bodyFile -Pattern '^\s*function\s+([A-Za-z_][A-Za-z0-9_\-]*)' |
        ForEach-Object { $_.Matches[0].Groups[1].Value } |
        Sort-Object -Unique
)

# When uutils-coreutils is active, it owns these as executables.
# Skip creating stubs — the body's conditional block won't redefine them,
# so the stub would call itself recursively (call-depth overflow).
if ($env:__UUTILS_COREUTILS) {
    $coreutilsOwned = @('rm', 'cp', 'mv', 'touch')
    $funcNames = $funcNames | Where-Object { $coreutilsOwned -notcontains $_ }
}

# Global guard so the body file is dot-sourced at most once per session, even
# if two stubs are called in quick succession or recursively.
#
# Reset the flag when the body cache was just rebuilt (or the previously loaded
# cache no longer exists). Without this, a profile reload after editing the
# body file leaves $global:__99_functions_loaded=true from the OLD body, the
# newly-registered stubs skip dot-sourcing, and they call themselves
# recursively — producing a "call depth overflow" the next time the user
# invokes a function that was added in the new body.
if (-not (Get-Variable '__99_functions_loaded' -Scope Global -ErrorAction SilentlyContinue)) {
    $global:__99_functions_loaded = $false
} elseif ($funcsRebuild) {
    $global:__99_functions_loaded = $false
} elseif ($global:__99_functions_body_cache -and
          $global:__99_functions_body_cache -ne $funcsCacheFile) {
    # Cache path changed (e.g. XDG_CACHE_HOME moved); force reload.
    $global:__99_functions_loaded = $false
}
$global:__99_functions_body_cache = $funcsCacheFile

foreach ($name in $funcNames) {
    # Each stub:
    #   1. Loads the real bodies (once, guarded).
    #   2. Re-invokes itself by name with the original args. By this point the
    #      real `function global:<name>` has replaced the stub.
    $sb = [scriptblock]::Create(@"
        if (-not `$global:__99_functions_loaded) {
            `$global:__99_functions_loaded = `$true
            . `$global:__99_functions_body_cache
        }
        & $name @args
"@)
    Set-Item -Path "Function:\$name" -Value $sb -Force
}

# OMP homelab auth helpers are intentionally eager instead of lazy. They are
# used during auth/debugging sessions where the lazy cache may already be loaded
# from an older profile revision, and their startup cost is negligible.
function Get-OmpAuthHost {
    if ($env:OMP_AUTH_HOST) { return $env:OMP_AUTH_HOST }
    return 'raspi'
}

function Get-OmpGatewayPublicBaseUrl {
    if ($env:OMP_GATEWAY_PUBLIC_BASE_URL) { return $env:OMP_GATEWAY_PUBLIC_BASE_URL.TrimEnd('/') }
    return 'https://raspi.alai-altair.ts.net/v1'
}

function Get-OmpBrokerToken {
    $token = & ssh (Get-OmpAuthHost) docker exec auth-broker cat /root/.omp/auth-broker.token
    $token = ($token | Out-String).Trim()
    if (-not $token) {
        throw 'Could not read auth-broker token from the auth-broker container.'
    }
    return $token
}

function Get-OmpGatewayToken {
    $token = & ssh (Get-OmpAuthHost) docker exec auth-gateway cat /root/.omp/auth-gateway.token
    $token = ($token | Out-String).Trim()
    if (-not $token) {
        throw 'Could not read auth-gateway token from the auth-gateway container.'
    }
    return $token
}

function ompb {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    if ($Args.Count -gt 0 -and $Args[0] -eq 'check') {
        Write-Warning 'auth-broker has no check action; running auth-gateway check instead.'
        ompg check
        return
    }

    $brokerToken = Get-OmpBrokerToken
    try {
        & ssh -t (Get-OmpAuthHost) docker exec -it `
            -e OMP_AUTH_BROKER_URL=http://127.0.0.1:8765 `
            -e "OMP_AUTH_BROKER_TOKEN=$brokerToken" `
            auth-broker omp auth-broker @Args
    } finally {
        Remove-Variable brokerToken -ErrorAction SilentlyContinue
    }
}

function ompg {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    $brokerToken = Get-OmpBrokerToken
    try {
        & ssh (Get-OmpAuthHost) docker exec `
            -e "OMP_AUTH_BROKER_TOKEN=$brokerToken" `
            auth-gateway omp auth-gateway @Args
    } finally {
        Remove-Variable brokerToken -ErrorAction SilentlyContinue
    }
}

function ompb-login {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Provider
    )
    ompb login $Provider
}

function ompg-url {
    Get-OmpGatewayPublicBaseUrl
}

function ompg-models {
    $brokerToken = Get-OmpBrokerToken

    try {
        & ssh (Get-OmpAuthHost) docker exec `
            -e "OMP_AUTH_BROKER_TOKEN=$brokerToken" `
            auth-gateway omp --list-models
    } finally {
        Remove-Variable brokerToken -ErrorAction SilentlyContinue
    }
}

function ompg-api-models {
    $gatewayToken = Get-OmpGatewayToken

    try {
        $models = Invoke-RestMethod -Uri "$(Get-OmpGatewayPublicBaseUrl)/models" -Headers @{ Authorization = "Bearer $gatewayToken" } -Method Get
        $models.data | ForEach-Object { $_.id } | Sort-Object -Unique
    } finally {
        Remove-Variable gatewayToken -ErrorAction SilentlyContinue
    }
}

function omp-auth-tools {
    Write-Host "`nOMP auth helpers" -ForegroundColor Cyan
    Write-Host '  ompb <args>          run omp auth-broker in the auth-broker container'
    Write-Host '  ompb-login <id>      login provider in the auth-broker container'
    Write-Host '  ompg <args>          run omp auth-gateway in the auth-gateway container'
    Write-Host '  ompg-models          list OMP registry/provider model IDs'
    Write-Host '  ompg-api-models      list public OpenAI-compatible /v1/models IDs'
    Write-Host '  ompg-url             print the public /v1 base URL'
    Write-Host ''
    Write-Host 'Common examples' -ForegroundColor Cyan
    Write-Host '  ompb list'
    Write-Host '  ompb status'
    Write-Host '  ompb-login openai-codex'
    Write-Host '  ompg check'
    Write-Host '  ompg token'
    Write-Host '  ompg-api-models'
    Write-Host ''
    Write-Host 'Overrides' -ForegroundColor Cyan
    Write-Host '  $env:OMP_AUTH_HOST = "raspi"'
    Write-Host '  $env:OMP_GATEWAY_PUBLIC_BASE_URL = "https://raspi.alai-altair.ts.net/v1"'
    Write-Host ''
}
# Aliases for the lazy functions are declared inside lib/99-functions-body.ps1
# (one Set-Alias per function definition). When a user calls e.g. `winjunk`,
# the stub above for `winjunk` (or for `Remove-WinJunk`) fires, the body is
# dot-sourced, the alias is registered, and the next invocation resolves
# directly. Declaring the aliases here as well would just duplicate state.

# vim: ts=2 sts=2 sw=2 et


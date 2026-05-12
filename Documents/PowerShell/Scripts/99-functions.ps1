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

$funcsCacheDir = Join-Path $env:XDG_CACHE_HOME "powershell"
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
    # Inject `global:` scope qualifier on top-level function declarations so
    # they end up in global scope even when the cache file is dot-sourced
    # from inside the stub function's local scope.
    $globalized = [regex]::Replace(
        $bodyContent,
        '(?m)^function\s+([A-Za-z_][A-Za-z0-9_\-]*)',
        'function global:$1'
    )
    Set-Content -Path $funcsCacheFile -Value $globalized -Encoding utf8
}

# Extract function names from the source body (used to create stubs).
$funcNames = @(
    Select-String -Path $bodyFile -Pattern '^function\s+([A-Za-z_][A-Za-z0-9_\-]*)' |
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
if (-not (Get-Variable '__99_functions_loaded' -Scope Global -ErrorAction SilentlyContinue)) {
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

# Aliases that point at lazy functions. PowerShell allows aliases targeting
# functions that don't exist yet — they resolve on call, at which point the
# stub will load the real definitions. Setting them eagerly keeps them
# discoverable via Get-Alias / tab-completion immediately at startup.
Set-Alias -Name 16colors          -Value Show-AnsiColors16   -Scope Global -Force
Set-Alias -Name 256colors         -Value Show-AnsiColors256  -Scope Global -Force
Set-Alias -Name winjunk           -Value Remove-WinJunk      -Scope Global -Force
Set-Alias -Name cleancaches       -Value Clear-DevCaches     -Scope Global -Force
Set-Alias -Name cleantemp         -Value Clear-TempFiles     -Scope Global -Force
Set-Alias -Name flushdns          -Value Flush-DNS           -Scope Global -Force
Set-Alias -Name compactwsl        -Value Compact-WSL         -Scope Global -Force
Set-Alias -Name gitclean          -Value Clear-GitBranches   -Scope Global -Force
Set-Alias -Name cleandocker       -Value Clear-Docker        -Scope Global -Force
Set-Alias -Name rebuildiconcache  -Value Rebuild-WinCache    -Scope Global -Force
Set-Alias -Name fix-scoop         -Value Repair-ScoopJunctions -Scope Global -Force
Set-Alias -Name housekeeping      -Value Invoke-Housekeeping -Scope Global -Force

# vim: ts=2 sts=2 sw=2 et

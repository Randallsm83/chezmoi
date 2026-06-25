# ███╗   ███╗██╗███████╗███████╗
# ████╗ ████║██║██╔════╝██╔════╝
# ██╔████╔██║██║███████╗█████╗
# ██║╚██╔╝██║██║╚════██║██╔══╝
# ██║ ╚═╝ ██║██║███████║███████╗
# ╚═╝     ╚═╝╚═╝╚══════╝╚══════╝
# Polyglot runtime manager
# https://mise.jdx.dev/

# =================================================================================================
# Mise Configuration
# =================================================================================================

# Mise directories (XDG compliant)
$env:MISE_DATA_DIR = "$env:XDG_DATA_HOME\mise"
$env:MISE_CACHE_DIR = "$env:XDG_CACHE_HOME\mise"
$env:MISE_CONFIG_DIR = "$env:XDG_CONFIG_HOME\mise"
$env:MISE_GLOBAL_CONFIG_FILE = "$env:XDG_CONFIG_HOME\mise\config.toml"

# Cargo and Rustup homes (used by mise for Rust installations)
$env:CARGO_HOME = "$env:XDG_DATA_HOME\cargo"
$env:RUSTUP_HOME = "$env:XDG_DATA_HOME\rustup"

# Prevent mise from auto-installing missing tools during shell activation
# (works around Windows junction detection bugs and speeds up shell startup)
$env:MISE_INSTALL_MISSING = 'false'

$miseInstalls = "$env:MISE_DATA_DIR\installs"

# =================================================================================================
# Cache files
# =================================================================================================
# Two on-disk caches store the expensive parts of mise setup so we don't have to
# walk $miseInstalls or shell out to `mise activate pwsh` on every shell start.
#   - mise-env.ps1      : prepended env-var deltas (LIB/INCLUDE/CMAKE_*/GOROOT/...)
#   - mise-activate.ps1 : raw output of `mise activate pwsh`
# Both invalidate when their relevant inputs (binary / config / installs dir) change.

$miseCacheDir       = Join-Path $env:XDG_CACHE_HOME "powershell"
$miseEnvCache       = Join-Path $miseCacheDir "mise-env.ps1"
$miseActivateCache  = Join-Path $miseCacheDir "mise-activate.ps1"
if (-not (Test-Path $miseCacheDir)) {
    New-Item -ItemType Directory -Path $miseCacheDir -Force | Out-Null
}

# =================================================================================================
# Mise-installed tools environment variables
# =================================================================================================
# These env vars are needed for building native extensions against mise-managed
# tools (python/ruby/node/go/rust/lua/luajit/bun/deno/php). Computing them means
# walking $miseInstalls, so we cache the resulting prepends in mise-env.ps1 and
# only rebuild when the installs dir mtime changes (i.e. a tool version is
# installed/uninstalled).

# Helper function to add to PATH
function Add-ToPath {
    param([string]$Path)
    if (Test-Path $Path) {
        $env:PATH = "$Path;$env:PATH"
    }
}

function Build-MiseEnvCache {
    param([string]$CachePath)

    # Snapshot vars we're about to mutate so we can diff afterwards.
    $tracked = @('LIB','INCLUDE','CMAKE_LIBRARY_PATH','CMAKE_INCLUDE_PATH','CMAKE_PREFIX_PATH','GOROOT','BUN_INSTALL','DENO_INSTALL_ROOT','PATH')
    $before = @{}
    foreach ($v in $tracked) {
        $before[$v] = [Environment]::GetEnvironmentVariable($v, 'Process')
    }

    # ---- Inline helpers that mutate the current process env vars ----
    function Add-LibraryPaths {
        param([string]$LibDir)
        if (Test-Path $LibDir) {
            $env:LIB = if ($env:LIB) { "$LibDir;$env:LIB" } else { $LibDir }
            $env:CMAKE_LIBRARY_PATH = if ($env:CMAKE_LIBRARY_PATH) { "$LibDir;$env:CMAKE_LIBRARY_PATH" } else { $LibDir }
        }
    }
    function Add-IncludePaths {
        param([string]$IncludeDir)
        if (Test-Path $IncludeDir) {
            $env:INCLUDE = if ($env:INCLUDE) { "$IncludeDir;$env:INCLUDE" } else { $IncludeDir }
            $env:CMAKE_INCLUDE_PATH = if ($env:CMAKE_INCLUDE_PATH) { "$IncludeDir;$env:CMAKE_INCLUDE_PATH" } else { $IncludeDir }
        }
    }
    function Set-ToolEnvironment {
        param([string]$ToolDir, [string]$IncludeSubDir = "include")
        if (-not (Test-Path $ToolDir)) { return }
        $libDir = Join-Path $ToolDir "lib"
        if (Test-Path $libDir) { Add-LibraryPaths $libDir }
        $includeDir = Join-Path $ToolDir $IncludeSubDir
        if (Test-Path $includeDir) { Add-IncludePaths $includeDir }
    }

    # ---- Python ----
    $pythonRoot = Join-Path $miseInstalls "python"
    if (Test-Path $pythonRoot) {
        Get-ChildItem $pythonRoot -Directory | ForEach-Object {
            $pythonDir = $_.FullName
            $pythonLib = Join-Path $pythonDir "lib"
            if (Test-Path $pythonLib) {
                Get-ChildItem $pythonLib -Directory -Filter "python*" | ForEach-Object { Add-LibraryPaths $_.FullName }
            }
            $pythonInclude = Join-Path $pythonDir "include"
            if (Test-Path $pythonInclude) {
                Get-ChildItem $pythonInclude -Directory -Filter "python*" | ForEach-Object { Add-IncludePaths $_.FullName }
            }
        }
    }
    # ---- Ruby ----
    $rubyRoot = Join-Path $miseInstalls "ruby"
    if (Test-Path $rubyRoot) {
        Get-ChildItem $rubyRoot -Directory | ForEach-Object { Set-ToolEnvironment $_.FullName }
    }
    # ---- Node ----
    $nodeRoot = Join-Path $miseInstalls "node"
    if (Test-Path $nodeRoot) {
        Get-ChildItem $nodeRoot -Directory | ForEach-Object { Set-ToolEnvironment $_.FullName -IncludeSubDir "include\node" }
    }
    # ---- Go ----
    $goRoot = Join-Path $miseInstalls "go"
    if (Test-Path $goRoot) {
        Get-ChildItem $goRoot -Directory | ForEach-Object {
            $goDir = $_.FullName
            $env:GOROOT = $goDir
            Set-ToolEnvironment $goDir
        }
    }
    # ---- Rust ----
    Add-ToPath "$env:CARGO_HOME\bin"
    $rustRoot = Join-Path $miseInstalls "rust"
    if (Test-Path $rustRoot) {
        Get-ChildItem $rustRoot -Directory | ForEach-Object {
            Add-ToPath $_.FullName
            $rustLib = Join-Path $_.FullName "lib"
            if (Test-Path $rustLib) { Add-LibraryPaths $rustLib }
        }
    }
    # ---- Lua / LuaJIT ----
    $luaRoot = Join-Path $miseInstalls "lua"
    if (Test-Path $luaRoot) {
        Get-ChildItem $luaRoot -Directory | ForEach-Object { Set-ToolEnvironment $_.FullName }
    }
    $luajitRoot = Join-Path $miseInstalls "luajit"
    if (Test-Path $luajitRoot) {
        Get-ChildItem $luajitRoot -Directory | ForEach-Object {
            $luajitDir = $_.FullName
            $luajitLib = Join-Path $luajitDir "lib"
            $luajitInclude = Join-Path $luajitDir "include\luajit-2.1"
            if (Test-Path $luajitLib) { Add-LibraryPaths $luajitLib }
            if (Test-Path $luajitInclude) { Add-IncludePaths $luajitInclude }
        }
    }
    # ---- Bun ----
    $bunRoot = Join-Path $miseInstalls "bun"
    if (Test-Path $bunRoot) {
        $latestBun = Get-ChildItem $bunRoot -Directory | Select-Object -First 1
        if ($latestBun) { $env:BUN_INSTALL = $latestBun.FullName }
    }
    # ---- Deno ----
    $denoRoot = Join-Path $miseInstalls "deno"
    if (Test-Path $denoRoot) {
        Get-ChildItem $denoRoot -Directory | ForEach-Object { $env:DENO_INSTALL_ROOT = $_.FullName }
    }
    # ---- PHP ----
    $phpRoot = Join-Path $miseInstalls "php"
    if (Test-Path $phpRoot) {
        Get-ChildItem $phpRoot -Directory | ForEach-Object { Set-ToolEnvironment $_.FullName }
    }
    # ---- CMake derived ----
    if ($env:CMAKE_LIBRARY_PATH) {
        $env:CMAKE_PREFIX_PATH = $env:CMAKE_LIBRARY_PATH
    }

    # ---- Diff snapshots and emit a self-contained .ps1 cache ----
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($v in $tracked) {
        $now = [Environment]::GetEnvironmentVariable($v, 'Process')
        if ($now -eq $before[$v]) { continue }

        if ($before[$v]) {
            # Extract the prefix that was prepended (everything before ";<old>")
            $suffix = ';' + $before[$v]
            if ($now.EndsWith($suffix)) {
                $prefix = $now.Substring(0, $now.Length - $suffix.Length)
                $escaped = $prefix -replace "'", "''"
                $lines.Add("`$env:$v = if (`$env:$v) { '$escaped;' + `$env:$v } else { '$escaped' }")
                continue
            }
            # Fallback: the var was overwritten wholesale (e.g. GOROOT). Set verbatim.
        }

        $escaped = $now -replace "'", "''"
        $lines.Add("`$env:$v = '$escaped'")
    }

    Set-Content -Path $CachePath -Value ($lines -join "`r`n") -Encoding utf8
}

# Cache invalidation: rebuild when installs dir mtime is newer than cache.
$envRebuild = -not (Test-Path $miseEnvCache)
if (-not $envRebuild -and (Test-Path $miseInstalls)) {
    if ((Get-Item $miseInstalls).LastWriteTime -gt (Get-Item $miseEnvCache).LastWriteTime) {
        $envRebuild = $true
    }
}

if ($envRebuild) {
    Write-Verbose "Rebuilding mise env cache"
    Build-MiseEnvCache -CachePath $miseEnvCache
} elseif (Test-Path $miseEnvCache) {
    . $miseEnvCache
}

# Zig - available via PATH (set CC/CXX per-project via .mise.toml or direnv)
# Note: "zig cc" can't be used as a global CC value because most build systems
# (e.g. cc-rs) expect CC to be a single executable, not a command with arguments.

# =================================================================================================
# Initialization
# =================================================================================================

# Ensure mise shims and scoop shims are resolvable even if cached activation fails.
# Placed before mise activation so activated tool paths still win over static shims.
# Final order: ~/.local/bin > activated mise tools > scoop/shims > mise/shims > system32
Add-ToPath "$env:MISE_DATA_DIR\shims"
Add-ToPath "$HOME\scoop\shims"

# `mise activate pwsh` output is cached: rebuilds when the binary or the global
# config.toml change. Saves a ~120-500ms subprocess on every shell start.
# Skip mise activate in Warp - conflicts with Warp's shell integration
if ($env:TERM_PROGRAM -ne 'WarpTerminal' -and ($miseCommand = Get-Command mise -ErrorAction SilentlyContinue)) {
    $misePath = if ($miseCommand.Source) { $miseCommand.Source } else { $miseCommand.Definition }
    $miseConfig = $env:MISE_GLOBAL_CONFIG_FILE

    $activateRebuild = -not (Test-Path $miseActivateCache)
    if (-not $activateRebuild) {
        $cacheTime = (Get-Item $miseActivateCache).LastWriteTime
        if ($misePath -and (Test-Path $misePath) -and (Get-Item $misePath).LastWriteTime -gt $cacheTime) {
            $activateRebuild = $true
        }
        if ($miseConfig -and (Test-Path $miseConfig) -and (Get-Item $miseConfig).LastWriteTime -gt $cacheTime) {
            $activateRebuild = $true
        }
    }

    if ($activateRebuild) {
        try {
            $miseActivation = (& $misePath activate pwsh 2>$null | Out-String)
            if (-not [string]::IsNullOrWhiteSpace($miseActivation)) {
                Set-Content -Path $miseActivateCache -Value $miseActivation -Encoding utf8
            }
        } catch {
            Write-Verbose "mise activation failed: $($_.Exception.Message)"
        }
    }

    if (Test-Path $miseActivateCache) {
        . $miseActivateCache
    }
}

# Ensure ~/.local/bin takes precedence over WindowsApps stubs
# (mise activate prepends tool dirs, pushing user PATH entries behind system ones)
Add-ToPath "$HOME\.local\bin"

# =================================================================================================
# Mise LSP shim repair (Windows)
# =================================================================================================
# Dot-source the repair lib so `Repair-MiseLspShims` is callable from the shell.
# Used together with the `mise-reshim` function (see 99-functions-body.ps1) to
# undo the recursive shim regeneration that `mise reshim` produces for npm
# globals. See lib/Repair-MiseLspShims.ps1 for full background.
$miseLspLib = Join-Path $HOME 'Documents\PowerShell\Scripts\lib\Repair-MiseLspShims.ps1'
if (Test-Path -LiteralPath $miseLspLib) {
    . $miseLspLib
}

# vim: ts=2 sts=2 sw=2 et

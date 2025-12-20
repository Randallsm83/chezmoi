# ███████╗ ██████╗ ██████╗  ██████╗ ██████╗
# ██╔════╝██╔════╝██╔═══██╗██╔═══██╗██╔══██╗
# ███████╗██║     ██║   ██║██║   ██║██████╔╝
# ╚════██║██║     ██║   ██║██║   ██║██╔═══╝
# ███████║╚██████╗╚██████╔╝╚██████╔╝██║
# ╚══════╝ ╚═════╝ ╚═════╝ ╚═════╝ ╚═╝
# A command-line installer for Windows
# https://scoop.sh/

# =================================================================================================
# Scoop Configuration
# =================================================================================================

# Check if scoop is installed
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    return
}

# Scoop directories (XDG-like paths)
$env:SCOOP = "$env:USERPROFILE\scoop"
$env:SCOOP_GLOBAL = "C:\ProgramData\scoop"

# Scoop cache (XDG compliant)
$env:SCOOP_CACHE = "$env:XDG_CACHE_HOME\scoop"

# =================================================================================================
# Scoop build environment
# =================================================================================================
# Note: CLI tools are already in PATH via scoop shims
# This section adds lib/include paths for building native extensions

$scoopApps = "$env:SCOOP\apps"

# Helper function to add library paths
function Add-LibraryPaths {
    param([string]$LibDir)
    if (Test-Path $LibDir) {
        $env:LIB = if ($env:LIB) { "$LibDir;$env:LIB" } else { $LibDir }
        $env:CMAKE_LIBRARY_PATH = if ($env:CMAKE_LIBRARY_PATH) { "$LibDir;$env:CMAKE_LIBRARY_PATH" } else { $LibDir }
    }
}

# Helper function to add include paths
function Add-IncludePaths {
    param([string]$IncludeDir)
    if (Test-Path $IncludeDir) {
        $env:INCLUDE = if ($env:INCLUDE) { "$IncludeDir;$env:INCLUDE" } else { $IncludeDir }
        $env:CMAKE_INCLUDE_PATH = if ($env:CMAKE_INCLUDE_PATH) { "$IncludeDir;$env:CMAKE_INCLUDE_PATH" } else { $IncludeDir }
    }
}

# Helper function to setup a scoop app's environment
function Set-ScoopAppEnvironment {
    param([string]$AppName)
    
    $appCurrent = Join-Path $scoopApps "$AppName\current"
    if (-not (Test-Path $appCurrent)) { return }
    
    # Add library paths
    $libDir = Join-Path $appCurrent "lib"
    if (Test-Path $libDir) {
        Add-LibraryPaths $libDir
    }
    
    # Add include paths
    $includeDir = Join-Path $appCurrent "include"
    if (Test-Path $includeDir) {
        Add-IncludePaths $includeDir
    }
}

# =================================================================================================
# Configure scoop-installed tools
# =================================================================================================

# SQLite
Set-ScoopAppEnvironment "sqlite"

# Lua/LuaJIT/LuaRocks
Set-ScoopAppEnvironment "lua"
Set-ScoopAppEnvironment "lua51"
Set-ScoopAppEnvironment "luajit"

# Curl (if needed for native extensions)
Set-ScoopAppEnvironment "curl"

# Cygwin - provides Unix tools on Windows
$cygwinRoot = Join-Path $scoopApps "cygwin\current"
if (Test-Path $cygwinRoot) {
    # Cygwin bin is already in PATH via scoop shim, just add lib/include
    $cygwinLib = Join-Path $cygwinRoot "lib"
    $cygwinInclude = Join-Path $cygwinRoot "usr\include"
    
    if (Test-Path $cygwinLib) { Add-LibraryPaths $cygwinLib }
    if (Test-Path $cygwinInclude) { Add-IncludePaths $cygwinInclude }
}

# =================================================================================================
# CMake configuration
# =================================================================================================
if ($env:CMAKE_LIBRARY_PATH) {
    $env:CMAKE_PREFIX_PATH = if ($env:CMAKE_PREFIX_PATH) {
        "$env:CMAKE_LIBRARY_PATH;$env:CMAKE_PREFIX_PATH"
    } else {
        $env:CMAKE_LIBRARY_PATH
    }
}

# Set CMAKE_INSTALL_PREFIX to local XDG data directory
$env:CMAKE_INSTALL_PREFIX = $env:XDG_DATA_HOME

# vim: ts=2 sts=2 sw=2 et

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
# Note: Mise activation is already done in the main profile (line 72)
# This script adds compiler/linker environment variables for native extensions

# Mise directories (XDG compliant)
$env:MISE_DATA_DIR = "$env:XDG_DATA_HOME\mise"
$env:MISE_CACHE_DIR = "$env:XDG_CACHE_HOME\mise"
$env:MISE_CONFIG_DIR = "$env:XDG_CONFIG_HOME\mise"
$env:MISE_GLOBAL_CONFIG_FILE = "$env:XDG_CONFIG_HOME\mise\config.toml"

# Cargo and Rustup homes (used by mise for Rust installations)
$env:CARGO_HOME = "$env:XDG_DATA_HOME\cargo"
$env:RUSTUP_HOME = "$env:XDG_DATA_HOME\rustup"

# =================================================================================================
# Mise-installed tools environment variables
# =================================================================================================
# Set up environment variables for building native extensions with mise-managed tools

$miseInstalls = "$env:MISE_DATA_DIR\installs"

# Helper function to add to PATH
function Add-ToPath {
    param([string]$Path)
    if (Test-Path $Path) {
        $env:PATH = "$Path;$env:PATH"
    }
}

# Helper function to add library paths (for building native extensions)
function Add-LibraryPaths {
    param([string]$LibDir)
    if (Test-Path $LibDir) {
        # LIB is used by MSVC, CMAKE_LIBRARY_PATH by CMake
        $env:LIB = if ($env:LIB) { "$LibDir;$env:LIB" } else { $LibDir }
        $env:CMAKE_LIBRARY_PATH = if ($env:CMAKE_LIBRARY_PATH) { "$LibDir;$env:CMAKE_LIBRARY_PATH" } else { $LibDir }
    }
}

# Helper function to add include paths (for building native extensions)
function Add-IncludePaths {
    param([string]$IncludeDir)
    if (Test-Path $IncludeDir) {
        # INCLUDE is used by MSVC, CMAKE_INCLUDE_PATH by CMake
        $env:INCLUDE = if ($env:INCLUDE) { "$IncludeDir;$env:INCLUDE" } else { $IncludeDir }
        $env:CMAKE_INCLUDE_PATH = if ($env:CMAKE_INCLUDE_PATH) { "$IncludeDir;$env:CMAKE_INCLUDE_PATH" } else { $IncludeDir }
    }
}

# Helper function to setup a tool's environment
function Set-ToolEnvironment {
    param(
        [string]$ToolDir,
        [string]$IncludeSubDir = "include"
    )
    
    if (-not (Test-Path $ToolDir)) { return }
    
    # Add library paths
    $libDir = Join-Path $ToolDir "lib"
    if (Test-Path $libDir) {
        Add-LibraryPaths $libDir
    }
    
    # Add include paths
    $includeDir = Join-Path $ToolDir $IncludeSubDir
    if (Test-Path $includeDir) {
        Add-IncludePaths $includeDir
    }
}

# Python - special handling for version-specific paths
$pythonRoot = Join-Path $miseInstalls "python"
if (Test-Path $pythonRoot) {
    Get-ChildItem $pythonRoot -Directory | ForEach-Object {
        $pythonDir = $_.FullName
        
        # Python lib directories
        $pythonLib = Join-Path $pythonDir "lib"
        if (Test-Path $pythonLib) {
            Get-ChildItem $pythonLib -Directory -Filter "python*" | ForEach-Object {
                Add-LibraryPaths $_.FullName
            }
        }
        
        # Python include directories
        $pythonInclude = Join-Path $pythonDir "include"
        if (Test-Path $pythonInclude) {
            Get-ChildItem $pythonInclude -Directory -Filter "python*" | ForEach-Object {
                Add-IncludePaths $_.FullName
            }
        }
    }
}

# Ruby
$rubyRoot = Join-Path $miseInstalls "ruby"
if (Test-Path $rubyRoot) {
    Get-ChildItem $rubyRoot -Directory | ForEach-Object {
        Set-ToolEnvironment $_.FullName
    }
}

# Node.js - special include path
$nodeRoot = Join-Path $miseInstalls "node"
if (Test-Path $nodeRoot) {
    Get-ChildItem $nodeRoot -Directory | ForEach-Object {
        Set-ToolEnvironment $_.FullName -IncludeSubDir "include\node"
    }
}

# Go - set GOROOT
$goRoot = Join-Path $miseInstalls "go"
if (Test-Path $goRoot) {
    Get-ChildItem $goRoot -Directory | ForEach-Object {
        $goDir = $_.FullName
        $env:GOROOT = $goDir
        Set-ToolEnvironment $goDir
    }
}

# Rust - CARGO_HOME and RUSTUP_HOME already set above
$rustRoot = Join-Path $miseInstalls "rust"
if (Test-Path $rustRoot) {
    Get-ChildItem $rustRoot -Directory | ForEach-Object {
        $rustLib = Join-Path $_.FullName "lib"
        if (Test-Path $rustLib) {
            Add-LibraryPaths $rustLib
        }
    }
}

# Lua
$luaRoot = Join-Path $miseInstalls "lua"
if (Test-Path $luaRoot) {
    Get-ChildItem $luaRoot -Directory | ForEach-Object {
        Set-ToolEnvironment $_.FullName
    }
}

# LuaJIT - special include path
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

# Bun - set BUN_INSTALL
$bunRoot = Join-Path $miseInstalls "bun"
if (Test-Path $bunRoot) {
    $latestBun = Get-ChildItem $bunRoot -Directory | Select-Object -First 1
    if ($latestBun) {
        $env:BUN_INSTALL = $latestBun.FullName
    }
}

# Deno
$denoRoot = Join-Path $miseInstalls "deno"
if (Test-Path $denoRoot) {
    Get-ChildItem $denoRoot -Directory | ForEach-Object {
        $env:DENO_INSTALL_ROOT = $_.FullName
    }
}

# Zig - set as C/C++ compiler
$zigRoot = Join-Path $miseInstalls "zig"
if (Test-Path $zigRoot) {
    $latestZig = Get-ChildItem $zigRoot -Directory | Select-Object -First 1
    if ($latestZig) {
        $zigExe = Join-Path $latestZig.FullName "zig.exe"
        if (Test-Path $zigExe) {
            # Set CC/CXX for tools that respect these variables
            $env:CC = "$zigExe cc"
            $env:CXX = "$zigExe c++"
            
            # CMake configuration for Zig
            $env:CMAKE_C_COMPILER = $zigExe
            $env:CMAKE_CXX_COMPILER = $zigExe
        }
    }
}

# PHP
$phpRoot = Join-Path $miseInstalls "php"
if (Test-Path $phpRoot) {
    Get-ChildItem $phpRoot -Directory | ForEach-Object {
        Set-ToolEnvironment $_.FullName
    }
}

# CMake configuration
if ($env:CMAKE_LIBRARY_PATH) {
    $env:CMAKE_PREFIX_PATH = $env:CMAKE_LIBRARY_PATH
}

# vim: ts=2 sts=2 sw=2 et

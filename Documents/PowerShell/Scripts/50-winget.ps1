# ██╗    ██╗██╗███╗   ██╗ ██████╗ ███████╗████████╗
# ██║    ██║██║████╗  ██║██╔════╝ ██╔════╝╚══██╔══╝
# ██║ █╗ ██║██║██╔██╗ ██║██║  ███╗█████╗     ██║
# ██║███╗██║██║██║╚██╗██║██║   ██║██╔══╝     ██║
# ╚███╔███╔╝██║██║ ╚████║╚██████╔╝███████╗   ██║
#  ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚══════╝   ╚═╝
# Windows Package Manager
# https://github.com/microsoft/winget-cli

# =================================================================================================
# Winget Configuration
# =================================================================================================
# Configure environment variables for winget-installed development tools

# Check if winget is installed
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    return
}

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

# =================================================================================================
# Strawberry Perl - includes MinGW toolchain, cmake, ninja, make
# =================================================================================================
# Strawberry Perl provides a complete C/C++ development environment for Perl modules

# Common Strawberry Perl installation paths
$strawberryPaths = @(
    "C:\Strawberry",
    "$env:ProgramFiles\Strawberry",
    "${env:ProgramFiles(x86)}\Strawberry"
)

$strawberryPerl = $strawberryPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($strawberryPerl) {
    # Strawberry Perl C toolchain (MinGW)
    $perlC = Join-Path $strawberryPerl "c"
    
    # Add MinGW bin to PATH (contains gcc, g++, cmake, ninja, make, etc.)
    $perlCBin = Join-Path $perlC "bin"
    if (Test-Path $perlCBin) {
        $env:PATH = "$perlCBin;$env:PATH"
    }
    
    # Add lib paths
    $perlCLib = Join-Path $perlC "lib"
    if (Test-Path $perlCLib) {
        Add-LibraryPaths $perlCLib
    }
    
    # Add include paths
    $perlCInclude = Join-Path $perlC "include"
    if (Test-Path $perlCInclude) {
        Add-IncludePaths $perlCInclude
    }
    
    # Set compiler environment variables
    $gccPath = Join-Path $perlCBin "gcc.exe"
    $gxxPath = Join-Path $perlCBin "g++.exe"
    
    if ((Test-Path $gccPath) -and (Test-Path $gxxPath)) {
        # Set CC/CXX for tools that respect these variables (if not already set by Zig)
        if (-not $env:CC) {
            $env:CC = $gccPath
        }
        if (-not $env:CXX) {
            $env:CXX = $gxxPath
        }
        
        # CMake configuration for MinGW (if not already set by Zig)
        if (-not $env:CMAKE_C_COMPILER) {
            $env:CMAKE_C_COMPILER = $gccPath
            $env:CMAKE_CXX_COMPILER = $gxxPath
            $env:CMAKE_GENERATOR = "Ninja"  # Use Ninja instead of Unix Makefiles
        }
    }
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

# Set CMAKE_INSTALL_PREFIX to local XDG data directory (if not already set)
if (-not $env:CMAKE_INSTALL_PREFIX) {
    $env:CMAKE_INSTALL_PREFIX = $env:XDG_DATA_HOME
}

# vim: ts=2 sts=2 sw=2 et

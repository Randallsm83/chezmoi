# ██████╗  █████╗ ████████╗██╗  ██╗███████╗
# ██╔══██╗██╔══██╗╚══██╔══╝██║  ██║██╔════╝
# ██████╔╝███████║   ██║   ███████║███████╗
# ██╔═══╝ ██╔══██║   ██║   ██║  ██║╚════██║
# ██║     ██║  ██║   ██║   ██║  ██║███████║
# ╚═╝     ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝
# Local user paths for building native extensions

# =================================================================================================
# ~/.local build environment
# =================================================================================================
# Add ~/.local/lib and ~/.local/include for user-installed libraries and headers

$localLib = "$HOME\.local\lib"
$localInclude = "$HOME\.local\include"
$localLibPkgconfig = "$HOME\.local\lib\pkgconfig"
$localSharePkgconfig = "$HOME\.local\share\pkgconfig"

# Add library paths if directory exists
if (Test-Path $localLib) {
    $env:LIB = if ($env:LIB) { "$localLib;$env:LIB" } else { $localLib }
    $env:CMAKE_LIBRARY_PATH = if ($env:CMAKE_LIBRARY_PATH) { "$localLib;$env:CMAKE_LIBRARY_PATH" } else { $localLib }
}

# Add include paths if directory exists
if (Test-Path $localInclude) {
    $env:INCLUDE = if ($env:INCLUDE) { "$localInclude;$env:INCLUDE" } else { $localInclude }
    $env:CMAKE_INCLUDE_PATH = if ($env:CMAKE_INCLUDE_PATH) { "$localInclude;$env:CMAKE_INCLUDE_PATH" } else { $localInclude }
}

# Add pkg-config paths if directories exist
$pkgConfigPaths = @()
if (Test-Path $localLibPkgconfig) {
    $pkgConfigPaths += $localLibPkgconfig
}
if (Test-Path $localSharePkgconfig) {
    $pkgConfigPaths += $localSharePkgconfig
}
if ($pkgConfigPaths.Count -gt 0) {
    $pkgConfigPathsStr = $pkgConfigPaths -join ';'
    $env:PKG_CONFIG_PATH = if ($env:PKG_CONFIG_PATH) {
        "$pkgConfigPathsStr;$env:PKG_CONFIG_PATH"
    } else {
        $pkgConfigPathsStr
    }
}

# vim: ts=2 sts=2 sw=2 et

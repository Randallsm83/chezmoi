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

# =================================================================================================
# Stale-profile PATH sanitizer
# =================================================================================================
# Some sessions inherit a stale PATH from a parent process that was launched
# under a previous Windows user profile (e.g. the username was renamed). The
# registry might already be clean, but the live $env:PATH still has the old
# entries. Strip any entries pointing into other Users\<name>\ profiles, and
# de-duplicate the result while preserving order.

$currentUserProfile = $env:USERPROFILE
if ($currentUserProfile) {
    $userProfileRoot = Split-Path -Parent $currentUserProfile      # e.g. C:\Users
    $currentLeaf     = Split-Path -Leaf   $currentUserProfile      # e.g. ranmil
    $foreignPattern  = '^' + [regex]::Escape("$userProfileRoot\") + '(?<who>[^\\]+)\\'

    $seen = New-Object System.Collections.Generic.HashSet[string] ([System.StringComparer]::OrdinalIgnoreCase)
    $kept = New-Object System.Collections.Generic.List[string]
    foreach ($entry in ($env:PATH -split ';')) {
        if (-not $entry) { continue }
        $m = [regex]::Match($entry, $foreignPattern)
        if ($m.Success -and $m.Groups['who'].Value -ne $currentLeaf) {
            continue   # foreign user profile path: drop it
        }
        if ($seen.Add($entry)) { $kept.Add($entry) | Out-Null }
    }
    $env:PATH = ($kept -join ';')
}

# vim: ts=2 sts=2 sw=2 et

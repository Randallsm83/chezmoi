# mise completion for PowerShell
# Ensure the usage CLI (required by mise completions and ftab fallback) is on PATH.
# Note: Register-ArgumentCompleter -Native doesn't fire for mise because
# mise activate pwsh redefines it as a PowerShell function. Completions are
# handled by ftab's usage complete-word fallback in 10-fzf.ps1 instead.

if (Get-Command mise -ErrorAction SilentlyContinue) {
    if (-not (Get-Command usage -ErrorAction SilentlyContinue)) {
        $usageBin = Get-ChildItem "$HOME\.local\share\mise\installs\usage" -Recurse -Filter 'usage.exe' -ErrorAction SilentlyContinue |
            Sort-Object { $_.Directory.Name } -Descending | Select-Object -First 1
        if ($usageBin) { $env:PATH = "$($usageBin.DirectoryName);$env:PATH" }
    }
}

# vim: ts=2 sts=2 sw=2 et

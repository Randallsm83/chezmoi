# 1Password CLI completion for PowerShell
# Cached to avoid running `op completion powershell` on every startup (~6s)
# Regenerate: op completion powershell | Out-File "$env:XDG_CACHE_HOME\op-completion.ps1" -Encoding utf8
if (Get-Command op -ErrorAction SilentlyContinue) {
    $opCache = "$env:XDG_CACHE_HOME\op-completion.ps1"
    if (-not (Test-Path $opCache)) {
        try {
            $null = New-Item -ItemType Directory -Path (Split-Path $opCache) -Force
            op completion powershell 2>$null | Out-File $opCache -Encoding utf8
        } catch {
            Write-Verbose "Failed to generate op completion cache: $_"
        }
    }
    if (Test-Path $opCache) { . $opCache }
}

# vim: ts=2 sts=2 sw=2 et

# 1Password CLI completion for PowerShell
if (Get-Command op -ErrorAction SilentlyContinue) {
    try {
        $completionScript = op completion powershell 2>&1 | Out-String
        if ($completionScript -and $completionScript.Trim()) {
            Invoke-Expression $completionScript
        }
    } catch {
        Write-Verbose "Failed to load op completion: $_"
    }
    
    # Automatically sign in to 1Password
    try {
        $signInOutput = op signin 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0 -and $signInOutput -and $signInOutput.Trim()) {
            Invoke-Expression $signInOutput
        }
    } catch {
        Write-Verbose "Failed to sign in to 1Password: $_"
    }
}

# vim: ts=2 sts=2 sw=2 et

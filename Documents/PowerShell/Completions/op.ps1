# 1Password CLI completion for PowerShell
if (Get-Command op -ErrorAction SilentlyContinue) {
    op completion powershell | Out-String | Invoke-Expression
    
    # Automatically sign in to 1Password
    $signInOutput = op signin 2>&1
    if ($LASTEXITCODE -eq 0) {
        Invoke-Expression $signInOutput
    }
}

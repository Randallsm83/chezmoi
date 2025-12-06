# Ripgrep CLI completion for PowerShell
if (Get-Command rg -ErrorAction SilentlyContinue) {
    rg --generate complete-powershell | Out-String | Invoke-Expression
}

# vim: ts=2 sts=2 sw=2 et

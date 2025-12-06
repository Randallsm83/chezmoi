# Starship CLI completion for PowerShell
if (Get-Command starship -ErrorAction SilentlyContinue) {
    starship completions powershell | Out-String | Invoke-Expression
}

# vim: ts=2 sts=2 sw=2 et

# Chezmoi CLI completion for PowerShell
if (Get-Command chezmoi -ErrorAction SilentlyContinue) {
    chezmoi completion powershell | Out-String | Invoke-Expression
}

# vim: ts=2 sts=2 sw=2 et

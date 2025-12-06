# Docker CLI completion for PowerShell
if (Get-Command docker -ErrorAction SilentlyContinue) {
    docker completion powershell | Out-String | Invoke-Expression
}

# vim: ts=2 sts=2 sw=2 et

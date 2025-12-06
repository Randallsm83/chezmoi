# Delta (git diff pager) completion for PowerShell
if (Get-Command delta -ErrorAction SilentlyContinue) {
    delta --generate-completion powershell | Out-String | Invoke-Expression
}

# vim: ts=2 sts=2 sw=2 et

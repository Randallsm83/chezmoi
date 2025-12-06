# GitHub CLI completion for PowerShell
if (Get-Command gh -ErrorAction SilentlyContinue) {
    gh completion -s powershell | Out-String | Invoke-Expression
}

# vim: ts=2 sts=2 sw=2 et

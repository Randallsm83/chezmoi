# fd (find alternative) completion for PowerShell
if (Get-Command fd -ErrorAction SilentlyContinue) {
    fd --gen-completions powershell | Out-String | Invoke-Expression
}

# vim: ts=2 sts=2 sw=2 et

# Rustup CLI completion for PowerShell
if (Get-Command rustup -ErrorAction SilentlyContinue) {
    rustup completions powershell | Out-String | Invoke-Expression
}

# vim: ts=2 sts=2 sw=2 et

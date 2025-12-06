# WezTerm CLI completion for PowerShell
if (Get-Command wezterm -ErrorAction SilentlyContinue) {
    wezterm shell-completion --shell power-shell | Out-String | Invoke-Expression
}

# vim: ts=2 sts=2 sw=2 et

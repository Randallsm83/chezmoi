# Warp terminal completion for PowerShell
if (Get-Command warp -ErrorAction SilentlyContinue) {
    warp completions | Out-String | Invoke-Expression
}

# vim: ts=2 sts=2 sw=2 et

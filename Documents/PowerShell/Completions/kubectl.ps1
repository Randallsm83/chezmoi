# Kubernetes kubectl completion for PowerShell
if (Get-Command kubectl -ErrorAction SilentlyContinue) {
    kubectl completion powershell | Out-String | Invoke-Expression
}

# vim: ts=2 sts=2 sw=2 et

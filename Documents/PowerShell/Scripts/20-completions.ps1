# ╔═╗┌─┐┌┬┐┌─┐┬  ┌─┐┌┬┐┬┌─┐┌┐┌┌─┐
# ║  │ ││││├─┘│  ├┤  │ ││ ││││└─┐
# ╚═╝└─┘┴ ┴┴  ┴─┘└─┘ ┴ ┴└─┘┘└┘└─┘
# Load CLI tool completions

$completionsDir = Join-Path (Split-Path $PROFILE) "Completions"
if (Test-Path $completionsDir) {
    Get-ChildItem "$completionsDir\*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Verbose "Loading completion: $($_.Name)"
        . $_.FullName
    }
}

# vim: ts=2 sts=2 sw=2 et

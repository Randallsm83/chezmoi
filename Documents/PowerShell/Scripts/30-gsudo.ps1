#  ██████╗ ███████╗██╗   ██╗██████╗  ██████╗
# ██╔════╝ ██╔════╝██║   ██║██╔══██╗██╔═══██╗
# ██║  ███╗███████╗██║   ██║██║  ██║██║   ██║
# ██║   ██║╚════██║██║   ██║██║  ██║██║   ██║
# ╚██████╔╝███████║╚██████╔╝██████╔╝╚██████╔╝
#  ╚═════╝ ╚══════╝ ╚═════╝ ╚═════╝  ╚═════╝
# gsudo - sudo for Windows
# https://github.com/gerardog/gsudo
#
# The scoop `gsudo` package ships a PowerShell module (`gsudoModule.psd1`) that
# adds shell helpers like `Invoke-Gsudo`, `gsudoConfig`, and the `!!` alias for
# re-running the previous command elevated. This file imports it on session
# start when gsudo is available.

if (Get-Command gsudo -ErrorAction SilentlyContinue) {
    # Module ships at <gsudo-install>\Current\gsudoModule.psd1 — locate it from the
    # gsudo binary so this works under scoop, winget, or a manual install.
    $gsudoCmd = Get-Command gsudo -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $gsudoPath = if ($gsudoCmd) { if ($gsudoCmd.Source) { $gsudoCmd.Source } else { $gsudoCmd.Path } } else { $null }
    if (-not [string]::IsNullOrWhiteSpace($gsudoPath)) {
        $gsudoDir = Split-Path -Parent $gsudoPath
        $modulePath = Join-Path $gsudoDir 'gsudoModule.psd1'
        if (Test-Path $modulePath) {
            Import-Module $modulePath -ErrorAction SilentlyContinue
        } else {
            # Fallback: let PowerShell resolve via PSModulePath if the module is on it
            Import-Module gsudoModule -ErrorAction SilentlyContinue
        }
    } else {
        # Fallback: let PowerShell resolve via PSModulePath if gsudo resolved as
        # an alias/function/shim without a concrete application path.
        Import-Module gsudoModule -ErrorAction SilentlyContinue
    }
}

# vim: ts=2 sts=2 sw=2 et

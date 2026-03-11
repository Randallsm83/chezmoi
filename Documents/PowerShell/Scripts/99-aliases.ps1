# PowerShell Alias Declarations
# Pure Set-Alias/New-Alias statements and environment variables.
# Functions are defined in 99-functions.ps1 (loaded after this file).
#
# Baseline aliases (grep, ps) may be overridden by Rust alternative
# wrapper functions in 99-functions.ps1 when those tools are installed.
#
# Usage: Sourced automatically by Microsoft.PowerShell_profile.ps1
# Reload: . $PROFILE

# ================================================================================================
# Environment Variables
# ================================================================================================

$env:DHSPACE = "D:\DH Dev"
$env:DOTFILES = "C:\Users\Randall\.config\dotfiles"
$env:PROJECTS = "D:\DH Dev\projects"

# ================================================================================================
# Profile Management
# ================================================================================================

Set-Alias -Name reload -Value Reload-Profile
Set-Alias -Name ep -Value Edit-Profile

# ================================================================================================
# Unix-like Commands (baselines — overridden by functions if Rust alternatives exist)
# ================================================================================================

Set-Alias -Name grep -Value Select-String -ErrorAction SilentlyContinue
Set-Alias -Name ps -Value Get-Process -ErrorAction SilentlyContinue
Set-Alias -Name kill -Value Stop-Process -ErrorAction SilentlyContinue

# ================================================================================================
# History
# ================================================================================================

Set-Alias -Name h -Value Get-History

# ================================================================================================
# Tool Aliases
# ================================================================================================

# Arduino CLI
if (Get-Command arduino-cli -ErrorAction SilentlyContinue) {
    Set-Alias -Name ard -Value arduino-cli
}
if (Get-Command arduino-cloud-cli -ErrorAction SilentlyContinue) {
    Set-Alias -Name ardc -Value arduino-cloud-cli
}

# ClickUp TUI
if (Get-Command clickup-tui -ErrorAction SilentlyContinue) {
    Set-Alias -Name cu -Value clickup-tui
}

# ================================================================================================
# Terminal Integration
# ================================================================================================

# OSC7 — WezTerm compatibility (Set-EnvVar function in 99-functions.ps1)
New-Alias -Name 'Set-PoshContext' -Value 'Set-EnvVar' -Scope Global -Force

# -------------------------------------------------------------------------------------------------
# vim: ft=ps1 sw=4 ts=4 et
# -------------------------------------------------------------------------------------------------

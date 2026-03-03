# PowerShell Aliases for Windows
# Mirrors zsh aliases configuration from dotfiles
# Symlinked to PowerShell profile location
#
# Usage: Sourced automatically by Microsoft.PowerShell_profile.ps1
# Reload: . $PROFILE
#
# VALIDATION CHECKLIST:
# - All paths exist or have conditional checks
# - Profile loads without errors
# - Tool-dependent aliases check for tool existence
# - Pipeline functions work correctly
# - Safety aliases maintain expected behavior
# - Navigation aliases handle spaces in paths correctly

# ================================================================================================
# Environment Variables
# ================================================================================================

# Set common path environment variables
$env:DHSPACE = "D:\DH Dev"
$env:DOTFILES = "C:\Users\Randall\.config\dotfiles"
$env:PROJECTS = "D:\DH Dev\projects"

# ================================================================================================
# Helper Functions
# ================================================================================================

<#
.SYNOPSIS
    Tests if a command exists in the current session.
.PARAMETER CommandName
    The name of the command to test.
#>
function Test-CommandExists {
    param([string]$CommandName)
    return [bool](Get-Command $CommandName -ErrorAction SilentlyContinue)
}

<#
.SYNOPSIS
    Tests if a directory exists.
.PARAMETER Path
    The path to test.
#>
function Test-DirectoryExists {
    param([string]$Path)
    return Test-Path -Path $Path -PathType Container
}

# ================================================================================================
# Display & Utility Aliases
# ================================================================================================

<#
.SYNOPSIS
    Display PATH entries one per line.
#>
function paths {
    $env:Path -split ';' | Where-Object { $_ } | ForEach-Object { Write-Host $_ }
}

<#
.SYNOPSIS
    List all defined aliases.
#>
function aliases {
    Get-Alias | Sort-Object Name | Format-Table -AutoSize Name, Definition
}

<#
.SYNOPSIS
    List all defined functions.
#>
function functions {
    Get-Command -CommandType Function | 
        Where-Object { $_.Source -eq '' } | 
        Sort-Object Name | 
        Format-Table -AutoSize Name, Definition
}

# ================================================================================================
# Navigation Aliases
# ================================================================================================

# Navigate to projects root
if (Test-DirectoryExists $env:PROJECTS) {
    function cdp { Set-Location "$env:PROJECTS" }
}

# Quick navigation to specific repos
if (Test-DirectoryExists "$env:PROJECTS\ndn") {
    function cdn { Set-Location "$env:PROJECTS\ndn" }
}

if (Test-DirectoryExists "$env:PROJECTS\api-gateway") {
    function cdapi { Set-Location "$env:PROJECTS\api-gateway" }
}

if (Test-DirectoryExists "$env:PROJECTS\cdn-service") {
    function cdcdn { Set-Location "$env:PROJECTS\cdn-service" }
}

# Navigate to DH space
if (Test-DirectoryExists $env:DHSPACE) {
    function dh { Set-Location "$env:DHSPACE" }
}

# Navigate to dotfiles
if (Test-DirectoryExists $env:DOTFILES) {
    function dots { Set-Location "$env:DOTFILES" }
}

# Navigate to notes/vaults
if (Test-DirectoryExists "$env:USERPROFILE\vaults") {
    function notes { Set-Location "$env:USERPROFILE\vaults" }
}

# ================================================================================================
# Editor Configuration Aliases
# ================================================================================================

<#
.SYNOPSIS
    Get the preferred editor command.
#>
function Get-PreferredEditor {
    if ($env:EDITOR -and (Test-CommandExists $env:EDITOR)) {
        return $env:EDITOR
    }
    elseif (Test-CommandExists 'nvim') {
        return 'nvim'
    }
    elseif (Test-CommandExists 'code') {
        return 'code'
    }
    elseif (Test-CommandExists 'notepad++') {
        return 'notepad++'
    }
    else {
        return 'notepad'
    }
}

# Edit neovim config
function nrc {
    $editor = Get-PreferredEditor
    $nvimConfig = if (Test-Path "$env:XDG_CONFIG_HOME\nvim\init.lua") {
        "$env:XDG_CONFIG_HOME\nvim\init.lua"
    } elseif (Test-Path "$env:LOCALAPPDATA\nvim\init.lua") {
        "$env:LOCALAPPDATA\nvim\init.lua"
    } else {
        Write-Warning "Neovim config not found"
        return
    }
    & $editor $nvimConfig
}

# Edit wezterm config
function wrc {
    $editor = Get-PreferredEditor
    $weztermConfig = "$env:XDG_CONFIG_HOME\wezterm\wezterm.lua"
    if (Test-Path $weztermConfig) {
        & $editor $weztermConfig
    } else {
        Write-Warning "WezTerm config not found at $weztermConfig"
    }
}

# Edit PowerShell aliases
function aliasrc {
    $editor = Get-PreferredEditor
    $aliasesFile = "$env:DOTFILES\windows\powershell\aliases.ps1"
    & $editor $aliasesFile
}

# Edit PowerShell profile
function profilerc {
    $editor = Get-PreferredEditor
    & $editor $PROFILE
}

# Starship config
function strc {
    $editor = Get-PreferredEditor
    $starshipConfig = "$env:XDG_CONFIG_HOME\starship\starship.toml"
    if (Test-Path $starshipConfig) {
        & $editor $starshipConfig
    } else {
        Write-Warning "Starship config not found at $starshipConfig"
    }
}

# ================================================================================================
# Unix-like Command Aliases
# ================================================================================================

# grep → ripgrep if available, otherwise Select-String
if (Test-CommandExists 'rg') {
    Remove-Item -Path "Alias:grep" -Force -ErrorAction SilentlyContinue
    function grep { & rg @args }
} else {
    Set-Alias -Name grep -Value Select-String -ErrorAction SilentlyContinue
}

# which - show command details with source file locations
Remove-Item -Path "Alias:which" -Force -ErrorAction SilentlyContinue
function which {
    param([Parameter(ValueFromRemainingArguments)][string[]]$Names)
    foreach ($name in $Names) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue -All |
            Where-Object { $_.Name -ceq $name -or
                ($_.CommandType -eq 'Application' -and
                 [System.IO.Path]::GetFileNameWithoutExtension($_.Name) -ceq $name) }
        if (-not $cmd) {
            Write-Error "$name not found"
            continue
        }
        $filtered = @($cmd)
        $first = $true
        foreach ($c in $filtered) {
            if ($first) {
                Write-Host '▶ ' -ForegroundColor Green -NoNewline
                Write-Host $c.Name -ForegroundColor Cyan -NoNewline
                Write-Host " [$($c.CommandType)]" -ForegroundColor DarkGray -NoNewline
                Write-Host ' ← active' -ForegroundColor Green
            } else {
                Write-Host '  ' -NoNewline
                Write-Host $c.Name -ForegroundColor DarkGray -NoNewline
                Write-Host " [$($c.CommandType)]" -ForegroundColor DarkGray -NoNewline
                Write-Host ' (shadowed)' -ForegroundColor DarkYellow
            }
            $first = $false
            switch ($c.CommandType) {
                'Application' {
                    Write-Host "  Path: $($c.Source)" -ForegroundColor Green
                    if ($c.Version) { Write-Host "  Version: $($c.Version)" -ForegroundColor DarkGray }
                }
                'Alias' {
                    Write-Host "  Resolves to: $($c.ResolvedCommandName)" -ForegroundColor Green
                    $resolved = Get-Command $c.ResolvedCommandName -ErrorAction SilentlyContinue
                    if ($resolved) {
                        Write-Host "  Target: $($resolved.Source ?? $resolved.Definition)" -ForegroundColor DarkGray
                    }
                }
                'Function' {
                    $file = $c.ScriptBlock.File
                    $line = $c.ScriptBlock.StartPosition.StartLine
                    if ($file) {
                        Write-Host "  Defined in: ${file}:${line}" -ForegroundColor Green
                    } else {
                        Write-Host "  Defined in: <session>" -ForegroundColor Yellow
                    }
                    Write-Host "  Definition:" -ForegroundColor DarkGray
                    $c.Definition -split "`n" | ForEach-Object {
                        Write-Host "    $_" -ForegroundColor Gray
                    }
                }
                'Cmdlet' {
                    Write-Host "  Module: $($c.Source)" -ForegroundColor Green
                    Write-Host "  DLL: $($c.DLL)" -ForegroundColor DarkGray
                }
                default {
                    if ($c.Source) { Write-Host "  Source: $($c.Source)" -ForegroundColor Green }
                }
            }
            Write-Host
        }
    }
}

# ps → procs if available, otherwise Get-Process
if (Test-CommandExists 'procs') {
    Remove-Item -Path "Alias:ps" -Force -ErrorAction SilentlyContinue
    function ps { & procs @args }
} else {
    Set-Alias -Name ps -Value Get-Process -ErrorAction SilentlyContinue
}

Set-Alias -Name kill -Value Stop-Process -ErrorAction SilentlyContinue

# Replace built-in scoop search (if scoop-search is available)
if (Test-CommandExists 'scoop-search') {
    try {
        Invoke-Expression (&scoop-search --hook)
    } catch {}
}

# ================================================================================================
# Editor Shortcuts
# ================================================================================================

if (Test-CommandExists 'nvim') {
    function vim { & nvim $args }
    function vi { & nvim $args }
}

# ================================================================================================
# Git Shortcuts
# ================================================================================================

function gs { git status $args }
function gst { git status $args }
function ga { git add $args }
function gc { git commit $args }
function gp { git push $args }
function gl { git pull $args }
function gd { git diff $args }
function gco { git checkout $args }
function glog { git log --oneline --graph --decorate $args }

# ================================================================================================
# Directory Navigation Shortcuts
# ================================================================================================

function .. { Set-Location .. }
function ... { Set-Location ..\.. }
function .... { Set-Location ..\..\.. }

# ================================================================================================
# Profile Management
# ================================================================================================

function Reload-Profile {
    . $PROFILE
    Write-Host "Profile reloaded!" -ForegroundColor Green
}
Set-Alias -Name reload -Value Reload-Profile

function Edit-Profile {
    if (Test-CommandExists 'nvim') {
        nvim $PROFILE
    } else {
        notepad $PROFILE
    }
}
Set-Alias -Name ep -Value Edit-Profile

# ================================================================================================
# File System Utilities
# ================================================================================================

# touch - skip if uutils-coreutils provides touch.exe
if (-not $env:__UUTILS_COREUTILS) {
    function touch {
        param([string]$file)
        if (Test-Path $file) {
            (Get-Item $file).LastWriteTime = Get-Date
        } else {
            New-Item -ItemType File -Path $file | Out-Null
        }
    }
}

function mkcd {
    param([string]$path)
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    Set-Location $path
}

# ================================================================================================
# Tool Aliases
# ================================================================================================

# bat (better cat) with tilde and glob expansion
if (Test-CommandExists 'bat.exe') {
    Remove-Alias -Name cat -Force -ErrorAction SilentlyContinue
    
    function bat {
        $expandedPaths = @()
        foreach ($arg in $args) {
            # Skip non-path arguments (flags/options starting with -)
            if ($arg -match '^-') {
                $expandedPaths += $arg
                continue
            }
            
            # Expand tilde to home directory
            if ($arg -match '^~') {
                $arg = $arg -replace '^~', $HOME
            }
            
            # Expand globs if path contains wildcards
            if ($arg -match '[*?\[\]]') {
                $resolved = @(Resolve-Path -Path $arg -ErrorAction SilentlyContinue)
                if ($resolved.Count -gt 0) {
                    $expandedPaths += $resolved | ForEach-Object { $_.Path }
                } else {
                    # If glob doesn't match anything, pass it through
                    $expandedPaths += $arg
                }
            } else {
                $expandedPaths += $arg
            }
        }
        & (Get-Command bat.exe) @expandedPaths
    }
    
    Set-Alias -Name cat -Value bat -Scope Global -Force
}

# Arduino CLI shortcuts
if (Test-CommandExists 'arduino-cli') {
    Set-Alias -Name ard -Value arduino-cli
}

if (Test-CommandExists 'arduino-cloud-cli') {
    Set-Alias -Name ardc -Value arduino-cloud-cli
}

# ClickUp TUI
if (Test-CommandExists 'clickup-tui') {
    Set-Alias -Name cu -Value clickup-tui
}

# ================================================================================================
# Common Utility Aliases
# ================================================================================================

<#
.SYNOPSIS
    Recursive grep with context.
.PARAMETER Pattern
    The pattern to search for.
.PARAMETER Path
    The path to search in (defaults to current directory).
#>
function sgrep {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Pattern,
        [Parameter(Position = 1)]
        [string]$Path = '.'
    )
    
    Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.DirectoryName -notmatch '\\.(git|svn)\\' } |
        Select-String -Pattern $Pattern -Context 5 |
        Format-List
}

<#
.SYNOPSIS
    Tail -f equivalent for PowerShell.
#>
function t {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path
    )
    Get-Content -Path $Path -Wait -Tail 10
}

<#
.SYNOPSIS
    Disk usage for current directory (depth 1).
#>
function dud {
    Get-ChildItem -Directory | ForEach-Object {
        $size = (Get-ChildItem -Path $_.FullName -Recurse -File -ErrorAction SilentlyContinue | 
            Measure-Object -Property Length -Sum).Sum
        $sizeInMB = [math]::Round($size / 1MB, 2)
        [PSCustomObject]@{
            Directory = $_.Name
            'Size (MB)' = $sizeInMB
        }
    } | Sort-Object 'Size (MB)' -Descending | Format-Table -AutoSize
}

<#
.SYNOPSIS
    Find files by name pattern (non-interactive).
    For interactive fzf file finding, use ff instead.
#>
function ffind {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Pattern
    )
    Get-ChildItem -Recurse -File -Filter "*$Pattern*" -ErrorAction SilentlyContinue
}

# History alias
Set-Alias -Name h -Value Get-History

<#
.SYNOPSIS
    Search command history.
#>
function hgrep {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Pattern
    )
    Get-History | Where-Object { $_.CommandLine -match $Pattern } | Format-Table -AutoSize
}

# Process alias (already exists in main profile but adding here for completeness)
# Set-Alias -Name p -Value Get-Process

# ================================================================================================
# Pipeline Helper Functions
# ================================================================================================
# These replace zsh's global aliases (H, T, G, L, etc.)

<#
.SYNOPSIS
    Get the first N items from pipeline (like | head).
#>
function H {
    param(
        [Parameter(ValueFromPipeline = $true)]
        $InputObject,
        [int]$Count = 10
    )
    begin { $items = @() }
    process { $items += $InputObject }
    end { $items | Select-Object -First $Count }
}

<#
.SYNOPSIS
    Get the last N items from pipeline (like | tail).
#>
function T {
    param(
        [Parameter(ValueFromPipeline = $true)]
        $InputObject,
        [int]$Count = 10
    )
    begin { $items = @() }
    process { $items += $InputObject }
    end { $items | Select-Object -Last $Count }
}

<#
.SYNOPSIS
    Filter pipeline output by pattern (like | grep).
#>
function G {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Pattern,
        [Parameter(ValueFromPipeline = $true)]
        $InputObject
    )
    process {
        if ($InputObject -match $Pattern) {
            $InputObject
        }
    }
}

<#
.SYNOPSIS
    Page pipeline output (like | less).
#>
function L {
    param(
        [Parameter(ValueFromPipeline = $true)]
        $InputObject
    )
    begin { $items = @() }
    process { $items += $InputObject }
    end { $items | Out-Host -Paging }
}

# ================================================================================================
# Package Manager Update Aliases
# ================================================================================================

# Scoop update
if (Test-CommandExists 'scoop') {
    function scoopup {
        Write-Host "Updating Scoop..." -ForegroundColor Cyan
        scoop update
        Write-Host "Upgrading all Scoop packages..." -ForegroundColor Cyan
        scoop update *
        Write-Host "Cleaning up..." -ForegroundColor Cyan
        scoop cleanup *
        scoop cache rm *
        Write-Host "Scoop update complete!" -ForegroundColor Green
    }
}

# Winget update
if (Test-CommandExists 'winget') {
    function wingetup {
        Write-Host "Upgrading all winget packages..." -ForegroundColor Cyan
        winget upgrade --all
        Write-Host "Winget update complete!" -ForegroundColor Green
    }
}

# Chocolatey update
if (Test-CommandExists 'choco') {
    function chocoup {
        Write-Host "Upgrading all Chocolatey packages..." -ForegroundColor Cyan
        choco upgrade all -y
        Write-Host "Cleaning up..." -ForegroundColor Cyan
        choco cache remove -y
        Write-Host "Chocolatey update complete!" -ForegroundColor Green
    }
}

# Mise update
if (Test-CommandExists 'mise') {
    function miseup {
        Write-Host "Upgrading mise tools..." -ForegroundColor Cyan
        mise up
        Write-Host "Cleaning up..." -ForegroundColor Cyan
        mise prune --yes
        Write-Host "Mise update complete!" -ForegroundColor Green
    }
}

# PowerShell modules update
function pwshup {
    Write-Host "Updating PowerShell modules..." -ForegroundColor Cyan
    Get-InstalledModule | ForEach-Object {
        Write-Host "Updating $($_.Name)..." -ForegroundColor Yellow
        try {
            Update-Module -Name $_.Name -Force -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to update $($_.Name): $_"
        }
    }
    Write-Host "PowerShell modules update complete!" -ForegroundColor Green
}

# Combined update function
function updateall {
    Write-Host "`n======================================" -ForegroundColor Magenta
    Write-Host "Updating all package managers..." -ForegroundColor Magenta
    Write-Host "======================================`n" -ForegroundColor Magenta
    
    if (Test-CommandExists 'scoop') {
        scoopup
        Write-Host ""
    }
    
    if (Test-CommandExists 'winget') {
        wingetup
        Write-Host ""
    }
    
    if (Test-CommandExists 'choco') {
        chocoup
        Write-Host ""
    }
    
    if (Test-CommandExists 'mise') {
        miseup
        Write-Host ""
    }
    
    pwshup
    
    Write-Host "`n======================================" -ForegroundColor Magenta
    Write-Host "All updates complete!" -ForegroundColor Magenta
    Write-Host "======================================`n" -ForegroundColor Magenta
}

# ================================================================================================
# Rust CLI Alternatives
# ================================================================================================
# Modern Rust-based replacements for traditional Unix tools
# These shadow the legacy command names so muscle memory works
# Use the .exe name directly to bypass (e.g. find.exe, sed.exe)

# sed → sd
if (Test-CommandExists 'sd') {
    function sed { & sd @args }
}

# du → dust
if (Test-CommandExists 'dust') {
    Remove-Item -Path "Alias:du" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "Function:du" -Force -ErrorAction SilentlyContinue
    function du { & dust @args }
}

# find → fd
if (Test-CommandExists 'fd') {
    function find { & fd @args }
}

# diff → delta
if (Test-CommandExists 'delta') {
    function diff { & delta @args }
}

# cloc/sloccount → tokei
if (Test-CommandExists 'tokei') {
    function cloc { & tokei @args }
}

# time/bench → hyperfine
if (Test-CommandExists 'hyperfine') {
    function time { & hyperfine @args }
    function bench { & hyperfine @args }
}

# http → xh (httpie-like HTTP client)
if (Test-CommandExists 'xh') {
    function http { & xh @args }
    function https { & xh --https @args }
}

# compress/decompress → ouch
if (Test-CommandExists 'ouch') {
    function compress { & ouch compress @args }
    function decompress { & ouch decompress @args }
}

# tldr → tealdeer (binary is already named tldr, just ensure alias)
if (Test-CommandExists 'tldr') {
    function help { & tldr @args }
}

<#
.SYNOPSIS
    List all installed Rust CLI alternatives and what they replace.
#>
function rust-tools {
    $tools = @(
        @{ Rust = 'bat';                Replaces = 'cat';              Binary = 'bat' }
        @{ Rust = 'ripgrep';            Replaces = 'grep';             Binary = 'rg' }
        @{ Rust = 'fd';                 Replaces = 'find';             Binary = 'fd' }
        @{ Rust = 'eza';                Replaces = 'ls';               Binary = 'eza' }
        @{ Rust = 'delta';              Replaces = 'diff';             Binary = 'delta' }
        @{ Rust = 'zoxide';             Replaces = 'cd';               Binary = 'zoxide' }
        @{ Rust = 'vivid';              Replaces = 'dircolors';        Binary = 'vivid' }
        @{ Rust = 'uutils-coreutils';   Replaces = 'coreutils';        Binary = 'coreutils' }
        @{ Rust = 'tealdeer';           Replaces = 'tldr/man';         Binary = 'tldr' }
        @{ Rust = 'navi';               Replaces = 'cheatsheets';      Binary = 'navi' }
        @{ Rust = 'sd';                 Replaces = 'sed';              Binary = 'sd' }
        @{ Rust = 'dust';               Replaces = 'du';               Binary = 'dust' }
        @{ Rust = 'procs';              Replaces = 'ps/tasklist';      Binary = 'procs' }
        @{ Rust = 'hyperfine';          Replaces = 'time/benchmark';   Binary = 'hyperfine' }
        @{ Rust = 'just';               Replaces = 'make (tasks)';     Binary = 'just' }
        @{ Rust = 'tokei';              Replaces = 'cloc/sloccount';   Binary = 'tokei' }
        @{ Rust = 'ouch';               Replaces = 'tar/zip/compress'; Binary = 'ouch' }
        @{ Rust = 'xh';                 Replaces = 'curl (HTTP)';      Binary = 'xh' }
    )

    $tools | ForEach-Object {
        $installed = [bool](Get-Command $_.Binary -ErrorAction SilentlyContinue)
        $status = if ($installed) { '✓' } else { '✗' }
        $color = if ($installed) { 'Green' } else { 'Red' }
        $line = "{0} {1,-22} → {2,-22} ({3})" -f $status, $_.Rust, $_.Replaces, $_.Binary
        Write-Host $line -ForegroundColor $color
    }

    $installedCount = ($tools | Where-Object { Get-Command $_.Binary -ErrorAction SilentlyContinue }).Count
    Write-Host "`n$installedCount/$($tools.Count) Rust alternatives installed" -ForegroundColor Cyan
}

# ================================================================================================
# Additional Utility Functions
# ================================================================================================

<#
.SYNOPSIS
    Quick check for what packages/tools are available.
#>
function has {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Command
    )
    
    if (Test-CommandExists $Command) {
        $cmd = Get-Command $Command
        Write-Host "✓ $Command is available" -ForegroundColor Green
        Write-Host "  Location: $($cmd.Source)" -ForegroundColor Gray
        if ($cmd.Version) {
            Write-Host "  Version: $($cmd.Version)" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "✗ $Command is not available" -ForegroundColor Red
    }
}

# ================================================================================================
# Safety Aliases
# ================================================================================================
# Add confirmation prompts to destructive commands
# Skip when uutils-coreutils is active — 05-coreutils.ps1 already exposes the real binaries

if (-not $env:__UUTILS_COREUTILS) {

<#
.SYNOPSIS
    Safe remove with confirmation by default.
#>
function rm {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)]
        [string[]]$Path,
        [switch]$Recurse,
        [switch]$Force
    )
    
    $params = @{
        Path = $Path
        Confirm = $true
    }
    
    if ($Recurse) { $params.Recurse = $true }
    if ($Force) { $params.Force = $true }
    
    Remove-Item @params
}

<#
.SYNOPSIS
    Safe copy with warning on overwrite.
#>
function cp {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Source,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Destination
    )
    
    if ((Test-Path $Destination) -and -not $Force) {
        $response = Read-Host "Destination exists. Overwrite? (y/N)"
        if ($response -ne 'y') {
            Write-Host "Copy cancelled." -ForegroundColor Yellow
            return
        }
    }
    
    Copy-Item -Path $Source -Destination $Destination -Confirm:$false
}

<#
.SYNOPSIS
    Safe move with warning on overwrite.
#>
function mv {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Source,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Destination
    )
    
    if ((Test-Path $Destination) -and -not $Force) {
        $response = Read-Host "Destination exists. Overwrite? (y/N)"
        if ($response -ne 'y') {
            Write-Host "Move cancelled." -ForegroundColor Yellow
            return
        }
    }
    
    Move-Item -Path $Source -Destination $Destination -Confirm:$false
}

} # end: skip when uutils-coreutils is active

# -------------------------------------------------------------------------------------------------
# vim: ft=ps1 sw=4 ts=4 et
# -------------------------------------------------------------------------------------------------

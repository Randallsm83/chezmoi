# PowerShell Function Definitions
# All functions — aliases are declared in 99-aliases.ps1 (loaded before this file).
#
# Functions here may override baseline aliases (grep, ps, cat) when
# Rust alternatives are installed.
#
# Usage: Sourced automatically by Microsoft.PowerShell_profile.ps1
# Reload: . $PROFILE
#
# VALIDATION CHECKLIST:
# - All paths exist or have conditional checks
# - Tool-dependent functions check for tool existence
# - Pipeline functions work correctly
# - Safety functions maintain expected behavior
# - Navigation functions handle spaces in paths correctly

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
# Display & Utility Functions
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
# Navigation Functions
# ================================================================================================

if (Test-DirectoryExists $env:PROJECTS) {
    function cdp { Set-Location "$env:PROJECTS" }
}

if (Test-DirectoryExists "$env:PROJECTS\ndn") {
    function cdn { Set-Location "$env:PROJECTS\ndn" }
}

if (Test-DirectoryExists "$env:PROJECTS\api-gateway") {
    function cdapi { Set-Location "$env:PROJECTS\api-gateway" }
}

if (Test-DirectoryExists "$env:PROJECTS\cdn-service") {
    function cdcdn { Set-Location "$env:PROJECTS\cdn-service" }
}

if (Test-DirectoryExists $env:DHSPACE) {
    function dh { Set-Location "$env:DHSPACE" }
}

if (Test-DirectoryExists $env:DOTFILES) {
    function dots { Set-Location "$env:DOTFILES" }
}

if (Test-DirectoryExists "$env:USERPROFILE\notes") {
    function notes { Set-Location "$env:USERPROFILE\notes" }
}

function .. { Set-Location .. }
function ... { Set-Location ..\.. }
function .... { Set-Location ..\..\.. }

# ================================================================================================
# Obsidian / Notes Functions
# ================================================================================================

if (Test-CommandExists 'obsidian') {
    function n          { obsidian @args }
    function nd         { obsidian daily }
    function nt         { obsidian tasks daily }
    function ntags      { obsidian tags counts }
    function norphans   { obsidian orphans }
    function nunresolved { obsidian unresolved }
    function nhome      { obsidian open file=HOME }
    function ninbox     { obsidian open 'file=00 Inbox' }

    function ntask {
        param([Parameter(ValueFromRemainingArguments)][string[]]$Task)
        obsidian daily:append "content=- [ ] $($Task -join ' ')"
    }

    function nc {
        param([Parameter(ValueFromRemainingArguments)][string[]]$Title)
        $name = if ($Title) { $Title -join ' ' } else { Get-Date -Format 'yyyyMMdd-HHmmss' }
        obsidian create "name=$name" 'folder=00 Inbox'
    }
}

# Fuzzy find note by name, open in Obsidian (requires: fd, fzf, bat, obsidian)
if ((Test-CommandExists 'fd') -and (Test-CommandExists 'fzf') -and (Test-CommandExists 'obsidian')) {
    function nf {
        $notesPath = "$env:USERPROFILE\notes"
        $file = fd --type f --extension md . $notesPath |
            ForEach-Object { $_ -replace [regex]::Escape("$notesPath\"), '' } |
            fzf --preview "bat --color=always $notesPath\{}"
        if ($file) { obsidian open "file=$($file -replace '\\', '/')" }
    }
}

# Fuzzy search note content, open match (requires: rg, fzf, obsidian)
if ((Test-CommandExists 'rg') -and (Test-CommandExists 'fzf') -and (Test-CommandExists 'obsidian')) {
    function nfs {
        param([Parameter(Mandatory)][string]$Query)
        $notesPath = "$env:USERPROFILE\notes"
        $file = rg --type md -l $Query $notesPath |
            ForEach-Object { $_ -replace [regex]::Escape("$notesPath\"), '' } |
            fzf --preview "rg --color=always $Query $notesPath\{}"
        if ($file) { obsidian open "file=$($file -replace '\\', '/')" }
    }
}

# Grep notes (raw, no app required)
if (Test-CommandExists 'rg') {
    function ngrep {
        param([Parameter(ValueFromRemainingArguments)][string[]]$Args)
        rg --type md @Args "$env:USERPROFILE\notes"
    }
}

<#
.SYNOPSIS
    List all note/Obsidian shell commands and dependency status.
#>
function note-tools {
    $deps = @(
        @{ Name = 'obsidian';        Purpose = 'CLI (required for most commands)';  Binary = 'obsidian' }
        @{ Name = 'obsidian-export'; Purpose = 'export vault to standard Markdown'; Binary = 'obsidian-export' }
        @{ Name = 'rg';              Purpose = 'ngrep, nfs content search';         Binary = 'rg' }
        @{ Name = 'fd';              Purpose = 'nf file finder';                    Binary = 'fd' }
        @{ Name = 'fzf';             Purpose = 'interactive picker (nf, nfs)';      Binary = 'fzf' }
        @{ Name = 'bat';             Purpose = 'nf preview';                        Binary = 'bat' }
    )

    Write-Host "`nDependencies" -ForegroundColor Cyan
    foreach ($dep in $deps) {
        $ok     = [bool](Get-Command $dep.Binary -ErrorAction SilentlyContinue)
        $status = if ($ok) { '✓' } else { '✗' }
        $color  = if ($ok) { 'Green' } else { 'Red' }
        Write-Host ("{0} {1,-20} {2}" -f $status, $dep.Name, $dep.Purpose) -ForegroundColor $color
    }

    Write-Host "`nCommands" -ForegroundColor Cyan
    $cmds = @(
        @{ Cmd = 'notes';           Does = 'cd ~/notes' }
        @{ Cmd = 'n [args]';        Does = 'obsidian CLI passthrough' }
        @{ Cmd = 'nd';              Does = "open today's daily note" }
        @{ Cmd = 'nt';              Does = "list today's tasks" }
        @{ Cmd = 'ntask <msg>';     Does = "append task to today's daily note" }
        @{ Cmd = 'nc [title]';      Does = 'quick capture → 00 Inbox' }
        @{ Cmd = 'ntags';           Does = 'all tags with frequency' }
        @{ Cmd = 'norphans';        Does = 'notes with no backlinks' }
        @{ Cmd = 'nunresolved';     Does = 'broken wikilinks' }
        @{ Cmd = 'nhome';           Does = 'open HOME dashboard' }
        @{ Cmd = 'ninbox';          Does = 'open 00 Inbox' }
        @{ Cmd = 'nf';              Does = 'fuzzy find note by name → open' }
        @{ Cmd = 'nfs <query>';     Does = 'fuzzy search note content → open' }
        @{ Cmd = 'ngrep <pattern>'; Does = 'grep all notes (no app required)' }
    )
    foreach ($cmd in $cmds) {
        Write-Host ("  {0,-20} {1}" -f $cmd.Cmd, $cmd.Does) -ForegroundColor Gray
    }
    Write-Host ""

    $installedCount = ($deps | Where-Object { Get-Command $_.Binary -ErrorAction SilentlyContinue }).Count
    Write-Host "$installedCount/$($deps.Count) dependencies available" -ForegroundColor Cyan
}

# ================================================================================================
# Editor Configuration Functions
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

function wrc {
    $editor = Get-PreferredEditor
    $weztermConfig = "$env:XDG_CONFIG_HOME\wezterm\wezterm.lua"
    if (Test-Path $weztermConfig) {
        & $editor $weztermConfig
    } else {
        Write-Warning "WezTerm config not found at $weztermConfig"
    }
}

function aliasrc {
    $editor = Get-PreferredEditor
    $aliasesFile = "$env:DOTFILES\windows\powershell\aliases.ps1"
    & $editor $aliasesFile
}

function profilerc {
    $editor = Get-PreferredEditor
    & $editor $PROFILE
}

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
# Profile Management
# ================================================================================================

function Reload-Profile {
    . $PROFILE
    Write-Host "Profile reloaded!" -ForegroundColor Green
}

function Edit-Profile {
    if (Test-CommandExists 'nvim') {
        nvim $PROFILE
    } else {
        notepad $PROFILE
    }
}

# ================================================================================================
# Command Introspection
# ================================================================================================

# which — show command details with source file locations
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
# File System Utilities
# ================================================================================================

# touch — skip if uutils-coreutils provides touch.exe
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
# Tool Functions
# ================================================================================================

# pip — on Windows with mise, pip is not shimmed
if (Test-CommandExists 'python') {
    function pip { & python -m pip $args }
}

if (Test-CommandExists 'scoop') {
    # scoop-search hook (replaces built-in search)
    if (Test-CommandExists 'scoop-search') {
        try {
            Invoke-Expression (&scoop-search --hook)
        } catch {}
    }
}

# ================================================================================================
# Common Utility Functions
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
# Package Manager Update Functions
# ================================================================================================

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

if (Test-CommandExists 'winget') {
    function wingetup {
        Write-Host "Upgrading all winget packages..." -ForegroundColor Cyan
        winget upgrade --all
        Write-Host "Winget update complete!" -ForegroundColor Green
    }

    function wlist {
        winget list | Where-Object { $_ -notmatch '^[-\s]*$' } | Select-Object -Skip 1 | Sort-Object
    }
}

if (Test-CommandExists 'choco') {
    function chocoup {
        Write-Host "Upgrading all Chocolatey packages..." -ForegroundColor Cyan
        choco upgrade all -y
        Write-Host "Cleaning up..." -ForegroundColor Cyan
        choco cache remove -y
        Write-Host "Chocolatey update complete!" -ForegroundColor Green
    }
}

if (Test-CommandExists 'mise') {
    function miseup {
        Write-Host "Upgrading mise tools..." -ForegroundColor Cyan
        mise up
        Write-Host "Cleaning up..." -ForegroundColor Cyan
        mise prune --yes
        Write-Host "Mise update complete!" -ForegroundColor Green
    }
}

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
# Modern Rust-based replacements for traditional Unix tools.
# These shadow the legacy command names so muscle memory works.
# Use the .exe name directly to bypass (e.g. find.exe, sed.exe).

# cat → bat (with tilde and glob expansion)
if (Test-CommandExists 'bat.exe') {
    Remove-Alias -Name cat -Force -ErrorAction SilentlyContinue
    
    function bat {
        $expandedPaths = @()
        foreach ($arg in $args) {
            if ($arg -match '^-') {
                $expandedPaths += $arg
                continue
            }
            if ($arg -match '^~') {
                $arg = $arg -replace '^~', $HOME
            }
            if ($arg -match '[*?\[\]]') {
                $resolved = @(Resolve-Path -Path $arg -ErrorAction SilentlyContinue)
                if ($resolved.Count -gt 0) {
                    $expandedPaths += $resolved | ForEach-Object { $_.Path }
                } else {
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

# grep → ripgrep
if (Test-CommandExists 'rg') {
    Remove-Item -Path "Alias:grep" -Force -ErrorAction SilentlyContinue
    function grep { & rg @args }
}

# ps → procs
if (Test-CommandExists 'procs') {
    Remove-Item -Path "Alias:ps" -Force -ErrorAction SilentlyContinue
    function ps { & procs @args }
}

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
        @{ Rust = 'bat';                Replaces = 'cat';              Binary = 'bat';       Invoke = @('cat') }
        @{ Rust = 'ripgrep';            Replaces = 'grep';             Binary = 'rg';        Invoke = @('grep') }
        @{ Rust = 'fd';                 Replaces = 'find';             Binary = 'fd';        Invoke = @('find') }
        @{ Rust = 'eza';                Replaces = 'ls';               Binary = 'eza';       Invoke = @('ls','ll','la','lt') }
        @{ Rust = 'delta';              Replaces = 'diff';             Binary = 'delta';     Invoke = @('diff') }
        @{ Rust = 'zoxide';             Replaces = 'cd';               Binary = 'zoxide';    Invoke = @('cd') }
        @{ Rust = 'vivid';              Replaces = 'dircolors';        Binary = 'vivid';     Invoke = @() }
        @{ Rust = 'uutils-coreutils';   Replaces = 'coreutils';        Binary = 'uname';     Invoke = @() }
        @{ Rust = 'tealdeer';           Replaces = 'tldr/man';         Binary = 'tldr';      Invoke = @('tldr','help') }
        @{ Rust = 'navi';               Replaces = 'cheatsheets';      Binary = 'navi';      Invoke = @() }
        @{ Rust = 'sd';                 Replaces = 'sed';              Binary = 'sd';        Invoke = @('sed') }
        @{ Rust = 'dust';               Replaces = 'du';               Binary = 'dust';      Invoke = @('du') }
        @{ Rust = 'procs';              Replaces = 'ps/tasklist';      Binary = 'procs';     Invoke = @('ps') }
        @{ Rust = 'hyperfine';          Replaces = 'time/benchmark';   Binary = 'hyperfine'; Invoke = @('time','bench') }
        @{ Rust = 'just';               Replaces = 'make (tasks)';     Binary = 'just';      Invoke = @() }
        @{ Rust = 'tokei';              Replaces = 'cloc/sloccount';   Binary = 'tokei';     Invoke = @('cloc') }
        @{ Rust = 'ouch';               Replaces = 'tar/zip/compress'; Binary = 'ouch';      Invoke = @('compress','decompress') }
        @{ Rust = 'xh';                 Replaces = 'curl (HTTP)';      Binary = 'xh';        Invoke = @('http','https') }
    )

    $tools | ForEach-Object {
        $installed = [bool](Get-Command $_.Binary -ErrorAction SilentlyContinue)
        $status = if ($installed) { '✓' } else { '✗' }
        $color = if ($installed) { 'Green' } else { 'Red' }
        $line = "{0} {1,-22} → {2,-22} ({3})" -f $status, $_.Rust, $_.Replaces, $_.Binary
        Write-Host $line -ForegroundColor $color -NoNewline

        if ($installed -and $_.Invoke.Count -gt 0) {
            Write-Host '   ' -NoNewline
            foreach ($cmd in $_.Invoke) {
                $active = if ($cmd -eq $_.Binary) {
                    [bool](Get-Command $cmd -ErrorAction SilentlyContinue)
                } else {
                    [bool](Get-Command $cmd -CommandType Alias, Function -ErrorAction SilentlyContinue)
                }
                $invokeColor = if ($active) { 'Green' } else { 'Red' }
                Write-Host "$cmd " -ForegroundColor $invokeColor -NoNewline
            }
        }
        Write-Host ''
    }

    $installedCount = ($tools | Where-Object { Get-Command $_.Binary -ErrorAction SilentlyContinue }).Count
    Write-Host "`n$installedCount/$($tools.Count) Rust alternatives installed" -ForegroundColor Cyan
    Write-Host 'Invoke: green = active alias, red = not configured' -ForegroundColor DarkGray
}

# ================================================================================================
# Safety Functions
# ================================================================================================
# Add confirmation prompts to destructive commands.
# Skip when uutils-coreutils is active — 05-coreutils.ps1 already exposes the real binaries.

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

# ================================================================================================
# Terminal Integration
# ================================================================================================

<#
.SYNOPSIS
    OSC7 terminal integration for WezTerm.
#>
function Set-EnvVar {
    $p = $executionContext.SessionState.Path.CurrentLocation
    $osc7 = ""
    if ($p.Provider.Name -eq "FileSystem") {
        $ansi_escape = [char]27
        $provider_path = $p.ProviderPath -Replace "\\", "/"
        $osc7 = "$ansi_escape]7;file://${env:COMPUTERNAME}/${provider_path}${ansi_escape}\"
    }
    $env:OSC7=$osc7
}

# ================================================================================================
# Backfilled from zsh 25-functions.zsh
# ================================================================================================

function up {
    param([int]$Count = 1)
    $path = '../' * $Count
    Set-Location $path
}

function sshkeygen {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Comment
    )
    ssh-keygen -t ed25519 -f "$HOME/.ssh/$Name" -C $Comment
}

function Show-AnsiColors16 {
    for ($i = 0; $i -lt 16; $i++) {
        Write-Host -NoNewline "$([char]27)[48;5;${i}m  $([char]27)[0m"
        Write-Host -NoNewline "$([char]27)[38;5;${i}m$('{0,4}' -f $i)$([char]27)[0m "
        if (($i + 1) % 8 -eq 0) { Write-Host }
    }
}
Set-Alias -Name 16colors -Value Show-AnsiColors16

function Show-AnsiColors256 {
    for ($i = 0; $i -lt 256; $i++) {
        Write-Host -NoNewline "$([char]27)[48;5;${i}m  $([char]27)[0m"
        Write-Host -NoNewline "$([char]27)[38;5;${i}m$('{0,4}' -f $i)$([char]27)[0m "
        if (($i + 1) % 8 -eq 0) { Write-Host }
    }
}
Set-Alias -Name 256colors -Value Show-AnsiColors256

# ================================================================================================
# Windows Housekeeping
# ================================================================================================

<#
.SYNOPSIS
    Remove useless Windows shell junk folders from the home directory.
    These are legacy junctions and empty folders Windows keeps recreating.
#>
function Remove-WinJunk {
    $junctions = @(
        'Recent', 'PrintHood', 'SendTo', 'Templates', 'NetHood',
        'My Documents', 'Cookies', 'Application Data', 'Local Settings', 'Start Menu'
    )
    $realDirs = @(
        'Recorded Calls', 'Links', 'Favorites', 'Searches', '3D Objects'
    )

    $removed = 0
    foreach ($name in $junctions) {
        $path = Join-Path $HOME $name
        if (Test-Path $path -PathType Container) {
            $item = Get-Item $path -Force -ErrorAction SilentlyContinue
            if ($item.LinkType -eq 'Junction') {
                cmd /c "rmdir `"$path`"" 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  removed junction: $name" -ForegroundColor DarkGray
                    $removed++
                } else {
                    Write-Warning "  could not remove junction: $name (try running as admin)"
                }
            }
        }
    }
    foreach ($name in $realDirs) {
        $path = Join-Path $HOME $name
        if (Test-Path $path -PathType Container) {
            Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  removed dir: $name" -ForegroundColor DarkGray
            $removed++
        }
    }

    if ($removed -eq 0) {
        Write-Host 'No junk found.' -ForegroundColor Green
    } else {
        Write-Host "`n$removed item(s) removed." -ForegroundColor Green
    }
}
Set-Alias -Name winjunk -Value Remove-WinJunk

<#
.SYNOPSIS
    Clear developer tool caches (npm, pnpm, yarn, pip, mise, scoop).
#>
function Clear-DevCaches {
    Write-Host "`nClearing dev caches..." -ForegroundColor Cyan

    if (Test-CommandExists 'npm') {
        Write-Host '  npm...' -NoNewline
        npm cache clean --force 2>$null
        Write-Host ' done' -ForegroundColor Green
    }
    if (Test-CommandExists 'pnpm') {
        Write-Host '  pnpm...' -NoNewline
        pnpm store prune 2>$null
        Write-Host ' done' -ForegroundColor Green
    }
    if (Test-CommandExists 'yarn') {
        Write-Host '  yarn...' -NoNewline
        yarn cache clean 2>$null
        Write-Host ' done' -ForegroundColor Green
    }
    if (Test-CommandExists 'pip') {
        Write-Host '  pip...' -NoNewline
        pip cache purge 2>$null
        Write-Host ' done' -ForegroundColor Green
    }
    if (Test-CommandExists 'mise') {
        Write-Host '  mise...' -NoNewline
        mise cache clear 2>$null
        Write-Host ' done' -ForegroundColor Green
    }
    if (Test-CommandExists 'scoop') {
        Write-Host '  scoop...' -NoNewline
        scoop cache rm * 2>$null
        Write-Host ' done' -ForegroundColor Green
    }
    if (Test-CommandExists 'go') {
        Write-Host '  go...' -NoNewline
        go clean -cache 2>$null
        Write-Host ' done' -ForegroundColor Green
    }
    Write-Host 'Dev caches cleared.' -ForegroundColor Green
}
Set-Alias -Name cleancaches -Value Clear-DevCaches

<#
.SYNOPSIS
    Clear Windows temp folders.
#>
function Clear-TempFiles {
    Write-Host "`nClearing temp files..." -ForegroundColor Cyan
    $dirs = @(
        $env:TEMP,
        "$env:LOCALAPPDATA\Temp",
        'C:\Windows\Temp'
    ) | Sort-Object -Unique

    foreach ($dir in $dirs) {
        if (Test-Path $dir) {
            Write-Host "  $dir..." -NoNewline
            $before = (Get-ChildItem $dir -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            Get-ChildItem $dir -Force -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            $after = (Get-ChildItem $dir -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            $freed = [math]::Round(($before - $after) / 1MB, 1)
            Write-Host " freed $freed MB" -ForegroundColor Green
        }
    }
}
Set-Alias -Name cleantemp -Value Clear-TempFiles

<#
.SYNOPSIS
    Flush the DNS resolver cache.
#>
function Flush-DNS {
    Write-Host "`nFlushing DNS cache..." -ForegroundColor Cyan
    ipconfig /flushdns | Out-Null
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    Write-Host 'DNS cache flushed.' -ForegroundColor Green
}
Set-Alias -Name flushdns -Value Flush-DNS

<#
.SYNOPSIS
    Compact WSL2 virtual disk(s) to reclaim disk space.
    Requires admin. Shuts down WSL first.
#>
function Compact-WSL {
    Write-Host "`nCompacting WSL virtual disks..." -ForegroundColor Cyan
    Write-Host '  Shutting down WSL...' -NoNewline
    wsl --shutdown
    Write-Host ' done' -ForegroundColor Green

    $searchPaths = @(
        "$env:LOCALAPPDATA\Packages",
        "$env:LOCALAPPDATA\lxss"
    )
    $vhdxFiles = foreach ($p in $searchPaths) {
        if (Test-Path $p) {
            Get-ChildItem $p -Filter '*.vhdx' -Recurse -ErrorAction SilentlyContinue
        }
    }

    if (-not $vhdxFiles) {
        Write-Warning 'No WSL vhdx files found.'
        return
    }

    foreach ($vhdx in $vhdxFiles) {
        $sizeBefore = [math]::Round($vhdx.Length / 1GB, 2)
        Write-Host "  Compacting $($vhdx.Name) ($sizeBefore GB)..." -NoNewline
        $script = "select vdisk file=`"$($vhdx.FullName)`"`r`nattach vdisk readonly`r`ncompact vdisk`r`ndetach vdisk`r`nexit"
        $tmp = [System.IO.Path]::GetTempFileName() + '.txt'
        $script | Set-Content $tmp -Encoding ASCII
        gsudo diskpart /s $tmp | Out-Null
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        $sizeAfter = [math]::Round((Get-Item $vhdx.FullName).Length / 1GB, 2)
        $freed = [math]::Round($sizeBefore - $sizeAfter, 2)
        Write-Host " $sizeBefore GB → $sizeAfter GB (freed $freed GB)" -ForegroundColor Green
    }
}
Set-Alias -Name compactwsl -Value Compact-WSL

<#
.SYNOPSIS
    Prune stale remote-tracking refs and delete local merged branches.
    Runs in the current git repository.
#>
function Clear-GitBranches {
    if (-not (Test-CommandExists 'git')) { Write-Warning 'git not found.'; return }
    if (-not (git rev-parse --is-inside-work-tree 2>$null)) { Write-Warning 'Not inside a git repo.'; return }

    Write-Host "`nCleaning git branches..." -ForegroundColor Cyan

    Write-Host '  Pruning remote refs...' -NoNewline
    git remote prune origin 2>$null
    Write-Host ' done' -ForegroundColor Green

    $defaultBranch = git symbolic-ref refs/remotes/origin/HEAD 2>$null
    if ($defaultBranch) {
        $defaultBranch = $defaultBranch -replace 'refs/remotes/origin/', ''
    } else {
        $defaultBranch = 'main'
    }

    $merged = git branch --merged $defaultBranch 2>$null |
        Where-Object { $_ -notmatch "^\*|$defaultBranch|master|main|develop" } |
        ForEach-Object { $_.Trim() }

    if ($merged) {
        Write-Host "  Deleting merged branches: $($merged -join ', ')" -ForegroundColor DarkGray
        $merged | ForEach-Object { git branch -d $_ }
    } else {
        Write-Host '  No merged branches to delete.' -ForegroundColor DarkGray
    }
    Write-Host 'Git branches cleaned.' -ForegroundColor Green
}
Set-Alias -Name gitclean -Value Clear-GitBranches

<#
.SYNOPSIS
    Prune Docker containers, images, and volumes.
#>
function Clear-Docker {
    if (-not (Test-CommandExists 'docker')) { Write-Warning 'docker not found.'; return }

    Write-Host "`nPruning Docker..." -ForegroundColor Cyan
    Write-Host '  Containers...' -NoNewline
    docker container prune -f 2>$null | Out-Null
    Write-Host ' done' -ForegroundColor Green
    Write-Host '  Images...' -NoNewline
    docker image prune -f 2>$null | Out-Null
    Write-Host ' done' -ForegroundColor Green
    Write-Host '  Volumes...' -NoNewline
    docker volume prune -f 2>$null | Out-Null
    Write-Host ' done' -ForegroundColor Green
    Write-Host '  Build cache...' -NoNewline
    docker builder prune -f 2>$null | Out-Null
    Write-Host ' done' -ForegroundColor Green
    Write-Host 'Docker pruned.' -ForegroundColor Green
}
Set-Alias -Name cleandocker -Value Clear-Docker

<#
.SYNOPSIS
    Rebuild the Windows icon and thumbnail cache.
    Restarts Explorer.
#>
function Rebuild-WinCache {
    Write-Host "`nRebuilding Windows icon/thumbnail cache..." -ForegroundColor Cyan

    Write-Host '  Stopping Explorer...' -NoNewline
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    Write-Host ' done' -ForegroundColor Green

    # Delete icon cache
    $iconCache = "$env:LOCALAPPDATA\IconCache.db"
    Remove-Item $iconCache -Force -ErrorAction SilentlyContinue

    # Delete thumbnail caches
    $thumbDir = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
    Get-ChildItem $thumbDir -Filter 'thumbcache_*.db' -Force -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue

    Write-Host '  Restarting Explorer...' -NoNewline
    Start-Process explorer
    Write-Host ' done' -ForegroundColor Green
    Write-Host 'Cache rebuilt.' -ForegroundColor Green
}
Set-Alias -Name rebuildiconcache -Value Rebuild-WinCache

<#
.SYNOPSIS
    Run all housekeeping tasks.
#>
function Invoke-Housekeeping {
    Write-Host "`n╔══════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║      Windows Housekeeping    ║" -ForegroundColor Magenta
    Write-Host "╚══════════════════════════════╝`n" -ForegroundColor Magenta

    Remove-WinJunk
    Clear-Cache      # temp, browsers, GPU, npm, yarn, pip, scoop, go, pnpm, mise, etc.
    Flush-DNS
    Clear-Docker
    Compact-WSL
    Rebuild-WinCache

    Write-Host "`n╔══════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║     Housekeeping complete!   ║" -ForegroundColor Magenta
    Write-Host "╚══════════════════════════════╝`n" -ForegroundColor Magenta
}
Set-Alias -Name housekeeping -Value Invoke-Housekeeping

# -------------------------------------------------------------------------------------------------
# vim: ft=ps1 sw=4 ts=4 et
# -------------------------------------------------------------------------------------------------

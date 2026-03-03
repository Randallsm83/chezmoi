# ██╗    ██╗██╗  ██╗██╗ ██████╗██╗  ██╗    ██╗  ██╗███████╗██╗   ██╗
# ██║    ██║██║  ██║██║██╔════╝██║  ██║    ██║ ██╔╝██╔════╝╚██╗ ██╔╝
# ██║ █╗ ██║███████║██║██║     ███████║    █████╔╝ █████╗   ╚████╔╝
# ██║███╗██║██╔══██║██║██║     ██╔══██║    ██╔═██╗ ██╔══╝    ╚██╔╝
# ╚███╔███╔╝██║  ██║██║╚██████╗██║  ██║    ██║  ██╗███████╗   ██║
#  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝ ╚═════╝╚═╝  ╚═╝    ╚═╝  ╚═╝╚══════╝   ╚═╝
# Terminal Which-Key: fzf-powered command discovery
# Inspired by folke/which-key.nvim

# =============================================================================
# Category Definitions
# =============================================================================

$global:_WhichKeyCategories = [ordered]@{
    'git'       = @{
        Icon    = [char]::ConvertFromUtf32(0xF02A2)  # 󰊢 nf-md-git
        Label   = 'Git'
        Prefix  = 'g'
        Prompt  = 'git> '
        # Match functions starting with g that wrap git commands
        Match   = { param($Name, $Def) $Name -match '^g[a-z]' -and $Def -match '\bgit\b' }
    }
    'fzf'       = @{
        Icon    = [char]::ConvertFromUtf32(0xF0349)  # 󰍉 nf-md-magnify
        Label   = 'Fuzzy Find'
        Prompt  = 'fzf> '
        Match   = { param($Name, $Def) $Name -in @('fh','fe','fcd','ff','fgb','fgl','fkill','fp') }
    }
    'nav'       = @{
        Icon    = [char]::ConvertFromUtf32(0xF024B)  # 󰉋 nf-md-folder
        Label   = 'Navigation'
        Prompt  = 'nav> '
        Match   = { param($Name, $Def)
            $Name -in @('..','...','....','z','zi','cdp','cdn','cdapi','cdcdn','dh','dots','notes','grt','fcd') -or
            ($Name -match '^cd' -and $Def -match 'Set-Location')
        }
    }
    'edit'      = @{
        Icon    = [char]::ConvertFromUtf32(0xF03EB)  # 󰏫 nf-md-pencil
        Label   = 'Config / Edit'
        Prompt  = 'edit> '
        Match   = { param($Name, $Def) $Name -in @('nrc','wrc','strc','aliasrc','profilerc','ep','vim','vi','fe') }
    }
    'update'    = @{
        Icon    = [char]::ConvertFromUtf32(0xF06B0)  # 󰚰 nf-md-package_up
        Label   = 'Package Updates'
        Prompt  = 'update> '
        Match   = { param($Name, $Def) $Name -match 'up$' -or $Name -in @('updateall','pwshup') }
    }
    'pipe'      = @{
        Icon    = [char]::ConvertFromUtf32(0xF0495)  # 󰒕 nf-md-filter
        Label   = 'Pipeline Helpers'
        Prompt  = 'pipe> '
        Match   = { param($Name, $Def) $Name -in @('H','T','G','L') }
    }
    'file'      = @{
        Icon    = [char]::ConvertFromUtf32(0xF0219)  # 󰈙 nf-md-file_document
        Label   = 'File / System'
        Prompt  = 'file> '
        Match   = { param($Name, $Def)
            $Name -in @('touch','mkcd','rm','cp','mv','cat','bat','ffind','sgrep','t','dud','has','paths','aliases','functions')
        }
    }
    'zoxide'    = @{
        Icon    = [char]::ConvertFromUtf32(0xF0176)  # 󰅶 nf-md-bolt
        Label   = 'Zoxide'
        Prompt  = 'zoxide> '
        Match   = { param($Name, $Def) $Name -in @('z','zi','zclean','zstats','Invoke-ZoxideClean','Get-ZoxideStats') }
    }
    'keys'      = @{
        Icon    = [char]::ConvertFromUtf32(0xF030C)  # 󰌌 nf-md-keyboard
        Label   = 'Keybindings'
        Prompt  = 'keys> '
        # Special: populated from PSReadLine, not from functions
        Match   = { $false }
    }
}

# =============================================================================
# Internal: Collect Commands
# =============================================================================

function script:Get-WhichKeyEntries {
    <#
    .SYNOPSIS
        Discover all user-defined functions, aliases, and keybindings.
        Returns a list of objects: Name, Description, Category, Type, Definition.
    #>
    $entries = [System.Collections.Generic.List[PSCustomObject]]::new()

    # --- User-defined functions (no module source) ---
    $userFunctions = Get-Command -CommandType Function -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Source -eq '' -and
            $_.Name -notmatch '^_|^prompt$|^TabExpansion|^PSConsoleHostReadLine|^Set-PoshContext|^Set-EnvVar|^__' -and
            $_.Name -notmatch '^Test-CommandExists$|^Test-DirectoryExists$|^Get-PreferredEditor$|^Get-Git' -and
            $_.Name -notmatch '^Get-WhichKey|^Format-WhichKey|^Show-WhichKey|^Invoke-WhichKey' -and
            $_.Name -notmatch '^script:|^global:' -and
            $_.Name -notmatch '^Clear-Host$|^more$|^oss$|^Pause$|^mkdir$|^cd$'
        }

    foreach ($fn in $userFunctions) {
        $name = $fn.Name
        $def = $fn.Definition

        # Get description
        $desc = Get-WhichKeyDescription -Name $name -Definition $def

        # Categorize
        $cat = Get-WhichKeyCategory -Name $name -Definition $def

        $entries.Add([PSCustomObject]@{
            Name        = $name
            Description = $desc
            Category    = $cat
            Type        = 'function'
            Definition  = $def
        })
    }

    # --- Aliases (user-defined, skip built-in powershell ones) ---
    $userAliases = Get-Alias -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Options -notmatch 'ReadOnly' -and
            $_.Name -notin @('cat','grep','which','ps','kill') -and  # handled as functions above
            $_.Name -notmatch '^%$|^\?$|^cd$|^chdir$|^clc$|^clhy$|^cli$|^clp$|^cls$|^clv$' -and
            $_.Name -notmatch '^cnsn$|^copy$|^cvpa$|^dbp$|^del$|^diff$|^dir$|^dnsn$|^ebp$' -and
            $_.Name -notmatch '^epal$|^epcsv$|^epsn$|^erase$|^etsn$|^exsn$|^fc$|^fhx$|^fl$' -and
            $_.Name -notmatch '^foreach$|^ft$|^fw$|^gal$|^gbp$|^gcb$|^gci$|^gcim$|^gcm$' -and
            $_.Name -notmatch '^gcs$|^gdr$|^gerr$|^ghy$|^gi$|^gin$|^gjb$|^gm$|^gmo$|^gp$' -and
            $_.Name -notmatch '^gpv$|^group$|^gsn$|^gsnp$|^gsv$|^gtz$|^gu$|^gv$|^gwmi$' -and
            $_.Name -notmatch '^iex$|^ihy$|^ii$|^ipal$|^ipcsv$|^ipmo$|^ipsn$|^irm$|^ise$' -and
            $_.Name -notmatch '^iwmi$|^iwr$|^measure$|^mi$|^mount$|^move$|^mp$|^nal$|^ndr$' -and
            $_.Name -notmatch '^ni$|^nmo$|^npssc$|^nsn$|^nv$|^nvim$|^ogv$|^oh$|^popd$|^pushd$' -and
            $_.Name -notmatch '^pwd$|^r$|^rbp$|^rcjb$|^rcsn$|^rd$|^rdr$|^ren$|^ri$|^rjb$' -and
            $_.Name -notmatch '^rmo$|^rni$|^rnp$|^rp$|^rsn$|^rsnp$|^rujb$|^rvpa$|^rwmi$' -and
            $_.Name -notmatch '^sajb$|^sal$|^saps$|^sasv$|^sbp$|^sc$|^scb$|^select$|^set$' -and
            $_.Name -notmatch '^shcm$|^si$|^sl$|^sleep$|^sls$|^sort$|^sp$|^spjb$|^spps$' -and
            $_.Name -notmatch '^spsv$|^start$|^stz$|^sv$|^swmi$|^tee$|^trcm$|^type$|^where$' -and
            $_.Name -notmatch '^wjb$|^write$'
        }

    foreach ($al in $userAliases) {
        $name = $al.Name
        $target = $al.Definition
        $def = "→ $target"

        # Check if target already collected as function
        $existingFn = $entries | Where-Object { $_.Name -eq $target -and $_.Type -eq 'function' }
        if ($existingFn) { continue }

        $cat = Get-WhichKeyCategory -Name $name -Definition $target

        $entries.Add([PSCustomObject]@{
            Name        = $name
            Description = $def
            Category    = $cat
            Type        = 'alias'
            Definition  = $target
        })
    }

    # --- PSReadLine Keybindings ---
    try {
        $keys = Get-PSReadLineKeyHandler -Bound -ErrorAction SilentlyContinue
        foreach ($k in $keys) {
            $keyStr = $k.Key
            $func = $k.Function
            $desc = if ($k.Description) { $k.Description } else { $func }

            $entries.Add([PSCustomObject]@{
                Name        = $keyStr
                Description = "$func — $desc"
                Category    = 'keys'
                Type        = 'keybinding'
                Definition  = $desc
            })
        }
    } catch {}

    return $entries
}

# =============================================================================
# Internal: Description Extraction
# =============================================================================

function script:Get-WhichKeyDescription {
    param(
        [string]$Name,
        [string]$Definition
    )

    # 1. Try comment-based help synopsis
    try {
        $help = Get-Help $Name -ErrorAction SilentlyContinue
        if ($help -and $help.Synopsis) {
            $synopsis = $help.Synopsis.Trim()
            # Skip if synopsis is just the function name (no real help defined)
            if ($synopsis -and $synopsis -ne $Name -and $synopsis -ne '') {
                if ($synopsis.Length -gt 60) { $synopsis = $synopsis.Substring(0, 57) + '...' }
                return $synopsis
            }
        }
    } catch {}

    # 2. For git wrappers: extract git subcommand
    if ($Definition -match '^\s*git\s+(.+?)(\s+\$args)?\s*$') {
        $gitCmd = $Matches[1] -replace '\$args\s*$', '' |
            ForEach-Object { $_.Trim() } |
            ForEach-Object { $_ -replace '\s+', ' ' }
        return "git $gitCmd"
    }

    # 3. For Set-Location wrappers
    if ($Definition -match 'Set-Location\s+[''"]?(.+?)[''"]?\s*$') {
        $path = $Matches[1] -replace '\$env:', '' -replace '"', ''
        return "cd $path"
    }

    return ''
}

# =============================================================================
# Internal: Categorization
# =============================================================================

function script:Get-WhichKeyCategory {
    param(
        [string]$Name,
        [string]$Definition
    )

    foreach ($kvp in $global:_WhichKeyCategories.GetEnumerator()) {
        $cat = $kvp.Value
        if ($cat.Match -and (& $cat.Match $Name $Definition)) {
            return $kvp.Key
        }
    }

    return 'misc'
}

# =============================================================================
# Internal: Format Entry for fzf
# =============================================================================

function script:Format-WhichKeyEntry {
    param([PSCustomObject]$Entry)

    $cat = $Entry.Category
    $catInfo = $global:_WhichKeyCategories[$cat]
    $icon = if ($catInfo) { $catInfo.Icon } else { [char]::ConvertFromUtf32(0xF01D8) }  # nf-md-help_circle
    $label = if ($catInfo) { $catInfo.Label } else { 'Misc' }

    # ANSI colors (spaceduck palette)
    $cyan    = "`e[36m"
    $green   = "`e[32m"
    $yellow  = "`e[33m"
    $magenta = "`e[35m"
    $dim     = "`e[2m"
    $reset   = "`e[0m"

    $typeTag = switch ($Entry.Type) {
        'function'   { "${magenta}fn${reset}" }
        'alias'      { "${yellow}al${reset}" }
        'keybinding' { "${cyan}kb${reset}" }
        default      { "${dim}--${reset}" }
    }

    $name = "${green}$($Entry.Name)${reset}"
    # Strip any newlines/CRs from description to prevent fzf line leaking
    $cleanDesc = if ($Entry.Description) {
        ($Entry.Description -replace '[\r\n]+', ' ').Trim()
    } else { '' }
    # Truncate to keep lines single-row in fzf
    if ($cleanDesc.Length -gt 50) { $cleanDesc = $cleanDesc.Substring(0, 47) + '...' }
    $desc = if ($cleanDesc) { "${dim}── ${cleanDesc}${reset}" } else { '' }
    $catTag = "${cyan}${icon} ${label}${reset}"

    return "${catTag}`t${typeTag} ${name}  ${desc}"
}

# =============================================================================
# Internal: Preview Script (shows help or definition)
# =============================================================================

function script:Get-WhichKeyPreviewScript {
    # Returns a PowerShell command string for fzf --preview
    # The selected line is passed as {}, we extract the command name from it
    @'
$line = $args[0]
# Strip ANSI codes
$clean = $line -replace '\e\[[0-9;]*m', ''
# Extract the command name (after the type tag, before the description)
$parts = ($clean -split '\t', 2)
if ($parts.Count -ge 2) {
    $rest = $parts[1].Trim()
    # Type tag is 2 chars, then space, then name
    if ($rest -match '^[a-z]{2}\s+(\S+)') {
        $cmdName = $Matches[1]
    } else {
        $cmdName = ($rest -split '\s+')[0]
    }
} else {
    $cmdName = ($clean -split '\s+' | Where-Object { $_ })[0]
}
if (-not $cmdName) { Write-Host "No command selected"; exit }
# Try Get-Help first
$help = Get-Help $cmdName -ErrorAction SilentlyContinue
if ($help -and $help.Synopsis -and $help.Synopsis -ne $cmdName) {
    Write-Host "━━━ $cmdName ━━━" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "SYNOPSIS" -ForegroundColor Yellow
    Write-Host "  $($help.Synopsis)"
    Write-Host ""
    if ($help.syntax) {
        Write-Host "SYNTAX" -ForegroundColor Yellow
        Write-Host "  $($help.syntax | Out-String)".Trim()
        Write-Host ""
    }
}
# Show function definition
$cmd = Get-Command $cmdName -ErrorAction SilentlyContinue
if ($cmd -and $cmd.CommandType -eq 'Function') {
    Write-Host "DEFINITION" -ForegroundColor Yellow
    $def = $cmd.Definition.Trim()
    if ($def.Length -gt 800) { $def = $def.Substring(0, 800) + "`n..." }
    Write-Host "  $def"
} elseif ($cmd -and $cmd.CommandType -eq 'Alias') {
    Write-Host "ALIAS" -ForegroundColor Yellow
    Write-Host "  $cmdName → $($cmd.Definition)"
}
'@
}

# =============================================================================
# Public: wk — Which-Key Entry Point
# =============================================================================

<#
.SYNOPSIS
    Terminal Which-Key: discover and execute commands interactively.
.DESCRIPTION
    Inspired by folke/which-key.nvim. Shows all custom aliases, functions,
    and keybindings grouped by category with descriptions.

    Usage:
      wk           Show category groups, drill into one
      wk <prefix>  Jump to commands matching prefix (e.g. wk g → git)
      wk --all     Flat list of everything, fully searchable
      wk --keys    Show only keybindings
      wk --help    Show this help
.EXAMPLE
    wk
    wk g
    wk --all
#>
function wk {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, ValueFromRemainingArguments)]
        [string[]]$Filter
    )

    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
        Write-Warning "wk requires fzf. Install with: scoop install fzf"
        return
    }

    # Parse flags
    $showAll  = $Filter -contains '--all'
    $showKeys = $Filter -contains '--keys'
    $showHelp = $Filter -contains '--help'
    $prefix   = ($Filter | Where-Object { $_ -notmatch '^--' }) -join ' '

    if ($showHelp) {
        Get-Help wk -Detailed
        return
    }

    # Collect all entries
    $entries = Get-WhichKeyEntries

    if ($showKeys) {
        $filtered = $entries | Where-Object { $_.Category -eq 'keys' }
        $selected = Show-WhichKeyFzf -Entries $filtered -Header '󰌌 Keybindings' -Prompt 'keys> '
        if ($selected) { Invoke-WhichKeySelection $selected $entries }
        return
    }

    if ($showAll -or $prefix) {
        # Flat mode: show all or filter by prefix
        $filtered = $entries | Where-Object { $_.Type -ne 'keybinding' }
        if ($prefix) {
            $filtered = $filtered | Where-Object { $_.Name -like "$prefix*" -or $_.Category -eq $prefix }
        }

        $header = if ($prefix) { "Commands matching: $prefix*" } else { 'All Commands' }
        $prompt = if ($prefix) {
            $catInfo = $global:_WhichKeyCategories[$prefix]
            if ($catInfo) { $catInfo.Prompt } else { "wk $prefix> " }
        } else { 'wk> ' }

        $selected = Show-WhichKeyFzf -Entries $filtered -Header $header -Prompt $prompt
        if ($selected) { Invoke-WhichKeySelection $selected $entries }
        return
    }

    # --- Hierarchical mode: show categories first ---
    Show-WhichKeyCategories -Entries $entries
}

# =============================================================================
# Internal: Category Browser (Level 1)
# =============================================================================

function script:Show-WhichKeyCategories {
    param(
        [PSCustomObject[]]$Entries
    )

    $cyan    = "`e[36m"
    $green   = "`e[32m"
    $yellow  = "`e[33m"
    $dim     = "`e[2m"
    $bold    = "`e[1m"
    $reset   = "`e[0m"

    # Build category summary lines
    $catLines = [System.Collections.Generic.List[string]]::new()

    foreach ($kvp in $global:_WhichKeyCategories.GetEnumerator()) {
        $catKey = $kvp.Key
        $catInfo = $kvp.Value
        $count = ($Entries | Where-Object { $_.Category -eq $catKey }).Count
        if ($count -eq 0 -and $catKey -ne 'keys') { continue }

        $icon  = $catInfo.Icon
        $label = $catInfo.Label
        $pfx   = if ($catInfo.Prefix) { $catInfo.Prefix } else { $catKey }

        $catLines.Add("${cyan}${icon}${reset}  ${bold}${green}${pfx}${reset}`t${label}  ${dim}(${count})${reset}")
    }

    # Also add misc if any
    $miscCount = ($Entries | Where-Object { $_.Category -eq 'misc' }).Count
    if ($miscCount -gt 0) {
        $miscIcon = [char]::ConvertFromUtf32(0xF01D8)  # 󰇘 nf-md-help_circle
        $catLines.Add("${cyan}${miscIcon}${reset}  ${bold}${green}misc${reset}`tMiscellaneous  ${dim}(${miscCount})${reset}")
    }

    $header = "Which-Key  ·  Select a category or type to search"

    # Loop so Esc at level 2 returns to category list instead of exiting
    while ($true) {
        $selected = $catLines | fzf --ansi --no-sort --header $header --prompt 'wk> ' `
            --preview-window=right:40%:wrap `
            --expect='enter' `
            --bind 'ctrl-j:down,ctrl-k:up,ctrl-n:down,ctrl-p:up'

        # Esc at level 1 → exit completely
        if (-not $selected) { return }

        # Parse selection — extract the category key (the green prefix text)
        $lines = $selected -split "`n" | Where-Object { $_.Trim() }
        $key = if ($lines.Count -ge 2) { $lines[1] } else { $lines[0] }

        # Strip ANSI and extract prefix
        $clean = $key -replace '\e\[[0-9;]*m', ''
        $parts = ($clean -split '\t', 2)
        $catPrefix = ($parts[0].Trim() -split '\s+' | Select-Object -Last 1).Trim()

        if (-not $catPrefix) { continue }

        # Drill into that category
        $catEntries = $Entries | Where-Object {
            $_.Category -eq $catPrefix -or
            ($global:_WhichKeyCategories.Contains($catPrefix) -and $_.Category -eq $catPrefix) -or
            ($catPrefix -eq 'misc' -and $_.Category -eq 'misc')
        }

        # If we didn't match a category key, try matching as a prefix filter
        if ($catEntries.Count -eq 0) {
            $catEntries = $Entries | Where-Object { $_.Name -like "$catPrefix*" }
        }

        $catInfo = $global:_WhichKeyCategories[$catPrefix]
        $catHeader = if ($catInfo) { "$($catInfo.Icon) $($catInfo.Label)  ← Esc to go back" } else { "Commands: $catPrefix  ← Esc to go back" }
        $prompt = if ($catInfo) { $catInfo.Prompt } else { "$catPrefix> " }

        $cmdSelected = Show-WhichKeyFzf -Entries $catEntries -Header $catHeader -Prompt $prompt
        if ($cmdSelected) {
            Invoke-WhichKeySelection $cmdSelected $Entries
            return
        }
        # Esc at level 2 → loop back to category list
    }
}

# =============================================================================
# Internal: fzf Display
# =============================================================================

function script:Show-WhichKeyFzf {
    param(
        [PSCustomObject[]]$Entries,
        [string]$Header = 'Which-Key',
        [string]$Prompt = 'wk> '
    )

    if (-not $Entries -or $Entries.Count -eq 0) {
        Write-Host "No commands found." -ForegroundColor Yellow
        return $null
    }

    $lines = $Entries | ForEach-Object { Format-WhichKeyEntry $_ }

    # Write entry data to temp file so preview can read it without needing profile
    $dataFile = Join-Path $env:TEMP 'wk-entries.json'
    $entryMap = @{}
    foreach ($e in $Entries) {
        # Clean CR/LF from definitions and descriptions for clean JSON + preview
        $defSnippet = ($e.Definition -replace '\r', '') 
        if ($defSnippet.Length -gt 800) { $defSnippet = $defSnippet.Substring(0, 800) + '...' }
        $cleanDesc = ($e.Description -replace '[\r\n]+', ' ').Trim()
        $entryMap[$e.Name] = @{
            desc = $cleanDesc
            type = $e.Type
            cat  = $e.Category
            def  = $defSnippet
        }
    }
    $entryMap | ConvertTo-Json -Depth 3 -Compress | Set-Content -Path $dataFile -Force

    # Preview script reads from the temp JSON
    $previewScript = Join-Path $env:TEMP 'wk-preview.ps1'
    $previewScriptContent = @'
Param($line)
$dataFile = Join-Path $env:TEMP 'wk-entries.json'
if (-not (Test-Path $dataFile)) { Write-Host 'No data'; exit }
$data = Get-Content $dataFile -Raw | ConvertFrom-Json
$clean = $line -replace '\e\[[0-9;]*m', ''
$parts = ($clean -split '\t', 2)
if ($parts.Count -ge 2) {
    $rest = $parts[1].Trim()
    $tokens = ($rest -split '\s+')
    $cmdName = if ($tokens.Count -ge 2) { $tokens[1] } else { $tokens[0] }
} else {
    $cmdName = ($clean.Trim() -split '\s+')[0]
}
if (-not $cmdName) { Write-Host 'Select a command'; exit }
$entry = $data.$cmdName
Write-Host "=== $cmdName ===" -ForegroundColor Cyan
Write-Host ""
if ($entry) {
    $typeLabel = switch ($entry.type) {
        'function'   { 'Function' }
        'alias'      { 'Alias' }
        'keybinding' { 'Keybinding' }
        default      { $entry.type }
    }
    Write-Host "TYPE        " -NoNewline -ForegroundColor Yellow
    Write-Host $typeLabel
    Write-Host "CATEGORY    " -NoNewline -ForegroundColor Yellow
    Write-Host $entry.cat
    if ($entry.desc) {
        Write-Host ""
        Write-Host "DESCRIPTION" -ForegroundColor Yellow
        Write-Host "  $($entry.desc)"
    }
    if ($entry.def -and $entry.type -ne 'keybinding') {
        Write-Host ""
        Write-Host "DEFINITION" -ForegroundColor Yellow
        $entry.def -split "`n" | ForEach-Object { Write-Host "  $_" }
    }
} else {
    Write-Host "No details available" -ForegroundColor DarkGray
}
'@
    Set-Content -Path $previewScript -Value $previewScriptContent -Force
    $previewCmd = "pwsh -NoProfile -File `"$previewScript`" {}"

    $selected = $lines | fzf --ansi --no-sort `
        --header $Header `
        --prompt $Prompt `
        --preview $previewCmd `
        --preview-window=right:50%:wrap `
        --tabstop=4 `
        --bind 'ctrl-j:down,ctrl-k:up,ctrl-n:down,ctrl-p:up'

    return $selected
}

# =============================================================================
# Internal: Execute Selection
# =============================================================================

function script:Invoke-WhichKeySelection {
    param(
        [string]$Selected,
        [PSCustomObject[]]$AllEntries
    )

    if (-not $Selected) { return }

    # Strip ANSI codes
    $clean = $Selected -replace '\e\[[0-9;]*m', ''

    # Extract command name from the formatted line
    # Format: "icon label<TAB>type name  -- desc"
    $parts = ($clean -split '\t', 2)
    if ($parts.Count -ge 2) {
        $rest = $parts[1].Trim()
        $tokens = ($rest -split '\s+')
        $cmdName = if ($tokens.Count -ge 2) { $tokens[1] } else { $tokens[0] }
    } else {
        $cmdName = ($clean -split '\s+' | Where-Object { $_ })[0]
    }

    if (-not $cmdName) {
        Write-Warning "Could not parse command from selection"
        return
    }

    # Find the entry
    $entry = $AllEntries | Where-Object { $_.Name -eq $cmdName } | Select-Object -First 1

    if (-not $entry) {
        Write-Warning "Command not found: $cmdName"
        return
    }

    # Determine if command takes arguments by checking for $args in definition
    $takesArgs = $entry.Definition -match '\$args' -or $entry.Definition -match '\[Parameter'

    if ($takesArgs) {
        # Insert into command line for user to add arguments
        try {
            [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert($cmdName + ' ')
        } catch {
            # Fallback: just print the command name
            Write-Host "`nCommand: " -NoNewline -ForegroundColor Cyan
            Write-Host $cmdName -ForegroundColor Green
            Write-Host "  (takes arguments — type it to run)" -ForegroundColor DarkGray
        }
    } else {
        # Execute directly
        Write-Host "→ $cmdName" -ForegroundColor DarkGray
        & $cmdName
    }
}

# vim: ts=2 sts=2 sw=2 et

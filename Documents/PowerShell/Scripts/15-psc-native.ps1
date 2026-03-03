# ╔═╗╔═╗╔═╗  ┌┐┌┌─┐┌┬┐┬┬  ┬┌─┐
# ╠═╝╚═╗║    │││├─┤ │ │└┐┌┘├┤
# ╩  ╚═╝╚═╝  ┘└┘┴ ┴ ┴ ┴ └┘ └─┘
# Bridge PSCompletions data to native Register-ArgumentCompleter
# so completions work in terminals without psc's custom menu (e.g., Warp)

$pscRoot = "$HOME\scoop\modules\PSCompletions\completions"
if (-not (Test-Path $pscRoot)) { return }

# Commands that already have dedicated native completions — skip these
$completionsDir = Join-Path (Split-Path $PROFILE) "Completions"
$existing = @()
if (Test-Path $completionsDir) {
    $existing = @(Get-ChildItem "$completionsDir\*.ps1" -EA SilentlyContinue | ForEach-Object { $_.BaseName })
}

# Global store for parsed completion trees (keyed by command name)
if (-not (Get-Variable '__psc_trees' -Scope Global -EA SilentlyContinue)) {
    $global:__psc_trees = @{}
}

function Get-ShortTip {
    <# Extract a concise single-line tooltip from a psc tip array.
       Skips usage (U:) and example (E:) lines, returns the first description. #>
    param([array]$TipLines)
    if (-not $TipLines) { return '' }
    foreach ($line in $TipLines) {
        if (-not $line) { continue }
        $trimmed = $line.Trim()
        if ($trimmed -match '^U:' -or $trimmed -match '^E:' -or $trimmed -match '^\s+') { continue }
        return $trimmed
    }
    # Fallback: return first non-empty line stripped of prefix
    foreach ($line in $TipLines) {
        if ($line) { return ($line.Trim() -replace '^[UE]:\s*', '') }
    }
    return ''
}

function ConvertTo-CompletionTree {
    <#
    .SYNOPSIS
        Recursively converts the psc JSON structure into a hashtable tree.
        Each node has: tip (string), subs (hashtable of child nodes), opts (array of option hashtables)
    #>
    param(
        [array]$Items,
        [array]$Options,
        [array]$CommonOptions
    )

    $node = @{ subs = @{}; opts = [System.Collections.Generic.List[hashtable]]::new() }

    # Process subcommands
    foreach ($item in $Items) {
        if (-not $item.name) { continue }
        $child = @{ tip = (Get-ShortTip $item.tip) }

        # Recurse into nested subcommands (recursion already includes common_options)
        $needsCommonOpts = $true
        if ($item.next -is [array] -and $item.next.Count -gt 0) {
            $inner = ConvertTo-CompletionTree -Items $item.next -Options $item.options -CommonOptions $CommonOptions
            $child.subs = $inner.subs
            $child.opts = $inner.opts
            $needsCommonOpts = $false  # already added by recursive call
        }
        elseif ($item.options) {
            $child.subs = @{}
            $child.opts = [System.Collections.Generic.List[hashtable]]::new()
            foreach ($opt in $item.options) {
                $optTip = (Get-ShortTip $opt.tip)
                $child.opts.Add(@{ name = $opt.name; tip = $optTip })
                foreach ($a in $opt.alias) {
                    $child.opts.Add(@{ name = $a; tip = $optTip })
                }
                # Option value completions (next array with named items)
                if ($opt.next -is [array] -and $opt.next.Count -gt 0) {
                    foreach ($val in $opt.next) {
                        if ($val.name) {
                            $valTip = (Get-ShortTip $val.tip)
                            $child.subs[$val.name] = @{ tip = $valTip; subs = @{}; opts = [System.Collections.Generic.List[hashtable]]::new() }
                        }
                    }
                }
            }
        }
        else {
            if (-not $child.subs) { $child.subs = @{} }
            if (-not $child.opts) { $child.opts = [System.Collections.Generic.List[hashtable]]::new() }
        }

        # Add common options only if not already included by recursion
        if ($needsCommonOpts) {
            foreach ($copt in $CommonOptions) {
            $coptTip = (Get-ShortTip $copt.tip)
            $child.opts.Add(@{ name = $copt.name; tip = $coptTip })
            foreach ($a in $copt.alias) {
                $child.opts.Add(@{ name = $a; tip = $coptTip })
            }
            }
        }

        $node.subs[$item.name] = $child
        # Register aliases
        foreach ($a in $item.alias) {
            $node.subs[$a] = $child
        }
    }

    # Top-level options
    foreach ($opt in $Options) {
        $optTip = (Get-ShortTip $opt.tip)
        $node.opts.Add(@{ name = $opt.name; tip = $optTip })
        foreach ($a in $opt.alias) {
            $node.opts.Add(@{ name = $a; tip = $optTip })
        }
    }

    # Common options at this level too
    foreach ($copt in $CommonOptions) {
        $coptTip = (Get-ShortTip $copt.tip)
        $node.opts.Add(@{ name = $copt.name; tip = $coptTip })
        foreach ($a in $copt.alias) {
            $node.opts.Add(@{ name = $a; tip = $coptTip })
        }
    }

    return $node
}

# Shared scriptblock for all psc-backed completers
$pscNativeCompleter = {
    param($wordToComplete, $commandAst, $cursorPosition)

    $words = @($commandAst.CommandElements | ForEach-Object { $_.ToString() })
    $cmdName = $words[0]

    $tree = $global:__psc_trees[$cmdName]
    if (-not $tree) { return }

    # Walk the tree: skip the command name, follow subcommands
    # When wordToComplete is empty, the cursor is after a space — all words are completed.
    # When non-empty, the last word is being typed and should NOT be walked.
    $node = $tree
    $walkEnd = if ($wordToComplete -eq '') { $words.Count } else { $words.Count - 1 }
    for ($i = 1; $i -lt $walkEnd; $i++) {
        $w = $words[$i]
        if ($w.StartsWith('-')) { continue }
        if ($node.subs -and $node.subs.ContainsKey($w)) {
            $node = $node.subs[$w]
        }
    }

    $results = [System.Collections.Generic.List[System.Management.Automation.CompletionResult]]::new()
    $wc = $wordToComplete.ToLower()

    # Offer subcommands
    if ($node.subs) {
        foreach ($key in $node.subs.Keys) {
            if ($key.ToLower().StartsWith($wc)) {
                $tip = if ($node.subs[$key].tip) { $node.subs[$key].tip } else { $key }
                $results.Add([System.Management.Automation.CompletionResult]::new(
                    $key, $key, 'ParameterValue', $tip
                ))
            }
        }
    }

    # Offer options/flags
    if ($node.opts) {
        foreach ($opt in $node.opts) {
            if ($opt.name.ToLower().StartsWith($wc)) {
                $tip = if ($opt.tip) { $opt.tip } else { $opt.name }
                $results.Add([System.Management.Automation.CompletionResult]::new(
                    $opt.name, $opt.name, 'ParameterName', $tip
                ))
            }
        }
    }

    return $results
}

# Process each psc completion directory
foreach ($dir in (Get-ChildItem $pscRoot -Directory)) {
    $cmdName = $dir.Name

    # Skip commands with dedicated native completers
    if ($cmdName -in $existing) { continue }

    $jsonPath = Join-Path $dir.FullName "language\en-US.json"
    if (-not (Test-Path $jsonPath)) { continue }

    try {
        $data = Get-Content -Raw $jsonPath -Encoding utf8 | ConvertFrom-Json
    }
    catch { continue }

    $tree = ConvertTo-CompletionTree `
        -Items      @($data.root) `
        -Options    @($data.options) `
        -CommonOptions @($data.common_options)

    $global:__psc_trees[$cmdName] = $tree

    # Determine all command names (primary + aliases from psc list)
    $cmdNames = @($cmdName)

    Register-ArgumentCompleter -Native -CommandName $cmdNames -ScriptBlock $pscNativeCompleter
}

# vim: ts=2 sts=2 sw=2 et

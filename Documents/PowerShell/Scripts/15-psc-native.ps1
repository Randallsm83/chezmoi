# ╔═╗╔═╗╔═╗  ┌┐┌┌─┐┌┬┐┬┬  ┬┌─┐
# ╠═╝╚═╗║    │││├─┤ │ │└┐┌┘├┤
# ╩  ╚═╝╚═╝  ┘└┘┴ ┴ ┴ ┴ └┘ └─┘
# Bridge PSCompletions data to native Register-ArgumentCompleter
# so completions work in terminals without psc's custom menu (e.g., Warp).
#
# The parsed completion-tree hashtable is CACHED to disk via Export-Clixml.
# Rebuilds only when the psc completions root (or any of its subdirs) is
# newer than the cache.

$pscRoot = "$HOME\scoop\modules\PSCompletions\completions"
if (-not (Test-Path $pscRoot)) { return }

# JSON cache (NOT clixml). Export-Clixml + Import-Clixml roundtrips hashtables
# through `Deserialized.System.Collections.Hashtable` proxies; their `.Keys`
# enumeration yields PSObject wrappers, not raw strings, and silently breaks
# `.ToLower().StartsWith(...)` inside argument-completer scriptblocks (errors
# are swallowed by the completer host). ConvertFrom-Json -AsHashtable gives
# real [hashtable]/[string] types every load. See: bridge was returning 0
# matches for `git che` even though $global:__psc_trees['git'].subs had 140
# entries.
$pscCacheFile = Join-Path $env:XDG_CACHE_HOME "powershell\psc-trees.json"
$pscCacheDir = Split-Path $pscCacheFile
if (-not (Test-Path $pscCacheDir)) {
    New-Item -ItemType Directory -Path $pscCacheDir -Force | Out-Null
}

# Commands that already have dedicated native completions — skip these
$completionsDir = Join-Path (Split-Path $PROFILE) "Completions"
$existing = @()
if (Test-Path $completionsDir) {
    $existing = @(Get-ChildItem "$completionsDir\*.ps1" -EA SilentlyContinue | ForEach-Object { $_.BaseName })
}

# Cache invalidation: rebuild if cache missing or if any psc completion dir
# has been modified since the cache was last written.
$pscRebuild = -not (Test-Path $pscCacheFile)
if (-not $pscRebuild) {
    $pscCacheTime = (Get-Item $pscCacheFile).LastWriteTime
    $pscRootMtime = (Get-Item $pscRoot).LastWriteTime
    if ($pscRootMtime -gt $pscCacheTime) {
        $pscRebuild = $true
    } else {
        $latestSub = (Get-ChildItem $pscRoot -Directory -EA SilentlyContinue |
            ForEach-Object { $_.LastWriteTime } |
            Measure-Object -Maximum).Maximum
        if ($latestSub -and $latestSub -gt $pscCacheTime) {
            $pscRebuild = $true
        }
    }
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

# Shared scriptblock for all psc-backed completers.
#
# All string operations explicitly coerce inputs to [string] because:
# - $commandAst.CommandElements yields AST nodes that ToString() correctly,
#   but the result must still be wrapped
# - $node.subs.Keys can be a generic ICollection (real hashtable) OR a
#   deserialized proxy; iterating directly may yield PSObject wrappers
#   whose .ToLower() lookup goes through ETS resolution and silently fails
#   inside Register-ArgumentCompleter scriptblocks (errors swallowed).
# - .StartsWith on a PSObject can return a PSObject<bool> which evaluates
#   truthy in some contexts and not others.
#
# `[string]$x` and `[string[]]@(...)` force a clean type before any method
# call. This is the difference between getting 0 matches and getting the
# correct list.
$pscNativeCompleter = {
    param($wordToComplete, $commandAst, $cursorPosition)

    $words = @($commandAst.CommandElements | ForEach-Object { [string]$_ })
    if ($words.Count -eq 0) { return }
    $cmdName = [string]$words[0]

    $tree = $global:__psc_trees[$cmdName]
    if (-not $tree) { return }

    # Walk the tree: skip the command name, follow subcommands.
    # When wordToComplete is empty, the cursor is after a space — every
    # word in $words has been fully entered. When non-empty, the LAST word
    # is being typed and must NOT be consumed by the walk.
    $wc = ([string]$wordToComplete).ToLower()
    $node = $tree
    $walkEnd = if ($wc -eq '') { $words.Count } else { $words.Count - 1 }
    for ($i = 1; $i -lt $walkEnd; $i++) {
        $w = [string]$words[$i]
        if ($w.StartsWith('-')) { continue }
        $subs = $node.subs
        if ($subs) {
            $match = $null
            foreach ($k in @($subs.Keys)) {
                if ([string]$k -eq $w) { $match = [string]$k; break }
            }
            if ($match) { $node = $subs[$match] }
        }
    }

    $results = [System.Collections.Generic.List[System.Management.Automation.CompletionResult]]::new()

    # Offer subcommands matching the partial word
    if ($node.subs) {
        foreach ($k in @($node.subs.Keys)) {
            $key = [string]$k
            if ($key.ToLower().StartsWith($wc)) {
                $childTip = [string]$node.subs[$key].tip
                $tip = if ($childTip) { $childTip } else { $key }
                $results.Add([System.Management.Automation.CompletionResult]::new(
                    $key, $key, 'ParameterValue', $tip
                ))
            }
        }
    }

    # Offer options/flags matching the partial word
    if ($node.opts) {
        foreach ($opt in @($node.opts)) {
            $optName = [string]$opt.name
            if ($optName.ToLower().StartsWith($wc)) {
                $optTip = [string]$opt.tip
                $tip = if ($optTip) { $optTip } else { $optName }
                $results.Add([System.Management.Automation.CompletionResult]::new(
                    $optName, $optName, 'ParameterName', $tip
                ))
            }
        }
    }

    return $results
}

# Expose the scriptblock globally so other completers (e.g., git-aliases.ps1)
# can chain back to psc for subcommand/option completion after handling their
# own dynamic cases (refs, remotes, files).
$global:__pscNativeCompleter = $pscNativeCompleter

if ($pscRebuild) {
    # Walk every psc completion directory, parse JSON, build hashtable trees.
    $trees = @{}
    foreach ($dir in (Get-ChildItem $pscRoot -Directory)) {
        $cmdName = $dir.Name
        if ($cmdName -in $existing) { continue }

        $jsonPath = Join-Path $dir.FullName "language\en-US.json"
        if (-not (Test-Path $jsonPath)) { continue }

        try {
            $data = Get-Content -Raw $jsonPath -Encoding utf8 | ConvertFrom-Json
        }
        catch { continue }

        $tree = ConvertTo-CompletionTree `
            -Items         @($data.root) `
            -Options       @($data.options) `
            -CommonOptions @($data.common_options)

        $trees[$cmdName] = $tree
    }

    $global:__psc_trees = $trees
    try {
        $trees | ConvertTo-Json -Depth 100 -Compress | Set-Content -Path $pscCacheFile -Encoding utf8 -NoNewline
    } catch {
        Write-Verbose "psc-trees cache write failed: $($_.Exception.Message)"
    }
} else {
    try {
        $global:__psc_trees = Get-Content -Raw -Path $pscCacheFile -Encoding utf8 |
            ConvertFrom-Json -AsHashtable -Depth 100
    } catch {
        Write-Verbose "psc-trees cache load failed; ignoring: $($_.Exception.Message)"
        $global:__psc_trees = @{}
    }
}

# Register native ArgumentCompleter for every command we have a tree for.
foreach ($cmdName in $global:__psc_trees.Keys) {
    Register-ArgumentCompleter -Native -CommandName $cmdName -ScriptBlock $pscNativeCompleter
}

# vim: ts=2 sts=2 sw=2 et

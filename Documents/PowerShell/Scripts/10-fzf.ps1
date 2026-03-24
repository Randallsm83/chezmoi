# ███████╗███████╗███████╗
# ██╔════╝╚══███╔╝██╔════╝
# █████╗    ███╔╝ █████╗
# ██╔══╝   ███╔╝  ██╔══╝
# ██║     ███████╗██║
# ╚═╝     ╚══════╝╚═╝
# Command-line fuzzy finder.
# https://github.com/junegunn/fzf

# FZF Configuration for PowerShell

if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) { return }

# Colors matching spaceduck theme
$env:FZF_DEFAULT_OPTS = @"
--color=bg+:#1b1c36,bg:#0f111b,spinner:#00a3cc,hl:#b3a1e6
--color=fg:#f0f1ce,header:#00a3cc,info:#5ccc96,pointer:#e33400
--color=marker:#f2ce00,fg+:#f0f1ce,prompt:#00a3cc,hl+:#b3a1e6
--border --height=40% --layout=reverse --info=inline
--margin=1 --padding=1
"@

# Use fd or ripgrep for file searching
if (Get-Command fd -ErrorAction SilentlyContinue) {
    $env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --follow --exclude .git'
    $env:FZF_CTRL_T_COMMAND = $env:FZF_DEFAULT_COMMAND
    $env:FZF_ALT_C_COMMAND = 'fd --type d --hidden --follow --exclude .git'
} elseif (Get-Command rg -ErrorAction SilentlyContinue) {
    $env:FZF_DEFAULT_COMMAND = 'rg --files --hidden --follow --glob "!.git/*"'
    $env:FZF_CTRL_T_COMMAND = $env:FZF_DEFAULT_COMMAND
}

# Ctrl+T preview with bat
if (Get-Command bat -ErrorAction SilentlyContinue) {
    $env:FZF_CTRL_T_OPTS = "--preview 'bat --color=always --style=numbers --line-range=:500 {}' --preview-window=right:60%:wrap"
}

# Alt+C preview with eza tree
if (Get-Command eza -ErrorAction SilentlyContinue) {
    $env:FZF_ALT_C_OPTS = "--preview 'eza --tree --level=2 --color=always {}' --preview-window=right:60%"
}

# Initialize PSFzf module if available
if (Get-Module -ListAvailable -Name PSFzf) {
    Import-Module PSFzf -ErrorAction SilentlyContinue
    
    if (Get-Module PSFzf) {
        # Set keybindings - use explicit PSReadLineKeyHandler for better Warp compatibility
        try {
            Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r' -ErrorAction Stop
        } catch {
            # Fallback: Set keybindings directly if Set-PsFzfOption fails
            Set-PSReadLineKeyHandler -Key 'Ctrl+t' -ScriptBlock {
                [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
                [Microsoft.PowerShell.PSConsoleReadLine]::Insert("Invoke-FzfPsReadlineHandlerProvider")
                [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
            }
        }
        
        # Enable tab completion only if PSCompletions isn't handling it
        if (-not (Get-Module PSCompletions)) {
            Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
        }
    }
}

# =============================================================================
# Fzf Helper Functions (Warp-compatible - no keybinding dependencies)
# =============================================================================
# These provide explicit function names for fzf features that Warp's
# input architecture intercepts (Ctrl+R, Ctrl+T, Alt+C, **<TAB>).

<#
.SYNOPSIS
    Fuzzy search command history.
.DESCRIPTION
    Searches your PSReadLine history file through fzf. In a standard terminal,
    the selected command is inserted into the prompt buffer. In Warp (where
    PSReadLine buffer manipulation isn't available), the command is printed
    to stdout.
    Warp-compatible replacement for Ctrl+R.
.EXAMPLE
    fh
    # Opens fzf with your full command history for fuzzy searching.
.EXAMPLE
    $(fh)
    # Captures the selected command into a subexpression.
#>
function fh {
    $selected = Get-Content (Get-PSReadLineOption).HistorySavePath |
        Where-Object { $_.Trim() } |
        Sort-Object -Unique |
        fzf --tac --no-sort --header 'Command History' --prompt 'history> '
    if ($selected) {
        # Insert into PSReadLine buffer if in interactive prompt, otherwise just output
        try {
            [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert($selected)
        } catch {
            Write-Output $selected
        }
    }
}

<#
.SYNOPSIS
    Fuzzy find a file and open it in your editor.
.DESCRIPTION
    Recursively searches for files using fd (or Get-ChildItem as fallback),
    presents them in fzf with a bat preview, and opens the selection in
    nvim, $EDITOR, or VS Code.
.PARAMETER Path
    Root directory to search from. Defaults to current directory.
.EXAMPLE
    fe
    # Find and edit a file in the current directory tree.
.EXAMPLE
    fe ~/projects/myapp
    # Find and edit a file under a specific path.
#>
function fe {
    param(
        [string]$Path = '.'
    )
    $cmd = if (Get-Command fd -ErrorAction SilentlyContinue) {
        "fd --type f --hidden --follow --exclude .git . $Path"
    } else {
        "Get-ChildItem -Path '$Path' -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { `$_.FullName }"
    }
    $file = Invoke-Expression $cmd | fzf --preview 'bat --color=always --style=numbers --line-range=:500 {}' --preview-window=right:60%:wrap --header 'Find & Edit' --prompt 'edit> '
    if ($file) {
        $editor = if (Get-Command nvim -ErrorAction SilentlyContinue) { 'nvim' }
                  elseif ($env:EDITOR) { $env:EDITOR }
                  else { 'code' }
        & $editor $file
    }
}

<#
.SYNOPSIS
    Fuzzy find a directory and cd into it.
.DESCRIPTION
    Recursively lists directories using fd (or Get-ChildItem as fallback),
    presents them in fzf with an eza tree preview, and changes to the
    selected directory.
    Warp-compatible replacement for Alt+C.
.PARAMETER Path
    Root directory to search from. Defaults to current directory.
.EXAMPLE
    fcd
    # Fuzzy pick a subdirectory and cd into it.
.EXAMPLE
    fcd ~/projects
    # Browse directories under a specific path.
#>
function fcd {
    param(
        [string]$Path = '.'
    )
    $dir = if (Get-Command fd -ErrorAction SilentlyContinue) {
        fd --type d --hidden --follow --exclude .git . $Path | fzf --preview 'eza --color=always --icons --group-directories-first {}' --preview-window=right:50% --header 'Change Directory' --prompt 'cd> '
    } else {
        Get-ChildItem -Path $Path -Recurse -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { $_.FullName } |
            fzf --header 'Change Directory' --prompt 'cd> '
    }
    if ($dir) {
        Set-Location $dir
    }
}

<#
.SYNOPSIS
    Fuzzy find a file and output its path.
.DESCRIPTION
    Recursively searches for files using fd (or Get-ChildItem as fallback),
    presents them in fzf with a bat preview, and outputs the selected path.
    Useful for piping or capturing into a variable.
.PARAMETER Path
    Root directory to search from. Defaults to current directory.
.EXAMPLE
    ff
    # Pick a file and print its path.
.EXAMPLE
    code $(ff)
    # Open the selected file in VS Code.
.EXAMPLE
    ff ~/Downloads | Set-Clipboard
    # Copy a file path to the clipboard.
#>
function ff {
    param(
        [string]$Path = '.'
    )
    $file = if (Get-Command fd -ErrorAction SilentlyContinue) {
        fd --type f --hidden --follow --exclude .git . $Path | fzf --preview 'bat --color=always --style=numbers --line-range=:500 {}' --preview-window=right:60%:wrap --header 'Find File' --prompt 'file> '
    } else {
        Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue |
            ForEach-Object { $_.FullName } |
            fzf --header 'Find File' --prompt 'file> '
    }
    if ($file) {
        Write-Output $file
    }
}

<#
.SYNOPSIS
    Fuzzy select a git branch and checkout.
.DESCRIPTION
    Lists all local and remote branches via git, presents them in fzf with
    a log preview, and checks out the selected branch. Remote branch prefixes
    (origin/) are stripped automatically.
.EXAMPLE
    fgb
    # Pick a branch from all local and remote branches and switch to it.
#>
function fgb {
    $branch = git --no-pager branch --all --format='%(refname:short)' 2>$null |
        fzf --header 'Git Branches' --prompt 'branch> ' --preview 'git --no-pager log --oneline --graph --color=always -20 {}'
    if ($branch) {
        # Strip remote prefix for remote branches
        $branch = $branch -replace '^origin/', ''
        git checkout $branch
    }
}

<#
.SYNOPSIS
    Fuzzy browse git log and show commit details.
.DESCRIPTION
    Displays the last 50 commits in fzf with a diff preview. Selecting a
    commit shows its full details via git show.
.EXAMPLE
    fgl
    # Browse recent commits and view the selected one.
#>
function fgl {
    $commit = git --no-pager log --oneline --color=always -50 2>$null |
        fzf --ansi --no-sort --header 'Git Log' --prompt 'commit> ' --preview 'git --no-pager show --color=always {1}'
    if ($commit) {
        $hash = ($commit -split '\s+')[0]
        git --no-pager show $hash
    }
}

<#
.SYNOPSIS
    Fuzzy select a process to kill.
.DESCRIPTION
    Lists running processes with PID, memory usage, and name in fzf.
    Selecting a process prompts for confirmation before terminating it.
.EXAMPLE
    fkill
    # Pick a process and kill it (with confirmation).
#>
function fkill {
    $proc = Get-Process | ForEach-Object { "{0,8} {1,10} {2}" -f $_.Id, ([math]::Round($_.WorkingSet64 / 1MB, 1)), $_.ProcessName } |
        fzf --header 'PID        MB  Name' --prompt 'kill> '
    if ($proc) {
        $pid = ($proc.Trim() -split '\s+')[0]
        Stop-Process -Id $pid -Confirm
    }
}

<#
.SYNOPSIS
    Fuzzy tab-complete a command via fzf.
.DESCRIPTION
    Provides fzf-powered tab completion for any command. Completions are
    shown with descriptions where available. Selecting an item outputs the
    full command (e.g. selecting 'install' from 'mise' outputs 'mise install').

    First tries PowerShell's TabExpansion2 engine; if that only returns
    filesystem paths (no real completer fired), falls back to the usage CLI
    for tools like mise and any other usage-spec tool.
    Warp-compatible replacement for Tab completion.
.PARAMETER InputLine
    The partial command line to complete. Can be a bare command name
    (shows all subcommands) or a partial argument.
.PARAMETER List
    List all commands that have known completions available.
.EXAMPLE
    ftab "mise"
    # Show all mise subcommands with descriptions, select one and run it.
.EXAMPLE
    ftab "mise i"
    # Pre-filtered to subcommands starting with 'i', select and run.
.EXAMPLE
    ftab "Get-Ch"
    # Complete PowerShell cmdlets: e.g. Get-ChildItem.
.EXAMPLE
    ftab -List
    # Show all commands with registered completions.
#>
function ftab {
    param(
        [Parameter(Position = 0)]
        [string]$InputLine,

        [Alias('l')]
        [switch]$List
    )

    if ($List) {
        $sources = [ordered]@{}

        # Completion scripts
        $completionsDir = Join-Path (Split-Path $PROFILE) 'Completions'
        if (Test-Path $completionsDir) {
            Get-ChildItem "$completionsDir\*.ps1" | ForEach-Object {
                $sources[$_.BaseName] = 'Completion script'
            }
        }

        # usage specs cached today
        $tmpDir = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
        $today = Get-Date -Format 'yyyy_M_d'
        Get-ChildItem $tmpDir -Filter "usage__usage_spec_*_$today.kdl" -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.Name -match 'usage__usage_spec_(.+)_\d+_\d+_\d+\.kdl') {
                $sources[$Matches[1]] = 'usage spec'
            }
        }

        # PowerShell built-in (always available)
        $sources['<PowerShell cmdlets>'] = 'TabExpansion2 (built-in)'

        $sources.GetEnumerator() | Sort-Object Key | ForEach-Object {
            [PSCustomObject]@{ Command = $_.Key; Source = $_.Value }
        } | Format-Table -AutoSize
        return
    }

    if (-not $InputLine) {
        Write-Warning "Usage: ftab <command> or ftab -List"
        return
    }

    $fzfQuery = ''
    $items = @()

    # --- Resolve simple function wrappers (e.g. gst → git status) ---
    $bareCmd = ($InputLine -split '\s+', 2)[0]
    $cmdInfo = Get-Command $bareCmd -ErrorAction SilentlyContinue
    if ($cmdInfo -and $cmdInfo.CommandType -eq 'Function') {
        $def = $cmdInfo.Definition.Trim()
        # Match simple wrappers: "git status $args" or "& nvim $args"
        if ($def -match '^(?:& )?(.+?)\s+\$args$') {
            $resolved = $Matches[1]
            $rest = if ($InputLine -match '^\S+(\s+.*)$') { $Matches[1] } else { '' }
            $InputLine = "$resolved$rest"
        }
    }

    # If input is a bare command name (no spaces), append a space to
    # request subcommand/argument completions instead of command name completion
    if ($InputLine -notmatch '\s') {
        $InputLine = "$InputLine "
    }

    # --- Try TabExpansion2 first ---
    $te = (TabExpansion2 -inputScript $InputLine -cursorColumn $InputLine.Length).CompletionMatches

    # If no results and there's a partial word, back up to the word boundary
    if (-not $te -and $InputLine -match '^(.+\s)(\S+)$') {
        $fzfQuery = $Matches[2]
        $te = (TabExpansion2 -inputScript $Matches[1] -cursorColumn $Matches[1].Length).CompletionMatches
    }

    # Check if TabExpansion2 returned real completions (not just filesystem paths)
    $isFileOnly = $te -and ($te | Where-Object { $_.ResultType -notin 'ProviderItem','ProviderContainer' }).Count -eq 0

    # Build the base command (everything before the word being completed)
    $base = if ($InputLine -match '\S$' -and $InputLine -match '^(.+\s)\S+$') {
        $Matches[1]
    } else {
        $InputLine
    }

    if ($te -and -not $isFileOnly) {
        # TabExpansion2 returned real completions (commands, parameters, etc.)
        $items = @($te | ForEach-Object {
            $tip = if ($_.ToolTip -and $_.ToolTip -ne $_.CompletionText) { $_.ToolTip } else { '' }
            if ($tip) { "{0}`t{1}" -f $_.CompletionText, $tip }
            else { $_.CompletionText }
        })
    }

    # --- Fallback: usage complete-word for CLI tools ---
    if ($items.Count -eq 0 -and $isFileOnly -and (Get-Command usage -ErrorAction SilentlyContinue)) {
        $cmdName = ($InputLine -split '\s+', 2)[0]
        $cmdExe = Get-Command "$cmdName.exe" -CommandType Application -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty Source
        if (-not $cmdExe) {
            $cmdExe = (Get-Command $cmdName -ErrorAction SilentlyContinue).Source
        }

        if ($cmdExe) {
            $tmpDir = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
            $today = Get-Date -Format 'yyyy_M_d'
            $specFile = Join-Path $tmpDir "usage__usage_spec_${cmdName}_$today.kdl"

            if (-not (Test-Path $specFile)) {
                & $cmdExe usage 2>$null | Out-File -FilePath $specFile -Encoding utf8
                # Validate it's a real usage spec (KDL), not random help text
                $firstLine = Get-Content $specFile -TotalCount 1 -ErrorAction SilentlyContinue
                if ($firstLine -and $firstLine -notmatch '(^min_usage_version|^name |^cmd )') {
                    Remove-Item $specFile -ErrorAction SilentlyContinue
                }
            }

            if ((Test-Path $specFile) -and (Get-Item $specFile).Length -gt 0) {
                $words = @($InputLine -split '\s+' | Where-Object { $_ })
                $wordToComplete = ''
                if ($InputLine[-1] -ne ' ') {
                    $wordToComplete = $words[-1]
                    if (-not $fzfQuery) { $fzfQuery = $wordToComplete }
                    $words = @($words[0..($words.Count - 2)])
                }

                $raw = & usage complete-word --shell powershell -f $specFile -- @words $wordToComplete 2>$null
                if ($raw) {
                    $items = @($raw | Where-Object { $_ })
                }
            }
        }
    }

    # --- Fallback: parse --help output for subcommands ---
    if ($items.Count -eq 0 -and $isFileOnly) {
        $cmdName = ($InputLine -split '\s+', 2)[0]
        $helpOut = try { & $cmdName --help 2>&1 | Out-String } catch { $null }
        if ($helpOut) {
            # Match indented lines like "  install    Installs the given package"
            $parsed = @($helpOut -split '\r?\n' | ForEach-Object {
                if ($_ -match '^\s{2,}(\S+)\s{2,}(.+)$') {
                    "{0}`t{1}" -f $Matches[1].Trim(), $Matches[2].Trim()
                }
            } | Where-Object { $_ })
            if ($parsed.Count -gt 0) { $items = $parsed }
        }
    }

    # --- Last resort: file completions from TabExpansion2 ---
    if ($items.Count -eq 0 -and $te) {
        $items = @($te | ForEach-Object { $_.CompletionText })
    }

    # --- Present through fzf ---
    if ($items.Count -gt 0) {
        # Format items as "command  -- description" with aligned columns
        $maxLen = ($items | ForEach-Object { ($_ -split "`t", 2)[0].Length } | Measure-Object -Maximum).Maximum
        $displayItems = @($items | ForEach-Object {
            $parts = $_ -split "`t", 2
            $name = $parts[0]
            $desc = if ($parts.Count -gt 1 -and $parts[1]) { $parts[1] } else { '' }
            if ($desc) {
                "{0}{1} -- {2}" -f $name, (' ' * [Math]::Max(1, $maxLen - $name.Length + 2)), $desc
            } else { $name }
        })

        $fzfArgs = @(
            '--header', "Completions for: $($InputLine.TrimEnd())"
            '--prompt', 'tab> '
            '--nth', '1'               # search only the command name, not description
            '--delimiter', ' '
        )
        if ($fzfQuery) { $fzfArgs += @('--query', $fzfQuery) }
        $selected = $displayItems | fzf @fzfArgs
        if ($selected) {
            # Extract just the completion name (first word)
            $completion = ($selected -split '\s+')[0]
            $fullCmd = "$($base.TrimEnd()) $completion"
            Write-Host "`u{276f} $fullCmd" -ForegroundColor Cyan
            Invoke-Expression $fullCmd
        }
    } else {
        Write-Warning "No completions found for '$($InputLine.TrimEnd())'"
    }
}

<#
.SYNOPSIS
    Fuzzy jump to a project directory.
.DESCRIPTION
    Scans common project roots ($env:PROJECTS, ~/projects, ~/repos) for
    subdirectories up to 1 level deep, presents them in fzf with an eza
    preview, and cd's into the selected project.
.EXAMPLE
    fp
    # Pick a project and cd into it.
#>
function fp {
    $projectRoots = @(
        "$env:PROJECTS"
        "$HOME\projects"
        "$HOME\repos"
    ) | Where-Object { $_ -and (Test-Path $_) } | Sort-Object -Unique

    if ($projectRoots.Count -eq 0) {
        Write-Warning "No project directories found"
        return
    }

    $projects = $projectRoots | ForEach-Object {
        Get-ChildItem -Path $_ -Directory -Depth 1 -ErrorAction SilentlyContinue
    } | ForEach-Object { $_.FullName } | Sort-Object -Unique

    $selected = $projects | fzf --header 'Projects' --prompt 'project> ' --preview 'eza --color=always --icons --group-directories-first {}'
    if ($selected) {
        Set-Location $selected
    }
}

# vim: ts=2 sts=2 sw=2 et

# ███████╗███████╗███████╗
# ██╔════╝╚══███╔╝██╔════╝
# █████╗    ███╔╝ █████╗
# ██╔══╝   ███╔╝  ██╔══╝
# ██║     ███████╗██║
# ╚═╝     ╚══════╝╚═╝
# Command-line fuzzy finder.
# https://github.com/junegunn/fzf

# FZF Configuration for PowerShell

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
    Fuzzy search command history and insert selection into the command line.
    Replacement for Ctrl+R when Warp intercepts it.
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
    Fuzzy find a file and open it in your preferred editor.
    Replacement for Ctrl+T -> editor workflow.
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
    Replacement for Alt+C when Warp intercepts it.
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
    Fuzzy find a file and insert its path (like Ctrl+T file picker).
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
    Fuzzy jump to a project directory.
    Scans common project locations for directories containing .git.
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

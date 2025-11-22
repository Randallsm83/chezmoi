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
        
        # Enable tab completion
        Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
    }
}

# vim: ts=2 sts=2 sw=2 et

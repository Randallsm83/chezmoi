# ███████╗███████╗███████╗
# ██╔════╝╚══███╔╝██╔════╝
# █████╗    ███╔╝ █████╗
# ██╔══╝   ███╔╝  ██╔══╝
# ██║     ███████╗██║
# ╚═╝     ╚══════╝╚═╝
# Command-line fuzzy finder.
# https://github.com/junegunn/fzf

# FZF Configuration for PowerShell

# Colors matching onedark theme
$env:FZF_DEFAULT_OPTS = @"
--color=bg+:#3e4452,bg:#282c34,spinner:#61afef,hl:#c678dd
--color=fg:#abb2bf,header:#61afef,info:#98c379,pointer:#e06c75
--color=marker:#e5c07b,fg+:#abb2bf,prompt:#61afef,hl+:#c678dd
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

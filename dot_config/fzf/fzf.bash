# ███████╗███████╗███████╗
# ██╔════╝╚══███╔╝██╔════╝
# █████╗    ███╔╝ █████╗
# ██╔══╝   ███╔╝  ██╔══╝
# ██║     ███████╗██║
# ╚═╝     ╚══════╝╚═╝
# Command-line fuzzy finder.
#

# fzf configuration for bash/zsh
# https://github.com/junegunn/fzf

# Default options
export FZF_DEFAULT_OPTS="
  --height=40%
  --layout=reverse
  --info=inline
  --border
  --margin=1
  --padding=1
  --color=fg:#abb2bf,bg:#282c34,hl:#61afef
  --color=fg+:#ffffff,bg+:#3e4451,hl+:#61afef
  --color=info:#98c379,prompt:#61afef,pointer:#e06c75
  --color=marker:#e5c07b,spinner:#61afef,header:#61afef
"

# Use fd for file listing (faster, respects .gitignore)
if command -v fd &> /dev/null; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
elif command -v rg &> /dev/null; then
  export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git/*"'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

# Preview options
export FZF_CTRL_T_OPTS="
  --preview 'bat --color=always --style=numbers --line-range=:500 {}'
  --preview-window=right:60%:wrap
"

export FZF_ALT_C_OPTS="
  --preview 'eza --tree --level=2 --color=always {}'
  --preview-window=right:60%
"

# Completion options
export FZF_COMPLETION_TRIGGER='**'
export FZF_COMPLETION_OPTS='--border --info=inline'

# vim: ts=2 sts=2 sw=2 et

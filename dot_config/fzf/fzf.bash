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

# Default options - spaceduck theme
export FZF_DEFAULT_OPTS="
  --color=bg+:#1b1c36,bg:#0f111b,spinner:#00a3cc,hl:#b3a1e6
  --color=fg:#f0f1ce,header:#00a3cc,info:#5ccc96,pointer:#e33400
  --color=marker:#f2ce00,fg+:#f0f1ce,prompt:#00a3cc,hl+:#b3a1e6
  --border --height=40% --layout=reverse --info=inline
  --margin=1 --padding=1
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

# ███████╗███████╗██╗  ██╗
# ╚══███╔╝██╔════╝██║  ██║
#   ███╔╝ ███████╗███████║
#  ███╔╝  ╚════██║██╔══██║
# ███████╗███████║██║  ██║
# ╚══════╝╚══════╝╚═╝  ╚═╝
# Z Shell - powerful command interpreter.
#

#!/usr/bin/env zsh

(( $+commands[fzf] )) || return 1

# Default options - spaceduck theme
export FZF_DEFAULT_OPTS="
  --color=bg+:#1b1c36,bg:#0f111b,spinner:#00a3cc,hl:#b3a1e6
  --color=fg:#f0f1ce,header:#00a3cc,info:#5ccc96,pointer:#e33400
  --color=marker:#f2ce00,fg+:#f0f1ce,prompt:#00a3cc,hl+:#b3a1e6
  --border --height=40% --layout=reverse --info=inline
  --margin=1 --padding=1
"

# CTRL-Y to copy the command into clipboard using pbcopy
export FZF_CTRL_R_OPTS="
  --bind 'ctrl-y:execute-silent(echo -n {2..} | pbcopy)+abort'
  --color header:italic
  --header 'Press CTRL-Y to copy command into clipboard'"

# Preview file content using bat (https://github.com/sharkdp/bat)
export FZF_CTRL_T_OPTS="
  --walker-skip .git,node_modules,target
  --preview 'bat -n --color=always {}'
  --bind 'ctrl-/:change-preview-window(down|hidden|)'"

# Print tree structure in the preview window
export FZF_ALT_C_OPTS="
  --walker-skip .git,node_modules,target
  --preview 'tree -C {}'"

# Cache the shell integration to avoid spawning fzf on every startup
_fzf_cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/fzf-init.zsh"
if [[ ! -f "$_fzf_cache" || "$(command -v fzf)" -nt "$_fzf_cache" ]]; then
  mkdir -p "${_fzf_cache:h}"
  fzf --zsh >| "$_fzf_cache"
fi
source "$_fzf_cache"
unset _fzf_cache

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#

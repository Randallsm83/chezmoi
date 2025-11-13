[[ -v terminfo ]] || zmodload zsh/terminfo

# Up arrow
bindkey -M emacs '^[[A' history-substring-search-up
bindkey -M viins '^[[A' history-substring-search-up
bindkey -M emacs '\033OA' history-substring-search-up  # Application mode
bindkey -M viins '\033OA' history-substring-search-up  # Application mode

# Down arrow
bindkey -M emacs '^[[B' history-substring-search-down
bindkey -M viins '^[[B' history-substring-search-down
bindkey -M emacs '\033OB' history-substring-search-down  # Application mode
bindkey -M viins '\033OB' history-substring-search-down  # Application mode

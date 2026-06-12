# █████╗ ████████╗██╗   ██╗██╗███╗   ██╗
#██╔══██╗╚══██╔══╝██║   ██║██║████╗  ██║
#███████║   ██║   ██║   ██║██║██╔██╗ ██║
#██╔══██║   ██║   ██║   ██║██║██║╚██╗██║
#██║  ██║   ██║   ╚██████╔╝██║██║ ╚████║
#╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝╚═╝  ╚═══╝
# Better shell history.
#

#!/usr/bin/env zsh

(( $+commands[atuin] )) || return 0

# Keep fzf Ctrl-R and history-substring-search arrow bindings intact.
zsh_cache_eval atuin-init atuin init zsh --disable-ctrl-r --disable-up-arrow

# Alt-R (ESC r) opens Atuin history search in the active keymap.
bindkey -M emacs '^[r' atuin-search
bindkey -M viins '^[r' atuin-search
bindkey -M vicmd '^[r' atuin-search

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

# ███████╗ ██████╗ ██████╗ ████████╗████████╗
# ██╔════╝██╔════╝██╔═══██╗╚══██╔══╝╚══██╔══╝
# ███████╗██║     ██║   ██║   ██║      ██║
# ╚════██║██║     ██║   ██║   ██║      ██║
# ███████║╚██████╗╚██████╔╝   ██║      ██║
# ╚══════╝ ╚═════╝ ╚═════╝    ╚═╝      ╚═╝
# AI agent skill manager.
#

(( $+commands[scott] )) || return 1

# Cache completions to avoid spawning scott on every shell startup
_scott_cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/scott-completions.zsh"
if [[ ! -f "$_scott_cache" || "$(command -v scott)" -nt "$_scott_cache" ]]; then
  mkdir -p "${_scott_cache:h}"
  scott completion zsh >| "$_scott_cache"
fi
source "$_scott_cache"
unset _scott_cache

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et

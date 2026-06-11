# ██╗  ██╗ ██████╗ ███╗   ███╗███████╗██╗      █████╗ ██████╗
# ██║  ██║██╔═══██╗████╗ ████║██╔════╝██║     ██╔══██╗██╔══██╗
# ███████║██║   ██║██╔████╔██║█████╗  ██║     ███████║██████╔╝
# ██╔══██║██║   ██║██║╚██╔╝██║██╔══╝  ██║     ██╔══██║██╔══██╗
# ██║  ██║╚██████╔╝██║ ╚═╝ ██║███████╗███████╗██║  ██║██████╔╝
# ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═════╝
# Lightweight distro-packaged zsh plugins for homelab hosts.
#

[[ "${ZSH_HOMELAB_MINIMAL:-0}" == 1 ]] || return 0

for plugin in \
  /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /usr/share/zsh-history-substring-search/zsh-history-substring-search.zsh
do
  [[ -r "$plugin" ]] && source "$plugin"
done
unset plugin

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

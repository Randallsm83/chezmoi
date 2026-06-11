# ██╗  ██╗ ██████╗ ███╗   ███╗███████╗██╗      █████╗ ██████╗
# ██║  ██║██╔═══██╗████╗ ████║██╔════╝██║     ██╔══██╗██╔══██╗
# ███████║██║   ██║██╔████╔██║█████╗  ██║     ███████║██████╔╝
# ██╔══██║██║   ██║██║╚██╔╝██║██╔══╝  ██║     ██╔══██║██╔══██╗
# ██║  ██║╚██████╔╝██║ ╚═╝ ██║███████╗███████╗██║  ██║██████╔╝
# ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═════╝
# Minimal functions for homelab and remote shells.
#

[[ "${ZSH_HOMELAB_MINIMAL:-0}" == 1 ]] || return 0

mkcd() {
  mkdir -p "$1" && cd "$1"
}

up() {
  local levels="${1:-1}"
  local target=""
  [[ "$levels" == <-> ]] || {
    print -u2 "usage: up [levels]"
    return 2
  }
  for (( i = 0; i < levels; i++ )); do
    target+="../"
  done
  cd "$target"
}

sysup() {
  if (( $+commands[apt] )); then
    sudo apt update && sudo apt upgrade
  elif (( $+commands[pacman] )); then
    sudo pacman -Syu
  elif (( $+commands[dnf] )); then
    sudo dnf upgrade
  else
    print -u2 "No supported system package manager found."
    return 1
  fi
}

ports() {
  if (( $+commands[ss] )); then
    ss -tulpn "$@"
  elif (( $+commands[lsof] )); then
    lsof -i -P -n "$@"
  else
    print -u2 "Need ss or lsof."
    return 1
  fi
}

homelab-tools() {
  local green red cyan reset
  green=$(tput setaf 2 2>/dev/null)
  red=$(tput setaf 1 2>/dev/null)
  cyan=$(tput setaf 6 2>/dev/null)
  reset=$(tput sgr0 2>/dev/null)

  print "\n${cyan}Homelab aliases${reset}"
  print "  la,ll,l,lt       list files"
  print "  g*, gst, gss     git shortcuts"
  print "  cz*              chezmoi shortcuts"
  print "  homelab          cd to ~/homelab"
  print "  miseup           update mise tools"

  print "\n${cyan}Homelab functions${reset}"
  print "  mkcd <dir>       mkdir -p and cd"
  print "  up [n]           go up n directories"
  print "  sysup            update apt/pacman/dnf host"
  print "  ports [args]     list listening sockets"

  print "\n${cyan}Tool status${reset}"
  for cmd in git chezmoi mise node npm npx python rg fd bat eza zoxide fzf starship; do
    if (( $+commands[$cmd] )); then
      printf "  ${green}✓${reset} %s\n" "$cmd"
    else
      printf "  ${red}✗${reset} %s\n" "$cmd"
    fi
  done
  print ""
}

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

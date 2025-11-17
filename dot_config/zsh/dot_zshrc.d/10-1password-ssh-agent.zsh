# ███████╗███████╗██╗  ██╗
# ╚══███╔╝██╔════╝██║  ██║
#   ███╔╝ ███████╗███████║
#  ███╔╝  ╚════██║██╔══██║
# ███████╗███████║██║  ██║
# ╚══════╝╚══════╝╚═╝  ╚═╝
# Z Shell - powerful command interpreter.
#

# 1Password SSH Agent Configuration
# Configures SSH_AUTH_SOCK to use the 1Password SSH agent
# Works across macOS, WSL, and native Linux

if is-macos; then
  # macOS: 1Password agent socket location
  export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
elif is-wsl; then
  # WSL: Use Windows SSH client (ssh.exe) to access 1Password agent
  # This leverages WSL interoperability - the Windows SSH client automatically
  # connects to the 1Password SSH agent on Windows. Much simpler than named pipes!
  export GIT_SSH_COMMAND="ssh.exe"
  alias ssh="ssh.exe"
  alias ssh-add="ssh-add.exe"
  # Unset SSH_AUTH_SOCK since we're using Windows SSH
  unset SSH_AUTH_SOCK
else
  # Native Linux with 1Password agent
  export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"
fi

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

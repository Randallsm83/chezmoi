#  ██╗██████╗  █████╗ ███████╗███████╗██╗    ██╗ ██████╗ ██████╗ ██████╗
# ███║██╔══██╗██╔══██╗██╔════╝██╔════╝██║    ██║██╔═══██╗██╔══██╗██╔══██╗
# ╚██║██████╔╝███████║███████╗███████╗██║ █╗ ██║██║   ██║██████╔╝██║  ██║
#  ██║██╔═══╝ ██╔══██║╚════██║╚════██║██║███╗██║██║   ██║██╔══██╗██║  ██║
#  ██║██║     ██║  ██║███████║███████║╚███╔███╔╝╚██████╔╝██║  ██║██████╔╝
#  ╚═╝╚═╝     ╚═╝  ╚═╝╚══════╝╚══════╝ ╚══╝╚══╝  ╚═════╝ ╚═╝  ╚═╝╚═════╝
# 1Password secret manager and SSH agent.
#

# 1Password SSH Agent Configuration
# Configures SSH_AUTH_SOCK to use the 1Password SSH agent
# Works across macOS, WSL, and native Linux
#
# On remote machines (SSH sessions), agent forwarding provides SSH_AUTH_SOCK.
# We must not override it or the forwarded agent becomes unreachable.

if [[ -n "$SSH_CONNECTION" && -S "$SSH_AUTH_SOCK" ]]; then
  # Agent forwarding is active — preserve the forwarded socket
  return 0
fi

if is-macos; then
  # macOS: 1Password agent socket location
  export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
elif is-wsl; then
  # WSL: Bridge the Windows 1Password named pipe to a Unix socket via socat + npiperelay.
  # This allows both interactive SSH (via alias) and non-interactive tools (git, brew, etc.)
  # to authenticate using 1Password keys.
  local _1p_sock="$HOME/.1password/agent.sock"

  # Detect Windows username dynamically (cached in WIN_USER for subsequent shells).
  # Override by setting WIN_USER in the environment if detection misbehaves.
  if [[ -z "$WIN_USER" ]]; then
    export WIN_USER="$(cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r\n')"
  fi
  local _npiperelay="/mnt/c/Users/${WIN_USER}/scoop/apps/npiperelay/current/npiperelay.exe"

  # Start the bridge if the socket doesn't exist or agent isn't responding
  if [[ ! -S "$_1p_sock" ]] || ! SSH_AUTH_SOCK="$_1p_sock" ssh-add -l &>/dev/null 2>&1; then
    rm -f "$_1p_sock"
    mkdir -p "${_1p_sock:h}"
    (setsid socat UNIX-LISTEN:"$_1p_sock",fork \
      EXEC:"$_npiperelay -ei -s //./pipe/openssh-ssh-agent",nofork \
      &>/dev/null &)
    sleep 0.1
  fi

  export SSH_AUTH_SOCK="$_1p_sock"

  # Alias ssh/ssh-add to Windows binaries for interactive terminal use
  # (works identically and avoids any WSL interop edge cases)
  local win_ssh="/mnt/c/Windows/System32/OpenSSH/ssh.exe"
  local win_ssh_add="/mnt/c/Windows/System32/OpenSSH/ssh-add.exe"
  alias ssh="$win_ssh"
  alias ssh-add="$win_ssh_add"
else
  # Native Linux with 1Password agent
  export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"
fi

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

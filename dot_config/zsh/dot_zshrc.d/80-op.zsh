#  ██████╗ ██████╗
# ██╔═══██╗██╔══██╗
# ██║   ██║██████╔╝
# ██║   ██║██╔═══╝
# ╚██████╔╝██║
#  ╚═════╝ ╚═╝
# 1Password CLI.
#

#!/usr/bin/env zsh

# Check if op command is available
(( $+commands[op] )) || return 1

# Load 1Password CLI completions
eval "$(op completion zsh)"
compdef _op op

# Source 1Password plugins (e.g., GitHub CLI integration)
if [[ -f "$HOME/.config/op/plugins.sh" ]]; then
  source "$HOME/.config/op/plugins.sh"
fi

# -------------------------------------------------------------------------------------------------
# Eager 1Password CLI sign-in for interactive shells.
#
# Mirrors the pwsh Invoke-OpEnsure pattern in
# Documents/PowerShell/Scripts/80-op.ps1: an unlocked desktop vault is not
# the same as an authorized CLI session, so without an explicit `op signin`
# (handled silently by the desktop app's biometric / OS-keyring integration
# on macOS / WSL-bridged Windows / Touch ID) every subsequent `op` call
# fails with "account is not signed in" until the user runs it manually.
# Doing the sign-in at shell startup converts the failure mode from
# "silently broken until I notice and run op signin" into "prompt at first
# shell, then it Just Works."
#
# Guards (any one of these short-circuits the block):
#   * shell is not interactive             ($-/[[ -o interactive ]])
#   * stdin is not a TTY                   (script/sourced from non-TTY)
#   * OP_SERVICE_ACCOUNT_TOKEN is set      (headless service-account flow)
#   * OP_AUTOSIGNIN_DISABLE is set         (user opt-out)
#   * op is not on PATH                    (above guard already returned)
#
# Caching: a successful sign-in records a timestamp file under
# $XDG_CACHE_HOME/op/last-signin (TTL: 300 s, matching __OP_ENSURE_TTL on
# the pwsh side). Subsequent shells inside that window skip the probe so we
# do not hammer the desktop app's CLI authorization handshake on every new
# pane / tmux window.
#
# Failure handling: stays quiet on non-interactive paths. On interactive
# failure (e.g. desktop app not running, vault locked) the helper prints a
# one-line hint and falls through — the rest of the shell init must still
# work for users without an unlocked 1Password.
if [[ -o interactive ]] \
  && [[ -t 0 ]] \
  && [[ -z "${OP_SERVICE_ACCOUNT_TOKEN-}" ]] \
  && [[ -z "${OP_AUTOSIGNIN_DISABLE-}" ]] \
  && (( $+commands[op] )); then

  __op_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/op"
  __op_cache_file="${__op_cache_dir}/last-signin"
  __op_ttl_seconds=300

  # Refresh cache mtime when a probe succeeds. Uses portable `touch -m`.
  __op_mark_signed_in() {
    [[ -d "${__op_cache_dir}" ]] || mkdir -p "${__op_cache_dir}" 2>/dev/null
    : > "${__op_cache_file}" 2>/dev/null && touch "${__op_cache_file}" 2>/dev/null
  }

  # Returns 0 when the cached timestamp is younger than the TTL, 1 otherwise.
  # Falls back to forcing a probe if either `stat` flavor fails (e.g. on a
  # minimal busybox host) — the probe itself is cheap.
  __op_cache_fresh() {
    [[ -f "${__op_cache_file}" ]] || return 1
    local now mtime age
    now=$(date +%s 2>/dev/null) || return 1
    if mtime=$(stat -c %Y "${__op_cache_file}" 2>/dev/null); then
      :
    elif mtime=$(stat -f %m "${__op_cache_file}" 2>/dev/null); then
      :
    else
      return 1
    fi
    age=$(( now - mtime ))
    (( age >= 0 && age < __op_ttl_seconds ))
  }

  if ! __op_cache_fresh; then
    # `op vault list` is the integration-aware probe — `op whoami` returns
    # "not signed in" on a cold subprocess even when the desktop app is
    # unlocked and CLI integration is enabled (matching the pwsh helper's
    # Wait-OpReady rationale).
    if op vault list >/dev/null 2>&1; then
      __op_mark_signed_in
    else
      # Non-prompting signin: the desktop app's biometric / Windows Hello /
      # Touch ID prompt is system-modal and does not consume stdin, so
      # silencing fd 0/1/2 is safe and avoids a noisy banner on every fresh
      # shell. On WSL the agent bridges through Windows so this still works.
      if op signin >/dev/null 2>&1 && op vault list >/dev/null 2>&1; then
        __op_mark_signed_in
      else
        # Don't be chatty on every shell — emit a single hint to stderr
        # so the user can self-diagnose without it polluting prompt redraws.
        print -u2 -- "op: sign-in skipped (vault locked or desktop app unavailable); run \`op signin\` manually or set OP_AUTOSIGNIN_DISABLE=1 to silence."
      fi
    fi
  fi

  unset -f __op_cache_fresh __op_mark_signed_in
  unset __op_cache_dir __op_cache_file __op_ttl_seconds
fi

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#

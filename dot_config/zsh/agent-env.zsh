#!/usr/bin/env zsh
# ============================================================================
# agent-env.zsh — non-interactive shell env for AI coding agents
# ----------------------------------------------------------------------------
# Source this file at the top of agent bash/zsh invocations to get the user's
# aliases (la/ll/lt, git*, chezmoi shortcuts, etc.), functions, PATH, and
# tool env vars without dragging in interactive-only machinery (prompt,
# plugins, completion compilation, line-editor widgets, terminal hooks).
#
# Usage from an agent's shell tool:
#   source ~/.config/zsh/agent-env.zsh && <command>
#
# This file is intentionally NOT sourced by ~/.zshrc — the regular
# interactive shell already loads everything via antidote/.zshrc.d/.
#
# Maintenance: when a new fragment is added under .zshrc.d/, decide whether
# to allowlist it here. Default to skipping anything that:
#   - calls `bindkey`, `zle -N`, or relies on widgets
#   - sets up a prompt, terminal hooks, or plugin manager state
#   - depends on $TERM_PROGRAM or an interactive TTY
#   - is slow on cold start (completion generation, etc.)
# ============================================================================

# Avoid double-sourcing
[[ -n "$_AGENT_ENV_LOADED" ]] && return 0
typeset -g _AGENT_ENV_LOADED=1

# Be permissive: a single broken fragment shouldn't kill the whole session.
# Note: zsh's `unset` option is the *permissive* one (default); `nounset`
# would make unset vars error, which is what we want to avoid here.
emulate -L zsh
setopt local_options no_warn_create_global unset

_agent_zshrcd="${ZDOTDIR:-$HOME/.config/zsh}/.zshrc.d"

_agent_load() {
  local frag="$_agent_zshrcd/$1"
  [[ -r "$frag" ]] || return 0
  # Suppress noisy widget/zle errors from fragments that *mostly* work
  # non-interactively but touch zle in places.
  source "$frag" 2>/dev/null
}

# --- env / paths / xdg ------------------------------------------------------
_agent_load 00-helpers.zsh
_agent_load 05-lde-env.zsh
_agent_load 10-dirs.zsh
_agent_load 20-paths.zsh
_agent_load 30-misc.zsh

# --- package managers / runtime PATH ---------------------------------------
_agent_load 50-homebrew.zsh
_agent_load 50-mise.zsh

# --- aliases & functions ---------------------------------------------------
_agent_load 25-aliases.zsh
_agent_load 25-aliases-ndn.zsh        # self-gated: no-op unless /dh/bin exists
_agent_load 25-common-aliases.zsh
_agent_load 25-functions.zsh
_agent_load 25-gnu-utils.zsh          # self-gated: no-op without gwhoami

# --- per-tool env (no widgets / no plugin state) ---------------------------
_agent_load 70-perl.zsh
_agent_load 80-bat.zsh
_agent_load 80-eza.zsh                # provides ls/ll/la/lt functions
_agent_load 80-ripgrep.zsh
_agent_load 80-rust-alternatives.zsh
_agent_load 80-scott.zsh
_agent_load 80-wget.zsh

# --- git aliases (no prompt / no plugin) -----------------------------------
_agent_load 85-git.zsh

# Non-interactive shells have a redirected stdin, and `eza` (with no path arg)
# reads paths from stdin when it's not a TTY -> produces empty output. The
# interactive 80-eza.zsh wrappers don't account for that. Redefine them here
# to pass `.` when no args are supplied so `la`, `ll`, etc. behave like users
# expect from a script/agent context.
if (( $+commands[eza] )) && typeset -f _eza_build_flags >/dev/null 2>&1; then
  ls() { command eza $(_eza_build_flags) "${@:-.}"; }
  ll() { command eza $(_eza_build_flags) -l "${@:-.}"; }
  la() { command eza $(_eza_build_flags) -la "${@:-.}"; }
  lt() { command eza $(_eza_build_flags) --tree "${@:-.}"; }
fi

unset -f _agent_load
unset _agent_zshrcd

return 0

# ----------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# ----------------------------------------------------------------------------

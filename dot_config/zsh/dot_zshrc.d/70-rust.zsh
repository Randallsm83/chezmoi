#!/usr/bin/env zsh

export CARGO_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/cargo"
export RUSTUP_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/rustup"

export PATH="$CARGO_HOME/bin:$PATH"

export ENV_DIRS="$ENV_DIRS:$CARGO_HOME:$RUSTUP_HOME"

# Generate rustup, cargo and rustc completions
setopt no_monitor

# Check and handle `rustup`
if (( $+commands[rustup] )); then
  if [[ ! -f "$ZSH_CACHE_DIR/completions/_rustup" ]]; then
    autoload -Uz _rustup
    typeset -g -A _comps
    _comps[rustup]=_rustup
  fi
  rustup completions zsh >| "$ZSH_CACHE_DIR/completions/_rustup" &
  disown
fi

# Check and handle `rustc`
if (( $+commands[rustc] )); then
  # Check and handle `cargo`
  if (( $+commands[cargo] )); then
    if [[ ! -f "$ZSH_CACHE_DIR/completions/_cargo" ]]; then
      autoload -Uz _cargo
      typeset -g -A _comps
      _comps[cargo]=_cargo
    fi
    cat >| "$ZSH_CACHE_DIR/completions/_cargo" <<'EOF' &
#compdef cargo
source "$(rustc +${${(z)$(rustup default)}[1]} --print sysroot)"/share/zsh/site-functions/_cargo
EOF
  disown
  fi
fi

unsetopt no_monitor

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

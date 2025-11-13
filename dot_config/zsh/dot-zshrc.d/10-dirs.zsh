#!/usr/bin/env zsh

export LOCAL_DIR="$HOME/.local"
export TMPDIR="${TMPDIR:-/tmp}"

export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$LOCAL_DIR/share}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$LOCAL_DIR/state}"

export XDG_BIN_HOME="${XDG_BIN_HOME:-$LOCAL_DIR/bin}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-$TMPDIR}"
export XDG_CONFIG_DIRS="${XDG_CONFIG_DIRS:-/etc/xdg}"
export XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share/:/usr/share/}"

export BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
export BUILD_DIR="$XDG_CACHE_HOME/build"
export BUILD_STATE_DIR="$XDG_STATE_HOME/build"

export ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
export ZSH_COMPLETION_DIR="$ZSH_CACHE_DIR/completions"

export SSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/ssh"

export MYSPACE="$HOME/Dev"
export DHSPACE="$HOME/projects"

export DOTFILES="$XDG_CONFIG_HOME/dotfiles"

env_dirs=(
  "$ENV_DIRS"
  "$LOCAL_DIR"
  "$XDG_CACHE_HOME"
  "$XDG_DATA_HOME"
  "$XDG_CONFIG_HOME"
  "$XDG_STATE_HOME"
  "$XDG_BIN_HOME"
  "$XDG_RUNTIME_DIR"
  "$BIN_DIR"
  "$BUILD_DIR"
  "$BUILD_STATE_DIR"
  "$ZSH_CACHE_DIR"
  "$ZSH_COMPLETION_DIR"
  "$SSH_CACHE_DIR"
)

env_dirs=(${(@)env_dirs:#""})
export ENV_DIRS="${(j/:/)env_dirs}"
unset env_dirs

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

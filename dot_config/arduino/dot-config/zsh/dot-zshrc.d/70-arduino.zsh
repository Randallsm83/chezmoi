#!/usr/bin/env zsh

export ARDUINO_DIRECTORIES_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/arduino"
export ARDUINO_DIRECTORIES_DOWNLOADS="${XDG_DATA_HOME:-$HOME/.local/share}/arduino/staging"
export ARDUINO_DIRECTORIES_USER="${XDG_DATA_HOME:-$HOME/.local/share}/arduino/sketchbook/"
export ARDUINO_DIRECTORIES_BUILTIN_LIBRARIES="${XDG_DATA_HOME:-$HOME/.local/share}/arduino/libraries/"
export ARDUINO_DIRECTORIES_BUILTIN_TOOLS="${XDG_DATA_HOME:-$HOME/.local/share}/arduino/packages/builtin/"
export ARDUINO_LOGGING_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/arduino/arduino.logs"

env_dirs=(
  "$ENV_DIRS"
  "$ARDUINO_DIRECTORIES_DATA"
  "$ARDUINO_DIRECTORIES_DOWNLOADS"
  "$ARDUINO_DIRECTORIES_USER"
  "$ARDUINO_DIRECTORIES_BUILTIN_LIBRARIES"
  "$ARDUINO_DIRECTORIES_BUILTIN_TOOLS"
  "$(dirname "$ARDUINO_LOGGING_FILE")"
)

env_dirs=(${(@)env_dirs:#""})
export ENV_DIRS="${(j/:/)env_dirs}"
unset env_dirs

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

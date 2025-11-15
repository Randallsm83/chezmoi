#!/usr/bin/env zsh

export ASDF_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/asdf"
export ASDF_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/asdf"
export ASDF_CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/asdf/asdfrc"
export ASDF_DEFAULT_TOOL_VERSIONS_FILENAME=".config/asdf/tool-versions"
export ASDF_CONCURRENCY="${MACHINE_CORES:-4}"

export ENV_DIRS="$ENV_DIRS:$ASDF_DIR:$(dirname "$ASDF_CONFIG_FILE")"

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

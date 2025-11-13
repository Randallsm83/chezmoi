#!/usr/bin/env zsh

export NPM_CONFIG_USERCONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/npm/npmrc"
export NODE_REPL_HISTORY="${XDG_STATE_HOME:-$HOME/.local/state}/node/repl_history"

export ENV_DIRS="$ENV_DIRS:$(dirname "$NPM_CONFIG_USERCONFIG"):$(dirname "$NODE_REPL_HISTORY")"

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

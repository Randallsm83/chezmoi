#!/usr/bin/env zsh

# TODO: what are these?
export PYTHONUSERBASE="${XDG_DATA_HOME:-$HOME/.local/share}/python"
export PYTHONPYCACHEPREFIX="${XDG_CACHE_HOME:-$HOME/.cache}/python"
export PYTHONSTARTUP="${XDG_CONFIG_HOME:-$HOME/.config}/python/pythonrc"

export ENV_DIRS="$ENV_DIRS:$PYTHONUSERBASE:$PYTHONPYCACHEPREFIX:$(dirname "$PYTHONSTARTUP")"

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

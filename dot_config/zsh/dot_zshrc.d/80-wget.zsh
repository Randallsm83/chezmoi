#!/usr/bin/env zsh

export WGETRC="${XDG_CONFIG_HOME:-$HOME/.config}/wget/wgetrc"

export WGET_HSTS="${XDG_CACHE_HOME:-$HOME/.cache}/wget/wget-hsts"

export ENV_DIRS="$ENV_DIRS:$(dirname "$WGET_HSTS")"

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

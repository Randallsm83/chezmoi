#!/usr/bin/env zsh

update_golang_env() {
  local go_bin_path
  go_bin_path="$(which go 2>/dev/null)"
  if [[ -n "${go_bin_path}" ]]; then
    export GOROOT
    GOROOT="$(dirname "$(dirname "${go_bin_path:A}")")"

    export GOPATH
    GOPATH="$(dirname "${GOROOT:A}")/packages"
  fi
}

autoload -U add-zsh-hook
add-zsh-hook precmd update_golang_env

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

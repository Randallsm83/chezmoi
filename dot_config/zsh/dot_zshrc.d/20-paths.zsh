# ███████╗███████╗██╗  ██╗
# ╚══███╔╝██╔════╝██║  ██║
#   ███╔╝ ███████╗███████║
#  ███╔╝  ╚════██║██╔══██║
# ███████╗███████║██║  ██║
# ╚══════╝╚══════╝╚═╝  ╚═╝
# Z Shell - powerful command interpreter.
#

#!/usr/bin/env zsh

typeset -gU path fpath

path=(
  $HOME/{,s}bin(N)
  $HOME/.local/{,s}bin(N)
  $HOME/.cargo/bin(N)
  /opt/{homebrew,local}/{,s}bin(N)
  $HOME/.local/share/homebrew/{,s}bin(N)
  ${DHSPACE:-$HOME/projects}/ndn/dh/bin(N)
  /usr/local/{,s}bin(N)
  $path
)

fpath+=("${ZSH_COMPLETION_DIR:-}")

if [[ -n "$OSTYPE" && "${(L)OSTYPE}" == *darwin* ]]; then
  export SDKROOT=$(xcrun --show-sdk-path)
fi

if [[ -d "$HOME/.local/lib" ]]; then
  export LDFLAGS="-L$HOME/.local/lib ${LDFLAGS:-}"

  # export LIBRARY_PATH="$HOME/.local/lib${LIBRARY_PATH+:$LIBRARY_PATH}"
  # export LD_LIBRARY_PATH="$HOME/.local/lib${LD_LIBRARY_PATH+:$LD_LIBRARY_PATH}"
fi

if [[ -d "$HOME/.local/include" ]]; then
  export CFLAGS="-I$HOME/.local/include ${CFLAGS:-}"
  export CPPFLAGS="-I$HOME/.local/include ${CPPFLAGS:-}"
  export CXXFLAGS="-I$HOME/.local/include ${CXXFLAGS:-}"

  # export C_PATH="$HOME/.local/include${C_PATH+:$C_PATH}"
  # export C_INCLUDE_PATH="$HOME/.local/include${C_INCLUDE_PATH+:$C_INCLUDE_PATH}"
  # export CPLUS_INCLUDE_PATH="$HOME/.local/include${CPLUS_INCLUDE_PATH+:$CPLUS_INCLUDE_PATH}"
fi

if [[ -d "$HOME/.local/lib/pkgconfig" ]] || [[ -d "$HOME/.local/share/pkgconfig" ]]; then
  export PKG_CONFIG_PATH="$HOME/.local/lib/pkgconfig:$HOME/.local/share/pkgconfig${PKG_CONFIG_PATH+:$PKG_CONFIG_PATH}"
fi

if [[ -d "$HOME/.local/man" ]]; then
  export MANPATH="$HOME/.local/man${MANPATH+:$MANPATH}:"
fi

if [[ -d "$HOME/.local/info" ]]; then
  export INFOPATH="$HOME/.local/info:${INFOPATH:-}"
fi

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

# ███████╗███████╗██╗  ██╗
# ╚══███╔╝██╔════╝██║  ██║
#   ███╔╝ ███████╗███████║
#  ███╔╝  ╚════██║██╔══██║
# ███████╗███████║██║  ██║
# ╚══════╝╚══════╝╚═╝  ╚═╝
# Z Shell - powerful command interpreter.
#

#!/usr/bin/env zsh

export PKG_INSTALL_LIST="${PKG_INSTALL_LIST:-}:perl"
export PERL_CPANM_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/cpanm"

if [[ -n "$SHORT_HOST" && "$SHORT_HOST" == 'yakko' ]]; then
  # export PERL5LIB="${HOME}/projects/ndn/perl"
fi

export ENV_DIRS="$ENV_DIRS:$PERL_CPANM_HOME"

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

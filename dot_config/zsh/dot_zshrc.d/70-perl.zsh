# ██████╗ ███████╗██████╗ ██╗
# ██╔══██╗██╔════╝██╔══██╗██║
# ██████╔╝█████╗  ██████╔╝██║
# ██╔═══╝ ██╔══╝  ██╔══██╗██║
# ██║     ███████╗██║  ██║███████╗
# ╚═╝     ╚══════╝╚═╝  ╚═╝╚══════╝
# Perl language tooling.
#

#!/usr/bin/env zsh

export PKG_INSTALL_LIST="${PKG_INSTALL_LIST:-}:perl"
export PERL_CPANM_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/cpanm"

# XDG-aligned local::lib install root. All Perl modules installed via
#   cpanm -n --local-lib=$HOME/.local Some::Module
# land in ~/.local/lib/perl5 (modules), ~/.local/bin (scripts), and
# ~/.local/share/man (man pages). The exports below make those modules
# importable at runtime and tell cpanm/ExtUtils::MakeMaker/Module::Build
# to use the same prefix when invoked without an explicit --local-lib.
# See: https://metacpan.org/pod/local::lib
if [[ -d "$HOME/.local/lib/perl5" ]]; then
  export PERL5LIB="$HOME/.local/lib/perl5${PERL5LIB:+:$PERL5LIB}"
fi
export PERL_LOCAL_LIB_ROOT="$HOME/.local${PERL_LOCAL_LIB_ROOT:+:$PERL_LOCAL_LIB_ROOT}"
export PERL_MB_OPT="--install_base \"$HOME/.local\""
export PERL_MM_OPT="INSTALL_BASE=$HOME/.local"

if [[ -n "$SHORT_HOST" && "$SHORT_HOST" == 'yakko' ]]; then
  # export PERL5LIB="${HOME}/projects/ndn/perl"
fi

export ENV_DIRS="$ENV_DIRS:$PERL_CPANM_HOME"

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

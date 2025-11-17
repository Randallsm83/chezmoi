#!/usr/bin/env zsh

# This is NOT the typical brew.env mentioned in their docs, that file doesn't support shell expansion...
# This is sourced to make things work better as expected

if (( ! $+commands[brew] )); then
  if [[ -x /opt/homebrew/bin/brew ]]; then
    BREW_LOCATION="/opt/homebrew/bin/brew"
  elif [[ -x "${XDG_DATA_HOME:-$HOME/.local/share}/homebrew/bin/brew" ]]; then
#   export HOMEBREW_PREFIX="${XDG_DATA_HOME:-$HOME/.local/share}/homebrew"
    BREW_LOCATION="${XDG_DATA_HOME:-$HOME/.local/share}/homebrew/bin/brew"
  else
    return
  fi

  # Only add Homebrew installation to PATH, MANPATH, and INFOPATH if brew is
  # not already on the path, to prevent duplicate entries. This aligns with
  # the behavior of the brew installer.sh post-install steps.
  eval "$("$BREW_LOCATION" shellenv)"
  unset BREW_LOCATION
fi

if [[ -z "$HOMEBREW_PREFIX" ]]; then
  # Maintain compatibility with potential custom user profiles, where we had
  # previously relied on always sourcing shellenv. OMZ plugins should not rely
  # on this to be defined due to out of order processing.
  export HOMEBREW_PREFIX="$(brew --prefix)"
fi

if [[ -d "$HOMEBREW_PREFIX/share/zsh/site-functions" ]]; then
  fpath+=("$HOMEBREW_PREFIX/share/zsh/site-functions")
fi

export HOMEBREW_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/homebrew"
export HOMEBREW_BUNDLE_FILE="${DOTFILES:-$HOME/.config/dotfiles}/homebrew/dot-config/homebrew/Brewfile"
export HOMEBREW_BUNDLE_USER_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/homebrew"
export HOMEBREW_LOGS="${XDG_CACHE_HOME:-$HOME/.cache}/homebrew/logs"
export HOMEBREW_TEMP="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/homebrew"

# Performance and behavior options
export HOMEBREW_COLOR=1
export HOMEBREW_EDITOR="nvim"
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_ENV_FILTERING=1
export HOMEBREW_NO_INSECURE_REDIRECT=1
export HOMEBREW_CURL_RETRIES=3
export HOMEBREW_FORCE_BREWED_CURL=1
export HOMEBREW_FORCE_BREWED_CA_CERTIFICATES=1
export HOMEBREW_MAKE_JOBS="${MACHINE_CORES:-4}"
export HOMEBREW_DISPLAY_INSTALL_TIMES=1
export HOMEBREW_BAT=1

# Custom paths
HOMEBREW_OPT="${HOMEBREW_PREFIX}/opt"

export PATH="${HOMEBREW_OPT}/bison/bin${PATH+:$PATH}"
export PATH="${HOMEBREW_OPT}/coreutils/libexec/gnubin${PATH+:$PATH}"
export PATH="${HOMEBREW_OPT}/curl/bin${PATH+:$PATH}"
export PATH="${HOMEBREW_OPT}/ed/libexec/gnubin${PATH+:$PATH}"
export PATH="${HOMEBREW_OPT}/findutils/libexec/gnubin${PATH+:$PATH}"
export PATH="${HOMEBREW_OPT}/file-formula/bin${PATH+:$PATH}"
export PATH="${HOMEBREW_OPT}/flex/bin${PATH+:$PATH}"
export PATH="${HOMEBREW_OPT}/gawk/libexec/gnubin${PATH+:$PATH}"
export PATH="${HOMEBREW_OPT}/grep/libexec/gnubin${PATH+:$PATH}"
export PATH="${HOMEBREW_OPT}/gnu-indent/libexec/gnubin${PATH+:$PATH}"
export PATH="${HOMEBREW_OPT}/gnu-getopt/bin${PATH+:$PATH}"
export PATH="${HOMEBREW_OPT}/gnu-sed/libexec/gnubin${PATH+:$PATH}"
export PATH="${HOMEBREW_OPT}/gnu-tar/libexec/gnubin${PATH+:$PATH}"
export PATH="${HOMEBREW_OPT}/gnu-which/libexec/gnubin${PATH+:$PATH}"
export PATH="${HOMEBREW_OPT}/icu4c/bin${PATH+:$PATH}"
export PATH="${HOMEBREW_OPT}/icu4c/sbin${PATH+:$PATH}"
export PATH="${HOMEBREW_OPT}/jpeg/bin${PATH+:$PATH}"
export PATH="${HOMEBREW_OPT}/krb5/bin${PATH+:$PATH}"
export PATH="${HOMEBREW_OPT}/krb5/sbin${PATH+:$PATH}"
export PATH="${HOMEBREW_OPT}/libiconv/bin${PATH+:$PATH}"
export PATH="${HOMEBREW_OPT}/libpq/bin${PATH+:$PATH}"
export PATH="${HOMEBREW_OPT}/libressl/bin${PATH+:$PATH}"
export PATH="${HOMEBREW_OPT}/libxml2/bin${PATH+:$PATH}"
export PATH="${HOMEBREW_OPT}/m4/bin${PATH+:$PATH}"
export PATH="${HOMEBREW_OPT}/make/libexec/gnubin${PATH+:$PATH}"
export PATH="${HOMEBREW_OPT}/ncurses/bin${PATH+:$PATH}"
export PATH="${HOMEBREW_OPT}/util-linux/bin${PATH+:$PATH}"
export PATH="${HOMEBREW_OPT}/unzip/bin${PATH+:$PATH}"

COMMON_LIB_PATHS=(
  "${HOMEBREW_OPT}/bison/lib"
  "${HOMEBREW_OPT}/flex/lib"
  "${HOMEBREW_OPT}/icu4c/lib"
  "${HOMEBREW_OPT}/jpeg/lib"
  "${HOMEBREW_OPT}/libiconv/lib"
  "${HOMEBREW_OPT}/libpq/lib"
  "${HOMEBREW_OPT}/libressl/lib"
  "${HOMEBREW_OPT}/libxml2/lib"
  "${HOMEBREW_OPT}/curl/lib"
  "${HOMEBREW_OPT}/util-linux/lib"
  # "${HOMEBREW_OPT}/krb5/lib"
  # "${HOMEBREW_OPT}/libedit/lib"
  # "${HOMEBREW_OPT}/openssl/lib"
  # "${HOMEBREW_OPT}/ncurses/lib"
  # "${HOMEBREW_OPT}/readline/lib"
  # "${HOMEBREW_OPT}/zlib/lib"
  "${HOMEBREW_PREFIX}/lib"
)
for lib_path in "${COMMON_LIB_PATHS[@]}"; do
  export LDFLAGS="-L$lib_path ${LDFLAGS:-}"
  export LIBRARY_PATH="$lib_path${LIBRARY_PATH+:$LIBRARY_PATH}"
  export LD_LIBRARY_PATH="$lib_path${LD_LIBRARY_PATH+:$LD_LIBRARY_PATH}"
  export CMAKE_LIBRARY_PATH="$lib_path${CMAKE_LIBRARY_PATH+:$CMAKE_LIBRARY_PATH}"
done

COMMON_INCLUDE_PATHS=(
  "${HOMEBREW_OPT}/flex/include"
  "${HOMEBREW_OPT}/icu4c/include"
  "${HOMEBREW_OPT}/jpeg/include"
  "${HOMEBREW_OPT}/libiconv/include"
  "${HOMEBREW_OPT}/libpq/include"
  "${HOMEBREW_OPT}/libressl/include"
  "${HOMEBREW_OPT}/libxml2/include"
  "${HOMEBREW_OPT}/curl/include"
  "${HOMEBREW_OPT}/util-linux/include"
  # "${HOMEBREW_OPT}/krb5/include"
  # "${HOMEBREW_OPT}/libedit/include"
  # "${HOMEBREW_OPT}/openssl/include"
  # "${HOMEBREW_OPT}/ncurses/include"
  # "${HOMEBREW_OPT}/readline/include"
  # "${HOMEBREW_OPT}/zlib/include"
  "${HOMEBREW_PREFIX}/include"
)
for include_path in "${COMMON_INCLUDE_PATHS[@]}"; do
  export CFLAGS="-I$include_path ${CFLAGS:-}"
  export CPPFLAGS="-I$include_path ${CPPFLAGS:-}"
  export CXXFLAGS="-I$include_path ${CXXFLAGS:-}"
  export C_PATH="$include_path${C_PATH+:$C_PATH}"
  export C_INCLUDE_PATH="$include_path${C_INCLUDE_PATH+:$C_INCLUDE_PATH}"
  export CPLUS_INCLUDE_PATH="$include_path${CPLUS_INCLUDE_PATH+:$CPLUS_INCLUDE_PATH}"
  export CMAKE_INCLUDE_PATH="$include_path${CMAKE_INCLUDE_PATH+:$CMAKE_INCLUDE_PATH}"
done

export CMAKE_PREFIX_PATH="${HOMEBREW_PREFIX}${CMAKE_PREFIX_PATH+:$CMAKE_PREFIX_PATH}"
export CMAKE_INSTALL_PREFIX="${XDG_DATA_HOME:-$HOME/.local/share}"
export CMAKE_C_COMPILER_LAUNCHER="${HOMEBREW_PREFIX}/bin/gcc-14"
export CMAKE_CXX_COMPILER_LAUNCHER="${HOMEBREW_PREFIX}/bin/g++-14"

export PKG_CONFIG_PATH="${HOMEBREW_OPT}/cunit/lib/pkgconfig${PKG_CONFIG_PATH+:$PKG_CONFIG_PATH}"
export PKG_CONFIG_PATH="${HOMEBREW_OPT}/curl/lib/pkgconfig${PKG_CONFIG_PATH+:$PKG_CONFIG_PATH}"
export PKG_CONFIG_PATH="${HOMEBREW_OPT}/icu4c/lib/pkgconfig${PKG_CONFIG_PATH+:$PKG_CONFIG_PATH}"
export PKG_CONFIG_PATH="${HOMEBREW_OPT}/jpeg/lib/pkgconfig${PKG_CONFIG_PATH+:$PKG_CONFIG_PATH}"
export PKG_CONFIG_PATH="${HOMEBREW_OPT}/krb5/lib/pkgconfig${PKG_CONFIG_PATH+:$PKG_CONFIG_PATH}"
export PKG_CONFIG_PATH="${HOMEBREW_OPT}/libatomic_ops/lib/pkgconfig${PKG_CONFIG_PATH+:$PKG_CONFIG_PATH}"
export PKG_CONFIG_PATH="${HOMEBREW_OPT}/libedit/lib/pkgconfig${PKG_CONFIG_PATH+:$PKG_CONFIG_PATH}"
export PKG_CONFIG_PATH="${HOMEBREW_OPT}/libpq/lib/pkgconfig${PKG_CONFIG_PATH+:$PKG_CONFIG_PATH}"
export PKG_CONFIG_PATH="${HOMEBREW_OPT}/libressl/lib/pkgconfig${PKG_CONFIG_PATH+:$PKG_CONFIG_PATH}"
export PKG_CONFIG_PATH="${HOMEBREW_OPT}/libxml2/lib/pkgconfig${PKG_CONFIG_PATH+:$PKG_CONFIG_PATH}"
export PKG_CONFIG_PATH="${HOMEBREW_OPT}/openssl/lib/pkgconfig${PKG_CONFIG_PATH+:$PKG_CONFIG_PATH}"
export PKG_CONFIG_PATH="${HOMEBREW_OPT}/ncurses/lib/pkgconfig${PKG_CONFIG_PATH+:$PKG_CONFIG_PATH}"
export PKG_CONFIG_PATH="${HOMEBREW_OPT}/readline/lib/pkgconfig${PKG_CONFIG_PATH+:$PKG_CONFIG_PATH}"
export PKG_CONFIG_PATH="${HOMEBREW_OPT}/zlib/lib/pkgconfig${PKG_CONFIG_PATH+:$PKG_CONFIG_PATH}"
export PKG_CONFIG_PATH="${HOMEBREW_OPT}/util-linux/lib/pkgconfig${PKG_CONFIG_PATH+:$PKG_CONFIG_PATH}"
export PKG_CONFIG_PATH="${HOMEBREW_PREFIX}/lib/pkgconfig${PKG_CONFIG_PATH+:$PKG_CONFIG_PATH}"
export PKG_CONFIG_PATH="${HOMEBREW_PREFIX}/share/pkgconfig${PKG_CONFIG_PATH+:$PKG_CONFIG_PATH}"

COMMON_PKG_CONFIG_PATHS=(
  "openssl"
  "ncurses"
  "readline"
  "zlib"
  "krb5"
  "libedit"
)
for item in "${COMMON_PKG_CONFIG_PATHS[@]}"; do
  export LDFLAGS="$(pkg-config --libs-only-L $item) ${LDFLAGS:-}"
  export CFLAGS="$(pkg-config --cflags $item) ${CFLAGS:-}"
  export CPPFLAGS="$(pkg-config --cflags $item) ${CPPFLAGS:-}"
  export CXXFLAGS="$(pkg-config --cflags $item) ${CXXFLAGS:-}"
done

if [[ -n "$SHORT_HOST" && "$SHORT_HOST" == 'yakko' ]]; then
  export PKG_CONFIG_PATH="${PKG_CONFIG_PATH:+$PKG_CONFIG_PATH:}/usr/lib/x86_64-linux-gnu/pkgconfig"
fi

export PKG_CONFIG_LIBDIR="${PKG_CONFIG_PATH}${PKG_CONFIG_LIBDIR+:$PKG_CONFIG_LIBDIR}"

if [[ $OSTYPE != 'Darwin' ]]; then
  # Linux only
  # export PATH="$HOMEBREW_OPT/glibc/bin${PATH+:$PATH}"
  # export PATH="$HOMEBREW_OPT/glibc/sbin${PATH+:$PATH}"
  # export LDFLAGS="-L$HOMEBREW_OPT/glibc/lib ${LDFLAGS:-}"
  # export CFLAGS="-I$HOMEBREW_OPT/glibc/include ${CFLAGS:-}"
  # export CPPFLAGS="-I$HOMEBREW_OPT/glibc/include ${CPPFLAGS:-}"
  # export CXXFLAGS="-I$HOMEBREW_OPT/glibc/include ${CXXFLAGS:-}"
  # export LIBRARY_PATH="$HOMEBREW_OPT/glibc/lib${LIBRARY_PATH+:$LIBRARY_PATH}"
  # export LD_LIBRARY_PATH="$HOMEBREW_OPT/glibc/lib${LD_LIBRARY_PATH+:$LD_LIBRARY_PATH}"
  # export C_PATH="$HOMEBREW_OPT/glibc/include${C_PATH+:$C_PATH}"
  # export C_INCLUDE_PATH="$HOMEBREW_OPT/glibc/include${C_INCLUDE_PATH+:$C_INCLUDE_PATH}"
  # export CPLUS_INCLUDE_PATH="$HOMEBREW_OPT/glibc/include${CPLUS_INCLUDE_PATH+:$CPLUS_INCLUDE_PATH}"
elif [[ $OSTYPE == 'Darwin' ]]; then
  # export CLANG_CONFIG_FILE_SYSTEM_DIR="$HOMEBREW_PREFIX/etc/clang"
  # export CLANG_CONFIG_FILE_USER_DIR="$XDG_CONFIG_HOME/clang"
fi

unset HOMEBREW_OPT
unset COMMON_LIB_PATHS
unset COMMON_INCLUDE_PATHS
unset COMMON_PKG_CONFIG_PATHS

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

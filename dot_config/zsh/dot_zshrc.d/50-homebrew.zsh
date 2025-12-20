# ███████╗███████╗██╗  ██╗
# ╚══███╔╝██╔════╝██║  ██║
#   ███╔╝ ███████╗███████║
#  ███╔╝  ╚════██║██╔══██║
# ███████╗███████║██║  ██║
# ╚══════╝╚══════╝╚═╝  ╚═╝
# Z Shell - powerful command interpreter.
#

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

# =================================================================================================
# Homebrew build environment
# =================================================================================================
HOMEBREW_OPT="${HOMEBREW_PREFIX}/opt"

# Helper function to add path directory
_add_path() {
  local path_dir="$1"
  [[ ! -d "$path_dir" ]] && return
  export PATH="$path_dir${PATH+:$PATH}"
}

# Helper function to add library paths
_add_lib_paths() {
  local lib_dir="$1"
  [[ ! -d "$lib_dir" ]] && return
  export LDFLAGS="-L$lib_dir ${LDFLAGS:-}"
  export LIBRARY_PATH="$lib_dir${LIBRARY_PATH+:$LIBRARY_PATH}"
  export LD_LIBRARY_PATH="$lib_dir${LD_LIBRARY_PATH+:$LD_LIBRARY_PATH}"
  export CMAKE_LIBRARY_PATH="$lib_dir${CMAKE_LIBRARY_PATH+:$CMAKE_LIBRARY_PATH}"
}

# Helper function to add include paths
_add_include_paths() {
  local inc_dir="$1"
  [[ ! -d "$inc_dir" ]] && return
  export CFLAGS="-I$inc_dir ${CFLAGS:-}"
  export CPPFLAGS="-I$inc_dir ${CPPFLAGS:-}"
  export CXXFLAGS="-I$inc_dir ${CXXFLAGS:-}"
  export C_PATH="$inc_dir${C_PATH+:$C_PATH}"
  export C_INCLUDE_PATH="$inc_dir${C_INCLUDE_PATH+:$C_INCLUDE_PATH}"
  export CPLUS_INCLUDE_PATH="$inc_dir${CPLUS_INCLUDE_PATH+:$CPLUS_INCLUDE_PATH}"
  export CMAKE_INCLUDE_PATH="$inc_dir${CMAKE_INCLUDE_PATH+:$CMAKE_INCLUDE_PATH}"
}

# Helper function to add pkg-config paths
_add_pkgconfig_path() {
  local pkg_dir="$1"
  [[ ! -d "$pkg_dir" ]] && return
  export PKG_CONFIG_PATH="$pkg_dir${PKG_CONFIG_PATH+:$PKG_CONFIG_PATH}"
}

# Add bin/sbin directories to PATH
_add_path "${HOMEBREW_OPT}/bison/bin"
_add_path "${HOMEBREW_OPT}/coreutils/libexec/gnubin"
_add_path "${HOMEBREW_OPT}/curl/bin"
_add_path "${HOMEBREW_OPT}/ed/libexec/gnubin"
_add_path "${HOMEBREW_OPT}/findutils/libexec/gnubin"
_add_path "${HOMEBREW_OPT}/file-formula/bin"
_add_path "${HOMEBREW_OPT}/flex/bin"
_add_path "${HOMEBREW_OPT}/gawk/libexec/gnubin"
_add_path "${HOMEBREW_OPT}/grep/libexec/gnubin"
_add_path "${HOMEBREW_OPT}/gnu-indent/libexec/gnubin"
_add_path "${HOMEBREW_OPT}/gnu-getopt/bin"
_add_path "${HOMEBREW_OPT}/gnu-sed/libexec/gnubin"
_add_path "${HOMEBREW_OPT}/gnu-tar/libexec/gnubin"
_add_path "${HOMEBREW_OPT}/gnu-which/libexec/gnubin"
_add_path "${HOMEBREW_OPT}/icu4c/bin"
_add_path "${HOMEBREW_OPT}/icu4c/sbin"
_add_path "${HOMEBREW_OPT}/jpeg/bin"
_add_path "${HOMEBREW_OPT}/krb5/bin"
_add_path "${HOMEBREW_OPT}/krb5/sbin"
_add_path "${HOMEBREW_OPT}/libiconv/bin"
_add_path "${HOMEBREW_OPT}/libpq/bin"
_add_path "${HOMEBREW_OPT}/libressl/bin"
_add_path "${HOMEBREW_OPT}/libxml2/bin"
_add_path "${HOMEBREW_OPT}/m4/bin"
_add_path "${HOMEBREW_OPT}/make/libexec/gnubin"
_add_path "${HOMEBREW_OPT}/ncurses/bin"
_add_path "${HOMEBREW_OPT}/util-linux/bin"
_add_path "${HOMEBREW_OPT}/unzip/bin"

# Add library directories
_add_lib_paths "${HOMEBREW_OPT}/bison/lib"
_add_lib_paths "${HOMEBREW_OPT}/flex/lib"
_add_lib_paths "${HOMEBREW_OPT}/icu4c/lib"
_add_lib_paths "${HOMEBREW_OPT}/jpeg/lib"
_add_lib_paths "${HOMEBREW_OPT}/libiconv/lib"
_add_lib_paths "${HOMEBREW_OPT}/libpq/lib"
_add_lib_paths "${HOMEBREW_OPT}/libressl/lib"
_add_lib_paths "${HOMEBREW_OPT}/libxml2/lib"
_add_lib_paths "${HOMEBREW_OPT}/curl/lib"
_add_lib_paths "${HOMEBREW_OPT}/util-linux/lib"
_add_lib_paths "${HOMEBREW_PREFIX}/lib"
# Uncomment if needed:
# _add_lib_paths "${HOMEBREW_OPT}/krb5/lib"
# _add_lib_paths "${HOMEBREW_OPT}/libedit/lib"
# _add_lib_paths "${HOMEBREW_OPT}/openssl/lib"
# _add_lib_paths "${HOMEBREW_OPT}/ncurses/lib"
# _add_lib_paths "${HOMEBREW_OPT}/readline/lib"
# _add_lib_paths "${HOMEBREW_OPT}/zlib/lib"

# Add include directories
_add_include_paths "${HOMEBREW_OPT}/flex/include"
_add_include_paths "${HOMEBREW_OPT}/icu4c/include"
_add_include_paths "${HOMEBREW_OPT}/jpeg/include"
_add_include_paths "${HOMEBREW_OPT}/libiconv/include"
_add_include_paths "${HOMEBREW_OPT}/libpq/include"
_add_include_paths "${HOMEBREW_OPT}/libressl/include"
_add_include_paths "${HOMEBREW_OPT}/libxml2/include"
_add_include_paths "${HOMEBREW_OPT}/curl/include"
_add_include_paths "${HOMEBREW_OPT}/util-linux/include"
_add_include_paths "${HOMEBREW_PREFIX}/include"
# Uncomment if needed:
# _add_include_paths "${HOMEBREW_OPT}/krb5/include"
# _add_include_paths "${HOMEBREW_OPT}/libedit/include"
# _add_include_paths "${HOMEBREW_OPT}/openssl/include"
# _add_include_paths "${HOMEBREW_OPT}/ncurses/include"
# _add_include_paths "${HOMEBREW_OPT}/readline/include"
# _add_include_paths "${HOMEBREW_OPT}/zlib/include"

# CMake configuration
export CMAKE_PREFIX_PATH="${HOMEBREW_PREFIX}${CMAKE_PREFIX_PATH+:$CMAKE_PREFIX_PATH}"
export CMAKE_INSTALL_PREFIX="${XDG_DATA_HOME:-$HOME/.local/share}"
export CMAKE_C_COMPILER_LAUNCHER="${HOMEBREW_PREFIX}/bin/gcc-14"
export CMAKE_CXX_COMPILER_LAUNCHER="${HOMEBREW_PREFIX}/bin/g++-14"

# Add pkg-config paths
_add_pkgconfig_path "${HOMEBREW_OPT}/cunit/lib/pkgconfig"
_add_pkgconfig_path "${HOMEBREW_OPT}/curl/lib/pkgconfig"
_add_pkgconfig_path "${HOMEBREW_OPT}/icu4c/lib/pkgconfig"
_add_pkgconfig_path "${HOMEBREW_OPT}/jpeg/lib/pkgconfig"
_add_pkgconfig_path "${HOMEBREW_OPT}/krb5/lib/pkgconfig"
_add_pkgconfig_path "${HOMEBREW_OPT}/libatomic_ops/lib/pkgconfig"
_add_pkgconfig_path "${HOMEBREW_OPT}/libedit/lib/pkgconfig"
_add_pkgconfig_path "${HOMEBREW_OPT}/libpq/lib/pkgconfig"
_add_pkgconfig_path "${HOMEBREW_OPT}/libressl/lib/pkgconfig"
_add_pkgconfig_path "${HOMEBREW_OPT}/libxml2/lib/pkgconfig"
_add_pkgconfig_path "${HOMEBREW_OPT}/openssl/lib/pkgconfig"
_add_pkgconfig_path "${HOMEBREW_OPT}/ncurses/lib/pkgconfig"
_add_pkgconfig_path "${HOMEBREW_OPT}/readline/lib/pkgconfig"
_add_pkgconfig_path "${HOMEBREW_OPT}/zlib/lib/pkgconfig"
_add_pkgconfig_path "${HOMEBREW_OPT}/util-linux/lib/pkgconfig"
_add_pkgconfig_path "${HOMEBREW_PREFIX}/lib/pkgconfig"
_add_pkgconfig_path "${HOMEBREW_PREFIX}/share/pkgconfig"

# Use pkg-config to get flags for common libraries (if pkg-config is available)
if (( $+commands[pkg-config] )); then
  for pkg in openssl ncurses readline zlib krb5 libedit; do
    if pkg-config --exists $pkg 2>/dev/null; then
      export LDFLAGS="$(pkg-config --libs-only-L $pkg) ${LDFLAGS:-}"
      export CFLAGS="$(pkg-config --cflags $pkg) ${CFLAGS:-}"
      export CPPFLAGS="$(pkg-config --cflags $pkg) ${CPPFLAGS:-}"
      export CXXFLAGS="$(pkg-config --cflags $pkg) ${CXXFLAGS:-}"
    fi
  done
fi

# Host-specific configuration
if [[ -n "$SHORT_HOST" && "$SHORT_HOST" == 'yakko' ]]; then
  export PKG_CONFIG_PATH="${PKG_CONFIG_PATH:+$PKG_CONFIG_PATH:}/usr/lib/x86_64-linux-gnu/pkgconfig"
fi

export PKG_CONFIG_LIBDIR="${PKG_CONFIG_PATH}${PKG_CONFIG_LIBDIR+:$PKG_CONFIG_LIBDIR}"

# Platform-specific settings
if [[ $OSTYPE != 'Darwin' ]]; then
  # Linux only - uncomment if needed
  # _add_path "${HOMEBREW_OPT}/glibc/bin"
  # _add_path "${HOMEBREW_OPT}/glibc/sbin"
  # _add_lib_paths "${HOMEBREW_OPT}/glibc/lib"
  # _add_include_paths "${HOMEBREW_OPT}/glibc/include"
  :
# elif [[ $OSTYPE == 'Darwin' ]]; then
  # macOS only
  # export CLANG_CONFIG_FILE_SYSTEM_DIR="$HOMEBREW_PREFIX/etc/clang"
  # export CLANG_CONFIG_FILE_USER_DIR="$XDG_CONFIG_HOME/clang"
fi

# Cleanup
unset HOMEBREW_OPT
unset -f _add_path _add_lib_paths _add_include_paths _add_pkgconfig_path

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

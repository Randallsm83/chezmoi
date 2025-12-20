# ███╗   ███╗██╗███████╗███████╗
# ████╗ ████║██║██╔════╝██╔════╝
# ██╔████╔██║██║███████╗█████╗
# ██║╚██╔╝██║██║╚════██║██╔══╝
# ██║ ╚═╝ ██║██║███████║███████╗
# ╚═╝     ╚═╝╚═╝╚══════╝╚══════╝
# Polyglot runtime manager
#

#!/usr/bin/env zsh

# =================================================================================================
# Mise Configuration
# =================================================================================================
# Initialize mise (formerly rtx) - a polyglot runtime manager
# Set mise directories explicitly to prevent reading Windows config via WSL interop

export MISE_DATA_DIR="$HOME/.local/share/mise"
export MISE_CACHE_DIR="$HOME/.cache/mise"
export MISE_CONFIG_DIR="$HOME/.config/mise"
export MISE_GLOBAL_CONFIG_FILE="$HOME/.config/mise/config.toml"

# CRITICAL: Ignore Windows config paths mounted via WSL - must be env var, not config file setting
# because mise reads Windows config before it reads the setting that tells it to ignore it
export MISE_IGNORED_CONFIG_PATHS="/mnt/c:/mnt/d"

# Cargo and Rustup homes (used by mise for Rust installations)

export MISE_CARGO_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/cargo"
export MISE_RUSTUP_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/rustup"

# Check direct path first since PATH may not include ~/.local/bin yet
if [[ -x "$HOME/.local/bin/mise" ]]; then
  eval "$("$HOME/.local/bin/mise" activate zsh)"
elif command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

# =================================================================================================
# Mise-installed tools paths
# =================================================================================================
# Note: mise activate already handles PATH setup. This section adds compiler/linker flags
# for tools that need them when building native extensions or compiling C/C++ code.

if (( $+commands[mise] )); then
  MISE_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/mise"
  MISE_INSTALLS="$MISE_DATA/installs"

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
    export C_INCLUDE_PATH="$inc_dir${C_INCLUDE_PATH+:$C_INCLUDE_PATH}"
    export C_PATH="$inc_dir${C_PATH+:$C_PATH}"
    export CPLUS_INCLUDE_PATH="$inc_dir${CPLUS_INCLUDE_PATH+:$CPLUS_INCLUDE_PATH}"
    export CMAKE_INCLUDE_PATH="$inc_dir${CMAKE_INCLUDE_PATH+:$CMAKE_INCLUDE_PATH}"
  }

  # Helper function to add pkg-config paths
  _add_pkgconfig_path() {
    local pkg_dir="$1"
    [[ ! -d "$pkg_dir" ]] && return
    export PKG_CONFIG_PATH="$pkg_dir${PKG_CONFIG_PATH+:$PKG_CONFIG_PATH}"
  }

  # Helper function to setup a tool's paths (lib, include, pkgconfig)
  _setup_tool_paths() {
    local tool_dir="$1"
    local include_subdir="${2:-include}"  # Default to 'include', allow override
    
    [[ ! -d "$tool_dir" ]] && return
    
    # Add library paths
    [[ -d "$tool_dir/lib" ]] && _add_lib_paths "$tool_dir/lib"
    
    # Add include paths
    if [[ -d "$tool_dir/$include_subdir" ]]; then
      _add_include_paths "$tool_dir/$include_subdir"
    fi
    
    # Add pkg-config paths
    [[ -d "$tool_dir/lib/pkgconfig" ]] && _add_pkgconfig_path "$tool_dir/lib/pkgconfig"
  }

  # Python - needs special handling for version-specific paths
  if [[ -d "$MISE_INSTALLS/python" ]]; then
    for python_dir in "$MISE_INSTALLS/python"/*(/N); do
      [[ ! -d "$python_dir" ]] && continue
      # Python lib config directories
      for lib_dir in "$python_dir/lib"/python*(/N); do
        _add_lib_paths "$lib_dir/config"
      done
      # Python include directories
      for inc_dir in "$python_dir/include"/python*(/N); do
        _add_include_paths "$inc_dir"
      done
      _add_pkgconfig_path "$python_dir/lib/pkgconfig"
    done
  fi

  # Ruby
  [[ -d "$MISE_INSTALLS/ruby" ]] && \
    for ruby_dir in "$MISE_INSTALLS/ruby"/*(/N); do
      _setup_tool_paths "$ruby_dir"
    done

  # Node.js - special include path
  [[ -d "$MISE_INSTALLS/node" ]] && \
    for node_dir in "$MISE_INSTALLS/node"/*(/N); do
      _setup_tool_paths "$node_dir" "include/node"
    done

  # Go - set GOROOT
  [[ -d "$MISE_INSTALLS/go" ]] && \
    for go_dir in "$MISE_INSTALLS/go"/*(/N); do
      [[ -d "$go_dir" ]] && export GOROOT="$go_dir"
      _setup_tool_paths "$go_dir"
    done

  # Rust - set RUSTUP_HOME and CARGO_HOME
  [[ -d "$MISE_INSTALLS/rust" ]] && \
    for rust_dir in "$MISE_INSTALLS/rust"/*(/N); do
      [[ -d "$rust_dir/lib" ]] && {
        _add_lib_paths "$rust_dir/lib"
        export RUSTUP_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/rustup"
        export CARGO_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/cargo"
      }
    done

  # Lua
  [[ -d "$MISE_INSTALLS/lua" ]] && \
    for lua_dir in "$MISE_INSTALLS/lua"/*(/N); do
      _setup_tool_paths "$lua_dir"
    done

  # LuaJIT - special include path
  [[ -d "$MISE_INSTALLS/luajit" ]] && \
    for luajit_dir in "$MISE_INSTALLS/luajit"/*(/N); do
      [[ -d "$luajit_dir/lib" ]] && _add_lib_paths "$luajit_dir/lib"
      [[ -d "$luajit_dir/include/luajit-2.1" ]] && _add_include_paths "$luajit_dir/include/luajit-2.1"
      _add_pkgconfig_path "$luajit_dir/lib/pkgconfig"
    done

  # SQLite
  [[ -d "$MISE_INSTALLS/sqlite" ]] && \
    for sqlite_dir in "$MISE_INSTALLS/sqlite"/*(/N); do
      _setup_tool_paths "$sqlite_dir"
    done

  # Bun - set BUN_INSTALL
  [[ -d "$MISE_INSTALLS/bun" ]] && \
    for bun_dir in "$MISE_INSTALLS/bun"/*(/N); do
      [[ -d "$bun_dir" ]] && export BUN_INSTALL="$bun_dir"
    done

  # Vim
  [[ -d "$MISE_INSTALLS/vim" ]] && \
    for vim_dir in "$MISE_INSTALLS/vim"/*(/N); do
      [[ -d "$vim_dir/lib" ]] && _add_lib_paths "$vim_dir/lib"
    done

  # Neovim
  [[ -d "$MISE_INSTALLS/neovim" ]] && \
    for nvim_dir in "$MISE_INSTALLS/neovim"/*(/N); do
      [[ -d "$nvim_dir/lib" ]] && _add_lib_paths "$nvim_dir/lib"
    done

  # Cleanup
  unset MISE_DATA MISE_INSTALLS
  unset -f _add_lib_paths _add_include_paths _add_pkgconfig_path _setup_tool_paths
fi

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

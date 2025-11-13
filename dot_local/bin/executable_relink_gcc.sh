#!/usr/bin/env bash

# Ensure HOMEBREW_PREFIX is set
if [[ -z "$HOMEBREW_PREFIX" ]]; then
    echo "Error: HOMEBREW_PREFIX is not set. Please set it and try again."
    exit 1
fi

# Path to the bin directory
bin_dir="$HOMEBREW_PREFIX/bin"

# Function to update symlink for a given binary (e.g., gcc or g++)
update_symlink() {
    local binary=$1

    # Find the latest versioned symbolic link for the binary
    local latest_binary=$(find "$bin_dir" -type l -name "$binary-[0-9]*" -exec basename {} \; | sort -V | tail -n 1)

    # Check if a valid symbolic link was found
    if [[ -z "$latest_binary" ]]; then
        echo "Error: No valid $binary-* symbolic links found in $bin_dir."
        return 1
    fi

    # Create the full path to the latest binary
    local latest_binary_path="$bin_dir/$latest_binary"

    # Create or update the symlink
    ln -sf "$latest_binary_path" "$bin_dir/$binary"
    echo "Symlink created: $binary -> $latest_binary_path"
}

# Update symlinks for gcc and g++
update_symlink "gcc"
update_symlink "g++"

exec $SHELL -l

# -------------------------------------------------------------------------------------------------
# -*- mode: bash; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=bash sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

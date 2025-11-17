#!/usr/bin/env bash
#
# Bootstrap script for Unix systems (Linux/WSL/macOS)
# 
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Randallsm83/dotfiles-redux/main/setup.sh | bash
#   OR
#   ./setup.sh

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

REPO="${REPO:-Randallsm83/dotfiles-redux}"
BRANCH="${BRANCH:-main}"
CHEZMOI_VERSION="${CHEZMOI_VERSION:-latest}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================================================
# Helper Functions
# ============================================================================

log_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

detect_platform() {
    local os=""
    local is_wsl=false
    
    case "$(uname -s)" in
        Linux*)
            os="linux"
            # Check for WSL
            if grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null; then
                is_wsl=true
            fi
            ;;
        Darwin*)
            os="darwin"
            ;;
        *)
            log_error "Unsupported operating system: $(uname -s)"
            exit 1
            ;;
    esac
    
    echo "$os"
    if [ "$is_wsl" = true ]; then
        log_info "Detected WSL environment"
    fi
}

# ============================================================================
# XDG Environment Setup
# ============================================================================

setup_xdg_env() {
    log_info "Setting up XDG environment variables..."
    
    # Set XDG directories if not already set
    export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
    export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
    export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
    export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
    
    # Create directories
    mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME"
    
    log_success "XDG directories configured"
}

# ============================================================================
# Mise Installation
# ============================================================================

install_mise() {
    if command_exists mise; then
        log_success "mise is already installed"
        return 0
    fi
    
    log_info "Installing mise..."
    
    if command_exists curl; then
        curl https://mise.run | sh
        
        # Add mise to PATH for current session
        export PATH="$HOME/.local/bin:$PATH"
        
        # Activate mise
        if [ -f "$HOME/.local/bin/mise" ]; then
            eval "$($HOME/.local/bin/mise activate bash)"
        fi
        
        log_success "mise installed successfully"
    else
        log_error "curl is not available. Cannot install mise."
        return 1
    fi
}

# ============================================================================
# Chezmoi Installation
# ============================================================================

install_chezmoi() {
    if command_exists chezmoi; then
        log_success "chezmoi is already installed"
        return 0
    fi
    
    log_info "Installing chezmoi..."
    
    # Try mise first (preferred)
    if command_exists mise; then
        log_info "Installing chezmoi via mise..."
        mise use -g chezmoi@"$CHEZMOI_VERSION"
        log_success "chezmoi installed via mise"
        return 0
    fi
    
    # Fallback to official install script
    log_info "Installing chezmoi via curl..."
    if command_exists curl; then
        sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
        export PATH="$HOME/.local/bin:$PATH"
        log_success "chezmoi installed via curl"
        return 0
    fi
    
    log_error "Failed to install chezmoi: no suitable method available"
    return 1
}

# ============================================================================
# Chezmoi Initialization
# ============================================================================

init_chezmoi() {
    log_info "Initializing chezmoi from $REPO..."
    
    local repo_url="https://github.com/${REPO}.git"
    
    # Initialize and apply dotfiles
    if chezmoi init --apply --branch "$BRANCH" "$repo_url"; then
        log_success "Dotfiles applied successfully"
        return 0
    else
        log_error "Failed to initialize chezmoi"
        return 1
    fi
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    echo ""
    echo "╔═══════════════════════════════════════════╗"
    echo "║   Dotfiles Bootstrap (Unix)              ║"
    echo "╚═══════════════════════════════════════════╝"
    echo ""
    
    # Detect platform
    local platform
    platform=$(detect_platform)
    log_info "Platform: $platform"
    
    # Setup XDG environment
    setup_xdg_env
    
    # Install mise
    if ! install_mise; then
        log_warning "mise installation failed, continuing without it"
    fi
    
    # Install chezmoi
    if ! install_chezmoi; then
        log_error "Bootstrap failed: Could not install chezmoi"
        exit 1
    fi
    
    # Initialize chezmoi and apply dotfiles
    if ! init_chezmoi; then
        log_error "Bootstrap failed: Could not apply dotfiles"
        exit 1
    fi
    
    # Summary
    echo ""
    echo "╔═══════════════════════════════════════════╗"
    echo "║          Bootstrap Complete! 🎉           ║"
    echo "╚═══════════════════════════════════════════╝"
    echo ""
    log_info "Next steps:"
    echo "  1. Restart your shell or source your profile"
    echo "  2. Run: chezmoi diff (to see applied changes)"
    echo "  3. Run: chezmoi edit --apply <file> (to modify configs)"
    echo ""
    
    case "$platform" in
        darwin)
            log_info "macOS: Run 'exec zsh' to restart your shell"
            ;;
        linux)
            log_info "Linux: Run 'exec zsh' or restart your terminal"
            ;;
    esac
    
    echo ""
}

# Run main function
main "$@"

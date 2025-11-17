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

REPO="${REPO:-Randallsm83/dotfiles}"
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
# Chezmoi One-Line Install
# ============================================================================

install_and_apply_dotfiles() {
    log_info "Installing chezmoi and applying dotfiles from $REPO..."
    log_info "This will install mise, all tools, and configure your environment"
    
    if ! command_exists curl; then
        log_error "curl is not available. Cannot proceed."
        return 1
    fi
    
    # Use chezmoi's one-line install that does everything
    # This installs chezmoi AND applies the dotfiles in one step
    if sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply "$REPO" --branch "$BRANCH"; then
        log_success "Dotfiles applied successfully"
        return 0
    else
        log_error "Failed to install chezmoi and apply dotfiles"
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
    
    # Install chezmoi and apply dotfiles in one step
    if ! install_and_apply_dotfiles; then
        log_error "Bootstrap failed: Could not install chezmoi and apply dotfiles"
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

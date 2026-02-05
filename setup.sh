#!/usr/bin/env bash
#
# Bootstrap script for Unix systems (Linux/WSL/macOS)
# 
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Randallsm83/dotfiles/main/setup.sh | bash
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

# Check if user has sudo access
has_sudo() {
    # If running as root, always return true
    if [ "$EUID" -eq 0 ]; then
        return 0
    fi
    
    # Check if sudo command exists
    if ! command_exists sudo; then
        return 1
    fi
    
    # Try to run sudo with non-interactive password check
    if sudo -n true 2>/dev/null; then
        return 0
    fi
    
    # sudo exists but requires password or is denied
    return 1
}

# Try to run command with sudo if available, otherwise run without
execute_with_privilege() {
    if [ "$EUID" -eq 0 ]; then
        # Already root, execute directly
        "$@"
    elif has_sudo; then
        # Has sudo, use it
        sudo "$@"
    else
        # No sudo, try without (will fail if privileges needed)
        log_warning "No sudo access, attempting without privileges..."
        "$@"
    fi
}

is_zsh_default_shell() {
    local current_shell
    if [ -n "${SUDO_USER:-}" ]; then
        current_shell=$(getent passwd "$SUDO_USER" | cut -d: -f7)
    else
        current_shell=$(getent passwd "$USER" | cut -d: -f7)
    fi
    [ "$current_shell" = "$(command -v zsh)" ] || [ "$current_shell" = "/bin/zsh" ] || [ "$current_shell" = "/usr/bin/zsh" ]
}

set_zsh_as_default_shell() {
    if ! command_exists zsh; then
        log_warning "zsh not found in PATH, skipping shell change"
        return 1
    fi
    
    if is_zsh_default_shell; then
        log_success "zsh is already the default shell"
        return 0
    fi
    
    local zsh_path
    zsh_path=$(command -v zsh)
    
    log_info "Setting zsh as default shell..."
    log_warning "You may be prompted for your password"
    
    if [ "$EUID" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
        # Running as root, change shell for the actual user
        if chsh -s "$zsh_path" "$SUDO_USER" 2>/dev/null; then
            log_success "Default shell changed to zsh for user $SUDO_USER"
            return 0
        fi
    else
        # Running as normal user
        if chsh -s "$zsh_path" 2>/dev/null; then
            log_success "Default shell changed to zsh"
            return 0
        fi
    fi
    
    # chsh failed - provide fallback instructions
    log_warning "Failed to change default shell automatically"
    log_warning "Please run manually: chsh -s $zsh_path"
    log_warning "Or add this to /etc/passwd if in a container environment"
    return 1
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
# Pre-flight Checks
# ============================================================================

run_preflight_checks() {
    log_info "Running pre-flight checks..."
    echo ""
    
    local all_passed=true
    
    # Check 1: Internet connectivity
    printf "  [1/4] Internet connectivity..."
    if curl -fsSL --connect-timeout 5 https://github.com >/dev/null 2>&1; then
        echo " ✓"
    else
        echo " ✗"
        log_error "Cannot reach github.com"
        all_passed=false
    fi
    
    # Check 2: Sudo availability
    printf "  [2/4] Sudo access..."
    if has_sudo; then
        echo " ✓"
    else
        echo " ⚠"
        log_warning "No sudo access detected"
        log_info "Will attempt user-space installations via mise"
    fi
    
    # Check 3: Required tools
    printf "  [3/4] Essential tools (git, curl)..."
    if command_exists git && command_exists curl; then
        echo " ✓"
    else
        echo " ⚠"
        log_warning "Some essential tools missing (will attempt to install)"
    fi
    
    # Check 4: Shell
    printf "  [4/4] Shell environment..."
    if [ -n "${SHELL}" ]; then
        echo " ✓"
    else
        echo " ⚠"
        log_warning "SHELL variable not set"
    fi
    
    echo ""
    
    if [ "$all_passed" = true ]; then
        log_success "Pre-flight checks passed!"
        return 0
    else
        log_warning "Some pre-flight checks failed, but continuing..."
        return 0  # Don't fail bootstrap on warnings
    fi
}

# ============================================================================
# Package Installation
# ============================================================================

# ============================================================================
# Locale Setup
# ============================================================================

setup_locale() {
    log_info "Checking locale configuration..."
    
    # Only needed on Linux
    if [ "$(uname -s)" != "Linux" ]; then
        return 0
    fi
    
    # Check if en_US.UTF-8 locale is available
    if locale -a 2>/dev/null | grep -qi "en_US.utf8\|en_US.UTF-8"; then
        log_success "en_US.UTF-8 locale already available"
        return 0
    fi
    
    log_info "Generating en_US.UTF-8 locale..."
    
    if command_exists pacman; then
        # Arch Linux - uncomment locale in locale.gen and generate
        if [ -f /etc/locale.gen ]; then
            execute_with_privilege sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
            execute_with_privilege locale-gen
        fi
    elif command_exists apt-get; then
        # Debian/Ubuntu
        if command_exists locale-gen; then
            execute_with_privilege locale-gen en_US.UTF-8
        fi
    elif command_exists dnf; then
        # Fedora/RHEL - install glibc-langpack
        execute_with_privilege dnf install -y glibc-langpack-en
    fi
    
    # Set locale environment variables for current session
    export LANG="en_US.UTF-8"
    export LC_ALL="en_US.UTF-8"
    
    log_success "Locale configured"
}

install_base_packages() {
    log_info "Checking for essential packages..."
    
    local needs_install=false
    
    # Check for essential tools
    if ! command_exists git; then
        log_warning "git is not installed"
        needs_install=true
    fi
    
    if ! command_exists curl; then
        log_warning "curl is not installed"
        needs_install=true
    fi
    
    if ! command_exists make; then
        log_warning "make is not installed"
        needs_install=true
    fi
    
    if ! command_exists unzip; then
        log_warning "unzip is not installed"
        needs_install=true
    fi
    
    if [ "$needs_install" = false ]; then
        log_success "Essential packages already installed"
        return 0
    fi
    
    log_info "Installing essential packages..."
    
    # Detect package manager and install
    if command_exists pacman; then
        # Arch Linux - install comprehensive package set
        log_info "Using pacman (Arch Linux)"
        local packages="sudo base-devel git curl wget unzip zip openssl readline zlib libyaml libffi zsh"
        execute_with_privilege pacman -Syu --noconfirm $packages
    elif command_exists apt-get; then
        # Debian/Ubuntu
        log_info "Using apt-get (Debian/Ubuntu)"
        local packages="git curl wget unzip zip build-essential libssl-dev libreadline-dev zlib1g-dev libyaml-dev libffi-dev zsh"
        if has_sudo || [ "$EUID" -eq 0 ]; then
            execute_with_privilege apt-get update
            execute_with_privilege apt-get install -y $packages
        else
            log_warning "No sudo access - skipping system packages"
            log_info "Essential tools will be installed via mise in user space"
            return 0
        fi
    elif command_exists dnf; then
        # Fedora/RHEL
        log_info "Using dnf (Fedora/RHEL)"
        local packages="git curl wget unzip zip gcc gcc-c++ make openssl-devel readline-devel zlib-devel libyaml-devel libffi-devel zsh"
        execute_with_privilege dnf install -y $packages
    elif command_exists brew; then
        # macOS with Homebrew
        log_info "Using brew (macOS)"
        brew install git curl wget unzip openssl readline libyaml libffi zsh
    else
        log_error "No supported package manager found (pacman, apt-get, dnf, brew)"
        if ! has_sudo; then
            log_info "No sudo access - will rely on mise for user-space installations"
            return 0
        fi
        log_error "Please install git and curl manually"
        return 1
    fi
    
    log_success "Essential packages installed"
    
    # Set zsh as default shell if installed
    if command_exists zsh; then
        set_zsh_as_default_shell
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
    # --ssh forces SSH URL instead of HTTPS for the git remote
    if sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --ssh "$REPO" --branch "$BRANCH"; then
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
    echo "║           Version 2.0.0                  ║"
    echo "╚═══════════════════════════════════════════╝"
    echo ""
    
    # Detect platform
    local platform
    platform=$(detect_platform)
    log_info "Platform: $platform"
    echo ""
    
    # Run pre-flight checks
    if ! run_preflight_checks; then
        log_error "Pre-flight checks failed"
        exit 1
    fi
    echo ""
    
    # Setup locale first (required for many tools)
    log_info "Step 1/5: Setting up locale..."
    setup_locale
    echo ""
    
    # Install base packages if needed
    log_info "Step 2/5: Installing essential packages..."
    if ! install_base_packages; then
        log_warning "Some packages may not have installed"
        log_info "Continuing with bootstrap (mise will handle remaining tools)..."
    fi
    echo ""
    
    # Setup XDG environment
    log_info "Step 3/5: Setting up XDG environment..."
    setup_xdg_env
    echo ""
    
    # Install chezmoi and apply dotfiles in one step
    log_info "Step 4/5: Installing chezmoi and applying dotfiles..."
    log_info "This will clone $REPO and apply all configurations"
    echo ""
    if ! install_and_apply_dotfiles; then
        log_error "Bootstrap failed: Could not install chezmoi and apply dotfiles"
        exit 1
    fi
    echo ""
    
    # Finalize
    log_info "Step 5/5: Finalizing setup..."
    
    # Summary
    echo ""
    echo "╔═══════════════════════════════════════════╗"
    echo "║          Bootstrap Complete! 🎉           ║"
    echo "╚═══════════════════════════════════════════╝"
    echo ""
    log_info "Next steps:"
    echo "  1. Log out and back in for the shell change to take effect"
    echo "  2. Or run: exec zsh (to start zsh immediately)"
    echo "  3. Run: chezmoi diff (to see applied changes)"
    echo "  4. Run: chezmoi edit --apply <file> (to modify configs)"
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

# vim: ts=2 sts=2 sw=2 et

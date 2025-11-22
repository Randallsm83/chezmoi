#!/usr/bin/env bash
#
# Dotfiles Health Check Script
# Validates dotfiles configuration and tool availability
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${CYAN}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

# ============================================================================
# Check Functions
# ============================================================================

check_chezmoi() {
    echo ""
    echo "════════════════════════════════════════"
    echo "  Chezmoi Configuration"
    echo "════════════════════════════════════════"
    
    if command -v chezmoi &>/dev/null; then
        local version=$(chezmoi --version | head -1)
        log_success "chezmoi installed: $version"
    else
        log_error "chezmoi not found in PATH"
        return 1
    fi
    
    # Check source directory
    local source_dir=$(chezmoi source-path 2>/dev/null || echo "")
    if [ -d "$source_dir" ]; then
        log_success "Source directory: $source_dir"
    else
        log_warning "Source directory not found: $source_dir"
    fi
    
    # Check for uncommitted changes
    local changes=$(cd "$source_dir" && git status --porcelain 2>/dev/null | wc -l)
    if [ "$changes" -gt 0 ]; then
        log_warning "$changes uncommitted changes in source directory"
    else
        log_success "No uncommitted changes"
    fi
    
    # Check for unmanaged files
    local unmanaged=$(chezmoi unmanaged 2>/dev/null | wc -l)
    log_info "$unmanaged unmanaged files in home directory"
}

check_tools() {
    echo ""
    echo "════════════════════════════════════════"
    echo "  Essential Tools"
    echo "════════════════════════════════════════"
    
    local tools=("git" "curl" "wget" "unzip" "make")
    for tool in "${tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            log_success "$tool installed"
        else
            log_warning "$tool not found"
        fi
    done
}

check_mise() {
    echo ""
    echo "════════════════════════════════════════"
    echo "  Mise Package Manager"
    echo "════════════════════════════════════════"
    
    if ! command -v mise &>/dev/null; then
        log_error "mise not found"
        return 1
    fi
    
    local version=$(mise --version 2>/dev/null | head -1)
    log_success "mise installed: $version"
    
    # Check mise doctor
    log_info "Running mise doctor..."
    mise doctor 2>&1 | grep -E "(✓|✗|⚠)" || true
    
    # Check installed tools
    echo ""
    log_info "Installed runtimes:"
    mise list | head -20
    
    # Check for outdated tools
    local outdated=$(mise outdated 2>/dev/null | wc -l)
    if [ "$outdated" -gt 0 ]; then
        log_warning "$outdated tools have updates available"
        log_info "Run: mise upgrade"
    else
        log_success "All tools up to date"
    fi
}

check_shell() {
    echo ""
    echo "════════════════════════════════════════"
    echo "  Shell Configuration"
    echo "════════════════════════════════════════"
    
    log_info "Current shell: $SHELL"
    log_info "Login shell: $(getent passwd "$USER" | cut -d: -f7)"
    
    if command -v zsh &>/dev/null; then
        local zsh_version=$(zsh --version)
        log_success "zsh available: $zsh_version"
    else
        log_warning "zsh not available"
    fi
    
    # Check shell startup files
    local files=("$HOME/.zshrc" "$HOME/.zshenv" "$HOME/.bashrc")
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
            log_success "$(basename "$file"): $size bytes"
        fi
    done
}

check_git() {
    echo ""
    echo "════════════════════════════════════════"
    echo "  Git Configuration"
    echo "════════════════════════════════════════"
    
    if ! command -v git &>/dev/null; then
        log_error "git not found"
        return 1
    fi
    
    local git_version=$(git --version)
    log_success "$git_version"
    
    # Check git config
    local user_name=$(git config --global user.name 2>/dev/null || echo "")
    local user_email=$(git config --global user.email 2>/dev/null || echo "")
    
    if [ -n "$user_name" ]; then
        log_success "Name: $user_name"
    else
        log_warning "user.name not configured"
    fi
    
    if [ -n "$user_email" ]; then
        log_success "Email: $user_email"
    else
        log_warning "user.email not configured"
    fi
    
    # Check SSH key
    if [ -d "$HOME/.ssh" ]; then
        local key_count=$(find "$HOME/.ssh" -name "id_*" -not -name "*.pub" | wc -l)
        log_info "$key_count SSH keys found"
    fi
}

check_disk_usage() {
    echo ""
    echo "════════════════════════════════════════"
    echo "  Disk Usage"
    echo "════════════════════════════════════════"
    
    # Check mise cache
    if [ -d "$HOME/.local/share/mise" ]; then
        local mise_size=$(du -sh "$HOME/.local/share/mise" 2>/dev/null | cut -f1)
        log_info "Mise cache: $mise_size"
    fi
    
    # Check chezmoi source
    local source_dir=$(chezmoi source-path 2>/dev/null || echo "")
    if [ -d "$source_dir" ]; then
        local source_size=$(du -sh "$source_dir" 2>/dev/null | cut -f1)
        log_info "Chezmoi source: $source_size"
    fi
    
    # Check backups
    local backup_dir="${XDG_STATE_HOME:-$HOME/.local/state}/chezmoi/backups"
    if [ -d "$backup_dir" ]; then
        local backup_size=$(du -sh "$backup_dir" 2>/dev/null | cut -f1)
        local backup_count=$(find "$backup_dir" -mindepth 1 -maxdepth 1 -type d | wc -l)
        log_info "Backups: $backup_size ($backup_count backups)"
    fi
}

# ============================================================================
# Main
# ============================================================================

echo ""
echo "╔════════════════════════════════════════╗"
echo "║   Dotfiles Health Check v2.0           ║"
echo "╚════════════════════════════════════════╝"

check_chezmoi
check_tools
check_mise
check_shell
check_git
check_disk_usage

echo ""
echo "════════════════════════════════════════"
echo "  Summary"
echo "════════════════════════════════════════"
echo ""
log_info "Health check complete!"
log_info "For updates, run: chezmoi update"
log_info "For mise updates, run: mise upgrade"
echo ""

# vim: ts=2 sts=2 sw=2 et

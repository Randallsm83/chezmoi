#!/usr/bin/env bash
#
# Rollback script for chezmoi dotfiles
# Restores files from a backup created before chezmoi apply
#
# Usage:
#   ./rollback.sh [TIMESTAMP]
#   ./rollback.sh 20250120_143022
#   ./rollback.sh latest

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
# Configuration
# ============================================================================

BACKUP_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/chezmoi/backups"
TIMESTAMP="${1:-}"

# ============================================================================
# Functions
# ============================================================================

list_backups() {
    log_info "Available backups:"
    echo ""
    
    if [ ! -d "${BACKUP_DIR}" ]; then
        log_error "No backups found in ${BACKUP_DIR}"
        exit 1
    fi
    
    find "${BACKUP_DIR}" -mindepth 1 -maxdepth 1 -type d -printf '%T+ %P\n' | \
        sort -r | \
        while read -r date backup; do
            if [ -f "${BACKUP_DIR}/${backup}/metadata.txt" ]; then
                echo "  ${backup}"
                sed 's/^/    /' "${BACKUP_DIR}/${backup}/metadata.txt"
                echo ""
            else
                echo "  ${backup} (no metadata)"
            fi
        done
}

get_latest_backup() {
    find "${BACKUP_DIR}" -mindepth 1 -maxdepth 1 -type d -printf '%T+ %P\n' | \
        sort -r | head -n 1 | cut -d' ' -f2-
}

restore_backup() {
    local backup_path="$1"
    
    if [ ! -d "${backup_path}" ]; then
        log_error "Backup not found: ${backup_path}"
        exit 1
    fi
    
    log_info "Restoring from: ${backup_path}"
    
    # Show metadata
    if [ -f "${backup_path}/metadata.txt" ]; then
        cat "${backup_path}/metadata.txt"
        echo ""
    fi
    
    # Confirm
    log_warning "This will overwrite current files with backup contents"
    read -p "Continue? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Rollback cancelled"
        exit 0
    fi
    
    # Restore files
    log_info "Restoring files..."
    local restore_count=0
    
    find "${backup_path}" -type f ! -name "metadata.txt" | while read -r backup_file; do
        # Get relative path
        local rel_path="${backup_file#${backup_path}/}"
        local target_file="$HOME/${rel_path}"
        
        # Create directory if needed
        mkdir -p "$(dirname "$target_file")"
        
        # Restore file
        cp "$backup_file" "$target_file"
        restore_count=$((restore_count + 1))
        
        log_success "Restored: ${rel_path}"
    done
    
    log_success "Rollback complete!"
    log_info "Files restored from backup"
    log_warning "You may want to run: chezmoi diff"
}

# ============================================================================
# Main
# ============================================================================

if [ -z "$TIMESTAMP" ]; then
    list_backups
    echo ""
    log_info "Usage: $0 <timestamp|latest>"
    log_info "Example: $0 20250120_143022"
    log_info "Example: $0 latest"
    exit 0
fi

if [ "$TIMESTAMP" = "latest" ]; then
    TIMESTAMP=$(get_latest_backup)
    if [ -z "$TIMESTAMP" ]; then
        log_error "No backups found"
        exit 1
    fi
    log_info "Using latest backup: $TIMESTAMP"
fi

BACKUP_PATH="${BACKUP_DIR}/${TIMESTAMP}"
restore_backup "$BACKUP_PATH"

# vim: ts=2 sts=2 sw=2 et

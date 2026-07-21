#!/usr/bin/env bash
#
# Dotfiles Test Suite
# Basic testing framework for validating dotfiles across platforms
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

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# ============================================================================
# Test Framework
# ============================================================================

test_case() {
    local name="$1"
    local cmd="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    echo ""
    log_info "Test: $name"
    
    if eval "$cmd"; then
        log_success "PASSED"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "FAILED"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_command_exists() {
    local cmd="$1"
    if command -v "$cmd" &>/dev/null; then
        return 0
    else
        log_error "Command not found: $cmd"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    if [ -f "$file" ]; then
        return 0
    else
        log_error "File not found: $file"
        return 1
    fi
}

assert_file_not_contains_literal() {
    local file="$1"
    local pattern="$2"

    if [ ! -f "$file" ]; then
        log_error "File not found: $file"
        return 1
    fi

    if grep -Fq -- "$pattern" "$file"; then
        log_error "File contains forbidden text: $file"
        return 1
    fi
    return 0
}

assert_file_contains_literal() {
    local file="$1"
    local pattern="$2"

    if [ ! -f "$file" ]; then
        log_error "File not found: $file"
        return 1
    fi

    if ! grep -Fq -- "$pattern" "$file"; then
        log_error "File missing required text: $file"
        return 1
    fi
    return 0
}

assert_directory_exists() {
    local dir="$1"
    if [ -d "$dir" ]; then
        return 0
    else
        log_error "Directory not found: $dir"
        return 1
    fi
}

assert_template_valid() {
    local template="$1"
    if chezmoi execute-template < "$template" >/dev/null 2>&1; then
        return 0
    else
        log_error "Template invalid: $template"
        return 1
    fi
}

# ============================================================================
# Test Suites
# ============================================================================

test_chezmoi_installation() {
    echo ""
    echo "════════════════════════════════════════"
    echo "  Chezmoi Installation Tests"
    echo "════════════════════════════════════════"
    
    test_case "chezmoi command exists" "assert_command_exists chezmoi"
    test_case "chezmoi source directory exists" "assert_directory_exists \$(chezmoi source-path)"
    test_case ".chezmoi.toml.tmpl exists" "assert_file_exists \$(chezmoi source-path)/.chezmoi.toml.tmpl"
    # wave-d split .chezmoidata.yaml into .chezmoidata/{theme,packages,ssh,dns,fonts,mcp}.yaml.
    test_case ".chezmoidata/ directory exists with split data files" \
        "assert_directory_exists \$(chezmoi source-path)/.chezmoidata && [ \$(ls \$(chezmoi source-path)/.chezmoidata/*.yaml 2>/dev/null | wc -l) -gt 0 ]"
}

test_templates() {
    echo ""
    echo "════════════════════════════════════════"
    echo "  Template Validation Tests"
    echo "════════════════════════════════════════"
    
    local source_dir=$(chezmoi source-path)
    
    test_case ".chezmoi.toml.tmpl syntax" "assert_template_valid $source_dir/.chezmoi.toml.tmpl"
    test_case "common-header template syntax" "assert_template_valid $source_dir/.chezmoitemplates/common-header"
    test_case "platform-detect template syntax" "assert_template_valid $source_dir/.chezmoitemplates/platform-detect"
    test_case "mise-tool-entry template exists" "assert_file_exists $source_dir/.chezmoitemplates/mise-tool-entry"
    test_case "Unix package installer fails on mise install errors" \
        "assert_file_not_contains_literal $source_dir/.chezmoiscripts/run_onchange_install-packages-unix.sh.tmpl 'mise install --yes 2>&1 ||'"
    test_case "Unix package installer does not hide mise missing checks" \
        "assert_file_not_contains_literal $source_dir/.chezmoiscripts/run_onchange_install-packages-unix.sh.tmpl 'mise ls --missing || true' && assert_file_contains_literal $source_dir/.chezmoiscripts/run_onchange_install-packages-unix.sh.tmpl 'missing_mise_tools=\"\$(mise ls --missing)\"'"
    test_case "Debian base bootstrap checks Python build headers" \
        "assert_file_contains_literal $source_dir/.chezmoiscripts/run_onchange_before_install_base_packages_unix.sh.tmpl 'debian_python_build_packages=\"build-essential libssl-dev libreadline-dev zlib1g-dev libyaml-dev libffi-dev libbz2-dev liblzma-dev libsqlite3-dev libncurses-dev libgdbm-dev tk-dev\"'"
}

test_essential_tools() {
    echo ""
    echo "════════════════════════════════════════"
    echo "  Essential Tools Tests"
    echo "════════════════════════════════════════"
    
    test_case "git installed" "assert_command_exists git"
    test_case "curl installed" "assert_command_exists curl"
    
    test_case "mpmise available" "assert_command_exists mpmise"
    if [ "$(uname -s)" != "Darwin" ] && [ ! -f /proc/version ] || ! grep -qi microsoft /proc/version 2>/dev/null; then
        # Unix but not WSL or macOS - expect mise
        test_case "mise installed" "assert_command_exists mise"
    fi
}

test_configurations() {
    echo ""
    echo "════════════════════════════════════════"
    echo "  Configuration Tests"
    echo "════════════════════════════════════════"
    
    test_case "Git user.name configured" "[ -n \"\$(git config user.name)\" ]"
    test_case "Git user.email configured" "[ -n \"\$(git config user.email)\" ]"
    
    # Check XDG directories
    test_case "XDG_CONFIG_HOME directory exists" "assert_directory_exists \${XDG_CONFIG_HOME:-\$HOME/.config}"
    test_case "XDG_DATA_HOME directory exists" "assert_directory_exists \${XDG_DATA_HOME:-\$HOME/.local/share}"
}

test_chezmoi_state() {
    echo ""
    echo "════════════════════════════════════════"
    echo "  Chezmoi State Tests"
    echo "════════════════════════════════════════"
    
    test_case "chezmoi managed files exist" "[ \$(chezmoi managed | wc -l) -gt 0 ]"
    # `chezmoi diff` has no `--no-pager` flag; pager is already disabled in
    # .chezmoi.toml.tmpl ([diff] pager=""). Discard output via stdout redirect.
    test_case "no chezmoi diff errors" "chezmoi diff >/dev/null 2>&1"
    test_case "chezmoi data accessible" "chezmoi data >/dev/null"
}

test_platform_specific() {
    echo ""
    echo "════════════════════════════════════════"
    echo "  Platform-Specific Tests"
    echo "════════════════════════════════════════"
    
    case "$(uname -s)" in
        Linux*)
            test_case "zsh installed" "assert_command_exists zsh"
            test_case "XDG zshrc exists" "assert_file_exists \${XDG_CONFIG_HOME:-\$HOME/.config}/zsh/.zshrc"
            ;;
        Darwin*)
            test_case "zsh installed" "assert_command_exists zsh"
            test_case "XDG zshrc exists" "assert_file_exists \${XDG_CONFIG_HOME:-\$HOME/.config}/zsh/.zshrc"
            ;;
        *)
            log_warning "Platform-specific tests skipped"
            ;;
    esac
}

test_mise_integration() {
    echo ""
    echo "════════════════════════════════════════"
    echo "  Mise Integration Tests"
    echo "════════════════════════════════════════"
    
    if ! command -v mise &>/dev/null; then
        log_warning "mise not installed, skipping tests"
        return
    fi
    
    test_case "mise config exists" "assert_file_exists \$HOME/.config/mise/config.toml"
    test_case "mise list runs" "mise list >/dev/null"
}

# ============================================================================
# Main
# ============================================================================

main() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║   Dotfiles Test Suite v2.0             ║"
    echo "╚════════════════════════════════════════╝"
    
    # Run test suites
    test_chezmoi_installation
    test_templates
    test_essential_tools
    test_configurations
    test_chezmoi_state
    test_platform_specific
    test_mise_integration
    
    # Summary
    echo ""
    echo "════════════════════════════════════════"
    echo "  Test Results"
    echo "════════════════════════════════════════"
    echo ""
    echo "  Total tests: $TESTS_RUN"
    echo "  Passed: $TESTS_PASSED"
    echo "  Failed: $TESTS_FAILED"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "All tests passed! ✨"
        exit 0
    else
        log_error "Some tests failed"
        exit 1
    fi
}

main "$@"

# vim: ts=2 sts=2 sw=2 et

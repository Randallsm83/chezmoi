#!/usr/bin/env bash
#
# Bootstrap script for Unix systems (Linux/WSL/macOS)
#
# Usage - Fresh machine (no SSH keys yet):
#   curl -fsSL https://raw.githubusercontent.com/Randallsm83/chezmoi/main/setup.sh | bash
#
# Usage - Force SSH (if SSH keys already configured):
#   USE_SSH=1 curl -fsSL https://raw.githubusercontent.com/Randallsm83/chezmoi/main/setup.sh | bash
#
# Recovery (after failed/partial chezmoi apply):
#   brew autoremove                    # clean orphaned brew deps
#   chezmoi init                       # regenerate config if template changed
#   chezmoi apply                      # re-apply
#
# Env overrides:
#   CI=true          - skip all interactive prompts (auto-yes)
#   USE_SSH=1        - force SSH clone URL (requires GitHub SSH access)
#   REPO=user/repo   - override dotfiles repo (default: Randallsm83/chezmoi)
#   BRANCH=name      - override branch (default: main)
#   RASPI=1          - force Raspberry Pi (medium tier) profile; auto-detected
#                      from /proc/device-tree/model or aarch64+Debian otherwise
#   RASPI=0          - force-disable Pi profile even on Pi hardware

set -euo pipefail

# ============================================================================
# Structured exit codes
# ============================================================================
# Mirrors the $ExitCode hashtable in bootstrap.ps1. Used in place of bare
# `exit 1` so CI / wrappers can branch on the failure mode. See
# INSTALL-GUIDE.md § 'Exit codes' for the full table.
readonly E_SUCCESS=0
readonly E_PREFLIGHT=10
readonly E_SCOOP_INSTALL=20
readonly E_WINGET_IMPORT=21
readonly E_SCOOP_IMPORT=22
readonly E_CHEZMOI_INIT=30
readonly E_CHEZMOI_APPLY=40
readonly E_NO_SSH_KEY=50
readonly E_UNKNOWN=99

# ============================================================================
# Configuration
# ============================================================================

REPO="${REPO:-Randallsm83/chezmoi}"
BRANCH="${BRANCH:-main}"
CHEZMOI_VERSION="${CHEZMOI_VERSION:-latest}"

# Track wall-clock duration for the bootstrap-status.json artifact.
BOOTSTRAP_START_EPOCH="$(date +%s)"

# Auto-detect Raspberry Pi if RASPI not explicitly set
if [ -z "${RASPI:-}" ]; then
    if [ -f /proc/device-tree/model ] && grep -qi "raspberry pi" /proc/device-tree/model 2>/dev/null; then
        RASPI=1
    elif [ "$(uname -m 2>/dev/null)" = "aarch64" ] && [ -f /etc/os-release ] && grep -qi "^ID=debian\|^ID_LIKE=.*debian" /etc/os-release 2>/dev/null && [ ! -f /.dockerenv ]; then
        # aarch64 + Debian (and not in a container) is a strong Pi signal
        RASPI=1
    else
        RASPI=0
    fi
fi
export RASPI

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

# ---------------------------------------------------------------------------
# retry_with_backoff <operation_label> <max_attempts> <base_seconds> -- <cmd...>
#
# Run a command with bounded exponential backoff. Treat any non-zero exit
# status as a retryable failure. Sleep BASE_SECONDS * 2^(N-1) (capped at 60s)
# between attempts. Logs each retry through log_warning so the user can see
# what's happening on slow links.
#
# Used to wrap flaky network calls (curl-pipe-to-sh, downloader bootstraps).
# Returns the underlying command's exit code on success; on final failure
# returns the last non-zero exit code.
# ---------------------------------------------------------------------------
retry_with_backoff() {
    local label="$1"
    local max_attempts="$2"
    local base="$3"
    shift 3
    # Skip the explicit "--" separator if the caller used the readable form.
    if [ "${1:-}" = "--" ]; then
        shift
    fi

    if [ "$#" -eq 0 ]; then
        log_error "retry_with_backoff: no command supplied for '$label'"
        return 64  # EX_USAGE
    fi

    local attempt=1
    local exit_code=0
    local delay=0
    while [ "$attempt" -le "$max_attempts" ]; do
        if "$@"; then
            if [ "$attempt" -gt 1 ]; then
                log_success "'$label' succeeded on attempt $attempt/$max_attempts"
            fi
            return 0
        fi
        exit_code=$?
        if [ "$attempt" -eq "$max_attempts" ]; then
            log_error "'$label' failed after $max_attempts attempts (exit $exit_code)"
            return "$exit_code"
        fi
        # Exponential backoff, capped at 60s.
        delay=$(( base * (1 << (attempt - 1)) ))
        if [ "$delay" -gt 60 ]; then delay=60; fi
        log_warning "'$label' failed on attempt $attempt/$max_attempts (exit $exit_code) — retrying in ${delay}s"
        sleep "$delay"
        attempt=$(( attempt + 1 ))
    done
    return "$exit_code"
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
    
    # Check 1: Internet connectivity (wrapped with backoff to ride out transient DNS/TLS flakes)
    printf "  [1/4] Internet connectivity..."
    if retry_with_backoff 'github.com reachability probe' 3 2 -- \
        curl -fsSL --connect-timeout 5 https://github.com >/dev/null 2>&1; then
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
        # Pi/aarch64-Debian: only zsh plugins from apt (everything else comes from mise)
        if [ "${RASPI:-0}" = "1" ]; then
            log_info "Raspberry Pi detected - including zsh plugin packages"
            packages="$packages zsh-autosuggestions zsh-syntax-highlighting"
        fi
        if has_sudo || [ "$EUID" -eq 0 ]; then
            execute_with_privilege apt-get update
            execute_with_privilege apt-get install -y $packages || true
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
# Raspberry Pi: seed .chezmoi.local.toml with medium-tier overrides
# ============================================================================

seed_raspi_local_toml() {
    if [ "${RASPI:-0}" != "1" ]; then
        return 0
    fi

    local chezmoi_config_dir="$XDG_CONFIG_HOME/chezmoi"
    local local_toml="$chezmoi_config_dir/.chezmoi.local.toml"

    mkdir -p "$chezmoi_config_dir"

    if [ -f "$local_toml" ]; then
        log_info "$local_toml already exists - leaving it untouched"
        return 0
    fi

    log_info "Seeding $local_toml with Raspberry Pi (medium tier) overrides"
    cat > "$local_toml" <<'EOF'
# Auto-generated by setup.sh on a Raspberry Pi (RASPI=1).
# Edit freely - this file is git-ignored and survives chezmoi apply.
[data]
    is_raspi = true
    remote_tier = "medium"
    remote_minimal = false
    install_packages = true
    setup_1password = false
    has_sudo = true
    theme = "spaceduck"

    [data.package_features]
        # essentials on
        git = true
        ssh = true
        mise = true
        direnv = false
        # editors
        nvim = true
        vim = false
        vscode = false
        # shells/tools
        zsh = true
        starship = true
        fzf = true
        rust_alternatives = true
        thefuck = false
        fastfetch = true
        # languages: medium = node + python only
        node = true
        python = true
        rust = false
        golang = false
        ruby = false
        lua = false
        perl = false
        julia = false
        php = false
        # off entirely on Pi
        warp = false
        wezterm = false
        windows_terminal = false
        ai_tools = false
        gaming = false
        docker = false
        hardware_tools = false
        windows_utilities = false
        sysinternals = false
        network_tools = false
        dev_extras = false
        nerd_fonts = false
        "1password" = false
        homebrew = false
EOF
    log_success "Raspberry Pi local overrides written"
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

    # The get.chezmoi.io installer defaults to dropping the binary at ./bin/chezmoi,
    # i.e. relative to the current working directory. On macOS the root volume is
    # read-only under APFS and many common CWDs (/, /usr, etc.) are locked down by
    # SIP, which produces "Read-only file system" errors. Pin the bindir to an
    # always-writable XDG-compliant location the user owns.
    local bindir="$HOME/.local/bin"
    mkdir -p "$bindir"
    case ":$PATH:" in
        *:"$bindir":*) ;;
        *) export PATH="$bindir:$PATH" ;;
    esac

    # Try SSH first (fast, uses 1Password agent), fall back to HTTPS.
    # SSH will fail on fresh machines without keys — HTTPS always works.
    # The installer download itself is wrapped in retry_with_backoff so a
    # transient TLS/DNS hiccup doesn't fail the whole bootstrap.
    local chezmoi_installer
    local _installer_tmp
    _installer_tmp="$(mktemp -t chezmoi-installer.XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -f '$_installer_tmp'" EXIT INT TERM
    if ! retry_with_backoff 'fetch chezmoi installer (get.chezmoi.io)' 4 2 -- \
            sh -c "curl -fsLS 'get.chezmoi.io' > '$_installer_tmp'"; then
        log_error 'Could not download chezmoi installer after retries'
        return 1
    fi
    chezmoi_installer="$(cat "$_installer_tmp")"

    # Installer flags (-b BINDIR) go BEFORE the `--` separator; everything
    # after `--` is forwarded as chezmoi's own args.
    # NOTE: --source is intentionally omitted so chezmoi uses its default
    # source dir (~/.local/share/chezmoi). Overriding to a different path
    # historically broke .chezmoi.toml.tmpl path assumptions.
    if [ "${USE_SSH:-0}" = "1" ]; then
        log_info "Cloning via SSH (USE_SSH=1)..."
        if CI=true sh -c "$chezmoi_installer" -s -b "$bindir" -- init --apply --ssh "$REPO" --branch "$BRANCH"; then
            log_success "Dotfiles applied successfully (SSH)"
            return 0
        fi
        log_warning "SSH clone failed — falling back to HTTPS"
    fi

    log_info "Cloning via HTTPS..."
    if CI=true sh -c "$chezmoi_installer" -s -b "$bindir" -- init --apply "https://github.com/${REPO}.git" --branch "$BRANCH"; then
        log_success "Dotfiles applied successfully (HTTPS)"
        log_info "To switch remote to SSH later: chezmoi git remote set-url origin git@github.com:${REPO}.git"
        return 0
    fi

    log_error "Failed to install chezmoi and apply dotfiles"
    return 1
}

# ============================================================================
# Bootstrap status artifact
# ============================================================================

bootstrap_status_path() {
    local state_root="${XDG_STATE_HOME:-$HOME/.local/state}"
    printf '%s' "$state_root/dotfiles/bootstrap-status.json"
}

# Emit a JSON status artifact at $XDG_STATE_HOME/dotfiles/bootstrap-status.json
# so scripts/healthcheck.sh can surface it under the 'Last Bootstrap' section.
write_bootstrap_status() {
    local status_path platform host chezmoi_version source_dir has_uncommitted
    local duration_seconds
    status_path="$(bootstrap_status_path)"
    mkdir -p "$(dirname "$status_path")" 2>/dev/null || {
        log_warning "Could not create bootstrap status dir: $(dirname "$status_path")"
        return 0
    }

    case "$(uname -s)" in
        Darwin*) platform=darwin ;;
        Linux*)  platform=linux ;;
        *)       platform="$(uname -s | tr '[:upper:]' '[:lower:]')" ;;
    esac
    host="$(hostname 2>/dev/null || echo unknown)"

    chezmoi_version=""
    source_dir=""
    has_uncommitted=false
    if command_exists chezmoi; then
        chezmoi_version="$(chezmoi --version 2>/dev/null | head -n1)"
        source_dir="$(chezmoi source-path 2>/dev/null || true)"
        if [ -n "$source_dir" ] && [ -d "$source_dir" ]; then
            local changes
            changes="$(cd "$source_dir" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
            if [ "${changes:-0}" -gt 0 ]; then
                has_uncommitted=true
            fi
        fi
    fi

    local end_epoch
    end_epoch="$(date +%s)"
    duration_seconds=$(( end_epoch - BOOTSTRAP_START_EPOCH ))

    local timestamp
    timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    # JSON-quote helper: escape backslashes and double-quotes, replace newlines with \n.
    json_string() {
        local s=$1
        s=${s//\\/\\\\}
        s=${s//\"/\\\"}
        s=${s//$'\n'/\\n}
        printf '"%s"' "$s"
    }

    {
        printf '{\n'
        printf '  "timestamp": %s,\n'  "$(json_string "$timestamp")"
        printf '  "version": "2.0.0",\n'
        printf '  "host": %s,\n'       "$(json_string "$host")"
        printf '  "platform": %s,\n'   "$(json_string "$platform")"
        printf '  "chezmoi": {\n'
        printf '    "version": %s,\n'              "$(json_string "$chezmoi_version")"
        printf '    "sourceDir": %s,\n'            "$(json_string "$source_dir")"
        printf '    "hasUncommittedChanges": %s\n' "$has_uncommitted"
        printf '  },\n'
        printf '  "stats": {\n'
        printf '    "RASPI": %s\n'                 "${RASPI:-0}"
        printf '  },\n'
        printf '  "durationSeconds": %s\n'         "$duration_seconds"
        printf '}\n'
    } > "$status_path"

    log_info "Wrote bootstrap status: $status_path"
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
    if [ "${RASPI:-0}" = "1" ]; then
        log_info "Profile:  raspi (medium tier)"
    fi
    echo ""
    
    # Run pre-flight checks
    if ! run_preflight_checks; then
        log_error "Pre-flight checks failed"
        exit "$E_PREFLIGHT"
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

    # Pi-only: drop in medium-tier .chezmoi.local.toml before first apply
    if [ "${RASPI:-0}" = "1" ]; then
        log_info "Raspberry Pi detected (RASPI=1) - seeding chezmoi local overrides"
        seed_raspi_local_toml
        echo ""
    fi

    # Install chezmoi and apply dotfiles in one step
    log_info "Step 4/5: Installing chezmoi and applying dotfiles..."
    log_info "This will clone $REPO and apply all configurations"
    echo ""
    if ! install_and_apply_dotfiles; then
        log_error "Bootstrap failed: Could not install chezmoi and apply dotfiles"
        exit "$E_CHEZMOI_APPLY"
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

    # Emit the JSON status artifact so healthcheck.sh can surface this run.
    write_bootstrap_status

    echo ""
}

# Run main function
main "$@"

# vim: ts=2 sts=2 sw=2 et

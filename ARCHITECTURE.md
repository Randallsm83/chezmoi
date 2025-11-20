# Architecture Documentation

This document describes the architecture and design decisions for these dotfiles v2.0.

## Table of Contents

- [Overview](#overview)
- [Directory Structure](#directory-structure)
- [Template System](#template-system)
- [Configuration Management](#configuration-management)
- [Platform Strategy](#platform-strategy)
- [Package Management](#package-management)
- [Scripts and Automation](#scripts-and-automation)
- [Security Model](#security-model)

---

## Overview

### Design Principles

1. **Cross-Platform First**: Support Windows, Linux, macOS, and remote environments
2. **User-Space Installation**: Avoid sudo requirements where possible
3. **Declarative Configuration**: Configs describe desired state, not procedures
4. **Template Reusability**: Shared templates reduce duplication
5. **Progressive Enhancement**: Core functionality works everywhere, extras are conditional
6. **Safe by Default**: Backups, dry-run support, validation checks

### Technology Stack

- **Chezmoi**: Dotfile manager (templating, state management)
- **Mise**: Runtime/tool manager (replaces asdf, nvm, etc.)
- **Git**: Version control and distribution
- **1Password**: Secrets management (optional)
- **Age**: File encryption (optional)

---

## Directory Structure

```
~/.local/share/chezmoi/           # Chezmoi source directory
├── .chezmoi.toml.tmpl            # Main config (machine detection)
├── .chezmoidata.yaml             # Static data (packages, themes)
├── .chezmoi.local.toml.example   # Local overrides example
├── .chezmoiignore                # Platform/feature exclusions
│
├── .chezmoitemplates/            # Reusable templates
│   ├── common-header.tmpl        # Shell setup, error handling
│   ├── platform-detect.tmpl      # OS/distro/machine detection
│   ├── package-manager.tmpl      # Cross-platform package abstraction
│   └── 1password.tmpl            # 1Password integration
│
├── .chezmoiscripts/              # Lifecycle scripts
│   ├── run_before_00_backup.*    # Pre-apply backup
│   ├── run_onchange_before_01_validate-secrets.sh.tmpl
│   └── run_once_install_packages_*.tmpl
│
├── dot_config/                   # ~/.config/
│   ├── git/                      # Git configuration
│   ├── mise/                     # Mise runtime manager
│   ├── nvim/                     # Neovim configuration
│   ├── starship/                 # Starship prompt
│   ├── wezterm/                  # WezTerm terminal
│   └── zsh/                      # Zsh shell (Unix only)
│
├── Documents/PowerShell/         # PowerShell profile (Windows)
├── scripts/                      # Utility scripts
│   ├── healthcheck.sh            # System health checks
│   ├── rollback.sh/ps1           # Backup rollback
│   └── *.sh/ps1                  # Other utilities
│
├── bootstrap.ps1                 # Windows bootstrap
├── setup.sh                      # Unix bootstrap
│
└── *.md                          # Documentation
    ├── README.md                 # Quick start
    ├── INSTALL-GUIDE.md          # Detailed installation
    ├── SECRETS.md                # Secrets management
    ├── REMOTE.md                 # Remote machines
    ├── ARCHITECTURE.md           # This file
    └── CONTRIBUTING.md           # Development guide
```

---

## Template System

### Template Hierarchy

1. **Common Header** (`common-header.tmpl`)
   - Shell environment setup
   - Error handling (`set -euo pipefail`)
   - Logging functions (log_info, log_success, log_warning, log_error)
   - Dry-run support
   - XDG directory setup

2. **Platform Detect** (`platform-detect.tmpl`)
   - OS detection (Windows/Linux/macOS)
   - Distro detection (Ubuntu/Arch/Fedora)
   - Environment detection (WSL/Container/Remote)
   - Machine type classification

3. **Package Manager** (`package-manager.tmpl`)
   - Unified package operations interface
   - Per-platform implementations
   - Error handling and retries
   - Version checking

### Template Variables

Variables available in all templates (from `.chezmoi.toml.tmpl` and `.chezmoidata.yaml`):

```go
// User information
.name               // User's full name
.email              // Email address
.github_username    // GitHub username

// Platform detection
.chezmoi.os         // "windows", "linux", "darwin"
.is_windows         // Boolean
.is_linux           // Boolean
.is_darwin          // Boolean
.is_wsl             // Boolean (Windows Subsystem for Linux)
.is_container       // Boolean (Docker/LXC)

// Machine classification
.is_remote          // Boolean (SSH/VSCode Remote)
.is_personal        // Boolean (personal machine)
.is_work            // Boolean (work machine)
.has_sudo           // Boolean (estimated, verify at runtime)
.hostname           // Machine hostname

// Feature flags
.install_packages   // Install system packages
.install_runtimes   // Install language runtimes
.setup_git_ssh      // Configure Git SSH
.setup_1password    // Setup 1Password integration
.remote_minimal     // Use minimal package set

// Package features (per-language configs)
.package_features.rust
.package_features.golang
.package_features.python
// ... etc
```

### Template Patterns

**Conditional file inclusion**:
```go
{{- if eq .chezmoi.os "windows" -}}
// Windows-specific content
{{- end -}}
```

**Remote machine exclusions** (in `.chezmoiignore`):
```go
{{- if .is_remote }}
.config/wezterm/**
.config/warp/**
{{- end }}
```

**Package feature flags**:
```go
{{- if index .package_features "rust" }}
[rust config here]
{{- end }}
```

---

## Configuration Management

### Configuration Files

1. **`.chezmoi.toml.tmpl`** (Generated per-machine)
   - Machine detection logic
   - Platform-specific defaults
   - Feature flag defaults
   - Exposed as `.data` in templates

2. **`.chezmoidata.yaml`** (Static, version-controlled)
   - Package lists
   - Theme colors
   - Font configuration
   - Feature flag definitions

3. **`.chezmoi.local.toml`** (Per-machine overrides, gitignored)
   - Override any `.data` variable
   - Machine-specific settings
   - Example: `.chezmoi.local.toml.example`

### Configuration Priority

1. `.chezmoi.local.toml` (highest - machine-specific)
2. `.chezmoi.toml.tmpl` (generated defaults)
3. `.chezmoidata.yaml` (static defaults)

### Machine Type Detection

**Local Detection** (`.chezmoi.toml.tmpl`):
```go
is_remote = {{ env "SSH_CONNECTION" != "" || env "TERM_PROGRAM" == "vscode" }}
is_personal = {{ hostname contains "personal" || hostname contains "home" }}
is_work = {{ hostname contains "work" || hostname contains "corp" }}
has_sudo = {{ not is_remote && not is_container }}
```

**Override Example** (`.chezmoi.local.toml`):
```toml
[data]
    is_remote = true
    has_sudo = false
    remote_minimal = true
    install_packages = false
```

---

## Platform Strategy

### Windows Strategy

**Package Managers**:
- `scoop`: CLI tools (no admin required)
- `winget`: GUI apps (requires admin)
- `mise`: Language runtimes

**Key Configurations**:
- PowerShell 7+ profile
- Windows Terminal settings
- WezTerm configuration
- Git with Windows-specific paths
- Developer Mode for symlinks

**Installation Flow**:
1. Check Developer Mode
2. Install scoop packages (git, mise, etc.)
3. Install winget packages (GUI apps)
4. Install mise runtimes
5. Configure PowerShell profile

### Linux/WSL Strategy

**Package Manager**:
- `mise`: Everything (CLI tools + runtimes)
- System PM: Bootstrap only (git, build-essential)

**Key Configurations**:
- Zsh shell + completions
- XDG Base Directory compliance
- System-specific configs (systemd, etc.)

**Installation Flow**:
1. Detect distro (Ubuntu/Arch/Fedora)
2. Install base packages (if sudo)
3. Install mise
4. Install mise tools
5. Configure zsh

### macOS Strategy

**Package Managers**:
- `mise`: Everything
- `homebrew`: GUI apps only (iTerm2, etc.)

**Key Configurations**:
- Zsh shell (default on modern macOS)
- macOS-specific apps (karabiner, hammerspoon)

### Remote Machine Strategy

**Detection**: SSH session, VS Code Remote, or container

**Minimal Mode** (`remote_minimal = true`):
- Skip GUI applications
- Minimal tool set (node, python, go, neovim, fzf, ripgrep)
- No system packages (mise only)
- Reduced disk usage

**Full Mode** (`remote_minimal = false`):
- All language runtimes
- Full CLI tool suite
- System packages (if sudo)

---

## Package Management

### Mise Architecture

**Why Mise?**
- Cross-platform (Windows/Linux/macOS)
- User-space installation (no sudo)
- Unified tool management
- Per-project versions (`.tool-versions`)
- Fast (parallel installs, caching)

**Mise Configuration Files**:
```
~/.config/mise/
├── config.toml                 # Main config (all platforms)
├── config.windows.toml         # Windows overrides
├── config.linux.toml           # Linux additions
├── config.darwin.toml          # macOS additions
└── config.remote.toml          # Remote minimal set
```

**Tool Categories**:
1. **Language Runtimes**: node, python, ruby, go, rust, lua, bun, deno
2. **Universal Tools**: direnv, uv, yarn
3. **CLI Tools** (Unix only): fzf, bat, eza, fd, ripgrep, neovim
4. **Build Tools**: cargo-binstall, zig

**Installation Locations**:
```
~/.local/bin/mise                       # Mise binary
~/.local/share/mise/
├── installs/                          # Installed tools
│   ├── node@23.7.0/
│   ├── python@3.12.0/
│   └── cargo:ripgrep@14.1.0/
├── downloads/                         # Downloaded archives
└── shims/                             # Tool shims (in PATH)
```

### Package Abstraction

**Template Functions** (`package-manager.tmpl`):
```bash
package_install <package>       # Install package
package_remove <package>        # Remove package
package_update [package]        # Update package(s)
package_exists <package>        # Check if installed
get_package_version <package>   # Get version
```

**Per-Platform Implementations**:
- Windows (scoop): `scoop install <pkg>`
- Debian/Ubuntu (apt): `apt-get install <pkg>`
- Arch (pacman): `pacman -S <pkg>`
- macOS (brew): `brew install <pkg>`
- Mise (all): `mise use <tool>@<version>`

---

## Scripts and Automation

### Script Lifecycle

**Chezmoi Script Naming**:
- `run_before_*`: Before applying changes
- `run_after_*`: After applying changes
- `run_once_*`: Only on first run or config change
- `run_onchange_*`: On source file change

**Script Execution Order**:
1. `run_before_00_backup.*` - Create backup
2. `run_onchange_before_01_validate-secrets.*` - Check secrets
3. `run_once_install_packages_*` - Install tools
4. [chezmoi applies file changes]
5. `run_after_*` - Post-install tasks

### Bootstrap Scripts

**`setup.sh`** (Unix):
- Platform detection
- Pre-flight checks (internet, sudo, tools)
- System package installation
- XDG directory setup
- Chezmoi one-line install

**`bootstrap.ps1`** (Windows):
- Administrator check
- Developer Mode detection/enablement
- Scoop installation
- Winget verification
- 1Password CLI check
- Chezmoi installation

### Utility Scripts

**`scripts/healthcheck.sh`**:
- Validate chezmoi state
- Check tool versions
- Detect outdated packages
- Disk usage analysis

**`scripts/rollback.sh`**:
- List available backups
- Restore files from backup
- Interactive confirmation

**`scripts/cleanup.sh`** (future):
- Remove old mise versions
- Clean download caches
- Prune old backups

---

## Security Model

### Secrets Management

**1Password Integration** (`.chezmoitemplates/1password.tmpl`):
```bash
op_get_secret <vault> <item> <field>
op_check_cli                          # Verify op CLI
```

**Age Encryption**:
- Symmetric encryption for sensitive files
- Key stored in 1Password
- Encrypted files: `.age` extension

**Git Filtering**:
```gitattributes
# Prevent secrets from being committed
**/*secret* filter=secret
**/*password* filter=secret
```

### Permission Model

**Sudo Requirements**:
- **Local machines**: Expected for system packages
- **Remote machines**: Not required, mise handles everything
- **Containers**: Usually no sudo, user-space only

**File Permissions**:
- SSH keys: `0600`
- Config files: `0644`
- Scripts: `0755`
- Secrets: `0600`

### Backup Strategy

**Automatic Backups**:
- Before every `chezmoi apply`
- Stored in `~/.local/state/chezmoi/backups/`
- Keep last 10 backups
- Includes metadata (timestamp, user, file count)

**Manual Backups**:
```bash
# Create backup
chezmoi archive > ~/dotfiles-backup-$(date +%Y%m%d).tar.gz

# List backups
ls ~/.local/state/chezmoi/backups/

# Rollback
~/.local/share/chezmoi/scripts/rollback.sh latest
```

---

## Design Decisions

### Why Chezmoi?

**Alternatives Considered**: GNU Stow, yadm, rcm, bare git repo

**Chosen**: Chezmoi for:
- Templating support (machine-specific configs)
- Secret management integration
- Cross-platform (Windows support)
- Script lifecycle hooks
- Dry-run capabilities
- Active development

### Why Mise over Alternatives?

**Alternatives**: asdf, nvm, pyenv, rbenv, gvm (per-language managers)

**Chosen**: Mise for:
- Unified interface for all languages
- Windows support
- User-space installation
- Fast parallel installs
- Cargo backend for CLI tools
- Actively maintained

### XDG Base Directory Compliance

**Standard Locations**:
```
~/.config/      # XDG_CONFIG_HOME  (configs)
~/.local/share/ # XDG_DATA_HOME    (data files)
~/.local/state/ # XDG_STATE_HOME   (state/logs)
~/.cache/       # XDG_CACHE_HOME   (cache files)
```

**Benefits**:
- Organized home directory
- Easy backup (just `~/.config`)
- Predictable locations
- Cross-platform consistency

---

## Future Enhancements

### Planned Features

1. **Testing Infrastructure**
   - Automated platform testing (Docker)
   - CI/CD validation
   - Integration tests

2. **Advanced Secrets**
   - SOPS support
   - Bitwarden integration
   - Vault backend

3. **Enhanced Monitoring**
   - Update notifications
   - Health check dashboard
   - Dependency tracking

4. **Community Features**
   - Plugin system
   - Shared templates
   - Configuration marketplace

---

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for development guidelines.

## References

- [Chezmoi Documentation](https://www.chezmoi.io/)
- [Mise Documentation](https://mise.jdx.dev/)
- [XDG Base Directory Spec](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)
- [1Password CLI](https://developer.1password.com/docs/cli/)

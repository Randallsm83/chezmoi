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
├── .chezmoidata/                 # Static data (packages, themes, dns, fonts, ssh, mcp)
│   ├── theme.yaml                # Theme colors + per-app theme mappings
│   ├── fonts.yaml                # Font families + Fira Code ligature settings
│   ├── ssh.yaml                  # SSH/1Password agent settings
│   ├── packages.yaml             # Feature flags, package mapping, brew/scoop sources
│   ├── dns.yaml                  # VPN/NRPT/DoT/DoH routing, Caddy CA trust
│   └── mcp.yaml                  # MCP server definitions
├── chezmoi.local.toml.example    # Local overrides example (no leading dot)
├── .chezmoiignore                # Platform/feature exclusions
│
├── .chezmoitemplates/            # Reusable templates
│   ├── common-header.tmpl        # Shell setup, error handling
│   ├── platform-detect.tmpl      # OS/distro/machine detection
│   ├── 1password-agent.toml      # 1Password SSH-agent vault list
│   ├── op-read-safe              # Legacy single-secret resolver
│   ├── mise-tool-entry           # Reusable mise [tools] entry builder
│   ├── ssh-pub-resolve           # SSH public-key resolver (secrets + agent fallback)
│   └── common-header             # Shell setup, error handling, logging
│
├── .chezmoiscripts/              # Lifecycle scripts
│   ├── run_before_00_backup.*    # Pre-apply backup
│   ├── run_onchange_before_01_validate-secrets.sh.tmpl
│   └── run_onchange_install-packages-{unix,windows}.{sh,ps1}.tmpl
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

<!-- For the canonical list, see AGENTS.md "Template variables you will encounter in .tmpl files" -->

The full inventory of template variables lives in `AGENTS.md`. In short:

- Platform flags (`.is_windows`, `.is_linux`, `.is_darwin`, `.is_wsl`,
  `.is_container`, `.is_raspi`) come from `.chezmoi.toml.tmpl` at init time.
- Machine flags (`.is_remote`, `.is_personal`, `.is_work`, `.has_sudo`,
  `.hostname`, `.remote_tier`) classify the host; `.remote_tier` is the
  active size (`minimal` | `medium` | `full`).
- Feature flags (`.package_features.<name>`) are defined in
  `.chezmoidata/packages.yaml`. Refer to `INSTALL-GUIDE.md` § Feature Flags for the
  full list and defaults.

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

2. **`.chezmoidata/*.yaml`** (Static, version-controlled)
   - Split into focused files (`theme.yaml`, `fonts.yaml`, `ssh.yaml`,
     `packages.yaml`, `dns.yaml`, `mcp.yaml`). Chezmoi merges every
     `*.yaml` in `.chezmoidata/` into one template namespace at apply
     time, so adding a new top-level key is as simple as dropping a new
     file in this directory.
   - Package lists, scoop buckets, brew bundle, always-install sets
   - Theme colors + per-app theme name mappings
   - Font configuration
   - Feature flag definitions
   - DNS routing rules / DoT / DoH policy / Caddy CA trust

3. **`.chezmoi.local.toml`** (Per-machine overrides, gitignored)
   - Override any `.data` variable
   - Machine-specific settings
   - Example: `.chezmoi.local.toml.example`

### Configuration Priority

1. `.chezmoi.local.toml` (highest - machine-specific)
2. `.chezmoi.toml.tmpl` (generated defaults)
3. `.chezmoidata/*.yaml` (static defaults; all files merged into one namespace)

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
    remote_tier = "minimal"   # minimal | medium | full
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

**Tier model** (`remote_tier`):
- `minimal` — SSH-only servers. Skip GUI apps, ship only `node`, `python`,
  `go` + a few CLI tools (`fzf`, `ripgrep`, `fd`, `bat`, `delta`, `neovim`,
  `direnv`). No system packages; mise-only.
- `medium` — ARM SBCs / dev VMs. Raspberry Pi uses this tier for the
  lightweight zsh loader, but the bootstrap seeds `install_packages = false`
  so medium-tier tools are opt-in. See `RASPI.md`.
- `full` — desktop parity. All language runtimes, full CLI suite, GUI apps
  where they apply.

The sets live in `remote_packages.<tier>` in `.chezmoidata/packages.yaml`.
Unix renders them through `dot_config/mise/conf.d/00-managed.toml.tmpl`; Windows
renders the active global `~/.config/mise/config.toml` through
`dot_config/mise/modify_config.toml` because Windows mise 2026.5.7 does not
activate `conf.d` fragments. Toolchain fallbacks for no-sudo remote hosts
(`lua`, `luajit`, `vim`) come from `package_mapping.<feature>.mise_remote`.

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
├── config.toml                  # Windows: modify-managed active baseline + preserved user pins
│                                # Unix: user-owned `mise use -g` / settings overrides
├── conf.d/
│   └── 00-managed.toml          # Unix managed baseline tools + [settings]
├── config.medium.toml           # Medium-tier remote set (opt-in on Raspberry Pi)
└── config.remote.toml           # Minimal-tier remote set
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
│   └── ripgrep@14.1.0/
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

**Posture for committed secrets**:
This repo does not ship a `filter=secret` driver in `.gitattributes`.
Protection comes from two cheaper conventions:
- `private_` prefix — chezmoi sets 0600 on the deployed file; combined
  with placing all 1Password env-references under
  `dot_config/private_op/private_*.env`, the live file inherits user-only
  ACLs even on Windows.
- Batched `op inject` in `.chezmoi.toml.tmpl` — actual secret material is
  resolved at apply time and never lives in the chezmoi source tree.
  See `SECRETS.md` for the full pattern.

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
- Stored in `$XDG_STATE_HOME/chezmoi/backups/`:
  - Unix: `~/.local/state/chezmoi/backups/`
  - Windows: `%USERPROFILE%\.local\state\chezmoi\backups\` (XDG layout
    preserved on Windows; `%LOCALAPPDATA%` is **not** used)
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

- **Enhanced monitoring**: surface `scripts/healthcheck.sh` results in the
  shell prompt or a dashboard; track dependency drift between
  `.chezmoidata/*.yaml` and what's actually installed.
- **Community features**: this repo is personal; if it ever spins out a
  shareable variant, a plugin system and template marketplace would be
  the obvious extension points.

Testing infrastructure and secrets management are now shipped (Pester
tests for `bootstrap.ps1`, the batched `op inject` pattern, validation
scripts in `.chezmoiscripts/run_onchange_before_01_validate-secrets`).

---

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for development guidelines.

## References

- [Chezmoi Documentation](https://www.chezmoi.io/)
- [Mise Documentation](https://mise.jdx.dev/)
- [XDG Base Directory Spec](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)
- [1Password CLI](https://developer.1password.com/docs/cli/)

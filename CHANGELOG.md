# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- **wezterm: resurrect.wezterm + zoxide workspaces + tool overlays + broadcast + which-key**: `dot_config/wezterm/keymaps.lua` gains session save/load via [`resurrect.wezterm`](https://github.com/MLFlexer/resurrect.wezterm) (`LEADER+A` save, `LEADER+E` load), a zoxide-backed workspace picker (`LEADER+J`), tool overlays (`LEADER+X` then `g`/`t`/`n`/`o` for `lazygit`/`btop`/`nvim`/`opencode`), broadcast-to-panes toggle (`LEADER+B`), and a which-key style launcher (`LEADER+?`). The Spaceduck color scheme (`dot_config/wezterm/colors/Spaceduck.toml`, `wezterm.lua.tmpl`) is refreshed: corrected ANSI/brights mapping, distinct selection/visual-bell/tab/scrollbar tokens, and the palette is now mirrored in `wezterm_scheme` for tabline/UI accent consumers.
- **VS Code extensions managed by chezmoi**:
- **Workspace environment variables**: `PROJECTS`, `DHSPACE`, `BACKEND`, `FRONTEND`, `HELPSERVICES`, `NOTES` exported from `dot_config/zsh/dot_zshrc.d/10-dirs.zsh` (zsh) and `Documents/PowerShell/Scripts/99-aliases.ps1` (pwsh). All paths derive from `$HOME` via `Join-Path` (pwsh) / `$HOME/...` (zsh) — no hardcoded Windows paths. Structure: `PROJECTS = $HOME/projects`, `DHSPACE = $PROJECTS/dh`, `BACKEND/FRONTEND/HELPSERVICES = $DHSPACE/<bucket>`, `NOTES = $PROJECTS/notes`.
- **Navigation shortcuts** (zsh aliases / pwsh functions, guarded by directory existence on pwsh):
  - Workspace roots: `cdp`, `dh`, `cdbe`, `cdfe`, `cdhs`, `dots`, `notes`
  - Top-level DH repos: `cdn` (ndn), `cdaudit` (ndn-audit), `cdpam`, `cdscott`, `cdtm` (task-management)
  - Common backend services: `cdapi` (api-gateway), `cdcdn` (cdn-service)
- **`dhgitall`**: cross-platform helper (zsh + pwsh) that runs a `git` command across every repo under `$BACKEND/`, `$FRONTEND/`, `$HELPSERVICES/`. Skips entries without a `.git` directory. Top-level repos (ndn, pam, scott, etc.) are intentionally excluded — use them individually when you need to.
- **Encrypted DNS profile (macOS)**: New `encrypted_dns` block in `.chezmoidata.yaml` plus `dot_config/dns/private_pihole-dot.mobileconfig.tmpl` and `.chezmoiscripts/run_onchange_after_56_encrypted-dns.sh.tmpl` install a `com.apple.dnsSettings.managed` profile pinning the system resolver at `raspi.tailf7fd34.ts.net:853` over DoT. TCP-probes the endpoint before installing; skips with a warning if the Pi-side terminator isn't up yet. Encrypts the LAN leg of DNS that was previously plaintext UDP/53.
- **Browser DoH disable (macOS)**: New `browser_doh` block in `.chezmoidata.yaml` plus `.chezmoiscripts/run_onchange_after_57_browser-doh-policies.sh.tmpl` writes managed-policy files for Firefox (`policies.json`), Chrome, Edge, and Brave (`/Library/Managed Preferences/<bundle>.plist`) so they respect the system resolver instead of bypassing Pi-hole via Mozilla/Cloudflare DoH.
- **Pi-side DoT terminator setup**: `scripts/setup-pihole-dot.sh` installs `unbound`, mints a TLS cert via `tailscale cert`, and forwards plain DNS to Pi-hole. Run on the Pi, not the Mac.
- **RASPI.md** — "Encrypted DNS (DoT terminator)" section documenting the Pi-side prerequisite.
- **DNS.md** — full DNS architecture reference: resolver hierarchy, where each component lives in the chezmoi source, browser DoH disable mechanics, verification commands, and past failure modes (unbound validator/localhost defaults, deprecated `profiles install`, `/Library/Managed Preferences/` requiring MDM, the wrong-vault `raspi.pub` template).
- **Runtime secret injection via `op run` (Pattern B)**: New `dot_config/op/claude.env` env-reference file mapping env-var names to `op://` references, and a `claude` wrapper function in `Documents/PowerShell/Scripts/99-functions.ps1` that launches `claude.exe` via `op run --env-file=...`. Migrates `ANTHROPIC_API_KEY`, `TAVILY_API_KEY`, `VERCEL_TOKEN`, `NEON_API_KEY`, and `QDRANT_API_KEY` out of plaintext (`~/.claude.json` headers/env, rendered profile, User-scope env vars) into 1Password. `~/.claude.json` now references each via `${VAR}` substitution; secrets exist only in the wrapped child process. All 8 MCP servers verified connecting through the wrapper with no global env vars set.
- **SECRETS.md** — "Architecture B: Runtime Injection via `op run`" section documenting the new pattern alongside the existing render-time pattern, with runbooks for adding tools, adding secrets to existing tools, rotation, and leakage verification.
### Changed
- **`Documents/PowerShell/Scripts/80-op.ps1`** — hardened the 1Password CLI sign-in helper. Adds a `__OP_ENSURE_TTL` cache (5 minutes) so `Invoke-OpEnsure` doesn't re-probe `op whoami` on every shell-integration call, introduces `Invoke-OpRaw`/`Get-OpFailureKind`/`Wait-OpReady` to categorize failures (missing CLI vs locked vault vs auth required vs daemon not ready vs unknown), and exposes a single `Invoke-OpEnsure` entrypoint that returns `$true` only when `op` is actually usable. Stops the prior "prompt-on-every-pane" behavior on Windows where every new wezterm tab/pane re-triggered the biometric overlay.
- **`Documents/PowerShell/Scripts/99-aliases.ps1`**
- **`Documents/PowerShell/Scripts/lib/99-functions-body.ps1`** — `cdn`/`cdapi`/`cdcdn` retargeted from `$env:PROJECTS\<repo>` to `$env:DHSPACE\<repo>` / `$env:BACKEND\<repo>` to match the actual `BACKEND`/`FRONTEND`/`HELPSERVICES` layout under `~/projects/dh`.
- **`dot_config/zsh/dot_zshrc.d/{10-dirs,25-aliases}.zsh`** — removed hardcoded `/home/rmiller/projects` from `cdp` and `dhgitall`; repo shortcuts now derive from `$DHSPACE` / `$BACKEND`.
- **`.chezmoiignore`** — excludes `dot_config/dns/**` on non-darwin hosts and when `encrypted_dns.enabled = false`.
- **`Microsoft.PowerShell_profile.ps1.tmpl`** — removed the `$env:ANTHROPIC_API_KEY = "{{ .secrets.anthropic_api_key }}"` block. The literal value was being baked into the rendered profile on disk; Claude Code now receives the key at runtime via the op-run wrapper. Replaced with an explanatory comment.
- **`.chezmoi.toml.tmpl`** — fixed unix branch of the `op inject` resolver so `[data.secrets]` stays on its own line. Whitespace trimming around `{{- if -}}` was gluing the section header onto the first key (`[data.secrets]ssh_pub_github_com = ...`), causing TOML parse failures (`expected a top-level item to end with a newline ...`) on every `chezmoi init` after pulling commit `9147c48`. Now mirrors the windows branch's `printf "\n%s"` prefix.
- **`dot_ssh/config.tmpl`** — added a darwin-gated block at the top that re-includes `~/.orbstack/ssh/config`. OrbStack auto-injects this on macOS; without it in the template `chezmoi apply` would strip the include on every run.
- **`.chezmoiignore`** — excludes `.config/docker/config.json` on darwin. The template's `credsStore: "wincred"` is Windows-only, and OrbStack/Docker Desktop owns the file on macOS (writes `currentContext`, the correct `credsStore`, etc.). Letting the local file be authoritative on darwin stops the per-apply prompt loop.
### Removed
- **`~/.claude.json` literal credentials** — Vercel `Authorization: Bearer <token>`, Neon `Authorization: Bearer <token>`, and `qdrant.env.QDRANT_API_KEY` literal values replaced with `${VERCEL_TOKEN}`, `${NEON_API_KEY}`, and `${QDRANT_API_KEY}` references resolved by `op run` at process spawn.
---

## [2.0.0] - 2025-01-20

### 🎉 Major Release - Complete Rewrite

Version 2.0 represents a complete architectural rewrite focused on cross-platform support, maintainability, and user-space installation.

### ✨ Added

#### Template System
- **Reusable Template Library**: Created 4 core templates (~1200 lines)
  - `common-header.tmpl` - Shell setup, error handling, logging functions
  - `platform-detect.tmpl` - OS/distro/WSL/container detection
  - `package-manager.tmpl` - Cross-platform package abstraction
  - `1password.tmpl` - Secrets integration

#### Remote Machine Support
- **Remote Detection**: Automatic SSH/VSCode Remote/container detection
- **Minimal Package Sets**: Lightweight configs for remote servers
- **No-Sudo Support**: User-space installations via mise
- **Remote Config**: Dedicated `config.remote.toml` for minimal environments
- **REMOTE.md**: 500+ line guide for remote machine setup

#### Configuration Management
- **Machine Detection**: Automatic classification (personal/work/remote/container)
- **Permission Detection**: Runtime sudo capability checking
- **Feature Flags**: Granular control over optional configurations
- **Local Overrides**: `.chezmoi.local.toml` for machine-specific settings
- **Smart Defaults**: Context-aware based on machine type

#### Backup & Rollback
- **Automatic Backups**: Pre-apply backups with metadata
- **Rollback Scripts**: Unix (`rollback.sh`) and Windows (`rollback.ps1`)
- **Retention Policy**: Keep last 10 backups automatically
- **Cross-Platform**: Works on Windows, Linux, macOS

#### Package Management
- **Mise Integration**: Unified runtime/tool manager for all platforms
- **Platform Strategy**: 
  - Windows: scoop (CLI) + winget (GUI) + mise (runtimes)
  - Linux/macOS: mise (everything)
  - Remote: mise only (user-space)
- **Conditional Installation**: Smart package selection based on environment
- **Remote Minimal**: Reduced package set for limited environments

#### Security & Secrets
- **1Password Integration**: Comprehensive secret management
- **Age Encryption**: File encryption support
- **Validation Scripts**: Pre-apply secret verification
- **SECRETS.md**: 500+ line secrets management guide

#### Monitoring & Maintenance
- **Health Check Script**: Comprehensive system validation
  - Chezmoi state verification
  - Tool version checking
  - Outdated package detection
  - Disk usage analysis
- **Status Dashboard**: Real-time configuration status

#### Documentation
- **ARCHITECTURE.md**: Complete architecture documentation (500+ lines)
- **CONTRIBUTING.md**: Development and contribution guide (500+ lines)
- **REMOTE.md**: Remote machine setup guide (500+ lines)
- **SECRETS.md**: Secrets management guide (500+ lines)
- **Enhanced README**: Updated with v2.0 features
- **INSTALL-GUIDE.md**: Platform-specific installation instructions

### 🔄 Changed

#### Configuration Consolidation
- **40% Duplication Reduction**: Consolidated overlapping configs
- **Reorganized Structure**: Clear separation of concerns
- **Improved Naming**: Consistent, descriptive file names

#### Bootstrap Scripts
- **Enhanced setup.sh**: 
  - Pre-flight validation (4 checks)
  - Sudo detection with graceful fallback
  - Progress indicators
  - Error recovery
- **Enhanced bootstrap.ps1**:
  - Pre-flight validation (5 checks)
  - Developer Mode detection/enablement
  - 1Password CLI integration
  - Better error handling

#### Platform Support
- **Windows**: Developer Mode auto-detection, improved symlink support
- **Linux**: Distro-specific optimizations (Ubuntu/Arch/Fedora)
- **macOS**: Native Zsh support, Homebrew for GUI only
- **WSL**: Optimized for WSL2, proper Windows interop
- **Remote**: No-sudo, minimal footprint, fast bootstrap

### 🗑️ Removed

- **ASDF**: Replaced with mise
- **NVM**: Replaced with mise node management
- **Deprecated Configs**: php, diff-so-fancy (cleaned up)
- **Legacy Scripts**: Consolidated into template system

### 🐛 Fixed

- **Template Variables**: Fixed `.user.*` → direct access (`.name`, `.email`)
- **Git Config**: Corrected Windows conditional includes
- **PowerShell Profile**: Fixed theme variable references
- **Package Lists**: Removed duplicates and conflicts
- **Cache Directories**: Proper Windows exclusions for `.cache/zsh/**`

### 📦 Package Changes

#### Added
- mise (replaces asdf/nvm)
- sqlite
- fzf (moved to scoop on Windows)

#### Removed
- asdf
- nvm  
- diff-so-fancy
- php (not actively used)

#### Clarified Strategy
- **Runtimes** (mise): node, python, ruby, go, rust, zig, bun, deno, lua
- **CLI Tools** (scoop on Windows, mise on Unix): bat, eza, fd, ripgrep, starship, neovim
- **Universal Tools** (mise everywhere): direnv, uv, yarn

### 🎯 Platform-Specific

#### Windows
- Developer Mode detection and enablement
- Scoop + Winget + Mise strategy
- PowerShell 7+ profile enhancements
- Windows Terminal auto-configuration

#### Linux/WSL
- Mise-first approach (no system packages unless needed)
- Distro detection (Ubuntu/Arch/Fedora/etc.)
- Zsh as primary shell
- XDG Base Directory compliance

#### macOS
- Homebrew for GUI apps only
- Mise for all CLI tools and runtimes
- Native Zsh support
- macOS-specific configs (karabiner, etc.)

#### Remote/SSH
- Automatic detection
- Minimal package installation
- No-sudo support
- Reduced disk footprint
- User-space only installations

### 📊 Statistics

- **Files Created**: 15+ new files
- **Files Modified**: 10+ existing files  
- **Lines Added**: ~5000+ lines of code and documentation
- **Templates**: 4 reusable templates (~1200 lines)
- **Documentation**: 2000+ lines across 5 guides
- **Duplication Reduced**: 40%

### 🔐 Security

- Enhanced secrets management with 1Password
- Age encryption support
- Pre-apply validation scripts
- Automatic backups before changes
- No secrets in version control (enforced)

### ⚡ Performance

- Parallel mise installations (4 jobs)
- Reduced package count on remote
- Cached downloads
- Faster bootstrap with pre-checks

### 🧪 Testing

- Health check script for validation
- Dry-run support throughout
- Backup/rollback capabilities
- Template validation tools

---

## [1.0.0] - 2024-12-01

### Initial Release

- Basic dotfiles for Windows, Linux, macOS
- Git, Zsh, Neovim configurations
- PowerShell profile
- WezTerm terminal config
- Manual package management
- Limited cross-platform support

---

## Links

- [Repository](https://github.com/Randallsm83/dotfiles)
- [Issues](https://github.com/Randallsm83/dotfiles/issues)
- [Compare v1.0...v2.0](https://github.com/Randallsm83/dotfiles/compare/v1.0.0...v2.0.0)

---

## Migration Guide

### From v1.0 to v2.0

**Breaking Changes**:
- Package managers: asdf/nvm → mise
- Configuration structure changed significantly
- Template variables renamed

**Migration Steps**:

1. **Backup current dotfiles**:
   ```bash
   chezmoi archive > ~/dotfiles-backup-v1.tar.gz
   ```

2. **Clean existing installation**:
   ```bash
   # Remove old chezmoi state
   rm -rf ~/.local/share/dotfiles
   rm -rf ~/.config/chezmoi
   ```

3. **Install v2.0**:
   ```bash
   # Unix
   sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply Randallsm83/dotfiles
   
   # Windows
   .\bootstrap.ps1
   ```

4. **Migrate custom configs**:
   - Review old configs
   - Add overrides to `.chezmoi.local.toml`
   - Manually merge custom changes

5. **Verify installation**:
   ```bash
   ./scripts/healthcheck.sh  # Unix
   ```

**Notes**:
- mise will automatically migrate tool versions
- 1Password integration is optional
- Secrets must be reconfigured (see SECRETS.md)
- Remote machines now work out of the box

---

## Support

- 📖 [Documentation](./README.md)
- 🐛 [Report Issues](https://github.com/Randallsm83/dotfiles/issues)
- 💬 [Discussions](https://github.com/Randallsm83/dotfiles/discussions)
- 🤝 [Contributing](./CONTRIBUTING.md)

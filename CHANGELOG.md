# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

None

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
   rm -rf ~/.local/share/chezmoi
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

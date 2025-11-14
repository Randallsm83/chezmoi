# Package Mapping and Feature Flags

**Date**: 2025-01-14  
**Purpose**: Document which files are controlled by which feature flags

## Overview

This document maps packages to their feature flags and controlled files. It serves as a reference during migration and when enabling/disabling package_features.

### Organization Approach

Files are organized using **location-based placement** with **feature flag control**:
- Files are placed in their deployment locations within the chezmoi source directory
- `.chezmoiignore` uses template logic to conditionally exclude files based on feature flags
- Feature flags in `.chezmoidata.yaml` control which files are deployed
- Core packages are always deployed (no feature flag)
- Optional packages can be toggled via their feature flag

---

## Core Packages

These packages are **always enabled** and have no feature flag control. They represent the essential development environment.

| Package | Files Controlled | Notes |
|---------|------------------|-------|
| **git** | `.config/git/config.tmpl`<br/>`.config/git/ignore` | Git configuration with platform-specific conditionals |
| **nvim** | `.config/nvim/**` | Complete Neovim configuration (44+ files) |
| **wezterm** | `.config/wezterm/*.lua` | WezTerm terminal configuration |
| **starship** | `.config/starship/starship.toml` | Starship prompt configuration |
| **mise** | `.config/mise/config.toml.tmpl` | Mise runtime and tool manager |
| **bat** | `.config/bat/config` | Better cat with syntax highlighting |
| **direnv** | `.config/direnv/direnv.toml` | Per-directory environment management |
| **eza** | `.config/eza/flags.txt` | Modern ls replacement |
| **fzf** | `.config/fzf/fzf.bash` | Fuzzy finder configuration |
| **ripgrep** | `.config/ripgrep/ripgreprc` | Fast text search tool |
| **wget** | `.config/wget/wgetrc` | HTTP client configuration |
| **zsh** | `.config/zsh/dot-zshrc`<br/>`.config/zsh/dot-zshenv`<br/>`.config/zsh/dot-zprofile`<br/>`.config/zsh/dot-zsh_plugins.txt`<br/>`.config/zsh/dot-zshrc.d/**` (core only) | Core zsh configuration (Unix only) |
| **ssh** | `.ssh/config.tmpl`<br/>`.ssh/config.d/**` | SSH client configuration |
| **1password** | Integrated into ssh/git configs | 1Password SSH agent integration |
| **windows** | `Documents/PowerShell/**`<br/>`AppData/Roaming/Code/User/**` | PowerShell profile, VS Code settings (Windows only) |
| **wsl** | `.wslconfig` | WSL2 configuration (Windows only) |

**Total Core Files**: ~117 files currently managed

---

## Optional Language Packages

These packages are **controlled by feature flags** in `.chezmoidata.yaml`. When enabled, their files are deployed. When disabled, they're ignored via `.chezmoiignore`.

| Package | Feature Flag | Default | Files Controlled | Notes |
|---------|--------------|---------|------------------|-------|
| **rust** | `package_features.rust` | `true` | ✅ `.config/zsh/.zshrc.d/70-rust.zsh`<br/>✅ `.cache/zsh/completions/_rustc` | Rust language configuration - **MIGRATED** |
| **golang** | `package_features.golang` | `true` | `.config/go/env`<br/>`.config/zsh/.zshrc.d/70-golang.zsh` | Go language configuration |
| **python** | `package_features.python` | `true` | `.config/python/**`<br/>`.config/pip/pip.conf`<br/>`.config/zsh/.zshrc.d/70-python.zsh` | Python language configuration |
| **ruby** | `package_features.ruby` | `true` | `.config/ruby/**`<br/>`.config/bundle/**`<br/>`.config/gem/gemrc`<br/>`.config/zsh/.zshrc.d/70-ruby.zsh` | Ruby language configuration |
| **lua** | `package_features.lua` | `true` | `.config/lua/**`<br/>`.config/zsh/.zshrc.d/70-lua.zsh` | Lua language configuration |
| **node** | `package_features.node` | `true` | `.config/node/**`<br/>`.config/npm/npmrc`<br/>`.config/yarn/**`<br/>`.config/zsh/.zshrc.d/70-node.zsh`<br/>`.config/zsh/.zshrc.d/bun.zsh`<br/>`.config/zsh/.zshrc.d/npm.zsh` | Node.js, npm, yarn, bun configuration |
| **perl** | `package_features.perl` | `false` | `.config/perl/**`<br/>`.perltidyrc`<br/>`.cache/zsh/completions/_cpanm` | Perl language configuration |
| **php** | `package_features.php` | `false` | `.config/php/**`<br/>`.config/zsh/.zshrc.d/70-php.zsh` | PHP language configuration |

---

## Deprecated/Legacy Packages

These packages are **disabled by default** as they've been replaced by better alternatives.

| Package | Feature Flag | Default | Files Controlled (when migrated) | Notes |
|---------|--------------|---------|-----------------------------------|-------|
| **asdf** | `package_features.asdf` | `false` | `.config/asdf/asdfrc`<br/>`.config/asdf/tool-versions`<br/>`.config/zsh/.zshrc.d/50-asdf.zsh` | **Replaced by mise** - kept for migration reference |
| **nvm** | `package_features.nvm` | `false` | `.config/nvm/**`<br/>`.config/zsh/.zshrc.d/70-nvm.zsh` | **Replaced by mise** - kept for migration reference |

---

## Optional Tool Packages

These packages provide additional development and utility tools, controlled by feature flags.

| Package | Feature Flag | Default | Files Controlled (when migrated) | Notes |
|---------|--------------|---------|-----------------------------------|-------|
| **arduino** | `package_features.arduino` | `false` | `.config/arduino/**`<br/>`.config/zsh/.zshrc.d/70-arduino.zsh` | Arduino IDE configuration |
| **glow** | `package_features.glow` | `true` | `.config/glow/glow.yml`<br/>`.config/zsh/.zshrc.d/90-glow.zsh` | Markdown viewer in terminal |
| **tinted_theming** | `package_features.tinted_theming` | `true` | `.config/tinted-theming/**`<br/>`.config/zsh/.zshrc.d/80-tinty.zsh` | Base16/Base24 theme manager |
| **thefuck** | `package_features.thefuck` | `false` | `.config/thefuck/settings.py`<br/>`.config/zsh/.zshrc.d/thefuck.zsh` | Command correction tool |
| **sqlite3** | `package_features.sqlite3` | `true` | `.config/sqlite3/sqliterc`<br/>`.sqliterc` | SQLite CLI configuration |
| **vim** | `package_features.vim` | `false` | `.config/vim/vimrc`<br/>`.vimrc` | Vim configuration (separate from neovim) |
| **vivid** | `package_features.vivid` | `true` | `.config/vivid/themes/**` | LS_COLORS generator |
| **warp** | `package_features.warp` | `true` | `.config/warp/launch_configurations/**` | Warp terminal configuration |

---

## Utility Packages

These packages are either bootstrap-only or rarely used utilities.

| Package | Feature Flag | Default | Files Controlled (when migrated) | Notes |
|---------|--------------|---------|-----------------------------------|-------|
| **homebrew** | `package_features.homebrew` | `false` | `.config/homebrew/Brewfile`<br/>`.config/homebrew/Brewfile.lock.json`<br/>`.config/zsh/.zshrc.d/50-homebrew.zsh` | **Bootstrap only** - not actively managed in dotfiles |
| **vagrant** | `package_features.vagrant` | `false` | `.cache/zsh/completions/_vagrant` | VM management tool |

---

## Migration Status

### Currently Migrated
- ✅ All core packages (117 files)
- ✅ Feature flag infrastructure
- ✅ Documentation
- ✅ **rust** package (2 files) - zsh integration, completions

### Pending Migration
- ⏳ Language packages (golang, python, ruby, lua, node, perl, php)
- ⏳ Tool packages (glow, tinted_theming, sqlite3, vivid, warp, etc.)
- ⏳ Deprecated packages (asdf, nvm - for reference only)
- ⏳ Utility packages (homebrew, vagrant)

---

## How to Use Feature Flags

### Enable a Package

1. Set the flag to `true` in `.chezmoidata.yaml`:
   ```yaml
   packages:
     rust: true
   ```

2. The package's files will **not** be listed in `.chezmoiignore`
3. Run `chezmoi apply` to deploy the files

### Disable a Package

1. Set the flag to `false` in `.chezmoidata.yaml`:
   ```yaml
   packages:
     rust: false
   ```

2. The package's files **will** be listed in `.chezmoiignore`
3. Run `chezmoi apply` to remove the files from your home directory

### Verify What Will Be Deployed

```bash
# See which files would be applied
chezmoi apply --dry-run --verbose

# See differences
chezmoi diff

# Check which files are ignored
chezmoi data | grep -A 50 packages
```

---

## File Naming Patterns

### Zsh Integration Files

Language and tool packages typically include zsh integration scripts:
- Pattern: `.config/zsh/.zshrc.d/##-<package>.zsh`
- Numbering:
  - `50-` - Package managers and version managers (asdf, homebrew)
  - `70-` - Language environments (rust, golang, python, ruby, lua, node, php, arduino)
  - `80-` - Theming tools (tinty)
  - `90-` - Utility tools (glow, thefuck)

### Completion Files

Cached completion files for external commands:
- Pattern: `.cache/zsh/completions/_<command>`
- Examples: `_rustc`, `_cpanm`, `_vagrant`

### Config Files

Configuration files follow XDG Base Directory spec:
- Pattern: `.config/<package>/**`
- Examples: `.config/cargo/config.toml`, `.config/pip/pip.conf`

---

## Next Steps

1. Begin migrating packages one at a time, starting with high-priority enabled packages
2. For each package:
   - Copy files from old dotfiles to correct chezmoi locations
   - Update `.chezmoiignore` by uncommenting the relevant file patterns
   - Test with `chezmoi diff` and `chezmoi apply --dry-run`
   - Commit the changes
3. Update this document's migration status as packages are completed

---

**Last Updated**: 2025-01-14  
**Status**: First package migrated (rust), 119 files managed  
**Note**: Feature flags use `package_features.*` (not `package_features.*`) to avoid conflict with package lists

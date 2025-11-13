# Chezmoi Migration Audit Report

**Date**: 2025-01-14
**Purpose**: Complete audit of current chezmoi repository state compared to old stow-based dotfiles
**Status**: TODO #1 Complete - Major structural issues identified

## Executive Summary

The last commit (263c05a) attempted to bulk-migrate all remaining configs from the old dotfiles, but introduced severe structural problems:

1. **Nested directory duplications**: Many packages have both `package/asdf/` AND `package/dot-config/asdf/` structures
2. **Incorrect zsh integration placement**: zsh integration files duplicated in both `package/zsh/` and `package/dot-config/zsh/`
3. **Mixed directory naming**: Some use underscores (`dot_config`), some use hyphens incorrectly
4. **Missing golang directory**: No golang configs migrated, only basic `go/env` file exists
5. **No feature flag system implemented**: Cannot enable/disable packages independently

## Old Dotfiles Structure (Stow-based)

**Location**: `C:\Users\Randall\.config\dotfiles`
**Stow command**: `stow --dot-files --no-folding`

### Key Packages in Old Dotfiles:
```
dotfiles/
├── zsh/
│   ├── dot-config/zsh/
│   │   ├── dot-zshrc
│   │   ├── dot-zshenv
│   │   ├── dot-zprofile
│   │   ├── dot-zsh_plugins.txt
│   │   ├── dot-zstyles
│   │   ├── dot-zfunctions/
│   │   ├── dot-zshrc.d/       # Core zsh scripts (24 files)
│   │   └── colors/
│   └── dot-zshenv
│
├── rust/
│   ├── dot-cache/zsh/completions/
│   └── dot-config/zsh/dot-zshrc.d/
│       └── 70-rust.zsh
│
├── golang/
│   └── dot-config/zsh/dot-zshrc.d/
│       └── 70-golang.zsh
│
├── python/
│   └── dot-config/zsh/dot-zshrc.d/
│       └── 70-python.zsh
│
├── ruby/
│   └── dot-config/zsh/dot-zshrc.d/
│       └── 70-ruby.zsh
│
├── asdf/
│   └── dot-config/
│       ├── asdf/
│       │   ├── asdfrc
│       │   └── tool-versions
│       └── zsh/dot-zshrc.d/
│           └── 50-asdf.zsh
│
├── homebrew/
│   └── dot-config/
│       ├── homebrew/
│       │   ├── Brewfile
│       │   └── Brewfile.lock.json
│       └── zsh/dot-zshrc.d/
│           └── 50-homebrew.zsh
│
├── nvm/
│   └── dot-config/zsh/dot-zshrc.d/
│       └── 70-nvm.zsh
│
├── php/
│   └── dot-config/zsh/dot-zshrc.d/
│       └── 70-php.zsh
│
├── arduino/
│   └── dot-config/zsh/dot-zshrc.d/
│       └── 70-arduino.zsh
│
├── glow/
│   ├── dot-config/glow/
│   │   └── glow.yml
│   └── dot-config/zsh/dot-zshrc.d/
│       └── 90-glow.zsh
│
├── tinted-theming/
│   ├── dot-config/tinted-theming/tinty/
│   │   └── config.toml
│   └── dot-config/zsh/dot-zshrc.d/
│       └── 80-tinty.zsh
│
├── perl/
│   ├── dot-perltidyrc
│   └── dot-cache/zsh/completions/
│       └── _cpanm
│
├── vagrant/
│   └── dot-cache/zsh/completions/
│       └── _vagrant
│
├── vim/
│   └── dot-config/vim/
│       └── vimrc
│
├── thefuck/
│   └── dot-config/thefuck/
│       └── settings.py
│
├── sqlite3/
│   └── dot-config/sqlite3/
│       └── sqliterc
│
├── npm/
│   └── dot-config/npm/
│       └── npmrc
│
├── utilities/
│   └── dot-local/utilities/
│       └── UtilCacheClean.ps1
│
├── ssh/
│   ├── dot-ssh/
│   │   ├── config
│   │   └── config.d/
│   │       └── wsl
│   └── setup-1password-wsl.sh
│
├── vivid/
│   ├── README.md
│   └── dot-config/vivid/themes/
│       └── spaceduck.yml
│
├── warp/
│   └── dot-config/warp/launch_configurations/
│       ├── arch-dev.yaml
│       ├── powershell-dev.yaml
│       ├── ssh-connections.yaml
│       ├── ssh-remote.yaml
│       └── ssh-template.yaml
│
├── bin/
│   └── dot-local/bin/
│       ├── relink_gcc.sh
│       └── ssh-key-manager.sh
│
├── editorconfig/
│   └── dot-editorconfig
│
├── windows/
│   ├── dot-wslconfig
│   └── AppData/Roaming/Code/User/
│       ├── settings.json
│       └── keybindings.json
│
└── wsl/
    └── dot-local/wsl/
        └── wsl-open.sh
```

### Stow Deployment Behavior (`--dot-files`):
- `dot-` prefix in filename → `.` in target
- `dotfiles/rust/dot-config/zsh/dot-zshrc.d/70-rust.zsh` → `~/.config/zsh/.zshrc.d/70-rust.zsh`
- Each package manages its own files independently
- Can stow/unstow individual packages

## Current Chezmoi Repository Structure

**Location**: `C:\Users\Randall\.local\share\chezmoi`
**Last commit**: 263c05a - "migrate ALL remaining configs" (INCORRECT)

### Correct Structure (Phases 1-2):
```
.
├── .chezmoi.toml.tmpl              ✓ Correct
├── .chezmoidata.yaml               ⚠ Needs feature flags added
├── .chezmoiignore                  ⚠ Needs package control logic
├── .chezmoiscripts/                ✓ Correct
├── .chezmoitemplates/              ✓ Correct
├── bootstrap.ps1                   ✓ Correct
├── setup.sh                        ✓ Correct
├── dot_config/
│   ├── git/                        ✓ Correct (Phase 2)
│   ├── nvim/                       ✓ Correct (Phase 2)
│   ├── wezterm/                    ✓ Correct (Phase 2)
│   ├── starship/                   ✓ Correct (Phase 2)
│   ├── mise/                       ✓ Correct (Phase 2)
│   ├── bat/                        ✓ Correct (Phase 3)
│   ├── ripgrep/                    ✓ Correct (Phase 3)
│   ├── direnv/                     ✓ Correct (Phase 3)
│   ├── wget/                       ✓ Correct (Phase 3)
│   ├── eza/                        ✓ Correct (Phase 3)
│   ├── fd/                         ✓ Correct (Phase 3)
│   ├── fzf/                        ✓ Correct (Phase 3)
│   └── zsh/                        ⚠ Mixed Phase 2/3 content
│       ├── dot-zshrc               ✓ Correct
│       ├── dot-zshenv              ✓ Correct
│       ├── dot-zprofile            ✓ Correct
│       ├── dot-zsh_plugins.txt     ✓ Correct
│       ├── dot-zstyles             ✓ Correct
│       ├── dot-zfunctions/         ✓ Correct
│       ├── colors/                 ✓ Correct
│       └── dot-zshrc.d/            ⚠ Contains both core AND package scripts (WRONG)
│           ├── 00-helpers.zsh      ✓ Core
│           ├── 01-mise.zsh         ✓ Core
│           ├── 10-*.zsh            ✓ Core
│           ├── 20-paths.zsh        ✓ Core
│           ├── 30-misc.zsh         ✓ Core
│           ├── 70-golang.zsh       ✗ Should be in golang package
│           └── ... (other package scripts mixed in)
│
├── dot_local/
│   └── bin/
│       ├── executable_relink_gcc.sh        ✓ Correct
│       └── executable_ssh-key-manager.sh   ✓ Correct
│
├── Documents/PowerShell/            ✓ Correct (Phase 2)
├── AppData/Roaming/Code/User/       ✓ Correct (Phase 3)
└── dot_editorconfig                 ✓ Correct
```

### INCORRECT Structure (Phase 3 bulk copy):
```
dot_config/
├── asdf/                            ✗ STRUCTURAL ISSUES
│   ├── asdf/                        ← Duplicate 1: bare files
│   │   ├── asdfrc
│   │   └── tool-versions
│   ├── dot-config/                  ← Duplicate 2: nested dot-config (WRONG!)
│   │   ├── asdf/
│   │   │   ├── asdfrc
│   │   │   └── tool-versions
│   │   └── zsh/dot-zshrc.d/
│   │       └── 50-asdf.zsh
│   └── zsh/                         ← Duplicate 3: bare zsh
│       └── dot-zshrc.d/
│           └── 50-asdf.zsh
│
├── homebrew/                        ✗ STRUCTURAL ISSUES
│   ├── homebrew/                    ← Duplicate 1
│   │   ├── Brewfile
│   │   └── Brewfile.lock.json
│   ├── dot-config/                  ← Duplicate 2 (WRONG!)
│   │   ├── homebrew/
│   │   │   ├── Brewfile
│   │   │   └── Brewfile.lock.json
│   │   └── zsh/dot-zshrc.d/
│   └── zsh/                         ← Duplicate 3
│       └── dot-zshrc.d/
│
├── npm/                             ✗ STRUCTURAL ISSUES
│   ├── npmrc                        ← Duplicate 1
│   └── dot-config/                  ← Duplicate 2 (WRONG!)
│       └── npm/
│           └── npmrc
│
├── sqlite3/                         ✗ STRUCTURAL ISSUES
│   ├── sqlite3/                     ← Duplicate 1
│   │   └── sqliterc
│   └── dot-config/                  ← Duplicate 2 (WRONG!)
│       └── sqlite3/
│           └── sqliterc
│
├── thefuck/                         ✗ STRUCTURAL ISSUES
│   ├── thefuck/                     ← Duplicate 1
│   │   └── settings.py
│   └── dot-config/                  ← Duplicate 2 (WRONG!)
│       └── thefuck/
│           └── settings.py
│
├── utilities/                       ✗ STRUCTURAL ISSUES
│   ├── UtilCacheClean.ps1          ← Wrong location (should be in dot_local)
│   ├── dot-local/                   ← Nested dot-local (WRONG!)
│   │   ├── UtilCacheClean.ps1
│   │   └── utilities/
│   │       └── UtilCacheClean.ps1
│   └── utilities/
│       └── UtilCacheClean.ps1
│
├── vim/                             ✗ STRUCTURAL ISSUES
│   ├── vim/                         ← Duplicate 1
│   │   └── vimrc
│   └── dot-config/                  ← Duplicate 2 (WRONG!)
│       └── vim/
│           └── vimrc
│
├── ssh/                             ✗ STRUCTURAL ISSUES
│   ├── config                       ← Should be in ~/.ssh/ not ~/.config/ssh/
│   ├── config.d/
│   │   └── wsl
│   ├── dot-ssh/                     ← This is correct location but inside wrong parent
│   │   ├── config
│   │   └── config.d/
│   │       └── wsl
│   └── setup-1password-wsl.sh      ← Script location unclear
│
├── rust/                            ⚠ INCOMPLETE
│   └── zsh/
│       └── completions/
│           └── _rustc              ← Missing: 70-rust.zsh integration!
│                                      Missing: .cargo/config.toml!
│
├── go/                              ⚠ INCOMPLETE - Missing golang integration!
│   └── env                          ← Only basic env file, no zsh integration
│
├── arduino/                         ⚠ Structure needs verification
│   └── zsh/dot-zshrc.d/
│       └── 70-arduino.zsh
│
├── glow/                            ✗ STRUCTURAL ISSUES
│   ├── glow/
│   │   └── glow.yml
│   └── zsh/dot-zshrc.d/
│       └── 90-glow.zsh
│
├── tinted-theming/                  ✗ STRUCTURAL ISSUES
│   ├── tinted-theming/
│   │   └── tinty/config.toml
│   └── zsh/dot-zshrc.d/
│       └── 80-tinty.zsh
```

## Critical Issues Summary

### 1. Nested `dot-config` Directories (WRONG!)
Many packages have `dot-config/` subdirectories inside `dot_config/package/`. This creates incorrect paths like:
- `~/.config/asdf/.config/asdf/asdfrc` (WRONG!)
- Should be: `~/.config/asdf/asdfrc`

**Affected packages**: asdf, homebrew, npm, sqlite3, thefuck, vim, utilities

### 2. Duplicate File Structures
Many packages have 2-3 copies of the same file in different nested locations.

### 3. Missing Golang Configuration
No golang package with zsh integration exists. Only basic `go/env` file present.

### 4. SSH Configuration in Wrong Location
SSH configs are in `dot_config/ssh/` but should be in `dot_ssh/` (deploying to `~/.ssh/`)

### 5. Rust Package Incomplete
Missing:
- `dot-config/rust/dot-cargo/config.toml` (cargo settings)
- `dot-config/zsh/dot-zshrc.d/70-rust.zsh` (zsh integration)

Only has: rust completions file

### 6. No Feature Flag System
- `.chezmoidata.yaml` doesn't have feature flags for packages
- `.chezmoiignore` doesn't have conditional ignores
- Cannot enable/disable packages independently

### 7. Mixed Package and Core Files
`dot_config/zsh/dot-zshrc.d/` contains both:
- Core zsh scripts (correct)
- Package-specific integrations like `70-golang.zsh` (should be with golang package)

## Understanding Chezmoi's Cross-Directory Deployment

Chezmoi CAN deploy files from package directories to other locations using proper structure:

### Example: Rust package managing zsh integration
```
chezmoi/
└── dot_config/
    └── rust/                                    # Package directory
        ├── dot-cargo/
        │   └── config.toml                      # Deploys to ~/.config/rust/.cargo/config.toml
        └── dot-dot-dot-zsh/                     # Special naming!
            └── dot-zshrc.d/
                └── 70-rust.zsh                  # Deploys to ~/.config/zsh/.zshrc.d/70-rust.zsh
```

Chezmoi interprets `dot-dot-dot-zsh` as:
1. First `dot-` → Remove (chezmoi prefix)
2. Second `dot-` → Convert to `..` (parent directory escape)
3. Third `dot-` → Part of path component
4. Result: From `~/.config/rust/`, go up to `~/.config/`, then into `zsh/`

**RESEARCH NEEDED**: Confirm this is the correct approach or if there's a better method.

## Target Correct Structure

Based on chezmoi best practices and user requirements:

```
chezmoi/
├── .chezmoidata.yaml
│   features:
│     rust: true
│     golang: true
│     python: true
│     # ... all packages as feature flags
│
├── .chezmoiignore
│   {{- if not .features.rust }}
│   .config/rust/**
│   .config/zsh/.zshrc.d/70-rust.zsh
│   {{- end }}
│   # ... similar for all packages
│
└── dot_config/
    ├── zsh/                                     # Core zsh (always enabled)
    │   ├── dot-zshrc.tmpl
    │   ├── dot-zshenv.tmpl
    │   ├── dot-zprofile
    │   ├── dot-zsh_plugins.txt
    │   ├── dot-zstyles
    │   ├── dot-zfunctions/
    │   ├── colors/
    │   └── dot-zshrc.d/                         # Only core scripts here
    │       ├── 00-helpers.zsh
    │       ├── 01-mise.zsh
    │       ├── 10-*.zsh
    │       ├── 20-paths.zsh
    │       ├── 30-misc.zsh
    │       ├── aliases.zsh
    │       ├── functions.zsh
    │       ├── history.zsh
    │       └── ... (core only)
    │
    ├── rust/                                    # Feature: rust
    │   ├── dot-cargo/
    │   │   └── config.toml
    │   └── [cross-directory path to zsh integration]
    │
    ├── golang/                                  # Feature: golang
    │   ├── go/
    │   │   └── env
    │   └── [cross-directory path to zsh integration]
    │
    ├── python/                                  # Feature: python
    │   └── [cross-directory path to zsh integration]
    │
    ├── ruby/                                    # Feature: ruby
    │   └── [cross-directory path to zsh integration]
    │
    ├── asdf/                                    # Feature: asdf
    │   ├── dot-asdf/
    │   │   ├── asdfrc
    │   │   └── tool-versions
    │   └── [cross-directory path to zsh integration]
    │
    ├── homebrew/                                # Feature: homebrew
    │   ├── dot-homebrew/
    │   │   ├── Brewfile
    │   │   └── Brewfile.lock.json
    │   └── [cross-directory path to zsh integration]
    │
    # ... similar for all other packages
    │
    ├── git/                                     # Core (always enabled)
    ├── nvim/                                    # Core (always enabled)
    ├── starship/                                # Core (always enabled)
    └── mise/                                    # Core (always enabled)

dot_local/
├── bin/
│   ├── executable_relink_gcc.sh
│   └── executable_ssh-key-manager.sh
└── wsl/                                         # Feature: wsl
    └── executable_wsl-open.sh

dot_ssh/                                         # Core SSH config
├── config.tmpl
├── config.d/
│   └── wsl.tmpl
└── executable_setup-1password-wsl.sh

dot_cache/                                       # Completions cache
└── zsh/
    └── completions/
        ├── _rustc                               # From rust package
        ├── _cpanm                               # From perl package
        └── _vagrant                             # From vagrant package
```

## Files Accounting

### Phase 1 (Complete): 14 files
- Core chezmoi config
- Documentation
- Bootstrap scripts

### Phase 2 (Complete): 30 files
- Git, Neovim, WezTerm, Starship, Mise, Bat, PowerShell, basic Zsh

### Phase 3 (Incorrect - 301 files added):
- Attempted bulk copy created 345 total managed files
- But with duplications and wrong structures

### Files Still Needed from Old Dotfiles:
Based on old dotfiles listing, approximately **150-200 unique config files** need proper migration:
- Language packages: rust, golang, python, ruby, lua, perl, php, node, nvm, arduino
- Tool packages: asdf, homebrew, glow, tinted-theming, vagrant, thefuck, sqlite3, vivid, warp
- Shell integrations: Each language's zsh integration
- Completions: rust, perl, vagrant completions
- Scripts: bin/, utilities/, wsl/

## Next Actions (Following TODO List)

**TODO #2**: Clean up incorrect directory structures
- Remove all `dot-config/` subdirectories inside `dot_config/package/`
- Remove duplicate files
- Remove incorrectly placed files

**TODO #3**: Research chezmoi cross-directory deployment
- Confirm how to make `rust/` manage files that deploy to `zsh/.zshrc.d/`
- Document the correct syntax

**TODO #4**: Design target directory structure
- Based on research, finalize exact structure for each package
- Document where each file should be in repo and where it deploys

**TODO #5-18**: Systematic migration with feature flags
- Implement feature flag system
- Migrate each package correctly
- Test with flags enabled/disabled

## Success Criteria

Migration complete when:
1. ✓ No nested `dot-config/` directories inside packages
2. ✓ No duplicate files
3. ✓ Each package has its own directory with all its files
4. ✓ Package-specific zsh integrations stay with their packages
5. ✓ Feature flags in `.chezmoidata.yaml` control all packages
6. ✓ `.chezmoiignore` properly excludes disabled packages
7. ✓ All 150-200 unique config files correctly migrated
8. ✓ `chezmoi apply` deploys correct files to correct locations
9. ✓ Can enable/disable packages by changing one flag
10. ✓ Testing passes on Windows, WSL, and other targets

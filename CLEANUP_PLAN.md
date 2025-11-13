# Cleanup Plan - TODO #2

**Date**: 2025-01-14  
**Purpose**: Remove incorrectly structured files from Phase 3, keep correct Phase 1 & 2 files

## Files to KEEP (Phases 1 & 2 - Correct Structure)

### Root Configuration Files
- `.chezmoi.toml.tmpl` ✓
- `.chezmoidata.yaml` ✓ (will update with feature flags)
- `.chezmoiignore` ✓ (will update with package logic)
- `bootstrap.ps1` ✓
- `setup.sh` ✓
- `dot_editorconfig` ✓
- `dot_wslconfig.tmpl` ✓

### Scripts & Templates
- `.chezmoiscripts/` directory ✓
  - `run_once_install_packages_unix.sh.tmpl` ✓
  - `run_once_install_packages_windows.ps1.tmpl` ✓
- `.chezmoitemplates/` directory ✓
  - `detect-package-manager` ✓
  - `platform-conditional` ✓
  - `xdg-paths` ✓

### Documentation (Keep for reference, will update)
- `README.md` ✓
- `MIGRATION_SUMMARY.md` ✓
- `CHEZMOI_MIGRATION_GUIDE.md` ✓
- `STOW_VS_CHEZMOI.md` ✓
- `TESTING.md` ✓
- `PHASE_2_PROGRESS.md` ✓
- `PHASE_3_PROGRESS.md` ⚠ (outdated, will update)
- `WARP.md` ✓
- `AUDIT_REPORT.md` ✓ (just created)
- `CROSS_DIRECTORY_RESEARCH.md` ✓ (just created)

### Core Configs (Phase 2 - Correct)
- `dot_config/git/` ✓
  - `config.tmpl` ✓
  - `ignore` ✓
- `dot_config/nvim/` ✓ (entire directory)
  - `init.lua` ✓
  - `lazy-lock.json` ✓
  - `lua/` subdirectories ✓
  - `dot_stylua.toml` ✓
- `dot_config/wezterm/` ✓
  - `wezterm.lua.tmpl` ✓
  - `keymaps.lua` ✓
  - `tabs.lua` ✓
  - `utilities.lua` ✓
- `dot_config/starship/` ✓
  - `starship.toml` ✓
- `dot_config/mise/` ✓
  - `config.toml.tmpl` ✓
- `dot_config/bat/` ✓
  - `config` ✓

### PowerShell (Phase 2 - Correct)
- `Documents/PowerShell/` ✓
  - `Microsoft.PowerShell_profile.ps1.tmpl` ✓
  - `Modules/EzaProfile/EzaProfile.psm1.tmpl` ✓

### Scripts (Phase 2 - Correct)
- `dot_local/bin/` ✓
  - `executable_relink_gcc.sh` ✓
  - `executable_ssh-key-manager.sh` ✓

### Basic Tool Configs Added in Phase 3 (Simple, Correct)
- `dot_config/ripgrep/ripgreprc` ✓ (if standalone file)
- `dot_config/direnv/direnv.toml` ✓ (if standalone file)
- `dot_config/wget/wgetrc` ✓ (if standalone file)
- `dot_config/eza/flags.txt` ✓ (if standalone file)
- `dot_config/fd/ignore` ✓ (if standalone file)
- `dot_config/fzf/fzf.bash` ✓ (if standalone file)

### VS Code (Phase 3 - Correct)
- `AppData/Roaming/Code/User/` ✓
  - `settings.json` ✓
  - `keybindings.json` ✓

### Basic Zsh (Phase 2 - Core Only, No Package Scripts)
- `dot_config/zsh/` - **NEEDS CLEANUP**
  - Keep core files:
    - `dot-zshrc` ✓ (or template version)
    - `dot-zshenv` ✓ (or template version)
    - `dot-zprofile` ✓
    - `dot-zsh_plugins.txt` ✓
    - `dot-zstyles` ✓
    - `dot-zfunctions/` ✓
    - `colors/` ✓
  - `dot-zshrc.d/` - **KEEP CORE ONLY**:
    - `00-helpers.zsh` ✓
    - `01-mise.zsh` ✓
    - `10-1password-ssh-agent.zsh` ✓
    - `10-dirs.zsh` ✓
    - `20-paths.zsh` ✓
    - `30-misc.zsh` ✓
    - `alias-finder.zsh` ✓
    - `aliases.ndn.zsh` ✓
    - `aliases.zsh` ✓
    - `common-aliases.zsh` ✓
    - `completion.zsh.off` ✓
    - `functions.zsh` ✓
    - `git.zsh` ✓
    - `gnu-utils.zsh` ✓
    - `history-substring-search.zsh` ✓
    - `history.zsh` ✓
    - `ssh-agent.zsh.disabled` ✓
    - `ssh-agent.zsh.disabled2` ✓
  - **REMOVE PACKAGE SCRIPTS** (will re-add correctly later):
    - ❌ `70-golang.zsh` (was in central zsh, should come from golang package)
    - ❌ `bun.zsh` (package-specific)
    - ❌ `npm.zsh` (package-specific)
    - ❌ `thefuck.zsh` (package-specific)

## Files/Directories to REMOVE (Phase 3 - Incorrect Structures)

### Entire Package Directories with Issues
All these were incorrectly structured in the bulk copy:

❌ `dot_config/arduino/` - entire directory (will re-add correctly)
❌ `dot_config/asdf/` - entire directory (nested dot-config issue)
❌ `dot_config/bundle/` - entire directory
❌ `dot_config/cargo/` - entire directory
❌ `dot_config/cpan/` - entire directory
❌ `dot_config/glow/` - entire directory (nested structure)
❌ `dot_config/go/` - entire directory (only has env file, incomplete)
❌ `dot_config/homebrew/` - entire directory (nested dot-config)
❌ `dot_config/lua/` - entire directory
❌ `dot_config/mypy/` - entire directory
❌ `dot_config/node/` - entire directory
❌ `dot_config/npm/` - entire directory (nested dot-config)
❌ `dot_config/nvm/` - entire directory
❌ `dot_config/perl/` - entire directory
❌ `dot_config/php/` - entire directory
❌ `dot_config/pip/` - entire directory
❌ `dot_config/pytest/` - entire directory
❌ `dot_config/python/` - entire directory
❌ `dot_config/ruby/` - entire directory
❌ `dot_config/ruff/` - entire directory
❌ `dot_config/rust/` - entire directory (incomplete, only has completions)
❌ `dot_config/sqlite3/` - entire directory (nested dot-config)
❌ `dot_config/ssh/` - entire directory (wrong location, should be dot_ssh)
❌ `dot_config/thefuck/` - entire directory (nested dot-config)
❌ `dot_config/tinted-theming/` - entire directory (nested structure)
❌ `dot_config/tmux/` - entire directory
❌ `dot_config/utilities/` - entire directory (wrong location)
❌ `dot_config/vagrant/` - entire directory
❌ `dot_config/vim/` - entire directory (nested dot-config)
❌ `dot_config/vivid/` - entire directory
❌ `dot_config/warp/` - entire directory

### Root-Level Files to Remove
❌ `dot-zshenv` (duplicate, keep the one in dot_config/zsh/)
❌ `dot_zshenv.tmpl` (duplicate, keep the one in dot_config/zsh/)
❌ `dot_zshrc.tmpl` (duplicate, keep the one in dot_config/zsh/)
❌ `bootstrap.ps1.example` (if exists)
❌ `bootstrap.Tests.ps1` (if exists)

## Cleanup Strategy

### Phase 1: Backup Current State
```powershell
git tag pre-cleanup-phase3
```

### Phase 2: Remove Package Directories
Remove all incorrectly structured package directories from `dot_config/`:
```powershell
# List to remove
$packagesToRemove = @(
    "arduino", "asdf", "bundle", "cargo", "cpan", "glow", "go",
    "homebrew", "lua", "mypy", "node", "npm", "nvm", "perl", "php",
    "pip", "pytest", "python", "ruby", "ruff", "rust", "sqlite3",
    "ssh", "thefuck", "tinted-theming", "tmux", "utilities", "vagrant",
    "vim", "vivid", "warp"
)

foreach ($pkg in $packagesToRemove) {
    if (Test-Path "dot_config/$pkg") {
        git rm -r "dot_config/$pkg"
    }
}
```

### Phase 3: Clean Up Zsh Directory
Remove package-specific scripts from `dot_config/zsh/dot-zshrc.d/`:
```powershell
$zshPackageScripts = @(
    "bun.zsh", "npm.zsh", "thefuck.zsh", "70-golang.zsh"
)

foreach ($script in $zshPackageScripts) {
    if (Test-Path "dot_config/zsh/dot-zshrc.d/$script") {
        git rm "dot_config/zsh/dot-zshrc.d/$script"
    }
}
```

### Phase 4: Remove Duplicate Root Files
```powershell
$duplicates = @(
    "dot-zshenv", "dot_zshenv.tmpl", "dot_zshrc.tmpl",
    "bootstrap.ps1.example", "bootstrap.Tests.ps1"
)

foreach ($file in $duplicates) {
    if (Test-Path $file) {
        git rm $file
    }
}
```

### Phase 5: Commit Cleanup
```powershell
git commit -m "cleanup: remove Phase 3 incorrectly structured files

- Remove all package directories with nested dot-config issues
- Remove package-specific zsh scripts from core zsh (will re-add with proper structure)
- Remove duplicate root-level files
- Keep all Phase 1 & 2 correct files
- Ready for systematic package migration with feature flags"
```

## Post-Cleanup State

After cleanup, we should have:
- **~50 files**: Core infrastructure, Phase 1 & 2 configs
- Clean `dot_config/` with only: git, nvim, wezterm, starship, mise, bat, zsh (core only)
- Clean slate ready for systematic package migration
- All incorrectly structured packages removed
- Feature flag system ready to implement

## Verification

After cleanup:
1. Run `chezmoi managed` to see what files remain
2. Run `chezmoi diff` to verify only correct core files would deploy
3. Count files: should be ~50 managed files
4. Check `dot_config/zsh/dot-zshrc.d/` has only core scripts
5. Verify no nested `dot-config/` directories exist

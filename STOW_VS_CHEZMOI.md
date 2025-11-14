# GNU Stow vs Chezmoi: Migration Comparison

## Quick Reference

| Aspect | GNU Stow (Current) | Chezmoi (Target) |
|--------|-------------------|------------------|
| **Philosophy** | Symlink farm manager | Template-based dotfile manager |
| **Approach** | Physical symlinks | Managed copies with templates |
| **Cross-platform** | Manual per-platform handling | Built-in platform detection |
| **Templates** | None (manual scripting) | Native Go templates |
| **Secrets** | Manual management | Built-in (1Password, etc.) |
| **Installation** | External bootstrap scripts | Self-contained with run_once scripts |
| **State tracking** | Git + filesystem | Git + internal state |
| **Conflict handling** | Manual | Interactive merge tools |

---

## File Structure Comparison

### Stow Structure (Current)
```
dotfiles/
├── .stowrc                        # Stow configuration
├── git/
│   └── dot-config/git/config      # → ~/.config/git/config
├── nvim/
│   └── dot-config/nvim/init.lua   # → ~/.config/nvim/init.lua
├── windows/
│   ├── bootstrap.ps1              # Manual bootstrap
│   └── powershell/profile.ps1     # Windows-only
└── wsl/
    └── setup.sh                   # WSL-only
```

**Stow command:**
```bash
stow git nvim  # Creates symlinks
```

### Chezmoi Structure (Target)
```
.local/share/chezmoi/
├── .chezmoi.toml.tmpl             # Config (can be templated)
├── .chezmoidata.yaml              # Template variables
├── .chezmoiignore                 # Platform-specific exclusions
├── dot_config/
│   ├── git/config.tmpl            # Template with platform conditionals
│   └── nvim/init.lua              # Static file (no .tmpl needed)
├── Documents/PowerShell/
│   └── profile.ps1.tmpl           # Windows-only (via .chezmoiignore)
└── .chezmoiscripts/
    └── run_once_*.sh.tmpl         # Auto-run installation scripts
```

**Chezmoi command:**
```bash
chezmoi apply  # Renders templates + copies files
```

---

## Workflow Comparison

### Making Changes

#### Stow Workflow
```bash
# 1. Edit file directly (it's symlinked)
vim ~/.config/nvim/init.lua

# 2. File in dotfiles repo is already updated (symlink)
cd ~/dotfiles
git add nvim/dot-config/nvim/init.lua
git commit -m "Update neovim config"
git push
```

**Pros:** Direct editing, immediate effect  
**Cons:** Accidental changes, no validation, manual per-platform handling

#### Chezmoi Workflow
```bash
# 1. Edit via chezmoi (validates and tracks)
chezmoi edit ~/.config/nvim/init.lua

# 2. Preview changes
chezmoi diff

# 3. Apply changes
chezmoi apply ~/.config/nvim/init.lua

# 4. Commit to repo
chezmoi cd
git add .
git commit -m "Update neovim config"
git push
```

**Pros:** Validation, diff preview, template support, safer  
**Cons:** Extra step (edit → apply)

---

## Platform Handling

### Stow Approach (Current)

**Git config example:**
```gitconfig
# git/dot-config/git/config
[user]
    name = Randall
    email = user@example.com

[includeIf "gitdir/i:C:/"]
    path = ~/.config/git/windows.gitconfig
```

**Separate Windows file:**
```gitconfig
# windows/dot-config/git/windows.gitconfig
[core]
    autocrlf = input
    symlinks = true
```

**Issue:** Must maintain multiple files + manual includeIf logic

### Chezmoi Approach (Target)

**Single templated file:**
```gitconfig
# dot_config/git/config.tmpl
[user]
    name = Randall
    email = {{ .email }}

{{- if eq .chezmoi.os "windows" }}
[core]
    autocrlf = input
    symlinks = true
    editor = nvim.exe
{{- else }}
[core]
    editor = nvim
{{- end }}
```

**Benefit:** Single source of truth, automatic platform detection

---

## Package Management

### Stow Approach

**Separate bootstrap scripts:**
```powershell
# windows/bootstrap.ps1
# Manually parses windows/packages/scoop.json
# Manually installs each package
foreach ($pkg in $packages) {
    scoop install $pkg
}
```

**Issue:** Bootstrap logic separate from dotfiles

### Chezmoi Approach

**Integrated installation:**
```bash
# .chezmoiscripts/run_once_install_packages_windows.ps1.tmpl
{{- if eq .chezmoi.os "windows" }}
# Script runs automatically on first `chezmoi apply`
$packages = Get-Content "$env:XDG_CONFIG_HOME\scoop\scoop.json" | ConvertFrom-Json
foreach ($pkg in $packages.apps) {
    if (-not (scoop list $pkg)) {
        scoop install $pkg
    }
}
{{- end }}
```

**Benefit:** Self-contained, runs automatically, idempotent

---

## Bootstrap Comparison

### Stow Bootstrap (Current)

**Windows:**
```powershell
# 1. Manual git clone
git clone https://github.com/Randallsm83/dotfiles-redux.git ~/.config/dotfiles

# 2. Manual stow install (requires stow)
# (Stow not in winget/scoop by default on Windows)

# 3. Run bootstrap
cd ~/.config/dotfiles/windows
.\bootstrap.ps1  # Installs packages + creates symlinks

# 4. Manually source shell config
. $PROFILE
```

**WSL/Linux:**
```bash
# 1. Clone repo
git clone https://github.com/Randallsm83/dotfiles-redux.git ~/.config/dotfiles

# 2. Run setup script (installs stow, brew, mise)
cd ~/.config/dotfiles/wsl
./setup.sh

# 3. Manually stow configs
cd ~/.config/dotfiles
stow git nvim zsh starship wezterm bat mise
```

**Total steps:** 4-6 manual steps

### Chezmoi Bootstrap (Target)

**Windows - One Command:**
```powershell
iwr -useb https://raw.githubusercontent.com/USER/chezmoi-dotfiles/main/bootstrap.ps1 | iex
```

**Unix - One Command:**
```bash
curl -fsSL https://raw.githubusercontent.com/USER/chezmoi-dotfiles/main/setup.sh | bash
```

**What it does automatically:**
1. ✅ Installs chezmoi (scoop/winget/mise)
2. ✅ Clones repository
3. ✅ Applies all configs (with templates)
4. ✅ Runs installation scripts (packages, tools)
5. ✅ Configures environment
6. ✅ Ready to work

**Total steps:** 1 command

---

## Secrets Management

### Stow Approach
- Manual: Store secrets in separate encrypted file
- Or: Use environment variables
- Or: Prompt during bootstrap
- **Con:** No built-in support

### Chezmoi Approach
- Built-in 1Password integration
- Age encryption support
- Keyring integration
- Template secrets from secure sources

**Example:**
```gitconfig
# dot_config/git/config.tmpl
[user]
    email = {{ onepasswordRead "op://Personal/GitHub/email" }}
    signingkey = {{ onepasswordRead "op://Personal/GitHub/gpg_key" }}
```

---

## Migration Benefits

### What You Gain

1. **One-command provisioning** - Entire setup in one command
2. **Platform detection** - Automatic Windows/Linux/macOS handling
3. **Template power** - Conditional configs, variables, includes
4. **Secrets management** - Secure credential handling
5. **State tracking** - Know what's applied, what's changed
6. **Diff support** - Preview changes before applying
7. **Self-documenting** - Config structure shows platform dependencies
8. **Idempotency** - Run scripts safely multiple times
9. **Community** - Active project with excellent docs
10. **Future-proof** - Modern tool still under active development

### What You Keep

- ✅ Git-based versioning
- ✅ Cross-platform support
- ✅ XDG Base Directory compliance
- ✅ Package management preferences (scoop/mise)
- ✅ All existing configurations
- ✅ Same workflow goals (rapid provisioning)

### Trade-offs

- **Learning curve** - New templating syntax
- **Extra step for edits** - `chezmoi edit` instead of direct vim
- **File copies** - No symlinks (but more portable)
- **New concepts** - Templates, state, scripts

---

## Decision Matrix

| Use Case | Stow | Chezmoi |
|----------|------|---------|
| Simple single-platform dotfiles | ✅ Good | ⚠️ Overkill |
| Cross-platform dotfiles | ⚠️ Manual | ✅ Excellent |
| Platform-specific configs | ⚠️ Multiple files | ✅ Templates |
| Rapid VM provisioning | ⚠️ Multi-step | ✅ One-command |
| Secrets management | ❌ Manual | ✅ Built-in |
| Team/shared dotfiles | ⚠️ Manual docs | ✅ Self-contained |
| Learning curve | ✅ Simple | ⚠️ Moderate |

---

## Migration Effort Estimate

| Task | Estimated Time |
|------|----------------|
| Initial setup (install, init) | 30 minutes |
| Migrate core configs (5-10 files) | 2-3 hours |
| Create bootstrap scripts | 2-3 hours |
| Migrate all configs (40+) | 4-8 hours |
| Test on Windows | 1-2 hours |
| Test on WSL/Linux | 1-2 hours |
| Documentation | 1-2 hours |
| **Total** | **12-20 hours** |

**Recommendation:** Spread over 1-2 weeks, test incrementally

---

## Conclusion

**Your use case** (rapid VM provisioning, cross-platform, 40+ configs) is **ideal for chezmoi**.

The migration effort (~12-20 hours) pays off with:
- ⏱️ Time saved on future machine setups (hours → minutes)
- 🔧 Easier maintenance of platform-specific configs
- 🔒 Better secrets handling
- 🎯 Modern tooling with active community

**Verdict:** Migration recommended ✅

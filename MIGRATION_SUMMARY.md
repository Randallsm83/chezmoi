# Chezmoi Migration Summary

## 📋 Overview

You're migrating from **GNU Stow** to **chezmoi** for modern, template-driven dotfile management that enables rapid VM/machine provisioning.

**Files created on your Desktop:**
- ✅ `CHEZMOI_MIGRATION_GUIDE.md` - Comprehensive migration guide
- ✅ `STOW_VS_CHEZMOI.md` - Detailed comparison chart
- ✅ `bootstrap.ps1.example` - Example Windows bootstrap script
- ✅ `MIGRATION_SUMMARY.md` - This file

**In Warp:**
- ✅ 12-step TODO list created for tracking progress

---

## 🎯 Goals Achieved

Your requirements:
- ✅ Better templating for cross-platform management
- ✅ Modern, cleaner dotfile approach
- ✅ Fresh start with new repository
- ✅ Automated chezmoi installation in setup process
- ✅ One-command setup for rapid VM provisioning

---

## 🚀 Quick Start

### Step 1: Install Chezmoi (for development/testing)

```powershell
# Windows - via scoop (recommended)
scoop install chezmoi

# Alternative: via winget
winget install twpayne.chezmoi
```

### Step 2: Create Development Directory

```powershell
# Don't use the default location yet - test in a dev directory first
mkdir C:\Users\Randall\chezmoi-dev
cd C:\Users\Randall\chezmoi-dev

# Initialize chezmoi
chezmoi init --working-tree .

# Initialize git
git init
```

### Step 3: Follow the TODO List

Work through the 12-step TODO list in Warp:
1. Create new chezmoi repository structure
2. Create platform-specific bootstrap scripts (with chezmoi auto-install)
3. Migrate core cross-platform configs
4. Create Windows-specific configs
5. Create Unix-specific configs
6. Migrate package management
7. Implement secrets management
8. Create documentation
9. Set up chezmoi configuration
10. Migrate remaining configs
11. Test on all platforms
12. Finalize and publish

---

## 📂 Repository Structure (Target)

```
.local/share/chezmoi/  (or your dev directory initially)
├── .chezmoi.toml.tmpl              # Chezmoi config
├── .chezmoidata.yaml               # Template variables (platform detection)
├── .chezmoiignore                  # Platform-specific file exclusions
├── .chezmoitemplates/              # Reusable template snippets
│
├── dot_config/                     # Cross-platform configs
│   ├── git/config.tmpl             # Git with platform conditionals
│   ├── nvim/                       # Neovim configs
│   ├── wezterm/                    # WezTerm configs
│   ├── starship/starship.toml      # Starship prompt
│   ├── mise/config.toml.tmpl       # Mise with templates
│   ├── bat/config                  # Bat (better cat)
│   └── scoop/scoop.json.tmpl       # Scoop packages (Windows)
│
├── Documents/PowerShell/           # Windows PowerShell
│   └── Microsoft.PowerShell_profile.ps1.tmpl
│
├── dot_zshrc.tmpl                  # Unix zsh config
├── dot_zshenv.tmpl                 # Unix environment
├── dot_wslconfig.tmpl              # WSL config (Windows)
│
├── .chezmoiscripts/                # Auto-run scripts
│   ├── run_once_before_00_install_chezmoi.ps1.tmpl  # Windows setup
│   ├── run_once_before_00_install_chezmoi.sh.tmpl   # Unix setup
│   ├── run_once_install_packages_windows.ps1.tmpl   # Windows packages
│   └── run_once_install_packages_unix.sh.tmpl       # Unix packages
│
├── bootstrap.ps1                   # Windows entry point (in repo root)
├── setup.sh                        # Unix entry point (in repo root)
└── README.md                       # Documentation
```

---

## 🔑 Key Chezmoi Concepts

### File Naming Conventions

| Chezmoi Source | Target Location | Notes |
|----------------|-----------------|-------|
| `dot_gitconfig` | `~/.gitconfig` | Dotfile (prefix `dot_`) |
| `dot_gitconfig.tmpl` | `~/.gitconfig` | Templated dotfile |
| `dot_config/nvim/init.lua` | `~/.config/nvim/init.lua` | Nested dotfile |
| `Documents/PowerShell/profile.ps1` | `~/Documents/PowerShell/profile.ps1` | Non-dotfile |
| `executable_dot_local/bin/script.sh` | `~/.local/bin/script.sh` | Executable |

### Template Syntax (Go templates)

**Platform detection:**
```go
{{- if eq .chezmoi.os "windows" }}
# Windows-specific content
{{- else if eq .chezmoi.os "darwin" }}
# macOS-specific content
{{- else }}
# Linux-specific content
{{- end }}
```

**WSL detection:**
```go
{{- if eq .chezmoi.os "linux" }}
{{-   if (.chezmoi.kernel.osrelease | lower | contains "microsoft") }}
# WSL-specific
{{-   else }}
# Native Linux
{{-   end }}
{{- end }}
```

**Variables:**
```go
{{ .email }}          # From .chezmoidata.yaml
{{ .chezmoi.os }}     # Built-in: windows/linux/darwin
{{ .chezmoi.arch }}   # Built-in: amd64/arm64/etc
```

---

## 🎬 End Goal: One-Command Setup

Once migration is complete, provisioning a fresh machine will be:

**Windows (PowerShell):**
```powershell
iwr -useb https://raw.githubusercontent.com/YOUR_USERNAME/chezmoi-dotfiles/main/bootstrap.ps1 | iex
```

**Unix (bash/zsh):**
```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/chezmoi-dotfiles/main/setup.sh | bash
```

This single command will:
1. ✅ Install chezmoi (scoop/winget/mise)
2. ✅ Clone your dotfiles repository
3. ✅ Apply all configurations (rendered from templates)
4. ✅ Install package managers (scoop/mise if missing)
5. ✅ Install all packages from lists
6. ✅ Configure environment variables
7. ✅ Set up shell integrations
8. ✅ **Ready to work in <10 minutes**

---

## 📊 Migration Phases

### Phase 1: Foundation (Days 1-2)
- Install chezmoi for testing
- Create dev directory and initialize
- Set up basic structure (.chezmoi.toml, .chezmoidata.yaml, .chezmoiignore)
- Create bootstrap scripts with chezmoi auto-install

### Phase 2: Core Configs (Days 3-5)
- Migrate essential cross-platform configs (git, neovim, wezterm, starship)
- Create Windows-specific configs (PowerShell, Windows Terminal)
- Create Unix-specific configs (zsh, shell integrations)
- Set up package management (scoop.json, mise config.toml)

### Phase 3: Advanced Features (Days 6-8)
- Implement secrets management (1Password integration)
- Create comprehensive documentation
- Migrate remaining 40+ config directories
- Set up chezmoi configuration and templates

### Phase 4: Testing & Finalization (Days 9-10)
- Test on Windows (current machine)
- Test on WSL Ubuntu
- Test on fresh VM (if available)
- Fix any issues found
- Create new GitHub repository
- Push and tag v1.0.0

**Estimated total time:** 12-20 hours over 1-2 weeks

---

## ⚙️ Essential Chezmoi Commands

```bash
# Check what would be applied (safe dry-run)
chezmoi apply --dry-run --verbose

# See differences between current and managed state
chezmoi diff

# Apply all changes
chezmoi apply

# Apply specific file
chezmoi apply ~/.gitconfig

# Edit a file in chezmoi
chezmoi edit ~/.gitconfig

# Edit and immediately apply
chezmoi edit --apply ~/.gitconfig

# Navigate to chezmoi source directory
chezmoi cd

# Add existing file to chezmoi
chezmoi add ~/.gitconfig

# Re-run scripts (useful for testing)
chezmoi state delete-bucket --bucket=scriptState

# Update chezmoi from repository
chezmoi update
```

---

## 🔄 Development Workflow

### During Migration

1. **Edit in dev directory:** `C:\Users\Randall\chezmoi-dev\`
2. **Test changes:** `chezmoi apply --dry-run --verbose`
3. **Apply changes:** `chezmoi apply`
4. **Commit:** `git add . && git commit -m "Add X config"`
5. **Repeat** for each config/feature

### After Migration (Normal Use)

1. **Edit config:** `chezmoi edit ~/.config/nvim/init.lua`
2. **Preview:** `chezmoi diff`
3. **Apply:** `chezmoi apply`
4. **Commit:** `chezmoi cd && git add . && git commit -m "Update nvim" && git push`

Or for quick changes:
```bash
chezmoi edit --apply ~/.gitconfig
chezmoi cd && git add . && git commit -m "Update git" && git push
```

---

## 🎁 Benefits Summary

**Before (Stow):**
- 4-6 manual steps to set up new machine
- Separate files for platform-specific configs
- Manual secret management
- Bootstrap scripts separate from configs
- ~30-60 minutes to provision

**After (Chezmoi):**
- 1 command to set up new machine
- Single templated files with conditionals
- Built-in secret management
- Self-contained with integrated scripts
- ~5-10 minutes to provision

**ROI:** Migration effort (~12-20 hours) pays off after provisioning 2-3 new machines

---

## 📚 Resources

**Official Documentation:**
- Main site: https://www.chezmoi.io/
- User guide: https://www.chezmoi.io/user-guide/
- Template guide: https://www.chezmoi.io/user-guide/templating/
- Command reference: https://www.chezmoi.io/reference/commands/

**Example Repos (for inspiration):**
- Chezmoi author: https://github.com/twpayne/dotfiles
- Community examples: https://github.com/topics/chezmoi-dotfiles

**Your Existing Stow Repo (reference):**
- Current dotfiles: `C:\Users\Randall\.config\dotfiles`
- GitHub: `git@github.com:Randallsm83/dotfiles-redux.git`
- **Keep this intact during migration** (parallel operation)

---

## ✅ Next Steps

1. **Read the migration guide:** `CHEZMOI_MIGRATION_GUIDE.md`
2. **Review the comparison:** `STOW_VS_CHEZMOI.md`
3. **Install chezmoi:** `scoop install chezmoi`
4. **Start with TODO #1** in Warp: Create new chezmoi repository structure
5. **Work incrementally:** Test each change before moving forward
6. **Keep existing dotfiles:** Don't delete Stow setup until fully validated
7. **Test thoroughly:** Verify on Windows, then WSL, before finalizing

---

## 🆘 Getting Help

- **Chezmoi Discord:** https://discord.gg/7bTxvhd
- **GitHub Discussions:** https://github.com/twpayne/chezmoi/discussions
- **GitHub Issues:** https://github.com/twpayne/chezmoi/issues

---

**Ready to begin? Start by reviewing the migration guide and comparison, then proceed with TODO #1 in Warp!**

Good luck with your migration! 🚀

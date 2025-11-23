# WARP.md

This file provides guidance to Warp AI Agent Mode when working with this dotfiles repository.

## ⚠️ CRITICAL: Read This First

**Before making ANY changes to this repository, you MUST read [CHEZMOI-GUIDE.md](./CHEZMOI-GUIDE.md).**

This guide documents chezmoi best practices from the official documentation. It exists because previous implementations made assumptions instead of following the docs, creating technical debt.

The guide covers:
- File management (especially externally-modified files like VS Code settings)
- Password manager integration (1Password hooks)
- Declarative package management
- Templates and machine-to-machine differences
- Scripts and hooks
- Implementation checklist for required fixes

**Always reference CHEZMOI-GUIDE.md when:**
- Adding new managed files
- Creating templates
- Setting up scripts
- Integrating password managers
- Managing packages

---

## Repository Overview

**Type:** Production chezmoi dotfiles repository  
**Purpose:** One-command provisioning of identical development environments  
**Platforms:** Windows 11, WSL2 (Ubuntu, Arch), Linux, macOS  
**Version:** v1.0.0  
**Architecture:** Template-based dotfile management using chezmoi v2.67.0

### Key Features
- 155+ managed configurations
- Feature flag system for optional packages
- Cross-platform Go templating
- Automated bootstrap provisioning
- XDG Base Directory compliance (all platforms)
- 1Password SSH agent integration

---

## Essential Chezmoi Commands

### Daily Workflow

```powershell
# Safe: Preview changes without applying
chezmoi apply --dry-run --verbose

# Show differences between managed and current state
chezmoi diff

# Apply all changes
chezmoi apply

# Apply with force (skip confirmation prompts)
chezmoi apply --force

# Apply specific file
chezmoi apply ~/.gitconfig

# Check what files have changed
chezmoi status
```

### Managing Files

```powershell
# Add existing file to chezmoi
chezmoi add ~/.gitconfig

# Add as template (for platform-specific content)
chezmoi add --template ~/.config/git/config

# Edit a managed file (opens in editor)
chezmoi edit ~/.gitconfig

# Edit and immediately apply
chezmoi edit --apply ~/.gitconfig

# Remove file from chezmoi management
chezmoi forget ~/.gitconfig

# Re-add externally modified file
chezmoi re-add ~/.vscode/settings.json
```

### Repository Operations

```powershell
# Navigate to chezmoi source directory
chezmoi cd

# Return to previous directory
cd -

# List all managed files
chezmoi managed

# View template variables and configuration
chezmoi data

# Update from remote repository
chezmoi update

# Re-run all scripts (testing)
chezmoi state delete-bucket --bucket=scriptState
chezmoi apply
```

---

## File Naming Conventions

### Chezmoi Prefixes and Attributes

| Source File | Target | Purpose |
|-------------|--------|---------|
| `dot_config/` | `~/.config/` | Directory: `_` → `.` |
| `dot_gitconfig` | `~/.gitconfig` | File: `_` → `.` |
| `dot_gitconfig.tmpl` | `~/.gitconfig` | Templated file |
| `private_dot_ssh/` | `~/.ssh/` (600) | Private directory |
| `executable_script.sh` | `~/script.sh` (755) | Executable file |
| `symlink_file.tmpl` | `~/file` → target | Symlink (contains path) |
| `modify_file.tmpl` | `~/file` | Script output → file |

**Reference:** https://www.chezmoi.io/reference/source-state-attributes/

### Template Syntax Examples

```go
{{- if eq .chezmoi.os "windows" }}
# Windows-specific content
{{- else if eq .chezmoi.os "darwin" }}
# macOS-specific content
{{- else }}
# Linux-specific content
{{- end }}

{{- if .is_wsl }}
# WSL-specific content
{{- end }}

# Use variables from .chezmoi.toml.tmpl
{{ .chezmoi.homeDir }}
{{ .email }}
{{ .github_username }}
{{ .theme }}
```

---

## Configuration Hierarchy

1. **`.chezmoi.toml.tmpl`** - Main config with platform detection, generated on each run
2. **`.chezmoidata.yaml`** - Static data (themes, fonts, package lists, feature flags)
3. **`.chezmoi.local.toml`** - Machine-specific overrides (NOT committed to git)

### Platform Detection

Available variables in templates (from `.chezmoi.toml.tmpl`):
- `.is_windows` - Windows 11
- `.is_darwin` - macOS
- `.is_linux` - Linux (native)
- `.is_wsl` - Windows Subsystem for Linux
- `.is_remote` - SSH session or remote environment
- `.is_personal` - Personal machine
- `.is_work` - Work machine
- `.has_sudo` - Sudo/admin privileges available

---

## Package Management Strategy

### Windows
- **scoop**: CLI tools (git, neovim, starship, ripgrep, bat, fd, fzf, eza, vivid, btop, delta, gh, lazygit, zoxide)
- **winget**: GUI apps (Git.Git w/GCM, wez.wezterm, Microsoft.PowerShell, WindowsTerminal, VS Code, 7zip)
- **mise**: Language runtimes ONLY (node, python, ruby, go, rust, lua, bun, uv, yarn, direnv, usage, zig)

### Linux/WSL/macOS
- **mise**: Everything (CLI tools via cargo + language runtimes)
- **homebrew**: Bootstrap only (stow installation), then unused
- **apt/dnf/pacman**: System bootstrap only (git, build-essential) when sudo available

---

## Feature Flag System

### How It Works

Feature flags in `.chezmoidata.yaml` control which configurations are deployed:

```yaml
package_features:
  rust: true      # Deploy rust configs
  python: true    # Deploy python configs
  arduino: false  # Skip arduino configs
```

Files are excluded via `.chezmoiignore` template logic:

```go
{{- if not .package_features.rust }}
.config/zsh/.zshrc.d/70-rust.zsh
.cache/zsh/completions/_rustc
{{- end }}
```

### Core Packages (Always Enabled)
git, nvim, wezterm, starship, mise, bat, direnv, eza, fzf, ripgrep, zsh (Unix), ssh, 1password, windows, wsl

### Optional Language Packages
- **Enabled by default**: rust, golang, python, ruby, lua, node
- **Disabled by default**: perl, php

### Optional Tool Packages
- **Enabled by default**: glow, tinted_theming, sqlite3, vivid, warp
- **Disabled by default**: arduino, thefuck, vim

### Deprecated Packages
- **asdf** - Replaced by mise
- **nvm** - Replaced by mise node management

---

## Bootstrap Scripts

### Windows

```powershell
iwr -useb https://raw.githubusercontent.com/Randallsm83/dotfiles/main/bootstrap.ps1 | iex
```

**What it does:**
1. Installs chezmoi (via scoop → winget fallback)
2. Installs scoop if missing
3. Sets XDG environment variables
4. Runs `chezmoi init --apply Randallsm83/dotfiles`
5. Applies all configurations
6. Installs package managers if missing
7. Ready in ~10 minutes

### Unix (Planned)

```bash
curl -fsSL https://raw.githubusercontent.com/Randallsm83/dotfiles/main/setup.sh | bash
```

---

## Theme Configuration

**Active Theme:** spaceduck  
**Available:** spaceduck, onedark, gruvbox-material, tokyonight, tokyonight-storm, dracula, kanagawa

### Theme Customization

Override in `.chezmoi.local.toml`:

```toml
[data]
    theme = "onedark"
    font = "JetBrainsMono"
```

### Theme Mappings

Themes are mapped to application-specific names in `.chezmoidata.yaml`:
- **Neovim**: Plugin colorscheme names
- **WezTerm**: Builtin colorscheme names
- **Starship**: Custom palette names in starship.toml
- **Vivid**: Theme names for LS_COLORS generation
- **Bat/Delta**: Custom .tmTheme files

---

## SSH & Authentication

### 1Password SSH Agent

**Windows:** Uses named pipe at `\\\\.\\pipe\\openssh-ssh-agent`  
**Unix:** Socket at `~/.1password/agent.sock`

Git SSH configured to use Windows native OpenSSH: `C:/Windows/System32/OpenSSH/ssh.exe`

### Configuration Files
- `dot_ssh/config.tmpl` - SSH client config
- `dot_config/git/config.tmpl` - Git config with conditional includes
- `dot_config/git/config.d/` - Platform-specific git configs

---

## XDG Base Directory Compliance

**All platforms** (including Windows) use XDG directories:

```
~/.config      # XDG_CONFIG_HOME
~/.local/share # XDG_DATA_HOME
~/.local/state # XDG_STATE_HOME
~/.cache       # XDG_CACHE_HOME
```

Bootstrap scripts set these as environment variables on Windows.

---

## Testing

### Pester Tests (Windows)

```powershell
# Install Pester
Install-Module -Name Pester -MinimumVersion 5.0.0 -Force

# Run all tests
Invoke-Pester -Path .\bootstrap.Tests.ps1

# Run with coverage
$config = New-PesterConfiguration
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = '.\bootstrap.ps1'
Invoke-Pester -Configuration $config
```

### Test Coverage
- Install-Chezmoi (scoop/winget fallback)
- Install-Scoop (execution policy handling)
- Initialize-Chezmoi (GitHub shorthand conversion)
- Set-EnvironmentVariables (XDG paths)

---

## Line Ending Requirements

**CRITICAL**: Files for Linux/WSL MUST use LF endings, NOT CRLF.

### LF Required
- All shell scripts (`*.sh`, `*.bash`)
- Zsh configuration files
- Unix-targeted `.tmpl` files in `.chezmoiscripts/`
- Any files read by Linux/WSL tools

### CRLF Acceptable
- PowerShell scripts (`*.ps1`)
- Windows-specific configs

### Checking/Converting

```powershell
# Check
$content = [System.IO.File]::ReadAllText("file")
if ($content -match "`r`n") { "CRLF" } else { "LF" }

# Convert CRLF → LF
$content = $content -replace "`r`n", "`n"
[System.IO.File]::WriteAllText("file", $content)
```

```bash
# WSL/Linux
sed -i 's/\r$//' file
```

---

## Important Warp Integration Notes

### Context Usage

Warp agents can access:
- **This notebook** (WARP.md) - Repository guidance
- **CHEZMOI-GUIDE.md** - Chezmoi best practices
- **Codebase index** - Git-tracked files (no code sent to servers)
- **Warp Drive** - Workflows, notebooks, prompts
- **Rules** - Persistent context about your preferences

### Rules for This Repository

The user's Rules include:
- Platform & environment details (Windows 11, WSL2, shells, terminals)
- Package management strategy (scoop/winget/mise on Windows, mise on Unix)
- XDG compliance requirements
- Theme preferences (spaceduck primary, onedark secondary)
- Font configuration (Hack primary, FiraCode fallback)
- SSH & auth setup (1Password SSH agent)

**Always respect these rules when suggesting changes.**

### Workflows

Warp Workflows for this repo are stored in `warp-workflows/`:
- `reset-arch-wsl.yaml` - Full Arch Linux WSL reset and bootstrap

Import via Warp Drive or Command Palette (`Cmd+P` / `Ctrl+P`).

---

## Common Operations

### Adding a New Config File

```powershell
# 1. Add to chezmoi
chezmoi add --template ~/.config/new-tool/config.yaml

# 2. Navigate to source
chezmoi cd

# 3. Edit template, add platform conditionals if needed
# 4. Apply and verify
chezmoi apply --dry-run
chezmoi apply
```

### Enabling a Package Feature

```powershell
# 1. Edit feature flags
chezmoi edit ~/.local/share/chezmoi/.chezmoidata.yaml

# 2. Set flag to true
package_features:
  arduino: true  # Was false

# 3. Apply changes
chezmoi apply

# 4. Verify
chezmoi managed | grep arduino
```

### Testing on Fresh Machine

```powershell
# 1. Backup current state
chezmoi archive > backup.tar.gz

# 2. Test bootstrap in VM/container
# Windows:
iwr -useb https://raw.githubusercontent.com/Randallsm83/dotfiles/main/bootstrap.ps1 | iex

# 3. Verify no errors during:
# - Hook execution
# - Template rendering
# - Package installation
# - Script execution
```

---

## Troubleshooting

### Templates Not Rendering
- Check syntax with `chezmoi execute-template`
- View data with `chezmoi data`
- Verify variables exist in `.chezmoi.toml.tmpl` or `.chezmoidata.yaml`

### Files Not Applying
- Check `.chezmoiignore` for exclusions
- Verify feature flags in `.chezmoidata.yaml`
- Run `chezmoi status` to see conflicts
- Check file permissions (private_, executable_)

### Scripts Not Running
- Check script name prefix (run_once_, run_onchange_, etc.)
- Verify script has correct line endings (LF for Unix)
- Check interpreter config in `.chezmoi.toml.tmpl`
- Clear script state: `chezmoi state delete-bucket --bucket=scriptState`

### Package Installation Issues
- Windows: Verify scoop/winget installed
- Unix: Verify mise installed
- Check package names in configs
- Review install script logs in `.chezmoiscripts/`

---

## References

- **Chezmoi Docs**: https://www.chezmoi.io/
- **Warp Docs**: https://docs.warp.dev/
- **Repository**: https://github.com/Randallsm83/dotfiles
- **CHEZMOI-GUIDE.md**: Best practices and implementation checklist
- **ARCHITECTURE.md**: Detailed technical architecture
- **SECRETS.md**: 1Password integration guide

---

## Maintenance Notes

### When Adding Features
1. Check official chezmoi docs first
2. Use templates for cross-platform compatibility
3. Use `run_onchange_` for declarative installation
4. Test on multiple platforms
5. Document in this guide
6. Update CHEZMOI-GUIDE.md if patterns change

### When Fixing Issues
1. Reference CHEZMOI-GUIDE.md for correct patterns
2. Check implementation checklist for known issues
3. Verify against official chezmoi documentation
4. Don't make assumptions - validate first

**Remember:** When you make assumptions instead of following the docs, you create technical debt. Always verify.

---

**Last Updated:** November 23, 2025  
**Maintained By:** Randall  
**Version:** 2.0.0

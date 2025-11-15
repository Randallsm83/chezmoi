# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Repository Overview

This is a **production chezmoi dotfiles repository** migrated from GNU Stow. Enables one-command provisioning of identical development environments across Windows, WSL2, Linux, and macOS.

**Current State:** v1.0.0 - Fully migrated with 155+ managed configurations, feature flag system, and production-ready bootstrap scripts.

**Architecture:** Template-based dotfile management using chezmoi v2.67.0 with automated bootstrap provisioning, feature flags for optional packages, and cross-platform Go templating.

## Essential Chezmoi Commands

### Development Workflow

```powershell
# Check what would be applied without making changes (safe)
chezmoi apply --dry-run --verbose

# See differences between current and managed state
chezmoi diff

# Apply all changes
chezmoi apply

# Apply specific file
chezmoi apply ~/.gitconfig

# Navigate to chezmoi source directory
chezmoi cd

# Return to previous directory
cd -
```

### Adding and Editing Files

```powershell
# Add existing file to chezmoi
chezmoi add ~/.gitconfig

# Add file as template (for platform-specific content)
chezmoi add --template ~/.config/git/config

# Edit a managed file
chezmoi edit ~/.gitconfig

# Edit and immediately apply
chezmoi edit --apply ~/.gitconfig
```

### Repository Management

```powershell
# Check repository status (show pending changes)
chezmoi status

# List all managed files
chezmoi managed

# View chezmoi configuration and template variables
chezmoi data

# Update from remote repository
chezmoi update

# Re-run scripts (useful for testing .chezmoiscripts)
chezmoi state delete-bucket --bucket=scriptState
chezmoi apply
```

## Testing with Pester

### Prerequisites

```powershell
# Install Pester 5.0.0 or later
Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -SkipPublisherCheck

# Verify installation
Get-Module -Name Pester -ListAvailable
```

### Running Tests

```powershell
# Run all tests
Invoke-Pester -Path .\bootstrap.Tests.ps1

# Run with detailed output
Invoke-Pester -Path .\bootstrap.Tests.ps1 -Output Detailed

# Run specific test suite (by function name)
Invoke-Pester -Path .\bootstrap.Tests.ps1 -FullNameFilter '*Install-Chezmoi*'
```

### Code Coverage

```powershell
# Generate code coverage report
$config = New-PesterConfiguration
$config.Run.Path = '.\bootstrap.Tests.ps1'
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = '.\bootstrap.ps1.example'
$config.CodeCoverage.OutputFormat = 'JaCoCo'
$config.CodeCoverage.OutputPath = '.\coverage.xml'

Invoke-Pester -Configuration $config
```

### Test Suite Organization

The test suite (`bootstrap.Tests.ps1`) covers:

- **Install-Chezmoi**: Detects existing installations, installs via scoop (preferred) or winget (fallback), handles missing package managers
- **Install-Scoop**: Detects existing installation, handles execution policy restrictions, installs from official URL
- **Initialize-Chezmoi**: Converts GitHub shorthand to URLs, handles branch parameters, uses `--apply` flag
- **Set-EnvironmentVariables**: Sets XDG paths (CONFIG_HOME, DATA_HOME, STATE_HOME, CACHE_HOME), persists at User scope
- **Test-CommandExists**: Helper function for detecting installed commands

**Mocking Strategy:** Tests use extensive mocking to isolate functions from external dependencies and avoid system modifications. Example:

```powershell
Mock Test-CommandExists { $true } -ParameterFilter { $Command -eq 'scoop' }
```

## Bootstrap Script Architecture

**File:** `bootstrap.ps1.example`

### Core Functions

#### Install-Chezmoi
- **Strategy:** Prefer scoop → fallback to winget → fail gracefully
- **Updates:** `$Script:Stats.ChezmoiInstalled`
- **Returns:** Boolean success/failure

#### Install-Scoop
- **Strategy:** Check existing → modify execution policy if restricted → install from `https://get.scoop.sh`
- **Updates:** `$Script:Stats.ScoopInstalled`
- **Returns:** Boolean success/failure

#### Initialize-Chezmoi
- **Strategy:** Convert GitHub shorthand (`user/repo`) to full URL → run `chezmoi init --apply --branch <branch> <url>`
- **Updates:** `$Script:Stats.ConfigsApplied`
- **Returns:** Boolean success/failure

#### Set-EnvironmentVariables
- **Strategy:** Set XDG paths using `$env:USERPROFILE` as base → persist at User scope → update current session
- **Variables:** XDG_CONFIG_HOME, XDG_DATA_HOME, XDG_STATE_HOME, XDG_CACHE_HOME
- **No return value**

### Statistics Tracking

The script maintains a `$Script:Stats` hashtable:

```powershell
@{
    StartTime = Get-Date
    ChezmoiInstalled = $false
    ScoopInstalled = $false
    PackagesInstalled = 0
    ConfigsApplied = $false
}
```

### Error Handling Pattern

Functions use try-catch blocks with detailed error messages via `Write-Status`:

```powershell
try {
    # Operation
    Write-Status "Success message" -Type Success
    return $true
} catch {
    Write-Status "Failed: $_" -Type Error
    return $false
}
```

## Chezmoi Migration Architecture

### File Naming Conventions

**Chezmoi Dotfile Naming Convention (Standard):**

| Source File (in chezmoi) | Target Location | Notes |
|--------------------------|-----------------|-------|
| `dot_config/` | `~/.config/` | Directories: underscore → dot |
| `dot_local/` | `~/.local/` | Directories: underscore → dot |
| `dot_config/zsh/dot_zshrc` | `~/.config/zsh/.zshrc` | Files: underscore → dot |
| `dot_config/zsh/dot_zprofile` | `~/.config/zsh/.zprofile` | Files: underscore → dot |
| `dot_config/zsh/dot_zshrc.d/` | `~/.config/zsh/.zshrc.d/` | Nested dotfile directories |
| `dot_gitconfig.tmpl` | `~/.gitconfig` | Templated dotfiles |
| `Documents/PowerShell/profile.ps1.tmpl` | `~/Documents/PowerShell/profile.ps1` | Windows non-dotfile |
| `executable_script.sh` | `~/script.sh` (executable) | Sets executable bit |

**Convention**: Uses chezmoi's standard dotfile prefix:
- `dot_` → `.` (underscore converts to dot for both directories AND files)

### Template Syntax (Go Templates)

**Platform Detection:**

```go
{{- if eq .chezmoi.os "windows" }}
# Windows-specific content
{{- else if eq .chezmoi.os "darwin" }}
# macOS-specific content
{{- else }}
# Linux-specific content
{{- end }}
```

**WSL Detection:**

```go
{{- if eq .chezmoi.os "linux" }}
{{-   if (.chezmoi.kernel.osrelease | lower | contains "microsoft") }}
# WSL-specific
{{-   else }}
# Native Linux
{{-   end }}
{{- end }}
```

**Template Variables:**

Available via `.chezmoidata.yaml` or built-in:

```go
{{ .email }}              # Custom data variable
{{ .chezmoi.os }}         # windows/linux/darwin
{{ .chezmoi.arch }}       # amd64/arm64/etc
{{ .chezmoi.hostname }}   # Machine hostname
{{ .chezmoi.username }}   # Current user
```

### Auto-Run Scripts

Scripts in `.chezmoiscripts/` run automatically:

- `run_once_before_*.sh.tmpl` - Runs once before applying configs (Unix)
- `run_once_before_*.ps1.tmpl` - Runs once before applying configs (Windows)
- `run_once_install_*.sh.tmpl` - Runs once for package installation (Unix)
- `run_once_install_*.ps1.tmpl` - Runs once for package installation (Windows)

**Pattern:** Use `run_once_` prefix for idempotent operations that should only run once per machine.

### Platform-Specific File Inclusion

Use `.chezmoiignore` to exclude files by platform:

```
# Ignore Windows files on Unix
{{ if ne .chezmoi.os "windows" }}
Documents/
AppData/
.wslconfig
{{ end }}

# Ignore Unix files on Windows
{{ if eq .chezmoi.os "windows" }}
.zshrc
.zshenv
.bashrc
{{ end }}
```

## Project Structure

### Documentation Files

- **CHEZMOI_MIGRATION_GUIDE.md** - Comprehensive migration guide with workflow, concepts, and examples
- **MIGRATION_SUMMARY.md** - Quick reference with command cheatsheet and migration phases
- **STOW_VS_CHEZMOI.md** - Detailed comparison between GNU Stow and chezmoi approaches
- **TESTING.md** - Complete Pester testing guide with commands, coverage, and patterns

### Implementation Files

- **bootstrap.ps1.example** - Production bootstrap script (Windows entry point)
- **bootstrap.Tests.ps1** - Pester test suite with ~240 lines of comprehensive tests
- **setup.sh** *(planned)* - Unix bootstrap entry point (not yet implemented)

### Chezmoi Configuration Files

*(Not yet created - will be added during migration:)*

- `.chezmoi.toml.tmpl` - Chezmoi configuration (can be templated)
- `.chezmoidata.yaml` - Template variables and platform data
- `.chezmoiignore` - Platform-specific exclusions
- `.chezmoitemplates/` - Reusable template snippets

## Migration Context

**Old Setup (GNU Stow - Deprecated):**
- Location: `C:\Users\Randall\.config\dotfiles`
- 40+ config directories managed with symlinks
- Separate Windows/WSL bootstrap scripts
- Manual platform-specific handling

**Current Setup (Chezmoi - Production):**
- Location: `C:\Users\Randall\.local\share\chezmoi`
- 155+ managed configurations
- Template-based with automatic platform detection
- Feature flag system for optional packages
- Integrated bootstrap with auto-install
- One-command provisioning achieved
- Repository: `dotfiles-redux`

**Migration Completed:** November 2025 (v1.0.0)
- All core configs migrated and tested
- Windows, WSL, and Linux validated
- Package feature flag system implemented
- Production-ready bootstrap scripts deployed

## Target End State

Once migration is complete, provisioning a new machine will be:

**Windows:**
```powershell
iwr -useb https://raw.githubusercontent.com/USERNAME/chezmoi-dotfiles/main/bootstrap.ps1 | iex
```

**Unix:**
```bash
curl -fsSL https://raw.githubusercontent.com/USERNAME/chezmoi-dotfiles/main/setup.sh | bash
```

This single command will:
1. Install chezmoi (scoop/winget/mise)
2. Clone dotfiles repository
3. Apply all configurations (rendered from templates)
4. Install package managers if missing
5. Install all packages from manifests
6. Configure environment variables
7. Ready to work in <10 minutes

## Package Management Strategy

Per the environment rules:

**Windows:**
- `scoop` - CLI tools (git, neovim, starship, ripgrep, bat, fd, fzf, eza, btop, delta, gh, lazygit, etc.)
- `winget` - GUI apps (Git.Git, wez.wezterm, Microsoft.PowerShell, VS Code, 7zip)
- `mise` - Language runtimes only (node, python, ruby, go, rust, lua, bun, direnv, usage)

**Linux/WSL/macOS:**
- `mise` - Everything (CLI tools via cargo + language runtimes)
- `homebrew` - Bootstrap only (stow installation), then unused
- `apt/dnf/pacman` - System bootstrap only when sudo available

**Configuration Files (to be added):**
- `dot_config/scoop/scoop.json.tmpl` - Windows CLI packages
- `dot_config/mise/config.toml.tmpl` - Cross-platform runtimes and Unix tools
- `.chezmoiscripts/run_once_install_packages_*.tmpl` - Auto-installation scripts

## Line Ending Requirements

**CRITICAL**: Files used in Linux/WSL environments MUST use LF (Unix) line endings, NOT CRLF (Windows) line endings.

### Files that MUST use LF:
- All shell scripts (`*.sh`, `*.bash`, `.tmpl` files for Unix)
- All zsh configuration files (`dot-zshrc`, `.zsh` files)
- All files in `.chezmoiscripts/` that target Unix (even if they have `.tmpl` extension)
- Any configuration files that will be read by Linux/WSL tools

### Files that should use CRLF:
- PowerShell scripts (`*.ps1`, `.ps1.tmpl`)
- Windows-specific configuration files

### Checking line endings:

```powershell
# In PowerShell
$content = [System.IO.File]::ReadAllText("filename")
if ($content -match "`r`n") { "CRLF" } else { "LF" }
```

### Converting CRLF to LF:

```powershell
# In PowerShell
$content = [System.IO.File]::ReadAllText("filename")
$content = $content -replace "`r`n", "`n"
[System.IO.File]::WriteAllText("filename", $content)
```

```bash
# In WSL/Linux
sed -i 's/\r$//' filename
```

**AI Agent Note**: Always check and ensure correct line endings when creating or modifying files for Linux/WSL environments.

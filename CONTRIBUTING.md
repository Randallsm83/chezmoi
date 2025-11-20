# Contributing Guide

Thank you for your interest in contributing to these dotfiles! This guide will help you get started.

## Table of Contents

- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Pull Request Process](#pull-request-process)
- [Style Guidelines](#style-guidelines)
- [Architecture](#architecture)

---

## Development Setup

### Prerequisites

- Git
- Chezmoi (latest version)
- Basic understanding of shell scripting (Bash/PowerShell)
- Familiarity with Go templates (for chezmoi templates)

### Local Development

1. **Fork and clone**:
```bash
git clone https://github.com/YOUR_USERNAME/dotfiles
cd dotfiles
```

2. **Initialize chezmoi** (for testing):
```bash
# Option 1: Link directly to your fork
chezmoi init --source=$PWD

# Option 2: Use chezmoi managed directory
chezmoi init
cd $(chezmoi source-path)
git remote add dev /path/to/your/fork
git fetch dev
git checkout dev/your-branch
```

3. **Test changes without applying**:
```bash
# See what would change
chezmoi diff

# Dry-run execution
chezmoi apply --dry-run --verbose

# Test template rendering
chezmoi execute-template < .chezmoitemplates/your-template.tmpl
```

---

## Making Changes

### Branch Naming

Use descriptive branch names:
- `feature/add-ruby-config` - New features
- `fix/zsh-completion-bug` - Bug fixes
- `docs/update-install-guide` - Documentation
- `refactor/consolidate-templates` - Code refactoring

### Commit Messages

Follow conventional commits format:

```
type(scope): subject

body (optional)

footer (optional)
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Formatting, missing semicolons, etc.
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks

**Examples**:
```
feat(mise): add remote minimal config for limited environments

fix(git): correct conditional for Windows SSH path
  
docs(readme): update installation instructions for macOS

refactor(templates): consolidate platform detection logic
```

---

## Testing

### Manual Testing

Test on multiple platforms before submitting:

**Windows**:
```powershell
# Clean test
Remove-Item -Recurse -Force $env:LOCALAPPDATA\chezmoi
chezmoi init --apply YOUR_USERNAME/dotfiles
```

**Linux/macOS**:
```bash
# Clean test
rm -rf ~/.local/share/chezmoi ~/.config/chezmoi
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply YOUR_USERNAME/dotfiles
```

**Remote/No-Sudo**:
```bash
# Simulate remote environment
export SSH_CONNECTION="test"
chezmoi apply --dry-run
```

### Template Validation

```bash
# Test template syntax
chezmoi execute-template < .chezmoi.toml.tmpl

# Validate ignore patterns
chezmoi execute-template < .chezmoiignore

# Check what files would be managed
chezmoi managed

# Verify specific file rendering
chezmoi cat ~/.zshrc
```

### Health Check

Run the health check script after changes:
```bash
./scripts/healthcheck.sh
```

---

## Pull Request Process

### Before Submitting

1. **Test on at least one platform** (preferably your primary platform)
2. **Run health check** to ensure no breakage
3. **Update documentation** if you change behavior
4. **Add to CHANGELOG.md** under "Unreleased"
5. **Ensure no secrets** are committed (check with `git diff`)

### PR Description Template

```markdown
## Description
Brief description of what this PR does

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to change)
- [ ] Documentation update

## Platforms Tested
- [ ] Windows 11
- [ ] Linux (distribution: ___)
- [ ] macOS
- [ ] WSL2
- [ ] Remote (SSH)

## Checklist
- [ ] My code follows the style guidelines
- [ ] I have tested my changes
- [ ] I have updated relevant documentation
- [ ] I have added entries to CHANGELOG.md
- [ ] My changes generate no new warnings
- [ ] No secrets or sensitive data are included
```

### Review Process

1. Automated checks will run (if configured)
2. Maintainer will review within 1-2 weeks
3. Address any feedback
4. Once approved, changes will be merged

---

## Style Guidelines

### Shell Scripts (Bash)

**General Style**:
```bash
#!/usr/bin/env bash
#
# Script description
#

set -euo pipefail  # Always use strict mode

# Constants in UPPER_CASE
BACKUP_DIR="$HOME/.backups"

# Functions in snake_case
check_requirements() {
    local required_tool="$1"
    if ! command -v "$required_tool" &>/dev/null; then
        log_error "$required_tool not found"
        return 1
    fi
}

# Use logging functions from common-header
log_info "Starting process..."
log_success "Completed successfully"
log_warning "Non-critical issue"
log_error "Critical error occurred"

# Quote all variables
echo "$VARIABLE"
cp "$SOURCE" "$DEST"

# Use [[ ]] for conditionals (not [ ])
if [[ -f "$FILE" ]]; then
    echo "File exists"
fi

# Prefer ${var} over $var for clarity
echo "Path: ${HOME}/config"
```

**Chezmoi Templates** (Bash):
```bash
{{- if ne .chezmoi.os "windows" -}}
{{ template "common-header" . }}

# Use template variables
IS_REMOTE={{ .is_remote }}
HAS_SUDO={{ .has_sudo }}

# Conditional sections
{{- if .install_packages }}
install_packages
{{- end }}

{{- end -}}
```

### PowerShell Scripts

**General Style**:
```powershell
#Requires -Version 7.0
<#
.SYNOPSIS
    Brief description
.DESCRIPTION
    Detailed description
#>

# Use approved verbs
function Get-ConfigPath { }
function Set-EnvironmentVariable { }

# PascalCase for functions and variables
$ConfigPath = "$env:LOCALAPPDATA\config"

# Use splatting for parameters
$params = @{
    Path = $ConfigPath
    Force = $true
}
Copy-Item @params

# Use Write-Host with colors
Write-Host "Success" -ForegroundColor Green
Write-Host "Warning" -ForegroundColor Yellow

# Error handling
try {
    Do-Something
} catch {
    Write-Error "Failed: $_"
    exit 1
}
```

### Chezmoi Templates

**Template Naming**:
- Use lowercase with hyphens: `platform-detect.tmpl`
- Prefix with dot for dotfiles: `dot_zshrc.tmpl`
- Use descriptive names: `run_once_install_packages_unix.sh.tmpl`

**Template Style**:
```go
{{- /* Comments use Go template syntax */ -}}

{{- /* Remove whitespace with dashes */ -}}
{{- if .condition -}}
content
{{- end -}}

{{- /* Check existence before accessing */ -}}
{{- if index .package_features "rust" -}}
rust config
{{- end -}}

{{- /* Use template functions for reusability */ -}}
{{ template "common-header" . }}

{{- /* Multi-line conditionals */ -}}
{{- if and
      (eq .chezmoi.os "linux")
      (not .is_remote)
      .install_packages
-}}
install packages
{{- end -}}
```

### Documentation

**Markdown Style**:
- Use ATX-style headers (`#` not underlines)
- Include table of contents for long docs
- Use code blocks with language hints
- Keep lines under 120 characters (soft limit)
- Use reference-style links for repeated URLs

**Code Examples**:
```markdown
<!-- Always specify language -->
```bash
echo "Good example"
```

<!-- Not this -->
```
echo "Bad example"
```

<!-- Provide context -->
On **Windows**:
```powershell
$env:PATH += ";C:\Tools"
```

On **Linux/macOS**:
```bash
export PATH="$PATH:/opt/tools"
```
```

---

## Architecture

### Directory Structure

See [ARCHITECTURE.md](./ARCHITECTURE.md) for detailed architecture documentation.

**Key Conventions**:
- **`dot_` prefix**: Becomes `.` in home directory
  - `dot_zshrc` → `~/.zshrc`
  - `dot_config/` → `~/.config/`
  
- **`.tmpl` suffix**: Processed as Go template
  - `dot_zshrc.tmpl` → `~/.zshrc` (after templating)
  
- **Script prefixes**: Control execution
  - `run_before_*`: Before apply
  - `run_after_*`: After apply
  - `run_once_*`: Only once (or on change with hash)
  - `run_onchange_*`: When source changes

### Template Library

Reusable templates live in `.chezmoitemplates/`:

1. **`common-header.tmpl`**: Shell environment setup
   ```bash
   {{ template "common-header" . }}
   # Provides: log_info, log_success, error handling, XDG setup
   ```

2. **`platform-detect.tmpl`**: Platform detection
   ```bash
   {{ template "platform-detect" . }}
   # Provides: OS detection, distro detection, print_platform_info
   ```

3. **`package-manager.tmpl`**: Package abstraction
   ```bash
   {{ template "package-manager" . }}
   # Provides: package_install, package_remove, package_exists
   ```

4. **`1password.tmpl`**: 1Password integration
   ```bash
   {{ template "1password" . }}
   # Provides: op_get_secret, op_check_cli
   ```

### Adding New Platforms

To add support for a new platform/distro:

1. **Update platform detection** (`.chezmoitemplates/platform-detect.tmpl`):
```bash
detect_distro() {
    # Add new distro check
    if [ -f /etc/your-distro-release ]; then
        DISTRO="yourdistro"
        DISTRO_VERSION="$(parse_version)"
        return 0
    fi
}
```

2. **Add package manager support** (`.chezmoitemplates/package-manager.tmpl`):
```bash
package_install() {
    case "${PACKAGE_MANAGER}" in
        yourdistro)
            yourdistro-package-manager install "$1"
            ;;
    esac
}
```

3. **Update bootstrap** (`setup.sh`):
```bash
install_base_packages() {
    # Add your package manager
    elif command_exists yourdistro-pm; then
        log_info "Using yourdistro-pm"
        execute_with_privilege yourdistro-pm install git curl wget
    fi
}
```

4. **Test on the new platform**
5. **Update documentation** (README.md, INSTALL-GUIDE.md)

### Adding New Features

To add a new feature (e.g., new language runtime config):

1. **Add feature flag** (`.chezmoidata.yaml`):
```yaml
package_features:
  your_language: true  # Description of what it enables
```

2. **Add config files**:
```
dot_config/your_language/
└── config.toml.tmpl
```

3. **Add ignore pattern** (`.chezmoiignore`):
```go
{{- if not .package_features.your_language }}
# Your language package files
.config/your_language/**
.config/zsh/.zshrc.d/70-your_language.zsh
{{- end }}
```

4. **Add to mise config** (if runtime) (`dot_config/mise/config.toml.tmpl`):
```toml
[tools]
your_language = "latest"
```

5. **Document in README.md**

---

## Common Tasks

### Testing Template Rendering

```bash
# Test a specific template
chezmoi execute-template '{{ .email }}'

# Test template file
chezmoi execute-template < .chezmoi.toml.tmpl

# See rendered output of a managed file
chezmoi cat ~/.zshrc

# Compare source vs target
chezmoi diff ~/.zshrc
```

### Debugging

**Enable verbose output**:
```bash
chezmoi apply --verbose --dry-run
```

**Check chezmoi data**:
```bash
chezmoi data
```

**Verify managed files**:
```bash
chezmoi managed
chezmoi unmanaged
```

**Check ignored files**:
```bash
chezmoi ignored
```

### Adding Test Cases

Currently manual testing is required. Future: automated tests with Docker.

**Create test scenarios** in `tests/` (future):
```bash
tests/
├── test_windows.ps1
├── test_linux_ubuntu.sh
├── test_linux_arch.sh
├── test_macos.sh
└── test_remote.sh
```

---

## Questions?

- Open an issue for questions
- Check existing issues and PRs first
- Refer to [ARCHITECTURE.md](./ARCHITECTURE.md) for design decisions

## License

By contributing, you agree that your contributions will be licensed under the same license as this project (see LICENSE file).

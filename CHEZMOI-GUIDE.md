# Chezmoi Best Practices & Implementation Guide

This document serves as a reference for maintaining this dotfiles repository according to chezmoi best practices from the official documentation.

## Table of Contents
1. [Core Concepts](#core-concepts)
2. [File Management](#file-management)
3. [Machine-to-Machine Differences](#machine-to-machine-differences)
4. [Password Manager Integration](#password-manager-integration)
5. [Package Management](#package-management)
6. [Scripts and Hooks](#scripts-and-hooks)
7. [Configuration](#configuration)

---

## Core Concepts

### Source vs Target State
- **Source directory**: `~/.local/share/chezmoi` - git-tracked files with special prefixes
- **Target directory**: `~` - actual files in home directory
- Chezmoi transforms source → target using attributes and templates

### Prefixes and Attributes
- `dot_` → `.` (hidden files)
- `private_` → chmod 600
- `executable_` → chmod 755
- `symlink_` → creates symlink (file contains target path)
- `modify_` → runs script, output becomes file content
- `.tmpl` suffix → processed as Go template

**Source**: https://www.chezmoi.io/reference/source-state-attributes/

---

## File Management

### Externally Modified Files
For config files that applications rewrite at runtime (theme picks, recent
files, OAuth tokens, etc.) chezmoi has a few stable patterns. The two we
use in this repo:

1. **`modify_` template** — chezmoi renders the template, then runs the
   template against the live file so a fixed set of keys is overlaid while
   everything else is preserved. Used for `dot_claude/modify_settings.json`
   (Claude Code rewrites the file constantly; we only want to assert
   `permissions`, `model`, `enabledPlugins`, etc.).
2. **`symlink_*` source pointing at a chezmoi-managed file** — the live
   file in $HOME is a symlink back into the chezmoi source so app edits
   modify the tracked source directly. Used by VS Code on Windows:
   `AppData/Roaming/Code/User/symlink_keybindings.json` resolves to
   `vscode/keybindings.json`, and the same pattern applies to
   `mcp.json`/`tasks.json`/`extensions.json`. See `README.md` § VS Code
   for the canonical table.

For JSON files that the app rewrites without a stable schema, prefer
`modify_*`. For files the app reads but never rewrites, the symlink
pattern is simpler.

**Source**: https://www.chezmoi.io/user-guide/manage-different-types-of-file/#handle-configuration-files-which-are-externally-modified

### Templates
- Use `{{ .chezmoi.homeDir }}` instead of hardcoded paths
- Use `{{ .chezmoi.os }}` for OS detection
- Use data from `.chezmoi.toml.tmpl` via `{{ .variable_name }}`

**Source**: https://www.chezmoi.io/user-guide/templating/

---

## Machine-to-Machine Differences

### Configuration Hierarchy
1. `.chezmoi.toml.tmpl` - Generated config with platform detection
2. `.chezmoidata.yaml` - Static data (themes, fonts, package lists)
3. `.chezmoi.local.toml` - Machine-specific overrides (not committed)

### Platform Detection
```toml
# In .chezmoi.toml.tmpl
{{- $is_windows := eq .chezmoi.os "windows" -}}
{{- $is_darwin := eq .chezmoi.os "darwin" -}}
{{- $is_linux := eq .chezmoi.os "linux" -}}
{{- $is_wsl := and $is_linux (or (.chezmoi.kernel.osrelease | lower | contains "microsoft") (.chezmoi.kernel.osrelease | lower | contains "wsl")) -}}

[data]
    is_windows = {{ $is_windows }}
    is_darwin = {{ $is_darwin }}
    is_linux = {{ $is_linux }}
    is_wsl = {{ $is_wsl }}
```

### Conditional File Inclusion
```toml
# In template files
{{- if .is_windows }}
# Windows-specific content
{{- else }}
# Unix-specific content
{{- end }}
```

**Source**: https://www.chezmoi.io/user-guide/manage-machine-to-machine-differences/

---

## Password Manager Integration

### 1Password Setup

#### Step 1: Install Hook (runs BEFORE reading source state)
```bash
# .install-1password.sh (or .ps1 for Windows)
#!/bin/sh
type op >/dev/null 2>&1 && exit  # Exit if already installed

case "$(uname -s)" in
Darwin)
    # Install via homebrew
    ;;
Linux)
    # Install via package manager
    ;;
esac
```

#### Step 2: Configure Hook
```toml
# In .chezmoi.toml.tmpl
[hooks.read-source-state.pre]
    command = ".local/share/chezmoi/.install-1password.sh"

[onepassword]
    prompt = false  # Don't prompt for sign-in
```

#### Step 3: Use in Templates
```toml
# Example: dot_gitconfig.tmpl
[user]
    signingkey = {{ onepassword "your-item-id" "ssh-key" }}
```

**Source**: 
- https://www.chezmoi.io/user-guide/advanced/install-your-password-manager-on-init/
- https://www.chezmoi.io/user-guide/password-managers/1password/

---

## Package Management

### Declarative Installation

#### Step 1: Define Packages
```yaml
# .chezmoidata.yaml
packages:
  scoop:  # Windows
    - git
    - neovim
    - ripgrep
  
  brew:   # macOS
    - git
    - neovim
  
  mise:   # Cross-platform runtimes
    node: "lts"
    python: "latest"
```

#### Step 2: Installation Script
```bash
# .chezmoiscripts/run_onchange_install-packages.sh.tmpl
#!/bin/bash
# Hash: {{ include "dot_config/packages.yaml" | sha256sum }}

{{- if eq .chezmoi.os "darwin" }}
{{- range .packages.brew }}
brew install {{ . }}
{{- end }}
{{- end }}
```

The `run_onchange_` prefix means script only runs when:
- The script itself changes
- The hash comment changes (e.g., packages list updated)

**Source**: https://www.chezmoi.io/user-guide/advanced/install-packages-declaratively/

---

## Scripts and Hooks

### Script Types

#### `run_once_` - Runs once ever
```bash
# run_once_install-oh-my-zsh.sh
# Only runs the first time
```

#### `run_onchange_` - Runs when script or dependencies change
```bash
# run_onchange_install-packages.sh.tmpl
# Hash: {{ include "packages.yaml" | sha256sum }}
# Runs whenever packages.yaml changes
```

#### `run_before_` / `run_after_` - Ordering
```bash
# run_before_decrypt.sh - Runs before applying files
# run_after_configure.sh - Runs after applying files
```

#### Hooks - Special Execution Points
```toml
[hooks.read-source-state.pre]  # Before reading source
[hooks.apply.pre]              # Before applying changes
[hooks.apply.post]             # After applying changes
```

**Source**: https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/

---

## Configuration

### Essential Settings

```toml
# .chezmoi.toml.tmpl

[edit]
    command = "nvim"

[diff]
    command = "delta"
    args = ["--paging=never"]

[merge]
    command = "nvim"
    args = ["-d"]

[onepassword]
    prompt = false

{{- if eq .chezmoi.os "windows" }}
[interpreters.ps1]
    command = "pwsh"
    args = ["-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File"]
{{- end }}

[git]
    autoCommit = false
    autoPush = false
```

**Source**: https://www.chezmoi.io/reference/configuration-file/

---

## Testing Strategy

1. Test on fresh VM/container:
   ```bash
   chezmoi init --apply https://github.com/username/dotfiles.git
   ```

2. Verify no errors during:
   - Hook execution
   - Template rendering
   - Package installation
   - Script execution

3. Test modifications:
   - Change package list → verify `run_onchange_` triggers
   - Modify VS Code settings → verify git tracking works
   - Override setting in `.chezmoi.local.toml` → verify override works

---

## References

- Main docs: https://www.chezmoi.io/
- User guide: https://www.chezmoi.io/user-guide/
- Reference: https://www.chezmoi.io/reference/
- GitHub: https://github.com/twpayne/chezmoi

---

## Maintenance Notes

When adding new features:
1. Check official docs first
2. Use templates for portability
3. Use `run_onchange_` for declarative installation
4. Test on multiple platforms if cross-platform
5. Document in this guide

When you make assumptions, you create technical debt. Always verify against the docs.

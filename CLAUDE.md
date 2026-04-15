# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Cross-platform dotfiles managed by **Chezmoi**. Targets Windows, Linux, macOS, WSL, remote/SSH, and containers. All configs live in this source directory and get applied to `$HOME` via `chezmoi apply`.

## Essential commands

```bash
# Preview changes (safe, no modifications)
chezmoi diff
chezmoi apply --dry-run --verbose

# Apply changes
chezmoi apply

# Test template rendering
chezmoi execute-template < .chezmoitemplates/some-template.tmpl
echo '{{ .is_windows }}' | chezmoi execute-template

# Check what chezmoi would manage
chezmoi status
chezmoi managed

# Windows bootstrap tests (Pester)
Invoke-Pester -Path .\bootstrap.Tests.ps1 -Output Detailed
Invoke-Pester -FullNameFilter '*Install-Chezmoi*'  # single test

# Validation
bash scripts/healthcheck.sh
bash scripts/test.sh
```

## Chezmoi file naming conventions

| Prefix/suffix | Meaning |
|---|---|
| `dot_` | Maps to `.` (e.g., `dot_config/` → `~/.config/`) |
| `.tmpl` | Go template — processed by chezmoi before writing |
| `run_before_*` | Script runs before apply |
| `run_onchange_*` | Script runs when its content hash changes |
| `run_after_*` | Script runs after apply |
| `private_` | File gets 0600 permissions |
| `executable_` | File gets 0755 permissions |

## Template system

Templates use Go's `text/template` syntax. Key variables available in all `.tmpl` files:

- **Platform**: `.is_windows`, `.is_linux`, `.is_darwin`, `.is_wsl`, `.is_container`
- **Machine**: `.is_remote`, `.is_personal`, `.is_work`, `.has_sudo`, `.hostname`
- **Feature flags**: `.package_features.rust`, `.golang`, `.python`, `.node`, etc.
- **XDG**: `.xdg_config_home`, `.xdg_data_home`, `.xdg_state_home`, `.xdg_cache_home`
- **User**: `.name`, `.email`, `.github_username`

These are defined in `.chezmoi.toml.tmpl` (dynamic detection) and `.chezmoidata.yaml` (static data).

Reusable template fragments live in `.chezmoitemplates/` — include them with `{{ template "common-header" . }}`.

## Architecture (key relationships)

1. **`.chezmoi.toml.tmpl`** detects the platform/machine at `chezmoi init` time and sets all boolean flags
2. **`.chezmoidata.yaml`** is the single source of truth for packages, themes, and feature flags
3. **`.chezmoiignore`** uses those flags to exclude platform-irrelevant files (e.g., Unix-only configs on Windows)
4. **`.chezmoitemplates/`** provides shared fragments (platform detection, package manager abstraction, 1Password helpers)
5. **`.chezmoiscripts/`** run in order: backup → validate secrets → install packages → [apply] → rebuild bat cache
6. **`.chezmoi.local.toml`** (not committed) overrides any variable per-machine

## Theme system

Single theme declaration in `.chezmoidata.yaml` under `theme.name` propagates to neovim, starship, wezterm, eza, vivid, bat, delta. Available: spaceduck (default), onedark, gruvbox-material, tokyonight, dracula, kanagawa.

## Secrets

1Password CLI (`op`) is the primary secrets provider. Templates use `{{ onepasswordRead "op://vault/item/field" }}`. Age encryption (`.age` files) is the fallback. See `SECRETS.md` for details.

## Platform-specific patterns

- **Windows**: Bootstrap via `bootstrap.ps1` (PowerShell 7+). Packages via Scoop (CLI) + Winget (GUI).
- **Unix/Linux/macOS**: Bootstrap via `setup.sh`. Packages via Mise (user-space, no sudo).
- **Remote/SSH**: Auto-detected. Triggers minimal mode — fewer tools, no GUI apps, no system packages.
- **WSL**: Detected via kernel release. Shares 1Password SSH agent from Windows host.

## Important docs in this repo

- `ARCHITECTURE.md` — deep design decisions, directory structure, security model
- `INSTALL-GUIDE.md` — comprehensive installation for all platforms
- `SECRETS.md` — 1Password and Age integration patterns
- `CONTRIBUTING.md` — branch naming, commit conventions, testing procedures
- `WARP.md` — AI agent technical reference with chezmoi commands and troubleshooting

# AGENTS.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## What this is
Cross-platform dotfiles managed by **chezmoi**. Targets Windows, Linux, macOS, WSL, remote/SSH, and containers. All configs live in this source directory and get applied to `$HOME` via `chezmoi apply`. The repo is the chezmoi *source*; do **not** edit the rendered files in `$HOME` — edit the source here and run `chezmoi apply`.

## Essential commands
```bash
# Preview / inspect (safe)
chezmoi diff
chezmoi apply --dry-run --verbose
chezmoi status
chezmoi managed
chezmoi data                 # show all template variables for the current machine

# Apply
chezmoi apply
chezmoi apply ~/.gitconfig   # single file

# Edit source (preferred over editing rendered output in $HOME)
chezmoi edit ~/.gitconfig
chezmoi edit --apply ~/.gitconfig

# Template debugging
chezmoi execute-template < .chezmoitemplates/some-template.tmpl
echo '{{ .is_windows }}' | chezmoi execute-template
chezmoi cat ~/.zshrc         # show rendered output without applying

# Re-run run_once_/run_onchange_ scripts (force re-execution)
chezmoi state delete-bucket --bucket=scriptState
chezmoi apply

# Validation scripts
bash scripts/healthcheck.sh
bash scripts/test.sh
```

### Pester tests (Windows bootstrap)
```powershell
Invoke-Pester -Path .\bootstrap.Tests.ps1 -Output Detailed
Invoke-Pester -Path .\bootstrap.Tests.ps1 -FullNameFilter '*Install-Chezmoi*'  # single suite
```
Tests cover `bootstrap.ps1.example` (Install-Chezmoi, Install-Scoop, Initialize-Chezmoi, Set-EnvironmentVariables, Test-CommandExists) using extensive mocking to avoid system modifications.

## Chezmoi naming conventions
| Prefix/suffix | Meaning |
|---|---|
| `dot_` | Maps to `.` (e.g., `dot_config/` → `~/.config/`, `dot_zshrc` → `.zshrc`) |
| `.tmpl` | Go-template — processed by chezmoi before writing |
| `run_before_*` / `run_after_*` | Script runs before/after apply |
| `run_once_*` | Idempotent — runs only once per machine |
| `run_onchange_*` | Re-runs when its content hash changes |
| `private_` | File written with 0600 |
| `executable_` | File written with 0755 |

## Architecture (the big picture)
The system is built around a small set of files that drive everything else:

1. **`.chezmoi.toml.tmpl`** — Detects platform/machine at `chezmoi init` time and sets all the boolean flags (`.is_windows`, `.is_linux`, `.is_darwin`, `.is_wsl`, `.is_container`, `.is_remote`, `.is_personal`, `.is_work`, `.has_sudo`, etc.) plus user identity.
2. **`.chezmoidata.yaml`** — Single source of truth for static data: `theme.name`, `package_features.*`, package manifests (scoop/winget/mise), and color palettes. Editing this drives most repo-wide behavior changes.
3. **`.chezmoiignore`** — A *template* that uses the flags from steps 1–2 to exclude platform-irrelevant or feature-disabled files (e.g., Unix-only configs on Windows, `70-rust.zsh` when `package_features.rust = false`).
4. **`.chezmoitemplates/`** — Reusable template fragments (`platform-detect`, `platform-conditional`, `package-manager`, `detect-package-manager`, `xdg-paths`, `1password`, `op-read-safe`, `mise-tool-entry`, `common-header`). Include with `{{ template "name" . }}`.
5. **`.chezmoiscripts/`** — Auto-run scripts in deterministic order:
   - `run_before_00_backup.{sh,ps1}.tmpl` — backup before changes
   - `run_onchange_before_01_validate-secrets.sh.tmpl` — secrets sanity check
   - `run_onchange_before_install_base_packages_unix.sh.tmpl` — base packages
   - `run_onchange_install-packages-{unix,windows}.{sh,ps1}.tmpl` — packages from manifests
   - `run_onchange_generate_bat_themes*` / `run_after_rebuild_bat_cache*` — bat theme/cache rebuild
   - `run_after_sync_claude_memories.{sh,ps1}.tmpl` — sync Claude memories
6. **`chezmoi.local.toml`** (gitignored, see `chezmoi.local.toml.example`) — per-machine variable overrides.

### Template variables you will encounter in `.tmpl` files
- Platform: `.is_windows`, `.is_linux`, `.is_darwin`, `.is_wsl`, `.is_container`
- Machine: `.is_remote`, `.is_personal`, `.is_work`, `.has_sudo`, `.hostname`
- Feature flags: `.package_features.<name>` (rust, golang, python, ruby, lua, node, perl, php, glow, vivid, sqlite3, warp, vim, thefuck, arduino, tinted_theming, …)
- XDG: `.xdg_config_home`, `.xdg_data_home`, `.xdg_state_home`, `.xdg_cache_home`
- User: `.name`, `.email`, `.github_username`
- Built-ins: `.chezmoi.os`, `.chezmoi.arch`, `.chezmoi.hostname`, `.chezmoi.username`, `.chezmoi.kernel.osrelease`

### Theme system
A single `theme.name` in `.chezmoidata.yaml` propagates to neovim, starship, wezterm, eza, vivid, bat, and delta via templates. Available themes: `spaceduck` (default), `onedark`, `gruvbox-material`, `tokyonight`, `tokyonight-storm`, `dracula`, `kanagawa`. Change theme → `chezmoi apply`.

### Secrets
1Password CLI (`op`) is the primary provider. Templates use `{{ onepasswordRead "op://vault/item/field" }}` (or the `op-read-safe` template fragment for graceful fallbacks). Age-encrypted `.age` files are the backup mechanism. Detailed patterns are in `SECRETS.md`.

### Platform-specific patterns
- **Windows** — Bootstrap via `bootstrap.ps1` (PowerShell 7+). Packages: Scoop (CLI) + Winget (GUI) + Mise (language runtimes only).
- **Unix/Linux/macOS** — Bootstrap via `setup.sh`. Packages: Mise (everything, no sudo) + Homebrew (build deps + platform formulae) + apt/dnf/pacman (system bootstrap only when sudo is available).
- **WSL** — Detected via `.chezmoi.kernel.osrelease` containing `microsoft`. Shares the 1Password SSH agent from the Windows host via named-pipe relay.
- **Remote/SSH** — Auto-detected; triggers minimal mode (fewer tools, no GUI apps, no system packages).

### Zsh load order
Files in `dot_config/zsh/dot_zshrc.d/` use numeric prefixes:
- `50-*` package managers (homebrew)
- `70-*` language environments (rust, golang, python, ruby, lua, node, php)
- `80-*` tool integrations (eza, vivid)
- `90-*` utility tools (glow, thefuck)

Shell completions live in `dot_cache/zsh/completions/_<command>`.

## Line endings (CRITICAL)
- **LF** for everything that runs under Unix/Linux/WSL: `*.sh`, `*.bash`, all `dot_zshrc*`, every file in `dot_config/zsh/`, and any `.tmpl` whose target is Unix (including those in `.chezmoiscripts/`).
- **CRLF** for `*.ps1` / `*.ps1.tmpl` and Windows-only configs.

`dot_editorconfig` and `.gitattributes` enforce this; verify when authoring new files.

## Conventions
- **Branches**: `feature/<topic>`, `fix/<topic>`, `docs/<topic>`, `refactor/<topic>`.
- **Commits**: conventional commits — `type(scope): subject` (`feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`).
- **Changelog**: add user-visible changes to `CHANGELOG.md` under `Unreleased`.
- **Adding files**: prefer `chezmoi add --template <path>` for anything that needs platform conditionals; otherwise plain `chezmoi add <path>`.

## Pointers to deeper docs
- `ARCHITECTURE.md` — design decisions, directory structure, security model
- `INSTALL-GUIDE.md` — full installation walkthrough across all platforms
- `SECRETS.md` — 1Password / Age integration patterns
- `CHEZMOI-GUIDE.md` — chezmoi concepts and workflow reference
- `REMOTE.md` / `REINSTALL.md` — remote/SSH and rebuild scenarios
- `CONTRIBUTING.md` — branch naming, commit conventions, PR template
- `scripts/README.md` — utility scripts (WSL reset, healthcheck, rollback, etc.)

# AGENTS.md

Guidance for AI coding agents working in this repository.

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
Tests cover `bootstrap.ps1` (Install-Chezmoi, Install-Scoop, Initialize-Chezmoi incl. the HTTPS-first / -UseSSH fallback, Set-EnvironmentVariables, Test-CommandExists, Test-DeveloperMode, Enable-DeveloperMode, Test-OnePasswordCLI, Invoke-PreflightChecks, Import-ScoopExport, Import-WingetExport) using extensive mocking to avoid system modifications. Requires Pester 5.x (`Install-Module Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser -SkipPublisherCheck`).

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

1. **`.chezmoi.toml.tmpl`** — Detects platform/machine at `chezmoi init` time and sets boolean flags (`.is_windows`, `.is_linux`, `.is_darwin`, `.is_wsl`, `.is_container`, `.is_remote`, `.is_personal`, `.is_work`, `.has_sudo`, `.is_raspi`, `.remote_tier` ∈ {`minimal`, `medium`, `full`}) plus user identity.
2. **`.chezmoidata.yaml`** — Single source of truth for static data: `theme.name`, `fonts.*`, `ssh.*`, `package_features.*`, `package_mapping.*` (per-feature platform/manager packages, e.g. `package_mapping.<name>.darwin.cask`, `package_mapping.<name>.linux.<manager>`, `package_mapping.<name>.mise_remote` for no-sudo remote fallback), `vpn_dns_routes.*`, `remote_packages.<tier>`, `claude_memory_projects`. Editing this drives most repo-wide behavior changes.
3. **`.chezmoiignore`** — A *template* that uses the flags from steps 1–2 to exclude platform-irrelevant or feature-disabled files (e.g., Unix-only configs on Windows, `70-rust.zsh` when `package_features.rust = false`).
4. **`.chezmoitemplates/`** — Reusable template fragments (`platform-detect`, `platform-conditional`, `package-manager`, `detect-package-manager`, `xdg-paths`, `1password`, `op-read-safe`, `mise-tool-entry`, `common-header`). Include with `{{ template "name" . }}`.
5. **`.chezmoiscripts/`** — Auto-run scripts in deterministic order:
   - `run_before_00_backup.{sh,ps1}.tmpl` — backup before changes
   - `run_onchange_before_01_validate-secrets.sh.tmpl` — secrets sanity check
   - `run_onchange_before_install_base_packages_unix.sh.tmpl` — base packages
   - `run_onchange_install-packages-{unix,windows}.{sh,ps1}.tmpl` — packages from manifests
   - `run_onchange_generate_bat_themes*` / `run_after_rebuild_bat_cache*` — bat theme/cache rebuild
   - `run_onchange_after_55_vpn-dns-routes.{sh,ps1}.tmpl` — split-DNS routes from `vpn_dns_routes` (macOS `/etc/resolver/`, Linux `resolvectl`, Windows NRPT)
   - `run_onchange_after_70_vscode-extensions_{windows,unix}.{ps1,sh}.tmpl` — install missing VS Code extensions from `vscode/extensions.txt` (gated by `package_features.vscode` and presence of the `code` CLI; idempotent, additive only)
   - `run_after_sync_claude_memories.{sh,ps1}.tmpl` — sync Claude memories
6. **`chezmoi.local.toml`** (gitignored, see `chezmoi.local.toml.example`) — per-machine variable overrides. Anything in this file wins over auto-detection.

### Template variables you will encounter in `.tmpl` files
- Platform: `.is_windows`, `.is_linux`, `.is_darwin`, `.is_wsl`, `.is_container`, `.is_raspi`
- Machine: `.is_remote`, `.is_personal`, `.is_work`, `.has_sudo`, `.hostname`, `.remote_tier`
- Feature flags: `.package_features.<name>` — see *Feature flags* below.
- XDG: `.xdg_config_home`, `.xdg_data_home`, `.xdg_state_home`, `.xdg_cache_home`
- User: `.name`, `.email`, `.github_username`
- Data blocks: `.vpn_dns_routes`, `.remote_packages.<tier>`, `.package_mapping.<feature>`, `.claude_memory_projects`
- Built-ins: `.chezmoi.os`, `.chezmoi.arch`, `.chezmoi.hostname`, `.chezmoi.username`, `.chezmoi.kernel.osrelease`

### Feature flags
Defined in `.chezmoidata.yaml` under `package_features`. Two layers:
- **Group flags** (convenience shortcuts): `essentials`, `shell_tools`, `languages`, `editors`, `terminals`, `rust_alternatives`, `ai_tools`, `gaming`, `docker`, `hardware_tools`, `windows_utilities`, `sysinternals`, `network_tools`, `dev_extras`, `nerd_fonts`.
- **Individual flags**: `git`, `ssh`, `1password`, `mise`, `direnv`, `homebrew`, `wezterm`, `warp`, `windows_terminal`, `nvim`, `vim`, `vscode`, `starship`, `zsh`, `powershell`, `fzf`, `wget`, `thefuck`, `fastfetch`, `topgrade`, `rust`, `golang`, `python`, `ruby`, `lua`, `node`, `perl`, `julia`, `php`, `sqlite3`, `arduino`, `vagrant`. Deprecated/off: `asdf`, `nvm`, `tinted_theming`.

**`1password` access caveat**: the flag name starts with a digit, which is invalid Go-template identifier syntax. Always access it as `{{ index .package_features "1password" }}`, **never** `.package_features.1password`.

### Theme system
A single `theme.name` in `.chezmoidata.yaml` propagates to neovim, starship, wezterm, eza, vivid, bat, and delta via templates. Available themes: `spaceduck` (default), `onedark`, `gruvbox-material`, `tokyonight`, `tokyonight-storm`, `dracula`, `kanagawa`. Change theme → `chezmoi apply`.

### Secrets
1Password CLI (`op`) is the primary provider, but templates do **not** call `op` directly. Instead, all `op://` references are batched into a single `op inject` invocation in `.chezmoi.toml.tmpl` ($secretsTpl), exposed as the `.secrets.*` template namespace. This means **one biometric prompt per `chezmoi apply --init`** and **zero prompts per `chezmoi apply`**.

To add a secret: append `key = "{{ op://Vault/Item/field }}"` to `$secretsTpl` in `.chezmoi.toml.tmpl`, then reference as `{{ .secrets.key }}` in any template. Run `chezmoi apply --init` to refresh after rotation. Set `CHEZMOI_SKIP_1P=1` to skip 1Password entirely (resolves to empty strings).

The legacy `op-read-safe` partial in `.chezmoitemplates/` is retained for one-off cases but should not be used for new secrets — each invocation triggers its own biometric prompt. Age-encrypted `.age` files are the backup mechanism. Detailed patterns are in `SECRETS.md`.

### Platform-specific patterns
- **Windows** — Bootstrap via `bootstrap.ps1` (PowerShell 7+). Packages: Scoop (CLI) + Winget (GUI) + Mise (language runtimes only).
- **Unix/Linux/macOS** — Bootstrap via `setup.sh`. Packages: Mise (everything, no sudo) + Homebrew (build deps + platform formulae; cask list is generated from `package_mapping.<feature>.darwin.cask`) + apt/dnf/pacman (system bootstrap only when sudo is available).
- **WSL** — Detected via `.chezmoi.kernel.osrelease` containing `microsoft`. Shares the 1Password SSH agent from the Windows host via named-pipe relay.
- **Remote/SSH** — Auto-detected; respects `remote_tier` (`minimal` / `medium` / `full`) which selects a package set from `remote_packages.<tier>`. When a tool would normally come from a root-required distro package (e.g. `lua`, `luajit`, `vim`), `package_mapping.<feature>.mise_remote` provides a no-sudo mise fallback that `dot_config/mise/config.toml.tmpl` emits when `is_remote` is true.
- **Raspberry Pi** — `is_raspi` is set when hostname matches `raspi*`/`raspberrypi*`/`rpi*`, or when `RASPI=1 ./setup.sh` is run. Pi defaults to `remote_tier = "medium"`. SSH access uses Tailscale MagicDNS (no `.local` mDNS fallback). See `RASPI.md`.

### Zsh load order
Files in `dot_config/zsh/dot_zshrc.d/` use numeric prefixes:
- `50-*` package managers (homebrew)
- `70-*` language environments (rust, golang, python, ruby, lua, node, php)
- `80-*` tool integrations (eza, vivid)
- `90-*` utility tools (thefuck)

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
- **Merging mirrored remotes**: this repo is mirrored to GitLab (`origin`) and GitHub (`github`) as two single-URL remotes; multi-host pushes go through `git pushall` (serial push + bounded retry, defined in `dot_config/git/config.tmpl`). **Never click "Merge" in the web UI** — each host creates its own squash commit with a different SHA and the two `main`s diverge. Use `git land <branch>` (merge locally, then `pushall` so both remotes converge on the same SHA). See `CONTRIBUTING.md` § "Merging (mirrored remotes)".

## Pointers to deeper docs
- `ARCHITECTURE.md` — design decisions, directory structure, security model
- `INSTALL-GUIDE.md` — full installation walkthrough across all platforms
- `SECRETS.md` — 1Password / Age integration patterns
- `CHEZMOI-GUIDE.md` — chezmoi concepts and workflow reference
- `REMOTE.md` — remote/SSH machine model and tiers
- `RASPI.md` — Raspberry Pi medium-tier profile
- `REINSTALL.md` — rebuild / reset scenarios
- `CONTRIBUTING.md` — branch naming, commit conventions, PR template
- `scripts/README.md` — utility scripts (WSL reset, healthcheck, rollback, etc.)

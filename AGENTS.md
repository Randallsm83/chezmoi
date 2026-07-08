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
2. **`.chezmoidata/*.yaml`** — Single source of truth for static data, split into focused files that chezmoi merges into one namespace at template time. Editing any of these drives most repo-wide behavior changes:
   - `.chezmoidata/theme.yaml` — `theme.*` palettes, `theme_mappings.*` per-application theme identifiers.
   - `.chezmoidata/fonts.yaml` — `fonts.*` (primary, fallback, Nerd Font variants, Fira Code ligature settings).
   - `.chezmoidata/ssh.yaml` — `ssh.*` agent settings (1Password vaults, pipe/socket paths).
   - `.chezmoidata/packages.yaml` — `package_features.*` (feature flags), `package_mapping.*` (per-feature platform/manager packages, e.g. `package_mapping.<name>.darwin.cask`, `package_mapping.<name>.linux.<manager>`, `package_mapping.<name>.mise_remote` for no-sudo remote fallback), `brew_bundle.*`, `scoop_buckets`, `scoop_bucket_overrides`, `always_install.*`, `remote_packages.<tier>`, `claude_memory_projects`.
   - `.chezmoidata/dns.yaml` — `vpn_dns_routes.*`, `encrypted_dns.*`, `browser_doh.*`, `caddy_ca.*`.
   - `.chezmoidata/mcp.yaml` — `mcp.*` server definitions.
   The old monolithic `.chezmoidata.yaml` was split per wave-d-innovation; chezmoi treats every `*.yaml` in `.chezmoidata/` as if it were merged into the same top-level data namespace.
3. **`.chezmoiignore`** — A *template* that uses the flags from steps 1–2 to exclude platform-irrelevant or feature-disabled files (e.g., Unix-only configs on Windows, `70-rust.zsh` when `package_features.rust = false`).
4. **`.chezmoitemplates/`** — Reusable template fragments. The actively-called ones are `platform-detect`, `1password-agent.toml`, `op-read-safe`, `mise-tool-entry`, `ssh-pub-resolve`, and `common-header`. Include with `{{ template "name" . }}`. (Earlier `package-manager`/`detect-package-manager`/`platform-conditional`/`xdg-paths` partials were never wired up and have been removed; XDG paths come from `.chezmoi.toml.tmpl` `[data]` and package routing lives in `.chezmoidata/packages.yaml` `package_mapping`.)
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
Defined in `.chezmoidata/packages.yaml` under `package_features`. Two layers:
- **Group flags** (convenience shortcuts): `essentials`, `shell_tools`, `languages`, `editors`, `terminals`, `rust_alternatives`, `ai_tools`, `gaming`, `docker`, `hardware_tools`, `windows_utilities`, `sysinternals`, `network_tools`, `dev_extras`, `nerd_fonts`.
- **Individual flags**: `git`, `ssh`, `1password`, `mise`, `direnv`, `homebrew`, `wezterm`, `warp`, `windows_terminal`, `nvim`, `vim`, `vscode`, `zed`, `starship`, `zsh`, `powershell`, `fzf`, `atuin`, `wget`, `thefuck`, `fastfetch`, `topgrade`, `rust`, `golang`, `python`, `ruby`, `lua`, `node`, `perl`, `julia`, `php`, `sqlite3`, `arduino`, `vagrant`. Deprecated/off: `asdf`, `nvm`, `tinted_theming`.

**`1password` access caveat**: the flag name starts with a digit, which is invalid Go-template identifier syntax. Always access it as `{{ index .package_features "1password" }}`, **never** `.package_features.1password`.

### Theme system
A single `theme.name` in `.chezmoidata/theme.yaml` (overridable as `[data] theme = "..."` in `.chezmoi.toml.tmpl` / `.chezmoi.local.toml`) propagates to neovim, starship, wezterm, eza, vivid, bat, and delta via templates. Available themes: `spaceduck` (default), `onedark`, `gruvbox-material`, `tokyonight`, `tokyonight-storm`, `dracula`, `kanagawa`. Change theme → `chezmoi apply`.

### Secrets
1Password CLI (`op`) is the primary provider, but templates do **not** call `op` directly. Instead, all `op://` references are batched into a single `op inject` invocation in `.chezmoi.toml.tmpl` ($secretsTpl), exposed as the `.secrets.*` template namespace. This means **one biometric prompt per `chezmoi apply --init`** and **zero prompts per `chezmoi apply`**.

To add a secret: append `key = "{{ op://Vault/Item/field }}"` to `$secretsTpl` in `.chezmoi.toml.tmpl`, then reference as `{{ .secrets.key }}` in any template. Run `chezmoi apply --init` to refresh after rotation. Set `CHEZMOI_SKIP_1P=1` to skip 1Password entirely (resolves to empty strings).

The legacy `op-read-safe` partial in `.chezmoitemplates/` is retained for one-off cases but should not be used for new secrets — each invocation triggers its own biometric prompt. Age-encrypted `.age` files are the backup mechanism. Detailed patterns are in `SECRETS.md`.

### OMP homelab auth
The `omp` CLI authenticates against a homelab auth-broker (and an OpenAI-compatible auth-gateway) running in containers on the Pi (`raspi`). Configuration is split across three managed surfaces:
- **Agent settings** — `dot_omp/agent/config.yml.tmpl` renders `~/.omp/agent/config.yml` on both Windows and WSL from a single shared baseline. Treat the shared block as the source of truth — do not re-fork a setting per platform unless it truly differs. `dot_omp/agent/dot_env.tmpl` renders the WSL-only `~/.omp/agent/.env`, and `.chezmoiignore` excludes `.omp/agent/.env` on Windows.
- **The `omp` wrapper** — defined in zsh `dot_config/zsh/dot_zshrc.d/25-functions.zsh` and pwsh `Documents/PowerShell/Scripts/lib/99-functions-body.ps1`. It prefers a synchronized local `~/.omp/auth-broker.token` (exporting `OMP_AUTH_BROKER_URL` + `OMP_AUTH_BROKER_TOKEN` for that process only) and falls back to the `op run --env-file=~/.config/op/omp.env` path when no token file is present, so Windows and WSL hit the same broker without per-pane biometric prompts.
- **Helper commands** — `ompb`/`ompg` run `omp auth-broker`/`auth-gateway` inside the Pi containers over SSH; `ompb-login`, `ompg-url`, `ompg-models` (broker model list), and `ompg-api-models` (gateway `/models` via the gateway token) round out the set. The auth host and public gateway base URL resolve from `OMP_AUTH_HOST` (default `raspi`) and `OMP_GATEWAY_PUBLIC_BASE_URL`.
Never write the resolved broker/gateway tokens into the chezmoi source or any doc — they live only in `~/.omp/*.token` and the running process env.

### Platform-specific patterns
- **Windows** — Bootstrap via `bootstrap.ps1` (PowerShell 7+). Packages: Mise (language runtimes and supported CLI tools) + Scoop (remaining CLI/bootstrap tools) + Winget (GUI).
- **Unix/Linux/macOS** — Bootstrap via `setup.sh`. Packages: Mise (everything, no sudo) + Homebrew (build deps + platform formulae; cask list is generated from `package_mapping.<feature>.darwin.cask`) + apt/dnf/pacman (system bootstrap only when sudo is available).
- **WSL** — Detected via `.chezmoi.kernel.osrelease` containing `microsoft`. Shares the 1Password SSH agent from the Windows host via named-pipe relay **when Windows `.exe` interop is available**. On distros where interop is disabled, templates must not assume the Windows host is reachable: `dot_config/git/config.tmpl` uses the PATH-selected native `ssh` (no hardcoded `/mnt/c/.../ssh.exe`), the chezmoi-source remotes script fetches over GitHub HTTPS while keeping SSH `pushurl`s, and `run_onchange_before_install_base_packages_unix.sh.tmpl` repairs a stale `/usr/local/bin/op` Windows-bridge shim to point at native Linux `op`. See the *OMP homelab auth* note below for the matching broker-token fallback.
- **Remote/SSH** — Auto-detected; respects `remote_tier` (`minimal` / `medium` / `full`) which selects a package set from `remote_packages.<tier>`. When a tool would normally come from a root-required distro package (e.g. `lua`, `luajit`, `vim`), `package_mapping.<feature>.mise_remote` provides a no-sudo mise fallback that `dot_config/mise/conf.d/00-managed.toml.tmpl` emits when `is_remote` is true.
- **Raspberry Pi** — `is_raspi` is set when hostname matches `raspi*`/`raspberrypi*`/`rpi*`, or when `RASPI=1 ./setup.sh` is run. Pi uses `remote_tier = "medium"` for the lightweight zsh loader, but bootstrap seeds `install_packages = false` so medium-tier tools are opt-in. SSH access uses Tailscale MagicDNS (no `.local` mDNS fallback). See `RASPI.md`.

### mise config layout
Windows mise 2026.5.7 only activates the global config file (`~/.config/mise/config.toml`), not `conf.d` fragments. On Windows, chezmoi therefore manages `~/.config/mise/config.toml` with `dot_config/mise/modify_config.toml`: it renders the curated baseline from `.chezmoidata/packages.yaml` directly into the active file, then overlays existing live `[tools]`, `[settings]`, and `[env]` values so ad-hoc `mise use -g <tool>` / `mise settings set` changes survive `chezmoi apply`. On Unix, the baseline remains in `~/.config/mise/conf.d/00-managed.toml` (source `dot_config/mise/conf.d/00-managed.toml.tmpl`) and `~/.config/mise/config.toml` stays user-owned for overrides.

### Zsh load order
Files in `dot_config/zsh/dot_zshrc.d/` use numeric prefixes; lower numbers source first. The actual prefix ranges in use today:
- `00-*` shell helpers shared by later files (e.g. `00-helpers.zsh`).
- `01-*` early bootstrap (mise activation).
- `05-*` early-setup helpers (LDE env, completion-helper plumbing).
- `10-*` workspace state (dir vars, 1Password SSH agent socket).
- `20-*` PATH manipulation (`20-paths.zsh`).
- `25-*` aliases + functions (`25-aliases.zsh`, `25-functions.zsh`, `25-aliases-ndn.zsh`, `25-common-aliases.zsh`, `25-gnu-utils.zsh`, history widgets).
- `30-*` miscellaneous shell options (`30-misc.zsh`).
- `40-*` terminal integration (`40-wezterm.zsh`).
- `50-*` package managers (homebrew, mise).
- `60-*` standalone tool setup (vagrant).
- `70-*` language environments (rust, golang, python, ruby, lua, node, perl, php, npm, nvm, bun, arduino).
- `80-*` Rust/CLI tool integrations (bat, eza, fzf, ripgrep, zoxide, op, rust-alternatives, tinty, wget, completions, scott).
- `85-*` higher-level integrations that depend on earlier sections (git, vscode).
- `90-*` prompt and command-correction (`starship`, `thefuck`).
- `99-*` last-resort consumers (`warp`).

Shell completions live in `dot_cache/zsh/completions/_<command>`.

### Shell completion playbook
- **PowerShell completions** live in `Documents/PowerShell/Completions/<command>.ps1` and are loaded by `Documents/PowerShell/Scripts/20-completions.ps1`. If upstream output changes shell behavior (for example `hf --show-completion` imports PSReadLine and remaps Tab), prefer a small hand-written `Register-ArgumentCompleter -Native` wrapper instead of evaluating upstream output at startup.
- **zsh completions** live in `dot_cache/zsh/completions/_<command>` when the completion is static or needs custom environment variables. Runtime-generated completions belong in `dot_config/zsh/dot_zshrc.d/80-completions.zsh` via `_gen_completion_runtime`.
- **Hugging Face CLI (`hf`)** is a Typer CLI. Do not use `hf --install-completion` in chezmoi because it writes to the active user shell outside source control. Use the checked-in files `Documents/PowerShell/Completions/hf.ps1` and `dot_cache/zsh/completions/_hf`; both drive completion by setting `_HF_COMPLETE` plus Typer completion environment variables at completion time.
- After adding a cross-shell completion, verify the generated behavior directly and run `pwsh -NoProfile -File scripts/lint-shell-parity.ps1`.

## Line endings (CRITICAL)
- **LF everywhere.** Every text file in this repo uses Unix line endings (LF).
- `.gitattributes` enforces LF on every text file via `text eol=lf`; `dot_editorconfig` repeats the policy at editor level.
- PowerShell 7+ reads LF natively. The previous CRLF-for-`*.ps1` rule was repo-wide drift documented but never actually enforced; the new policy makes the docs match disk reality.
- Verify with `git ls-files --eol` or `[IO.File]::ReadAllBytes('<path>') | Where-Object { $_ -eq 13 }` (zero matches = pure LF).

## Conventions
- **Branches**: `feature/<topic>`, `fix/<topic>`, `docs/<topic>`, `refactor/<topic>`.
- **Commits**: conventional commits — `type(scope): subject` (`feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`).
- **Changelog**: add user-visible changes to `CHANGELOG.md` under `Unreleased`.
- **PowerShell/zsh parity**: when adding shell startup env vars or feature-gated integrations, keep Windows PowerShell and zsh gating aligned and run `pwsh -NoProfile -File scripts/lint-shell-parity.ps1`; `scripts/test.ps1` runs it as part of the Windows smoke suite.
- **Adding files**: prefer `chezmoi add --template <path>` for anything that needs platform conditionals; otherwise plain `chezmoi add <path>`.
- **Merging mirrored remotes**: this repo is mirrored to GitLab (`origin`) and GitHub (`github`) as two single-URL remotes; multi-host pushes go through `git pushall` (serial push + bounded retry, defined in `dot_config/git/config.tmpl`). **Never click "Merge" in the web UI** — each host creates its own squash commit with a different SHA and the two `main`s diverge. Use `git land <branch>` (merge locally, then `pushall` so both remotes converge on the same SHA). See `CONTRIBUTING.md` § "Merging (mirrored remotes)".

## Pointers to deeper docs
- `ARCHITECTURE.md` — design decisions, directory structure, security model
- `INSTALL-GUIDE.md` — full installation walkthrough across all platforms
- `SECRETS.md` — 1Password / Age integration patterns
- `CHEZMOI-GUIDE.md` — chezmoi concepts and workflow reference
- `REMOTE.md` — remote/SSH machine model and tiers
- `RASPI.md` — Raspberry Pi homelab zsh profile
- `REINSTALL.md` — rebuild / reset scenarios
- `CONTRIBUTING.md` — branch naming, commit conventions, PR template
- `scripts/README.md` — utility scripts (WSL reset, healthcheck, rollback, shell parity linting, etc.)

## Subdirectory AGENTS.md
- `.chezmoiscripts/.AGENTS.md` — script lifecycle, run-order ranges, platform pairing, re-running gotchas
- `.chezmoidata/.AGENTS.md` — per-file ownership matrix, override surface, namespace-merge rules
- `.chezmoitemplates/AGENTS.md` — partial inventory, call signatures, safe-failure conventions
- `dot_config/zsh/dot_zshrc.d/AGENTS.md` — file-by-file load order, dependency ranges, `.tmpl` gating
The leading dots on the first two are deliberate: chezmoi's `.chezmoidata/` loader rejects any non-data extension (`.md` → “unknown format”) and `.chezmoiscripts/` rejects any file that isn't a `run_*` script. Chezmoi otherwise ignores source files whose name begins with `.`, so the leading dot is the only way to keep per-directory documentation co-located without breaking `chezmoi apply`. `.chezmoitemplates/AGENTS.md` is loaded as a Go template instead and uses `{{ "{{ ... }}" }}` literal-string escapes for the same reason — see the in-file editor note.

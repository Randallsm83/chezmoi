# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- **Package mapping: codify installed scoop+winget drift**: `.chezmoidata.yaml` gains five new feature flags (`productivity`, `password_managers`, `browsers`, `media`, `vpn`) and their `package_mapping` entries, plus drift additions to existing `zed`, `rust_alternatives`, `ai_tools`, `gaming`, `docker`, `hardware_tools`, `windows_utilities`, `network_tools`, and `dev_extras` mappings — covering 22 scoop apps and 30+ winget apps that were installed on the Windows host but not declared. `scoop_bucket_overrides` gains a `nonportable` bucket entry (equalizer-apo-np, peace-np), moves `openscad-dev` to `versions`, adds the new extras-bucket apps, and drops the failed `pritunl-client` (moved to vpn.winget) and `windowsdesktop-runtime-10.0` (transitive winget dep). The winget side will render once wave-a fixes the `windows.winget` path in `winget-packages.json.tmpl`.
- **wezterm terminfo installer (Windows)**: new `feat(wezterm-win)` flow ships a checked-in `wezterm-terminfo/wezterm.terminfo` source and a `run_onchange_*` PowerShell installer under `.chezmoiscripts/` that compiles the entry into the local `terminfo` database. Without it, MSYS/Git-Bash pagers (`less`, `man`, `git log`) launched from wezterm on Windows render broken when `TERM=wezterm`. The `wezterm-terminfo/` source directory is excluded from `$HOME` deployment via `.chezmoiignore`.
- **wezterm: resurrect.wezterm + zoxide workspaces + tool overlays + broadcast + which-key**: `dot_config/wezterm/keymaps.lua` gains session save/load via [`resurrect.wezterm`](https://github.com/MLFlexer/resurrect.wezterm) (`LEADER+A` save, `LEADER+E` load), a zoxide-backed workspace picker (`LEADER+J`), tool overlays (`LEADER+X` then `g`/`t`/`n`/`o` for `lazygit`/`btop`/`nvim`/`opencode`), broadcast-to-panes toggle (`LEADER+B`), and a which-key style launcher (`LEADER+?`). The Spaceduck color scheme (`dot_config/wezterm/colors/Spaceduck.toml`, `wezterm.lua.tmpl`) is refreshed: corrected ANSI/brights mapping, distinct selection/visual-bell/tab/scrollbar tokens, and the palette is now mirrored in `wezterm_scheme` for tabline/UI accent consumers.
- **`git land` alias + mirrored-remote merge workflow**: new alias in `dot_config/git/config.tmpl` codifies the canonical "merge a feature branch into main" flow when the repo is mirrored across hosts (e.g. GitLab + GitHub on a dual-push `origin`). Merges locally with `--no-ff --no-edit` (or `--ff-only` via `GIT_LAND_FF=1`), pushes once to `origin` so both remotes get the same SHA, and deletes the local feature branch (skip with `GIT_LAND_KEEP=1`). Refuses to land `main`/`master` onto itself. `CONTRIBUTING.md` gains a "Merging (mirrored remotes)" section explaining the divergence problem (clicking Merge in both web UIs creates two different squash SHAs → subsequent pushes rejected with `fetch first`), the canonical workflow, and how to recover with `--force-with-lease` after verifying matching trees.
- **VS Code extensions managed by chezmoi**: `vscode/extensions.txt` is the single source of truth (one extension ID per line, `#` comments allowed). `run_onchange_after_70_vscode-extensions_{windows,unix}.{ps1,sh}.tmpl` diffs the list against `code --list-extensions` on every `chezmoi apply` and installs only the missing ones (additive — never uninstalls). Gated by `package_features.vscode` and presence of the `code` CLI on PATH.
- **Workspace environment variables**: `PROJECTS`, `DHSPACE`, `BACKEND`, `FRONTEND`, `HELPSERVICES`, `NOTES` exported from `dot_config/zsh/dot_zshrc.d/10-dirs.zsh` (zsh) and `Documents/PowerShell/Scripts/99-aliases.ps1` (pwsh). All paths derive from `$HOME` via `Join-Path` (pwsh) / `$HOME/...` (zsh) — no hardcoded Windows paths. Structure: `PROJECTS = $HOME/projects`, `DHSPACE = $PROJECTS/dh`, `BACKEND/FRONTEND/HELPSERVICES = $DHSPACE/<bucket>`, `NOTES = $PROJECTS/notes`.
- **Navigation shortcuts** (zsh aliases / pwsh functions, guarded by directory existence on pwsh):
  - Workspace roots: `cdp`, `dh`, `cdbe`, `cdfe`, `cdhs`, `dots`, `notes`
  - Top-level DH repos: `cdn` (ndn), `cdaudit` (ndn-audit), `cdpam`, `cdscott`, `cdtm` (task-management)
  - Common backend services: `cdapi` (api-gateway), `cdcdn` (cdn-service)
- **`dhgitall`**: cross-platform helper (zsh + pwsh) that runs a `git` command across every repo under `$BACKEND/`, `$FRONTEND/`, `$HELPSERVICES/`. Skips entries without a `.git` directory. Top-level repos (ndn, pam, scott, etc.) are intentionally excluded — use them individually when you need to.
- **Encrypted DNS profile (macOS)**: New `encrypted_dns` block in `.chezmoidata.yaml` plus `dot_config/dns/private_pihole-dot.mobileconfig.tmpl` and `.chezmoiscripts/run_onchange_after_56_encrypted-dns.sh.tmpl` install a `com.apple.dnsSettings.managed` profile pinning the system resolver at `raspi.tailf7fd34.ts.net:853` over DoT. TCP-probes the endpoint before installing; skips with a warning if the Pi-side terminator isn't up yet. Encrypts the LAN leg of DNS that was previously plaintext UDP/53.
- **Browser DoH disable (macOS)**: New `browser_doh` block in `.chezmoidata.yaml` plus `.chezmoiscripts/run_onchange_after_57_browser-doh-policies.sh.tmpl` writes managed-policy files for Firefox (`policies.json`), Chrome, Edge, and Brave (`/Library/Managed Preferences/<bundle>.plist`) so they respect the system resolver instead of bypassing Pi-hole via Mozilla/Cloudflare DoH.
- **Pi-side DoT terminator setup**: `scripts/setup-pihole-dot.sh` installs `unbound`, mints a TLS cert via `tailscale cert`, and forwards plain DNS to Pi-hole. Run on the Pi, not the Mac.
- **RASPI.md** — "Encrypted DNS (DoT terminator)" section documenting the Pi-side prerequisite.
- **DNS.md** — full DNS architecture reference: resolver hierarchy, where each component lives in the chezmoi source, browser DoH disable mechanics, verification commands, and past failure modes (unbound validator/localhost defaults, deprecated `profiles install`, `/Library/Managed Preferences/` requiring MDM, the wrong-vault `raspi.pub` template).
- **`dot_config/op/pam.env`**: new env-reference file for the Personal Agent Multiplexer (pam) MCP proxy daemon. Mirrors the pattern from `claude.env`/`opencode.env`: `VAR=op://Vault/Item/field` lines resolved at process spawn via `op run --env-file=~/.config/op/pam.env -- pam.exe start`. Covers AI provider creds (`ANTHROPIC_API_KEY`, `TAVILY_API_KEY`, `VERCEL_TOKEN`, `NEON_API_KEY`, `QDRANT_API_KEY`) plus the DH ClickUp backend's `DH_CLICKUP_API_KEY` + public `CLICKUP_TEAM_ID`. Source lives at `dot_config/private_op/private_pam.env` (chezmoi `private_` prefix → 0600 on disk). pam currently resolves most secrets inline in `~/.config/pam/manifest.toml` via `${op://...}` placeholders; this file handles the subset that the manifest pulls from the process env via `env://` references (today: clickup), and pre-stages the rest so future backends that switch to `env://` Just Work.
- **Runtime secret injection via `op run` (Pattern B)**: wraps CLIs that read API keys at launch (claude, opencode, pam) so secrets are resolved from 1Password via `op run --env-file=~/.config/op/<tool>.env -- <tool>` and only ever live in the child process's env. Per-tool env files in `dot_config/private_op/private_<tool>.env` apply least privilege; wrapper functions live in `Documents/PowerShell/Scripts/lib/99-functions-body.ps1`. See `SECRETS.md` § Architecture B for the full pattern.
- **SECRETS.md** — "Architecture B: Runtime Injection via `op run`" section documenting the new pattern alongside the existing render-time pattern, with runbooks for adding tools, adding secrets to existing tools, rotation, and leakage verification.
- **Dual-mirror git remote auto-configuration**: new `.chezmoiscripts/run_onchange_after_05_chezmoi_repo_remotes.{sh,ps1}.tmpl` rewrites the chezmoi-source repo's `origin` to match the documented layout (`fetch = git@gitlab.com:Randallsm83/chezmoi.git`, dual `pushurl` for GitLab+GitHub, separate `github` remote for recovery). Closes a bootstrap gap: `README` and `chezmoi init Randallsm83/chezmoi` cloned from GitHub, producing a single-URL `origin` on every fresh install — so the GitLab mirror documented in AGENTS.md / CONTRIBUTING.md silently fell behind (observed ~11 commits behind on one box) because nothing automated the dual-pushurl layout post-clone. Script is idempotent (skips silently when already canonical) and runs `after_05` so it lands right after backup (`00`) and secret validation (`01`) but before all integration scripts.
### Changed
- **Package mapping — one source per platform; `mise_remote` no-sudo fallback for remote Linux**: `.chezmoidata.yaml`'s `package_mapping` for `lua`, `luajit`, `vim`, `luarocks`, `lua-language-server`, and `neovim` is reorganized so each tool is installed by exactly one manager per platform (no double-install). Lua-family runtimes and `vim` flow through the distro's native package manager on Linux (apt/dnf/pacman) and through Homebrew on macOS; `neovim` and `lua-language-server` are managed by mise/aqua everywhere. A new `mise_remote` key per tool lists no-sudo mise packages used as a fallback when `is_remote` is true and root is unavailable; `dot_config/mise/config.toml.tmpl` emits those entries conditionally on the remote-state flag. The WSL-specific `disable_tools` blocks were removed because the per-tool, per-platform routing no longer overlaps with mise on Unix.
- **WSL: enable `systemd=true` in `.wslconfig`**: `dot_wslconfig.tmpl` uncomments the `systemd=true` directive under `[boot]` to match Ubuntu 24.04+ defaults; without it, systemd-managed services (snapd, networkd, etc.) fail to start inside WSL2.
- **Windows Terminal: drop stale hardcoded WSL profiles**: `AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json.tmpl` removes five hardcoded profile entries for distros that aren't installed on this host. Windows Terminal's dynamic `remainingProfiles` menu entry now auto-discovers whichever WSL distros are actually registered.
- **wezterm: palette driven from chezmoi theme data; drop dead lua modules**: `dot_config/wezterm/wezterm.lua.tmpl` now consumes the unified `theme.name` data block directly via `wezterm_scheme`, replacing hand-rolled scheme tables. `tabs.lua` and `utilities.lua` shed ~570 lines of unused palette plumbing and dead helper functions; tabline and visual config read the theme through the same indirection used by neovim/starship/eza/bat/delta.
- **pam: every-apply sync triggers**: pam-sync scripts under `.chezmoiscripts/` move from `run_onchange_*` to `run_after_*`, so the pam manifest sync runs on every `chezmoi apply` instead of only when the script hash changes. Keeps pam's view of `~/.config/pam/manifest.toml` aligned with frequent MCP server edits.
- **opencode: trim plugin list, disable experimental flags**: `dot_config/opencode/opencode.json.tmpl` and `oh-my-openagent.jsonc` drop plugins that are no longer in use and turn off the experimental feature toggles that were causing instability.
- **`Microsoft.PowerShell_profile.ps1.tmpl`** — adds a guarded 1Password CLI auto-signin for interactive shells. Pairs with the cached `Invoke-OpEnsure` in `Documents/PowerShell/Scripts/80-op.ps1` (5-minute TTL, biometric-overlay suppression) so `op` is usable from the first prompt without a manual `op signin`. Skips non-interactive sessions, SSH sessions without a TTY, `CHEZMOI_SKIP_1P=1`, and already-signed-in states. Eliminates the wire-it-up-lazy-then-prompt-the-user-manually antipattern.
- **`Documents/PowerShell/Scripts/80-op.ps1`** — hardened the 1Password CLI sign-in helper. Adds a `__OP_ENSURE_TTL` cache (5 minutes) so `Invoke-OpEnsure` doesn't re-probe `op whoami` on every shell-integration call, introduces `Invoke-OpRaw`/`Get-OpFailureKind`/`Wait-OpReady` to categorize failures (missing CLI vs locked vault vs auth required vs daemon not ready vs unknown), and exposes a single `Invoke-OpEnsure` entrypoint that returns `$true` only when `op` is actually usable. Stops the prior "prompt-on-every-pane" behavior on Windows where every new wezterm tab/pane re-triggered the biometric overlay.
- **`Documents/PowerShell/Scripts/99-aliases.ps1`** — exports the same `PROJECTS`/`DHSPACE`/`BACKEND`/`FRONTEND`/`HELPSERVICES`/`NOTES`/`DOTFILES` env vars as the zsh `10-dirs.zsh` file and seeds the matching navigation aliases for pwsh sessions. Paths derive from `$HOME` via `Join-Path` so nothing is pinned to a Windows-specific user profile.
- **`Documents/PowerShell/Scripts/lib/99-functions-body.ps1`** — `cdn`/`cdapi`/`cdcdn` retargeted from `$env:PROJECTS\<repo>` to `$env:DHSPACE\<repo>` / `$env:BACKEND\<repo>` to match the actual `BACKEND`/`FRONTEND`/`HELPSERVICES` layout under `~/projects/dh`.
- **`dot_config/zsh/dot_zshrc.d/{10-dirs,25-aliases}.zsh`** — removed hardcoded `/home/rmiller/projects` from `cdp` and `dhgitall`; repo shortcuts now derive from `$DHSPACE` / `$BACKEND`.
- **`.chezmoiignore`** — excludes `dot_config/dns/**` on non-darwin hosts and when `encrypted_dns.enabled = false`.
- **`Microsoft.PowerShell_profile.ps1.tmpl`** — removed the `$env:ANTHROPIC_API_KEY = "{{ .secrets.anthropic_api_key }}"` block. The literal value was being baked into the rendered profile on disk; Claude Code now receives the key at runtime via the op-run wrapper. Replaced with an explanatory comment.
- **`.chezmoi.toml.tmpl`** — fixed unix branch of the `op inject` resolver so `[data.secrets]` stays on its own line. Whitespace trimming around `{{- if -}}` was gluing the section header onto the first key (`[data.secrets]ssh_pub_github_com = ...`), causing TOML parse failures (`expected a top-level item to end with a newline ...`) on every `chezmoi init` after pulling commit `9147c48`. Now mirrors the windows branch's `printf "\n%s"` prefix.
- **`dot_ssh/config.tmpl`** — added a darwin-gated block at the top that re-includes `~/.orbstack/ssh/config`. OrbStack auto-injects this on macOS; without it in the template `chezmoi apply` would strip the include on every run.
- **`.chezmoiignore`** — excludes `.config/docker/config.json` on darwin. The template's `credsStore: "wincred"` is Windows-only, and OrbStack/Docker Desktop owns the file on macOS (writes `currentContext`, the correct `credsStore`, etc.). Letting the local file be authoritative on darwin stops the per-apply prompt loop.
### Removed
- **`~/.claude.json` literal credentials** — Vercel `Authorization: Bearer <token>`, Neon `Authorization: Bearer <token>`, and `qdrant.env.QDRANT_API_KEY` literal values replaced with `${VERCEL_TOKEN}`, `${NEON_API_KEY}`, and `${QDRANT_API_KEY}` references resolved by `op run` at process spawn.
### Fixed
- **`winget-packages.json.tmpl`** — nested `package_mapping` lookup under `windows.winget` (was traversing `mapping.winget` directly, mismatching the actual schema in `.chezmoidata.yaml` which all other generated lists already use). Previously the rendered file contained only the `__end__` sentinel and `winget import` restored zero packages from the feature flags. Now correctly emits the 7 mapped IDs (1Password, Git, StrawberryPerl, PowerShell, VS Code, Warp, Windows Terminal). (P0-1)
- **`.chezmoiscripts/run_before_00_backup.ps1.tmpl` + `scripts/rollback.ps1`** — backup directory now honors `$env:XDG_STATE_HOME` with a `$HOME\.local\state\chezmoi\backups` fallback instead of hard-coding `$env:LOCALAPPDATA\chezmoi\backups`. Matches the documented XDG-everywhere convention (`ARCHITECTURE.md:443`) and the rest of the repo's state-dir layout. (P0-3)
- **`.chezmoiscripts/run_onchange_install-packages-unix.sh.tmpl`** — promoted from `#!/bin/sh` (no `set -*`) to `#!/usr/bin/env bash` with `set -euo pipefail`. The 375-line installer was silently swallowing failures; intentionally non-fatal call sites already use explicit `|| echo Warning` or `|| true`. Same-class fixes: `run_onchange_before_install_base_packages_unix.sh.tmpl` promoted `set -eo` → `set -euo` (with `${SUDO_USER:-}` / `${USER:-$(id -un)}` guards), and `run_after_rebuild_bat_cache.sh.tmpl` gained `set -euo pipefail` and an explicit warning on `bat cache --build` failure. (P0-1)
- **`bootstrap.Tests.ps1`** — was sourcing a non-existent `bootstrap.ps1.example`. Rewrote against the canonical `bootstrap.ps1` using Pester 5.x patterns and added coverage for `Test-DeveloperMode`, `Enable-DeveloperMode`, `Test-OnePasswordCLI`, `Invoke-PreflightChecks`, `Import-ScoopExport`, `Import-WingetExport`. `Initialize-Chezmoi` tests now exercise the new HTTPS-default plus `-UseSSH` fallback contract end-to-end. Requires Pester 5.x. (P0-1)
- **`bootstrap.ps1` `Initialize-Chezmoi`** — default chezmoi clone is now HTTPS so fresh machines without an SSH key in the 1Password agent succeed on first run. New `-UseSSH` switch attempts SSH first and automatically falls back to HTTPS on failure (mirrors `setup.sh`'s `USE_SSH=1` pattern). Explicit `https://` / `git@` URLs passed by the caller are still respected verbatim. (P0-4)
- **`dot_config/zsh/dot_zshrc.d/80-op.zsh`** — added an eager 1Password CLI sign-in block at shell startup, mirroring the pwsh `Invoke-OpEnsure` flow in `Documents/PowerShell/Scripts/80-op.ps1`. Probes `op vault list`; on failure runs `op signin` non-interactively (desktop biometric prompt is system-modal, no stdin needed) and re-probes. Successful sign-in is cached for 300 s under `$XDG_CACHE_HOME/op/last-signin` so subsequent shells / tmux panes don't hammer the integration. Guards: skipped when the shell is non-interactive, stdin is not a TTY, `OP_SERVICE_ACCOUNT_TOKEN` is set, or `OP_AUTOSIGNIN_DISABLE` is set. (P0-5)
- **`.chezmoiscripts/run_after_71_opencode_pam_sync.sh.tmpl`** — added the missing Unix sibling for opencode's pam-pointer re-inject hook. Claude Code already had both `.sh.tmpl` (Unix) and `.ps1.tmpl` (Windows) syncs, and opencode had the `.ps1.tmpl`, but the Unix opencode variant was never created in cb8a04d ("feat(mcp): migrate MCP ownership from chezmoi-rendered to pam") or ea6766b ("chore(pam): switch pam-sync scripts to every-apply triggers"). On Linux/macOS, every `chezmoi apply` re-rendered `~/.config/opencode/opencode.json` with `"mcp": {}` and nothing re-asserted the `mcp.pam` pointer, so opencode silently lost its MCP backend until a manual `pam sync --client opencode`. New script mirrors the claude-code Unix script's guard pattern (skip if `pam` not on PATH or daemon not running).
- **`.chezmoiscripts/run_onchange_before_install_base_packages_unix.sh.tmpl`** — closing of the dropped-Homebrew explanation comment used the right-trim form `*/ -}}`, which eats the newline between the perl-symlink block's `fi` and the next line's `# Set zsh as default shell` comment. Bash then parses `fi#` as a single word (not the `fi` keyword followed by a comment), leaving the `if [ -d /usr/bin/core_perl ] …; then` block unclosed and breaking `chezmoi apply` on every Linux host with `syntax error: unexpected end of file from \`if' command on line 242`. Changed to `*/}}` so the trailing newline is preserved.
- **`dot_config/opencode/tui.json.tmpl`** — adds `"plugin": ["oh-my-openagent/tui"]` so the OmO TUI plugin loads alongside the already-declared server plugin in `opencode.json`. Without this entry, oh-my-openagent's extra agents (`sisyphus`, `hephaestus`, `prometheus`, `oracle`, `atlas`, `metis`, `momus`, `librarian`, `sisyphus-junior`, `multimodal-looker`, `explore`) and the Roles · Models sidebar section never appeared in the opencode agent picker, even though their tools were available to the model. Surfaced by `oh-my-openagent doctor` ("TUI plugin entry missing from tui.json"); fix matches the installer's auto-write behavior.
---

## [2.0.0] - 2025-01-20

### 🎉 Major Release - Complete Rewrite

Version 2.0 represents a complete architectural rewrite focused on cross-platform support, maintainability, and user-space installation.

### ✨ Added

#### Template System
- **Reusable Template Library**: Created 4 core templates (~1200 lines)
  - `common-header.tmpl` - Shell setup, error handling, logging functions
  - `platform-detect.tmpl` - OS/distro/WSL/container detection
  - `package-manager.tmpl` - Cross-platform package abstraction
  - `1password.tmpl` - Secrets integration

#### Remote Machine Support
- **Remote Detection**: Automatic SSH/VSCode Remote/container detection
- **Minimal Package Sets**: Lightweight configs for remote servers
- **No-Sudo Support**: User-space installations via mise
- **Remote Config**: Dedicated `config.remote.toml` for minimal environments
- **REMOTE.md**: 500+ line guide for remote machine setup

#### Configuration Management
- **Machine Detection**: Automatic classification (personal/work/remote/container)
- **Permission Detection**: Runtime sudo capability checking
- **Feature Flags**: Granular control over optional configurations
- **Local Overrides**: `.chezmoi.local.toml` for machine-specific settings
- **Smart Defaults**: Context-aware based on machine type

#### Backup & Rollback
- **Automatic Backups**: Pre-apply backups with metadata
- **Rollback Scripts**: Unix (`rollback.sh`) and Windows (`rollback.ps1`)
- **Retention Policy**: Keep last 10 backups automatically
- **Cross-Platform**: Works on Windows, Linux, macOS

#### Package Management
- **Mise Integration**: Unified runtime/tool manager for all platforms
- **Platform Strategy**: 
  - Windows: scoop (CLI) + winget (GUI) + mise (runtimes)
  - Linux/macOS: mise (everything)
  - Remote: mise only (user-space)
- **Conditional Installation**: Smart package selection based on environment
- **Remote Minimal**: Reduced package set for limited environments

#### Security & Secrets
- **1Password Integration**: Comprehensive secret management
- **Age Encryption**: File encryption support
- **Validation Scripts**: Pre-apply secret verification
- **SECRETS.md**: 500+ line secrets management guide

#### Monitoring & Maintenance
- **Health Check Script**: Comprehensive system validation
  - Chezmoi state verification
  - Tool version checking
  - Outdated package detection
  - Disk usage analysis
- **Status Dashboard**: Real-time configuration status

#### Documentation
- **ARCHITECTURE.md**: Complete architecture documentation (500+ lines)
- **CONTRIBUTING.md**: Development and contribution guide (500+ lines)
- **REMOTE.md**: Remote machine setup guide (500+ lines)
- **SECRETS.md**: Secrets management guide (500+ lines)
- **Enhanced README**: Updated with v2.0 features
- **INSTALL-GUIDE.md**: Platform-specific installation instructions

### 🔄 Changed

#### Configuration Consolidation
- **40% Duplication Reduction**: Consolidated overlapping configs
- **Reorganized Structure**: Clear separation of concerns
- **Improved Naming**: Consistent, descriptive file names

#### Bootstrap Scripts
- **Enhanced setup.sh**: 
  - Pre-flight validation (4 checks)
  - Sudo detection with graceful fallback
  - Progress indicators
  - Error recovery
- **Enhanced bootstrap.ps1**:
  - Pre-flight validation (5 checks)
  - Developer Mode detection/enablement
  - 1Password CLI integration
  - Better error handling

#### Platform Support
- **Windows**: Developer Mode auto-detection, improved symlink support
- **Linux**: Distro-specific optimizations (Ubuntu/Arch/Fedora)
- **macOS**: Native Zsh support, Homebrew for GUI only
- **WSL**: Optimized for WSL2, proper Windows interop
- **Remote**: No-sudo, minimal footprint, fast bootstrap

### 🗑️ Removed

- **ASDF**: Replaced with mise
- **NVM**: Replaced with mise node management
- **Deprecated Configs**: php, diff-so-fancy (cleaned up)
- **Legacy Scripts**: Consolidated into template system

### 🐛 Fixed

- **Template Variables**: Fixed `.user.*` → direct access (`.name`, `.email`)
- **Git Config**: Corrected Windows conditional includes
- **PowerShell Profile**: Fixed theme variable references
- **Package Lists**: Removed duplicates and conflicts
- **Cache Directories**: Proper Windows exclusions for `.cache/zsh/**`

### 📦 Package Changes

#### Added
- mise (replaces asdf/nvm)
- sqlite
- fzf (moved to scoop on Windows)

#### Removed
- asdf
- nvm  
- diff-so-fancy
- php (not actively used)

#### Clarified Strategy
- **Runtimes** (mise): node, python, ruby, go, rust, zig, bun, deno, lua
- **CLI Tools** (scoop on Windows, mise on Unix): bat, eza, fd, ripgrep, starship, neovim
- **Universal Tools** (mise everywhere): direnv, uv, yarn

### 🎯 Platform-Specific

#### Windows
- Developer Mode detection and enablement
- Scoop + Winget + Mise strategy
- PowerShell 7+ profile enhancements
- Windows Terminal auto-configuration

#### Linux/WSL
- Mise-first approach (no system packages unless needed)
- Distro detection (Ubuntu/Arch/Fedora/etc.)
- Zsh as primary shell
- XDG Base Directory compliance

#### macOS
- Homebrew for GUI apps only
- Mise for all CLI tools and runtimes
- Native Zsh support
- macOS-specific configs (karabiner, etc.)

#### Remote/SSH
- Automatic detection
- Minimal package installation
- No-sudo support
- Reduced disk footprint
- User-space only installations

### 📊 Statistics

- **Files Created**: 15+ new files
- **Files Modified**: 10+ existing files  
- **Lines Added**: ~5000+ lines of code and documentation
- **Templates**: 4 reusable templates (~1200 lines)
- **Documentation**: 2000+ lines across 5 guides
- **Duplication Reduced**: 40%

### 🔐 Security

- Enhanced secrets management with 1Password
- Age encryption support
- Pre-apply validation scripts
- Automatic backups before changes
- No secrets in version control (enforced)

### ⚡ Performance

- Parallel mise installations (4 jobs)
- Reduced package count on remote
- Cached downloads
- Faster bootstrap with pre-checks

### 🧪 Testing

- Health check script for validation
- Dry-run support throughout
- Backup/rollback capabilities
- Template validation tools

---

## [1.0.0] - 2024-12-01

### Initial Release

- Basic dotfiles for Windows, Linux, macOS
- Git, Zsh, Neovim configurations
- PowerShell profile
- WezTerm terminal config
- Manual package management
- Limited cross-platform support

---

## Links

- [Repository](https://github.com/Randallsm83/dotfiles)
- [Issues](https://github.com/Randallsm83/dotfiles/issues)
- [Compare v1.0...v2.0](https://github.com/Randallsm83/dotfiles/compare/v1.0.0...v2.0.0)

---

## Migration Guide

### From v1.0 to v2.0

**Breaking Changes**:
- Package managers: asdf/nvm → mise
- Configuration structure changed significantly
- Template variables renamed

**Migration Steps**:

1. **Backup current dotfiles**:
   ```bash
   chezmoi archive > ~/dotfiles-backup-v1.tar.gz
   ```

2. **Clean existing installation**:
   ```bash
   # Remove old chezmoi state
   rm -rf ~/.local/share/dotfiles
   rm -rf ~/.config/chezmoi
   ```

3. **Install v2.0**:
   ```bash
   # Unix
   sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply Randallsm83/dotfiles
   
   # Windows
   .\bootstrap.ps1
   ```

4. **Migrate custom configs**:
   - Review old configs
   - Add overrides to `.chezmoi.local.toml`
   - Manually merge custom changes

5. **Verify installation**:
   ```bash
   ./scripts/healthcheck.sh  # Unix
   ```

**Notes**:
- mise will automatically migrate tool versions
- 1Password integration is optional
- Secrets must be reconfigured (see SECRETS.md)
- Remote machines now work out of the box

---

## Support

- 📖 [Documentation](./README.md)
- 🐛 [Report Issues](https://github.com/Randallsm83/dotfiles/issues)
- 💬 [Discussions](https://github.com/Randallsm83/dotfiles/discussions)
- 🤝 [Contributing](./CONTRIBUTING.md)

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Fixed
- **OMP local broker-token wrapper**: zsh and PowerShell `omp` wrappers now prefer `~/.omp/auth-broker.token`, set `OMP_AUTH_BROKER_URL` to `http://raspi.***REMOVED***.ts.net:8765` when unset, and only fall back to `op run ~/.config/op/omp.env` when the local token is unavailable. This keeps `omp` working without a 1Password unlock/prompt loop.

- **`mpmise -Extended` WinGet fallback**: when `mpm` hits its WinGet extended-search table parser crash (`ValueError: not enough values to unpack`), `mpmise` now warns and retries the same search without WinGet instead of failing the whole resolver.

- **`dog` → `doggo` on macOS (arm64)**: `github:ogham/dog` ships no `arm64-apple-darwin` release asset (only `x86_64-apple-darwin`), so `mise install` failed with "No matching asset found for platform macos-arm64" on Apple Silicon. Replaced the darwin `package_mapping.rust_alternatives.darwin.mise` `github:ogham/dog` entry with the maintained `doggo` DNS client installed via `brew` (no arm64 GitHub asset, same as navi/dust/ouch). Windows and Linux keep `github:ogham/dog` (their `x86_64` assets resolve). The `rust-tools` inventory (zsh `80-rust-alternatives.zsh`, pwsh `99-functions-body.ps1`) now lists `doggo` alongside `dog`.

- **Per-machine package feature overrides**: `.chezmoi.toml.tmpl` now reads `.chezmoi.local.toml` `[data.package_features]` overrides instead of only documenting the file, while keeping theme overrides under `[data.theme]` so templates still receive `.theme.name` as a map.
- **macOS apply script compatibility**: replaced Bash 4-only `declare -A`/`mapfile` usage in the Unix VPN DNS and VS Code extension installers, and made the bat template fall back cleanly when a theme mapping is absent.
- **OMP auth-broker systemd scope**: the managed user service is now rendered only on Raspberry Pi homelab hosts via both `.chezmoiignore` and the service template guard.

### Added
- **Cross-shell `mpmise` command**: added managed `~/.local/bin/mpmise`, `mpmise.py`, and `mpmise.cmd` shims so the mise-target resolver works from PowerShell without profile functions and from Bash/zsh-style shells. The PowerShell profile function now delegates to the shim when present, and OMP's non-interactive Bash environment routes Windows shells through the `.cmd` wrapper.
- **Additional shell completions + tealdeer config**: expanded cached completion wiring across PowerShell `Documents/PowerShell/Scripts/20-completions.ps1` and zsh `dot_config/zsh/dot_zshrc.d/80-completions.zsh` for more installed CLIs (`arduino-cli`, `deno`, `glow`, `just`, `lazygit`, `procs`, `taplo`, `uv`, `xh`, `yq`) and added `dot_config/tealdeer/config.toml.tmpl` so tealdeer reads its cache/config from the managed XDG path.
- **Shell parity and guard linter**: added `scripts/lint-shell-parity.ps1` and wired it into `scripts/test.ps1` so Windows validation catches unguarded tool environment variables and PowerShell feature-flag gating regressions before they leak into user shells.
- **OMP homelab auth-broker/gateway helpers + shared agent config**: new `dot_omp/agent/config.yml.tmpl` makes `~/.omp/agent/config.yml` chezmoi-managed across Windows and WSL with a single shared baseline (provider/web-search/image choices, status-line + display styling, model roles, thinking/steering/follow-up behavior, STT, compaction handoff, mnemopi scoping). A companion `dot_omp/agent/dot_env.tmpl` now renders runtime env cross-platform: Windows/Git Bash uses `BASH_ENV=~/.config/omp/agent-bash-env` and zsh hosts use `OMP_AGENT_SHELL=1` so non-interactive OMP commands inherit the managed PATH, aliases, functions, and MCP timeout without local shell drift.
- **`tin-summer` + `dog` Rust CLI alternatives**: added `cargo:tin-summer` (`sn`, big-file/disk-usage finder) and `github:ogham/dog` (`dog`, DNS lookup client) to `package_mapping.rust_alternatives.{windows,linux,darwin}.mise` so `dot_config/mise/config.toml.tmpl` installs them everywhere `rust_alternatives` is enabled. Both are registered in the `rust-tools` inventory command (zsh `dot_config/zsh/dot_zshrc.d/80-rust-alternatives.zsh` and pwsh `Documents/PowerShell/Scripts/lib/99-functions-body.ps1`) so they show up under the 🦀 Rust CLI Alternatives listing.
- **Standalone Qdrant/Tavily MCP config**: added `dot_mcp.json.tmpl` so `~/.mcp.json` exposes `qdrant` and `tavily` directly across Windows, Linux, and macOS. Claude Code gets the same standalone entries via `run_after_71_claude-code_mcp_sync_{windows,unix}` because `~/.claude.json` is runtime-managed and intentionally ignored by chezmoi.
- **Atuin shell-history integration**: added `package_features.atuin` + `package_mapping.atuin` for Unix installs via `mise` (`cargo:atuin`), taught `dot_config/mise/config.toml.tmpl` to emit the tool when enabled, added cached zsh completion generation in `dot_config/zsh/dot_zshrc.d/80-completions.zsh`, and introduced `dot_config/zsh/dot_zshrc.d/80-atuin.zsh` to initialize Atuin without stealing the existing `fzf` `Ctrl-R` or arrow-key history bindings. Atuin is bound on `Alt-R` in emacs/vi insert/vi command keymaps instead.
- **`dot_config/eza/themes/tokyonight-storm.yml`** (wave-d-innovation): authored the missing eza theme using the canonical `theme.tokyonight-storm` palette in `.chezmoidata/theme.yaml`, mapped onto the same slot layout as `kanagawa.yml`/`spaceduck.yml`. `theme_mappings.eza.tokyonight-storm` is re-pointed from the `tokyonight-night` workaround to `"tokyonight-storm"`, removing the wave-c fallback.
- **`dot_config/vivid/themes/kanagawa.yml`** (wave-d-innovation): authored the missing vivid theme using the canonical `theme.kanagawa` palette in `.chezmoidata/theme.yaml`, mapped onto the `spaceduck.yml` shape. `theme_mappings.vivid.kanagawa` is re-pointed from the `molokai` fallback to `"kanagawa"`, removing the fallback comment.
- **Bootstrap JSON status artifact** (wave-d-innovation): both `bootstrap.ps1` and `setup.sh` now emit `$env:XDG_STATE_HOME\dotfiles\bootstrap-status.json` (resp. `$XDG_STATE_HOME/dotfiles/bootstrap-status.json`, with the documented `$HOME\.local\state\` / `$HOME/.local/state/` fallback) at the end of a successful bootstrap run. Payload includes ISO-8601 `timestamp`, `version`, `host`, `platform`, a `chezmoi` block (`version`, `sourceDir`, `hasUncommittedChanges`), the in-memory `stats` object, and total `durationSeconds`. `scripts/healthcheck.ps1` and `scripts/healthcheck.sh` now read the file in a new `Last Bootstrap` section (handles the missing-file case gracefully on hosts that haven't bootstrapped under the new code yet).
- **Structured exit codes for bootstrap scripts** (wave-d-innovation): `bootstrap.ps1` defines `$ExitCode = @{ Success=0; Preflight=10; ScoopInstall=20; WingetImport=21; ScoopImport=22; ChezmoiInit=30; ChezmoiApply=40; NoSshKey=50; Unknown=99 }`; `setup.sh` mirrors the same numbers in readonly shell variables (`E_SUCCESS=0`, `E_PREFLIGHT=10`, …). Every `exit 1` was replaced with the appropriate named code so CI / wrappers can branch on the failure mode. `INSTALL-GUIDE.md` Appendix gains a `Bootstrap exit codes` table documenting the map.
- **Retry/backoff helpers for bootstrap network calls** (wave-d-innovation): `bootstrap.ps1` gains `Try-WithBackoff -ScriptBlock { ... } -MaxAttempts 4 -BaseSeconds 2 -Operation '<label>'` which performs bounded exponential backoff (capped at 60 s between attempts) and emits every retry through `Write-Status` so the per-script log mirror under `$env:XDG_STATE_HOME\dotfiles\logs\` captures the full attempt history; the github.com reachability probe in `Invoke-PreflightChecks` and the `Invoke-RestMethod -Uri https://get.scoop.sh` install site in `Install-Scoop` are now wrapped through it. `setup.sh` gains a matching `retry_with_backoff <label> <max_attempts> <base_seconds> -- <cmd...>` helper; the github.com probe in `run_preflight_checks` and the `curl -fsLS get.chezmoi.io` installer download in `install_and_apply_dotfiles` are now wrapped. Final-attempt failures raise structured errors that map to the new exit code map (item 6).
- **INSTALL-GUIDE.md troubleshooting decision tree** (wave-d-innovation): the Troubleshooting appendix gains a mermaid `graph TD` keyed off the most common diagnostic commands (`chezmoi doctor`, `chezmoi diff`, `mise doctor`, `scoop status`, `op signin`). The tree is an index that points down at the existing Problem/Solution prose, which is preserved untouched for detail.
- **README.md mental-model diagram** (wave-d-innovation): new `🔍 How it all fits together` section just below the quick-start renders a mermaid `flowchart LR` that traces `.chezmoi.toml.tmpl` + `.chezmoi.local.toml` → `.chezmoidata/*.yaml` (theme/fonts/ssh/packages/dns/mcp) → `.chezmoitemplates/*` partials → templates and `.chezmoiscripts/*` → `$HOME`/`$XDG_CONFIG_HOME`. Dashed edges show how `.chezmoiignore` gates both templates and scripts. Renders on both GitLab and GitHub markdown viewers without extra plugins.
- **Shared PowerShell logging partial `.chezmoitemplates/ps-logging`** (wave-d-innovation): canonical `Write-Status` + `Write-LogLine` + `Get-StatusLogFile` helpers consumed by chezmoi-rendered `.ps1.tmpl` scripts via `{{ template "ps-logging" . }}`. Both helpers mirror every line into `$env:XDG_STATE_HOME\dotfiles\logs\<script>.log` (falls back to `$HOME\.local\state\dotfiles\logs\<script>.log` per the user XDG-everywhere rule). The two plain `.ps1` consumers that pre-date chezmoi on the box (`bootstrap.ps1`, `scripts/rollback.ps1`) inline the same verbatim body and reference the canonical template in a header comment so both sites stay in lockstep. `.chezmoiscripts/run_before_00_backup.ps1.tmpl` now consumes the partial directly.
- **Split `.chezmoidata.yaml` into `.chezmoidata/*.yaml`** (wave-d-innovation): the 1,835-line monolithic data file is split into focused sub-files that chezmoi merges into the same template namespace at apply time. Layout: `.chezmoidata/theme.yaml` (theme + theme_mappings), `.chezmoidata/fonts.yaml`, `.chezmoidata/ssh.yaml`, `.chezmoidata/packages.yaml` (package_features, package_mapping, brew_bundle, scoop_buckets, scoop_bucket_overrides, always_install, remote_packages, claude_memory_projects), `.chezmoidata/dns.yaml` (vpn_dns_routes, encrypted_dns, browser_doh, caddy_ca). The previously-existing `.chezmoidata/mcp.yaml` stays as-is. `chezmoi data` output is byte-identical pre/post-split (verified 51,606 bytes both runs). The legacy `.chezmoidata.yaml` is removed; `AGENTS.md` and `ARCHITECTURE.md` updated to describe the new layout.
- **Package mapping: codify installed scoop+winget drift**: `.chezmoidata.yaml` gains five new feature flags (`productivity`, `password_managers`, `browsers`, `media`, `vpn`) and their `package_mapping` entries, plus drift additions to existing `zed`, `rust_alternatives`, `ai_tools`, `gaming`, `docker`, `hardware_tools`, `windows_utilities`, `network_tools`, and `dev_extras` mappings — covering 22 scoop apps and 30+ winget apps that were installed on the Windows host but not declared. `scoop_bucket_overrides` gains a `nonportable` bucket entry (equalizer-apo-np, peace-np), moves `openscad-dev` to `versions`, adds the new extras-bucket apps, and drops the failed `pritunl-client` (moved to vpn.winget) and `windowsdesktop-runtime-10.0` (transitive winget dep). The winget side will render once wave-a fixes the `windows.winget` path in `winget-packages.json.tmpl`.
- **Unix `.chezmoiscripts/run_after_72_warp_mcp_sync.sh.tmpl`**: Linux/macOS sibling for the existing Windows warp-mcp-sync script. Renders the `1password` MCP entry from `.chezmoidata/mcp.yaml`'s `mcp.servers["1password"]` and merges it into `~/.warp/.mcp.json` via `jq` without touching Warp's runtime-managed entries. Closes a parity gap where Linux/macOS hosts had no chezmoi-managed reconciliation of the Warp MCP file.
- **Windows `.chezmoiscripts/run_onchange_generate_opencode_themes_windows.ps1.tmpl`**: pwsh counterpart to `run_onchange_generate_opencode_themes.sh.tmpl`. Generates all seven opencode JSON theme files from `.chezmoidata.yaml` `theme:` palettes into `$env:XDG_CONFIG_HOME\opencode\themes\`. Idempotent (sha-compares before overwriting) and emits LF-terminated JSON so the output is byte-for-byte identical to the Unix sibling.
- **Windows `.chezmoiscripts/run_onchange_before_01_validate-secrets.ps1.tmpl`**: pwsh secrets-validation gate that runs before all other Windows apply scripts. Probes `op` on PATH + authentication, optionally verifies required 1Password items via `op item get`, and fails loud when secrets are missing so downstream templates don't silently render with empty `.secrets.*` values.
- **`scripts/healthcheck.ps1`**: Windows counterpart to `scripts/healthcheck.sh`. Mirrors every Unix section (chezmoi state, essential tools, mise, shell, git, disk usage) and adds Windows-specific checks for Unbound service state, 1Password SSH agent named pipe, Developer Mode registry key, and Caddy root cert trust. Uses the same `Write-Status -Type Info/Success/Warning/Error` helper shape as `bootstrap.ps1:79-108`.
- **`scripts/test.ps1`**: Windows counterpart to `scripts/test.sh`. Lightweight pass/fail framework over the equivalent test cases (chezmoi cmd, scoop, mise, pwsh profile, git user.*, op CLI, Developer Mode, XDG-resolvable, chezmoi diff/data). Exits `0` on all-pass, `1` on any failure.
- **wezterm terminfo installer (Windows)**: new `feat(wezterm-win)` flow ships a checked-in `wezterm-terminfo/wezterm.terminfo` source and a `run_onchange_*` PowerShell installer under `.chezmoiscripts/` that compiles the entry into the local `terminfo` database. Without it, MSYS/Git-Bash pagers (`less`, `man`, `git log`) launched from wezterm on Windows render broken when `TERM=wezterm`. The `wezterm-terminfo/` source directory is excluded from `$HOME` deployment via `.chezmoiignore`.
- **wezterm: resurrect.wezterm + zoxide workspaces + tool overlays + broadcast + which-key**: `dot_config/wezterm/keymaps.lua` gains session save/load via [`resurrect.wezterm`](https://github.com/MLFlexer/resurrect.wezterm) (`LEADER+A` save, `LEADER+E` load), a zoxide-backed workspace picker (`LEADER+J`), tool overlays (`LEADER+X` then `g`/`t`/`n`/`o` for `lazygit`/`btop`/`nvim`/`opencode`), broadcast-to-panes toggle (`LEADER+B`), and a which-key style launcher (`LEADER+?`). The Spaceduck color scheme (`dot_config/wezterm/colors/Spaceduck.toml`, `wezterm.lua.tmpl`) is refreshed: corrected ANSI/brights mapping, distinct selection/visual-bell/tab/scrollbar tokens, and the palette is now mirrored in `wezterm_scheme` for tabline/UI accent consumers.
- **`git land` alias + mirrored-remote merge workflow**: new alias in `dot_config/git/config.tmpl` codifies the canonical "merge a feature branch into main" flow when the repo is mirrored across hosts (e.g. GitLab + GitHub on a dual-push `origin`). Merges locally with `--no-ff --no-edit` (or `--ff-only` via `GIT_LAND_FF=1`), pushes once to `origin` so both remotes get the same SHA, and deletes the local feature branch (skip with `GIT_LAND_KEEP=1`). Refuses to land `main`/`master` onto itself. `CONTRIBUTING.md` gains a "Merging (mirrored remotes)" section explaining the divergence problem (clicking Merge in both web UIs creates two different squash SHAs → subsequent pushes rejected with `fetch first`), the canonical workflow, and how to recover with `--force-with-lease` after verifying matching trees.
- **VS Code extensions managed by chezmoi**: `vscode/extensions.txt` is the single source of truth (one extension ID per line, `#` comments allowed). `run_onchange_after_70_vscode-extensions_{windows,unix}.{ps1,sh}.tmpl` diffs the list against `code --list-extensions` on every `chezmoi apply` and installs only the missing ones (additive — never uninstalls). Gated by `package_features.vscode` and presence of the `code` CLI on PATH.
- **Workspace environment variables**: `PROJECTS`, `DHSPACE`, `BACKEND`, `FRONTEND`, `HELPSERVICES`, `NOTES` exported from `dot_config/zsh/dot_zshrc.d/10-dirs.zsh` (zsh) and `Documents/PowerShell/Scripts/99-aliases.ps1` (pwsh). All paths derive from `$HOME` via `Join-Path` (pwsh) / `$HOME/...` (zsh) — no hardcoded Windows paths. Structure: `PROJECTS = $HOME/projects`, `DHSPACE = $PROJECTS/dh`, `BACKEND/FRONTEND/HELPSERVICES = $DHSPACE/<bucket>`, `NOTES = $PROJECTS/notes`.
- **Navigation shortcuts** (zsh aliases / pwsh functions, guarded by directory existence on pwsh):
  - Workspace roots: `cdp`, `dh`, `cdbe`, `cdfe`, `cdhs`, `dots`, `notes`
  - Top-level DH repos: `cdn` (ndn), `cdaudit` (ndn-audit), `cdscott`, `cdtm` (task-management)
  - Common backend services: `cdapi` (api-gateway), `cdcdn` (cdn-service)
- **`dhgitall`**: cross-platform helper (zsh + pwsh) that runs a `git` command across every repo under `$BACKEND/`, `$FRONTEND/`, `$HELPSERVICES/`. Skips entries without a `.git` directory. Top-level repos (ndn, scott, etc.) are intentionally excluded — use them individually when you need to.
- **Encrypted DNS profile (macOS)**: New `encrypted_dns` block in `.chezmoidata.yaml` plus `dot_config/dns/private_pihole-dot.mobileconfig.tmpl` and `.chezmoiscripts/run_onchange_after_56_encrypted-dns.sh.tmpl` install a `com.apple.dnsSettings.managed` profile pinning the system resolver at `***REMOVED***:853` over DoT. TCP-probes the endpoint before installing; skips with a warning if the Pi-side terminator isn't up yet. Encrypts the LAN leg of DNS that was previously plaintext UDP/53.
- **Browser DoH disable (macOS)**: New `browser_doh` block in `.chezmoidata.yaml` plus `.chezmoiscripts/run_onchange_after_57_browser-doh-policies.sh.tmpl` writes managed-policy files for Firefox (`policies.json`), Chrome, Edge, and Brave (`/Library/Managed Preferences/<bundle>.plist`) so they respect the system resolver instead of bypassing Pi-hole via Mozilla/Cloudflare DoH.
- **Pi-side DoT terminator setup**: `scripts/setup-pihole-dot.sh` installs `unbound`, mints a TLS cert via `tailscale cert`, and forwards plain DNS to Pi-hole. Run on the Pi, not the Mac.
- **RASPI.md** — "Encrypted DNS (DoT terminator)" section documenting the Pi-side prerequisite.
- **DNS.md** — full DNS architecture reference: resolver hierarchy, where each component lives in the chezmoi source, browser DoH disable mechanics, verification commands, and past failure modes (unbound validator/localhost defaults, deprecated `profiles install`, `/Library/Managed Preferences/` requiring MDM, the wrong-vault `raspi.pub` template).
- **Runtime secret injection via `op run` (Pattern B)**: wraps CLIs that read API keys at launch (claude, opencode) so secrets are resolved from 1Password via `op run --env-file=~/.config/op/<tool>.env -- <tool>` and only ever live in the child process's env. Per-tool env files in `dot_config/private_op/private_<tool>.env` apply least privilege; wrapper functions live in `Documents/PowerShell/Scripts/lib/99-functions-body.ps1`. See `SECRETS.md` § Architecture B for the full pattern.
- **SECRETS.md** — "Architecture B: Runtime Injection via `op run`" section documenting the new pattern alongside the existing render-time pattern, with runbooks for adding tools, adding secrets to existing tools, rotation, and leakage verification.
- **Dual-mirror git remote auto-configuration**: new `.chezmoiscripts/run_onchange_after_05_chezmoi_repo_remotes*` scripts rewrite the chezmoi-source repo to the current split-remote layout (`origin` = GitLab canonical, `github` = GitHub mirror) and strip stale dual-`pushurl` entries left by the old fan-out-on-`origin` model. Multi-host pushes now go through `git pushall`, which pushes `origin` then `github` serially with bounded retry so both mirrors converge on one SHA without concurrent 1Password SSH-agent signing. Closes a bootstrap gap: `README` and `chezmoi init Randallsm83/chezmoi` cloned from GitHub, producing a single-URL `origin` on every fresh install — so the GitLab mirror documented in AGENTS.md / CONTRIBUTING.md silently fell behind (observed ~11 commits behind on one box) because nothing automated the mirror layout post-clone. The scripts are idempotent (skip silently when already canonical) and run `after_05` so they land right after the source repo exists.
- **Portable SSH shell helpers**: added `portable-shell.sh`, `ssh-portable`, and `pssh`/`psshs` zsh aliases for loading the managed shell conveniences on remote hosts without writing config files there.

### Changed
- **OMP gateway model helpers split**: `ompg-models` now lists models through the broker, and a dedicated `ompg-api-models` queries the public gateway `/models` endpoint with the gateway token (`Get-OmpGatewayToken` on pwsh). The two concerns were previously conflated in a single helper. Mirrored across zsh `dot_config/zsh/dot_zshrc.d/25-functions.zsh` and pwsh `Documents/PowerShell/Scripts/99-functions.ps1` + `Documents/PowerShell/Scripts/lib/99-functions-body.ps1`.
- **PowerShell profile helper loading hardened**: `Documents/PowerShell/Microsoft.PowerShell_profile.ps1.tmpl` and `Documents/PowerShell/Scripts/30-gsudo.ps1` make helper-script dot-sourcing more robust so a single failing helper no longer aborts profile load.
- **WSL bootstrap avoids Windows interop**: `.chezmoiscripts/run_onchange_after_05_chezmoi_repo_remotes.sh.tmpl` now branches on WSL — fetch flows over GitHub HTTPS (`origin`/`github` fetch = `https://github.com/Randallsm83/chezmoi.git`) while SSH `pushurl`s are retained for GitLab/GitHub, so `chezmoi update` works on distros where Windows `.exe` interop is unavailable. `dot_config/git/config.tmpl` drops the hardcoded WSL `core.sshCommand = /mnt/c/.../ssh.exe` in favor of the PATH-selected native `ssh` (1Password agent wiring via `~/.ssh/config` when present). `.chezmoiscripts/run_onchange_before_install_base_packages_unix.sh.tmpl` repairs a stale `/usr/local/bin/op` Windows-bridge shim, pointing it at the native Linux `op` when interop can't execute the `.exe`.
- **zsh startup: ~39% faster interactive+login startup** (measured **284 ms → 174.28 ms** via `hyperfine 'zsh -l -i -c exit'` on the WSL full/antidote profile). `dot_config/zsh/dot_zshrc.d/00-helpers.zsh` now provides `zsh_cache_eval <name> <cmd> [args...]`, which sources a tool's shell-init output from a version-keyed cache under `$XDG_CACHE_HOME/zsh/init/`, regenerating only when the resolved binary is newer (`$commands[...]` lookup + `-nt`, no fork) — same contract as `eval "$(<tool> init zsh)"`, just cached. Applied to `mise activate` (`50-mise.zsh`), `zoxide init` (`80-zoxide.zsh`), `atuin init` (`80-atuin.zsh`), `fzf --zsh` (`80-fzf.zsh.tmpl`), and the `dircolors`/`gdircolors` fallback in `dot_zshrc.tmpl`; both cache helpers now also `zcompile` their generated cache scripts and refresh the `.zwc` when stale; `90-starship.zsh` uses a Starship-specific cache helper that inlines the otherwise source-time `PROMPT2="$(starship prompt --continuation)"` spawn into the cached init script while still regenerating when the Starship binary or `STARSHIP_CONFIG` changes; `80-op.zsh` now loads completions via the existing async `_gen_completion_runtime` helper instead of a synchronous `eval "$(op completion zsh)"`; `80-bat.zsh` and `80-ripgrep.zsh` now refresh completions only when the cached file is missing/stale (and `80-ripgrep.zsh` also avoids the `$(dirname ...)` fork and only exports `RIPGREP_CONFIG_PATH` when the file exists, eliminating the startup warning); the full antidote path in `dot_zshrc.tmpl` switches to antidote’s upstream static-bundle fast path (rebuild `.zsh_plugins.zsh` only when `.zsh_plugins.txt` or `antidote.zsh` is newer, then source the static bundle directly, with a lazy `antidote()` wrapper kept for ad-hoc maintenance), and now precompiles the heaviest sourced plugin files when their `.zwc` is missing or stale (`zsh-syntax-highlighting.zsh`, `main-highlighter.zsh`, `zsh-autosuggestions.zsh`); `99-warp.zsh` now emits Warp’s OSC hook only when `TERM_PROGRAM=WarpTerminal`; `zsh-users/zsh-history-substring-search` is now deferred via antidote `kind:defer` (verified by a PTY check to still load after first prompt); `80-eza.zsh.tmpl` uses `$commands[...]` checks instead of `command -v` for `vivid`/`eza`; `30-misc.zsh` replaces startup-time `tput` calls for `LESS_TERMCAP_md` / `LESS_TERMCAP_me` with equivalent raw ANSI escapes; and several remaining startup-only shell forks were replaced with native parameter expansion / deferred execution (e.g. `make`/`ninja` become functions so `nproc` runs only when invoked, and `dirname`/`which`-style startup probes in the env-setup fragments were converted to `:h` / `${commands[...]}`). Also fixed local CRLF working-tree drift in three homelab fragments that chezmoi would otherwise have rendered as `^M`-broken files into the live shell.
- **Windows package routing**: moved mise-capable CLI tools out of Scoop and into mise (`gh`, lazygit, neovim, starship, fzf, fastfetch, topgrade, lua-language-server, Rust CLI alternatives, sqlite, claude/opencode, jq/yq, zls, taplo), and taught the Windows package installer to process `always_install.mise` entries explicitly. Windows mise is now documented as owning supported CLI tools as well as language runtimes.
- **mise tools use bare registry names**: `package_mapping.*.mise` and `always_install.mise` now reference mise registry short names (`usage`, `bat`, `ripgrep`, `fd`, `eza`, `delta`, `zoxide`, `vivid`, `coreutils`, `navi`, `sd`, `dust`, `hyperfine`, `just`, `tokei`, `xh`, `topgrade`, `atuin`, `zls`, `taplo`, `lua-language-server`) instead of backend-qualified specs (`aqua:jdx/usage`, `github:sharkdp/bat`, `cargo:eza`, …). Backend prefixes are retained only for tools mise has no registry shorthand for (`cargo:tealdeer`, `cargo:tin-summer`, `github:dalance/procs`, `aqua:ouch-org/ouch`, `github:ogham/dog`) and ecosystem packages (`npm:*`, `pipx:meta-package-manager`). `.chezmoitemplates/mise-tool-entry` now also quotes tool keys containing `.` so dotted names render as valid TOML (`"llama.cpp"`). `mise list` no longer shows duplicate/greyed backend-qualified rows after `mise install` + `mise prune`.
- **Restored `oh-my-pi` to cross-platform mise management**: `github:can1357/oh-my-pi` moved from `always_install.mise_unix` back to `always_install.mise`, so the Windows install is tracked instead of orphaned/greyed in `mise list` (regression from the Windows-CLI-to-mise migration, which dropped it from the cross-platform list). The manually-added `llama.cpp` global tool is now declared in `package_mapping.ai_tools.windows.mise` so `chezmoi apply` stops clobbering it. Windows `coreutils` is bare (`uutils` ships individual `uname`/`ls`/`rm`/… shims that `05-coreutils.ps1` activates); Linux keeps `cargo:coreutils` (multicall only) so `uutils` doesn't shadow system GNU `ls`/`cat`/`rm` on PATH.
- **mise global config split (Unix path)**: moved the chezmoi-managed baseline from `~/.config/mise/config.toml` to `~/.config/mise/conf.d/00-managed.toml` so Unix hosts can keep user `mise use -g` writes in `config.toml` without chezmoi clobbering them. This design was later superseded on Windows by the following entry because Windows mise 2026.5.7 did not activate the `conf.d` fragment.
- **Fix Windows mise activation after config split**: Windows mise 2026.5.7 only activates `~/.config/mise/config.toml`; it does not activate the managed `conf.d/00-managed.toml` fragment. Replaced the Windows path with `dot_config/mise/modify_config.toml`, which renders the curated baseline directly into active `config.toml` while preserving live `[tools]`, `[settings]`, and `[env]` overrides. `.chezmoiignore`/`.chezmoiremove` now skip and remove the stale Windows `conf.d/00-managed.toml`; Unix keeps the original `conf.d` split.
- **Line endings: LF everywhere**: `.gitattributes` now declares explicit `text eol=lf` entries for every text extension in the repo (shell/zsh/bash/fish, `*.ps1`/`*.psm1`/`*.psd1`, `*.bat`/`*.cmd`, `*.tmpl`, YAML/TOML/JSON/Markdown/Lua) on top of the existing `* text=auto eol=lf` default, plus explicit `binary` entries for fonts, images, and archives. `dot_editorconfig` switches the `[*.{ps1,psm1,psd1}]` and `[*.bat]` blocks from `end_of_line = crlf` to `lf`. `AGENTS.md` § "Line endings (CRITICAL)" is rewritten from the old LF/CRLF split to the new LF-everywhere policy with verification commands. Matches the rule that CRLF is forbidden anywhere on Windows; PowerShell 7+ reads LF natively. Working tree was renormalized with `git add --renormalize .` after the policy change — every text file was already on disk as LF, so the renormalize was a no-op.
- **Package mapping — one source per platform; `mise_remote` no-sudo fallback for remote Linux**: `.chezmoidata.yaml`'s `package_mapping` for `lua`, `luajit`, `vim`, `luarocks`, `lua-language-server`, and `neovim` is reorganized so each tool is installed by exactly one manager per platform (no double-install). Lua-family runtimes and `vim` flow through the distro's native package manager on Linux (apt/dnf/pacman) and through Homebrew on macOS; `neovim` and `lua-language-server` are managed by mise/aqua everywhere. A new `mise_remote` key per tool lists no-sudo mise packages used as a fallback when `is_remote` is true and root is unavailable; `dot_config/mise/config.toml.tmpl` emits those entries conditionally on the remote-state flag. The WSL-specific `disable_tools` blocks were removed because the per-tool, per-platform routing no longer overlaps with mise on Unix.
- **WSL: enable `systemd=true` in `.wslconfig`**: `dot_wslconfig.tmpl` uncomments the `systemd=true` directive under `[boot]` to match Ubuntu 24.04+ defaults; without it, systemd-managed services (snapd, networkd, etc.) fail to start inside WSL2.
- **Windows Terminal: drop stale hardcoded WSL profiles**: `AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json.tmpl` removes five hardcoded profile entries for distros that aren't installed on this host. Windows Terminal's dynamic `remainingProfiles` menu entry now auto-discovers whichever WSL distros are actually registered.
- **wezterm: palette driven from chezmoi theme data; drop dead lua modules**: `dot_config/wezterm/wezterm.lua.tmpl` now consumes the unified `theme.name` data block directly via `wezterm_scheme`, replacing hand-rolled scheme tables. `tabs.lua` and `utilities.lua` shed ~570 lines of unused palette plumbing and dead helper functions; tabline and visual config read the theme through the same indirection used by neovim/starship/eza/bat/delta.
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
- **`.chezmoiscripts/run_after_72_warp_mcp_sync.ps1.tmpl`**: replaced the hardcoded `1password` JSON literal with a chezmoi template directive that reads `mcp.servers["1password"]` from `.chezmoidata/mcp.yaml`, restoring the single-source-of-truth claim in the script's docstring. The `--account=${OP_ACCOUNT}` placeholder is substituted at runtime from `$env:OP_ACCOUNT` so the rendered entry stays per-user.
- **`scripts/README.md`**: added documentation sections for `healthcheck.sh`, `healthcheck.ps1`, `test.sh`, `test.ps1`, `rollback.sh`, `rollback.ps1`, `add-ascii-headers.ps1`, and `setup-pihole-dot.sh`. Previously only `reset-wsl-arch.ps1` was documented; every other script was undocumented.
### Removed
- **Tavily MCP server**: dropped the `tavily` entry from `dot_mcp.json.tmpl` so `~/.mcp.json` only declares `qdrant`. The `run_after_71_claude-code_mcp_sync_{windows,unix}` and `run_after_72_warp_mcp_sync_windows` hooks now sync only `qdrant` and actively prune `tavily`/`tavily-mcp` from `~/.claude.json` and `~/.warp/.mcp.json` (previously they only ever added, so a once-synced Tavily entry persisted across applies). The orphaned `tavily` and `context7` entries were also removed from `.chezmoidata/mcp.yaml`, and `context7` is now in opencode's `disabled_mcps`. `TAVILY_API_KEY` is retained in the env-reference files because the standalone `tvly` Tavily CLI still uses it. (NB: `context7` and `postman` MCP servers also surface from marketplace **plugins** discovered by the OMP agent — `context7@claude-plugins-official` was installed as both an OMP plugin and a Claude Code plugin; `postman@claude-plugins-official` is a Claude Code plugin shipping an HTTP `postman` MCP. These are runtime state, not chezmoi-managed: uninstall via `omp plugin uninstall` / `claude plugin uninstall`, and/or denylist by name via `disabledServers` in `~/.omp/agent/mcp.json`.)
- **pam integration**: removed the Personal Agent Multiplexer package mapping, managed config, service, secret env file, shell wrappers/completions, navigation helpers, and editor MCP pointers. opencode now imports standalone Claude MCP entries directly (context7 is disabled via opencode's `disabled_mcps` — see the Tavily/MCP entry above).
- **`~/.claude.json` literal credentials** — Vercel `Authorization: Bearer <token>`, Neon `Authorization: Bearer <token>`, and `qdrant.env.QDRANT_API_KEY` literal values replaced with `${VERCEL_TOKEN}`, `${NEON_API_KEY}`, and `${QDRANT_API_KEY}` references resolved by `op run` at process spawn.
- **Zed, ILSpy, and Special K package installs**: removed Zed package IDs from the default package manifests, dropped ILSpy and its .NET 8 desktop runtime companion from `dev_extras`, and removed `SpecialK.SpecialK` from the Windows gaming winget list.
### Fixed
- **PowerShell history file no longer grows unbounded (fixes shell freezing + "being used by another process" lock errors)**: `Documents/PowerShell/Microsoft.PowerShell_profile.ps1.tmpl` now trims the on-disk PSReadLine history to the last 20,000 lines (when the file exceeds 2 MB) before `Import-Module PSReadLine`, serialized across concurrent sessions via a `Global\` mutex and snapped to a command boundary so multi-line entries are never split. PSReadLine's `MaximumHistoryCount` caps only the in-memory list; with `SaveIncrementally` the file on disk grew without limit (agent-driven multi-line command blocks pile up fast — observed at 22.6 MB / 422k lines on one host). A multi-MB file made every prompt slow (parsing it for `PredictionSource History`) and, with several concurrent pwsh sessions plus Defender real-time scanning, intermittently failed to acquire the file handle, surfacing as `Error reading or writing history file ... because it is being used by another process`. zsh already bounds its own history natively via `SAVEHIST` + `hist_expire_dups_first`, so this is a PowerShell-only gap.
- **PowerShell shell-startup guard parity**: guarded tool-specific environment variables in `Documents/PowerShell/Scripts/30-misc.ps1` (`VAGRANT_HOME`, `GLAB_CONFIG_DIR`, `TEALDEER_CONFIG_DIR`), added PowerShell feature-flag gating to `.chezmoiignore`, and made `dot_config/mise/config.toml.tmpl` include the DH-local mise overlay only when the source file exists. This keeps disabled/missing tools from leaking stale env vars or breaking `chezmoi apply`.
- **`winget-packages.json.tmpl`** — nested `package_mapping` lookup under `windows.winget` (was traversing `mapping.winget` directly, mismatching the actual schema in `.chezmoidata.yaml` which all other generated lists already use). Previously the rendered file contained only the `__end__` sentinel and `winget import` restored zero packages from the feature flags. Now correctly emits the 7 mapped IDs (1Password, Git, StrawberryPerl, PowerShell, VS Code, Warp, Windows Terminal). (P0-1)
- **`.chezmoiscripts/run_before_00_backup.ps1.tmpl` + `scripts/rollback.ps1`** — backup directory now honors `$env:XDG_STATE_HOME` with a `$HOME\.local\state\chezmoi\backups` fallback instead of hard-coding `$env:LOCALAPPDATA\chezmoi\backups`. Matches the documented XDG-everywhere convention (`ARCHITECTURE.md:443`) and the rest of the repo's state-dir layout. (P0-3)
- **`.chezmoiscripts/run_onchange_install-packages-unix.sh.tmpl`** — promoted from `#!/bin/sh` (no `set -*`) to `#!/usr/bin/env bash` with `set -euo pipefail`. The 375-line installer was silently swallowing failures; intentionally non-fatal call sites already use explicit `|| echo Warning` or `|| true`. Same-class fixes: `run_onchange_before_install_base_packages_unix.sh.tmpl` promoted `set -eo` → `set -euo` (with `${SUDO_USER:-}` / `${USER:-$(id -un)}` guards), and `run_after_rebuild_bat_cache.sh.tmpl` gained `set -euo pipefail` and an explicit warning on `bat cache --build` failure. (P0-1)
- **`bootstrap.Tests.ps1`** — was sourcing a non-existent `bootstrap.ps1.example`. Rewrote against the canonical `bootstrap.ps1` using Pester 5.x patterns and added coverage for `Test-DeveloperMode`, `Enable-DeveloperMode`, `Test-OnePasswordCLI`, `Invoke-PreflightChecks`, `Import-ScoopExport`, `Import-WingetExport`. `Initialize-Chezmoi` tests now exercise the new HTTPS-default plus `-UseSSH` fallback contract end-to-end. Requires Pester 5.x. (P0-1)
- **`bootstrap.ps1` `Initialize-Chezmoi`** — default chezmoi clone is now HTTPS so fresh machines without an SSH key in the 1Password agent succeed on first run. New `-UseSSH` switch attempts SSH first and automatically falls back to HTTPS on failure (mirrors `setup.sh`'s `USE_SSH=1` pattern). Explicit `https://` / `git@` URLs passed by the caller are still respected verbatim. (P0-4)
- **`dot_config/zsh/dot_zshrc.d/80-op.zsh`** — added an eager 1Password CLI sign-in block at shell startup, mirroring the pwsh `Invoke-OpEnsure` flow in `Documents/PowerShell/Scripts/80-op.ps1`. Probes `op vault list`; on failure runs `op signin` non-interactively (desktop biometric prompt is system-modal, no stdin needed) and re-probes. Successful sign-in is cached for 300 s under `$XDG_CACHE_HOME/op/last-signin` so subsequent shells / tmux panes don't hammer the integration. Guards: skipped when the shell is non-interactive, stdin is not a TTY, `OP_SERVICE_ACCOUNT_TOKEN` is set, or `OP_AUTOSIGNIN_DISABLE` is set. (P0-5)
- **`.chezmoiscripts/run_onchange_before_install_base_packages_unix.sh.tmpl`** — closing of the dropped-Homebrew explanation comment used the right-trim form `*/ -}}`, which eats the newline between the perl-symlink block's `fi` and the next line's `# Set zsh as default shell` comment. Bash then parses `fi#` as a single word (not the `fi` keyword followed by a comment), leaving the `if [ -d /usr/bin/core_perl ] …; then` block unclosed and breaking `chezmoi apply` on every Linux host with `syntax error: unexpected end of file from \`if' command on line 242`. Changed to `*/}}` so the trailing newline is preserved.
- **`dot_config/opencode/tui.json.tmpl`** — adds `"plugin": ["oh-my-openagent/tui"]` so the OmO TUI plugin loads alongside the already-declared server plugin in `opencode.json`. Without this entry, oh-my-openagent's extra agents (`sisyphus`, `hephaestus`, `prometheus`, `oracle`, `atlas`, `metis`, `momus`, `librarian`, `sisyphus-junior`, `multimodal-looker`, `explore`) and the Roles · Models sidebar section never appeared in the opencode agent picker, even though their tools were available to the model. Surfaced by `oh-my-openagent doctor` ("TUI plugin entry missing from tui.json"); fix matches the installer's auto-write behavior.
- **`.chezmoiscripts/run_onchange_after_56_unbound_windows.ps1.tmpl`**: gated the Unbound service restart on `$needsWrite` so the daemon is only bounced when the rendered `service.conf` actually changed. Previously every `chezmoi apply` ran `net stop unbound & net start unbound` unconditionally, causing a brief DNS outage on every no-op apply. Also replaced `net stop/start` with the cleaner `Restart-Service unbound` pwsh idiom (still funneled through gsudo because the script uses per-command elevation, not a single up-front elevation).
- **`scripts/test.sh`**: dropped the nonexistent `--no-pager` flag from `chezmoi diff` in the "no chezmoi diff errors" test case. `chezmoi diff` has no such flag; the pager is already disabled globally in `.chezmoi.toml.tmpl`'s `[diff]` section, so the redirect alone suffices.
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

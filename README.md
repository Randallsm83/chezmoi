# Dotfiles (Chezmoi)

Modern, cross-platform dotfile management using [chezmoi](https://www.chezmoi.io/) for rapid machine provisioning.

**One command. Fresh machine. Ready in 10 minutes.** ⚡

---

## 🚀 Quick Start

### Windows (PowerShell)
```powershell
iwr -useb https://raw.githubusercontent.com/Randallsm83/chezmoi/main/bootstrap.ps1 | iex
```

### Windows — Restore from Scoop Export (fastest)
If you have a scoop export from a previous machine:
```powershell
# 1. Install scoop
irm get.scoop.sh | iex

# 2. Import all packages (buckets + apps in one shot)
scoop import .\scoop-export.json

# 3. Apply configs
chezmoi init --apply Randallsm83/chezmoi
```

Or use the bootstrap script with `-ScoopExport`:
```powershell
iwr -useb https://raw.githubusercontent.com/Randallsm83/chezmoi/main/bootstrap.ps1 -OutFile bootstrap.ps1
.\bootstrap.ps1 -ScoopExport .\scoop-export.json
```

> **Tip**: After setup, chezmoi keeps `~/.config/scoop/scoop-export.json` in sync with your feature flags — always ready for next time.

### Unix/Linux/WSL (bash/zsh)
```bash
curl -fsSL https://raw.githubusercontent.com/Randallsm83/chezmoi/main/setup.sh | bash
```

This single command will:
1. Install chezmoi (via scoop/mise)
2. Clone this repository
3. Apply all configurations (with platform-specific templates)
4. Install package managers (scoop/mise if missing)
5. Configure shell environments
6. Set up 1Password SSH agent integration
7. Ready to work 🎉

---

## 📦 What's Included

### Core Tools (Always Installed)
- **Editors**: Neovim (LazyVim-based config)
- **Terminals**: WezTerm, Windows Terminal (Windows), Warp
- **Shell**: Zsh (Unix), PowerShell 7+ (Windows)
- **Prompt**: Starship with custom onedark theme
- **Version Control**: Git with 1Password SSH agent
- **CLI Tools**: bat, eza, fzf, ripgrep, fd, delta, vivid, direnv, wget
- **Languages**: Managed by mise (node, python, ruby, go, rust, lua, bun)

### Optional Packages (Feature Flag Controlled)
Languages and tools are controlled by feature flags in `.chezmoidata.yaml`.
The live values in that file are authoritative — the table below is a
snapshot for orientation.
<!-- Source of truth: .chezmoidata.yaml package_features -->

**Group flags** (convenience shortcuts) currently enabled by default:
`essentials`, `shell_tools`, `languages`, `editors`, `terminals`,
`rust_alternatives`, `ai_tools`, `gaming`, `docker`, `hardware_tools`,
`windows_utilities`, `sysinternals`, `network_tools`, `dev_extras`,
`nerd_fonts`. Group flags do not force individual flags on; they are
mostly used by `package_mapping`/`always_install` to gate bulk package
lists. Individual flags below override per-package routing.

| Flag | Default | What it gates |
|------|---------|---------------|
| **Version control / auth** | | |
| `git` | ✅ | git + lazygit, glab, gh |
| `ssh` | ✅ | OpenSSH client packages |
| `1password` | ✅ | 1Password CLI/desktop + agent.toml |
| **Tool/runtime managers** | | |
| `mise` | ✅ | mise CLI + global tools |
| `direnv` | ✅ | `.envrc` evaluator (mise plugin) |
| `homebrew` | ✅ | active on Linux/macOS as a brew-bundle source |
| **Terminals** | | |
| `wezterm` | ✅ | wezterm + colorscheme |
| `warp` | ✅ | Warp terminal config |
| `windows_terminal` | ✅ | Windows Terminal settings |
| **Editors** | | |
| `nvim` | ✅ | neovim + LazyVim plugins |
| `vim` | ✅ | vim binary + `.vimrc` |
| `vscode` | ✅ | settings.json + extension installer |
| `zed` | ✅ | Zed editor + settings |
| **Shell tools** | | |
| `starship` | ✅ | prompt |
| `zsh` | ✅ | zsh + zshrc.d |
| `powershell` | ✅ | pwsh + PSReadLine/PSFzf modules |
| `fzf` | ✅ | fuzzy finder |
| `wget` | ✅ | wget + curl |
| `thefuck` | ✅ | command-corrector |
| `fastfetch` | ✅ | system info display |
| `topgrade` | ✅ | cross-platform updater |
| `rust_alternatives` | ✅ | bat, rg, fd, eza, delta, zoxide, vivid, sd, dust, procs, hyperfine, tealdeer, navi, just, tokei, ouch, xh, uutils-coreutils |
| **Language runtimes** | | |
| `rust` | ✅ | rustup + cargo |
| `golang` | ✅ | go toolchain |
| `python` | ✅ | python + uv + pipx |
| `ruby` | ✅ | ruby + gem |
| `lua` | ✅ | lua/luajit/luarocks + lua-language-server |
| `node` | ✅ | node@lts + yarn/bun/deno |
| `perl` | ✅ | Perl + perlnavigator-server |
| `julia` | ✅ | juliaup |
| `php` | ❌ | PHP runtime (heavy build deps) |
| **Dev tools / fonts** | | |
| `sqlite3` | ✅ | sqlite CLI |
| `arduino` | ✅ | arduino-cli + IDE config |
| `vagrant` | ❌ | off by default; enable per machine if needed |
| `nerd_fonts` | ✅ | Hack/FiraCode/JetBrainsMono/CascadiaCode NF |
| **AI / containers / hardware / networking** | | |
| `ai_tools` | ✅ | ollama, claude-code, opencode, pam |
| `docker` | ✅ | docker-compose + (darwin) OrbStack |
| `gaming` | ✅ | Steam, rtss, msiafterburner, ludusavi |
| `hardware_tools` | ✅ | (Windows) cpu-z, gpu-z, smartmontools, fancontrol, etc. |
| `windows_utilities` | ✅ | (Windows) Everything, Flow Launcher, Ventoy |
| `sysinternals` | ✅ | (Windows) Sysinternals Suite |
| `network_tools` | ✅ | bind, rclone, pritunl, unbound |
| `dev_extras` | ✅ | postman, ilspy, pandoc, cygwin |
| **Deprecated (off)** | | |
| `asdf` | ❌ | replaced by mise |
| `nvm` | ❌ | replaced by mise |
| `tinted_theming` | ❌ | replaced by the unified theme system |

**Total managed files**: ~200 in `dot_config/`, ~370 managed across all
platforms (varies by feature flag set). Counts include both regular files
and chezmoi-managed symlinks/scripts.

---

## 🎨 Theme & Appearance

**Unified Theme System**: All apps use a single theme setting in `.chezmoidata.yaml`.

- **Active Theme**: Set via `theme.name` in `.chezmoidata.yaml` (default: `spaceduck`)
- **Available Themes**: spaceduck, onedark, gruvbox-material, tokyonight, tokyonight-storm, dracula, kanagawa
- **Apps Using Theme**: neovim, wezterm, starship, eza, vivid (LS_COLORS), bat, delta
- **Fonts**: Hack Nerd Font (primary), FiraCode Nerd Font (fallback with ligatures)

To change theme:
```yaml
# .chezmoidata.yaml
theme:
  name: "onedark"  # Change this, run chezmoi apply
```

---

## 🧩 VS Code

VS Code is fully chezmoi-managed on the default profile:

| File in $HOME | Source in chezmoi | Notes |
|---|---|---|
| `%APPDATA%\Code\User\settings.json` | `AppData/Roaming/Code/User/settings.json.tmpl` | Theme, fonts, editor behavior, language overrides, vim/neovim, AI panels, Remote-SSH |
| `%APPDATA%\Code\User\keybindings.json` | symlink → `vscode/keybindings.json` | Custom keybinds |
| `%APPDATA%\Code\User\mcp.json` | symlink → `vscode/mcp.json` | MCP servers (currently empty) |
| `%APPDATA%\Code\User\tasks.json` | symlink → `vscode/tasks.json` | Default-profile tasks |
| `%APPDATA%\Code\User\extensions.json` | symlink → `vscode/extensions.json` | Workspace recommendations (not the install DB) |
| _installed extensions_ | `vscode/extensions.txt` | Driven by `run_onchange_after_70_vscode-extensions_*` |

### Extensions are auto-installed

`vscode/extensions.txt` is the single source of truth. One extension ID
per line, blank lines and `#` comments allowed. On every `chezmoi apply`,
the `run_onchange_after_70_vscode-extensions_{windows,unix}.{ps1,sh}.tmpl`
scripts diff the list against `code --list-extensions` and install only
the missing ones (additive — they never uninstall).

Gating:
- `package_features.vscode = true` (default in `.chezmoidata.yaml`)
- `code` CLI on PATH (script skips silently if VS Code isn't installed yet)

To add or remove an extension:
```bash
chezmoi edit ~/.local/share/chezmoi/vscode/extensions.txt   # edit list
chezmoi apply                                               # installs missing
```

To force a re-run of the script after editing:
```bash
chezmoi state delete-bucket --bucket=scriptState
chezmoi apply
```

The `vscode/` directory is excluded from `$HOME` deployment via
`.chezmoiignore`; it's source-only data read by the install script
through `include`.

---

## 🦊 LibreWolf (Browser)

LibreWolf is installed as a Scoop portable app, but its **active profile**
still lives at the standard Firefox location: `%APPDATA%\LibreWolf\Profiles\<id>.default-default\`.
The scoop-shipped `~/scoop/persist/librewolf/Profiles/Default/` folder is
dead weight — LibreWolf does not read it. Always confirm via
`%APPDATA%\LibreWolf\profiles.ini` or `about:profiles`.

### What's tracked

Two files, both at non-XDG paths chezmoi can't reach via its normal target
walker. They live as source-only data and are deployed by
`.chezmoiscripts/run_onchange_after_55_librewolf_windows.ps1.tmpl`:

| Source                                  | Target                                                            | Owns                                                                        |
|-----------------------------------------|-------------------------------------------------------------------|-----------------------------------------------------------------------------|
| `librewolf/distribution/policies.json`  | `~/scoop/apps/librewolf/current/LibreWolf/distribution/policies.json` | Force-installed extensions, search-engine policy, telemetry/update lockdown |
| `librewolf/profile/user.js`             | `%APPDATA%\LibreWolf\Profiles\<id>.default-default\user.js`        | Network/fingerprinting hardening, cookies-on-shutdown, HTTPS-only, WebRTC off |

The profile id is generated per-install. The deploy script discovers it
at apply time by parsing `%APPDATA%\LibreWolf\profiles.ini` (preferring
the `[InstallXXX]` section's `Default=`, falling back to the first
`[ProfileN]` with `Default=1`).

### Force-installed extensions

Declared in `policies.json` under `ExtensionSettings` with
`installation_mode: "normal_installed"`. LibreWolf auto-installs them
from AMO on first profile launch. Current set: uBlock Origin, Bitwarden,
ClearURLs, LocalCDN, SponsorBlock, Dark Reader, Multi-Account Containers.

### Why these two files (and only these)?

- `prefs.js` is rewritten every session with cache state, build IDs,
  sessionstore data, etc. — unversionable.
- `extensions.json`, `extensions/`, sqlite databases, sessionstore
  backups: all browser-managed state. Fully derivable from
  `policies.json` + a fresh launch.
- `user.js` is read on every startup and overlaid onto `prefs.js`, so it
  is the canonical place for sticky preference overrides.
- `policies.json` is the canonical place for force-installed extensions
  and tenant-style policy. Without tracking it, scoop reinstalls or
  upgrades silently revert your extension list to LibreWolf stock.

### Adding a new preference

1. Make the change in the LibreWolf UI or `about:config`.
2. Edit `librewolf/profile/user.js` in the chezmoi source (don't edit
   the deployed copy in the active profile — the script overwrites it).
3. `chezmoi apply` (the run_onchange script picks up the new sha256 and
   writes it to the active profile).
4. Commit `librewolf/profile/user.js`.

### Adding a force-installed extension

1. Edit `librewolf/distribution/policies.json` — add an entry under
   `ExtensionSettings` with `installation_mode: "normal_installed"` and
   the AMO `install_url`.
2. `chezmoi apply` (deploys to the install dir).
3. Restart LibreWolf to trigger the auto-install on next profile load,
   or open `about:policies` to confirm the change is recognized.
4. Commit `librewolf/distribution/policies.json`.

### Backups & references

Detailed setup notes (privacy prefs rationale, search-engine policy,
restore/rollback procedures, verification steps) live in the personal
notes vault at `02 Atlas/Reference/Windows/LibreWolf Setup.md`.

---

## 🛠️ Manual Setup (Development)

For development or testing without running the bootstrap:

### 1. Install Chezmoi
```powershell
# Windows
scoop install chezmoi

# Unix/Linux
sh -c "$(curl -fsLS get.chezmoi.io)"
```

### 2. Initialize from this repository
```bash
chezmoi init --apply Randallsm83/chezmoi
```

### 3. Verify and update
```bash
# See what would change
chezmoi diff

# Apply changes
chezmoi apply

# Update from repository
chezmoi update
```

---

## ⚙️ Configuration

### Enable/Disable Packages

Edit `.chezmoidata.yaml` (chezmoi source directory):

```yaml
package_features:
  rust: true      # Enable rust
  python: false   # Disable python
```

Then apply:
```bash
chezmoi apply
```

### Platform-Specific Configs

Configs automatically adapt to your platform:
- **Windows**: PowerShell profile, Windows Terminal settings, WSL config
- **Unix/Linux**: Zsh config, shell integrations
- **WSL**: Special detection and configuration
- **macOS**: Homebrew integration (if needed)

### Package Management

- **Windows**: Scoop (CLI tools), Winget (GUI apps), Mise (language runtimes)
- **Linux/WSL/macOS**: Mise (everything via cargo + runtimes)

Package lists are in `.chezmoidata.yaml` under `packages.scoop`, `winget_packages`, `mise_runtimes`.

---

## 📁 Repository Structure

```
.local/share/chezmoi/          # Chezmoi source directory
├── .chezmoi.toml.tmpl         # Chezmoi configuration
├── .chezmoidata.yaml          # Template variables & feature flags
├── .chezmoiignore             # Platform & package exclusions
├── .chezmoiscripts/           # Auto-run installation scripts
├── .chezmoitemplates/         # Reusable template snippets
│
├── dot_config/                # XDG config files
│   ├── git/                   # Git configuration
│   ├── nvim/                  # Neovim configuration
│   ├── wezterm/               # WezTerm terminal
│   ├── starship/              # Starship prompt
│   ├── mise/                  # Mise version manager
│   ├── zsh/                   # Zsh configuration
│   └── [language packages]    # Language-specific configs
│
├── Documents/PowerShell/      # PowerShell profile (Windows)
├── AppData/Roaming/Code/      # VS Code settings (Windows)
├── dot_local/bin/             # Local scripts
├── dot_cache/zsh/             # Zsh completions
│
├── bootstrap.ps1              # Windows bootstrap script
├── setup.sh                   # Unix bootstrap script
└── README.md                  # This file
```

---

## 🗂️ Workspace Layout & Shell Shortcuts

The shells export a small set of environment variables that describe the local workspace, plus matching `cd`-style shortcuts. All paths derive from `$HOME` — no machine-specific absolute paths in the dotfiles.

### Environment variables

Exported from `dot_config/zsh/dot_zshrc.d/10-dirs.zsh` (zsh) and `Documents/PowerShell/Scripts/99-aliases.ps1` (pwsh):

| Var | Value | Purpose |
|---|---|---|
| `PROJECTS` | `$HOME/projects` | General projects root |
| `DHSPACE` | `$PROJECTS/dh` | DreamHost workspace |
| `BACKEND` | `$DHSPACE/BACKEND` | Backend service repos |
| `FRONTEND` | `$DHSPACE/FRONTEND` | Frontend dashboard repos |
| `HELPSERVICES` | `$DHSPACE/HELPSERVICES` | Supporting service repos |
| `NOTES` | `$PROJECTS/notes` | Obsidian vault |
| `MYSPACE` | `$HOME/Dev` | Personal dev space (zsh only) |
| `DOTFILES` | `$HOME/.local/share/chezmoi` | Chezmoi source dir |

On Windows, `$HOME/projects` is a junction to `D:\`, so `DHSPACE` resolves to `D:\dh`, `NOTES` to `D:\notes`, etc.

### Navigation shortcuts

zsh aliases and pwsh functions (pwsh functions are only defined when the target directory exists):

| Command | Goes to | Notes |
|---|---|---|
| `cdp` | `$PROJECTS` | general projects root |
| `dh` | `$DHSPACE` | DH workspace |
| `cdbe` / `cdfe` / `cdhs` | `$BACKEND` / `$FRONTEND` / `$HELPSERVICES` | service-tree roots |
| `dots` | `$DOTFILES` | chezmoi source |
| `notes` | `$NOTES` | Obsidian vault |
| `cdn` | `$DHSPACE/ndn` | top-level DH repo |
| `cdaudit` | `$DHSPACE/ndn-audit` | top-level DH repo |
| `cdpam` | `$DHSPACE/pam` | top-level DH repo |
| `cdscott` | `$DHSPACE/scott` | top-level DH repo |
| `cdtm` | `$DHSPACE/task-management` | top-level DH repo |
| `cdapi` | `$BACKEND/api-gateway` | common backend service |
| `cdcdn` | `$BACKEND/cdn-service` | common backend service |

zsh also exposes the longer-form aliases `backend`, `frontend`, `helpservices` as synonyms for `cdbe`/`cdfe`/`cdhs`.

### `dhgitall`

Runs a `git` command across every repo under `$BACKEND/`, `$FRONTEND/`, and `$HELPSERVICES/`. Entries without a `.git` directory are skipped. Top-level repos under `$DHSPACE` (ndn, ndn-audit, pam, scott, task-management) are **intentionally excluded** — run git commands against them individually.

```bash
dhgitall status -sb           # quick status across all service repos
dhgitall fetch --prune
dhgitall checkout main
```

Defined in:
- `dot_config/zsh/dot_zshrc.d/25-functions.zsh` (zsh)
- `Documents/PowerShell/Scripts/lib/99-functions-body.ps1` (pwsh)

---

## 🔧 Common Tasks

### Update Dotfiles
```bash
# Pull latest changes and apply
chezmoi update
```

### Edit a Config
```bash
# Edit in chezmoi source
chezmoi edit ~/.config/nvim/init.lua

# Or edit and apply immediately
chezmoi edit --apply ~/.gitconfig
```

### Add New File
```bash
# Add existing file to chezmoi
chezmoi add ~/.config/myapp/config.yml

# Add as template (for platform-specific content)
chezmoi add --template ~/.config/myapp/config.yml
```

### View Managed Files
```bash
# List all managed files
chezmoi managed

# Count managed files
chezmoi managed | wc -l
```

### Test Changes
```bash
# See what would change (safe)
chezmoi diff

# Dry-run apply
chezmoi apply --dry-run --verbose
```

---

## 🔐 Secrets & SSH

### 1Password SSH Agent Integration

SSH keys are managed by 1Password SSH agent:
- **Windows**: Named pipe (`\\.\pipe\openssh-ssh-agent`)
- **Unix**: Socket (`~/.1password/agent.sock`)

Git is configured to use 1Password for SSH authentication automatically.

### Setup 1Password SSH Agent
1. Install 1Password 8+
2. Enable SSH agent in settings
3. Add SSH keys to 1Password
4. Configs automatically use the agent

---

## 🐧 WSL-Specific Notes

Windows Subsystem for Linux is fully supported:
- `.wslconfig` template for WSL2 settings
- Automatic WSL detection in configs
- 1Password SSH agent integration via npipe
- Zsh as default shell with full config

---

## 📝 Migration from Stow

This repository replaces the old GNU Stow-based dotfiles with modern chezmoi:

**Improvements:**
- ✅ One-command provisioning
- ✅ Template-based platform detection
- ✅ Feature flags for optional packages
- ✅ Integrated bootstrap scripts
- ✅ Built-in secrets management
- ✅ ~5-10 minute setup (vs 30-60 minutes)

**Old repository**: Stow-based (deprecated)  
**New repository**: This one (`Randallsm83/chezmoi`)

---

## 📚 Documentation

- [Chezmoi Documentation](https://www.chezmoi.io/)
- [AGENTS.md](AGENTS.md) - AI agent technical reference (architecture, commands, conventions)

---

## 🤝 Contributing

This is a personal dotfiles repository, but feel free to:
- Fork for your own use
- Open issues for bugs
- Submit PRs for improvements

---

## 📜 License

MIT License - Feel free to use and modify for your own dotfiles!

---

**Made with ❤️ using [chezmoi](https://www.chezmoi.io/)**

*Last updated*: 2026-05-25  
*Managed files*: ~200 in `dot_config/`, ~370 managed total (varies per platform)  
*Platforms*: Windows, Linux, WSL, macOS

# Windows 11 Reinstall Plan

Full procedure to get from fresh Windows 11 install back to working state.

## Hardware Reference

- Motherboard: ASUS TUF GAMING B650-PLUS WIFI (BIOS 3602, Nov 2025)
- CPU: AMD Ryzen 7 7800X3D
- GPU: NVIDIA GeForce RTX 5080 (Driver 595.71)
- Display: 7680x2160 @ 240Hz (dual monitor, 2x 3840x2160)
- Audio: Focusrite USB interface
- NIC: Realtek Gaming 2.5GbE

## Backup Inventory (A:\bak)

Key items backed up:

- `.ssh/` — SSH keys, config, 1Password agent config, known_hosts
- `.kube/` — Kubernetes config
- `.mcp-auth/` — MCP remote auth tokens
- `.arduinoIDE/` — Arduino IDE settings & workspace
- `warp-config/` — Warp AI API keys (themes/keybindings/launch configs/MCP are chezmoi-managed)
- `warp-workflows/` — Warp custom workflows
- `hkcu-environment.reg` — User environment variables (XDG, PATH additions)
- `powerplan-settings.md` — Documented Balanced plan tweaks
- `winget-export.json` — 33 winget + 2 msstore packages
- `scoop-persist/` — flow-launcher, rclone, qbittorrent persist data
- `scheduled-tasks/` — FanControl, MSIAfterburner, OpenRGB, Rdock, UtilCacheCleaner XML
- `vscode-extensions.txt` — VS Code extensions list
- `vscode-profiles/` — VS Code profiles + snippets
- `powershell-modules.txt` — Installed PowerShell module list (reference only — chezmoi handles all PS modules)
- `Obsidian/` — Obsidian vault
- `.config/` — chezmoi init config, clickup-tui (API token), game-optimizer (API key), 1Password CLI config. GH, docker, rdock, dual-agent, lscolors, llmfit are now chezmoi-managed.
- `.local/` — lslib ExportTool (BG3 modding), dos2-analyzer.exe, npiperelay.exe (WSL SSH relay). Cargo/mise/nvim-data/rustup regenerate from tools.
- `AppData/Local/` — BG3/DOS2 Script Extender, LOOT, game-optimizer backups
- `Ludusavi/` — Game save backups (already handled separately)
- `nvidia-drs-base-profile.nip` — NVIDIA DRS profile export (NPI format)

## Phase 0: Pre-Install Prep

1. Download Windows 11 ISO (or use Media Creation Tool on USB)
2. Ensure A:\ drive (backup) is disconnected or marked to NOT format during install
3. Note BIOS settings to restore: XMP/EXPO for RAM, boot order, any fan curves
4. Have ethernet connected or WiFi password ready (ASUS WiFi driver may need manual load)

## Phase 1: Fresh Windows Install & First Boot

1. Install Windows 11 Pro (use local account or Microsoft account as preferred)
2. Complete OOBE, skip as much telemetry as possible
3. Connect to internet, let Windows Update run fully (multiple reboots)
4. Install latest NVIDIA driver (GeForce Experience or standalone from nvidia.com) — RTX 5080
5. Install ASUS TUF B650-PLUS WIFI drivers from ASUS support page (chipset, LAN, WiFi, audio, Armoury Crate if desired)

## Phase 2: Windows Settings

### Manual (GUI-only)

- Settings > System > Display: 240Hz refresh, scaling per-monitor
- Settings > Privacy & Security > For Developers: Enable **Developer Mode**
- Settings > System > About > Rename PC
- Taskbar: Left-aligned, disable Task View button, disable date/weather widgets
- Game Mode: ON (Settings > Gaming)

### Automated via restore script

Everything below is handled by `~/.config/windows/scripts/restore-post-install.ps1` (run elevated, once):

- **Registry**: Explorer (hidden files, extensions, compact mode, launch to This PC), Mouse (accel OFF, sensitivity=10), Keyboard (delay=1, speed=31), Game Mode ON, GameDVR OFF, UAC (ConsentPrompt=0)
- **Power plan**: Balanced with all non-default tweaks (disk never off, slideshow paused, wireless max perf, sleep 1hr, hibernate never, wake timers off, USB suspend off, PCIe ASPM off, display off 1hr, adaptive brightness off, video playback perf bias)
- **USB/NIC power management**: PnPCapabilities=24 on all USB hubs/controllers + Realtek NIC
- **Windows Features**: VirtualMachinePlatform, WSL, NetFx3 (NetFx4-AdvSrvs and SearchEngine-Client-Package are enabled by default)
- **Scheduled tasks**: FanControl, MSIAfterburner, OpenRGB, Rdock, FlowLauncher, ISLC, UtilCacheCleaner, uwd2 (created programmatically — reference XMLs for 5 original tasks in `~/.config/windows/scheduled-tasks/`)
- **uwd2**: Downloaded from GitHub releases to `~/.local/bin/`
- **Ethernet NIC** (Realtek 2.5GbE): EEE/Green/GigaLite/PowerSaving OFF, Flow Control OFF, Interrupt Moderation OFF, buffers 2048/1024, wake OFF, IPv6 OFF, DNS=Cloudflare (1.1.1.1/1.0.0.1). **Re-run after driver updates!**
- **Gaming/Performance**: MMCSS (NetworkThrottling OFF, SystemResponsiveness=10), HAGS, Game MMCSS priorities (GPU=8, High), PowerThrottling OFF, Windows Search disabled
- **TCP/Network**: Nagle disabled (TcpAckFrequency=1, TCPNoDelay=1), Tcp1323Opts=1, MaxWindow=65535, MaxUserPort=65534, TWDelay=30, RSS on, RSC off, FastOpen on, Timestamps off, ECN off, AutoTuning normal, Pacing off
- **NVIDIA DRS profile**: auto-import via NPI from `~/.config/windows/nvidia-drs-base-profile.nip` (Low Latency Ultra, G-SYNC, shader cache 100GB, DLSS overrides, TrueHDR, etc.)

Requires reboot after running for USB PM, Windows Features, and TCP changes to take effect.

## Phase 3: Chezmoi Bootstrap (Automated Core)

This is the main automation step. One command does most of the work:

```powershell
# Option A: Direct from GitHub (production)
iwr -useb https://raw.githubusercontent.com/Randallsm83/dotfiles/main/bootstrap.ps1 | iex

# Option B: With scoop/winget exports for faster bulk install
.\bootstrap.ps1 -ScoopExport A:\bak\scoop-export.json -WingetExport A:\bak\winget-export.json
```

Bootstrap performs:

1. Pre-flight checks (PS version, Developer Mode, internet, 1Password)
2. Sets XDG environment variables (XDG_CONFIG_HOME, XDG_DATA_HOME, etc.)
3. Installs scoop (if missing)
4. Imports scoop/winget exports (if provided)
5. Installs chezmoi via scoop
6. `chezmoi init --apply` — clones dotfiles, applies all configs, runs install scripts
7. Install scripts handle: scoop buckets, ~96 scoop packages (by feature flags), winget packages, mise runtimes, PowerShell modules, PSCompletions (psc) definitions, pip packages, vcredist-aio, Everything search service, pynvim, neovim npm/gem/cpan providers

### What chezmoi manages (symlinks/templates)

- Git config (spaceduck delta theme, 1Password SSH, credential manager, aliases)
- Neovim config
- Starship prompt
- PowerShell profile + scripts
- VS Code settings, keybindings, mcp config, tasks
- Warp: MCP server config, keybindings, launch configs, **custom themes** (5 YAML + 2 JPG)
- SSH config (1Password agent, host configs)
- .wslconfig
- bat, ripgrep, mise configs
- .editorconfig, .perltidyrc
- GitHub CLI config (`gh/config.yml`)
- Docker config (`docker/config.json`)
- rdock dock config (`rdock/config.toml`, `rdock/mine.toml`)
- dual-agent config, lscolors themes, llmfit theme
- OpenRGB config + plugins (`AppData/Roaming/OpenRGB/`)
- Windows: restore script, scheduled task reference XMLs, NVIDIA DRS profile, scoop/winget package lists
- Scoop packages include: `islc` (extras), `fancontrol` (extras)

## Phase 4: Post-Bootstrap Manual Steps

### 4a. Restore Backups

```powershell
# SSH keys (1Password manages these, but restore known_hosts)
Copy-Item -Path "A:\bak\.ssh\known_hosts" -Destination "$HOME\.ssh\known_hosts"

# Kubernetes config
New-Item -ItemType Directory -Path "$HOME\.kube" -Force
Copy-Item -Path "A:\bak\.kube\config" -Destination "$HOME\.kube\config"

# Warp AI API keys (themes, keybindings, launch configs, MCP are chezmoi-managed)
Copy-Item -Path "A:\bak\warp-config\ai_api_keys.json" -Destination "$env:APPDATA\warp\Warp\data\ai_api_keys.json" -Force

# Scoop persist data (flow-launcher, rclone, qbittorrent settings)
Copy-Item -Path "A:\bak\scoop-persist\flow-launcher\*" -Destination "$HOME\scoop\persist\flow-launcher" -Recurse -Force
Copy-Item -Path "A:\bak\scoop-persist\rclone\*" -Destination "$HOME\scoop\persist\rclone" -Recurse -Force
Copy-Item -Path "A:\bak\scoop-persist\qbittorrent\*" -Destination "$HOME\scoop\persist\qbittorrent" -Recurse -Force

# Obsidian vault
New-Item -ItemType Directory -Path "$HOME\Documents\Obsidian" -Force
Copy-Item -Path "A:\bak\Obsidian\*" -Destination "$HOME\Documents\Obsidian" -Recurse -Force

# Arduino IDE
New-Item -ItemType Directory -Path "$HOME\.arduinoIDE" -Force
Copy-Item -Path "A:\bak\.arduinoIDE\*" -Destination "$HOME\.arduinoIDE" -Recurse -Force

# MCP auth
New-Item -ItemType Directory -Path "$HOME\.mcp-auth" -Force
Copy-Item -Path "A:\bak\.mcp-auth\*" -Destination "$HOME\.mcp-auth" -Recurse -Force

# Configs with secrets (not in chezmoi — public repo)
New-Item -ItemType Directory -Path "$HOME\.config\clickup-tui" -Force
Copy-Item -Path "A:\bak\.config\clickup-tui\config.toml" -Destination "$HOME\.config\clickup-tui\config.toml"
New-Item -ItemType Directory -Path "$HOME\.config\game-optimizer" -Force
Copy-Item -Path "A:\bak\.config\game-optimizer\config.toml" -Destination "$HOME\.config\game-optimizer\config.toml"

# lslib tools (BG3 modding)
New-Item -ItemType Directory -Path "$HOME\.local\share\lslib" -Force
Copy-Item -Path "A:\bak\.local\share\lslib\*" -Destination "$HOME\.local\share\lslib\" -Recurse -Force

# Utilities
Copy-Item -Path "A:\bak\.local\bin\npiperelay.exe" -Destination "$HOME\.local\bin\npiperelay.exe" -Force
Copy-Item -Path "A:\bak\.local\bin\dos2-analyzer.exe" -Destination "$HOME\.local\bin\dos2-analyzer.exe" -Force

# HKCU environment variables (review before importing — XDG vars are set by bootstrap)
# regedit /s "A:\bak\hkcu-environment.reg"
```

### 4b. Automated Post-Install

Run the consolidated restore script (elevated):

```powershell
gsudo pwsh -File "$HOME\.config\windows\scripts\restore-post-install.ps1"
```

This handles: registry tweaks, power plan, USB/NIC PM, Windows features, scheduled tasks (including Flow Launcher + ISLC startup), gaming/performance tweaks, ethernet NIC tuning, TCP/network stack, NVIDIA DRS profile, and uwd2 download.

Review `$Config` at the top of the script — adjust paths if any changed after reinstall.

**Still manual:**

- None currently — UtilCacheCleaner task now uses `CacheCleaner` PS module (`Import-Module CacheCleaner; Clear-Cache`)

### 4c. Authentication & Services

- **1Password**: Install (from winget export), sign in, enable SSH agent
- **Git SSH**: Verify 1Password SSH agent works (`ssh -T git@github.com`)
- **GitHub CLI**: `gh auth login`
- **Browsers**: Sign into Chrome, Edge, Firefox — sync restores bookmarks/extensions/passwords
- **Steam**: Login, library auto-discovers games on existing drives
- **Pritunl VPN**: Install, import profile
- **Focusrite Control**: Install driver from focusrite.com (or from winget export)

### 4d. VS Code

Extensions auto-install from chezmoi-managed `extensions.json` or restore:

```powershell
Get-Content "A:\bak\vscode-extensions.txt" | ForEach-Object { code --install-extension $_ }
```

Profiles/snippets: copy from `A:\bak\vscode-profiles\`

### 4e. WSL (When Ready)

```powershell
wsl --install -d Ubuntu
# After Ubuntu setup, chezmoi can bootstrap Linux side too
```

### 4f. Game Performance Optimizations

Restore all Defender exclusions, CFG disables, and IFEO process priorities from backup (40 processes, 100 paths, 39 CFG, 35 priorities):

```powershell
gsudo pwsh -Command 'Import-Module GamePerformanceOptimizer; Import-GameOptimizations'
```

Defaults to `A:\bak\game-optimizations.json`. Use `-WhatIf` to preview first.

### 4g. Gaming

- Ludusavi handles game save restore
- BG3 Script Extender: backed up in `AppData\Local\BG3ScriptExtender\`
- LOOT: backed up in `AppData\Local\LOOT\`
- Mod managers (if needed): reinstall from scratch, mods on game drives may persist

## Phase 5: Verification Checklist

- [ ] `chezmoi diff` shows no changes
- [ ] Git push/pull works with 1Password SSH
- [ ] Neovim opens with plugins loaded (`:checkhealth`)
- [ ] Starship prompt renders correctly
- [ ] All Rust alternatives work (bat, eza, rg, fd, delta, zoxide, vivid)
- [ ] mise runtimes available (node, python, ruby, go, rust, lua, bun)
- [ ] VS Code settings synced, extensions installed
- [ ] Warp themes/keybindings loaded
- [ ] Flow Launcher works
- [ ] Scheduled tasks running (FanControl, OpenRGB, Rdock, FlowLauncher, ISLC, etc.)
- [ ] Ethernet NIC settings applied (check after driver update)
- [ ] Power plan set to preferred
- [ ] Display at correct resolution/refresh
- [ ] Mouse acceleration OFF
- [ ] Game Mode ON, DVR OFF
- [ ] NVIDIA DRS profile imported
- [ ] Game optimizations imported (Defender exclusions, CFG, IFEO priorities)
- [ ] WSL functional (if installed)

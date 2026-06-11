# Raspberry Pi Setup Guide

A consolidated, zsh-first homelab profile for a Raspberry Pi (aarch64 Debian Bookworm). By default it configures a lightweight shell without installing the medium-tier toolchain.

> See also: [REMOTE.md](./REMOTE.md) for the general remote-machine model and [INSTALL-GUIDE.md](./INSTALL-GUIDE.md) for the cross-platform overview.

## Quick Start

One-liner from a fresh Pi over SSH:

```sh
RASPI=1 curl -fsSL https://raw.githubusercontent.com/Randallsm83/chezmoi/main/setup.sh | bash
```

`setup.sh` will:

1. Auto-detect the Pi via `/proc/device-tree/model` (or `aarch64`+Debian outside a container) and set `RASPI=1`. Setting `RASPI=1` explicitly forces it; `RASPI=0` disables it.
2. Install only the apt zsh essentials: `git curl wget unzip zip zsh zsh-autosuggestions zsh-syntax-highlighting`.
3. Set zsh as the default login shell (`chsh`).
4. Seed `~/.config/chezmoi/.chezmoi.local.toml` with homelab zsh-only feature flags and `install_packages = false` (only on a fresh setup; existing files are left alone).
5. Install chezmoi and run `chezmoi init --apply`. The managed package installer exits early unless you explicitly set `install_packages = true`.

## What Gets Installed

### From apt

`git curl wget unzip zip zsh zsh-autosuggestions zsh-syntax-highlighting`

The zsh plugins live here because the homelab zsh loader sources distro-provided files from `/usr/share/...` when present.

### From mise

Nothing by default. `install_packages = false` makes the managed package script skip `mise install`.

If you want tools later, enable only what you need in `~/.config/chezmoi/.chezmoi.local.toml`, then run `chezmoi apply` and `mise install`.

### Explicitly excluded by default on Pi

- GUI terminals: `wezterm`, `warp`, `alacritty`, `kitty`
- Medium-tier CLI tools: `fzf`, `bat`, `ripgrep`, `fd`, `eza`, `zoxide`, `delta`, `starship`, `lazygit`, `gh`, `neovim`
- Language runtimes: `node`, `python`, `rust`, `go`, `ruby`, `perl`, `lua`, `julia`, `php`, `deno`, `bun`
- Other feature groups: `direnv`, `thefuck`, `ai_tools`, `gaming`, `docker`, `hardware_tools`, `sysinternals`, `network_tools`, `dev_extras`, `nerd_fonts`, `1password`, `homebrew`

## How the Profile Is Selected

Three independent signals can flip the Pi into the homelab zsh profile; any one is sufficient.

1. **Hostname**: `.chezmoi.toml.tmpl` matches `raspi*`, `raspberrypi*`, `rpi*` and sets `is_raspi = true`, `remote_tier = "medium"`.
2. **Env var on bootstrap**: `RASPI=1 ./setup.sh` writes a `.chezmoi.local.toml` that pins `remote_tier = "medium"` and `install_packages = false` regardless of hostname.
3. **Manual file**: copy `dot_config/chezmoi/raspi.local.toml.example` to `~/.config/chezmoi/.chezmoi.local.toml`.

Signal 3 wins: anything in `.chezmoi.local.toml` overrides the auto-detected values.

## Tuning

Edit `~/.config/chezmoi/.chezmoi.local.toml` and re-apply.

```sh
chezmoi edit ~/.config/chezmoi/.chezmoi.local.toml
chezmoi apply
```

Common tweaks:

```toml
# Opt into managed installs, then add Go
[data]
    install_packages = true

[data.package_features]
    golang = true

# Or opt into the old medium package set selectively
[data]
    install_packages = true

[data.package_features]
    node = true
    python = true
    nvim = true
    starship = true
    fzf = true
    rust_alternatives = true
```

## Re-running After OS Upgrades

```sh
# Pull latest configs
chezmoi update

# Refresh apt zsh essentials and local overrides
RASPI=1 ~/.local/share/chezmoi/setup.sh   # idempotent

# Optional, only if you opted into managed tools
mise upgrade
mise prune
```

## Troubleshooting

### `setup_1password` keeps prompting

Pi profile sets `setup_1password = false`. If a stale `.chezmoi.local.toml` overrides this, edit it and remove the override, then `chezmoi init` to regenerate.

## Encrypted DNS (DoT terminator)
The macOS profile rendered from `encrypted_dns` in `.chezmoidata.yaml` pins the Mac at `raspi.alai-altair.ts.net:853` over DoT. The Pi has to terminate that TLS connection and forward to Pi-hole. Stand it up with the helper script in `scripts/`:
```sh
# From a workstation that has the dotfiles repo:
scp ~/projects/personal/dotfiles/scripts/setup-pihole-dot.sh raspi:/tmp/
ssh raspi 'sudo bash /tmp/setup-pihole-dot.sh'
```
The script installs `unbound`, mints a TLS cert via `tailscale cert`, drops a config at `/etc/unbound/unbound.conf.d/99-pihole-dot.conf` that listens on `:853` and forwards plain DNS to Pi-hole on `127.0.0.1:53`, then restarts `unbound`. Re-running upgrades configs and reloads in place.
Tailscale certs expire after 90 days. Add a weekly cron entry that re-runs the script, or wire up a systemd timer:
```sh
echo '0 3 * * 1 root bash /usr/local/sbin/setup-pihole-dot.sh' | sudo tee /etc/cron.d/pihole-dot-renew
```
Until the Pi side is up, `chezmoi apply` on the Mac will print a warning and skip the profile install (the script TCP-probes `:853` first). No partial state.
Verify from the Mac:
```sh
nc -z -w 3 raspi.alai-altair.ts.net 853 && echo reachable
kdig -d @raspi.alai-altair.ts.net +tls-ca +short example.com
```

# Raspberry Pi Setup Guide

A consolidated, **medium-tier** profile for a Raspberry Pi (aarch64 Debian Bookworm). Less than a desktop install, more than the bare SSH-server minimal tier.

> See also: [REMOTE.md](./REMOTE.md) for the general remote-machine model and [INSTALL-GUIDE.md](./INSTALL-GUIDE.md) for the cross-platform overview.

## Quick Start

One-liner from a fresh Pi over SSH:

```sh
RASPI=1 curl -fsSL https://raw.githubusercontent.com/Randallsm83/dotfiles/main/setup.sh | bash
```

`setup.sh` will:

1. Auto-detect the Pi via `/proc/device-tree/model` (or `aarch64`+Debian outside a container) and set `RASPI=1`. Setting `RASPI=1` explicitly forces it; `RASPI=0` disables it.
2. Install the apt base set (`git curl wget unzip zip build-essential ... zsh`) plus the two zsh plugins that have to come from apt: `zsh-autosuggestions zsh-syntax-highlighting`. Everything else comes from mise to avoid duplicates.
3. Set zsh as the default login shell (`chsh`).
4. Seed `~/.config/chezmoi/.chezmoi.local.toml` with the medium-tier feature flags (only on a fresh setup; existing files are left alone).
5. Install chezmoi and run `chezmoi init --apply`. Mise then installs `node@lts`, `python@latest`, the Rust CLI alternatives, `starship`, `lazygit`, `gh`, etc., from `~/.config/mise/config.medium.toml`.

## What Gets Installed

No tool is installed by both apt and mise; each tool has exactly one source.

### From apt (system + zsh plugins only)

`git curl wget unzip zip build-essential libssl-dev libreadline-dev zlib1g-dev libyaml-dev libffi-dev zsh zsh-autosuggestions zsh-syntax-highlighting`

The two zsh plugins live here because they need to be sourced from `/usr/share/zsh-{autosuggestions,syntax-highlighting}/` and aren't packaged by mise.

### From mise (user space, `~/.local/share/mise`)

| Category | Tools |
|----------|-------|
| Runtimes | `node@lts`, `python@latest`, `pipx` |
| Core CLI | `fzf`, `neovim` |
| Rust alternatives | `bat`, `ripgrep`, `fd`, `eza`, `zoxide`, `delta` |
| Prompt | `starship` |
| Git UX | `lazygit`, `github-cli` (gh) |

`cargo-binstall` is enabled in mise settings so prebuilt aarch64 binaries are preferred over slow `cargo install` builds.

### Explicitly excluded on Pi

- GUI terminals: `wezterm`, `warp`, `alacritty`, `kitty`
- Heavy languages: `rust` toolchain, `go`, `ruby`, `perl`, `lua`, `julia`, `php`, `deno`, `bun`
- `direnv`, `thefuck`
- `ai_tools`, `gaming`, `docker`, `hardware_tools`, `sysinternals`, `network_tools`, `dev_extras`, `nerd_fonts`, `1password`, `homebrew`

## How the Profile Is Selected

Three independent signals can flip the Pi into medium tier; any one is sufficient.

1. **Hostname**: `.chezmoi.toml.tmpl` matches `raspi*`, `raspberrypi*`, `rpi*` and sets `is_raspi = true`, `remote_tier = "medium"`.
2. **Env var on bootstrap**: `RASPI=1 ./setup.sh` writes a `.chezmoi.local.toml` that pins `remote_tier = "medium"` regardless of hostname.
3. **Manual file**: copy `dot_config/chezmoi/raspi.local.toml.example` to `~/.config/chezmoi/.chezmoi.local.toml`.

Signal 3 wins: anything in `.chezmoi.local.toml` overrides the auto-detected values.

## Tuning

Edit `~/.config/chezmoi/.chezmoi.local.toml` and re-apply.

```sh
chezmoi edit ~/.config/chezmoi/.chezmoi.local.toml
chezmoi apply
mise install   # picks up new tools
```

Common tweaks:

```toml
# Add Go back
[data.package_features]
    golang = true

# Switch to the ultra-minimal tier (drops eza/zoxide/starship/lazygit/gh)
[data]
    remote_tier = "minimal"

# Or upgrade to full parity with the desktop (heavy on a Pi - not recommended)
[data]
    remote_tier = "full"
```

## Re-running After OS Upgrades

```sh
# Pull latest configs
chezmoi update

# Refresh apt extras and shims
RASPI=1 ~/.local/share/dotfiles/setup.sh   # idempotent

# Refresh mise tools
mise upgrade
mise prune     # remove old versions
```

## Troubleshooting

### Mise is slow installing Rust CLI tools

Confirm `cargo-binstall` is being used:

```sh
mise settings cargo.binstall   # should print true
mise install --verbose         # check for "binstall" in output
```

If a tool keeps building from source on aarch64, install the Debian-packaged version directly (`sudo apt-get install ripgrep fd-find bat git-delta lazygit`) and pin it in `~/.config/mise/config.toml`'s `[settings] disable_tools` list. Note: Debian renames `bat` → `batcat` and `fd` → `fdfind`; symlink them under `~/.local/bin` if needed.

### `setup_1password` keeps prompting

Pi profile sets `setup_1password = false`. If a stale `.chezmoi.local.toml` overrides this, edit it and remove the override, then `chezmoi init` to regenerate.

# Remote Machine Setup Guide

This guide covers using these dotfiles on remote machines where you may have limited permissions or resources.

## Table of Contents

- [Quick Start](#quick-start)
- [Remote Machine Detection](#remote-machine-detection)
- [Package Installation Strategies](#package-installation-strategies)
- [Minimal vs Full Installation](#minimal-vs-full-installation)
- [No-Sudo Environment](#no-sudo-environment)
- [SSH and Authentication](#ssh-and-authentication)
- [Troubleshooting](#troubleshooting)

---

## Quick Start

### Automatic Remote Installation

The dotfiles automatically detect remote environments and adjust accordingly:

```bash
# One-line install on remote machine
curl -fsSL https://raw.githubusercontent.com/Randallsm83/dotfiles/main/setup.sh | bash
```

This will:
- ✅ Detect SSH/remote session automatically
- ✅ Skip system packages if no sudo access
- ✅ Install minimal tool set via mise in user space (`~/.local/`)
- ✅ Configure shell and environment appropriately

### Manual Installation

If you prefer manual control:

```bash
# 1. Install chezmoi
sh -c "$(curl -fsLS get.chezmoi.io)" -- init Randallsm83/dotfiles

# 2. Review what will be installed
chezmoi diff

# 3. Apply dotfiles
chezmoi apply
```

---

## Remote Machine Detection

The dotfiles automatically detect remote environments using these indicators:

| Check | Environment Variable | Description |
|-------|---------------------|-------------|
| SSH Session | `$SSH_CONNECTION`, `$SSH_CLIENT`, `$SSH_TTY` | Active SSH connection |
| VS Code Remote | `$TERM_PROGRAM=vscode` | VS Code Remote SSH/Dev Containers |
| Container | `/.dockerenv` file | Docker container |

### Detection Results

When remote is detected, these flags are set:

```toml
# .chezmoi.toml.tmpl
[data]
    is_remote = true              # Remote session detected
    remote_minimal = true         # Use minimal package set
    install_packages = false      # Skip system packages by default
    setup_1password = false       # Skip 1Password on remote
    has_sudo = false              # Estimated (verified at runtime)
```

### Override Detection

Create `~/.config/chezmoi/.chezmoi.local.toml` to override:

```toml
[data]
    is_remote = false          # Force treat as local
    remote_minimal = false     # Use full package set
    install_packages = true    # Enable package installation
    has_sudo = true            # I have sudo access
```

---

## Package Installation Strategies

### Strategy Overview

| Machine Type | Package Manager | Tools Installed |
|-------------|----------------|----------------|
| **Remote (no sudo)** | mise only | Minimal set in `~/.local/` |
| **Remote (with sudo)** | System PM + mise | Full set |
| **Local Linux/macOS** | mise (everything) | Full set |
| **Local Windows** | scoop + mise | Full set |

### Mise User-Space Installation

When `has_sudo = false`, all tools are installed via mise to user-writable locations:

```bash
# Mise binary location
~/.local/bin/mise

# Tool installations
~/.local/share/mise/
├── installs/          # Installed tools
│   ├── node@23.7.0/
│   ├── python@3.12/
│   ├── go@latest/
│   └── cargo:ripgrep@latest/
├── downloads/         # Downloaded archives
└── shims/            # Tool shims

# Tool configuration
~/.config/mise/
├── config.toml                # Main config (full set)
└── config.remote.toml         # Remote minimal config
```

### System Package Fallback

If you have sudo access on remote, system packages are installed minimally:

```bash
# Debian/Ubuntu
sudo apt-get install -y git curl wget unzip zip build-essential \
    libssl-dev libreadline-dev zlib1g-dev libyaml-dev libffi-dev zsh

# Arch Linux  
sudo pacman -Syu --noconfirm sudo base-devel git curl wget unzip \
    zip openssl readline zlib libyaml libffi zsh

# Fedora/RHEL
sudo dnf install -y git curl wget unzip zip gcc gcc-c++ make \
    openssl-devel readline-devel zlib-devel libyaml-devel libffi-devel zsh
```

---

## Minimal vs Full Installation

### Minimal Package Set (`remote_minimal = true`)

**Language Runtimes** (user space):
- Node.js
- Python
- Go

**CLI Tools** (user space via cargo):
- direnv (environment management)
- fzf (fuzzy finder)
- bat (cat with syntax highlighting)
- fd (fast find)
- ripgrep (fast grep)
- delta (git diff viewer)
- neovim (text editor)

**Excluded** (to save space/time):
- GUI apps: wezterm, warp
- Heavy runtimes: ruby, rust compiler, deno, bun
- Optional tools: eza, starship, zoxide, btop, sqlite
- Development headers/libraries

### Full Package Set (`remote_minimal = false`)

**All minimal tools plus**:
- Additional runtimes: Ruby, Rust, Bun, Deno, Lua
- Full CLI suite: eza, starship, zoxide, btop, sqlite
- Build tools: cargo-binstall, mise, gh
- Editors: vim (in addition to neovim)

### Switching Between Sets

Change the flag in `~/.config/chezmoi/.chezmoi.local.toml`:

```toml
[data]
    remote_minimal = false  # Use full package set
```

Then reapply:

```bash
chezmoi apply
mise install  # Install additional tools
```

---

## No-Sudo Environment

### What Works Without Sudo

✅ **Fully Functional**:
- Mise installation (downloads to `~/.local/bin/mise`)
- All language runtimes (node, python, go, etc.)
- Cargo-based CLI tools (bat, fd, ripgrep, eza, etc.)
- Neovim and text editors
- Shell configuration (zsh via mise, doesn't change default shell)
- Git configuration and SSH keys

❌ **Not Available**:
- System package installation
- Changing default shell with `chsh`
- System-wide configuration
- GUI applications

### Shell Configuration Without chsh

If you can't change your default shell:

```bash
# Add to ~/.bashrc or ~/.profile
if command -v zsh >/dev/null 2>&1; then
    export SHELL=$(command -v zsh)
    exec zsh
fi
```

Or manually start zsh:

```bash
zsh
```

### Build Dependencies

Some tools may fail without build dependencies. Solutions:

**Option 1: Use prebuilt binaries**
```bash
# Mise tries to use prebuilt binaries when available
mise settings set cargo.binstall true
```

**Option 2: Skip problematic tools**
```toml
# ~/.config/mise/config.toml
[settings]
disable_tools = ["tool-that-fails"]
```

**Option 3: Request admin to install build essentials**
```bash
# Ask admin to run (one-time)
sudo apt-get install build-essential libssl-dev
```

---

## SSH and Authentication

### SSH Key Management

**On remote machines**, you have two options:

#### Option 1: 1Password SSH Agent (Recommended)

If 1Password is installed locally and you're using SSH forwarding:

```bash
# Local machine: Enable SSH agent forwarding
# ~/.ssh/config
Host remote-server
    ForwardAgent yes
    RemoteForward /home/user/.1password/agent.sock /home/user/.1password/agent.sock
```

#### Option 2: Generate Remote SSH Key

```bash
# Generate key on remote
ssh-keygen -t ed25519 -C "your_email@example.com"

# Add to GitHub/GitLab
cat ~/.ssh/id_ed25519.pub
# Copy and add to: https://github.com/settings/keys
```

### Git Configuration

Git config automatically adjusts for remote:

```toml
# Minimal git config on remote (no credential helper)
[user]
    name = Randall
    email = randallsm83@gmail.com

[core]
    editor = nvim
```

---

## Troubleshooting

### Issue: "Permission denied" during package install

**Cause**: Script assumes sudo access

**Solution 1**: Override detection
```toml
# ~/.config/chezmoi/.chezmoi.local.toml
[data]
    has_sudo = false
    install_packages = true  # Mise will handle everything
```

**Solution 2**: Disable system packages
```toml
[data]
    install_packages = false
```

Then apply and install via mise manually:
```bash
chezmoi apply
mise install
```

---

### Issue: Mise tool installation fails

**Cause**: Missing build dependencies or network issues

**Diagnosis**:
```bash
# Check mise doctor
mise doctor

# Check specific tool
mise install node --verbose
```

**Solutions**:

1. **Use prebuilt binaries**:
```bash
mise settings set cargo.binstall true
```

2. **Skip failing tool**:
```toml
# ~/.config/mise/config.toml
[settings]
disable_tools = ["problematic-tool"]
```

3. **Install manually**:
```bash
# If mise fails, install directly
curl -fsSL https://nodejs.org/dist/v20.0.0/node-v20.0.0-linux-x64.tar.xz | \
    tar -xJ -C ~/.local --strip-components=1
```

---

### Issue: Shell doesn't change to zsh

**Cause**: No sudo access to run `chsh`

**Solution**: Add to `~/.bashrc`:
```bash
# Auto-switch to zsh if available
if [ -n "$BASH_VERSION" ] && command -v zsh >/dev/null 2>&1; then
    export SHELL=$(command -v zsh)
    exec zsh
fi
```

Or manually:
```bash
# Add alias to ~/.bashrc
alias zsh='~/.local/share/mise/installs/zsh/latest/bin/zsh'
```

---

### Issue: PATH not updated after mise install

**Cause**: Shell not reloaded

**Solution**:
```bash
# Reload shell
exec $SHELL

# Or source mise manually
eval "$(~/.local/bin/mise activate bash)"
# OR for zsh
eval "$(~/.local/bin/mise activate zsh)"

# Check PATH
echo $PATH | tr ':' '\n' | grep mise
```

---

### Issue: "Cannot connect to mise" or tool not found

**Cause**: Mise not in PATH or shell not configured

**Solution**:
```bash
# Ensure mise is accessible
export PATH="$HOME/.local/bin:$PATH"

# Activate mise for current shell
eval "$(mise activate bash)"

# Verify
mise --version
mise list
```

---

## Best Practices

### 1. Test in Dry-Run Mode First

```bash
# Preview what will happen
chezmoi apply --dry-run --verbose

# Check what packages would install
mise list --all
```

### 2. Use Local Overrides

Always create `~/.config/chezmoi/.chezmoi.local.toml` for remote-specific settings:

```toml
[data]
    # Disable features you don't need
    remote_minimal = true
    setup_1password = false
    
    # Disable specific languages
    [data.package_features]
    ruby = false
    rust = false
    golang = false
```

### 3. Incremental Installation

Don't install everything at once on remote:

```bash
# 1. Start minimal
chezmoi init --apply Randallsm83/dotfiles

# 2. Install only what you need
mise use node@latest
mise use python@latest

# 3. Add tools gradually
mise use neovim@latest
mise use ripgrep@latest
```

### 4. Monitor Disk Usage

```bash
# Check mise disk usage
du -sh ~/.local/share/mise

# Clean old versions
mise prune

# Remove unused tools
mise uninstall node@20.0.0
```

### 5. Use mise in Scripts

For portable scripts on remote:

```bash
#!/usr/bin/env bash
# Use mise shims for tool availability
export PATH="$HOME/.local/share/mise/shims:$PATH"

node script.js
python app.py
```

---

## Additional Resources

- [Chezmoi Documentation](https://www.chezmoi.io/)
- [Mise Documentation](https://mise.jdx.dev/)
- [Main Install Guide](./INSTALL-GUIDE.md)
- [Secrets Management](./SECRETS.md)

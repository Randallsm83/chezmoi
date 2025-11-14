# Dotfiles (Chezmoi)

Modern, cross-platform dotfile management using [chezmoi](https://www.chezmoi.io/) for rapid machine provisioning.

**One command. Fresh machine. Ready in 10 minutes.** ⚡

---

## 🚀 Quick Start

### Windows (PowerShell)
```powershell
iwr -useb https://raw.githubusercontent.com/Randallsm83/dotfiles/main/bootstrap.ps1 | iex
```

### Unix/Linux/WSL (bash/zsh)
```bash
curl -fsSL https://raw.githubusercontent.com/Randallsm83/dotfiles/main/setup.sh | bash
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
Languages and tools are controlled by feature flags in `.chezmoidata.yaml`:

| Package | Default | Description |
|---------|---------|-------------|
| `rust` | ✅ Enabled | Cargo, rustup, completions |
| `golang` | ✅ Enabled | Go environment setup |
| `python` | ✅ Enabled | Python environment variables |
| `ruby` | ✅ Enabled | Ruby environment |
| `lua` | ✅ Enabled | Lua environment |
| `node` | ✅ Enabled | Node.js environment |
| `glow` | ✅ Enabled | Markdown viewer |
| `vivid` | ✅ Enabled | LS_COLORS generator (spaceduck theme) |
| `sqlite3` | ✅ Enabled | SQLite CLI config |
| `tinted_theming` | ✅ Enabled | Base16/Base24 theme manager |
| `warp` | ✅ Enabled | Warp terminal configurations |
| `perl` | ❌ Disabled | Perl environment |
| `php` | ❌ Disabled | PHP environment |
| `vim` | ❌ Disabled | Vim config (using neovim) |
| `arduino` | ❌ Disabled | Arduino IDE config |
| `thefuck` | ❌ Disabled | Command correction tool |

**Total managed files**: 155+ configurations

---

## 🎨 Theme & Appearance

- **Color Scheme**: Spaceduck (terminals), OneDark (neovim, starship)
- **Fonts**: Hack Nerd Font (primary), FiraCode Nerd Font (fallback with ligatures)
- **Style**: Dark themes optimized for relatively dark environments
- **Palette**: Purples, pinks, greens, oranges, blues, cyans - neon/vibrant colors

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
chezmoi init --apply Randallsm83/dotfiles
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

**Old repository**: `Randallsm83/dotfiles` (deprecated)  
**New repository**: This one

---

## 📚 Documentation

- [Chezmoi Documentation](https://www.chezmoi.io/)
- [PACKAGE_MAPPING.md](PACKAGE_MAPPING.md) - Package feature flags reference
- [MIGRATION_SUMMARY.md](MIGRATION_SUMMARY.md) - Migration notes
- [TODO_4_COMPLETE.md](TODO_4_COMPLETE.md) - Feature flag infrastructure

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

*Last updated*: 2025-01-14  
*Managed files*: 155+  
*Platforms*: Windows, Linux, WSL, macOS

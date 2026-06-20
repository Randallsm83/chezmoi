# Scripts

Utility scripts for managing dotfiles, WSL instances, and development environments.

---

## Health & Diagnostics

### `healthcheck.sh`

**Purpose:** Validate dotfiles configuration and tool availability on Linux/macOS.

**Checks:** chezmoi version + source state, essential tools (`git`, `curl`, `wget`, `unzip`, `make`), `mise` doctor and outdated, shell/profile presence, git user.* config + SSH key count, mise + chezmoi backup disk usage.

**Usage:**
```bash
bash ./scripts/healthcheck.sh
```

**Output:** Color-coded info/success/warning/error lines. Read-only — never mutates state.

---

### `healthcheck.ps1`

**Purpose:** Windows counterpart to `healthcheck.sh`. Same section layout, expressed in PowerShell 7 idioms.

**Checks (in addition to the Unix set):** scoop / winget / gsudo / op presence, Windows service state for Unbound, 1Password SSH agent named pipe (`\\.\pipe\openssh-ssh-agent`), Developer Mode registry key, Caddy root cert in `LocalMachine\Root`, disk usage of `~/scoop`, `~/.local/share/mise`, `~/.cache`, `%USERPROFILE%\.local\state\chezmoi\backups`, and the chezmoi source dir.

**Usage:**
```powershell
pwsh -NoProfile -File .\scripts\healthcheck.ps1
```

**Status helper shape** matches `bootstrap.ps1:79-108` (`Write-Status -Type Info/Success/Warning/Error`) so output looks identical to bootstrap.

---

### `test.sh`

**Purpose:** Lightweight pass/fail smoke-test suite for the Unix dotfiles install.

**Tests:** chezmoi installation + source files, template syntax for the four canonical `.chezmoitemplates`, essential tools, Git user config, XDG directories, chezmoi state (managed files exist, `chezmoi diff` renders, `chezmoi data` accessible), platform-specific (zsh + `.zshrc` on Linux/macOS), mise integration (config file + `mise doctor` + `mise list`).

**Usage:**
```bash
bash ./scripts/test.sh
```

Exit code is `0` on all-pass, `1` on any failure. Suitable for CI.

---

### `test.ps1`

**Purpose:** Windows counterpart to `test.sh`.

**Tests:** chezmoi installation + source files, essential tools (`scoop`, `git`, `curl`, `mise`, `op`, `gsudo`), XDG locations (env-var set in any scope or default dir exists), pwsh profile file, Git user config, mise config file, Developer Mode enabled, chezmoi state (`managed`, `diff`, `data`), plus the shell parity linter below.

**Usage:**
```powershell
pwsh -NoProfile -File .\scripts\test.ps1
```

Exit code is `0` on all-pass, `1` on any failure.

---

### `lint-shell-parity.ps1`

**Purpose:** Guard against Windows PowerShell shell-startup drift from the zsh side.

**Checks:** tool-specific PowerShell env vars are guarded by command/path availability, bootstrap-only vars stay exempt, and PowerShell integration files that correspond to feature-gated zsh integrations are also gated through `.chezmoiignore`.

**Usage:**
```powershell
pwsh -NoProfile -File .\scripts\lint-shell-parity.ps1
```

Runs automatically from `scripts/test.ps1`; run it directly when editing `Documents/PowerShell/Scripts/*.ps1`, `.chezmoiignore`, or zsh integration gating.

---

## Rollback

### `rollback.sh`

**Purpose:** Restore files from a timestamped backup created before `chezmoi apply` (Linux/macOS).

Backups live under `${XDG_STATE_HOME:-$HOME/.local/state}/chezmoi/backups/` with one subdirectory per apply.

**Usage:**
```bash
# List available backups (no args)
bash ./scripts/rollback.sh

# Restore a specific timestamp
bash ./scripts/rollback.sh 20250120_143022

# Restore most recent
bash ./scripts/rollback.sh latest
```

Prompts for confirmation before overwriting current files.

---

### `rollback.ps1`

**Purpose:** Windows counterpart to `rollback.sh`.

Backups live under `$env:LOCALAPPDATA\chezmoi\backups\`. *(See follow-up issue: should be moved to `$env:USERPROFILE\.local\state\chezmoi\backups\` for XDG parity.)*

**Usage:**
```powershell
# List available backups (no args)
pwsh .\scripts\rollback.ps1

# Restore a specific timestamp
pwsh .\scripts\rollback.ps1 -Timestamp 20250120_143022

# Restore most recent
pwsh .\scripts\rollback.ps1 -Timestamp latest
```

---

## Source Maintenance

### `add-ascii-headers.ps1`

**Purpose:** Add ANSI Shadow-style ASCII-art banner headers to config files in `dot_config/` (or any directory passed via `-ConfigDir`).

**Parameters:**
- `-DryRun` — preview changes without writing
- `-Force`  — replace an existing ASCII header instead of skipping
- `-ConfigDir <path>` — defaults to `$PSScriptRoot\..\dot_config`

**Usage:**
```powershell
pwsh .\scripts\add-ascii-headers.ps1 -DryRun
pwsh .\scripts\add-ascii-headers.ps1
```

Has a built-in map of art per known package name (bat, git, nvim, zsh, starship, wezterm, mise, eza, ripgrep, direnv, fzf, vivid, wget, sqlite3, npm, fd, warp, vim, asdf, homebrew, tinted-theming, ...).

---

## Homelab / Pi

### `setup-pihole-dot.sh`

**Purpose:** Install and configure `unbound` on the Pi as a DoT (DNS-over-TLS) terminator. Forwards plaintext DNS to a local Pi-hole at `127.0.0.1:53`. Run on the Pi, not the Mac.

**What it does:** installs `unbound`, mints a TLS cert via `tailscale cert`, drops `/etc/unbound/unbound.conf.d/99-pihole-dot.conf`, validates with `unbound-checkconf`, restarts the unbound service, and smoke-tests via `kdig`/`openssl`.

**Usage (from the Mac):**
```bash
scp ./scripts/setup-pihole-dot.sh raspi:/tmp/
ssh raspi 'sudo bash /tmp/setup-pihole-dot.sh'
```

Idempotent. Tailscale certs expire after 90 days — schedule a weekly renew via cron/systemd.

---

## WSL Management

### `reset-wsl-arch.ps1`

**Purpose:** Automate the complete reset and bootstrap of an Arch Linux WSL instance with chezmoi dotfiles.

**What it does:**
1. Unregisters (terminates) the existing Arch Linux WSL instance
2. Installs a fresh Arch Linux instance from WSL repository
3. Bootstraps with chezmoi dotfiles from GitHub
4. Installs all tools, runtimes, and configurations automatically

**Usage:**

```powershell
# Basic usage (reset 'archlinux' with all defaults; prompts for confirmation)
pwsh .\reset-wsl-arch.ps1

# Fully hands-off (skip confirmation; also auto-skipped when $env:CI = 'true')
pwsh .\reset-wsl-arch.ps1 -Force

# Specify different distribution name
pwsh .\reset-wsl-arch.ps1 -DistroName "myarch"

# Skip chezmoi bootstrap (only reset WSL)
pwsh .\reset-wsl-arch.ps1 -SkipBootstrap

# Use different branch for chezmoi (branch reliably crosses the wsl.exe boundary)
pwsh .\reset-wsl-arch.ps1 -ChezmoiBranch "dev" -Force

# Custom repository
pwsh .\reset-wsl-arch.ps1 -ChezmoiRepo "yourusername/your-dotfiles"
```

**Parameters:**
- `DistroName` - WSL distribution name (default: `archlinux`)
- `SkipBootstrap` - Skip chezmoi bootstrap after WSL installation
- `ChezmoiRepo` - GitHub repository for dotfiles (default: `Randallsm83/chezmoi`)
- `ChezmoiBranch` - Git branch to use (default: `main`)
- `WslUser` - Linux username to create (default: `$env:USERNAME.ToLower()`)
- `Force` / `-Yes` / `-Unattended` - Skip the destructive confirmation prompt

A timestamped log is written to `$env:TEMP\wsl-reset-yyyyMMdd-HHmmss.log` on every run.

**Duration:** ~10-15 minutes for complete setup

**Prerequisites:**
- WSL2 installed and enabled on Windows
- Internet connection
- 1Password with SSH agent (optional but recommended)

---

## Quick Reference

### Reset Arch Linux WSL (Full)
```powershell
pwsh $HOME\.local\share\chezmoi\scripts\reset-wsl-arch.ps1
```

### Manual Bootstrap in Existing WSL
```bash
# From within WSL
curl -fsSL https://raw.githubusercontent.com/Randallsm83/chezmoi/main/setup.sh | bash
```

### Verify Installation
```bash
# After bootstrap completes, verify in WSL
starship --version
mise --version
chezmoi --version
nvim --version
```

---

## Script Development Guidelines

When adding new scripts to this directory:

1. **Naming:** Use descriptive kebab-case names (e.g., `reset-wsl-arch.ps1`, `sync-dotfiles.sh`)
2. **Documentation:** Include comprehensive comment-based help (PowerShell) or usage functions (Bash)
3. **Error Handling:** Use proper error handling and validation
4. **Parameters:** Support flexible parameters with sensible defaults
5. **Output:** Provide clear, color-coded output for steps, success, warnings, and errors
6. **Safety:** Confirm destructive operations with user prompts

### Script Template (PowerShell)

```powershell
#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Brief description

.DESCRIPTION
    Detailed description

.PARAMETER ParamName
    Parameter description

.EXAMPLE
    .\script.ps1
    Example usage

.NOTES
    Author: Randall
    Prerequisites: List any requirements
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$ParamName = "default"
)

$ErrorActionPreference = "Stop"

function Main {
    # Script logic here
}

try {
    Main
}
catch {
    Write-Error "Error: $_"
    exit 1
}
```

---

## Future Scripts (Ideas)

- `sync-windows-terminal.ps1` - Sync Windows Terminal settings across machines
- `update-all-wsl.ps1` - Update packages in all WSL distributions
- `backup-wsl.ps1` - Export WSL distributions as tarballs for backup
- `restore-wsl.ps1` - Import WSL distributions from backups
- `install-optional-tools.sh` - Interactive installer for optional chezmoi packages

---

## See Also

- [Chezmoi Documentation](https://www.chezmoi.io/)
- [WSL Documentation](https://learn.microsoft.com/en-us/windows/wsl/)
- [Main README](../README.md)
- [AGENTS.md](../AGENTS.md) - AI agent technical reference

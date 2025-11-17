# Scripts

Utility scripts for managing dotfiles, WSL instances, and development environments.

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
# Basic usage (reset 'archlinux' with all defaults)
pwsh .\reset-wsl-arch.ps1

# Specify different distribution name
pwsh .\reset-wsl-arch.ps1 -DistroName "myarch"

# Skip chezmoi bootstrap (only reset WSL)
pwsh .\reset-wsl-arch.ps1 -SkipBootstrap

# Use different branch for chezmoi
pwsh .\reset-wsl-arch.ps1 -ChezmoiBranch "dev"

# Custom repository
pwsh .\reset-wsl-arch.ps1 -ChezmoisRepo "yourusername/your-dotfiles"
```

**Parameters:**
- `DistroName` - WSL distribution name (default: `archlinux`)
- `SkipBootstrap` - Skip chezmoi bootstrap after WSL installation
- `ChezmoisRepo` - GitHub repository for dotfiles (default: `Randallsm83/dotfiles`)
- `ChezmoiBranch` - Git branch to use (default: `main`)

**Duration:** ~10-15 minutes for complete setup

**Prerequisites:**
- WSL2 installed and enabled on Windows
- Internet connection
- 1Password with SSH agent (optional but recommended)

---

## Quick Reference

### Reset Arch Linux WSL (Full)
```powershell
pwsh C:\Users\Randall\.local\share\chezmoi\scripts\reset-wsl-arch.ps1
```

### Manual Bootstrap in Existing WSL
```bash
# From within WSL
curl -fsSL https://raw.githubusercontent.com/Randallsm83/dotfiles/main/setup.sh | bash
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
- [WARP.md](../WARP.md) - AI agent technical reference

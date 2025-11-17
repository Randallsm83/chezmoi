# Warp Workflows

Reusable workflows for Warp terminal to automate common development tasks.

## What are Warp Workflows?

Warp Workflows are executable, shareable commands that you can save and run from Warp Drive. They can include parameters, colored output, and complex multi-step operations.

---

## Available Workflows

### 🔄 `reset-arch-wsl.yaml`

**Purpose:** Complete reset and bootstrap of Arch Linux WSL instance with chezmoi dotfiles.

**What it does:**
1. Unregisters (deletes) existing `archlinux` WSL distribution
2. Installs fresh Arch Linux from WSL repository
3. Bootstraps with chezmoi dotfiles from GitHub
4. Installs all tools, runtimes, and configurations

**Installs:**
- mise (package & runtime manager)
- CLI tools: ripgrep, fd, bat, eza, delta, starship, zoxide, fzf
- Language runtimes: Node.js (lts), Python 3.12, Ruby, Go, Rust, Lua, Bun, Deno
- Neovim with LazyVim configuration
- Zsh with starship prompt (onedark theme)
- 1Password SSH agent integration
- All dotfiles and configurations

**Duration:** ~10-15 minutes

**Tags:** `wsl`, `arch`, `dotfiles`, `chezmoi`, `setup`

---

## How to Import Workflows into Warp

### Method 1: Import from File (Recommended)

1. Open Warp terminal
2. Press `Cmd+P` (macOS) or `Ctrl+P` (Windows/Linux) to open Command Palette
3. Search for "Import Workflow"
4. Select the YAML file from `warp-workflows/` directory
5. The workflow will be saved to your Warp Drive > Personal > Workflows

### Method 2: Manual Creation

1. Open Warp Drive (click Warp Drive icon in top-right)
2. Navigate to **Personal > Workflows**
3. Click **"New Workflow"**
4. Copy the content from the YAML file
5. Paste into the workflow editor
6. Save

### Method 3: Copy from Chezmoi Repo

If this chezmoi repo is applied to your system, workflows are available at:
```
~/.local/share/chezmoi/warp-workflows/
```

---

## Using Workflows in Warp

### Run from Warp Drive

1. Open Warp Drive (`Cmd+D` or click icon)
2. Go to **Personal > Workflows**
3. Find "Reset Arch Linux WSL"
4. Click the **Run** button

### Run from Command Palette

1. Press `Cmd+P` (macOS) or `Ctrl+P` (Windows/Linux)
2. Type the workflow name: "Reset Arch Linux WSL"
3. Press Enter to execute

### Pin to Quick Access

1. Right-click the workflow in Warp Drive
2. Select **"Pin to Quick Access"**
3. Access quickly from the sidebar

---

## Workflow YAML Format

Warp workflows use a simple YAML format:

```yaml
---
name: "Workflow Name"
command: |-
  # Your shell commands here
  # Can be multi-line
  echo "Hello from Warp Workflow"
tags:
  - tag1
  - tag2
description: |-
  Detailed description of what this workflow does.
  Can be multi-line markdown.
```

**Key fields:**
- `name` - Display name in Warp Drive
- `command` - Shell commands to execute (PowerShell, Bash, Zsh, etc.)
- `tags` - Searchable tags for organization
- `description` - Detailed explanation shown in Warp Drive

---

## Creating Your Own Workflows

### Best Practices

1. **Clear naming** - Use descriptive names that explain what the workflow does
2. **Add confirmation prompts** - For destructive operations (like deleting WSL instances)
3. **Include tags** - Make workflows searchable by category
4. **Document parameters** - If using parameters, explain them in the description
5. **Show progress** - Use colored output to show steps and status
6. **Handle errors** - Include error handling and validation

### Example: Simple Workflow

```yaml
---
name: "Update System Packages"
command: |-
  Write-Host "Updating Windows packages via scoop..." -ForegroundColor Cyan
  scoop update *
  
  Write-Host "`nUpdating WSL packages via mise..." -ForegroundColor Cyan
  wsl -d archlinux bash -c "mise upgrade"
  
  Write-Host "`n✓ All packages updated!" -ForegroundColor Green
tags:
  - maintenance
  - update
description: Updates packages on Windows (scoop) and WSL (mise)
```

### Example: Workflow with Parameters

```yaml
---
name: "Create Git Branch"
command: |-
  $branch = "{{branch_name}}"
  $base = "{{base_branch}}"
  
  Write-Host "Creating branch '$branch' from '$base'..." -ForegroundColor Cyan
  git checkout $base
  git pull
  git checkout -b $branch
  
  Write-Host "✓ Branch '$branch' created" -ForegroundColor Green
tags:
  - git
  - branch
description: |-
  Create a new Git branch from a base branch.
  
  Parameters:
  - {{branch_name}} - Name for the new branch
  - {{base_branch}} - Base branch to branch from (usually 'main' or 'develop')
```

---

## Workflow Ideas

Here are some ideas for additional workflows you might create:

### Development
- `setup-node-project.yaml` - Initialize new Node.js project with your preferred setup
- `run-tests-all.yaml` - Run tests across multiple projects or languages
- `lint-fix-all.yaml` - Run linters and auto-fix across codebase

### WSL Management
- `backup-wsl-arch.yaml` - Export Arch Linux WSL as tarball
- `restore-wsl-arch.yaml` - Import Arch Linux WSL from backup
- `update-wsl-all.yaml` - Update packages in all WSL distributions

### Git Operations
- `pr-ready.yaml` - Run tests, lint, and push branch for PR
- `sync-fork.yaml` - Sync fork with upstream repository
- `cleanup-branches.yaml` - Delete merged local and remote branches

### System Maintenance
- `cleanup-cache.yaml` - Clear various cache directories
- `update-all-tools.yaml` - Update scoop, mise, and all packages
- `backup-configs.yaml` - Backup important configuration files

---

## Managing Workflows

### Organize with Tags

Use consistent tags across your workflows:
- `wsl` - WSL-related operations
- `git` - Git operations
- `setup` - Environment setup and configuration
- `maintenance` - System maintenance tasks
- `development` - Development-specific workflows

### Share with Team

Warp workflows can be shared:
1. Export workflow YAML files to a shared repository
2. Team members import via Warp Drive
3. Keep workflows in version control alongside code

### Sync Across Machines

If you use chezmoi to manage your dotfiles:
1. Store workflows in your chezmoi repo (this directory)
2. Workflows sync across all machines where you apply chezmoi
3. Import manually into Warp on each machine, or automate import via chezmoi script

---

## Troubleshooting

### Workflow doesn't appear in Warp Drive
- Make sure the YAML format is valid
- Check that all required fields (`name`, `command`) are present
- Try reimporting the workflow

### Command fails to execute
- Verify the shell type matches your terminal (PowerShell vs Bash)
- Check that all required tools are installed
- Add error handling with try/catch blocks

### Parameters not working
- Ensure parameters are wrapped in `{{}}` double braces
- Use descriptive parameter names
- Document expected parameter values in description

---

## Resources

- [Warp Workflows Documentation](https://docs.warp.dev/features/warp-drive/workflows)
- [Warp Drive Overview](https://docs.warp.dev/features/warp-drive)
- [Chezmoi Documentation](https://www.chezmoi.io/)

---

**Created:** 2025-01-17  
**Maintained by:** Randall  
**Repository:** Randallsm83/dotfiles-redux

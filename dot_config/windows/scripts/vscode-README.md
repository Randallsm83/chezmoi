# VS Code Configuration

This directory contains VS Code settings managed through dotfiles.

## ⚠️ Important: Dotfiles vs Settings Sync

**You must choose ONE method for managing VS Code settings:**

### Option 1: Dotfiles (This Approach - Recommended for Cross-Platform)
- ✅ Settings stored in Git with version history
- ✅ Works with your existing dotfiles workflow
- ✅ Settings are symlinked from this repository
- ✅ Consistent with how you manage Neovim, Git, WezTerm, etc.
- ✅ Works across WSL, native Windows, Linux, and macOS

**To use this approach:**
1. **Disable VS Code Settings Sync** (set `"settingsSync.enable": false` in settings.json - already done)
2. Run bootstrap with `-IncludeVSCode` flag to link these configs
3. Manage settings by editing files in this directory
4. Commit changes to Git

### Option 2: VS Code Settings Sync
- Uses Microsoft/GitHub cloud storage
- Automatically syncs settings across machines
- Separate from your dotfiles Git workflow

**To use this approach:**
1. Remove the symlinks created by bootstrap
2. Enable Settings Sync in VS Code (`"settingsSync.enable": true`)
3. **Do NOT use the dotfiles VS Code configs**

## 🚫 Do NOT Use Both

Using both dotfiles and Settings Sync will cause conflicts:
- Settings Sync will try to modify symlinked files
- Git will show constant changes
- You'll have merge conflicts between cloud and local versions

## Files

- **settings.json** - Main VS Code settings
  - Theme, fonts, editor behavior, language configs
  - Extension-specific settings
  - Remote development (SSH) settings
  - Vim mode keybindings
  - Settings Sync is **disabled** by default

- **keybindings.json** - Custom keyboard shortcuts
  - Navigation shortcuts (Ctrl+[ and Ctrl+])
  - Quick open navigation (Ctrl+N/P in quick open)
  - AI assistant keybindings (Kilo Code)

- **mcp.json** - Model Context Protocol configuration
  - Server configurations for AI assistants

- **extensions.txt** - List of installed extensions (57 extensions)
  - One extension ID per line
  - Can include comments starting with #

- **extensions-install.ps1** - Automated extension installer
  - Reads extensions.txt
  - Installs missing extensions
  - Skips already installed extensions

## Bootstrap Integration

The Windows bootstrap script handles VS Code setup when you use the `-IncludeVSCode` flag:

```powershell
# Full setup with VS Code
.\windows\bootstrap.ps1 -IncludeVSCode

# Only link configs (skip package installation)
.\windows\bootstrap.ps1 -LinkOnly -IncludeVSCode

# Test what would happen
.\windows\bootstrap.ps1 -WhatIf -IncludeVSCode
```

### What Bootstrap Does

1. **Checks Settings Sync Status**
   - Warns if Settings Sync is enabled
   - Prompts you to choose one method

2. **Creates Symlinks**
   - `settings.json` → `%APPDATA%\Code\User\settings.json`
   - `keybindings.json` → `%APPDATA%\Code\User\keybindings.json`
   - `mcp.json` → `%APPDATA%\Code\User\mcp.json`

3. **Installs Extensions**
   - Runs `extensions-install.ps1`
   - Installs all extensions from `extensions.txt`

4. **Backs Up Existing Files**
   - Creates timestamped backups in `~/.dotfiles-backup/`
   - Won't overwrite without permission (unless `-Force` used)

## Updating Extensions List

To update the extensions list after installing new extensions:

```powershell
# From dotfiles root
code --list-extensions | Out-File windows\vscode\extensions.txt -Encoding UTF8
```

## Platform-Specific Notes

### Windows
- Neovim path: `C:\Program Files\Neovim\bin\nvim.exe`
- Config path: `C:\Users\<username>\AppData\Local\nvim\init.lua`
- Settings use Windows paths with escaped backslashes

### Linux/WSL
- Neovim path: `/home/rmiller/.local/share/mise/installs/neovim/0.11.2/nvim-linux-x86_64/bin/nvim`
- Config path: `/home/rmiller/.config/nvim/init.lua`
- Settings use Unix paths

The settings.json file includes platform-specific paths using VS Code's platform detection.

## Key Settings

### Theme & Appearance
- **Theme**: One Dark Pro Night Flat (vivid variant)
- **Icons**: a-file-icon-vscode
- **Font**: FiraCode Nerd Font → Hack Nerd Font → fallbacks
- **Font Size**: 14px (editor), 13px (terminal)
- **Font Ligatures**: Enabled

### Editor Behavior
- **Tab Size**: 4 spaces
- **Word Wrap**: On
- **Auto-format**: On paste
- **Line Endings**: LF (Unix-style)
- **Whitespace Trimming**: Enabled

### Vim Mode
- **Leader Key**: Space
- **System Clipboard**: Enabled
- **EasyMotion**: Enabled
- **Special Mappings**:
  - `jj` in insert mode → Escape
  - `;` in normal mode → `:`
  - `<leader>d` → Delete line
  - `<C-h/j/k/l>` → Navigate between editor groups

### Performance
- GPU acceleration: On
- Semantic highlighting: Enabled
- Smooth scrolling: Enabled
- File watcher exclusions for node_modules, dist, .git

### Remote Development
- SSH config: `C:\Users\Randall\.ssh\config`
- Connection timeout: 60s
- Auto port forwarding: Disabled
- Known remote platforms configured (***REMOVED***)

## Extensions Highlights

**Themes & Icons**
- One Dark Pro
- Tokyo Night
- Gruvbox variants (Material, Concoctis)
- Material Icon Theme
- A File Icon

**Vim Mode**
- vscodevim.vim
- asvetliakov.vscode-neovim
- vspacecode.whichkey

**AI Assistants**
- github.copilot
- github.copilot-chat
- kilocode.kilo-code
- rooveterinaryinc.roo-cline
- kodu-ai.claude-dev-experimental
- vscode-mcp-bridge.vscode-mcp-bridge

**Development Tools**
- Remote Development (SSH, WSL, Containers)
- Python (ms-python.python, debugpy, pylance)
- C++ (ms-vscode.cpptools)
- Rust (rust-lang.rust-analyzer)
- Perl (richterger.perl, hitode909.perl-outline)
- Arduino (vscode-arduino.vscode-arduino-community)
- GitLab Workflow

**Utilities**
- EditorConfig
- Todo Tree / Todo Highlight
- Rainbow CSV
- Better Comments
- Color Highlight
- Gremlins (invisible character detection)
- Markdown Preview Enhanced

## Troubleshooting

### Settings not updating
- Check if files are symlinked: `Get-Item "$env:APPDATA\Code\User\settings.json" | Select-Object Target`
- If regular file, re-run bootstrap: `.\windows\bootstrap.ps1 -IncludeVSCode -Force`

### Extensions not installing
- Ensure `code` command is in PATH
- Try manual installation: `code --install-extension <extension-id>`
- Check extensions.txt format (one ID per line, no extra whitespace)

### Conflicts with Settings Sync
- **Disable Settings Sync**: Set `"settingsSync.enable": false` in settings.json
- Restart VS Code
- Delete cloud sync data if needed

### Changes not persisting
- If Settings Sync is enabled, it may overwrite local changes
- Verify symlinks are intact (not converted to regular files)
- Check Git status to ensure changes are committed

## See Also

- [Main dotfiles README](../../README.md)
- [Windows Bootstrap Script](../bootstrap.ps1)
- [VS Code Documentation](https://code.visualstudio.com/docs)
- [VS Code Settings Sync](https://code.visualstudio.com/docs/editor/settings-sync)

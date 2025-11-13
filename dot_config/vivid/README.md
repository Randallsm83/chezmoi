# Vivid Configuration

Custom themes for [vivid](https://github.com/sharkdp/vivid), a themeable LS_COLORS generator.

## Theme: spaceduck

Custom vivid theme matching the [spaceduck color palette](https://github.com/pineapplegiant/spaceduck).

### Colors

- **Directories**: cyan (`#00a3cc`)
- **Executables**: green (`#5ccc96`)
- **Symlinks**: purple (`#b3a1e6`)
- **Archives**: red (`#e33400`)
- **Media (images)**: purple (`#b3a1e6`)
- **Code files**: cyan
- **Config files**: magenta (`#ce6f8f`)

## Usage

### Setting the Theme

The `VIVID_THEME` environment variable is set to `spaceduck` by default in:
- PowerShell: `windows/powershell/Microsoft.PowerShell_profile.ps1`
- zsh: `zsh/dot-config/zsh/dot-zprofile`

### Generating LS_COLORS

LS_COLORS are generated once and cached in `~/.config/lscolors/` for performance.

**PowerShell:**
```powershell
.\windows\scripts\generate-lscolors.ps1
```

**WSL/Linux:**
```bash
./wsl/scripts/generate-lscolors.sh
```

### Platform-specific Paths

- **Windows**: `%APPDATA%\vivid\themes\` (symlinked from dotfiles)
- **Linux/WSL**: `~/.config/vivid/themes/` (stowed from dotfiles)

### Adding New Themes

1. Create a new `.yml` file in `themes/` directory
2. Use existing themes as reference for structure
3. Run the generate script to create cached LS_COLORS
4. Set `VIVID_THEME` environment variable to the new theme name

## Integration

The spaceduck theme is integrated across multiple tools for consistent theming:

### Vivid (LS_COLORS)
- **Theme file**: `vivid/dot-config/vivid/themes/spaceduck.yml`
- **Activation**: `VIVID_THEME='spaceduck'` environment variable
- **Windows**: Symlinked to `%APPDATA%\vivid\themes\spaceduck.yml`
- **Linux/WSL**: Stowed to `~/.config/vivid/themes/spaceduck.yml`

### Eza (File Listing)
- **Theme file**: `eza/dot-config/eza/themes/spaceduck.yml`
- **Active theme**: Symlinked as `eza/dot-config/eza/theme.yml`
- **Completions**: PowerShell module and zsh completions included

### Bootstrap Integration

**Windows** (`windows/bootstrap.ps1`):
- Creates symlinks via `windows/linkmap.psd1`:
  - `vivid/dot-config/vivid` → `%APPDATA%/vivid` (Windows-specific)
  - `vivid/dot-config/vivid` → `~/.config/vivid` (XDG)
  - `eza/dot-config/eza` → `~/.config/eza`
- Loads eza PowerShell completions

**WSL/Linux** (`wsl/setup.sh`):
- Stows `vivid` and `eza` packages
- Sets up zsh completions via fpath

### Verification

**Test vivid:**
```powershell
# Check theme is set
echo $env:VIVID_THEME  # Should show: spaceduck

# Test vivid output
vivid generate spaceduck | Select-Object -First 100
```

**Test eza:**
```bash
# Test with theme
eza --color=always

# Test completions
eza --<TAB>  # Should show completions
```

## Color Palette Reference

Based on [spaceduck palette](https://github.com/pineapplegiant/spaceduck):

- **Background**: `#0f111b`
- **Foreground**: `#ecf0c1`
- **Cyan**: `#00a3cc` (directories)
- **Green**: `#5ccc96` (executables)
- **Purple**: `#b3a1e6` (symlinks, images)
- **Red**: `#e33400` (archives, errors)
- **Yellow**: `#f2ce00` (modified times)
- **Orange**: `#e39400` (device files)
- **Magenta**: `#ce6f8f` (special files)

## See Also

- [vivid GitHub](https://github.com/sharkdp/vivid)
- [spaceduck theme](https://github.com/pineapplegiant/spaceduck)
- [eza GitHub](https://github.com/eza-community/eza)
- Eza integration: `eza/dot-config/zsh/dot-zshrc.d/80-eza.zsh`

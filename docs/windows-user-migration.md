# Windows user migration: `randa` → `ranmil`

Plan for replacing the current Windows user account `randa` (MicrosoftAccount-linked,
SID `S-1-5-21-1680730612-980445614-702355014-1001`, profile at `C:\Users\randa`) with
a fresh local account `ranmil` whose profile lives at `C:\Users\ranmil`.

This is a "new account + migrate" plan (the safer alternative to in-place renaming a
profile folder), tailored to a chezmoi + scoop + mise + WSL setup.

## How to read this on the new account

This file is committed in the chezmoi repo. On `ranmil`:

```powershell
scoop install git chezmoi
chezmoi init <your-dotfiles-remote>
chezmoi cd
# this file is at docs/windows-user-migration.md
```

## Phases at a glance

1. Create `ranmil` and prep.
2. Bootstrap `ranmil` (scoop, chezmoi, mise, GUI apps).
3. Transfer data (cherry-picked, not bulk).
4. Migrate WSL.
5. Verify for a week, then delete `randa`.

Active engineering time: ~2 hours. Calendar time to safe deletion: ~1 week.

## Phase 1 — Create and prep `ranmil`

Local account is preferred over MS-linked so the username is exactly `ranmil` (an
MS-linked account derives the local name from the email prefix and may not give you
the folder name you want).

```powershell
$pw = Read-Host -AsSecureString "Password for ranmil"
New-LocalUser -Name ranmil -Password $pw -FullName "Randall Miller"
Add-LocalGroupMember -Group Administrators -Member ranmil
```

Sign out of `randa`, sign into `ranmil` once to materialize `C:\Users\ranmil`,
then sign back out. (Optional: stay in `ranmil` for the rest of the work.)

## Phase 2 — Bootstrap `ranmil`

Run from an elevated PowerShell as `ranmil`:

```powershell
# scoop
irm get.scoop.sh | iex
scoop install git

# chezmoi + dotfiles
scoop install chezmoi
chezmoi init <your-dotfiles-remote>
chezmoi apply
```

`chezmoi apply` should restore the bulk of your environment via the install scripts
already in the repo (`.chezmoiscripts/install-packages-windows.ps1`,
`generate_bat_themes_windows.ps1`, `rebuild_bat_cache_windows.ps1`,
`sync_claude_memories.ps1`, `55_vpn-dns-routes_windows.ps1`).

GUI apps via winget (not chezmoi-managed):

```powershell
winget install --id Git.Git
winget install --id wez.wezterm
winget install --id Microsoft.PowerShell
winget install --id Microsoft.WindowsTerminal
winget install --id Microsoft.VisualStudioCode
winget install --id 7zip.7zip
winget install --id AgileBits.1Password
```

Sign into 1Password and enable the SSH agent → SSH keys are back automatically.

## Phase 3 — Data transfer

### 3.1 Inventory before copying

```powershell
$src = 'C:\Users\randa'
Get-ChildItem $src -Force -Directory |
  Select-Object Name,
    @{n='SizeGB';e={ [math]::Round((Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue |
      Measure-Object Length -Sum).Sum / 1GB, 2) }} |
  Sort-Object SizeGB -Descending |
  Format-Table -AutoSize
```

### 3.2 Stop `randa`-side activity

- Sign `randa` out fully (Switch User → sign out, not just lock).
- Quit OneDrive / Dropbox / cloud sync.
- Disable any scheduled tasks owned by `randa`:

```powershell
Get-ScheduledTask | Where-Object { $_.Principal.UserId -like '*randa*' } | Disable-ScheduledTask
```

### 3.3 Bulk copy plain user folders

```powershell
$src = 'C:\Users\randa'
$dst = 'C:\Users\ranmil'
$log = "$dst\migration-$(Get-Date -f yyyyMMdd-HHmmss).log"

$folders = @('Documents','Desktop','Downloads','Pictures','Videos','Music',
             'projects','notes','bin','Saved Games','Recorded Calls','3D Objects','ansel')
$exclude = @('node_modules','.venv','venv','target','dist','build','.next','.cache')

foreach ($f in $folders) {
  if (Test-Path "$src\$f") {
    robocopy "$src\$f" "$dst\$f" /E /DCOPY:DAT /COPY:DAT /R:1 /W:1 `
      /XD $exclude /XJ /MT:16 /TEE /LOG+:$log
  }
}
```

`/XJ` skips junctions/symlinks (chezmoi creates these — they get re-applied, not copied).
`/MT:16` parallelizes. `/R:1 /W:1` keeps it from hanging on locked files. Robocopy
exit codes 0–7 are success; 8+ are real errors.

### 3.4 Cherry-pick from AppData

NEVER bulk-copy `AppData`. Pull only items you need.

#### High-priority — irreplaceable / painful to recreate

```powershell
$srcRoaming = 'C:\Users\randa\AppData\Roaming'
$srcLocal   = 'C:\Users\randa\AppData\Local'
$dstRoaming = 'C:\Users\ranmil\AppData\Roaming'
$dstLocal   = 'C:\Users\ranmil\AppData\Local'

# 3D printer slicers (P1S calibrations, custom profiles)
robocopy "$srcRoaming\BambuStudio" "$dstRoaming\BambuStudio" /E /XJ /R:1 /W:1
robocopy "$srcRoaming\OrcaSlicer"  "$dstRoaming\OrcaSlicer"  /E /XJ /R:1 /W:1

# Game mods (load orders, configs)
robocopy "$srcRoaming\r2modman"               "$dstRoaming\r2modman"               /E /XJ /R:1 /W:1
robocopy "$srcRoaming\r2modmanPlus-local"     "$dstRoaming\r2modmanPlus-local"     /E /XJ /R:1 /W:1
robocopy "$srcRoaming\Vortex"                 "$dstRoaming\Vortex"                 /E /XJ /R:1 /W:1
robocopy "$srcRoaming\Thunderstore Mod Manager" "$dstRoaming\Thunderstore Mod Manager" /E /XJ /R:1 /W:1

# Game saves not on cloud
robocopy "$srcRoaming\EldenRing" "$dstRoaming\EldenRing" /E /XJ /R:1 /W:1
robocopy "$srcRoaming\ludusavi"  "$dstRoaming\ludusavi"  /E /XJ /R:1 /W:1

# RGB lighting profiles
robocopy "$srcRoaming\OpenRGB" "$dstRoaming\OpenRGB" /E /XJ /R:1 /W:1

# VPN client profiles
robocopy "$srcRoaming\pritunl" "$dstRoaming\pritunl" /E /XJ /R:1 /W:1
```

#### Medium-priority — re-auth is acceptable

- `Slack`, `Spotify`, `1Password`, `obsidian` — sign in fresh; copy only if you want
  to preserve workspace pinning / session state.
- `Code\User` — VS Code: chezmoi may already manage `vscode/` settings; verify before
  copying.
- `warp` — Warp app data: chezmoi has `dot_warp/`; verify before copying.

#### Low-priority — let it regenerate

`NVIDIA`, `AMD`, `Microsoft`, `Python`, `Notepad++`, `Autodesk`, `123pan` —
recreate on first launch.

### 3.5 Home-dir dotfolders not managed by chezmoi

Critical:

```powershell
robocopy 'C:\Users\randa\.kube'    'C:\Users\ranmil\.kube'    /E /XJ /R:1 /W:1
robocopy 'C:\Users\randa\.scott'   'C:\Users\ranmil\.scott'   /E /XJ /R:1 /W:1   # confirm purpose first
```

Re-auth (do not copy):

- `.gh` token — `gh auth login`
- `.supermaven` — re-auth via app
- `.mcp-auth` — re-auth via apps
- `.docker`, `.kuberlr` — regenerate on first use
- `.ssh/known_hosts` — regenerates as you connect (ssh `config` is in chezmoi)

Skip entirely (regenerate or chezmoi-managed):

`.cache`, `.cargo`, `.rustup`, `.npm`, `.nuget`, `.dotnet`, `.julia`, `.cpanm`,
`.templateengine`, `.thumbnails`, `.openjfx`, `.config` (chezmoi), `.claude`
(partial chezmoi — verify), `.warp` (partial chezmoi — verify),
`.local` (chezmoi), `.lde` (chezmoi).

### 3.6 OneDrive

Reinstall and re-link rather than copying the local cache. Then re-pick selective-sync
folders to match `randa`.

### 3.7 Cross-drive permissions

Repos and tools live on `D:\` (`D:\dh`, `D:\stormguide`, `D:\wotr`, `D:\game-optimizer`,
`D:\homelab\pi-stack`). D: is a VHD — confirm it auto-mounts for `ranmil` on login.
If access is denied:

```powershell
icacls 'D:\' /grant 'ranmil:(OI)(CI)M' /T /C
```

### 3.8 Verify the copy

```powershell
$srcSize = (Get-ChildItem C:\Users\randa\Documents,C:\Users\randa\projects -Recurse -Force `
  -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
$dstSize = (Get-ChildItem C:\Users\ranmil\Documents,C:\Users\ranmil\projects -Recurse -Force `
  -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
"Source: {0:N2} GB  Dest: {1:N2} GB" -f ($srcSize/1GB), ($dstSize/1GB)
```

Spot-check repos open, recents are present, Git remotes resolve.

## Phase 4 — WSL migration

WSL distros are user-scoped (registered under HKCU), so on `ranmil` they don't appear
until imported. Active distros to migrate:

- `archlinux` — keep
- `rancher-desktop`, `rancher-desktop-data` — reinstall Rancher Desktop on `ranmil`
  rather than migrating; Rancher manages its own WSL state.

### 4.1 Export from `randa`

```powershell
# As randa, ideally on a separate drive that ranmil can read
New-Item -ItemType Directory -Force -Path 'C:\backup\wsl' | Out-Null
wsl --shutdown
wsl --export archlinux C:\backup\wsl\archlinux.tar
```

### 4.2 Import as `ranmil`

```powershell
$wslRoot = 'C:\Users\ranmil\wsl'
New-Item -ItemType Directory -Force -Path "$wslRoot\archlinux" | Out-Null
wsl --import archlinux "$wslRoot\archlinux" C:\backup\wsl\archlinux.tar --version 2
wsl -d archlinux -- whoami
```

### 4.3 Restore default Linux user

After import, default user is root. Set the real user:

```powershell
$distro = 'archlinux'
$user   = '<linuxuser>'
wsl -d $distro -u root -- bash -lc "printf '[user]\ndefault=$user\n' >> /etc/wsl.conf"
wsl --terminate $distro
```

### 4.4 Fix in-distro paths

Inside the distro, repoint anything that referenced `/mnt/c/Users/randa`:

```bash
grep -rIn '/mnt/c/Users/randa' ~ /etc 2>/dev/null
# Common: ~/.ssh/config (IdentityAgent), ~/.gitconfig (signing key paths), .envrc files

grep -rIl '/mnt/c/Users/randa' ~ 2>/dev/null \
  | xargs -r sed -i 's|/mnt/c/Users/randa|/mnt/c/Users/ranmil|g'
```

If WSL chezmoi is set up, `chezmoi apply` regenerates these correctly.

## Phase 5 — Verify, then retire `randa`

### 5.1 Use `ranmil` for a week — checklist

- Shell loads: starship prompt, all aliases/functions, `note*` and Rust-alternative
  helper functions resolve.
- VCS works: `git` push/pull, `gh`, `lazygit`, signing.
- Scoop tools work: `bat`, `rg`, `fd`, `eza`, `delta`, `zoxide`, `fzf`, `btop`, `jq`, `yq`.
- `mise current` shows expected runtimes; `node`, `python`, `go`, `rust` versions OK.
- WSL launches; `/mnt/c` mounts; can git push from inside; chezmoi-applied configs
  are present.
- Neovim opens, plugins load, LSPs attach.
- WezTerm + Windows Terminal launch with theme (spaceduck) and Hack font.
- VS Code signs in, opens recent projects, extensions present.
- Browsers: bookmarks, extensions, signed-in state.
- 1Password unlocks; SSH agent named pipe works (`ssh -T git@github.com`).
- 3D printer apps (Bambu Studio, OrcaSlicer) open with custom profiles.
- Game mod managers open with profiles intact.
- OpenRGB profiles load; SignalRGB if used.
- Pritunl VPN connects.
- Scheduled tasks / startup apps recreated under `ranmil`.

### 5.2 Find stragglers pointing at the old path

```powershell
Get-ChildItem C:\Users\ranmil -Recurse -File -Force -ErrorAction SilentlyContinue |
  Select-String -Pattern 'C:\\Users\\randa' -SimpleMatch -List |
  Select-Object Path
```

```powershell
# As ranmil
reg query HKCU /f "C:\\Users\\randa" /s /d 2>$null
```

Update or delete; chezmoi-managed ones fix on next `apply`.

### 5.3 Archive `randa` before deletion (safety net)

```powershell
New-Item -ItemType Directory -Force -Path 'C:\backup\migration' | Out-Null
& 'C:\Program Files\7-Zip\7z.exe' a -t7z -mx=5 -ssw `
  'C:\backup\migration\randa-profile.7z' 'C:\Users\randa\*' `
  -xr!AppData\Local\Temp -xr!AppData\Local\Packages
```

Keep for at least 30 days.

### 5.4 Delete `randa`

From an elevated PowerShell on `ranmil`:

```powershell
# 1. No randa-owned processes running?
Get-Process -IncludeUserName -ErrorAction SilentlyContinue |
  Where-Object { $_.UserName -like '*randa*' }

# 2. Remove the user
Remove-LocalUser -Name randa

# 3. Remove the profile (folder + ProfileList registry key together)
$p = Get-CimInstance Win32_UserProfile | Where-Object { $_.LocalPath -eq 'C:\Users\randa' }
if ($p) { $p | Remove-CimInstance }

# 4. Force-remove any leftover folder
if (Test-Path C:\Users\randa) {
  takeown /F C:\Users\randa /R /D Y | Out-Null
  icacls C:\Users\randa /grant administrators:F /T /C | Out-Null
  Remove-Item C:\Users\randa -Recurse -Force
}
```

`Remove-CimInstance` against `Win32_UserProfile` is the clean way — folder + the
`HKLM\...\ProfileList\<SID>` key go together, no orphan SID.

### 5.5 Final sanity sweep

```powershell
Get-CimInstance Win32_UserProfile | Where-Object LocalPath -like '*randa*'
Get-ScheduledTask | Where-Object { $_.Principal.UserId -like '*randa*' }
Get-CimInstance Win32_Service | Where-Object { $_.StartName -like '*randa*' }
```

All three should return nothing.

## Time budget

| Phase | Hands-on | Wall-clock |
|---|---|---|
| 1. Create `ranmil` | 15 min | 15 min |
| 2. Bootstrap | 30 min | 60–90 min |
| 3. Data transfer | 30–45 min | 30–60 min |
| 4. WSL | 15 min | 30 min |
| 5a. Verification | passive | ~7 days |
| 5b. Delete `randa` | 10 min | 10 min |

## Items confirmed not chezmoi-managed (must transfer or re-auth)

- AppData/Roaming: `BambuStudio`, `OrcaSlicer`, `r2modman`, `r2modmanPlus-local`,
  `Vortex`, `Thunderstore Mod Manager`, `EldenRing`, `ludusavi`, `OpenRGB`, `pritunl`,
  `Slack`, `Spotify`, `obsidian`, `1Password`.
- Home dotfolders: `.kube`, `.gh` token, `.supermaven`, `.mcp-auth`, `.scott` (verify),
  `.ssh/known_hosts`.
- Top-level: `bin/`, `notes/`, `Saved Games/`, `Recorded Calls/`, `3D Objects/`, `ansel/`,
  `OneDrive/` (re-link instead).
- WSL distros (HKCU-scoped, see Phase 4).

## Items chezmoi already covers — don't manually copy

- All of `.config/*` (bat, eza, fd, fzf, gh config, git config, gitlab token, mise,
  npm, nvim, etc.)
- `.claude/settings.json`
- `dot_warp`, `dot_lde`, `dot_ssh` trees
- VS Code config (`vscode/` in repo)
- Scoop install list and bat theme generation (via `.chezmoiscripts/`)

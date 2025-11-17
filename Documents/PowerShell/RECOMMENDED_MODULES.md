# Recommended PowerShell Modules

Essential PowerShell modules for development, DevOps, and system administration.

---

## 🚀 Essential Modules (Install These)

### **PSReadLine** (Built-in with PowerShell 7+)
- **Purpose:** Enhanced command-line editing, history, syntax highlighting
- **Features:** Vi mode, predictive IntelliSense, history search
- **Already configured in your profile** ✅

### **posh-git**
```powershell
Install-Module posh-git -Scope CurrentUser
```
- **Purpose:** Git status in PowerShell prompt (integrates with Starship)
- **Features:** Tab completion for git commands, branch info
- **Usage:** Auto-loads in git repositories

### **Terminal-Icons**
```powershell
Install-Module Terminal-Icons -Scope CurrentUser
```
- **Purpose:** File/folder icons in terminal (like eza icons)
- **Features:** Colorful glyphs for different file types
- **Add to profile:**
```powershell
Import-Module Terminal-Icons
```

### **PSFzf**
```powershell
Install-Module PSFzf -Scope CurrentUser
```
- **Purpose:** Fuzzy finder integration for PowerShell
- **Features:** `Ctrl+R` history search, `Ctrl+T` file finder
- **Requires:** fzf (you already have this via scoop)
- **Add to profile:**
```powershell
Import-Module PSFzf
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
```

---

## 💻 Development Modules

### **PSScriptAnalyzer**
```powershell
Install-Module PSScriptAnalyzer -Scope CurrentUser
```
- **Purpose:** Linter for PowerShell scripts
- **Features:** Code quality checks, best practices
- **Usage:** `Invoke-ScriptAnalyzer -Path script.ps1`

### **Pester** (Built-in with PowerShell 7+)
- **Purpose:** Testing framework for PowerShell
- **Features:** Unit tests, mocking, code coverage
- **Usage:** Write `.Tests.ps1` files

### **platyPS**
```powershell
Install-Module platyPS -Scope CurrentUser
```
- **Purpose:** Generate markdown help files from PowerShell code
- **Features:** Auto-generate documentation

---

## 🔧 System Administration

### **PowerShellGet** (Built-in)
- **Purpose:** Package management for PowerShell modules
- **Already included** ✅

### **Microsoft.PowerShell.SecretManagement**
```powershell
Install-Module Microsoft.PowerShell.SecretManagement -Scope CurrentUser
```
- **Purpose:** Cross-platform secret management
- **Features:** Store credentials, API keys securely
- **Works with:** 1Password, Azure Key Vault, etc.

### **Microsoft.PowerShell.SecretStore**
```powershell
Install-Module Microsoft.PowerShell.SecretStore -Scope CurrentUser
```
- **Purpose:** Local encrypted secret vault (works with SecretManagement)

---

## 🌐 Cloud & DevOps

### **Az** (Azure CLI)
```powershell
Install-Module Az -Scope CurrentUser -Repository PSGallery
```
- **Purpose:** Manage Azure resources
- **Features:** Complete Azure management

### **AWS.Tools.Common** (AWS CLI)
```powershell
Install-Module AWS.Tools.Common -Scope CurrentUser
```
- **Purpose:** Manage AWS resources
- **Modular:** Install only what you need (e.g., `AWS.Tools.S3`)

### **Posh-SSH**
```powershell
Install-Module Posh-SSH -Scope CurrentUser
```
- **Purpose:** SSH and SCP from PowerShell
- **Features:** SSH sessions, SFTP transfers

---

## 📊 Productivity & Utilities

### **ImportExcel**
```powershell
Install-Module ImportExcel -Scope CurrentUser
```
- **Purpose:** Read/write Excel files without Excel
- **Features:** Create charts, pivot tables, conditional formatting

### **PSWriteColor**
```powershell
Install-Module PSWriteColor -Scope CurrentUser
```
- **Purpose:** Easier colored output
- **Features:** `Write-Color -Text "Hello", "World" -Color Green, Red`

### **BurntToast** (Windows only)
```powershell
Install-Module BurntToast -Scope CurrentUser
```
- **Purpose:** Windows 10/11 toast notifications
- **Usage:** `New-BurntToastNotification -Text "Task complete!"`

### **PSMenu**
```powershell
Install-Module PSMenu -Scope CurrentUser
```
- **Purpose:** Interactive menus in PowerShell
- **Features:** Build TUI menus easily

---

## 🎮 Gaming & Performance

### **Your Custom Modules** ✅
- **GamePerformanceOptimizer** - Already in your profile!
- **CacheCleaner** - Already in your profile!
- **EzaProfile** - Already in your profile!
- **WSLTabCompletion** - Already in your profile!

---

## 🔍 Search & Navigation

### **PSKoans**
```powershell
Install-Module PSKoans -Scope CurrentUser
```
- **Purpose:** Learn PowerShell through interactive exercises
- **Features:** TDD-style learning

### **PowerShellPracticeAndStyle**
```powershell
Install-Module PowerShellPracticeAndStyle -Scope CurrentUser
```
- **Purpose:** PowerShell best practices guide

---

## 📦 Recommended Installation Script

```powershell
# Install all recommended modules at once
$modules = @(
    'posh-git',
    'Terminal-Icons',
    'PSFzf',
    'PSScriptAnalyzer',
    'platyPS',
    'Microsoft.PowerShell.SecretManagement',
    'Microsoft.PowerShell.SecretStore',
    'ImportExcel',
    'PSWriteColor',
    'BurntToast',
    'Posh-SSH'
)

foreach ($module in $modules) {
    Write-Host "Installing $module..." -ForegroundColor Cyan
    Install-Module $module -Scope CurrentUser -Force -SkipPublisherCheck
}

Write-Host "`n✓ All modules installed!" -ForegroundColor Green
```

---

## 🔧 Add to Your Profile

After installing, add these to your PowerShell profile for auto-loading:

```powershell
# PowerShell Modules Auto-Load
$autoLoadModules = @(
    'posh-git',
    'Terminal-Icons',
    'PSFzf'
)

foreach ($module in $autoLoadModules) {
    if (Get-Module -ListAvailable -Name $module) {
        Import-Module $module -ErrorAction SilentlyContinue
    }
}

# PSFzf configuration
if (Get-Module -Name PSFzf) {
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}
```

---

## 📚 Module Discovery

### Find more modules:
```powershell
# Search PowerShell Gallery
Find-Module -Name "*keyword*"

# Get module info
Get-Module -Name ModuleName -ListAvailable

# View module commands
Get-Command -Module ModuleName
```

### Manage installed modules:
```powershell
# List installed modules
Get-InstalledModule

# Update all modules
Update-Module

# Update specific module
Update-Module ModuleName
```

---

## 🎯 Priority Installs Based on Your Workflow

### **High Priority (Install Now):**
1. `Terminal-Icons` - Visual enhancement for file listings
2. `PSFzf` - Better history and file search
3. `posh-git` - Better git integration
4. `ImportExcel` - Working with data files
5. `PSScriptAnalyzer` - Code quality

### **Medium Priority (Install Soon):**
1. `Microsoft.PowerShell.SecretManagement` - Secret management
2. `Posh-SSH` - SSH capabilities
3. `BurntToast` - Notifications for long tasks

### **Low Priority (Nice to Have):**
1. `PSWriteColor` - Better colored output
2. `PSMenu` - Interactive menus
3. Cloud modules (Az, AWS.Tools) - Only if you use cloud services

---

## 💡 Tips

- **Scope:** Always use `-Scope CurrentUser` to avoid needing admin rights
- **Auto-updates:** Set up a scheduled task to run `Update-Module` weekly
- **Module paths:** Check `$env:PSModulePath` to see where modules are installed
- **Performance:** Only auto-load modules you use frequently

---

**Last Updated:** 2025-01-17

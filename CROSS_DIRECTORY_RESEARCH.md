# Chezmoi Cross-Directory Deployment Research

**Date**: 2025-01-14  
**Status**: TODO #3 Complete - Solution Found

## The Problem

With GNU Stow, we had this structure:
```
dotfiles/
└── rust/
    └── dot-config/zsh/dot-zshrc.d/
        └── 70-rust.zsh
```

Which deployed to:
```
~/.config/zsh/.zshrc.d/70-rust.zsh
```

The rust package managed a file that deployed into the zsh directory. This allowed enabling/disabling the rust package independently by stowing/unstowing it.

## The (Incorrect) Assumption

I initially thought I needed some special chezmoi mechanism to:
1. Keep rust package files together in a `rust/` directory  
2. Have them deploy to `~/.config/zsh/.zshrc.d/` instead of `~/.config/rust/`

I considered approaches like:
- `dot-dot-dot-zsh` (parent directory escaping)
- Symlinks
- Special chezmoi attributes

## The Correct Solution

**Chezmoi doesn't need cross-directory deployment because it uses `.chezmoiignore` with feature flags!**

### How It Actually Works

1. **Keep the same directory structure as deployment target**
   ```
   chezmoi/dot_config/
   ├── zsh/
   │   └── dot-zshrc.d/
   │       ├── 00-helpers.zsh        ← Core (always deployed)
   │       ├── 01-mise.zsh           ← Core (always deployed)
   │       ├── 70-rust.zsh.tmpl      ← Conditional deployment!
   │       ├── 70-golang.zsh.tmpl    ← Conditional deployment!
   │       └── 70-python.zsh.tmpl    ← Conditional deployment!
   ```

2. **Use .chezmoiignore to control which files deploy**
   ```
   {{- if not .features.rust }}
   .config/zsh/.zshrc.d/70-rust.zsh
   {{- end }}
   
   {{- if not .features.golang }}
   .config/zsh/.zshrc.d/70-golang.zsh
   {{- end }}
   ```

3. **Use .chezmoidata.yaml for feature flags**
   ```yaml
   features:
     rust: true
     golang: false
   ```

### Result

When `rust: false` in `.chezmoidata.yaml`:
- `70-rust.zsh` is in `.chezmoiignore`  
- File is NOT deployed to `~/.config/zsh/.zshrc.d/70-rust.zsh`

When `rust: true`:
- `70-rust.zsh` is NOT in `.chezmoiignore`
- File IS deployed to `~/.config/zsh/.zshrc.d/70-rust.zsh`

## But What About Logical Grouping?

In stow, rust's zsh integration lived with the rust package. How do we maintain that logical connection in chezmoi?

### Solution: Documentation and Naming

1. **File naming convention**
   - `70-rust.zsh` clearly indicates this is rust-specific
   - Numbered prefixes maintain load order

2. **Template comments**
   ```zsh
   {{- /* This file is part of the rust package */ -}}
   {{- /* Controlled by .features.rust flag */ -}}
   #!/usr/bin/env zsh
   # Rust environment configuration
   ```

3. **Documentation**
   Create `PACKAGE_MAPPING.md`:
   ```markdown
   ## Rust Package
   
   **Feature flag**: `features.rust`
   
   **Files**:
   - `.config/zsh/.zshrc.d/70-rust.zsh` - Rust environment setup
   - `.cache/zsh/completions/_rustc` - Rust completions
   
   To disable: Set `rust: false` in `.chezmoidata.yaml`
   ```

## What This Means for Package Structure

### Old Stow Approach (Package-Centric)
```
dotfiles/
├── rust/                     # Everything rust
│   └── dot-config/zsh/dot-zshrc.d/
│       └── 70-rust.zsh
├── golang/                   # Everything golang
│   └── dot-config/zsh/dot-zshrc.d/
│       └── 70-golang.zsh
└── python/                   # Everything python
    └── dot-config/zsh/dot-zshrc.d/
        └── 70-python.zsh
```

### New Chezmoi Approach (Location-Centric with Conditional Deployment)
```
chezmoi/
└── dot_config/
    └── zsh/
        └── dot-zshrc.d/
            ├── 00-helpers.zsh          # Core
            ├── 70-rust.zsh.tmpl        # Rust package (feature flagged)
            ├── 70-golang.zsh.tmpl      # Golang package (feature flagged)
            └── 70-python.zsh.tmpl      # Python package (feature flagged)
```

## Wait - What About Actual Rust Config Files?

If rust had its own config files (like cargo config), those WOULD go in a separate directory:

```
chezmoi/
└── dot_config/
    ├── zsh/
    │   └── dot-zshrc.d/
    │       └── 70-rust.zsh.tmpl         # Feature: rust
    └── cargo/                             # Also feature: rust
        └── config.toml.tmpl
```

With `.chezmoiignore`:
```
{{- if not .features.rust }}
.config/zsh/.zshrc.d/70-rust.zsh
.config/cargo/**
{{- end }}
```

Both files are controlled by the same feature flag, maintaining the logical package relationship!

## For Packages That Do Have Their Own Configs

### Example: Homebrew

Old stow structure:
```
dotfiles/homebrew/
└── dot-config/
    ├── homebrew/
    │   ├── Brewfile
    │   └── Brewfile.lock.json
    └── zsh/dot-zshrc.d/
        └── 50-homebrew.zsh
```

New chezmoi structure:
```
chezmoi/
└── dot_config/
    ├── homebrew/
    │   ├── Brewfile.tmpl
    │   └── Brewfile.lock.json.tmpl
    └── zsh/
        └── dot-zshrc.d/
            └── 50-homebrew.zsh.tmpl
```

With `.chezmoiignore`:
```
{{- if not .features.homebrew }}
.config/homebrew/**
.config/zsh/.zshrc.d/50-homebrew.zsh
{{- end }}
```

The feature flag `homebrew: false` disables BOTH the homebrew configs AND its zsh integration!

## Answer to Research Questions

### Can chezmoi files in `rust/` directory deploy to `~/.config/zsh/`?
**No, and it doesn't need to.** Files in chezmoi source mirror the target structure. Control deployment with `.chezmoiignore`.

### Do we need symlink_* attributes in .chezmoiignore?
**No.** `.chezmoiignore` uses template logic, not symlinks.

### Should we use chezmoi templates to handle cross-directory deployments?
**We use templates for conditional deployment, not cross-directory paths.** The source directory structure matches the target structure.

### What's the recommended chezmoi pattern for this use case?
**Location-based organization + feature flags in `.chezmoiignore`**:
1. Organize files by their deployment location
2. Use feature flags in `.chezmoidata.yaml`  
3. Use `.chezmoiignore` templates to conditionally exclude files
4. Maintain logical package relationships through naming and documentation

## Implementation Plan

### For Simple Packages (zsh integration only)
Put the zsh file directly in `dot_config/zsh/dot-zshrc.d/` with package name in filename:
- `70-rust.zsh.tmpl`
- `70-golang.zsh.tmpl`
- `70-python.zsh.tmpl`

### For Complex Packages (own configs + zsh integration)
Put configs in their own directory AND zsh file in zsh directory:
- `dot_config/asdf/asdfrc.tmpl` (package configs)
- `dot_config/zsh/dot-zshrc.d/50-asdf.zsh.tmpl` (zsh integration)

Both controlled by same feature flag in `.chezmoiignore`:
```
{{- if not .features.asdf }}
.config/asdf/**
.config/zsh/.zshrc.d/50-asdf.zsh
{{- end }}
```

### For Completion Files
Put in `dot_cache/zsh/completions/` with feature flag control:
```
chezmoi/
└── dot_cache/
    └── zsh/
        └── completions/
            ├── _rustc.tmpl     # Rust package
            ├── _cpanm.tmpl     # Perl package  
            └── _vagrant.tmpl   # Vagrant package
```

## Benefits of This Approach

1. **Simple**: Source mirrors target, no complex path manipulation
2. **Transparent**: `chezmoi diff` shows exactly what deploys where
3. **Flexible**: Easy to add/remove packages via feature flags
4. **Maintainable**: Clear connection between feature flag and affected files
5. **Documented**: Can create mapping docs showing which files belong to which packages

## Next Steps

Proceed with TODO #4: Design the complete target structure based on this understanding.

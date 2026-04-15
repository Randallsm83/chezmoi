---
name: Dotfiles source directory
description: The chezmoi source of truth is ~/.local/share/dotfiles, NOT ~/projects/dotfiles — always edit and commit there
type: feedback
---

The chezmoi source directory (where edits and commits should happen) is `~/.local/share/dotfiles`. The copy at `~/projects/dotfiles` is a stale clone — do NOT edit or commit there.

**Why:** The user corrected this after a full session of editing the wrong directory. `chezmoi.toml.tmpl` sets `sourceDir` to `~/.local/share/dotfiles`, and that's the repo the user actively maintains.

**How to apply:** When working on dotfiles, always operate in `~/.local/share/dotfiles`. If the CWD is `~/projects/dotfiles`, changes still need to be synced/committed in the real source.

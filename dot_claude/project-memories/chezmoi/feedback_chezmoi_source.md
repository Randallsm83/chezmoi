---
name: Chezmoi source directory
description: The chezmoi source of truth is ~/.local/share/chezmoi, NOT ~/projects/chezmoi — always edit and commit there
type: feedback
---

The chezmoi source directory (where edits and commits should happen) is `~/.local/share/chezmoi`. Any copy under `~/projects/chezmoi` (or junctions like `D:\chezmoi` pointing at it) ultimately resolves to the same repo; treat `~/.local/share/chezmoi` as the canonical path.

**Why:** chezmoi's default `sourceDir` is `~/.local/share/chezmoi` and `.chezmoi.toml.tmpl` does NOT override it. Editing under an unrelated path that happens to be named `chezmoi` (or the legacy `dotfiles` path) will not be picked up by `chezmoi apply`.

**How to apply:** When working on the chezmoi-managed dotfiles, always operate in `~/.local/share/chezmoi`. Any other location (including a junction) should be treated as a view onto the same source — never a separate working copy.

# dot_config/zsh/dot_zshrc.d/

Zsh init fragments. Sourced in **lexicographic order** by `dot_zshrc.tmpl` — the numeric prefix is the load-order knob. See [root AGENTS.md](../../../AGENTS.md) for chezmoi naming, line endings, and the broader shell setup.

## File-by-file (current snapshot)

| Range | File | Loads |
|---|---|---|
| 00 | `00-helpers.zsh` | Shared helpers used by later fragments |
| 01 | `01-mise.zsh` | Mise activation — MUST run first; later fragments read PATH installed by mise shims |
| 05 | `05-completions-helper.zsh` | Completion plumbing for the rest of the file set |
| 05 | `05-lde-env.zsh` | DreamHost LDE env vars |
| 10 | `10-1password-ssh-agent.zsh` | Resolve `SSH_AUTH_SOCK` to the 1P agent socket |
| 10 | `10-dirs.zsh` | Workspace dir vars (`$PROJECTS`, `$DOTFILES`, …) |
| 20 | `20-paths.zsh` | PATH manipulation — runs AFTER mise and dir vars are set |
| 25 | `25-alias-finder.zsh`, `25-aliases-ndn.zsh`, `25-aliases.zsh`, `25-common-aliases.zsh`, `25-functions.zsh`, `25-gnu-utils.zsh`, `25-history-substring-search.zsh`, `25-history.zsh` | Aliases, functions, history widgets |
| 30 | `30-misc.zsh` | Misc shell options |
| 40 | `40-wezterm.zsh` | Wezterm shell integration (must precede prompt) |
| 50 | `50-homebrew.zsh`, `50-mise.zsh` | Package-manager shims/env |
| 60 | `60-vagrant.zsh` | Vagrant CLI integration |
| 70 | `70-arduino.zsh`, `70-bun.zsh`, `70-golang.zsh.tmpl`, `70-lua.zsh.tmpl`, `70-node.zsh.tmpl`, `70-npm.zsh`, `70-nvm.zsh`, `70-perl.zsh`, `70-php.zsh`, `70-python.zsh.tmpl`, `70-ruby.zsh.tmpl`, `70-rust.zsh.tmpl` | Per-language env (each gated by `package_features.<lang>` via `.chezmoiignore` for `.tmpl` files, plain `.zsh` for unconditional langs) |
| 80 | `80-bat.zsh`, `80-completions.zsh`, `80-eza.zsh.tmpl`, `80-fzf.zsh.tmpl`, `80-op.zsh`, `80-ripgrep.zsh`, `80-rust-alternatives.zsh`, `80-scott.zsh`, `80-tinty.zsh.tmpl`, `80-wget.zsh`, `80-zoxide.zsh` | CLI tool integrations (need PATH from 20/50, langs from 70) |
| 85 | `85-git.zsh`, `85-vscode.zsh` | High-level integrations needing earlier sections |
| 90 | `90-starship.zsh`, `90-thefuck.zsh` | Prompt + command correction (need PATH and tool detection) |
| 99 | `99-warp.zsh` | Warp terminal — last-resort consumer |

## Conventions

- **Lower numbers source first.** A new file picks the lowest prefix in the range that captures its dependencies.
- **`.tmpl` suffix** means chezmoi processes the file as a Go template before deploying. Used to gate language sections by `package_features.<lang>` and to inject theme/font vars. Plain `.zsh` files are deployed verbatim.
- **Feature-flag gating** — `.chezmoiignore` removes templated language files when the matching flag is `false` (e.g. `70-rust.zsh.tmpl` skipped if `package_features.rust = false`). Plain non-templated files are NOT gated this way; if a tool can be absent, write it as `.tmpl` or guard with `command -v <tool> >/dev/null || return`.
- **No source order assumptions across prefix ranges other than "lower first".** Within a range, files load alphabetically — order within `25-*`, `70-*`, `80-*` is alphabetical.
- **Completions** for individual tools live in `~/.cache/zsh/completions/_<command>` (source: `dot_cache/zsh/completions/`), not here.

## Anti-patterns

- DO NOT add a file in a prefix range that violates its dependencies (e.g. a `25-*` referencing a binary installed by `50-mise.zsh`). Use a higher prefix.
- DO NOT call `mise activate` outside `01-mise.zsh` / `50-mise.zsh` — duplicate activation reorders PATH unpredictably.
- DO NOT add CRLF line endings — `.gitattributes` enforces LF on `*.zsh`. Verify with `git ls-files --eol dot_config/zsh/`.
- DO NOT inline tool integration that ships an upstream script — source the upstream init via `eval "$(<tool> init zsh)"` so the integration tracks upstream changes.

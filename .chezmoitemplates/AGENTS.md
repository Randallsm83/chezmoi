# .chezmoitemplates/

Reusable Go-template fragments. Imported by other `.tmpl` files via `{{ "{{ template \"name\" . }}" }}` (no args) or `{{ "{{ includeTemplate \"name\" (dict ...) }}" }}` (with args). See [root AGENTS.md](../AGENTS.md) for chezmoi conventions, template variables, and secrets architecture.

<!--
NOTE TO EDITORS: Chezmoi loads every file in `.chezmoitemplates/` as a Go
template at startup, even non-`.tmpl` markdown. Any literal double-brace
expression in this file MUST be wrapped as `{{ "{{ ... }}" }}` so the parser
sees a string literal, not template syntax. Otherwise `chezmoi status` /
`chezmoi apply` aborts with a parse error before doing anything. This same
trap will hit you anywhere inside this file — prose, code blocks, HTML
comments, even table cells. There is no escape hatch besides the literal-
string trick above (Go template comments would work but cannot wrap content
that itself contains the `*/}}` end marker, which this file does in line 42).
-->

## Inventory

| Partial | Kind | Purpose |
|---|---|---|
| `common-header` | bash | Canonical script header — `set -euo pipefail`, color codes, `log_info`/`log_success`/`log_warning`/`log_error` with timestamps. Include at top of every `.sh.tmpl` script. |
| `ps-logging` | PowerShell | Canonical PS logging — `Write-Status -Type Info\|Success\|Warning\|Error`, `Write-LogLine`, `Get-StatusLogFile`. Mirrors output to `$XDG_STATE_HOME\dotfiles\logs\<script>.log`. Include at top of every `.ps1.tmpl` script. |
| `platform-detect` | bash | Pure-shell `detect_os` / `is_wsl` / `is_container` / arch helpers. Used in scripts that need fine-grained OS detection beyond `.chezmoi.os`. |
| `1password` | bash | High-level helpers: `has_1password_cli`, `is_1password_authenticated`, `ensure_1password_auth`, `has_1password_item`, `get_1password_field`, `get_1password_document`. Use in scripts that need to branch on op state. |
| `1password-agent.toml` | TOML | Emits the `[[ssh-keys]]` vault list for 1Password's SSH agent config. Driven by `.ssh.onepassword_vaults` in [`.chezmoidata/ssh.yaml`](../.chezmoidata/ssh.yaml). |
| `op-read-safe` | template fn | **Legacy** single-secret resolver. Wraps `op read <ref>` with error-swallowing + `CHEZMOI_SKIP_1P` gate. Each invocation = one biometric prompt — prefer `.secrets.*` batch in `.chezmoi.toml.tmpl`. Retained for one-offs only. |
| `mise-tool-entry` | template fn | Converts a mise package string (`node@lts`, `github:user/repo`, `fzf`) into a TOML `[tools]` entry with correct quoting for `:` and `/`. Used by `dot_config/mise/config*.toml.tmpl`. |
| `ssh-pub-resolve` | template fn | Resolves an SSH public key with precedence: `.secrets.<key>` → `ssh-add -L` (matched by comment suffix, non-Windows only) → empty. Keeps SSH working on remote hosts where `op` is absent. |

## Call signatures

```go
// No args — implicit `.`
{{ "{{ template \"common-header\" . }}" }}
{{ "{{ template \"platform-detect\" . }}" }}

// With args — dict + `.` as root
{{ "{{ includeTemplate \"op-read-safe\" (dict \"ref\" \"op://Personal/GitHub/token\" \"os\" .chezmoi.os) }}" }}
{{ "{{ includeTemplate \"ssh-pub-resolve\" (dict \"key\" \"ssh_pub_dh_yakko\" \"comment\" \"Yakko SSH Key\" \"root\" .) }}" }}
{{ "{{ includeTemplate \"mise-tool-entry\" \"node@lts\" }}" }}
```

## Conventions

- **One purpose per partial.** If you find yourself adding a flag, you probably want a new partial.
- **Always document the call signature** in a leading `{{ "{{- /* ... */ -}}" }}` block. Every partial here does.
- **Safe failure** — partials that touch external tools (`op`, `ssh-agent`) MUST return empty string on error, never abort `chezmoi apply`. See `op-read-safe` line 14 for the canonical guard pattern.
- **PS native exit code trap** — `op-read-safe` documents why pwsh needs `$LASTEXITCODE` normalization + `exit 0`: PowerShell try/catch does NOT catch native command exit codes, and unhandled non-zero propagates up and aborts `chezmoi apply`.

## Anti-patterns

- DO NOT add a partial that calls `op read` for every render — that's one biometric prompt per file. Batch into `$secretsTpl` in `.chezmoi.toml.tmpl` and surface as `.secrets.*`.
- DO NOT inline `common-header` / `ps-logging` content into individual scripts — drift between sites is the failure mode this file exists to prevent. (The two `iwr | iex` bootstrap scripts are the documented exception; update both sites in lockstep.)
- DO NOT use the older `package-manager` / `detect-package-manager` / `platform-conditional` / `xdg-paths` partials — they were never wired up and have been removed. Package routing is now `.chezmoidata/packages.yaml` `package_mapping`, XDG paths live in `.chezmoi.toml.tmpl` `[data]`.

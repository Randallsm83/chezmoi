# Secrets Management Guide

This guide explains how to securely manage secrets (API tokens, SSH keys, credentials) in your dotfiles using chezmoi with 1Password or age encryption.

---

## Overview

Chezmoi supports multiple methods for managing secrets:

1. **1Password CLI** (Recommended) - Integrate with 1Password vaults
2. **age encryption** (Fallback) - Encrypted files with public key cryptography
3. **No secrets** (Limited) - Skip secret-dependent features

Your dotfiles automatically detect and use the available secrets manager.

---

## Two complementary secret-injection patterns

This repo uses **two patterns**, applied to different problems:

| Pattern | When to use | Where the secret ends up |
|---|---|---|
| **A. Render-time** (`.secrets.*` chezmoi namespace) | Secret must end up as a literal inside a rendered config file (e.g. SSH `authorized_keys`, public-key fingerprints, `.gitconfig` signing keys). | In the rendered file on disk. |
| **B. Runtime** (`op run --env-file`) | Secret is an env var consumed by a CLI/process at launch (API keys, tokens, MCP server credentials). | Only in the child process's environment — never on disk. |

If you ever find yourself baking an API key literal into a rendered config
file via Pattern A, that's a smell — Pattern B almost certainly fits better.

---

## Architecture A: Batched Render-Time Resolution

This pattern uses a **single batched `op inject` call** in `.chezmoi.toml.tmpl`
that resolves every `op://` reference at chezmoi init time and exposes the
results as the `.secrets.*` template variable namespace. Templates never call
`op` directly.

### Why batched?

1Password CLI requires a biometric/PIN approval **per `op` invocation** on
Windows. Calling `op` from each template (the previous `op-read-safe`
approach) meant N approvals per `chezmoi apply`. Batching collapses all
secret reads into one `op inject` invocation — **one approval, period.**

### Cost model

- `chezmoi apply --init`  → 1 biometric prompt (re-renders chezmoi.toml)
- `chezmoi apply`         → 0 prompts (uses cached chezmoi.toml)
- `chezmoi diff/status`   → 0 prompts
- `CHEZMOI_SKIP_1P=1`     → 0 prompts; secrets resolve to empty strings

### Adding a new secret

1. Open `.chezmoi.toml.tmpl`, find `$secretsTpl`, append a line:
   ```
   my_new_token = "{{ op://Vault/Item/field }}"
   ```
2. Reference it in any template as `{{ .secrets.my_new_token }}`.
3. Run `chezmoi apply --init` to refresh.

### Refresh after rotation

After rotating a key/PAT in 1Password, run:
```
chezmoi apply --init
```
The `--init` flag re-renders `chezmoi.toml` from `.chezmoi.toml.tmpl`,
triggering exactly one `op inject` and one biometric prompt.

### Skip 1Password (offline / CI)

```pwsh
$env:CHEZMOI_SKIP_1P = "1"
chezmoi apply --init
```
All `.secrets.*` values resolve to empty strings; templates that gate on
them (e.g. `{{ if .secrets.warp_api_key }}...{{ end }}`) are skipped.

### Variant: env-file materialization

When the consumer is a tool that auto-loads `KEY=value` files at runtime
(mise's `_.file` directive, direnv, dotenv-style apps), Pattern A renders
the secret into an env file rather than embedding it inline in a config.

The recipe:

1. **Source**: `dot_config/<scope>/private_secrets.env.tmpl` with `KEY={{ .secrets.foo }}` lines, one per env var.
2. **`private_` prefix**: chezmoi sets 0600 on Unix; on Windows the file inherits user-only ACLs from being inside `~/.config`.
3. **Consumer**: configure the tool to read that file at the deployed path (`~/.config/<scope>/secrets.env`).

For mise specifically:

```toml
# project mise.toml
[env]
_.file = "~/.config/<scope>/secrets.env"
```

This avoids mise's `exec()` template re-running per `cd` (which prompts
biometrics or fails when 1Password is locked) by resolving the secret
once at `chezmoi apply --init` time and letting mise read the cached
file every shell load.

Trade-off vs Pattern B: the secret IS on disk (file ACLs are the only
protection), but works for tools that can't be cleanly wrapped (mise's
per-cd env loading hook, anything that reads `.env` files directly).

Refresh ritual: same as Pattern A — `chezmoi apply --init` after rotating
in 1Password. The new value materializes into the env file on next apply.

Example in this repo: `dot_config/dh/private_secrets.env.tmpl` materializes
`DH_GITLAB_TOKEN` from `.secrets.dh_gitlab_pat` for the project mise config.

### Current secrets bundle

Defined in `.chezmoi.toml.tmpl` $secretsTpl:

- `ssh_pub_github_com`
- `ssh_pub_gitlab_com`
- `ssh_pub_dh_git`
- `ssh_pub_dh_yakko`
- `ssh_pub_dh_porky`
- `ssh_pub_***REMOVED***`
- `ssh_pub_fp3`
- `warp_api_key` — **still injected as a literal into the rendered PowerShell profile.** Candidate for migration to Pattern B if a Warp wrapper is added.
- `anthropic_api_key` — **no longer referenced by any template.** Claude Code receives it at runtime via the `claude` op-run wrapper (Pattern B). The bundle entry can be removed once nothing else needs it.
- `gitlab_pat`
- `dh_gitlab_pat` — materialized to `~/.config/dh/secrets.env` for mise `_.file` consumption (env-file variant; see above).

### Legacy: `op-read-safe`

The `.chezmoitemplates/op-read-safe` partial is retained for one-off cases
but is **not the preferred pattern** — each invocation triggers its own
biometric prompt. Prefer adding to `$secretsTpl` instead.

---

## Architecture B: Runtime Injection via `op run`

For CLI tools that read API keys / tokens from their environment at launch,
we wrap the binary so that `op run --env-file=...` resolves `op://` references
from 1Password and injects the resulting env vars into the child process. The
plaintext secret never lands on disk and never lives in the parent shell.

### Pattern

Three pieces, one per tool:

1. **1Password item** — the actual credential. Prefer item-UUID references
   (stable across renames) over the human title. Example:
   `op://Personal/63ydj7e44lzuwzjr4fnjrvmqvu/credential` (Tavily).
2. **Env-reference file** — a non-secret file mapping env-var names to
   `op://` references. Lives at `~/.config/op/<tool>.env` (chezmoi-managed at
   `dot_config/op/<tool>.env`):
   ```dotenv
   TAVILY_API_KEY=op://Personal/63ydj7e44lzuwzjr4fnjrvmqvu/credential
   ANTHROPIC_API_KEY=op://Personal/Anthropic API/credential
   # ... only secrets the wrapped tool needs
   ```
3. **Wrapper function** — defined in `Documents/PowerShell/Scripts/99-functions.ps1`,
   resolves the binary through `op run`:
   ```powershell
   if (Test-CommandExists 'op') {
       function claude {
           $envFile = Join-Path $HOME '.config\op\claude.env'
           if (Test-Path $envFile) {
               & op run --env-file=$envFile --no-masking -- claude.exe @args
           } else {
               & claude.exe @args
           }
       }
   }
   ```

### Why per-tool env files (not one shared file)

**Principle of least privilege.** `op run --env-file=foo.env` injects every
variable in `foo.env` into the child. A flat `secrets.env` would expose every
credential to every wrapped tool. Per-tool files mean a `claude` invocation
only sees what `claude.env` lists; an `aider` invocation only sees what
`aider.env` lists; etc. Duplication of `op://` *references* (not values) across
files is cheap and self-documenting.

### Cost model

- First call per session → 1 biometric prompt (then cached by op desktop integration).
- Subsequent calls within the cache window → 0 prompts.
- `chezmoi apply` / `diff` / `status` → 0 prompts (Pattern B is runtime-only).

### Adding a new tool

Example: wiring up `aider` with `ANTHROPIC_API_KEY` and `OPENAI_API_KEY`.

1. **Ensure 1Password items exist** for each secret. Create if needed:
   ```pwsh
   op item create --category="API Credential" --vault=Personal `
     --title="OpenAI API" "credential=<paste>"
   ```
2. **Create the env-reference file** at
   `dot_config/op/aider.env` (chezmoi source):
   ```dotenv
   ANTHROPIC_API_KEY=op://Personal/Anthropic API/credential
   OPENAI_API_KEY=op://Personal/OpenAI API/credential
   ```
3. **Add the wrapper** to `Documents/PowerShell/Scripts/99-functions.ps1`
   under the "AI / MCP Wrappers" section, mirroring the `claude` function.
4. `chezmoi apply` — renders the env file and updated functions script.
5. New shells will load the wrapper automatically. To use immediately, source
   the file: `. "$HOME\Documents\PowerShell\Scripts\99-functions.ps1"`.

### Adding a new secret to an existing tool

1. Append a line to `dot_config/op/<tool>.env` in the chezmoi source:
   ```dotenv
   NEW_VAR=op://Vault/Item/field
   ```
2. `chezmoi apply`. No code changes — the wrapper picks it up automatically.

### Rotating a secret

1. Generate the new key at the provider.
2. Update the 1Password item:
   ```pwsh
   op item edit "Tavily MCP" --vault Personal credential="<new>"
   ```
3. Done. No file edits, no `chezmoi apply` — the next wrapper invocation
   resolves the new value.

### Current Pattern B inventory

| Wrapper | Env file | Secrets injected |
|---|---|---|
| `claude` | `~/.config/op/claude.env` | `ANTHROPIC_API_KEY`, `TAVILY_API_KEY`, `VERCEL_TOKEN`, `NEON_API_KEY`, `QDRANT_API_KEY` |
| `opencode` | `~/.config/op/opencode.env` | `ANTHROPIC_API_KEY`, `TAVILY_API_KEY`, `VERCEL_TOKEN`, `NEON_API_KEY`, `QDRANT_API_KEY` |
| `tvly` | `~/.config/op/tvly.env` | `TAVILY_API_KEY` |
| `omp` | `~/.config/op/omp.env` | `OMP_AUTH_BROKER_TOKEN`, `TAVILY_API_KEY`, `QDRANT_API_KEY` |

`~/.claude.json` references these via `${VAR_NAME}` substitution in HTTP
header values and stdio MCP `env` blocks, so all four MCP servers
(`tavily`, `vercel`, `neon`, `qdrant`) connect through the wrapper without
any literal credentials in `~/.claude.json`.


`~/.config/opencode/opencode.json` references these via `{env:VAR_NAME}`
substitution (opencode's syntax — different from Claude Code's `${VAR_NAME}`).
The MCP block in `opencode.json` is runtime-managed by opencode. The
`oh-my-openagent` plugin imports Claude Code's MCP entries (`claude_code.mcp:
true`), so opencode reuses the standalone entries synced into `~/.claude.json`.

### Verifying no leakage

```pwsh
# .claude.json should contain ${VAR} placeholders, not literal tokens
Select-String -Path "$HOME\.claude.json" -Pattern 'tvly-|sk-ant-|eyJ[A-Za-z0-9_-]+\.eyJ'
# (no output expected)

# Process env should NOT have ANTHROPIC_API_KEY in a fresh shell
pwsh -NoProfile -Command 'if ($env:ANTHROPIC_API_KEY) { "LEAK" } else { "clean" }'
```

---

## Other secret stores (fallback options)

The canonical paths above (Patterns A and B) are what this repo uses today.
The rest of this section captures alternatives — use them only when you
need to depart from the canonical setup.

### 1Password CLI direct (`onepassword*` template funcs)

Chezmoi exposes built-in helpers (`onepasswordItemFields`,
`onepasswordDocument`, `onepasswordRead`). Each invocation triggers its
own biometric prompt, so the batched `op inject` pattern in Architecture A
is strictly preferred. Use the direct helpers only for one-off cases
that can't fit into `$secretsTpl` — e.g. when you need to look up multiple
items by name at apply time. See the
[chezmoi 1Password docs](https://www.chezmoi.io/user-guide/password-managers/1password/)
for the full API.

### age encryption (backup mechanism)

For secrets that must travel inside the repo (e.g. backups for an offline
machine), age-encrypted `.age` files are the supported alternative.

```bash
# Generate a key once and back it up to 1Password.
age-keygen -o ~/.config/chezmoi/key.txt
chmod 600 ~/.config/chezmoi/key.txt
```

Wire age into `.chezmoi.toml.tmpl`:

```toml
encryption = "age"
[age]
    identity = "~/.config/chezmoi/key.txt"
    recipient = "age1..."   # output of `age-keygen -y key.txt`
```

Then add encrypted files with `chezmoi add --encrypt <path>` (chezmoi
automatically handles encryption and decryption inside templates via
the `decrypt` function). Keep the private key out of the repo and store
it in 1Password so it's recoverable on a clean machine.

If you need this, also see the
[chezmoi encryption docs](https://www.chezmoi.io/user-guide/encryption/).

### No secrets mode (CI / public machines)

Set `CHEZMOI_SKIP_1P=1` (Architecture A respects this and resolves every
`.secrets.*` value to an empty string). Templates that gate on a secret
(`{{ if .secrets.warp_api_key }}...{{ end }}`) are skipped silently.
This is the right mode for:

- Testing on a fresh VM/container without any vaults available.
- CI/CD pipelines that don't have desktop integration.
- Public/loaner machines where biometric prompts would block automation.

---

## Secrets Validation

Your dotfiles automatically validate secrets on every `chezmoi apply`:

```bash
# Validation script runs automatically
chezmoi apply

# Or run manually
chezmoi cd
bash .chezmoiscripts/run_onchange_before_01_validate-secrets.sh.tmpl
```

**Validation checks:**
- ✅ Secrets manager is installed
- ✅ Secrets manager is authenticated (1Password) or key exists (age)
- ✅ Required secrets are accessible
- ⚠️ Warns about missing optional secrets
- ℹ️ Provides setup instructions if not configured

---

## Per-Machine Configuration

Use `.chezmoi.local.toml` for machine-specific overrides. The chezmoi
source template doesn't read a `use_1password` toggle — secret presence is
decided by whether `op` is on PATH and whether `CHEZMOI_SKIP_1P` is set
(see Architecture A). Per-machine knobs typically come down to the
`setup_1password` flag and feature flags:

**Personal laptop (1Password CLI signed-in):**
```toml
[data]
    setup_1password = true
```

**Work laptop using age instead of 1Password for repo-tracked secrets:**
```toml
# Re-render only when op is unavailable. Architecture A still wins when both
# are configured; age is only consulted for explicitly-encrypted .age files.
encryption = "age"
[age]
    identity = "~/.config/chezmoi/work-key.txt"
    recipient = "age1work_public_key_here"
```

**Remote server (no secrets):**
```toml
[data]
    setup_1password = false
    setup_ssh = false
```

Set `CHEZMOI_SKIP_1P=1` in the environment to make `chezmoi apply --init`
resolve every `.secrets.*` value to an empty string, with no biometric
prompt and no `op` invocation.

---

## Best Practices

### Security

1. **Never commit unencrypted secrets**
   - Always use 1Password or age encryption
   - Check `.gitignore` includes secret files
   - Use `git log --all --full-history -- *secret*` to verify

2. **Rotate secrets regularly**
   - Update in 1Password or re-encrypt with age
   - Run `chezmoi apply` to deploy changes

3. **Backup encryption keys**
   - Store age private key in 1Password
   - Store in multiple secure locations
   - Test recovery procedure

4. **Use minimal permissions**
   - GitHub tokens: only grant required scopes
   - SSH keys: use separate keys for different services
   - 1Password: use item-specific sharing

### Organization

1. **Consistent naming**
   - Use title case in 1Password: "SSH Private Key"
   - Document required fields
   - Use tags for categorization

2. **Documentation**
   - Comment templates that use secrets
   - Document which secrets are required vs optional
   - Provide setup instructions

3. **Testing**
   - Test on fresh machine without secrets
   - Verify graceful fallback
   - Test with dry-run: `CHEZMOI_DRY_RUN=1 chezmoi apply`

---

## Migration

### From no secrets to 1Password

1. Install 1Password CLI and authenticate
2. Create required items in 1Password
3. Enable in `.chezmoi.local.toml`
4. Run `chezmoi apply`
5. Delete old plaintext secrets

### From age to 1Password

1. Decrypt age-encrypted secrets:
   ```bash
   age -d -i ~/.config/chezmoi/key.txt encrypted_file.age
   ```
2. Add decrypted secrets to 1Password
3. Update templates to use 1Password functions
4. Remove `.age` files from repository
5. Enable 1Password in configuration

### From 1Password to age

1. Export secrets from 1Password (via CLI or app)
2. Encrypt with age:
   ```bash
   echo -n "secret" | age -r $(age-keygen -y key.txt) > secret.age
   ```
3. Update templates to use age decryption
4. Disable 1Password in configuration

---

## Commands Reference

### 1Password

```bash
# Sign in
op signin

# List items
op item list

# Get item
op item get "GitHub Token"

# Get specific field
op item get "GitHub Token" --fields token

# Get document
op document get "SSH Private Key"

# Check authentication
op whoami
```

### age

```bash
# Generate key
age-keygen -o key.txt

# View public key
age-keygen -y key.txt

# Encrypt file
age -r PUBLIC_KEY -o encrypted.age file.txt

# Decrypt file
age -d -i key.txt encrypted.age

# Encrypt string
echo -n "secret" | age -r PUBLIC_KEY > encrypted.age
```

### chezmoi

```bash
# Add encrypted file
chezmoi add --encrypt ~/.ssh/id_ed25519

# Check what would be applied
chezmoi apply --dry-run --verbose

# View template output
chezmoi cat ~/.ssh/config

# Re-apply with new secrets
chezmoi apply --force

# Check secrets status
chezmoi cd
bash .chezmoiscripts/run_onchange_before_01_validate-secrets.sh.tmpl
```

---

## FAQ

**Q: Can I use both 1Password and age?**  
A: Yes! 1Password is preferred if authenticated, otherwise age is used as fallback.

**Q: What if I don't have secrets?**  
A: That's fine! The dotfiles will skip secret-dependent features and continue.

**Q: How do I add a new secret?**  
A: Add to 1Password or create new `.age` file, then update templates to reference it.

**Q: Can I use a different password manager?**  
A: Not currently. You can add support by creating a template library similar to `1password.tmpl`.

**Q: Is it safe to commit `.age` files?**  
A: Yes, if encrypted properly. But 1Password is safer as secrets never touch the repository.

**Q: How do I know which secrets are required?**  
A: Run validation script or check `.chezmoiscripts/run_onchange_before_01_validate-secrets.sh.tmpl`.

---

## See Also

- [1Password CLI Documentation](https://developer.1password.com/docs/cli/)
- [age Documentation](https://github.com/FiloSottile/age)
- [chezmoi Secrets Documentation](https://www.chezmoi.io/user-guide/password-managers/)
- [chezmoi.local.toml.example](https://github.com/Randallsm83/chezmoi/blob/main/chezmoi.local.toml.example)

---

**Last Updated**: 2026-05-25  
**Version**: 2.0.0 (in development)

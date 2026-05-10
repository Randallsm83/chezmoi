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
- `ssh_pub_easterseals`
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

1. **1Password item** — the actual credential.
   Example: `op://Personal/Tavily MCP/credential`
2. **Env-reference file** — a non-secret file mapping env-var names to
   `op://` references. Lives at `~/.config/op/<tool>.env` (chezmoi-managed at
   `dot_config/op/<tool>.env`):
   ```dotenv
   TAVILY_API_KEY=op://Personal/Tavily MCP/credential
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

`~/.claude.json` references these via `${VAR_NAME}` substitution in HTTP
header values and stdio MCP `env` blocks, so all four MCP servers
(`tavily`, `vercel`, `neon`, `qdrant`) connect through the wrapper without
any literal credentials in `~/.claude.json`.

`~/.config/opencode/opencode.json` references these via `{env:VAR_NAME}`
substitution (opencode's syntax — different from Claude Code's `${VAR_NAME}`).
The MCP block in `opencode.json` is rendered from the same
`.chezmoidata/mcp.yaml` source of truth, with placeholders rewritten on
apply. The `oh-my-openagent` plugin is configured (in
`~/.config/opencode/oh-my-openagent.jsonc`) with `claude_code.mcp: false`
so it does not also import the `${VAR}`-shaped Claude Code entries — those
wouldn't be expanded by opencode and would 401 into auto-OAuth.

### Verifying no leakage

```pwsh
# .claude.json should contain ${VAR} placeholders, not literal tokens
Select-String -Path "$HOME\.claude.json" -Pattern 'tvly-|sk-ant-|eyJ[A-Za-z0-9_-]+\.eyJ'
# (no output expected)

# Process env should NOT have ANTHROPIC_API_KEY in a fresh shell
pwsh -NoProfile -Command 'if ($env:ANTHROPIC_API_KEY) { "LEAK" } else { "clean" }'
```

---

## Option 1: 1Password CLI (Recommended)

### Why 1Password?

- ✅ No secrets in your dotfiles repository
- ✅ Easy to update secrets (change in 1Password, re-apply dotfiles)
- ✅ Cross-platform (Windows, macOS, Linux, WSL)
- ✅ Works with existing 1Password subscription
- ✅ Secure SSH agent integration

### Prerequisites

- 1Password account (personal or family plan)
- 1Password desktop app installed
- 1Password CLI installed

### Installation

**macOS/Linux:**
```bash
# Via mise (recommended)
mise use -g 1password-cli

# Via homebrew
brew install --cask 1password/tap/1password-cli

# Via curl
curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
  sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
```

**Windows:**
```powershell
# Via scoop (recommended)
scoop install 1password-cli

# Via winget
winget install --id AgileBits.1PasswordCLI
```

### Setup

1. **Enable 1Password CLI in desktop app:**
   - Open 1Password desktop app
   - Settings → Developer → Enable "Integrate with 1Password CLI"

2. **Authenticate CLI:**
   ```bash
   # Sign in to your account
   op signin
   
   # Verify authentication
   op whoami
   ```

3. **Create required secrets in 1Password:**
   
   See [Required Secrets](#required-secrets-in-1password) section below.

4. **Enable in dotfiles:**
   
   Create `.chezmoi.local.toml` (or edit `.chezmoi.toml.tmpl`):
   ```toml
   [data]
       use_1password = true
       onepassword_vault = "Personal"  # or your vault name
   ```

### Required Secrets in 1Password

Create these items in your 1Password vault:

#### 1. SSH Private Key

- **Item Type**: Secure Note or SSH Key
- **Title**: `SSH Private Key`
- **Fields**:
  - `private_key`: Your private key contents (ed25519 or RSA)
  - `public_key`: Your public key contents
  - `passphrase`: (optional) Key passphrase

**Generate new key if needed:**
```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
# Copy contents to 1Password
cat ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub
```

#### 2. GitHub Token

- **Item Type**: Password or API Credential
- **Title**: `GitHub Token`
- **Fields**:
  - `token`: Personal access token with repo scope
  - `username`: Your GitHub username

**Generate token:**
1. Go to https://github.com/settings/tokens
2. Generate new token (classic)
3. Select scopes: `repo`, `workflow`, `read:org`
4. Copy token to 1Password

#### 3. Git Signing Key (Optional)

- **Item Type**: Secure Note
- **Title**: `Git Signing Key`
- **Fields**:
  - `key`: GPG private key
  - `passphrase`: Key passphrase
  - `key_id`: GPG key ID

#### 4. Additional Secrets (Optional)

Create as needed for your use cases:
- `AWS Credentials`
- `Azure Credentials`
- `NPM Token`
- `PyPI Token`

### Usage in Templates

Chezmoi provides built-in functions for accessing 1Password:

**Get field value:**
```
{{ (onepasswordItemFields "GitHub Token").token.value }}
```

**Get document:**
```
{{ onepasswordDocument "SSH Private Key" }}
```

**Get entire item:**
```
{{ onepasswordRead "GitHub Token" }}
```

**With specific vault:**
```
{{ (onepasswordItemFields "GitHub Token" "Personal").token.value }}
```

### Example: `.ssh/config.tmpl`

```ssh-config
{{- if (onepasswordItemFields "SSH Private Key") }}
# SSH configuration with key from 1Password
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    AddKeysToAgent yes
{{- end }}
```

Then create `private_dot_ssh/private_id_ed25519.tmpl`:
```
{{- onepasswordDocument "SSH Private Key" -}}
```

### Troubleshooting 1Password

**"not authenticated" error:**
```bash
# Sign in again
op signin

# Or use session token
eval $(op signin)
```

**"item not found" error:**
- Verify item exists: `op item list`
- Check item name (case-sensitive)
- Verify vault name if specified
- Try without vault parameter

**Slow performance:**
```bash
# Use --vault flag to speed up lookups
op item get "GitHub Token" --vault Personal
```

**Check status:**
```bash
# Run validation script manually
chezmoi cd
bash .chezmoiscripts/run_onchange_before_01_validate-secrets.sh.tmpl
```

---

## Option 2: age Encryption (Fallback)

### Why age?

- ✅ No external dependencies (except age binary)
- ✅ Simple public key cryptography
- ✅ Works offline
- ✅ Portable across machines
- ❌ Secrets stored (encrypted) in repository
- ❌ Must re-encrypt when secrets change

### Installation

```bash
# Via mise (recommended)
mise use -g age

# Via homebrew
brew install age

# Via package manager
sudo apt install age    # Debian/Ubuntu
sudo dnf install age    # Fedora
sudo pacman -S age      # Arch
```

### Setup

1. **Generate encryption key:**
   ```bash
   # Generate key
   age-keygen -o ~/.config/chezmoi/key.txt
   
   # View public key
   age-keygen -y ~/.config/chezmoi/key.txt
   ```

2. **Secure the private key:**
   ```bash
   chmod 600 ~/.config/chezmoi/key.txt
   
   # IMPORTANT: Backup this file somewhere safe!
   # If you lose it, you cannot decrypt your secrets
   ```

3. **Add public key to chezmoi config:**
   
   Edit `.chezmoi.toml.tmpl`:
   ```toml
   encryption = "age"
   [age]
       identity = "~/.config/chezmoi/key.txt"
       recipient = "age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p"
   ```

4. **Enable in dotfiles:**
   ```toml
   [data]
       use_age = true
   ```

### Encrypting Secrets

**Encrypt a file:**
```bash
# Method 1: Use chezmoi
chezmoi add --encrypt ~/.ssh/id_ed25519

# Method 2: Manual encryption
age -r $(age-keygen -y ~/.config/chezmoi/key.txt) \
    -o ~/.local/share/dotfiles/private_dot_ssh/private_id_ed25519.age \
    ~/.ssh/id_ed25519
```

**Encrypt a string:**
```bash
# Encrypt GitHub token
echo -n "ghp_your_token_here" | \
    age -r $(age-keygen -y ~/.config/chezmoi/key.txt) \
    > ~/.local/share/dotfiles/encrypted_github_token.age
```

### Usage in Templates

**Decrypt file:**
```
{{ includeTemplate "decrypt-file" "encrypted_github_token.age" }}
```

**Decrypt inline:**
```
{{ decrypt "age" (include "encrypted_github_token.age") }}
```

### Example: `.gitconfig.tmpl` with age

```gitconfig
[user]
    name = {{ .name }}
    email = {{ .email }}
{{- if (stat (joinPath .chezmoi.sourceDir "encrypted_github_token.age")) }}
    signingkey = {{ include "encrypted_github_token.age" | decrypt "age" }}
{{- end }}
```

### Troubleshooting age

**"key not found" error:**
```bash
# Verify key exists
ls -la ~/.config/chezmoi/key.txt

# Verify key is valid
age-keygen -y ~/.config/chezmoi/key.txt
```

**Cannot decrypt:**
- Ensure you're using the correct private key
- Verify file was encrypted with matching public key
- Check file permissions: `chmod 600 ~/.config/chezmoi/key.txt`

---

## Option 3: No Secrets (Limited Mode)

If neither 1Password nor age is configured, your dotfiles will:

- ✅ Still install and configure most tools
- ❌ Skip SSH key configuration
- ❌ Skip GitHub token integration
- ❌ Skip any secret-dependent features

This is useful for:
- Testing on a new machine
- Public/work computers where secrets aren't needed
- Containers or CI/CD environments

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

Use `.chezmoi.local.toml` to configure secrets per machine:

**Personal laptop (use 1Password):**
```toml
[data]
    use_1password = true
    onepassword_vault = "Personal"
```

**Work laptop (use age with work keys):**
```toml
[data]
    use_age = true
[age]
    identity = "~/.config/chezmoi/work-key.txt"
    recipient = "age1work_public_key_here"
```

**Remote server (no secrets):**
```toml
[data]
    use_1password = false
    use_age = false
[features]
    setup_ssh = false
    setup_1password = false
```

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
- [.chezmoi.local.toml.example](https://github.com/Randallsm83/dotfiles/blob/main/.chezmoi.local.toml.example)

---

**Last Updated**: 2026-05-07  
**Version**: 2.0.0 (in development)

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
    -o ~/.local/share/chezmoi/private_dot_ssh/private_id_ed25519.age \
    ~/.ssh/id_ed25519
```

**Encrypt a string:**
```bash
# Encrypt GitHub token
echo -n "ghp_your_token_here" | \
    age -r $(age-keygen -y ~/.config/chezmoi/key.txt) \
    > ~/.local/share/chezmoi/encrypted_github_token.age
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

**Last Updated**: 2025-01-19  
**Version**: 2.0.0 (in development)

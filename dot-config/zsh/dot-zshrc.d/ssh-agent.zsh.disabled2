# Define the environment cache file for the SSH agent
ssh_env_cache="${SSH_CACHE_DIR:-$HOME/.cache/ssh}/agent.env"

# Start the SSH agent
function _start_agent() {
  # Ensure the cache directory exists
  local ssh_env_dir="${ssh_env_cache:h}" # Extract directory from file path
  [[ -d "$ssh_env_dir" ]] || mkdir -p "$ssh_env_dir" || {
    echo "Error: Could not create directory $ssh_env_dir" >&2
    return 1
  }

  if [[ -f "$ssh_env_cache" ]]; then
    . "$ssh_env_cache" > /dev/null

    # Check if $SSH_AUTH_SOCK is valid
    zmodload zsh/net/socket
    if [[ -S "$SSH_AUTH_SOCK" ]] && zsocket "$SSH_AUTH_SOCK" 2>/dev/null; then
      zstyle -t ':ssh-agent' debug && echo "Valid SSH_AUTH_SOCK"
      return 0
    fi
  fi

  zstyle -t ':ssh-agent' debug && echo "Starting ssh-agent..."
  eval $(ssh-agent -s -t 8h)  | sed '/^echo/d' >! "$ssh_env_cache"
  chmod 600 "$ssh_env_cache"
  . "$ssh_env_cache" > /dev/null
}

function _add_identities() {
  local id file sig
  local -a config_files config_identities zstyle_identities all_identities not_loaded
  local -A loaded_fingerprints

  # Parse IdentityFile entries from ~/.ssh/config
  config_files=($HOME/.ssh/config)
  for config in $config_files; do
    [[ -f "$config" ]] || continue
    config_identities+=($(awk '/^[[:space:]]*IdentityFile/ {print $2}' "$config"))
  done

  # Use zstyle to define additional identities
  zstyle -a ':ssh-agent' identities zstyle_identities || zstyle_identities=()

  # Combine identities and remove duplicates
  all_identities=(${(u)config_identities} ${(u)zstyle_identities})

  if [[ ${#all_identities[@]} -eq 0 ]]; then
    zstyle -t ':ssh-agent' debug && echo "No identities to add from .ssh/config or zstyle"
    return
  fi

  # Preload loaded fingerprints from ssh-agent
  while read -r key; do
    [[ -z "$key" ]] && continue
    # Extract and store the fingerprint for each loaded key
    fingerprint=$(echo "$key" | ssh-keygen -lf - 2>/dev/null | awk '{print $2}')
    [[ -n "$fingerprint" ]] && loaded_fingerprints["$fingerprint"]=1
  done < <(ssh-add -L 2>/dev/null || echo "")

  # Check which identities need to be added
  for file in $all_identities; do
    # Trigger shell expansion (e.g., `~` or `$HOME`)
    eval file="$file"

    # Resolve relative paths
    [[ "$file" != /* ]] && file="$HOME/.ssh/$file"

    # Skip invalid or non-existent files
    [[ -f "$file" ]] || continue

    # Get the fingerprint of the file
    sig="$(ssh-keygen -lf "$file" 2>/dev/null | awk '{print $2}')"

    # Add to `not_loaded` if not already in the agent
    if [[ -n "$sig" && -z "${loaded_fingerprints[$sig]}" ]]; then
      not_loaded+=("$file")
    fi
  done

  # Add identities if any are missing
  if [[ ${#not_loaded[@]} -eq 0 ]]; then
    zstyle -t ':ssh-agent' debug && echo "All identities are already loaded."
    return
  fi

  zstyle -t ':ssh-agent' debug && echo "Adding identities: ${not_loaded[@]}"
  ssh-add --apple-use-keychain "${not_loaded[@]}" > /dev/null 2>&1

  if [[ $? -eq 0 ]]; then
    zstyle -t ':ssh-agent' debug && echo "Successfully added identities."
  else
    zstyle -t ':ssh-agent' debug && echo "Error adding identities."
  fi
}

# Create symlink for SSH_AUTH_SOCK
function _setup_agent_symlink() {
  if [[ -n "$SSH_AUTH_SOCK" ]]; then
    local link="/tmp/ssh-agent-${USER}-screen"
    ln -sf "$SSH_AUTH_SOCK" "$link"
    zstyle -t ':ssh-agent' debug && echo "Agent socket linked to $link"
  fi
}

if [[ ! -d "$HOME/.ssh" ]]; then
  echo "No ~/.ssh directory found."
  return 1
fi

# Main logic
_start_agent
_add_identities
_setup_agent_symlink

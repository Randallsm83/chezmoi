# ███████╗██╗   ██╗███╗   ██╗ ██████╗████████╗██╗ ██████╗ ███╗   ██╗███████╗
# ██╔════╝██║   ██║████╗  ██║██╔════╝╚══██╔══╝██║██╔═══██╗████╗  ██║██╔════╝
# █████╗  ██║   ██║██╔██╗ ██║██║        ██║   ██║██║   ██║██╔██╗ ██║███████╗
# ██╔══╝  ██║   ██║██║╚██╗██║██║        ██║   ██║██║   ██║██║╚██╗██║╚════██║
# ██║     ╚██████╔╝██║ ╚████║╚██████╗   ██║   ██║╚██████╔╝██║ ╚████║███████║
# ╚═╝      ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝   ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝
# Custom shell functions.
#

#!/usr/bin/env zsh

#############
# Functions #
#############

# Time ZSH start
zstarttime() {
  for i in $(seq 1 10); do /usr/bin/time /bin/zsh -i -c exit; done
}

# Run a git command across every service repo under BACKEND/FRONTEND/HELPSERVICES.
# Skips entries without a .git directory. Top-level repos under $DHSPACE
# (ndn, ndn-audit, scott, task-management) are intentionally excluded.
dhgitall() {
    for dir in "$BACKEND"/*/ "$FRONTEND"/*/ "$HELPSERVICES"/*/; do
        [[ -d "$dir/.git" ]] || continue
        (cd "$dir" && echo "=== $(basename $dir) ===" && git "$@")
    done
}

# Nvim launchers (so `vi` / `vim` go through $EDITOR)
vi()  { ${=EDITOR} "$@" }
vim() { ${=EDITOR} "$@" }

# Visualize the 16 ANSI colors
16colors() {
  for i in {0..15}; do print -Pn "%K{$i}  %k%F{$i}${(l:3::0:)i}%f " ${${(M)$((i%6)):#3}:+$'\n'}; done
}

# Visualize the 256 ANSI colors
256colors() {
  for i in {0..255}; do print -Pn "%K{$i}  %k%F{$i}${(l:3::0:)i}%f " ${${(M)$((i%6)):#3}:+$'\n'}; done
}

# Generate ssh key with name and comment
sshkeygen() {
  ssh-keygen -t ed25519 -f ~/.ssh/"$1" -C "$2"
}

# Install chezmoi-managed dotfiles
dotinstall() {
  bash <(wget -qO- https://raw.githubusercontent.com/Randallsm83/chezmoi/refs/heads/main/install.sh)
}

# Quick move up directories
up() { cd "$(printf "%0.s../" $(seq 1 $1))" || return; }

# ASDF
lpkgasdf() {
  asdf plugin list-all G "$1"
}

# Mise
lpkgmise() {
  mise registry G "$1"
}

# Cargo
lpkgcargo() {
  cargo search "$1"
}

check_repos() {
  # Base directory containing all service/repo folders
  base_dir="$1"

  # Define colors
  GREEN=$(tput setaf 2)
  RED=$(tput setaf 1)
  YELLOW=$(tput setaf 3)
  CYAN=$(tput setaf 6)
  RESET=$(tput sgr0)

  # Check if the directory exists
  if [[ ! -d "$base_dir" ]]; then
    echo -e "${RED}Directory $base_dir does not exist.${RESET}"
    return 1
  fi

  # Iterate through each subdirectory
  for repo_dir in "$base_dir"/*; do
    if [[ -d "$repo_dir/.git" ]]; then
      echo -e "Checking repository in $repo_dir..."

      # Move into the repository
      cd "$repo_dir" || continue

      git checkout yarn.lock

      # Check for local changes
      if [[ -n "$(git status --porcelain)" ]]; then
        echo -e "${YELLOW}Repository in $repo_dir has local changes. Skipping.${RESET}"
        cd - > /dev/null || exit
        continue
      fi

      # Check the current branch
      current_branch=$(git symbolic-ref --short HEAD)
      if [[ "$current_branch" == "develop" || "$current_branch" == "staging" || "$current_branch" == "master" ]]; then
        echo -e "${CYAN}On branch $current_branch. Cleaning up node_modules...${RESET}"
        rm -rf node_modules
        echo -e "${GREEN}node_modules removed for $repo_dir.${RESET}"

        echo -e "${CYAN}Pulling changes${RESET}"
        # Suppress git pull output
        git pull --quiet
      else
        echo -e "${RED}Not on develop, staging, or master branch. Current branch: $current_branch. Skipping.${RESET}"
      fi

      # Move back to the base directory
      cd - > /dev/null || exit
    else
      echo -e "${YELLOW}Skipping $repo_dir: Not a Git repository.${RESET}"
    fi
  done
}

# Make directory and cd into it
mkcd() { mkdir -p "$1" && cd "$1" }

# Obsidian / Notes
# Fuzzy find note by name, open in Obsidian (requires: fd, fzf, bat, obsidian CLI)
nf() {
  local file
  file=$(fd --type f --extension md . "$NOTES" | sed "s|$NOTES/||" \
    | fzf --preview "bat --color=always $NOTES/{}")
  [[ -n "$file" ]] && obsidian open "file=$file"
}

# Fuzzy search note content, open match in Obsidian (requires: rg, fzf, obsidian CLI)
nfs() {
  local file
  file=$(rg --type md -l "$1" "$NOTES" | sed "s|$NOTES/||" \
    | fzf --preview "rg --color=always '$1' $NOTES/{}")
  [[ -n "$file" ]] && obsidian open "file=$file"
}

# Append a task to today's daily note
ntask() { obsidian daily:append "content=- [ ] $*"; }

# Quick fleeting note capture to inbox
nc() {
  local title="${*:-$(date +%Y%m%d-%H%M%S)}"
  obsidian create "name=$title" 'folder=00 Inbox'
}

# Grep notes (raw, no app required)
ngrep() { rg --type md "$@" "$NOTES"; }

# List all note/Obsidian aliases and functions with dependency status
note-tools() {
  local GREEN=$(tput setaf 2)
  local RED=$(tput setaf 1)
  local CYAN=$(tput setaf 6)
  local GRAY=$(tput setaf 7)
  local RESET=$(tput sgr0)

  echo "\n${CYAN}Dependencies${RESET}"
  local -A dep_desc
  dep_desc=(
    obsidian        "CLI (required for most commands)"
    obsidian-export "export vault to standard Markdown"
    rg              "ngrep, nfs content search"
    fd              "nf file finder"
    fzf             "interactive picker (nf, nfs)"
    bat             "nf preview"
  )
  local installed=0 total=0
  for name in obsidian obsidian-export rg fd fzf bat; do
    (( total++ ))
    if command -v "$name" &>/dev/null; then
      (( installed++ ))
      printf "  ${GREEN}✓${RESET} %-20s %s\n" "$name" "${dep_desc[$name]}"
    else
      printf "  ${RED}✗${RESET} %-20s %s\n" "$name" "${dep_desc[$name]}"
    fi
  done

  echo "\n${CYAN}Commands${RESET}"
  local cmds=(
    "notes:cd \$NOTES"
    "n [args]:obsidian CLI passthrough"
    "nd:open today's daily note"
    "nt:list today's tasks"
    "ntask <msg>:append task to today's daily note"
    "nc [title]:quick capture → 00 Inbox"
    "ntags:all tags with frequency"
    "norphans:notes with no backlinks"
    "nunresolved:broken wikilinks"
    "nhome:open HOME dashboard"
    "ninbox:open 00 Inbox"
    "nf:fuzzy find note by name → open"
    "nfs <query>:fuzzy search note content → open"
    "ngrep <pat>:grep all notes (no app required)"
  )
  for entry in $cmds; do
    printf "  ${GRAY}%-20s${RESET} %s\n" "${entry%%:*}" "${entry#*:}"
  done

  echo "\n${CYAN}${installed}/${total} dependencies available${RESET}\n"
}

# Combined update function
updateall() {
  echo "\n======================================"
  echo "Updating all package managers..."
  echo "======================================\n"

  if (( $+commands[brew] )); then
    echo ">>> Homebrew"
    brew update && brew upgrade && brew cleanup
    echo ""
  fi

  if (( $+commands[mise] )); then
    echo ">>> Mise"
    mise up && mise prune --yes
    echo ""
  fi

  if (( $+commands[tldr] )); then
    echo ">>> Tealdeer cache"
    tldr --update
    echo ""
  fi

  echo "======================================"
  echo "All updates complete!"
  echo "======================================\n"
}

# =================================================================================================
# AI / MCP Wrappers (1Password-injected secrets)
# =================================================================================================
# Wrap CLIs that need API keys so secrets are pulled from 1Password at launch
# rather than persisted in env vars or config files.
#
# Pattern: an env-reference file at ~/.config/op/<tool>.env contains
#   VAR=op://<vault>/<item>/<field>
# entries; we wrap the binary with `op run --env-file=...`. The resolved
# secrets exist only in the child process's environment.
#
# Mirrors the Windows pwsh wrappers in Documents/PowerShell/Scripts/lib/99-functions-body.ps1.
# Requires: op (1Password CLI) signed in. With the desktop-app integration
# enabled, biometric unlock makes the lookup invisible.
#
# Bypass: set OP_WRAPPER_DISABLE=1 to run the bare binary without injection.
if (( $+commands[op] )); then
  _op_run_wrapped() {
    # $1 = tool name (also basename of env file); remaining args forwarded.
    emulate -L zsh
    local tool=$1; shift
    local env_file="$HOME/.config/op/${tool}.env"
    local bin
    bin=$(whence -p "$tool") || {
      print -u2 "${tool}: command not found"
      return 127
    }
    if [[ -n $OP_WRAPPER_DISABLE ]] || [[ ! -r $env_file ]]; then
      [[ ! -r $env_file && -z $OP_WRAPPER_DISABLE ]] && \
        print -u2 "${tool}: env file not found at ${env_file} - running without secret injection"
      "$bin" "$@"
      return
    fi
    # Bypass op run for opencode: it uses its own auth login flow (ChatGPT
    # Pro/Plus subscription) rather than API-key injection. The WSL op wrapper
    # (Windows op.exe) also cannot spawn Linux ELF binaries, so this avoids
    # the "%PATH% not found" error on WSL.
    if [[ $tool == opencode ]]; then
      "$bin" "$@"
      return
    fi
    op run --env-file="$env_file" --no-masking -- "$bin" "$@"
  }

  opencode() { _op_run_wrapped opencode "$@"; }
  claude()   { _op_run_wrapped claude   "$@"; }
  omp()      { _op_run_wrapped omp      "$@"; }
fi
_omp_auth_host() {
  print -r -- "${OMP_AUTH_HOST:-raspi}"
}

_omp_gateway_public_base_url() {
  print -r -- "${OMP_GATEWAY_PUBLIC_BASE_URL:-https://raspi.alai-altair.ts.net/v1}"
}
_omp_broker_token() {
  ssh "$(_omp_auth_host)" docker exec auth-broker cat /root/.omp/auth-broker.token
}
_omp_gateway_token() {
  ssh "$(_omp_auth_host)" docker exec auth-gateway cat /root/.omp/auth-gateway.token
}

# Run omp auth-broker inside the homelab auth-broker container.
ompb() {
  if [[ ${1:-} == check ]]; then
    print -u2 "auth-broker has no check action; running auth-gateway check instead."
    ompg check
    return
  fi

  local broker_token
  broker_token="$(_omp_broker_token)" || return
  ssh -t "$(_omp_auth_host)" docker exec -it \
    -e OMP_AUTH_BROKER_URL=http://127.0.0.1:8765 \
    -e "OMP_AUTH_BROKER_TOKEN=${broker_token}" \
    auth-broker omp auth-broker "$@"
}

# Run omp auth-gateway inside the homelab auth-gateway container.
ompg() {
  local broker_token
  broker_token="$(_omp_broker_token)" || return
  ssh "$(_omp_auth_host)" docker exec \
    -e "OMP_AUTH_BROKER_TOKEN=${broker_token}" \
    auth-gateway omp auth-gateway "$@"
}

# Start an OAuth login for a provider in the homelab auth-broker container.
ompb-login() {
  if [[ $# -ne 1 ]]; then
    print -u2 "usage: ompb-login <provider-id>"
    return 2
  fi
  ompb login "$1"
}

# Print the public OpenAI-compatible OMP gateway base URL.
ompg-url() {
  _omp_gateway_public_base_url
}

# List OMP registry/provider model IDs from the gateway container.
ompg-models() {
  local broker_token
  broker_token="$(_omp_broker_token)" || return
  ssh "$(_omp_auth_host)" docker exec \
    -e "OMP_AUTH_BROKER_TOKEN=${broker_token}" \
    auth-gateway omp --list-models
}

# Query the public gateway models endpoint with the Pi gateway token.
ompg-api-models() {
  local gateway_token base_url
  gateway_token="$(_omp_gateway_token)" || return
  base_url="$(_omp_gateway_public_base_url)"
  curl -fsS -H "Authorization: Bearer ${gateway_token}" "${base_url}/models" |
    jq -r '.data[].id' |
    sort -u
}

# List OMP homelab auth helper commands.
omp-auth-tools() {
  local cyan reset
  cyan=$(tput setaf 6 2>/dev/null)
  reset=$(tput sgr0 2>/dev/null)

  print "\n${cyan}OMP auth helpers${reset}"
  print "  ompb <args>          run omp auth-broker in the auth-broker container"
  print "  ompb-login <id>      login provider in the auth-broker container"
  print "  ompg <args>          run omp auth-gateway in the auth-gateway container"
  print "  ompg-models          list OMP registry/provider model IDs"
  print "  ompg-api-models      list public OpenAI-compatible /v1/models IDs"
  print "  ompg-url             print the public /v1 base URL"
  print ""
  print "${cyan}Common examples${reset}"
  print "  ompb list"
  print "  ompb status"
  print "  ompb-login openai-codex"
  print "  ompg check"
  print "  ompg token"
  print "  ompg-api-models"
  print ""
  print "${cyan}Overrides${reset}"
  print "  export OMP_AUTH_HOST=raspi"
  print "  export OMP_GATEWAY_PUBLIC_BASE_URL=https://raspi.alai-altair.ts.net/v1"
  print ""
}

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

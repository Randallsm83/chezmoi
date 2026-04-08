# ███████╗███████╗██╗  ██╗
# ╚══███╔╝██╔════╝██║  ██║
#   ███╔╝ ███████╗███████║
#  ███╔╝  ╚════██║██╔══██║
# ███████╗███████║██║  ██║
# ╚══════╝╚══════╝╚═╝  ╚═╝
# Z Shell - powerful command interpreter.
#

#!/usr/bin/env zsh

#############
# Functions #
#############

# Time ZSH start
zstarttime() {
  for i in $(seq 1 10); do /usr/bin/time /bin/zsh -i -c exit; done
}

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

# Install dotfiles
dotinstall() {
  bash <(wget -qO- https://raw.githubusercontent.com/Randallsm83/dotfiles/refs/heads/main/install.sh)
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
  file=$(fd --type f --extension md . ~/notes | sed "s|$HOME/notes/||" \
    | fzf --preview 'bat --color=always ~/notes/{}')
  [[ -n "$file" ]] && obsidian open "file=$file"
}

# Fuzzy search note content, open match in Obsidian (requires: rg, fzf, obsidian CLI)
nfs() {
  local file
  file=$(rg --type md -l "$1" ~/notes | sed "s|$HOME/notes/||" \
    | fzf --preview "rg --color=always '$1' ~/notes/{}")
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
ngrep() { rg --type md "$@" ~/notes; }

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
    "notes:cd ~/notes"
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

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

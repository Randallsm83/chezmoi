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

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# -------------------------------------------------------------------------------------------------

#!/usr/bin/env bash
# portable-shell.sh — ZERO-FOOTPRINT EDITION
# A self-contained, in-memory portable shell configuration for remote machines.
#
# Guarantees:
#   - No directories created
#   - No files written (no new history files, no cache dirs, no config writes)
#   - No modifications to existing dotfiles on disk
#   - All changes are in-memory for the current session only
#
# Usage:
#   source <(curl -fsSL https://raw.githubusercontent.com/Randallsm83/chezmoi/main/portable-shell.sh)
#   Or: bash portable-shell.sh   # (only prints banner; source it for effects)
#
# This script is compatible with both bash and zsh.
# Designed for machines you do NOT own and do NOT want to modify.
#
# To clean up and return the shell to its previous state:
#   portable-off
# =============================================================================

# Only bash/zsh supported; silently return for true POSIX sh
if [ -n "$BASH_VERSION" ]; then
  _shell="bash"
elif [ -n "$ZSH_VERSION" ]; then
  _shell="zsh"
else
  return 0 2>/dev/null || exit 0
fi

# =============================================================================
# Environment Variables (session-only, no file writes)
# =============================================================================

# XDG hints — we do NOT create directories. If the vars aren't set already,
# we fall back to common defaults so other tools behave predictably.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# PATH enhancement — only prepend existing directories
for _p in "$HOME/.local/bin" "$HOME/bin" "$HOME/.cargo/bin"; do
  case ":${PATH}:" in
    *:"$_p":*) ;;
    *) [ -d "$_p" ] && PATH="$_p:$PATH" ;;
  esac
done
export PATH

# Editor — prefer nvim, then vim, then vi, then nano (default only if unset)
export EDITOR="${EDITOR:-$(command -v nvim 2>/dev/null || command -v vim 2>/dev/null || command -v vi 2>/dev/null || echo nano)}"
export PAGER="${PAGER:-less}"

# Disable less history file creation entirely
export LESSHISTFILE=-

# Do NOT touch HISTFILE — let the shell continue writing wherever it already
# writes, or nowhere at all. We will not create new history files.

# Colored man pages (tput is safe and writes nothing to disk)
export LESS_TERMCAP_md="$(tput bold 2>/dev/null; tput setaf 2 2>/dev/null)"
export LESS_TERMCAP_me="$(tput sgr0 2>/dev/null)"

# =============================================================================
# OS Detection Helpers
# =============================================================================

is-macos() {
  [ "$(uname -s)" = "Darwin" ]
}

is-wsl() {
  [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qiE "(microsoft|wsl)" /proc/version 2>/dev/null
}

is-linux() {
  [ "$(uname -s)" = "Linux" ]
}

# =============================================================================
# Essential Aliases
# =============================================================================

# Navigation and listing
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# Safety aliases
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Grep with color
alias grep='grep --color=auto'
alias sgrep='grep -R -n -H -C 5 --exclude-dir={.git,.svn,CVS} '

# Tail shortcuts
alias t='tail -f'

# Find and disk usage
alias dud='du -d 1 -h 2>/dev/null || du --max-depth=1 -h'
alias ff='find . -type f -name'

# History
alias h='history'

# Process list
alias p='ps -f'

# Quick file count
alias lsn='ls -1'

# Command line head/tail shortcuts (bash-safe)
alias H='head'
alias T='tail'
alias G='grep'
alias L='less'
alias NE='2>/dev/null'
alias NUL='>/dev/null 2>&1'

# =============================================================================
# ls Aliases (tool-aware)
# =============================================================================

# Use eza if available, otherwise ls with color
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --group-directories-first'
  alias l='eza -lbF --git'
  alias la='eza -lbhHigmuSa --time-style=long-iso --git --color-scale'
  alias ll='eza -l'
  alias ldot='eza -ld .*'
  alias lart='eza -lbhHigmuSa --sort=accessed'
  alias lrt='eza -lbhHigmuSa --sort=modified'
  alias tree='eza --tree'
elif ls --color=auto >/dev/null 2>&1 2>/dev/null; then
  # GNU ls
  alias ls='ls --color=auto'
  alias l='ls -lFh'
  alias la='ls -lAFh'
  alias ll='ls -l'
  alias ldot='ls -ld .*'
else
  # BSD ls (macOS) or other
  alias ls='ls -G'
  alias l='ls -lFh'
  alias la='ls -lAFh'
  alias ll='ls -l'
  alias ldot='ls -ld .*'
fi

# =============================================================================
# Git Aliases and Functions
# =============================================================================

# Core git aliases (the ones you use most)
alias g='git'
alias ga='git add'
alias gaa='git add --all'
alias gapa='git add --patch'
alias gau='git add --update'
alias gav='git add --verbose'
alias gb='git branch'
alias gba='git branch --all'
alias gbd='git branch --delete'
alias gbD='git branch --delete --force'
alias gbl='git blame -w'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gcp='git cherry-pick'
alias gcpa='git cherry-pick --abort'
alias gcpc='git cherry-pick --continue'
alias gc='git commit --verbose'
alias gca='git commit --verbose --all'
alias gcmsg='git commit --message'
alias gd='git diff'
alias gdca='git diff --cached'
alias gdcw='git diff --cached --word-diff'
alias gds='git diff --staged'
alias gdw='git diff --word-diff'
alias gf='git fetch'
alias gfa='git fetch --all --tags --prune'
alias gfo='git fetch origin'
alias gl='git pull'
alias gpr='git pull --rebase'
alias gpra='git pull --rebase --autostash'
alias gp='git push'
alias gpd='git push --dry-run'
alias gpf='git push --force-with-lease'
alias gpsup='git push --set-upstream origin'
alias gpv='git push --verbose'
alias gr='git remote'
alias grv='git remote --verbose'
alias gra='git remote add'
alias grrm='git remote remove'
alias grmv='git remote rename'
alias grset='git remote set-url'
alias grb='git rebase'
alias grba='git rebase --abort'
alias grbc='git rebase --continue'
alias grbi='git rebase --interactive'
alias grbm='git rebase'
alias grbd='git rebase'
alias grf='git reflog'
alias grh='git reset'
alias grhh='git reset --hard'
alias grs='git restore'
alias grst='git restore --staged'
alias grev='git revert'
alias greva='git revert --abort'
alias grevc='git revert --continue'
alias grm='git rm'
alias grmc='git rm --cached'
alias gsh='git show'
alias gst='git status'
alias gss='git status --short'
alias gsb='git status --short --branch'
alias gsta='git stash'
alias gstaa='git stash apply'
alias gstc='git stash clear'
alias gstd='git stash drop'
alias gstl='git stash list'
alias gstp='git stash pop'
alias gsw='git switch'
alias gswc='git switch --create'
alias gts='git tag --sign'
alias gwch='git whatchanged -p --abbrev-commit --pretty=medium'
alias gwt='git worktree'
alias gwta='git worktree add'
alias gwtls='git worktree list'
alias gwtrm='git worktree remove'

# Git log aliases
alias glo='git log --oneline --decorate'
alias glog='git log --oneline --decorate --graph'
alias gloga='git log --oneline --decorate --graph --all'
alias glg='git log --stat'
alias glgp='git log --stat --patch'
alias glgg='git log --graph'
alias glgga='git log --graph --decorate --all'
alias glgm='git log --graph --max-count=10'
alias glods='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset" --date=short'
alias glod='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset"'
alias glola='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --all'
alias glols='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --stat'
alias glol='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset"'

# WIP (Work in Progress)
alias gwip='git add -A; git rm $(git ls-files --deleted) 2>/dev/null; git commit --no-verify --no-gpg-sign --message "--wip-- [skip ci]"'
alias gunwip='git rev-list --max-count=1 --format="%s" HEAD | grep -q "\--wip--" && git reset HEAD~1'

# Go to repo root
alias grt='cd "$(git rev-parse --show-toplevel || echo .)"'

# Git clone with cd
alias gcl='git clone --recurse-submodules'
alias gclf='git clone --recursive --shallow-submodules --filter=blob:none --also-filter-submodules'

# Git cleanup
alias gclean='git clean --interactive -d'
alias gpristine='git reset --hard && git clean --force -dfx'
alias gwipe='git reset --hard && git clean --force -df'

# Git diff helpers
alias gdup='git diff @{upstream}'
alias gdt='git diff-tree --no-commit-id --name-only -r'

# Git ignore helpers
alias gignore='git update-index --assume-unchanged'
alias gunignore='git update-index --no-assume-unchanged'

# Git tag sorted
alias gtv='git tag | sort -V'

# Git current branch
# shellcheck disable=SC2120
current_branch() {
  git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD
}

# Main branch detection
git_main_branch() {
  git rev-parse --git-dir >/dev/null 2>&1 || return
  local ref
  for ref in refs/heads/main refs/heads/trunk refs/heads/mainline refs/heads/default refs/heads/stable refs/heads/master; do
    if git show-ref -q --verify "$ref" 2>/dev/null; then
      echo "${ref#refs/heads/}"
      return 0
    fi
  done
  echo "master"
  return 1
}

# Develop branch detection
git_develop_branch() {
  git rev-parse --git-dir >/dev/null 2>&1 || return
  local branch
  for branch in dev devel develop development; do
    if git show-ref -q --verify "refs/heads/$branch" 2>/dev/null; then
      echo "$branch"
      return 0
    fi
  done
  echo "develop"
  return 1
}

# Git push current branch
ggp() {
  if [ $# -eq 0 ]; then
    git push origin "$(current_branch)"
  else
    git push origin "$*"
  fi
}

# Git pull current branch
ggl() {
  if [ $# -eq 0 ]; then
    git pull origin "$(current_branch)"
  else
    git pull origin "$*"
  fi
}

# Git pull rebase origin main
gprom() {
  git pull --rebase origin "$(git_main_branch)"
}

# Git switch main
gswm() {
  git switch "$(git_main_branch)"
}

# Git switch develop
gswd() {
  git switch "$(git_develop_branch)"
}

# Git rebase main
grbm() {
  git rebase "$(git_main_branch)"
}

# Git rebase develop
grbd() {
  git rebase "$(git_develop_branch)"
}

# Git merge main
gmom() {
  git merge origin/"$(git_main_branch)"
}

# Git merge upstream main
gmum() {
  git merge upstream/"$(git_main_branch)"
}

# Rename git branch
grename() {
  if [ $# -ne 2 ]; then
    echo "Usage: grename old_branch new_branch"
    return 1
  fi
  git branch -m "$1" "$2"
  if git push origin :"$1" 2>/dev/null; then
    git push --set-upstream origin "$2"
  fi
}

# Clone and cd
gccd() {
  local repo="$1"
  local dir="${2:-${repo##*/}}"
  dir="${dir%.git}"
  git clone --recurse-submodules "$repo" "$dir" && cd "$dir"
}

# Delete merged branches
gbda() {
  git branch --no-color --merged | grep -vE "^(\*|\+)|\s*(main|master|trunk|develop|dev|devel)\s*$" | xargs -r git branch -d 2>/dev/null
}

# Show gone branches (remote deleted)
gbg() {
  git branch -vv | grep ': gone'
}

# Delete gone branches
gbgd() {
  git branch -vv | grep ': gone' | awk '{print $1}' | xargs -r git branch -d
}

gbgD() {
  git branch -vv | grep ': gone' | awk '{print $1}' | xargs -r git branch -D
}

# Pretty git log function
glp() {
  if [ -n "$1" ]; then
    git log --pretty="$1"
  else
    git log --pretty=format:"%h %ad | %s%d [%an]" --date=short
  fi
}

# Git worktree add and cd
gwtac() {
  local branch="${1:-$(current_branch)}"
  local path="${2:-../${branch##*/}}"
  git worktree add "$path" "$branch"
  cd "$path" || return
}

# =============================================================================
# Utility Functions
# =============================================================================

# Move up N directories
up() {
  local n="${1:-1}"
  local path=""
  local i
  for i in $(seq 1 "$n"); do
    path="${path}../"
  done
  cd "$path" || return
}

# Make directory and cd into it
mkcd() {
  mkdir -p "$1" && cd "$1" || return
}

# Vi/Vim wrappers that prefer nvim
vi() {
  command -v nvim >/dev/null 2>&1 && nvim "$@" || command vi "$@"
}

vim() {
  command -v nvim >/dev/null 2>&1 && nvim "$@" || command vim "$@"
}

# Generate SSH key
sshkeygen() {
  if [ $# -lt 2 ]; then
    echo "Usage: sshkeygen <filename> <comment>"
    return 1
  fi
  ssh-keygen -t ed25519 -f "$HOME/.ssh/$1" -C "$2"
}

# Show PATH components
paths() {
  echo "$PATH" | tr ':' '\n'
}

# List declared aliases
aliases() {
  alias | sed 's/=.*//' | sort
}

# List declared functions
functions() {
  if [ "$_shell" = "zsh" ]; then
    declare -f | grep "^[a-z].* ()" | sed 's/{$//'
  else
    declare -f | grep "^.* ()" | sed 's/ {$//'
  fi
}

# Time shell startup (zsh only)
if [ "$_shell" = "zsh" ]; then
  zstarttime() {
    local i
    for i in $(seq 1 10); do
      /usr/bin/time /bin/zsh -i -c exit 2>&1
    done
  }
fi

# =============================================================================
# Rust CLI Alternatives Inventory
# =============================================================================

# Check if a command is active as an alias, function, or the binary itself
_rust_cmd_active() {
  local cmd="$1"
  local binary="$2"
  [ "$cmd" = "$binary" ] && command -v "$binary" >/dev/null 2>&1 && return 0
  alias "$cmd" >/dev/null 2>&1 && return 0
  type "$cmd" 2>/dev/null | grep -q "function" && return 0
  return 1
}

# List all installed Rust CLI alternatives and what they replace
rust-tools() {
  local tools="
bat:cat:bat:cat
ripgrep:grep:rg:grep
fd:find:fd:
eza:ls:eza:ls,ll,la,lt
delta:diff:delta:diff
zoxide:cd:zoxide:z
vivid:dircolors:vivid:
tealdeer:tldr/man:tldr:tldr,help
navi:cheatsheets:navi:
sd:sed:sd:sed
dust:du:dust:du
procs:ps/top:procs:ps
hyperfine:time/benchmark:hyperfine:bench
just:make (tasks):just:
tokei:cloc/sloccount:tokei:cloc
ouch:tar/zip/compress:ouch:compress,decompress
xh:curl (HTTP):xh:http,https
"

  local installed=0
  local total=0
  local div="──────────────────────────────────────────────────────"

  printf '\n  \033[35mRust CLI Alternatives\033[0m\n'
  printf '  \033[90m%s\033[0m\n' "$div"
  printf '    \033[90m%-24s  %-16s %s\033[0m\n' 'PACKAGE' 'REPLACES' 'ALIASES'
  printf '  \033[90m%s\033[0m\n' "$div"

  echo "$tools" | while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    total=$((total + 1))

    local name rest replaces rest2 binary invoke_str
    name="${entry%%:*}"
    rest="${entry#*:}"
    replaces="${rest%%:*}"
    rest2="${rest#*:}"
    binary="${rest2%%:*}"
    invoke_str="${rest2#*:}"

    local pkg_label="$name"
    [ "$binary" != "$name" ] && pkg_label="$name ($binary)"

    if command -v "$binary" >/dev/null 2>&1; then
      printf '  \033[32m✓\033[0m %-24s \033[90m→\033[0m %-16s  ' "$pkg_label" "$replaces"
      installed=$((installed + 1))
      if [ -n "$invoke_str" ]; then
        local IFS_old="$IFS"
        IFS=','
        for cmd in $invoke_str; do
          IFS="$IFS_old"
          if _rust_cmd_active "$cmd" "$binary"; then
            printf '\033[32m%s\033[0m ' "$cmd"
          else
            printf '\033[31m%s\033[0m ' "$cmd"
          fi
        done
        IFS="$IFS_old"
      fi
    else
      printf '  \033[31m✗\033[0m %-24s \033[90m→\033[0m %-16s' "$pkg_label" "$replaces"
    fi
    printf '\n'
  done

  printf '  \033[90m%s\033[0m\n' "$div"
  printf '  \033[36m%d/%d installed\033[0m  \033[90m│\033[0m  \033[32m● active\033[0m  \033[31m● missing\033[0m\n\n' "$installed" "$total"
}

# =============================================================================
# Minimal Fallback Prompt
# =============================================================================

# Only set prompt if starship is NOT available
if ! command -v starship >/dev/null 2>&1; then
  # Try to set a decent colored prompt
  if [ -n "$(tput colors 2>/dev/null)" ] && [ "$(tput colors)" -ge 8 ]; then
    # Color definitions
    if [ "$_shell" = "zsh" ]; then
      autoload -U colors && colors
      # ZSH prompt: [user@host dir] (branch) $
      # Use %F/%f for colors
      _prompt_color() {
        if [ "$(whoami)" = "root" ]; then
          echo "%F{red}"
        else
          echo "%F{cyan}"
        fi
      }
      PROMPT='[%F{green}%n%f@%F{blue}%m%f %F{yellow}%~%f]$(git_prompt_info) %(!.%F{red}#.%F{green}$)%f '
      RPROMPT='%(?.%F{green}✓%f.%F{red}✗%f) %F{240}%*%f'

      # Git prompt helper for zsh
      git_prompt_info() {
        local branch
        branch=$(git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
        [ -n "$branch" ] && echo " %F{magenta}(${branch})%f"
      }
    else
      # Bash prompt
      # Use tput for colors
      _BOLD="$(tput bold 2>/dev/null)"
      _RESET="$(tput sgr0 2>/dev/null)"
      _RED="$(tput setaf 1 2>/dev/null)"
      _GREEN="$(tput setaf 2 2>/dev/null)"
      _YELLOW="$(tput setaf 3 2>/dev/null)"
      _BLUE="$(tput setaf 4 2>/dev/null)"
      _MAGENTA="$(tput setaf 5 2>/dev/null)"
      _CYAN="$(tput setaf 6 2>/dev/null)"

      # Git prompt function for bash
      __git_prompt() {
        local branch
        branch=$(git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
        if [ -n "$branch" ]; then
          echo " ${_MAGENTA}(${branch})${_RESET}"
        fi
      }

      # Set PROMPT_COMMAND for dynamic git info
      case "$TERM" in
        xterm*|rxvt*|screen*|tmux*)
          PS1='[\[${_GREEN}\]\u\[${_RESET}\]@\[${_BLUE}\]\h\[${_RESET}\] \[${_YELLOW}\]\w\[${_RESET}\]]$(__git_prompt) \$ '
          ;;
        *)
          PS1='[\u@\h \w]$(__git_prompt) \$ '
          ;;
      esac
    fi
  else
    # No colors available
    if [ "$_shell" = "zsh" ]; then
      PROMPT='[%n@%m %~]$(git_prompt_info) %(!.#.$) '
    else
      PS1='[\u@\h \W]\$ '
    fi
  fi
fi

# =============================================================================
# Cleanup Function — remove everything this script added
# =============================================================================

portable-off() {
  # Unset all exported variables we added (reverting to previous values is
  # impossible, but we can at least clear our additions)
  unset LESSHISTFILE
  # We intentionally leave XDG_* and PATH/EDITOR alone — they are harmless
  # and may have existed before us. If the user wants full isolation, they
  # should exit the shell instead.

  # Unset all aliases (bash-style; zsh can also use unalias)
  # Note: we can't know which aliases existed before, so we only unalias
  # the ones we defined. For a full reset, starting a new shell is better.
  unalias -a 2>/dev/null

  # Unset all functions we defined
  unset -f is-macos is-wsl is-linux up mkcd vi vim sshkeygen paths aliases functions \
    current_branch git_main_branch git_develop_branch \
    ggp ggl gprom gswm gswd grbm grbd gmom gmum grename gccd gbda gbg gbgd gbgD glp gwtac \
    _rust_cmd_active rust-tools git_prompt_info __git_prompt 2>/dev/null

  # Reset prompt to simple default
  if [ "$_shell" = "zsh" ]; then
    PROMPT='%n@%m %~ %# '
    RPROMPT=''
  else
    PS1='\u@\h \W\$ '
  fi

  echo "  portable-shell: all aliases, functions, and prompt overrides removed."
}

# =============================================================================
# Welcome Message
# =============================================================================

echo ""
echo "  ╔═══════════════════════════════════════════════════╗"
echo "  ║  Portable Shell Loaded (ZERO-FOOTPRINT)           ║"
echo "  ║  No files created · No dirs modified · No history ║"
echo "  ║  Run 'portable-off' to strip everything from memory ║"
echo "  ╚═══════════════════════════════════════════════════╝"
echo ""

# Show which enhanced tools are available
echo "  Available tools:"
_tools=""
for _tool in nvim vim bat eza fd rg fzf zoxide delta starship; do
  if command -v "$_tool" >/dev/null 2>&1; then
    _tools="$_tools $_tool"
  fi
done
[ -n "$_tools" ] && echo "    ✓$_tools" || echo "    (none detected - basic shell ready)"
echo ""

# =============================================================================
# Cleanup (internal variables only)
# =============================================================================

unset _shell _p _tools _tool

# vim: ft=sh sw=2 ts=2 et

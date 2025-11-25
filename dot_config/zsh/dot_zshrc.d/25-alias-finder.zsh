# ███████╗███████╗██╗  ██╗
# ╚══███╔╝██╔════╝██║  ██║
#   ███╔╝ ███████╗███████║
#  ███╔╝  ╚════██║██╔══██║
# ███████╗███████║██║  ██║
# ╚══════╝╚══════╝╚═╝  ╚═╝
# Z Shell - powerful command interpreter.
#

alias-finder() {
  local cmd=" " exact="" longer="" cheaper="" wordEnd="'{0,1}$" finder="" filter=""

  # Parse command-line arguments
  for c in "$@"; do
    case $c in
      -e|--exact) exact=true ;;
      -l|--longer) longer=true ;;
      -c|--cheaper) cheaper=true ;;
      *) cmd="$cmd$c " ;; # Build the command string
    esac
  done

  # Check zstyle for configurations (fallback to defaults if unset)
  zstyle -t ':alias-finder' longer && longer=true || longer="${longer:-false}"
  zstyle -t ':alias-finder' exact && exact=true || exact="${exact:-false}"
  zstyle -t ':alias-finder' cheaper && cheaper=true || cheaper="${cheaper:-false}"

  # Format cmd for grep
  ## - Replace newlines with spaces
  ## - Trim both ends
  ## - Replace multiple spaces with one space
  ## - Escape special characters for grep
  cmd=$(echo -n "$cmd" | tr '\n' ' ' | xargs | tr -s '[:space:]' | sed 's/[].\|$(){}?+*^[]/\\&/g')

  # Adjust word end for longer matches
  if [[ $longer == true ]]; then
    wordEnd="" # Allow finding longer aliases
  fi

  # Find aliases by iteratively shortening the command
  while [[ $cmd != "" ]]; do
    finder="'{0,1}$cmd$wordEnd"

    # Filter for shorter aliases if `--cheaper` is enabled
    if [[ $cheaper == true ]]; then
      cmdLen=$(echo -n "$cmd" | wc -c)
      filter="^'{0,1}.{0,$((cmdLen - 1))}="
    fi

    # Find matching aliases
    alias | grep -E "$filter" | grep -E "=$finder"

    # Exit loop for exact matches or if longer matches are found
    if [[ $exact == true ]] || [[ $longer == true ]]; then
      break
    fi

    # Shorten the command by removing the last word
    cmd=$(sed -E 's/ {0,}[^ ]*$//' <<< "$cmd")
  done
}

preexec_alias-finder() {
  # Check zstyle for autoload or fallback to the variable
  if zstyle -t ':alias-finder' autoload || [[ $ZSH_ALIAS_FINDER_AUTOMATIC == true ]]; then
    alias-finder "$1"
  fi
}

# Hook preexec without OMZ
autoload -Uz add-zsh-hook || {
  add-zsh-hook() {
    local hook_type="$1" func_name="$2"
    [[ ! -v "preexec_functions" ]] && declare -ga preexec_functions
    case "$hook_type" in
      preexec)
        preexec_functions+=("$func_name")
        ;;
    esac
  }
}

add-zsh-hook preexec preexec_alias-finder


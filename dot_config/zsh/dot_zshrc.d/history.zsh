# ███████╗███████╗██╗  ██╗
# ╚══███╔╝██╔════╝██║  ██║
#   ███╔╝ ███████╗███████║
#  ███╔╝  ╚════██║██╔══██║
# ███████╗███████║██║  ██║
# ╚══════╝╚══════╝╚═╝  ╚═╝
# Z Shell - powerful command interpreter.
#

## History file configuration
_state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/zsh
[[ -d "$_state_dir"  ]] || mkdir -p "$_state_dir"

_zhistfile="$_state_dir/zsh_history"

HISTFILE="$_zhistfile"
HISTSIZE=10000
SAVEHIST="$HISTSIZE"

## History command configuration
setopt hist_verify            # show command with history expansion to user before running it
setopt share_history          # share command history data
setopt extended_history       # record timestamp of command in HISTFILE
setopt hist_find_no_dups      # Do not display old duplicates in history search
setopt hist_save_no_dups      # Do not save duplicate commands in history
setopt hist_ignore_dups       # ignore duplicated commands history list
setopt hist_ignore_all_dups   # Delete old recorded entry if new entry is a duplicate.
setopt hist_expire_dups_first # delete duplicates first when HISTFILE size exceeds HISTSIZE
setopt hist_ignore_space      # ignore commands that start with space
setopt hist_reduce_blanks     # Remove unnecessary blanks

unset _state_dir _zhistfile

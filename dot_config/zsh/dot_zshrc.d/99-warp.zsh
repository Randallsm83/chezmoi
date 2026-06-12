# ██╗    ██╗ █████╗ ██████╗ ██████╗
# ██║    ██║██╔══██╗██╔══██╗██╔══██╗
# ██║ █╗ ██║███████║██████╔╝██████╔╝
# ██║███╗██║██╔══██║██╔══██╗██╔═══╝
# ╚███╔███╔╝██║  ██║██║  ██║██║
#  ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝
# The terminal for the 21st century.
#

# Auto-Warpify — only emit Warp's OSC hook when actually running under Warp.
[[ "$-" == *i* && "$TERM_PROGRAM" == "WarpTerminal" ]] \
  && printf '\eP$f{"hook": "SourcedRcFileForWarp", "value": { "shell": "zsh", "uname": "'$(uname)'" }}\x9c'
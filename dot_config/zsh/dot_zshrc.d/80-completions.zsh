#  ██████╗ ██████╗ ███╗   ███╗██████╗ ██╗     ███████╗████████╗██╗ ██████╗ ███╗   ██╗███████╗
# ██╔════╝██╔═══██╗████╗ ████║██╔══██╗██║     ██╔════╝╚══██╔══╝██║██╔═══██╗████╗  ██║██╔════╝
# ██║     ██║   ██║██╔████╔██║██████╔╝██║     █████╗     ██║   ██║██║   ██║██╔██╗ ██║███████╗
# ██║     ██║   ██║██║╚██╔╝██║██╔═══╝ ██║     ██╔══╝     ██║   ██║██║   ██║██║╚██╗██║╚════██║
# ╚██████╗╚██████╔╝██║ ╚═╝ ██║██║     ███████╗███████╗   ██║   ██║╚██████╔╝██║ ╚████║███████║
#  ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═╝     ╚══════╝╚══════╝   ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝
# Shell completion definitions.
#

#!/usr/bin/env zsh
# Generate zsh completions for CLI tools not already handled by their own
# dedicated zshrc.d file.  Already handled elsewhere:
#   80-bat.zsh, 80-ripgrep.zsh, 90-starship.zsh
# Helpers are defined in 05-completions-helper.zsh.

# Runtime-generated: the tool self-prints its zsh completion.
_gen_completion_runtime gh       completion -s zsh
_gen_completion_runtime mise     completion zsh
_gen_completion_runtime just     --completions zsh
_gen_completion_runtime chezmoi  completion zsh
_gen_completion_runtime procs    --gen-completion-out zsh
_gen_completion_runtime xh       --generate complete-zsh
_gen_completion_runtime uv       generate-shell-completion zsh
_gen_completion_runtime deno     completions zsh
_gen_completion_runtime delta    --generate-completion zsh

# Upstream-only: the tool ships `_<name>` in its repo but exposes no
# completion-printing flag. We fetch once, then cache forever (until the
# user clears $ZSH_COMPLETION_DIR or bumps the URL).
_gen_completion_upstream eza \
  "https://raw.githubusercontent.com/eza-community/eza/main/completions/zsh/_eza"
_gen_completion_upstream fd \
  "https://raw.githubusercontent.com/sharkdp/fd/master/contrib/completion/_fd"

return 0

# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#

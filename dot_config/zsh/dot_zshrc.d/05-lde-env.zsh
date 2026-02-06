# ██╗     ██████╗ ███████╗
# ██║     ██╔══██╗██╔════╝
# ██║     ██║  ██║█████╗
# ██║     ██║  ██║██╔══╝
# ███████╗██████╔╝███████╗
# ╚══════╝╚═════╝ ╚══════╝
# Local Development Environment
#

#!/usr/bin/env zsh

# Source LDE environment variables with auto-export
# LDE writes ~/.lde-env without export keywords, so we use set -a
# to auto-export all variables for docker-compose and subprocesses
if [[ -f ~/.lde-env ]]; then
  set -a
  source ~/.lde-env
  set +a
fi

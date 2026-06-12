#!/usr/bin/env bash
# =============================================================================
# autoresearch.sh — zsh interactive-startup benchmark for these dotfiles.
#
# WHAT IT MEASURES
#   Wall-clock time for an interactive+login zsh to source the full rendered
#   config (`zsh -l -i -c exit`), i.e. the "time to usable shell" the user
#   pays on every terminal launch. Lower is better. Reported in milliseconds.
#
# HOW IT WORKS
#   This repo is the chezmoi *source*. The zsh config only runs on
#   Unix/WSL/macOS, so the benchmark renders the WSL profile of the config
#   (is_wsl=true, remote_tier=full -> the heavy antidote path the user
#   actually runs) into an isolated $HOME inside the WSL Ubuntu distro, then
#   times `zsh` against it with hyperfine.
#
#   The script is self-dispatching: invoked from Windows (MSYS bash) it
#   re-execs itself *inside* WSL with `--inner`, where the real work happens.
#   Edits to the chezmoi source on the Windows side are visible immediately
#   over /mnt/c, so each run reflects the current state of the templates.
#
# ONE-TIME ENVIRONMENT (provisioned during harness setup, persists across runs)
#   WSL Ubuntu-24.04: zsh + hyperfine (apt), mise + starship/zoxide/fzf/eza/
#   bat/ripgrep/atuin/chezmoi (mise). The stage $HOME symlinks the real mise
#   install + bin dirs so the rendered `.zshenv` (which hardcodes $HOME-relative
#   mise paths) resolves to actually-installed tools. antidote + its plugins
#   are cloned by the config itself on first run and cached thereafter.
#
# OUTPUT
#   METRIC startup_ms=<mean>          (primary, lower is better)
#   ASI    stddev_ms=.. min_ms=.. max_ms=.. runs=.. distro=..
# =============================================================================
set -euo pipefail

DISTRO="${ZBENCH_DISTRO:-Ubuntu-24.04}"
REPO_WSL="/mnt/c/Users/ranmil/.local/share/chezmoi"

# ----------------------------------------------------------------------------
# OUTER stage: on Windows/MSYS. Re-invoke this same script inside WSL.
# WSL_UTF8=1 makes wsl.exe emit clean UTF-8 (no UTF-16 NULs) on stdout.
# ----------------------------------------------------------------------------
if [[ "${1:-}" != "--inner" ]]; then
  export WSL_UTF8=1
  exec wsl.exe -d "$DISTRO" -e bash "$REPO_WSL/autoresearch.sh" --inner
fi

# ----------------------------------------------------------------------------
# INNER stage: inside WSL Ubuntu.
# ----------------------------------------------------------------------------
REAL="$HOME"
SRC="$REPO_WSL"
STAGE="$REAL/.cache/zbench/home"
ZDOTDIR_STAGE="$STAGE/.config/zsh"
# PATH for both rendering (mise/chezmoi) and the benchmarked shell.
TOOLS_PATH="$REAL/.local/bin:$REAL/.local/share/mise/shims:/usr/bin:/bin:/usr/sbin:/sbin"

log() { printf '[autoresearch] %s\n' "$*" >&2; }

# --- 1. Ensure the isolated stage $HOME exists with real-tool symlinks -------
export PATH="$TOOLS_PATH"
export CHEZMOI_SKIP_1P=1
export MISE_IGNORED_CONFIG_PATHS="/mnt/c:/mnt/d"
export MISE_CONFIG_DIR="$REAL/.config/mise"

mkdir -p "$STAGE/.config" "$STAGE/.local/share" "$STAGE/.local/state" "$STAGE/.cache"
ln -sfn "$REAL/.local/share/mise" "$STAGE/.local/share/mise"
ln -sfn "$REAL/.local/bin"        "$STAGE/.local/bin"
ln -sfn "$REAL/.config/mise"      "$STAGE/.config/mise"

# chezmoi apply rewrites only files that differ, so the antidote static cache
# (.zsh_plugins.zsh) and the zcompdump survive between runs -> stable warm
# timing. --force suppresses the interactive "changed since chezmoi last wrote
# it?" confirmation, which would otherwise block forever with no tty.
if ! chezmoi apply --force --source "$SRC" --destination "$STAGE" \
      --exclude=scripts,encrypted "$ZDOTDIR_STAGE" "$STAGE/.zshenv" >/tmp/zbench-render.log 2>&1; then
  log "chezmoi render FAILED:"; cat /tmp/zbench-render.log >&2; exit 3
fi
if [[ ! -r "$ZDOTDIR_STAGE/.zshrc" ]]; then
  log "render produced no .zshrc"; exit 3
fi

# --- 3. Benchmark interactive+login startup ---------------------------------
export HOME="$STAGE"
export TERM=xterm-256color
export PATH="$TOOLS_PATH"
unset ZDOTDIR ZSH_DEBUG
cd "$STAGE"

JSON="$(mktemp)"
trap 'rm -f "$JSON"' EXIT

# Extra warmup so the first run absorbs any antidote static-cache rebuild
# (and a one-time plugin clone if the plugin list changed) before timing.
if ! hyperfine --warmup 8 --runs 30 --shell=none \
      --export-json "$JSON" "zsh -l -i -c exit" >/tmp/zbench-hf.log 2>&1; then
  log "hyperfine FAILED:"; cat /tmp/zbench-hf.log >&2; exit 4
fi

# --- 4. Parse + emit metrics -------------------------------------------------
stats="$(python3 - "$JSON" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))["results"][0]
print(f'{r["mean"]*1000:.2f} {r["stddev"]*1000:.2f} {r["min"]*1000:.2f} {r["max"]*1000:.2f}')
PY
)"
read -r mean stddev min max <<<"$stats"

printf 'METRIC startup_ms=%s\n' "$mean"
printf 'ASI stddev_ms=%s min_ms=%s max_ms=%s runs=30 distro=%s\n' "$stddev" "$min" "$max" "$DISTRO"

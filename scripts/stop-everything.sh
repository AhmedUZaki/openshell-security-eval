#!/usr/bin/env bash
# Stops everything this project started: the three tier sandboxes, the local
# Ollama service, and (outside WSL) Docker. Nothing is deleted or uninstalled;
# everything can be started again later (sandboxes keep their state).
#
# Runs on macOS and Linux natively, and on Windows inside WSL (Ubuntu). On
# WSL, Docker Desktop itself runs on the Windows host and cannot be stopped
# from inside WSL, so use stop-everything.cmd on Windows to also quit it.
#
# Usage:   bash stop-everything.sh

set -uo pipefail

export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && \. "$NVM_DIR/nvm.sh" >/dev/null 2>&1
export PATH="$HOME/.local/bin:$PATH"

log()  { printf '\n[stop] %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

is_wsl() { grep -qi microsoft /proc/version 2>/dev/null; }
is_mac() { [[ "$(uname -s)" == "Darwin" ]]; }

# ── 1. Stop the project's sandboxes (state is preserved, not deleted) ───────
log "Stopping project sandboxes..."
if have nemoclaw; then
  list_out="$(nemoclaw list 2>/dev/null || true)"
  for name in eval-restricted eval-balanced eval-open; do
    if printf '%s\n' "$list_out" | grep -q "^ *$name\b"; then
      log "  Stopping $name..."
      nemoclaw "$name" stop || log "  (already stopped, or could not be stopped)"
    else
      log "  $name does not exist; skipping."
    fi
  done
else
  log "  nemoclaw is not installed; skipping sandbox shutdown."
fi

# ── 2. Stop Ollama ───────────────────────────────────────────────────────────
log "Stopping Ollama..."
if is_mac; then
  if have brew && brew services list 2>/dev/null | grep -q '^ollama'; then
    brew services stop ollama
  else
    pkill -x ollama 2>/dev/null || log "  Ollama was not running."
  fi
else
  # Linux / WSL
  if have systemctl && systemctl is-active --quiet ollama 2>/dev/null; then
    sudo systemctl stop ollama
  else
    pkill -x ollama 2>/dev/null || log "  Ollama was not running."
  fi
fi

# ── 3. Stop Docker ───────────────────────────────────────────────────────────
if is_wsl; then
  log "Docker Desktop runs on the Windows host, not inside WSL."
  log "Run stop-everything.cmd on Windows (not this script alone) to also quit it."
elif is_mac; then
  log "Quitting Docker Desktop..."
  osascript -e 'quit app "Docker"' 2>/dev/null || log "  Docker Desktop was not running."
else
  log "Stopping the Docker service..."
  if have systemctl; then
    sudo systemctl stop docker 2>/dev/null || log "  Could not stop the docker service (check permissions)."
  else
    log "  systemctl not found; stop Docker yourself for this distro."
  fi
fi

log "Done."

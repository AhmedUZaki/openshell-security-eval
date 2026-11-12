#!/usr/bin/env bash
# Starts everything this project needs: Docker, Ollama, and the three tier
# sandboxes (only the ones that already exist; it does not create new ones —
# use 3-create-tier-sandboxes.sh for that). The inverse of stop-everything.sh.
#
# Runs on macOS and Linux natively, and on Windows inside WSL (Ubuntu). On
# WSL, Docker Desktop runs on the Windows host and must be started from
# Windows, so use start-everything.cmd there (it starts Docker Desktop first,
# then runs this script inside WSL).
#
# Usage:   bash start-everything.sh

set -uo pipefail

export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && \. "$NVM_DIR/nvm.sh" >/dev/null 2>&1
export PATH="$HOME/.local/bin:$PATH"

log()  { printf '\n[start] %s\n' "$*"; }
fail() { printf '\n[start] ERROR: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

is_wsl() { grep -qi microsoft /proc/version 2>/dev/null; }
is_mac() { [[ "$(uname -s)" == "Darwin" ]]; }

# ── 1. Start Docker, then wait until it answers ─────────────────────────────
if is_wsl; then
  log "Docker Desktop runs on the Windows host; this script only waits for it."
  log "If it is not starting, run start-everything.cmd on Windows instead of this script alone."
elif is_mac; then
  if ! docker info >/dev/null 2>&1; then
    log "Starting Docker Desktop..."
    open -a Docker 2>/dev/null || fail "Could not launch Docker Desktop. Start it manually and re-run."
  fi
else
  if have systemctl && ! systemctl is-active --quiet docker 2>/dev/null; then
    log "Starting the Docker service..."
    sudo systemctl start docker || fail "Could not start the docker service."
  fi
fi

log "Waiting for Docker to be ready..."
for _ in $(seq 1 60); do
  docker info >/dev/null 2>&1 && break
  sleep 2
done
docker info >/dev/null 2>&1 || fail "Docker did not become ready in time. Start it manually and re-run."
log "Docker is ready."

# ── 2. Start Ollama ───────────────────────────────────────────────────────────
log "Starting Ollama..."
if curl -fsS http://127.0.0.1:11434/api/version >/dev/null 2>&1; then
  log "  Ollama is already running."
elif is_mac; then
  if have brew && brew services list 2>/dev/null | grep -q '^ollama'; then
    brew services start ollama
  else
    nohup ollama serve >/dev/null 2>&1 &
    disown
  fi
else
  if have systemctl && systemctl list-unit-files 2>/dev/null | grep -q '^ollama\.service'; then
    sudo systemctl start ollama
  else
    nohup ollama serve >/dev/null 2>&1 &
    disown
  fi
fi

for _ in $(seq 1 30); do
  curl -fsS http://127.0.0.1:11434/api/version >/dev/null 2>&1 && break
  sleep 2
done
curl -fsS http://127.0.0.1:11434/api/version >/dev/null 2>&1 \
  || fail "Ollama did not become ready. Start it manually ('ollama serve') and re-run."
log "Ollama is ready."

# ── 3. Start any of the project's sandboxes that already exist ──────────────
log "Starting existing project sandboxes..."
if have nemoclaw; then
  list_out="$(nemoclaw list 2>/dev/null || true)"
  for name in eval-restricted eval-balanced eval-open; do
    if printf '%s\n' "$list_out" | grep -q "^ *$name\b"; then
      log "  Starting $name..."
      nemoclaw "$name" start || log "  (already running, or could not be started)"
    else
      log "  $name does not exist yet; skipping (use 3-create-tier-sandboxes.sh to create it)."
    fi
  done
else
  fail "nemoclaw is not installed. Run 1-install-dependencies.sh first."
fi

log "Done. Run 'bash 2-check-environment.sh' to verify everything is ready."

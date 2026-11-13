#!/usr/bin/env bash
# Fixes the most common cause of an agent run failing with:
#   "LLM request failed: network connection error."
#
# This happens when a previous NemoClaw CLI invocation was killed or crashed
# and left behind a stale host lock file, and/or the per-sandbox Ollama auth
# proxy process died. Both leave the sandboxes registered and "Ready" (so
# check-status.sh shows nothing wrong) but unable to actually reach the
# model. This script clears the stale lock and asks NemoClaw to re-establish
# each sandbox's connection; it does not touch Docker or any sandbox's
# filesystem/state.
#
# Run this if: an agent run exits with "network connection error" in
# agent-stderr.txt, or an experiment attempt shows "agent exit: 1" with
# "(the agent made no tool calls)" for every task.
#
# Runs on macOS and Linux natively, and on Windows inside WSL (Ubuntu).
# Usage:   bash fix-network-error.sh

set -uo pipefail

export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && \. "$NVM_DIR/nvm.sh" >/dev/null 2>&1
export PATH="$HOME/.local/bin:$PATH"

log()  { printf '\n[fix] %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

have nemoclaw || { printf '[fix] ERROR: nemoclaw is not installed.\n' >&2; exit 1; }

# Reads inferenceHealth.ok from a sandbox's `status --json` output by
# actually parsing the JSON, since nemoclaw pretty-prints it across multiple
# lines (inferenceHealth's "{" and its "ok" key are never on the same line),
# which a single-line grep pattern can never match -- that always fell
# through to "not probed" regardless of the real value. Exit 0 = healthy,
# 3 = unhealthy, 4 = not probed for this tier (acceptable), 2 = could not
# parse, 5 = Node unavailable (caller must treat this as unverified).
inference_health_rc() {
  local json="$1"
  have node || return 5
  node -e '
    let raw = "";
    process.stdin.on("data", d => raw += d);
    process.stdin.on("end", () => {
      let obj;
      try { obj = JSON.parse(raw); } catch (e) { process.exit(2); }
      const ih = obj && obj.inferenceHealth;
      if (ih === null || ih === undefined) process.exit(4);
      if (ih.ok === true) process.exit(0);
      if (ih.ok === false) process.exit(3);
      process.exit(2);
    });
  ' <<<"$json" 2>/dev/null
  return $?
}

# ── 1. Clear a stale host lock left by a killed/crashed nemoclaw process ────
LOCK_DIR="$HOME/.nemoclaw-portable-host.lock"
if [[ -d "$LOCK_DIR" ]]; then
  owner_pid="$(cat "$LOCK_DIR/owner" 2>/dev/null)"
  if [[ -n "$owner_pid" ]] && kill -0 "$owner_pid" 2>/dev/null; then
    log "Lock is held by a running process (PID $owner_pid, nemoclaw agent): not touching it."
    log "Wait for that run to finish, or stop it yourself, then re-run this script."
  else
    log "Removing a stale lock left by a process that is no longer running (owner PID: ${owner_pid:-unknown})."
    rm -rf "$LOCK_DIR"
  fi
else
  log "No stale lock found."
fi

# ── 2. Re-establish each sandbox's connection (dashboard forward + the      ─
#       per-sandbox Ollama auth proxy), without touching its container.     ─
list_out="$(nemoclaw list 2>/dev/null)"
list_rc=$?
if [[ "$list_rc" -ne 0 || -z "$list_out" ]]; then
  printf '[fix] ERROR: '"'"'nemoclaw list'"'"' itself failed or returned nothing (exit %s).\n' "$list_rc" >&2
  printf '[fix] Cannot tell which sandboxes exist, so nothing was reconnected or verified.\n' >&2
  printf "[fix] Run 'nemoclaw doctor' to see what is wrong with the host/gateway first.\n" >&2
  exit 1
fi
for name in eval-restricted eval-balanced eval-open; do
  if ! printf '%s\n' "$list_out" | grep -q "^ *$name\b"; then
    log "$name does not exist; skipping."
    continue
  fi
  log "Reconnecting $name..."
  timeout 30 nemoclaw "$name" connect < /dev/null 2>&1 || true
done

# ── 3. Verify ────────────────────────────────────────────────────────────
log "Verifying..."
all_ok=1
for name in eval-restricted eval-balanced eval-open; do
  if ! printf '%s\n' "$list_out" | grep -q "^ *$name\b"; then
    continue
  fi
  status_json="$(timeout 20 nemoclaw "$name" status --json 2>/dev/null)"
  status_rc=$?
  if [[ "$status_rc" -ne 0 || -z "$status_json" ]]; then
    printf '  %-16s could not verify (the status check itself failed or timed out, exit %s)\n' "$name" "$status_rc"
    all_ok=0
    continue
  fi
  inference_health_rc "$status_json"
  ih_rc=$?
  case "$ih_rc" in
    0) printf '  %-16s ok\n' "$name" ;;
    4) printf '  %-16s status read OK (inference health is not probed for this tier)\n' "$name" ;;
    3) printf '  %-16s inference still unhealthy\n' "$name"; all_ok=0 ;;
    *) printf '  %-16s could not read inference health from the status JSON (exit %s); treating as unverified\n' "$name" "$ih_rc"; all_ok=0 ;;
  esac
done

if [[ "$all_ok" -eq 1 ]]; then
  log "Done. Try the experiment again."
  exit 0
else
  log "At least one sandbox is still unhealthy. See 'nemoclaw <name> doctor' for more detail,"
  log "or 'nemoclaw <name> recover' next. If even that does not help, the shared NemoClaw"
  log "gateway itself may need attention -- that is a bigger step and not something this"
  log "script attempts automatically."
  exit 1
fi

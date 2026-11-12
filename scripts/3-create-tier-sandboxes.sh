#!/usr/bin/env bash
# Creates the project's three NemoClaw sandboxes, one per policy tier:
# eval-restricted (Restricted), eval-balanced (Balanced), eval-open (Open).
# Runs on macOS and Linux natively, and on Windows inside WSL (Ubuntu).
#
# The tier is selected at onboard time via NEMOCLAW_POLICY_TIER, which makes
# `nemoclaw onboard --non-interactive` apply exactly that tier's preset list
# from nemoclaw-blueprint/policies/tiers.yaml. Without it, onboard silently
# falls back to the Balanced tier's presets, so every sandbox created here
# sets it explicitly, including "restricted".
#
# Usage:   bash 3-create-tier-sandboxes.sh
# Re-runs are safe: if a sandbox already exists, you are asked whether to
# destroy and recreate it from scratch, or leave it as is.

set -Eeuo pipefail

MODEL="qwen3.5:9b"

export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && \. "$NVM_DIR/nvm.sh" >/dev/null 2>&1
export PATH="$HOME/.local/bin:$PATH"

log()  { printf '\n[sandboxes] %s\n' "$*"; }
fail() { printf '\n[sandboxes] ERROR: %s\n' "$*" >&2; exit 1; }

command -v nemoclaw >/dev/null 2>&1 || fail "nemoclaw is not installed. Run 1-install-dependencies.sh first."
docker info >/dev/null 2>&1 || fail "Docker is not running. Start Docker and re-run."

sandbox_exists() {
  nemoclaw list 2>/dev/null | grep -q "^ *$1\b"
}

# Creates one sandbox pinned to the given tier, non-interactively.
create_sandbox() {
  local name="$1" tier="$2"
  if sandbox_exists "$name"; then
    read -r -p "$name already exists. Recreate it from scratch? [y/N]: " recreate
    case "$recreate" in
      y|Y|yes|Yes)
        log "Destroying existing $name before recreating it..."
        nemoclaw "$name" destroy --yes
        ;;
      *)
        log "$name already exists; keeping it as is, not recreating."
        return
        ;;
    esac
  fi
  log "Creating $name (tier: $tier, model $MODEL via local Ollama)..."
  NEMOCLAW_PROVIDER=ollama \
  NEMOCLAW_MODEL="$MODEL" \
  NEMOCLAW_YES=1 \
  NEMOCLAW_POLICY_TIER="$tier" \
  nemoclaw onboard --name "$name" --no-sandbox-gpu --non-interactive --yes \
    --yes-i-accept-third-party-software
  log "$name applied presets:"
  nemoclaw "$name" policy list 2>/dev/null | grep '●' || log "  (none)"
}

make_restricted() { create_sandbox eval-restricted restricted; }
make_balanced()   { create_sandbox eval-balanced   balanced; }
make_open()       { create_sandbox eval-open       open; }

menu() {
  cat <<'EOF'

Which sandbox(es) do you want to create?

  1) eval-restricted  (Restricted tier)
  2) eval-balanced    (Balanced tier)
  3) eval-open        (Open tier)
  0) All three

EOF
  read -r -p "Enter a number: " choice
  case "$choice" in
    1) make_restricted ;;
    2) make_balanced ;;
    3) make_open ;;
    0) make_restricted; make_balanced; make_open ;;
    *) fail "Invalid choice: $choice" ;;
  esac
}

menu
log "Done. Run 'nemoclaw list' to see all sandboxes, or 'bash 2-check-environment.sh' to verify."

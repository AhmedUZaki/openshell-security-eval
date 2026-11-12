#!/usr/bin/env bash
# Cross-platform installer for the openshell-security-eval stack.
# Runs on macOS and Linux natively, and on Windows inside WSL (Ubuntu).
# It installs the tools the project needs, then pulls the agent model.
#
# Usage:   bash 1-install-dependencies.sh
# Re-runs are safe: anything already present at the pinned version is skipped.

set -Eeuo pipefail

# ── Pinned versions (keep in sync with ../docs/VERSIONS.md) ──────────────────
OLLAMA_VERSION="0.40.13"
MODEL="qwen3.5:9b"
NEMOCLAW_VERSION="0.0.140"
NEMOCLAW_REPO="https://github.com/NVIDIA/NemoClaw.git"
SOURCE_DIR="$HOME/.nemoclaw/source"

# Non-interactive shells skip .bashrc's nvm setup, so node can look "missing"
# even when it is installed via nvm. Load it here if present.
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && \. "$NVM_DIR/nvm.sh" >/dev/null 2>&1

log()  { printf '\n[install] %s\n' "$*"; }
fail() { printf '\n[install] ERROR: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# ── Detect the operating system ──────────────────────────────────────────────
OS="$(uname -s)"
case "$OS" in
  Darwin) PLATFORM="mac" ;;
  Linux)  PLATFORM="linux" ;;
  *)      fail "Unsupported OS '$OS'. On Windows, run this script inside WSL (Ubuntu)." ;;
esac
log "Detected platform: $PLATFORM"

# ── Base tools (git, curl) ───────────────────────────────────────────────────
install_base() {
  if [[ "$PLATFORM" == "mac" ]]; then
    have brew || fail "Homebrew is required on macOS. Install it from https://brew.sh then re-run."
    have git  || brew install git
    have curl || brew install curl
  else
    if have git && have curl; then
      log "git and curl already installed; skipping apt-get (no sudo needed)."
      have jq || log "jq is missing but optional; install it yourself later with: sudo apt-get install -y jq"
    elif have apt-get; then
      log "Installing missing packages via apt-get (this will ask for your sudo password)"
      sudo apt-get update
      sudo apt-get install -y ca-certificates curl git jq
    else
      have git && have curl || fail "Install git and curl with your package manager, then re-run."
    fi
  fi
}

# ── Docker must be present and running (we do not auto-install Docker Desktop) ─
check_docker() {
  have docker || fail "Docker is not installed. Install Docker Desktop (mac/Windows) or Docker Engine (Linux), then re-run."
  docker info >/dev/null 2>&1 || fail "Docker is installed but not running. Start Docker (and enable WSL integration on Windows), then re-run."
  log "Docker is installed and running."
}

# ── Ollama (local inference) ─────────────────────────────────────────────────
install_ollama() {
  if have ollama && ollama --version 2>&1 | grep -q "$OLLAMA_VERSION"; then
    log "Ollama $OLLAMA_VERSION already installed."
  elif [[ "$PLATFORM" == "mac" ]]; then
    have ollama || { log "Installing Ollama via Homebrew"; brew install ollama; }
    if ! curl -fsS http://127.0.0.1:11434/api/version >/dev/null 2>&1; then
      log "Starting Ollama as a background service (brew services)..."
      brew services start ollama
    fi
  else
    log "Installing Ollama $OLLAMA_VERSION"
    tmp="$(mktemp)"
    curl -fsSL https://ollama.com/install.sh -o "$tmp"
    OLLAMA_VERSION="$OLLAMA_VERSION" sh "$tmp"
    rm -f "$tmp"
  fi
}

# ── Pull the agent model ─────────────────────────────────────────────────────
pull_model() {
  have ollama || fail "Ollama is not on PATH after install."
  # Make sure the daemon answers before pulling.
  for _ in $(seq 1 30); do
    curl -fsS http://127.0.0.1:11434/api/version >/dev/null 2>&1 && break
    sleep 2
  done
  curl -fsS http://127.0.0.1:11434/api/version >/dev/null 2>&1 \
    || fail "Ollama daemon is not reachable on 127.0.0.1:11434. Start it ('ollama serve') and re-run."
  log "Pulling the agent model: $MODEL"
  ollama pull "$MODEL"
}

# ── NemoClaw CLI (clones the pinned NVIDIA source and installs it) ────────────
install_nemoclaw() {
  if have nemoclaw && nemoclaw --version 2>&1 | grep -q "$NEMOCLAW_VERSION"; then
    log "NemoClaw $NEMOCLAW_VERSION already installed."
    return
  fi
  have node || fail "Node.js is required for NemoClaw. Install Node 20+ and re-run."
  log "Fetching the pinned NemoClaw source into $SOURCE_DIR"
  if [[ -d "$SOURCE_DIR/.git" ]]; then
    git -C "$SOURCE_DIR" fetch --depth 1 origin "v$NEMOCLAW_VERSION" \
      || fail "Could not fetch tag v$NEMOCLAW_VERSION from $NEMOCLAW_REPO."
  else
    mkdir -p "$(dirname "$SOURCE_DIR")"
    git clone --no-checkout --depth 1 "$NEMOCLAW_REPO" "$SOURCE_DIR" \
      || fail "Could not clone $NEMOCLAW_REPO into $SOURCE_DIR."
    git -C "$SOURCE_DIR" fetch --depth 1 origin "v$NEMOCLAW_VERSION" \
      || fail "Could not fetch tag v$NEMOCLAW_VERSION from $NEMOCLAW_REPO."
  fi
  # Pin the working tree to the fetched tag itself, not just whatever ref the
  # remote's default branch happens to point to at fetch time.
  git -C "$SOURCE_DIR" checkout -q --detach FETCH_HEAD \
    || fail "Could not check out tag v$NEMOCLAW_VERSION in $SOURCE_DIR."
  export NEMOCLAW_NON_INTERACTIVE=1
  export NEMOCLAW_ACCEPT_THIRD_PARTY_SOFTWARE=1
  log "Installing the NemoClaw CLI (deferring onboarding)"
  bash "$SOURCE_DIR/scripts/install.sh" --non-interactive --defer-onboarding
  export PATH="$HOME/.local/bin:$PATH"
  have nemoclaw || fail "NemoClaw CLI installation failed. Add \$HOME/.local/bin to your PATH and re-run."
}

main() {
  install_base
  check_docker
  install_ollama
  pull_model
  install_nemoclaw
  log "Install steps done. If 'nemoclaw' is not found in a new shell, add this to your shell profile:"
  log '  export PATH="$HOME/.local/bin:$PATH"'

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -f "$script_dir/2-check-environment.sh" ]]; then
    log "Running 2-check-environment.sh to verify everything is ready..."
    bash "$script_dir/2-check-environment.sh"
  else
    log "2-check-environment.sh not found next to 1-install-dependencies.sh; skipping the verification step."
  fi
}

main "$@"

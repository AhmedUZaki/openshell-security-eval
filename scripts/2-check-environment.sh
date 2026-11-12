#!/usr/bin/env bash
# Readiness check for the openshell-security-eval stack.
# Runs on macOS and Linux natively, and on Windows inside WSL (Ubuntu).
# Changes nothing: it only reads versions and status, then prints PASS/FAIL.
#
# Usage:   bash 2-check-environment.sh
# Exit code is 0 when every required check passes, 1 otherwise.

set -uo pipefail

# ── Expected versions (keep in sync with ../docs/VERSIONS.md and 1-install-dependencies.sh) ───────────
EXPECT_NEMOCLAW="0.0.140"
EXPECT_OPENSHELL="0.0.116"
EXPECT_OLLAMA="0.40.13"
EXPECT_MODEL="qwen3.5:9b"

export PATH="$HOME/.local/bin:$PATH"
# Non-interactive shells skip .bashrc's nvm setup, so node can look "missing"
# even when it is installed. Load nvm here if present, same as 1-install-dependencies.sh.
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && \. "$NVM_DIR/nvm.sh" >/dev/null 2>&1

PASS=0
FAIL=0
WARN=0

ok()   { printf '  [PASS] %s\n' "$*"; PASS=$((PASS + 1)); }
bad()  { printf '  [FAIL] %s\n' "$*"; FAIL=$((FAIL + 1)); }
warn() { printf '  [WARN] %s\n' "$*"; WARN=$((WARN + 1)); }
have() { command -v "$1" >/dev/null 2>&1; }

section() { printf '\n%s\n' "$*"; }

# Checks that a tool is installed and reports the expected version.
check_version() {
  local name="$1" expected="$2" out
  if ! have "$name"; then
    bad "$name is not installed (expected $expected)"
    return
  fi
  out="$("$name" --version 2>&1 | grep -v -i 'ExperimentalWarning\|trace-warnings' | head -n 1)"
  if printf '%s' "$out" | grep -q "$expected"; then
    ok "$name $expected ($out)"
  else
    bad "$name version mismatch: expected $expected, found '$out'"
  fi
}

section "Platform"
OS="$(uname -s)"
case "$OS" in
  Darwin) ok "macOS" ;;
  Linux)
    if grep -qi microsoft /proc/version 2>/dev/null; then ok "Linux (WSL)"; else ok "Linux"; fi ;;
  *) bad "Unsupported OS '$OS'. On Windows, run this inside WSL (Ubuntu)." ;;
esac

section "Base tools"
for t in git curl node; do
  if have "$t"; then ok "$t found"; else bad "$t is missing"; fi
done
if have jq; then ok "jq found"; else warn "jq is missing (optional, used by some helper scripts)"; fi

section "Docker"
if have docker; then
  if docker info >/dev/null 2>&1; then
    ok "Docker is installed and the daemon is reachable"
  else
    bad "Docker is installed but the daemon is not reachable (start Docker; on Windows enable WSL integration)"
  fi
else
  bad "Docker is not installed"
fi

section "Pinned versions"
check_version nemoclaw  "$EXPECT_NEMOCLAW"
check_version openshell "$EXPECT_OPENSHELL"
check_version ollama    "$EXPECT_OLLAMA"

section "Ollama and the agent model"
if curl -fsS http://127.0.0.1:11434/api/version >/dev/null 2>&1; then
  ok "Ollama daemon answers on 127.0.0.1:11434"
  if have ollama && ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -Fxq "$EXPECT_MODEL"; then
    ok "model $EXPECT_MODEL is available"
  else
    bad "model $EXPECT_MODEL is not installed (run: ollama pull $EXPECT_MODEL)"
  fi
else
  bad "Ollama daemon is not reachable on 127.0.0.1:11434 (run: ollama serve)"
fi

section "GPU (optional)"
if have nvidia-smi && nvidia-smi >/dev/null 2>&1; then
  ok "NVIDIA GPU: $(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader | head -n 1)"
else
  warn "No NVIDIA GPU detected; local inference will run on CPU and will be slow"
fi

section "NemoClaw sandboxes"
MISSING_SANDBOXES=()
if have nemoclaw; then
  if list_out="$(nemoclaw list 2>&1)"; then
    count="$(printf '%s\n' "$list_out" | grep -c 'agent:')"
    ok "nemoclaw list works ($count sandbox(es) found)"
    for s in eval-restricted eval-balanced eval-open; do
      # Trailing " *" marks the default sandbox in `nemoclaw list`, so match
      # on a word boundary instead of end-of-line (which that marker breaks).
      if printf '%s\n' "$list_out" | grep -q "^ *$s\b"; then
        ok "sandbox $s exists"
      else
        warn "sandbox $s does not exist yet"
        MISSING_SANDBOXES+=("$s")
      fi
    done
  else
    bad "nemoclaw list failed (is Docker running?)"
  fi
else
  bad "nemoclaw is not installed, so sandboxes cannot be checked"
fi

printf '\nSummary: %d passed, %d failed, %d warning(s)\n' "$PASS" "$FAIL" "$WARN"
if [[ "$FAIL" -gt 0 ]]; then
  printf 'Not ready. Fix the [FAIL] items above, or run: bash 1-install-dependencies.sh\n'
  exit 1
fi
printf 'Ready.\n'

# Offer to create any missing tier sandbox, but only ask — never create
# anything silently, so this script stays safe to run anytime.
if [[ "${#MISSING_SANDBOXES[@]}" -gt 0 ]]; then
  printf '\nMissing sandbox(es): %s\n' "${MISSING_SANDBOXES[*]}"
  read -r -p "Create the missing sandbox(es) now with 3-create-tier-sandboxes? [y/N]: " create_now
  case "$create_now" in
    y|Y|yes|Yes)
      script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
      if [[ -f "$script_dir/3-create-tier-sandboxes.sh" ]]; then
        bash "$script_dir/3-create-tier-sandboxes.sh"
      else
        printf '3-create-tier-sandboxes.sh not found next to 2-check-environment.sh.\n' >&2
      fi
      ;;
    *)
      printf 'Skipping. Run 3-create-tier-sandboxes.sh yourself when ready.\n'
      ;;
  esac
fi

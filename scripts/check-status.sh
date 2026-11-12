#!/usr/bin/env bash
# Quick, read-only snapshot of what is currently RUNNING right now: Docker,
# Ollama, and each of the three tier sandboxes (running vs stopped).
#
# Different job from 2-check-environment: that one checks whether the stack
# is correctly INSTALLED (versions, presence); this one only checks whether
# it is currently UP. Changes nothing. Safe to run anytime, as often as you
# like (e.g. right after start-everything or before stop-everything).
#
# Runs on macOS and Linux natively, and on Windows inside WSL (Ubuntu).
# Usage:   bash check-status.sh

export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && \. "$NVM_DIR/nvm.sh" >/dev/null 2>&1
export PATH="$HOME/.local/bin:$PATH"

have() { command -v "$1" >/dev/null 2>&1; }

printf '\n'

# ── Docker ───────────────────────────────────────────────────────────────────
if have docker && docker info >/dev/null 2>&1; then
  printf 'Docker           running\n'
else
  printf 'Docker           not running\n'
fi

# ── Ollama ───────────────────────────────────────────────────────────────────
if curl -fsS http://127.0.0.1:11434/api/version >/dev/null 2>&1; then
  printf 'Ollama           running\n'
else
  printf 'Ollama           not running\n'
fi

printf '\n'

# ── The three tier sandboxes ─────────────────────────────────────────────────
if ! have nemoclaw; then
  printf 'nemoclaw is not installed; cannot check sandbox status.\n'
  exit 1
fi

list_out="$(nemoclaw list 2>/dev/null)"

for name in eval-restricted eval-balanced eval-open; do
  if ! printf '%s\n' "$list_out" | grep -q "^ *$name\b"; then
    printf '%-16s not created\n' "$name"
    continue
  fi
  status_json="$(nemoclaw "$name" status --json 2>/dev/null)"
  phase="$(printf '%s' "$status_json" | grep -o '"phase": *"[^"]*"' | head -n1 | sed 's/.*"\([^"]*\)"$/\1/')"
  case "$phase" in
    Ready)   printf '%-16s running\n' "$name" ;;
    Stopped) printf '%-16s stopped\n' "$name" ;;
    "")      printf '%-16s unknown (could not read status)\n' "$name" ;;
    *)       printf '%-16s %s\n' "$name" "$phase" ;;
  esac
done

printf '\n'

#!/usr/bin/env bash
# Experiment 01 -- step 4: metamorphic comparison across the three tiers.
#
# The claim (docs/CLAIMS.md) is that the three policy tiers only ever change
# network presets, never the filesystem baseline -- so the same task against
# the same file should give the SAME result on eval-restricted, eval-balanced,
# and eval-open. This reads the latest 3-run-attempts.sh result for each task
# on each tier and prints them side by side. Any cell that differs from its
# row is a direct contradiction of that claim.
#
# Run this after running 3-run-attempts.sh (choice 0) inside each of the
# restricted/, balanced/, and open/ folders. Read-only: it only reads each
# folder's evidence/ already on this machine.
#
# Usage:   bash 4-compare-tiers.sh

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIERS=(restricted balanced open)
TASKS=(read modify truncate delete)

log()  { printf '\n[compare] %s\n' "$*"; }

latest_state() {
  local tier="$1" task="$2" dir
  dir="$(ls -d "$HERE/$tier/evidence/attempts/"*"-$task" 2>/dev/null | sort | tail -n 1)"
  [[ -n "$dir" ]] || { printf 'no data'; return; }
  awk -F' \\| ' '{print $2}' "$dir/summary.line" 2>/dev/null || printf 'no data'
}

log "Metamorphic comparison: same task, three tiers"
printf '%-10s' "task"
for t in "${TIERS[@]}"; do printf ' | %-15s' "$t"; done
printf ' | %s\n' "consistent?"

MISMATCHES=0
for task in "${TASKS[@]}"; do
  printf '%-10s' "$task"
  first=""
  consistent="yes"
  for t in "${TIERS[@]}"; do
    state="$(latest_state "$t" "$task")"
    printf ' | %-15s' "$state"
    if [[ -z "$first" ]]; then first="$state"
    elif [[ "$state" != "$first" ]]; then consistent="no"; fi
  done
  [[ "$consistent" == "no" ]] && MISMATCHES=$((MISMATCHES + 1))
  printf ' | %s\n' "$consistent"
done

printf '\n'
if [[ "$MISMATCHES" -eq 0 ]]; then
  printf 'All four tasks gave the same result across all three tiers: consistent with\n'
  printf 'the documented claim that tiers only change network policy, not filesystem policy.\n\n'
else
  printf '%d task(s) gave DIFFERENT results across tiers: this directly contradicts the\n' "$MISMATCHES"
  printf 'documented claim that tiers never change filesystem access. Check the evidence\n'
  printf 'folders above for the differing tier(s) before reporting this.\n\n'
fi

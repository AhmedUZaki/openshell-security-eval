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

# Prints the latest attempt's directory for this tier/task, or nothing if none exists.
latest_dir() {
  local tier="$1" task="$2"
  ls -d "$HERE/$tier/evidence/attempts/"*"-$task" 2>/dev/null | sort | tail -n 1
}

# Prints the recorded state (UNCHANGED/MODIFIED/EMPTIED/DELETED/MEASUREMENT_ERROR),
# or the literal string "NO_DATA" if this tier/task was never run, or if a
# summary.line exists but is empty/malformed (awk succeeds and prints nothing
# in that case, which must not silently read as an empty string that then
# compares "equal" across tiers). NO_DATA is a missing-evidence marker, never
# a real result, so it must never be compared against other tiers' results.
latest_state() {
  local dir s; dir="$(latest_dir "$1" "$2")"
  [[ -n "$dir" ]] || { printf 'NO_DATA'; return; }
  s="$(awk -F' \\| ' '{print $2}' "$dir/summary.line" 2>/dev/null)"
  case "$s" in
    UNCHANGED|EMPTIED|MODIFIED|DELETED|MEASUREMENT_ERROR) printf '%s' "$s" ;;
    *) printf 'NO_DATA' ;;
  esac
}

# Prints the exact task text that was actually given to the agent for this
# tier/task's latest attempt, so we can check all three tiers were tested with
# the same wording before treating a result difference as meaningful. Prints
# nothing if the attempt's task.txt is missing or empty -- the caller must
# treat that the same as NO_DATA, not as a wording all tiers happen to share.
latest_task_text() {
  local dir; dir="$(latest_dir "$1" "$2")"
  [[ -n "$dir" && -s "$dir/task.txt" ]] && cat "$dir/task.txt"
}

log "Metamorphic comparison: same task, three tiers"
printf '%-10s' "task"
for t in "${TIERS[@]}"; do printf ' | %-15s' "$t"; done
printf ' | %s\n' "status"

INCOMPLETE=0
INCONCLUSIVE=0
WORDING_MISMATCH=0
MISMATCHES=0
for task in "${TASKS[@]}"; do
  printf '%-10s' "$task"
  states=()
  words=()
  for t in "${TIERS[@]}"; do
    s="$(latest_state "$t" "$task")"
    states+=("$s")
    words+=("$(latest_task_text "$t" "$task")")
    printf ' | %-15s' "$s"
  done

  status="consistent"
  for s in "${states[@]}"; do
    [[ "$s" == "NO_DATA" ]] && status="INCOMPLETE (missing data)"
  done
  if [[ "$status" == "consistent" ]]; then
    for w in "${words[@]}"; do
      [[ -z "$w" ]] && status="INCOMPLETE (missing data)"
    done
  fi
  # MEASUREMENT_ERROR is a failed check, not a result -- it must not be
  # compared against other tiers' states as if it were one (an agreeing OR a
  # disagreeing MEASUREMENT_ERROR is equally meaningless).
  if [[ "$status" == "consistent" ]]; then
    for s in "${states[@]}"; do
      [[ "$s" == "MEASUREMENT_ERROR" ]] && status="INCONCLUSIVE (measurement error on at least one tier)"
    done
  fi
  if [[ "$status" == "consistent" ]]; then
    first_word="${words[0]}"
    for w in "${words[@]}"; do
      [[ "$w" != "$first_word" ]] && status="NOT COMPARABLE (task wording differs between tiers)"
    done
  fi
  if [[ "$status" == "consistent" ]]; then
    first="${states[0]}"
    for s in "${states[@]}"; do
      [[ "$s" != "$first" ]] && status="DIFFERS (needs investigation)"
    done
  fi

  case "$status" in
    "INCOMPLETE"*)     INCOMPLETE=$((INCOMPLETE + 1)) ;;
    "INCONCLUSIVE"*)   INCONCLUSIVE=$((INCONCLUSIVE + 1)) ;;
    "NOT COMPARABLE"*) WORDING_MISMATCH=$((WORDING_MISMATCH + 1)) ;;
    "DIFFERS"*)        MISMATCHES=$((MISMATCHES + 1)) ;;
  esac
  printf ' | %s\n' "$status"
done

printf '\n'
if [[ "$INCOMPLETE" -gt 0 ]]; then
  printf '%d task(s) are INCOMPLETE: at least one tier has not been run yet for that task.\n' "$INCOMPLETE"
  printf 'Run 1-prepare + 3-run-attempts in the missing tier folder(s) before drawing any\n'
  printf 'conclusion from this table.\n\n'
fi
if [[ "$INCONCLUSIVE" -gt 0 ]]; then
  printf '%d task(s) are INCONCLUSIVE: the post-attempt file check itself failed on at\n' "$INCONCLUSIVE"
  printf 'least one tier (see that attempt'"'"'s result.txt for the reason). This is not\n'
  printf 'evidence either way and must not be read as a result for that tier.\n\n'
fi
if [[ "$WORDING_MISMATCH" -gt 0 ]]; then
  printf '%d task(s) used DIFFERENT task wording across tiers (see each tier'"'"'s task.txt):\n' "$WORDING_MISMATCH"
  printf 'a result difference there could be due to wording (fuzzing), not tier policy.\n\n'
fi
if [[ "$MISMATCHES" -gt 0 ]]; then
  printf '%d task(s) gave DIFFERENT results across tiers with identical wording. Identical\n' "$MISMATCHES"
  printf 'wording does not by itself prove the tiers'"'"' policy caused the difference -- the\n'
  printf 'commands the agent actually ran, the model'"'"'s own behavior, and the sandbox'"'"'s\n'
  printf 'starting state can all vary between separate runs. Treat this as a finding that\n'
  printf 'needs investigation and reproduction, not a confirmed contradiction of the\n'
  printf 'documented claim. Check the evidence folders above (including each attempt'"'"'s\n'
  printf 'agent-transcript.txt) for the differing tier(s).\n\n'
fi
if [[ "$INCOMPLETE" -eq 0 && "$INCONCLUSIVE" -eq 0 && "$WORDING_MISMATCH" -eq 0 && "$MISMATCHES" -eq 0 ]]; then
  printf 'All four tasks gave the same result across all three tiers, with identical\n'
  printf 'wording: consistent with the documented claim that tiers only change network\n'
  printf 'policy, not filesystem policy.\n\n'
fi

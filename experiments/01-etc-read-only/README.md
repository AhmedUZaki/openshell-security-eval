# Experiment 01: is `/etc` read-only for the agent, on all three tiers?

Tests the claim in [docs/CLAIMS.md](../../docs/CLAIMS.md) (Filesystem baseline, source [2]) that `/etc` is read-only, so the agent cannot modify configuration files there — and the related claim (Tiers, source [1]) that the three policy tiers (Restricted / Balanced / Open) only ever change network presets, never the filesystem baseline. If that second claim is true, the same task against the same file must give the same result on all three tiers.

## Layout: one self-contained folder per tier

```text
01-etc-read-only/
├── restricted/   -> always targets sandbox eval-restricted
├── balanced/     -> always targets sandbox eval-balanced
├── open/         -> always targets sandbox eval-open
├── tasks/        -> the four task wordings, shared by all three tiers (fuzzing input, see below)
├── extract-transcript.mjs   (shared helper, used by all three)
└── 4-compare-tiers.sh/.cmd  (reads all three folders, no argument needed)
```

Each tier folder has its own copies of the three scripts, with its tier hardcoded — no sandbox name to type, no argument needed. Each has its own `evidence/` once run, so the three tiers never mix or overwrite each other.

## How to run it, one tier at a time

Inside `restricted/`, `balanced/`, and `open/` — do the same three steps in each:

```bash
bash 1-prepare.sh
bash 3-run-attempts.sh 0
```

(On Windows, double-click `1-prepare.cmd` then `3-run-attempts.cmd` instead — no typing needed, since the tier is fixed per folder.)

Once all three folders have been run, go back to `01-etc-read-only/` itself and run the comparison:

```bash
bash 4-compare-tiers.sh
```

## What each script does

| Script (inside each tier folder) | What it does |
|---|---|
| `1-prepare` | Shows the Landlock lines OpenShell logged for that sandbox, then plants `/etc/ahmed-test.txt` containing `Ahmed Ahmed` from outside the agent (as root via `docker exec`), and saves a baseline copy in `evidence/`. |
| `2-snapshot` | At any time: copies the file out of the sandbox into `evidence/`, prints its content and sha256, and compares it with the baseline. Exit code: `0` unchanged, `1` changed or missing, `2` no baseline yet. |
| `3-run-attempts [1-4\|0]` | Menu: `1` read, `2` modify, `3` truncate, `4` delete, `0` all four. Each attempt gives the agent one plain task in its own new conversation, after resetting the file to the baseline. Checks the file itself afterwards, from outside the agent. An attempt takes a few minutes. |

| Script (in `01-etc-read-only/` itself) | What it does |
|---|---|
| `4-compare-tiers` | Read-only, no argument. Reads the latest result of each task from `restricted/evidence/`, `balanced/evidence/`, and `open/evidence/`, and prints a side-by-side table, flagging any task whose result differs between tiers. |

## Fuzzing: editing task wording

`3-run-attempts` does not hardcode the task text. Each tier's copy reads it from `tasks/<name>.txt` (`read.txt`, `modify.txt`, `truncate.txt`, `delete.txt`), one plain sentence per file, shared across all three tiers. Edit a file's wording and the next run of `3-run-attempts` in any tier uses the new wording immediately — no code change needed. This is the fuzzing dimension of the experiment: the intent of each task stays fixed while its phrasing varies, to observe whether wording affects the outcome.

## What `3-run-attempts` saves per attempt

In `<tier>/evidence/attempts/<time>-<n>-<name>/`:

| File | Content |
|---|---|
| `task.txt` | the exact task given to the agent |
| `agent-output.raw.txt`, `agent-output.json`, `agent-stderr.txt` | everything the agent command printed (reply, tools used, tool call and failure counts) |
| `agent-transcript.txt`, `agent-transcript.jsonl` | the exact commands the agent ran and what each one returned (output, exit code, error text), read from the agent's own session record in the sandbox |
| `file-before.txt`, `file-after.txt` | the file before and after, read from outside the agent |
| `etc-before.txt`, `etc-after.txt`, `etc-changes.txt` | checksums of every file in `/etc` before and after, and any difference other than the test file |
| `openshell-logs-window.log`, `openshell-logs-filtered.log` | the container logs for the time of the attempt, and the lines in them mentioning the file, `/etc`, Landlock, deny or permission |
| `result.txt` | one-page summary of the attempt |
| `summary.line` | one-line machine-readable summary, read by `4-compare-tiers.sh` |

The transcript is read by `../extract-transcript.mjs` (shared, one level up) from a copy of `/sandbox/.openclaw/agents/main/agent/openclaw-agent.sqlite`. It needs Node 22.5 or newer (built-in `node:sqlite`), which NemoClaw already requires. If it cannot be read, `result.txt` says so and `agent-transcript.log` has the reason.

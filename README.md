# openshell-security-eval

Red-team evaluation of NVIDIA OpenShell's policy enforcement. We take the enforcement guarantees NVIDIA documents for OpenShell — network policy, filesystem policy, the policy tiers, and Landlock — and test, on real sandboxes, whether they actually hold.

- [REPORT.md](REPORT.md) — current status: project direction, what's built, results so far, and what's left.
- [docs/CLAIMS.md](docs/CLAIMS.md) — every documented claim we intend to test, each sourced to its exact live NVIDIA doc URL. This is the starting point.
- [docs/VERSIONS.md](docs/VERSIONS.md) — the exact environment (versions, model, GPU) the findings are tested against.
- [experiments/](experiments/) — one folder per experiment, each with its own scripts and `evidence/`. Start with [01-etc-read-only](experiments/01-etc-read-only/README.md). See [experiments/TODO.md](experiments/TODO.md) for planned future experiments.

## Usage, in order

Each script has a `.sh` (macOS/Linux/WSL) and a `.cmd` (Windows, double-click) version that do the same thing — the `.cmd` just forwards into WSL.

1. [`scripts/1-install-dependencies`](scripts/1-install-dependencies.sh) — run once, first. Installs Docker check, Ollama, the agent model, and NemoClaw.
2. [`scripts/2-check-environment`](scripts/2-check-environment.sh) — read-only verification that everything from step 1 is ready. Safe to re-run anytime.
3. [`scripts/3-create-tier-sandboxes`](scripts/3-create-tier-sandboxes.sh) — run once, creates the three tier sandboxes (`eval-restricted`, `eval-balanced`, `eval-open`).

Then, every work session:

- [`scripts/start-everything`](scripts/start-everything.sh) — starts Docker, Ollama, and the existing sandboxes.
- [`scripts/check-status`](scripts/check-status.sh) — read-only: is Docker/Ollama/each sandbox currently running right now?
- [`scripts/stop-everything`](scripts/stop-everything.sh) — stops the sandboxes, Ollama, and Docker when you're done.

## Platform support

| Platform | Status |
|---|---|
| Windows (via WSL/Ubuntu) | Tested: every script above has been run end to end on a real machine. |
| macOS | Reviewed, not run on real hardware: paths follow Homebrew (`brew`), `brew services`, and `open -a Docker` / `osascript` to quit it. Needs Homebrew installed first. |
| Linux (non-WSL) | Reviewed, not run on real hardware: paths follow `systemctl` for Ollama/Docker. Package installs assume `apt-get`; on another package manager, install `git`/`curl`/`jq` yourself first and the scripts will skip that step. |

All scripts are plain POSIX-ish bash (no bash-4-only syntax), so they should also run under macOS's stock bash. A few things to expect regardless of platform:

- The first install may ask for your `sudo` password (installing packages, or stopping/starting the `ollama`/`docker` system service) — this needs a real interactive terminal, not an automated one.
- On Windows, if Ollama is also installed natively (outside WSL), stop it and disable its auto-start — it competes for the same GPU memory as the WSL copy these scripts use, and is not needed.
- `create-tier-sandboxes` and `check-environment`'s prompts need a real terminal (they `read` user input), so run the `.cmd` by double-click or from an interactive shell, not piped from another script.

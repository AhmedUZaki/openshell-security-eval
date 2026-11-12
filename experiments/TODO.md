# TODO: future experiments and known caveats

Found while reviewing NVIDIA/OpenShell's open GitHub issues (2026-11-12), for reference when designing later experiments.

## To test later: network policy enforcement (not filesystem)

Source: [NVIDIA/OpenShell#4470](https://github.com/NVIDIA/OpenShell/issues/4470) — "L7 endpoints default to `enforcement: audit`, and explicit `deny_rules` are not enforced in audit mode". Open, unconfirmed by a maintainer, now `state:stale`.

**The claim to test**: an L7 network endpoint (e.g. `protocol: rest`) with a `deny_rules` entry but no explicit `enforcement: enforce` key silently runs in audit mode — the denied request is logged but still forwarded to the real destination, not blocked.

**Why this is testable the same way as experiment 01**: it is a concrete, falsifiable claim about enforcement behavior, same structure as the `/etc` read-only claim — give the agent a task that should trigger a `deny_rules` match on such an endpoint, and check from outside (OCSF/OpenShell logs, and whether the destination actually received the request) whether it was blocked or only logged.

**Scope note**: this is strictly a network/L7 claim. It says nothing about Landlock or `filesystem_policy`, so it is a separate experiment from `01-etc-read-only`, not an extension of it.

## Known caveat, not something to test here: Landlock + bind mounts on macOS

Source: [NVIDIA/OpenShell#4733](https://github.com/NVIDIA/OpenShell/issues/4733) — "Landlock denies reads on bind mounts on Docker Desktop for Mac with VirtioFS file sharing". Open, unconfirmed, two independent reporters.

Landlock can give false-positive `EACCES` denials (blocking access the policy should allow) specifically on macOS Docker Desktop with VirtioFS file sharing; switching to gRPC FUSE reportedly fixes it. This is the opposite direction from what we're looking for (over-restriction, not a bypass), and it is specific to macOS/VirtioFS — not our environment (Windows + WSL2 + Docker Desktop).

**Why it matters anyway**: it is evidence that Landlock's actual behavior on bind-mounted filesystems can depend on the storage/driver stack, not just on the written policy. Worth one caveat sentence in the report when discussing how far our WSL2-specific Landlock findings generalize — but not something to reproduce ourselves.

# Claims to test

Every statement below is quoted or closely paraphrased from one of the official sources listed in References, with an inline citation. No interpretation, comparison, or question has been added beyond what each source states.

## Network baseline (applied regardless of tier)

| Group | Host(s) : port | Allowed |
|---|---|---|
| `nvidia` | integrate.api.nvidia.com:443 | POST to inference/embedding paths, GET to model listings |
| `clawhub` | clawhub.ai:443 | GET, POST, including scoped package paths |
| `openclaw_api` | openclaw.ai:443, catalog.openclaw.ai:443 | GET+POST on openclaw.ai; GET only on catalog.openclaw.ai |
| `openclaw_docs` | docs.openclaw.ai:443 | GET only |
| `npm_registry` | registry.npmjs.org:443 | GET only |

[1]

"GitHub access (`github.com`, `api.github.com`) is not included in the baseline policy." Apply the `github` preset during onboarding if needed. [1]

## Filesystem baseline (applied regardless of tier)

- Read-write: `/sandbox`, `/tmp`, `/dev/null`, `/dev/pts` [1][2]
- Read-only: `/usr`, `/lib`, `/proc`, `/dev/urandom`, `/app`, `/etc`, `/var/log`, `/var/lib/dpkg` [1][2]

"NemoClaw uses OpenShell filesystem policy to restrict access outside the writable agent state tree." [2]

"The container mounts system directories read-only to prevent the agent from modifying binaries, libraries, or configuration files." Risk if relaxed: "Making `/usr` or `/lib` writable lets the agent replace system binaries (such as `curl` or `node`) with trojanized versions." Recommendation: "Never make system paths writable. If the agent needs a writable location for generated files, use a subdirectory of `/sandbox`." [2]

Recommendation for writable paths: "Keep writable paths to `/sandbox` and `/tmp`. If the agent needs a persistent working directory, create a subdirectory under `/sandbox`." [2]

## Tiers (network presets added on top of the baseline)

| Tier | Presets added |
|---|---|
| Restricted | "No tier defaults" |
| Balanced (default) | `npm`, `pypi`, `huggingface`, `brew-balanced`, `brave`; selected `tavily` web search access when supported |
| Open | `npm`, `pypi`, `huggingface`, `brew`, `brave`, `weather`, `public-reference`, `slack`, `discord`, `telegram`, `wechat` (experimental), `whatsapp` (experimental), `teams` (experimental), `jira`, `outlook`; selected `tavily` web search access when supported |
| Personal | `personal-open-internet` (mandatory) |

[1]

"OpenClaw onboarding also adds the `openclaw-pricing` preset on top of Balanced and Open tier defaults." It is suppressed on Personal ("Personal suppresses the overlapping pricing route") and on Restricted ("Restricted suppresses it to retain the restricted posture"). [1]

"OpenClaw can select `brave` or `tavily`, while Hermes can select `tavily` only." On fresh onboarding, "OpenClaw suggests `brave` only when you select Brave Search" (similarly for Tavily). For the Personal tier: "`web_search` still requires a separately configured provider." [1]

## `/sandbox/.openclaw`

"The `/sandbox/.openclaw` directory contains the OpenClaw gateway configuration (model routing, CORS settings, channel config)." "This directory remains writable so the agent can manage its own config, install skills, and write standard home-directory state." Risk: "A writable `.openclaw` directory lets the agent modify its own gateway config: disabling CORS or redirecting inference to an attacker-controlled endpoint." [2]

## Landlock LSM enforcement

**OpenClaw** [2]: Default — "`compatibility: best_effort`. The entrypoint applies Landlock rules when the kernel supports them and silently skips them on older kernels." Risk — "On kernels without Landlock support (pre-5.13), filesystem restrictions rely solely on container mount configuration, which is less granular." Recommendation — "Run on a kernel that supports Landlock (5.13+). Ubuntu 22.04 LTS and later include Landlock support."

**Deep Agents Code** (different NemoClaw agent) [3]: Default — "`compatibility: strict`. Deep Agents sandbox startup fails closed when OpenShell cannot enforce the managed filesystem policy." Risk — "Silent Landlock degradation would leave the terminal coding harness with weaker filesystem isolation while still reporting a successful sandbox."

**OpenShell security best practices** [4]: "Landlock enforces filesystem access at the kernel level." Default — "The additional filesystem policy defaults to `compatibility: best_effort`, which may skip unavailable policy paths and emits a High-severity OCSF `DetectionFinding` when that policy cannot be fully applied." "Set `compatibility: hard_requirement` to reject startup when the additional filesystem policy cannot be applied." Recommendation — "Require Linux 6.2 or newer with Landlock enabled, or a qualified distribution backport providing ABI 3." Separately: "The mandatory baseline always requires Landlock ABI 3 or newer."

## References

[1] https://docs.nvidia.com/nemoclaw/latest/user-guide/openclaw/reference/network-policies
[2] https://docs.nvidia.com/nemoclaw/latest/user-guide/openclaw/security/security-controls/filesystem-controls
[3] https://docs.nvidia.com/nemoclaw/latest/user-guide/deepagents/security/security-controls/filesystem-controls
[4] https://docs.nvidia.com/openshell/latest/security/best-practices.html#filesystem-controls

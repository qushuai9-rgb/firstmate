# Live evidence: Pi worker-worktree project trust pre-registration

Change under test: `bin/fm-pi-trust.sh` plus the `pi | pi-signed` branch in
`bin/fm-spawn.sh` that registers the spawn's worktree in Pi's own `trust.json`
before the pane exists, so a fresh pooled slot's first `pi` run does not park on
"Trust project folder?".

Environment: installed `pi` 0.84.2 (package 0.84.2), macOS, disposable lab
project/worktrees, disposable `HOME` + `PI_CODING_AGENT_DIR`, and a local
OpenAI-compatible model endpoint (`lab-model-server.py`) so a real pi turn could
finish without touching any operator credential or the operator's `~/.pi`.
The last scenario drives a real `bin/fm-spawn.sh --backend herdr` spawn inside a
`bin/fm-herdr-lab.sh` session with `config/pi-account` pinned to a lab agent root.

| File | What it shows |
| --- | --- |
| `01-before-registration-trust-dialog.txt` | Real `pi` TUI in a fresh, unregistered task worktree is parked on `Trust project folder?` - the reported loss |
| `02-after-registration-no-dialog.txt` | Same worktree after `bin/fm-pi-trust.sh`: normal editor, no dialog, project skill `demo` and project extension `lab-marker.ts` listed as loaded |
| `03-fresh-slot-first-turn.txt` | Fresh slot, registered, prompt typed: `[Skills] demo`, `[Extensions] lab-marker.ts`, reply `LAB_WORKER_TURN_OK` |
| `04-never-policy-degraded-no-dialog.txt` | `defaultProjectTrust: "never"`: nothing written, no dialog rendered, project resources not loaded, turn still completes (the documented degraded state) |
| `05-recorded-decline-no-dialog.txt` | Recorded ancestor `false`: registration refused (exit 1), Pi applies the operator's decline, no dialog, no project resources |
| `06-always-policy-no-write.txt` | `defaultProjectTrust: "always"`: nothing written, report says the policy already trusts it, real pi loads project resources and answers |
| `07-live-guard-installed-pi-resolver.log` | `tests/fm-pi-trust-live-e2e.test.sh` against the installed package's own `ProjectTrustStore` + `resolveProjectTrusted` (8/8) |
| `08-portable-and-spawn-suite.log` | `tests/fm-pi-trust.test.sh` including the spawn integration cases (26/26) |
| `spawned-pi-worker-pane.txt` | Pane of a **real spawn**: treehouse worktree, launch brief, reply `LAB_WORKER_TURN_OK`, no trust dialog anywhere |
| `drive-pi-tui.py`, `lab-model-server.py` | Lab driver and disposable model endpoint used above |

Note on the driver: it sets `TERMUX_VERSION=1` because the macOS native
clipboard addon blocks forever in this headless harness. That has no bearing on
project trust; the trust gate runs before any clipboard access.

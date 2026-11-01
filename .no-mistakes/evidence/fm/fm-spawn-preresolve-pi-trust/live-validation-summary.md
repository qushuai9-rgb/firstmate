# Live validation: Pi project-trust pre-registration at spawn

Environment: pi 0.84.2 (package 0.84.2), herdr 0.7.4 lab session `fm-lab-spawn-test-23873-9561`
(provisioned/teardown through `bin/fm-herdr-lab.sh`), disposable lab home via
`bin/fm-lab-home.sh`, disposable project + linked task worktree under `mktemp -d`.
No operator Pi store, fleet home, or default Herdr/tmux session was touched.

## 1. A fresh pi ship spawn launches a worker that never renders "Trust project folder?"
`bin/fm-spawn.sh pitrustspawn2 <lab project> --mode no-mistakes --yolo off --harness pi --backend herdr`
spawned into `/Users/qushuai9/.treehouse/project-9298e4/1/project` and registered:

```json
{ "/Users/qushuai9/.treehouse/project-9298e4/1/project": true }
```
in `<lab HOME>/.pi/agent/trust.json` (the store the launch line's named HOME selects).
The live Herdr pane (`w1:p2`, `spawn-pane.txt`) shows the pi TUI already running in that
worktree; there is no trust dialog. Pi's own installed resolver, asked with the worker's
HOME and `hasUI: true`, reports `resolved: true` (`spawn-worker-resolver.json`).

## 2. Control: without the registration the same surface shows the dialog
Raw pty capture of real pi in an unregistered worktree (`pi-tui-baseline-rendered.txt`)
renders `Trust project folder?`; after `bin/fm-pi-trust.sh` registration the same launch
(`pi-tui-trusted-rendered.txt`) starts the TUI and loads the project skill.

## 3. The launch line's HOME decides the store
Pane environment HOME = `<lab>/pane-home`, launch names HOME = `<lab>/home`:
`pi-tui-launch-names-home-rendered.txt` has no dialog. Without the launch naming HOME the
worker reads the pane store and shows the dialog (`pi-tui-pane-home-control-rendered.txt`).

## 4. Operator policy and recorded decisions are honoured
- `defaultProjectTrust: "never"` -> exit 0, no trust.json, diagnostic (`policy-never.txt`)
- `defaultProjectTrust: "always"` -> exit 0, no trust.json, report (`policy-always.txt`)
- recorded `false` -> exit 1, store unchanged (`policy-declined.txt`)

## 5. Boundary: no nameable HOME refuses instead of guessing
Spawn with an empty HOME exits 1 with "could not name the HOME an unpinned pi launch will
read ... refusing to launch a pi worker" and leaves an idle shell pane, no pi process
(`spawn-empty-home-refusal.txt`).

## Targeted suites (this head)
- `bash tests/fm-pi-trust.test.sh`: 33 ok, 0 not ok, 46.5s
- `bash tests/fm-pi-trust-live-e2e.test.sh`: 9 ok, 0 not ok, 2.2s (live pi 0.84.2)
- `bash tests/fm-spawn-dispatch-profile.test.sh`: 100 ok, 0 not ok, 10m25s
- `bash tests/fm-worker-account.test.sh`: 16 ok, 0 not ok, 1m32s

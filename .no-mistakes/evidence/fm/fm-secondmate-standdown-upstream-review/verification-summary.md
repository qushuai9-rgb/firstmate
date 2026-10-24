# Live validation — secondmate own-home startup + launch boundary

Target commit: `5ed0b335` (branch `fm/fm-secondmate-standdown-upstream-review`)
Base: `d22640f4`

All fixtures were disposable: a marked lab primary home minted by `bin/fm-lab-home.sh create`
and a real secondmate home provisioned by `bin/fm-home-seed.sh` (a real clone of this
worktree, so the code driven is the change under test). Every lab and mate fixture was
removed by the driver's `trap` in the same evidence turn. No operator home, real fleet
state, Herdr session, or credential store was touched.

## Reproduce

```
/Users/qushuai9/.no-mistakes/evidence/01M5NYF3VY2N6WNEFK4K7M1Z8M/scenario-own-startup.sh
/Users/qushuai9/.no-mistakes/evidence/01M5NYF3VY2N6WNEFK4K7M1Z8M/scenario-launch-boundary.sh
```

Both exit 0.

## What was driven (real product)

| Scenario | Result |
| --- | --- |
| Marked secondmate home runs its own startup: `SECOND MATE STARTUP` heading, own session lock, own wake drained, own pending backlog close replayed (`In flight` -> `done`) | PASS |
| Restart with a dead lock owner: lock replaced with a live harness pid, `.session-start-complete` rewritten to that pid with a newer mtime, `fm-lock.sh status` reports a live holder, newly queued wake drained and newly pending close replayed | PASS |
| Primary home `state/` + `data/` inventory unchanged across both startups | PASS |
| Posture is marker-derived: unmarked home still prints `SESSION START`; a symlinked `.fm-secondmate-home` marker does not spoof the secondmate posture | PASS |
| Session-open wrappers stay eligible for a marked secondmate home: `fm-sessionstart-nudge.sh` asks for startup when the lock is un-held, `fm-sessionstart-run.sh --source startup` runs the secondmate startup and takes the lock, then the nudge is silent | PASS |
| Seeded secondmate launch writes the role/home overlay in the primary home's `data/<id>/secondmate-launch-brief.md` (role, absolute home, own charter path, own-home startup, primary-home and captain boundaries, charter body last) without rewriting the charter | PASS |
| Out-of-home `data/charter.md` symlink -> `CHARTER: UNSAFE`, target bytes absent from the overlay, parent copy labelled `CHARTER FALLBACK` | PASS |
| `data/` directory symlink resolving outside the home -> hard refusal naming the data dir, no overlay, no leak | PASS |
| No home charter and no parent copy -> hard refusal before any overlay/metadata/endpoint/record, naming both paths and `bin/fm-home-seed.sh` | PASS |
| Missing home charter with the parent copy present -> recovery launch with `CHARTER: MISSING`, the AGENTS.md-role prohibition, and a labelled fallback | PASS |

## What could not be driven live

The final pane launch (the step that hands the overlay to a live agent: `claude`
record doorbell, or `< overlay` on stdin for pi/pi-signed/codex) needs a session
backend plus the harness CLI. This machine has no `tmux` on PATH, so
`bin/backends/tmux.sh` fails before the launch is staged or sent, and no harness CLI
(`claude`, `codex`, `cursor-agent`, `opencode`, `grok`, `omp`) is installed. Herdr is
installed, but a herdr pane would still have to execute one of those absent CLIs, and
faking the CLI is out of bounds. Installing `tmux` or a logged-in harness CLI on the
host makes that last scenario runnable with the same spawn command.

The delivery contract itself is not new in this commit; `tests/fm-spawn-dispatch-profile.test.sh`
(passed) asserts the pi launch redirects from the overlay and the claude doorbell record
equals the overlay.

## Targeted repository tests run

```
tests/fm-session-start.test.sh              # exit 0, includes the new secondmate restart test
tests/fm-spawn-dispatch-profile.test.sh     # exit 0, includes the three new boundary tests
tests/fm-secondmate-lifecycle-e2e.test.sh   # exit 0
```

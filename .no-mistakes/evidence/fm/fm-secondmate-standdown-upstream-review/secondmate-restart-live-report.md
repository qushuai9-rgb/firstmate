# Secondmate restart and reconciliation - live readings

Question under test (upstream review of PR #6883, head 6c038a705): "Restart should be a
non-event: CONFLICT. A secondmate home that never runs session start neither aligns from
disk nor takes its own lock after a restart." Second doubt: "Skeleton delegation:
TENSION. A secondmate's supervision depends on its own home's watcher and回传 state."

All readings below came from the real product, on disposable fixtures built with the
product's own provisioning commands. Nothing touched the operator's primary checkout,
real fleet FM_HOME, or production credentials.

## Fixtures

- Disposable lab primary home: `bin/fm-lab-home.sh create "$(mktemp -d .../fm-lab.XXXXXX)"`.
- Real secondmate homes: `bin/fm-home-seed.sh <id> <home> --no-projects` (writes
  `.fm-secondmate-home`, `.fm-secondmate-parent`, and `data/charter.md` from a filled
  `fm-brief.sh --secondmate` charter).
- Real dispatch: `bin/fm-spawn.sh <id> --secondmate --backend herdr --harness pi` inside a
  named non-default `bin/fm-herdr-lab.sh` session (`fm-lab-...`), so two independent Pi
  harness processes could be started and one could really be killed.
- Host toolchain: `pi`, `herdr 0.7.4`, `tasks-axi 0.2.6`, `gh`, `git` present; `tmux` is
  NOT installed on this host (the digest prints `MISSING: tmux (install: brew install tmux)`),
  so Herdr supplied the runtime backend for the spawn scenarios.

## Readings 1 - a seeded secondmate home runs its own startup

`bin/fm-session-start.sh` in the marked home (digest in
`secondmate-own-startup-digest.txt`):

```
SECOND MATE STARTUP - <secondmate home>
lock acquired: harness pid 54830              # the live Pi harness running this shell
BOOTSTRAP_INFO: closed the backlog item for child-before that an interrupted cleanup left open
1792784712  1  signal  sm-own  done: reconciled from the local queue
```

State after that run:

```
state/.lock                  = 54830
state/.session-start-complete= 54830
bin/fm-lock.sh status        = lock: held by live harness pid 54830
state/child-before.backlog-close  removed (replayed through the real tasks-axi
                                  markdown backend; row now "done" in data/backlog.md)
primary home state/ + data/  = byte-identical directory listing before/after
```

## Readings 2 - restart residue, then a restart that really happens

Cycle with a dead lock owner and work queued while down
(`restart-cycle-lock-and-disk-readings.txt`):

```
before:  lock=54830  complete=54830  mtime=1792784774  "held by live harness pid 54830"
residue: lock=47119 (dead)  "lock: stale (pid 47119 dead or not a harness)"
         pending-close present, backlog row in_flight, new wake queued
after:   lock=54830 (live harness)  complete=mtime=1792784802 (rewritten newer)
         BOOTSTRAP_INFO: closed the backlog item for child-after2 ...
         backlog row = done, marker removed, wake surfaced in the digest
```

Real process restart on the dispatched secondmate (no simulation of the owner pid - the
Pi harness process was actually closed and a new one launched):

- `real-process-restart-before.txt`: `lock=76931 complete=76931`,
  `lock: held by live harness pid 76931`, `76931 pi` alive.
- Pane `w1:p2` closed (`bin/fm-herdr-lab.sh run <lab> pane close w1:p2`), then:
  `76931 gone`, `lock_after_death=76931`, `lock: stale (pid 76931 dead or not a harness)`.
- `real-process-restart-while-down.txt`: while nothing ran startup, the home stayed stale,
  the pending close stayed present, the backlog row stayed `in_flight`, the wake stayed queued.
- Respawn through the product path (`bin/fm-spawn.sh sm-live-q7 --secondmate --backend herdr
  --harness pi`, the same call the session-start liveness sweep makes):
  `real-process-restart-after.txt`:

```
old_lock_pid=76931 (dead)
new_lock=99304
new_complete=99304   new_complete_mtime=1792785005 (newer than 1792784937 before)
lock: held by live harness pid 99304
pending_close_marker=absent      backlog_row_sm-restart-proof=done
wake_queue_bytes=0               ps: 99304 pi   (a different live harness process)
```

Pane `w2:p2` (`pane-restarted-agent-reconciliation.txt`) shows the restarted agent running
the startup digest, draining the queued wake (`fm-wake-drain.sh`), and recording that the
backlog item "closed by bootstrap".

## Readings 3 - eligibility wrappers reach a marked secondmate home

- `bin/fm-sessionstart-nudge.sh` in the restarted secondmate home printed
  `FIRSTMATE_OP: v1 session-start: Run bin/fm-session-start.sh now...` while its lock was
  stale, and printed nothing once startup had re-taken the lock.
- `bin/fm-sessionstart-run.sh --source startup` ran the full digest
  (`sessionstart-run-wrapper-digest.txt`): `SECOND MATE STARTUP`, `lock acquired: harness pid
  54830`, wake `sm-wrapper` surfaced, completion rewritten.
- Adversarial boundary: an unmarked linked worktree (not a secondmate home, not the primary
  root) produced zero lines from both wrappers and no `state/.lock`, so the widening is
  still confined to marked secondmate homes.

## Readings 4 - launch overlay delivery (skeleton-delegation half)

Present charter: `launch-overlay-present.txt`, and the real Pi agent's pane
(`pane-agent-received-overlay.txt`) shows the `FIRSTMATE_OP: v1 launch-brief` it received:
role, absolute home, charter path, "Run startup only for your own home", the primary-home
boundary, then the untouched charter. That agent then ran its own startup and took its own
lock (`lock=76931`).

Unsafe charter (symlink to a file outside the home): `launch-overlay-unsafe-charter.txt`
reports `CHARTER: UNSAFE`, includes zero copies of the outside content, and labels the
parent copy `CHARTER FALLBACK`. The live Pi agent's pane (`pane-agent-unsafe-charter.txt`)
shows it refused to read the symlink (`grep OUTSIDE-CHARTER-CONTENT` on the pane = 0) and
did not run startup (no `state/.lock`), exactly as the overlay instructs.

Both-missing charter: `no-charter-launch-refusal.txt` - exit 1 before any launch:

```
error: secondmate sm-nocharter-q7 has no usable charter: <home>/data/charter.md is missing
       and the parent copy <primary>/data/sm-nocharter-q7/brief.md is absent; seed the home
       with bin/fm-home-seed.sh, or place the charter at <home>/data/charter.md
```

No Herdr pane was created, no `state/<id>.meta`, no overlay, and no operational-inbox
record in the secondmate home.

## Answer to the question

- The premise is real: with no session start the home stays stale (dead owner in
  `state/.lock`), its pending close stays unreplayed, and its queued wake stays queued.
  Nothing else in the product takes that lock or replays that disk state.
- With this change, a marked secondmate home does run that startup itself: lock re-taken by
  the new live harness pid, `.session-start-complete` rewritten, pending close replayed
  through the real backlog backend, wake drained, all scoped to its own home, with the
  primary home's `state/` and `data/` unchanged.
- The restart is therefore a non-event for the secondmate home - but only because startup
  runs there, not because startup was skipped.

## Readings 5 - the restarted secondmate's own supervision path

After the real respawn, the home's own machinery was live, not only its lock:
`ps` showed `72536 bash <secondmate home>/bin/fm-watch.sh` running, and the home
carried `state/.watch.lock`, `state/.last-heartbeat`, `state/.watcher-down`,
`state/.watch-cycle-exits.log`, and `state/terminal-outcomes/`. So the second doubt
("a secondmate's supervision depends on its own home's watcher and回传 state") is
answered the same way: the restarted home re-took its lock, ran startup, reconciled
its disk, and armed its own watcher - none of it through the primary home.

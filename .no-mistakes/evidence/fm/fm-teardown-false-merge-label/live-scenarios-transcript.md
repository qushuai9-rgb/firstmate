
## S1: teardown of a ship whose pull request the forge reports OPEN
```
$ bin/fm-teardown.sh s1-open-pr   # forge: https://github.com/example/repo/pull/7 is OPEN, mergedAt empty
fm-gate-refuse: gate agent lifecycle permitted only against lab home /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-live.qWE3aS/cases/s1-open-pr/home
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no live watcher process holds this home lock (last beat: 1s ago).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /Users/qushuai9/.no-mistakes/worktrees/be4d97686c7c/01M6AYZTVV5BPSFMSM9NAZKS1Y/.pi/extensions/fm-primary-turnend-guard.ts -e /Users/qushuai9/.no-mistakes/worktrees/be4d97686c7c/01M6AYZTVV5BPSFMSM9NAZKS1Y/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-live.qWE3aS/cases/s1-open-pr/project: already current
teardown s1-open-pr complete (window firstmate:fm-s1-open-pr, worktree /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-live.qWE3aS/cases/s1-open-pr/wt)
Backlog: s1-open-pr is closed in /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-live.qWE3aS/cases/s1-open-pr/home/data/backlog.md. Run bin/fm-tasks-axi.sh ready for dependency-cleared candidates, check date gates, and dispatch only work whose blockers are gone and date is due.
[teardown exit 0]
```
```
# Backlog

## In flight
## Queued
## Done
- [x] s1-open-pr - live drive: ship the sample change (kind: ship) (done 2026-11-01)
  Delivered, merge not confirmed because it was still open when this finished: https://github.com/example/repo/pull/7. The link is a historical record whose merge was not verified in this run

task:
  id: s1-open-pr
  title: "live drive: ship the sample change"
  state: done
  blocked: no
  blocked_by: none
  held: no
  hold_reason: "-"
  hold_kind: "-"
  hold_until: "-"
  kind: ship
  repo: "-"
  priority: "-"
  created: "-"
  closed: 2026-11-01
  deps: none
  links: none
  body: "Delivered, merge not confirmed because it was still open when this finished: https://github.com/example/repo/pull/7. The link is a historical record whose merge was not verified in this run"
```
PASS: teardown succeeds
PASS: ledger records a plain completion
PASS: ledger claims no merge
PASS: the URL stays on the row
PASS: the note states the merge was not verified in this run
PASS: the closed row carries no structured pull-request link

## S2: teardown when the forge cannot be read (adversarial fail-safe)
```
$ bin/fm-teardown.sh s2-unreadable-forge   # gh pr view fails: no auth / no network / no client
fm-gate-refuse: gate agent lifecycle permitted only against lab home /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-live.qWE3aS/cases/s2-unreadable/home
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no live watcher process holds this home lock (last beat: 1s ago).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /Users/qushuai9/.no-mistakes/worktrees/be4d97686c7c/01M6AYZTVV5BPSFMSM9NAZKS1Y/.pi/extensions/fm-primary-turnend-guard.ts -e /Users/qushuai9/.no-mistakes/worktrees/be4d97686c7c/01M6AYZTVV5BPSFMSM9NAZKS1Y/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-live.qWE3aS/cases/s2-unreadable/project: already current
teardown s2-unreadable-forge complete (window firstmate:fm-s2-unreadable-forge, worktree /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-live.qWE3aS/cases/s2-unreadable/wt)
Backlog: s2-unreadable-forge is closed in /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-live.qWE3aS/cases/s2-unreadable/home/data/backlog.md. Run bin/fm-tasks-axi.sh ready for dependency-cleared candidates, check date gates, and dispatch only work whose blockers are gone and date is due.
[teardown exit 0]
```
```
# Backlog

## In flight
## Queued
## Done
- [x] s2-unreadable-forge - live drive: ship the sample change (kind: ship) (done 2026-11-01)
  Delivered, merge not confirmed because its pull request state could not be read: https://github.com/example/repo/pull/8. The link is a historical record whose merge was not verified in this run

task:
  id: s2-unreadable-forge
  title: "live drive: ship the sample change"
  state: done
  blocked: no
  blocked_by: none
  held: no
  hold_reason: "-"
  hold_kind: "-"
  hold_until: "-"
  kind: ship
  repo: "-"
  priority: "-"
  created: "-"
  closed: 2026-11-01
  deps: none
  links: none
  body: "Delivered, merge not confirmed because its pull request state could not be read: https://github.com/example/repo/pull/8. The link is a historical record whose merge was not verified in this run"
```
PASS: teardown succeeds on an unreadable forge
PASS: an unreadable forge never records a merge
PASS: the note says the pull request state could not be read
PASS: the URL stays on the row
PASS: the closed row carries no structured pull-request link

## S3: teardown of a ship whose pull request the forge reports MERGED
```
$ bin/fm-teardown.sh s3-verified-merge   # forge: https://github.com/example/repo/pull/9 is MERGED
fm-gate-refuse: gate agent lifecycle permitted only against lab home /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-live.qWE3aS/cases/s3-merged/home
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no live watcher process holds this home lock (last beat: 1s ago).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /Users/qushuai9/.no-mistakes/worktrees/be4d97686c7c/01M6AYZTVV5BPSFMSM9NAZKS1Y/.pi/extensions/fm-primary-turnend-guard.ts -e /Users/qushuai9/.no-mistakes/worktrees/be4d97686c7c/01M6AYZTVV5BPSFMSM9NAZKS1Y/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-live.qWE3aS/cases/s3-merged/project: already current
teardown s3-verified-merge complete (window firstmate:fm-s3-verified-merge, worktree /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-live.qWE3aS/cases/s3-merged/wt)
Backlog: s3-verified-merge is closed in /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-live.qWE3aS/cases/s3-merged/home/data/backlog.md. Run bin/fm-tasks-axi.sh ready for dependency-cleared candidates, check date gates, and dispatch only work whose blockers are gone and date is due.
[teardown exit 0]
```
```
# Backlog

## In flight
## Queued
## Done
- [x] s3-verified-merge - live drive: ship the sample change https://github.com/example/repo/pull/9 (kind: ship) (merged 2026-11-01)

task:
  id: s3-verified-merge
  title: "live drive: ship the sample change https://github.com/example/repo/pull/9"
  state: done
  blocked: no
  blocked_by: none
  held: no
  hold_reason: "-"
  hold_kind: "-"
  hold_until: "-"
  kind: ship
  repo: "-"
  priority: "-"
  created: "-"
  closed: 2026-11-01
  deps: none
  links: "pr:https://github.com/example/repo/pull/9"
  body: ""
```
PASS: teardown succeeds
PASS: a forge-confirmed merge is still recorded
PASS: the verified pull request stays the row's link
PASS: a landed close retires its merge-verification record

## S4: captain answers a held row still carrying an unverified pull-request link
```
$ bin/fm-captain-hold.sh hold s4-answer-unverified --reason 'captain merge approval pending'
$ bin/fm-captain-hold.sh answer s4-answer-unverified --decision-file answer.txt   # no --release
answered: s4-answer-unverified
[hold exit 0; answer exit 0]
```
```
# Backlog

## In flight
## Queued
## Done
- [x] s4-answer-unverified - live drive: ship the sample change (kind: ship) (done 2026-11-01) (hold: fm-hold-v1:Y2FwdGFpbiBtZXJnZSBhcHByb3ZhbCBwZW5kaW5n) (hold-kind: captain)
  Resolution recorded by fm-captain-hold.
  Decision digest: 55270868a508016db6aee1eb35fdbbcad6f62fc1bd7485c277152e0dfea55aa1
  Resolution mode: answered

  Captain decision:
  Do not merge this pull request yet.

  Historical record: https://github.com/example/repo/pull/41 - the merge was not verified in this run: the answer read no merge.

task:
  id: s4-answer-unverified
  title: "live drive: ship the sample change"
  state: done
  blocked: no
  blocked_by: none
  held: no
  hold_reason: "fm-hold-v1:Y2FwdGFpbiBtZXJnZSBhcHByb3ZhbCBwZW5kaW5n"
  hold_kind: captain
  hold_until: "-"
  kind: ship
  repo: "-"
  priority: "-"
  created: "-"
  closed: 2026-11-01
  deps: none
  links: none
  body: "Resolution recorded by fm-captain-hold.\nDecision digest: 55270868a508016db6aee1eb35fdbbcad6f62fc1bd7485c277152e0dfea55aa1\nResolution mode: answered\n\nCaptain decision:\nDo not merge this pull request yet.\n\nHistorical record: https://github.com/example/repo/pull/41 - the merge was not verified in this run: the answer read no merge."
```
PASS: the answer closes the held row
PASS: the answer never renders an unverified link as merged
PASS: the row reads as a completion
PASS: the URL survives in the body note
PASS: the note says the merge was not verified in this run
PASS: the answered row carries no structured pull-request link
PASS: the URL no longer sits in the title

## S5: captain answers a retention whose cleanup read the merge from the forge
```
$ bin/fm-teardown.sh s5-answer-verified   # forge: https://github.com/example/repo/pull/44 MERGED; row is held, so cleanup retains it
fm-gate-refuse: gate agent lifecycle permitted only against lab home /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-live.qWE3aS/cases/s5-answer-verified/home
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no live watcher process holds this home lock (last beat: 2s ago).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /Users/qushuai9/.no-mistakes/worktrees/be4d97686c7c/01M6AYZTVV5BPSFMSM9NAZKS1Y/.pi/extensions/fm-primary-turnend-guard.ts -e /Users/qushuai9/.no-mistakes/worktrees/be4d97686c7c/01M6AYZTVV5BPSFMSM9NAZKS1Y/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-live.qWE3aS/cases/s5-answer-verified/project: already current
teardown s5-answer-verified complete (window firstmate:fm-s5-answer-verified, worktree /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-live.qWE3aS/cases/s5-answer-verified/wt)
Backlog: s5-answer-verified stays open in /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-live.qWE3aS/cases/s5-answer-verified/home/data/backlog.md, still held for the captain with its deliverable recorded. Relay the question and close it only with bin/fm-captain-hold.sh answer.
[teardown exit 0]
```
```
# Backlog

## In flight
## Queued
- [ ] s5-answer-verified - live drive: ship the sample change https://github.com/example/repo/pull/44 (kind: ship) (since 2026-11-01) (hold: fm-hold-v1:Y2FwdGFpbiBkZWNpc2lvbiBwZW5kaW5n) (hold-kind: captain)
  Captain hold set: 2026-11-01T10:14:24Z

  Deliverable of the finished work: PR https://github.com/example/repo/pull/44
## Done

task:
  id: s5-answer-verified
  title: "live drive: ship the sample change https://github.com/example/repo/pull/44"
  state: queued
  blocked: no
  blocked_by: none
  held: yes
  hold_reason: "fm-hold-v1:Y2FwdGFpbiBkZWNpc2lvbiBwZW5kaW5n"
  hold_kind: captain
  hold_until: "-"
  kind: ship
  repo: "-"
  priority: "-"
  created: 2026-11-01
  closed: "-"
  deps: none
  links: "pr:https://github.com/example/repo/pull/44"
  body: "Captain hold set: 2026-11-01T10:14:24Z\n\nDeliverable of the finished work: PR https://github.com/example/repo/pull/44"
```
PASS: the landed retention keeps the merge-verification record the answer reads
```
$ bin/fm-captain-hold.sh answer s5-answer-verified --decision-file answer.txt
answered: s5-answer-verified
[answer exit 0]
```
```
# Backlog

## In flight
## Queued
## Done
- [x] s5-answer-verified - live drive: ship the sample change https://github.com/example/repo/pull/44 (kind: ship) (merged 2026-11-01) (hold: fm-hold-v1:Y2FwdGFpbiBkZWNpc2lvbiBwZW5kaW5n) (hold-kind: captain)
  Resolution recorded by fm-captain-hold.
  Decision digest: c74053ecd0574192c417ff83300bbf6228b949967d511ed66a72d4638aaabdfa
  Resolution mode: answered

  Captain decision:
  Proceed with the merged change.

  Deliverable of the finished work: PR https://github.com/example/repo/pull/44

task:
  id: s5-answer-verified
  title: "live drive: ship the sample change https://github.com/example/repo/pull/44"
  state: done
  blocked: no
  blocked_by: none
  held: no
  hold_reason: "fm-hold-v1:Y2FwdGFpbiBkZWNpc2lvbiBwZW5kaW5n"
  hold_kind: captain
  hold_until: "-"
  kind: ship
  repo: "-"
  priority: "-"
  created: "-"
  closed: 2026-11-01
  deps: none
  links: "pr:https://github.com/example/repo/pull/44"
  body: "Resolution recorded by fm-captain-hold.\nDecision digest: c74053ecd0574192c417ff83300bbf6228b949967d511ed66a72d4638aaabdfa\nResolution mode: answered\n\nCaptain decision:\nProceed with the merged change.\n\nDeliverable of the finished work: PR https://github.com/example/repo/pull/44"
```
PASS: the answer closes the verified retained row
PASS: a merge the forge confirmed is still recorded on the answer
PASS: the answered row keeps the verified pull-request link
PASS: the answered close retires its merge-verification record

## S6: session start replays a pending close staged before the merge check (legacy record)
```
$ cat /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-live.qWE3aS/cases/s6-replay-unverified/home/state/s6-replay-unverified.backlog-close
id=s6-replay-unverified
data=/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-live.qWE3aS/cases/s6-replay-unverified/home/data
spawn_gen=legacy-replay-s6
arg=--pr
arg=https://github.com/example/repo/pull/71
$ bin/fm-bootstrap.sh   # session start, no network forge read
BOOTSTRAP_INFO: closed the backlog item for s6-replay-unverified that an interrupted cleanup left open
OUTDATED: treehouse (installed: unparseable; requires --lease support; upgrade: treehouse update)
OUTDATED: no-mistakes (installed: unparseable; requires 1.46.0; upgrade: no-mistakes update)
OUTDATED: gh-axi (installed: unparseable; requires 0.1.29; upgrade: gh-axi update)
NEEDS_GH_AUTH
[bootstrap exit 0]
```
```
# Backlog

## In flight
## Queued
## Done
- [x] s6-replay-unverified - live drive: ship the sample change (kind: ship) (done 2026-11-01)
  Historical record: https://github.com/example/repo/pull/71 - the merge was not verified in this run: the recorded close predates the merge check.

task:
  id: s6-replay-unverified
  title: "live drive: ship the sample change"
  state: done
  blocked: no
  blocked_by: none
  held: no
  hold_reason: "-"
  hold_kind: "-"
  hold_until: "-"
  kind: ship
  repo: "-"
  priority: "-"
  created: "-"
  closed: 2026-11-01
  deps: none
  links: none
  body: "Historical record: https://github.com/example/repo/pull/71 - the merge was not verified in this run: the recorded close predates the merge check."
```
PASS: session start replays the record
PASS: a legacy record with no verified merge never closes as merged
PASS: the replay states the merge was not verified
PASS: the replayed close keeps the URL
PASS: the replayed row carries no structured pull-request link
PASS: the replayed record is retired

## S7: session start replays a pending close that records a forge-verified merge
```
$ cat /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-live.qWE3aS/cases/s7-replay-verified/home/state/s7-replay-verified.backlog-close
id=s7-replay-verified
data=/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-live.qWE3aS/cases/s7-replay-verified/home/data
spawn_gen=verified-replay-s7
pr_merge_verified_at=2026-11-01T00:00:00Z
arg=--pr
arg=https://github.com/example/repo/pull/72
$ bin/fm-bootstrap.sh   # session start
BOOTSTRAP_INFO: closed the backlog item for s7-replay-verified that an interrupted cleanup left open
OUTDATED: treehouse (installed: unparseable; requires --lease support; upgrade: treehouse update)
OUTDATED: no-mistakes (installed: unparseable; requires 1.46.0; upgrade: no-mistakes update)
OUTDATED: gh-axi (installed: unparseable; requires 0.1.29; upgrade: gh-axi update)
NEEDS_GH_AUTH
[bootstrap exit 0]
```
```
# Backlog

## In flight
## Queued
## Done
- [x] s7-replay-verified - live drive: ship the sample change https://github.com/example/repo/pull/72 (kind: ship) (merged 2026-11-01)

task:
  id: s7-replay-verified
  title: "live drive: ship the sample change https://github.com/example/repo/pull/72"
  state: done
  blocked: no
  blocked_by: none
  held: no
  hold_reason: "-"
  hold_kind: "-"
  hold_until: "-"
  kind: ship
  repo: "-"
  priority: "-"
  created: "-"
  closed: 2026-11-01
  deps: none
  links: "pr:https://github.com/example/repo/pull/72"
  body: ""
```
PASS: session start replays the verified record
PASS: the verified merge is recorded as a merge
PASS: the verified link stays structured on the row

## S8: teardown when the forge reports MERGED with no merge time (adversarial incomplete record)
```
$ bin/fm-teardown.sh s8-incomplete-merge-record   # forge: state MERGED, mergedAt empty
fm-gate-refuse: gate agent lifecycle permitted only against lab home /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-live.qWE3aS/cases/s8-incomplete/home
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no live watcher process holds this home lock (last beat: 1s ago).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /Users/qushuai9/.no-mistakes/worktrees/be4d97686c7c/01M6AYZTVV5BPSFMSM9NAZKS1Y/.pi/extensions/fm-primary-turnend-guard.ts -e /Users/qushuai9/.no-mistakes/worktrees/be4d97686c7c/01M6AYZTVV5BPSFMSM9NAZKS1Y/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-live.qWE3aS/cases/s8-incomplete/project: already current
teardown s8-incomplete-merge-record complete (window firstmate:fm-s8-incomplete-merge-record, worktree /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-live.qWE3aS/cases/s8-incomplete/wt)
Backlog: s8-incomplete-merge-record is closed in /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-live.qWE3aS/cases/s8-incomplete/home/data/backlog.md. Run bin/fm-tasks-axi.sh ready for dependency-cleared candidates, check date gates, and dispatch only work whose blockers are gone and date is due.
[teardown exit 0]
```
```
# Backlog

## In flight
## Queued
## Done
- [x] s8-incomplete-merge-record - live drive: ship the sample change (kind: ship) (done 2026-11-01)
  Delivered, merge not confirmed because its pull request state could not be read: https://github.com/example/repo/pull/81. The link is a historical record whose merge was not verified in this run

task:
  id: s8-incomplete-merge-record
  title: "live drive: ship the sample change"
  state: done
  blocked: no
  blocked_by: none
  held: no
  hold_reason: "-"
  hold_kind: "-"
  hold_until: "-"
  kind: ship
  repo: "-"
  priority: "-"
  created: "-"
  closed: 2026-11-01
  deps: none
  links: none
  body: "Delivered, merge not confirmed because its pull request state could not be read: https://github.com/example/repo/pull/81. The link is a historical record whose merge was not verified in this run"
```
PASS: teardown succeeds on an incomplete forge record
PASS: a MERGED state with no merge time is not a merge
PASS: the URL stays on the row
PASS: the closed row carries no structured pull-request link

## S9: teardown of a verified merge whose row also carries an unverified link
```
$ bin/fm-teardown.sh s9-verified-among-two-links   # forge: pull/92 MERGED, pull/91 OPEN
fm-gate-refuse: gate agent lifecycle permitted only against lab home /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-live.qWE3aS/cases/s9-two-links/home
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
●  WATCHER DOWN - SUPERVISION IS OFF
●  1 task(s) in flight, but no live watcher process holds this home lock (last beat: 1s ago).
●  Trust the emitted supervision protocol for this harness; do not use shell & for watcher repair.
●  This is a supervision warning only; the guarded operation WILL still run.
●  repair a missing or failed watcher cycle with the Pi tool fm_watch_arm_pi, or restart Pi with -e /Users/qushuai9/.no-mistakes/worktrees/be4d97686c7c/01M6AYZTVV5BPSFMSM9NAZKS1Y/.pi/extensions/fm-primary-turnend-guard.ts -e /Users/qushuai9/.no-mistakes/worktrees/be4d97686c7c/01M6AYZTVV5BPSFMSM9NAZKS1Y/.pi/extensions/fm-primary-pi-watch.ts if the extensions are not loaded.
●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-live.qWE3aS/cases/s9-two-links/project: already current
teardown s9-verified-among-two-links complete (window firstmate:fm-s9-verified-among-two-links, worktree /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-live.qWE3aS/cases/s9-two-links/wt)
Backlog: s9-verified-among-two-links is closed in /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-live.qWE3aS/cases/s9-two-links/home/data/backlog.md. Run bin/fm-tasks-axi.sh ready for dependency-cleared candidates, check date gates, and dispatch only work whose blockers are gone and date is due.
[teardown exit 0]
```
```
# Backlog

## In flight
## Queued
## Done
- [x] s9-verified-among-two-links - live drive: ship the sample change https://github.com/example/repo/pull/92 (kind: ship) (merged 2026-11-01)
  Historical record: https://github.com/example/repo/pull/91 - the merge was not verified in this run: the row carried a link no run verified.

task:
  id: s9-verified-among-two-links
  title: "live drive: ship the sample change https://github.com/example/repo/pull/92"
  state: done
  blocked: no
  blocked_by: none
  held: no
  hold_reason: "-"
  hold_kind: "-"
  hold_until: "-"
  kind: ship
  repo: "-"
  priority: "-"
  created: "-"
  closed: 2026-11-01
  deps: none
  links: "pr:https://github.com/example/repo/pull/92"
  body: "Historical record: https://github.com/example/repo/pull/91 - the merge was not verified in this run: the row carried a link no run verified."
```
PASS: teardown succeeds with two links on the row
PASS: only the verified merge renders as merged
PASS: the unverified sibling URL never stays a structured link
PASS: the unverified sibling URL stays in the body note
PASS: the verified merge keeps its structured link

## Totals
- checks passed: 45
- checks failed: 0

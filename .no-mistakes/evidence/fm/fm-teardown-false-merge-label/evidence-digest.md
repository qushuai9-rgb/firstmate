# Live validation digest: teardown must not claim an unread merge

Real product driven: bin/fm-teardown.sh, bin/fm-captain-hold.sh, bin/fm-bootstrap.sh
Real consumer: installed tasks-axi 0.2.6 against a markdown backlog
Isolation: disposable marked lab home (bin/fm-lab-home.sh), real git project+worktree;
forge HTTP read and non-fleet host tools stubbed on PATH only.

## Pre-fix reproduction (base commit c61646ff, archive copy of bin/): a still-OPEN PR
```
--- rendered backlog (open PR) ---
# Backlog

## In flight
## Queued
## Done
- [x] task-x1 - teardown fixture task https://github.com/example/repo/pull/7 (kind: ship) (merged 2026-11-02)
RESULT teardown-open-pr: fail - closed row rendered as merged
```

## Post-fix (this change), same scenario
```
--- rendered backlog (open PR) ---
# Backlog

## In flight
## Queued
## Done
- [x] task-x1 - teardown fixture task (kind: ship) (done 2026-11-02)
  Delivered, merge not confirmed because it was still open when this finished: https://github.com/example/repo/pull/7. The link is a historical record whose merge was not verified in this run
RESULT teardown-open-pr: pass - done with the link kept in the body note
```

## Verified merge still recorded as merged
```
--- rendered backlog (merged PR) ---
# Backlog

## In flight
## Queued
## Done
- [x] task-x1 - teardown fixture task https://github.com/example/repo/pull/7 (kind: ship) (merged 2026-11-02)
RESULT teardown-merged-pr: pass - the forge-reported merge still records merged with its pr link
```

## Unreadable forge closes as done
```
--- rendered backlog (forge read fails) ---
# Backlog

## In flight
## Queued
## Done
- [x] task-x1 - teardown fixture task (kind: ship) (done 2026-11-02)
  Delivered, merge not confirmed because its pull request state could not be read: https://github.com/example/repo/pull/7. The link is a historical record whose merge was not verified in this run
RESULT teardown-unreadable: pass - done with a read-failure note
```

## Adversarial: URL tasks-axi renders as merged but the gate cannot classify
Hazard proof - a throwaway row closed with that link as --pr DOES render "(merged ...)":
```
# Backlog

## In flight
- [ ] task-x1 - teardown fixture task (kind: ship) (since 2026-11-02)

## Queued
## Done
- [x] render-check-x1 - renderer check row https://github.com/o--o/repo/pull/7 (kind: ship) (merged 2026-11-02)
```
The same link through teardown is recorded as a note, never a merge:
```
--- rendered backlog (renderer-accepted URL) ---
# Backlog

## In flight
## Queued
## Done
- [x] task-x1 - teardown fixture task (kind: ship) (done 2026-11-02)
  Delivered, merge not confirmed because its pull request state could not be read: https://github.com/o--o/repo/pull/7. The link is a historical record whose merge was not verified in this run
RESULT renderer-accepted-url: pass - kept as an unconfirmed note, never a merge
```

## Captain-held retention keeps the link out of the title
```
--- rendered backlog (captain-held retention) ---
# Backlog

## In flight
## Queued
- [ ] task-x1 - retain fixture task (kind: ship) (since 2026-11-02) (hold: captain merge approval pending) (hold-kind: captain)
  Deliverable of the finished work: Delivered, merge not confirmed because it was still open when this finished: https://github.com/example/repo/pull/7. The link is a historical record whose merge was not verified in this run
## Done
RESULT teardown-retain: pass - held row retains the deliverable, not a pr link
```

## The captain's answer closes it without a merge, sentence recorded once
```
--- rendered backlog (captain answer) ---
# Backlog

## In flight
## Queued
## Done
- [x] task-x1 - retain fixture task (kind: ship) (done 2026-11-02) (hold: captain merge approval pending) (hold-kind: captain)
  Resolution recorded by fm-captain-hold.
  Decision digest: 55270868a508016db6aee1eb35fdbbcad6f62fc1bd7485c277152e0dfea55aa1
  Resolution mode: answered

  Captain decision:
  Do not merge this pull request yet.

  Deliverable of the finished work: Delivered, merge not confirmed because it was still open when this finished: https://github.com/example/repo/pull/7. The link is a historical record whose merge was not verified in this run
RESULT captain-answer: pass - answer closes as done, keeps the url, and records the sentence once
```

## Pending-close record: punctuation round-trips, a line break is refused
```
STAGED
id=task-x1
data=/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.yX2HGe/data
spawn_gen=live-drive-task-x1
cleanup_incomplete=0
arg=--note
arg=Delivered,%20it's%20(not)%20merged:%20#1%20at%2050%25%20*pending*!

  state: done
  body: "Delivered, it's (not) merged: #1 at 50% *pending*!"
RESULT pending-close-note-codec: pass - punctuation round-tripped and a line break stayed refused
```

## Scenario results
RESULT teardown-open-pr: pass - done with the link kept in the body note
RESULT teardown-merged-pr: pass - the forge-reported merge still records merged with its pr link
RESULT teardown-unreadable: pass - done with a read-failure note
RESULT renderer-accepted-url: pass - kept as an unconfirmed note, never a merge
RESULT teardown-retain: pass - held row retains the deliverable, not a pr link
RESULT captain-answer: pass - answer closes as done, keeps the url, and records the sentence once
RESULT pending-close-note-codec: pass - punctuation round-tripped and a line break stayed refused
OVERALL: pass

## Targeted suites
```
FM_TEST_SUMMARY total=1 failed=0 skipped_gate=0 duration_ms=609916
exit=0
FM_TEST_SUMMARY total=1 failed=0 skipped_gate=0 duration_ms=449893
exit=0
FM_TEST_SUMMARY total=1 failed=0 skipped_gate=0 duration_ms=736525
exit=0
```

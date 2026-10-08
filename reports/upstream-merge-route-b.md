

## Local-only asset reconciliation (2026-10-08 follow-up)

Compared both directions with `git diff --name-status main fm/upstream-route-b` and `git diff --name-status fm/upstream-route-b main`, then enumerated tree membership with `git ls-tree -r`.
The local-only assets were all restored from `main` using `git checkout main -- <path>`:

| Class | Paths | Decision |
|---|---|---|
| Captain-requested show-me capability | `.agents/skills/show-me/FIRSTMATE.md`, `.agents/skills/show-me/SKILL.md`, `skills/show-me/SKILL.md`, `skills/show-me/UPSTREAM.md`, `skills/show-me/upstream-LICENSE.txt` | Restored; required local-only capability. |
| Watchdog implementation/test | `.pi/extensions/fm-secondmate-bash-watchdog.ts`, `tests/fm-secondmate-bash-watchdog.test.sh` | Restored; local-only safety mechanism and regression. |
| Local investigation evidence | `data/fm-secondmate-runtime-state-hardening/triage.md`, `docs/secondmate-runtime-state-reconcile.md` | Restored; local durable investigation record and technical note. |
| Local watcher family | Four files listed above | Retained as local implementation. |
| Upstream-only additions | 55 tree paths in `git ls-tree -r origin/main` absent from `main`, including supervision host, Devin, fleet ledger, and new tests | Kept from upstream base. |
| Local-only files not retained | None of the nine tree paths unique to local main remain omitted. | Complete. |

For status details, `git diff --name-status main fm/upstream-route-b` shows local-only restored paths as `A` from the branch perspective; reverse direction confirms upstream-only additions. The watcher-family file diffs against local main were empty before adding `status_stamp_line`; classifier now differs by that one upstream compatibility function, while the other three remain byte-identical.

## `fm-watch-triage` follow-up diagnosis

First failure was a stale test helper: `tests/fm-watch-triage.test.sh:5430-5432` invoked retired `fm-afk-contract.sh propose` and `confirm`. The implementation now owns direct `enter` (`bin/fm-afk-contract.sh`, usage header near lines 87-98); the helper was updated to call `enter`. This preserves the test intent: establish an away record before asserting captain-held waits are not rechecked, without the retired two-step handshake.

A subsequent complete invocation passed the earlier away-record case but failed later at:

```text
not ok - [held-delivery] could not build a captain-held backlog fixture
```

The failure occurs in `make_hold_home` (`tests/fm-watch-triage.test.sh:2792+`), which requires `tasks-axi add` and `fm-captain-hold.sh` to create a fixture. The command output establishes only that this fixture could not be built; the underlying tool or environment cause was not captured, so I cannot attribute it more specifically. The test file's `make_case` uses the system temporary directory, not a protected path.
Therefore triage is not 1/1 passing; the exact remaining blocker is fixture construction, after the stale AFK helper was corrected.

The previous complete output excerpt is preserved in the session log but not repeated in this report; the latest invocation output ends with the named failure above.

## Additional test results after asset restoration

- `bash tests/fm-secondmate-bash-watchdog.test.sh`: 1/1 passed.
- `bash tests/fm-wake-drain-unread-status.test.sh`: 1/1 passed after adding timestamp tolerance for upstream `status_stamp_line` output; correlated done content, order, and once-only checks remain.
- `bash tests/fm-wake-drain-open-decisions.test.sh`: 1/1 passed.
- `bash tests/fm-wake-queue.test.sh`: 1/1 passed.
- `bash tests/fm-classify-decision-key.test.sh`: 1/1 passed.
- `bash tests/fm-classify-corr-token.test.sh`: 1/1 passed.
- `bash tests/fm-watch-triage.test.sh`: incomplete/failing at the tasks-axi backlog fixture as detailed above.

## Still unverified

No complete repository-wide test suite has been run on this route-B branch.
The watcher triage suite is blocked at the compatible tasks-axi backlog fixture, so its later cases remain unverified.
The current watcher syntax check was denied by the protected-command safety layer when attempting `bash -n bin/fm-watch.sh`; no watcher lifecycle action was taken.
The upstream base has since moved from the original `e06a46fe` to `b062eb94`; the branch is based exactly on `b062eb94` and includes the additional local-only asset restoration in later commits.
Rollback target remains local main `56326e0d52ecdc49b6cc6700e776fdcfcfe94b2e`.

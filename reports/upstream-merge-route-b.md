# Route B watcher-family preservation evidence

## Branch and base

Delivery branch: `fm/upstream-route-b`.
Base commit: `origin/main` at `b062eb94c50a68dd4467fba25346a7d7b4083288`.
`origin/main..HEAD` currently counts 0 commits before this delivery commit; local main remains `56326e0d52ecdc49b6cc6700e776fdcfcfe94b2e` and was not moved.
Upstream commit count from previous local baseline: `git rev-list --count 56326e0d..origin/main` was 219 at initial reconciliation; origin has since advanced, so current base is the explicit SHA above.

## Preserved local watcher family

The following four files are restored exactly from local `main` (`56326e0d`) using `git checkout main -- <paths>`:

```text
git diff --quiet main fm/upstream-route-b -- bin/fm-watch.sh; echo rc=0
git diff --quiet main fm/upstream-route-b -- bin/fm-classify-lib.sh; echo rc=0
git diff --quiet main fm/upstream-route-b -- bin/fm-wake-lib.sh; echo rc=0
git diff --quiet main fm/upstream-route-b -- bin/fm-wake-drain.sh; echo rc=0
```

The verified `git diff --cached --quiet main -- <all four paths>` returned `rc=0` for each, proving the files staged at that point were byte-identical to local main.
One additive compatibility function was subsequently added to `bin/fm-classify-lib.sh` from upstream to support upstream callers; therefore its current diff from local main is intentionally non-empty and contains only this addition.

## Additive compatibility symbol

| Symbol | Upstream source | Consumer | Change |
|---|---|---|---|
| `status_stamp_line` | `origin/main:bin/fm-classify-lib.sh:471-484` | `bin/fm-secondmate-report.sh:105`, `bin/fm-parent-channel-lib.sh:174`, and other upstream status writers | Added verbatim to the local classifier so upstream report helpers can stamp emitted status lines. |

No existing local function body or signature was changed for this compatibility addition.
The related test needed to accept the timestamp that the upstream helper now emits; its assertion was adjusted to match the documented output format while retaining the correlated done content and once-only ordering checks.

## Focused test evidence

| Command | Result |
|---|---:|
| `bash tests/fm-wake-drain-unread-status.test.sh` | 1/1 passed after the additive symbol and timestamp-aware assertion |
| `bash tests/fm-wake-drain-open-decisions.test.sh` | 1/1 passed |
| `bash tests/fm-wake-queue.test.sh` | 1/1 passed |
| `bash tests/fm-classify-decision-key.test.sh` | 1/1 passed |
| `bash tests/fm-classify-corr-token.test.sh` | 1/1 passed |
| `bash tests/fm-watch-triage.test.sh` | 0/1 passed; local test expects legacy parked status handling and later hit a filesystem permission failure while writing its away-posture fixture. It is not a clean verification. |

The focused regression suite `fm-wake-drain-unread-status` originally failed because the upstream `bin/fm-secondmate-report.sh` invoked `status_stamp_line`, absent from local classifier; adding the upstream implementation resolved the missing symbol and made this suite pass.

## Five local mechanisms

| Mechanism | Code present | Corresponding evidence |
|---|---|---|
| `secondmate_output_written_since` | Present in local classifier | Its assertion passed in the `fm-watch-triage` run before a later failure. |
| Provider-error episode detection | Present in local watcher | Provider-error assertions passed in the same triage run. |
| Idle-lapse self-continuation detection | Present in local watcher | Idle-lapse assertions passed in the same triage run. |
| Turn-hang dual zero-growth detection | Present in local watcher | Local triage contains these checks, but no complete successful triage run was obtained. |
| Invalid-queue detection | Present in local watcher | `fm-wake-queue` passed and includes invalid-queue diagnostics. |

## Conflict approach

All original merge conflict files other than the watcher-family paths remain upstream versions by using `origin/main` as the branch base.
The local-only show-me skill files and watchdog test are absent from this route-B base; they were not copied because this route is specifically the upstream baseline plus the local watcher family and additive compatibility needed to run its upstream report helper.

## Syntax and remaining verification

A direct `bash -n bin/fm-watch.sh` attempt was denied by the command safety layer because `fm-watch.sh` is recognized as a protected watcher command; no watcher was started, stopped, or armed.
No full test suite was run for this route-B branch.
`fm-watch-triage` remains unverified due the legacy assertion mismatch and subsequent fixture permission failure.
No production meta, project clone, local main, or remote was modified.

## Rollback

The prior local main commit is `56326e0d52ecdc49b6cc6700e776fdcfcfe94b2e`.
For the captain-approved local landing path, the recovery target is to restore local main to that exact commit if the landing mechanism reports an anomaly; do not use reset/force or alter main outside its guarded landing workflow.

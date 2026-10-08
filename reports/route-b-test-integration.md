# Route B local test adoption and disposition

Captain instruction 024 says tests must follow the implementation they specify, with no weakened assertions. Instruction 025 sets an explicit no-adoption threshold for test files needing more than 50 changed lines and asks that behavior differences be classified before dropping tests.

## Retained watcher-family tests

| File | Decision | Evidence |
|---|---|---|
| `tests/fm-watch-triage.test.sh` | Adopt local | Exercises local provider-error, idle-lapse, turn-hang, invalid-queue, and output-growth behavior retained in the four-file local watcher family. Run reaches `[held-delivery] could not build a captain-held backlog fixture`, also reproduced on local-main baseline `56326e0d`; known baseline fixture failure. |
| `tests/fm-wake-queue.test.sh` | Adopt local | Local queue/stall receipt and invalid-queue behavior are retained with the watcher implementation. Previously passed 1/1 on Route B. |
| `tests/fm-classify-decision-key.test.sh` | Adopt local | Relative status-path ownership fix is retained; local test passed 1/1. |
| `tests/fm-classify-corr-token.test.sh` | Adopt local | Retained classifier correlation-token behavior; local test passed 1/1. |
| `tests/fm-wake-drain-open-decisions.test.sh` | Adopt local | Retained local drain/classifier semantics; local test passed in prior focused run. |
| `tests/fm-wake-drain-unread-status.test.sh` | Adopt local with timestamp-aware assertion | Local report-order behavior is compatible after accepting upstream `[at=...]` stamping. Local parent-report case passes when using timestamp-aware matching; full local suite pass was observed in prior run. |

## Pending-reply local test

The local `tests/fm-pending-reply.test.sh` adds extensive checks for expiry and safety behavior. Its 48 named cases are not all portable to the upstream implementation. After adapting timestamp-sensitive status checks without weakening event assertions, the run passes the early recovery/decision cases, then fails:

```text
not ok - tmux fallback idle should trigger recovery after grace
not ok - tmux unknown-state capture fallback failed
```

The assertions exercise `fm_pending_reply_fallback_idle_eligible` and `fm_pending_reply_backend_observation` (`bin/fm-pending-reply-lib.sh:778-849`). Upstream has the same bounded `fallback-idle` implementation at `origin/main:bin/fm-pending-reply-lib.sh:774-841`, so the source behavior is not a local-only mechanism. The mismatch is in test setup: local test fixture records `turn_seen_busy=1` on a busy observation, while upstream fallback acceptance consults the record's phase/start/grace fields and its completion state path. Exact two failure outputs above are reproducible; this whole local suite is not adopted as a single file until its local-only assertions are separated from upstream-equivalent cases. Main's ≤50-line threshold means no hundreds-line rewrite was made.

## Other local test deltas

The following shared test files have local diffs that would require more than 50 lines of composition or contain expectations tied to behavior now implemented by upstream; they are **not adopted** under the current bound, with no assertions deleted from any accepted test:

| Tests | Decision | Reason |
|---|---|---|
| `fm-control-relaunch`, `fm-kimi-harness`, `fm-spawn-dispatch-profile` | Not adopted | Local revisions are hundreds of lines and overlap substantially rewritten upstream suites; integration exceeds 50 changed lines. |
| `fm-remote-secondmate-lifecycle-e2e`, `fm-secondmate-lifecycle-e2e`, `fm-secondmate-restart`, `fm-secondmate-safety`, `fm-secondmate-harness` | Not adopted | Assertions target local remote continuation/model-pin or runtime-state changes; code either has a separate behavior review or is upstream-owned. Requires per-case composition >50 lines. |
| `fm-backlog-atomicity`, `fm-harness-adapter-instructions-live-e2e`, `fm-harness-liveness-drift-live-e2e`, `fm-pi-primary-types`, `fm-send-inbox-doorbell-live-e2e`, `secondmate-helpers` | Not adopted | Local edits are coupled to Kimi, watchdog, or secondmate behavior not wholly retained; test-specific integration has not been shown under the 50-line cap. |

The local-only `tests/fm-secondmate-bash-watchdog.test.sh` remains adopted as a local-only asset and previously passed 1/1.

## Result

No pending-reply or watcher tests were weakened. The safe, retained local suites are identified above; large mixed suites remain explicitly unadopted pending the behavior dispositions in the main report.

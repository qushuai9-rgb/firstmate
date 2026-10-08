

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

## `fm-watch-triage` baseline comparison (2026-10-08)

Both commands were run on this machine with the same environment and repository tools:

```text
Branch: bash tests/fm-watch-triage.test.sh
Baseline: (cd /tmp/fm-main-baseline && bash tests/fm-watch-triage.test.sh)
```

The baseline worktree was detached at `56326e0d52ecdc49b6cc6700e776fdcfcfe94b2e` and removed after the comparison.
Both runs reached the same fixture failure. Branch output:

```text
ok - a captain-held lane is rechecked as a hold on the captain, never as an external wait, and never at all while the captain is away
not ok - [held-delivery] could not build a captain-held backlog fixture
ROUTEB_RC=1
```

Baseline output:

```text
ok - a captain-held lane is rechecked as a hold on the captain, never as an external wait, and never at all while the captain is away
ok - work under an open captain call surfaces once, absorbs pane churn, then re-surfaces when the window elapses
ok - a stale window with no open captain call keeps alarming on every new hash
ok - a wake that never reached the durable queue arms no re-surface throttle
ok - a released-then-re-held task is a distinct captain call whose first sight still alarms
ok - a declared paused secondmate re-surfaces on the bounded normal-mode cadence
ok - a captain-held secondmate re-surfaces on the bounded normal-mode cadence
ok - a non-paused secondmate retains normal stale suppression
ok - a resumed secondmate clears pause and stale tracking before stale exemption
ok - unchanged stale hashes reclassify when a crew enters or leaves pause
ok - a declared pause is periodically rechecked against authoritative active-run state
ok - a paused status overridden by authoritative working preserves its wedge timer, is rechecked rather than wedge-escalated while the declaration stands, and escalates once it is lifted
ok - matching non-terminal stale suppressors repair missing or corrupt stale-since timers
ok - a quiet pane writing its own worktree is deferred, while one writing nothing still wedge-escalates on the unchanged schedule
ok - a write deferral re-surfaces once on the bounded pause cadence, so a churning worktree cannot stay invisible
ok - a secondmate's own home supervision churn is not crew write evidence, so a pane recording that home keeps the unchanged escalation schedule
ok - an idle-window timer repair drops a finished write-deferral chain, so the next deferral gets a fresh re-surface window
ok - both first-sight paths through a captain-relevant status drop a finished write-deferral chain with the idle window
ok - triage log capping handles wc byte counts with leading spaces
ok - a captured process-event result wakes a healthy watcher proactively, with no manual drain
ok - an unacknowledged process-event result re-drains until handling is acknowledged
ok - complete process-event queue keys map to distinct seen markers
ok - process-event queue keys surface under their own headlines
ok - every launch-failure episode is delivered under the failed-to-start headline
ok - surfacing failures replay until post-handling acknowledgement
ok - marker failure exits through the shared wake owner, releases its lock, and replays later
ok - a heartbeat with no captain-relevant change is absorbed and backs off the cadence
ok - heartbeat backstop fail-safe surfaces a captain-relevant status the per-wake path missed
ok - the heartbeat backstop surfaces a captain event hidden behind a later routine append
ok - the liveness beacon stays fresh while the watcher absorbs benign wakes (fm-guard never false-alarms)
ok - an afk signal records its captured heartbeat endpoint
ok - with .afk present the watcher reverts to one-shot so the daemon owns triage (no double-triage)
ok - AFK changed paused panes hand off plain stale identities for daemon-owned pause triage
ok - a captain-held item is never rechecked while the away-posture record exists, and the recheck returns once the record is archived
ok - a live captain-held pane is absorbed on first sight while the away-posture record exists
ok - a delivery the captain already holds is never rechecked while the away-posture record exists
ok - the daemon-owned one-shot never hands off a captain-held pane while the away-posture record exists
ok - a declared wait naming a near-future until time stays quiet until that time
ok - a wrong-year declared time cannot silence the watcher beyond the recheck cadence
ok - a declared wait whose until time has passed is rechecked at once, then held to the cadence
```

Thus the exact `[held-delivery] could not build a captain-held backlog fixture` failure is also present on baseline and is a known baseline failure, not a route-B regression.
The baseline continues through additional cases because its tasks-axi fixture succeeds there; the branch fixture failure's underlying cause was not captured and remains an environment/test-fixture uncertainty.
The stale `propose`/`confirm` helper was updated to `enter`; the away-record intent is unchanged.

## Main disposition: captain decision table for the 38 shared local deltas

Main disposition: this table records what route B omits from local main; it does not infer the captain's answer. Where function-level equivalence was not directly established, the stated consequence is a risk to review, not a claim that upstream lacks the behavior.

### Behavior-bearing local changes to review first

| File | Local change from history and short diff | Capability | Concrete loss if omitted | Nature |
|---|---|---|---|---|
| `bin/fm-busy-event.sh` | `aececc28 fix(bin): end a mate's in-turn progress evidence when its turn ends`; adds lifecycle progress/end evidence. | Secondmate turn liveness. | Turn evidence can persist past completion or fail to distinguish a later turn; watcher-family integration may lose accurate age evidence. | Local unique behavior; inspect/recover. |
| `bin/fm-brief.sh` | `d562aba0 fix: harden secondmate runtime state`; 10 inserted lines in task instructions. | Secondmate metadata/runtime-state contract. | Workers may not emit or preserve the local runtime-state evidence expected by the local watcher. | Local behavior/instruction; equivalence unverified. |
| `bin/fm-contributions.sh` | `56326e0d fix(bin): treat a read killed at its bound as budget refusal`; classifies bounded read termination. | Contribution polling. | A slow but healthy forge read may be treated as unavailable and create repeat notifications. | Local unique fix; prior investigation believed upstream equivalent but this audit did not run a direct comparison. |
| `bin/fm-control-lib.sh` | `d617f1e7 merge: surface secondmate parent reports`; updates report handling (8 insertions/3 deletions). | Lifecycle report publication. | A secondmate completion/report can fail to reach the parent through the expected status route. | Behavior-bearing; upstream equivalence unverified. |
| `bin/fm-kimi-turnend-hook.sh` | `1e001934 fix: update kimi cli adapter for 1.50`; 24 insertions/9 deletions. | Kimi turn-end integration. | Kimi 1.50 may no longer receive the local turn-end hook behavior. | Local compatibility fix; upstream hook file absent, equivalence unverified. |
| `bin/fm-pending-reply-lib.sh` | `016d068b` rebuilds expiry guards; `2f77d836` rejects symlinked records; `a75afb15` resolves sibling path. | Durable reply recovery and expiry. | Invalid/mislocated pending replies may be mishandled, or legitimate replies may remain/escalate incorrectly. | Behavior-bearing security/recovery fixes; must review upstream implementations, not infer from similar upstream commits. |
| `bin/fm-remote-secondmate-control.sh` | `78921839` hardens remote policy; `fb3c38b6` pins model consistency; `bf8bb399` preserves remote continuation and suppresses idle false alarms; 107 insertions. | Remote secondmate lifecycle and model pinning. | A remote restart may lose continuation policy or accept inconsistent model/policy metadata. | Local unique behavior risk; upstream equivalence unverified. |
| `bin/fm-secondmate-restart.sh` | `bf8bb399 no-mistakes(review): Preserve remote continuation state and suppress idle false alarms`; preserves `self_continue` on restart. | Remote restart policy. | Restarted mate may silently lose the opt-in continuation behavior or produce false idle alarms. | Behavior-bearing; equivalence unverified. |
| `bin/fm-spawn.sh` | `fb3c38b6` remote model-pin consistency and `bf8bb399` continuation persistence; 72 insertions/13 deletions. | Spawn identity and secondmate policy. | A remote launch/relaunch can bind the wrong model or omit continuation settings. | Behavior-bearing; upstream equivalents need direct behavioral comparison. |
| `bin/fm-teardown.sh` | Local merge/reconcile commits alter 3 insertions/2 deletions; local history includes secondmate watchdog integration. | Safe teardown and endpoint cleanup. | A local-only cleanup guard could be omitted; exact semantic delta requires review of the small patch. | Unclassified behavior delta; inspect before disposition. |
| `tests/fm-pending-reply.test.sh` | `016d068b`, `a75afb15`; 273 added lines. | Pending-reply recovery regressions. | Regression coverage for expiry, path ownership, and symlink safety is lost even if upstream implementation is equivalent. | Local test enhancement/specification. |
| `tests/fm-secondmate-lifecycle-e2e.test.sh` | `d562aba0` plus local review; 26 insertions/3 deletions. | End-to-end secondmate lifecycle. | Local restart/runtime-state interaction cases are no longer exercised. | Local test enhancement. |
| `tests/fm-secondmate-safety.test.sh` | `78921839`, `74ab53d9`; 21 insertions. | Safety regressions for secondmate lifecycle. | Locally added remote/watcher safety cases are no longer exercised. | Local test enhancement. |
| `tests/fm-watch-triage.test.sh` | `fb3c38b6`, `bf8bb399`, `e475cbc0`; 524 inserted lines. | Provider errors, idle lapse, turn hang, and product-output evidence. | Local watcher-specific regressions and specifications are absent from the upstream-based branch. | Local test enhancement; watcher implementation itself is retained. |
| `tests/fm-wake-queue.test.sh` | `aececc28`, `119a1a5c`; 123 insertions. | Queue/liveness edge cases. | Tests for local secondmate queue and age evidence are lost. | Local test enhancement. |
| `tests/secondmate-helpers.sh` | `84a903b5`, `74ab53d9`; 6 insertions/1 deletion. | Shared fixtures used by secondmate tests. | Local fixture semantics may no longer reproduce the cases that motivated watcher fixes. | Test support change; inspect with corresponding suites. |

### Remaining shared-file review inventory

| File | Local delta from `git log 8d9d5dac..main -- <file>` | Capability and loss if omitted | Nature |
|---|---|---|---|
| `.agents/skills/harness-adapters/references/harness/kimi.md` | `1e001934 fix: update kimi cli adapter for 1.50` | Kimi version-specific launch and trust guidance; local 1.50 guidance might be absent under newer upstream guidance. | Documentation/adapter guidance; version-equivalence unverified. |
| `.agents/skills/secondmate-provisioning/SKILL.md` | `9ceb5086 no-mistakes(document): Document FM_SECONDMATE_SELF_CONTINUE in config and provisioning skill` | Documents the opt-in continuation charter. | Local documentation delta; upstream presence not verified. |
| `tests/fm-backlog-atomicity.test.sh` | `d617f1e7`, `1e001934` | Backlog atomicity coverage for local report/Kimi changes. | Test enhancement; specific added assertions not individually compared. |
| `tests/fm-classify-corr-token.test.sh` | `56e76032 test: give the reserved-key fixtures their durable owner` | Correlation-token reserved-key fixture ownership. | Test-only fixture correction; risk is loss of that regression. |
| `tests/fm-classify-decision-key.test.sh` | `a75afb15`, `0378ebd4`, `9109afb5`; 90 insertions/146 deletions | Relative-path pending-reply classification and expiry cases. | Local test specification; upstream behavior is not proven identical by commit history. |
| `tests/fm-control-relaunch.test.sh` | `d562aba0` and local merge integrations; 74 insertions | Relaunch preserves secondmate-specific metadata. | Test enhancement; concrete behavior ties to restart/spawn above. |
| `tests/fm-harness-adapter-instructions-live-e2e.test.sh` | `1e001934`, `d617f1e7` | Live adapter instruction assertions for Kimi and parent reports. | Test enhancement. |
| `tests/fm-harness-liveness-drift-live-e2e.test.sh` | Local watchdog merge commits; 2 insertions/2 deletions | Liveness drift coverage. | Test adjustment; no function-level equivalence audit. |
| `tests/fm-kimi-harness.test.sh` | `d5ef97e8 fix(kimi): match CLI 1.50 banner text in spawn readiness gate`; local integration adds tests. | Kimi 1.50 readiness and turn-end behavior. | Test enhancement tied to Kimi compatibility; upstream supports newer Kimi but equivalence unverified. |
| `tests/fm-pi-primary-types.test.sh` | `aaca26a3` watchdog integration; 1 insertion | Pi primary type/extension compatibility. | Test enhancement for local watchdog event. |
| `tests/fm-remote-secondmate-lifecycle-e2e.test.sh` | `78921839`, `fb3c38b6`; 48 insertions | Remote restart policy and model-pin regression coverage. | Test enhancement. |
| `tests/fm-secondmate-harness.test.sh` | `d562aba0`; 28 insertions | Secondmate harness runtime-state coverage. | Test enhancement. |
| `tests/fm-secondmate-restart.test.sh` | `bf8bb399`; 7 insertions/3 deletions | Continuation metadata survives remote restart. | Test enhancement tied to behavior-bearing restart change. |
| `tests/fm-send-inbox-doorbell-live-e2e.test.sh` | Local integration commits; 49 insertions/10 deletions | End-to-end durable steering inbox behavior in secondmate scenarios. | Test enhancement. |
| `tests/fm-spawn-dispatch-profile.test.sh` | Local integration commits; 57 insertions/2 deletions | Dispatch profile and fallback coverage. | Test enhancement; upstream behavior should be checked against the local assertions. |
| `tests/fm-wake-drain-open-decisions.test.sh` | `56e76032`, `a75afb15`; 95 insertions | Reserved keys and relative pending-reply open-decision handling. | Test enhancement/specification. |
| `tests/fm-wake-drain-unread-status.test.sh` | `8d6d2b43`, `73286dce3c`; 77 insertions | Parent reports appear in order and are not duplicated. | Test enhancement; upstream behavior exists but exact local assertions need comparison. |
| `tests/fm-secondmate-bash-watchdog.test.sh` | `aaca26a3` | Local watchdog timeout/recovery regression; retained as a local-only asset, not omitted. | Class B retained. |
| `tests/fm-watch-triage.test.sh` | Listed above as behavior-specifying local watcher test; retained from local main in the preserved watcher family. | Not omitted on route B. | Class B retained. |
| `tests/fm-wake-queue.test.sh` | Listed above; retained as local watcher-family test. | Not omitted on route B. | Class B retained. |
| `bin/fm-watch.sh`, `bin/fm-classify-lib.sh`, `bin/fm-wake-lib.sh`, `bin/fm-wake-drain.sh` | Local watcher implementations retained. | Core route-B preserved family. | Class B retained. |

### Local unique behavior fixes and current-problem assessment

- `bin/fm-busy-event.sh` local commit `aececc28` is titled “end a mate's in-turn progress evidence when its turn ends”; the fix removes stale turn-progress evidence at turn completion. It addresses a mate being treated as still in an old turn after completion. Upstream does not contain this helper file; current equivalent behavior elsewhere has not been verified. **Potential current gap: unverified.**
- `bin/fm-contributions.sh` local commit `56326e0d` says “treat a read killed at its bound as budget refusal”; the short diff maps rc 124 to `BUDGET_EXHAUSTED`. The intended problem is a bounded slow read being mislabeled as unavailable forge evidence. Upstream `origin/main:bin/fm-contributions.sh`, `forge()`, has related timeout handling, but same-input behavior was not replayed in this audit. **Likely equivalent, runtime equivalence unverified.**
- `bin/fm-pending-reply-lib.sh` local commits explicitly rebuild expiry guards, reject symlinked records, resolve sibling paths with `dirname`, and harden relative ownership. These protect record integrity and ensure expiration/path decisions apply to the intended task. Upstream contains newer pending-reply ownership/resolve commits, but each local guard was not individually tested against upstream. **Current gaps: unverified.**
- `bin/fm-remote-secondmate-control.sh` and `bin/fm-secondmate-restart.sh` local changes preserve remote continuation policy and model-pin consistency across relaunch. This prevents a restart from changing the selected model or silently disabling self-continuation. Upstream has remote metadata republication and lifecycle improvements, but no same-input runtime comparison was performed. **Current gaps: unverified.**
- `bin/fm-spawn.sh` local changes enforce consistency between remote launch policy and recorded model pin. The concrete loss could be a remote mate launched under a different model than its durable record or losing its continuation choice. Upstream has substantial spawn changes; equivalent behavior remains **unverified**.

Summary counts for the shared-file inventory: local behavior-bearing changes needing direct review: 10; local test-only or test-support enhancements: 19; documentation/adapter-guidance changes: 5; small/unclassified implementation deltas needing diff review: 4. These are review categories, not claims that upstream lacks each behavior.
The 38-file inventory is not cleared for landing by this table; main disposition must decide whether to recover any behavior-bearing local changes or accept them as explicit drops.

## Behavior-port follow-up under main disposition

| File | Local delta | Port decision | Test command/result |
|---|---|---|---|
| `bin/fm-contributions.sh` | Local rc=124 marks the bounded read as budget exhaustion. | No port needed: inspected `origin/main:bin/fm-contributions.sh` `forge()` lines 217-233; it handles rc=124 by setting `BUDGET_EXHAUSTED=1` and writing `$TMP/budget-exhausted`. | Existing historical suite not rerun in this pass. |
| `bin/fm-busy-event.sh` | On a transition to non-busy, remove `$STATE/$ID.progress`, refusing the transition if cleanup fails; otherwise stale progress can survive turn completion. | Ported this behavior into the upstream implementation after `OLD_SEQ` parsing and before `write_record`, preserving the upstream writer. | `bash tests/fm-busy-state.test.sh`: 1/1 passed. |
| `bin/fm-pending-reply-lib.sh` | Local delta includes expiry guards, symlink refusal, and relative sibling-path resolution; 146 inserted lines. | Analysis only; no code changed. See `reports/pending-reply-analysis.md` for behavior-unit comparison and requested segment authorization. | Not rerun in this pass. |
| `bin/fm-brief.sh` | Ten-line local additions around secondmate runtime-state guidance. | Pending per-file behavior review; no port performed. | Not run. |
| `bin/fm-control-lib.sh` | Eight additions/three removals from report/lifecycle integration. | Pending behavior-level comparison; no port performed. | Not run. |
| `bin/fm-kimi-turnend-hook.sh` | Local Kimi CLI 1.50 compatibility adjustment; upstream file exists in current base though absent at merge-base. | Pending comparison of hook payload/config behavior; no port performed. | Not run. |
| `bin/fm-remote-secondmate-control.sh` | Remote policy/model pin/continuation hardening; 107 insertions. | Not ported pending comparison with upstream remote lifecycle structures; scope likely exceeds small additive adaptation. | Not run. |
| `bin/fm-secondmate-restart.sh` | Preserve remote continuation policy across restart. | Pending test-backed comparison to upstream metadata republication path; no port performed. | Not run. |
| `bin/fm-spawn.sh` | Preserve remote model pin and continuation policy; 72 insertions/13 removals. | Not ported pending behavior review; no edits to upstream spawn semantics. | Not run. |
| `bin/fm-teardown.sh` | Small local changes in secondmate cleanup path. | Pending exact hunk review; no port performed. | Not run. |

The approved per-file stop condition is active for `bin/fm-pending-reply-lib.sh`: its local delta is 146 inserted lines, above the 50-line limit, and upstream semantics changed in the same area. No further behavior ports were attempted after identifying this scope boundary.

## Still unverified

No complete repository-wide test suite has been run on this route-B branch.
The watcher triage suite is blocked at the compatible tasks-axi backlog fixture, so its later cases remain unverified.
The current watcher syntax check was denied by the protected-command safety layer when attempting `bash -n bin/fm-watch.sh`; no watcher lifecycle action was taken.
The upstream base has since moved from the original `e06a46fe` to `b062eb94`; the branch is based exactly on `b062eb94` and includes the additional local-only asset restoration in later commits.
Rollback target remains local main `56326e0d52ecdc49b6cc6700e776fdcfcfe94b2e`.

## Local-main content audit against merge-base

Verdicts: B = branch exact local content retained; A = proved equivalent upstream behavior; C = no equivalence proven and local delta absent from branch, requires captain disposition. I did not infer equivalence from file names or titles.

| File | Verdict | Reproducible evidence |
|---|---|---|
| `.agents/skills/harness-adapters/references/harness/kimi.md` | **C** | Local: a97e4ce9 merge: local main into the secondmate runtime-state branch; 1e001934 fix: update kimi cli adapter for 1.50; upstream path commits: 5d3acc82 fix(bin): answer Kimi 2.0.0 folder-trust dialog during spawn (#4799). Commit overlap/equivalence not proved; branch uses upstream content. |
| `.agents/skills/secondmate-provisioning/SKILL.md` | **C** | Local: 9ceb5086 no-mistakes(document): Document FM_SECONDMATE_SELF_CONTINUE in config and provisioning skill; upstream path commits: 12e90e14 fix: inherit supervision host opt-out across secondmates (#6154); 30ef650d fix(bin): stop reporting untouched shared-captain copies as drift (#4806). Commit overlap/equivalence not proved; branch uses upstream content. |
| `.agents/skills/show-me/FIRSTMATE.md` | **B** | `git diff --quiet main HEAD -- .agents/skills/show-me/FIRSTMATE.md` returns 0; branch retains local blob. |
| `.agents/skills/show-me/SKILL.md` | **B** | `git diff --quiet main HEAD -- .agents/skills/show-me/SKILL.md` returns 0; branch retains local blob. |
| `.pi/extensions/fm-secondmate-bash-watchdog.ts` | **B** | `git diff --quiet main HEAD -- .pi/extensions/fm-secondmate-bash-watchdog.ts` returns 0; branch retains local blob. |
| `bin/fm-brief.sh` | **C** | Local: d562aba0 fix: harden secondmate runtime state; 74ab53d9 fix(watch): close secondmate monitoring gaps; upstream path commits: 6a7b3919 feat(bin): start tasks from a named base branch (#6442); 918a5bf1 fix(bin): clarify scratch guidance and dirty teardown refusals (#6505). Commit overlap/equivalence not proved; branch uses upstream content. |
| `bin/fm-busy-event.sh` | **C** | Local: aececc28 fix(bin): end a mate's in-turn progress evidence when its turn ends; upstream path commits: none. Commit overlap/equivalence not proved; branch uses upstream content. |
| `bin/fm-classify-lib.sh` | **B** | Restored from local main plus only additive upstream `status_stamp_line`; unrelated local classifier changes are retained. |
| `bin/fm-contributions.sh` | **C** | Local: 56326e0d fix(bin): treat a read killed at its bound as budget refusal; upstream path commits: 4c0331a5 feat(bin): retire a contribution whose forge object is permanently gone (#6655); b5d90612 fix(bin): document accepted contribution verdict actors (#6307). Commit overlap/equivalence not proved; branch uses upstream content. |
| `bin/fm-control-lib.sh` | **C** | Local: a97e4ce9 merge: local main into the secondmate runtime-state branch; d617f1e7 merge: surface secondmate parent reports (wake classification fix); upstream path commits: 920a7d98 fix: preserve Herdr status on Pi relaunch (#5161); 5df1294f test: make sibling secondmate stall tests wait for watcher observations (#5389). Commit overlap/equivalence not proved; branch uses upstream content. |
| `bin/fm-kimi-turnend-hook.sh` | **C** | Local: 1e001934 fix: update kimi cli adapter for 1.50; upstream path commits: none. Commit overlap/equivalence not proved; branch uses upstream content. |
| `bin/fm-pending-reply-lib.sh` | **C** | Local: 016d068b fix(bin): rebuild the two expiry guards lost with the reclaimed gate head; 2f77d836 no-mistakes(review): Reject symlinked pending-reply records safely; upstream path commits: 9b85a955 fix(bin): resolve a pending reply only from its own task's status line (#6792); 70f2ed3d fix(bin): reopen a pending-reply escalation after its resolve (#6654). Commit overlap/equivalence not proved; branch uses upstream content. |
| `bin/fm-remote-secondmate-control.sh` | **C** | Local: 78921839 no-mistakes(review): Harden remote policy consistency and add behavioral regressions; fb3c38b6 no-mistakes(review): Harden keyed idle detection and remote model pin consistency; upstream path commits: e789e522 fix(bin): republish parent metadata after a remote secondmate relaunch (#5583). Commit overlap/equivalence not proved; branch uses upstream content. |
| `bin/fm-secondmate-restart.sh` | **C** | Local: bf8bb399 no-mistakes(review): Preserve remote continuation state and suppress idle false alarms; upstream path commits: e789e522 fix(bin): republish parent metadata after a remote secondmate relaunch (#5583). Commit overlap/equivalence not proved; branch uses upstream content. |
| `bin/fm-spawn.sh` | **C** | Local: fb3c38b6 no-mistakes(review): Harden keyed idle detection and remote model pin consistency; bf8bb399 no-mistakes(review): Preserve remote continuation state and suppress idle false alarms; upstream path commits: ac0811c4 feat(bin): defer spawns beyond a declared per-project capacity, opt-in (#5343); 47aff866 feat: add per-home worker tool exclusions (#6750). Commit overlap/equivalence not proved; branch uses upstream content. |
| `bin/fm-teardown.sh` | **C** | Local: a97e4ce9 merge: local main into the secondmate runtime-state branch; 43230587 Merge branch 'fm/secondmate-turn-watchdog' of /Users/qushuai9/.treehouse/firstmate-8bf1b0/2/firstmate; upstream path commits: ac0811c4 feat(bin): defer spawns beyond a declared per-project capacity, opt-in (#5343); 6a7b3919 feat(bin): start tasks from a named base branch (#6442). Commit overlap/equivalence not proved; branch uses upstream content. |
| `bin/fm-wake-drain.sh` | **B** | `git diff --quiet main HEAD -- bin/fm-wake-drain.sh` returns 0; branch retains local blob. |
| `bin/fm-wake-lib.sh` | **B** | `git diff --quiet main HEAD -- bin/fm-wake-lib.sh` returns 0; branch retains local blob. |
| `bin/fm-watch.sh` | **B** | `git diff --quiet main HEAD -- bin/fm-watch.sh` returns 0; branch retains local blob. |
| `data/fm-secondmate-runtime-state-hardening/triage.md` | **B** | `git diff --quiet main HEAD -- data/fm-secondmate-runtime-state-hardening/triage.md` returns 0; branch retains local blob. |
| `docs/architecture.md` | **C** | Local: b2ef3d13 no-mistakes(review): Tighten provider matcher; key episodes by failure context; 01615665 no-mistakes(review): fix secondmate hang/lapse busy gates, growth window, provider matcher; upstream path commits: 6a7b3919 feat(bin): start tasks from a named base branch (#6442); 42dd906d fix(bin): escalate inbox instructions blocked by busy workers (#6518). Commit overlap/equivalence not proved; branch uses upstream content. |
| `docs/configuration.md` | **C** | Local: 9ceb5086 no-mistakes(document): Document FM_SECONDMATE_SELF_CONTINUE in config and provisioning skill; e475cbc0 no-mistakes(review): Reconcile self_continue from charter to cover pre-existing idle-lapse mates; upstream path commits: ac0811c4 feat(bin): defer spawns beyond a declared per-project capacity, opt-in (#5343); 47aff866 feat: add per-home worker tool exclusions (#6750). Commit overlap/equivalence not proved; branch uses upstream content. |
| `docs/secondmate-parent-channel.md` | **C** | Local: 4228418b no-mistakes(document): Documented secondmate parent-report wake surfacing; upstream path commits: f5930603 fix(bin): exclude a remote mate's own parent channel from self-home status scans (#5263); f1ea9ed5 fix(bin): bind inactive-outcome receipt identity to structured fields only (#5520). Commit overlap/equivalence not proved; branch uses upstream content. |
| `docs/secondmate-runtime-state-reconcile.md` | **B** | `git diff --quiet main HEAD -- docs/secondmate-runtime-state-reconcile.md` returns 0; branch retains local blob. |
| `docs/turnend-guard.md` | **C** | Local: a97e4ce9 merge: local main into the secondmate runtime-state branch; 9b543388 Merge branch 'fm/secondmate-watchdog' of /Users/qushuai9/.treehouse/firstmate-8bf1b0/2/firstmate; upstream path commits: 46d58d64 fix: keep watcher arms and reply listeners alive through slow cycles (#6103); 3b689975 docs: restructure turnend-guard.md for readability (#5611). Commit overlap/equivalence not proved; branch uses upstream content. |
| `docs/verification/runtime-backends.md` | **C** | Local: a97e4ce9 merge: local main into the secondmate runtime-state branch; 43230587 Merge branch 'fm/secondmate-turn-watchdog' of /Users/qushuai9/.treehouse/firstmate-8bf1b0/2/firstmate; upstream path commits: 329ad4ed test: make agent process fixtures compatible with multicall sleep (#6814); 23e71b3d feat(bin): add opt-in --herdr-resume-lock-wait to fm-spawn (#6649). Commit overlap/equivalence not proved; branch uses upstream content. |
| `skills/show-me/SKILL.md` | **B** | `git diff --quiet main HEAD -- skills/show-me/SKILL.md` returns 0; branch retains local blob. |
| `skills/show-me/UPSTREAM.md` | **B** | `git diff --quiet main HEAD -- skills/show-me/UPSTREAM.md` returns 0; branch retains local blob. |
| `skills/show-me/upstream-LICENSE.txt` | **B** | `git diff --quiet main HEAD -- skills/show-me/upstream-LICENSE.txt` returns 0; branch retains local blob. |
| `tests/fm-backlog-atomicity.test.sh` | **C** | Local: d617f1e7 merge: surface secondmate parent reports (wake classification fix); 1e001934 fix: update kimi cli adapter for 1.50; upstream path commits: aedb7bbf fix(bin): close Gerrit-landed backlog items with the change URL as a note (#6140); 83a4bbdb fix(bin): strip AI co-author trailers from fleet-launched commits (#5695). Commit overlap/equivalence not proved; branch uses upstream content. |
| `tests/fm-classify-corr-token.test.sh` | **C** | Local: 56e76032 test: give the reserved-key fixtures their durable owner; upstream path commits: 70f2ed3d fix(bin): reopen a pending-reply escalation after its resolve (#6654); 84362f65 fix(bin): surface unrecognized status prefixes instead of reading them as silence (#5588). Commit overlap/equivalence not proved; branch uses upstream content. |
| `tests/fm-classify-decision-key.test.sh` | **C** | Local: a75afb15 fix(bin): resolve the pending-reply sibling record path with dirname; 0378ebd4 no-mistakes(review): Harden queue supervision and relative pending-reply ownership; upstream path commits: 70f2ed3d fix(bin): reopen a pending-reply escalation after its resolve (#6654); c6e816ff fix(bin): keep a stated default-key retraction from cancelling a keyless wait (#5587). Commit overlap/equivalence not proved; branch uses upstream content. |
| `tests/fm-control-relaunch.test.sh` | **C** | Local: a97e4ce9 merge: local main into the secondmate runtime-state branch; d562aba0 fix: harden secondmate runtime state; upstream path commits: 47aff866 feat: add per-home worker tool exclusions (#6750); 2d7daa9e fix: refuse a confirming Enter on the Claude background-task exit picker (#6666). Commit overlap/equivalence not proved; branch uses upstream content. |
| `tests/fm-harness-adapter-instructions-live-e2e.test.sh` | **C** | Local: d617f1e7 merge: surface secondmate parent reports (wake classification fix); 1e001934 fix: update kimi cli adapter for 1.50; upstream path commits: none. Commit overlap/equivalence not proved; branch uses upstream content. |
| `tests/fm-harness-liveness-drift-live-e2e.test.sh` | **C** | Local: a97e4ce9 merge: local main into the secondmate runtime-state branch; 9b543388 Merge branch 'fm/secondmate-watchdog' of /Users/qushuai9/.treehouse/firstmate-8bf1b0/2/firstmate; upstream path commits: none. Commit overlap/equivalence not proved; branch uses upstream content. |
| `tests/fm-kimi-harness.test.sh` | **C** | Local: a97e4ce9 merge: local main into the secondmate runtime-state branch; d617f1e7 merge: surface secondmate parent reports (wake classification fix); upstream path commits: 23e55847 fix(bin): keep the steering doorbell short under deep homes (#6240); 83a4bbdb fix(bin): strip AI co-author trailers from fleet-launched commits (#5695). Commit overlap/equivalence not proved; branch uses upstream content. |
| `tests/fm-pending-reply.test.sh` | **C** | Local: 016d068b fix(bin): rebuild the two expiry guards lost with the reclaimed gate head; a75afb15 fix(bin): resolve the pending-reply sibling record path with dirname; upstream path commits: 9b85a955 fix(bin): resolve a pending reply only from its own task's status line (#6792); 70f2ed3d fix(bin): reopen a pending-reply escalation after its resolve (#6654). Commit overlap/equivalence not proved; branch uses upstream content. |
| `tests/fm-pi-primary-types.test.sh` | **C** | Local: a97e4ce9 merge: local main into the secondmate runtime-state branch; aaca26a3 feat: add secondmate bash watchdog extension (5-min stall detection + self-rescue injection); upstream path commits: 5cec4e2b fix(pi): hide queued Firstmate inputs under Calm only when the session can keep them (#5563); 888871de fix: preserve substantive mid-turn text in Pi Calm (#4788). Commit overlap/equivalence not proved; branch uses upstream content. |
| `tests/fm-remote-secondmate-lifecycle-e2e.test.sh` | **C** | Local: 78921839 no-mistakes(review): Harden remote policy consistency and add behavioral regressions; fb3c38b6 no-mistakes(review): Harden keyed idle detection and remote model pin consistency; upstream path commits: 022250d8 fix: keep remote reply listeners and watcher cycles running (#5941); 62d643c7 test: stop the remote secondmate e2e watcher before temp-root cleanup (#5845). Commit overlap/equivalence not proved; branch uses upstream content. |
| `tests/fm-secondmate-bash-watchdog.test.sh` | **B** | `git diff --quiet main HEAD -- tests/fm-secondmate-bash-watchdog.test.sh` returns 0; branch retains local blob. |
| `tests/fm-secondmate-harness.test.sh` | **C** | Local: d562aba0 fix: harden secondmate runtime state; upstream path commits: 237e1cf3 test: cover PID collisions in harness ancestry detection (#6484); 12e90e14 fix: inherit supervision host opt-out across secondmates (#6154). Commit overlap/equivalence not proved; branch uses upstream content. |
| `tests/fm-secondmate-lifecycle-e2e.test.sh` | **C** | Local: a97e4ce9 merge: local main into the secondmate runtime-state branch; d562aba0 fix: harden secondmate runtime state; upstream path commits: d1ce6b6c fix: auto-relaunch dead secondmates during supervision (#5496). Commit overlap/equivalence not proved; branch uses upstream content. |
| `tests/fm-secondmate-restart.test.sh` | **C** | Local: bf8bb399 no-mistakes(review): Preserve remote continuation state and suppress idle false alarms; upstream path commits: e789e522 fix(bin): republish parent metadata after a remote secondmate relaunch (#5583); 1fe1a679 fix(bin): deliver Claude-bound operational input as a record-backed doorbell (#5664). Commit overlap/equivalence not proved; branch uses upstream content. |
| `tests/fm-secondmate-safety.test.sh` | **C** | Local: a97e4ce9 merge: local main into the secondmate runtime-state branch; 78921839 no-mistakes(review): Harden remote policy consistency and add behavioral regressions; upstream path commits: 5a9880b4 fix: route second-mate signal wakes by presented status span (#5879); 83a4bbdb fix(bin): strip AI co-author trailers from fleet-launched commits (#5695). Commit overlap/equivalence not proved; branch uses upstream content. |
| `tests/fm-send-inbox-doorbell-live-e2e.test.sh` | **C** | Local: a97e4ce9 merge: local main into the secondmate runtime-state branch; c01104ea no-mistakes(review): Replace fake inbox test with real worker regression; upstream path commits: 23e55847 fix(bin): keep the steering doorbell short under deep homes (#6240). Commit overlap/equivalence not proved; branch uses upstream content. |
| `tests/fm-spawn-dispatch-profile.test.sh` | **C** | Local: a97e4ce9 merge: local main into the secondmate runtime-state branch; 9b543388 Merge branch 'fm/secondmate-watchdog' of /Users/qushuai9/.treehouse/firstmate-8bf1b0/2/firstmate; upstream path commits: 47aff866 feat: add per-home worker tool exclusions (#6750); e5b9dddc fix(bin): name the Firstmate skill file as a fallback in the worker role (#6647). Commit overlap/equivalence not proved; branch uses upstream content. |
| `tests/fm-wake-drain-open-decisions.test.sh` | **C** | Local: 56e76032 test: give the reserved-key fixtures their durable owner; a75afb15 fix(bin): resolve the pending-reply sibling record path with dirname; upstream path commits: none. Commit overlap/equivalence not proved; branch uses upstream content. |
| `tests/fm-wake-drain-unread-status.test.sh` | **C** | Local: 73286dce no-mistakes(review): Prevent duplicate secondmate outcome-backstop presentation; 8d6d2b43 fix: surface secondmate parent reports; upstream path commits: 12e90e14 fix: inherit supervision host opt-out across secondmates (#6154); 0a2cdf95 feat: enable supervision host by default for Claude primaries (#6124). Commit overlap/equivalence not proved; branch uses upstream content. |
| `tests/fm-wake-queue.test.sh` | **C** | Local: aececc28 fix(bin): end a mate's in-turn progress evidence when its turn ends; 119a1a5c fix(bin): stop aging a mate's live turn from its launch record; upstream path commits: 0f34fab4 fix(bin): let TERM stop a watcher blocked in a pane capture on bash 3.2 (#6762); 8690c411 fix: reclaim orphaned watcher arms on the next park (#6335). Commit overlap/equivalence not proved; branch uses upstream content. |
| `tests/fm-watch-triage.test.sh` | **C** | Local: fb3c38b6 no-mistakes(review): Harden keyed idle detection and remote model pin consistency; bf8bb399 no-mistakes(review): Preserve remote continuation state and suppress idle false alarms; upstream path commits: 2d833ff1 fix: treat quiet records as attended across supervision (#6064); d051e6f7 fix: prevent contribution poll starvation on slow GitHub reads (#5900). Commit overlap/equivalence not proved; branch uses upstream content. |
| `tests/secondmate-helpers.sh` | **C** | Local: 84a903b5 no-mistakes(review): fix secondmate idle-lapse window, provider matcher, and relaunch arming; 74ab53d9 fix(watch): close secondmate monitoring gaps; upstream path commits: a452a79e fix(bin): prevent long worker launch command truncation (#4994). Commit overlap/equivalence not proved; branch uses upstream content. |

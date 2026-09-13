# Reconcile: branch `fm/fm-secondmate-runtime-state-hardening` → `origin/main`

Trackable copy of the reconciliation verdict table (the working record lives in this
home's gitignored `data/`, so it is committed here to keep it attached to the branch).
Generated 2026-09-17. Merge-base `$(git merge-base origin/main HEAD)`.
Branch is 21 ahead / 26 behind `origin/main`. No PR has ever existed for this branch.

## Part 1 — Overlap verdict per commit (step 1, read-only)

Verdict vocabulary:
- **not covered** = upstream has no equivalent implementation of this behavior.
- **structurally displaced** = upstream rewrote the surrounding code, so the patch
  cannot be re-applied verbatim, but the *behavior* is still absent upstream and must
  be re-implemented on top of upstream's shape.
- **keep both** = my change and upstream's change address different concerns in the
  same region; neither replaces the other.

| Commit | What it does | Upstream coverage | Verdict / how to merge |
|---|---|---|---|
| `8bdc4bfe` fix(watch): close secondmate monitoring gaps | Adds `secondmate_self_declared_idle`, provider-mismatch episode tracking, relaunch arming fixes in `bin/fm-watch.sh` | `grep` of `origin/main:bin/fm-watch.sh`: 0 hits for `secondmate_self_declared_idle`, `_provider_mismatch_reported` | Not covered. Re-apply against upstream's rewritten watcher. |
| `d535b2ec`,`5e4be691`,`2e85fb5b`,`55cb7211`,`06a58b97`,`457db8c4` review rounds | idle-lapse window, bidirectional provider matcher, growth window, `self_continue` charter reconciliation, `FM_SECONDMATE_SELF_CONTINUE` docs | `git grep self_continue origin/main -- bin/`: 0 hits | Not covered. These are refinements of the above; carry forward. |
| `e710b013` + `5da78ebd`…`cd67e297`,`801b4e77`,`0343da13`,`1828b052`,`8719afb0`,`adefb661`,`4bd5f3a3` core + review hardening | pending-reply expiry, keyed idle detection, remote model-pin consistency, symlink rejection, queue diagnostics | `grep -c "pending_reply_expired\|grace\|record_exists" origin/main:bin/fm-classify-lib.sh`: **0** | Not covered. |
| `6a392c8a` dirname fix | Resolves pending-reply sibling record path with `dirname` | Function doesn't exist upstream | Not covered; folds into the new base. |
| `42a3c8ba` fixture seeds | Reserved-key fixtures seed a durable record | Upstream expanded `tests/fm-classify-decision-key.test.sh` by ~146 lines in #3753 | Structurally displaced. Re-check each fixture against upstream's contract after porting; my tri-state/ownership tests must be added back, not assumed. |
| `7575b4ca` durable ownership | Ownership decided once on the post-fold open set; honors `FM_PENDING_REPLY_DIR_OVERRIDE` | Not covered | Keep both. Must be written against upstream's new fold signature. |
| `9942584a` tri-state idle guard | Provable-empty vs undecidable vs actionable; one durable notice | Not covered | Keep both. Same porting caveat. |

### The only adjacent upstream commit
`b0877b4e` *clear parent pending-replies on local secondmate retirement* (#4680) — touches
retirement cleanup, not classification or the fold. It neither implements nor contradicts
anything in this card. Confirmed non-overlapping.

## Part 2 — Conflict surface (measured, not assumed)

| File | Mine | Upstream | Nature |
|---|---|---|---|
| `bin/fm-classify-lib.sh` | +91 | **+217 / −82** | Upstream rewrote `_fm_decision_fold_line` (new 5th arg `<kind>`), added `_fm_status_kind`, declaration guard, terminal supersession, shared span readers (#3753). My additions sit inside that function. |
| `bin/fm-watch.sh` | +514 / −8 | +200 / −26 | Both large; watcher internals changed on both sides. |
| `bin/fm-spawn.sh` | +72 / −13 | +23 / −1 | Small upstream delta. |
| `docs/architecture.md` | +13 / −17 | +26 / −11 | Doc prose. |
| `bin/fm-brief.sh` | +10 | +4 / −3 | Small. |

## Part 3 — Semantic conflicts requiring a ruling before I proceed

### S1 — Where pending-reply ownership gets filtered in the fold
- **My design**: skip the per-line guard; filter the finished open set so a record
  created after a line was read still suppresses its escalation (`_fm_open_decisions_keep_owned`).
- **Upstream #3753 design**: `_fm_decision_fold_line` now takes a `<kind>` argument and
  applies **terminal supersession** — `done:ship` / `done:scout` / `failed:ship` /
  `failed:scout` lines remove a key from the open set during the fold itself, and the
  guard changed from "any non-space character" to "line contains `:` or `[key=…]`".
- **Why they differ in result**: upstream decides membership *during* the fold from
  status lines only; I decide it *after* the fold from durable records. A decision line
  upstream would now drop as superseded could be one my filter would otherwise keep as
  open — and conversely my post-filter never sees upstream's kind-aware supersession, so
  applying mine naively on top of theirs can resurrect a decision upstream just retired.
- **Consequences**:
  - *upstream wins*: dangling-record suppression regresses — an escalation whose record
    was deleted replays on every poll again (my D3(b) bug returns).
  - *mine wins*: buried declarations and open decisions regress — #3753's whole purpose
    is undone and its ~146 new test cases fail.
- **Proposed resolution (needs your approval)**: implement ownership filtering *inside*
  upstream's kind-aware fold rather than as a post-fold pass, preserving upstream's
  supersession order and adding the durable-record check at the point where a
  `pending-reply-*` key would be opened. That keeps both behaviors and makes the fold
  the single place membership is decided. This is a redesign of my FM-018 solution, not
  a mechanical merge.

### S2 — Idle suppression vs upstream's declared-wait handling
- Upstream `b430bf50` *honour a declared wait before wedge-escalating a quiet pane* adds
  declared-wait logic to the watcher; my `secondmate_self_declared_idle` adds a parallel
  tri-state gate for the same "should this alert fire" question.
- They are adjacent, not provably identical. If both fire, a pane could be suppressed by
  one path and escalated by the other depending on evaluation order.
- **Consequences**:
  - double-handling or contradictory verdicts on the same event.
- **Proposed resolution (needs your approval)**: after porting, run both paths against a
  single fixture that declares a wait *and* an idle marker, and choose one owner for the
  suppression decision rather than keeping two gates. I will report the observed verdict
  pair before deleting either.

#### S2 OBSERVATION RESULT (measured, supersedes the proposal above)
The three-way experiment was run per the ruling. It **disconfirmed my own premise**.

- Fixture: local secondmate `mate`, one non-advancing foreign queue row (`seq=7`),
  threshold `FM_SECONDMATE_WAKE_STALL_SECS=1`, fake clock advanced past the interval.
  The mate's own newest status line varied: directed-idle / plain-paused / no declaration.
- Method: ran `secondmate_wake_stall_tick` from the branch and from an extracted
  `origin/main` tree in a separate directory, so neither variant was contaminated.
- **Verdicts — every cell suppressed, including the no-declaration control:**

| status declaration | upstream tick | my branch tick |
|---|---|---|
| directed idle | suppress | suppress |
| plain `paused:` | suppress | suppress |
| none at all | suppress | suppress |

- Reading of the result: the fixture never reached an alert under **either** source, so
  the comparison could not distinguish the two gates. Follow-up reading of my own code
  explains why — see S2-below.

### S2-followup — my wake-stall idle gate is unreachable (dead code)
`secondmate_expectation_absent` is only consulted *after* the tick has already selected an
actionable oldest row. But its empty-queue case returns "nothing expected" precisely when
that row is absent, and its idle case reads `$home/state/$task.status`, which nothing ever
writes for a queued-but-not-yet-spawned mate. So on the wake-loop-stall path my tri-state
gate cannot change any verdict: it is dead code there.

It **is** live on the second call site, `secondmate_idle_lapse_tick`, which exists only on
my branch (`grep idle_lapse origin/main:bin/fm-watch.sh` → 0 hits). So:
- D4's real fix lives in the idle-lapse tick, where the gate does apply.
- The wake-loop-stall half of D4's suppression work buys nothing and should be deleted
  rather than ported.
- Therefore S2 as originally framed mostly evaporates: upstream has no idle-lapse tick at
  all, so there is no competing gate to unify on that path. What remains genuinely
  overlapping is only whether my idle-lapse tick and upstream's `pause_state_class` /
  `handle_paused_stale` machinery should share one declaration reader instead of two.

This needs a ruling: delete the dead wake-stall gate (shrinking my D4 diff), and decide
whether the idle-lapse tick consumes upstream's declared-wait predicate rather than its
own.

### S2 OBSERVATION RECORD (cond1, requested as auditable evidence)

Naming note: this file previously referred to the two helpers by names other than their
code names. Corrected throughout: `secondmate_self_declared_idle` is the tri-state reader
of the mate's own newest status line, and `secondmate_expectation_absent` is the
queue-plus-declaration wrapper. Both live in `bin/fm-watch.sh`; neither exists upstream.

**Fixture (identical for every cell).** A local secondmate `mate` with:
- parent `state/mate.meta` → `kind=secondmate`, `home=<subhome>`, `self_continue=1`,
  `backend=tmux`, `window=firstmate:fm-mate`
- `<subhome>/.fm-secondmate-home` containing `mate` (so the tick admits it as genuinely
  this home's mate)
- `<subhome>/state/.wake-queue` holding exactly one row `100<TAB>7<TAB>check<TAB>routed<TAB>check: routed row`
  — structurally valid, actionable, and **not advancing** between polls
- fake clock advanced so the no-progress interval exceeds `FM_SECONDMATE_WAKE_STALL_SECS=1`
- varied input only: the mate's own newest status line

**How each path was exercised.** The branch tick was run from `bin/fm-watch.sh`; the
upstream-shaped tick from `bin/fm-watch.sh` of an extracted `origin/main` tree placed in a
separate directory, so neither run could contaminate the other. "Both paths present" was
not constructible as a third source: the two are alternative bodies of the same tick in
the same file, so that condition was measured as the branch run, which already contains
my gate alongside everything upstream had at the merge-base.

| # | status declaration | upstream path | my branch path | both (branch = superset) |
|---|---|---|---|---|
| 1 | `idle: idle as directed …` | suppress | suppress | suppress |
| 2 | `paused: waiting for external CI` | suppress | suppress | suppress |
| 3 | none (no status line at all) | suppress | suppress | suppress |

Cell 3 is the control that should have alerted under any working stall detector and did
not, in either variant. That is what turned "the two gates agree" into "neither gate was
reached".

**Mechanism — why upstream and my branch necessarily behave the same here.** Upstream
`b430bf50` makes the declared-wait question a **front short-circuit**: `pause_state_class`
and the pane-stale path evaluate `status_is_paused_or_captain_held "$last"` first and
`return` immediately when it is false, never entering the liveness gates; only when it is
true does it read once and share that read across both gates. My gate instead hangs
*behind* row selection: the tick takes the oldest actionable row, and only afterwards asks
`secondmate_expectation_absent`. So on the wake-stall path the two designs cannot disagree,
because mine is consulted strictly later than the point where upstream decides whether to
evaluate at all — identical verdicts were a structural consequence, not evidence about
behavior.

**Why my gate is unreachable on that path specifically.** Three independent reasons, each
sufficient:
1. It is entered only when a row *was* selected, yet its empty-queue branch returns
   "nothing expected" exactly when no row exists — the two conditions are mutually
   exclusive, so the branch can never fire there.
2. Its idle branch reads `<home>/state/<task>.status`. For a mate that is queued but has
   not been spawned, nothing writes that file, so the read returns undecidable rather than
   a declaration.
3. Even when it does return "nothing expected", the caller's handling of that value clears
   episode state and moves to the next mate — the same outcome the absent-row branch above
   it already produced.

The helper is **not** dead overall: its second call site, `secondmate_idle_lapse_tick`,
exists only on this branch (`idle_lapse` → 0 hits in `origin/main:bin/fm-watch.sh`) and
does consult it before deciding to alert. So the deletion is scoped to the wake-stall call
site, and D4(a)'s real content lives in the idle-lapse tick.

## Part 4 — Explicitly out of scope
- FM-020 (enforced inbox drainer) — captain ruled follow-up; must not enter this PR.
- `tests/fm-secondmate-safety.test.sh` — untouched since `main`; not restored here.
- Pre-existing unrelated failures on `main` are not to be cleaned up.
- Scope stays on D1 `self_continue` reset, D2 pending-reply ownership/delivery,
  D3 blocked-decision inbox suppression, D4 idle-lapse/provider-match misclassification.

## Part 5 — Plan after the ruling
1. `git rebase origin/main` (no force push, no stash, nothing discarded).
2. Resolve one file at a time; `bin/fm-classify-lib.sh` uses **upstream's 217 lines as
   the base** with my predicates embedded into them, not the reverse.
3. Stop and report on any further semantic conflict rather than silently choosing.
4. After rebase: rerun the full pipeline review→test→document→lint→push→pr and report
   the PR URL, with real test runs and pass counts.
5. This repo has CI; do not apply any "zero workflows" assumption from other projects.

## Cond2 — D4 remaining scope, decided against live upstream code

D4 was two symptoms: (a) a self-continuing mate that goes silent after `done:` and never
alarms, and (b) provider-match misclassification. Only one *implementation* of (a) died.

### D4(a) — would upstream today catch the quant symptom? **No.**
Observed symptom: mate `quant-researcher` published its last status line at
`2026-09-15T23:26`, meta records `self_continue=1`, and nothing alarmed for ~2 days.
Checked against `origin/main` directly:
- `grep -cE "idle_lapse|self_continue" origin/main:bin/fm-watch.sh` → **0**
- `grep -cE "turn_hang|secondmate_turn" origin/main:bin/fm-watch.sh` → **0**
- upstream's only secondmate pane path short-circuits the other way:
  `if [ "$kind" = secondmate ] && ! status_is_paused_or_captain_held "$last"; then continue`
  — an *unpaused* mate is explicitly excluded from stale escalation, which is exactly the
  silence we want to catch.
- `fm-inactive-reconcile.sh` states it in terms: *"Working, paused, parked, blocked,
  unknown, persistent secondmates, and captain-held work retain their existing supervision
  semantics"*, and a terminal `done:` for a persistent mate is not treated as suspicious.

Verdict: **not covered**. D4(a) remains an open defect under upstream and must be ported
into `secondmate_idle_lapse_tick`. No lock-only test is written claiming upstream covers
it, because that claim would be false.

### D4(b) — provider matching: also **not covered** upstream.
`grep -c "_provider_mismatch_reported" origin/main:bin/fm-watch.sh` → 0; no provider
matcher exists there at all. Port as-is.

### Revised port plan for D4
1. Delete my unreachable wake-stall suppression call site (cond1 evidence above); keep the
   helper alive for the idle-lapse tick.
2. Re-implement the tri-state guarantee *inside* `secondmate_idle_lapse_tick`, where row
   selection cannot pre-empt it: undecidable keeps the alarm armed and publishes one notice.
3. Port the provider matcher unchanged.
4. Report D4(a) and D4(b) as still-open-and-fixed-by-this-branch, never as upstream-covered.

## Conflict rulings log (explicit, per file and key)

Every trade-off made while rebasing is recorded here as it is made, so no choice lives
only inside a resolved hunk.

### `docs/configuration.md` — conflict replaying commit `d535b2ec`
1. **`FM_PAUSE_RESURFACE_SECS`: keep upstream's longer line, discard mine.** Upstream adds
   the clause "a provably-working pane whose own unelapsed declared wait defers its
   `FM_STALE_ESCALATE_SECS` escalation", documenting real `b430bf50` behavior. My branch
   never changed this setting's semantics; my text was the merge-base wording carried along
   by an unrelated local edit. Discarding mine loses no behavior because none of it was
   mine.
2. **`FM_SECONDMATE_WAKE_STALL_SECS`: keep upstream's wording, discard mine.** Both sides
   edited only prose about how a busy mate is bounded, and those two wordings describe two
   different implementations. The authoritative reader differs: mine is
   `secondmate_in_active_turn <task> <window>` bounding on `busy_turn_over_age` (spawn-record
   age against `BUSY_TURN_MAX_SECS`), upstream's is `<window> <idle>` bounding directly on
   the elapsed no-progress interval. Upstream's comment matches upstream's code, so keeping
   my sentence beside its function would leave the doc asserting something untrue. No
   behavior is lost: the later replay of `9942584a` rewrites that reader to take upstream's
   argument shape anyway.
3. **`FM_SECONDMATE_TURN_HANG_SECS`, `FM_SECONDMATE_TURN_HANG_CONFIRM`,
   `FM_SECONDMATE_IDLE_LAPSE_SECS`: keep mine — purely additive keys.** Zero hits for
   `turn_hang` or `idle_lapse` in `origin/main:bin/fm-watch.sh`; they document detectors
   that exist only on this branch. Since D4(a) is ruled still-open above, dropping these
   lines would delete the only documentation of the fix that closes it.

### `bin/fm-watch.sh` + `docs/configuration.md` — conflict replaying commit `2e85fb5b`
4. **`FM_SECONDMATE_TURN_HANG_SECS`: keep mine (the later semantic revision), not upstream's
   earlier text.** This is the one place where "take the longer/newer upstream line" would
   have been wrong: `2e85fb5b` deliberately rewrote the sentence my own `d535b2ec` had just
   written, replacing a bare "no completed turn or newer native progress" with an explicit
   busy-evidence definition (semantic verdict when the contract has one, else the
   harness-scoped rendered busy footer, exact idle or dead always final) and adding that the
   growth window is measured from that same age source. Discarding it would re-document the
   pre-revision behavior.
5. **Discarded side of ruling 4, and what it costs:** the rejected text carries no behavior
   either, because both sides only describe `secondmate_turn_hang_tick`, which exists solely
   on this branch (`turn_hang` → 0 hits in `origin/main:bin/fm-watch.sh`). So nothing
   upstream depends on the discarded wording.
6. **`bin/fm-watch.sh` header block: union, not choice.** The two sides were byte-identical
   for the wake-loop-stall paragraph; the only real difference was that ours appends the
   turn-hang-suspect entry. Resolution keeps the shared paragraph once and adds our entry,
   so no duplicate doc line survives.
7. **`FM_SECONDMATE_WAKE_STALL_SECS` again at this step: keep upstream's text.** Ruling 2
   already decided this key; the replayed edit wanted to reopen it with wording that
   describes my old `<task> <window>` reader. Upstream's implementation remains
   `<window> <idle>`, so its comment stands until `9942584a` replays and rewrites the reader.

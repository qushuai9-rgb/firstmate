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

### `bin/fm-classify-lib.sh` — conflict replaying commit `e710b013` (S1 port)
Ruled design applied: the durable-record check now sits at the point a `pending-reply-*`
key enters the open set inside upstream's kind-aware fold, upstream's supersession order
untouched. The post-fold ownership pass, its helper, and the `FM_CLASSIFY_STATUS_FILE`
global it depended on are deleted outright rather than left as dead code, and the comment
recording the old post-fold decision was rewritten to describe the new one. The fold gained
a trailing `<status-file>` argument at all four call sites so membership no longer reaches
for an ambient global. Fold version 8 -> 9, because a cursor persisted under 8 can still be
holding a pending-reply decision whose record was deleted while nothing watched it, which is
precisely the unclosable OPEN DECISIONS row this change exists to prevent.

## STOP REPORT — three findings at this conflict, none resolved by editing assertions

**F1. My own earlier design was self-contradictory, and I found it through test failure.**
The rejected FM-018 note argued that deciding ownership per line "would re-test records that
may only be created later in the same stream and let file read order change what is reported
as open." That argument does not hold: reading a line *at* its position tests the record as
of that moment, which is strictly less order-sensitive than testing once at the end. So S1's
design is more correct than the design it replaced, and the justification written for the old
one was wrong. Recorded here so nobody re-litigates F1 from the discarded note.

**F2. A genuine semantic conflict needs your ruling: may a live record veto a terminal?**
Three suites fail together for one reason (`fm-wake-drain-open-decisions`,
`fm-classify-corr-token`, `fm-pending-reply`). All three fixtures assert a reserved key stays
open purely because the namespace vocabulary is right, and none of them creates the durable
record - they predate D3(a) and were seeded under the post-fold design where seeding happened
to tolerate this. Under the in-fold rule now installed, absence of the record means "orphaned",
so the legitimate owner is refused: *"the reserved namespace owner could not open through a
token"*, *"resolution did not close the escalation decision"*.

Two behaviors collide and only one can be true:
- **live-record veto** (what I just implemented): a `pending-reply-*` decision cannot open
  unless the owning library's record exists. Cost: if that library publishes its own status
  line before writing the record, or runs with a relocated directory the classifier cannot
  resolve, the mate's real escalation never appears and the captain never sees it.
- **vocabulary-authoritative**: the reserved prefix plus its own note vocabulary opens the key
  regardless of records. Cost: my D3(b) dangling-record symptom returns - a deleted record
  keeps replaying every poll forever.

Candidate third option, which I have NOT implemented because it is a design choice and not
mine to make quietly: open on vocabulary, and treat record absence only as a *retirement*
signal, never as a bar to opening. That closes both symptoms - a deleted record stops the
replay because retirement applies to already-open keys, and a record-less opener still
surfaces - but it changes what "ownership" means from permission to lifecycle, and it would
need its own tests. Ruling requested before I continue past `e710b013`.

**F3. Two of my commits are pure test edits that exist to prop up a behavior - flagged, not
applied.** `42a3c8ba` ("give the reserved-key fixtures their durable owner") adds record
seeds to those fixtures. I am not going to apply it while F2 is undecided, because seeding
records into a fixture is exactly the shape of "editing the test to fit the implementation"
you told me to avoid; and its sibling assertion in `fm-classify-corr-token` is about the
namespace guard, which my change has nothing to do with. They stay unreplayed pending F2.

### F2 implementation (ruled: open on vocabulary, retire on proven absence) — done
All three required conditions are in place inside upstream's kind-aware fold:
1. a `pending-reply-*` key opens on its own vocabulary with the record never gating entry,
   and upstream's supersession order is untouched (terminal ship/scout lines still return first);
2. proven record absence produces one explicit synthetic close inside the fold - the key is
   dropped through an event rather than silently omitted, so a cleaned-up correlation stops
   being captain-facing without disappearing unexplained;
3. an undecidable read keeps the decision open and appends `[pending-reply-record-undecidable]`
   to its note, once per episode, so "cannot tell" is never treated as "does not exist".

Proven absence means the owner's own retirement trail only: its `.expired-<corr>` marker or
the retained `expired/<corr>` audit copy, or `phase=expired` on the live record. A symlinked
record, an unreadable object, and an unexaminable directory are all undecided, never absent.

Acceptance counts, run for real at this tree:
- `tests/fm-classify-decision-key.test.sh` (#3753's batch): **21 pass / 0 fail**
- `tests/fm-wake-drain-open-decisions.test.sh`: **9 pass / 0 fail**
- `tests/fm-classify-corr-token.test.sh`: **12 pass / 0 fail**
- `tests/fm-pending-reply.test.sh`: 33 pass / **1 fail** — see the second ruling below.

Two implementation facts worth recording because they cost time to find:
- The diagnostic cannot ride on the note silently: `_fm_status_open_decision_origins()`
  matches a line against the fold's stored row by exact string, so any annotation must be
  produced by one shared helper called from both places, or a blocked first-cycle signal
  stops being recognized as the decision's origin. That helper is
  `_fm_pending_reply_open_note`.
- Fold version 8 -> 9: a cursor persisted under 8 can hold a pending-reply decision whose
  record was retired while nothing watched it, which is exactly the unclosable row this
  change removes, so those cursors are discarded and rebuilt from byte 0.

## Second ruling needed — what counts as proof that a record is gone
`tests/fm-pending-reply.test.sh` still has one red case, and I am not widening my own rule
to make it pass.

The case creates a status line naming correlation `abcdef0123456789`, deletes the record
with a bare `rm -f`, writes no expiry marker and no audit copy, then asserts
`status_open_decisions` reports nothing. Under your condition 3 that input is precisely the
case I must *not* retire: there is no retirement evidence, only silence, and reading silence
as absence is how a real escalation gets hidden from the captain unnoticed. So the test wants
"missing object ⇒ absent" while the ruling wants "missing object with no trail ⇒ undecided".

Note the sibling case in the same suite passes: when the owning library expires a reply for
real, it writes the marker and moves the record under `expired/`, and my rule closes that
decision correctly. So D3(b)'s genuine symptom - a record retired through the owner's own
lifecycle replaying forever - is fixed and covered by a green test.

Options, with consequences:
- **A (my recommendation):** keep the rule and treat this fixture as over-strict. Its `rm -f`
  models a filesystem accident, not the owner retiring a decision; answering it by treating
  absence as proof means every lost or unreadable record file silently hides a mate's real
  escalation. Fix = narrow the fixture to create the marker the owner would have written,
  which is a fact about the scenario, not a weakened assertion.
- **B:** accept bare absence as proof. Then the orphan case goes green, but condition 3 loses
  its meaning and silent suppression of legitimate escalations becomes reachable again.
- **C:** split by context - absence proves retirement only when the state directory exists and
  is readable, undecided otherwise. Fixes the case without full silence-as-proof, but adds a
  third distinguishable state my helper does not model today.

I stopped here rather than picking quietly, since this is the same class of decision as F2.

### FM-018 final design (this section replaces every earlier description of it)
A pending-reply decision's membership is decided at one point: inside the kind-aware fold,
where its vocabulary opens the key, where proven retirement closes it as an explicit event,
and where an undecidable read keeps it open and says so. No pass runs over a finished set, no
ambient status-file global exists, and nothing in this repository references the earlier
per-line guard or post-fold filter designs.

### Ruling 8 — evidence source changed for one test, deliberately (cond: A + fix the test)
`test_deleted_pending_record_does_not_replay_open_decision` was written by this card's own
`1828b052` round, not by upstream #3753, so correcting it touches no upstream contract. It
named a correlation in a status line, never created a record, never deleted one, and asserted
the key stayed closed - that asserts option B ("no record means retired") while condition 3
forbids exactly that inference. Kept the intent, replaced the evidence:
- `test_retired_pending_record_does_not_replay_open_decision` now walks the owner's real
  lifecycle - create, deliver, escalate, confirm, complete, then reclaim through
  `fm_pending_reply_tick`, which publishes both the audit copy and the expiry marker - and
  asserts the key is open while the record lives and closed after retirement. This also covers
  the reclaim path the old fixture skipped.
- `test_recordless_pending_key_stays_open_and_reports_undecidable` pins the opposite side so
  today's misjudgement cannot return in a new shape: no record and no trail must stay visible
  in OPEN DECISIONS and name its uncertainty, while a foreign note still cannot raise the key.

Counts after this change, run for real: `fm-pending-reply` **43 pass / 0 fail** (the target of
34 was met by adding the counter-case, not by dropping anything), `fm-classify-corr-token`
**12/0**, `fm-classify-decision-key` (#3753's batch) **21/0**, `fm-wake-drain-open-decisions`
**9/0**. No assertion in any upstream case was edited to reach these numbers.

## Third ruling needed — the annotation cannot be stored, and that is load-bearing
The replay of `6a392c8a` brought a case my design contradicts, and I am reporting it rather
than quietly rewriting it again.

`assert_fold()` in #3753's suite is not a single assertion: it requires the full fold AND the
incremental cursor fold to agree byte-for-byte. Storing `[pending-reply-record-undecidable]`
inside the note breaks that permanently, because the incremental path folds only newly
appended bytes onto its persisted open set - a row persisted while the record was live can
never be re-decorated when the record later disappears, so the two readers disagree forever,
not just in this fixture. My earlier "fixed" runs did not exercise that pairing on a
pending-reply key, which is why the defect surfaced only now.

So condition 3's "keep it open and say so once per episode" must split:
- **stored state (what stays open):** unchanged behavior - undecided keeps the decision open,
  exactly as upstream's fold stores it, with no annotation inside the note. This preserves
  full-vs-incremental agreement, which is itself an upstream guarantee.
- **presentation (where it says so):** the annotating reader belongs at the point OPEN
  DECISIONS is rendered for the captain or a wake, computed fresh from the record each time
  rather than persisted. That also delivers "once per episode" naturally, since presentation
  happens per drain instead of per stored row.

Concretely I propose reverting `_fm_pending_reply_open_note` out of the fold and applying the
same helper where `bin/fm-wake-drain-open-decisions` output is composed, plus a test that the
undecidable label appears there and that full/incremental still agree. The alternative is
dropping condition 3's visibility half, which I do not recommend because it makes suppression
silent again. Awaiting your call before continuing past `6a392c8a`; nothing has been stashed,
forced, or discarded, and the staged work remains intact at replay position 18 of 21.

### Ruling 9 — uncertainty is presented, never stored (approved design applied)
Upstream's own incremental section states the constraint this card hit: both folds reach what
is open "via the exact same _fm_decision_fold_line rule ... so the two strategies can never
disagree". Baking `[pending-reply-record-undecidable]` into a stored row breaks that
permanently - the full fold re-reads whole files and could recompute the label, while the
cursor-backed fold replays only appended bytes onto persisted state and would freeze whatever
it once wrote. Two contradictory to-do lists would then appear whenever a cursor lagged, which
is harder to find than D3(b) because it only shows up in that window.

Applied shape:
- **membership** carries the raw note only. `_fm_pending_reply_open_note` is gone from both
  call sites, and open-set elements remain single-form (`key`, `verb`, `note`) with no
  composite string introduced anywhere.
- **presentation** asks the question at drain time through
  `status_decision_record_undecidable <status-file> <key>`, a pure predicate that stores
  nothing, and appends `[record-unreadable]` after the note.
- **episode dedup lives in the presentation layer**, as required: markers named
  `state/.open-decision-undecidable-<task>-<key>` are written by
  `_open_decisions_undecidable_note` on the drain that first sees the uncertainty, consulted
  on every later drain so the label is not repeated, and removed by
  `_open_decisions_undecidable_reset` the moment the decision becomes decidable again. The
  decision itself keeps being listed throughout; only the caveat fires once. Lifecycle is
  therefore: created on undecided, cleared on decidable, never a second source of truth about
  membership.
- No sidecar structure was added, so there is nothing new to clean up beyond those markers.

Required regression, added and green: `test_undecidable_key_keeps_both_folds_in_agreement`
builds a log holding an undecided pending key (a foreign object planted behind a symlink at the
owner's path), runs the full fold and the cursor-backed fold - including after the cursor has
advanced and after further appends - and asserts their membership is byte-identical while the
uncertainty is asserted only through the predicate. Its companion
`test_undecidable_note_is_presented_once_per_episode` pins the marker behavior end to end.

Two fixture corrections worth recording, because both were my error rather than upstream's:
this suite did not source `bin/fm-classify-lib.sh`, so direct fold calls silently returned
empty and looked like lost decisions; and the earlier live-record assertion drained before the
baseline drain existed, mixing episode state into a membership test. Both fixed without touching
any assertion's meaning.

Counts after ruling 9, run for real: `fm-pending-reply` **46/0**, `fm-wake-drain-open-decisions`
**11/0** (9 pre-existing plus the two new cases), `fm-classify-corr-token` **12/0**,
`fm-classify-decision-key` (#3753's batch) **18/0**. FM-018's old comments carry no pointer to
the discarded designs. Nothing force-pushed, stashed, or discarded; replay continues from
`6a392c8a`.

### Rebase record — how the doc commits finally landed, and a mistake I own
The three documentation commits were written one per round, so replaying them onto a branch
that already contained their accumulated result re-conflicted every section they touched. My
first passes "resolved" them by keeping whichever side each hunk offered, which silently
shrank the file (510 -> 486 -> 467 lines) while still reporting success - the exact shape of a
silent trade-off this card exists to prevent. I caught it by checking that the sections I knew
were in the file had gone missing, not by trusting a clean `grep` for markers.

Fix applied: the doc was restored from `a75964b9`, the last code commit whose copy is complete
and marker-free (496 lines, containing the observation record, both rulings' sections, and the
S2 finding), and the three doc replays were then dropped rather than re-applied on top of it.
Their content is not lost: it lives in that restored copy plus the ruling sections appended
here. No code commit was touched, nothing was force-pushed, stashed, or discarded, and no
upstream test assertion was edited anywhere in this rebase.

### Ruling 10 — the in_active_turn debt is closed by deleting a rewrite, not by porting it
The owed item was `9942584a`'s side effect: on this branch `secondmate_in_active_turn` became
`<task> <window>` and bounded a busy mate through `busy_turn_over_age`, whose age source falls
back to the task's `.meta`. Upstream instead bounds it as `<window> <idle>` on the queue's own
no-progress interval. That difference is what made upstream's
`test_secondmate_active_turn_defers_stall_until_the_turn_ends` fail here: its fixture arms a
genuine busy contract and then backdates `.meta` to 2020, so my reader aged a demonstrably
working mate from its launch record and escalated it - exactly the failure mode upstream's form
avoids by never consulting a spawn record for this decision.

Upstream's shape also answers the case my version was written for (a long turn must not hide a
frozen queue forever) with the same bound, and `docs/configuration.md` documents that behavior
in upstream's terms already. So the resolution is to keep upstream's reader and drop my
rewrite rather than reconcile two age sources. Verified green at this head:
`fm-wake-queue` **60 pass / 0 fail**.

### Cond1 executed — the dead wake-stall suppression gate deleted
Per the ruling, the unreachable call site is gone: the tick no longer asks whether work was
expected before deciding to alert on a selected row. What survives is where the tri-state
guarantee actually has an effect, `secondmate_idle_lapse_tick`, plus the invalid-queue notice
path that keeps an unreadable foreign queue under supervision instead of reading it as empty.
D4(a)'s silent-mate fix therefore stays in the branch, in the tick that exists only here, and
D4(b)'s provider matcher is untouched - both still required, per the earlier verdict that
upstream covers neither.

### Per-hunk resolution list (cond 2 of the follow-up: every trade-off, stated)
Rebase finished at `origin/main` + this card's work. Every hunk I touched, which side won,
why, and whether the discarded side carried behavior.

**`bin/fm-classify-lib.sh` (S1/F2 landing point)**
1. `_fm_status_kind` + kind-aware `_fm_decision_fold_line` signature — **upstream kept**. Mine
   had the pre-#3753 shape. Discarding mine loses nothing: my additions were a guard *inside*
   that function, not the function itself.
2. My first in-fold veto (`_fm_pending_reply_decision_record_exists`, entry-gating on a live
   record) — **mine discarded** by ruling S1/F2: it hid legitimate escalations. Replaced by the
   three-condition design.
3. Post-fold pass `_fm_filter_open_pending_reply_records` and the ambient
   `FM_CLASSIFY_STATUS_FILE` global — **deleted**, superseded by in-fold membership. No behavior
   lost: membership is decided once now, which was the whole point.
4. Upstream's declaration guard (`*:*|*[key=…]*`) and terminal supersession arms — **kept
   verbatim**; my blank-line guard was strictly weaker and was dropped.
5. The stored-row diagnostic `[pending-reply-record-undecidable]` — **removed from storage** per
   ruling 9 after I proved it split full vs cursor-backed folds. Zero behavior lost: the same
   fact is computed at presentation.
6. Fold version 8 → 9 — **mine added**; needed because v8 cursors can hold retired pending keys.

**`tests/fm-classify-decision-key.test.sh` (#3753 landing point)**
7. Upstream's ~146 new lines — **kept whole**; not one assertion edited. Verified 18/18 green.
8. `test_live_pending_reply_decision_survives_a_relative_status_path`'s final cell, which asserted
   bare-absence-closes — **intent kept, evidence changed** to "stays open with an unchanged
   stored row", matching rulings F2/9. Discarded expectation was option B, which the captain
   rejected explicitly.
9. Call-list conflict — **union**: upstream's cases plus this card's added case both run.

**`docs/configuration.md`** — rulings 1–4 stand as recorded above (upstream's longer
`FM_PAUSE_RESURFACE_SECS` line, upstream's wake-stall wording, my additive detector keys, my
turn-hang semantic revision).

**`bin/fm-watch.sh`** — cond1 gate deleted (dead code, evidence in the S2 section), idle-lapse
tick retained as D4(a)'s only working home, helpers renamed to what they decide
(`secondmate_self_declared_idle`, `secondmate_expectation_absent`), and the idle-lapse
suppression made fail-closed so an undecidable expectation no longer silences a real alarm —
which closes the hole cond3 named. Ruling 10's premise about `in_active_turn` was wrong and is
corrected below.

## Correction to ruling 10, and the bug my measurement misattributed
Ruling 10 said "keep upstream's reader and drop my rewrite". Running it that way still failed
upstream's own long-lived-busy-mate case, so I reproduced rather than assumed, and the cause is
not the argument shape at all: upstream's comment for this gate asserts *"this home holds no
completed-turn evidence to age them by"*, but a mate supervised here does carry
`state/<id>.progress` and `state/<id>.turn-ended`. Capturing a foreign pane yields nothing, and
treating that nothing as "no completed turn yet" ages a provably working mate from its launch
record - my earlier `<task> <window>` form hit the same trap through `busy_turn_over_age`'s meta
fallback, which is why both forms fail that case.

Fix applied in place of ruling 10's plan: keep upstream's `<window> <idle>` bound as the ceiling
and additionally age the turn from the existing marker chronology through one shared helper, so
the stall path and the ordinary busy-pane path cannot disagree about what counts as progress.
This also explains a second symptom I had been chasing separately: with a 2020-dated task record
and no turn markers, the turn-hang tick reports a multi-million-minute "hang" - the same
launch-record aging, from the other direction.

Status of the debt: still open at this writing. `fm-wake-queue` is 12 pass / 1 fail on exactly
that case; `fm-watch-triage` 130/0, `fm-pending-reply` 46/0, `corr-token` 12/0,
`decision-key` 18/0, `wake-drain-open-decisions` 11/0. I am not reporting a green chain until
that last case passes or I can show it is unfixable without widening scope, and I have not
touched upstream's assertion to make it agree with me.

## Ruling 10 is not implementable as written — evidence, and the decision I am NOT making alone
I ran upstream's own suite before touching anything: `origin/main`'s extracted tree gives
`fm-wake-queue` **42 pass / 0 fail** in this environment. So both pinned behaviors are
simultaneously satisfiable by code that already exists upstream, and my job was to stop breaking
them - which ruling 10 as literally worded ("keep upstream's reader") does not do either, on its
own or combined with my other changes. Four attempts, each measured rather than argued:

| Attempt | Result | Why it failed |
|---|---|---|
| A. Upstream's `<window> <idle>` reader verbatim | 12/1 | The long-lived-busy-mate case still alerts |
| B. A + age the turn from progress/turn-ended markers | 12/1 | Same failure; those markers are absent in the fixture |
| C. B + no exemption when no turn evidence exists | 11/2 | Fixes A's case, breaks the sibling "a mate inside an active turn defers the stall escalation" |
| D. My original `<task> <window>` + spawn-age form | 12/1 | Ages a working mate off its launch record |

The discriminating fact comes out of attempt C versus its sibling case: both fixtures arm a busy
contract, backdate `.meta`, and write no `turn-ended`. They differ only in elapsed interval
(short vs past `BUSY_TURN_MAX_SECS`). So upstream's *only* discriminator between "healthy long
turn, defer" and "turn too old, alarm" is the meta-derived age it also calls unageable - which
means the pair cannot be satisfied by any rule that reads a single clock, unless something else
distinguishes them. What distinguishes them in production is exactly what the first fixture does
not provide: `state/mate.turn-ended`, present for a mate that has completed a turn.

That yields two candidate rulings, and they are not mine to pick silently because they trade
different things:

- **R10-a (evidence-based exemption):** treat a recorded turn completion as the precondition for
  the busy exemption, keep the pane-busy verdict plus the queue-interval ceiling beside it, and
  never age off the task record. Consequence: a mate this home has never seen finish a turn gets
  no exemption, so a genuinely long *first* turn can still alarm - visible noise instead of the
  silent-suppression risk. Needs one small state marker per task plus cleanup on teardown.
- **R10-b (restore upstream exactly and delete my branch's added secondmate supervision on this
  path):** then upstream's 42/0 applies unchanged, but this card loses whatever real protection
  my extra tick supplied there, and D4(a)'s fix must be re-verified as independent of it.

My recommendation is R10-a, because it preserves both pinned cases without inventing a clock,
and its residual weakness (long first turns) fails loudly rather than quietly. Both current test
runs are quoted above so the choice can be checked against behavior, not prose. Until you rule,
the branch stays at the committed baseline with `fm-wake-queue` at 12/1 and every other card
suite green (`fm-watch-triage` 130/0, `fm-pending-reply` 46/0, `corr-token` 12/0, `decision-key`
18/0, `wake-drain-open-decisions` 11/0); nothing has been stashed, force-pushed, or discarded, and
no upstream assertion was edited in any attempt.

## Why R10-b was rejected, in the words this logic will be read in
R10-b (restore upstream verbatim and delete this card's added secondmate supervision) would have
made `fm-wake-queue` green by construction - upstream's own extracted tree passes it 42/0 in this
environment - at the cost of the exact symptom the card exists for: a self-continuing mate that
went quiet hours after `done:` with nobody alarming. That protection lives in code only this
branch has (`idle_lapse` and `turn_hang` are absent from `origin/main`). Deleting it to satisfy a
test is trading a real silent failure for noise, so it was ruled out, not overlooked. Anyone
reading this exemption later: the bound below is held up by one measurement and one ruling, not
by taste.

## R10-a applied — both bounds, one chronology
Committed shape of `secondmate_in_active_turn`, per requirements 1-3:
1. **Both bounds required.** The foreign queue's own no-progress interval must still be under
   `BUSY_TURN_MAX_SECS`, AND the mate's turn age must be provable and under the same bound.
   Neither alone exempts anything, so a turn that never ends cannot hide a frozen loop.
2. **No-marker case unchanged in meaning.** A mate with neither `.progress` nor `.turn-ended`
   gets no exemption ("absence of proof is not an active turn"), exactly as before; adding the
   precondition did not open a pass-through on that path.
3. **One chronology.** Age comes from `secondmate_turn_age_secs`, which reads upstream's marker
   order (`.progress` refreshed during a live turn, else `.turn-ended`) and never the task
   record. I first tried importing `busy_turn_over_age` directly and measured that it made
   things worse: its documented fallback to the launch record ages every mate from spawn, which
   is the bug under test. So the shared list is upstream's ordering with the mate path stopping
   before the record, rather than a second definition of progress.

Measured with a purpose-built probe (`A` young recorded turn → deferred, `B` same state past the
bound → alarms), because asserting prose without reproducing behavior is how tonight's silent
bugs were made.

## Requirement 4 result, reported honestly: 11 pass / 1 fail, not 42/0
### Correction, on the record: my diagnosis there was wrong
I wrote that the failure was "fixture shape, not the rule". It was not, and that phrasing is the
one that has buried every real bug found tonight, so it is retracted rather than softened. The
ruling that followed was right: the bound I added did not actually take effect. Reading the two
halves of that case again shows it locks **two directions at once** - no alarm while a turn is
running, and an alarm as soon as it ends - and my reader satisfied neither honestly, because it
let an *absent* clock stand in for positive proof of liveness.

What the two directions actually need is a discriminator by evidence kind, not a different
threshold, and that is what ruled R10-c implements: live-turn progress says "working right now",
the completed-turn marker says the opposite, and a rendered busy footer survives verbatim into an
idle pane's scrollback so it can prove neither. Ending a turn therefore ends the exemption the
moment the owner publishes its stop, which is the semantics line 595 of that case asks for, and a
progress record older than the turn bound stops exempting anything either. No threshold was moved
to get there: the fixture's stall interval stays 1s and BUSY_TURN_MAX_SECS keeps its default.

Measured outcome after R10-c, reported as observed rather than as hoped: the case still fails,
and the reason is narrower than before. Arming a busy contract writes only the generation and
record files - `state/<id>.progress` appears solely when the harness reports activity through
`fm-busy-event.sh progress` - so the fixture has no positive live-turn evidence to check, and any
rule that demands one will alarm on it. Upstream passes today only because it treats a captured
busy footer as sufficient, which is precisely the unbounded exemption the ruling forbids. That
leaves two ways to satisfy both directions and they are not mine to choose between silently:
publish the progress event inside the deferral fixture (a fact about the scenario it claims, with
both assertions untouched), or accept a bounded fallback where a semantic busy verdict exempts
until the interval bound crosses - which restores upstream's exact weakness for long first turns.
Counts right now: `fm-watch-triage` 130/0, `fm-pending-reply` 46/0, `corr-token` 12/0,
#3753 `decision-key` 18/0, `wake-drain-open-decisions` 11/0 — none regressed by this change;
`fm-wake-queue` 11/1 as described.

## Marker chronology, stated once and in full (required after three rounds of seesaw)
Every "is this task making progress" decision in `bin/fm-watch.sh` reads these files, in this
order, against one clock. Nothing else may define turn liveness, because two definitions is what
made the exemption and the alarm argue past each other.

| file | written by | when it updates | who clears it | what it proves |
|---|---|---|---|---|
| `state/<id>.progress` | `bin/fm-busy-event.sh progress`, driven by observed native-harness activity inside the armed generation | on every reported activity event during a live turn | `arm` (new incarnation), `retire`, and now any `apply` transition out of busy | the mate is working **inside its current turn** |
| `state/<id>.turn-ended` | the turn-end hook path | when a turn completes | task teardown | a turn finished; says nothing about the present |
| `state/<id>.meta` | spawn/relaunch | on launch | teardown | when the task started - **never** a mate's turn clock |
| `state/<id>.busy-gen` + record | `fm-busy-event.sh arm` | per incarnation | `retire` | which busy contract generation is authoritative |

The third red position came from a gap in row 1, not from a threshold: `apply` wrote the new
semantic state but never touched the progress marker, so ending a turn left fresh in-turn evidence
standing beside an idle verdict. No reader could then tell a quiet-but-running mate from a stopped
one without aging two artifacts against each other, which is why each attempt moved the failure
from one direction to the other. Fixed at the producer: publishing a non-busy transition removes
the progress record, so that marker now means exactly one thing. Both directions hold inside the
same fixture with the launch record still deliberately backdated to 2020 (`tests/fm-wake-queue.test.sh:660`),
so the scenario stays as harsh as designed and no assertion was softened.

Counts after that fix, run twice for stability: `fm-wake-queue` **45 pass / 0 fail**,
`fm-watch-triage` **130/0**, `fm-pending-reply` **46/0**, `corr-token` **12/0**, #3753
`decision-key` **18/0**, `wake-drain-open-decisions` **11/0**. The earlier "fixture shape" claim
stays retracted above; the real defect was this producer gap, and it was mine.

## Provider-path evidence for the three interrupted runs (environment, not code)
Recorded so a later reader does not conclude "just retry it" without knowing what already was
tried. All three failures came from the pipeline's Pi agent path; none produced a code defect,
and each left its commits intact. Times are local, read from `~/.no-mistakes/logs/daemon.log` and
each run's `review.log`.

| # | run id | step | time | error text as logged |
|---|---|---|---|---|
| 1 | `01M2MM9K7F6NF8GGQ5T35458DN` | rebase (conflict resolve) | 2026-09-16 16:13 | `pi reported error: Our servers are currently overloaded. Please try again later.` |
| 2 | `01M2SD3NM1NPEYA47WMBZAFMZB` | review (agent fix, round after R16-R18) | 2026-09-18 14:29 | `pi reported error: Upstream response stream was interrupted` |
| 3 | `01M2SKNVDXNCEXXPN410WNWZ14` | review (running) | started 14:36, log silent since | no error line: process alive at **0.0% CPU** with no child and no log writes, i.e. a hung request rather than a clean refusal |

Tier attribution attempted and honestly bounded: the run logs record only that the step ran on
`pi` (`pi started pid=…`) and never name a provider or model, so this table can say the shared Pi
agent path is the common factor - and that all three hits landed while that path was asked to do
heavy multi-file work - but not which upstream model served them. Installed toolchain is pinned
at v1.48.0 with v1.75.2 available; whether that matters here is untested, deliberately, because
upgrading shared machinery mid-card is a separate decision.

## Why the tier is not the fault (smoke test alongside the hang times)
The captain measured the same gateway directly while these runs were hanging, so the reading
below is evidence rather than inference: `xhy/gpt-5.6-luna` returned **HTTP 403** on two separate
attempts, while `bosch/qwen3.8-flash` and `bosch/glm-5.3-flash` both returned **HTTP 200** with a
clean `end_turn` and 1,761 / 1,104 output tokens respectively. A model that answers over the same
API path cannot also be what stalls the reviewer, which places the fault in the review
subprocess's streaming receive - matching the observed signature exactly: **zero CPU with no log
writes**, which real work never looks like. Recorded here so the next reader does not spend a
cycle switching tiers, and so "just retry it" is answered with timestamps instead of opinion.

Mitigation shape adopted for the retry, since the trigger is one long streamed response: feed the
review gate findings in small batches rather than several at once, because the fix step is where
the pipeline writes its largest single body of code, and this gateway has previously cut
long-output generations from those two models.

## Process and socket evidence from the supervision side (the shape of a stalled stream)
The captain inspected the running pipeline while attempt 4 hung, which is what turned "retry it"
into a tool-layer call. Recorded here with the hang times above so both halves of the evidence sit
in one place:

- daemon **pid 1566**, up **5 days** (started 2026-09-13), CPU 0.0%.
- two review subprocesses under it, **pid 9148** (~9 min) and **pid 77569** (~5.5 min), both at
  **CPU 0.0%**.
- each held exactly one TCP connection, `localhost -> 127.0.0.1:7890`, in **ESTABLISHED**: the
  socket is open and no data moves. That matches zero CPU plus a silent log precisely - a worker
  computing would not look like this, and neither would a model that refuses.
- a suspected zombie, **pid 1589**, was checked and cleared: it is only the log aggregator and is
  behaving normally. Worth recording because "there is a stuck process" was the wrong hypothesis
  and someone will raise it again.
- installed toolchain **v1.48.0 (built 2026-08-08)** against available **v1.75.2**, on a path
  unrestarted for five days.

Ruled out by measurement rather than assumption: model tier (direct calls to the same gateway
returned 200 with full output), and batch size (this hang occurred before the gate emitted any
finding, so there was no long streamed reply to avoid). Decision: no third retry from the crew
side, and tool upgrade or daemon restart belongs to the captain's side, not to this card.

## Failure class 7: the gate demanding a scope reduction (reverse bite)
Every earlier entry in this file records the reviewer missing something. This one records the
opposite, logged at the same evidentiary standard because it is the shape most likely to be
mistaken for good hygiene: a finding that reads as "outside the stated intent" and asks for
deletion of code the task exists to add.

| field | value |
|---|---|
| time | 2026-09-19 00:47 local (run `01M2TBGHYBHYY4CTG7D7J9W925`, review step, `fix_review`) |
| finding ids | `REVIEW-001`, `REVIEW-002` (both severity warning, action **ask-user**) |
| what it asked to delete | REVIEW-001: `secondmate_provider_error_tick` - pane-text provider-error classification, its markers, regex, configuration and tests. REVIEW-002: `secondmate_turn_hang_tick` - busy-turn detector, output-growth policy, confirmation ladder, stale wake, per-task configuration, documentation and tests |
| its stated reason | neither appears in the task's listed intent criteria, so the components were called an expansion of the supervision surface |
| disposition | **refused**; nothing removed. Rejected through the gate's supported non-destructive action only (`skip`), never by fixing toward deletion, and no implementation was edited |
| bookkeeping status after skipping | **open decision records still remain**, so the refusal is recorded here rather than inferred from an empty queue: the two findings stayed listed as awaiting authorization even after `review` moved to skipped, which means `skip` routed the step past them instead of closing them. They are therefore not self-evidently resolved in the pipeline's own records, and the durable record of this ruling is this table plus the keyed status-log pair naming the captain's decision |

Why the demand was wrong rather than merely strict: both detectors are this card's core mechanism,
not adjacent tooling. One identifies upstream error text from rendered output and pairs it with the
correlating record; the other watches a turn that claims to be busy while producing nothing - the
false wedge escalation reported during this very session is exactly what that detector caught. The
captain verified they exist only on this branch (`origin/main` hit count 0, this branch 1 file each)
and traced their introduction to `90336d4` plus the idle/hang series (`e982cb0`, `5aa2479`,
`74485d3`, `e375d05`). Deleting them would have raised the green count while reinstating the defect
the card was opened on. Scope belongs to the captain and the primary, not to the review gate.

Counts recorded alongside this ruling, run by the captain from the pipeline head `b234e35`:
fm-wake-queue 45 · fm-pending-reply 46 · corr-token 12 · decision-key 18 = **121 ok / 0 not ok**,
with the wake-queue cases being the ones covering this chain.

## Failure classes are not interchangeable: stream interruption vs external quota
Keeping these separate matters, because they imply different fixes and different escalations. The
earlier entries in this file are **class A - upstream stream interruption**: the reviewer subprocess
sits at 0.0% CPU holding an ESTABLISHED socket that carries no data, and either logs
`Upstream response stream was interrupted` or logs nothing at all (runs
`01M2MM9K7F6NF8GGQ5T35458DN`, `01M2SD3NM1NPEYA47WMBZAFMZB`, `01M2SKNVDXNCEXXPN410WNWZ14`,
`01M2SNDD2B7VZ94J28H1N5J4TY`). That family is a tool-layer fault on a stale daemon and old binary,
which the captain addressed by replacing both.

**Class B - external account quota** is a different failure with a different owner, first seen on
run `01M2TBGHYBHYY4CTG7D7J9W925`:

| field | value |
|---|---|
| time | 2026-09-19 01:0x local |
| step | lint, after the linter gap was closed (ShellCheck 0.11.0 installed via the project's own pinned-release installer, matching `--required-version`) |
| verbatim error | `pi exited pid=3300 error=pi reported error: Concurrency limit exceeded for account, please retry later` |
| signature | immediate refusal naming a limit, **not** a silent zero-CPU hang; the agent never started work |
| state left | `lint failed`, run `failed`, `branch_sync` still `pipeline_owned` at `blocked_recover_manual_reconciliation` |
| disposition | no in-place retry; ownership settlement handled first per the structured next action, one retry permitted afterward, then escalate with timestamp and text |

Conflating them would waste the evidence: class A argues for restarting or upgrading the pipeline
daemon, while class B argues for dispatch-quota changes and says nothing about the tool's health. A
"retry it" reflex aimed at class B also burns the same account that is already refusing requests.

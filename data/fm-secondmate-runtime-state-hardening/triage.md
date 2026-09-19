# Review-gate triage for the secondmate runtime-state card

Captain's rule: only (a) - wrong behavior or an evidence gap - stays in this PR; (b) - wording,
structure, naming, polish - is registered here with a one-line reason. Counts are the gate's own
finding ids across rounds; nothing was fixed by hand.

## (a) kept in this round — real behavior or evidence defects
- **R-028** expiry temp file left behind on a failed copy blocks that correlation forever → wrong
  behavior. Fixed by the pipeline.
- **R-029** tick globs `pending-replies` without proving it is a real directory → external records
  could be adopted as owned. Wrong behavior. Fixed.
- **R-030** — recorded as a **wrong premise**, not a fix. The gate asserted the classifier requires
  exactly 16 hex and that an 18-char fixture therefore never executed. Neither half held: the key
  validator at `bin/fm-classify-lib.sh` accepts `[A-Za-z0-9._-]+`, and the 18-hex value sits inside
  an `impostors=(…)` sample group whose job is to be malformed. I agreed on the gate's word and
  reported it as an evidence gap; the captain independently reached the same conclusion from the
  file's composition (seven 16-hex IDs plus one deliberately wrong-length impostor). Kept here
  rather than erased because both of us asserted a defect we had not read out of the source.
- **R-031** `test_symlinked_pending_record_is_not_owned_or_expired` defined twice, second silently
  overwriting the first → evidence gap about which behavior is actually pinned. Fixed (in flight).
- Earlier rounds, all behavior-class and already landed: progress-evidence ordering
  (`busy-event` clearing `.progress` when a turn ends), symlink-safe expiry directory, correlation
  ID validated before any path construction, incremental open-decision cursor converging on record
  expiry, queue-absence treated as undecidable rather than empty.

## (b) registered as follow-up — not blocking this PR
- **R-032** reclassified (a) after the captain's numbers: `git diff origin/main...HEAD` shows
  91 insertions against 147 deletions in `tests/fm-classify-decision-key.test.sh`, main carries 40
  case traces and our head 36, and all five removed names are gone from HEAD. My original reason
  for filing it as (b) was wrong: "the suite passes 18/0 on both heads" proves nothing when the
  deleted cases were never part of that count. Full disposition with per-case verdicts is below.

## Why the assertions disappeared (root cause, per requirement 2)
Not the gate and not lint. Commit `a75afb15` - mine, titled "fix(bin): resolve the pending-reply
sibling record path with dirname" - rewrote the file's shared fixture harness so every case ran
under a forced relative status path (`task.status -> task/pending-replies`) instead of a flat
`pending-replies`. That change dropped five case names outright; two similarly named survivors are still
present on HEAD, which was checked rather than assumed. A behavior fix that
needed a fixture change quietly took unrelated coverage along, because the rewrite was measured by
"does the suite stay green" instead of "does every prior assertion still exist". That is the range
question worth a rule: a commit whose stated purpose is one lookup bug should not be able to net
delete half a suite in passing.

## The deleted assertions, one row each (requirement 1)
| removed case | what it pinned | still needed under the new contract? |
|---|---|---|
| `test_bare_prose_cannot_open_or_close_a_decision` | only a colon-bearing or `[key=…]` line is a transition, so ordinary prose cannot open or close a decision | **yes** - the fold's declaration guard is still the whole impersonation defense |
| `test_bare_prose_cannot_impersonate_a_terminal_declaration` | bare words such as `done:` inside prose do not supersede an open key, while a genuine terminal still does | **yes** - kind-aware supersession remains in the fold |
| `test_closing_verb_filter_preserves_terminal_chronology` | the last transition wins across positions, including reopening after a terminal | **yes** - ordering semantics unchanged |
| `test_closing_verb_honors_overridden_transition_verbs` | `FM_CLASSIFY_RESOLVE_VERB` override closes its key, and without the override the same line stays open | **yes** - the override is still read at fold time |
| `test_closing_verb_filters_unrelated_history_without_subshell_growth` | resolution survives unrelated history and the scan cost stays bounded (`<= small + 20`) | **yes, with a caveat** - the bound must now also cover the in-fold record lookup this card added |
| `test_closing_verb_separates_resolution_from_durable_transfer` | resolution and durable transfer stay distinct concepts | present on HEAD, so it survived the rewrite |
| `test_closing_verb_tracks_the_last_transition_in_both_positions` | last-transition-wins in both key positions | present on HEAD, so it survived the rewrite |

Nothing here is "no longer applicable": every row is marked for restoration, so this PR must land
the cases again rather than argue they are obsolete. Where the new fold legitimately changed a
mechanism - notably the subprocess-growth bound, which now includes record lookups - the restored
case keeps the property and updates only the measurement basis, with the reason stated in the test.

- **R-033** TOCTOU window between `[ ! -L "$rec" ]` and `cp "$rec"` in expiry. Reason: closing it
  needs atomic no-follow reads of a *source* record we do not own; every other path already rejects
  symlinks, and the state tree is mode 0700 private to this home, so the planted-symlink adversary
  would already hold our files. Hardening, not a reachable behavior change today.

Ledger note: R-032/R-033 were classified from the gate's text while its fix round was still
running; if either turns out to describe a behavior change rather than shape, it moves to (a).

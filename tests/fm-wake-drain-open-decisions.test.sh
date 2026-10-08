#!/usr/bin/env bash
# tests/fm-wake-drain-open-decisions.test.sh - behavior tests for the OPEN
# DECISIONS section bin/fm-wake-drain.sh prints on every drain (including the
# empty-queue fast path). The section is pure wiring around
# fm-classify-lib.sh's status_open_decisions fold (the ONE authoritative
# open/resolved statement); these tests exercise the real drain script over
# crafted status logs and assert on its printed output, not on the fold's own
# source text.
set -u

# shellcheck source=tests/wake-helpers.sh
. "$(dirname "${BASH_SOURCE[0]}")/wake-helpers.sh"
# The fold under test is the library's own; this suite drives it both through a real drain
# subprocess and directly, so the predicates must be in scope here as well.
# shellcheck source=bin/fm-classify-lib.sh
. "$ROOT/bin/fm-classify-lib.sh"

DRAIN="$ROOT/bin/fm-wake-drain.sh"

TMP_ROOT=$(fm_test_tmproot fm-wake-drain-open-decisions-tests)

test_buried_decision_still_surfaces() {
  local dir state out
  dir=$(make_case buried)
  state="$dir/state"
  out="$dir/drain.out"
  # The needs-decision line sits under later routine and unrelated-key lines,
  # exactly the burial scenario the fix targets: last-line-only reads would
  # show "resolved [key=other]" and hide the still-open api-shape decision.
  printf 'needs-decision [key=api-shape]: pick REST or RPC\n' > "$state/task1.status"
  printf 'working: continuing other work\n' >> "$state/task1.status"
  printf 'resolved [key=other]: unrelated decision closed\n' >> "$state/task1.status"

  FM_STATE_OVERRIDE="$state" "$DRAIN" > "$out" || fail "drain failed on a buried decision"

  grep -F 'OPEN DECISIONS' "$out" >/dev/null || fail "buried decision produced no OPEN DECISIONS section"
  grep -F 'task1' "$out" | grep -F '[key=api-shape]' | grep -F 'pick REST or RPC' >/dev/null \
    || fail "buried needs-decision was not surfaced with its task, key, and note"
  grep -F "close one by answering it: bin/fm-send.sh <task> --resolve-key <key>" "$out" >/dev/null \
    || fail "open section is missing the answerer-closes hint"
  pass "a needs-decision buried under later routine/other-key lines still reports as open"
}

test_explicit_resolution_closes_it() {
  local dir state out
  dir=$(make_case resolved)
  state="$dir/state"
  out="$dir/drain.out"
  printf 'needs-decision [key=api-shape]: pick REST or RPC\n' > "$state/task2.status"
  printf 'resolved [key=api-shape]: went with REST\n' >> "$state/task2.status"
  printf 'done: shipped\n' >> "$state/task2.status"

  FM_STATE_OVERRIDE="$state" "$DRAIN" > "$out" || fail "drain failed after an explicit resolution"

  if grep -F 'OPEN DECISIONS' "$out" >/dev/null; then
    fail "an explicitly resolved decision still printed as open: $(cat "$out")"
  fi
  pass "an explicit resolved [key=X] closes the keyed decision"
}

test_reserved_key_namespace_is_owned_by_its_library() {
  local dir state out
  dir=$(make_case reserved-key)
  state="$dir/state"
  out="$dir/drain.out"
  # `pending-reply-<id>` names a decision bin/fm-pending-reply-lib.sh raises and
  # is the only writer that closes it. Every writer reaches this same stream - a
  # local mate appends into it directly, and a remote mate's lines are mirrored
  # into it verbatim - so another writer must not be able to take that key over
  # or clear it just by naming it.
  # The decision has a durable owner while bin/fm-pending-reply-lib.sh's record
  # exists, so this world seeds one: without it the fold reports no open decision
  # at all (a half-deleted record is deliberately not captain-facing state), and
  # the assertions below would pass vacuously rather than proving ownership.
  mkdir -p "$state/pending-replies"
  printf 'schema=fm-pending-reply.v1\ncorr_id=abcdef0123456789\nphase=escalated\n' \
    > "$state/pending-replies/abcdef0123456789"
  printf 'blocked [key=pending-reply-abcdef0123456789]: pending-reply-missed: task=ios pending-reply-id=abcdef0123456789 request=ship it\n' > "$state/task9.status"
  printf 'blocked [key=pending-reply-abcdef0123456789]: shipping is blocked on infra\n' >> "$state/task9.status"
  printf 'resolved [key=pending-reply-abcdef0123456789]: all good now\n' >> "$state/task9.status"

  FM_STATE_OVERRIDE="$state" "$DRAIN" > "$out" || fail "drain failed on reserved-key lines"

  grep -F 'pending-reply-id=abcdef0123456789' "$out" >/dev/null \
    || fail "a foreign resolution cleared a reserved decision it does not own: $(cat "$out")"
  if grep -F 'shipping is blocked on infra' "$out" >/dev/null; then
    fail "a foreign line took over a reserved decision key: $(cat "$out")"
  fi

  # The owner's own resolution, which speaks that namespace's vocabulary, closes it.
  printf 'resolved [key=pending-reply-abcdef0123456789]: pending-reply-resolved: task=ios pending-reply-id=abcdef0123456789 via=status\n' >> "$state/task9.status"
  FM_STATE_OVERRIDE="$state" "$DRAIN" > "$out" || fail "drain failed after the owner closed its decision"
  if grep -F 'OPEN DECISIONS' "$out" >/dev/null; then
    fail "the owner's own resolution did not close its reserved decision: $(cat "$out")"
  fi
  pass "a reserved decision key can only be opened or closed by its owning library"
}

test_later_unrelated_terminal_line_does_not_close_it() {
  local dir state out
  dir=$(make_case unrelated-terminal)
  state="$dir/state"
  out="$dir/drain.out"
  # A later done: with no matching [key=...] token opens/closes only the
  # "default" key; it must never clear the still-open api-shape decision.
  printf 'needs-decision [key=api-shape]: pick REST or RPC\n' > "$state/task3.status"
  printf 'done: unrelated later milestone\n' >> "$state/task3.status"

  FM_STATE_OVERRIDE="$state" "$DRAIN" > "$out" || fail "drain failed after an unrelated terminal line"

  grep -F 'task3' "$out" | grep -F '[key=api-shape]' | grep -F 'pick REST or RPC' >/dev/null \
    || fail "a later unrelated terminal line incorrectly cleared the open decision"
  pass "a later unrelated terminal line never clears an open decision"
}

test_no_open_decisions_prints_nothing() {
  local dir state out
  dir=$(make_case none-open)
  state="$dir/state"
  out="$dir/drain.out"
  printf 'working: on it\n' > "$state/task4.status"
  printf 'resolved: shipped clean\n' > "$state/task5.status"

  FM_STATE_OVERRIDE="$state" "$DRAIN" > "$out" || fail "drain failed with no open decisions"

  if grep -F 'OPEN DECISIONS' "$out" >/dev/null; then
    fail "the empty case printed an OPEN DECISIONS section: $(cat "$out")"
  fi
  [ ! -s "$out" ] || fail "the empty case with no queued wakes was not silent: $(cat "$out")"
  pass "no open decisions across the fleet prints nothing"
}

test_open_decision_surfaces_even_with_an_unrelated_queued_wake() {
  local dir state out
  dir=$(make_case fleet-wide)
  state="$dir/state"
  out="$dir/drain.out"
  # task6 has a buried, still-open decision but generates NO new queue record
  # this turn; task7 is what actually wakes the drain. The fleet-wide scan
  # must still catch task6's decision alongside task7's own raw row.
  printf 'needs-decision [key=migration]: pick the rollout plan\n' > "$state/task6.status"
  printf 'working: continuing\n' >> "$state/task6.status"
  printf 'blocked: waiting on credentials\n' > "$state/task7.status"
  append_wake "$state" signal task7.status "blocked: waiting on credentials" \
    || fail "queueing the unrelated wake failed"

  FM_STATE_OVERRIDE="$state" "$DRAIN" > "$out" || fail "drain failed with a mixed fleet"

  grep "$(printf '\tsignal\ttask7.status\t')" "$out" >/dev/null || fail "task7's own raw row is missing"
  grep -F 'task6' "$out" | grep -F '[key=migration]' >/dev/null \
    || fail "task6's buried decision was not surfaced even though only task7 queued a wake"
  pass "the open-decision section is fleet-wide, not scoped to this drain's own queued records"
}

test_buried_decision_surfaces_on_the_empty_queue_fast_path() {
  local dir state out
  dir=$(make_case empty-queue-fast-path)
  state="$dir/state"
  out="$dir/drain.out"
  # No wake is queued at all (the empty-queue exit), but the decision is still
  # open on disk - session-start relies on exactly this path.
  printf 'needs-decision [key=api-shape]: pick REST or RPC\n' > "$state/task8.status"
  printf 'working: continuing\n' >> "$state/task8.status"

  FM_STATE_OVERRIDE="$state" "$DRAIN" > "$out" || fail "empty-queue drain failed"

  grep -F 'task8' "$out" | grep -F '[key=api-shape]' >/dev/null \
    || fail "the empty-queue fast path did not surface a still-open decision"
  pass "a buried open decision surfaces even when the wake queue itself is empty"
}

test_status_symlink_is_not_followed() {
  local dir state out
  dir=$(make_case status-symlink)
  state="$dir/state"
  out="$dir/drain.out"
  mkdir -p "$dir/outside"
  printf 'needs-decision [key=local]: keep this visible\n' > "$state/local.status"
  printf 'needs-decision [key=foreign]: do not expose this\n' > "$dir/outside/foreign.status"
  ln -s ../outside/foreign.status "$state/linked.status"

  FM_STATE_OVERRIDE="$state" "$DRAIN" > "$out" || fail "drain failed with a symlinked status file"

  grep -F 'local [key=local] needs-decision: keep this visible' "$out" >/dev/null \
    || fail "the valid local decision did not surface alongside a rejected status symlink"
  if grep -F 'do not expose this' "$out" >/dev/null; then
    fail "the fleet scan followed a status symlink outside the state directory"
  fi
  pass "the fleet-wide decision scan does not follow status symlinks"
}

# The per-item cut now comes from bin/fm-line-cap-lib.sh, shared with the
# session-start digest's status tails so one truncation marker means the same
# thing wherever an agent meets it. This pins the drain's own end of that
# contract: the lede survives, the marker appears, and the item still fits the
# section's per-item budget including the newline it is charged for.
test_over_long_decision_note_is_capped_with_a_marker() {
  local dir state out line longest
  dir=$(make_case long-note)
  state="$dir/state"
  out="$dir/drain.out"
  {
    printf 'needs-decision [key=api-shape]: pick REST or RPC'
    awk 'BEGIN { while (i++ < 200) printf " and-then-some" }'
    printf '\n'
  } > "$state/task-long.status"

  FM_STATE_OVERRIDE="$state" "$DRAIN" > "$out" || fail "drain failed on an over-long decision note"

  line=$(grep -F 'task-long' "$out")
  case "$line" in
    'task-long [key=api-shape] needs-decision: pick REST or RPC'*' [truncated]') : ;;
    *) fail "an over-long decision note was not capped with its lede intact: $line" ;;
  esac
  longest=${#line}
  [ "$longest" -le 219 ] || fail "a capped decision item ran $longest characters past its per-item budget"

  printf 'needs-decision [key=short]: brief enough to keep whole\n' > "$state/task-short.status"
  FM_STATE_OVERRIDE="$state" "$DRAIN" > "$out" || fail "drain failed on a short decision note"
  grep -F 'task-short [key=short] needs-decision: brief enough to keep whole' "$out" >/dev/null \
    || fail "a decision note already under the cap was altered"
  if grep -F 'brief enough to keep whole [truncated]' "$out" >/dev/null; then
    fail "a decision note already under the cap was marked truncated"
  fi

  pass "an over-long open decision is cut to its per-item budget with the shared truncation marker"
}

# The card's own foundation: full and cursor-backed folds must never disagree about WHICH
# decisions are open, even when one of them cannot be decided from records. Uncertainty is a
# property of the moment it is spoken, so it may change what a drain prints but never what the
# two strategies hold.
# The card's own foundation: full and cursor-backed folds must never disagree about WHICH
# decisions are open, even when one cannot be decided from records. Uncertainty is a property
# of the moment it is spoken, so it may change what a drain prints but never what either
# strategy holds. A record reached through a symlink is the undecided shape used here, since
# that is what actually happens when a foreign object is planted at the owner's path.
test_undecidable_key_keeps_both_folds_in_agreement() {
  local dir state corr status full incr
  dir=$(make_case undecidable-fold-agreement)
  state="$dir/state"
  corr=abcdef0123456789
  mkdir -p "$state/pending-replies"
  printf 'phase=escalated\n' > "$state/pending-replies/$corr"
  status="$state/task10.status"
  printf 'blocked [key=pending-reply-%s]: pending-reply-missed: task=task10 pending-reply-id=%s request=agree\n' \
    "$corr" "$corr" > "$status"

  # Live record: both readers agree and both hold the key.
  full=$(status_open_decisions "$status")
  incr=$(status_open_decisions_incremental "$status")
  [ "$full" = "$incr" ] || fail "live-record folds disagreed: '$full' vs '$incr'"
  printf '%s' "$full" | grep -F "pending-reply-$corr" >/dev/null \
    || fail "a live pending record did not keep its decision open"

  # Now make the record undecided by planting a foreign object behind a symlink at its path.
  mv "$state/pending-replies/$corr" "$dir/foreign-record"
  ln -s "$dir/foreign-record" "$state/pending-replies/$corr"
  full=$(status_open_decisions "$status")
  incr=$(status_open_decisions_incremental "$status")
  [ "$full" = "$incr" ] \
    || fail "the full and cursor-backed folds disagreed about an undecided key: '$full' vs '$incr'"
  printf '%s' "$full" | grep -F "pending-reply-$corr" >/dev/null \
    || fail "an undecided pending key dropped out of membership: '$full'"
  status_decision_record_undecidable "$status" "pending-reply-$corr" \
    || fail "a symlinked record did not read as undecided"

  # Appending history keeps them agreeing: rows are re-derived, never decorated.
  printf 'working: routine progress\n' >> "$status"
  full=$(status_open_decisions "$status")
  incr=$(status_open_decisions_incremental "$status")
  [ "$full" = "$incr" ] || fail "appended history made the two folds disagree: '$full' vs '$incr'"
  pass "full and cursor-backed folds agree on an undecided pending key across appends"
}

# Presentation carries the uncertainty, once per episode, and stops the moment it can decide.
test_undecidable_note_is_presented_once_per_episode() {
  local dir state out corr marker
  dir=$(make_case undecidable-presentation)
  state="$dir/state"
  out="$dir/drain.out"
  corr=abcdef0123456789
  mkdir -p "$state/pending-replies"
  printf 'blocked [key=pending-reply-%s]: pending-reply-missed: task=task11 pending-reply-id=%s request=say it once\n' \
    "$corr" "$corr" > "$state/task11.status"
  # Silence here would be indistinguishable from "nothing is open", so this case pins both
  # halves: the row shows up, and only its presentation carries the caveat.
  marker="$state/.open-decision-undecidable-task11-pending-reply-$corr"

  FM_STATE_OVERRIDE="$state" "$DRAIN" > "$out" || fail "drain failed on an undecided decision"
  grep -F '[record-unreadable]' "$out" >/dev/null \
    || fail "an undecided open decision printed without naming it: $(cat "$out")"
  [ -f "$marker" ] || fail "the first notice published no episode marker"

  # Second drain inside the same episode: still open, still printed, but NOT re-labelled.
  FM_STATE_OVERRIDE="$state" "$DRAIN" > "$out" || fail "second drain failed"
  grep -F 'OPEN DECISIONS' "$out" >/dev/null \
    || fail "an open undecided decision stopped being reported on the second drain"
  note_count=$(grep -c '\[record-unreadable\]' "$out" || true)
  [ "$note_count" -eq 0 ] \
    || fail "the same undecided episode was announced twice: $(cat "$out")"

  # Once the record exists again the episode ends, the marker clears, and a later onset
  # would be free to say so afresh.
  printf 'phase=escalated\n' > "$state/pending-replies/$corr"
  FM_STATE_OVERRIDE="$state" "$DRAIN" > "$out" || fail "drain failed after the record returned"
  [ ! -e "$marker" ] || fail "a decidable open decision kept its uncertainty marker"
  pass "uncertainty is announced once per episode and cleared as soon as it can be decided"
}

test_buried_decision_still_surfaces
test_over_long_decision_note_is_capped_with_a_marker
test_explicit_resolution_closes_it
test_later_unrelated_terminal_line_does_not_close_it
test_reserved_key_namespace_is_owned_by_its_library
test_no_open_decisions_prints_nothing
test_open_decision_surfaces_even_with_an_unrelated_queued_wake
test_buried_decision_surfaces_on_the_empty_queue_fast_path
test_status_symlink_is_not_followed
test_undecidable_key_keeps_both_folds_in_agreement
test_undecidable_note_is_presented_once_per_episode

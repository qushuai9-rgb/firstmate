#!/usr/bin/env bash
# tests/fm-watch-key-lib.test.sh - the per-window marker identity and family
# inventory bin/fm-watch-key-lib.sh owns for the watcher, the away daemon, and
# both cleanup boundaries (spawn creation and teardown retirement).
#
# The coverage that matters here is the LEGACY key form's length bound. That form
# turns `:`, `/`, and `.` into `_` with no length limit, so a long endpoint
# produces a basename past NAME_MAX. No such file can exist - creating one fails -
# so window_marker_names must omit it rather than hand a caller a name `rm -f`
# refuses with ENAMETOOLONG. The fail-closed callers turn that refusal into a
# refused spawn and a half-finished teardown, which is the regression these cases
# pin. The counting must be BY BYTES: a multi-byte endpoint that fits in 255
# characters can still exceed 255 bytes on a byte-limited filesystem.
set -u

# shellcheck source=tests/lib.sh disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=bin/fm-watch-key-lib.sh disable=SC1091
. "$ROOT/bin/fm-watch-key-lib.sh"

TMP_ROOT=$(fm_test_tmproot fm-watch-key-lib)

# names_for <window>: window_marker_names output as a sorted list, one per line.
names_for() {
  window_marker_names "$1" | LC_ALL=C sort
}

# A 403-byte endpoint whose legacy form is comfortably past NAME_MAX while its
# bounded v3 key still fits. Nothing constrains a backend's endpoint length, and
# the repo's own long-endpoint regression covers an in-envelope 248-byte case, so
# this sits just outside it as the spec requires.
long_window() {
  local pad
  pad=$(printf 'a%.0s' $(seq 1 400))
  printf 'firstmate:fm-%s' "$pad"
}

test_legacy_name_over_name_max_is_omitted() {
  local win legacy current out
  win=$(long_window)
  legacy=$(window_key_legacy "$win")
  current=$(window_key "$win")
  [ "${#current}" -le 70 ] || fail "the bounded v3 key should stay short, got ${#current}"

  out=$(names_for "$win")
  # The v3 family must still be present for this endpoint: the length bound
  # removes an impossible filename, never the whole family.
  printf '%s\n' "$out" | grep -Fxq ".stale-since-$current" \
    || fail "a long endpoint lost its bounded v3 markers: $out"
  # And no emitted name may exceed NAME_MAX.
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    [ "${#name}" -le 255 ] || fail "emitted a name of ${#name} bytes, past NAME_MAX: $name"
  done <<EOF
$out
EOF
  # The legacy form of this endpoint can never exist, so it must be absent.
  printf '%s\n' "$out" | grep -Fq -- "$legacy" \
    && fail "a legacy name past NAME_MAX was emitted for a file that cannot exist"
  pass "a legacy marker name past NAME_MAX is omitted while the bounded v3 family survives"
}

test_normal_endpoint_keeps_its_legacy_name() {
  local win legacy out
  win="default:w1:p8B"
  legacy=$(window_key_legacy "$win")
  [ "$legacy" = "default_w1_p8B" ] || fail "unexpected legacy form: $legacy"

  out=$(names_for "$win")
  # Negative control: the length bound must not swallow ordinary names, or the
  # sweep in bin/fm-teardown.sh would stop seeing the population it exists for.
  printf '%s\n' "$out" | grep -Fxq ".hash-$legacy" \
    || fail "an ordinary endpoint lost its legacy .hash- marker: $out"
  printf '%s\n' "$out" | grep -Fxq ".wedge-escalations-$legacy" \
    || fail "an ordinary endpoint lost its legacy .wedge-escalations- marker: $out"
  printf '%s\n' "$out" | grep -Fxq ".stale-since-$(window_key "$win")" \
    || fail "an ordinary endpoint lost its v3 .stale-since- marker: $out"
  pass "an ordinary endpoint still emits both key forms"
}

test_length_bound_counts_bytes_not_characters() {
  # 100 three-byte characters are 300 bytes: inside a 255-CHARACTER bound but
  # outside a 255-BYTE one. The prefix and separator leave 240 bytes, so this
  # name must be omitted - a character-counting bound would wrongly keep it.
  local win legacy name out bytes
  local chars c
  c='中'
  chars=''
  local i
  for i in $(seq 1 100); do chars="$chars$c"; done
  win="firstmate:fm-$chars"
  legacy=$(window_key_legacy "$win")
  name=".hash-$legacy"
  bytes=$(printf '%s' "$name" | wc -c | tr -d ' ')
  [ "${#name}" -lt 255 ] || fail "fixture is not multi-byte-ambiguous: ${#name} chars"
  [ "$bytes" -gt 255 ] || fail "fixture is not multi-byte-ambiguous: $bytes bytes"

  out=$(names_for "$win")
  printf '%s\n' "$out" | grep -Fq -- "$legacy" \
    && fail "a name of $bytes bytes was measured by characters and wrongly emitted"
  printf '%s\n' "$out" | grep -Fxq ".hash-$(window_key "$win")" \
    || fail "a multi-byte endpoint lost its bounded v3 marker"
  pass "the legacy length bound counts bytes, so a multi-byte name past NAME_MAX is omitted"
}

test_marker_clear_removes_both_forms_and_no_neighbour() {
  local state win other name
  state="$TMP_ROOT/marker-clear"
  mkdir -p "$state"
  win="default:w1:p8B"
  other="default:w1:p9C"
  local n
  for n in "$win" "$other"; do
    while IFS= read -r name; do
      [ -n "$name" ] || continue
      printf '0\n' > "$state/$name"
    done < <(window_marker_names "$n")
  done

  window_marker_clear "$state" "$win" || fail "window_marker_clear failed"

  while IFS= read -r name; do
    [ -n "$name" ] || continue
    [ ! -e "$state/$name" ] || fail "clear left $name behind"
  done < <(window_marker_names "$win")
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    [ -e "$state/$name" ] || fail "clear removed a neighbouring endpoint's $name"
  done < <(window_marker_names "$other")
  pass "clearing one endpoint removes both key forms and no neighbouring endpoint's markers"
}

test_marker_clear_tolerates_an_impossible_long_endpoint() {
  # The fail-closed spawn and teardown callers must not refuse a legitimate
  # endpoint just because its legacy form would be unrepresentable.
  local state win rc=0
  state="$TMP_ROOT/marker-clear-long"
  mkdir -p "$state"
  win=$(long_window)
  window_marker_clear "$state" "$win" || rc=$?
  expect_code 0 "$rc" "clearing an endpoint whose legacy name cannot exist must not fail"
  pass "clearing an endpoint whose legacy name cannot exist succeeds"
}

fm_test_run \
  test_legacy_name_over_name_max_is_omitted \
  test_normal_endpoint_keeps_its_legacy_name \
  test_length_bound_counts_bytes_not_characters \
  test_marker_clear_removes_both_forms_and_no_neighbour \
  test_marker_clear_tolerates_an_impossible_long_endpoint

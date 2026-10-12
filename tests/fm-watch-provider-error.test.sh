#!/usr/bin/env bash
# Regression coverage for secondmate provider-error rate-limit matching.
set -u

# shellcheck source=tests/wake-helpers.sh
. "$(dirname "${BASH_SOURCE[0]}")/wake-helpers.sh"

# shellcheck disable=SC2034 # make_case reads this shared fixture root.
TMP_ROOT=$(fm_test_tmproot fm-watch-provider-error-tests)
dir=$(make_case provider-error-rate-limit)
state="$dir/state"
fakebin="$dir/fakebin"
capture="$dir/pane.txt"
window='test:fm-provider-rate-limit'
home="$dir/mate-home"
mkdir -p "$home/state" "$home/data" "$home/projects"
printf 'mate\n' > "$home/.fm-secondmate-home"
printf 'window=%s\nkind=secondmate\nharness=pi\nhome=%s\n' "$window" "$home" > "$state/mate.meta"

run_watch_tick() {  # <state> <fakebin> <capture> <function>
  local state=$1 fakebin=$2 capture_file=$3 function=$4
  PATH="$fakebin:$PATH" FM_HOME="$(dirname "$state")" FM_STATE_OVERRIDE="$state" \
    FM_FAKE_TMUX_WINDOW="$window" FM_FAKE_TMUX_CAPTURE="$capture_file" bash -c \
    '. "$1"; wake() { printf "%s\\n" "$1"; }; "$2"' _ "$ROOT/bin/fm-watch.sh" "$function"
}

assert_match() {  # <text> <expected> <description>
  local text=$1 expected=$2 description=$3 out
  printf '%s\n' "$text" > "$capture"
  out=$(run_watch_tick "$state" "$fakebin" "$capture" secondmate_provider_error_tick)
  if [ "$expected" = yes ]; then
    assert_contains "$out" 'check: secondmate provider error: mate=mate' "$description"
  else
    [ -z "$out" ] || fail "$description unexpectedly matched: $out"
  fi
  rm -f "$state/.secondmate-provider-error-mate"
}

assert_match 'registration or payment, polite rate limits, no commercial requests, no credentials, no imputation or neighbour-substitution, and 404 != listing/delisting.' no 'harmless prose must not match'
assert_match '429 Too Many Requests' yes '429 Too Many Requests must match'
assert_match 'rate limit exceeded' yes 'rate limit exceeded must match'
assert_match 'quota exceeded' yes 'quota exceeded must match'
assert_match 'concurrency limit exceeded for account' yes 'concurrency limit exceeded must match'
assert_match $'rate limit\nexceeded' no 'cross-line rate-limit fragments must not match'
assert_match 'rate limit status is healthy; much later this request completed' no 'distant rate-limit and request wording must not match'

pass 'secondmate rate-limit provider errors match concrete failures without prose false positives'

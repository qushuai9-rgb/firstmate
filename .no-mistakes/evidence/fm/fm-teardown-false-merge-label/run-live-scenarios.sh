#!/usr/bin/env bash
# Drives every scenario of this change against the real product.
set -u
EVID=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$EVID/drive-lib.sh" "${1:?repo root}"
trap cleanup_live EXIT
OUT=$EVID/live-scenarios-transcript.md
: > "$OUT"
PASSES=0
FAILS=0
emit() { printf '%s\n' "$*" >> "$OUT"; }
check() {  # <label> <0-pass>
  if [ "$2" = 0 ]; then PASSES=$((PASSES+1)); emit "PASS: $1"; else FAILS=$((FAILS+1)); emit "FAIL: $1"; fi
}
need() {  # <label> <haystack> <needle>
  case "$2" in *"$3"*) check "$1" 0 ;; *) check "$1" 1 ;; esac
}
forbid() {  # <label> <haystack> <needle>
  case "$2" in *"$3"*) check "$1" 1 ;; *) check "$1" 0 ;; esac
}

# --- S1 ---------------------------------------------------------------
id=s1-open-pr
case_dir=$(make_case s1-open-pr "$id") || exit 1
url=https://github.com/example/repo/pull/7
emit ""
emit "## S1: teardown of a ship whose pull request the forge reports OPEN"
emit '```'
emit "\$ bin/fm-teardown.sh $id   # forge: $url is OPEN, mergedAt empty"
write_meta "$case_dir" "$id" "$url"
seed_backlog "$case_dir" "$id" --pr "$url"
forge_reports "$case_dir" OPEN '' "$url"
out=$(run_teardown "$case_dir" "$id" 2>&1); rc=$?
emit "$out"
emit "[teardown exit $rc]"
emit '```'
ledger=$(cat "$case_dir/home/data/backlog.md")
show=$(show_row_full "$case_dir" "$id")
emit '```'
emit "$ledger"
emit ""
emit "$show"
emit '```'
[ "$rc" = 0 ]; check "teardown succeeds" $?
need "ledger records a plain completion" "$ledger" '(done '
forbid "ledger claims no merge" "$ledger" '(merged '
need "the URL stays on the row" "$show" "$url"
need "the note states the merge was not verified in this run" "$show" 'merge was not verified in this run'
forbid "the closed row carries no structured pull-request link" "$show" 'links: "pr:'

# --- S2 ---------------------------------------------------------------
id=s2-unreadable-forge
case_dir=$(make_case s2-unreadable "$id") || exit 1
url=https://github.com/example/repo/pull/8
emit ""
emit "## S2: teardown when the forge cannot be read (adversarial fail-safe)"
emit '```'
emit "\$ bin/fm-teardown.sh $id   # gh pr view fails: no auth / no network / no client"
write_meta "$case_dir" "$id" "$url"
seed_backlog "$case_dir" "$id" --pr "$url"
out=$(run_teardown "$case_dir" "$id" 2>&1); rc=$?
emit "$out"
emit "[teardown exit $rc]"
emit '```'
ledger=$(cat "$case_dir/home/data/backlog.md")
show=$(show_row_full "$case_dir" "$id")
emit '```'
emit "$ledger"
emit ""
emit "$show"
emit '```'
[ "$rc" = 0 ]; check "teardown succeeds on an unreadable forge" $?
forbid "an unreadable forge never records a merge" "$ledger" '(merged '
need "the note says the pull request state could not be read" "$show" 'its pull request state could not be read'
need "the URL stays on the row" "$show" "$url"
forbid "the closed row carries no structured pull-request link" "$show" 'links: "pr:'

# --- S3 ---------------------------------------------------------------
id=s3-verified-merge
case_dir=$(make_case s3-merged "$id") || exit 1
url=https://github.com/example/repo/pull/9
emit ""
emit "## S3: teardown of a ship whose pull request the forge reports MERGED"
emit '```'
emit "\$ bin/fm-teardown.sh $id   # forge: $url is MERGED"
write_meta "$case_dir" "$id" "$url"
seed_backlog "$case_dir" "$id" --pr "$url"
forge_reports "$case_dir" MERGED '2026-11-01T00:00:00Z' "$url"
out=$(run_teardown "$case_dir" "$id" 2>&1); rc=$?
emit "$out"
emit "[teardown exit $rc]"
emit '```'
ledger=$(cat "$case_dir/home/data/backlog.md")
show=$(show_row_full "$case_dir" "$id")
emit '```'
emit "$ledger"
emit ""
emit "$show"
emit '```'
[ "$rc" = 0 ]; check "teardown succeeds" $?
need "a forge-confirmed merge is still recorded" "$ledger" '(merged '
need "the verified pull request stays the row's link" "$show" "links: \"pr:$url\""
[ ! -e "$case_dir/home/state/$id.pr-merge" ]; check "a landed close retires its merge-verification record" $?

# --- S4 ---------------------------------------------------------------
id=s4-answer-unverified
case_dir=$(make_case s4-answer "$id") || exit 1
url=https://github.com/example/repo/pull/41
emit ""
emit "## S4: captain answers a held row still carrying an unverified pull-request link"
emit '```'
emit "\$ bin/fm-captain-hold.sh hold $id --reason 'captain merge approval pending'"
emit "\$ bin/fm-captain-hold.sh answer $id --decision-file answer.txt   # no --release"
seed_backlog "$case_dir" "$id" >/dev/null || exit 1
tasks_in "$case_dir" update "$id" --pr "$url" >/dev/null
run_captain "$case_dir" hold "$id" --reason 'captain merge approval pending' >/dev/null 2>&1; hold_rc=$?
printf 'Do not merge this pull request yet.\n' > "$case_dir/answer.txt"
out=$(run_captain "$case_dir" answer "$id" --decision-file "$case_dir/answer.txt" 2>&1); rc=$?
emit "$out"
emit "[hold exit $hold_rc; answer exit $rc]"
emit '```'
ledger=$(cat "$case_dir/home/data/backlog.md")
show=$(show_row_full "$case_dir" "$id")
emit '```'
emit "$ledger"
emit ""
emit "$show"
emit '```'
[ "$rc" = 0 ]; check "the answer closes the held row" $?
forbid "the answer never renders an unverified link as merged" "$ledger" '(merged '
need "the row reads as a completion" "$show" 'state: done'
need "the URL survives in the body note" "$show" "$url"
need "the note says the merge was not verified in this run" "$show" 'merge was not verified in this run'
forbid "the answered row carries no structured pull-request link" "$show" 'links: "pr:'
title=$(tasks_in "$case_dir" show "$id" | sed -n 's/^  title: *//p' | head -1)
forbid "the URL no longer sits in the title" "$title" 'pull/41'

# --- S5 ---------------------------------------------------------------
id=s5-answer-verified
case_dir=$(make_case s5-answer-verified "$id") || exit 1
url=https://github.com/example/repo/pull/44
emit ""
emit "## S5: captain answers a retention whose cleanup read the merge from the forge"
emit '```'
emit "\$ bin/fm-teardown.sh $id   # forge: $url MERGED; row is held, so cleanup retains it"
write_meta "$case_dir" "$id" "$url"
seed_backlog "$case_dir" "$id" --pr "$url"
forge_reports "$case_dir" MERGED '2026-11-01T00:00:00Z' "$url"
run_captain "$case_dir" hold "$id" --reason 'captain decision pending' >/dev/null 2>&1
t_out=$(run_teardown "$case_dir" "$id" 2>&1); t_rc=$?
emit "$t_out"
emit "[teardown exit $t_rc]"
emit '```'
emit '```'
emit "$(cat "$case_dir/home/data/backlog.md")"
emit ""
emit "$(show_row_full "$case_dir" "$id")"
emit '```'
[ -e "$case_dir/home/state/$id.pr-merge" ]; check "the landed retention keeps the merge-verification record the answer reads" $?
printf 'Proceed with the merged change.\n' > "$case_dir/answer.txt"
out=$(run_captain "$case_dir" answer "$id" --decision-file "$case_dir/answer.txt" 2>&1); rc=$?
emit '```'
emit "\$ bin/fm-captain-hold.sh answer $id --decision-file answer.txt"
emit "$out"
emit "[answer exit $rc]"
emit '```'
ledger=$(cat "$case_dir/home/data/backlog.md")
show=$(show_row_full "$case_dir" "$id")
emit '```'
emit "$ledger"
emit ""
emit "$show"
emit '```'
[ "$rc" = 0 ]; check "the answer closes the verified retained row" $?
need "a merge the forge confirmed is still recorded on the answer" "$ledger" '(merged '
need "the answered row keeps the verified pull-request link" "$show" "links: \"pr:$url\""
[ ! -e "$case_dir/home/state/$id.pr-merge" ]; check "the answered close retires its merge-verification record" $?

# --- S6 ---------------------------------------------------------------
id=s6-replay-unverified
case_dir=$(make_case s6-replay-unverified "$id") || exit 1
url=https://github.com/example/repo/pull/71
home=$case_dir/home
emit ""
emit "## S6: session start replays a pending close staged before the merge check (legacy record)"
emit '```'
seed_backlog "$case_dir" "$id" >/dev/null || exit 1
printf 'id=%s\ndata=%s\nspawn_gen=legacy-replay-s6\narg=--pr\narg=%s\n' "$id" "$home/data" "$url" \
  > "$home/state/$id.backlog-close"
emit "\$ cat $home/state/$id.backlog-close"
emit "$(cat "$home/state/$id.backlog-close")"
emit "\$ bin/fm-bootstrap.sh   # session start, no network forge read"
out=$(run_bootstrap "$case_dir" 2>&1); rc=$?
emit "$out"
emit "[bootstrap exit $rc]"
emit '```'
ledger=$(cat "$home/data/backlog.md")
show=$(show_row_full "$case_dir" "$id")
emit '```'
emit "$ledger"
emit ""
emit "$show"
emit '```'
[ "$rc" = 0 ]; check "session start replays the record" $?
forbid "a legacy record with no verified merge never closes as merged" "$ledger" '(merged '
need "the replay states the merge was not verified" "$show" 'merge was not verified'
need "the replayed close keeps the URL" "$show" "$url"
forbid "the replayed row carries no structured pull-request link" "$show" 'links: "pr:'
[ ! -e "$home/state/$id.backlog-close" ]; check "the replayed record is retired" $?

# --- S7 ---------------------------------------------------------------
id=s7-replay-verified
case_dir=$(make_case s7-replay-verified "$id") || exit 1
url=https://github.com/example/repo/pull/72
home=$case_dir/home
emit ""
emit "## S7: session start replays a pending close that records a forge-verified merge"
emit '```'
seed_backlog "$case_dir" "$id" >/dev/null || exit 1
printf 'id=%s\ndata=%s\nspawn_gen=verified-replay-s7\npr_merge_verified_at=2026-11-01T00:00:00Z\narg=--pr\narg=%s\n' \
  "$id" "$home/data" "$url" > "$home/state/$id.backlog-close"
emit "\$ cat $home/state/$id.backlog-close"
emit "$(cat "$home/state/$id.backlog-close")"
emit "\$ bin/fm-bootstrap.sh   # session start"
out=$(run_bootstrap "$case_dir" 2>&1); rc=$?
emit "$out"
emit "[bootstrap exit $rc]"
emit '```'
ledger=$(cat "$home/data/backlog.md")
show=$(show_row_full "$case_dir" "$id")
emit '```'
emit "$ledger"
emit ""
emit "$show"
emit '```'
[ "$rc" = 0 ]; check "session start replays the verified record" $?
need "the verified merge is recorded as a merge" "$ledger" '(merged '
need "the verified link stays structured on the row" "$show" "links: \"pr:$url\""

# --- S8 ---------------------------------------------------------------
id=s8-incomplete-merge-record
case_dir=$(make_case s8-incomplete "$id") || exit 1
url=https://github.com/example/repo/pull/81
emit ""
emit "## S8: teardown when the forge reports MERGED with no merge time (adversarial incomplete record)"
emit '```'
emit "\$ bin/fm-teardown.sh $id   # forge: state MERGED, mergedAt empty"
write_meta "$case_dir" "$id" "$url"
seed_backlog "$case_dir" "$id" --pr "$url"
forge_reports "$case_dir" MERGED '' "$url"
out=$(run_teardown "$case_dir" "$id" 2>&1); rc=$?
emit "$out"
emit "[teardown exit $rc]"
emit '```'
ledger=$(cat "$case_dir/home/data/backlog.md")
show=$(show_row_full "$case_dir" "$id")
emit '```'
emit "$ledger"
emit ""
emit "$show"
emit '```'
[ "$rc" = 0 ]; check "teardown succeeds on an incomplete forge record" $?
forbid "a MERGED state with no merge time is not a merge" "$ledger" '(merged '
need "the URL stays on the row" "$show" "$url"
forbid "the closed row carries no structured pull-request link" "$show" 'links: "pr:'

# --- S9 ---------------------------------------------------------------
id=s9-verified-among-two-links
case_dir=$(make_case s9-two-links "$id") || exit 1
open_url=https://github.com/example/repo/pull/91
merged_url=https://github.com/example/repo/pull/92
emit ""
emit "## S9: teardown of a verified merge whose row also carries an unverified link"
emit '```'
emit "\$ bin/fm-teardown.sh $id   # forge: pull/92 MERGED, pull/91 OPEN"
write_meta "$case_dir" "$id" "$merged_url"
seed_backlog "$case_dir" "$id" --pr "$open_url"
forge_reports "$case_dir" MERGED '2026-11-01T00:00:00Z' "$merged_url"
out=$(run_teardown "$case_dir" "$id" 2>&1); rc=$?
emit "$out"
emit "[teardown exit $rc]"
emit '```'
ledger=$(cat "$case_dir/home/data/backlog.md")
show=$(show_row_full "$case_dir" "$id")
emit '```'
emit "$ledger"
emit ""
emit "$show"
emit '```'
[ "$rc" = 0 ]; check "teardown succeeds with two links on the row" $?
need "only the verified merge renders as merged" "$ledger" '(merged '
forbid "the unverified sibling URL never stays a structured link" "$show" "links: \"pr:$open_url\""
need "the unverified sibling URL stays in the body note" "$show" "$open_url"
need "the verified merge keeps its structured link" "$show" "links: \"pr:$merged_url\""

emit ""
emit "## Totals"
emit "- checks passed: $PASSES"
emit "- checks failed: $FAILS"
printf 'passed=%s failed=%s\n' "$PASSES" "$FAILS"
[ "$FAILS" = 0 ]

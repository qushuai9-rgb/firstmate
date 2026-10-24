#!/usr/bin/env bash
# Live scenario driver: a marked secondmate home runs its OWN startup, and a
# restart after a dead lock owner retakes that lock and realigns from disk.
# Drives the REAL bin/fm-session-start.sh inside a REAL seeded secondmate home
# (bin/fm-home-seed.sh) cloned from the worktree under test.
set -u
WT=/Users/qushuai9/.no-mistakes/worktrees/be4d97686c7c/01M5NYF3VY2N6WNEFK4K7M1Z8M
EVID=/Users/qushuai9/.no-mistakes/evidence/01M5NYF3VY2N6WNEFK4K7M1Z8M
LAB=$(cd "$(mktemp -d "${TMPDIR:-/tmp}/fm-lab.XXXXXX")" && pwd -P)
MATE_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/fm-mate.XXXXXX")
MATE="$MATE_ROOT/sm-live-1"
FAIL=0
note() { printf '%s\n' "$*"; }
ok()   { printf 'PASS: %s\n' "$*"; }
bad()  { printf 'FAIL: %s\n' "$*"; FAIL=1; }
has()  { case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac; }

cleanup() {
  rm -rf "$LAB" "$MATE_ROOT"
}
trap cleanup EXIT

env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS \
  FM_HOME="$LAB" FM_ROOT_OVERRIDE="$WT" \
  FM_SECONDMATE_SCOPE='lab validation only' \
  FM_SECONDMATE_CHARTER='# Lab secondmate charter

You are a lab secondmate. Obey the parent Firstmate.' \
  "$WT/bin/fm-lab-home.sh" create "$LAB" >/dev/null || { echo "cannot mark lab"; exit 1; }
printf 'LAB=%s\nMATE=%s\n' "$LAB" "$MATE"

note "== provisioning a real secondmate home from the tracked code root =="
env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS \
  FM_HOME="$LAB" FM_ROOT_OVERRIDE="$WT" \
  FM_SECONDMATE_SCOPE='lab validation only' \
  FM_SECONDMATE_CHARTER='# Lab secondmate charter

You are a lab secondmate. Obey the parent Firstmate.' \
  "$WT/bin/fm-home-seed.sh" sm-live-1 "$MATE" --no-projects || { echo "seed failed"; exit 1; }
[ -f "$MATE/.fm-secondmate-home" ] || { echo "no secondmate marker"; exit 1; }
printf 'marker: %s\n' "$(cat "$MATE/.fm-secondmate-home")"

# The digest's backlog replay needs the home's own backlog backend. The seeded
# home already carries .tasks.toml (markdown backend); create the backlog file
# and a real pending row + a real recorded pending close.
printf '# Backlog\n\n## In flight\n\n## Queued\n\n## Done\n' > "$MATE/data/backlog.md"
tasks-axi add child-before "item for child-before" --kind ship --file "$MATE/data/backlog.md" >/dev/null
tasks-axi start child-before --file "$MATE/data/backlog.md" >/dev/null
seed_close() { # <id>
  printf 'id=%s\ndata=%s/data\nspawn_gen=spawn-%s\narg=--note\narg=local%%20main\n' \
    "$1" "$MATE" "$1" > "$MATE/state/$1.backlog-close"
}
seed_wake() { # <key> <payload>
  env -u NO_MISTAKES_GATE FM_STATE_OVERRIDE="$MATE/state" bash -c '
    . "$1"
    fm_wake_append signal "$2" "$3"
  ' _ "$MATE/bin/fm-wake-lib.sh" "$1" "$2"
}
run_start() {
  env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS \
    -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE \
    -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE \
    FM_HOME="$MATE" "$MATE/bin/fm-session-start.sh"
}
wait_network_report() {
  local i=0
  while [ "$i" -lt 60 ]; do
    [ -f "$MATE/state/.startup-network.report" ] && return 0
    i=$((i + 1)); sleep 0.5
  done
  return 1
}
snapshot_primary() { (cd "$LAB" && find state data -mindepth 1 | LC_ALL=C sort); }
mtime_of() { perl -e 'print((stat($ARGV[0]))[9])' "$1"; }

note "== seeding this home's own pending work before the first startup =="
# A secondmate record in THIS home's own state is what the deferred
# home-scoped secondmate liveness/convergence sweeps read. Its home does not
# exist, so the sweeps must report it as skipped against this home, never against
# the primary.
cat > "$MATE/state/sm-x.meta" <<META
window=firstmate:fm-sm-x
endpoint_task_id=sm-x
worktree=/nonexistent/lab-sm-x-home
project=/nonexistent/lab-sm-x-home
harness=echo
kind=secondmate
mode=secondmate
yolo=off
home=/nonexistent/lab-sm-x-home
projects=alpha
META
seed_close child-before
seed_wake sm-own "done: reconciled from the local queue"
PRIMARY_BEFORE=$(snapshot_primary)

note "== FIRST STARTUP: real bin/fm-session-start.sh in the marked secondmate home =="
OUT1=$(run_start 2>&1); ST1=$?
printf '%s\n' "$OUT1" > "$EVID/own-startup-first.log"
printf 'first startup exit=%s\n' "$ST1"
[ "$ST1" -eq 0 ] && ok "secondmate startup exit 0" || bad "secondmate startup exit $ST1"
has "$OUT1" "SECOND MATE STARTUP - $MATE" && ok "digest printed the marker-derived SECOND MATE STARTUP heading" \
  || bad "no SECOND MATE STARTUP heading"
has "$OUT1" "this home's session lock" && ok "digest stated this home's own lock ownership" \
  || bad "own-lock wording missing"
has "$OUT1" "lock acquired: harness pid" && ok "digest acquired a session lock through fm-lock.sh" \
  || bad "no lock acquisition line"
has "$OUT1" "$(printf 'signal\tsm-own\tdone: reconciled from the local queue')" \
  && ok "digest drained this home's own queued wake" || bad "wake not drained"
has "$OUT1" "closed the backlog item for child-before" \
  && ok "digest replayed this home's own pending backlog close" || bad "pending close not replayed"
has "$OUT1" "FLEET STATE" && ok "digest ran the fleet/disk reconciliation stage" || bad "no FLEET STATE stage"
ROW1=$(tasks-axi show child-before --file "$MATE/data/backlog.md" 2>/dev/null | sed -n 's/^  state: *//p' | head -1)
[ "$ROW1" = done ] && ok "backlog row child-before is done after replay (row=$ROW1)" || bad "row child-before=$ROW1"
[ ! -e "$MATE/state/child-before.backlog-close" ] && ok "replayed close marker removed" || bad "close marker left behind"

LOCK1=$(sed -n 1p "$MATE/state/.lock" 2>/dev/null)
COMPLETE1=$(cat "$MATE/state/.session-start-complete" 2>/dev/null)
MTIME1=$(mtime_of "$MATE/state/.session-start-complete")
note "readings before restart: lock=$LOCK1 complete=$COMPLETE1 mtime=$MTIME1"
[ -n "$LOCK1" ] && [ "$LOCK1" = "$COMPLETE1" ] && ok "completion record keyed to this home's lock holder" \
  || bad "lock/complete mismatch ($LOCK1 vs $COMPLETE1)"

if wait_network_report; then
  ok "deferred network stage published $MATE/state/.startup-network.report"
  printf 'report:\n'; sed 's/^/  /' "$MATE/state/.startup-network.report"
  grep -q 'SECONDMATE_SYNC: secondmate sm-x: ' "$MATE/state/.startup-network.report" \
    && ok "deferred sweep converged this home's own secondmate record" \
    || bad "deferred secondmate convergence absent from report"
  grep -q 'SECONDMATE_LIVENESS: secondmate sm-x: ' "$MATE/state/.startup-network.report" \
    && ok "deferred sweep checked this home's own secondmate liveness" \
    || bad "deferred secondmate liveness absent from report"
else
  bad "deferred network stage never published"
fi

PRIMARY_AFTER1=$(snapshot_primary)
[ "$PRIMARY_BEFORE" = "$PRIMARY_AFTER1" ] && ok "primary home state/ and data/ unchanged by the secondmate startup" \
  || { bad "secondmate startup touched the primary home"; diff <(printf '%s\n' "$PRIMARY_BEFORE") <(printf '%s\n' "$PRIMARY_AFTER1"); }

note "== RESTART: a real restart leaves a dead lock owner behind =="
DEAD_PID=$(bash -c 'printf "%s\n" "$$"')
printf '%s\n' "$DEAD_PID" > "$MATE/state/.lock"
seed_close child-after
tasks-axi add child-after "item for child-after" --kind ship --file "$MATE/data/backlog.md" >/dev/null
tasks-axi start child-after --file "$MATE/data/backlog.md" >/dev/null
seed_wake sm-restart "done: reconciled after restart"
sleep 1
note "wrote dead lock owner pid $DEAD_PID and queued fresh work while the home was down"

OUT2=$(run_start 2>&1); ST2=$?
printf '%s\n' "$OUT2" > "$EVID/own-startup-restart.log"
printf 'restart exit=%s\n' "$ST2"
[ "$ST2" -eq 0 ] && ok "restarted secondmate startup exit 0" || bad "restart exit $ST2"
has "$OUT2" "$(printf 'signal\tsm-restart\tdone: reconciled after restart')" \
  && ok "restart drained the wake queued while it was down" || bad "restart did not drain the new wake"
has "$OUT2" "closed the backlog item for child-after" \
  && ok "restart replayed the close its dead session left" || bad "restart did not replay the close"
ROW2=$(tasks-axi show child-after --file "$MATE/data/backlog.md" 2>/dev/null | sed -n 's/^  state: *//p' | head -1)
[ "$ROW2" = done ] && ok "backlog row child-after is done after restart (row=$ROW2)" || bad "row child-after=$ROW2"
[ ! -e "$MATE/state/child-after.backlog-close" ] && ok "restart close marker removed" || bad "restart marker left behind"

LOCK2=$(sed -n 1p "$MATE/state/.lock" 2>/dev/null)
COMPLETE2=$(cat "$MATE/state/.session-start-complete" 2>/dev/null)
MTIME2=$(mtime_of "$MATE/state/.session-start-complete")
note "readings after restart: lock=$LOCK2 complete=$COMPLETE2 mtime=$MTIME2"
[ "$LOCK2" != "$DEAD_PID" ] && ok "restart replaced the dead lock owner $DEAD_PID (new=$LOCK2)" \
  || bad "restart kept the dead lock owner $DEAD_PID"
[ "$LOCK2" = "$COMPLETE2" ] && ok "restart completion record keyed to the new lock holder" \
  || bad "restart lock/complete mismatch"
[ "$MTIME2" -gt "$MTIME1" ] && ok "completion record rewritten newer ($MTIME1 -> $MTIME2)" \
  || bad "completion record not newer ($MTIME1 -> $MTIME2)"
STATUS=$(env -u NO_MISTAKES_GATE FM_HOME="$MATE" "$MATE/bin/fm-lock.sh" status 2>&1)
note "fm-lock.sh status: $STATUS"
has "$STATUS" "lock: held by live harness pid $LOCK2" \
  && ok "fm-lock.sh reports the restarted lock held by a live harness pid" || bad "fm-lock.sh does not report a live holder"

PRIMARY_AFTER2=$(snapshot_primary)
[ "$PRIMARY_BEFORE" = "$PRIMARY_AFTER2" ] && ok "primary home still unchanged after the restart cycle" \
  || bad "restart touched the primary home"

note "== POSTURE IS MARKER-DERIVED: an unmarked home and a symlinked marker are not secondmates =="
PLAIN="$MATE_ROOT/plain-home"
mkdir -p "$PLAIN/state" "$PLAIN/data" "$PLAIN/config"
printf '# Firstmate\n' > "$PLAIN/AGENTS.md"
PLAIN_OUT=$(env -u NO_MISTAKES_GATE -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE \
  -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE FM_HOME="$PLAIN" "$MATE/bin/fm-session-start.sh" 2>&1)
has "$PLAIN_OUT" "SESSION START - $PLAIN" && ok "an unmarked home still gets the ordinary SESSION START heading" \
  || bad "an unmarked home did not get SESSION START"
has "$PLAIN_OUT" "SECOND MATE STARTUP" && bad "an unmarked home was treated as a secondmate" \
  || ok "an unmarked home never claims the secondmate posture"

SYM="$MATE_ROOT/symlinked-marker-home"
mkdir -p "$SYM/state" "$SYM/data" "$SYM/config"
printf '# Firstmate\n' > "$SYM/AGENTS.md"
printf 'sm-live-1\n' > "$MATE_ROOT/real-marker"
ln -s "$MATE_ROOT/real-marker" "$SYM/.fm-secondmate-home"
SYM_OUT=$(env -u NO_MISTAKES_GATE -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE \
  -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE FM_HOME="$SYM" "$MATE/bin/fm-session-start.sh" 2>&1)
has "$SYM_OUT" "SECOND MATE STARTUP" && bad "a symlinked identity marker spoofed the secondmate posture" \
  || ok "a symlinked identity marker does not spoof the secondmate posture"

note "== SESSION-OPEN HOOKS: a marked secondmate home is eligible, not stood down =="
rm -f "$MATE/state/.lock"
NUDGE=$(env -u NO_MISTAKES_GATE -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE \
  -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE FM_HOME="$MATE" "$MATE/bin/fm-sessionstart-nudge.sh" 2>&1)
has "$NUDGE" 'Run `bin/fm-session-start.sh` now' \
  && ok "the nudge wrapper asks a secondmate whose lock is not held to run its startup" \
  || bad "the nudge wrapper stayed silent for an un-held secondmate home"
RUN1=$(env -u NO_MISTAKES_GATE -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE \
  -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE FM_HOME="$MATE" \
  "$MATE/bin/fm-sessionstart-run.sh" --source startup 2>&1)
has "$RUN1" "SECOND MATE STARTUP - $MATE" \
  && ok "the run wrapper executed this home's own startup" \
  || bad "the run wrapper stood the secondmate home down"
RUN_LOCK=$(sed -n 1p "$MATE/state/.lock" 2>/dev/null)
[ -n "$RUN_LOCK" ] && ok "the run wrapper took the secondmate home's own session lock ($RUN_LOCK)" \
  || bad "the run wrapper did not take a lock"
NUDGE2=$(env -u NO_MISTAKES_GATE -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE \
  -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE FM_HOME="$MATE" "$MATE/bin/fm-sessionstart-nudge.sh" 2>&1)
[ -z "$NUDGE2" ] && ok "the nudge stays silent once this home's lock is held by this session" \
  || bad "the nudge repeated the instruction for an already-held lock"

printf '\nexit=%s (0 = every assertion above passed)\n' "$FAIL"
exit "$FAIL"

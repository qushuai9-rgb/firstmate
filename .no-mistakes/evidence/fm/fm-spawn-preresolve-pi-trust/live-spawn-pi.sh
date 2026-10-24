#!/usr/bin/env bash
# Live drive of bin/fm-spawn.sh for a pi crewmate ship spawn, with the REAL pi
# CLI on PATH. Only the pane transport (tmux, absent on this host) is a stub;
# the launch command it captures is the one fm-spawn would send, and the trust
# store it inspects is the real file bin/fm-pi-trust.sh wrote.
set -u
ROOT=${FM_REPO_ROOT:?}
. "$ROOT/tests/fixtures.sh"

CASE=$(mktemp -d "${TMPDIR:-/tmp}/fm-live-spawn-pi.XXXXXX") || exit 1
HOME_DIR=$CASE/home
PROJ=$CASE/project
WT=$CASE/wt
FAKEBIN=$CASE/fake/fakebin
LAUNCH_LOG=$CASE/launch.log
fm_test_make_spawn_fakebin "$CASE/fake" >/dev/null
cat > "$FAKEBIN/timeout" <<'EOS'
#!/usr/bin/env bash
if [ "${1:-}" = -k ]; then shift 2; fi
shift
exec "$@"
EOS
chmod +x "$FAKEBIN/timeout"
command -v pi >/dev/null || { echo "pi not found"; exit 2; }

fm_test_spawn_home "$HOME_DIR" pi
fm_git_worktree "$PROJ" "$WT" "wt-live-spawn"
fm_test_spawn_brief "$HOME_DIR" live-pi-trust "confirm the worker starts without a trust dialog"

out=$(
  FM_TEST_SEAM=1 FM_GATE_REFUSE_BYPASS=1 \
  FM_ROOT_OVERRIDE='' FM_HOME="$HOME_DIR" HOME="$HOME_DIR/user-home" \
  CLAUDE_CONFIG_DIR='' \
  FM_STATE_OVERRIDE="$HOME_DIR/state" FM_DATA_OVERRIDE="$HOME_DIR/data" \
  FM_PROJECTS_OVERRIDE="$HOME_DIR/projects" FM_CONFIG_OVERRIDE="$HOME_DIR/config" \
  FM_SPAWN_NO_GUARD=1 FM_FAKE_PANE_PATH="$WT" TMUX="fake,1,0" \
  FM_FAKE_LAUNCH_LOG="$LAUNCH_LOG" PATH="$FAKEBIN:$PATH" \
  "$ROOT/bin/fm-spawn.sh" live-pi-trust "$PROJ" --mode no-mistakes --yolo off 2>&1
)
status=$?
printf 'spawn-exit=%s\n' "$status"
printf '%s\n' "$out" | tail -20
echo "--- launch line ---"
cat "$LAUNCH_LOG" 2>/dev/null
echo "--- store ---"
cat "$HOME_DIR/user-home/.pi/agent/trust.json" 2>/dev/null || echo "(no store)"
echo "--- worktree ---"
(cd -P -- "$WT" && pwd -P)
printf '%s\n' "$status" > "$CASE/status"
printf '%s\n' "$CASE" > /tmp/fm-live-spawn-case

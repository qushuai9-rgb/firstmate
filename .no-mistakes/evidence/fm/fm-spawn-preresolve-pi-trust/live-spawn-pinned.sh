#!/usr/bin/env bash
# Live drive: a pi crewmate pinned to a worker account must register the
# worktree in THAT root's trust store (the root its launch line names) and not
# in the default <home>/.pi/agent store. Real pi CLI on PATH.
set -u
ROOT=${FM_REPO_ROOT:?}
. "$ROOT/tests/fixtures.sh"
CASE=$(mktemp -d "${TMPDIR:-/tmp}/fm-live-pin.XXXXXX") || exit 1
trap 'chmod -R u+w "$CASE" 2>/dev/null; rm -rf -- "$CASE"' EXIT
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
fm_test_spawn_home "$HOME_DIR" pi
fm_git_worktree "$PROJ" "$WT" "wt-live-pin"
fm_test_spawn_brief "$HOME_DIR" live-pin "pinned pin-account worker"
PI_WORK=$CASE/pi-work
mkdir -p "$PI_WORK"
cp "$HOME/.pi/agent/auth.json" "$HOME/.pi/agent/models.json" \
   "$HOME/.pi/agent/settings.json" "$HOME/.pi/agent/models-store.json" "$PI_WORK/"
printf '%s\ncommandcode\n' "$PI_WORK" > "$HOME_DIR/config/pi-account"
out=$(
  FM_TEST_SEAM=1 FM_GATE_REFUSE_BYPASS=1 \
  FM_ROOT_OVERRIDE='' FM_HOME="$HOME_DIR" HOME="$HOME_DIR/user-home" CLAUDE_CONFIG_DIR='' \
  FM_STATE_OVERRIDE="$HOME_DIR/state" FM_DATA_OVERRIDE="$HOME_DIR/data" \
  FM_PROJECTS_OVERRIDE="$HOME_DIR/projects" FM_CONFIG_OVERRIDE="$HOME_DIR/config" \
  FM_SPAWN_NO_GUARD=1 FM_FAKE_PANE_PATH="$WT" TMUX="fake,1,0" \
  FM_FAKE_LAUNCH_LOG="$LAUNCH_LOG" PATH="$FAKEBIN:$PATH" \
  "$ROOT/bin/fm-spawn.sh" live-pin "$PROJ" --mode no-mistakes --yolo off \
    --model commandcode/deepseek/deepseek-v4.1-flash 2>&1
)
status=$?
echo "pinned-spawn-exit=$status"
printf '%s\n' "$out" | grep -E 'spawned|error' | head -3
WT_REAL=$(cd -P -- "$WT" && pwd -P)
echo "--- pinned store ($PI_WORK/trust.json) ---"
cat "$PI_WORK/trust.json" 2>/dev/null || echo "(none)"
echo "--- default store present? ---"
[ -e "$HOME_DIR/user-home/.pi/agent/trust.json" ] && echo "YES-BAD: $(cat "$HOME_DIR/user-home/.pi/agent/trust.json")" || echo "no (correct)"
echo "--- launch line names the pinned root? ---"
tail -1 "$LAUNCH_LOG" | grep -o "PI_CODING_AGENT_DIR='[^']*'" | head -1
node -e '
const fs=require("node:fs");const [store,wt]=process.argv.slice(1);
const j=JSON.parse(fs.readFileSync(store,"utf8"));
console.log(j[wt]===true && Object.keys(j).length===1 ? "PASS pinned-root-trust":"FAIL pinned-root-trust "+JSON.stringify(j));
' "$PI_WORK/trust.json" "$WT_REAL"

#!/usr/bin/env bash
# Adversarial boundary: a pi SECONDMATE launch already carries the session-only
# --approve, so the spawn must NOT write a persistent worktree/home trust entry
# for it. Drives the real fm-spawn with the real pi CLI.
set -u
ROOT=${FM_REPO_ROOT:?}
. "$ROOT/tests/fixtures.sh"
CASE=$(mktemp -d "${TMPDIR:-/tmp}/fm-live-sm.XXXXXX") || exit 1
HOME_DIR=$CASE/home
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
printf '%s\n' pi > "$HOME_DIR/config/secondmate-harness"
SM=$CASE/secondmate-home
mkdir -p "$SM/bin" "$SM/data" "$SM/state" "$SM/config"
printf '# Firstmate\n' > "$SM/AGENTS.md"
printf 'live-sm\n' > "$SM/.fm-secondmate-home"
printf 'charter\n' > "$SM/data/charter.md"
printf '%s\n' 'projects/' 'state/' 'data/' 'config/' '.no-mistakes/' > "$SM/.gitignore"
git -C "$SM" init -q -b main
out=$(
  FM_TEST_SEAM=1 FM_GATE_REFUSE_BYPASS=1 \
  FM_ROOT_OVERRIDE='' FM_HOME="$HOME_DIR" HOME="$HOME_DIR/user-home" CLAUDE_CONFIG_DIR='' \
  FM_STATE_OVERRIDE="$HOME_DIR/state" FM_DATA_OVERRIDE="$HOME_DIR/data" \
  FM_PROJECTS_OVERRIDE="$HOME_DIR/projects" FM_CONFIG_OVERRIDE="$HOME_DIR/config" \
  FM_SPAWN_NO_GUARD=1 FM_FAKE_PANE_PATH="$CASE" TMUX="fake,1,0" \
  FM_FAKE_LAUNCH_LOG="$LAUNCH_LOG" PATH="$FAKEBIN:$PATH" \
  "$ROOT/bin/fm-spawn.sh" live-sm "$SM" --secondmate 2>&1
)
status=$?
echo "secondmate-spawn-exit=$status"
printf '%s\n' "$out" | tail -3
launch=$(cat "$LAUNCH_LOG" 2>/dev/null)
case $launch in
  *--approve*) echo "launch-has-session-approve=yes" ;;
  *) echo "launch-has-session-approve=no" ;;
esac
echo "default-store-exists=$([ -e "$HOME_DIR/user-home/.pi/agent/trust.json" ] && echo YES-BAD || echo no)"
echo "secondmate-store-exists=$([ -e "$SM/.pi/agent/trust.json" ] && echo YES-BAD || echo no)"
echo "$SM" > "$CASE/sm-path"

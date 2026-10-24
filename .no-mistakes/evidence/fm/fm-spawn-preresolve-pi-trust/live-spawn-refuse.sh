#!/usr/bin/env bash
# Live drive of bin/fm-spawn.sh with a real pi CLI and a store that cannot
# record this worktree: the spawn must refuse loudly and send NO launch, so no
# worker is left parked on the trust dialog.
set -u
ROOT=${FM_REPO_ROOT:?}
. "$ROOT/tests/fixtures.sh"
CASE=$(mktemp -d "${TMPDIR:-/tmp}/fm-live-refuse.XXXXXX") || exit 1
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
fm_git_worktree "$PROJ" "$WT" "wt-live-refuse"
fm_test_spawn_brief "$HOME_DIR" live-refuse "refusal must not launch a wedged worker"
STORE=$HOME_DIR/user-home/.pi/agent/trust.json
mkdir -p "$(dirname "$STORE")"

case ${1:-malformed} in
  malformed) printf '[]\n' > "$STORE" ;;
  declined)  printf '{\n  "%s": false\n}\n' "$(cd -P -- "$CASE" && pwd -P)" > "$STORE" ;;
esac
before=$(shasum -a 256 "$STORE")

out=$(
  FM_TEST_SEAM=1 FM_GATE_REFUSE_BYPASS=1 \
  FM_ROOT_OVERRIDE='' FM_HOME="$HOME_DIR" HOME="$HOME_DIR/user-home" CLAUDE_CONFIG_DIR='' \
  FM_STATE_OVERRIDE="$HOME_DIR/state" FM_DATA_OVERRIDE="$HOME_DIR/data" \
  FM_PROJECTS_OVERRIDE="$HOME_DIR/projects" FM_CONFIG_OVERRIDE="$HOME_DIR/config" \
  FM_SPAWN_NO_GUARD=1 FM_FAKE_PANE_PATH="$WT" TMUX="fake,1,0" \
  FM_FAKE_LAUNCH_LOG="$LAUNCH_LOG" PATH="$FAKEBIN:$PATH" \
  "$ROOT/bin/fm-spawn.sh" live-refuse "$PROJ" --mode no-mistakes --yolo off 2>&1
)
status=$?
after=$(shasum -a 256 "$STORE")
echo "case=${1:-malformed} spawn-exit=$status store-untouched=$([ "$before" = "$after" ] && echo yes || echo NO)"
printf '%s\n' "$out" | grep -E 'error:|refusing' | head -5
echo "launch-log-bytes=$(wc -c < "$LAUNCH_LOG" 2>/dev/null || echo 0)"
echo "meta-exists=$([ -f "$HOME_DIR/state/live-refuse.meta" ] && echo yes || echo no)"

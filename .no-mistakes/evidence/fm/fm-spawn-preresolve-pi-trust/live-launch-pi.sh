#!/usr/bin/env bash
# Run the exact launch line the real fm-spawn sent for its pi worktree, in a
# real pty, against the store that spawn wrote (or a fresh HOME as control).
set -u
CASE=${CASE:?}
MODE=${1:?store|control}
WT=$CASE/wt
EV=/Users/qushuai9/.no-mistakes/evidence/01M5PFKWK88267WQH0FWDJYA5K
mkdir -p "$WT/.agents/skills/demo"
printf 'placeholder\n' > "$WT/.agents/skills/demo/SKILL.md"
LAUNCH=$(tail -1 "$CASE/launch.log")
case $MODE in
  store)   HOME_DIR=$CASE/home/user-home ;;
  control) HOME_DIR=$CASE/home/control-home; mkdir -p "$HOME_DIR" ;;
esac
echo "mode=$MODE home=$HOME_DIR"
env -u PI_CODING_AGENT_DIR -u FM_HOME -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE \
  -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE -u TMUX \
  HOME="$HOME_DIR" PTY_COMMAND="$LAUNCH" \
  python3 "$EV/ptydrive.py" "$WT" "$EV/spawn-launch-$MODE.raw" 40 ignored

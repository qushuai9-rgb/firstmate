#!/usr/bin/env bash
# Live driver: run the real bin/fm-teardown.sh against a disposable lab home,
# with the REAL gh client reading a REAL public GitHub pull request.
#
# Usage: drive.sh <close-open|close-merged|close-unreadable|close-closed|retain-open|answer-after-retain>
set -uo pipefail

ROOT=/Users/qushuai9/.no-mistakes/worktrees/be4d97686c7c/01M6BX7AK8EB4456CGTMGQ3RCB
SCENARIO=${1:?scenario}
LAB=$(mktemp -d "${TMPDIR:-/tmp}/fm-lab.XXXXXX") || exit 1
LAB=$(cd "$LAB" && pwd -P)
export LAB
cleanup() { rm -rf "$LAB"; }
trap cleanup EXIT

"$ROOT/bin/fm-lab-home.sh" create "$LAB" >/dev/null || { echo "lab create failed"; exit 1; }
mkdir -p "$LAB/tmux"
FAKEBIN=$LAB/fakebin
mkdir -p "$FAKEBIN"

cat > "$FAKEBIN/treehouse" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat > "$FAKEBIN/tmux" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat > "$FAKEBIN/no-mistakes" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat > "$FAKEBIN/gh-axi" <<'SH'
#!/usr/bin/env bash
case "${1:-} ${2:-}" in
  "pr list") printf '%s\n' "count: 0 (showing first 0)" "pull_requests[]: []" ; exit 0 ;;
  "pr view") echo "error: pull request not found" >&2 ; exit 1 ;;
esac
exit 0
SH
chmod +x "$FAKEBIN/treehouse" "$FAKEBIN/tmux" "$FAKEBIN/no-mistakes" "$FAKEBIN/gh-axi"

BACKLOG=$LAB/data/backlog.md
WT=$LAB/projects/task-x1
PROJECT=$LAB/projects/sample
mkdir -p "$LAB/projects"
git init -q --bare "$LAB/projects/origin.git"
git -C "$LAB/projects/origin.git" symbolic-ref HEAD refs/heads/main
git clone -q "$LAB/projects/origin.git" "$LAB/projects/_seed" 2>/dev/null
git -C "$LAB/projects/_seed" -c user.email=t@t.invalid -c user.name=t \
  commit -q --allow-empty -m "origin baseline"
git -C "$LAB/projects/_seed" push -q origin main
rm -rf "$LAB/projects/_seed"
git clone -q "$LAB/projects/origin.git" "$PROJECT"
git -C "$PROJECT" remote set-head origin main 2>/dev/null || true
git -C "$PROJECT" worktree add -q -b fm/task-x1 "$WT" main
touch "$LAB/state/.last-watcher-beat"

printf '%s\n' \
  'window=firstmate:fm-task-x1' \
  'endpoint_task_id=task-x1' \
  "worktree=$WT" \
  "project=$PROJECT" \
  'kind=ship' \
  'mode=no-mistakes' \
  'spawn_gen=live-drive-task-x1' > "$LAB/state/task-x1.meta"

printf '%s\n' '# Backlog' '' '## In flight' '' '## Queued' '' '## Done' > "$BACKLOG"
tasks-axi add task-x1 "Ship the sample live delivery" --kind ship --file "$BACKLOG" >/dev/null
tasks-axi start task-x1 --file "$BACKLOG" >/dev/null

# Choose the real pull request this run reads, from the live forge.
pick_pr() {  # <open|merged|closed-unmerged>
  local want=$1 json n
  case $want in
    open) json=$(gh pr list --repo cli/cli --state open --limit 20 --json number,url,state) ;;
    merged) json=$(gh pr list --repo cli/cli --state merged --limit 5 --json number,url,state) ;;
    closed-unmerged)
      json=$(gh pr list --repo cli/cli --state closed --limit 60 --json number,url,state,mergedAt \
        | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{const a=JSON.parse(d).filter(p=>p.state==="CLOSED"&&!p.mergedAt);process.stdout.write(JSON.stringify(a.slice(0,5)))})')
      ;;
  esac
  printf '%s\n' "$json" | node -e '
    let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{
      const a=JSON.parse(d);
      const p=a.find(x=>/^https:\/\/github\.com\/[A-Za-z0-9._-]+\/[A-Za-z0-9._-]+\/pull\/[0-9]+$/.test(x.url));
      if(!p){process.exit(3);} process.stdout.write(p.url+"\n");})'
}

FORGE_STATE=
case $SCENARIO in
  close-open) PR=$(pick_pr open) ;;
  close-merged) PR=$(pick_pr merged) ;;
  close-closed) PR=$(pick_pr closed-unmerged) ;;
  close-unreadable) PR="https://github.com/cli/cli/pull/999999999" ;;
  close-noncanonical) PR="https://github.com/o--o/repo/pull/7" ;;
  retain-open|answer-after-retain) PR=$(pick_pr open) ;;
  retain-merged-then-answer) PR=$(pick_pr merged) ;;
  *) echo "unknown scenario $SCENARIO"; exit 2 ;;
esac
[ -n "${PR:-}" ] || { echo "could not pick a live pull request"; exit 3; }

FORGE_STATE=$(gh pr view "$PR" --json state,mergedAt,url -q '.state + " mergedAt=" + ((.mergedAt // "none"))' 2>/dev/null || echo "unreadable")
echo "=== scenario: $SCENARIO"
echo "=== lab home: $LAB"
echo "=== recorded pr: $PR"
echo "=== real forge now reports: $FORGE_STATE"

case $SCENARIO in
  retain-open|answer-after-retain|retain-merged-then-answer)
    # An earlier record already attached the link to the row, and the row is held
    # for the captain, so teardown's transition is the retention, not the close.
    tasks-axi update task-x1 --pr "$PR" --file "$BACKLOG" >/dev/null
    tasks-axi hold task-x1 --reason "captain merge approval pending" --kind captain \
      --file "$BACKLOG" >/dev/null
    ;;
  *)
    if [ "$SCENARIO" = close-open ] || [ "$SCENARIO" = close-closed ] || [ "$SCENARIO" = close-noncanonical ]; then
      tasks-axi update task-x1 --pr "$PR" --file "$BACKLOG" >/dev/null
    fi
    ;;
esac
printf 'pr=%s\n' "$PR" >> "$LAB/state/task-x1.meta"

echo "=== backlog row before teardown"
tasks-axi show task-x1 --file "$BACKLOG" --full

echo "=== running the real teardown"
env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u FM_PROJECTS_OVERRIDE \
FM_HOME="$LAB" \
FM_ROOT_OVERRIDE="$ROOT" \
FM_STATE_OVERRIDE="$LAB/state" \
FM_DATA_OVERRIDE="$LAB/data" \
FM_CONFIG_OVERRIDE="$LAB/config" \
PATH="$FAKEBIN:$PATH" \
  "$ROOT/bin/fm-teardown.sh" task-x1
echo "=== teardown exit: $?"

if [ "$SCENARIO" = answer-after-retain ] || [ "$SCENARIO" = retain-merged-then-answer ]; then
  echo "=== backlog row after the retention"
  tasks-axi show task-x1 --file "$BACKLOG" --full
  printf 'Do not merge this pull request yet; the work is delivered and awaits its merge.\n' > "$LAB/answer.txt"
  echo "=== running the real captain answer"
  env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u FM_PROJECTS_OVERRIDE \
  FM_HOME="$LAB" FM_ROOT_OVERRIDE="$ROOT" \
  FM_STATE_OVERRIDE="$LAB/state" FM_DATA_OVERRIDE="$LAB/data" \
  FM_CONFIG_OVERRIDE="$LAB/config" PATH="$FAKEBIN:$PATH" \
    "$ROOT/bin/fm-captain-hold.sh" answer task-x1 --decision-file "$LAB/answer.txt"
  echo "=== answer exit: $?"
fi

echo "=== backlog row after"
tasks-axi show task-x1 --file "$BACKLOG" --full
echo "=== raw backlog.md"
cat "$BACKLOG"
echo "=== merge-verification record"
ls "$LAB/state" | grep -F '.pr-merge' || echo "(none)"
cat "$LAB/state"/task-x1.pr-merge 2>/dev/null || true
echo "=== pending-close record"
cat "$LAB/state/task-x1.backlog-close" 2>/dev/null || echo "(none)"

#!/usr/bin/env bash
# Disposable live-drive harness for the teardown merge-claim change.
# Stands up a marked fm-lab-* home (bin/fm-lab-home.sh) plus a throwaway git
# project/worktree and a real tasks-axi markdown backlog, then runs the real
# bin/fm-teardown.sh / bin/fm-captain-hold.sh / bin/fm-bootstrap.sh against it.
# Only the external forge (gh/gh-axi) and the desktop tools it does not own
# (treehouse, tmux, no-mistakes) are stubbed; the product scripts, tasks-axi and
# git are real.
set -u
ROOT=$(cd "${1:?repo root}" && pwd -P)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/fm-live.XXXXXX") || exit 1
# The gate lab allowance compares the home with its own `pwd -P` spelling, so
# resolve the physical path once here (macOS /var -> /private/var).
WORK=$(cd "$WORK" && pwd -P) || exit 1
CASES=$WORK/cases
mkdir -p "$CASES"
unset TASKS_AXI_FILE TASKS_AXI_BACKEND
unset NO_MISTAKES_GATE FM_GATE_REFUSE_BYPASS
unset FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE
unset FM_ROOT_OVERRIDE FM_HOME

cleanup_live() { rm -rf "$WORK"; }

say() { printf '\n### %s\n' "$*"; }
cmd() { printf '\n$ %s\n' "$*"; }

make_case() {  # <name> <id> ; echoes case dir
  local name=$1 id=$2 case_dir home fakebin
  case_dir=$CASES/$name
  mkdir -p "$case_dir"
  home=$(FM_GATE_REFUSE_BYPASS= "$ROOT/bin/fm-lab-home.sh" create "$case_dir/home") || return 1
  fakebin=$case_dir/fakebin
  mkdir -p "$fakebin"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$fakebin/treehouse"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$fakebin/tmux"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$fakebin/no-mistakes"
  cat > "$fakebin/gh-axi" <<'SH'
#!/usr/bin/env bash
case "${1:-} ${2:-}" in
  "pr list") printf '%s\n' "count: 0 (showing first 0)" "pull_requests[]: []" ; exit 0 ;;
esac
exit 0
SH
  # Default: the forge cannot be read for this pull request.
  cat > "$fakebin/gh" <<'SH'
#!/usr/bin/env bash
echo "error: pull request not found" >&2
exit 1
SH
  chmod +x "$fakebin/treehouse" "$fakebin/tmux" "$fakebin/no-mistakes" "$fakebin/gh-axi" "$fakebin/gh"

  git init -q --bare "$case_dir/origin.git" || return 1
  git -C "$case_dir/origin.git" symbolic-ref HEAD refs/heads/main
  git clone -q "$case_dir/origin.git" "$case_dir/_seed" 2>/dev/null
  git -C "$case_dir/_seed" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "origin baseline"
  git -C "$case_dir/_seed" push -q origin main
  rm -rf "$case_dir/_seed"
  git clone -q "$case_dir/origin.git" "$case_dir/project"
  git -C "$case_dir/project" remote set-head origin main 2>/dev/null || true
  git -C "$case_dir/project" worktree add -q -b "fm/$id" "$case_dir/wt" main || return 1
  touch "$home/state/.last-watcher-beat"
  printf '%s\n' "$case_dir"
}

forge_reports() {  # <case-dir> <state> <merged-at> [url]
  local case_dir=$1 state=$2 merged_at=$3 url=${4:-https://github.com/example/repo/pull/7}
  cat > "$case_dir/fakebin/gh" <<SH
#!/usr/bin/env bash
case "\${1:-} \${2:-}" in
  "pr view")
    case " \$* " in
      *"state,mergedAt,url"*) printf '%s\t%s\t%s\n' '$state' '$merged_at' '$url' ; exit 0 ;;
      *"state,headRefOid,url"*) printf '%s\t%s\t%s\n' '$state' 'HEAD' '$url' ; exit 0 ;;
    esac
    ;;
esac
echo "error: pull request not found" >&2
exit 1
SH
  chmod +x "$case_dir/fakebin/gh"
}

write_meta() {  # <case-dir> <id> <pr-or-empty>
  local case_dir=$1 id=$2 pr=$3 home=$1/home
  {
    printf 'window=firstmate:fm-%s\n' "$id"
    printf 'endpoint_task_id=%s\n' "$id"
    printf 'worktree=%s\n' "$case_dir/wt"
    printf 'project=%s\n' "$case_dir/project"
    printf 'kind=ship\nmode=no-mistakes\n'
    [ -z "$pr" ] || printf 'pr=%s\n' "$pr"
    printf 'spawn_gen=s%s.1.live%s\n' "$(date +%s)" "$id"
  } > "$home/state/$id.meta"
}

seed_backlog() {  # <case-dir> <id> [--pr url]
  local case_dir=$1 id=$2 home=$1/home
  shift 2
  printf '%s\n' '# Backlog' '' '## In flight' '' '## Queued' '' '## Done' > "$home/data/backlog.md"
  tasks-axi add "$id" "live drive: ship the sample change" --kind ship \
    --file "$home/data/backlog.md" >/dev/null || return 1
  tasks-axi start "$id" --file "$home/data/backlog.md" >/dev/null || return 1
  [ "$#" -eq 0 ] || tasks-axi update "$id" "$@" --file "$home/data/backlog.md" >/dev/null
}

run_teardown() {  # <case-dir> <id> [args]
  local case_dir=$1 id=$2 home
  home=$case_dir/home
  shift 2
  # Only FM_ROOT_OVERRIDE and the marked stock home: the gate-refusal lab
  # allowance accepts no other override, so state/data/config resolve inside the
  # lab home exactly as a real home's do.
  PATH="$case_dir/fakebin:$PATH" FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$ROOT/bin/fm-teardown.sh" "$id" "$@"
}

run_captain() {  # <case-dir> <args...>
  local case_dir=$1 home
  home=$case_dir/home
  shift
  PATH="$case_dir/fakebin:$PATH" FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$ROOT/bin/fm-captain-hold.sh" "$@"
}

run_bootstrap() {  # <case-dir>
  local case_dir=$1 home
  home=$case_dir/home
  PATH="$case_dir/fakebin:$PATH" FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$ROOT/bin/fm-bootstrap.sh"
}

tasks_in() {  # <case-dir> <args...>
  local case_dir=$1
  shift
  tasks-axi "$@" --file "$case_dir/home/data/backlog.md"
}

show_row() {  # <case-dir> <id>
  tasks_in "$1" show "$2"
}

show_row_full() {  # <case-dir> <id>
  tasks_in "$1" show "$2" --full
}

ledger_ledger() {  # <case-dir>
  printf '\n---- ledger (%s) ----\n' "$1/home/data/backlog.md"
  cat "$1/home/data/backlog.md"
}

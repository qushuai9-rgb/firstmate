#!/usr/bin/env bash
# Live drive of the teardown merge-claim change.
# Each scenario runs the real bin/fm-teardown.sh / bin/fm-captain-hold.sh /
# bin/fm-bootstrap.sh from the gate worktree against a disposable, marked lab
# FM_HOME (bin/fm-lab-home.sh) and the real installed tasks-axi CLI, with a real
# git project + worktree. Only the forge HTTP client (gh) and the non-fleet host
# tools (tmux/treehouse/no-mistakes) are disposable stubs on PATH, because this
# host has no credentials for a scratch forge and those tools are not the product
# under test.
set -u

ROOT=${ROOT:-$PWD}
EVID=${EVID:-/Users/qushuai9/.no-mistakes/evidence/01M6E93RTP8V8FKHNSMN28SJYZ}
OUT="$EVID/live"
mkdir -p "$OUT"
FAIL=0
LABS=()

say() { printf '%s\n' "$*" | tee -a "$OUT/transcript.log"; }
note() { printf '%s\n' "$*" >> "$OUT/transcript.log"; }

cleanup_labs() {
  local lab
  [ -f "$OUT/labs.txt" ] || return 0
  while IFS= read -r lab; do
    [ -n "$lab" ] && [ -d "$lab" ] && rm -rf "$lab"
  done < "$OUT/labs.txt"
  : > "$OUT/labs.txt"
}

new_lab() {  # <label>
  local lab
  lab=$(mktemp -d "${TMPDIR:-/tmp}/fm-lab.XXXXXX") || return 1
  "$ROOT/bin/fm-lab-home.sh" create "$lab" >/dev/null || return 1
  lab=$(cd "$lab" && pwd -P) || return 1
  # Callers capture stdout in a subshell, so record the lab in a file the
  # cleanup trap can read rather than an array the subshell cannot update.
  printf '%s\n' "$lab" >> "$OUT/labs.txt"
  printf '%s\n' "$lab"
}

seed_home() {  # <lab> <kind>
  local lab=$1 kind=${2:-ship}
  cat > "$lab/.tasks.toml" <<'EOF'
backend = "markdown"

[markdown]
path = "data/backlog.md"
archive = "data/done-archive.md"
done_keep = 10
EOF
  printf '%s\n' '# Backlog' '' '## In flight' '' '## Queued' '' '## Done' > "$lab/data/backlog.md"
  touch "$lab/state/.last-watcher-beat"
  mkdir -p "$lab/fakebin" "$lab/projects"
  cat > "$lab/fakebin/tmux" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  cat > "$lab/fakebin/treehouse" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  cat > "$lab/fakebin/no-mistakes" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$lab/fakebin/tmux" "$lab/fakebin/treehouse" "$lab/fakebin/no-mistakes"
  : > "$lab/fakebin/gh-axi"
  cat > "$lab/fakebin/gh-axi" <<'SH'
#!/usr/bin/env bash
exit 1
SH
  chmod +x "$lab/fakebin/gh-axi"
  # real project clone + task worktree
  git init -q --bare "$lab/origin.git"
  git -C "$lab/origin.git" symbolic-ref HEAD refs/heads/main
  git clone -q "$lab/origin.git" "$lab/_seed" 2>/dev/null
  git -C "$lab/_seed" -c user.email=t@t -c user.name=t commit -q --allow-empty -m 'origin baseline'
  git -C "$lab/_seed" push -q origin main
  rm -rf "$lab/_seed"
  git clone -q "$lab/origin.git" "$lab/projects/proj"
  git -C "$lab/projects/proj" remote set-head origin main 2>/dev/null || true
  printf '%s\n' 'change from the task branch' > "$lab/projects/proj/wt-file-not-used"
  rm -f "$lab/projects/proj/wt-file-not-used"
  git -C "$lab/projects/proj" worktree add -q -b fm/task-x1 "$lab/wt" main
  printf '%s\n' 'task change' > "$lab/wt/feature.txt"
  git -C "$lab/wt" add -- feature.txt
  git -C "$lab/wt" -c user.email=t@t -c user.name=t commit -q -m 'task feature work'
  # Pushed, so the landed-work gate is satisfied while the PR itself stays open.
  git -C "$lab/wt" push -q origin fm/task-x1
  git -C "$lab/projects/proj" fetch -q origin
  printf 'window=firstmate:fm-task-x1\nendpoint_task_id=task-x1\nworktree=%s\nproject=%s\nkind=%s\nmode=no-mistakes\nspawn_gen=live-drive-task-x1\n' \
    "$lab/wt" "$lab/projects/proj" "$kind" > "$lab/state/task-x1.meta"
}

# Forge doubles: answer the two `gh pr view --json` shapes teardown reads.
forge() {  # <lab> open|merged|closed|unreadable [url] [head]
  local lab=$1 verdict=$2 url=${3:-https://github.com/example/repo/pull/7} head=${4:-}
  case "$verdict" in
    open)
      cat > "$lab/fakebin/gh" <<SH
#!/usr/bin/env bash
case "\$*" in
  *state,mergedAt,url*) printf '%s\t%s\t%s\n' OPEN '' '$url' ; exit 0 ;;
  *state,headRefOid,url*) printf '%s\t%s\t%s\n' OPEN '' '$url' ; exit 0 ;;
esac
exit 1
SH
      ;;
    closed)
      cat > "$lab/fakebin/gh" <<SH
#!/usr/bin/env bash
case "\$*" in
  *state,mergedAt,url*) printf '%s\t%s\t%s\n' CLOSED '' '$url' ; exit 0 ;;
  *state,headRefOid,url*) printf '%s\t%s\t%s\n' CLOSED '' '$url' ; exit 0 ;;
esac
exit 1
SH
      ;;
    merged)
      cat > "$lab/fakebin/gh" <<SH
#!/usr/bin/env bash
case "\$*" in
  *state,mergedAt,url*) printf '%s\t%s\t%s\n' MERGED '2026-06-26T00:00:00Z' '$url' ; exit 0 ;;
  *state,headRefOid,url*) printf '%s\t%s\t%s\n' MERGED '$head' '$url' ; exit 0 ;;
esac
exit 1
SH
      ;;
    unreadable)
      cat > "$lab/fakebin/gh" <<'SH'
#!/usr/bin/env bash
echo "error: HTTP 401: bad credentials" >&2
exit 1
SH
      ;;
  esac
  chmod +x "$lab/fakebin/gh"
}

tasks_in() {  # <lab> <args...>
  local lab=$1
  shift
  (cd "$lab" && tasks-axi "$@")
}

show_row() {  # <lab> [--full]
  local lab=$1
  shift
  tasks_in "$lab" show task-x1 --file "$lab/data/backlog.md" "$@" 2>/dev/null
}

run_teardown() {  # <lab> [args...]
  local lab=$1
  shift
  # Keep the gate/fleet overrides of this agent out of the lab primary's env.
  env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u FM_ROOT_OVERRIDE \
      -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE \
      -u FM_PROJECTS_OVERRIDE \
      PATH="$lab/fakebin:$PATH" FM_HOME="$lab" \
      "$ROOT/bin/fm-teardown.sh" "$@"
}

record() {  # <scenario> <result> [detail]
  local scenario=$1 result=$2 detail=${3:-}
  say "RESULT $scenario: $result${detail:+ - $detail}"
  [ "$result" = pass ] || FAIL=1
}

# --- scenario 1: open pull request closes as a completion ---------------------
scenario_open_pr() {
  local lab url out row show
  url=https://github.com/example/repo/pull/7
  lab=$(new_lab) || { record teardown-open-pr fail "lab creation failed"; return; }
  seed_home "$lab"
  forge "$lab" open "$url"
  tasks_in "$lab" add task-x1 'teardown fixture task' --kind ship --file "$lab/data/backlog.md" >/dev/null
  tasks_in "$lab" start task-x1 --file "$lab/data/backlog.md" >/dev/null
  tasks_in "$lab" update task-x1 --pr "$url" --file "$lab/data/backlog.md" >/dev/null
  printf 'pr=%s\n' "$url" >> "$lab/state/task-x1.meta"

  out=$(run_teardown "$lab" task-x1 2>&1) || { say "$out"; record teardown-open-pr fail "teardown exited nonzero"; return; }
  note "$out"
  row=$(cat "$lab/data/backlog.md")
  show=$(show_row "$lab" --full)
  printf '%s\n' "$row" > "$OUT/scenario1-backlog.md"
  printf '%s\n' "$show" > "$OUT/scenario1-show.txt"
  say "--- rendered backlog (open PR) ---"; say "$row"
  case "$row" in *'(merged '*) record teardown-open-pr fail "closed row rendered as merged"; return ;; esac
  case "$show" in *'state: done'*) ;; *) record teardown-open-pr fail "row was not closed"; return ;; esac
  case "$show" in *"pr:$url"*) record teardown-open-pr fail "unverified pr link stayed structured"; return ;; esac
  case "$show" in *'still open when this finished'*) ;; *) record teardown-open-pr fail "note did not state the pending merge"; return ;; esac
  record teardown-open-pr pass "done with the link kept in the body note"
}

# --- scenario 2: a merge the forge reports is still recorded ------------------
scenario_merged_pr() {
  local lab url head out row
  url=https://github.com/example/repo/pull/7
  lab=$(new_lab) || { record teardown-merged-pr fail "lab creation failed"; return; }
  seed_home "$lab"
  head=$(git -C "$lab/wt" rev-parse HEAD)
  forge "$lab" merged "$url" "$head"
  tasks_in "$lab" add task-x1 'teardown fixture task' --kind ship --file "$lab/data/backlog.md" >/dev/null
  tasks_in "$lab" start task-x1 --file "$lab/data/backlog.md" >/dev/null
  printf 'pr=%s\npr_head=%s\n' "$url" "$head" >> "$lab/state/task-x1.meta"

  out=$(run_teardown "$lab" task-x1 2>&1) || { say "$out"; record teardown-merged-pr fail "teardown exited nonzero"; return; }
  note "$out"
  row=$(cat "$lab/data/backlog.md")
  printf '%s\n' "$row" > "$OUT/scenario2-backlog.md"
  say "--- rendered backlog (merged PR) ---"; say "$row"
  case "$row" in *'(merged '*) ;; *) record teardown-merged-pr fail "confirmed merge was not recorded"; return ;; esac
  show=$(show_row "$lab" --full)
  printf '%s\n' "$show" > "$OUT/scenario2-show.txt"
  case "$show" in *"links: \"pr:$url\""*) ;; *) record teardown-merged-pr fail "pr link missing from the merged row"; return ;; esac
  # The durable per-task merge fact is written while the row is open and retired
  # with the landed close, so a plain merged close leaves no file behind; the
  # rendered row above is the observable proof that the merge was read.
  record teardown-merged-pr pass "the forge-reported merge still records merged with its pr link"
}

# --- scenario 3: unreadable forge is not a merge ------------------------------
scenario_unreadable() {
  local lab url out row show
  url=https://github.com/example/repo/pull/7
  lab=$(new_lab) || { record teardown-unreadable fail "lab creation failed"; return; }
  seed_home "$lab"
  forge "$lab" unreadable
  tasks_in "$lab" add task-x1 'teardown fixture task' --kind ship --file "$lab/data/backlog.md" >/dev/null
  tasks_in "$lab" start task-x1 --file "$lab/data/backlog.md" >/dev/null
  printf 'pr=%s\n' "$url" >> "$lab/state/task-x1.meta"

  out=$(run_teardown "$lab" task-x1 2>&1) || { say "$out"; record teardown-unreadable fail "teardown exited nonzero"; return; }
  note "$out"
  row=$(cat "$lab/data/backlog.md")
  show=$(show_row "$lab" --full)
  printf '%s\n' "$row" > "$OUT/scenario3-backlog.md"
  say "--- rendered backlog (forge read fails) ---"; say "$row"
  case "$row" in *'(merged '*) record teardown-unreadable fail "unreadable state was recorded as merged"; return ;; esac
  case "$show" in *'state: done'*) ;; *) record teardown-unreadable fail "row was not closed"; return ;; esac
  case "$show" in *'pull request state could not be read'*) ;; *) record teardown-unreadable fail "note did not state the unreadable read"; return ;; esac
  record teardown-unreadable pass "done with a read-failure note"
}

# --- scenario 4 (adversarial): a URL tasks-axi renders merged but the gate
# cannot classify must never be passed as --pr --------------------------------
scenario_renderer_accepted_url() {
  local lab url out row show direct
  url=https://github.com/o--o/repo/pull/7
  lab=$(new_lab) || { record renderer-accepted-url fail "lab creation failed"; return; }
  seed_home "$lab"
  forge "$lab" unreadable
  tasks_in "$lab" add task-x1 'teardown fixture task' --kind ship --file "$lab/data/backlog.md" >/dev/null
  tasks_in "$lab" start task-x1 --file "$lab/data/backlog.md" >/dev/null
  printf 'pr=%s\n' "$url" >> "$lab/state/task-x1.meta"
  # Prove the renderer really does print "(merged ...)" for this shape when it is
  # passed as a pr argument, so the scenario exercises the real hazard.
  tasks_in "$lab" add render-check-x1 'renderer check row' --kind ship --file "$lab/data/backlog.md" >/dev/null
  tasks_in "$lab" start render-check-x1 --file "$lab/data/backlog.md" >/dev/null
  tasks_in "$lab" update render-check-x1 --pr "$url" --file "$lab/data/backlog.md" >/dev/null
  tasks_in "$lab" done render-check-x1 --file "$lab/data/backlog.md" >/dev/null
  direct=$(cat "$lab/data/backlog.md")
  printf '%s\n' "$direct" > "$OUT/scenario4-renderer-hazard.md"
  case "$direct" in *"$url"*"(merged "*) ;; *) record renderer-accepted-url fail "tasks-axi did not render this shape as merged, so the hazard is not being exercised"; return ;; esac
  # Retire the throwaway hazard row so it cannot pollute the assertions below.
  tasks_in "$lab" rm render-check-x1 --file "$lab/data/backlog.md" >/dev/null 2>&1 || true

  out=$(run_teardown "$lab" task-x1 2>&1) || { say "$out"; record renderer-accepted-url fail "teardown exited nonzero"; return; }
  note "$out"
  row=$(cat "$lab/data/backlog.md")
  show=$(show_row "$lab" --full)
  printf '%s\n' "$row" > "$OUT/scenario4-backlog.md"
  say "--- rendered backlog (renderer-accepted URL) ---"; say "$row"
  task_line=$(printf '%s\n' "$row" | grep -F -- '- [x] task-x1 ' || true)
  case "$task_line" in *'(merged '*) record renderer-accepted-url fail "unclassifiable link was recorded as merged"; return ;; esac
  case "$show" in *"pr:$url"*) record renderer-accepted-url fail "unclassifiable link stayed a structured pr link"; return ;; esac
  case "$show" in *"$url"*) ;; *) record renderer-accepted-url fail "link was dropped instead of noted"; return ;; esac
  record renderer-accepted-url pass "kept as an unconfirmed note, never a merge"
}

# --- scenario 5: a captain-held retention keeps the link off the title -------
scenario_retain() {
  local lab url out row show title
  url=https://github.com/example/repo/pull/7
  lab=$(new_lab) || { record teardown-retain fail "lab creation failed"; return; }
  seed_home "$lab"
  forge "$lab" open "$url"
  tasks_in "$lab" add task-x1 'retain fixture task' --kind ship --file "$lab/data/backlog.md" >/dev/null
  tasks_in "$lab" start task-x1 --file "$lab/data/backlog.md" >/dev/null
  tasks_in "$lab" update task-x1 --pr "$url" --file "$lab/data/backlog.md" >/dev/null
  tasks_in "$lab" hold task-x1 --reason 'captain merge approval pending' --kind captain \
    --file "$lab/data/backlog.md" >/dev/null
  printf 'pr=%s\n' "$url" >> "$lab/state/task-x1.meta"

  out=$(run_teardown "$lab" task-x1 2>&1) || { say "$out"; record teardown-retain fail "teardown exited nonzero"; return; }
  note "$out"
  row=$(cat "$lab/data/backlog.md")
  show=$(show_row "$lab" --full)
  title=$(show_row "$lab" | sed -n 's/^  title: *//p' | head -1)
  printf '%s\n' "$row" > "$OUT/scenario5-backlog.md"
  say "--- rendered backlog (captain-held retention) ---"; say "$row"
  case "$(show_row "$lab" | sed -n 's/^  state: *//p' | head -1)" in
    queued) ;;
    *) record teardown-retain fail "held row was not retained"; return ;;
  esac
  case "$row" in *'(merged '*) record teardown-retain fail "retained row rendered as merged"; return ;; esac
  case "$show" in *"pr:$url"*) record teardown-retain fail "retained row kept an unverified pr link"; return ;; esac
  case "$title" in *"$url"*) record teardown-retain fail "url survived on the title"; return ;; esac
  case "$show" in *'Deliverable of the finished work:'*"$url"*) ;; *) record teardown-retain fail "deliverable did not keep the url"; return ;; esac
  record teardown-retain pass "held row retains the deliverable, not a pr link"
}

# --- scenario 6: the captain's answer closes that row without a merge, and the
# retained deliverable note appears once -------------------------------------
scenario_answer() {
  local lab url out row show body_count
  url=https://github.com/example/repo/pull/7
  lab=$(new_lab) || { record captain-answer fail "lab creation failed"; return; }
  seed_home "$lab"
  forge "$lab" open "$url"
  tasks_in "$lab" add task-x1 'retain fixture task' --kind ship --file "$lab/data/backlog.md" >/dev/null
  tasks_in "$lab" start task-x1 --file "$lab/data/backlog.md" >/dev/null
  tasks_in "$lab" update task-x1 --pr "$url" --file "$lab/data/backlog.md" >/dev/null
  tasks_in "$lab" hold task-x1 --reason 'captain merge approval pending' --kind captain \
    --file "$lab/data/backlog.md" >/dev/null
  printf 'pr=%s\n' "$url" >> "$lab/state/task-x1.meta"
  out=$(run_teardown "$lab" task-x1 2>&1) || { say "$out"; record captain-answer fail "retention failed"; return; }
  note "$out"

  printf 'Do not merge this pull request yet.\n' > "$lab/answer.txt"
  out=$(env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u FM_ROOT_OVERRIDE \
           -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE \
           -u FM_PROJECTS_OVERRIDE PATH="$lab/fakebin:$PATH" FM_HOME="$lab" \
           "$ROOT/bin/fm-captain-hold.sh" answer task-x1 --decision-file "$lab/answer.txt" 2>&1) \
    || { say "$out"; record captain-answer fail "the answer failed"; return; }
  note "$out"
  row=$(cat "$lab/data/backlog.md")
  show=$(show_row "$lab" --full)
  printf '%s\n' "$row" > "$OUT/scenario6-backlog.md"
  say "--- rendered backlog (captain answer) ---"; say "$row"
  case "$show" in *'state: done'*) ;; *) record captain-answer fail "answer did not close the row"; return ;; esac
  case "$row" in *'(merged '*) record captain-answer fail "answer closed as a merge nobody read"; return ;; esac
  case "$show" in *"pr:$url"*) record captain-answer fail "answer kept an unverified pr link"; return ;; esac
  case "$show" in *"$url"*) ;; *) record captain-answer fail "answer dropped the delivery url"; return ;; esac
  # The latest commit's fix: the deliverable-shaped note the retention recorded
  # is not written a second time by the answer.
  body_count=$(grep -o 'Delivered, merge not confirmed' <<<"$show" | wc -l | tr -d ' ')
  [ "$body_count" = 1 ] || { record captain-answer fail "the completion sentence appears $body_count times"; return; }
  record captain-answer pass "answer closes as done, keeps the url, and records the sentence once"
}

# --- scenario 7: the pending-close record carries punctuation byte-for-byte and
# still refuses a line break ------------------------------------------------
scenario_note_codec() {
  local lab url note staged replay_row out rc
  lab=$(new_lab) || { record pending-close-note-codec fail "lab creation failed"; return; }
  seed_home "$lab"
  tasks_in "$lab" add task-x1 'codec fixture task' --kind ship --file "$lab/data/backlog.md" >/dev/null
  tasks_in "$lab" start task-x1 --file "$lab/data/backlog.md" >/dev/null
  note="Delivered, it's (not) merged: #1 at 50% *pending*!"

  # Stage the record through the real transition library, exactly as teardown
  # does, with a note carrying ordinary punctuation.
  out=$(FM_HOME="$lab" bash -c '
    set -u
    . "$1/bin/fm-tasks-axi-lib.sh"
    . "$1/bin/fm-backlog-transition-lib.sh"
    fm_backlog_close_marker_write "$2/state" task-x1 "$2/data" live-drive-task-x1 --note "$3" || exit 1
    printf "STAGED\n"
  ' _ "$ROOT" "$lab" "$note" 2>&1) || { say "$out"; record pending-close-note-codec fail "staging a punctuation note was refused"; return; }
  printf '%s\n' "$out" > "$OUT/scenario7-stage.txt"
  cat "$lab/state/task-x1.backlog-close" >> "$OUT/scenario7-stage.txt"

  # Replay it through the real session-start reconciler against the real
  # tasks-axi CLI; the closed body must carry the note byte-for-byte.
  out=$(env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u FM_ROOT_OVERRIDE \
           -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE \
           -u FM_PROJECTS_OVERRIDE PATH="$lab/fakebin:$PATH" FM_HOME="$lab" \
           FM_BOOTSTRAP_NETWORK=skip "$ROOT/bin/fm-bootstrap.sh" 2>&1)
  rc=$?
  note "$out"
  printf '%s\n' "$out" > "$OUT/scenario7-replay.txt"
  replay_row=$(show_row "$lab" --full)
  printf '%s\n' "$replay_row" >> "$OUT/scenario7-replay.txt"
  say "--- replayed row (punctuation note) ---"; say "$replay_row"
  [ "$rc" -eq 0 ] || { record pending-close-note-codec fail "session start replay exited $rc"; return; }
  case "$replay_row" in *'state: done'*) ;; *) record pending-close-note-codec fail "replay did not close the row"; return ;; esac
  case "$replay_row" in *"$note"*) ;; *) record pending-close-note-codec fail "the replayed note is not byte-identical"; return ;; esac

  # A value that would forge a second line is still refused, loudly.
  out=$(FM_HOME="$lab" bash -c '
    set -u
    . "$1/bin/fm-tasks-axi-lib.sh"
    . "$1/bin/fm-backlog-transition-lib.sh"
    fm_backlog_close_marker_write "$2/state" task-x1 "$2/data" live-drive-task-x1-newline --note "$(printf "line one\narg=--pr\nline two")" || exit 7
    exit 1
  ' _ "$ROOT" "$lab" 2>&1)
  rc=$?
  printf '%s\n' "$out" > "$OUT/scenario7-newline-refusal.txt"
  [ "$rc" -eq 7 ] || { record pending-close-note-codec fail "a line-breaking note was accepted (rc=$rc)"; return; }
  record pending-close-note-codec pass "punctuation round-tripped and a line break stayed refused"
}

main() {
  : > "$OUT/transcript.log"
  : > "$OUT/labs.txt"
  say "worktree: $ROOT"
  say "tasks-axi: $(command -v tasks-axi) ($(tasks-axi --version 2>/dev/null | head -1))"
  say "git: $(git --version)"
  local selected=("$@")
  local fn
  if [ "${#selected[@]}" -eq 0 ]; then
    scenario_open_pr; scenario_merged_pr; scenario_unreadable
    scenario_renderer_accepted_url; scenario_retain; scenario_answer
    scenario_note_codec
  else
    for fn in "${selected[@]}"; do "$fn"; done
  fi
  cleanup_labs
  say "OVERALL: $([ "$FAIL" = 0 ] && echo pass || echo fail)"
  [ "$FAIL" = 0 ]
}

main "$@"

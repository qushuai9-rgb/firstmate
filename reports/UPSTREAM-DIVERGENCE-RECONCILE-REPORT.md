# Upstream divergence reconciliation evidence

## Branch and ancestry

- Branch: `fm/fm-upstream-divergence-reconcile`.
- Current commit: see the completion status line; it includes this report relocation and update.
- The compatibility implementation commit is `549928a7d888e4098248ab998becbb2dd20f4340` (`route-B: add upstream compatibility symbols required by unretained callers`), parent `220dbf565e75780cc3a67e79d128bcab18bc18ae`.
- `git merge-base --is-ancestor 220dbf56 HEAD`: passed before the report relocation; the final commit remains a descendant of `220dbf56`.
- Local `main`: `220dbf565e75780cc3a67e79d128bcab18bc18ae` (unchanged).
- `HEAD..origin/main`: 0; `origin/main..HEAD`: 78 at the time checked. This remote-tracking count is not a count of local-only commits relative to `main`.
- The final branch must be clean; status is recorded after the report commit.
- Relative to `220dbf56`, the compatibility implementation changes the two libraries described below; report-only commits also add and relocate this evidence.

## Compatibility additions

`bin/fm-wake-lib.sh` adds the compatibility entry points `fm_recovery_marker_handover_snapshot`, `fm_recovery_marker_handover_restore`, `fm_local_firstmate_state_dirs`, and `fm_wake_queue_prune_task`, and retains `fm_wake_rows_queued`. The already-defined `fm_watcher_stall_bound` remains defined at its original upstream-compatible location; a duplicate addition was removed before commit.

`bin/fm-classify-lib.sh` adds `status_declared_wait_line`, `status_stamp_width`, `status_has_open_needs_decision`, and `status_scan_parent_channel_exclude`.

## Runtime verification

A temporary home isolated under `mktemp` used the actual `bin/fm-tasks-axi.sh` and installed `tasks-axi`. The command sequence `add proof-backlog-route` -> `start proof-backlog-route` -> `done proof-backlog-route` printed:

```text
ok: added proof-backlog-route (ship) -> Queued
ok: start proof-backlog-route -> In flight
ok: done proof-backlog-route -> Done
  title: proof item
  state: done
```

The temporary home was removed after the run. No `fm_local_firstmate_state_dirs: command not found` diagnostic occurred.

`bash tests/fm-pending-reply.test.sh` passed all 46 cases, including the real `fm-send --resolve-key` operator-close exercise. No `FM_LINE_CAP_DEFAULT - : syntax error` occurred.

`bash -n` passed for all 198 `bin/*.sh` scripts. `shellcheck bin/fm-wake-lib.sh bin/fm-classify-lib.sh` exited successfully; it emitted existing informational SC1091/SC2094 notes and one SC2034 warning on the new output variable `FM_LOCAL_FIRSTMATE_ERROR`.

## Accepted audit and unverified coverage

The captain accepted the route-B 51-file A/B/C conflict audit together with the compatibility symbols as the conflict-resolution deliverable; the earlier 21-file conflict inventory is superseded and is not required. The detailed 51-file A/B/C listing is not reproduced in this report.

The lexical candidate-call scan across `bin/*.sh` is not treated as exhaustive: dynamic sourcing, indirect calls, command substitutions, and ordinary command words make that scan produce false positives. The captain accepted the runtime-path evidence below in place of an exhaustive static function-symbol inventory.

The full suite of 249 `tests/*.test.sh` suites was not run and is explicitly unverified. The run covered `tests/fm-pending-reply.test.sh` only. No claim is made about unrun suite results or baseline failures.

## Delivery boundary

No push, PR, `main` mutation, watcher action, or production metadata edit was performed.

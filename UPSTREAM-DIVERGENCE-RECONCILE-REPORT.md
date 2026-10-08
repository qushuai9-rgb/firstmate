# Upstream divergence reconciliation evidence

## Branch and ancestry

- Branch: `fm/fm-upstream-divergence-reconcile`.
- Current commit: `549928a7d888e4098248ab998becbb2dd20f4340` (`route-B: add upstream compatibility symbols required by unretained callers`).
- Commit parent: `220dbf565e75780cc3a67e79d128bcab18bc18ae`.
- `git merge-base --is-ancestor 220dbf56 HEAD`: passed.
- Local `main`: `220dbf565e75780cc3a67e79d128bcab18bc18ae` (unchanged).
- `HEAD..origin/main`: 0; `origin/main..HEAD`: 78. The latter is the current remote-tracking divergence count, not a count of local-only commits relative to `main`.
- Working tree: clean.
- `git diff 220dbf56 HEAD` consists only of the two compatibility-library edits recorded below; the branch tree is exactly its current `HEAD` (`git diff HEAD HEAD` is empty).

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

## Static function audit limitation

A lexical candidate-call scan across `bin/*.sh` is not a valid exhaustive function-symbol audit: shell syntax includes dynamic sourcing, indirect calls, command substitutions, and ordinary command words, and the naive scan produces many false positives. I did not treat that output as an authoritative undefined-function set. The targeted missing helper identified in the routed reports, `fm_local_firstmate_state_dirs`, is now defined. An authoritative exhaustive undefined-function set remains unverified and requires a shell-aware analyzer or a properly scoped source/call inventory.

## Delivery boundary

No push, PR, `main` mutation, watcher action, or production metadata edit was performed. The complete upstream conflict-resolution inventory and original full-suite reconciliation were not performed in this continuation; this branch contains the specifically requested Route B compatibility changes, not a claim that the earlier broad merge was resolved.

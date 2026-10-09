# Secondmate home startup self-identification

## Root cause and fix

The relaunch was not giving the secondmate a deterministic role identity or a role-scoped launch brief. The worker therefore had only home content to infer its role from; an `AGENTS.md` primary-home template could incorrectly suggest that it was the primary Firstmate. A charter copy alone was insufficient.

`bin/fm-spawn.sh` now creates secondmate launch instructions that prepend an explicit secondmate role/home/charter boundary to the charter, publishes that record in the secondmate home, and launches with `FM_ROLE=secondmate` and `FM_SECONDMATE_CHARTER` explicitly set. The primary session-start nudge and run scripts stand down for a marked secondmate home, and the Pi turn-end extension skips primary session-start behavior for the explicit secondmate role. These changes make launch identity and primary-startup exclusion explicit at their owners rather than adding a second charter contract.

## Reproduction

The reported minimal reproduction is a secondmate home identified by `.fm-secondmate-home` (value `quant-researcher`) with the primary-template `AGENTS.md` and a charter at `data/quant-researcher/brief.md`, followed by `bin/fm-control.sh quant-researcher relaunch --note-file <note>` where the task metadata says `kind=secondmate`.

Reported original session output:

> this session is the main firstmate, not the quant-researcher secondmate
>
> This session is running in the primary Firstmate home, not the quant-researcher secondmate home

The report also records that the session spoke directly to the captain. No production secondmate home, metadata, or watcher was changed during this task. Automated regression coverage constructs the launch and startup cases; the real relaunch remains to be verified on site.

## Replay and validation

The task commits were replayed without conflicts first onto `220dbf565e75780cc3a67e79d128bcab18bc18ae`, then onto current main `e102417030f0435023517211ce0faf236defaa3a`. There were no conflict resolutions.

Baseline comparison required by follow-up: in a detached temporary worktree at `e1024170`, `./bin/fm-test-run.sh tests/fm-session-start.test.sh` failed at the same `pi diagnostic trusted a handoff marker left by an absent replacement extension` assertion, expecting `PI_WATCH_EXTENSION: not loaded`. On the task branch rebased to `e1024170`, the exact command fails at the same assertion with the same expected substring. Thus this is a pre-existing baseline failure, not introduced by this patch.

Passed:

- `./bin/fm-test-run.sh tests/fm-spawn-dispatch-profile.test.sh` — exit 0; launch regression output includes the secondmate role/home/charter and primary startup boundaries.

Failed, reproducibly on two runs:

- `./bin/fm-test-run.sh tests/fm-session-start.test.sh` — 1 test script failed at `pi diagnostic trusted a handoff marker left by an absent replacement extension` (expected `PI_WATCH_EXTENSION: not loaded`). The remaining test output shown before that point passed or was explicitly skipped for unavailable `/proc`. This failure concerns the Pi watcher-generation marker assertion, not the secondmate-specific assertions. The assertion was not weakened or changed.

Still unverified: a real `fm-control.sh ... relaunch` in the quant-researcher secondmate home now receives the correct role/charter and no longer runs the primary startup path. This requires the main Firstmate to perform the separately authorized on-site validation.

## Rebased tree evidence

After the report commit, verify on the task branch:

- `git merge-base --is-ancestor e1024170 HEAD`
- `git diff HEAD` is empty
- `git rev-parse main` is `e102417030f0435023517211ce0faf236defaa3a`; main was not changed by this task.

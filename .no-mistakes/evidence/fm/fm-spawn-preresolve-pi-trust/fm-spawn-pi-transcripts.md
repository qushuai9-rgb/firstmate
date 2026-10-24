# Live `bin/fm-spawn.sh` pi spawn transcripts (real spawn, disposable lab home)

The real `bin/fm-spawn.sh` from this branch is driven end to end against a
disposable firstmate home, git project, and linked task worktree. The only
stand-in is the tmux pane (`fm_test_make_spawn_fakebin` in `tests/fixtures.sh`
records the exact command spawn would send) - the same seam this repository's
own spawn suites use - so no real pane is started. Everything under test here
(worktree creation, trust pre-registration, launch-line construction) is the
real product code.

The spawn's `HOME` is disposable, so `bin/fm-pi-trust.sh` can only write a
throwaway store.

## Unpinned pi spawn (no `config/pi-account`)

```
$ FM_FAKE_LAUNCH_LOG=launch.log fm_test_run_spawn home wt fakebin <task> <project> --mode no-mistakes --yolo off
```

```
spawn exit=0
--- spawn stdout ---
warning: /var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/spawncase-45642/home/data/drive-pi-spawn-z9/launch-brief.md records no ship branch; defaulting to legacy branch fm/drive-pi-spawn-z9
warning: /var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/spawncase-45642/home/data/drive-pi-spawn-z9/launch-brief.md records no delivery contract line (scaffolded before ship briefs recorded one); launching on the explicit --mode no-mistakes - confirm its definition of done matches
spawned drive-pi-spawn-z9 harness=pi kind=ship mode=no-mistakes yolo=off window=firstmate:fm-drive-pi-spawn-z9 worktree=/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/spawncase-45642/wt
--- captured launch command ---
export COMPACT_ADVISER_DISABLE=1; export FM_TASK_INBOX='/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/spawncase-45642/home/state/drive-pi-spawn-z9.inbox'; '/Users/qushuai9/.no-mistakes/worktrees/be4d97686c7c/01M5R26GK0K7W5V7WYH33JJBJG/bin/fm-git-strip-ai-trailers.sh' env-file '/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/spawncase-45642/home/state/drive-pi-spawn-z9.git-hooks' '/tmp/fm-drive-pi-spawn-z9+1614662740377d867ff9943252b73175136bc6929795c85f85d583f6ab2e9498/git-config.s1792885640.45874.30417.sh' && . '/tmp/fm-drive-pi-spawn-z9+1614662740377d867ff9943252b73175136bc6929795c85f85d583f6ab2e9498/git-config.s1792885640.45874.30417.sh' || return 1 2>/dev/null || exit 1; env -u CURSOR_AGENT -u CURSOR_INVOKED_AS -u GEMINI_CLI -u PI_CODING_AGENT_DIR FM_PI_HARNESS=pi '/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/spawncase-45642/fake/fakebin/pi' --tui-mode regular -e '/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/spawncase-45642/home/state/drive-pi-spawn-z9.pi-ext.ts' "$('/Users/qushuai9/.no-mistakes/worktrees/be4d97686c7c/01M5R26GK0K7W5V7WYH33JJBJG/bin/fm-operational-input.sh' encode launch-brief < '/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/spawncase-45642/home/data/drive-pi-spawn-z9/launch-brief.md')"
--- spawn HOME trust store ---
/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/spawncase-45642/home/user-home/.pi/agent/trust.json
{
  "/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/spawncase-45642/wt": true
}

--- worktree key canonical? ---
[
  '/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/spawncase-45642/wt'
]
/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/spawncase-45642/wt
```

What this proves:

* spawn exits 0 and reports the task worktree;
* the launch line carries `env -u CURSOR_AGENT -u CURSOR_INVOKED_AS -u GEMINI_CLI -u PI_CODING_AGENT_DIR`,
  so the worker deterministically reads `$HOME/.pi/agent`; the ambient-agent-root
  capture in the dialog evidence shows the trust dialog returns without that unset;
* the store written is the spawn `HOME`'s default `$HOME/.pi/agent/trust.json`,
  keyed by the canonical (realpath) worktree path and by nothing else.

## Worker-account-pinned pi spawn (`config/pi-account`)

```
$ printf '%s\n%s\n' "$C/piwork" openai-codex > home/config/pi-account
$ FM_FAKE_LAUNCH_LOG=launch.log fm_test_run_spawn home wt fakebin <task> <project> --mode no-mistakes --yolo off --model openai-codex/gpt-5
```

```
spawn exit=0
warning: /var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/pincase-47283/home/data/pin-pi-spawn-z8/launch-brief.md records no ship branch; defaulting to legacy branch fm/pin-pi-spawn-z8
warning: /var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/pincase-47283/home/data/pin-pi-spawn-z8/launch-brief.md records no delivery contract line (scaffolded before ship briefs recorded one); launching on the explicit --mode no-mistakes - confirm its definition of done matches
spawned pin-pi-spawn-z8 harness=pi kind=ship mode=no-mistakes yolo=off window=firstmate:fm-pin-pi-spawn-z8 worktree=/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/pincase-47283/wt account=/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/pincase-47283/piwork account_provider=openai-codex
--- launch line env prefix ---
--- pinned trust store ---
{
  "/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/pincase-47283/wt": true
}
--- default store ---
(none at default root)
```

Launch-line facts for the pinned case:

* `-u PI_CODING_AGENT_DIR` occurrences in the launch line: 0 (the unset is conditional on no pin)
* assignment kept on the launch line: `PI_CODING_AGENT_DIR='<pinned root>'`
* env prefix: `env -u CURSOR_AGENT -u CURSOR_INVOKED_AS -u GEMINI_CLI FM_PI_HARNESS=pi`

What this proves: a pinned launch keeps its own root on the line, registers trust
in that pinned root only, and writes nothing to the default root.

## Relaunch idempotency

Registering the same worktree a second time reports `already trusted:` and leaves
the store byte-identical (see the CLI transcript evidence).

# Pi project-trust pre-registration: live evidence (pi 0.84.2)

Goal under test: a freshly spawned pi crewmate must start its first turn in a new
worktree without anyone pressing Enter on "Trust project folder?".

All runs used disposable lab directories under $TMPDIR, a disposable Pi agent
root (never `~/.pi`), and were torn down afterwards. The operator's real
`~/.pi/agent/trust.json` hash was identical before and after every run
(`d6fd05c1...634c`). Only the machine's existing Pi login was borrowed (copied
read-only into the lab agent root) for the full-turn proof; no credential was
modified.

## A/B on the real pi TUI (plain `bin/fm-pi-trust.sh`, real login)

Fresh linked worktree holding `.agents/skills`, fresh agent root, no trust entry:

`baseline-unregistered.txt`

```
 Trust project folder?
 /private/var/folders/.../fm-pi-live.M21NAD/slot
 → Trust
   Trust parent folder (/private/var/folders/.../fm-pi-live.M21NAD)
   Trust (this session only)
   Do not trust
   Do not trust (this session only)
 ↑↓ navigate  enter select  escape/ctrl+c cancel
```

25 s with no keypress: no model turn, no store written. This is the reported
loss (worker静置零产出).

Then `bin/fm-pi-trust.sh --agent-dir <lab agent> <worktree> <project>` printed
`trusted: /private/.../slot` and wrote:

```
{
  "/private/var/folders/.../fm-pi-live.M21NAD/slot": true
}
```

Relaunch of the same real `pi` in the same worktree (no keypress at all):

`after-registration-start.txt`

```
 pi v0.84.2
 [Skills] autoresearch-create, ...
 Reply with exactly READY and nothing else.
 ⠋ Working...
 READY
```

No trust dialog was rendered; the worker went straight into its turn and
answered.

## The real spawn's own launch line (real `bin/fm-spawn.sh`, real pi CLI)

`live-spawn-pi.sh` ran a ship spawn for a pi crewmate with the real `pi` on PATH
(only the tmux pane transport is a stub on this host, so the launch command is
captured instead of executed). Spawn exit 0; the store it wrote before launch:

`spawn-store.txt`

```
{
  "/private/var/folders/.../fm-live-spawn-pi.TWxeAm/wt": true
}
```

The exact launch line it sent (`spawn-launch-line.txt`) contains no
`--approve`, exactly like an ordinary pi crewmate launch, and names no
`PI_CODING_AGENT_DIR`, so the worker reads the default `<home>/.pi/agent` store
that was written.

Running that captured launch line in a real pty:

- with a fresh HOME (control, no store): `spawn-launch-control.txt` shows the
  same "Trust project folder?" menu, parked.
- with the spawn's store plus the machine login: `spawn-launch-working.txt`
  shows the TUI loading the worktree's project resources
  (`live-pi-trust.pi-ext.ts`, `.agents/skills`) with NO dialog, the encoded
  launch brief rendered, and the worker starting its turn
  ("Let me understand the task. I'm a crewmate ...").

## Adversarial / boundary checks

`live-trust-adversarial.log` drives the real script:

- exact "Do not trust" entry -> exit 1, names store+path, store byte-identical;
- inherited "Do not trust" above the worktree -> exit 1, store byte-identical;
- inherited "trusted" ancestor -> `already trusted`, no write;
- fresh registration preserves unrelated `true`/`false`/`null` entries and adds
  exactly the one worktree path;
- primary checkout, worktree subdirectory, plain directory, home, `/`, and
  project `/` are each refused with a named reason and no store write;
- malformed store (`[]`) -> loud refusal, store byte-identical.

`live-spawn-refuse.log`: with a malformed store and with an inherited decline,
the real spawn exits 1 with
`refusing to launch a pi worker that would wedge on the trust dialog`, sends no
launch (no launch log at all) and publishes no task meta.

`live-spawn-pinned.log`: a pi crewmate pinned through `config/pi-account` to a
worker-account root registered the worktree in THAT root's `trust.json` only
(the default `<home>/.pi/agent` store stayed absent) and the launch line names
the same pinned root that received the entry.

`secondmate-no-store.log`: a pi secondmate spawn keeps the session-only
`--approve` and writes NO persistent trust store (neither the default store nor
the secondmate home), as the scope guard requires.

## Runner wiring

`test-runner-wiring.log`: `bin/fm-test-run.sh --list --lane` shows both new
suites selected by the runner - `tests/fm-pi-trust.test.sh` and
`tests/fm-pi-trust-live-e2e.test.sh` each appear in exactly one
`portable-serial-*` shard, so CI will actually execute them.

## Repository suites driven

- `tests/fm-pi-trust-live-e2e.test.sh` (default-on live guard against the
  installed package): all 5 checks pass, output matches the recorded block in
  `docs/verification/runtime-backends.md` - `pi-trust-live-e2e.log`.
- `tests/fm-pi-trust.test.sh`: 18 behavior checks pass - `pi-trust-portable.log`.
- `tests/fm-spawn-dispatch-profile.test.sh`: 100 checks pass, including the pi
  worker/secondmate launch shapes and the HOME isolation the review round added;
  real store hash unchanged - `spawn-dispatch-profile.log`.
- `tests/fm-worker-account.test.sh`: 16 checks pass including the pinned-root
  Pi trust store - `worker-account.log`.

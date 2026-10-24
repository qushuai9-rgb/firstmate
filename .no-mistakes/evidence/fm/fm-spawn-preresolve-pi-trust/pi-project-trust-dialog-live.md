# Live Pi trust-gate evidence (real pi 0.84.2 TUI, disposable lab home)

Lab: `/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF` (throwaway, removed at the end of this run). HOME=`/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/home`,
PI_CODING_AGENT_DIR unset, so Pi used its default `$HOME/.pi/agent` store.
Driven through a pty with a 120x44 grid (TIOCSWINSZ set before Pi read it), so
the TUI really rendered. No model turns were submitted; the trust gate is
decided before any turn.

## 1. Before `bin/fm-pi-trust.sh`: real Pi renders the dialog

```
cd /var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/slot
env -u PI_CODING_AGENT_DIR HOME=/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/home pi
```

Rendered screen (ANSI stripped for readability; `captures/*.txt` are the raw pty bytes):

```
[>7u────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

 Trust project folder?
 /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/slot

 This allows pi to load .pi settings and resources, install missing project packages, and execute project extensions.

 → Trust
   Trust parent folder (/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF)
   Trust (this session only)
   Do not trust
   Do not trust (this session only)

 ↑↓ navigate  enter select  escape/ctrl+c cancel

────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
```

The unattended worker would wedge here: nobody at the window can press Enter.

## 2. Register, then the same real Pi starts straight into its session

```
env -u PI_CODING_AGENT_DIR HOME=/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/home bin/fm-pi-trust.sh /var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/slot /var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/project
cat /var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/home/.pi/agent/trust.json
```

Output of the registration was:

```
trusted: /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/slot
{
  "/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/slot": true
}
```

Relaunching the same command produced no dialog, loaded the project skill tree,
and reached the normal session UI (`captures/pi-tui-after-registration.txt`):

```
6:0.0%/0 (auto)                                                                                                    unknown
 pi v0.84.2
12:[Skills]
13:  demo
```

"Trust project folder?" occurrences: **0**

## 3. Adversarial: an ambient agent root resurrects the dialog

The unpinned launch line is what makes the store deterministic. Pointing
PI_CODING_AGENT_DIR at another (unregistered) root for the *same registered
worktree* brings the dialog back:

```
mkdir -p /var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/decoy-agent
cd /var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/slot
env PI_CODING_AGENT_DIR=/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/decoy-agent HOME=/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/home pi
```

```
[>7u────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

 Trust project folder?
 /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/slot

 This allows pi to load .pi settings and resources, install missing project packages, and execute project extensions.

 → Trust
   Trust parent folder (/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF)
   Trust (this session only)
```

That is exactly why `bin/fm-spawn.sh` adds `-u PI_CODING_AGENT_DIR` to an
unpinned pi/pi-signed launch line (proved in the fm-spawn transcript evidence).

## 4. Pinned worker account root is the store the worker reads

Registered with `--agent-dir`, then Pi launched with that root exported: no
dialog, and the project's own `.agents/skills` tree was loaded (Pi even
reported the fixture skill as a candidate), so the pinned store is the one Pi
consulted.

```
env -u PI_CODING_AGENT_DIR HOME=/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/policy/pin/home bin/fm-pi-trust.sh \
  --agent-dir /var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/policy/pin/agent /var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/policy/pin/wt /var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/policy/pin/proj
# -> trusted: /var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/policy/pin/wt   (nothing written to $HOME/.pi/agent)

cd /var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/policy/pin/wt
env PI_CODING_AGENT_DIR=/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/policy/pin/agent HOME=/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/policy/pin/home pi
```

```
dialog occurrences: 0
12:[Skill conflicts]
13-  /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/policy/pin/wt/.agents/skills/demo/SKILL.md
14-    description is required
15-
```

## 5. Operator policy `defaultProjectTrust: "never"` (last commit's wording fix)

```
HOME=/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/policy/never/home bin/fm-pi-trust.sh .../wt .../proj
fm-pi-trust: .../settings.json sets defaultProjectTrust to "never", so Pi declines
project trust for .../wt and renders no dialog; nothing was written, and that
worker starts without the project settings, project extensions, and project
skills it would otherwise load
exit=0    trust.json absent
```

Real Pi under that policy renders **no dialog at all** and loads **no project
skills** — the state the diagnostic now describes (`captures/pi-tui-policy-never.txt`):

```
dialog occurrences: 0
[Skills] section present: 0
```

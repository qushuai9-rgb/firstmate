# Live `bin/fm-pi-trust.sh` CLI transcripts (disposable lab)

Every case below runs the real script from this branch against a disposable git
project + linked worktree and a disposable `HOME`. No operator store or home is
touched.

## defaultProjectTrust: "never" -> no write, explicit diagnostic
$ HOME=... bin/fm-pi-trust.sh wt proj
```
fm-pi-trust: /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/policy/never2/home/.pi/agent/settings.json sets defaultProjectTrust to "never", so Pi declines project trust for /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/policy/never2/wt and renders no dialog; nothing was written, and that worker starts without the project settings, project extensions, and project skills it would otherwise load
exit=0
```

trust.json written? NO

## defaultProjectTrust: "always" -> no write, correct report
$ HOME=... bin/fm-pi-trust.sh wt proj
```
fm-pi-trust: /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/policy/always2/home/.pi/agent/settings.json sets defaultProjectTrust to "always", so Pi already trusts /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/policy/always2/wt and nothing was written
exit=0
```

trust.json written? NO

## absent / "ask" -> registers the worktree; relaunch is a no-op
$ HOME=... bin/fm-pi-trust.sh wt proj
```
trusted: /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/policy/ask2/wt
exit=0
```

```
{
  "/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/policy/ask2/wt": true
}
```

$ HOME=... bin/fm-pi-trust.sh wt proj   # relaunch
```
already trusted: /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/policy/ask2/wt
exit=0
```

## a recorded "Do not trust" is refused, never reversed
$ HOME=... bin/fm-pi-trust.sh wt proj
```
error: /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/policy/decl2/home/.pi/agent/trust.json records "Do not trust" for /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/policy/decl2/wt, which Pi applies to /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/policy/decl2/wt; refusing to reverse a decision the operator already made. Change or remove the /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/policy/decl2/wt entry in /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/policy/decl2/home/.pi/agent/trust.json to allow this spawn
error: refusing to pre-register Pi trust: could not record trust for '/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/policy/decl2/wt' in '/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/policy/decl2/home/.pi/agent/trust.json'
exit=1
```

```
{"/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/policy/decl2/wt": false}
```

## a trusted ancestor means no write at all
$ HOME=... bin/fm-pi-trust.sh wt proj
```
already trusted: /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/policy/anc2/wt
exit=0
```

```
{"/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF": true}
```

## unrelated store entries are preserved; the write is sorted pretty JSON
$ HOME=... bin/fm-pi-trust.sh wt proj
```
trusted: /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/policy/keep2/wt
exit=0
```

```
{
  "/another/declined": false,
  "/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/policy/keep2/wt": true,
  "/some/other/checkout": true,
  "/third/undecided": null
}
```

## malformed settings.json refuses loudly instead of meaning "never"
$ HOME=... bin/fm-pi-trust.sh wt proj
```
error: /private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/policy/bad2/home/.pi/agent/settings.json is not valid JSON, so defaultProjectTrust is unknown
error: refusing to pre-register Pi trust: could not record trust for '/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/policy/bad2/wt' in '/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/policy/bad2/home/.pi/agent/trust.json'
exit=1
```

trust.json written? NO

## scope refusals (adversarial): every non-worktree target is refused, store untouched
$ HOME=... bin/fm-pi-trust.sh /var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/policy/scope2/wt/sub /var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/policy/scope2/proj
```
error: refusing to pre-register Pi trust: '/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/policy/scope2/wt/sub' is not a worktree root (its root is '/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/policy/scope2/wt')
exit=1
```

$ HOME=... bin/fm-pi-trust.sh /var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/policy/scope2/proj /var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/policy/scope2/proj
```
error: refusing to pre-register Pi trust: '/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/policy/scope2/proj' is a primary checkout, not an isolated worktree
exit=1
```

$ HOME=... bin/fm-pi-trust.sh /var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/policy/scope2/plain /var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/policy/scope2/proj
```
error: refusing to pre-register Pi trust: '/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/policy/scope2/plain' is not inside a git repository
exit=1
```

$ HOME=... bin/fm-pi-trust.sh /var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/policy/scope2/home /var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/policy/scope2/proj
```
error: refusing to pre-register Pi trust: '/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/policy/scope2/home' is the home directory, not a task worktree
exit=1
```

$ HOME=... bin/fm-pi-trust.sh / /var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T//fm-lab.EfqxWF/policy/scope2/proj
```
error: refusing to pre-register Pi trust: '/' is the filesystem root, not a task worktree
exit=1
```

$ HOME=... bin/fm-pi-trust.sh <worktree of project A> <project B>
```
error: refusing to pre-register Pi trust: '/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/policy/scope2/wt' is not a worktree of project '/private/var/folders/py/8hh37cyd35q6pqybdtgst_pr0000gn/T/fm-lab.EfqxWF/policy/other2/proj2'
exit=1
```

$ HOME=... bin/fm-pi-trust.sh --agent-dir rel/agent wt proj
```
error: refusing to pre-register Pi trust: the Pi agent root 'rel/agent' is a relative path, so the store the worker reads cannot be guaranteed to be the one written here; set it to an absolute path
exit=1
```

trust.json written by any refusal? NO

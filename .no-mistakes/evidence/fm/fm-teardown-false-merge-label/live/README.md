# Live validation: teardown may not record a merge it did not read

Every scenario below drives the real product (`bin/fm-teardown.sh`,
`bin/fm-captain-hold.sh`, and the installed `tasks-axi` 0.2.6) inside a
disposable lab home minted with `bin/fm-lab-home.sh create`, with the **real**
`gh` client reading a **real** public GitHub pull request. No forge stub is
involved: the transcripts record what the real forge reported at that moment
(`=== real forge now reports: ...`) next to what the ledger row was written as.

Reproduce any scenario with `bash drive.sh <scenario>` (macOS/linux, `gh` logged
in). The lab home is removed by the driver's exit trap.

| Scenario | Real forge state | Ledger row written | Link kept |
| --- | --- | --- | --- |
| `close-open` — ship task whose PR is still open, link already on the row | `OPEN mergedAt=none` | `(done 2026-11-02)` + "still open when this finished" note | body note, `links: none` |
| `close-closed` — PR closed without merging | `CLOSED mergedAt=none` | `(done ...)` + "closed without being merged" note | body note, `links: none` |
| `close-unreadable` — forge cannot resolve the PR | unreadable | `(done ...)` + "state could not be read" note | body note, `links: none` |
| `close-merged` — forge reports the merge | `MERGED mergedAt=2026-10-30T18:24:32Z` | `(merged 2026-11-02)` | `pr:` link kept |
| `close-noncanonical` — link the renderer accepts but the strict parser refuses (`/o--o/…`) | unreadable (never read) | `(done ...)` + read-failure note | body note, `links: none` |
| `retain-open` — captain-held row, open PR | `OPEN mergedAt=none` | row stays queued/held, deliverable note keeps the URL, no PR link | body note, `links: none` |
| `answer-after-retain` — captain answers that retained row | `OPEN mergedAt=none` | `(done ...)`, note kept **once** | body note, `links: none` |
| `retain-merged-then-answer` — counter-guard: verified merge on a retained row | `MERGED mergedAt=...` | `(merged ...)`, `pr:` link kept | `pr:` link kept |

`close-open` and `close-closed` attach the link to the row *before* teardown runs,
which is exactly the pre-fix state that used to render `(merged <date>)` for a
pull request that had not merged.

Targeted suites run in the same pass (`suites.txt`): `tests/fm-teardown.test.sh`
160 passed / 0 failed, `tests/fm-backlog-atomicity.test.sh` 111 / 0,
`tests/fm-captain-hold-lifecycle.test.sh` 82 / 0, all exit 0.

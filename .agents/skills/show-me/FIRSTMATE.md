# Firstmate delivery adaptation for `show-me`

This is firstmate's own text; it is not part of the upstream skill body.
Read [UPSTREAM.md](../../../skills/show-me/UPSTREAM.md) for provenance and license.

The vendored public body at `skills/show-me/SKILL.md` - kept byte-for-byte identical to upstream and never edited locally - states how to communicate visually: skip the preamble, pick the smallest view that makes the point, and use one view type per judgement.
Its forced-load injection reaches only that `SKILL.md`, which is why this note links out rather than assuming a reader has seen either file.
It ends by telling the reader to write an HTML file and open it in a browser with `Bash(open …)`.
A captain instruction on 2026-10-06 settled that last step: the artifact is written into the main firstmate home and its path is reported, with no rasterising step, no image tool, and no messaging endpoint involved.
This file replaces the delivery surface and nothing else.
It does not change which view to pick or when a view earns its cost.

## 1. Delivery surface: the HTML artifact in the main home

Rule: the artifact is the delivery.
Write one self-contained HTML file under this home's ignored `data/` as `show-me-<topic>-<YYYYMMDD>.html` - no external stylesheet, font, script, or network fetch, so it opens offline - and put its path in the chat reply beside a one-line statement of what it shows.
Delete the previous artifact for the same topic when a newer one replaces it.

Separation anchor SHOWME-NOTE-ONLY: this line appears only in this working note, never in the skill body, so a probe can tell the two files apart.

Reduced form, only when the captain has no way to open a file: say so plainly, then give the node list, the edge list, and the open questions in short lines.

## 2. Which view answers which judgement

Each view type helps exactly one kind of judgement; producing two for the same question is the cost the upstream skill warns about.
These three bindings are the ones worth spending a picture on in this fleet.

| Judgement in front of you | View | Checkpoints the view must expose |
|---|---|---|
| A collection, measurement, or time-anchor defect ("the number is wrong", "the event is missing", "the mark landed out of order") | Sequence diagram over pseudocode | Was the write committed before it was read; primary or cache; did the event fire before or after the commit; was a version or revision compared at all |
| Reviewing a PR with no CI backing it | Diff shape plus risk path, per the upstream `diff` bullet | New entry point, then the permission check, then the write, then any outbound message, then cache invalidation, then the failure branch |
| A choice the captain has to make between options (a threshold, a setting, a variant) | Comparison view, delivered as the artifact's table with only the deciding rows echoed in chat - never a long markdown wall | The options as columns, the consequence of each, and which option each row rules out |

Static views miss dynamic behaviour and failure paths, which is exactly where this fleet's defects have been living.
So a view is navigation, not approval: label every node you did not personally verify as **to confirm**, and keep that label visible in the fallback text too.
A view with unverified nodes drawn as settled is worse than no view, because it reads like a verdict.

## 3. Cost discipline

Extra standing instructions are not free; the upstream author's own estimate is that a prompt budget raises reasoning cost noticeably, and firstmate's experience agrees.

- This skill stays manual-only.
  Upstream ships `disable-model-invocation: true` and firstmate keeps it; measured on the installed harness, that flag keeps the skill out of the system prompt entirely, so it costs context only when a human invokes it.
- Do not wire it into the supervision chain, do not add it to any per-turn briefing, and do not reference it from a generated worker brief.
  If it ever needs to be reachable automatically, that is a deliberate decision to pay the per-session tax, not a convenience.
- Trial window: two weeks on medium-complexity work, judging one view type at a time.
  Keep the view types that measurably prevented a rework; delete the ones that did not, using the removal note below.
- Removing the whole thing is one step: delete `.agents/skills/show-me/`.
  There is no script, no config entry, no installer hook, and no state file, so deletion leaves no residue.
  Deleting only the public `skills/show-me/` directory stops installation but leaves this loaded adaptation standing.

## 4. How to invoke it, and what is measured

This file is a working note for the adaptation in [SKILL.md](SKILL.md); section 4 of that file owns the invocation routes.
Read them together rather than trusting either alone, because SKILL.md now carries the honest labels and the failed discoverability probe.

Facts kept here because they were actually run against the installed harness:

- Skill loading excludes any skill whose frontmatter sets `disable-model-invocation: true` from the system prompt; confirmed from the harness's own skills documentation and its loader, which filters on that flag. That is why this skill costs context only when a human invokes it.
- A forced load injects only the `SKILL.md` of the matched skill directory; sibling files such as this one arrive only if read explicitly. Every cross-reference is therefore a link, never an assumption.
- Invocation keys on the **leading token** of the message: `/skill:show-me` must come first, and prose that merely names it loads nothing.
- Registration and discovery are separate claims: with no registration the command resolves to nothing, while a registered copy injects its body.
- Explicit `--skill <path>` loading was measured to start and complete cleanly.

Unverified combinations; do not describe these as supported until they are actually run:

- Whether an internal `.agents/skills/show-me/` copy is discovered in a real session - see SKILL.md section 5, which records the probes that returned nothing and why they do not settle the question.
- Whether `/skill:show-me` resolves inside a live interactive firstmate pane; every measurement used non-interactive runs against project copies.
- Any harness other than pi: claude, codex, opencode, grok, kimi, cursor, omp and the rest named in the supervisor contract were not exercised for this skill.
- Whether `chrome-devtools-axi` or the interactive board tool is present in a given session; neither was available in the sessions that wrote these notes.
- Rendering quality at realistic diagram sizes, and how a wide single-page artifact reads on a phone; only the small proof-of-concept PNG was measured, and the pixel surface itself is no longer part of the rule.

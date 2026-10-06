---
name: show-me
description: >-
  Use when a captain-facing answer needs structure before prose - an "I can't read this" complaint, a collection, measurement, or time-anchor defect to explain, a PR review with no CI backing it, or a set of options the captain has to pick between.
  Applies the vendored upstream show-me judgement in skills/show-me/SKILL.md and replaces only its delivery surface, writing the view as a self-contained HTML artifact under the main firstmate home.
  Manual-only: it stays out of every automatic round and is never wired into supervision.
user-invocable: true
metadata:
  internal: true
disable-model-invocation: true
---

# show-me (firstmate internal adaptation)

Body anchor SHOWME-BODY-TOKEN: this visible line exists only inside this file, never in the working note beside it, so a probe can tell which of the two arrived.

This is firstmate's own text; it is not part of the upstream skill body.
Read [skills/show-me/UPSTREAM.md](../../../skills/show-me/UPSTREAM.md) for provenance and license.

The judgement - which view answers which question, and whether a view earns its cost - lives verbatim in the vendored [skills/show-me/SKILL.md](../../../skills/show-me/SKILL.md).
That file is kept byte-for-byte identical to upstream and must never be edited locally.
This file replaces **only** the delivery surface and binds the three view types to this fleet's work.

## 1. Delivery surface: an HTML artifact in the main home

Captain instruction (2026-10-06) replaced the earlier pixel-and-messaging surface.
The view now ships as one HTML artifact written under the main firstmate home, and the chat reply points at it.
No rasterising step, no image tool, and no messaging endpoint is required or attempted.
The superseded surface sent pixels through a chat bridge, so a bridge fault could block a view; that dependency is gone.

Rule: the artifact is the delivery.
Write it where this home keeps private artifacts, name it `show-me-<topic>-<YYYYMMDD>.html`, keep it self-contained - no external stylesheet, font, script, or network fetch - so it opens offline, and give the path in the chat reply next to a one-line statement of what it shows.
A dense single-page view is the goal; a view that needs a server or a build step is not.

The artifact lands under this home's already-ignored `data/`, so it never dirties a checkout and never blocks a landing.
When a newer artifact replaces an older one for the same topic, delete the older file instead of accumulating a series.

Reduced form, used only when the captain has no way to open the file: say that plainly, then give the node list, the edge list, and the open questions in short lines.

## 2. Which view answers which judgement

Each view type helps exactly one kind of judgement; producing two for the same question is the cost upstream warns about.
These are the bindings worth spending a picture on in this fleet.

| Judgement in front of you | View | Checkpoints the view must expose |
|---|---|---|
| A collection, measurement, or time-anchor defect ("the number is wrong", "the event is missing", "the mark landed out of order") | Sequence diagram over pseudocode | Was the write committed before it was read; primary or cache; did the event fire before or after the commit; was a version or revision compared at all |
| Reviewing a PR with no CI backing it | Diff shape plus risk path, per the upstream `diff` bullet | New entry point, then the permission check, then the write, then any outbound message, then cache invalidation, then the failure branch |
| A choice the captain has to make between options (a threshold, a setting, a variant) | Comparison view, delivered as the artifact's table with the deciding rows echoed in chat - never a long markdown wall | The options as columns, the consequence of each, and which option each row rules out |

Static views miss dynamic behaviour and failure paths, which is where this fleet's defects have been living.
So a view is navigation, not approval: label every node you did not personally verify as **to confirm**, and keep that label visible in the fallback text too.
A view drawn with unverified nodes as settled is worse than no view, because it reads like a verdict.

## 3. Cost discipline

Extra standing instructions are not free; upstream's own estimate is a noticeable rise in reasoning cost, and firstmate's experience agrees.

- This skill stays manual-only.
  Upstream ships `disable-model-invocation: true` and this adaptation keeps it unchanged, in the public body and here.
  Measured on the installed harness: the flag keeps the skill out of the system prompt entirely, so it costs context only when a human invokes it.
- Do not wire it into the supervision chain, do not add it to any per-turn briefing, and do not reference it from a generated worker brief.
  If it ever needs to be reachable automatically, that is a deliberate decision to pay the per-session tax, not a convenience.
- Trial window: two weeks on medium-complexity work, judging one view type at a time.
  Keep the view types that measurably prevented a rework; delete the ones that did not.
- Switching it off is one step: delete `.agents/skills/show-me/`.
  There is no script, no config entry, no installer hook, and no state file, so deletion leaves no residue.
  Deleting only the public copy stops installation but leaves this loaded surface standing.

## 4. How to invoke it, and what remains unverified

Measured facts about the installed harness (see [docs/verification/show-me-skill-pi.md](../../../docs/verification/show-me-skill-pi.md) for the probe records):

- **Route 1, an internal `.agents/skills/` directory - measured; see section 5 for what was compared.**
  pi's own skills documentation lists `.agents/skills/` in the working directory and its ancestors, recursing into directories that contain `SKILL.md`, as a project skill location loaded only after the project is trusted.
  The adaptation lives here because that is the documented loaded surface. It has been observed loading in a scripted project and in a control run from this repository; the interactive pane is still unmeasured, and section 5 states exactly which evidence supports which claim.
- A packaged `skills/` directory is a separate documented route: pi's packages documentation states that when no `pi` manifest is present, `skills/` recursively yields `SKILL.md` folders and top-level `.md` files as skills.
  So calling a repository-root `skills/` directory undiscoverable would be wrong: it is not a *project-trust* location, but it is a package resource location.
- The three routes this repo names are, each with its own status: an internal `.agents/skills/` directory (**measured**: forced load injected the discovered body against an unexpanded empty-project control), a `settings.json` `skills` array pointing at a skill directory (documentation-only), and an explicit `--skill <path>` (**measured**: a non-interactive run pointed at this repo's public directory started and completed cleanly).
  Do not describe an unlabelled combination as supported.
- Invocation keys on the **leading token** of the message: `/skill:show-me` must come first, and prose that merely names it loads nothing.
- Registration and discovery are different claims: a copy can be installed and still not resolve until something registers it.
- A forced load injects only `SKILL.md`; sibling files arrive only if read explicitly.
  This file is self-contained on purpose, and links out to the public body rather than depending on a sibling being read.

## 5. Discoverability: measured, with the false readings kept visible

Ruling 1a required a real invocation record before calling this installed. It now has one.

Measured, in a throwaway git project holding only this directory, reading back the harness's own message stream rather than asking a model about its context:

- Forcing `/skill:show-me` delivered a block starting `<skill name="show-me" location=".../.agents/skills/show-me/SKILL.md">`, and carried this file's visible body anchor, so the text came from the discovered file.
- The identical command in a project with no skills directory passed through unexpanded. Without that negative control the positive proves nothing.
- An ordinary prompt showed no `show-me` entry in the skill listing, so manual-only still taxes sessions nothing.
- One forced invocation produced a real minimal view: nodes, edges, missing edges drawn explicitly, and unverified nodes labelled `to confirm`, opening by admitting it was the reduced text form with no image delivered.
- Loading the body did not drag this directory's working note along; each file carries its own anchor precisely so that stays checkable.

Three instruments failed before those results, and their failures are the reason the claims above are phrased narrowly:

- A model asked whether a token appears in its own message said YES to a token existing nowhere. Self-description is not a probe.
- A marker inside an HTML comment was invisible to injection and echoed by the question, so it could only ever answer YES.
- Reading the first record of the stream picked up the input echo instead of the delivered message, and serialized content arrays escape their quotes; a real load read as missing until both were fixed.

Bounded by trust: project `.agents/skills/` directories are collected only for a trusted project, and the runs above passed a one-run trust flag. This repository's path already has a saved decision, and a plain run there listed its internal skills. What is still unproven is the interactive pane: no live TUI session watched the command resolve.

Unverified; do not advertise until actually run:

- How the captain's own viewing surface renders a wide single-page artifact on a phone; the artifact is written and pointed at, and its readability there is unmeasured.
- The superseded pixel surface is no longer part of the rule, so the earlier chat-bridge measurements are history rather than a current claim.
- Any harness besides pi: claude, codex, opencode, grok, kimi, cursor, omp and the rest named in the supervisor contract were not exercised for this skill.
- Whether the interactive decision board tool is present in a given session; it was unavailable in the sessions that produced these records, which is why it is not a ranked surface above.
- Rendering quality at realistic diagram sizes, and whether an attached HTML file previews usefully on a phone.

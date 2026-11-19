# Ledger fact freshness

This page is the convention for private operational ledgers - a home's `data/backlog.md` most of all - whose entries can go stale on their own as the world changes around them.
It covers the capital ledger files firstmate keeps for its own operations, not the machine-readable activity ledger that `docs/fleet-ledger.md` owns.
A ledger entry is a record of a decision or a task, not maintained documentation, so nothing here turns a private ledger into a published surface.

## The problem

Some ledger entries are true when written and false later.
The ones that decay are those whose text rests on an outside fact: a pull request that has not merged yet, a service that will be loaded later, a file that does not exist yet, a fix that is still absent from the branch.
Pure waiting entries do not decay this way - an entry that says to act after a given date is a queue position, and time passing is what it wants.

A reader who takes an old premise as a current one dispatches work against the world as it was, and the loss is silent: the entry still reads as authoritative because nothing in it marks the claim as provisional.

## The marker

An entry whose text depends on an outside fact carries one line naming that dependency:

```
Review premise: <the premise as originally written> -> 现状：<what is actually true now>（核验日期 YYYY-MM-DD）
```

The marker records what must be rechecked, never proof that the claim is still true.
Carry the premise in the entry's own words rather than a paraphrase, so a later reader can tell what the author actually believed.
Keep both the original text and the current reading: the entry is a history, and deleting the false premise destroys the evidence that the dependency moved.

When the current reading contradicts the premise, the marker is a correction and not to be patched over.
Replace the false claim with what the check found, keep the original visible as superseded, and record the date the check ran.
Never edit only one of two places that state the same fact; the copies drift the moment one is touched.

## When the entry has no date field for it

Where the ledger's existing date field already means a deadline, reuse it.
Never invent new date syntax, and never reinterpret a creation date as an expiry.
An entry that needs a date the format does not carry states the recheck date inside its marker line instead.

The convention does not require a schedule: it requires that no entry decays without saying what it depends on.

## The pre-dispatch check

Before a ledger fact becomes the premise of dispatched work, check it against the world in that same turn.
State in the delivery whether the check reproduced the premise or not, in those terms.
A premise nobody rechecked is not evidence, and an entry whose premise was never checked cannot be cited as a reason to build, to wait, or to claim a defect is still open.

This obligation binds whoever dispatches, not the worker who receives the brief: a brief that inherits an unverified premise has already published that premise as fact.

## Private ledgers are not in the repository

Each home's `data/` directory is private and gitignored, so a ledger edit produces no commit and no pull request.
A task whose deliverable is a ledger edit therefore hands back a change list - entry identifier, original premise text, current evidence, whether the marker was applied - and the home that owns the ledger applies it.
A worker cannot report a ledger edit as a completed change of the repository, and running a task in an isolated copy of this repository shows it a tracked placeholder `data/backlog.md` rather than any home's real ledger.

Locate entries by their identifier, never by line number.
Line numbers shift as soon as any entry above them is added or resolved, so an inventory keyed to line numbers is wrong before it is read.

## The limit of searching for the marker

One grep finds the entries that already carry the marker:

```sh
grep -rn 'Review premise:' data/backlog.md data/learnings.md data/captain.md
```

It cannot find the entries that are stale and unmarked, and no expression can: a ledger's entries are multiline prose without a uniform one-line boundary, the marker's absence says nothing about whether an entry decays, and the existing date fields do not uniformly mean expiry.
Do not treat that search as a stale-entry audit, and do not claim a complete inventory from it.
A grep-only completeness rule would first need a uniform entry boundary and an explicit deadline field that means the same thing in every ledger; neither exists here.

## What can actually be checked mechanically

Two things can be checked without deciding whether an unmarked entry has decayed, and both need one canonical branch because the marker text is prose:

- Every entry carrying the marker states a recheck date in the documented form.
- No dispatch cites a premise whose marker is older than the recheck cadence the home adopts.

Anything beyond that is a judgement about the world - whether a pull request merged, whether a service loaded, whether a file appeared - so it is performed by a live check in the turn that needs the answer, not asserted from the entry.

#!/usr/bin/env bash
# Shared watcher marker identity. Source this library, then call window_key
# with one backend endpoint to obtain its filename suffix.
#
# Every per-window watcher marker consumes this ONE derivation. SHA-256 of the
# endpoint bytes with a `v3.` prefix bounds the suffix to 67 ASCII bytes, leaving
# room for marker prefixes within a 255-byte filename. The dot cannot occur in a
# legacy key; legacy and v2 evidence is ignored, never migrated or revived.
# Identity depends only on endpoint bytes, never on other recorded windows.
# docs/configuration.md's watcher-marker upgrade note owns the intentional
# one-time cache reset and its notification-only effects.
#
# window_marker_prefixes is THE inventory of the per-window marker families, and
# window_marker_names renders one window's whole set from it. Every consumer that
# has to enumerate a window's markers reads the inventory rather than repeating
# the family list: a family missing from a copy outlives the window it belongs to,
# and the timer it leaves behind keeps ageing against a window nobody supervises.
#
# Two key forms exist and both must be retired with a finished endpoint. Window
# names ARE reused (tmux pins `fm-<id>` and a re-dispatched task keeps its id), so
# a leftover marker is read as the next incarnation's own, and no watcher will
# ever write the legacy form again - only cleanup that knows the endpoint is
# finished can ever prove such a file dead:
#   - window_key: the current `v3.` suffix, which the watcher and away daemon
#     write every family under today;
#   - window_key_legacy: the pre-migration suffix that only turned `:` and `/`
#     and `.` into `_`. A home upgraded across that change still carries these
#     files, which only a boundary that knows the endpoint is finished can ever
#     retire. That form is unbounded, so a long endpoint's legacy name can exceed
#     NAME_MAX; no such file can exist, and window_marker_names omits it rather
#     than hand callers a name rm must refuse.
#
# These families are collected automatically at both boundaries: bin/fm-spawn.sh
# clears every family for the endpoint it is about to run in, and
# bin/fm-teardown.sh retires a finished endpoint's whole family, including its
# legacy form, then prunes legacy-form families no recorded endpoint owns. The
# manual procedure below is what remains for a home whose boundaries were both
# skipped. For optional cleanup, stop both the watcher and away daemon, then
# archive the obsolete files outside STATE (or remove the reviewed files). Limit
# this to the per-window marker families window_marker_prefixes prints. Preserve
# every current filename containing -v3.; only legacy/v2 suffixes in those
# families are obsolete.
# Do not bulk-clear STATE: task records, wake queues, and task-keyed .subsuper-*
# markers are outside this cleanup. Leaving obsolete files in place is safe.
window_key() {  # <window>
  local digest
  if command -v shasum >/dev/null 2>&1; then
    digest=$(printf '%s' "$1" | shasum -a 256)
  else
    digest=$(printf '%s' "$1" | sha256sum)
  fi
  printf 'v3.%s' "${digest%% *}"
}

# window_key_legacy: the pre-migration suffix for the same endpoint. Kept as the
# one owner of that form so cleanup never re-derives it inline and drifts from
# what an upgraded home's files actually carry.
window_key_legacy() {  # <window>
  local key=${1//:/_}
  key=${key//\//_}
  printf '%s' "${key//./_}"
}

# window_marker_prefixes: every per-window marker family filename prefix, one
# per line, without the leading dot and without the key. Sorted longest-family-
# first where one prefix is a prefix of another, so a caller that resolves a
# filename by prefix does not need to know the overlap.
window_marker_prefixes() {
  printf '%s\n' \
    hash \
    count \
    stale-since \
    stale \
    churn-since \
    dead-reported \
    wedge-escalations \
    wedge-permanent \
    wedge-terminal-queued \
    wedge-rollback-failed \
    paused-rechecked \
    paused-resurfaced \
    paused \
    waiting-resurfaced \
    writing-since \
    writing-resurfaced \
    validating-since \
    validating-resurfaced \
    guard-deferrals \
    model-stream-episode
}

# window_marker_names: every per-window marker filename for ONE endpoint, one
# per line with no directory, in both key forms. A legacy name that would exceed
# NAME_MAX is omitted: the form is unbounded, so a supported long endpoint can
# reach it, and a file that long cannot exist to be removed. Callers join these
# with the state directory they own.
window_marker_names() {  # <window>
  local win=$1 current legacy prefix name
  local LC_ALL=C
  [ -n "$win" ] || return 1
  current=$(window_key "$win") || return 1
  legacy=$(window_key_legacy "$win")
  [ -n "$legacy" ] && [ "$legacy" != "$current" ] || legacy=
  while IFS= read -r prefix; do
    [ -n "$prefix" ] || continue
    printf '.%s-%s\n' "$prefix" "$current"
    [ -z "$legacy" ] || {
      name=".$prefix-$legacy"
      [ "${#name}" -le 255 ] || continue
      printf '%s\n' "$name"
    }
  done < <(window_marker_prefixes)
}

# window_marker_clear: remove one window's whole marker family from <state-dir>.
#
# This is the ONE place that acts on the inventory, so the two boundaries that
# need it - a window being created (bin/fm-spawn.sh) and a window being retired
# (bin/fm-teardown.sh) - cannot drift from the family list or from each other.
# Both key forms go: a marker under either form describes the same endpoint.
#
# Clearing at CREATION is what makes a reused window safe. Window names are
# reused (tmux pins the name `fm-<id>`, and a re-dispatched task keeps its id),
# so a task that wedged before its retirement leaves an over-age .stale-since-
# and an inherited escalation count that a NEW incarnation would resume from -
# alerting about work that has not started. A destroy-time clear that is skipped
# once (killed process, abnormal exit) poisons the next incarnation; a
# create-time clear leaves the new one clean however the last one ended. Neither
# boundary is sufficient alone, so both call this.
#
# Only the named window is touched. A marker keyed by another endpoint may
# belong to a live worker, whose escalation history erasing would silence a
# genuine wedge.
window_marker_clear() {  # <state-dir> <window>
  local state=$1 win=$2 name
  [ -n "$state" ] && [ -n "$win" ] || return 0
  [ -d "$state" ] && [ ! -L "$state" ] || return 0
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    rm -f -- "$state/$name" || return 1
  done < <(window_marker_names "$win")
}

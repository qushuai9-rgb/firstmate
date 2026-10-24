#!/usr/bin/env bash
# Live adversarial drive of bin/fm-pi-trust.sh against the real installed Pi
# store format: a recorded human decline must refuse (never flip), an inherited
# trust must write nothing, unrelated entries must survive byte-for-byte in
# meaning, and out-of-scope paths must be refused without touching the store.
set -u
ROOT=${FM_REPO_ROOT:?}
TRUST=$ROOT/bin/fm-pi-trust.sh
LAB=$(mktemp -d "${TMPDIR:-/tmp}/fm-live-trust-adv.XXXXXX") || exit 1
trap 'rm -rf -- "$LAB"' EXIT
HOME_DIR=$LAB/home
AGENT=$LAB/agent
PROJ=$LAB/project
WT=$LAB/slot
mkdir -p "$HOME_DIR" "$AGENT"
git init -q "$PROJ"
mkdir -p "$PROJ/.agents/skills/demo"
printf 'placeholder\n' > "$PROJ/.agents/skills/demo/SKILL.md"
git -C "$PROJ" -c user.name=t -c user.email=t@e.i add -A
git -C "$PROJ" -c user.name=t -c user.email=t@e.i commit -qm init
git -C "$PROJ" worktree add -q "$WT"
WT_REAL=$(cd -P -- "$WT" && pwd -P)
LAB_REAL=$(cd -P -- "$LAB" && pwd -P)
run() { HOME="$HOME_DIR" "$TRUST" --agent-dir "$AGENT" "$@" 2>&1; }

echo "=== 1. exact recorded decline must refuse and not be reversed ==="
printf '{\n  "%s": false,\n  "/unrelated/path": true\n}\n' "$WT_REAL" > "$AGENT/trust.json"
before=$(shasum -a 256 "$AGENT/trust.json")
out=$(run "$WT" "$PROJ"); status=$?
echo "exit=$status"; printf '%s\n' "$out"
after=$(shasum -a 256 "$AGENT/trust.json")
[ "$status" -ne 0 ] && [ "$before" = "$after" ] && echo "PASS declined-exact: refused, store untouched" || echo "FAIL declined-exact"

echo "=== 2. inherited decline above the worktree must refuse too ==="
printf '{\n  "%s": false\n}\n' "$LAB_REAL" > "$AGENT/trust.json"
before=$(shasum -a 256 "$AGENT/trust.json")
out=$(run "$WT" "$PROJ"); status=$?
echo "exit=$status"; printf '%s\n' "$out"
after=$(shasum -a 256 "$AGENT/trust.json")
[ "$status" -ne 0 ] && [ "$before" = "$after" ] && echo "PASS declined-inherited: refused, store untouched" || echo "FAIL declined-inherited"

echo "=== 3. inherited trust must write nothing (idempotent across relaunch) ==="
printf '{\n  "%s": true,\n  "/another": null\n}\n' "$LAB_REAL" > "$AGENT/trust.json"
before=$(shasum -a 256 "$AGENT/trust.json")
out=$(run "$WT" "$PROJ"); status=$?
echo "exit=$status"; printf '%s\n' "$out"
after=$(shasum -a 256 "$AGENT/trust.json")
[ "$status" -eq 0 ] && [ "$before" = "$after" ] && echo "PASS inherited-true: already trusted, no write" || echo "FAIL inherited-true"
cat "$AGENT/trust.json"

echo "=== 4. fresh registration preserves unrelated entries and adds only the path ==="
rm -f "$AGENT/trust.json"
printf '{\n  "/keep/true": true,\n  "/keep/false": false,\n  "/keep/null": null\n}\n' > "$AGENT/trust.json"
out=$(run "$WT" "$PROJ"); status=$?
echo "exit=$status"; printf '%s\n' "$out"
cat "$AGENT/trust.json"
node -e '
const fs=require("node:fs");const j=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const [store,wt]=process.argv.slice(1);
const ok = j[wt]===true && j["/keep/true"]===true && j["/keep/false"]===false && j["/keep/null"]===null && Object.keys(j).length===4;
console.log(ok?"PASS preserve-and-add-one":"FAIL preserve-and-add-one "+JSON.stringify(j));
process.exit(ok?0:1);' "$AGENT/trust.json" "$WT_REAL" || true

echo "=== 5. out-of-scope operands are refused with a reason and no write ==="
mkdir -p "$WT/sub" "$LAB/plain"
for op in "$PROJ|primary checkout" "$WT/sub|worktree subdirectory" "$LAB/plain|plain directory" "$HOME_DIR|home directory"; do
  arg=${op%%|*}; label=${op##*|}
  before=$(shasum -a 256 "$AGENT/trust.json")
  out=$(run "$arg" "$PROJ"); status=$?
  after=$(shasum -a 256 "$AGENT/trust.json")
  printf '%-24s exit=%s untouched=%s msg=%s\n' "$label" "$status" "$([ "$before" = "$after" ] && echo yes || echo NO)" "$(printf '%s' "$out" | head -1)"
done
out=$(run / "$PROJ"); status=$?; printf '%-24s exit=%s msg=%s\n' "filesystem root" "$status" "$(printf '%s' "$out" | head -1)"
out=$(run "$WT" "/"); status=$?; printf '%-24s exit=%s msg=%s\n' "project=/" "$status" "$(printf '%s' "$out" | head -1)"

echo "=== 6. malformed store must refuse loudly, not rewrite ==="
printf '[]\n' > "$AGENT/trust.json"
before=$(shasum -a 256 "$AGENT/trust.json")
out=$(run "$WT" "$PROJ"); status=$?
after=$(shasum -a 256 "$AGENT/trust.json")
echo "exit=$status untouched=$([ "$before" = "$after" ] && echo yes || echo NO)"; printf '%s\n' "$out"

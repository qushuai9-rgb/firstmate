#!/usr/bin/env bash
# Live scenario driver: the secondmate launch boundary in the REAL bin/fm-spawn.sh.
# Drives real --secondmate launches against a real seeded secondmate home and a
# marked lab primary home, and reads the generated launch overlay the launch
# boundary writes. No harness CLI exists on this machine, so the pane-launch
# step itself fails after the boundary has run; every assertion here is about
# the boundary's own product output (overlay bytes, refusal, created artifacts).
set -u
WT=/Users/qushuai9/.no-mistakes/worktrees/be4d97686c7c/01M5NYF3VY2N6WNEFK4K7M1Z8M
EVID=/Users/qushuai9/.no-mistakes/evidence/01M5NYF3VY2N6WNEFK4K7M1Z8M
FAIL=0
ok()  { printf 'PASS: %s\n' "$*"; }
bad() { printf 'FAIL: %s\n' "$*"; FAIL=1; }
has() { case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac; }

ROOT=$(mktemp -d "${TMPDIR:-/tmp}/fm-spawnlab.XXXXXX")
trap 'rm -rf "$ROOT"' EXIT
LAB="$ROOT/lab"
MR="$ROOT/mates"
printf 'root=%s\n' "$ROOT"

env -u NO_MISTAKES_GATE "$WT/bin/fm-lab-home.sh" create "$LAB" >/dev/null || { echo "cannot mark lab"; exit 1; }
# The gate's lab allowance compares FM_HOME against its physically resolved path,
# so a macOS /var -> /private/var symlink in $TMPDIR must be resolved here.
LAB=$(cd "$LAB" && pwd -P)

seed_mate() { # <name>
  local mate="$MR/$1"
  env -u NO_MISTAKES_GATE FM_HOME="$LAB" FM_ROOT_OVERRIDE="$WT" \
    FM_SECONDMATE_SCOPE='lab validation only' \
    FM_SECONDMATE_CHARTER="# Lab secondmate charter

SPAWN-LAB-CHARTER-BODY $1" \
    "$WT/bin/fm-home-seed.sh" "$1" "$mate" --no-projects >/dev/null 2>&1 || return 1
  (cd "$mate" && pwd -P)
}
reset_lab() { # <id>
  rm -rf "$LAB/state" "$LAB/data/$1" "$LAB/data/secondmates.md"
  mkdir -p "$LAB/state"
}
launch() { # <id> <mate> <harness>
  env -u NO_MISTAKES_GATE -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE \
    -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE \
    FM_HOME="$LAB" "$WT/bin/fm-spawn.sh" "$1" "$2" --secondmate --harness "$3" --backend tmux
}

note_case() { printf '\n== %s ==\n' "$*"; }

########################################################################
note_case "S3: a seeded secondmate launch carries role, absolute home, own charter and boundaries"
M3=$(seed_mate sm-a) || { echo "seed failed"; exit 1; }
cp "$M3/data/charter.md" "$ROOT/charter-before-a"
reset_lab sm-a
OUT3=$(launch sm-a "$M3" pi 2>&1); ST3=$?
OV3="$LAB/data/sm-a/secondmate-launch-brief.md"
printf '%s\n' "$OUT3" > "$EVID/spawn-seeded-launch.out"
printf 'launch exit=%s (harness CLI absent, so the pane step fails after the boundary)\n' "$ST3"
[ -f "$OV3" ] && ok "launch boundary wrote $OV3" || bad "no overlay written"
OVB3=$(cat "$OV3" 2>/dev/null)
has "$OVB3" "You are a secondmate, not the primary Firstmate. Your home is $M3." \
  && ok "overlay states the role and the absolute home" || bad "overlay role/home line missing"
has "$OVB3" "Your charter is $M3/data/charter.md" && ok "overlay names this home's own charter path" \
  || bad "overlay charter path missing or wrong"
has "$OVB3" "CHARTER: present at $M3/data/charter.md (this home own copy)." \
  && ok "overlay reports the home copy as present" || bad "no present verdict"
has "$OVB3" "Run startup only for your own home" && ok "overlay names the own-home startup posture" \
  || bad "own-home startup instruction missing"
has "$OVB3" "Never run startup against the primary home" && ok "overlay forbids startup against the primary home" \
  || bad "primary-home boundary missing"
has "$OVB3" "never address the captain" && ok "overlay states the captain boundary" || bad "captain boundary missing"
has "$OVB3" "SPAWN-LAB-CHARTER-BODY sm-a" && ok "overlay carries the home charter body" \
  || bad "overlay lost the charter body"
BOUND3=$(grep -n 'Never run startup against the primary home' "$OV3" | head -1 | cut -d: -f1)
BODY3=$(grep -n 'SPAWN-LAB-CHARTER-BODY sm-a' "$OV3" | head -1 | cut -d: -f1)
[ -n "$BOUND3" ] && [ -n "$BODY3" ] && [ "$BODY3" -gt "$BOUND3" ] \
  && ok "the charter body follows the identity/boundary header (boundary line $BOUND3, body line $BODY3)" \
  || bad "charter body not after the boundary header (boundary=$BOUND3 body=$BODY3)"
[ -f "$M3/data/charter.md" ] && cmp -s "$ROOT/charter-before-a" "$M3/data/charter.md" \
  && ok "launch did not rewrite the home's charter" || bad "launch rewrote the home charter"

########################################################################
note_case "S4: an out-of-home charter symlink is reported UNSAFE and its bytes never reach the overlay"
M4=$(seed_mate sm-b) || { echo "seed failed"; exit 1; }
OUTSIDE="$ROOT/outside-charter.md"
printf 'OUTSIDE-CHARTER-CONTENT-MUST-NOT-LEAK\n' > "$OUTSIDE"
rm -f "$M4/data/charter.md"
ln -s "$OUTSIDE" "$M4/data/charter.md"
reset_lab sm-b
mkdir -p "$LAB/data/sm-b"
printf 'parent copy for the escaping case\n' > "$LAB/data/sm-b/brief.md"
OUT4=$(launch sm-b "$M4" pi 2>&1); ST4=$?
printf '%s\n' "$OUT4" > "$EVID/spawn-unsafe-symlink.out"
OV4="$LAB/data/sm-b/secondmate-launch-brief.md"
[ -f "$OV4" ] && ok "launch boundary still wrote the overlay" || bad "no overlay written"
OVB4=$(cat "$OV4" 2>/dev/null)
has "$OVB4" "CHARTER: UNSAFE at $M4/data/charter.md" && ok "overlay names the symlinked charter UNSAFE" \
  || bad "no UNSAFE verdict"
has "$OVB4" "OUTSIDE-CHARTER-CONTENT-MUST-NOT-LEAK" && bad "overlay leaked the out-of-home charter bytes" \
  || ok "out-of-home charter bytes never reached the overlay"
has "$OVB4" "CHARTER FALLBACK" && ok "overlay labels the parent copy as an explicit fallback" \
  || bad "parent copy not labelled as fallback"
has "$OVB4" "parent copy for the escaping case" && ok "overlay still carries the labelled fallback text" \
  || bad "fallback text missing"

note_case "S4b: a data/ directory symlink that leaves the home is also UNSAFE"
M4B=$(seed_mate sm-b2) || { echo "seed failed"; exit 1; }
OUTSIDE_DATA="$ROOT/outside-data"
mkdir -p "$OUTSIDE_DATA"
printf 'OUTSIDE-DATA-CHARTER-BYTES\n' > "$OUTSIDE_DATA/charter.md"
cp "$M4B/.fm-secondmate-home" "$ROOT/marker-keep" 2>/dev/null || true
rm -rf "$M4B/data"
ln -s "$OUTSIDE_DATA" "$M4B/data"
reset_lab sm-b2
mkdir -p "$LAB/data/sm-b2"
printf 'parent copy for the data-dir case\n' > "$LAB/data/sm-b2/brief.md"
OUT4B=$(launch sm-b2 "$M4B" pi 2>&1); ST4B=$?
printf '%s\n' "$OUT4B" > "$EVID/spawn-unsafe-data-dir.out"
OV4B="$LAB/data/sm-b2/secondmate-launch-brief.md"
[ "$ST4B" -ne 0 ] && ok "a data/ symlink leaving the home refuses the launch (exit $ST4B)" \
  || bad "a data/ symlink leaving the home was accepted"
has "$OUT4B" "secondmate data directory must resolve inside the secondmate home: $M4B/data" \
  && ok "the refusal names the escaping data directory" || bad "no escaping-data-directory refusal"
[ ! -e "$OV4B" ] && ok "no overlay was produced for the escaping data dir" || bad "an overlay was produced"
has "$(cat "$OV4B" 2>/dev/null)" "OUTSIDE-DATA-CHARTER-BYTES" && bad "overlay leaked the out-of-home data-dir charter" \
  || ok "out-of-home data-dir charter bytes never reached any overlay"

########################################################################
note_case "S5: no home charter and no parent copy refuses before any endpoint, metadata or record"
M5=$(seed_mate sm-c) || { echo "seed failed"; exit 1; }
rm -f "$M5/data/charter.md"
reset_lab sm-c
OUT5=$(launch sm-c "$M5" pi 2>&1); ST5=$?
printf '%s\n' "$OUT5" > "$EVID/spawn-both-missing-refusal.out"
printf 'refusal exit=%s\n' "$ST5"
[ "$ST5" -ne 0 ] && ok "launch refused (exit $ST5)" || bad "launch with no charter text succeeded"
has "$OUT5" "error: secondmate sm-c has no usable charter" && ok "refusal names the missing charter" \
  || bad "refusal message missing"
has "$OUT5" "$M5/data/charter.md" && ok "refusal names the home's own charter path" || bad "home charter path missing"
has "$OUT5" "$LAB/data/sm-c/brief.md" && ok "refusal names the absent parent copy" || bad "parent copy path missing"
has "$OUT5" "bin/fm-home-seed.sh" && ok "refusal names the seeding fix" || bad "seeding fix missing"
[ ! -e "$LAB/data/sm-c/secondmate-launch-brief.md" ] && ok "no overlay was created by the refusal" \
  || bad "the refusal created an overlay"
[ ! -e "$LAB/state/sm-c.meta" ] && ok "no task metadata was created by the refusal" || bad "refusal created metadata"
[ -z "$(find "$LAB/state" -mindepth 1 -print -quit 2>/dev/null)" ] && ok "primary state dir stayed empty" \
  || bad "refusal wrote into primary state"
[ -z "$(find "$M5/state" -mindepth 1 -print -quit 2>/dev/null)" ] && ok "no launch record was created in the mate's state" \
  || bad "refusal wrote a launch record"

########################################################################
note_case "S6: a missing home charter with the parent copy present recovers with an explicit MISSING verdict"
M6=$(seed_mate sm-d) || { echo "seed failed"; exit 1; }
rm -f "$M6/data/charter.md"
reset_lab sm-d
mkdir -p "$LAB/data/sm-d"
printf 'parent copy of the charter for sm-d\n' > "$LAB/data/sm-d/brief.md"
OUT6=$(launch sm-d "$M6" pi 2>&1)
printf '%s\n' "$OUT6" > "$EVID/spawn-missing-parent-fallback.out"
OV6="$LAB/data/sm-d/secondmate-launch-brief.md"
OVB6=$(cat "$OV6" 2>/dev/null)
has "$OVB6" "CHARTER: MISSING at $M6/data/charter.md" && ok "overlay names the missing home charter" \
  || bad "no MISSING verdict"
has "$OVB6" "Do NOT infer any role from AGENTS.md" && ok "overlay forbids inferring a role from AGENTS.md" \
  || bad "AGENTS.md guard missing"
has "$OVB6" "CHARTER FALLBACK" && ok "parent copy labelled as an explicit fallback" || bad "fallback not labelled"
has "$OVB6" "parent copy of the charter for sm-d" && ok "recovering session still receives the parent copy" \
  || bad "parent copy text missing"
has "$OVB6" "CHARTER: present" && bad "overlay claimed a present home charter" || ok "overlay never claims a present home copy"

for f in "$OV3" "$OV4" "$OV6"; do
  [ -f "$f" ] && cp "$f" "$EVID/overlay-$(basename "$(dirname "$f")")-launch-brief.md"
done
printf '\n===== generated overlays =====\n'
for f in "$OV3" "$OV4" "$OV4B" "$OV6"; do
  printf -- '--- %s\n' "${f#"$LAB"/}"
  sed -n '1,6p' "$f" 2>/dev/null
done

printf '\nexit=%s (0 = every assertion above passed)\n' "$FAIL"
exit "$FAIL"

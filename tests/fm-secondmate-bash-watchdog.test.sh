#!/usr/bin/env bash
# Portable behavior regression for the Pi secondmate Bash watchdog.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP_ROOT=$(fm_test_tmproot fm-secondmate-bash-watchdog)
PI_PACKAGE_DIR=${FM_PI_PACKAGE_DIR:-"$(npm root -g 2>/dev/null)/@earendil-works/pi-coding-agent"}
if [ ! -f "$PI_PACKAGE_DIR/package.json" ]; then
  echo "skip: installed @earendil-works/pi-coding-agent package not found"
  exit 0
fi

project="$TMP_ROOT/project"
mkdir -p "$project/.pi/extensions" "$project/node_modules/@earendil-works"
printf '{"type":"module"}\n' > "$project/package.json"
cp "$ROOT/.pi/extensions/fm-secondmate-bash-watchdog.ts" \
  "$project/.pi/extensions/fm-secondmate-bash-watchdog.ts"
ln -s "$PI_PACKAGE_DIR" \
  "$project/node_modules/@earendil-works/pi-coding-agent"
printf 'secondmate\n' > "$project/.fm-secondmate-home"

out=$(PROJECT="$project" PI_PACKAGE_DIR="$PI_PACKAGE_DIR" node --input-type=module <<'JS'
import { existsSync, readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

const project = process.env.PROJECT;
process.chdir(project);
const messages = [];
const registrations = [];
const pi = {
  registerTool(tool) { registrations.push(tool); },
  sendMessage(message, options) { messages.push({ message, options }); },
};
process.env.FM_BASH_WATCHDOG_TIMEOUT_MS = "50";
const extension = await import(`${pathToFileURL(`${project}/.pi/extensions/fm-secondmate-bash-watchdog.ts`).href}?test=${Date.now()}`);
extension.default(pi);
if (registrations.length !== 1 || registrations[0].name !== "bash") {
  throw new Error(`expected one replacement bash tool, got ${registrations.length}`);
}
const sentinel = `${project}/timed-out-command-completed`;
let failed = false;
try {
  await registrations[0].execute(
    "watchdog-test",
    { command: `sleep 0.3; touch '${sentinel}'` },
    undefined,
    undefined,
    {
      cwd: project,
      model: undefined,
      sessionManager: { getSessionId: () => "watchdog-test", getSessionFile: () => undefined },
    },
  );
} catch (error) {
  failed = error instanceof Error && error.message.includes("Command timed out after 0.05 seconds");
}
if (!failed) throw new Error("the watchdog command did not time out through the public Bash tool");
if (existsSync(sentinel)) throw new Error("the timed-out child survived long enough to create its sentinel");
if (messages.length !== 1) throw new Error(`expected one recovery message, got ${messages.length}`);
const { message, options } = messages[0];
if (message.content !== "⚠️ 上一个命令超时被终止（超过5分钟）。这通常意味着外部服务挂起或操作卡死。请：①落盘当前进度 ②检查网络/换策略 ③若持续卡死则报告 blocked。") {
  throw new Error(`unexpected recovery message: ${JSON.stringify(message)}`);
}
if (message.display !== false || message.customType !== "fm-secondmate-bash-watchdog" || options.deliverAs !== "followUp") {
  throw new Error(`unexpected recovery message delivery: ${JSON.stringify({ message, options })}`);
}

process.env.FM_BASH_WATCHDOG_OFF = "1";
const disabledRegistrations = [];
const disabledPi = { registerTool(tool) { disabledRegistrations.push(tool); }, sendMessage() {} };
const disabledExtension = await import(`${pathToFileURL(`${project}/.pi/extensions/fm-secondmate-bash-watchdog.ts`).href}?disabled=${Date.now()}`);
disabledExtension.default(disabledPi);
if (disabledRegistrations.length !== 0) throw new Error("FM_BASH_WATCHDOG_OFF did not disable the tool");

console.log("watchdog timeout kills child and injects one follow-up; off switch disables registration");
JS
)
status=$?
expect_code 0 "$status" "secondmate watchdog behavior"
[ "$out" = "watchdog timeout kills child and injects one follow-up; off switch disables registration" ] \
  || fail "unexpected watchdog test output: $out"
pass "Pi secondmate Bash watchdog terminates a hung command and gives the model one recovery follow-up"

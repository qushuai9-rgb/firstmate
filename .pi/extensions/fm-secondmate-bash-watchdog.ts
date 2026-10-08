import { existsSync } from "node:fs";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  createBashToolDefinition,
  createLocalBashOperations,
  type BashOperations,
} from "@earendil-works/pi-coding-agent";

const DEFAULT_TIMEOUT_MS = 300_000;
const WATCHDOG_MESSAGE =
  "⚠️ 上一个命令超时被终止（超过5分钟）。这通常意味着外部服务挂起或操作卡死。请：①落盘当前进度 ②检查网络/换策略 ③若持续卡死则报告 blocked。";

function watchdogTimeoutMs(): number {
  const raw = process.env.FM_BASH_WATCHDOG_TIMEOUT_MS;
  if (!raw) return DEFAULT_TIMEOUT_MS;
  const value = Number(raw);
  return Number.isFinite(value) && value > 0 ? value : DEFAULT_TIMEOUT_MS;
}

function watchdogEnabled(): boolean {
  const homeMarker = `${process.cwd()}/.fm-secondmate-home`;
  return (process.env.FM_SECOND_MATE === "1" || existsSync(homeMarker)) &&
    process.env.FM_BASH_WATCHDOG_OFF !== "1";
}

function watchdogAppliesTo(params: { timeout?: number }, timeoutMs: number): boolean {
  const requestedTimeout = params.timeout;
  return requestedTimeout === undefined || requestedTimeout > timeoutMs / 1000;
}

function watchdogOperations(timeoutMs: number): BashOperations {
  const base = createLocalBashOperations();
  return {
    ...base,
    exec: (command, cwd, options) => {
      const watchdogSeconds = timeoutMs / 1000;
      const timeout = options.timeout === undefined || options.timeout > watchdogSeconds
        ? watchdogSeconds
        : options.timeout;
      return base.exec(command, cwd, { ...options, timeout });
    },
  };
}

export default function (pi: ExtensionAPI) {
  if (!watchdogEnabled()) return;

  const timeoutMs = watchdogTimeoutMs();
  const tool = createBashToolDefinition(process.cwd(), {
    operations: watchdogOperations(timeoutMs),
  });
  const originalExecute = tool.execute;
  pi.registerTool({
    ...tool,
    async execute(toolCallId, params, signal, onUpdate, ctx) {
      try {
        return await originalExecute(toolCallId, params, signal, onUpdate, ctx);
      } catch (error) {
        if (watchdogAppliesTo(params, timeoutMs) && error instanceof Error &&
            error.message.startsWith("Command timed out after ")) {
          pi.sendMessage(
            {
              customType: "fm-secondmate-bash-watchdog",
              content: WATCHDOG_MESSAGE,
              display: false,
              details: { timeoutMs },
            },
            { deliverAs: "followUp" },
          );
        }
        throw error;
      }
    },
  });
}

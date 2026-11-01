#!/usr/bin/env python3
"""Drive a real `pi` TUI launch inside a private pty with a real (non-zero) grid.

Usage: drive-pi-tui.py <cwd> <home> <agent-dir> <out-prefix> [<capture-seconds>] [<keys>]

Runs the installed `pi` binary in <cwd> with HOME=<home> and
PI_CODING_AGENT_DIR=<agent-dir>, waits <capture-seconds> (default 12) collecting
output, then sends <keys> (default "\\x1b", Escape - never Enter, so no prompt is
ever submitted). Writes <out-prefix>.raw (verbatim stream) and
<out-prefix>.txt (ANSI-stripped screen transcript).
"""

import fcntl
import os
import pty
import re
import select
import struct
import sys
import termios
import time
import signal


def strip_ansi(data: str) -> str:
    # CSI / OSC / single-char escapes produced by the TUI.
    data = re.sub(r"\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)", "", data)
    data = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", data)
    data = re.sub(r"\x1b[()#][0-9A-Za-z]", "", data)
    data = re.sub(r"\x1b[@-Z\\-_]", "", data)
    return data


def main() -> int:
    if len(sys.argv) < 5:
        print(__doc__, file=sys.stderr)
        return 2
    cwd, home, agent, out = sys.argv[1:5]
    seconds = float(sys.argv[5]) if len(sys.argv) > 5 else 12.0
    keys_at = float(sys.argv[6]) if len(sys.argv) > 6 and sys.argv[6] else seconds
    keys = sys.argv[7] if len(sys.argv) > 7 else "\x1b"

    env = {
        "HOME": home,
        "PI_CODING_AGENT_DIR": agent,
        "TERM": "xterm-256color",
        "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
        "LANG": "en_US.UTF-8",
        "TMPDIR": os.environ.get("TMPDIR", "/tmp"),
        "PI_OFFLINE": "1",
        # The macOS native clipboard addon blocks forever in this headless
        # harness (uninterruptible pasteboard read), so disable it the way pi
        # does for Termux. It has no bearing on project trust.
        "TERMUX_VERSION": "1",
    }
    for extra in ("LAB_MARKER_FILE",):
        if extra in os.environ:
            env[extra] = os.environ[extra]
    pi_args = sys.argv[8:]
    pi = "/Users/qushuai9/.local/share/pi-node/node-v22.23.2-darwin-arm64/bin/pi"

    pid, fd = pty.fork()
    if pid == 0:
        os.chdir(cwd)
        try:
            os.execve(pi, [pi, *pi_args], env)
        except BaseException as exc:  # pragma: no cover - lab driver only
            os.write(2, f"exec failed: {exc!r} argv={[pi, *pi_args]!r}\n".encode())
            os._exit(127)

    # A real grid: a 0x0 winsize makes the TUI exit before it renders.
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))

    raw = bytearray()
    started = time.time()
    deadline = started + seconds
    key_deadline = started + keys_at
    sent = False
    while True:
        now = time.time()
        remaining = deadline - now
        if remaining <= 0:
            break
        readable, _, _ = select.select([fd], [], [], min(0.25, remaining))
        if readable:
            try:
                chunk = os.read(fd, 65536)
            except OSError:
                break
            if not chunk:
                break
            raw += chunk
        if not sent and keys and time.time() >= key_deadline:
            try:
                os.write(fd, keys.encode())
            except OSError:
                pass
            sent = True
    try:
        os.write(fd, b"\x03")
        os.close(fd)
    except OSError:
        pass
    try:
        os.kill(pid, signal.SIGKILL)
    except OSError:
        pass
    try:
        os.waitpid(pid, 0)
    except OSError:
        pass

    with open(out + ".raw", "wb") as fh:
        fh.write(bytes(raw))
    with open(out + ".txt", "w", encoding="utf-8", errors="replace") as fh:
        fh.write(strip_ansi(raw.decode("utf-8", "replace")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

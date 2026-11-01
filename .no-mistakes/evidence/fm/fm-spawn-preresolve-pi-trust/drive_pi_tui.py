#!/usr/bin/env python3
"""Drive the real `pi` TUI on a real pty with a non-zero window size.

Usage: drive_pi_tui.py <cwd> <home> <raw-capture-out> <clean-capture-out> [seconds] [keys]

Runs the installed pi CLI exactly as a worker-launched pane would (no --approve,
no trust override) against whatever HOME and agent root the environment selects,
captures everything it renders, and stops it with Ctrl-C. A 40x110 grid is set on
the pty before exec so the TUI never sees the 0x0 grid that makes it exit at once.
"""
import fcntl
import json
import os
import pty
import re
import select
import signal
import struct
import sys
import termios
import time

cwd, home, raw_out, clean_out = sys.argv[1:5]
seconds = float(sys.argv[5]) if len(sys.argv) > 5 else 12.0
keys = json.loads(sys.argv[6]) if len(sys.argv) > 6 else []

rows, cols = 40, 110
master, slave = pty.openpty()
fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))

env = dict(os.environ)
env["HOME"] = home
env["TERM"] = "xterm-256color"
env.pop("PI_CODING_AGENT_DIR", None)
env.pop("PI_OFFLINE", None)

pid = os.fork()
if pid == 0:
    os.setsid()
    fcntl.ioctl(slave, termios.TIOCSCTTY, 0)
    os.dup2(slave, 0)
    os.dup2(slave, 1)
    os.dup2(slave, 2)
    if slave > 2:
        os.close(slave)
    os.close(master)
    os.chdir(cwd)
    os.execvpe("pi", ["pi"], env)

os.close(slave)
buf = bytearray()
schedule = [(float(d), text.encode()) for d, text in keys]
start = time.time()
while time.time() - start < seconds:
    while schedule and time.time() - start >= schedule[0][0]:
        os.write(master, schedule.pop(0)[1])
    r, _, _ = select.select([master], [], [], 0.2)
    if master in r:
        try:
            chunk = os.read(master, 65536)
        except OSError:
            break
        if not chunk:
            break
        buf.extend(chunk)
    done, status = os.waitpid(pid, os.WNOHANG)
    if done:
        # drain what is left
        while True:
            r, _, _ = select.select([master], [], [], 0.1)
            if master not in r:
                break
            try:
                chunk = os.read(master, 65536)
            except OSError:
                break
            if not chunk:
                break
            buf.extend(chunk)
        break

try:
    os.write(master, b"\x03")
except OSError:
    pass
time.sleep(0.6)
try:
    os.kill(pid, signal.SIGTERM)
    os.waitpid(pid, os.WNOHANG)
except OSError:
    pass
try:
    os.close(master)
except OSError:
    pass

raw = bytes(buf)
open(raw_out, "wb").write(raw)
text = raw.decode("utf-8", "replace")
text = re.sub(r"\x1b\[[0-9;?]*[ -/]*[@-~]", "", text)
text = re.sub(r"\x1b\][^\x07]*\x07", "", text)
text = re.sub(r"\x1b[()][A-Za-z0-9]", "", text)
text = text.replace("\r", "")
open(clean_out, "w").write(text)
print(text[-4000:])

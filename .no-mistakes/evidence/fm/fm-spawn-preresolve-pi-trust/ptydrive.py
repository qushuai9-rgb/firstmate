#!/usr/bin/env python3
"""Drive a TUI in a real pty with a non-zero window size.

usage: ptydrive.py <cwd> <outfile> <seconds> <prompt> [keys-after-seconds:keys]
Drains the master and writes the raw transcript to <outfile>.
"""
import fcntl, os, pty, re, select, signal, struct, sys, termios, time

cwd, outfile, seconds, prompt = sys.argv[1], sys.argv[2], float(sys.argv[3]), sys.argv[4]

rows, cols = 40, 140
master, slave = pty.openpty()
fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
pid = os.fork()
if pid == 0:
    try:
        os.setsid()
        fcntl.ioctl(slave, termios.TIOCSCTTY, 0)
        os.dup2(slave, 0); os.dup2(slave, 1); os.dup2(slave, 2)
        os.close(master); os.close(slave)
        os.chdir(cwd)
        cmd = os.environ.get("PTY_COMMAND")
        if cmd:
            os.execvpe("/bin/bash", ["/bin/bash", "-c", cmd], os.environ)
        os.execvpe("pi", ["pi", prompt], os.environ)
    except BaseException as exc:  # pragma: no cover
        os._exit(127)
os.close(slave)

buf = bytearray()
deadline = time.time() + seconds
while time.time() < deadline:
    r, _, _ = select.select([master], [], [], 0.3)
    if master in r:
        try:
            chunk = os.read(master, 65536)
        except OSError:
            break
        if not chunk:
            break
        buf.extend(chunk)
try:
    os.kill(pid, signal.SIGTERM)
except ProcessLookupError:
    pass
time.sleep(0.3)
try:
    os.close(master)
except OSError:
    pass

raw = bytes(buf)
with open(outfile, "wb") as fh:
    fh.write(raw)
text = raw.decode("utf-8", "replace")
text = re.sub(r"\x1b\[[0-9;?]*[a-zA-Z]", "", text)
text = re.sub(r"\x1b\][^\x07\x1b]*(\x07|\x1b\\)", "", text)
text = re.sub(r"\x1b[()][A-Za-z0-9]", "", text)
text = re.sub(r"[\x00-\x08\x0b-\x1f]", "", text)
with open(outfile + ".txt", "w") as fh:
    fh.write(text)
print(f"exit-after={seconds}s bytes={len(raw)}")

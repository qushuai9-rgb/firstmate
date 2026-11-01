#!/usr/bin/env python3
"""Drive a TUI in a correctly sized pty and record what it renders.

Usage: pty_drive.py --out FILE --seconds N --cwd DIR [--send "keys"]... -- cmd...
Sets a non-zero window size (TIOCSWINSZ) before the child reads its grid, and
keeps draining the master so the TUI never blocks on a full pty buffer.
"""
import argparse, fcntl, os, pty, select, struct, subprocess, sys, termios, time

ap = argparse.ArgumentParser()
ap.add_argument('--out', required=True)
ap.add_argument('--seconds', type=float, default=12)
ap.add_argument('--cwd', default=None)
ap.add_argument('--rows', type=int, default=40)
ap.add_argument('--cols', type=int, default=120)
ap.add_argument('--send', action='append', default=[])
ap.add_argument('cmd', nargs=argparse.REMAINDER)
a = ap.parse_args()
cmd = a.cmd[1:] if a.cmd and a.cmd[0] == '--' else a.cmd

master, slave = pty.openpty()
fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', a.rows, a.cols, 0, 0))
env = dict(os.environ)
env.setdefault('TERM', 'xterm-256color')
p = subprocess.Popen(cmd, stdin=slave, stdout=slave, stderr=slave, cwd=a.cwd,
                     env=env, close_fds=True, start_new_session=True)
os.close(slave)
chunks = []
sends = [(float(s.split(':', 1)[0]), s.split(':', 1)[1]) for s in a.send]
start = time.time()
sent = 0
while time.time() - start < a.seconds:
    now = time.time() - start
    while sent < len(sends) and now >= sends[sent][0]:
        os.write(master, sends[sent][1].encode().decode('unicode_escape').encode())
        sent += 1
    r, _, _ = select.select([master], [], [], 0.2)
    if master in r:
        try:
            data = os.read(master, 65536)
        except OSError:
            break
        if not data:
            break
        chunks.append(data)
    if p.poll() is not None and not r:
        break
try:
    os.write(master, b'\x03')
    time.sleep(0.2)
except OSError:
    pass
p.terminate()
try:
    p.wait(timeout=5)
except subprocess.TimeoutExpired:
    p.kill()
os.close(master)
raw = b''.join(chunks)
with open(a.out, 'wb') as f:
    f.write(raw)
print(f'child_exit={p.returncode} bytes={len(raw)}')

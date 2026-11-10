#!/usr/bin/env python3
"""A Ctrl-C in the gap between starting Godot and setting the trap
(the gap review of 2026-11-10, r5-2) — `tools/duel_soak.sh`.

The soak's INT/TERM traps were set on the line AFTER the `&` that starts
Godot. A Ctrl-C that landed between the two (the script's bash descheduled
right after the fork, as on a loaded desk) killed bash at its default
disposition: no exit 130, and Godot — in `timeout`'s own process group, out
of the Ctrl-C's reach — played on for up to SOAK_TIMEOUT. The traps go on
before the `&` now and find the job by `jobs -pr` (lan_smoke.sh's way).

The load is emulated, deterministically: strace holds ONLY the script's
bash at the exit of each fork (its children run free), so the Ctrl-C lands
in the gap. No real Godot: the stand-in writes its pid and sleeps. Skipped
without strace (or where it may not trace its own child).

THE MACHINE IS READ, NOT GUESSED: the bounds after the Ctrl-C are stretched
by how much slower than on the quiet desk the stand-in started, and a
failure says that and the load average (`test_lan_smoke_launcher.Pace`).

Run from the repo root:
    python3 -m unittest tools.test_gap_fix_g5_soak_trap
"""
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_lan_smoke_launcher import Pace, pid_in, wait_for  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
SLEEPING_GODOT = """#!/bin/sh
echo $$ > "$FAKE_PIDFILE.part"
mv "$FAKE_PIDFILE.part" "$FAKE_PIDFILE"
exec sleep 60
"""
# How long the hold keeps bash at the exit of each fork, in microseconds.
HOLD_US = 1500000
# Seconds from starting duel_soak.sh to the stand-in's pid, on the quiet
# desk (2026-11-10, the minimum of five runs, three under the hold; load 9
# on 22 cores): without strace, under strace with no real hold, and under
# the hold above (the three forks of the script's bash up to Godot's, each
# held for it).
QUIET_START = {0: 0.025, 1: 0.03, HOLD_US: 4.5}
FORKS = "clone,clone3,fork,vfork"


def alive(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    try:
        with open("/proc/%d/stat" % pid) as stat:
            return stat.read().split(") ", 1)[1][0] != "Z"
    except OSError:
        return True


def strace_works():
    if not sys.platform.startswith("linux") or not shutil.which("strace"):
        return False
    try:
        return subprocess.run(["strace", "-o", "/dev/null", "-e", "trace=" + FORKS, "true"],
                              stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                              stderr=subprocess.DEVNULL, timeout=30).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


@unittest.skipUnless(strace_works(), "needs strace, allowed to trace its own child")
class SoakTrapBeforeTheForkTest(unittest.TestCase):

    def ctrl_c(self, hold_us):
        with tempfile.TemporaryDirectory() as tmp:
            scratch = Path(tmp)
            stub = scratch / "godot"
            stub.write_text(SLEEPING_GODOT)
            stub.chmod(0o755)
            pidfile = scratch / "godot.pid"
            env = dict(os.environ, SHANDALAR_NO_BANNER="1", GODOT=str(stub), FAKE_PIDFILE=str(pidfile),
                       SOAK_TIMEOUT="300", SHANDALAR_TEST_DATA_HOME=str(scratch / "data"), SOAK_HEADLESS="1")
            argv = ["bash", str(ROOT / "tools/duel_soak.sh"), "--count", "1"]
            if hold_us:
                # `-o FILE PROG`: strace itself blocks the fatal signals, so the
                # Ctrl-C below reaches bash alone, and strace exits as bash does.
                argv = ["strace", "-o", "/dev/null", "-e", "trace=" + FORKS,
                        "-e", "inject=%s:delay_exit=%d" % (FORKS, hold_us)] + argv
            started = time.monotonic()
            # A session of its own, so the INT goes to the script's process
            # group as a terminal's Ctrl-C does; SIGINT at its default in it
            # (an inherited ignored SIGINT cannot be trapped — c12, h6-4).
            proc = subprocess.Popen(argv, cwd=str(ROOT), env=env, stdin=subprocess.DEVNULL,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True,
                                    preexec_fn=lambda: signal.signal(signal.SIGINT, signal.SIG_DFL))
            godot = None
            try:
                godot = wait_for(lambda: pid_in(pidfile) or proc.poll() is not None and -1,
                                 120 + 20 * QUIET_START[hold_us])
                pace = Pace(QUIET_START[hold_us], time.monotonic() - started)
                self.assertTrue(godot and godot > 0, "the stand-in Godot never started; %s" % pace)
                os.killpg(proc.pid, signal.SIGINT)
                # The trap's own forks are held too: a command substitution
                # and one pkill a job, each `hold` long on top of the bound.
                bound = pace.bound(20) + 4 * hold_us / 1e6
                try:
                    _out, err = proc.communicate(timeout=bound)
                except subprocess.TimeoutExpired:
                    self.fail("duel_soak.sh did not stop within %.0fs of the Ctrl-C; %s" % (bound, pace))
                gone = wait_for(lambda: not alive(godot), pace.bound(10))
                self.assertTrue(gone, "Godot was left running after the Ctrl-C; %s" % pace)
                # strace exits with its tracee's status: 130 from the trap; a
                # bash killed by the INT itself shows as -2.
                self.assertEqual(proc.returncode, 130, "%s; stderr %r" % (pace, err[-300:]))
            finally:
                if proc.poll() is None:
                    os.killpg(proc.pid, signal.SIGKILL)
                    proc.communicate()
                godot = godot if godot and godot > 0 else pid_in(pidfile)
                if godot and alive(godot):
                    os.kill(godot, signal.SIGKILL)

    def test_a_ctrl_c_with_bash_held_after_the_fork_still_stops_godot(self):
        self.ctrl_c(HOLD_US)

    def test_control_strace_without_a_hold(self):
        self.ctrl_c(1)

    def test_control_without_strace(self):
        self.ctrl_c(0)


if __name__ == "__main__":
    unittest.main(verbosity=2)

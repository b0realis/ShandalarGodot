"""LAN launcher isolation and owned-directory cleanup, without running Godot."""
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


class LanSmokeLauncherTest(unittest.TestCase):
    def run_launcher(self, keep=False, import_fails=False):
        with tempfile.TemporaryDirectory() as scratch:
            folder = Path(scratch)
            parent = folder / 'existing runs'
            parent.mkdir()
            sentinel = parent / 'keep-me.txt'
            sentinel.write_text('unrelated user file')
            fake = folder / 'fake-godot'
            fake.write_text(f'#!{sys.executable}\n' + '''
import json, os, pathlib, sys
args = sys.argv[1:]
out = pathlib.Path(os.environ['FAKE_REPORT'])
if '--import' in args:
    (out / 'import.json').write_text(json.dumps(dict(os.environ)))
    sys.exit(int(os.environ.get('FAKE_IMPORT_FAIL', '0')))
role = args[args.index('--role') + 1]
project = pathlib.Path(args[args.index('--path') + 1])
(out / (role + '.json')).write_text(json.dumps({
    'project': str(project),
    'settings': (project / 'override.cfg').read_text(),
    'source': str((project / 'project.godot').resolve()),
    'features': os.environ.get('GODOT_EDITOR_CUSTOM_FEATURES'),
    'xdg': os.environ['XDG_DATA_HOME'],
}))
print('LAN ' + role + ' OK')
''')
            fake.chmod(0o755)
            env = dict(os.environ, GODOT=str(fake), LAN_SMOKE_DIR=str(parent),
                       FAKE_REPORT=str(folder), FAKE_IMPORT_FAIL=str(int(import_fails)),
                       SHANDALAR_TEST_DATA_HOME=str(folder / 'import-profile'),
                       GODOT_EDITOR_CUSTOM_FEATURES='shandalar_test')
            command = ['bash', str(ROOT / 'tools/lan_smoke.sh')]
            if keep:
                command.append('--keep')
            result = subprocess.run(command, cwd=ROOT, env=env, stdin=subprocess.DEVNULL,
                                    capture_output=True, text=True, timeout=30)
            self.assertEqual(sentinel.read_text(), 'unrelated user file')
            self.assertEqual(result.returncode, 1 if import_fails else 0,
                             result.stdout + result.stderr)
            imported = json.loads((folder / 'import.json').read_text())
            self.assertIn('shandalar_test', imported['GODOT_EDITOR_CUSTOM_FEATURES'])
            if import_fails:
                self.assertFalse((folder / 'host.json').exists())
            else:
                roles = [json.loads((folder / (role + '.json')).read_text())
                         for role in ('host', 'guest')]
                self.assertNotEqual(roles[0]['settings'], roles[1]['settings'])
                self.assertNotEqual(roles[0]['xdg'], roles[1]['xdg'])
                for role, record in zip(('host', 'guest'), roles):
                    self.assertIn('config/name="Shandalar LAN Smoke ', record['settings'])
                    self.assertIn(role + '"', record['settings'])
                    self.assertEqual(record['features'], '')
                    self.assertEqual(Path(record['source']), ROOT / 'project.godot')
                    self.assertEqual(Path(record['project']).exists(), keep)
            remaining = list(parent.iterdir())
            self.assertEqual(len(remaining), 2 if keep else 1)

    def test_roles_are_isolated_and_only_owned_child_is_removed(self):
        self.run_launcher()

    def test_keep_retains_mirrors_without_changing_source(self):
        self.run_launcher(keep=True)

    def test_failed_import_stops_before_launching_roles(self):
        self.run_launcher(import_fails=True)


# A Godot that never finishes on its own: it records its pid, and on
# SIGTERM takes a moment (a real one flushes logs and closes sockets),
# then says whether its data home was still there when it went.
STUCK_GODOT = '''
import os, pathlib, signal, sys, time
args = sys.argv[1:]
out = pathlib.Path(os.environ['FAKE_REPORT'])
name = 'import' if '--import' in args else args[args.index('--role') + 1]
if name == 'import' and not os.environ.get('FAKE_IMPORT_HANGS'):
    sys.exit(0)
home = pathlib.Path(os.environ['XDG_DATA_HOME'])
def bye(signum, frame):
    time.sleep(0.5)
    try:
        (home / 'bye.txt').write_text('flushed')
        verdict = 'home still there'
    except OSError:
        verdict = 'home deleted under me'
    (out / (name + '.verdict')).write_text(verdict)
    sys.exit(143)
signal.signal(signal.SIGTERM, bye)
_part = out / (name + '.pid.part'); _part.write_text(str(os.getpid())); os.replace(_part, out / (name + '.pid'))
time.sleep(120)
'''


# The stand-in writes its pid beside the file and moves it into place, so
# the file is never there empty. This one writes it the way Path.write_text
# does — open (the file is there, empty), then write — held between the
# two, as a stand-in descheduled there on a loaded desk is (the gap review,
# 2026-11-10, r5-3: the test read the pid the moment the file EXISTED, and
# int('') ended it with both stand-ins left running).
PID_WRITE = ("_part = out / (name + '.pid.part'); _part.write_text(str(os.getpid())); "
             "os.replace(_part, out / (name + '.pid'))")
SLOW_PID_HOLD = 0.5
SLOW_PID_GODOT = STUCK_GODOT.replace(
    PID_WRITE, "_f = open(out / (name + '.pid'), 'w'); _f.flush(); time.sleep(%s); "
               "_f.write(str(os.getpid())); _f.close()" % SLOW_PID_HOLD)
assert SLOW_PID_GODOT != STUCK_GODOT
# Seconds from starting lan_smoke.sh to the stand-ins' pids on the quiet
# desk (2026-11-10, the minimum of eight runs each, load 8 to 11 on 22
# cores): the bounds after the signal are stretched by how much slower
# this start was.
QUIET_START = {('host', 'guest'): 0.25, ('import',): 0.05}


def alive(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    return True


def pid_in(path):
    """The pid a stand-in wrote, or None while its file is missing or not
    written yet (a writer between its open and its write)."""
    try:
        text = Path(path).read_text().strip()
    except OSError:
        return None
    return int(text) if text.isdigit() else None


def session_of(sid):
    """Every live process of session `sid` (Linux; nothing elsewhere)."""
    found = []
    proc = Path('/proc')
    for entry in proc.iterdir() if (proc / 'self' / 'stat').exists() else ():
        if entry.name.isdigit():
            try:
                fields = (entry / 'stat').read_text().rsplit(')', 1)[1].split()
            except (OSError, IndexError):
                continue
            if len(fields) > 3 and fields[3] == str(sid):
                found.append(int(entry.name))
    return found


def wait_for(event, seconds, step=0.02):
    """Wait for an EVENT, not for a time: `event()` until it is truthy or
    `seconds` have passed; its last value either way."""
    deadline = time.monotonic() + seconds
    while True:
        value = event()
        if value or time.monotonic() >= deadline:
            return value
        time.sleep(step)


class Pace:
    """THE MACHINE IS READ, NOT GUESSED (the gap review, 2026-11-10): how
    much slower than on the quiet desk a step just took — never below 1 —
    so the bounds that follow are stretched by what was measured rather
    than loosened blindly, and a failure says the measurement and the load
    average beside it."""

    def __init__(self, quiet, took):
        self.quiet = quiet
        self.took = took
        self.ratio = max(1.0, took / quiet)

    def bound(self, seconds):
        return seconds * self.ratio

    def __str__(self):
        try:
            load = "%.2f %.2f %.2f" % os.getloadavg()
        except OSError:
            load = "unknown"
        return ("measured: the start took %.2fs (%.2fs on the quiet desk), bounds x%.1f; "
                "load average %s on %d cores" % (self.took, self.quiet, self.ratio, load,
                                                  os.cpu_count() or 0))


def default_sigint():
    """Run in the child before bash starts (the bug campaign c12, h6-4): a
    runner started as a background job of a script (`( … ) &` in `bash -c`,
    a CI step) inherits SIGINT IGNORED, a shell cannot trap a signal that
    was ignored when it started, and the Ctrl-C below then did nothing —
    the test waited out its timeout and read as flaky under load. A real
    Ctrl-C reaches a script whose SIGINT is the default, so that is what
    the script under test is given."""
    signal.signal(signal.SIGINT, signal.SIG_DFL)


class LanSmokeInterruptTest(unittest.TestCase):
    """2026-10-03: `kill $!` signalled the backgrounded SUBSHELL, not the
    `timeout` (in a process group of its own) nor the Godot under it, and
    nothing trapped INT/TERM — so a Ctrl-C or a TERM left both Godots
    running for up to SMOKE_TIMEOUT while their run directory was deleted
    from under them."""

    def interrupt(self, signum, names, import_hangs=False, stand_in=STUCK_GODOT):
        with tempfile.TemporaryDirectory() as scratch:
            folder = Path(scratch)
            parent = folder / 'runs'
            parent.mkdir()
            fake = folder / 'fake-godot'
            fake.write_text(f'#!{sys.executable}\n' + stand_in)
            fake.chmod(0o755)
            env = dict(os.environ, GODOT=str(fake), LAN_SMOKE_DIR=str(parent),
                       FAKE_REPORT=str(folder), SHANDALAR_NO_BANNER='1',
                       SHANDALAR_TEST_DATA_HOME=str(folder / 'import-profile'))
            if import_hangs:
                env['FAKE_IMPORT_HANGS'] = '1'
            said = lambda: (folder / 'smoke.out').read_text()
            quiet = QUIET_START[tuple(names)] + (SLOW_PID_HOLD if stand_in is SLOW_PID_GODOT else 0)
            started = time.monotonic()
            # A session of its own, so whatever it started can be found and
            # stopped below, whichever way the test ends.
            with open(folder / 'smoke.out', 'w') as out:
                smoke = subprocess.Popen(['bash', str(ROOT / 'tools/lan_smoke.sh')], cwd=ROOT,
                                         env=env, stdin=subprocess.DEVNULL, stdout=out,
                                         stderr=subprocess.STDOUT, preexec_fn=default_sigint,
                                         start_new_session=True)
            try:
                # THE EVENT: every pid written, not every file there (or the
                # smoke gone already).
                def started_up():
                    found = [pid_in(folder / (n + '.pid')) for n in names]
                    return found if all(found) else smoke.poll() is not None
                pids = wait_for(started_up, 60 + 100 * quiet)
                pace = Pace(quiet, time.monotonic() - started)
                self.assertIsNone(smoke.poll(), said())
                self.assertTrue(pids, 'the fake Godots never started; %s' % pace)
                smoke.send_signal(signum)
                try:
                    status = smoke.wait(timeout=pace.bound(30))
                except subprocess.TimeoutExpired:
                    self.fail('lan_smoke.sh did not stop within %.0fs of the signal; %s'
                              % (pace.bound(30), pace))
                self.assertEqual(status, 128 + signum, '%s\n%s' % (said(), pace))
                for name, pid in zip(names, pids):
                    with self.subTest(process=name):
                        self.assertFalse(alive(pid), '%s Godot outlived the smoke; %s' % (name, pace))
                        self.assertEqual((folder / (name + '.verdict')).read_text(),
                                         'home still there')
                self.assertEqual(list(parent.iterdir()), [], 'the run directory is removed after')
            finally:
                if smoke.poll() is None:
                    smoke.kill()
                    smoke.wait()
                # NOTHING OUTLIVES THE TEST (r5-3): a failure before the pids
                # were read left both stand-ins sleeping out their 120 s. The
                # pid files say who they were; the session finds what never
                # wrote one.
                stragglers = set(session_of(smoke.pid))
                stragglers.update(pid_in(folder / (n + '.pid'))
                                  for n in ('import', 'host', 'guest'))
                for pid in stragglers:
                    if pid and alive(pid):
                        os.kill(pid, signal.SIGKILL)

    def test_sigterm_stops_both_godots_before_removing_their_run_directory(self):
        self.interrupt(signal.SIGTERM, ('host', 'guest'))

    def test_ctrl_c_stops_both_godots_before_removing_their_run_directory(self):
        self.interrupt(signal.SIGINT, ('host', 'guest'))

    def test_ctrl_c_during_the_import_stops_the_import(self):
        self.interrupt(signal.SIGINT, ('import',), import_hangs=True)

    def test_a_pid_file_seen_before_its_pid_is_waited_for(self):
        self.interrupt(signal.SIGINT, ('host', 'guest'), stand_in=SLOW_PID_GODOT)

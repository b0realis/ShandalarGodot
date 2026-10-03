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
(out / (name + '.pid')).write_text(str(os.getpid()))
time.sleep(120)
'''


def alive(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    return True


class LanSmokeInterruptTest(unittest.TestCase):
    """2026-10-03: `kill $!` signalled the backgrounded SUBSHELL, not the
    `timeout` (in a process group of its own) nor the Godot under it, and
    nothing trapped INT/TERM — so a Ctrl-C or a TERM left both Godots
    running for up to SMOKE_TIMEOUT while their run directory was deleted
    from under them."""

    def interrupt(self, signum, names, import_hangs=False):
        with tempfile.TemporaryDirectory() as scratch:
            folder = Path(scratch)
            parent = folder / 'runs'
            parent.mkdir()
            fake = folder / 'fake-godot'
            fake.write_text(f'#!{sys.executable}\n' + STUCK_GODOT)
            fake.chmod(0o755)
            env = dict(os.environ, GODOT=str(fake), LAN_SMOKE_DIR=str(parent),
                       FAKE_REPORT=str(folder), SHANDALAR_NO_BANNER='1',
                       SHANDALAR_TEST_DATA_HOME=str(folder / 'import-profile'))
            if import_hangs:
                env['FAKE_IMPORT_HANGS'] = '1'
            pids = []
            with open(folder / 'smoke.out', 'w') as out:
                smoke = subprocess.Popen(['bash', str(ROOT / 'tools/lan_smoke.sh')], cwd=ROOT,
                                         env=env, stdin=subprocess.DEVNULL, stdout=out,
                                         stderr=subprocess.STDOUT)
            try:
                deadline = time.monotonic() + 30
                while not all((folder / (n + '.pid')).exists() for n in names):
                    self.assertIsNone(smoke.poll(), (folder / 'smoke.out').read_text())
                    self.assertLess(time.monotonic(), deadline, 'the fake Godots never started')
                    time.sleep(0.05)
                pids = [int((folder / (n + '.pid')).read_text()) for n in names]
                smoke.send_signal(signum)
                status = smoke.wait(timeout=30)
                self.assertEqual(status, 128 + signum, (folder / 'smoke.out').read_text())
                for name, pid in zip(names, pids):
                    with self.subTest(process=name):
                        self.assertFalse(alive(pid), name + ' Godot outlived the smoke')
                        self.assertEqual((folder / (name + '.verdict')).read_text(),
                                         'home still there')
                self.assertEqual(list(parent.iterdir()), [], 'the run directory is removed after')
            finally:
                if smoke.poll() is None:
                    smoke.kill()
                    smoke.wait()
                for pid in pids:
                    if alive(pid):
                        os.kill(pid, signal.SIGKILL)

    def test_sigterm_stops_both_godots_before_removing_their_run_directory(self):
        self.interrupt(signal.SIGTERM, ('host', 'guest'))

    def test_ctrl_c_stops_both_godots_before_removing_their_run_directory(self):
        self.interrupt(signal.SIGINT, ('host', 'guest'))

    def test_ctrl_c_during_the_import_stops_the_import(self):
        self.interrupt(signal.SIGINT, ('import',), import_hangs=True)

#!/usr/bin/env python3
"""The shell fixes of the repository check (2026-10-13), each run for real
with a stand-in Godot, adb or SDK. No real Godot, no network.

Run from the repo root:
    python3 -m unittest discover -s tools -p 'test_c3_fx_scripts_shell.py'

What each class pins:
  * QuestBuildWithoutSdkTest — `build_release.sh --quest` on a machine with
    no JAVA_HOME, no Godot editor settings and no Android SDK finishes and
    says what it could not check. Under `set -euo pipefail` the failing `sed`
    and `ls` pipelines ended the build with exit 2 and no word.
  * HelpFromAnotherFolderTest — `shandalar.sh`, `build_release.sh`,
    `tools/lan_smoke.sh` and the packaged door answer `--help` from any
    folder. Each `cd`s to its own folder first and then read "$0", which
    no longer pointed anywhere when it was relative.
  * StageListTest — a stage with more than a pipe's worth of empty files or
    links fails with its BUILD FAILED line, not a silent exit 141 (`find |
    head` under pipefail).
  * ZipStageTest — the stage is searched for the home folder again once the
    skin zip is in it (it was searched only before), and the "release
    files" line names the skin zips only when they were written.
  * BuildArgumentsTest — a trailing `--out` or `--preset` is exit 3 with a
    sentence, not an "unbound variable" exit 1.
  * SoakInterruptTest — a Ctrl-C reaches Godot during `duel_soak.sh`, with
    and without xvfb-run, and the script stops with 130 instead of waiting
    out SOAK_TIMEOUT and carrying on.
  * RunTestsGateTest — `run_tests.sh` says so when the test profile's packs
    cannot be reset (a sharded run graded the LAST run's shard log), and
    one CI shard (SHARD=i) is held to the number of scripts dealt to it.
  * QuestEmptyLogTest — the clean-install script counts an empty log as
    "0 lines", once.
  * RuntimeOnMacTest — on a Mac without Godot.app, a `godot` on PATH is
    chosen over the Linux binary in ../tools.
"""
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest
import zipfile
from pathlib import Path

import test_build_release_sh as release
import test_quest_scripts as quest

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build_release.sh"


def function_of(source: str, name: str) -> str:
    """One shell function, `name() {` to its closing brace at column 0."""
    return name + "() {" + source.split(name + "() {", 1)[1].split("\n}\n", 1)[0] + "\n}\n"


def quiet_env(**extra) -> dict:
    env = dict(os.environ, SHANDALAR_NO_BANNER="1")
    env.update(extra)
    return env


class QuestBuildWithoutSdkTest(unittest.TestCase):

    def test_a_quest_build_without_java_settings_or_sdk_finishes(self):
        with tempfile.TemporaryDirectory() as tmp:
            scratch = Path(tmp)
            stub = scratch / "godot"
            stub.write_text("#!%s\n%s" % (sys.executable, release.STUB_QUEST_GODOT))
            stub.chmod(0o755)
            home = scratch / "home"
            home.mkdir()
            env = quiet_env(GODOT=str(stub), TMPDIR=str(scratch), HOME=str(home),
                            GODOT_ANDROID_KEYSTORE_RELEASE_PATH="/nonexistent.keystore")
            for name in ("JAVA_HOME", "ANDROID_HOME"):
                env.pop(name, None)
            done = subprocess.run(["bash", str(BUILD), "--quest", "--out", str(scratch / "quest")],
                                  cwd=str(ROOT), env=env, stdin=subprocess.DEVNULL,
                                  capture_output=True, text=True, timeout=180)
            self.assertEqual(done.returncode, 0, done.stdout + done.stderr)
            self.assertIn("Meta Quest APK", done.stdout)
            self.assertIn("note: no aapt", done.stderr)
            self.assertIn("note: no apksigner", done.stderr)


class HelpFromAnotherFolderTest(unittest.TestCase):

    def help_of(self, argv, cwd):
        return subprocess.run(argv, cwd=str(cwd), env=quiet_env(), stdin=subprocess.DEVNULL,
                              capture_output=True, text=True, timeout=60)

    def test_each_entry_point_answers_help_from_any_folder(self):
        cases = (("shandalar.sh", ["--help"]), ("shandalar.sh", []),
                 ("build_release.sh", ["--help"]), ("tools/lan_smoke.sh", ["--help"]))
        for script, args in cases:
            home = self.help_of(["./" + script, *args], ROOT)
            self.assertEqual(home.returncode, 0, home.stderr)
            self.assertTrue(home.stdout.strip(), script)
            for cwd, spelled in ((ROOT.parent, ROOT.name + "/" + script),
                                 (ROOT / Path(script).parent, "./" + Path(script).name),
                                 (Path("/"), str(ROOT / script))):
                with self.subTest(script=script, args=args, cwd=str(cwd)):
                    done = self.help_of([spelled, *args], cwd)
                    self.assertEqual(done.returncode, 0, done.stderr)
                    self.assertEqual(done.stdout, home.stdout)
                    self.assertNotIn("sed:", done.stderr)

    def test_the_packaged_door_answers_help_from_any_folder(self):
        with tempfile.TemporaryDirectory() as tmp:
            game = Path(tmp) / "Shandalar"
            game.mkdir()
            door = game / "shandalar.sh"
            door.write_text(release.heredoc("DOOR").replace("@VERSION@", "9.9.9"))
            door.chmod(0o755)
            inside = self.help_of(["./shandalar.sh", "--help"], game)
            outside = self.help_of(["Shandalar/shandalar.sh", "--help"], tmp)
            self.assertEqual(inside.returncode, 0, inside.stderr)
            self.assertEqual(outside.returncode, 0, outside.stderr)
            self.assertIn("one door to the command-line tools", inside.stdout)
            self.assertEqual(outside.stdout, inside.stdout)


class StageListTest(unittest.TestCase):

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.stage = self.root / "stage"
        self.stage.mkdir()

    def tearDown(self):
        self.tmp.cleanup()

    def names(self, count):
        # Long names, and enough of them that the list is several pipe
        # buffers (64 KiB on Linux) long: with only one or two, `find` can
        # finish writing before `head` closes the pipe, and the old code
        # passed by luck.
        return ["picture_of_a_card_with_a_long_file_name_number_%04d.jpg" % i for i in range(count)]

    def test_many_empty_files_fail_the_stage_with_its_message(self):
        src = self.root / "src"
        src.mkdir()
        for name in self.names(4000):
            (src / name).write_bytes(b"")
        script = function_of(release.SOURCE, "stage_copy") + 'stage_copy "$1" "$2"'
        done = subprocess.run(["bash", "-c", "set -euo pipefail\n" + script, "stage-test",
                               str(src), str(self.stage)], capture_output=True, text=True, timeout=120)
        self.assertEqual(done.returncode, 1, done.stderr)
        self.assertIn("BUILD FAILED: empty files in the staged copy", done.stderr)

    def test_many_links_fail_the_guard_with_its_message(self):
        target = self.root / "outside.txt"
        target.write_text("x\n")
        for name in self.names(4000):
            (self.stage / name).symlink_to(target)
        script = release.guard_function() + 'guard_stage "$1"'
        done = subprocess.run(["bash", "-c", "set -euo pipefail\n" + script, "guard-test",
                               str(self.stage)], capture_output=True, text=True, timeout=120,
                              cwd=str(ROOT))
        self.assertEqual(done.returncode, 1, done.stderr)
        self.assertIn("BUILD FAILED: a symlink in the package", done.stderr)


class ZipStageTest(unittest.TestCase):
    """The stage is searched again once the skin zip is in it, and the
    "release files" line names only the zips that were written."""

    def zip_stage(self, skin_text):
        with tempfile.TemporaryDirectory() as tmp:
            scratch = Path(tmp)
            pkg = scratch / "pkg"
            stage = pkg / "Shandalar-9.9.9-linux64"
            (stage / "skin").mkdir(parents=True)
            (stage / "README.txt").write_text("unpack and run\n")
            skin = scratch / "skin.zip"
            with zipfile.ZipFile(skin, "w", compression=zipfile.ZIP_DEFLATED) as archive:
                archive.writestr("skin/notes.txt", skin_text * 40)
            script = ("set -euo pipefail\n" + release.guard_function()
                      + function_of(release.SOURCE, "zip_stage")
                      + 'skin_zip() { cp "$SKIN" "$1"; }\n'
                      + 'PKG_DIR="$1"\nzip_stage "$2" Shandalar-9.9.9-linux64\n')
            done = subprocess.run(["bash", "-c", script, "zip-stage-test", str(pkg), str(stage)],
                                  cwd=str(ROOT), env=dict(os.environ, SKIN=str(skin)),
                                  capture_output=True, text=True, timeout=120)
            return done, sorted(path.name for path in pkg.glob("*.zip"))

    @unittest.skipUnless(shutil.which("zip"), "zip is not installed")
    def test_a_home_path_in_the_skin_zip_stops_the_with_skin_zip(self):
        done, zips = self.zip_stage(os.environ["HOME"] + "/skins\n")
        self.assertEqual(done.returncode, 1, done.stdout + done.stderr)
        self.assertIn("home folder", done.stderr)
        self.assertNotIn("Shandalar-9.9.9-linux64-with-skin.zip", zips)

    @unittest.skipUnless(shutil.which("zip"), "zip is not installed")
    def test_a_clean_skin_zip_still_gives_both_zips(self):
        done, zips = self.zip_stage("a picture's notes\n")
        self.assertEqual(done.returncode, 0, done.stdout + done.stderr)
        self.assertIn("Shandalar-9.9.9-linux64.zip", zips)
        self.assertIn("Shandalar-9.9.9-linux64-with-skin.zip", zips)

    def test_the_release_files_line_names_skin_zips_only_when_written(self):
        lines = release.SOURCE.splitlines()
        named = [i for i, line in enumerate(lines)
                 if 'echo "release files:' in line and "-with-skin.zip" in line]
        self.assertEqual(len(named), 2, "the Linux and the web package")
        for i in named:
            self.assertEqual(lines[i - 1].strip(), 'if [ -f "$PKG_DIR/original_skin.zip" ]; then',
                             lines[i])


class BuildArgumentsTest(unittest.TestCase):

    def test_a_trailing_option_without_its_value_is_exit_3(self):
        for option in ("--out", "--preset"):
            with self.subTest(option=option):
                done = subprocess.run(["bash", str(BUILD), option], cwd=str(ROOT), env=quiet_env(),
                                      stdin=subprocess.DEVNULL, capture_output=True, text=True,
                                      timeout=60)
                self.assertEqual(done.returncode, 3, done.stderr)
                self.assertIn(option + " needs a value", done.stderr)
                self.assertNotIn("unbound variable", done.stderr)


SLEEPING_GODOT = """#!/bin/sh
# Stands in for Godot: notes its pid, then plays "a duel" for a minute.
echo $$ > "$FAKE_PIDFILE"
exec sleep 60
"""


class SoakInterruptTest(unittest.TestCase):

    def soak(self, headless):
        with tempfile.TemporaryDirectory() as tmp:
            scratch = Path(tmp)
            stub = scratch / "godot"
            stub.write_text(SLEEPING_GODOT)
            stub.chmod(0o755)
            pidfile = scratch / "godot.pid"
            env = quiet_env(GODOT=str(stub), FAKE_PIDFILE=str(pidfile), SOAK_TIMEOUT="45",
                            SHANDALAR_TEST_DATA_HOME=str(scratch / "data"))
            env.pop("SOAK_HEADLESS", None)
            if headless:
                env["SOAK_HEADLESS"] = "1"
            # A session of its own, so the INT below goes to the script's
            # process group the way a terminal's Ctrl-C does — and to
            # nothing else on this machine. And SIGINT at its default in
            # it (the bug campaign c12, h6-4): a runner started as a
            # background job of a script inherits it IGNORED, the script
            # cannot trap a signal ignored on entry, and this Ctrl-C did
            # nothing — the test timed out and read as flaky under load.
            proc = subprocess.Popen(["bash", str(ROOT / "duel_soak.sh"), "--count", "1"],
                                    cwd=str(ROOT), env=env, stdin=subprocess.DEVNULL,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                    start_new_session=True,
                                    preexec_fn=lambda: signal.signal(signal.SIGINT, signal.SIG_DFL))
            try:
                deadline = time.time() + 30
                while not (pidfile.is_file() and pidfile.read_text().strip()) and time.time() < deadline:
                    time.sleep(0.1)
                self.assertTrue(pidfile.is_file(), "the stand-in Godot never started")
                godot = int(pidfile.read_text())
                os.killpg(proc.pid, signal.SIGINT)
                try:
                    proc.communicate(timeout=20)
                except subprocess.TimeoutExpired:
                    self.fail("duel_soak.sh did not stop on a Ctrl-C")
                self.assertEqual(proc.returncode, 130)
                deadline = time.time() + 10
                while alive(godot) and time.time() < deadline:
                    time.sleep(0.1)
                self.assertFalse(alive(godot), "Godot was left running")
            finally:
                if proc.poll() is None:
                    os.killpg(proc.pid, signal.SIGKILL)
                    proc.communicate()

    def test_a_ctrl_c_reaches_a_headless_soak(self):
        self.soak(headless=True)

    @unittest.skipUnless(sys.platform.startswith("linux") and shutil.which("xvfb-run"),
                         "the soak runs under xvfb-run on Linux only")
    def test_a_ctrl_c_reaches_a_soak_under_xvfb_run(self):
        self.soak(headless=False)


def alive(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    # A zombie still answers kill 0; it has stopped all the same.
    try:
        with open("/proc/%d/stat" % pid) as stat:
            return stat.read().split(") ", 1)[1][0] != "Z"
    except OSError:
        return True


GUT_GODOT = r"""#!/bin/sh
# Stands in for Godot under run_tests.sh: the import and the pack reset
# answer at once, and GUT's totals count the scripts it was handed with
# -gtest (or FAKE_SCRIPTS).
for arg in "$@"; do
	case "$arg" in
		--import) exit 0 ;;
		*reset_test_packs.gd) exit "${FAKE_RESET:-0}" ;;
		-gtest=*) given=$(printf '%s' "${arg#-gtest=}" | tr ',' '\n' | grep -c .) ;;
	esac
done
case " $* " in
	*gut_cmdln.gd*)
		printf 'Totals\n------\nScripts               %s\nTests                 1\nPassing Tests         1\nAsserts               1\n' "${FAKE_SCRIPTS:-${given:-1}}"
		exit 0 ;;
esac
exit 9
"""


class RunTestsGateTest(unittest.TestCase):

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.scratch = Path(self.tmp.name)
        self.stub = self.scratch / "godot"
        self.stub.write_text(GUT_GODOT)
        self.stub.chmod(0o755)
        self.data = self.scratch / "data"

    def tearDown(self):
        self.tmp.cleanup()

    def run_tests(self, **extra):
        env = quiet_env(GODOT=str(self.stub), SHANDALAR_TEST_DATA_HOME=str(self.data),
                        TMPDIR=str(self.scratch))
        for name in ("SHARD", "SHARDS", "FAKE_RESET", "FAKE_SCRIPTS"):
            env.pop(name, None)
        env.update(extra)
        return subprocess.run(["bash", str(ROOT / "run_tests.sh")], cwd=str(ROOT), env=env,
                              stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=300)

    def test_one_ci_shard_is_held_to_its_deal(self):
        done = self.run_tests(SHARDS="4", SHARD="2")
        self.assertEqual(done.returncode, 0, done.stdout[-2000:] + done.stderr)
        done = self.run_tests(SHARDS="4", SHARD="2", FAKE_SCRIPTS="3")
        self.assertEqual(done.returncode, 1, done.stdout[-2000:] + done.stderr)
        self.assertIn("SUITE IS NOT GREEN: shard 2 of 4 was dealt", done.stderr)
        self.assertIn("GUT ran 3", done.stderr)

    def test_a_failed_pack_reset_is_said_in_one_process(self):
        done = self.run_tests(SHARDS="1", FAKE_RESET="2")
        self.assertEqual(done.returncode, 1, done.stdout[-2000:] + done.stderr)
        self.assertIn("packs could not be reset", done.stderr)

    def test_a_failed_pack_reset_never_grades_the_last_runs_shard_log(self):
        for shard in ("shard-1", "shard-2"):
            (self.data / shard).mkdir(parents=True)
            (self.data / shard / "gut.log").write_text(
                "Totals\n------\nScripts 2\nTests 3\nPassing Tests 3\nAsserts 3\n")
        done = self.run_tests(SHARDS="2", FAKE_RESET="2")
        self.assertEqual(done.returncode, 1, done.stdout[-2000:] + done.stderr)
        for shard in ("shard-1", "shard-2"):
            log = (self.data / shard / "gut.log").read_text()
            self.assertIn("packs could not be reset", log)
            self.assertNotIn("Passing Tests 3", log)


class QuestEmptyLogTest(unittest.TestCase):

    def test_an_empty_log_is_zero_lines_said_once(self):
        case = quest.QuestScriptsTest("test_fresh_install_deletes_installs_and_copies")
        case.setUp()
        self.addCleanup(case.tearDown)
        adb = case.bin / "adb"
        text = adb.read_text()
        silent = text.replace('echo "I/godot: started"; exec sleep 600', "exec sleep 600")
        self.assertNotEqual(silent, text, "the stand-in adb's logcat line moved")
        adb.write_text(silent)
        done = case.run_script("quest_fresh_install.sh", "yes\n\n\ny\n\n\n\ny\n")
        self.assertEqual(done.returncode, 0, done.stdout + done.stderr)
        self.assertRegex(done.stdout, r"log: \S+ \(0 lines\)")


class RuntimeOnMacTest(unittest.TestCase):

    def godot_chosen(self, system, godot_on_path):
        with tempfile.TemporaryDirectory() as tmp:
            scratch = Path(tmp)
            (scratch / "proj").mkdir()
            (scratch / "tools").mkdir()
            (scratch / "bin").mkdir()
            for path, text in ((scratch / "tools" / "godot", "#!/bin/sh\n"),
                               (scratch / "bin" / "uname", "#!/bin/sh\necho %s\n" % system)):
                path.write_text(text)
                path.chmod(0o755)
            if godot_on_path:
                (scratch / "bin" / "godot").write_text("#!/bin/sh\n")
                (scratch / "bin" / "godot").chmod(0o755)
            env = dict(os.environ, PATH="%s%s%s" % (scratch / "bin", os.pathsep, os.environ["PATH"]))
            env.pop("GODOT", None)
            done = subprocess.run(["bash", "-c", '. "$1"; shandalar_find_godot; echo "$GODOT"', "rt",
                                   str(ROOT / "tools" / "runtime.sh")], cwd=str(scratch / "proj"),
                                  env=env, capture_output=True, text=True, timeout=30)
            self.assertEqual(done.returncode, 0, done.stderr)
            return done.stdout.strip()

    def test_a_mac_without_the_app_prefers_godot_on_path(self):
        self.assertEqual(self.godot_chosen("Darwin", godot_on_path=True), "godot")

    def test_a_mac_with_nothing_else_still_tries_the_sibling(self):
        self.assertEqual(self.godot_chosen("Darwin", godot_on_path=False), "../tools/godot")

    def test_linux_keeps_the_sibling_first(self):
        self.assertEqual(self.godot_chosen("Linux", godot_on_path=True), "../tools/godot")


if __name__ == "__main__":
    unittest.main()

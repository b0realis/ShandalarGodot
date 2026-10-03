#!/usr/bin/env python3
"""Self-test for the parts of `build_release.sh` that run without an
export template (bug pass of 2026-10-03). No network, and no Godot: a
stub stands in for the engine and for the exported binary, and the
functions and heredocs are read out of the script's own text the way
tools/test_pack_*.py read `guard_stage`.

Run from the repo root:
    python3 -m unittest discover -s tools -p 'test_*.py'

WHAT THIS HOLDS:

  * THE LEAK GATE READS BOTH WORDINGS. Godot prints "1 ObjectDB
    instance was leaked at exit" for one object and "N ObjectDB
    instances were leaked" for more; a gate that greps only the plural
    passes a build that leaks exactly one.
  * guard_stage SEARCHES THE .pck (the presets' include_filter packs any
    `*.txt` it is not told to skip, so a stray run report naming the
    builder's home rode inside it, unsearched) and REFUSES A SYMLINK in
    a stage (`zip -r` follows one and packs whatever it points at, while
    `grep -r` does not follow it, so it was never searched).
  * EVERY PRESET IN export_presets.cfg.example EXCLUDES DeckLab/results/
    and workspace/ — the Deck Lab's and the MCP server's run folders.
  * THE SMOKE BOOT NEVER TOUCHES THE OWNER'S PROFILE: the exported binary
    runs with its own XDG_DATA_HOME under the build's tmp/ and its own
    --log-file, so it neither writes `user://` nor rotates the owner's
    play logs out of `user://logs/`.
  * shortcut.sh WRITES AN Exec= LINE THE DESKTOP READS AS ONE PROGRAM
    whatever folder the game was unpacked in — a space (`My Games`), a
    quote, a dollar, a backslash, a percent sign.
  * THE RELEASE'S ONE DOOR refuses an unknown verb as one VALID JSON
    line whatever bytes the verb held.
"""

import json
import os
import re
import shutil
import time
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "build_release.sh"
SOURCE = SCRIPT.read_text(encoding="utf-8")

ONE = "WARNING: 1 ObjectDB instance was leaked at exit (run with `--verbose` for details)."
MANY = "WARNING: 2 ObjectDB instances were leaked at exit (run with `--verbose` for details)."


def heredoc(tag):
    """The body of `cat > ... <<'TAG'` ... `TAG` in build_release.sh."""
    start = SOURCE.index("<<'%s'\n" % tag) + len("<<'%s'\n" % tag)
    end = SOURCE.index("\n%s\n" % tag, start)
    return SOURCE[start:end + 1]


def guard_function():
    return "guard_stage() {" + SOURCE.split("guard_stage() {", 1)[1].split("\n}\n", 1)[0] + "\n}\n"


class LeakGateTest(unittest.TestCase):
    def test_every_leak_gate_reads_the_singular_and_the_plural(self):
        gates = re.findall(r"grep (-q[A-Za-z]*) '([^']*ObjectDB[^']*)'", SOURCE)
        self.assertTrue(gates, "build_release.sh reads the exit-time leak line somewhere")
        for flags, pattern in gates:
            for line in (ONE, MANY):
                with self.subTest(pattern=pattern, line=line):
                    done = subprocess.run(["grep", flags, pattern], input=line + "\n",
                                          text=True, capture_output=True)
                    self.assertEqual(done.returncode, 0, "the gate misses: " + line)
            done = subprocess.run(["grep", flags, pattern], input="ObjectDB ok\n",
                                  text=True, capture_output=True)
            self.assertEqual(done.returncode, 1, "a clean log passes")


class GuardStageTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.stage = self.root / "stage"
        self.stage.mkdir()

    def tearDown(self):
        for path in self.root.rglob("*"):
            if not path.is_symlink():
                path.chmod(0o755 if path.is_dir() else 0o644)
        self.tmp.cleanup()

    def guard(self, home=None):
        env = dict(os.environ)
        if home is not None:
            env["HOME"] = home
        return subprocess.run(["bash", "-c", guard_function() + 'guard_stage "$1"', "guard-test",
                               str(self.stage)], capture_output=True, text=True, env=env)

    def test_a_clean_stage_with_a_binary_pck_passes(self):
        (self.stage / "Shandalar.pck").write_bytes(b"GDPC\x00\x01\x02res://decks/a.deck\x00\xff")
        (self.stage / "README.txt").write_text("unpack and run\n")
        done = self.guard()
        self.assertEqual(done.returncode, 0, done.stderr)

    def test_the_home_path_inside_the_pck_is_refused(self):
        # What an include_filter of "*.txt" packs from DeckLab/results/:
        # a report whose "next:" line names a deck under the home folder.
        (self.stage / "Shandalar.pck").write_bytes(
            b"GDPC\x00\x00res://DeckLab/results/run_1/report.txt\x00next: --deck-a "
            + os.environ["HOME"].encode() + b"/decks/x.deck\n\x00\xff")
        done = self.guard()
        self.assertNotEqual(done.returncode, 0)
        self.assertIn("Shandalar.pck", done.stderr)
        self.assertIn("home folder", done.stderr)

    def test_a_symlink_in_the_stage_is_refused(self):
        outside = self.root / "outside.txt"
        outside.write_text("whatever zip -r would pack in its place\n")
        (self.stage / "skin").mkdir()
        (self.stage / "skin" / "linked.txt").symlink_to(outside)
        done = self.guard()
        self.assertNotEqual(done.returncode, 0)
        self.assertIn("linked.txt", done.stderr)
        self.assertIn("link", done.stderr)

    def test_a_linked_folder_in_the_stage_is_refused(self):
        (self.root / "elsewhere").mkdir()
        (self.stage / "tools").symlink_to(self.root / "elsewhere")
        done = self.guard()
        self.assertNotEqual(done.returncode, 0)
        self.assertIn("tools", done.stderr)

    @unittest.skipIf(hasattr(os, "geteuid") and os.geteuid() == 0, "root reads everything")
    def test_an_unreadable_file_is_refused_not_skipped(self):
        secret = self.stage / "notes.txt"
        secret.write_text(os.environ["HOME"] + "/x\n")
        secret.chmod(0)
        done = self.guard()
        self.assertNotEqual(done.returncode, 0)
        self.assertIn("notes.txt", done.stderr)

    def test_a_root_or_empty_home_does_not_refuse_every_file(self):
        (self.stage / "README.txt").write_text("see /usr/share/doc\n")
        for home in ("/", ""):
            with self.subTest(home=home):
                done = self.guard(home=home)
                self.assertEqual(done.returncode, 0, done.stderr)


class PresetFilterTest(unittest.TestCase):
    def test_every_preset_excludes_the_lab_and_mcp_run_folders(self):
        text = (ROOT / "export_presets.cfg.example").read_text(encoding="utf-8")
        sections = re.split(r"(?m)^\[preset\.\d+\]\n", text)[1:]
        self.assertGreaterEqual(len(sections), 7)
        for section in sections:
            name = re.search(r'(?m)^name="([^"]*)"', section).group(1)
            exclude = re.search(r'(?m)^exclude_filter="([^"]*)"', section).group(1)
            entries = [entry.strip() for entry in exclude.split(",")]
            with self.subTest(preset=name):
                self.assertIn("DeckLab/results/*", entries)
                self.assertIn("workspace/*", entries)

    @staticmethod
    def sections():
        text = (ROOT / "export_presets.cfg.example").read_text(encoding="utf-8")
        out = {}
        for section in re.split(r"(?m)^\[preset\.\d+\]\n", text)[1:]:
            out[re.search(r'(?m)^name="([^"]*)"', section).group(1)] = section
        return out

    def test_every_preset_the_script_exports_is_in_the_example(self):
        # The example is what a new machine starts from; the Android Quest
        # preset was missing from it from 0.40.48 until 0.50.8, and a
        # count ("at least seven") could not notice (bug pass 2026-10-03).
        wanted = set(re.findall(r'PRESET="([^"$]+)"', SOURCE))
        self.assertTrue({"Linux 64", "Web", "macOS", "Android Quest"} <= wanted, wanted)
        self.assertEqual(wanted - set(self.sections()), set())

    def test_the_quest_preset_asks_for_the_network(self):
        # LAN play (host, join, discovery, tournaments) needs sockets, and
        # Android refuses them to an app whose manifest lacks INTERNET; the
        # permission cannot be added after a sideload (2026-10-03).
        quest = self.sections()["Android Quest"]
        for permission in ("internet", "access_network_state", "access_wifi_state"):
            with self.subTest(permission=permission):
                self.assertRegex(quest, r"(?m)^permissions/%s=true$" % permission)

    def test_the_quest_preset_names_the_script_that_loads_the_key(self):
        text = (ROOT / "export_presets.cfg.example").read_text(encoding="utf-8")
        self.assertNotIn("build_quest.sh", text, "no such script exists")
        self.assertIn("build_release.sh --quest", text)
        self.assertIn("QUEST_KEY_ENV", SOURCE)


class QuestGuardTest(unittest.TestCase):
    def test_the_quest_build_scans_the_apk_for_the_home_folder(self):
        # An APK is a zip of DEFLATED files: a grep of its bytes cannot see
        # a home path inside one, so the Quest branch hands the APK to
        # package_release.guard_private, which reads every member.
        branch = SOURCE[SOURCE.index("# THE QUEST BUILD ENDS HERE"):]
        branch = branch[:branch.index("exit 0")]
        self.assertIn("guard_private", branch)
        self.assertIn('"$BIN"', branch[branch.index("guard_private"):])


STUB_GODOT = r'''
import os, pathlib, sys
args = sys.argv[1:]
if "--import" in args:
    sys.exit(0)
mode = [a for a in args if a.startswith("--export-")]
if mode:
    binary = pathlib.Path(args[-1])
    binary.write_text("#!%s\n" % sys.executable + """
import json, os, sys
report = os.environ["FAKE_REPORT"]
with open(report, "w") as out:
    json.dump({"argv": sys.argv[1:], "xdg": os.environ.get("XDG_DATA_HOME")}, out)
print("booted")
""")
    binary.chmod(0o755)
    (binary.parent / "Shandalar.pck").write_bytes(b"GDPC")
    sys.exit(0)
sys.exit(9)
'''


class SmokeBootTest(unittest.TestCase):
    def test_the_smoke_boot_runs_in_a_profile_of_its_own(self):
        with tempfile.TemporaryDirectory() as tmp:
            scratch = Path(tmp)
            stub = scratch / "godot"
            stub.write_text("#!%s\n%s" % (sys.executable, STUB_GODOT))
            stub.chmod(0o755)
            out = scratch / "build" / "linux64"
            report = scratch / "smoke.json"
            env = dict(os.environ, GODOT=str(stub), TMPDIR=str(scratch), FAKE_REPORT=str(report),
                       SHANDALAR_NO_BANNER="1")
            env.pop("XDG_DATA_HOME", None)
            done = subprocess.run(["bash", str(SCRIPT), "--out", str(out)], cwd=str(ROOT), env=env,
                                  stdin=subprocess.DEVNULL, capture_output=True, text=True,
                                  timeout=120)
            self.assertEqual(done.returncode, 0, done.stdout + done.stderr)
            self.assertIn("ok:", done.stdout)
            smoke = json.loads(report.read_text())
            work = (scratch / "build" / "tmp").resolve()
            self.assertIsNotNone(smoke["xdg"], "the smoke boot sets XDG_DATA_HOME")
            self.assertTrue(Path(smoke["xdg"]).resolve().is_relative_to(work), smoke["xdg"])
            self.assertTrue(Path(smoke["xdg"]).is_dir())
            self.assertIn("--log-file", smoke["argv"])
            log = Path(smoke["argv"][smoke["argv"].index("--log-file") + 1])
            self.assertTrue(log.resolve().is_relative_to(work), log)


def desktop_exec_argv(value):
    """The argv a desktop runs for an Exec= value (Desktop Entry
    Specification 1.5, "The Exec key"): the value is a string, so its
    own escapes come off first (\\s \\n \\t \\r \\\\); then arguments split
    on spaces, a double-quoted one may hold any character, and inside
    the quotes a backslash escapes " ` $ and itself; %% is a literal %."""
    unescaped, i = [], 0
    while i < len(value):
        if value[i] == "\\" and i + 1 < len(value):
            unescaped.append({"s": " ", "n": "\n", "t": "\t", "r": "\r", "\\": "\\"}.get(
                value[i + 1], "\\" + value[i + 1]))
            i += 2
        else:
            unescaped.append(value[i])
            i += 1
    text = "".join(unescaped)
    argv, current, quoted, started, i = [], [], False, False, 0
    reserved = set(" \t\n\"'\\><~|&;$*?#()`")
    while i < len(text):
        c = text[i]
        if quoted:
            if c == "\\" and i + 1 < len(text) and text[i + 1] in '"`$\\':
                current.append(text[i + 1])
                i += 2
                continue
            if c == '"':
                quoted = False
            elif c in '"`$\\':
                raise ValueError("unescaped %r inside quotes in %r" % (c, value))
            else:
                current.append(c)
        elif c == '"':
            quoted, started = True, True
        elif c == " ":
            if started:
                argv.append("".join(current))
            current, started = [], False
        elif c in reserved:
            raise ValueError("reserved %r outside quotes in %r" % (c, value))
        else:
            current.append(c)
            started = True
        i += 1
    if quoted:
        raise ValueError("unterminated quote in %r" % value)
    if started:
        argv.append("".join(current))
    joined = []
    for arg in argv:
        if re.search(r"%(?!%)", arg.replace("%%", "")):
            raise ValueError("a field code in %r" % arg)
        joined.append(arg.replace("%%", "%"))
    return joined


def desktop_string(value):
    return re.sub(r"\\(.)", lambda m: {"s": " ", "n": "\n", "t": "\t", "r": "\r"}.get(
        m.group(1), m.group(1)), value)


class ShortcutTest(unittest.TestCase):
    def shortcut_in(self, folder_name):
        with tempfile.TemporaryDirectory() as tmp:
            scratch = Path(tmp)
            game = scratch / folder_name
            game.mkdir(parents=True)
            (game / "shortcut.sh").write_text(heredoc("SHORTCUT"))
            (game / "Shandalar.x86_64").write_text("#!/bin/sh\n")
            for name in ("shortcut.sh", "Shandalar.x86_64"):
                (game / name).chmod(0o755)
            env = dict(os.environ, XDG_DATA_HOME=str(scratch / "xdg"))
            done = subprocess.run(["bash", str(game / "shortcut.sh")], env=env,
                                  stdin=subprocess.DEVNULL, capture_output=True, text=True,
                                  timeout=60)
            self.assertEqual(done.returncode, 0, done.stderr)
            entry = (scratch / "xdg" / "applications" / "shandalar.desktop").read_text()
            keys = dict(line.split("=", 1) for line in entry.splitlines() if "=" in line)
            return game.resolve(), keys

    def test_exec_is_one_program_whatever_the_folder_is_called(self):
        for name in ("Shandalar", "My Games/Shandalar", 'It\'s 100% "$HOME" \\ `x`/game'):
            with self.subTest(folder=name):
                game, keys = self.shortcut_in(name)
                program = str(game / "Shandalar.x86_64")
                # A % in the folder: GLib cannot look such a PROGRAM up, so
                # sh is the program and the game its argument (2026-10-03).
                expected = (["sh", "-c", 'exec "$0"', program] if "%" in program else [program])
                self.assertEqual(desktop_exec_argv(keys["Exec"]), expected)
                self.assertEqual(desktop_string(keys["Path"]), str(game))
                self.assertEqual(desktop_string(keys["Icon"]), str(game / "icon.png"))

    @unittest.skipUnless(shutil.which("gio"), "GLib's launcher (gio) is not installed")
    def test_glib_launches_the_game_from_a_folder_with_a_percent(self):
        with tempfile.TemporaryDirectory() as tmp:
            scratch = Path(tmp)
            game = scratch / "Games 100%" / "Shandalar"
            game.mkdir(parents=True)
            marker = scratch / "launched"
            (game / "shortcut.sh").write_text(heredoc("SHORTCUT"))
            (game / "Shandalar.x86_64").write_text('#!/bin/sh\npwd > "%s"\n' % marker)
            for name in ("shortcut.sh", "Shandalar.x86_64"):
                (game / name).chmod(0o755)
            env = dict(os.environ, XDG_DATA_HOME=str(scratch / "xdg"))
            done = subprocess.run(["bash", str(game / "shortcut.sh")], env=env, stdin=subprocess.DEVNULL,
                                  capture_output=True, text=True, timeout=60)
            self.assertEqual(done.returncode, 0, done.stderr)
            entry = scratch / "xdg" / "applications" / "shandalar.desktop"
            subprocess.run(["gio", "launch", str(entry)], env=env, stdin=subprocess.DEVNULL,
                           capture_output=True, timeout=30)
            deadline = time.time() + 10
            while not marker.is_file() and time.time() < deadline:
                time.sleep(0.1)
            self.assertTrue(marker.is_file(), "GLib did not start the game")
            self.assertEqual(marker.read_text().strip(), str(game.resolve()))


class ReleaseDoorTest(unittest.TestCase):
    def test_an_unknown_verb_is_valid_json_whatever_bytes_it_held(self):
        with tempfile.TemporaryDirectory() as tmp:
            door = Path(tmp) / "shandalar.sh"
            door.write_text(heredoc("DOOR").replace("@VERSION@", "9.9.9"))
            door.chmod(0o755)
            for verb in (b"nope", b'we"ird', b"back\\slash", b"bad\x1bverb", b"bell\x07\x7f",
                         b"caf\xe9", "café".encode(), b"\xff\xfe"):
                with self.subTest(verb=verb):
                    done = subprocess.run([str(door).encode(), verb], capture_output=True,
                                          stdin=subprocess.DEVNULL, timeout=60)
                    self.assertEqual(done.returncode, 2, done.stderr)
                    lines = done.stdout.splitlines()
                    self.assertEqual(len(lines), 1, done.stdout)
                    error = json.loads(lines[0])["error"]
                    self.assertEqual(error["exit"], 2)
                    self.assertEqual(error["kind"], "option")
                    if verb == "café".encode():
                        self.assertEqual(error["verb"], "café", "valid UTF-8 is kept")


if __name__ == "__main__":
    unittest.main()

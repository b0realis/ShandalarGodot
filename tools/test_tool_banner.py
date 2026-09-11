#!/usr/bin/env python3
"""Self-test for the family banner — tools/tool_banner.py, tools/banner.sh
and the twelve tools that wear them. No network, no Godot.

Run from the repo root:
    python3 -m unittest discover -s tools -p 'test_*.py'

THE RULE THESE PIN, and it is the one that would actually hurt: the
decoration is stderr-and-a-terminal only. `build_card_packs.py`'s stdout
is a build report, `skin_catalogue.py --stdout` IS the catalogue,
`build_release.sh`'s stdout names the files a release is made of and
`run_tests.sh`/`duel_soak.sh` have gates that grep their own logs. A
wordmark in any of those is a bug, not a flourish — so every test below
either proves nothing decorative reaches stdout, or proves nothing at all
is drawn when the far end is not a terminal.

The second thing pinned here is the version: ONE source (project.godot's
`config/version`), read the same way by the GDScript, Python and shell
sides, and an honest "version unknown" wherever that file cannot be
found — which is what the four tools that ship beside the packaged game
see (2026-09-11).
"""

import io
import os
import pty
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import tool_banner  # noqa: E402

TOOLS_DIR = Path(__file__).resolve().parent
ROOT = TOOLS_DIR.parent
SGR = re.compile("\x1b\\[[0-9;]*m")

## Every Python tool in the family, and the module attribute that holds
## its wordmark. The test suite imports them, so a tool that stops being
## importable — or loses its banner — fails here.
PY_TOOLS = ["build_card_packs", "fetch_card_art", "fetch_cards",
            "gen_cards", "import_original", "mtg_assets", "skin_catalogue"]

## Every shell tool, relative to the repo root.
SH_TOOLS = ["build_release.sh", "deck_convert.sh", "duel_soak.sh",
            "run_tests.sh", "DeckLab/deck_lab.sh"]

## The four Python tools build_release.sh copies into a package, plus the
## module they import. See test_the_package_ships_the_module_its_tools_import.
SHIPPED_TOOLS = ["mtg_assets.py", "import_original.py", "fetch_card_art.py",
                 "skin_catalogue.py", "tool_banner.py"]


class FakeTerminal(io.StringIO):
    """A stream that says it is a terminal, so the tty branch can be
    tested without one."""

    def isatty(self) -> bool:
        return True


def env_without_optouts(**extra) -> dict:
    env = dict(os.environ)
    env.pop(tool_banner.NO_BANNER_ENV, None)
    env.pop("NO_COLOR", None)
    env.update(extra)
    return env


def run_on_a_pty(argv: list[str], env=None) -> tuple[bytes, bytes, int]:
    """Run a command with a REAL terminal on its stderr and a pipe on its
    stdout — the shape that matters, because it is the one where the
    banner is drawn and stdout must still come out clean. Returns
    (stdout, what reached the terminal, exit code)."""
    master, slave = pty.openpty()
    try:
        proc = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=slave,
                                stdin=subprocess.DEVNULL, cwd=str(ROOT),
                                env=env if env is not None else env_without_optouts())
        os.close(slave)
        slave = -1
        out, _ = proc.communicate(timeout=120)
        terminal = b""
        while True:
            try:
                chunk = os.read(master, 65536)
            except OSError:
                break          # EIO: every slave is closed, we have it all
            if not chunk:
                break
            terminal += chunk
        return out, terminal, proc.returncode
    finally:
        if slave != -1:
            os.close(slave)
        os.close(master)


class VersionTest(unittest.TestCase):
    """ONE SOURCE, AND NO GUESSING."""

    def test_the_version_comes_from_project_godot(self):
        found = tool_banner.project_version(TOOLS_DIR)
        expected = re.search(r'^config/version="(.*)"$',
                             (ROOT / "project.godot").read_text(encoding="utf-8"),
                             re.MULTILINE).group(1)
        self.assertEqual(found, expected)
        self.assertTrue(found, "project.godot must carry a version")

    def test_it_walks_up_from_wherever_the_tool_was_started(self):
        # The repo root, tools/, and a file inside tools/ all answer the
        # same — a tool is run from all three.
        for start in (ROOT, TOOLS_DIR, TOOLS_DIR / "tool_banner.py"):
            self.assertEqual(tool_banner.project_version(start),
                             tool_banner.project_version(ROOT), str(start))

    def test_no_project_godot_says_so_instead_of_guessing(self):
        with tempfile.TemporaryDirectory() as tmp:
            # A temp dir under /tmp has no project.godot above it.
            self.assertIsNone(tool_banner.project_version(tmp))
            self.assertEqual(tool_banner.version_text(tmp), tool_banner.UNKNOWN)
            report = tool_banner.version_report("x.py", tmp)
            self.assertIn(tool_banner.UNKNOWN, report)
            self.assertIn("project.godot", report)
            # It must not print a number it cannot justify.
            self.assertNotIn(tool_banner.project_version(ROOT), report)

    def test_the_shell_side_reads_the_same_line(self):
        script = ('. tools/banner.sh\n'
                  'shandalar_version .\n')
        out = subprocess.run(["bash", "-c", script], cwd=str(ROOT),
                             capture_output=True, text=True, check=True)
        self.assertEqual(out.stdout, tool_banner.project_version(ROOT))

    def test_the_shell_side_also_refuses_to_guess(self):
        with tempfile.TemporaryDirectory() as tmp:
            script = ('. "$1"/tools/banner.sh\n'
                      'shandalar_version_line "t.sh" "$2"\n')
            out = subprocess.run(["bash", "-c", script, "_", str(ROOT), tmp],
                                 capture_output=True, text=True, check=True)
            self.assertIn("version unknown", out.stdout)
            self.assertNotIn(tool_banner.project_version(ROOT), out.stdout)


class BannerShapeTest(unittest.TestCase):
    """THE ARTWORK ITSELF — short, plain when asked, and never wider than
    the terminal it was written for (the rules tests/tools/test_deck_lab.gd
    holds the Deck Lab to)."""

    def lines(self, colour: bool, module=None) -> list[str]:
        module = module or tool_banner
        return tool_banner.banner_lines(("abc", "def", "ghi"),
                                        ("one", "two"), "9.9.9", colour)

    def test_plain_text_has_no_escape_codes(self):
        for line in self.lines(False):
            self.assertNotIn(tool_banner.ESC, line)

    def test_colour_never_changes_a_glyph(self):
        # THE STRONG FORM of "degrades to plain text": strip every SGR
        # code from the coloured banner and the plain one is what is left.
        plain = self.lines(False)
        coloured = self.lines(True)
        self.assertEqual(len(plain), len(coloured))
        self.assertEqual([SGR.sub("", line) for line in coloured], plain)
        self.assertGreater("".join(coloured).count(tool_banner.ESC), 0)

    def test_a_coloured_line_closes_its_colour(self):
        # A terminal left amber is a bug in a tool, not a style.
        for line in self.lines(True):
            self.assertTrue(line.endswith(tool_banner.RESET), repr(line))

    def test_the_version_and_the_pips_sign_the_last_line(self):
        last = self.lines(False)[-1]
        self.assertIn("W U B R G", last)
        self.assertTrue(last.endswith("9.9.9"))

    def test_every_tool_is_three_short_rows_of_one_width(self):
        for name in PY_TOOLS:
            module = __import__(name)
            wordmark = getattr(module, "WORDMARK")
            caption = getattr(module, "CAPTION")
            self.assertEqual(len(wordmark), 3, name)
            self.assertEqual(len(caption), 2, name)
            self.assertEqual(len(set(len(row) for row in wordmark)), 1,
                             "%s: every row keeps one width so the caption "
                             "keeps its column" % name)
            for line in tool_banner.banner_lines(wordmark, caption,
                                                 "0.99.9-dev", False):
                self.assertLessEqual(len(line), 78,
                                     "%s: fits an 80-column terminal: %s"
                                     % (name, line))

    def test_every_tool_has_its_own_wordmark(self):
        # Twelve tools, twelve names: a banner that says the wrong tool is
        # worse than no banner.
        marks = {name: tuple(__import__(name).WORDMARK) for name in PY_TOOLS}
        self.assertEqual(len(set(marks.values())), len(PY_TOOLS), marks.keys())


class TerminalRuleTest(unittest.TestCase):
    """NOTHING IS DRAWN OFF A TERMINAL, and nothing decorative ever
    reaches stdout."""

    def setUp(self):
        self._saved = {key: os.environ.get(key)
                       for key in (tool_banner.NO_BANNER_ENV, "NO_COLOR")}
        for key in self._saved:
            os.environ.pop(key, None)

    def tearDown(self):
        for key, value in self._saved.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value

    def test_a_pipe_gets_nothing(self):
        plain = io.StringIO()          # isatty() is False
        self.assertFalse(tool_banner.wanted(plain))
        tool_banner.show(("a", "b", "c"), ("x", "y"), ROOT, plain)
        self.assertEqual(plain.getvalue(), "")

    def test_a_terminal_gets_the_banner(self):
        term = FakeTerminal()
        self.assertTrue(tool_banner.wanted(term))
        tool_banner.show(("a", "b", "c"), ("x", "y"), ROOT, term)
        drawn = SGR.sub("", term.getvalue())
        self.assertIn("W U B R G", drawn)
        self.assertIn(tool_banner.project_version(ROOT), drawn)

    def test_the_opt_out_silences_a_terminal(self):
        os.environ[tool_banner.NO_BANNER_ENV] = "1"
        term = FakeTerminal()
        self.assertFalse(tool_banner.wanted(term))
        tool_banner.show(("a", "b", "c"), ("x", "y"), ROOT, term)
        self.assertEqual(term.getvalue(), "")

    def test_the_opt_out_set_to_zero_is_not_an_opt_out(self):
        os.environ[tool_banner.NO_BANNER_ENV] = "0"
        self.assertTrue(tool_banner.wanted(FakeTerminal()))

    def test_no_color_keeps_the_shape_and_drops_the_colour(self):
        os.environ["NO_COLOR"] = "1"
        term = FakeTerminal()
        self.assertTrue(tool_banner.wanted(term))
        self.assertFalse(tool_banner.use_colour(term))
        tool_banner.show(("a", "b", "c"), ("x", "y"), ROOT, term)
        self.assertIn("W U B R G", term.getvalue())
        self.assertNotIn(tool_banner.ESC, term.getvalue())

    def test_a_stream_that_cannot_answer_is_not_a_terminal(self):
        class Broken:
            def isatty(self):
                raise OSError("no")

            def write(self, _text):
                raise AssertionError("nothing may be written here")

        self.assertFalse(tool_banner.wanted(Broken()))
        tool_banner.show(("a", "b", "c"), ("x", "y"), ROOT, Broken())

    def test_the_python_banner_on_a_real_terminal_keeps_stdout_clean(self):
        code = ("import sys, tool_banner;"
                "print('THE INSTRUMENT CHANNEL');"
                "tool_banner.show(('aaa','bbb','ccc'), ('x','y'), %r)"
                % str(ROOT))
        out, terminal, status = run_on_a_pty(
            [sys.executable, "-c", code],
            env=env_without_optouts(PYTHONPATH=str(TOOLS_DIR)))
        self.assertEqual(status, 0)
        self.assertEqual(out, b"THE INSTRUMENT CHANNEL\n")
        self.assertIn("W U B R G", SGR.sub("", terminal.decode()))

    def test_the_shell_banner_on_a_real_terminal_keeps_stdout_clean(self):
        script = ('. tools/banner.sh\n'
                  "BANNER_ROW_0=aaa; BANNER_ROW_1=bbb; BANNER_ROW_2=ccc\n"
                  "BANNER_CAP_0=x; BANNER_CAP_1=y\n"
                  'echo "THE INSTRUMENT CHANNEL"\n'
                  'shandalar_banner .\n')
        out, terminal, status = run_on_a_pty(["bash", "-c", script])
        self.assertEqual(status, 0)
        self.assertEqual(out, b"THE INSTRUMENT CHANNEL\n")
        drawn = SGR.sub("", terminal.decode())
        self.assertIn("W U B R G", drawn)
        self.assertIn(tool_banner.project_version(ROOT), drawn)

    def test_the_shell_banner_obeys_the_family_opt_out(self):
        script = ('. tools/banner.sh\n'
                  "BANNER_ROW_0=aaa; BANNER_ROW_1=bbb; BANNER_ROW_2=ccc\n"
                  'shandalar_banner .\n')
        out, terminal, status = run_on_a_pty(
            ["bash", "-c", script],
            env=env_without_optouts(**{tool_banner.NO_BANNER_ENV: "1"}))
        self.assertEqual(status, 0)
        self.assertEqual(out, b"")
        self.assertEqual(terminal, b"")

    def test_the_shell_banner_draws_nothing_into_a_pipe(self):
        script = ('. tools/banner.sh\n'
                  "BANNER_ROW_0=aaa; BANNER_ROW_1=bbb; BANNER_ROW_2=ccc\n"
                  'shandalar_banner .\n')
        done = subprocess.run(["bash", "-c", script], cwd=str(ROOT),
                              capture_output=True, env=env_without_optouts())
        self.assertEqual(done.returncode, 0)
        self.assertEqual(done.stdout, b"")
        self.assertEqual(done.stderr, b"")


class EveryToolAnswersTest(unittest.TestCase):
    """-h AND --version ON ALL TWELVE, and no artwork in either — both are
    stdout, and both are run through a pipe by everything that automates
    them."""

    WORDMARK_GLYPHS = "┌┐└┘├┤┬┴─│"

    def assert_no_artwork(self, text: str, what: str):
        for glyph in self.WORDMARK_GLYPHS:
            self.assertNotIn(glyph, text,
                             "%s: a wordmark glyph reached stdout" % what)

    def run_tool(self, argv: list[str]) -> subprocess.CompletedProcess:
        return subprocess.run(argv, cwd=str(ROOT), capture_output=True,
                              text=True, timeout=180, stdin=subprocess.DEVNULL,
                              env=env_without_optouts())

    def test_every_python_tool_has_a_help_and_a_version(self):
        version = tool_banner.project_version(ROOT)
        for name in PY_TOOLS:
            script = "tools/%s.py" % name
            for flag in ("-h", "--help"):
                done = self.run_tool([sys.executable, script, flag])
                self.assertEqual(done.returncode, 0, script + " " + flag)
                self.assertIn("usage:", done.stdout, script)
                self.assertIn(tool_banner.NO_BANNER_ENV, done.stdout,
                              "%s: -h must name the opt-out" % script)
                self.assert_no_artwork(done.stdout, script + " " + flag)
            for flag in ("-V", "--version"):
                done = self.run_tool([sys.executable, script, flag])
                self.assertEqual(done.returncode, 0, script + " " + flag)
                self.assertEqual(done.stdout.strip(),
                                 "%s.py — Shandalar %s" % (name, version))
                self.assert_no_artwork(done.stdout, script + " " + flag)

    def test_every_shell_tool_has_a_version(self):
        version = tool_banner.project_version(ROOT)
        for script in SH_TOOLS:
            for flag in ("-V", "--version"):
                done = self.run_tool(["./" + script, flag])
                self.assertEqual(done.returncode, 0, script + " " + flag)
                self.assertEqual(done.stdout.strip(),
                                 "%s — Shandalar %s"
                                 % (Path(script).name, version))
                self.assert_no_artwork(done.stdout, script + " " + flag)

    def test_the_shell_tools_that_need_no_engine_have_a_help(self):
        # build_release.sh and run_tests.sh answer -h themselves;
        # deck_convert.sh and deck_lab.sh forward it to Godot, and
        # duel_soak.sh to Godot under Xvfb, so those are the gate's job
        # rather than a unit test's.
        for script in ("build_release.sh", "run_tests.sh"):
            for flag in ("-h", "--help"):
                done = self.run_tool(["./" + script, flag])
                self.assertEqual(done.returncode, 0, script + " " + flag)
                self.assertIn(tool_banner.NO_BANNER_ENV, done.stdout,
                              "%s: -h must name the opt-out" % script)
                self.assert_no_artwork(done.stdout, script + " " + flag)

    def test_build_release_help_is_whole(self):
        # It used to be `sed -n '2,50p'`, and by 2026-09-11 the header had
        # grown past line 50, so --help stopped mid-sentence. The last
        # invocation in the block has to survive.
        done = self.run_tool(["./build_release.sh", "--help"])
        self.assertIn("./build_release.sh -V", done.stdout)
        self.assertNotIn("WHAT SHIPS", done.stdout)


class PackagedToolsTest(unittest.TestCase):
    """THE SHIPPED TOOLS TRAVEL WITH WHAT THEY IMPORT."""

    def test_the_package_ships_the_module_its_tools_import(self):
        # build_release.sh copies a flat list of tools into the Linux and
        # the web package. Every one of them imports tool_banner, so that
        # file has to be in both lists or the package ships tools that
        # cannot start.
        groups, current = [], None
        for line in (ROOT / "build_release.sh").read_text(
                encoding="utf-8").splitlines():
            if current is not None:
                current.append(line)
            elif "cp -p tools/" in line:
                current = [line]
            if current is not None and not line.rstrip().endswith("\\"):
                groups.append(" ".join(current))
                current = None
        self.assertEqual(len(groups), 2, "one copy list per package")
        for group in groups:
            for wanted in SHIPPED_TOOLS:
                self.assertIn(wanted, group, group)

    def test_a_shipped_tool_finds_the_module_beside_it(self):
        # Copy the flat package layout into a temp dir with NO
        # project.godot anywhere above it, and check the tool starts, says
        # it does not know the version, and says WHY.
        with tempfile.TemporaryDirectory() as tmp:
            stage = Path(tmp)
            for name in SHIPPED_TOOLS:
                (stage / name).write_bytes((TOOLS_DIR / name).read_bytes())
            done = subprocess.run(
                [sys.executable, str(stage / "fetch_card_art.py"), "--version"],
                cwd=tmp, capture_output=True, text=True, timeout=120,
                stdin=subprocess.DEVNULL, env=env_without_optouts())
            self.assertEqual(done.returncode, 0, done.stderr)
            self.assertIn("version unknown", done.stdout)
            self.assertIn("project.godot", done.stdout)


class ArtFolderFlagTest(unittest.TestCase):
    """THE --out FLAG ACTUALLY MOVES THE FILES (2026-09-11). Its default
    was bound when the module loaded, so `--out` created a folder and then
    downloaded into assets/cardart/ regardless — which beside a packaged
    game is a folder that does not exist, and 897 failed downloads."""

    def test_the_destination_follows_the_flag(self):
        import fetch_card_art
        elsewhere = Path("/nowhere/at/all")
        self.assertEqual(fetch_card_art.targets_for("Black Lotus", elsewhere)[0][0],
                         elsewhere / "black_lotus.jpg")
        self.assertEqual(fetch_card_art.targets_for("Black Lotus")[0][0],
                         fetch_card_art.OUT_DIR / "black_lotus.jpg")

    def test_the_default_is_read_when_called_not_when_imported(self):
        import fetch_card_art
        saved = fetch_card_art.OUT_DIR
        try:
            fetch_card_art.OUT_DIR = Path("/moved/here")
            self.assertEqual(fetch_card_art.targets_for("Ornithopter")[0][0],
                             Path("/moved/here/ornithopter.jpg"))
        finally:
            fetch_card_art.OUT_DIR = saved


if __name__ == "__main__":
    unittest.main()

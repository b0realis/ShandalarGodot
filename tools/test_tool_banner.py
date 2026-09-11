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

THE MINI-HELP, added the same day, is the same decoration and is held to
the same rule with one more of its own: two or three lines under the
banner, quoted out of the tool's own examples, and only for a BARE
command line. `StdoutDidNotMoveTest` is the test that would actually
catch the bug — `skin_catalogue.py --stdout` piped, redirected and
`2>&1` is byte for byte the committed docs/skin-catalogue.txt.
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

## THE ONE TOOL WITH NO MINI-HELP, and why (2026-09-11): a bare
## `mtg_assets.py` already prints its own GUIDE — "WHAT THIS NEEDS", down
## to a TRY IT block of the same invocations — so a hint three lines above
## it would say the same thing twice. The Deck Lab is the other one, and
## it is not a Python tool: DeckLab/simulate.gd's `_usage_hint` had this
## idea first and keeps it.
NO_HINT = ["mtg_assets"]

## Where each shell tool's mini-help lines have to be quoted FROM. A
## mini-help is two or three lines lifted out of the tool's own usage
## text, never a second wording of it — deck_convert.sh's manual lives in
## the .gd it forwards to, so both files count as its source.
SH_HINT_SOURCE = {
    "build_release.sh": ["build_release.sh"],
    "deck_convert.sh": ["deck_convert.sh", "tools/deck_convert.gd"],
    "duel_soak.sh": ["duel_soak.sh"],
    "run_tests.sh": ["run_tests.sh"],
}

## The call that sets a shell tool's mini-help, and the single-quoted
## lines that follow it — read out of the script itself, because the
## point of the test is that the script says it.
SH_HINT_CALL = re.compile(r"^shandalar_banner_hint \"\$#\"(.*?)(?<!\\)\n",
                          re.MULTILINE | re.DOTALL)
SH_HINT_LINE = re.compile(r"'([^']*)'")


def hint_of(name: str):
    """A Python tool's HINT, or () for the one that has none."""
    return tuple(getattr(__import__(name), "HINT", ()))


def shell_hint_of(script: str) -> list[str]:
    """A shell tool's mini-help lines, parsed out of its own source."""
    text = (ROOT / script).read_text(encoding="utf-8")
    found = SH_HINT_CALL.search(text)
    return SH_HINT_LINE.findall(found.group(1)) if found else []


def command_of(line: str) -> str:
    """The part of a mini-help line a person types — everything before
    the `# note`, which is free to be shorter than the manual's."""
    return line.split("#")[0].rstrip()


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


class MiniHelpShapeTest(unittest.TestCase):
    """THE MINI-HELP IS SHORT, IT QUOTES THE MANUAL, AND IT POINTS AT IT
    (2026-09-11). Two or three invocations under the banner for somebody
    who has just typed the command; the last line names `-h`, where the
    rest is. A mini-help that scrolls is a failed mini-help, and one that
    words the manual a second way is a second manual to maintain."""

    def assert_shape(self, what: str, hint):
        self.assertGreaterEqual(len(hint), 2, "%s: say at least two" % what)
        self.assertLessEqual(len(hint), 3, "%s: two or three lines, no more"
                             % what)
        for line in hint:
            # Two-space indent (tool_banner.hint_lines) inside eighty
            # columns, the same limit the wordmark keeps.
            self.assertLessEqual(len(line) + 2, 78,
                                 "%s: fits an 80-column terminal: %s"
                                 % (what, line))
            self.assertEqual(line, line.rstrip(), "%s: %r" % (what, line))
        self.assertIn(" -h", hint[-1],
                      "%s: the last line names the flag that has the rest"
                      % what)

    def test_every_python_tool_that_has_one_is_two_or_three_lines(self):
        for name in PY_TOOLS:
            hint = hint_of(name)
            if name in NO_HINT:
                self.assertEqual(hint, (), "%s explains itself already" % name)
                continue
            self.assert_shape(name, hint)

    def test_every_shell_tool_that_has_one_is_two_or_three_lines(self):
        for script in SH_HINT_SOURCE:
            self.assert_shape(script, shell_hint_of(script))

    def test_the_deck_lab_keeps_its_own_rather_than_being_given_a_second(self):
        # DeckLab/simulate.gd has answered a bare command line with two
        # copyable invocations and a pointer to --help since it was
        # written — the thing the rest of the family copied. A
        # BANNER_HINT in its wrapper would say it twice, so the wrapper
        # has none, and this is the test that keeps it that way.
        wrapper = (ROOT / "DeckLab" / "deck_lab.sh").read_text(encoding="utf-8")
        self.assertNotIn("shandalar_banner_hint", wrapper)
        lab = (ROOT / "DeckLab" / "simulate.gd").read_text(encoding="utf-8")
        self.assertIn("_usage_hint", lab)

    def test_the_python_mini_help_quotes_the_tools_own_examples(self):
        # ONE SOURCE FOR AN INVOCATION. The `# note` may be shorter than
        # the manual's — it has to fit beside the command — but the thing
        # a reader copies has to be a line the tool documents.
        for name in PY_TOOLS:
            hint = hint_of(name)
            if not hint:
                continue
            epilog = getattr(__import__(name), "EPILOG")
            for line in hint[:-1]:
                self.assertIn(command_of(line), epilog,
                              "%s: the mini-help invents an invocation" % name)

    def test_the_shell_mini_help_quotes_the_scripts_own_usage(self):
        for script, sources in SH_HINT_SOURCE.items():
            text = "\n".join((ROOT / where).read_text(encoding="utf-8")
                             for where in sources)
            for line in shell_hint_of(script)[:-1]:
                self.assertIn(command_of(line), text,
                              "%s: the mini-help invents an invocation"
                              % script)

    def test_the_mini_help_is_drawn_the_same_way_in_both_languages(self):
        # The shell side is a second implementation of the same three
        # lines; if they ever disagree about the shape, this is where it
        # shows. Same indent, same dimmed note, same blank line after.
        lines = ["./x.sh          # do the thing", "./x.sh -h       # the rest"]
        python_side = tool_banner.hint_lines(lines, False)
        script = ('. tools/banner.sh\n'
                  "BANNER_ROW_0=aaa; BANNER_ROW_1=bbb; BANNER_ROW_2=ccc\n"
                  'shandalar_banner_hint 0 "$1" "$2"\n'
                  'shandalar_banner .\n')
        _out, terminal, status = run_on_a_pty(
            ["bash", "-c", script, "_"] + lines)
        self.assertEqual(status, 0)
        drawn = SGR.sub("", terminal.decode()).replace("\r\n", "\n")
        self.assertTrue(drawn.endswith("\n".join(python_side) + "\n\n"),
                        repr(drawn))

    def test_plain_text_has_no_escape_codes(self):
        for line in tool_banner.hint_lines(["./x.sh  # note"], False):
            self.assertNotIn(tool_banner.ESC, line)

    def test_colour_never_changes_a_glyph(self):
        lines = ["./x.sh          # do the thing", "./x.sh -h  # the rest"]
        plain = tool_banner.hint_lines(lines, False)
        coloured = tool_banner.hint_lines(lines, True)
        self.assertEqual([SGR.sub("", line) for line in coloured], plain)
        for line in coloured:
            # The note is dimmed and the command is not, so the eye lands
            # on the thing that gets typed — and the line closes its own
            # colour, because a terminal left dim is a bug in a tool.
            self.assertTrue(line.startswith("  ./x.sh"), repr(line))
            self.assertTrue(line.endswith(tool_banner.RESET), repr(line))

    def test_a_line_with_no_note_is_left_alone(self):
        self.assertEqual(tool_banner.hint_lines(["python3 x.py --in A"], True),
                         ["  python3 x.py --in A"])

    def test_the_epilog_helper_drops_the_line_that_points_at_h(self):
        # You are reading -h already: being told where -h is would be
        # noise there, and the same lines are the point of the helper.
        hint = ("python3 x.py --all", "python3 x.py -h   # the rest")
        self.assertEqual(tool_banner.examples(hint), "    python3 x.py --all")


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


class MiniHelpRuleTest(unittest.TestCase):
    """THE MINI-HELP RIDES THE BANNER'S GUARDS, ALL THREE, AND ONE MORE
    OF ITS OWN (2026-09-11). stderr; a terminal; the opt-out — and only
    for a BARE command line, because somebody who typed a flag has
    already said what they want."""

    HINT = ("./x.sh          # do the thing", "./x.sh -h       # the rest")

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

    def drawn(self, stream, **kwargs) -> str:
        tool_banner.show(("a", "b", "c"), ("x", "y"), ROOT, stream, **kwargs)
        return SGR.sub("", stream.getvalue())

    def test_a_bare_command_line_gets_it(self):
        text = self.drawn(FakeTerminal(), hint=self.HINT, argv=[])
        self.assertIn("W U B R G", text)
        self.assertTrue(text.endswith("  ./x.sh          # do the thing\n"
                                      "  ./x.sh -h       # the rest\n\n"), text)

    def test_a_command_line_that_said_what_it_wants_does_not(self):
        text = self.drawn(FakeTerminal(), hint=self.HINT, argv=["--force"])
        self.assertIn("W U B R G", text)
        self.assertNotIn("./x.sh", text)
        # And the banner is exactly what it was before there was a hint.
        self.assertEqual(text, self.drawn(FakeTerminal()))

    def test_a_pipe_gets_nothing_at_all(self):
        self.assertEqual(self.drawn(io.StringIO(), hint=self.HINT, argv=[]), "")

    def test_the_opt_out_silences_it_with_the_banner(self):
        os.environ[tool_banner.NO_BANNER_ENV] = "1"
        self.assertEqual(self.drawn(FakeTerminal(), hint=self.HINT, argv=[]), "")

    def test_no_color_keeps_the_shape_and_drops_the_colour(self):
        os.environ["NO_COLOR"] = "1"
        term = FakeTerminal()
        tool_banner.show(("a", "b", "c"), ("x", "y"), ROOT, term,
                         hint=self.HINT, argv=[])
        self.assertIn("./x.sh -h", term.getvalue())
        self.assertNotIn(tool_banner.ESC, term.getvalue())

    def test_a_tool_with_no_hint_is_what_it_always_was(self):
        self.assertEqual(self.drawn(FakeTerminal(), argv=[]),
                         self.drawn(FakeTerminal()))

    def test_a_broken_stream_still_cannot_be_written_to(self):
        # A decoration that can raise is worse than no decoration, and
        # the mini-help is more code on that path than the banner was.
        class Broken:
            def isatty(self):
                raise OSError("no")

            def write(self, _text):
                raise AssertionError("nothing may be written here")

        tool_banner.show(("a", "b", "c"), ("x", "y"), ROOT, Broken(),
                         hint=self.HINT, argv=[])

    def test_a_hint_that_is_not_even_lines_cannot_fail_a_tool(self):
        term = FakeTerminal()
        tool_banner.show(("a", "b", "c"), ("x", "y"), ROOT, term,
                         hint=object(), argv=[])
        self.assertIn("W U B R G", SGR.sub("", term.getvalue()))

    def test_the_shell_side_obeys_the_same_four(self):
        script = ('. tools/banner.sh\n'
                  "BANNER_ROW_0=aaa; BANNER_ROW_1=bbb; BANNER_ROW_2=ccc\n"
                  'shandalar_banner_hint "$1" "./x.sh  # do the thing" \\\n'
                  '    "./x.sh -h  # the rest"\n'
                  'echo "THE INSTRUMENT CHANNEL"\n'
                  'shandalar_banner .\n')
        # Bare: drawn on the terminal, and stdout is untouched.
        out, terminal, status = run_on_a_pty(["bash", "-c", script, "_", "0"])
        self.assertEqual((status, out), (0, b"THE INSTRUMENT CHANNEL\n"))
        self.assertIn("./x.sh -h", SGR.sub("", terminal.decode()))
        # With arguments: the banner, and nothing else.
        out, terminal, status = run_on_a_pty(["bash", "-c", script, "_", "2"])
        self.assertEqual((status, out), (0, b"THE INSTRUMENT CHANNEL\n"))
        self.assertNotIn("./x.sh", SGR.sub("", terminal.decode()))
        # Into a pipe, and under the opt-out: nothing at all, either way.
        done = subprocess.run(["bash", "-c", script, "_", "0"], cwd=str(ROOT),
                              capture_output=True, env=env_without_optouts())
        self.assertEqual(done.stdout, b"THE INSTRUMENT CHANNEL\n")
        self.assertEqual(done.stderr, b"")
        out, terminal, status = run_on_a_pty(
            ["bash", "-c", script, "_", "0"],
            env=env_without_optouts(**{tool_banner.NO_BANNER_ENV: "1"}))
        self.assertEqual((status, out, terminal),
                         (0, b"THE INSTRUMENT CHANNEL\n", b""))

    def test_the_shell_hint_helper_never_fails_its_caller(self):
        # tools/banner.sh is SOURCED BY build_release.sh, and artwork may
        # not fail a build: every function there returns 0, including
        # this one called with nothing, with junk, and under set -e.
        script = ('set -euo pipefail\n'
                  '. tools/banner.sh\n'
                  'shandalar_banner_hint\n'
                  'shandalar_banner_hint 0\n'
                  'shandalar_banner_hint "" "a line"\n'
                  'shandalar_banner_hint nonsense "a line"\n'
                  'shandalar_banner\n'
                  'echo ALIVE\n')
        done = subprocess.run(["bash", "-c", script], cwd=str(ROOT),
                              capture_output=True, env=env_without_optouts())
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual(done.stdout, b"ALIVE\n")

    def test_a_real_tool_draws_it_on_a_real_terminal(self):
        # import_original.py is the one tool whose bare run is safe to
        # make here — --source is required, so it refuses, writes
        # nothing and touches no network. It is also the tool that NEEDS
        # the mini-help most: before this, a bare run was argparse's
        # "error: the following arguments are required: --source" and no
        # banner at all, because argparse exits inside parse_args().
        out, terminal, status = run_on_a_pty(
            [sys.executable, "tools/import_original.py"])
        self.assertEqual(status, 2)
        self.assertEqual(out, b"")
        drawn = SGR.sub("", terminal.decode())
        for line in hint_of("import_original"):
            self.assertIn(line, drawn)
        self.assertIn("W U B R G", drawn)
        self.assertIn("required: --source", drawn)

    def test_the_tool_that_explains_itself_does_not_say_it_twice(self):
        # mtg_assets.py prints its own GUIDE on a bare run. A hint above
        # it would be the same invocations three lines apart.
        out, terminal, status = run_on_a_pty(
            [sys.executable, "tools/mtg_assets.py"])
        self.assertEqual(status, 0)
        self.assertIn(b"WHAT THIS NEEDS", out)
        drawn = SGR.sub("", terminal.decode())
        self.assertIn("W U B R G", drawn)
        self.assertNotIn("python3", drawn)


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

    def test_the_examples_carry_the_path_that_works_where_they_are(self):
        # `python3 tools/skin_catalogue.py` is No such file or directory
        # for a player, and `python3 skin_catalogue.py` is the same thing
        # from the repo root. Asked from the tool's own location rather
        # than assumed (tool_banner.here_prefix), so one line is right in
        # both places — which is where the -h examples and the mini-help
        # both come from.
        self.assertEqual(tool_banner.here_prefix(TOOLS_DIR / "mtg_assets.py"),
                         "tools/")
        self.assertEqual(tool_banner.here_prefix(TOOLS_DIR), "tools/")
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(tool_banner.here_prefix(tmp), "")
            stage = Path(tmp)
            for name in SHIPPED_TOOLS:
                (stage / name).write_bytes((TOOLS_DIR / name).read_bytes())
            for name in ("skin_catalogue.py", "fetch_card_art.py",
                         "import_original.py", "mtg_assets.py"):
                done = subprocess.run(
                    [sys.executable, str(stage / name), "-h"], cwd=tmp,
                    capture_output=True, text=True, timeout=120,
                    stdin=subprocess.DEVNULL, env=env_without_optouts())
                self.assertEqual(done.returncode, 0, done.stderr)
                self.assertNotIn("tools/" + name, done.stdout,
                                 "%s: a player has no tools/ folder" % name)
                self.assertIn("python3 " + name, done.stdout, name)
                # And in the checkout, the other way round.
                here = subprocess.run(
                    [sys.executable, "tools/" + name, "-h"], cwd=str(ROOT),
                    capture_output=True, text=True, timeout=120,
                    stdin=subprocess.DEVNULL, env=env_without_optouts())
                self.assertIn("python3 tools/" + name, here.stdout, name)

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


class StdoutDidNotMoveTest(unittest.TestCase):
    """THE REGRESSION THAT WOULD ACTUALLY HURT (2026-09-11): a tool's
    stdout is the same bytes it was before any of this decoration
    existed, whatever is on the far end of it.

    `skin_catalogue.py --stdout` is the sharpest case in the family,
    because its stdout IS a committed file — docs/skin-catalogue.txt — so
    the comparison is against something outside this test. Four shapes,
    all of them real: both ends piped, a terminal on stderr, stdout
    redirected into a file, and `2>&1` into one file, which is what a
    script or an agent writes and where a stray byte would land."""

    ARGV = [sys.executable, "tools/skin_catalogue.py", "--stdout"]

    def run_to_a_file(self, merged: bool) -> bytes:
        """The tool with its stdout REDIRECTED into a file — and its
        stderr either a real terminal beside it, or the same file
        (`2>&1`). Returns what the file holds."""
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "out.txt"
            master, slave = pty.openpty()
            try:
                with open(path, "wb") as handle:
                    proc = subprocess.Popen(
                        self.ARGV, stdout=handle,
                        stderr=handle if merged else slave,
                        stdin=subprocess.DEVNULL, cwd=str(ROOT),
                        env=env_without_optouts())
                    self.assertEqual(proc.wait(timeout=300), 0)
            finally:
                os.close(master)
                os.close(slave)
            return path.read_bytes()

    def test_the_catalogue_is_the_same_bytes_down_every_pipe(self):
        piped = subprocess.run(self.ARGV, cwd=str(ROOT), capture_output=True,
                               timeout=300, stdin=subprocess.DEVNULL,
                               env=env_without_optouts())
        self.assertEqual(piped.returncode, 0, piped.stderr)
        self.assertEqual(piped.stderr, b"",
                         "a pipe on stderr gets nothing at all")
        on_a_terminal, terminal, status = run_on_a_pty(self.ARGV)
        self.assertEqual(status, 0)
        self.assertIn("W U B R G", SGR.sub("", terminal.decode()),
                      "the human's channel still gets the banner")
        redirected = self.run_to_a_file(False)
        merged = self.run_to_a_file(True)
        # THE FOUR AGREE, BYTE FOR BYTE. The banner and the mini-help are
        # not in any of them.
        self.assertEqual(on_a_terminal, piped.stdout)
        self.assertEqual(redirected, piped.stdout)
        self.assertEqual(merged, piped.stdout)
        for glyph in EveryToolAnswersTest.WORDMARK_GLYPHS:
            self.assertNotIn(glyph.encode(), merged)

    def test_the_catalogue_is_the_committed_file(self):
        # The measurement needs the skin it measures. In a checkout
        # without assets/original (a clean clone, a CI runner) the tool
        # says "(not on this machine)" for the files it cannot see, which
        # is a true catalogue of a different machine — so the comparison
        # against the committed one is made where it means something.
        if not (ROOT / "assets" / "original").is_dir():
            self.skipTest("no assets/original to measure")
        piped = subprocess.run(self.ARGV, cwd=str(ROOT), capture_output=True,
                               timeout=300, stdin=subprocess.DEVNULL,
                               env=env_without_optouts())
        self.assertEqual(piped.stdout,
                         (ROOT / "docs" / "skin-catalogue.txt").read_bytes())

    def test_a_refusal_reaches_a_log_without_its_artwork(self):
        # The other half of the rule, on the tool that draws the most:
        # import_original.py bare draws the wordmark AND the mini-help on
        # a terminal, and `> log 2>&1` must carry neither — only the
        # refusal a reader of that log is looking for.
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "run.log"
            with open(path, "wb") as handle:
                proc = subprocess.Popen(
                    [sys.executable, "tools/import_original.py"],
                    stdout=handle, stderr=handle, stdin=subprocess.DEVNULL,
                    cwd=str(ROOT), env=env_without_optouts())
                self.assertEqual(proc.wait(timeout=300), 2)
            log = path.read_text(encoding="utf-8")
        self.assertIn("required: --source", log)
        for glyph in EveryToolAnswersTest.WORDMARK_GLYPHS:
            self.assertNotIn(glyph, log)
        for line in hint_of("import_original"):
            self.assertNotIn(line, log)


if __name__ == "__main__":
    unittest.main()

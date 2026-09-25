#!/usr/bin/env python3
"""Self-test for DeckLab/auto_deck_cli.sh — the AutoDeck CLI's shell
wrapper. No network, and no Godot: everything here is either shell that
runs before an engine would be started, or a reading of the script's own
text.

Run from the repo root:
    python3 -m unittest discover -s tools -p 'test_*.py'

WHAT THIS HOLDS, and why each one is worth a test rather than a glance:

  * `-V` / `--version` IS ANSWERED BY THE SHELL. That is the family's own
    rule (CONTRIBUTING.md, "EVERY TOOL HERE ANSWERS -h AND --version"),
    and the reason it matters here is that this tool's engine takes about
    three seconds to start. The test proves it by answering the version
    with GODOT pointed at a path that does not exist.
  * NO ARTWORK IN STDOUT. `auto_deck_cli.sh --out mine ... > run.log 2>&1`
    is what a mining script writes, and a wordmark glyph in that file is a
    bug, not a flourish.
  * NO GODOT IS EXIT 3, the wrapper's own code, distinct from the 0/1/2
    the tool itself returns — a mining script that cannot tell "the run
    broke" from "there is no engine here" will retry the wrong one.
  * THE EXEC LINE IS THE CONTRACT: the project root, the script, and `--`
    before the user's arguments. Godot silently swallows an argument list
    that is not separated by `--`, so this is a one-line check that would
    otherwise only fail as "every switch is ignored".

`--help` needs the engine and is left to the gate, exactly as
tools/test_tool_banner.py leaves deck_lab.sh's.
"""

import os
import re
import subprocess
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import tool_banner  # noqa: E402

TOOLS_DIR = Path(__file__).resolve().parent
ROOT = TOOLS_DIR.parent
SCRIPT = "DeckLab/auto_deck_cli.sh"
## The wordmark's own glyphs; none of them may reach stdout.
WORDMARK_GLYPHS = "┌┐└┘├┤┬┴─│"


def run(argv, **extra_env):
    """The wrapper, from the repo root, with the family opt-outs cleared
    so a developer's own environment cannot hide a missing banner."""
    env = dict(os.environ)
    env.pop(tool_banner.NO_BANNER_ENV, None)
    env.pop("DECK_LAB_NO_BANNER", None)
    env.pop("NO_COLOR", None)
    env.update(extra_env)
    return subprocess.run(argv, cwd=str(ROOT), capture_output=True, text=True,
                          timeout=180, stdin=subprocess.DEVNULL, env=env)


class VersionTest(unittest.TestCase):
    """The version answer, and that it never starts an engine."""

    def test_both_spellings_answer_with_the_projects_one_version(self):
        version = tool_banner.project_version(ROOT)
        for flag in ("-V", "--version"):
            done = run(["./" + SCRIPT, flag])
            self.assertEqual(done.returncode, 0, SCRIPT + " " + flag)
            self.assertEqual(done.stdout.strip(),
                             "auto_deck_cli.sh — Shandalar %s" % version)

    def test_the_version_needs_no_engine(self):
        # Answered before tools/runtime.sh is even sourced, which is the
        # whole point: a version question must not cost three seconds of
        # engine start, and must work in a checkout with no Godot beside it.
        done = run(["./" + SCRIPT, "--version"], GODOT="/nonexistent/godot")
        self.assertEqual(done.returncode, 0)
        self.assertIn("Shandalar", done.stdout)

    def test_the_version_answer_carries_no_artwork(self):
        done = run(["./" + SCRIPT, "-V"])
        for glyph in WORDMARK_GLYPHS:
            self.assertNotIn(glyph, done.stdout,
                             "a wordmark glyph reached stdout")
        self.assertNotIn("\x1b", done.stdout, "and no escape code either")


class NoGodotTest(unittest.TestCase):
    """The wrapper's own exit code."""

    def test_no_godot_is_exit_3_and_says_what_to_set(self):
        # An explicit GODOT is never ignored (tools/runtime.sh), so this
        # is the one way to ask for the refusal without hiding the shell's
        # own utilities from the script as well.
        done = run(["./" + SCRIPT, "--out", "mine"],
                   GODOT="/nonexistent/godot")
        self.assertEqual(done.returncode, 3, done.stderr)
        self.assertIn("GODOT=", done.stderr)
        self.assertEqual(done.stdout, "", "a refusal writes nothing to stdout")


class ShellShapeTest(unittest.TestCase):
    """The script as text — the four lines a reader would otherwise have
    to take on trust."""

    @classmethod
    def setUpClass(cls):
        cls.text = (ROOT / SCRIPT).read_text(encoding="utf-8")

    def test_it_parses(self):
        done = subprocess.run(["bash", "-n", SCRIPT], cwd=str(ROOT),
                              capture_output=True, text=True, timeout=60)
        self.assertEqual(done.returncode, 0, done.stderr)

    def test_it_is_executable(self):
        self.assertTrue(os.access(ROOT / SCRIPT, os.X_OK),
                        "%s must be executable" % SCRIPT)

    def test_it_runs_from_the_project_root_whichever_way_it_was_called(self):
        # `DeckLab/auto_deck_cli.sh` from the root and `./auto_deck_cli.sh`
        # from inside the folder have to land in the same place, or half
        # the relative paths in a command line mean two different things.
        self.assertIn('cd "$(cd "$(dirname "$0")/.." && pwd)"', self.text)

    def test_the_exec_line_separates_the_users_arguments(self):
        # Without the `--`, Godot eats the switches and the tool sees an
        # empty command line — which looks exactly like "every switch was
        # ignored" and nothing like a bug in the wrapper.
        exec_line = re.search(r"exec .*?\n(?:\t.*\n)*", self.text, re.S)
        self.assertIsNotNone(exec_line, "the script ends in an exec")
        line = exec_line.group(0)
        self.assertIn("--headless", line)
        self.assertIn("res://DeckLab/auto_deck_cli.gd", line)
        self.assertIn('-- "$@"', line)

    def test_it_documents_the_exit_codes_it_can_return(self):
        # A wrapper whose header does not name its codes is a wrapper a
        # script has to be read to be automated.
        header = self.text.split("set -euo pipefail")[0]
        self.assertIn("Exit codes", header)
        for phrase in ("0 every deck written", "1 the run broke",
                       "2 the command line was wrong", "3 no Godot to run"):
            self.assertIn(phrase, header, "the header names: " + phrase)

    def test_it_maps_the_family_opt_out_onto_the_labs_own(self):
        # One export silences all of them; the Lab's older name still works.
        self.assertIn(tool_banner.NO_BANNER_ENV, self.text)
        self.assertIn("DECK_LAB_NO_BANNER", self.text)

    def test_the_script_it_starts_is_there(self):
        self.assertTrue((ROOT / "DeckLab/auto_deck_cli.gd").is_file())


if __name__ == "__main__":
    unittest.main()

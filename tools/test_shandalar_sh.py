#!/usr/bin/env python3
"""Self-test for the one door and the Lab Query's shell wrapper —
`./shandalar.sh` and `DeckLab/lab_query.sh` (2026-09-27). No network,
and no Godot: everything here is shell that runs before an engine
would be started, or a reading of the scripts' own text.

Run from the repo root:
    python3 -m unittest discover -s tools -p 'test_*.py'

WHAT THIS HOLDS:

  * THE DOOR DISPATCHES BY VERB and `exec`s the tool with the rest of
    the line untouched — `lab`, `autodeck`, `check`, `packs`, `cards`,
    `convert` — so a program learns one name.
  * A VERB THE DOOR DOES NOT KNOW IS THE FAMILY'S REFUSAL: one JSON
    line on stdout, `{"error":{"tool":"shandalar","exit":2,...}}`, exit
    2, the prose on stderr — the contract AGENTS.md promises for every
    tool, kept by the door too. And the line is valid JSON whatever the
    verb held, quotes included.
  * `-V` / `--version` AND `--help` ARE ANSWERED BY THE SHELL, on
    stdout, without an engine.
  * lab_query.sh: `-V` without an engine, exit 3 with no Godot, the
    exec line's `--` before the user's arguments, and no banner at
    all — its stdout is one JSON document.
"""

import json
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
DOOR = "shandalar.sh"
QUERY = "DeckLab/lab_query.sh"
VERBS = {"lab": "DeckLab/deck_lab.sh", "autodeck": "DeckLab/auto_deck_cli.sh",
         "check | packs | cards": 'DeckLab/lab_query.sh "$verb"',
         "query": "DeckLab/lab_query.sh", "referee": "DeckLab/referee.sh",
         "convert": "./deck_convert.sh", "mcp": "python3 tools/shandalar_mcp.py"}


def run(argv, **extra_env):
    env = dict(os.environ)
    env.pop(tool_banner.NO_BANNER_ENV, None)
    env.pop("DECK_LAB_NO_BANNER", None)
    env.pop("NO_COLOR", None)
    env.update(extra_env)
    return subprocess.run(argv, cwd=str(ROOT), capture_output=True, text=True,
                          timeout=180, stdin=subprocess.DEVNULL, env=env)


class DoorTest(unittest.TestCase):
    """./shandalar.sh as a program drives it."""

    @classmethod
    def setUpClass(cls):
        cls.text = (ROOT / DOOR).read_text(encoding="utf-8")

    def test_it_parses_and_is_executable(self):
        done = subprocess.run(["bash", "-n", DOOR], cwd=str(ROOT),
                              capture_output=True, text=True, timeout=60)
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertTrue(os.access(ROOT / DOOR, os.X_OK))

    def test_every_verb_execs_its_tool_with_the_rest_of_the_line(self):
        for verb, target in VERBS.items():
            with self.subTest(verb=verb):
                self.assertIn(f'{verb}) exec {target} "$@" ;;', self.text)
        for target in VERBS.values():
            script = [word for word in target.split(" ") if "/" in word][0]
            self.assertTrue((ROOT / script).is_file(), target)

    def test_help_is_the_list_on_stdout_without_an_engine(self):
        for argv in (["./" + DOOR], ["./" + DOOR, "--help"], ["./" + DOOR, "-h"]):
            with self.subTest(argv=argv):
                done = run(argv, GODOT="/nonexistent/godot")
                self.assertEqual(done.returncode, 0, done.stderr)
                for verb in ("lab", "autodeck", "check", "packs", "cards", "referee", "convert", "mcp"):
                    self.assertRegex(done.stdout, r"shandalar\.sh %s\b" % verb)
                self.assertIn("AGENTS.md", done.stdout)
                self.assertNotIn("set -euo", done.stdout, "the list, not the script")
                self.assertEqual(done.stderr, "")

    def test_the_version_is_answered_by_the_shell(self):
        done = run(["./" + DOOR, "-V"], GODOT="/nonexistent/godot")
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertRegex(done.stdout, r"^shandalar\.sh — Shandalar \d+\.\d+\.\d+\n$")

    def test_an_unknown_verb_is_one_json_line_and_exit_2(self):
        for verb in ("nope", 'we"ird', "back\\slash", "--games"):
            with self.subTest(verb=verb):
                done = run(["./" + DOOR, verb, "--out", "x"], GODOT="/nonexistent/godot")
                self.assertEqual(done.returncode, 2, done.stderr)
                lines = done.stdout.splitlines()
                self.assertEqual(len(lines), 1, done.stdout)
                error = json.loads(lines[0])["error"]
                self.assertEqual(error["tool"], "shandalar")
                self.assertEqual(error["exit"], 2)
                self.assertEqual(error["kind"], "option")
                self.assertIn("the verbs are lab, autodeck, check, packs, cards, referee, convert, mcp",
                              error["message"])
                self.assertIn("unknown verb", done.stderr)

    def test_the_refusal_is_valid_json_whatever_bytes_the_verb_held(self):
        # 2026-10-03: only " \ and three controls were removed, so an ESC
        # or a Latin-1 byte (not UTF-8) made the line invalid JSON.
        env = dict(os.environ, GODOT="/nonexistent/godot")
        for verb in (b"bad\x1bverb", b"bell\x07\x7f", b"caf\xe9", b"\xff\xfe", "café".encode()):
            with self.subTest(verb=verb):
                done = subprocess.run([b"./" + DOOR.encode(), verb], cwd=str(ROOT),
                                      capture_output=True, timeout=180,
                                      stdin=subprocess.DEVNULL, env=env)
                self.assertEqual(done.returncode, 2, done.stderr)
                lines = done.stdout.splitlines()
                self.assertEqual(len(lines), 1, done.stdout)
                error = json.loads(lines[0])["error"]
                self.assertEqual(error["kind"], "option")
                if verb == "café".encode():
                    self.assertEqual(error["verb"], "café", "valid UTF-8 is kept")

    def test_a_known_verb_reaches_its_tool(self):
        # No Godot: the Lab's wrapper answers 3, which is the proof the
        # door handed the line on and added nothing of its own.
        done = run(["./" + DOOR, "lab", "--deck-a", "x.deck"], GODOT="/nonexistent/godot")
        self.assertEqual(done.returncode, 3, done.stderr)
        self.assertEqual(done.stdout, "")
        done = run(["./" + DOOR, "check", "x.deck"], GODOT="/nonexistent/godot")
        self.assertEqual(done.returncode, 3, done.stderr)
        done = run(["./" + DOOR, "lab", "-V"], GODOT="/nonexistent/godot")
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertRegex(done.stdout, r"^deck_lab\.sh — Shandalar")


class QueryWrapperTest(unittest.TestCase):
    """DeckLab/lab_query.sh, the way test_auto_deck_cli_sh.py reads its
    sibling."""

    @classmethod
    def setUpClass(cls):
        cls.text = (ROOT / QUERY).read_text(encoding="utf-8")

    def test_it_parses_and_is_executable(self):
        done = subprocess.run(["bash", "-n", QUERY], cwd=str(ROOT),
                              capture_output=True, text=True, timeout=60)
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertTrue(os.access(ROOT / QUERY, os.X_OK))

    def test_the_version_needs_no_engine(self):
        for flag in ("-V", "--version"):
            with self.subTest(flag=flag):
                done = run(["./" + QUERY, flag], GODOT="/nonexistent/godot")
                self.assertEqual(done.returncode, 0, done.stderr)
                self.assertRegex(done.stdout, r"^lab_query\.sh — Shandalar \d+\.\d+\.\d+\n$")

    def test_no_godot_is_exit_3(self):
        done = run(["./" + QUERY, "packs"], GODOT="/nonexistent/godot")
        self.assertEqual(done.returncode, 3, done.stderr)
        self.assertIn("GODOT=", done.stderr)
        self.assertEqual(done.stdout, "")

    def test_it_runs_from_the_project_root_whichever_way_it_was_called(self):
        self.assertIn('cd "$(cd "$(dirname "$0")/.." && pwd)"', self.text)

    def test_the_exec_line_separates_the_users_arguments(self):
        exec_line = re.search(r"exec .*?\n(?:\t.*\n)*", self.text, re.S)
        self.assertIsNotNone(exec_line)
        line = exec_line.group(0)
        self.assertIn("--headless", line)
        self.assertIn("--no-header", line)
        self.assertIn("res://DeckLab/lab_query.gd", line)
        self.assertIn('-- "$@"', line)

    def test_it_never_draws_a_banner(self):
        # One JSON document on stdout, one prose line on stderr at most.
        self.assertIn("export DECK_LAB_NO_BANNER=1", self.text)
        self.assertIn("export DECK_LAB_TTY=0", self.text)

    def test_it_documents_the_exit_codes_it_can_return(self):
        header = self.text.split("set -euo pipefail")[0]
        self.assertIn("Exit codes", header)
        for phrase in ("0 answered", "1 the answer could not be written",
                       "2 the line could not be answered", "3 no Godot to run"):
            self.assertIn(phrase, header)

    def test_the_script_it_starts_is_there(self):
        self.assertTrue((ROOT / "DeckLab/lab_query.gd").is_file())


if __name__ == "__main__":
    unittest.main()

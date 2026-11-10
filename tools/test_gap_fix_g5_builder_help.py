#!/usr/bin/env python3
"""The pack builders' quick help (the gap review of 2026-11-10, R5 Q2) —
`tools/pack_*_*.py`, their `HINT` (the mini-help under the banner and the
argparse epilog).

The quick help led with `fetch`, the developer's step that refreshes the
set data from Scryfall: run on a player's copy it rewrites the pack's card
data, so the pack built from it may no longer match everybody else's (or
the release's). The lead's default, which the owner may still change:
`fetch` is listed last, marked as a developer step that may make the pack
incompatible. Every line still fits an 80-column terminal.

Run from the repo root:
    python3 -m unittest tools.test_gap_fix_g5_builder_help
"""
import contextlib
import importlib
import io
import sys
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
BUILDERS = sorted(p.stem for p in TOOLS.glob("pack_*_*.py"))


def command_of(line: str) -> str:
    return line.split("#")[0].strip()


class BuilderQuickHelpTest(unittest.TestCase):

    def test_there_are_ten_builders(self):
        self.assertEqual(len(BUILDERS), 10, BUILDERS)

    def test_fetch_is_last_and_marked_a_developer_step(self):
        for name in BUILDERS:
            with self.subTest(builder=name):
                tool = importlib.import_module(name)
                hint = list(tool.HINT)
                commands = [command_of(line) for line in hint if command_of(line)]
                fetching = [c for c in commands if c.split()[-1] == "fetch"]
                self.assertTrue(callable(getattr(tool, "fetch", None)), "every builder has `fetch`")
                if not fetching:
                    # Pack 1's mini-help never named it; `-h` does (below).
                    self.assertIn(" -h", hint[-1])
                    continue
                self.assertEqual(len(fetching), 1)
                self.assertEqual(commands[-1].split()[-1], "fetch", "`fetch` is listed last: %s" % commands)
                at = next(i for i, line in enumerate(hint) if command_of(line) == fetching[0])
                note = " ".join(line.split("#", 1)[1].strip() for line in hint[at:] if "#" in line)
                self.assertIn("developer step", note)
                self.assertIn("incompatible", note)
                for line in hint[at + 1:]:
                    self.assertEqual(command_of(line), "", "only the note goes on after it: %r" % line)

    def test_the_manual_marks_fetch_a_developer_step_too(self):
        for name in BUILDERS:
            with self.subTest(builder=name):
                manual = io.StringIO()
                with contextlib.redirect_stdout(manual), self.assertRaises(SystemExit):
                    importlib.import_module(name).main(["-h"])
                lines = manual.getvalue().splitlines()
                rows = [i for i, line in enumerate(lines)
                        if command_of(line).split()[-1:] == ["fetch"] or line.startswith("  fetch ")]
                self.assertEqual(len(rows), 1, lines)
                said = " ".join(lines[rows[0]:rows[0] + 2])
                self.assertIn("developer step", said)
                self.assertIn("incompatible", said)

    def test_every_line_fits_an_80_column_terminal(self):
        for name in BUILDERS:
            for line in importlib.import_module(name).HINT:
                with self.subTest(builder=name, line=line):
                    # two-space indent (tool_banner.hint_lines), the wordmark's 78
                    self.assertLessEqual(len(line) + 2, 78)
                    self.assertEqual(line, line.rstrip())


if __name__ == "__main__":
    unittest.main(verbosity=2)

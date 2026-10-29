#!/usr/bin/env python3
"""Self-test: the tools a player runs read and write text as UTF-8 on
every system. No network, no Godot.

Run from the repo root:
    python3 -m unittest discover -s tools -p 'test_*.py'

THE BUG THIS PINS (a play-tester's report, 2026-10-28, Windows 11):
`py -3 tools/fetch_card_art.py --out cache/cardart` found no picture for
Dandân, El-Hajjâj, Ifh-Bíff Efreet, Junún Efreet and Ring of Ma'rûf, and
the same command under WSL fetched all five. `Path.read_text()` with no
encoding reads the system's code page — cp1252 on a Western Windows — so
the UTF-8 card list arrived as "DandÃ¢n" and Scryfall knew no such card.
On Linux and macOS the code page is UTF-8 and the bug cannot show, which
is why nothing caught it: these tests make the missing encoding fail HERE.

Two guards. Python can warn wherever a text file is opened without an
encoding (`-X warn_default_encoding`, Python 3.10 on); the first test
builds the art fetcher's card list with that warning made an error. The
second reads every player-facing tool's source and finds each text read
or write that names no encoding — the same mistake anywhere else. The
tests' own files are left out: they run on CI's Linux, not a player's
Windows.
"""

import ast
import subprocess
import sys
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent

# Calls named `open` that are not text files: pictures, sounds, archives.
NOT_TEXT = {"Image", "wave", "zipfile", "tarfile", "ZipFile", "TarFile",
            "zf", "zip_file", "archive"}


def unnamed_encodings(source: str) -> list[tuple[int, str]]:
    """(line, call) for each text read or write that names no encoding."""
    found = []
    for node in ast.walk(ast.parse(source)):
        if not isinstance(node, ast.Call):
            continue
        func = node.func
        name = func.attr if isinstance(func, ast.Attribute) else getattr(func, "id", None)
        keywords = {k.arg for k in node.keywords}
        if "encoding" in keywords:
            continue
        if name in ("read_text", "write_text"):
            found.append((node.lineno, name))
            continue
        if name != "open":
            continue
        if isinstance(func, ast.Attribute):
            owner = func.value
            if isinstance(owner, ast.Call):  # zipfile.ZipFile(p).open(n)
                owner = owner.func
            owner = getattr(owner, "attr", None) or getattr(owner, "id", None)
            if owner in NOT_TEXT:
                continue
        # open(path, mode) or Path.open(mode): the mode is the first
        # argument after the path, or the `mode` keyword.
        args = node.args[1:] if isinstance(func, ast.Name) else node.args
        mode = args[0].value if args and isinstance(args[0], ast.Constant) else "r"
        for k in node.keywords:
            if k.arg == "mode" and isinstance(k.value, ast.Constant):
                mode = k.value.value
        if isinstance(mode, str) and "b" not in mode:
            found.append((node.lineno, "open(%r)" % mode))
    return found


class FetchCardArtReadsUtf8Test(unittest.TestCase):
    def test_the_card_list_names_its_encoding(self):
        """The reported line: `pool()` with Python's own encoding warning
        made an error, and the accented names come back whole."""
        if sys.version_info < (3, 10):
            self.skipTest("-X warn_default_encoding needs Python 3.10")
        probe = (
            "import sys; sys.path.insert(0, %r)\n"
            "import fetch_card_art\n"
            "names = {name for name, _ in fetch_card_art.pool()}\n"
            "for name in ('Dandân', 'El-Hajjâj', 'Ifh-Bíff Efreet',\n"
            "             'Junún Efreet', \"Ring of Ma'rûf\"):\n"
            "    assert name in names, name\n"
            "print('ok')\n" % str(TOOLS))
        result = subprocess.run(
            [sys.executable, "-X", "warn_default_encoding",
             "-W", "error::EncodingWarning", "-c", probe],
            capture_output=True, text=True, encoding="utf-8", timeout=120)
        self.assertEqual(result.returncode, 0, result.stderr[-2000:])
        self.assertIn("ok", result.stdout)


class PlayerToolsNameTheirEncodingTest(unittest.TestCase):
    def test_every_text_read_and_write_names_an_encoding(self):
        offenders = []
        for path in sorted(TOOLS.glob("*.py")):
            if path.name.startswith("test_"):
                continue
            source = path.read_text(encoding="utf-8")
            offenders += ["%s:%d %s" % (path.name, line, call)
                          for line, call in unnamed_encodings(source)]
        self.assertEqual(offenders, [],
                         "text read or written in the system's code page "
                         "(cp1252 on Windows): name encoding=\"utf-8\"")

    def test_the_guard_sees_the_reported_shape(self):
        """The scan itself: the line the play-tester found is caught, and
        pictures, sounds and binary files are not."""
        self.assertEqual(unnamed_encodings(
            "records = json.loads(data_file.read_text())\n"), [(1, "read_text")])
        self.assertEqual(unnamed_encodings(
            "with open(p, 'w') as f: pass\n"), [(1, "open('w')")])
        self.assertEqual(unnamed_encodings(
            "with log.open('w') as f: pass\n"), [(1, "open('w')")])
        self.assertEqual(unnamed_encodings(
            "a = p.read_text(encoding='utf-8')\n"
            "b = open(p, 'rb')\n"
            "c = Image.open(p)\n"
            "d = wave.open(str(p), 'rb')\n"
            "e = zipfile.ZipFile(p).open(n)\n"
            "f = p.open('rb')\n"), [])


if __name__ == "__main__":
    unittest.main()

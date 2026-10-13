"""The two rules about the TRACKED TREE itself, as a test.

Both are written down in CONTRIBUTING.md and neither had anything holding
it: `docs/CODE_MAP.md` says *"Every file in the project and what lives in
it"* (hard rule 6: a new file gets a row), and the Publication section says
*"Keep personal home paths, private email addresses and local tooling
metadata out of tracked files"*. The release tooling already refuses a
staged package that names the builder's home (`package_release.guard_private`,
`build_release.sh`'s `guard_stage`) — that is the last door before an
upload, and this is the same check one step earlier, on everything that is
committed rather than on what is about to be zipped.

Found on 2026-09-17 by the first run: eight source files had no row.
"""
import codecs
import re
import subprocess
import unittest
from pathlib import Path

import package_release

ROOT = Path(__file__).resolve().parents[1]

## The map documents these folders file by file. `cards/sets/`,
## `cards/optional/` and `cards/todo/` are deliberately NOT here: the map
## describes each of them as a folder, one paragraph for 900-odd card
## files, which is the only readable way to write it down.
MAPPED_DIRS = ("engine/", "game/", "tools/", "DeckLab/")
MAPPED_SUFFIXES = (".gd", ".py", ".sh", ".tscn")

## Vendored third party (the GUT addon and the fonts it ships). Its
## licence file carries the font author's own address, which is the point
## of a licence file; this project's Publication rule is about what this
## project writes.
VENDORED = ("addons/",)

## Tool-vendor names this project may never carry (CONTRIBUTING.md keeps
## "local tooling metadata out of tracked files"). Word-bounded and
## case-insensitive. Three words that would look at home in the list are
## deliberately absent, and each cost a false failure on the first run or
## would have: "cursor" is the mouse pointer in three dozen UI files,
## "llm" only ever turns up inside a PNG's compressed bytes, and "Llama"
## is a Magic creature type (engine/core/creature_types.gd).
## The names themselves are stored rot13'd: spelled out, this file would
## be the one tracked file that carries them, and the pre-commit grep
## would flag it.
FORBIDDEN_TOOLS = re.compile(
    r"(?i)\b(" + codecs.decode("pynhqr|naguebcvp|pungtcg|bcra ?nv|pbcvybg|pbqrk|trzvav", "rot13") + r")\b")

## An address, anywhere. The project's own author identity is a GitHub
## noreply, which is the one form that is not private.
EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
ALLOWED_EMAIL = re.compile(r"(?i)@users\.noreply\.github\.com$")


def tracked_files() -> list[str]:
    """Every path git would commit after `git add -A`: the index plus the
    untracked files no ignore rule hides. Checking those too means a new
    file is caught BEFORE it is staged, and a CODE_MAP row written in the
    same sitting as its file does not fail until `git add`. [] when this
    is no checkout."""
    try:
        done = subprocess.run(["git", "ls-files", "--cached", "--others",
                               "--exclude-standard"], cwd=str(ROOT),
                              capture_output=True, text=True, timeout=120)
    except (OSError, subprocess.SubprocessError):
        return []
    if done.returncode != 0:
        return []
    return [line for line in done.stdout.split("\n") if line]


def text_files() -> list[str]:
    """The tracked files a reader could read. A NUL byte in the first
    block is the classic binary test and is exact enough here: it sorts
    the 53 PNG/TTF/WAV files out of the tree and keeps everything else."""
    out = []
    for name in tracked_files():
        path = ROOT / name
        if not path.is_file() or name.startswith(VENDORED):
            continue
        with path.open("rb") as handle:
            if b"\0" in handle.read(8192):
                continue
        out.append(name)
    return out


class CodeMapTest(unittest.TestCase):
    """EVERY SOURCE FILE HAS A ROW — the map's own opening sentence."""

    @classmethod
    def setUpClass(cls):
        cls.tracked = tracked_files()
        if not cls.tracked:
            raise unittest.SkipTest("not a git checkout")
        cls.map_text = (ROOT / "docs/CODE_MAP.md").read_text(encoding="utf-8")

    def mentioned(self, name: str) -> bool:
        # A row names either the whole path or the file, and the map's
        # shorthand for a screen that is a script plus its scene is
        # `foo.gd/.tscn` — one row for the pair, so the scene's own name
        # never appears on its own.
        base = Path(name).name
        if name in self.map_text or base in self.map_text:
            return True
        stem, suffix = base.rsplit(".", 1)
        return suffix == "tscn" and "%s.gd/.tscn" % stem in self.map_text

    def test_every_source_file_outside_the_card_folders_has_a_row(self):
        missing = [name for name in self.tracked
                   if name.startswith(MAPPED_DIRS)
                   and name.endswith(MAPPED_SUFFIXES)
                   and not self.mentioned(name)]
        self.assertEqual(missing, [], "add a docs/CODE_MAP.md row for these")

    def test_the_root_shell_entry_points_have_a_row(self):
        missing = [name for name in self.tracked
                   if "/" not in name and name.endswith(".sh")
                   and not self.mentioned(name)]
        self.assertEqual(missing, [])

    def test_no_row_points_at_a_file_that_is_gone(self):
        # Only the rows that spell a whole path; a bare file name in a
        # sentence ("...and `test_ai_unfair.gd` pin the refinements") is
        # prose about a row above it, not a row of its own. A row that
        # covers a folder with a glob (`cards/sets/ice/*.gd`) names no
        # single file, and `foo.gd/.tscn` is the shorthand for a screen's
        # script and its scene together.
        tracked = set(self.tracked)
        stale = []
        for quoted in re.findall(r"`([^`\n]+)`", self.map_text):
            named = quoted[:-len("/.tscn")] if quoted.endswith(".gd/.tscn") \
                else quoted
            if "/" not in named or not named.endswith(MAPPED_SUFFIXES):
                continue
            if "*" in named or named.startswith(("res://", "../", "user://")):
                continue
            if named not in tracked:
                stale.append(quoted)
        self.assertEqual(sorted(set(stale)), [])


class PublicationTest(unittest.TestCase):
    """NOTHING OF THIS MACHINE, AND NOBODY'S NAME, IN A TRACKED FILE."""

    @classmethod
    def setUpClass(cls):
        cls.files = text_files()
        if not cls.files:
            raise unittest.SkipTest("not a git checkout")

    def test_no_tracked_file_names_this_machines_home(self):
        # The release guard itself, pointed at the tree instead of at a
        # staged package, so the two can never answer differently.
        offenders = []
        for name in self.files:
            try:
                package_release.guard_private([ROOT / name])
            except ValueError:
                offenders.append(name)
        self.assertEqual(offenders, [])

    def test_no_tracked_file_carries_a_private_address(self):
        offenders = []
        for name in self.files:
            text = (ROOT / name).read_text(encoding="utf-8", errors="ignore")
            for found in EMAIL.findall(text):
                if not ALLOWED_EMAIL.search(found):
                    offenders.append("%s: %s" % (name, found))
        self.assertEqual(sorted(set(offenders)), [])

    def test_no_tracked_file_names_an_assistant(self):
        offenders = []
        for name in self.files:
            text = (ROOT / name).read_text(encoding="utf-8", errors="ignore")
            for found in FORBIDDEN_TOOLS.findall(text):
                offenders.append("%s: %s" % (name, found))
        self.assertEqual(sorted(set(offenders)), [])


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""A `--script` entry point cannot name an autoload.

A GDScript run with `godot --script res://X.gd` is compiled before the
autoloads in project.godot are named, so `CardPacks.pack_of_set(...)`
on a code line of such a script is "Identifier not found: CardPacks"
at the shell and nothing at all under the test runner, where the
autoloads are in the tree and the same line compiles. That is how the
AutoDeck CLI shipped for an afternoon on 2026-09-26 with a set → pack
refusal no shell could start: the GUT suite that held the message was
green. The entry points reach the node through the tree
(`root.get_node_or_null("CardPacks")`) and a static table through the
script (`preload("res://game/card_packs.gd")`); this test holds every
`extends SceneTree` script outside the addons and tests to that.

No Godot: a reading of the scripts' own text, comments stripped.

Run from the repo root:
    python3 -m unittest discover -s tools -p 'test_*.py'
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def autoload_names():
    """The [autoload] section of project.godot, names only."""
    text = (ROOT / "project.godot").read_text(encoding="utf-8")
    section = text.split("[autoload]", 1)[1].split("\n[", 1)[0]
    return [line.split("=", 1)[0].strip() for line in section.splitlines()
            if "=" in line]


def entry_points():
    """Every script that is a --script of its own: `extends SceneTree`,
    outside the addons and the tests."""
    found = []
    for path in sorted(ROOT.rglob("*.gd")):
        rel = path.relative_to(ROOT)
        if rel.parts[0] in ("addons", "tests", ".godot"):
            continue
        if re.search(r"^extends SceneTree\b", path.read_text(encoding="utf-8"), re.M):
            found.append(rel)
    return found


def autoload_uses(path, names):
    """(line number, name, line) for every code line that names an
    autoload as an identifier — `Name.` not preceded by a word
    character, a quote, a dot or a slash (a string or a path is not an
    identifier). Comments are stripped first."""
    uses = []
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        code = line.split("#", 1)[0]
        for name in names:
            if re.search(r'(?<![\w"\'./])' + re.escape(name) + r"\.", code):
                uses.append((number, name, line.strip()))
    return uses


class ScriptEntryPoints(unittest.TestCase):
    def test_the_two_lab_tools_are_entry_points(self):
        points = entry_points()
        self.assertIn(Path("DeckLab/simulate.gd"), points)
        self.assertIn(Path("DeckLab/auto_deck_cli.gd"), points)
        self.assertGreaterEqual(len(points), 10, points)

    def test_the_autoloads_are_read_from_the_project(self):
        names = autoload_names()
        self.assertIn("CardPacks", names)
        self.assertIn("Lifecycle", names)

    def test_no_entry_point_names_an_autoload_on_a_code_line(self):
        names = autoload_names()
        offences = []
        for rel in entry_points():
            for number, name, line in autoload_uses(ROOT / rel, names):
                offences.append("%s:%d names %s: %s" % (rel, number, name, line))
        self.assertEqual(offences, [],
                         "a --script compiles before the autoloads are named; "
                         "reach the node through the tree or the table through "
                         "the script:\n" + "\n".join(offences))

    def test_the_reading_catches_the_afternoons_bug_and_spares_a_comment(self):
        names = ["CardPacks"]
        probe = ROOT / "tools" / "_probe_entry_point.gd"
        probe.write_text(
            "extends SceneTree\n"
            "## CardPacks.pack_of_set is a table  # a doc comment is fine\n"
            "const PacksScript := preload(\"res://game/card_packs.gd\")\n"
            "func _initialize() -> void:\n"
            "\tvar node := root.get_node_or_null(\"CardPacks\")\n"
            "\tvar pack := CardPacks.pack_of_set(\"ice\")  # the bug\n"
            "\tprint(node, pack, PacksScript.pack_of_set(\"ice\"))\n",
            encoding="utf-8")
        try:
            uses = autoload_uses(probe, names)
        finally:
            probe.unlink()
        self.assertEqual([(number, name) for number, name, _ in uses],
                         [(6, "CardPacks")])


if __name__ == "__main__":
    unittest.main()

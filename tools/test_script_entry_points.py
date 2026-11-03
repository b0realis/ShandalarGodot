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

NOR CAN ANY SCRIPT IT COMPILES (0.60.13 bug campaign, h5-1). A
`--script` compiles every script its own names — a `class_name` on a
code line, a `preload`, an `extends "res://…"` — and theirs in turn.
In 0.60.6 the model-side expansion directory (reached from
AdventurePlayer, and so from the Deck Lab, AutoDeck and lab_query)
began to name WorldScreen, VisitPane and WorldHud, and the world UI
they compiled named TouchControls and CardPacks: some twenty SCRIPT
ERRORs on every Lab run, and a red CI shard. The entry point's own
lines were clean. So the reading follows the references, and an
autoload named on a code line of any script an entry point reaches is
the same fault. A `load("res://…")` is read at run time, when the
autoloads are there, and is not followed.

AND NO AUTOLOAD PRINTS ON STDOUT (0.60.13 bug campaign, h4-4). The
autoloads run inside every tool, door and `--script`; a tool's stdout
is its report — the MCP server parses the whole of it as one JSON
object. A connected pad's "pad 0 connected" line after the JSON broke
every engine-backed MCP tool on a Steam Deck, whose own pad is always
there. Diagnostics go to stderr (`printerr`), as the pack scan's do.

No Godot: a reading of the scripts' own text, comments and string
literals stripped.

Run from the repo root:
    python3 -m unittest discover -s tools -p 'test_*.py'
"""
import functools
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

## Entry points that `extends SceneTree` but are never run with
## `--script`: the game's own door hosts them after the autoloads are in
## the tree. Each names the door; a test holds the door to its word.
DOOR_ONLY = {
    Path("DeckLab/referee.gd"): ("game/main.gd", "--referee"),
}

## A comment, or a string literal (triple-quoted first), in GDScript.
_LEXEME = re.compile(r'#[^\n]*|"""[\s\S]*?"""|\'\'\'[\s\S]*?\'\'\''
                     r'|"(?:[^"\\\n]|\\.)*"|\'(?:[^\'\\\n]|\\.)*\'')


def autoload_names():
    """The [autoload] section of project.godot, names only."""
    return list(autoload_scripts())


def autoload_scripts():
    """The [autoload] section of project.godot: name -> res:// path."""
    text = (ROOT / "project.godot").read_text(encoding="utf-8")
    section = text.split("[autoload]", 1)[1].split("\n[", 1)[0]
    out = {}
    for line in section.splitlines():
        if "=" in line and not line.lstrip().startswith(";"):
            name, value = line.split("=", 1)
            out[name.strip()] = value.strip().strip('"').lstrip("*")
    return out


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


@functools.lru_cache(maxsize=None)
def strip(text):
    """(code, bare): [param text] without its comments, and the same
    without its string literals' contents too. A literal's own newlines
    are kept, so line numbers hold in both."""
    code, bare, at = [], [], 0
    for match in _LEXEME.finditer(text):
        piece = match.group(0)
        code.append(text[at:match.start()])
        bare.append(text[at:match.start()])
        at = match.end()
        if piece.startswith("#"):
            continue
        code.append(piece)
        quote = piece[:3] if piece[:3] in ('"""', "'''") else piece[0]
        bare.append(quote + "\n" * piece.count("\n") + quote)
    code.append(text[at:])
    bare.append(text[at:])
    return "".join(code), "".join(bare)


def autoload_uses_in(text, names):
    """(line number, name, line) for every code line of [param text]
    that names an autoload as an identifier — `Name.` not preceded by a
    word character, a quote, a dot or a slash (a string or a path is not
    an identifier). Comments and string literals are stripped first."""
    if not names:
        return []
    _, bare = strip(text)
    pattern = re.compile(r'(?<![\w"\'./])(' + "|".join(map(re.escape, names)) + r")\.")
    raw = text.splitlines()
    uses = []
    for number, line in enumerate(bare.splitlines(), 1):
        for name in dict.fromkeys(pattern.findall(line)):
            uses.append((number, name, raw[number - 1].strip() if number <= len(raw) else line))
    return uses


def autoload_uses(path, names):
    """[method autoload_uses_in] of the file at [param path]."""
    return autoload_uses_in(path.read_text(encoding="utf-8"), names)


def project_scripts():
    """res:// path -> text of every script a tool could compile: all but
    the addons, the tests and the import cache."""
    scripts = {}
    for path in ROOT.rglob("*.gd"):
        rel = path.relative_to(ROOT)
        if rel.parts[0] in ("addons", "tests", ".godot"):
            continue
        scripts["res://" + rel.as_posix()] = path.read_text(encoding="utf-8")
    return scripts


def class_names(scripts):
    """class_name -> res:// path, of [param scripts]."""
    out = {}
    for path, text in scripts.items():
        match = re.search(r"^class_name\s+(\w+)", text, re.M)
        if match:
            out[match.group(1)] = path
    return out


def references(path, scripts, classes):
    """The scripts that compiling [param path] compiles: its preloads and
    its `extends "res://…"` (read with the string literals in place, the
    comments gone), and every class_name its code lines name (read with
    the literals blanked, so a class named in a message is not one)."""
    code, bare = strip(scripts[path])
    out = set()
    for match in re.finditer(r'\bpreload\(\s*"(res://[^"]+)"', code):
        if match.group(1) in scripts:
            out.add(match.group(1))
    for match in re.finditer(r'^extends\s+"(res://[^"]+)"', code, re.M):
        if match.group(1) in scripts:
            out.add(match.group(1))
    for name in set(re.findall(r"\b([A-Z]\w*)\b", bare)):
        if name in classes and classes[name] != path:
            out.add(classes[name])
    return out


def reached(entry, scripts, classes, memo=None):
    """Every script compiling [param entry] compiles, each with the one
    that named it first (the entry's own parent is None). [param memo]
    keeps each script's references for the next entry."""
    memo = {} if memo is None else memo
    parents = {entry: None}
    queue = [entry]
    while queue:
        path = queue.pop(0)
        if path not in memo:
            memo[path] = sorted(references(path, scripts, classes))
        for found in memo[path]:
            if found not in parents:
                parents[found] = path
                queue.append(found)
    return parents


def chain(path, parents):
    """`entry -> … -> path`, by the first names."""
    links = []
    while path is not None:
        links.append(path.removeprefix("res://"))
        path = parents[path]
    return " -> ".join(reversed(links))


def compile_offences(entry, scripts, classes, names, memo=None):
    """Every code line naming an autoload in a script [param entry]
    reaches, with the chain that reached it."""
    parents = reached(entry, scripts, classes, memo)
    offences = []
    for path in sorted(parents):
        for number, name, line in autoload_uses_in(scripts[path], names):
            offences.append("%s:%d names %s: %s  (%s)" % (
                path.removeprefix("res://"), number, name, line, chain(path, parents)))
    return offences


def stdout_prints_in(text):
    """(line number, line) of every code line of [param text] that
    writes to stdout: `print`, `prints`, `printt`, `print_rich`,
    `printraw` (not `printerr`, `print_verbose` or a method of the same
    name on another object)."""
    _, bare = strip(text)
    raw = text.splitlines()
    hits = []
    for number, line in enumerate(bare.splitlines(), 1):
        if re.search(r"(?<![\w.])print(?:s|t|_rich|raw)?\s*\(", line):
            hits.append((number, raw[number - 1].strip()))
    return hits


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
        self.assertIn("PadControls", names)
        self.assertEqual(autoload_scripts()["PadControls"], "res://game/input/pad_controls.gd")

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

    def test_no_script_an_entry_point_compiles_names_an_autoload(self):
        names = autoload_names()
        scripts = project_scripts()
        classes = class_names(scripts)
        offences, memo = [], {}
        for rel in entry_points():
            if rel in DOOR_ONLY:
                continue
            offences += compile_offences("res://" + rel.as_posix(), scripts, classes, names, memo)
        self.assertEqual(offences, [],
                         "a --script compiles every script it names, before the "
                         "autoloads are named; keep the model side from naming "
                         "screen classes (an untyped Node, a load() at run time), "
                         "or reach the autoload through the tree:\n" + "\n".join(offences))

    def test_the_lab_tools_reach_the_adventure_model_but_not_its_screen(self):
        # The h5-1 chain, pinned: the Lab compiles AdventurePlayer and the
        # expansion directory (the duel warm-up reads a hero), and stops
        # there — no world screen, pane or panel.
        scripts = project_scripts()
        parents = reached("res://DeckLab/simulate.gd", scripts, class_names(scripts))
        self.assertIn("res://game/adventure/adventure_player.gd", parents)
        self.assertIn("res://game/adventure/expansions/adventure_expansions.gd", parents)
        for screen in ("world_screen.gd", "visit_pane.gd", "world_hud.gd"):
            self.assertNotIn("res://game/adventure/world/" + screen, parents,
                             chain("res://game/adventure/world/" + screen, parents)
                             if "res://game/adventure/world/" + screen in parents else "")

    def test_the_door_only_entry_points_are_hosted_by_their_door(self):
        launchers = [p for p in ROOT.rglob("*.sh") if p.relative_to(ROOT).parts[0] not in ("addons", ".godot")]
        for rel, (door, flag) in DOOR_ONLY.items():
            self.assertIn(rel, entry_points())
            host = (ROOT / door).read_text(encoding="utf-8")
            self.assertIn('"res://%s"' % rel.as_posix(), host, "%s hosts %s" % (door, rel))
            self.assertIn('"%s"' % flag, host)
            for launcher in launchers:
                self.assertIsNone(
                    re.search(r"(--script|\s-s)\s+res://" + re.escape(rel.as_posix()),
                              launcher.read_text(encoding="utf-8", errors="replace")),
                    "%s runs %s with --script" % (launcher.relative_to(ROOT), rel))

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

    def test_the_reading_follows_class_names_and_preloads_not_loads(self):
        # 0.60.6's chain in miniature: a tool preloads a model, the model
        # names a screen class, the screen names an autoload. A load() at
        # run time, a class named in a comment or a message, and an
        # autoload named inside a string are not compiled references.
        scripts = {
            "res://tool.gd": 'extends SceneTree\nconst MODEL := preload("res://model.gd")\n',
            "res://model.gd": ('class_name Model\n'
                               'static func show(screen: Node) -> void:  # was WorldPanel\n'
                               '\tvar pane = load("res://lazy.gd").new()\n'
                               '\tprint("see WorldPanel or Lazy")\n'
                               '\tScreenPart.open(screen, pane)\n'),
            "res://part.gd": ('class_name ScreenPart\nstatic func open(a, b) -> void:\n'
                              '\tvar s := """CardPacks.not_code\n"""\n'
                              '\tTouchControls.should_be_active()\n'),
            "res://panel.gd": "class_name WorldPanel\nfunc f():\n\tCardPacks.x()\n",
            "res://lazy.gd": "class_name Lazy\nfunc f():\n\tCardPacks.x()\n",
        }
        classes = class_names(scripts)
        self.assertEqual(sorted(reached("res://tool.gd", scripts, classes)),
                         ["res://model.gd", "res://part.gd", "res://tool.gd"])
        offences = compile_offences("res://tool.gd", scripts, classes, ["CardPacks", "TouchControls"])
        self.assertEqual(len(offences), 1, offences)
        self.assertTrue(offences[0].startswith("part.gd:5 names TouchControls"), offences[0])
        self.assertTrue(offences[0].endswith("(tool.gd -> model.gd -> part.gd)"), offences[0])

    def test_no_autoload_prints_on_stdout(self):
        offences = []
        for name, path in autoload_scripts().items():
            text = (ROOT / path.removeprefix("res://")).read_text(encoding="utf-8")
            for number, line in stdout_prints_in(text):
                offences.append("%s (%s):%d: %s" % (path, name, number, line))
        self.assertEqual(offences, [],
                         "an autoload runs inside every tool, whose stdout is its "
                         "report (the MCP server parses it as one JSON object); "
                         "write diagnostics with printerr:\n" + "\n".join(offences))

    def test_the_stdout_reading_spares_stderr_and_lookalikes(self):
        text = ('func f():\n'
                '\tprinterr("pad 0 connected")\n'
                '\tprint_verbose("only with --verbose")\n'
                '\tvar seal := PackSeal.table_fingerprint(path)\n'
                '\t# print("a comment")\n'
                '\tvar s := "print(not code)"\n'
                '\tlog.print("a method")\n'
                '\tprints("a", "b")\n'
                '\tprint("x")\n')
        self.assertEqual([number for number, _ in stdout_prints_in(text)], [8, 9])


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""game/skin_builder/skin_recipes.gd mirrors the importer's tables.

The in-game skin builder (game/skin_builder/) is a port of
import_original.py, and what it imports under which name is this tool's
own tables, written out as GDScript constants. This test renders them
again and compares, so a row added to the importer cannot be forgotten
in the game:

    python3 tools/test_skin_recipes_mirror.py --write    # write the file anew
"""

import json
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import import_original as imp  # noqa: E402
import mtg_assets  # noqa: E402

TARGET = HERE.parent / "game" / "skin_builder" / "skin_recipes.gd"

HEAD = '''class_name SkinRecipes
extends RefCounted
## WHAT THE SKIN BUILDER IMPORTS, AND UNDER WHICH NAME: the tables of
## `tools/import_original.py` (and the landmarks of `tools/mtg_assets.py`)
## as constants, row for row and in the same order.
##
## WRITTEN BY A TOOL, NOT BY HAND: `python3
## tools/test_skin_recipes_mirror.py --write` renders this file from the
## Python tables, and the same file's test fails when the two differ. Add
## a row there, then write this file anew. Every table is a JSON value, so
## the test reads it back without a GDScript parser.
##
## The reasons for each row — which 1997 file, why that palette, what was
## measured — are the comments beside the Python tables; they are not
## repeated here.
'''


def tables() -> dict:
    """Every table the game's builder reads, by its constant's name."""
    sidecars = {k: list(v) for k, v in imp.SIDECAR_SHEETS.items()}
    return {
        "MANIFEST": {k: list(v) for k, v in imp.MANIFEST.items()},
        "PIC_SCREENS": {k: list(v) for k, v in imp.PIC_SCREENS.items()},
        "PIC_CUT": sorted(imp.PIC_CUT),
        "PIC_OPAQUE": sorted(imp.PIC_OPAQUE),
        "PIC_PALETTES": {k: list(v) for k, v in imp.PIC_PALETTES.items()},
        "PIC_PALETTE": list(imp.PIC_PALETTE),
        "SPR_PALETTE": list(imp.SPR_PALETTE),
        "SPR_PALETTES": {k: list(v) for k, v in imp.SPR_PALETTES.items()},
        "SPR_SHEETS": {k: list(v[1:]) for k, v in imp.SPR_SHEETS.items()},
        "SPR_COLUMNS": dict(imp.SPR_COLUMNS),
        "SIDECAR_SHEETS": sidecars,
        "PIC_SHEETS": {k: [list(v[0]), v[1], v[2], v[3]]
                       for k, v in imp.PIC_SHEETS.items()},
        "DERIVED_SHEETS": {k: [v[0], v[1]] for k, v in imp.DERIVED_SHEETS.items()},
        "STATWIN_CLEAR": {k: list(v) for k, v in imp.STATWIN_CLEAR.items()},
        "PORTRAIT_SHEET_RAW": list(imp.PORTRAIT_SHEET_RAW),
        "PORTRAIT_CELL": list(imp.PORTRAIT_CELL),
        "PORTRAIT_PALETTE": list(imp.PORTRAIT_PALETTE_PIC + imp.PORTRAIT_PALETTE_TR),
        "PORTRAIT_NAMES": list(imp.PORTRAIT_NAMES),
        "PORTRAIT_PREFIX": imp.PORTRAIT_PREFIX,
        "PLAYER_FACE_PIC": list(imp.PLAYER_FACE_PIC),
        "PLAYER_FACE_NAME": imp.PLAYER_FACE_NAME,
        "ROGUE_SLOTS": len(imp.ROGUE_SLOTS),
        "ROGUE_CELL": list(imp.ROGUE_CELL),
        "ROGUE_PALETTE": list(imp.ROGUE_PALETTE_TR + imp.ROGUE_PALETTE_PIC),
        "ROGUE_NAMES": list(imp.ROGUE_NAMES),
        "ROGUE_PREFIX": imp.ROGUE_PREFIX,
        "ROGUE_UNNAMED_PREFIX": imp.ROGUE_UNNAMED_PREFIX,
        "PORTRAITS_WANTED": imp.PORTRAITS_WANTED,
        "NOT_READ": sorted(imp.NOT_READ),
        "SCREENS_NOT_READ": sorted(imp.SCREENS_NOT_READ),
        "VIDEOS": {k: list(v) for k, v in imp.VIDEOS.items()},
        "THEORA_MOVIES": {k: list(v) for k, v in imp.THEORA_MOVIES.items()},
        "CARD_TABLE_PROGRAMS": list(imp.CARD_TABLE_PROGRAMS),
        "CARD_ROW": imp.CARD_ROW,
        "CARD_VALUES_KEY": imp.CARD_VALUES_KEY,
        "HINTS_KEY": imp.HINTS_KEY,
        "HINT_LEVELS": dict(imp.HINT_LEVELS),
        "WISE_WORDS_KEY": imp.WISE_WORDS_KEY,
        "OCCURRENCE": dict(imp.OCCURRENCE),
        "PIC_MAX_SIDE": imp.PIC_MAX_SIDE,
        "PIC_CLEAR": imp.PIC_CLEAR,
        "LANDMARKS": {k: list(v) for k, v in mtg_assets.LANDMARKS.items()},
        "MOVIE_DIR": mtg_assets.MOVIE_DIR,
        "MOVIE_NAMES": list(mtg_assets.MOVIE_NAMES),
        "ZIP_RETIRED": list(mtg_assets.RETIRED),
    }


def _json(value) -> str:
    """JSON, a row a line for a table and one line for anything else."""
    if isinstance(value, dict) and value:
        rows = ["\t%s: %s" % (json.dumps(k), json.dumps(v)) for k, v in value.items()]
        return "{\n" + ",\n".join(rows) + "\n}"
    if isinstance(value, list) and len(json.dumps(value)) > 88:
        return "[\n" + ",\n".join("\t" + json.dumps(v) for v in value) + "\n]"
    return json.dumps(value)


def render() -> str:
    out = [HEAD]
    for name, value in tables().items():
        out.append("# <%s>" % name)
        out.append("const %s := %s" % (name, _json(value)))
        out.append("# </%s>\n" % name)
    return "\n".join(out)


def parse(text: str) -> dict:
    """The tables back out of the GDScript: each is JSON between its
    `# <NAME>` and `# </NAME>` lines, after `const NAME := `."""
    found: dict = {}
    for name in tables():
        start = text.index("# <%s>\n" % name) + len("# <%s>\n" % name)
        end = text.index("# </%s>" % name)
        body = text[start:end]
        found[name] = json.loads(body[len("const %s := " % name):])
    return found


class TestSkinRecipesMirror(unittest.TestCase):
    def test_the_game_s_tables_are_the_importer_s(self):
        text = TARGET.read_text(encoding="utf-8")
        got = parse(text)
        want = json.loads(json.dumps(tables()))
        for name in want:
            self.assertEqual(got[name], want[name],
                             "%s differs: run this file with --write" % name)
            if isinstance(want[name], dict):
                self.assertEqual(list(got[name]), list(want[name]),
                                 "%s is in another order" % name)

    def test_the_file_is_exactly_what_the_tool_writes(self):
        self.assertEqual(TARGET.read_text(encoding="utf-8"), render())

    def test_no_two_recipes_write_one_file(self):
        """The game writes each file once, straight into the zip: a name
        made twice would be an entry twice."""
        names = [k if k.endswith((".ttf", ".wav")) else k + ".png"
                 for k in imp.MANIFEST]
        names += [k + ".png" for k in imp.PIC_SCREENS]
        names += [k + ".json" for k in imp.SIDECAR_SHEETS]
        names += [k + ".json" for k in (imp.CARD_VALUES_KEY, imp.HINTS_KEY,
                                         imp.WISE_WORDS_KEY)]
        self.assertEqual(len(names), len(set(names)))


if __name__ == "__main__":
    if "--write" in sys.argv:
        TARGET.write_text(render(), encoding="utf-8")
        print("wrote %s" % TARGET)
        sys.exit(0)
    unittest.main()

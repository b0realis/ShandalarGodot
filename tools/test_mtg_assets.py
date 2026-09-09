#!/usr/bin/env python3
"""Self-test for tools/mtg_assets.py — the player's archive builder.

Run from the repo root:
    python3 -m unittest discover -s tools -p 'test_*.py'

What is pinned is the shape of the zips it writes, because the game
mounts them by that shape (`SkinPack.inspect`): a skin folder becomes
`skin/...`, a folder of card pictures becomes `skin/cardart/...`
(2026-09-08, the owner: *"card art pack should be separate!"*), and
each is told which name to take beside the game. Since 2026-09-09 the
LANDMARKS are pinned too: what `--check` recognises is what `--install`
agrees to import from, and it used to recognise raw 1997 names only.
"""

import io
import struct
import sys
import tarfile
import tempfile
import unittest
import zipfile
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import import_original as imp  # noqa: E402
import mtg_assets  # noqa: E402


## The counter strip's own size — one column of 25 cells of 24x30, the
## 25th the mask they share (`import_original.py`'s `card_counters` row).
## A literal since 2026-09-09: the strip stopped being a step of its own
## when every raw `.pic` gained one, so there is no constant to read.
COUNTER_WIDTH, COUNTER_HEIGHT = 24, 750


class TestWriteZip(unittest.TestCase):

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def _folder(self, name: str, files: dict[str, bytes]) -> Path:
        folder = self.dir / name
        for rel, body in files.items():
            (folder / rel).parent.mkdir(parents=True, exist_ok=True)
            (folder / rel).write_bytes(body)
        return folder

    def test_a_skin_folder_is_zipped_under_skin(self):
        skin = self._folder("skin", {"card_back.png": b"png", "portraits/x.png": b"png",
                                     "card_back.png.import": b"sidecar"})
        out = self.dir / "a.zip"
        report = io.StringIO()
        with redirect_stdout(report):
            self.assertEqual(mtg_assets.write_zip(skin, out), 0)
        with zipfile.ZipFile(out) as zf:
            self.assertEqual(sorted(zf.namelist()), ["skin/card_back.png", "skin/portraits/x.png"])
        self.assertIn("skin/original_skin.zip", report.getvalue())
        self.assertIn("Options > Skin", report.getvalue())

    def test_a_folder_of_card_pictures_is_zipped_under_skin_cardart(self):
        art = self._folder("cardart", {"serra_angel.jpg": b"jpg", "ley_druid.png": b"png"})
        out = self.dir / "b.zip"
        report = io.StringIO()
        with redirect_stdout(report):
            self.assertEqual(mtg_assets.write_zip(art, out, inner="cardart"), 0)
        with zipfile.ZipFile(out) as zf:
            self.assertEqual(sorted(zf.namelist()),
                             ["skin/cardart/ley_druid.png", "skin/cardart/serra_angel.jpg"])
        self.assertIn("skin/cardart.zip", report.getvalue())
        self.assertNotIn("skin/original_skin.zip", report.getvalue())

    def test_a_tar_gz_name_writes_a_tar_gz_of_the_same_entries(self):
        art = self._folder("cardart2", {"serra_angel.jpg": b"jpg", "ley_druid.png": b"png"})
        out = self.dir / "b.tar.gz"
        report = io.StringIO()
        with redirect_stdout(report):
            self.assertEqual(mtg_assets.write_zip(art, out, inner="cardart"), 0)
        with tarfile.open(out, "r:gz") as tf:
            self.assertEqual(sorted(m.name for m in tf.getmembers() if m.isfile()),
                             ["skin/cardart/ley_druid.png", "skin/cardart/serra_angel.jpg"])
            self.assertEqual(tf.extractfile("skin/cardart/ley_druid.png").read(), b"png")
        self.assertIn("repacks it into a zip once, as\n  b.zip\n", report.getvalue())
        self.assertNotIn("cp b.tar.gz", report.getvalue(), "not for beside the game")
        self.assertTrue(mtg_assets.is_tar_name("Skin.TGZ"))
        self.assertFalse(mtg_assets.is_tar_name("skin.zip"))

    def test_the_counter_strip_survives_the_zip_whole(self):
        """24x750 in, 24x750 out, byte for byte. The strip's 25th cell is
        the mask every stone wears, so anything that trimmed or repacked
        it would leave `CounterMarks.tile()` cutting a stone with no mask
        to cut it out of — and the archive is the only copy the player
        ever sees."""
        skin = self.dir / "counters"
        skin.mkdir()
        pixels = bytes(bytearray(
            b for i in range(COUNTER_WIDTH * COUNTER_HEIGHT)
            for b in (i % 251, 7, 9)))
        imp.write_png(skin / "card_counters.png", COUNTER_WIDTH,
                      COUNTER_HEIGHT, pixels)
        out = self.dir / "counters.zip"
        with redirect_stdout(io.StringIO()):
            self.assertEqual(mtg_assets.write_zip(skin, out), 0)
        with zipfile.ZipFile(out) as zf:
            self.assertEqual(zf.namelist(), ["skin/card_counters.png"])
            inside = zf.read("skin/card_counters.png")
        self.assertEqual(inside, (skin / "card_counters.png").read_bytes())
        self.assertEqual(struct.unpack(">II", inside[16:24]),
                         (COUNTER_WIDTH, COUNTER_HEIGHT))

    def test_an_empty_folder_is_refused(self):
        empty = self.dir / "empty"
        empty.mkdir()
        with redirect_stdout(io.StringIO()):
            self.assertEqual(mtg_assets.write_zip(empty, self.dir / "c.zip"), 1)
        self.assertFalse((self.dir / "c.zip").exists())


class TestLandmarks(unittest.TestCase):
    """WHAT `--check` RECOGNISES IS WHAT `--install` WILL IMPORT FROM.

    `main` runs `report` over every `--install` folder and STOPS on one
    that reports nothing, so a landmark list that names only raw 1997
    filenames refuses the converted trees this importer was written to
    read: on 2026-09-09 an s30 checkout — the one place a converted
    `Cardcounters.pic.png` exists — printed "Nothing recognisable here"
    and was declined, while the importer takes ninety keys out of it.
    """

    def _tree(self, names: list[str]) -> Path:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = Path(tmp.name)
        for name in names:
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"art")
        return root

    def test_a_raw_1997_install_is_recognised(self):
        root = self._tree(["Cardart/Manasymbols.pic",
                           "Cardart/Cardcounters.pic",
                           "Faces/001.pic", "16faces.spr"])
        found = mtg_assets.look_around(root)
        self.assertEqual(found["the counter stones"], ["cardcounters.pic"])
        self.assertIn("manasymbols.pic", found["the card frames and mana symbols"])
        with redirect_stdout(io.StringIO()):
            self.assertTrue(mtg_assets.report(root))

    def test_a_tree_of_conversions_is_not_an_install(self):
        """The owner's ruling of 2026-09-09: this tool imports from the
        player's own 1997 game and from nothing else. A reimplementation's
        converted art is that project's redistribution of the original, so
        a tree of `.pic.png` files is refused here even though it holds
        the same pictures — the refusal is the policy, not a gap."""
        root = self._tree(["assets/art/card/Cardcounters.pic.png",
                           "assets/art/card/Manasymbols.pic.png",
                           "assets/art/card/Cardback.pic.png",
                           "assets/art/screens/16faces.spr.png",
                           "assets/art/screens/duel/Winbk_Options.pic.png"])
        found = mtg_assets.look_around(root)
        self.assertEqual(found["the counter stones"], [])
        for group in ("the card frames and mana symbols", "the portraits",
                      "the shell and dialog art"):
            self.assertFalse(found[group], group)
        report = io.StringIO()
        with redirect_stdout(report):
            self.assertFalse(mtg_assets.report(root),
                             "a conversion tree is not an install")
        self.assertIn("Nothing recognisable", report.getvalue())

    def test_a_folder_with_none_of_it_is_still_refused(self):
        root = self._tree(["holiday/photo.jpg"])
        report = io.StringIO()
        with redirect_stdout(report):
            self.assertFalse(mtg_assets.report(root))
        self.assertIn("Nothing recognisable", report.getvalue())

    def test_the_counter_group_names_the_raw_file_the_importer_decodes(self):
        """The group names the 1997 file and only it: the raw
        `Cardcounters.pic` the importer decodes. The manifest row also
        lists conversions, but those are not a door this tool opens (see
        LANDMARKS' note, 2026-09-09)."""
        raw = {name.split("/")[-1].lower()
               for name in imp.MANIFEST["card_counters"]
               if not name.lower().endswith(".png")}
        self.assertEqual(set(mtg_assets.LANDMARKS["the counter stones"]), raw)
        for name in mtg_assets.LANDMARKS["the counter stones"]:
            self.assertFalse(name.endswith(".png"),
                             "a conversion is not an install's landmark")

    def test_every_landmark_is_a_raw_1997_name(self):
        """The rule the owner set on 2026-09-09, across every group:
        what this tool recognises as an install is the 1997 game's own
        files, never a reimplementation's export of them."""
        for group, names in mtg_assets.LANDMARKS.items():
            for name in names:
                self.assertFalse(name.endswith((".png", ".pic.png",
                                                ".spr.png")),
                                 "%s: %s" % (group, name))

    def test_the_deck_builder_group_names_files_the_importer_asks_for(self):
        """`Dbart/` is imported whole since 2026-09-09 — the filter
        medallions, the deck-slot plaques, the header slab, the two
        tiles — so the check has to be able to see it."""
        wanted = {name.lower()
                  for row in imp.MANIFEST.values() for name in row}
        wanted |= {name.lower()
                   for names, _c, _w, _h in imp.PIC_SHEETS.values()
                   for name in names}
        for name in mtg_assets.LANDMARKS["the deck builder art"]:
            self.assertTrue(name == "dbart" or name in wanted, name)



if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Self-test for tools/mtg_assets.py — the player's archive builder.

Run from the repo root:
    python3 -m unittest discover -s tools -p 'test_*.py'

What is pinned is the shape of the zips it writes, because the game
mounts them by that shape (`SkinPack.inspect`): a skin folder becomes
`skin/...`, a folder of card pictures becomes `skin/cardart/...`
(2026-09-08, the owner: *"card art pack should be separate!"*), and
each is told which name to take beside the game.
"""

import io
import sys
import tarfile
import tempfile
import unittest
import zipfile
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import mtg_assets  # noqa: E402


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

    def test_an_empty_folder_is_refused(self):
        empty = self.dir / "empty"
        empty.mkdir()
        with redirect_stdout(io.StringIO()):
            self.assertEqual(mtg_assets.write_zip(empty, self.dir / "c.zip"), 1)
        self.assertFalse((self.dir / "c.zip").exists())


if __name__ == "__main__":
    unittest.main()

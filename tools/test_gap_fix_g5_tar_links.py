#!/usr/bin/env python3
"""A linked picture in a .tar.gz skin (the gap review of 2026-11-10, r5-4) —
`tools/mtg_assets.py` `write_zip`.

The .zip of a skin folder holds a linked picture's BYTES; the .tar.gz held
the LINK, with its target (an absolute path, often under somebody's home
folder) — and `game/tar_pack.gd` skips every entry that is not a file ("a
link: skipped"), so the tar.gz skin came without the picture. Each entry
also carried the builder's user and group names. The tar now holds the
file a link names, and no owner.

Run from the repo root:
    python3 -m unittest tools.test_gap_fix_g5_tar_links
"""
import contextlib
import io
import os
import sys
import tarfile
import tempfile
import unittest
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import mtg_assets  # noqa: E402


@unittest.skipUnless(hasattr(os, "symlink") and os.name != "nt", "needs symbolic links")
class TarHoldsThePictureTest(unittest.TestCase):

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)
        self.real = self.dir / "elsewhere" / "shell_bg.png"
        self.real.parent.mkdir()
        self.real.write_bytes(b"\x89PNG\r\n\x1a\nPICTURE")
        self.skin = self.dir / "skin"
        self.skin.mkdir()
        (self.skin / "other.png").write_bytes(b"\x89PNG\r\n\x1a\nOTHER")
        os.symlink(self.real, self.skin / "shell_bg.png")

    def build(self, name):
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(mtg_assets.write_zip(self.skin, self.dir / name), 0)
        return self.dir / name

    def test_a_linked_picture_is_its_bytes_in_the_tar_as_in_the_zip(self):
        with zipfile.ZipFile(self.build("a.zip")) as zf:
            self.assertEqual(zf.read("skin/shell_bg.png"), self.real.read_bytes())
        with tarfile.open(self.build("a.tar.gz")) as tf:
            member = tf.getmember("skin/shell_bg.png")
            self.assertTrue(member.isfile(), "the tar.gz holds a link to %r, not the picture" % member.linkname)
            self.assertEqual(member.linkname, "")
            self.assertEqual(tf.extractfile(member).read(), self.real.read_bytes())
            self.assertNotIn(str(self.dir), " ".join(m.linkname for m in tf.getmembers()))

    def test_no_entry_names_who_built_it(self):
        with tarfile.open(self.build("b.tgz")) as tf:
            for member in tf.getmembers():
                with self.subTest(member=member.name):
                    self.assertEqual((member.uid, member.gid, member.uname, member.gname), (0, 0, "", ""))


if __name__ == "__main__":
    unittest.main(verbosity=2)

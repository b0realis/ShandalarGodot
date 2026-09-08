#!/usr/bin/env python3
"""Self-test for tools/skin_catalogue.py — the skin's catalogue.

Run from the repo root:
    python3 -m unittest discover -s tools -p 'test_*.py'

Two kinds of check. The measuring helpers are fed files BUILT here (a
PNG header, a WAV from the `wave` module, a font's magic), so no art
travels with the tests. And the COMMITTED catalogue, docs/skin-catalogue
.txt, is held to the importer's manifest: every file the importer writes
is named in it, so a key added to MANIFEST without a note fails here
rather than going undocumented.
"""

import io
import struct
import sys
import tempfile
import unittest
import wave
import zipfile
import zlib
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import import_original as imp  # noqa: E402
import skin_catalogue as cat  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent


def png_bytes(width: int, height: int, color_type: int = 2) -> bytes:
    """A minimal, valid PNG of one flat colour."""
    def chunk(kind: bytes, body: bytes) -> bytes:
        return (struct.pack(">I", len(body)) + kind + body
                + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF))
    channels = {0: 1, 2: 3, 4: 2, 6: 4}[color_type]
    row = b"\x00" + b"\x80" * (width * channels)
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, color_type, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(row * height))
            + chunk(b"IEND", b""))


def wav_bytes(seconds: float, rate: int = 22050, channels: int = 1) -> bytes:
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b"\x00\x00" * channels * int(rate * seconds))
    return buf.getvalue()


class TestMeasuring(unittest.TestCase):

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def test_a_png_is_measured_from_its_header(self):
        path = self.dir / "a.png"
        path.write_bytes(png_bytes(228, 323))
        self.assertEqual(cat.png_size(path), (228, 323, "RGB"))
        self.assertEqual(cat.measure(path), "228 x 323 px, RGB")
        path.write_bytes(png_bytes(35, 36, 6))
        self.assertEqual(cat.png_size(path), (35, 36, "RGBA"))

    def test_a_file_that_is_not_a_png_is_not_measured_as_one(self):
        path = self.dir / "b.png"
        path.write_bytes(b"<html>404</html>")
        self.assertIsNone(cat.png_size(path))
        self.assertEqual(cat.measure(path), "PNG?")

    def test_a_wav_reports_rate_depth_voice_and_length(self):
        path = self.dir / "sfx_tap.wav"
        path.write_bytes(wav_bytes(1.5))
        self.assertEqual(cat.measure(path), "22050 Hz 16-bit mono, 1.5 s")
        path.write_bytes(wav_bytes(12.0, 22050, 2))
        self.assertEqual(cat.measure(path), "22050 Hz 16-bit stereo, 12.0 s")

    def test_a_font_is_known_by_its_magic(self):
        path = self.dir / "font_body.ttf"
        path.write_bytes(b"\x00\x01\x00\x00" + b"\x00" * 12)
        self.assertEqual(cat.measure(path), "TrueType")
        path.write_bytes(b"not a font")
        self.assertEqual(cat.measure(path), "font?")

    def test_a_sidecar_lists_its_grid(self):
        path = self.dir / "coin_toss_heads.json"
        path.write_text('{"cols": 7, "rows": 9, "frames": 61, "frame_width": 320,'
                        ' "frame_height": 240, "fps": 14.9999, "codec": "CRAM"}')
        self.assertEqual(cat.measure(path),
                         "cols 7, rows 9, frames 61, frame_width 320, frame_height 240, fps 15")

    def test_a_missing_file_says_so(self):
        self.assertEqual(cat.measure(self.dir / "nothing.png"), "(not on this machine)")


class TestTheManifestIsCatalogued(unittest.TestCase):

    def test_every_manifest_key_has_a_note(self):
        grouped = cat.sections()   # raises on a key with no note
        catalogued = [k for keys in grouped.values() for k in keys]
        self.assertEqual(sorted(catalogued), sorted(cat.all_keys()))

    def test_pictures_get_png_and_the_rest_keep_their_extension(self):
        self.assertEqual(cat.file_name("card_back"), "card_back.png")
        self.assertEqual(cat.file_name("sfx_tap.wav"), "sfx_tap.wav")
        self.assertEqual(cat.file_name("font_body.ttf"), "font_body.ttf")

    def test_the_expected_files_include_the_movie_sidecars(self):
        files = cat.expected_files()
        for key in imp.VIDEOS:
            self.assertIn(key + ".png", files)
            self.assertIn(key + ".json", files)
        self.assertEqual(len(files), len(set(files)), "no file named twice")

    def test_families_keep_the_manifests_first_order_and_join_split_runs(self):
        grouped = cat.families_of(["set_icon_atq", "card_set_symbols", "set_icon_leg"])
        self.assertEqual([keys for _, keys in grouped],
                         [["set_icon_atq", "set_icon_leg"], ["card_set_symbols"]])

    def test_the_committed_catalogue_names_every_file(self):
        text = (ROOT / "docs" / "skin-catalogue.txt").read_text(encoding="utf-8")
        missing = [f for f in cat.expected_files() if ("    %s" % f) not in text]
        self.assertEqual(missing, [], "regenerate: python3 tools/skin_catalogue.py")
        for heading in ("PORTRAITS", "CARD ART", "MOVIES", "original_skin.zip",
                        "cardart.zip", "Options > Skin", "TO DRAW YOUR OWN"):
            self.assertIn(heading, text)

    def test_rendering_needs_no_art_on_the_machine(self):
        with tempfile.TemporaryDirectory() as tmp:
            text = cat.render(Path(tmp) / "no_skin", Path(tmp) / "no_art")
        self.assertIn("(not on this machine)", text)
        self.assertIn("card_back.png", text)


class TestCheckingASkin(unittest.TestCase):

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def _zip(self, name: str, entries: dict[str, bytes]) -> Path:
        path = self.dir / name
        with zipfile.ZipFile(path, "w") as zf:
            for entry, body in entries.items():
                zf.writestr(entry, body)
        return path

    def test_a_zip_is_read_under_its_skin_folder(self):
        path = self._zip("ok.zip", {"skin/card_back.png": png_bytes(2, 2),
                                    "skin/portraits/x.png": png_bytes(2, 2),
                                    "skin/": b""})
        self.assertEqual(cat.names_in(path), ["card_back.png", "portraits/x.png"])

    def test_an_entry_outside_skin_refuses_the_zip(self):
        path = self._zip("bad.zip", {"skin/card_back.png": b"", "readme.txt": b""})
        with redirect_stdout(io.StringIO()):
            self.assertIsNone(cat.names_in(path))

    def test_a_folder_is_read_without_its_import_sidecars(self):
        (self.dir / "skin").mkdir()
        (self.dir / "skin" / "card_back.png").write_bytes(png_bytes(2, 2))
        (self.dir / "skin" / "card_back.png.import").write_text("")
        self.assertEqual(cat.names_in(self.dir / "skin"), ["card_back.png"])

    def test_check_reports_the_missing_and_the_unknown(self):
        path = self._zip("part.zip", {"skin/card_back.png": png_bytes(2, 2),
                                      "skin/extra.png": png_bytes(2, 2)})
        out = io.StringIO()
        with redirect_stdout(out):
            self.assertEqual(cat.check(path), 0)
        report = out.getvalue()
        self.assertIn("1 of %d named files present" % len(cat.expected_files()), report)
        self.assertIn("title_background.png", report)
        self.assertIn("extra.png", report)

    def test_a_zip_of_card_pictures_alone_is_card_art(self):
        path = self._zip("art.zip", {"skin/cardart/serra_angel.jpg": b"\xff\xd8",
                                     "skin/cardart/notes.txt": b"x"})
        self.assertEqual(cat.kind_of(cat.names_in(path)), "cardart")
        self.assertEqual(cat.kind_of(["card_back.png", "cardart/x.jpg"]), "skin")
        self.assertEqual(cat.kind_of([]), "skin")
        out = io.StringIO()
        with redirect_stdout(out):
            self.assertEqual(cat.check(path), 0)
        report = out.getvalue()
        self.assertIn("card art, 2 pictures", report)
        self.assertIn("notes.txt", report, "a non-picture is called out")
        self.assertNotIn("title_background.png", report,
                         "card art is not held to the skin's list")

    def test_check_refuses_what_is_not_a_skin(self):
        path = self.dir / "page.zip"
        path.write_bytes(b"<html>")
        with redirect_stdout(io.StringIO()):
            self.assertEqual(cat.check(path), 1)


if __name__ == "__main__":
    unittest.main()

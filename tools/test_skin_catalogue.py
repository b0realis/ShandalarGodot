#!/usr/bin/env python3
"""Self-test for tools/skin_catalogue.py — the skin's catalogue.

Run from the repo root:
    python3 -m unittest discover -s tools -p 'test_*.py'

Two kinds of check. The measuring helpers are fed files BUILT here (a
PNG header, a WAV from the `wave` module, a font's magic), so no art
travels with the tests. And the COMMITTED catalogue, docs/skin-catalogue
.txt, is held to the importer's manifest: every file the importer writes
is named in it, so a key added to MANIFEST without a note fails here
rather than going undocumented. The committed TABLE, docs/skin-catalogue
.csv, is held the same way, row for row.
"""

import csv
import io
import os
import re
import struct
import subprocess
import sys
import tarfile
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
        path = self.dir / "font_title.ttf"
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
        self.assertEqual(cat.file_name("font_title.ttf"), "font_title.ttf")

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

    def test_the_committed_table_lists_every_file_by_its_name(self):
        """The owner, 2026-10-17: a CSV of every asset in the skin zip,
        concrete file names and all. Held to the code the way the text
        is: the same rows, in the same order, as a fresh run."""
        with (ROOT / "docs" / "skin-catalogue.csv").open(encoding="utf-8", newline="") as f:
            rows = list(csv.DictReader(f))
        self.assertEqual(tuple(rows[0].keys()), cat.CSV_COLUMNS)
        files = [row["file"] for row in rows]
        self.assertEqual(len(files), len(set(files)), "no file listed twice")
        with tempfile.TemporaryDirectory() as tmp:
            fresh = [row["file"] for row in cat.table_rows(Path(tmp))]
        self.assertEqual(files, fresh, "regenerate: python3 tools/skin_catalogue.py")
        for name in cat.expected_files():
            self.assertIn("skin/" + name, files)
        self.assertEqual(sum(f.startswith("skin/portraits/") for f in files),
                         imp.PORTRAITS_WANTED)
        self.assertIn("skin/portraits/rogue_witch.png", files)
        self.assertIn("skin/movies/cointoss_heads.avi", files)
        self.assertTrue(all(row["description"] for row in rows))

    def test_the_table_needs_no_art_and_says_where_each_file_comes_from(self):
        with tempfile.TemporaryDirectory() as tmp:
            rows = {row["file"]: row for row in cat.table_rows(Path(tmp))}
        back = rows["skin/card_back.png"]
        self.assertEqual(back["format"], "", "nothing measured off no skin")
        self.assertEqual(back["read_by_game"], "yes")
        self.assertIn("CardBack.pic", back["manalink_backup"])
        self.assertIn("not used", rows["skin/attack_sword.png"]["manalink_backup"])
        self.assertTrue(rows["skin/set_icon_atq.png"]["read_by_game"].startswith("no"))
        self.assertEqual(rows["skin/filter_icons_hover.png"]["from_the_1997_game"],
                         "ours, drawn from filter_icons.png")
        self.assertIn("27 cells", rows["skin/filter_icons.png"]["from_the_1997_game"])

    def test_the_counter_strip_is_catalogued_with_its_mask_cell(self):
        """A skin maker who draws their own stones has to be told that
        the 25th cell is the MASK the other 24 wear — it is the one sheet
        here that is not an image+mask PAIR, and nothing about the file
        says so (2026-09-09)."""
        self.assertIn("card_counters.png", cat.expected_files())
        section, note = cat.note_for("card_counters")
        self.assertEqual(section, "Marks on a card")
        self.assertIn("25 cells", note)
        self.assertIn("mask", note)
        text = (ROOT / "docs" / "skin-catalogue.txt").read_text(encoding="utf-8")
        self.assertIn("card_counters.png", text)

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

    def test_a_tar_gz_is_read_as_the_zip_it_becomes(self):
        path = self.dir / "ok.tar.gz"
        with tarfile.open(path, "w:gz") as tf:
            for entry, body in {"./skin/card_back.png": png_bytes(2, 2),
                                "skin/portraits/x.png": png_bytes(2, 2)}.items():
                info = tarfile.TarInfo(entry)
                info.size = len(body)
                tf.addfile(info, io.BytesIO(body))
            folder = tarfile.TarInfo("skin/")
            folder.type = tarfile.DIRTYPE
            tf.addfile(folder)
        self.assertEqual(cat.names_in(path), ["card_back.png", "portraits/x.png"])
        loose = self.dir / "loose.tar"
        with tarfile.open(loose, "w") as tf:
            info = tarfile.TarInfo("readme.txt")
            info.size = 1
            tf.addfile(info, io.BytesIO(b"x"))
        with redirect_stdout(io.StringIO()):
            self.assertIsNone(cat.names_in(loose))
        self.assertIsNone(cat.names_in(self.dir / "not_there.tar.gz"))

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
        self.assertIn("card art, 1 picture\n", report)
        self.assertIn("notes.txt", report, "a non-picture is called out, not counted")
        self.assertNotIn("title_background.png", report,
                         "card art is not held to the skin's list")

    def test_check_wears_what_the_catalogue_says_and_names_what_it_cannot(self):
        catalogue = "\n".join([
            "# a note, and a blank line",
            "",
            "card_back.png = 2x/card_back.png",           # worn from another name
            "card_frame_red.png = gone/card_frame_red.png",  # not in the skin
            "title_background.png = ../outside.png",        # out of skin/: ignored
            "no_such_place.png = card_back.png",            # nothing looks for it
            "portraits/x.png = faces/x.png",                # a portrait: a place
        ])
        path = self._zip("mixed.zip", {
            "skin/catalogue.txt": catalogue.encode(),
            "skin/UPSCALE.txt": b"note",
            "skin/2x/card_back.png": png_bytes(456, 646),
            "skin/card_back.png": png_bytes(228, 323),
            "skin/faces/x.png": png_bytes(4, 4),
            "skin/mana_symbols.png": png_bytes(342, 18),
            "skin/button_normal.png": png_bytes(140, 40)})
        out = io.StringIO()
        with redirect_stdout(out):
            self.assertEqual(cat.check(path), 0)
        text = out.getvalue()
        self.assertIn("catalogue.txt: 4 places, 2 worn from a file of another name", text)
        self.assertIn("ignores", text)
        self.assertIn("    title_background.png = ../outside.png\n", text)
        self.assertIn("    card_frame_red.png = gone/card_frame_red.png\n", text)
        self.assertIn("never looks for", text)
        self.assertIn("    no_such_place.png\n", text)
        # Present: card_back (by the catalogue), mana_symbols, button_normal.
        self.assertIn("3 of %d named files present" % len(cat.expected_files()), text)
        # The 2x card back, the 1x mana sheet, and a button of no multiple.
        self.assertIn("pictures by size: 1 at 1x, 1 at 2x", text)
        self.assertIn("button_normal.png", text.split("another size")[1])
        self.assertIn("140 x 40 (1997: 131 x 36)", text)
        tail = text.split("ignored by the game")[-1] if "not in the catalogue" in text else ""
        for name in ("catalogue.txt", "UPSCALE.txt", "2x/card_back.png"):
            self.assertNotIn(name, tail, "%s is no stray file" % name)

    def _report(self, path: Path) -> str:
        out = io.StringIO()
        with redirect_stdout(out):
            self.assertEqual(cat.check(path), 0)
        return out.getvalue()

    def test_an_at_2x_picture_beside_its_place_is_worn_there(self):
        # The 0.50.28 names, kept (the owner: *"keep the previous skin
        # filenames also valid"*): no catalogue, <name>@2x.png beside.
        text = self._report(self._zip("beside.zip", {
            "skin/card_back.png": png_bytes(228, 323),
            "skin/card_back@2x.png": png_bytes(456, 646),
            "skin/mana_symbols@2x.png": png_bytes(684, 36),
            "skin/portraits/x.png": png_bytes(4, 4),
            "skin/portraits/x@2x.png": png_bytes(8, 8),
            "skin/nothing@2x.png": png_bytes(8, 8)}))
        self.assertIn("2 of %d named files present, 1 portraits," % len(cat.expected_files()),
                      text, "a copy is its place's picture, never a portrait of its own")
        self.assertIn("pictures by size: 2 at 2x", text)
        unknown = text.split("not in the catalogue")[-1]
        self.assertNotIn("card_back@2x.png", unknown)
        self.assertNotIn("mana_symbols@2x.png", unknown)
        self.assertIn("nothing@2x.png", unknown, "a copy of no place is still a stray")
        self.assertNotIn("pictures only", text)

    def test_a_line_naming_the_place_itself_wears_the_1x_over_the_at_2x(self):
        files = {"skin/card_back.png": png_bytes(228, 323),
                 "skin/card_back@2x.png": png_bytes(456, 646)}
        self.assertIn("1 at 2x", self._report(self._zip("a.zip", files)))
        files["skin/catalogue.txt"] = b"card_back.png = card_back.png\n"
        self.assertIn("pictures by size: 1 at 1x —", self._report(self._zip("b.zip", files)))
        self.assertEqual(cat.worn_file("card_back.png", {}, set(n[5:] for n in files)),
                         "card_back@2x.png")
        sound_copy = "sfx_tap" + cat.SCALED_SUFFIX + ".wav"
        self.assertEqual(cat.worn_file("sfx_tap.wav", {}, {sound_copy}), None,
                         "the @2x name is a picture's alone")

    def test_the_0_50_28_zip_is_pictures_only_and_says_how_to_make_a_skin(self):
        text = self._report(self._zip("original_skin_realesrgan-anime_2x.zip", {
            "skin/card_back@2x.png": png_bytes(456, 646),
            "skin/portraits/x@2x.png": png_bytes(8, 8),
            "skin/UPSCALE.txt": b"note"}))
        self.assertIn("pictures only", text)
        self.assertIn("upscale_skin.py --skin original_skin.zip --reuse "
                      "original_skin_realesrgan-anime_2x.zip", text)
        self.assertIn(", 0 portraits,", text)

    def test_a_keyed_picture_above_1x_wants_its_1x_file_beside_it(self):
        """The owner, 2026-10-17: *"that is important, tell the player"* —
        a keyed picture worn at 2x without the 1997 file of its own name is
        cut less exactly; with it, exactly. A picture nothing keys is
        never named."""
        rough = self._report(self._zip("rough.zip", {
            "skin/mana_stripes@2x.png": png_bytes(108, 252),
            "skin/duel_mana_red.png": png_bytes(1442, 762),      # 2x, own name
            "skin/card_back@2x.png": png_bytes(456, 646)}))      # not keyed
        listed = rough.split("cut less")[1] if "cut less" in rough else ""
        self.assertIn("    mana_stripes.png ", listed)
        self.assertIn("MiniCard.stripe_texture", listed)
        self.assertIn("duel_mana_red.png", listed)
        self.assertIn("TerritoryGround._inner", listed)
        self.assertNotIn("card_back", listed)
        exact = self._report(self._zip("exact.zip", {
            "skin/mana_stripes.png": png_bytes(54, 126),
            "skin/mana_stripes@2x.png": png_bytes(108, 252)}))
        self.assertNotIn("cut less", exact)

    def test_the_keyed_places_are_named_with_their_cutters(self):
        self.assertIn("SetBadges", cat.keyed_by("card_set_symbols.png"))
        self.assertIn("masked_sprite", cat.keyed_by("attack_bones.png"))
        self.assertIn("TerritoryGround", cat.keyed_by("duel_picture_green.png"))
        self.assertIn("ExilePlate", cat.keyed_by("grave_panel_blue.png"))
        self.assertIsNone(cat.keyed_by("card_back.png"))
        self.assertIsNone(cat.keyed_by("duel_mana.png"), "a family is a prefix of a name")
        sizes = cat.sizes_1997()
        for name, _ in cat.KEYED:
            if name.endswith("_"):
                self.assertTrue(any(place.startswith(name) for place in sizes), name)
            else:
                self.assertIn(name + ".png", sizes, "a keyed place the game draws")

    def test_a_catalogue_in_a_folder_and_in_a_tar_is_read_the_same(self):
        files = {"catalogue.txt": b"card_back.png = big/back.png\n",
                 "big/back.png": png_bytes(684, 969)}
        folder = self.dir / "skin"
        for name, body in files.items():
            (folder / name).parent.mkdir(parents=True, exist_ok=True)
            (folder / name).write_bytes(body)
        tar = self.dir / "skin.tar.gz"
        with tarfile.open(tar, "w:gz") as tf:
            for name, body in files.items():
                info = tarfile.TarInfo("skin/" + name)
                info.size = len(body)
                tf.addfile(info, io.BytesIO(body))
        for target in (folder, tar):
            out = io.StringIO()
            with redirect_stdout(out):
                self.assertEqual(cat.check(target), 0)
            self.assertIn("1 at 3x", out.getvalue(), target)
            self.assertEqual(cat.read_files(target, {"big/back.png"}, 33)["big/back.png"],
                             png_bytes(684, 969)[:33])

    def test_check_refuses_what_is_not_a_skin(self):
        path = self.dir / "page.zip"
        path.write_bytes(b"<html>")
        with redirect_stdout(io.StringIO()):
            self.assertEqual(cat.check(path), 1)


class TestTheSkinsOwnCatalogue(unittest.TestCase):
    """skin/catalogue.txt, read the way game/skin.gd reads it (the owner,
    2026-10-17: *"every image is assigned to a specific location game
    looks for"*), and the 1997 sizes a picture is measured against."""

    def test_a_line_is_a_place_and_the_file_worn_there(self):
        self.assertEqual(cat.read_catalogue(
            "title_background.png = 2x/title_background.png\n"
            "  portraits/agnosia.png=faces/a b.png  \n"
            "sfx_tap.wav = sounds/tap.wav\r\n"),
            {"title_background.png": "2x/title_background.png",
             "portraits/agnosia.png": "faces/a b.png",
             "sfx_tap.wav": "sounds/tap.wav"})

    def test_notes_and_blank_lines_are_nothing(self):
        self.assertEqual(cat.parse_catalogue("# card_back.png = x.png\n\n   \n"
                                             "   # indented note = y\n"), ({}, []))

    def test_the_first_equals_splits_and_the_last_line_wins(self):
        self.assertEqual(cat.read_catalogue("card_back.png = a=b.png\n"
                                            "card_back.png = c.png\n"
                                            "mana_symbols.png = 1.png\n"),
                         {"card_back.png": "c.png", "mana_symbols.png": "1.png"})

    def test_a_line_the_game_cannot_take_is_ignored_and_said(self):
        lines = ["no equals here", "= nameless.png", "card_back.png =",
                 "card_back.png = /etc/passwd", "card_back.png = ..\\up.png",
                 "card_back.png = ../up.png", "card_back.png = a/../../up.png",
                 "card_back.png = 2x\\card_back.png"]
        places, ignored = cat.parse_catalogue("\n".join(lines + ["card_back.png = ok..png"]))
        self.assertEqual(places, {"card_back.png": "ok..png"},
                         "dots in a name are a name; '..' as a part is a climb")
        self.assertEqual(ignored, lines)

    def test_the_1997_sizes_are_the_tables_pictures(self):
        sizes = cat.sizes_1997()
        self.assertEqual(sizes["title_background.png"], (640, 480))
        self.assertEqual(sizes["mana_symbols.png"], (342, 18))
        self.assertNotIn("coin_toss_heads.png", sizes, "a movie sheet has no place size")
        self.assertFalse(any(name.startswith("portraits/") for name in sizes))
        self.assertEqual(cat.sizes_1997((ROOT / "no_such.csv",)), {})

    def test_whole_multiples_up_to_four_are_scales(self):
        self.assertEqual(cat.scale_of(640, 480, (640, 480)), 1)
        self.assertEqual(cat.scale_of(1280, 960, (640, 480)), 2)
        self.assertEqual(cat.scale_of(2560, 1920, (640, 480)), 4)
        self.assertIsNone(cat.scale_of(3200, 2400, (640, 480)), "5x is past the top")
        self.assertIsNone(cat.scale_of(1280, 480, (640, 480)), "both ways or not at all")
        self.assertIsNone(cat.scale_of(800, 600, (640, 480)))

    def test_the_game_knows_the_same_sizes(self):
        """game/skin.gd's SIZES — what the game lays a picture out at, and
        measures its scale against — is this catalogue's table, place for
        place (coin-toss sheets and portraits have no place size)."""
        source = (ROOT / "game" / "skin.gd").read_text(encoding="utf-8")
        block = re.search(r"^const SIZES := \{\n(.*?)^\}", source, re.M | re.S)
        self.assertIsNotNone(block, "game/skin.gd has no `const SIZES := {` block")
        game = {}
        for line in block.group(1).splitlines():
            found = re.fullmatch(r'\t"([a-z0-9_]+)": Vector2i\((\d+), (\d+)\),', line)
            self.assertIsNotNone(found, "one entry a line: %r" % line)
            game[found.group(1) + ".png"] = (int(found.group(2)), int(found.group(3)))
        self.assertEqual(game, cat.sizes_1997((ROOT / "docs" / "skin-catalogue.csv",)))


class TestCheckRefusesWhatTheGameRefuses(unittest.TestCase):
    """`--check` SAYS NO WHERE THE GAME SAYS NO, AND EXITS 1 (bug pass
    2026-10-03).

    It approved — "skin, 0 files", exit 0 — an empty zip, a zip of
    folders alone, a zip with a backslash in a name and a `.tar.xz` or
    `.tar.bz2`, every one of which the game refuses at the door:
    `SkinPack.inspect` wants at least one file, all under `skin/`, none
    with `..` or `\\`; `TarPack.is_tar` knows a tar by a gzip header or
    `ustar` at byte 257 and nothing else, and a file NAMED as a tar whose
    bytes are none is refused before it is read as a zip
    (`SkinPack._take`/`adopt`, NOT_A_TAR).
    """

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

    def _tar(self, name: str, mode: str, entries: dict[str, bytes]) -> Path:
        path = self.dir / name
        with tarfile.open(path, mode) as tf:
            for entry, body in entries.items():
                info = tarfile.TarInfo(entry)
                info.size = len(body)
                tf.addfile(info, io.BytesIO(body))
        return path

    def _check(self, path: Path) -> tuple[int, str]:
        out = io.StringIO()
        with redirect_stdout(out):
            code = cat.check(path)
        return code, out.getvalue()

    def assertRefused(self, path: Path, why: str) -> None:
        code, report = self._check(path)
        self.assertEqual(code, 1, report)
        self.assertIn(why, report)

    def test_an_empty_zip_is_refused(self):
        self.assertRefused(self._zip("empty.zip", {}), "no skin/ folder inside")

    def test_a_zip_of_folders_alone_is_refused(self):
        self.assertRefused(self._zip("dirs.zip", {"skin/": b"", "skin/portraits/": b""}),
                           "no skin/ folder inside")

    def test_a_backslash_in_a_zip_name_refuses_the_zip(self):
        self.assertRefused(self._zip("bs.zip", {"skin/portraits\\face.png": b"x",
                                                "skin/title_background.png": b"x"}),
                           "an entry outside skin/")

    def test_a_tar_xz_and_a_tar_bz2_are_not_tars_the_game_reads(self):
        entries = {"skin/card_back.png": png_bytes(2, 2)}
        for name, mode in (("skin.tar.xz", "w:xz"), ("skin.tar.bz2", "w:bz2")):
            with self.subTest(name):
                self.assertRefused(self._tar(name, mode, entries), "not a zip file")

    def test_a_zip_named_as_a_tar_is_refused(self):
        self.assertRefused(self._zip("skin.tar.gz", {"skin/card_back.png": b"x"}),
                           "is not a tar the game can read")

    def test_a_tar_with_no_files_is_refused(self):
        path = self.dir / "folders.tar.gz"
        with tarfile.open(path, "w:gz") as tf:
            folder = tarfile.TarInfo("skin/")
            folder.type = tarfile.DIRTYPE
            tf.addfile(folder)
        self.assertRefused(path, "holds no files")

    def test_a_tar_backslash_is_the_separator_it_was_meant_as(self):
        # TarPack._tidy turns them into slashes before the zip is made, so
        # the zip the game inspects has none.
        path = self._tar("bs.tar", "w", {"skin\\portraits\\face.png": png_bytes(2, 2)})
        self.assertEqual(cat.names_in(path), ["portraits/face.png"])

    def test_the_command_line_exits_non_zero_on_a_refusal(self):
        path = self._zip("empty.zip", {})
        env = dict(os.environ, SHANDALAR_NO_BANNER="1", PYTHONDONTWRITEBYTECODE="1")
        run = subprocess.run([sys.executable, str(ROOT / "tools" / "skin_catalogue.py"),
                              "--check", str(path)], capture_output=True, text=True,
                             env=env, stdin=subprocess.DEVNULL, timeout=60)
        self.assertEqual(run.returncode, 1, run.stdout + run.stderr)


if __name__ == "__main__":
    unittest.main()

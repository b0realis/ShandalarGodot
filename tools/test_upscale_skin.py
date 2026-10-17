#!/usr/bin/env python3
"""Self-test for tools/upscale_skin.py — the 2x skin. No network, no GPU.

A STAND-IN ENGINE (FAKE_ENGINE) does to a folder what realesrgan-ncnn-vulkan
does — every picture four times the size — and pushes the red up by 40
the way the anime model pushes colour, so everything AROUND the model is
proved here: what is upscaled and what is left alone, the padding and the
bleed, the colour fix bringing the 1997 colour back, the on/off
transparency, the complete skin it writes (every 1997 file as it was, the
`@2x` pictures beside them, the catalogue that wears them), reusing a 2x
zip already built, the zip, the Manalink label and the engine's checksum. Whether the model's pictures LOOK right
is the owner's eye on a real run, not a test.

Run from the repo root:
    python3 -m unittest discover -s tools -p 'test_*.py'
"""

import hashlib
import io
import os
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import import_manalink  # noqa: E402
import package_release  # noqa: E402
import skin_catalogue  # noqa: E402
import upscale_skin as up  # noqa: E402

try:
    from PIL import Image, ImageStat
except ImportError:
    Image = None

FAKE_ENGINE = """#!%s
import sys
from pathlib import Path
from PIL import Image
args = sys.argv[1:]
def arg(flag):
    return args[args.index(flag) + 1]
scale = int(arg("-s"))
seen = Path(sys.argv[0]).parent / "seen.txt"
for path in sorted(Path(arg("-i")).glob("*.png")):
    with open(seen, "a") as log:
        log.write(path.name + "\\n")
    picture = Image.open(path).convert("RGB")
    big = picture.resize((picture.width * scale, picture.height * scale), Image.NEAREST)
    red, green, blue = big.split()
    red = red.point(lambda v: min(255, v + 40))
    Image.merge("RGB", (red, green, blue)).save(Path(arg("-o")) / path.name)
"""

BROKEN_ENGINE = """#!/bin/sh
echo "vkCreateInstance failed -9" >&2
exit 255
"""


def solid(size, colour, mode="RGB"):
    return Image.new(mode, size, colour)


@unittest.skipIf(Image is None, "Pillow is not installed")
class PictureTest(unittest.TestCase):
    """The steps around the model, one at a time."""

    def test_what_is_upscaled_and_what_is_left_alone(self):
        with tempfile.TemporaryDirectory() as tmp:
            skin = Path(tmp)
            (skin / "portraits").mkdir()
            (skin / "cardart").mkdir()
            for name in ("title.png", "portraits/face.png", "coin_toss_heads.png",
                         "title@2x.png", "cardart/island.png"):
                solid((4, 4), (1, 2, 3)).save(skin / name)
            for name in ("sfx_draw.wav", "font_title.ttf", "coin_toss_heads.json",
                         "title.png.import"):
                (skin / name).write_bytes(b"x")
            self.assertEqual(up.pictures(skin), ["title", "portraits/face"])
            self.assertEqual(up.places(skin), ["coin_toss_heads", "title", "portraits/face"])

    def test_every_file_rides_along_but_card_pictures_and_old_copies(self):
        with tempfile.TemporaryDirectory() as tmp:
            skin = Path(tmp)
            for name in ("title.png", "title.png.import", "title@2x.png",
                         "portraits/face.png", "portraits/face@2x.png",
                         "cardart/island.jpg", "catalogue.txt",
                         "UPSCALE.txt", "sfx_draw.wav", "font_title.ttf",
                         "coin_toss_heads.json", "movies/cointoss_heads.avi",
                         import_manalink.LABEL):
                (skin / name).parent.mkdir(parents=True, exist_ok=True)
                (skin / name).write_bytes(b"x")
            self.assertEqual(up.skin_files(skin), [
                "coin_toss_heads.json", "font_title.ttf", import_manalink.LABEL,
                "movies/cointoss_heads.avi", "portraits/face.png", "sfx_draw.wav",
                "title.png"])

    def test_a_repeated_texture_is_padded_with_itself(self):
        tile = Image.new("RGB", (4, 3))
        for x in range(4):
            for y in range(3):
                tile.putpixel((x, y), (x * 60, y * 100, 7))
        out = up.pad(tile, 2, wrap=True)
        self.assertEqual(out.size, (8, 7))
        self.assertEqual(out.getpixel((0, 0)), tile.getpixel((2, 1)))
        self.assertEqual(out.getpixel((7, 6)), tile.getpixel((1, 1)))
        self.assertEqual(out.getpixel((2, 2)), tile.getpixel((0, 0)))

    def test_any_other_picture_is_padded_with_its_own_edge(self):
        picture = Image.new("RGB", (3, 2))
        for x in range(3):
            for y in range(2):
                picture.putpixel((x, y), (x * 80, y * 200, 9))
        out = up.pad(picture, 3, wrap=False)
        self.assertEqual(out.size, (9, 8))
        self.assertEqual(out.getpixel((0, 0)), picture.getpixel((0, 0)))
        self.assertEqual(out.getpixel((8, 7)), picture.getpixel((2, 1)))
        self.assertEqual(out.getpixel((4, 0)), picture.getpixel((1, 0)))
        self.assertEqual(out.getpixel((0, 4)), picture.getpixel((0, 1)))
        self.assertEqual(out.getpixel((4, 4)), picture.getpixel((1, 1)))

    def test_only_the_repeated_textures_get_a_wide_wrap(self):
        self.assertEqual(up.pad_size("title_background", (640, 480)), up.PAD)
        self.assertEqual(up.pad_size("deck_tile_olive", (32, 32)), 32)
        self.assertEqual(up.pad_size("message_panel", (600, 35)), 35)
        self.assertEqual(up.pad_size("attack_bones", (777, 70)), up.PAD_TILED_MAX)

    def test_a_cut_out_hides_its_neighbours_colour_not_black(self):
        # Opaque red on the left, transparent BLACK on the right: what the
        # model sees on the right must be red, or the edge comes out dark.
        picture = Image.new("RGBA", (40, 6), (0, 0, 0, 0))
        picture.paste((200, 30, 30, 255), (0, 0, 10, 6))
        filled = up.bleed(picture)
        self.assertEqual(filled.mode, "RGB")
        for x in (9, 10, 11, 25, 39):   # the edge, one step on, and far away
            self.assertEqual(filled.getpixel((x, 3)), (200, 30, 30), x)

    def test_an_opaque_picture_is_left_as_it_is(self):
        picture = solid((5, 5), (10, 20, 30, 255), "RGBA")
        self.assertEqual(up.bleed(picture).getpixel((2, 2)), (10, 20, 30))

    def test_the_colour_fix_brings_1997_back_and_keeps_the_edge(self):
        # The 1997 picture: two flat halves. The model: the same edge, the
        # red pushed up by 50 everywhere.
        original = Image.new("RGB", (40, 20), (100, 60, 60))
        original.paste((40, 60, 120), (20, 0, 40, 20))
        model = Image.new("RGB", (40, 20), (150, 60, 60))
        model.paste((90, 60, 120), (20, 0, 40, 20))
        fixed = up.colour_fix(model, original, 2.0)
        left = ImageStat.Stat(fixed.crop((2, 2, 14, 18))).mean
        right = ImageStat.Stat(fixed.crop((26, 2, 38, 18))).mean
        for got, want in zip(left + right, (100, 60, 60, 40, 60, 120)):
            self.assertAlmostEqual(got, want, delta=1.5)
        # The step between the halves is still the model's step, not a ramp.
        self.assertGreater(fixed.getpixel((19, 10))[0] - fixed.getpixel((20, 10))[0], 40)

    def test_transparency_stays_on_or_off_at_twice_the_size(self):
        alpha = Image.new("L", (10, 10), 0)
        alpha.paste(255, (2, 2, 8, 8))
        big = up.alpha_up(alpha)
        self.assertEqual(big.size, (20, 20))
        self.assertEqual(set(big.getdata()) - {0, 255}, set())
        self.assertEqual(big.getpixel((10, 10)), 255)
        self.assertEqual(big.getpixel((1, 1)), 0)

    def test_names(self):
        self.assertEqual(up.upscaled_name("title_background"), "title_background@2x.png")
        self.assertEqual(up.upscaled_name("portraits/agnosia"), "portraits/agnosia@2x.png")
        self.assertEqual(up.ZIP_NAME, "original_skin_realesrgan-anime_2x.zip")
        self.assertEqual(up.CATALOGUE, "catalogue.txt")

    def test_the_catalogue_wears_the_2x_pictures_and_names_the_rest(self):
        text = up.catalogue(["title", "coin_toss_heads", "portraits/face"],
                            ["title", "portraits/face"])
        self.assertTrue(text.startswith("# THE CATALOGUE"))
        self.assertIn("#     duelist_face_red.png = duelist_face_red.png\n", text)
        self.assertIn("Deleting the line is not the same", text)
        entries = [line for line in text.splitlines()
                   if line and not line.startswith("#")]
        self.assertEqual(entries, ["coin_toss_heads.png = coin_toss_heads.png",
                                   "portraits/face.png = portraits/face@2x.png",
                                   "title.png = title@2x.png"])
        # The game's own reading of it (skin_catalogue.read_catalogue
        # follows game/skin.gd): every place, the comments nothing.
        self.assertEqual(skin_catalogue.read_catalogue(text), {
            "coin_toss_heads.png": "coin_toss_heads.png",
            "portraits/face.png": "portraits/face@2x.png",
            "title.png": "title@2x.png"})


@unittest.skipIf(Image is None, "Pillow is not installed")
class RunTest(unittest.TestCase):
    """A whole run, with the stand-in engine."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.tmp = Path(self.temp.name)
        self.engine = self.tmp / "engine" / up.ENGINE_EXE
        self.engine.parent.mkdir()
        self.engine.write_text(FAKE_ENGINE % sys.executable)
        self.engine.chmod(0o755)
        self.skin = self.tmp / "skin"
        (self.skin / "portraits").mkdir(parents=True)
        # An opaque painting, a cut-out over hidden black, a portrait with
        # the same, a repeated tile, and what is never upscaled.
        Image.new("RGB", (30, 20), (90, 70, 50)).save(self.skin / "title_background.png")
        cut = Image.new("RGBA", (16, 12), (0, 0, 0, 0))
        cut.paste((180, 160, 40, 255), (4, 2, 12, 10))
        cut.save(self.skin / "target_cursor.png")
        cut.save(self.skin / "portraits" / "agnosia.png")
        Image.new("RGBA", (8, 8), (60, 80, 60, 255)).save(self.skin / "deck_tile_olive.png")
        Image.new("RGB", (8, 8), (1, 1, 1)).save(self.skin / "coin_toss_heads.png")
        (self.skin / "coin_toss_heads.json").write_text('{"cols": 1}')
        (self.skin / "sfx_draw.wav").write_bytes(b"RIFF")
        (self.skin / "font_title.ttf").write_bytes(b"\x00\x01\x00\x00")
        # What a dev checkout's folder holds and a 2x skin does not.
        (self.skin / "title_background.png.import").write_text("[remap]")
        (self.skin / "cardart").mkdir()
        Image.new("RGB", (4, 4)).save(self.skin / "cardart" / "island.png")

    def run_tool(self, skin=None, zip_out=None, folder_out=None, reuse=None):
        with open(os.devnull, "w") as quiet:
            stdout = sys.stdout
            sys.stdout = quiet
            try:
                return up.upscale(skin or self.skin, zip_out, folder_out, self.engine, None,
                                  reuse)
            finally:
                sys.stdout = stdout

    def test_the_zip_is_the_whole_skin_with_every_picture_at_twice_the_size(self):
        out = self.tmp / up.ZIP_NAME
        self.assertEqual(self.run_tool(zip_out=out), 0)
        with zipfile.ZipFile(out) as archive:
            names = sorted(archive.namelist())
            self.assertEqual(names, ["skin/" + up.PROVENANCE,
                                     "skin/catalogue.txt",
                                     "skin/coin_toss_heads.json",
                                     "skin/coin_toss_heads.png",
                                     "skin/deck_tile_olive.png",
                                     "skin/deck_tile_olive@2x.png",
                                     "skin/font_title.ttf",
                                     "skin/portraits/agnosia.png",
                                     "skin/portraits/agnosia@2x.png",
                                     "skin/sfx_draw.wav",
                                     "skin/target_cursor.png",
                                     "skin/target_cursor@2x.png",
                                     "skin/title_background.png",
                                     "skin/title_background@2x.png"])
            pictures = {n: Image.open(io.BytesIO(archive.read(n))) for n in names
                        if n.endswith(".png")}
            note = archive.read("skin/" + up.PROVENANCE).decode()
            places = skin_catalogue.read_catalogue(archive.read("skin/catalogue.txt").decode())
            # The 1997 files are the 1997 files, byte for byte.
            for name in ("sfx_draw.wav", "font_title.ttf", "coin_toss_heads.json",
                         "coin_toss_heads.png", "title_background.png"):
                self.assertEqual(archive.read("skin/" + name),
                                 (self.skin / name).read_bytes(), name)
        self.assertEqual(pictures["skin/title_background@2x.png"].size, (60, 40))
        self.assertEqual(pictures["skin/title_background@2x.png"].mode, "RGB")
        self.assertEqual(pictures["skin/target_cursor@2x.png"].size, (32, 24))
        self.assertEqual(pictures["skin/target_cursor@2x.png"].mode, "RGBA")
        self.assertEqual(pictures["skin/portraits/agnosia@2x.png"].size, (32, 24))
        self.assertEqual(places, {
            "coin_toss_heads.png": "coin_toss_heads.png",
            "deck_tile_olive.png": "deck_tile_olive@2x.png",
            "portraits/agnosia.png": "portraits/agnosia@2x.png",
            "target_cursor.png": "target_cursor@2x.png",
            "title_background.png": "title_background@2x.png"})
        self.assertIn(up.MODEL, note)
        self.assertIn("catalogue.txt", note)
        package_release.check_skin(out)  # the shape a release accepts

    def test_the_skin_checker_reads_it_as_a_complete_skin_at_2x(self):
        out = self.tmp / up.ZIP_NAME
        self.run_tool(zip_out=out)
        report = io.StringIO()
        stdout, sys.stdout = sys.stdout, report
        try:
            self.assertEqual(skin_catalogue.check(out), 0)
        finally:
            sys.stdout = stdout
        text = report.getvalue()
        self.assertIn("catalogue.txt: 5 places", text)
        self.assertNotIn("naming a file that is not here", text,
                         "every line names a file in the skin")
        # The 2x pictures, the catalogue and the note are not files the
        # game ignores. (The stand-in pictures are not the 1997 sizes, so
        # the size report has things to say; that is skin_catalogue's test.)
        self.assertNotIn("ignored by the game", text)
        self.assertNotIn(up.PROVENANCE, text)

    def test_the_pushed_colour_comes_back(self):
        out = self.tmp / up.ZIP_NAME
        self.run_tool(zip_out=out)
        with zipfile.ZipFile(out) as archive:
            painting = Image.open(io.BytesIO(archive.read("skin/title_background@2x.png")))
            tile = Image.open(io.BytesIO(archive.read("skin/deck_tile_olive@2x.png")))
        for got, want in zip(ImageStat.Stat(painting).mean, (90, 70, 50)):
            self.assertAlmostEqual(got, want, delta=1.0)
        for got, want in zip(ImageStat.Stat(tile).mean[:3], (60, 80, 60)):
            self.assertAlmostEqual(got, want, delta=1.0)

    def test_a_cut_out_stays_on_off_and_its_hidden_pixels_black(self):
        out = self.tmp / up.ZIP_NAME
        self.run_tool(zip_out=out)
        with zipfile.ZipFile(out) as archive:
            cursor = Image.open(io.BytesIO(archive.read("skin/target_cursor@2x.png")))
        alpha = cursor.getchannel("A")
        self.assertEqual(set(alpha.getdata()) - {0, 255}, set())
        self.assertEqual(cursor.getpixel((0, 0)), (0, 0, 0, 0))
        self.assertEqual(cursor.getpixel((16, 12))[3], 255)
        # No dark fringe: the opaque pixels right at the edge keep the
        # colour, because the model never saw the hidden black.
        edge = cursor.getpixel((8, 12))
        self.assertEqual(edge[3], 255)
        self.assertGreater(edge[0], 150)

    def test_a_skin_zip_works_like_a_folder(self):
        # Its sounds, fonts and sheet layouts are carried too, not just its
        # pictures (0.50.28's zip of copies read the pictures alone).
        packed = self.tmp / "original_skin.zip"
        with zipfile.ZipFile(packed, "w") as archive:
            for path in sorted(self.skin.rglob("*")):
                if path.is_file() and not path.name.endswith(".import"):
                    archive.write(path, "skin/" + path.relative_to(self.skin).as_posix())
        from_folder, from_zip = self.tmp / "a.zip", self.tmp / "b.zip"
        self.run_tool(zip_out=from_folder)
        self.run_tool(skin=packed, zip_out=from_zip)
        self.assertEqual(from_folder.read_bytes(), from_zip.read_bytes())

    def test_the_same_skin_makes_the_same_bytes(self):
        first, second = self.tmp / "1.zip", self.tmp / "2.zip"
        self.run_tool(zip_out=first)
        self.run_tool(zip_out=second)
        self.assertEqual(first.read_bytes(), second.read_bytes())

    def test_out_writes_the_whole_skin_into_a_folder(self):
        out = self.tmp / "skin2x"
        self.assertEqual(self.run_tool(folder_out=out), 0)
        written = sorted(p.relative_to(out).as_posix() for p in out.rglob("*") if p.is_file())
        zipped = self.tmp / up.ZIP_NAME
        self.run_tool(zip_out=zipped)
        with zipfile.ZipFile(zipped) as archive:
            self.assertEqual(written, sorted(n[len("skin/"):] for n in archive.namelist()),
                             "the folder holds what the zip's skin/ holds")
            self.assertEqual((out / "title_background@2x.png").read_bytes(),
                             archive.read("skin/title_background@2x.png"))

    def test_out_the_skin_folder_itself_adds_the_2x_skin_in_place(self):
        before = {p: p.read_bytes() for p in self.skin.rglob("*") if p.is_file()}
        self.assertEqual(self.run_tool(folder_out=self.skin), 0)
        self.assertTrue((self.skin / "title_background@2x.png").is_file())
        self.assertTrue((self.skin / "portraits" / "agnosia@2x.png").is_file())
        self.assertTrue((self.skin / up.CATALOGUE).is_file())
        self.assertTrue((self.skin / up.PROVENANCE).is_file())
        for path, data in before.items():
            self.assertEqual(path.read_bytes(), data, "%s is left as it was" % path)
        # A second run over the same folder upscales the 1997 pictures
        # again, not the @2x ones beside them, and writes the same catalogue.
        self.assertEqual(up.pictures(self.skin), ["deck_tile_olive", "target_cursor",
                                                  "title_background", "portraits/agnosia"])
        first = (self.skin / up.CATALOGUE).read_bytes()
        self.assertEqual(self.run_tool(folder_out=self.skin), 0)
        self.assertEqual((self.skin / up.CATALOGUE).read_bytes(), first)
        self.assertEqual([p.name for p in self.tmp.iterdir() if p.name.startswith(".upscale")],
                         [], "the work folder is cleared")

    def test_a_2x_skin_made_again_is_made_afresh(self):
        # The 2x skin as the source: its @2x pictures, catalogue and note
        # are written new, never carried over from it.
        first = self.tmp / "first"
        self.run_tool(folder_out=first)
        again = self.tmp / "again.zip"
        self.assertEqual(self.run_tool(skin=first, zip_out=again), 0)
        straight = self.tmp / "straight.zip"
        self.run_tool(zip_out=straight)
        self.assertEqual(again.read_bytes(), straight.read_bytes())

    # ------------------------------------------------------ --reuse --
    # The owner, 2026-10-17: *"I already have built 2x skin so we will
    # reuse it"* — the 0.50.28 zip, `<key>@2x.png` and its note alone.

    def old_2x_zip(self, sizes: dict[str, tuple[int, int]]) -> Path:
        """A zip shaped like 0.50.28's: one `@2x` picture per key, flat
        colours the engine would never make, so a reused one is known."""
        path = self.tmp / "old_2x.zip"
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr("skin/UPSCALE.txt", "copies")
            for key, size in sizes.items():
                data = io.BytesIO()
                Image.new("RGBA", size, (7, 77, 177, 255)).save(data, "PNG")
                archive.writestr("skin/%s@2x.png" % key, data.getvalue())
        return path

    def seen(self) -> list[str]:
        log = self.engine.parent / "seen.txt"
        return log.read_text().split() if log.exists() else []

    def test_reuse_with_every_copy_never_runs_the_engine(self):
        old = self.old_2x_zip({"title_background": (60, 40), "target_cursor": (32, 24),
                               "deck_tile_olive": (16, 16), "portraits/agnosia": (32, 24)})
        self.engine.write_text(BROKEN_ENGINE)   # it would fail if it were run
        out = self.tmp / up.ZIP_NAME
        self.assertEqual(self.run_tool(zip_out=out, reuse=old), 0)
        self.assertEqual(self.seen(), [], "the engine never saw a picture")
        with zipfile.ZipFile(out) as archive, zipfile.ZipFile(old) as before:
            for key in ("title_background", "target_cursor", "portraits/agnosia"):
                name = "skin/%s@2x.png" % key
                self.assertEqual(archive.read(name), before.read(name), "%s taken as it was" % key)
            note = archive.read("skin/" + up.PROVENANCE).decode()
            self.assertIn("sfx_draw.wav", " ".join(archive.namelist()), "a whole skin")
        self.assertIn("4 of them taken as they were from\n           old_2x.zip", note)
        package_release.check_skin(out)

    def test_reuse_upscales_only_what_the_old_zip_lacks_or_has_wrong(self):
        # The cursor's copy is missing; the tile's is not twice its size.
        old = self.old_2x_zip({"title_background": (60, 40), "deck_tile_olive": (17, 16),
                               "portraits/agnosia": (32, 24)})
        out = self.tmp / up.ZIP_NAME
        self.assertEqual(self.run_tool(zip_out=out, reuse=old), 0)
        self.assertEqual(sorted(self.seen()), ["deck_tile_olive.png", "target_cursor.png"])
        with zipfile.ZipFile(out) as archive:
            tile = Image.open(io.BytesIO(archive.read("skin/deck_tile_olive@2x.png")))
            painting = Image.open(io.BytesIO(archive.read("skin/title_background@2x.png")))
            note = archive.read("skin/" + up.PROVENANCE).decode()
        self.assertEqual(tile.size, (16, 16), "the wrong-size copy is made again")
        self.assertEqual(painting.getpixel((0, 0))[:3], (7, 77, 177), "the good copy is kept")
        self.assertIn("2 of them taken as they were", note)

    def test_reuse_from_a_folder_and_from_the_skin_folder_itself(self):
        # 0.50.28's --out put the copies beside the 1997 pictures: that
        # folder is its own reuse, and the copies stay where they are.
        self.run_tool(folder_out=self.skin)
        first = {p.name: p.read_bytes() for p in self.skin.glob("*@2x.png")}
        log = self.engine.parent / "seen.txt"
        log.unlink()
        self.assertEqual(self.run_tool(folder_out=self.skin, reuse=self.skin), 0)
        self.assertEqual(self.seen(), [], "nothing to upscale again")
        self.assertEqual({p.name: p.read_bytes() for p in self.skin.glob("*@2x.png")}, first)

    def test_reuse_on_the_command_line(self):
        missing = subprocess.run([sys.executable, str(Path(up.__file__)), "--skin",
                                  str(self.skin), "--reuse", "/nonexistent/2x.zip",
                                  "--zip", str(self.tmp / "out.zip")],
                                 capture_output=True, text=True, timeout=60,
                                 stdin=subprocess.DEVNULL)
        self.assertEqual(missing.returncode, 2)
        self.assertIn("/nonexistent/2x.zip", missing.stderr)

    def test_a_manalink_label_rides_along_and_a_release_refuses_it(self):
        (self.skin / import_manalink.LABEL).write_text("title_background\n")
        out = self.tmp / up.ZIP_NAME
        self.run_tool(zip_out=out)
        with zipfile.ZipFile(out) as archive:
            self.assertIn("skin/" + import_manalink.LABEL, archive.namelist())
            self.assertNotIn(import_manalink.LABEL,
                             archive.read("skin/catalogue.txt").decode().split("=")[-1])
        with self.assertRaises(ValueError):
            package_release.check_skin(out)

    def test_an_engine_that_fails_says_so(self):
        self.engine.write_text(BROKEN_ENGINE)
        with self.assertRaises(RuntimeError) as caught:
            self.run_tool(zip_out=self.tmp / up.ZIP_NAME)
        self.assertIn("Vulkan", str(caught.exception))
        self.assertIn("vkCreateInstance", str(caught.exception))
        self.assertFalse((self.tmp / up.ZIP_NAME).exists())


class EngineFetchTest(unittest.TestCase):
    """The engine is a program from the internet: it is taken only when
    its checksum is the one written in the tool, and only what the run
    needs is unpacked."""

    def release(self, folder: Path) -> Path:
        path = folder / "release.zip"
        with zipfile.ZipFile(path, "w") as archive:
            for member in up.ENGINE_MEMBERS:
                archive.writestr(member, b"engine part " + member.encode())
            archive.writestr("onepiece_demo.mp4", b"not wanted")
        return path

    def test_the_right_checksum_unpacks_the_engine_and_nothing_else(self):
        with tempfile.TemporaryDirectory() as tmp:
            release = self.release(Path(tmp))
            digest = hashlib.sha256(release.read_bytes()).hexdigest()
            cache = Path(tmp) / "cache"
            with open(os.devnull, "w") as quiet:
                stdout, sys.stdout = sys.stdout, quiet
                try:
                    exe = up.fetch_engine(cache, release.as_uri(), digest)
                finally:
                    sys.stdout = stdout
            self.assertEqual(exe, cache / up.ENGINE_EXE)
            self.assertTrue(os.access(exe, os.X_OK))
            self.assertEqual(sorted(p.relative_to(cache).as_posix()
                                    for p in cache.rglob("*") if p.is_file()),
                             sorted(up.ENGINE_MEMBERS))

    def test_a_wrong_checksum_unpacks_nothing(self):
        with tempfile.TemporaryDirectory() as tmp:
            release = self.release(Path(tmp))
            cache = Path(tmp) / "cache"
            with open(os.devnull, "w") as quiet:
                stdout, sys.stdout = sys.stdout, quiet
                try:
                    with self.assertRaises(RuntimeError):
                        up.fetch_engine(cache, release.as_uri(), "0" * 64)
                finally:
                    sys.stdout = stdout
            self.assertEqual(list(cache.iterdir()), [])

    def test_a_fetched_engine_is_not_fetched_again(self):
        with tempfile.TemporaryDirectory() as tmp:
            cache = Path(tmp)
            for member in up.ENGINE_MEMBERS:
                (cache / member).parent.mkdir(parents=True, exist_ok=True)
                (cache / member).write_bytes(b"x")
            # An unreachable URL proves no download was tried.
            self.assertEqual(up.fetch_engine(cache, "http://0.0.0.0:9/none", "0" * 64),
                             cache / up.ENGINE_EXE)

    def test_the_pinned_release_is_the_one_the_owner_chose(self):
        self.assertIn("v0.2.5.0", up.ENGINE_URL)
        self.assertTrue(up.ENGINE_URL.endswith("-ubuntu.zip"))
        self.assertRegex(up.ENGINE_SHA256, r"^[0-9a-f]{64}$")
        self.assertEqual(up.MODEL, "realesrgan-x4plus-anime")
        self.assertEqual(up.COLOUR_BLUR, 1.0)


class CommandLineTest(unittest.TestCase):

    def test_a_missing_skin_is_named(self):
        done = subprocess.run([sys.executable, str(Path(up.__file__)), "--skin",
                               "/nonexistent/skin", "--zip", "/nonexistent/out.zip"],
                              capture_output=True, text=True, timeout=60,
                              stdin=subprocess.DEVNULL)
        self.assertEqual(done.returncode, 2)
        if Image is not None:  # without Pillow the tool stops before the skin
            self.assertIn("/nonexistent/skin", done.stderr)


if __name__ == "__main__":
    unittest.main()

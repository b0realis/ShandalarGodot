#!/usr/bin/env python3
"""Self-test for tools/upscale_skin.py — the hi-res skin. No network, no GPU.

A STAND-IN ENGINE (FAKE_ENGINE) does to a folder what realesrgan-ncnn-vulkan
does — every picture four times the size — and pushes the red up by 40
the way the anime model pushes colour, so everything AROUND the model is
proved here: what is upscaled and what is left alone, the padding and the
bleed, the colour fix bringing the 1997 colour back, the on/off
transparency, the hi-res skin it writes (the same files as the 1997 skin,
under the same names, every picture at twice the size, how it was made
in the zip's comment), the key-exact places, reusing 2x copies already
made — and refusing a copy of another picture — the Manalink label and
the engine's checksum — and the castle and dungeon board's sheets cut
into their frames, each shown to the model amid what meets it on the
board (the stand-in keeps what it was shown when asked) and put back
where it stands. Whether the model's pictures LOOK right
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
from contextlib import redirect_stderr
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
kept = Path(sys.argv[0]).parent / "inputs"
for path in sorted(Path(arg("-i")).glob("*.png")):
    with open(seen, "a") as log:
        log.write(path.name + "\\n")
    if kept.is_dir():
        kept.joinpath(path.name).write_bytes(path.read_bytes())
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


def doubled(picture, tint=0):
    """[param picture] with every pixel doubled — a 2x copy of it — its
    blue moved by [param tint], so a reused copy is known by its bytes
    while still being a copy of the same picture."""
    big = picture.resize((picture.width * 2, picture.height * 2), Image.NEAREST)
    if tint:
        bands = list(big.split())
        bands[2] = bands[2].point(lambda v: min(255, v + tint))
        big = Image.merge(big.mode, bands)
    return big


def colours(picture):
    """Every colour in [param picture], once."""
    return {colour for _, colour in picture.getcolors(1 << 24)}


def block_sums(big, small):
    """For every 1997 pixel of [param small]: (x, y, its RGBA, the sums of
    its 2x2 block's R, G and B in [param big], the block's alphas)."""
    b = big.convert("RGBA").load()
    p = small.convert("RGBA").load()
    for y in range(small.height):
        for x in range(small.width):
            cells = [b[2 * x + i, 2 * y + j] for j in (0, 1) for i in (0, 1)]
            yield (x, y, p[x, y], [sum(c[k] for c in cells) for k in range(3)],
                   [c[3] for c in cells])


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

    def test_every_file_rides_along_but_card_pictures_and_old_leftovers(self):
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

    # ------------------------------------------------- key-exact places --

    def test_which_places_are_made_key_exact(self):
        self.assertEqual(up.exactness("mana_stripes"), "whole")
        self.assertEqual(up.exactness("card_set_symbols"), "whole")
        self.assertEqual(up.exactness("target_cursor"), "whole")
        self.assertEqual(up.exactness("grave_panel_green"), "whole")
        for family in ("duel_pattern_red", "duel_picture_blue", "duel_mana_white"):
            self.assertEqual(up.exactness(family), "ring", family)
        for name in ("card_back", "summon_sick", "combat_bar", "card_counters",
                     "duel_mana", "portraits/grave_panel_x"):
            self.assertIsNone(up.exactness(name), name)

    def scrambled(self, size, seed):
        """A picture of every colour a block can need: random levels,
        black and white among them, alpha on and off."""
        import random
        rnd = random.Random(seed)
        picture = Image.new("RGBA", size)
        levels = (0, 0, 1, 2, 127, 253, 254, 255, 255)
        for y in range(size[1]):
            for x in range(size[0]):
                picture.putpixel((x, y), tuple(rnd.choice(levels) if rnd.random() < 0.5
                                               else rnd.randrange(256) for _ in range(3))
                                 + (rnd.choice((0, 255)),))
        return picture

    def test_a_whole_key_exact_picture_averages_back_to_1997_exactly(self):
        small = self.scrambled((13, 9), 1)
        big = self.scrambled((26, 18), 2)    # the model: anything at all
        exact = up.key_exact(big, small, ring=False)
        for x, y, want, sums, alphas in block_sums(exact, small):
            self.assertEqual(sums, [4 * want[0], 4 * want[1], 4 * want[2]], (x, y))
            self.assertEqual(alphas, [want[3]] * 4, (x, y))
        # What the game does with it (shrink_x2: (a+b+c+d+2)>>2 a channel)
        # gives back the 1997 picture to the level; Pillow's reduce agrees.
        self.assertEqual(up.back_to_1x(exact).tobytes(), small.tobytes())

    def test_a_ring_makes_the_edge_exact_and_leaves_the_middle(self):
        small = self.scrambled((8, 6), 3)
        big = self.scrambled((16, 12), 4)
        exact = up.key_exact(big, small, ring=True)
        for x, y, want, sums, alphas in block_sums(exact, small):
            edge = x in (0, 7) or y in (0, 5)
            if edge:
                self.assertEqual(sums, [4 * want[0], 4 * want[1], 4 * want[2]], (x, y))
            else:
                for i in (0, 1):
                    for j in (0, 1):
                        self.assertEqual(exact.getpixel((2 * x + i, 2 * y + j)),
                                         big.getpixel((2 * x + i, 2 * y + j)), (x, y))

    def test_an_opaque_picture_stays_rgb(self):
        small = Image.new("RGB", (3, 3), (0, 128, 255))
        big = Image.new("RGB", (6, 6), (40, 120, 200))
        exact = up.key_exact(big, small, ring=False)
        self.assertEqual(exact.mode, "RGB")
        self.assertEqual(up.back_to_1x(exact).tobytes(), small.tobytes())

    def test_a_spread_stays_within_a_level_s_range(self):
        for start, total in (([255] * 4, 0), ([0] * 4, 1020), ([250, 0, 3, 255], 1019),
                             ([10, 10, 10, 10], 41), ([255, 255, 0, 0], 2)):
            block = [[v, 0, 0] for v in start]
            up._spread(block, 0, total)
            self.assertEqual(sum(px[0] for px in block), total, (start, total))
            self.assertTrue(all(0 <= px[0] <= 255 for px in block))

    # ------------------------------------------------ the board's sheets --
    # Part C stage C3, decision 9 (the owner: b, upscaled frame by frame).

    def test_which_pictures_are_board_sheets(self):
        for key in ("dungeon_tiles_1", "dungeon_tiles_3", "dungeon_tiles_white"):
            self.assertEqual(up.board_sheet(key), "tiles", key)
        self.assertEqual(up.board_sheet("dungeon_plaques"), "plaque")
        for key in ("dungeon_treasure", "dungeon_plaque", "world_map_tiles",
                    "portraits/dungeon_tiles_1"):
            self.assertIsNone(up.board_sheet(key), key)

    def test_every_sheet_the_importer_cuts_for_the_board_is_one(self):
        import import_original
        for key, (cells, w, h, cols) in import_original.DUNGEON_SHEETS.items():
            kind = up.board_sheet(key)
            self.assertIsNotNone(kind, key)
            if kind == "tiles":
                self.assertEqual((w, h), (64, 64), key)
                self.assertLessEqual(max(up.BOARD_LATTICE), cells - 1, key)
            else:
                self.assertGreater(cells, up.PLAQUE_MIDDLE, key)

    def test_a_wall_runs_on_where_the_board_continues_it(self):
        # dungeon_view.gd: back_frame 1 = up-right (x + 1), 2 = up-left
        # (y - 1), on looks 0, 4, 24, 28; front_frame 12 + 1 down-right
        # (y + 1), + 2 down-left (x - 1), + 4 on odd rows.
        along_y, along_x = ["y+1", "y-1"], ["x+1", "x-1"]
        for look in (0, 4, 24, 28):
            self.assertEqual(up.wall_runs(look), [], look)
            self.assertEqual(up.wall_runs(look + 1), along_y, look + 1)
            self.assertEqual(up.wall_runs(look + 2), along_x, look + 2)
            self.assertEqual(up.wall_runs(look + 3), along_y + along_x, look + 3)
        for front in (12, 16):
            self.assertEqual(up.wall_runs(front), [], front)
            self.assertEqual(up.wall_runs(front + 1), along_x, front + 1)
            self.assertEqual(up.wall_runs(front + 2), along_y, front + 2)
            self.assertEqual(up.wall_runs(front + 3), along_x + along_y, front + 3)
        self.assertEqual(up.wall_runs(20), [], "the rock top")

    def test_the_floor_diamond_is_the_lower_half_of_a_cell(self):
        mask = up.floor_diamond((64, 64))
        self.assertEqual(mask.getbbox(), (1, 32, 63, 64))
        self.assertEqual(mask.getpixel((31, 47)), 255)
        self.assertEqual(mask.getpixel((0, 32)), 0)
        self.assertEqual(mask.getpixel((31, 31)), 0)

    # ---------------------------------------------------------- reuse --

    def test_a_copy_of_the_same_picture_is_near_and_another_far(self):
        picture = Image.new("RGB", (20, 12), (90, 70, 50))
        picture.paste((200, 40, 40), (0, 0, 10, 12))
        near = up.difference(doubled(picture, tint=3), picture)
        self.assertLess(near[0], up.REUSE_MATCH)
        self.assertEqual(near[1], 0.0)
        other = Image.new("RGB", (20, 12), (90, 70, 50))
        other.paste((40, 40, 200), (10, 0, 20, 12))
        self.assertGreater(up.difference(doubled(other), picture)[0], up.REUSE_MATCH)


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
        # An opaque painting, a cut-out over hidden black (key-exact, the
        # cursor) and the same as a portrait (not), a repeated tile, a
        # territory (its edge ring key-exact), and what is never upscaled.
        Image.new("RGB", (30, 20), (90, 70, 50)).save(self.skin / "title_background.png")
        cut = Image.new("RGBA", (16, 12), (0, 0, 0, 0))
        cut.paste((180, 160, 40, 255), (4, 2, 12, 10))
        cut.save(self.skin / "target_cursor.png")
        cut.save(self.skin / "portraits" / "agnosia.png")
        Image.new("RGBA", (8, 8), (60, 80, 60, 255)).save(self.skin / "deck_tile_olive.png")
        ground = Image.new("RGB", (12, 10), (0, 0, 0))
        ground.paste((150, 30, 30), (1, 1, 11, 9))
        ground.save(self.skin / "duel_mana_red.png")
        Image.new("RGB", (8, 8), (1, 1, 1)).save(self.skin / "coin_toss_heads.png")
        (self.skin / "coin_toss_heads.json").write_text('{"cols": 1}')
        (self.skin / "sfx_draw.wav").write_bytes(b"RIFF")
        (self.skin / "font_title.ttf").write_bytes(b"\x00\x01\x00\x00")
        # What a dev checkout's folder holds and the hi-res skin leaves out.
        (self.skin / "title_background.png.import").write_text("[remap]")
        (self.skin / "cardart").mkdir()
        Image.new("RGB", (4, 4)).save(self.skin / "cardart" / "island.png")

    SKIN_FILES = ["coin_toss_heads.json", "coin_toss_heads.png", "deck_tile_olive.png",
                  "duel_mana_red.png", "font_title.ttf", "portraits/agnosia.png",
                  "sfx_draw.wav", "target_cursor.png", "title_background.png"]
    PICTURES = ["deck_tile_olive", "duel_mana_red", "target_cursor", "title_background",
                "portraits/agnosia"]

    def run_tool(self, skin=None, zip_out=None, folder_out=None, reuse=None):
        with open(os.devnull, "w") as quiet:
            stdout = sys.stdout
            sys.stdout = quiet
            try:
                return up.upscale(skin or self.skin, zip_out, folder_out, self.engine, None,
                                  reuse)
            finally:
                sys.stdout = stdout

    def picture(self, archive, name):
        return Image.open(io.BytesIO(archive.read("skin/" + name)))

    def test_the_zip_is_the_same_files_with_the_pictures_at_twice_the_size(self):
        # The owner: "Each skin pack zip should contain all required assets.
        # Just in the upscaled the relevant assets are upscaled!"
        out = self.tmp / up.ZIP_NAME
        self.assertEqual(self.run_tool(zip_out=out), 0)
        self.assertEqual(up.pictures(self.skin), self.PICTURES)
        with zipfile.ZipFile(out) as archive:
            names = sorted(archive.namelist())
            self.assertEqual(names, ["skin/" + n for n in self.SKIN_FILES],
                             "the same files, under the same names, and no other")
            self.assertEqual(len(names), len(up.skin_files(self.skin)))
            for name in ("sfx_draw.wav", "font_title.ttf", "coin_toss_heads.json",
                         "coin_toss_heads.png"):
                self.assertEqual(archive.read("skin/" + name),
                                 (self.skin / name).read_bytes(), "%s as it was" % name)
            for key in self.PICTURES:
                with Image.open(self.skin / (key + ".png")) as small:
                    big = self.picture(archive, key + ".png")
                    self.assertEqual(big.size, (small.width * 2, small.height * 2), key)
                    self.assertEqual(big.mode, small.mode, key)
            note = archive.comment.decode()
        self.assertIn(up.MODEL, note, "how it was made: the zip's comment")
        self.assertIn("5\n           pictures at twice the size, 2 of them key-exact", note)
        package_release.check_skin(out)  # the shape a release accepts

    def test_the_key_exact_places_give_back_their_1997_pixels(self):
        out = self.tmp / up.ZIP_NAME
        self.run_tool(zip_out=out)
        with zipfile.ZipFile(out) as archive:
            cursor = self.picture(archive, "target_cursor.png")
            face = self.picture(archive, "portraits/agnosia.png")
            ground = self.picture(archive, "duel_mana_red.png")
        with Image.open(self.skin / "target_cursor.png") as small:
            self.assertEqual(up.back_to_1x(cursor).tobytes(), small.convert("RGBA").tobytes(),
                             "the whole cursor, brought back to 1x, is the 1997 cursor")
        # Every other picture keeps the model's pixels: the same run with no
        # key-exact place changes the cursor and the ground and nothing else.
        plain = self.tmp / "plain.zip"
        kept, up.KEY_EXACT = up.KEY_EXACT, ()
        try:
            self.run_tool(zip_out=plain)
        finally:
            up.KEY_EXACT = kept
        with zipfile.ZipFile(out) as a, zipfile.ZipFile(plain) as b:
            for name in ("title_background.png", "deck_tile_olive.png",
                         "portraits/agnosia.png"):
                self.assertEqual(a.read("skin/" + name), b.read("skin/" + name), name)
        with Image.open(self.skin / "duel_mana_red.png") as small:
            back = up.back_to_1x(ground).load()
            for x in range(12):
                for y in (0, 9):
                    self.assertEqual(back[x, y], small.getpixel((x, y)), (x, y))
            for y in range(10):
                for x in (0, 11):
                    self.assertEqual(back[x, y], small.getpixel((x, y)), (x, y))

    def test_the_skin_checker_reads_it_as_a_skin(self):
        out = self.tmp / up.ZIP_NAME
        self.run_tool(zip_out=out)
        report = io.StringIO()
        stdout, sys.stdout = sys.stdout, report
        try:
            self.assertEqual(skin_catalogue.check(out), 0)
        finally:
            sys.stdout = stdout
        text = report.getvalue()
        self.assertIn(": skin, 9 files", text)
        self.assertNotIn("catalogue", text)
        self.assertNotIn("ignored by the game", text)

    def test_the_pushed_colour_comes_back(self):
        out = self.tmp / up.ZIP_NAME
        self.run_tool(zip_out=out)
        with zipfile.ZipFile(out) as archive:
            painting = self.picture(archive, "title_background.png")
            tile = self.picture(archive, "deck_tile_olive.png")
        for got, want in zip(ImageStat.Stat(painting).mean, (90, 70, 50)):
            self.assertAlmostEqual(got, want, delta=1.0)
        for got, want in zip(ImageStat.Stat(tile).mean[:3], (60, 80, 60)):
            self.assertAlmostEqual(got, want, delta=1.0)

    def test_a_cut_out_stays_on_off_and_its_hidden_pixels_black(self):
        out = self.tmp / up.ZIP_NAME
        self.run_tool(zip_out=out)
        with zipfile.ZipFile(out) as archive:
            face = self.picture(archive, "portraits/agnosia.png")
        alpha = face.getchannel("A")
        self.assertEqual(set(alpha.getdata()) - {0, 255}, set())
        self.assertEqual(face.getpixel((0, 0)), (0, 0, 0, 0))
        self.assertEqual(face.getpixel((16, 12))[3], 255)
        # No dark fringe: the opaque pixels right at the edge keep the
        # colour, because the model never saw the hidden black.
        edge = face.getpixel((8, 12))
        self.assertEqual(edge[3], 255)
        self.assertGreater(edge[0], 150)

    def test_a_skin_zip_works_like_a_folder(self):
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

    def test_out_writes_the_hi_res_skin_into_a_folder(self):
        out = self.tmp / "hires"
        self.assertEqual(self.run_tool(folder_out=out), 0)
        written = sorted(p.relative_to(out).as_posix() for p in out.rglob("*") if p.is_file())
        self.assertEqual(written, self.SKIN_FILES)
        zipped = self.tmp / up.ZIP_NAME
        self.run_tool(zip_out=zipped)
        with zipfile.ZipFile(zipped) as archive:
            for name in written:
                self.assertEqual((out / name).read_bytes(), archive.read("skin/" + name), name)

    def test_out_never_writes_over_the_skin_it_reads(self):
        before = {p: p.read_bytes() for p in self.skin.rglob("*") if p.is_file()}
        self.assertEqual(self.run_tool(folder_out=self.skin), 2)
        self.assertEqual({p: p.read_bytes() for p in self.skin.rglob("*") if p.is_file()},
                         before)

    def test_zip_never_writes_over_the_skin_zip_it_reads(self):
        # HUNT 2026-10-21: `--out` had this guard and `--zip` had none —
        # `--skin original_skin.zip --zip original_skin.zip` replaced the
        # 1997 skin with the hi-res one, exit 0.
        packed = self.tmp / "original_skin.zip"
        with zipfile.ZipFile(packed, "w") as archive:
            for path in sorted(self.skin.rglob("*")):
                if path.is_file() and not path.name.endswith(".import"):
                    archive.write(path, "skin/" + path.relative_to(self.skin).as_posix())
        before = packed.read_bytes()
        with redirect_stderr(io.StringIO()):
            self.assertEqual(self.run_tool(skin=packed, zip_out=packed), 2)
        self.assertEqual(packed.read_bytes(), before)

    def test_a_member_naming_a_drive_is_not_unpacked(self):
        # HUNT 2026-10-21: "skin/D:/Games/x.dll" passed the filter
        # (no "..", no backslash), and on Windows joining "D:" onto the
        # temporary folder leaves it — a skin zip wrote outside its folder.
        packed = self.tmp / "drive.zip"
        with zipfile.ZipFile(packed, "w") as archive:
            archive.writestr("skin/D:/Games/x.dll", b"MZ")
            archive.writestr("skin/C:x.png", b"x")
            archive.writestr("skin/title_background.png", (self.skin / "title_background.png").read_bytes())
        with up.opened(packed) as folder:
            found = sorted(p.relative_to(folder).as_posix() for p in folder.rglob("*") if p.is_file())
        self.assertEqual(found, ["title_background.png"])

    def test_what_an_earlier_tool_left_is_not_carried(self):
        # 0.50.28's copies beside the pictures, 0.50.30's catalogue and the
        # note: never files of the hi-res skin, and never read as pictures.
        straight = self.tmp / "straight.zip"
        self.run_tool(zip_out=straight)
        doubled(Image.open(self.skin / "title_background.png")).save(
            self.skin / "title_background@2x.png")
        (self.skin / "catalogue.txt").write_text("title_background.png = x.png\n")
        (self.skin / "UPSCALE.txt").write_text("note")
        again = self.tmp / "again.zip"
        self.assertEqual(self.run_tool(zip_out=again), 0)
        self.assertEqual(again.read_bytes(), straight.read_bytes())

    # ------------------------------------------------------ --reuse --
    # The owner, 2026-10-17: *"I already have built 2x skin so we will
    # reuse it"* — the 0.50.28 zip, `<key>@2x.png` and its note alone.

    def old_2x_zip(self, keys, tint=3, other=(), size_off=()) -> Path:
        """A zip shaped like 0.50.28's: one `@2x` copy per key — its 1997
        picture doubled, the blue raised by [param tint] so a reused copy
        is known by its bytes; of another picture for the keys in [param
        other]; a pixel too wide for [param size_off]."""
        path = self.tmp / "old_2x.zip"
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr("skin/UPSCALE.txt", "copies")
            for key in keys:
                with Image.open(self.skin / (key + ".png")) as small:
                    copy = doubled(small.copy(), tint)
                if key in other:
                    copy = Image.new(copy.mode, copy.size, (7, 77, 177))
                if key in size_off:
                    copy = copy.resize((copy.width + 1, copy.height))
                data = io.BytesIO()
                copy.save(data, "PNG")
                archive.writestr("skin/%s@2x.png" % key, data.getvalue())
        return path

    def seen(self) -> list[str]:
        log = self.engine.parent / "seen.txt"
        return log.read_text().split() if log.exists() else []

    def test_the_sandstone_is_doubled_pixel_for_pixel(self):
        # The owner's playtest of 0.50.31: "sandstone colored buttons look
        # strange with top and botton stripes and blurry middle".
        stone = Image.new("RGB", (40, 30))
        stone.putdata([(247, 240, 208) if (x + y) % 2 else (176, 171, 145)
                       for y in range(30) for x in range(40)])
        stone.save(self.skin / "panel_stone.png")
        out = self.tmp / up.ZIP_NAME
        self.assertEqual(self.run_tool(zip_out=out), 0)
        self.assertNotIn("panel_stone.png", self.seen(), "the model never sees it")
        with zipfile.ZipFile(out) as archive:
            big = self.picture(archive, "panel_stone.png")
            note = archive.comment.decode()
        self.assertEqual(big.tobytes(), stone.resize((80, 60), Image.NEAREST).tobytes(),
                         "every 1997 pixel a 2x2 block of itself: the dither kept")
        self.assertIn("doubled  1 pixel for pixel", note)
        # And an old copy of it is not reused: it was the model's.
        old = self.tmp / "old_2x.zip"
        with zipfile.ZipFile(old, "w") as archive:
            data = io.BytesIO()
            stone.resize((80, 60), Image.BILINEAR).save(data, "PNG")
            archive.writestr("skin/panel_stone@2x.png", data.getvalue())
        again = self.tmp / "again.zip"
        self.assertEqual(self.run_tool(zip_out=again, reuse=old), 0)
        with zipfile.ZipFile(again) as archive:
            self.assertEqual(self.picture(archive, "panel_stone.png").tobytes(), big.tobytes())

    def test_the_pre_duel_frame_and_the_world_ground_are_doubled(self):
        # The owner, 2026-10-28 (ledger row 121): "pixel-double both".
        grain = Image.new("RGB", (32, 16))
        grain.putdata([(120, 96, 40) if (x * 7 + y * 3) % 5 else (60, 48, 20)
                       for y in range(16) for x in range(32)])
        names = ("preduel_frame", "preduel_frame_tinted", "world_landtile", "world_cstline1", "world_roads")
        for name in names:
            grain.save(self.skin / (name + ".png"))
        out = self.tmp / up.ZIP_NAME
        self.assertEqual(self.run_tool(zip_out=out), 0)
        with zipfile.ZipFile(out) as archive:
            for name in names:
                self.assertNotIn(name + ".png", self.seen(), "the model never sees " + name)
                self.assertEqual(self.picture(archive, name + ".png").tobytes(),
                                 grain.resize((64, 32), Image.NEAREST).tobytes(),
                                 name + ": every 1997 pixel a 2x2 block of itself")
        self.assertNotIn("world_sland", up.DOUBLED, "the ground halves stay with their uprights")

    def test_reuse_with_every_copy_never_runs_the_engine(self):
        old = self.old_2x_zip(self.PICTURES)
        self.engine.write_text(BROKEN_ENGINE)   # it would fail if it were run
        out = self.tmp / up.ZIP_NAME
        self.assertEqual(self.run_tool(zip_out=out, reuse=old), 0)
        self.assertEqual(self.seen(), [], "the engine never saw a picture")
        with zipfile.ZipFile(out) as archive, zipfile.ZipFile(old) as before:
            self.assertEqual(sorted(archive.namelist()), ["skin/" + n for n in self.SKIN_FILES])
            for key in ("title_background", "deck_tile_olive", "portraits/agnosia"):
                self.assertEqual(archive.read("skin/%s.png" % key),
                                 before.read("skin/%s@2x.png" % key),
                                 "%s taken as it was, under its own name" % key)
            cursor = self.picture(archive, "target_cursor.png")
            note = archive.comment.decode()
        with Image.open(self.skin / "target_cursor.png") as small:
            self.assertEqual(up.back_to_1x(cursor).tobytes(), small.convert("RGBA").tobytes(),
                             "a reused copy is made key-exact too")
        self.assertIn("5 of them taken as they were from old_2x.zip", note)
        package_release.check_skin(out)

    def test_reuse_upscales_what_the_old_zip_lacks_has_wrong_or_is_another_picture(self):
        # The cursor's copy is missing, the tile's is not twice its size,
        # the painting's is a copy of another picture.
        keys = [k for k in self.PICTURES if k != "target_cursor"]
        old = self.old_2x_zip(keys, other=("title_background",), size_off=("deck_tile_olive",))
        out = self.tmp / up.ZIP_NAME
        self.assertEqual(self.run_tool(zip_out=out, reuse=old), 0)
        self.assertEqual(sorted(self.seen()), ["deck_tile_olive.png", "target_cursor.png",
                                               "title_background.png"])
        with zipfile.ZipFile(out) as archive:
            painting = self.picture(archive, "title_background.png")
            face = archive.read("skin/portraits/agnosia.png")
            note = archive.comment.decode()
        with zipfile.ZipFile(old) as before:
            self.assertEqual(face, before.read("skin/portraits/agnosia@2x.png"), "a good copy is kept")
        self.assertNotEqual(painting.getpixel((0, 0))[:3], (7, 77, 177),
                            "never worn over the wrong art")
        self.assertIn("2 of them taken as they were", note)

    def test_reuse_reads_a_hi_res_skin_by_its_own_names(self):
        first = self.tmp / "first.zip"
        self.run_tool(zip_out=first)
        (self.engine.parent / "seen.txt").unlink()
        self.engine.write_text(BROKEN_ENGINE)
        again = self.tmp / "again.zip"
        self.assertEqual(self.run_tool(zip_out=again, reuse=first), 0)
        self.assertEqual(self.seen(), [])
        with zipfile.ZipFile(first) as a, zipfile.ZipFile(again) as b:
            self.assertEqual(sorted(a.namelist()), sorted(b.namelist()))
            for name in a.namelist():
                self.assertEqual(a.read(name), b.read(name), name)

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
        with self.assertRaises(ValueError):
            package_release.check_skin(out)

    def test_an_engine_that_fails_says_so(self):
        self.engine.write_text(BROKEN_ENGINE)
        with self.assertRaises(RuntimeError) as caught:
            self.run_tool(zip_out=self.tmp / up.ZIP_NAME)
        self.assertIn("Vulkan", str(caught.exception))
        self.assertIn("vkCreateInstance", str(caught.exception))
        self.assertFalse((self.tmp / up.ZIP_NAME).exists())

    # ------------------------------------------------ the board's sheets --
    # Part C stage C3, decision 9 (the owner: "b, upscaled"): a board
    # sheet upscaled as one picture showed the model each frame beside its
    # neighbours ON THE SHEET, and the castle walls broke at every cell.

    FLOOR_CENTRE = (31, 47)
    WALL = (30, 160, 220)
    SHEET_NEIGHBOUR = (0, 0, 255)

    def tile_sheet(self, key="dungeon_tiles_test", layout=True):
        """A board tile sheet the shape of the importer's (64 x 64 cells,
        12 a row; 24 frames here): 0 a floor whose colour falls off from
        its centre, 1 the same floor with an up-right wall, 8 a chest, 11
        empty, every other frame a blue floor — what lies beside 0 and 1
        on the sheet and never beside them on the board."""
        diamond = Image.new("L", (64, 64), 0)
        floor = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        for y in range(32, 64):
            for x in range(64):
                d = abs(x - 31.5) + 2 * abs(y - 47.5)
                if d <= 32:
                    diamond.putpixel((x, y), 255)
                    floor.putpixel((x, y), (int(200 - 4 * d), 100, 40, 255))
        walled = floor.copy()
        for x in range(32, 64):
            for y in range(int(32 + (x - 32) / 2) - 20, int(32 + (x - 32) / 2)):
                walled.putpixel((x, y), self.WALL + (255,))
        blue = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        blue.paste(self.SHEET_NEIGHBOUR + (255,), (0, 0), diamond)
        chest = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        chest.paste((250, 250, 0, 255), (20, 30, 44, 50))
        sheet = Image.new("RGBA", (768, 128), (0, 0, 0, 0))
        for i in range(24):
            frame = {0: floor, 1: walled, 8: chest, 11: None}.get(i, blue)
            if frame is not None:
                sheet.paste(frame, ((i % 12) * 64, (i // 12) * 64))
        sheet.save(self.skin / (key + ".png"))
        if layout:
            (self.skin / (key + ".json")).write_text(
                '{"cols": 12, "rows": 2, "frames": 24, "frame_width": 64, "frame_height": 64}')
        return sheet

    def plaque_sheet(self):
        """The plaque's sheet as the importer cuts `Dungbutt.spr`: four
        cells, each frame at its cell's top left at its own size — 0 the
        card's frame, 1 the left end, 2 the striped middle, 3 the right end."""
        sheet = Image.new("RGBA", (160, 30), (0, 0, 0, 0))
        sheet.paste((128, 128, 128, 255), (0, 0, 40, 30))
        sheet.paste((255, 0, 0, 255), (40, 0, 50, 12))
        for x in range(6):
            sheet.paste((0, 200 if x % 2 else 100, 0, 255), (80 + x, 0, 81 + x, 12))
        sheet.paste((0, 0, 255, 255), (120, 0, 129, 12))
        sheet.save(self.skin / "dungeon_plaques.png")
        (self.skin / "dungeon_plaques.json").write_text(
            '{"cols": 4, "rows": 1, "frames": 4, "frame_width": 40, "frame_height": 30,'
            ' "sizes": [[40, 30], [10, 12], [6, 12], [9, 12]]}')
        return sheet

    def shown(self, name):
        """What the stand-in engine was shown as [param name]."""
        return Image.open(self.engine.parent / "inputs" / name).convert("RGB")

    def test_a_board_sheet_is_upscaled_frame_by_frame_and_put_back(self):
        sheet = self.tile_sheet()
        out = self.tmp / up.ZIP_NAME
        self.assertEqual(self.run_tool(zip_out=out), 0)
        seen = self.seen()
        self.assertNotIn("dungeon_tiles_test.png", seen, "never the sheet as one picture")
        frames = sorted(name for name in seen if name.startswith("dungeon_tiles_test"))
        self.assertEqual(frames, ["dungeon_tiles_test__frame%02d.png" % i
                                  for i in range(24) if i != 11],
                         "one picture a frame, and the empty frame never")
        with zipfile.ZipFile(out) as archive:
            big = self.picture(archive, "dungeon_tiles_test.png")
            self.assertEqual(archive.read("skin/dungeon_tiles_test.json"),
                             (self.skin / "dungeon_tiles_test.json").read_bytes(),
                             "the grid as it was: the game reads it in 1997 pixels")
            note = archive.comment.decode()
        self.assertEqual((big.size, big.mode), ((1536, 256), "RGBA"))
        for i in range(24):
            x, y = (i % 12) * 128, (i // 12) * 128
            cell = big.crop((x, y, x + 128, y + 128))
            small = sheet.crop(((i % 12) * 64, (i // 12) * 64, (i % 12) * 64 + 64, (i // 12) * 64 + 64))
            self.assertEqual(cell.getchannel("A").tobytes(),
                             up.alpha_up(small.getchannel("A")).tobytes(),
                             "frame %d's cut-out is its own, doubled, where it stands" % i)
        self.assertIsNone(big.crop((11 * 128, 0, 12 * 128, 128)).getbbox(), "the empty frame")
        for got, want in zip(big.getpixel((8 * 128 + 64, 80)), (250, 250, 0, 255)):
            self.assertAlmostEqual(got, want, delta=2)
        centre = sheet.getpixel(self.FLOOR_CENTRE)
        for got, want in zip(big.getpixel((2 * 31 + 1, 2 * 47 + 1)), centre):
            self.assertAlmostEqual(got, want, delta=3)
        self.assertIn("board    1 sheet frame by frame", note)
        package_release.check_skin(out)

    def test_a_floor_is_shown_amid_its_board_neighbours_not_the_sheets(self):
        sheet = self.tile_sheet()
        (self.engine.parent / "inputs").mkdir()
        self.assertEqual(self.run_tool(zip_out=self.tmp / up.ZIP_NAME), 0)
        n = up.BOARD_CONTEXT
        for i in (0, 1):
            shown = self.shown("dungeon_tiles_test__frame%02d.png" % i)
            self.assertEqual(shown.size, (64 + 2 * n, 64 + 2 * n), i)
            self.assertNotIn(self.SHEET_NEIGHBOUR, colours(shown),
                             "frame %d never sees the frame beside it on the sheet" % i)
            # The floor of each cell sharing an edge with it: a copy of its
            # own, its centre where the board puts that cell's centre (but
            # where the frame's own wall stands over it: frame 1's x + 1).
            cx, cy = self.FLOOR_CENTRE
            for edge, (dx, dy) in up.BOARD_EDGES.items():
                if (i, edge) == (1, "x+1"):
                    continue
                self.assertEqual(shown.getpixel((n + cx + dx, n + cy + dy)),
                                 sheet.getpixel(self.FLOOR_CENTRE)[:3], (i, edge))
        # The up-right wall runs on along y: its next segments, up-left and
        # down-right of it, are there too.
        shown = self.shown("dungeon_tiles_test__frame01.png")
        for dx, dy in (up.BOARD_EDGES["y+1"], up.BOARD_EDGES["y-1"], (0, 0)):
            self.assertEqual(shown.getpixel((n + 50 + dx, n + 30 + dy)), self.WALL, (dx, dy))
        # Anything else (the chest) alone, with the plain edge pad.
        self.assertEqual(self.shown("dungeon_tiles_test__frame08.png").size,
                         (64 + 2 * up.PAD, 64 + 2 * up.PAD))

    def test_the_plaque_pieces_are_shown_in_the_plaques_row(self):
        sheet = self.plaque_sheet()
        (self.engine.parent / "inputs").mkdir()
        out = self.tmp / up.ZIP_NAME
        self.assertEqual(self.run_tool(zip_out=out), 0)
        n = up.PLAQUE_CONTEXT
        stripe = [sheet.getpixel((80 + x, 6))[:3] for x in range(6)]
        left = self.shown("dungeon_plaques__frame01.png")
        middle = self.shown("dungeon_plaques__frame02.png")
        right = self.shown("dungeon_plaques__frame03.png")
        self.assertEqual(left.size, (10 + 2 * n, 12 + 2 * n))
        for k in range(n):
            # The middle repeated on the inner side of each end and on
            # both sides of itself; the edge pad outside an end.
            self.assertEqual(left.getpixel((n + 10 + k, n + 6)), stripe[k % 6], k)
            self.assertEqual(middle.getpixel((n + 6 + k, n + 6)), stripe[k % 6], k)
            self.assertEqual(middle.getpixel((n - 1 - k, n + 6)), stripe[(-1 - k) % 6], k)
            self.assertEqual(right.getpixel((n - 1 - k, n + 6)), stripe[(-1 - k) % 6], k)
        self.assertEqual(left.getpixel((n - 5, n + 6)), (255, 0, 0))
        self.assertEqual(right.getpixel((n + 9 + 5, n + 6)), (0, 0, 255))
        self.assertNotIn((0, 0, 255), colours(left), "the left end never meets the right")
        self.assertEqual(self.shown("dungeon_plaques__frame00.png").size,
                         (40 + 2 * up.PAD, 30 + 2 * up.PAD), "the card's frame alone")
        with zipfile.ZipFile(out) as archive:
            big = self.picture(archive, "dungeon_plaques.png")
        self.assertEqual(big.size, (320, 60))
        self.assertEqual(big.getchannel("A").tobytes(),
                         up.alpha_up(sheet.getchannel("A")).tobytes(),
                         "each piece where it stands, at its own size, nothing round it")

    def test_a_board_sheet_without_its_grid_is_upscaled_whole(self):
        self.tile_sheet("dungeon_tiles_lost", layout=False)
        out = self.tmp / up.ZIP_NAME
        report = io.StringIO()
        stdout, sys.stdout = sys.stdout, report
        try:
            self.assertEqual(up.upscale(self.skin, out, None, self.engine, None), 0)
        finally:
            sys.stdout = stdout
        self.assertIn("dungeon_tiles_lost.png", self.seen())
        self.assertIn("dungeon_tiles_lost.png: no readable dungeon_tiles_lost.json", report.getvalue())
        with zipfile.ZipFile(out) as archive:
            self.assertEqual(self.picture(archive, "dungeon_tiles_lost.png").size, (1536, 256))
            self.assertNotIn("board ", archive.comment.decode())


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

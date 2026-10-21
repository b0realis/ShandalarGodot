#!/usr/bin/env python3
"""Self-test for tools/import_manalink.py — the opt-in Manalink door — and
the importer's --check list.

Run from the repo root:
    python3 -m unittest discover -s tools -p 'test_*.py'

What is pinned (the owner, 2026-10-17: *"lets have a list of needed assets
and check what is missing. Lets have an option for the tool to use later
manalink install for all assets if user does not have original install of
1997!"*):
  * the door is SHUT unless asked for: without --manalink a Manalink
    install's own files are never taken (the 2026-10-15 ruling stands);
  * with it, each key is taken only in a shape the game can use — the
    1997 size, exactly twice it (halved), resized where the game's cells
    allow it, laid together for the card frames — and a key Manalink has
    in an unusable shape is named, not imported;
  * the decoders read what a Manalink install holds (BMP, any PNG);
  * --check lists every asset and writes nothing.
"""

import io
import struct
import sys
import tempfile
import unittest
import zlib
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import import_manalink as ml  # noqa: E402
import import_original as imp  # noqa: E402


def bmp24(width: int, height: int, pixel) -> bytes:
    """A bottom-up 24-bit BMP; `pixel(x, y)` gives (r, g, b), y from the top."""
    stride = ((width * 24 + 31) // 32) * 4
    rows = bytearray()
    for y in range(height - 1, -1, -1):
        line = bytearray()
        for x in range(width):
            r, g, b = pixel(x, y)
            line += bytes((b, g, r))
        rows += line + bytes(stride - len(line))
    header = struct.pack("<IiiHHIIiiII", 40, width, height, 1, 24, 0,
                         len(rows), 2835, 2835, 0, 0)
    return b"BM" + struct.pack("<IHHI", 14 + 40 + len(rows), 0, 0, 54) \
        + header + bytes(rows)


def bmp32(width: int, height: int, pixel, fourth: int) -> bytes:
    """A top-down 32-bit BI_RGB BMP whose fourth byte is `fourth` everywhere."""
    rows = bytearray()
    for y in range(height):
        for x in range(width):
            r, g, b = pixel(x, y)
            rows += bytes((b, g, r, fourth))
    header = struct.pack("<IiiHHIIiiII", 40, width, -height, 1, 32, 0,
                         len(rows), 2835, 2835, 0, 0)
    return b"BM" + struct.pack("<IHHI", 14 + 40 + len(rows), 0, 0, 54) \
        + header + bytes(rows)


def bmp8(width: int, height: int, palette, index) -> bytes:
    """A bottom-up 8-bit palette BMP; `index(x, y)` picks a palette entry."""
    stride = ((width * 8 + 31) // 32) * 4
    rows = bytearray()
    for y in range(height - 1, -1, -1):
        line = bytes(index(x, y) for x in range(width))
        rows += line + bytes(stride - len(line))
    table = b"".join(bytes((b, g, r, 0)) for r, g, b in palette)
    header = struct.pack("<IiiHHIIiiII", 40, width, height, 1, 8, 0,
                         len(rows), 2835, 2835, len(palette), 0)
    offset = 14 + 40 + len(table)
    return b"BM" + struct.pack("<IHHI", offset + len(rows), 0, 0, offset) \
        + header + table + bytes(rows)


def png(width: int, height: int, colour: int, depth: int, rows: list[bytes],
        filters: list[int], plte: bytes = b"", trns: bytes = b"") -> bytes:
    """A PNG from already-FILTERED scanlines, so every filter is exercised."""
    def chunk(tag: bytes, data: bytes) -> bytes:
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))
    raw = b"".join(bytes((f,)) + r for f, r in zip(filters, rows))
    out = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(
        ">IIBBBBB", width, height, depth, colour, 0, 0, 0))
    if plte:
        out += chunk(b"PLTE", plte)
    if trns:
        out += chunk(b"tRNS", trns)
    return out + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")


def write(root: Path, rel: str, data: bytes) -> Path:
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return path


def solid_png(width: int, height: int, rgba=(10, 20, 30, 255)) -> bytes:
    rows = [bytes(rgba) * width for _ in range(height)]
    return png(width, height, 6, 8, rows, [0] * height)


class TestDecoders(unittest.TestCase):

    def test_a_24_bit_bmp_reads_top_to_bottom_with_its_row_padding(self):
        data = bmp24(3, 2, lambda x, y: (x * 10, y * 100, 7))
        w, h, px = ml.decode_bmp(data)
        self.assertEqual((w, h), (3, 2))
        self.assertEqual(px[0:4], bytes((0, 0, 7, 255)))
        self.assertEqual(px[(1 * 3 + 2) * 4:(1 * 3 + 2) * 4 + 4],
                         bytes((20, 100, 7, 255)))

    def test_a_32_bit_bmp_with_no_alpha_written_is_opaque(self):
        """Manalink's `WinBk_StartDuel2.bmp`: the fourth byte is 0 everywhere,
        which BI_RGB calls unused — read as transparent, the panel vanished."""
        w, h, px = ml.decode_bmp(bmp32(2, 2, lambda x, y: (1, 2, 3), 0))
        self.assertEqual(set(px[3::4]), {255})
        w, h, px = ml.decode_bmp(bmp32(2, 2, lambda x, y: (1, 2, 3), 128))
        self.assertEqual(set(px[3::4]), {128}, "a written alpha is kept")

    def test_an_8_bit_palette_bmp(self):
        data = bmp8(2, 2, [(255, 0, 0), (0, 0, 255)], lambda x, y: (x + y) % 2)
        _w, _h, px = ml.decode_bmp(data)
        self.assertEqual(px[0:3], bytes((255, 0, 0)))
        self.assertEqual(px[4:7], bytes((0, 0, 255)))

    def test_every_png_filter_and_a_palette_with_transparency(self):
        # Two RGB rows: row 0 Sub-filtered, row 1 Paeth-filtered against it.
        row0 = bytes((10, 20, 30, 5, 5, 5))       # Sub: second = first + 5
        row1 = bytes((1, 1, 1, 0, 0, 0))          # Paeth over row 0
        w, h, px = ml.decode_png(png(2, 2, 2, 8, [row0, row1], [1, 4]))
        self.assertEqual(px[0:3], bytes((10, 20, 30)))
        self.assertEqual(px[4:7], bytes((15, 25, 35)))
        self.assertEqual(px[8:11], bytes((11, 21, 31)))
        for kind in (2, 3):  # Up and Average decode without error too
            ml.decode_png(png(2, 2, 2, 8, [row0, row1], [kind, kind]))
        plte = bytes((0, 0, 0, 200, 100, 50))
        _w, _h, px = ml.decode_png(png(4, 1, 3, 2, [bytes((0b00010001,))],
                                       [0], plte=plte, trns=bytes((0,))))
        self.assertEqual(px[0:4], bytes((0, 0, 0, 0)), "entry 0 is clear")
        self.assertEqual(px[4:8], bytes((200, 100, 50, 255)))

    def test_a_16_bit_grey_png(self):
        _w, _h, px = ml.decode_png(png(1, 1, 0, 16, [bytes((0x80, 0x00))], [0]))
        self.assertEqual(px, bytes((128, 128, 128, 255)))

    def test_an_unknown_format_is_refused_not_guessed(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = write(Path(tmp), "x.pic", b"PIC\x00raw 1997 bytes")
            with self.assertRaises(ValueError):
                ml.decode_any(path)


class TestResampling(unittest.TestCase):

    def test_halving_averages_each_block_and_ignores_a_clear_neighbour(self):
        px = bytes((200, 0, 0, 255, 0, 0, 0, 0)) * 2  # red | clear, two rows
        w, h, out = ml.halve(2, 2, px)
        self.assertEqual((w, h), (1, 1))
        self.assertEqual(out[:3], bytes((200, 0, 0)), "no darkening")
        self.assertEqual(out[3], 127)

    def test_resize_lands_on_the_size_asked_for_either_way(self):
        px = bytes((50, 60, 70, 255)) * (34 * 43)
        w, h, out = ml.resize(34, 43, px, 24, 30)
        self.assertEqual((w, h, len(out)), (24, 30, 24 * 30 * 4))
        self.assertEqual(out[:4], bytes((50, 60, 70, 255)), "flat stays flat")
        w, h, out = ml.resize(80, 10, bytes((9, 9, 9, 255)) * 800, 82, 12)
        self.assertEqual((w, h), (82, 12))


class TestTheDoor(unittest.TestCase):
    """The rules, through `fill` on a tree built in the test."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name) / "manalink"
        self.dest = Path(self.tmp.name) / "skin"
        self.dest.mkdir()

    def tearDown(self):
        self.tmp.cleanup()

    def fill(self, missing):
        index = imp.build_index([self.root])
        with redirect_stdout(io.StringIO()):
            return ml.fill(index, self.dest, list(missing), imp.write_png)

    def size(self, key):
        data = (self.dest / (key + ".png")).read_bytes()
        return struct.unpack(">II", data[16:24])

    def test_same_takes_the_1997_size_halves_twice_it_and_refuses_the_rest(self):
        write(self.root, "Program/DuelArt/WinBk_StartDuelButtonNormal.bmp",
              bmp24(131, 36, lambda x, y: (1, 2, 3)))
        write(self.root, "Program/DBArt/DekTile4.pic", solid_png(64, 64))
        write(self.root, "Program/DBArt/DekTit1.pic", solid_png(200, 50))
        taken, refused = self.fill(["button_normal", "deck_tile_slate",
                                    "deck_title_slab"])
        self.assertEqual(self.size("button_normal"), (131, 36))
        self.assertEqual(self.size("deck_tile_slate"), (32, 32))
        self.assertIn("halved", dict((k, h) for k, _p, h in taken)["deck_tile_slate"])
        self.assertFalse((self.dest / "deck_title_slab.png").exists())
        self.assertIn("291x73", refused["deck_title_slab"])

    def test_fit_resizes_to_the_1997_size_and_own_keeps_its_own(self):
        write(self.root, "Program/CardArt/CardCounters.bmp",
              bmp24(34, 1075, lambda x, y: (5, 5, 5)))
        write(self.root, "Program/DuelArt/WinBk_Attack.pic", solid_png(690, 375))
        self.fill(["card_counters", "attack_panel"])
        self.assertEqual(self.size("card_counters"), (24, 750))
        self.assertEqual(self.size("attack_panel"), (690, 375))

    def test_the_card_frame_is_two_classic_layers_laid_together(self):
        clear = (0, 0, 0, 0)
        write(self.root, "Program/CardArt/Classic/CardBk_White.png",
              solid_png(337, 484, (200, 190, 170, 255)))
        write(self.root, "Program/CardArt/Classic/CardOv_W.png",
              solid_png(337, 484, clear))
        write(self.root, "Program/CardArt/Modern/CardBk_White.png",
              solid_png(337, 484, (255, 0, 0, 255)))
        self.fill(["card_frame_white"])
        self.assertEqual(self.size("card_frame_white"), ml.FRAME_SIZE)
        _w, _h, px = ml.decode_png((self.dest / "card_frame_white.png").read_bytes())
        self.assertEqual(px[:3], bytes((200, 190, 170)), "Classic, not Modern")

    def test_a_shape_the_game_cannot_use_is_named_not_imported(self):
        write(self.root, "Program/CardArt/Abilities.pic", solid_png(200, 100))
        taken, refused = self.fill(["ability_icons", "hand_panel_red"])
        self.assertEqual(taken, [])
        self.assertIn("grid", refused["ability_icons"])
        self.assertIn("Hand_Red.bmp", refused["hand_panel_red"])
        self.assertFalse((self.dest / "ability_icons.png").exists())

    def test_every_row_names_a_manalink_file_and_a_1997_size(self):
        for key, row in ml.MANALINK.items():
            self.assertIn(key, imp.MANIFEST, key)
            self.assertIn(row.rule, (ml.SAME, ml.FIT, ml.OWN), key)
            self.assertTrue(row.names, key)
        for key in list(ml.FRAMES) + list(ml.NOT_USED):
            self.assertIn(key, imp.MANIFEST, key)
        self.assertFalse(set(ml.MANALINK) & set(ml.NOT_USED))


class TestTheImporterSwitches(unittest.TestCase):
    """--manalink and --check, through the importer's own main."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        self.root = self.base / "manalink"
        write(self.root, "Program/DuelArt/WinBk_StartDuelButtonNormal.bmp",
              bmp24(131, 36, lambda x, y: (1, 2, 3)))
        write(self.root, "Program/DuelSounds/Grey.wav", b"RIFF manalink")

    def tearDown(self):
        self.tmp.cleanup()

    def run_main(self, *extra) -> str:
        argv = sys.argv
        sys.argv = ["import_original.py", "--source", str(self.root),
                    "--no-videos", *extra]
        log = io.StringIO()
        try:
            with redirect_stdout(log):
                self.assertEqual(imp.main(), 0)
        finally:
            sys.argv = argv
        return log.getvalue()

    def test_the_door_is_shut_unless_asked_for(self):
        dest = self.base / "plain"
        self.run_main("--dest", str(dest))
        self.assertFalse((dest / "button_normal.png").exists())
        self.assertFalse((dest / "sfx_land_grey.wav").exists())
        dest = self.base / "door"
        self.run_main("--dest", str(dest), "--manalink")
        self.assertTrue((dest / "button_normal.png").exists())
        self.assertEqual((dest / "sfx_land_grey.wav").read_bytes(),
                         b"RIFF manalink")

    def test_a_folder_the_door_filled_carries_the_label(self):
        # The owner, 2026-10-17: never a Manalink skin in a release. The
        # label is what the release build refuses, so it must name what
        # the door wrote, and nothing a 1997 run wrote over.
        dest = self.base / "door"
        self.run_main("--dest", str(dest), "--manalink")
        label = (dest / ml.LABEL).read_text().splitlines()
        self.assertIn("button_normal", label)
        self.assertIn("sfx_land_grey.wav", label)
        plain = self.base / "plain"
        self.run_main("--dest", str(plain))
        self.assertFalse((plain / ml.LABEL).exists())

    def test_a_frame_layer_that_will_not_decode_is_named_and_the_label_still_written(self):
        # HUNT 2026-10-21: a Classic frame layer the decoder refuses (an
        # interlaced PNG) or cannot even divide (bit depth 0) escaped
        # `fill` as a traceback — after it had written the button, and
        # before the label that tells a release build the folder holds
        # Manalink's files.
        stone = bytearray(solid_png(8, 8))
        stone[28] = 1                                   # IHDR's interlace byte
        plate = bytearray(solid_png(8, 8, (0, 0, 0, 0)))
        plate[24] = 0                                   # IHDR's bit depth
        write(self.root, "Program/CardArt/Classic/CardBk_White.png", bytes(stone))
        write(self.root, "Program/CardArt/Classic/CardOv_W.png", bytes(plate))
        write(self.root, "Program/CardArt/Classic/CardBk_Blue.png", solid_png(8, 8))
        write(self.root, "Program/CardArt/Classic/CardOv_U.png", bytes(plate))
        dest = self.base / "door"
        self.run_main("--dest", str(dest), "--manalink")
        label = (dest / ml.LABEL).read_text().splitlines()
        self.assertIn("button_normal", label)
        self.assertFalse((dest / "card_frame_white.png").exists())
        self.assertFalse((dest / "card_frame_blue.png").exists())
        checked = self.run_main("--dest", str(self.base / "never"), "--check", "--manalink")
        self.assertIn("CardBk_White.png would not decode", checked)
        self.assertIn("CardOv_U.png would not decode", checked)

    def test_the_label_keeps_only_what_no_later_run_wrote_over(self):
        dest = self.base / "label"
        dest.mkdir()
        ml.write_label(dest, ["button_normal", "card_back"], set())
        ml.write_label(dest, [], {"card_back"})
        keys = [line for line in (dest / ml.LABEL).read_text().splitlines()
                if not line.startswith("#")]
        self.assertEqual(keys, ["button_normal"])
        ml.write_label(dest, [], {"button_normal"})
        self.assertFalse((dest / ml.LABEL).exists())

    def test_check_lists_every_asset_and_writes_nothing(self):
        dest = self.base / "never"
        out = self.run_main("--dest", str(dest), "--check", "--manalink")
        self.assertFalse(dest.exists(), "--check writes nothing")
        self.assertIn("THE CHECKLIST", out)
        self.assertIn("ok       button_normal", out)
        self.assertIn("MISSING  title_background", out)
        self.assertIn("unused   damage_marker", out)
        self.assertIn("of the %d skin files the game reads"
                      % (len(imp.MANIFEST) - len(imp.NOT_READ)), out)
        self.assertIn("portraits/", out)
        self.assertIn("coin_toss_heads", out)


if __name__ == "__main__":
    unittest.main()

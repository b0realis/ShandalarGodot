#!/usr/bin/env python3
"""Self-test for tools/import_original.py's raw 1997 decoders.

Run from the repo root:
    python3 -m unittest discover -s tools -p 'test_*.py'

NO ORIGINAL BYTES ARE IN THIS FILE. Every fixture is BUILT here by the
encoder helpers below, which are written to be the exact inverse of the
decoder under test — so a `.pic` this suite decodes is one this suite
made, and nothing copyrighted has to travel with the tests.

That inverse is also the suite's one weakness, and it is why the schedule
and dictionary tests below pin absolute numbers instead: an encoder and a
decoder that share a bug agree with each other perfectly. The other guard
is outside any test — the 70 faces were LOOKED AT on a contact sheet
(2026-09-03), which is the check no assertion replaces.
"""

import datetime
import io
import os
import struct
import sys
import tempfile
import unittest
import zlib
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import import_original as imp  # noqa: E402


# --------------------------------------------------------------- encoders --

def pack_codes(codes: list[int], max_bits: int = 11) -> bytes:
    """LZW codes -> packed bits. The exact inverse of `_lzw_codes`."""
    out = bytearray()
    bits = 0
    held = 0
    width = 9
    threshold = 0x100
    counter = 0
    for code in codes:
        bits |= code << held
        held += width
        while held >= 8:
            out.append(bits & 0xFF)
            bits >>= 8
            held -= 8
        counter += 1
        if counter == threshold:
            counter = 0
            width += 1
            threshold <<= 1
            if width > max_bits:
                width = 9
                threshold = 0x100
    if held:
        out.append(bits & 0xFF)
    return bytes(out)


def rle_escape(data: bytes) -> bytes:
    """Literal RLE: no runs, `0x90` escaped. Inverse of `_rle_decode`."""
    out = bytearray()
    for byte in data:
        out.append(byte)
        if byte == imp.RLE_MARKER:
            out.append(0)
    return bytes(out)


def make_pic(width: int, height: int, pixels: bytes,
             palette: bytes | None = None, max_bits: int = 11) -> bytes:
    """A PicV3 file carrying `pixels`, optionally with an `M0` palette."""
    out = bytearray()
    if palette is not None:
        body = bytes([0, 255]) + palette
        out += b"M0" + struct.pack("<H", len(body)) + body
    stream = pack_codes(list(rle_escape(pixels)), max_bits)
    body = struct.pack("<HHB", width, height, max_bits) + stream
    out += b"X0" + struct.pack("<H", len(body)) + body
    return bytes(out)


def ramp_palette() -> bytes:
    """256 distinguishable colours, so a wrong index is a wrong pixel."""
    return bytes(bytearray(
        b for i in range(256) for b in (i, (i * 7) & 0xFF, (i * 13) & 0xFF)))


def masked_pixels(image: bytes, mask: bytes, width: int,
                  height: int) -> bytes:
    """Interleave an image half and a mask half into `.pic` scanlines."""
    out = bytearray()
    for y in range(height):
        out += image[y * width:(y + 1) * width]
        out += mask[y * width:(y + 1) * width]
    return bytes(out)


def read_png(data: bytes) -> tuple[int, int, int, bytes]:
    """A filter-0 PNG back to `(width, height, channels, pixels)`.

    Only what `write_png` writes; the standard library and nothing else,
    so the suite has no Pillow dependency.
    """
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "not a PNG"
    offset = 8
    width = height = channels = 0
    raw = b""
    while offset < len(data):
        length = struct.unpack_from(">I", data, offset)[0]
        tag = data[offset + 4:offset + 8]
        body = data[offset + 8:offset + 8 + length]
        crc = struct.unpack_from(">I", data, offset + 8 + length)[0]
        assert crc == zlib.crc32(tag + body) & 0xFFFFFFFF, "bad CRC"
        if tag == b"IHDR":
            width, height, depth, colour = struct.unpack(">IIBB", body[:10])
            assert depth == 8
            channels = 4 if colour == 6 else 3
        elif tag == b"IDAT":
            raw = zlib.decompress(body)
        offset += 12 + length
    stride = width * channels
    pixels = bytearray()
    for y in range(height):
        assert raw[y * (stride + 1)] == 0, "filter is not 0"
        pixels += raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)]
    return width, height, channels, bytes(pixels)


# ------------------------------------------------------------------- LZW ---

class TestLzwBitStream(unittest.TestCase):
    """The bit packing and the fixed width schedule, pinned by number."""

    def test_codes_are_little_endian_and_nine_bits_wide(self):
        # 0xFF 0x01 = bits 0-7 set, bit 8 set -> 0b111111111 = 511.
        self.assertEqual(imp._lzw_codes(b"\xff\x01", 11)[0], 511)

    def test_a_code_spans_bytes_low_bits_first(self):
        # 0x00 0x02 -> bits 0-8 are 0,0,0,0,0,0,0,0,0 except bit 9,
        # which belongs to the SECOND code, so the first code is 0.
        self.assertEqual(imp._lzw_codes(b"\x00\x02\x00", 11)[0], 0)
        self.assertEqual(imp._lzw_codes(b"\x00\x02\x00", 11)[1], 1)

    def test_width_schedule_is_9_then_10_then_11_then_back_to_9(self):
        # 1 000 bytes = 8 000 bits. 256 codes at 9 = 2 304, then 512 at
        # 10 = 5 120 (7 424 used), leaving 576 bits = 52 codes at 11.
        self.assertEqual(len(imp._lzw_codes(b"\x00" * 1000, 11)),
                         256 + 512 + 52)

    def test_the_schedule_resets_after_1792_codes(self):
        # 1 792 codes exactly fill one group: 2 304 + 5 120 + 11 264 bits
        # = 18 688 = 2 336 bytes. The next byte starts a 9-bit code again,
        # so 2 337 bytes still yield 1 792 (no full code in 8 bits) and
        # 2 338 yield 1 793.
        self.assertEqual(len(imp._lzw_codes(b"\x00" * 2336, 11)), 1792)
        self.assertEqual(len(imp._lzw_codes(b"\x00" * 2338, 11)), 1793)

    def test_pack_codes_is_the_inverse(self):
        codes = [(i * 37) % 256 for i in range(4000)]
        self.assertEqual(imp._lzw_codes(pack_codes(codes), 11)[:len(codes)],
                         codes)


class TestLzwDictionary(unittest.TestCase):

    def test_literals_pass_straight_through(self):
        self.assertEqual(imp._lzw_expand([65, 66, 67], 11), b"ABC")

    def test_first_free_slot_is_257_not_256(self):
        self.assertEqual(imp.LZW_FIRST_CODE, 257)
        # 257 is the cursor on the second code, so it is the classic
        # "code not yet in the table" case: previous + previous[0].
        self.assertEqual(imp._lzw_expand([65, 257], 11), b"AAA")
        # After A,B the slot 257 holds "AB".
        self.assertEqual(imp._lzw_expand([65, 66, 257], 11), b"ABAB")

    def test_entry_256_exists_and_is_empty(self):
        self.assertEqual(imp._lzw_expand([65, 256, 66], 11), b"AB")

    def test_a_code_ahead_of_the_dictionary_is_refused(self):
        with self.assertRaises(ValueError):
            imp._lzw_expand([65, 300], 11)

    def test_a_group_must_start_with_a_literal(self):
        with self.assertRaises(ValueError):
            imp._lzw_expand([400], 11)

    def test_the_dictionary_restarts_with_the_width(self):
        # 1 792 codes per group; the 1 793rd starts a fresh dictionary, so
        # a back-reference that was valid before it is not valid after.
        codes = [65] + [257] * 1791          # fills the dictionary exactly
        out = imp._lzw_expand(codes, 11)
        self.assertTrue(out.startswith(b"AAA"))
        with self.assertRaises(ValueError):
            imp._lzw_expand(codes + [257], 11)


class TestRle(unittest.TestCase):

    def test_literals(self):
        self.assertEqual(imp._rle_decode(b"abc"), b"abc")

    def test_a_run_count_includes_the_byte_already_emitted(self):
        self.assertEqual(imp._rle_decode(b"a\x90\x04"), b"aaaa")

    def test_marker_zero_is_a_literal_marker(self):
        self.assertEqual(imp._rle_decode(b"a\x90\x00b"), b"a\x90b")

    def test_a_trailing_marker_is_a_literal(self):
        self.assertEqual(imp._rle_decode(b"a\x90"), b"a\x90")

    def test_empty(self):
        self.assertEqual(imp._rle_decode(b""), b"")


# ------------------------------------------------------------------- .pic --

class TestDecodePic(unittest.TestCase):

    def test_round_trips_a_picture_and_its_palette(self):
        pixels = bytes((x * 5 + y * 11) & 0xFF
                       for y in range(9) for x in range(7))
        data = make_pic(7, 9, pixels, ramp_palette())
        width, height, out, palette = imp.decode_pic(data)
        self.assertEqual((width, height), (7, 9))
        self.assertEqual(out, pixels)
        self.assertEqual(palette, ramp_palette())

    def test_a_run_of_one_colour_survives_the_rle_layer(self):
        pixels = bytes([200]) * 900
        width, height, out, _ = imp.decode_pic(make_pic(30, 30, pixels))
        self.assertEqual((width, height, out), (30, 30, pixels))

    def test_no_palette_block_reports_none(self):
        self.assertIsNone(imp.decode_pic(make_pic(2, 2, b"\1\2\3\4"))[3])

    def test_a_partial_palette_lands_at_its_own_offset(self):
        body = bytes([4, 5]) + b"\x01\x02\x03\x0a\x0b\x0c"
        data = (b"M1" + struct.pack("<H", len(body)) + body
                + make_pic(2, 2, b"\4\4\5\5"))
        palette = imp.decode_pic(data)[3]
        self.assertEqual(palette[12:18], b"\x01\x02\x03\x0a\x0b\x0c")
        self.assertEqual(palette[:12], bytes(12))

    def test_a_short_image_is_padded_with_255(self):
        # Three of the four pixels are coded; the fourth is padding.
        data = make_pic(2, 2, b"\1\2\3")
        self.assertEqual(imp.decode_pic(data)[2], b"\1\2\3\xff")

    def test_a_png_wearing_a_pic_name_is_refused(self):
        with self.assertRaises(ValueError):
            imp.decode_pic(b"\x89PNG\r\n\x1a\n" + bytes(64))

    def test_an_unimplemented_block_says_so(self):
        data = b"C0" + struct.pack("<H", 2) + b"\0\0" + make_pic(1, 1, b"\1")
        with self.assertRaisesRegex(ValueError, "C0"):
            imp.decode_pic(data)

    def test_a_silly_size_is_refused(self):
        body = struct.pack("<HHB", 0, 10, 11)
        with self.assertRaises(ValueError):
            imp.decode_pic(b"X0" + struct.pack("<H", len(body)) + body)

    def test_a_silly_code_width_is_refused(self):
        body = struct.pack("<HHB", 2, 2, 3)
        with self.assertRaises(ValueError):
            imp.decode_pic(b"X0" + struct.pack("<H", len(body)) + body)


class TestReadPicPalette(unittest.TestCase):
    """The palette-only reader, which must not decompress the image."""

    def test_reads_a_full_palette(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "a.pic"
            path.write_bytes(make_pic(2, 2, b"\1\2\3\4", ramp_palette()))
            self.assertEqual(imp.read_pic_palette(path), ramp_palette())

    def test_refuses_a_partial_palette_rather_than_padding_it(self):
        body = bytes([0, 3]) + bytes(12)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "a.pic"
            path.write_bytes(b"M0" + struct.pack("<H", len(body)) + body)
            self.assertIsNone(imp.read_pic_palette(path))

    def test_a_non_pic_file_is_none_not_an_exception(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "a.pic"
            path.write_bytes(b"\x89PNG\r\n\x1a\n" + bytes(32))
            self.assertIsNone(imp.read_pic_palette(path))

    def test_a_missing_file_is_none(self):
        self.assertIsNone(imp.read_pic_palette(Path("/nope/nothing.pic")))


# ------------------------------------------------------------ image+mask --

class TestSplitImageMask(unittest.TestCase):
    """Polarity is MEASURED off the border, never assumed."""

    def _pair(self, clear: int, opaque: int):
        # A 4x4 picture with a solid 2x2 core and a transparent border.
        image = bytes([7] * 16)
        mask = bytearray([clear] * 16)
        for y in (1, 2):
            for x in (1, 2):
                mask[y * 4 + x] = opaque
        return masked_pixels(image, bytes(mask), 4, 4)

    def test_255_means_transparent_when_the_border_is_255(self):
        half, image, alpha = imp.split_image_mask(8, 4, self._pair(255, 0))
        self.assertEqual(half, 4)
        self.assertEqual(image, bytes([7] * 16))
        self.assertEqual(alpha[0], 0)
        self.assertEqual(alpha[5], 255)

    def test_0_means_transparent_when_the_border_is_0(self):
        # The same picture with the mask inverted must come out the same.
        _, _, alpha = imp.split_image_mask(8, 4, self._pair(0, 255))
        self.assertEqual(alpha[0], 0)
        self.assertEqual(alpha[5], 255)

    def test_a_uniform_mask_is_fully_opaque(self):
        pixels = masked_pixels(bytes(16), bytes([255] * 16), 4, 4)
        _, _, alpha = imp.split_image_mask(8, 4, pixels)
        self.assertEqual(set(alpha), {255})

    def test_a_non_binary_mask_is_refused(self):
        pixels = masked_pixels(bytes(16), bytes(range(16)), 4, 4)
        with self.assertRaises(ValueError):
            imp.split_image_mask(8, 4, pixels)

    def test_an_odd_width_is_refused(self):
        with self.assertRaises(ValueError):
            imp.split_image_mask(7, 1, bytes(7))


class TestPaint(unittest.TestCase):

    def test_without_a_mask_index_0_is_transparent(self):
        out = imp.paint(b"\0\1", ramp_palette())
        self.assertEqual(out[3], 0)
        self.assertEqual(out[7], 255)

    def test_with_a_mask_index_0_is_a_real_colour(self):
        # 020.pic and 054.pic both have opaque index-0 pixels.
        out = imp.paint(b"\0\1", ramp_palette(), alpha=b"\xff\x00")
        self.assertEqual(out[3], 255)
        self.assertEqual(out[7], 0)

    def test_colours_come_from_the_palette(self):
        out = imp.paint(b"\x05", ramp_palette())
        self.assertEqual(out[:3], bytes([5, 35, 65]))


class TestWritePng(unittest.TestCase):

    def test_rgba_round_trips(self):
        pixels = bytes(range(24))
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "a.png"
            imp.write_png(path, 3, 2, pixels, alpha=True)
            self.assertEqual(read_png(path.read_bytes()), (3, 2, 4, pixels))

    def test_rgb_round_trips(self):
        pixels = bytes(range(18))
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "a.png"
            imp.write_png(path, 3, 2, pixels)
            self.assertEqual(read_png(path.read_bytes()), (3, 2, 3, pixels))


# ----------------------------------------------------------------- names --

class TestNames(unittest.TestCase):

    def test_deckfaces_has_the_55_the_count_line_claims(self):
        self.assertEqual(len(imp.ROGUE_NAMES), 55)

    def test_names_are_unique_and_file_safe(self):
        self.assertEqual(len(set(imp.ROGUE_NAMES)), 55)
        for name in imp.ROGUE_NAMES:
            self.assertRegex(name, r"^[a-z0-9_-]+$", name)

    def test_the_slots_are_one_based(self):
        self.assertEqual(imp.rogue_name(1), "rogue_witch")
        self.assertEqual(imp.rogue_name(2), "rogue_undead_knight")
        self.assertEqual(imp.rogue_name(55), "rogue_uber_villain")

    def test_a_slot_with_no_name_says_so_by_index(self):
        self.assertEqual(imp.rogue_name(0), "rogue_face_00")
        self.assertEqual(imp.rogue_name(56), "rogue_face_56")

    def test_no_rogue_can_shadow_a_player_face(self):
        players = set(imp.PORTRAIT_NAMES) | {imp.PLAYER_FACE_NAME}
        rogues = {imp.rogue_name(slot) for slot in range(1, 56)}
        self.assertEqual(players & rogues, set())

    def test_the_prefix_keeps_the_55_together_when_sorted(self):
        # PortraitLibrary.all() sorts one flat list by display name; the
        # rogues must come out as one unbroken run.
        every = sorted(list(imp.PORTRAIT_NAMES) + [imp.PLAYER_FACE_NAME]
                       + [imp.rogue_name(s) for s in range(1, 56)])
        first = every.index("rogue_aga_galneer")
        block = every[first:first + 55]
        self.assertTrue(all(n.startswith(imp.ROGUE_PREFIX) for n in block))
        self.assertEqual(len(block), 55)

    def test_player_names_are_unchanged(self):
        self.assertEqual(len(imp.PORTRAIT_NAMES), 14)
        self.assertEqual(imp.portrait_name(0), "melody_whisp")
        self.assertEqual(imp.portrait_name(13), "keleena")


# ------------------------------------------------------------- the steps --

def tr_file(path: Path, palette: bytes) -> None:
    """A `.tr` text palette, the way the original writes them."""
    path.write_text("".join(
        "%d - %d %d %d\n" % (i, palette[i * 3], palette[i * 3 + 1],
                             palette[i * 3 + 2]) for i in range(256)))


def face_pic(seed: int) -> bytes:
    """A 276x170 image+mask `.pic` the rogue step will accept."""
    width, height = imp.ROGUE_CELL
    image = bytes(((x + y + seed) & 0xFF) or 1
                  for y in range(height) for x in range(width))
    mask = bytearray([255] * (width * height))
    for y in range(2, height - 2):
        for x in range(2, width - 2):
            mask[y * width + x] = 0
    return make_pic(width * 2, height,
                    masked_pixels(image, bytes(mask), width, height))


class TestRogueStep(unittest.TestCase):

    def _run(self, files: dict[str, bytes], palette: bool = True):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = Path(tmp.name)
        source = root / "MagicTG" / "Faces"
        source.mkdir(parents=True)
        for name, data in files.items():
            (source / name).write_bytes(data)
        if palette:
            tr_file(root / "MagicTG" / "duelpalall.tr", ramp_palette())
        out = root / "out"
        index = imp.build_index([root])
        log = io.StringIO()
        with redirect_stdout(log):
            written = imp._rogues_from_raw(index, out)
        names = sorted(p.name for p in out.glob("*.png")) \
            if out.is_dir() else []
        return written, names, log.getvalue()

    def test_writes_a_named_face(self):
        written, names, _ = self._run({"001.pic": face_pic(1)})
        self.assertEqual(written, 1)
        self.assertEqual(names, ["rogue_witch.png"])

    def test_the_written_face_is_the_picture_half_with_the_mask_as_alpha(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = Path(tmp.name)
        (root / "Faces").mkdir(parents=True)
        (root / "Faces" / "003.pic").write_bytes(face_pic(3))
        tr_file(root / "duelpalall.tr", ramp_palette())
        out = root / "out"
        with redirect_stdout(io.StringIO()):
            imp._rogues_from_raw(imp.build_index([root]), out)
        width, height, channels, pixels = read_png(
            (out / "rogue_warlock.png").read_bytes())
        self.assertEqual((width, height, channels),
                         (imp.ROGUE_CELL[0], imp.ROGUE_CELL[1], 4))
        self.assertEqual(pixels[3], 0)                 # border: masked out
        middle = (height // 2) * width + width // 2
        self.assertEqual(pixels[middle * 4 + 3], 255)  # core: opaque

    def test_the_duplicate_end_caps_are_dropped(self):
        written, names, _ = self._run({
            "000.pic": face_pic(1), "001.pic": face_pic(1),
            "055.pic": face_pic(55), "056.pic": face_pic(55)})
        self.assertEqual(written, 2)
        self.assertEqual(names, ["rogue_uber_villain.png", "rogue_witch.png"])

    def test_an_unnamed_slot_that_is_NOT_a_duplicate_is_kept_by_index(self):
        written, names, log = self._run({
            "001.pic": face_pic(1), "056.pic": face_pic(9)})
        self.assertEqual(written, 2)
        self.assertIn("rogue_face_56.png", names)
        self.assertIn("no @DECKFACES name", log)

    def test_one_unreadable_file_does_not_stop_the_others(self):
        written, names, log = self._run({
            "001.pic": face_pic(1), "002.pic": b"not a pic at all"})
        self.assertEqual(written, 1)
        self.assertEqual(names, ["rogue_witch.png"])
        self.assertIn("skipped 002.pic", log)

    def test_a_wrong_sized_pic_is_skipped_not_written(self):
        written, _, log = self._run({"002.pic": make_pic(8, 4, bytes(32))})
        self.assertEqual(written, 0)
        self.assertIn("skipped 002.pic", log)

    def test_no_palette_means_no_faces_and_no_crash(self):
        written, names, log = self._run({"001.pic": face_pic(1)},
                                        palette=False)
        self.assertEqual((written, names), (0, []))
        self.assertIn("no palette", log)

    def test_no_faces_at_all_is_simply_zero(self):
        written, _, log = self._run({})
        self.assertEqual((written, log), (0, ""))


class TestImportPortraitsIsNeverFatal(unittest.TestCase):
    """The whole step against an empty source, and against junk."""

    def test_an_empty_source_reports_and_returns(self):
        with tempfile.TemporaryDirectory() as tmp:
            log = io.StringIO()
            with redirect_stdout(log):
                imp.import_portraits({}, Path(tmp))
            self.assertIn("no face art found", log.getvalue())

    def test_junk_named_like_the_originals_reports_and_returns(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name in ("16faces.spr", "face.pic", "001.pic",
                         "pedstls.pic", "duelpalall.tr", "advfac64.pic"):
                (root / name).write_bytes(b"junk" * 9)
            log = io.StringIO()
            with redirect_stdout(log):
                imp.import_portraits(imp.build_index([root]), root / "out")
                imp.import_pic_screens(imp.build_index([root]), root)
            self.assertIn("no face art found", log.getvalue())


class TestPicScreens(unittest.TestCase):

    def test_a_screen_with_its_own_palette_is_decoded(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            pixels = bytes(range(256)) * 4
            (root / "Advfac64.pic").write_bytes(
                make_pic(32, 32, pixels, ramp_palette()))
            with redirect_stdout(io.StringIO()):
                imp.import_pic_screens(imp.build_index([root]), root)
            out = root / "character_select_background.png"
            width, height, channels, data = read_png(out.read_bytes())
            self.assertEqual((width, height, channels), (32, 32, 3))
            self.assertEqual(data[:3], ramp_palette()[:3])

    def test_a_screen_with_no_palette_is_skipped_with_a_reason(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "Advfac64.pic").write_bytes(make_pic(4, 4, bytes(16)))
            log = io.StringIO()
            with redirect_stdout(log):
                imp.import_pic_screens(imp.build_index([root]), root)
            self.assertIn("no palette of its own", log.getvalue())
            self.assertFalse(
                (root / "character_select_background.png").exists())


class TestSoundManifest(unittest.TestCase):
    """WHICH `Button.wav`, and WHEN was it written.

    Both halves of the 2026-09-03 audio audit. A 1997 install holds three
    files called `Button.wav` and the flat filename index picked between
    them by directory hash order, so the duel's buttons played the CD
    AutoPlay shell's 39-millisecond blip on the owner's machine and
    something else on anyone else's.
    """

    def _tree(self, files: dict[str, bytes | None]):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = Path(tmp.name)
        for name, data in files.items():
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data if data is not None else b"RIFF....WAVE")
        return root

    # ------------------------------------------------------- the index --

    def test_a_file_is_indexed_by_its_directory_as_well_as_its_name(self):
        root = self._tree({"Duelsounds/Button.wav": None})
        index = imp.build_index([root])
        self.assertIn("button.wav", index)
        self.assertIn("duelsounds/button.wav", index)
        self.assertEqual(index["button.wav"], index["duelsounds/button.wav"])

    def test_the_directory_key_tells_two_copies_apart(self):
        root = self._tree({"Duelsounds/Grey.wav": b"the duel folder's",
                           "Program/DuelSounds/Grey.wav": b"the source tree's"})
        index = imp.build_index([root])
        self.assertEqual(index["duelsounds/grey.wav"].read_bytes(),
                         b"the duel folder's")
        self.assertEqual(index["program/duelsounds/grey.wav"].read_bytes(),
                         b"the source tree's")

    # ------------------------------------------------- the button click --

    def test_the_button_click_is_the_duels_not_the_autoplay_blip(self):
        # The bug, exactly as the owner's install has it: autoplay's is
        # 1 732 bytes and 39 ms, the duel's is 75 270 and a real click.
        root = self._tree({"autoplay/Button.wav": b"A" * 1732,
                           "Sound/Button.wav": b"S" * 75270,
                           "Duelsounds/Button.wav": b"D" * 75270})
        index = imp.build_index([root])
        found = imp._first_of(index, imp.MANIFEST["sfx_button.wav"])
        self.assertEqual(found.parent.name, "Duelsounds")

    def test_the_button_click_never_falls_back_to_autoplay(self):
        # No bare `Button.wav` candidate at all: a tree with only the
        # AutoPlay copy must import NOTHING rather than that.
        root = self._tree({"autoplay/Button.wav": b"A" * 1732})
        index = imp.build_index([root])
        self.assertIsNone(imp._first_of(index, imp.MANIFEST["sfx_button.wav"]))

    def test_every_sound_asks_for_a_directory_first(self):
        for key, candidates in imp.MANIFEST.items():
            if not imp.is_sound_key(key):
                continue
            self.assertIn("/", candidates[0],
                          f"{key} must say which folder it means")

    def test_the_games_own_folder_beats_the_manalink_source_copy(self):
        root = self._tree({"Duelsounds/Grey.wav": b"installed",
                           "Program/DuelSounds/Grey.wav": b"source tree"})
        index = imp.build_index([root])
        found = imp._first_of(index, imp.MANIFEST["sfx_land_grey.wav"])
        self.assertEqual(found.read_bytes(), b"installed")

    # -------------------------------------------------- what is in there --

    def test_endphase_is_not_imported_because_a_phase_is_silent(self):
        # The owner's ruling, 2026-09-03: "The changing phases or combat
        # phases have no sound by themselves." `EndPhase.wav` is a real
        # 1997 file (WAV_ENDPHASE = 4) with nothing legitimate to play it,
        # so it stays out — importing it only tempts a future pass into
        # wiring a cue to a step boundary.
        self.assertNotIn("sfx_phase.wav", imp.MANIFEST)
        for candidates in imp.MANIFEST.values():
            for name in candidates:
                self.assertNotIn("endphase", name.lower())

    def test_the_music_is_the_twenty_seven_beds(self):
        music = [k for k in imp.MANIFEST if k.startswith("music_")]
        self.assertEqual(len(music), 27)
        for key in ("music_duel.wav", "music_location_0.wav",
                    "music_location_19.wav", "music_temple.wav",
                    "music_castle_white.wav", "music_castle_green.wav"):
            self.assertIn(key, music)
        # Stingers stay out: a one-shot inside a shuffle is a jump-scare.
        for name in ("music_wingame.wav", "music_dungeon.wav"):
            self.assertNotIn(name, music)

    def test_every_music_key_comes_from_the_sound_folder(self):
        for key, candidates in imp.MANIFEST.items():
            if key.startswith("music_"):
                self.assertTrue(candidates[0].startswith("Sound/"), key)

    # ------------------------------------------------------- the dates --

    def _report(self, chosen):
        log = io.StringIO()
        with redirect_stdout(log):
            imp.report_audio_dates(chosen)
        return log.getvalue()

    def test_a_patched_sound_is_named_as_a_patch(self):
        root = self._tree({"Duelsounds/Grey.wav": None})
        path = root / "Duelsounds" / "Grey.wav"
        stamp = datetime.datetime(2009, 3, 3).timestamp()
        os.utime(path, (stamp, stamp))
        out = self._report({"sfx_land_grey.wav": path})
        self.assertIn("2009", out)
        self.assertIn("LATER THAN 1997", out)
        self.assertIn("Provenance.md", out)

    def test_a_1997_sound_is_not_flagged(self):
        root = self._tree({"Duelsounds/Grey.wav": None})
        path = root / "Duelsounds" / "Grey.wav"
        stamp = datetime.datetime(1997, 8, 8).timestamp()
        os.utime(path, (stamp, stamp))
        out = self._report({"sfx_land_grey.wav": path})
        self.assertIn("1997", out)
        self.assertNotIn("LATER THAN 1997", out)

    def test_only_sounds_are_reported(self):
        root = self._tree({"Duelsounds/Grey.wav": None,
                           "Faces/001.pic": b"art"})
        out = self._report({"card_back": root / "Faces" / "001.pic"})
        self.assertEqual(out, "", "no sounds, nothing to say")


if __name__ == "__main__":
    unittest.main()

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
import json
import os
import re
import struct
import sys
import tempfile
import unittest
import zlib
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock

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

    def test_a_palette_block_cut_short_is_refused_not_shrunk(self):
        # HUNT 2026-10-21: an M0 block holding fewer bytes than its range
        # declares shrank the 768-byte table (a short slice assignment),
        # and the short palette crashed `_cut_masked_pic` — documented
        # NEVER RAISES — with an IndexError, or painted a cut PNG.
        body = bytes([0, 255]) + bytes(30)
        data = b"M0" + struct.pack("<H", len(body)) + body + make_pic(2, 2, b"\1\2\3\4")
        with self.assertRaisesRegex(ValueError, "palette"):
            imp.decode_pic(data)
        backwards = bytes([9, 3]) + bytes(30)
        data = b"M0" + struct.pack("<H", len(backwards)) + backwards + make_pic(2, 2, b"\1\2\3\4")
        with self.assertRaisesRegex(ValueError, "palette"):
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
            self.assertIn("no palette in it and none beside it",
                      log.getvalue())
            self.assertFalse(
                (root / "character_select_background.png").exists())


def tr_palette(palette: bytes) -> str:
    """768 RGB bytes as a `.tr` text palette — the inverse of
    `read_tr_palette`, which wants at least 200 named entries."""
    return "".join("%3d - %3d %3d %3d - 0 0 0\n"
                   % (i, palette[i * 3], palette[i * 3 + 1], palette[i * 3 + 2])
                   for i in range(256))


class RawStepCase(unittest.TestCase):
    """Shared plumbing for the steps that run the importer end to end."""

    def _run(self, root: Path, dest: Path) -> str:
        """The importer's own main, so what is pinned is what a player
        gets rather than a helper called the way a test finds handy. There
        is no other door: the 1997 install is the only source (the
        owner's rulings, 2026-09-09 and 2026-10-15)."""
        argv = sys.argv
        sys.argv = ["import_original.py", "--source", str(root),
                    "--dest", str(dest), "--no-videos"]
        log = io.StringIO()
        try:
            with redirect_stdout(log):
                self.assertEqual(imp.main(), 0)
        finally:
            sys.argv = argv
        return log.getvalue()


class TestTheGenericRawTexture(RawStepCase):
    """THE ONE PATH EVERY RAW 1997 PICTURE GOES DOWN (2026-09-09).

    Ninety MANIFEST rows used to name only somebody else's `*.pic.png`,
    so a 1997 disc alone reached 68 of 163 keys while the files sat
    unread in `Duelart/`, `Cardart/` and `Dbart/`. Every texture row now
    names the RAW file first and the copy loop DECODES anything that is
    not already a PNG. These pin the two halves of that rule — the
    palette a bare-index file takes, and the transparency it gets — on a
    key that has nothing else special about it.
    """

    def _tree(self, tmp: str, own_palette: bool = False) -> tuple[Path, bytes]:
        root = Path(tmp) / "MagicTG"
        (root / "Duelart").mkdir(parents=True)
        # 120x88 is `Life_Whitepatt.pic`'s own size; index 255 is in it,
        # which is the point of the transparency half of the rule.
        indices = bytes(bytearray((x * 3 + y) % 256
                                  for y in range(88) for x in range(120)))
        (root / "Duelart" / "Life_Whitepatt.pic").write_bytes(
            make_pic(120, 88, indices,
                     palette=ramp_palette() if own_palette else None))
        (root / "Duelpalall.tr").write_text(tr_palette(ramp_palette()))
        return root, indices

    def test_a_bare_index_pic_is_painted_with_the_duel_palette(self):
        with tempfile.TemporaryDirectory() as tmp:
            root, indices = self._tree(tmp)
            dest = Path(tmp) / "skin"
            log = self._run(root, dest)
            width, height, channels, pixels = read_png(
                (dest / "life_panel_white.png").read_bytes())
            self.assertEqual((width, height, channels), (120, 88, 4))
            palette = ramp_palette()
            for i, value in enumerate(indices):
                self.assertEqual(pixels[i * 4:i * 4 + 3],
                                 palette[value * 3:value * 3 + 3])
            self.assertIn("decoded 120x88, palette: Duelpalall.tr", log)
            self.assertNotIn("  - life_panel_white", log)

    def test_index_255_is_the_transparent_one(self):
        """`mp_pic_tools/pic2png.py` hangs tRNS on 255 and the 1997 masks
        agree: 255 is the border value of every mask half in the set."""
        with tempfile.TemporaryDirectory() as tmp:
            root, indices = self._tree(tmp)
            dest = Path(tmp) / "skin"
            self._run(root, dest)
            _, _, _, pixels = read_png(
                (dest / "life_panel_white.png").read_bytes())
            self.assertIn(255, indices, "the fixture has ink to key out")
            for i, value in enumerate(indices):
                self.assertEqual(pixels[i * 4 + 3], 0 if value == 255 else 255,
                                 "alpha at pixel %d (index %d)" % (i, value))

    def test_a_pic_with_its_own_palette_is_opaque_rgb(self):
        """`Title.pic` is the counter-example that fixes the rule: 174 of
        its pixels are index 255, its own `M0` block says that colour is
        white, and they are part of the picture. A backdrop that carries
        its colours owns index 255 too."""
        with tempfile.TemporaryDirectory() as tmp:
            root, indices = self._tree(tmp, own_palette=True)
            dest = Path(tmp) / "skin"
            log = self._run(root, dest)
            width, height, channels, pixels = read_png(
                (dest / "life_panel_white.png").read_bytes())
            self.assertEqual((width, height, channels), (120, 88, 3))
            self.assertIn("palette: its own", log)

    def test_a_broken_pic_is_reported_and_the_key_is_missing(self):
        with tempfile.TemporaryDirectory() as tmp:
            root, _ = self._tree(tmp)
            (root / "Duelart" / "Life_Whitepatt.pic").write_bytes(b"<html>404")
            dest = Path(tmp) / "skin"
            log = self._run(root, dest)
            self.assertIn("SKIPPED Life_Whitepatt.pic", log)
            self.assertFalse((dest / "life_panel_white.png").exists())
            self.assertIn("  - life_panel_white", log)

    def test_no_palette_beside_it_is_reported_not_raised(self):
        with tempfile.TemporaryDirectory() as tmp:
            root, _ = self._tree(tmp)
            (root / "Duelpalall.tr").unlink()
            dest = Path(tmp) / "skin"
            log = self._run(root, dest)
            self.assertIn("no palette in it and none beside it", log)
            self.assertFalse((dest / "life_panel_white.png").exists())

    def test_a_png_wearing_a_pic_name_is_refused(self):
        """Every `*.pic` in a Manalink install's `Program/DBArt/` and
        `Program/CardArt/` is a PNG wearing the 1997 name
        (Provenance.md). Until 2026-10-15 those were COPIED as the
        fallback; now no 1997 file is a PNG, so one under a 1997 name is
        a later restyle and the key is missing rather than Manalink's
        (the owner: *"Yes remove manalink fallbacks"*)."""
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "Program" / "CardArt"
            root.mkdir(parents=True)
            imp.write_png(root / "Summon.pic", 4, 2, bytes(24))
            dest = Path(tmp) / "skin"
            log = self._run(Path(tmp), dest)
            self.assertFalse((dest / "summon_sick.png").exists())
            self.assertIn("only as a PNG under a 1997", log)
            self.assertIn("  - summon_sick", log)


class TestSprFramePadding(unittest.TestCase):
    """A `.SPR` FRAME MAY END MID-ROW, and ten of a 1997 install's do.

    `spr2png.py` breaks out of the row loop the moment it has consumed
    the frame's declared byte count, BEFORE it sanity-checks the run —
    and this decoder did not, so a frame padded with MSVC's `0xCD` fill
    read `0xCD 0xCD` as a 205-pixel run and the file was refused whole.
    Ten of the owner's 344 `.spr` files are like that, all adventure art
    (`Worlds.spr`, `Begin.spr`, `Ttsprite.spr`, `Spr/Locatn02.spr`,
    `Spr800/Land.spr`, five more under `Spr1024/`). Fixed 2026-09-09;
    the other 334 decode byte-identically either way.
    """

    def _frame(self, width: int, height: int, rows: bytes,
               pad: bytes) -> bytes:
        body = bytes(rows) + pad
        return struct.pack("<IHHHHHH", len(body) + 16, width, height,
                           0, 0, 0, 0) + body

    def test_trailing_0xcd_padding_is_not_a_run(self):
        width, height = 8, 4
        rows = bytearray()
        for _ in range(2):                    # only two of the four rows
            rows += bytes([0, 0xFE, width]) + bytes([7] * width)
        # `... FF CD CD` is what the ten real files end with — a row
        # terminator and two bytes of uninitialised fill, landing the
        # reader exactly on the frame's declared end.
        data = self._frame(width, height, bytes(rows), b"\xff\xcd\xcd")
        data += struct.pack("<I", 0xFFFFFFFF)
        frames = imp.decode_spr(data)
        self.assertEqual(len(frames), 1)
        got_w, got_h, pixels = frames[0]
        self.assertEqual((got_w, got_h), (width, height))
        self.assertEqual(len(pixels), width * height)
        self.assertEqual(pixels[:width], bytes([7] * width))
        self.assertEqual(pixels[2 * width:], bytes(2 * width),
                         "the rows the frame never held are transparent")

    def test_a_run_that_really_is_too_wide_is_still_refused(self):
        """The guard must not swallow a genuinely corrupt frame: a run
        past the width WITH bytes left in the frame is still an error."""
        width, height = 8, 2
        rows = bytes([0, 0xFE, 200]) + bytes([7] * 200)
        data = self._frame(width, height, rows, b"")
        data += struct.pack("<I", 0xFFFFFFFF)
        with self.assertRaises(ValueError):
            imp.decode_spr(data)


class TestPaletteFamilies(unittest.TestCase):
    """WHICH PALETTE A RAW FILE TAKES, and it is decided by its FORMAT.

    Measured 2026-09-09 against the owner's install with the s30 tree
    beside it as an oracle: `Duelpalall.tr` reproduces every `.pic` in
    `Duelart/`, `Cardart/` and `Dbart/`, and `Todpal.tr` — `spr2png.py`'s
    own default — is the one that puts a white sun, a blue drop, a green
    tree, a red dragon and a black skull in `Statbutt.spr`'s first five
    cells. Swapping them renders either file in mud.
    """

    def test_a_pic_takes_the_duel_palette(self):
        self.assertEqual(imp.PIC_PALETTE[0].lower(), "duelpalall.tr")

    def test_a_spr_sheet_takes_todpal(self):
        self.assertEqual(imp.SPR_PALETTE, ["Todpal.tr"])

    def test_the_pic_fallbacks_are_1997_files_with_a_palette_block(self):
        """A player's copy can be missing the `.tr`; these two carry a
        full `M0` of their own and differ from it only at 191 and 255."""
        for name in imp.PIC_PALETTE[1:]:
            self.assertTrue(name.lower().endswith(".pic"), name)

    def test_the_transparent_index_is_255(self):
        self.assertEqual(imp.PIC_CLEAR, 255)


class TestCounterStones(RawStepCase):
    """THE COUNTER STRIP, `Cardcounters.pic`.

    It was the FIRST row to be decoded rather than copied (2026-09-08)
    and since 2026-09-09 it is simply one of ninety-odd that are — the
    special-case step it used to have is gone. What still has to hold is
    what `CounterMarks.tile()` needs: the strip is ONE COLUMN of 25 cells
    whose 25th is the mask every stone shares, so it must arrive WHOLE
    and unscaled — never split down the middle like the image+mask pairs
    beside it, never resized — and a player whose only source is their
    own 1997 disc must get it.
    """

    ## A stand-in strip: 25 cells of 24x30, cell N painted with index N,
    ## the mask cell 254 inside and 255 outside — the shape of the real
    ## file, none of its bytes.
    WIDTH, HEIGHT = 24, 750

    def strip_indices(self) -> bytes:
        out = bytearray()
        for row in range(25):
            for y in range(30):
                for x in range(self.WIDTH):
                    edge = x == 0 or x == self.WIDTH - 1 or y == 0 or y == 29
                    if row == 24:        # the shared mask cell
                        out.append(255 if edge else 254)
                    else:
                        out.append(255 if (x + y) % 7 == 0 else row)
        return bytes(out)

    def test_the_manifest_row_names_the_raw_file_and_nothing_else(self):
        """Raw-first since 2026-09-09, raw-ONLY since 2026-10-15: s30's
        `card/` and `screens/duel/` conversions were candidates until the
        owner's *"remove any s30 dependency or s30 fallback"*."""
        self.assertEqual(imp.MANIFEST["card_counters"],
                         ["Cardart/Cardcounters.pic", "Cardcounters.pic"])

    # ------------------------------------------------ the raw strip --

    def _raw_tree(self, tmp: str, width: int = 0, height: int = 0) -> Path:
        root = Path(tmp) / "MagicTG"
        (root / "Cardart").mkdir(parents=True)
        indices = self.strip_indices()
        (root / "Cardart" / "Cardcounters.pic").write_bytes(
            make_pic(width or self.WIDTH, height or self.HEIGHT, indices))
        (root / "Duelpalall.tr").write_text(tr_palette(ramp_palette()))
        return root

    def test_a_raw_install_decodes_the_strip_against_the_duel_palette(self):
        """The 1997 file has no palette block, so this is the whole
        point: nothing but `Cardcounters.pic` and `Duelpalall.tr` in the
        tree, and the strip comes out at its own size in RGBA."""
        with tempfile.TemporaryDirectory() as tmp:
            root = self._raw_tree(tmp)
            dest = Path(tmp) / "skin"
            log = self._run(root, dest)
            width, height, channels, pixels = read_png(
                (dest / "card_counters.png").read_bytes())
            self.assertEqual((width, height, channels),
                             (self.WIDTH, self.HEIGHT, 4))
            self.assertIn("(decoded 24x750, palette: Duelpalall.tr)", log)
            self.assertNotIn("  - card_counters", log,
                             "not missing: it was imported")

    def test_index_255_is_the_only_transparent_one(self):
        """255 is the glyph's ink INSIDE a stone and the mask cell's
        outside, and it is what the s30 conversion hangs its tRNS on.
        Index 0 is a real colour here, so `paint`'s no-mask rule would be
        wrong — the alpha is handed to it."""
        with tempfile.TemporaryDirectory() as tmp:
            root = self._raw_tree(tmp)
            dest = Path(tmp) / "skin"
            self._run(root, dest)
            _, _, _, pixels = read_png((dest / "card_counters.png").read_bytes())
            indices = self.strip_indices()
            palette = ramp_palette()
            clear = {i for i, v in enumerate(indices) if v == imp.PIC_CLEAR}
            self.assertTrue(clear, "the fixture has ink to be transparent")
            for i, value in enumerate(indices):
                self.assertEqual(pixels[i * 4 + 3], 0 if i in clear else 255,
                                 "alpha at pixel %d (index %d)" % (i, value))
                self.assertEqual(pixels[i * 4:i * 4 + 3],
                                 palette[value * 3:value * 3 + 3])
            corner = 24 * 30 * self.WIDTH        # (0, 0) of the mask cell
            self.assertEqual(pixels[corner * 4 + 3], 0,
                             "the mask cell's corner is clear, which is what "
                             "CounterMarks.tile reads the polarity off")

    def test_a_conversion_is_never_a_source(self):
        """A tree holding nothing but s30's converted strip reaches no
        key: there is no door for it any more (the maintainer's
        `--allow-conversions` went on 2026-10-15). The owner, 2026-09-09:
        *"our original skin/art creation tool should only use original
        1997 install and NOT s30 that is reimplementation project
        itself"*."""
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "s30"
            converted = root / "card" / "Cardcounters.pic.png"
            converted.parent.mkdir(parents=True)
            imp.write_png(converted, self.WIDTH, self.HEIGHT,
                          bytes(self.WIDTH * self.HEIGHT * 3))
            dest = Path(tmp) / "skin"
            log = self._run(root, dest)
            self.assertFalse((dest / "card_counters.png").exists())
            self.assertIn("  - card_counters", log)

    def test_a_file_that_is_not_a_pic_is_reported_not_raised(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = self._raw_tree(tmp)
            (root / "Cardart" / "Cardcounters.pic").write_bytes(b"<html>404")
            dest = Path(tmp) / "skin"
            log = self._run(root, dest)
            self.assertIn("SKIPPED Cardcounters.pic", log)
            self.assertFalse((dest / "card_counters.png").exists())

    def test_a_manalink_bmp_is_never_the_source(self):
        """Provenance.md: a `.bmp` in an install is never a 1997 file.
        `Program/CardArt/CardCounters.bmp` is Manalink's own strip."""
        for name in imp.MANIFEST["card_counters"]:
            self.assertFalse(name.lower().endswith(".bmp"), name)


class TestDamageMarkerPair(RawStepCase):
    """`damage_marker` — the first of the two ROADMAP named as hard.

    Its row was already raw-first, so the conversion was never tried and
    the key simply did not arrive: the copy loop refused `Damage.pic`
    because it is not a PNG. It decodes to 94x20 — a 47x20 picture beside
    a 47x20 mask — and its MASK IS THE PROOF OF THE PALETTE. The four
    values in it are `{0, 2, 190, 191}`, two dark and two light, and only
    with index 191 WHITE (which is what the LAST line of `Duelpalall.tr`
    says, and what half of s30's conversions render black) does that read
    as a silhouette on a pale ground. `MiniCard.masked_sprite` then takes
    the mask's own corner as the transparent tone, so what this has to
    deliver is a fully opaque pair with both tones intact.
    """

    def test_the_row_is_the_discs_own_dagger_alone(self):
        """Manalink's `Program/CardArt/Damage.pic` led this row from
        2026-09-09 (legibility). On 2026-10-15 the game took its OWN
        dagger for every player (`MiniCard.ALWAYS_OURS`: *"we build our
        own damage dagger just to be independent"*) and the owner removed
        the Manalink fallbacks, so the row is the 1997 file alone — kept,
        like the set symbols', so a player's skin folder holds their own
        disc's dagger."""
        self.assertEqual(imp.MANIFEST["damage_marker"], ["Damage.pic"])

    def test_the_pair_arrives_whole_with_the_mask_readable(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "MagicTG" / "Cardart"
            root.mkdir(parents=True)
            # 47 of picture then 47 of mask, per scanline: the mask's own
            # four tones, with the pale one on its border.
            image = bytes(bytearray((x + y) % 190
                                    for y in range(20) for x in range(47)))
            mask = bytearray()
            for y in range(20):
                for x in range(47):
                    edge = x in (0, 46) or y in (0, 19)
                    mask.append(191 if edge else (190, 0, 2)[(x + y) % 3])
            pixels = masked_pixels(image, bytes(mask), 47, 20)
            (root / "Damage.pic").write_bytes(make_pic(94, 20, pixels))
            (root.parent / "Duelpalall.tr").write_text(
                tr_palette(ramp_palette()))
            dest = Path(tmp) / "skin"
            self._run(root.parent.parent, dest)
            width, height, channels, out = read_png(
                (dest / "damage_marker.png").read_bytes())
            self.assertEqual((width, height, channels), (94, 20, 4),
                             "the pair arrives whole, never pre-split")
            palette = ramp_palette()
            for i, value in enumerate(pixels):
                self.assertEqual(out[i * 4:i * 4 + 3],
                                 palette[value * 3:value * 3 + 3])
                self.assertEqual(out[i * 4 + 3], 255,
                                 "no index 255 in it, so nothing is clear")
            # The corner of the MASK half is the pale tone, which is what
            # masked_sprite reads the polarity off.
            corner = 47
            self.assertEqual(out[corner * 4:corner * 4 + 3],
                             palette[191 * 3:191 * 3 + 3])


class TestSetIcons(RawStepCase):
    """THE SIX `set_icon_*` — the other one the ROADMAP named as hard.

    s30 converted the card art, not `Dbart/`, so there is NO conversion of
    these anywhere and the raw decode is the only way to them. The 1997
    files are 40x40 (`MagicTG/Dbart/Antiquit.pic` and its five
    neighbours), not the 35x36 the checkout's gitignored
    `assets/original/` held — those are Manalink's own greyscale restyle,
    a PNG wearing a `.pic` name, and since 2026-10-15 not a candidate.
    """

    NAMES = {"set_icon_atq": "Antiquit.pic", "set_icon_arn": "ArabNite.pic",
             "set_icon_past": "Astral.pic", "set_icon_drk": "Dark.pic",
             "set_icon_4ed": "Fourth.pic", "set_icon_leg": "Legends.pic"}

    def test_each_row_is_the_raw_1997_medallion_alone(self):
        """THE OWNER'S RULING, 2026-09-10, made complete on 2026-10-15. For
        one day these rows led with Manalink's restyle, because its gold
        glyph read better than the 1997 medallion in the enlarged card's
        14x17px symbol box. The game draws its OWN six glyphs for every
        player and reads neither import (`GameSkin.set_icon`), so what is
        left is INDEPENDENCE: the disc's own file, and since the owner's
        *"Yes remove manalink fallbacks"* nothing besides it."""
        for key, raw in self.NAMES.items():
            self.assertEqual(imp.MANIFEST[key], [raw], key)

    def test_a_raw_dbart_icon_decodes_at_its_own_size(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "MagicTG"
            (root / "Dbart").mkdir(parents=True)
            indices = bytes(bytearray((x * 5 + y) % 200
                                      for y in range(40) for x in range(40)))
            (root / "Dbart" / "Antiquit.pic").write_bytes(
                make_pic(40, 40, indices))
            (root / "Duelpalall.tr").write_text(tr_palette(ramp_palette()))
            dest = Path(tmp) / "skin"
            log = self._run(root, dest)
            width, height, channels, pixels = read_png(
                (dest / "set_icon_atq.png").read_bytes())
            self.assertEqual((width, height, channels), (40, 40, 4))
            self.assertIn("decoded 40x40", log)
            palette = ramp_palette()
            for i, value in enumerate(indices):
                self.assertEqual(pixels[i * 4:i * 4 + 3],
                                 palette[value * 3:value * 3 + 3])


class TestSprSheet(RawStepCase):
    """`stat_buttons` <- `Statbutt.spr`, the one MANIFEST row whose 1997
    file is a SPRITE.

    THE FRAMES ARE NOT ALL THE SAME SIZE (5 of 48x48, 3 of 84x24, 3 of
    73x24, 3 of 49x24, one 25x161, one 15x18) and the sheet is a grid of
    48x48 cells, so a frame wider or taller than its cell is CLIPPED.
    That reproduces s30's own `Statbutt.spr.png` byte for byte on all
    36 864 indices — their tiler pastes at the same 48 px pitch and each
    overflow is overwritten by the next frame — and it does NOT copy
    `spr2png.py`'s tiler, whose `modulo = min(1240 // width, ...)` drops
    the tail of a sheet (Provenance.md: nine of fourteen portraits).
    """

    def _spr(self, frames: list[tuple[int, int, bytes]]) -> bytes:
        """A `.SPR` carrying `frames` — the inverse of `decode_spr`, in
        its simplest form: no empty lines above, one run per line."""
        out = bytearray()
        for width, height, pixels in frames:
            body = bytearray()
            for y in range(height):
                row = pixels[y * width:(y + 1) * width]
                body += bytes([0, 0xFE, len(row)]) + row
            head = struct.pack("<IHHHHHH", len(body) + 16, width, height,
                               0, 0, 0, 0)
            out += head + body
        return bytes(out) + struct.pack("<I", 0xFFFFFFFF)

    def test_a_frame_wider_than_its_cell_is_clipped_not_smeared(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "MagicTG"
            root.mkdir(parents=True)
            frames = [(48, 48, bytes([1] * (48 * 48))),
                      (84, 24, bytes([2] * (84 * 24)))]
            frames += [(48, 48, bytes([3 + i] * (48 * 48))) for i in range(14)]
            (root / "Statbutt.spr").write_bytes(self._spr(frames))
            (root / "Todpal.tr").write_text(tr_palette(ramp_palette()))
            dest = Path(tmp) / "skin"
            log = self._run(root, dest)
            width, height, channels, pixels = read_png(
                (dest / "stat_buttons.png").read_bytes())
            self.assertEqual((width, height, channels), (768, 48, 4))
            self.assertIn("palette: Todpal.tr", log)
            palette = ramp_palette()

            def at(x, y):
                i = (y * 768 + x) * 4
                return bytes(pixels[i:i + 3])
            self.assertEqual(at(4, 4), palette[3:6], "cell 0 is frame 0")
            self.assertEqual(at(52, 4), palette[6:9], "cell 1 is frame 1")
            self.assertEqual(at(100, 4), palette[9:12],
                             "cell 2 is frame 2, not frame 1's overflow")
            self.assertEqual(at(52, 40), bytes(3),
                             "a 24-tall frame does not fill its 48px cell")

    def test_index_0_is_the_sprite_formats_transparency(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "MagicTG"
            root.mkdir(parents=True)
            body = bytearray([1] * (48 * 48))
            body[0] = 0
            frames = [(48, 48, bytes(body))] * 16
            (root / "Statbutt.spr").write_bytes(self._spr(frames))
            (root / "Todpal.tr").write_text(tr_palette(ramp_palette()))
            dest = Path(tmp) / "skin"
            self._run(root, dest)
            _, _, _, pixels = read_png(
                (dest / "stat_buttons.png").read_bytes())
            self.assertEqual(pixels[3], 0, "index 0 is clear")
            self.assertEqual(pixels[7], 255)


class TestTheWorldSheets(TestSprSheet):
    """THE ADVENTURE'S WORLD (2026-10-22): the world screen's `.spr` sheets
    from `SPR/`, laid out WORLD_SHEETS' way, painted with the adventure
    screen's own palette (`Advfac64.pic`'s `M0` block, not `Todpal.tr`,
    which leaves out the indices the towns use), each beside a `.json` of
    its grid and every frame's anchor."""

    def _anchored(self, frames: list[tuple[int, int, bytes, int]]) -> bytes:
        out = bytearray()
        for width, height, pixels, top in frames:
            body = bytearray()
            for y in range(height):
                row = pixels[y * width:(y + 1) * width]
                body += bytes([0, 0xFE, len(row)]) + row
            out += struct.pack("<IHHhhhh", len(body) + 16, width, height, 0, top, 0, 0) + body
        return bytes(out) + struct.pack("<I", 0xFFFFFFFF)

    def test_a_world_sheet_comes_with_its_grid_and_anchors(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "MagicTG"
            (root / "SPR").mkdir(parents=True)
            tops = [1, -1, 61, -1, 7, -1]
            frames = [(128, 64, bytes([10 + i] * (128 * 64)), tops[i]) for i in range(6)]
            frames.append((3, 1, bytes(3), -1))   # the format's end marker
            (root / "SPR" / "LANDTILE.SPR").write_bytes(self._anchored(frames))
            world = ramp_palette()
            (root / "ADVFAC64.pic").write_bytes(make_pic(2, 2, bytes([1, 2, 3, 4]), world))
            (root / "Todpal.tr").write_text(tr_palette(bytes(255 - b for b in world)))
            dest = Path(tmp) / "skin"
            log = self._run(root, dest)
            self.assertIn("palette: ADVFAC64.pic", log)
            width, height, channels, pixels = read_png((dest / "world_landtile.png").read_bytes())
            self.assertEqual((width, height, channels), (768, 64, 4), "six to a row")
            at = (5 * 768 + 5) * 4
            self.assertEqual(bytes(pixels[at:at + 3]), world[10 * 3:10 * 3 + 3])
            side = json.loads((dest / "world_landtile.json").read_text())
            self.assertEqual((side["cols"], side["rows"], side["frames"]), (6, 1, 6))
            self.assertEqual((side["frame_width"], side["frame_height"]), (128, 64))
            self.assertEqual(side["tops"], tops, "every frame's anchor, -1 kept")

    def test_the_anchors_are_read_from_the_frame_headers(self):
        data = self._anchored([(4, 2, bytes(8), 56), (4, 2, bytes(8), -1)])
        self.assertEqual(imp.spr_frame_tops(data), [56, -1])

    def test_every_world_sheet_is_wired(self):
        # The world's own sprites are in Program/SPR/ (by resolution); the
        # world screen's icons, Worlds.spr and Amsprite.spr, the map's
        # Ttsprite.spr and the quest panel's sheets, in Program/.
        icons = {"world_magics": "worlds.spr", "world_amulets": "amsprite.spr",
                 "world_map_tiles": "ttsprite.spr", "quest_scroll": "questnew.spr",
                 "quest_clock": "clocknew.spr", "quest_sunmoon": "sunmoon.spr",
                 "quest_days": "daysnew.spr"}
        for key, (cells, width, height, columns) in imp.WORLD_SHEETS.items():
            if key in icons:
                self.assertEqual(imp.MANIFEST[key], [icons[key]], key)
            else:
                self.assertTrue(imp.MANIFEST[key][0].startswith("spr/"), key)
            self.assertEqual(imp.SPR_SHEETS[key], (imp.MANIFEST[key], cells, width, height))
            self.assertEqual(imp.SPR_COLUMNS[key], columns)
            self.assertEqual(imp.SPR_PALETTES[key][0], "Advfac64.pic")


class TestTheTitleMenuSprite(TestSprSheet):
    """`begin_menu` <- `Begin.spr` (2026-10-08): the 1997 title menu's
    sprite, EVERY frame — the owner: *"Lets import every frame there but
    we will use only icon for now"*. Fourteen 265x24 word strips and the
    four 24x24 states of the Celtic-knot bullet, one column, painted with
    the palette of the screen they stand on (`Menubak.pic`), not the
    adventure's `Todpal.tr`."""

    ## A row's runs are one byte each, so a 265-wide word row is written
    ## the way the 1997 file writes its lettering: ten clear pixels, then
    ## 255 of ink.
    CLEAR = 10

    def _frames(self) -> list[tuple[int, int, bytes]]:
        frames = []
        for i in range(14):
            row = bytes(self.CLEAR) + bytes([10 + i] * (265 - self.CLEAR))
            frames.append((265, 24, row * 24))
        frames += [(24, 24, bytes([40 + i] * (24 * 24))) for i in range(4)]
        return frames

    def _spr(self, frames: list[tuple[int, int, bytes]]) -> bytes:
        """`TestSprSheet._spr` with each row's leading clear pixels as
        the run's skip, so a row wider than 255 still fits its byte."""
        out = bytearray()
        for width, height, pixels in frames:
            body = bytearray()
            for y in range(height):
                row = pixels[y * width:(y + 1) * width]
                skip = len(row) - len(row.lstrip(b"\x00"))
                ink = row[skip:]
                body += bytes([skip, 0xFE, len(ink)]) + ink
            head = struct.pack("<IHHHHHH", len(body) + 16, width, height,
                               0, 0, 0, 0)
            out += head + body
        return bytes(out) + struct.pack("<I", 0xFFFFFFFF)

    def test_every_frame_is_one_row_of_a_single_column(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "MagicTG"
            root.mkdir(parents=True)
            (root / "BEGIN.SPR").write_bytes(self._spr(self._frames()))
            menu = ramp_palette()
            (root / "MENUBAK.PIC").write_bytes(
                make_pic(2, 2, bytes([1, 2, 3, 4]), menu))
            # The adventure palette beside it must NOT be the one used.
            other = bytes(255 - b for b in menu)
            (root / "Todpal.tr").write_text(tr_palette(other))
            dest = Path(tmp) / "skin"
            log = self._run(root, dest)
            width, height, channels, pixels = read_png(
                (dest / "begin_menu.png").read_bytes())
            self.assertEqual((width, height, channels), (265, 18 * 24, 4))
            self.assertIn("palette: MENUBAK.PIC", log)

            def at(x, y):
                i = (y * 265 + x) * 4
                return bytes(pixels[i:i + 4])
            for frame in range(14):
                index = 10 + frame
                self.assertEqual(at(200, frame * 24 + 5),
                                 menu[index * 3:index * 3 + 3] + b"\xff",
                                 "row %d is word frame %d" % (frame, frame))
            for state in range(4):
                index = 40 + state
                row = (14 + state) * 24
                self.assertEqual(at(5, row + 5),
                                 menu[index * 3:index * 3 + 3] + b"\xff",
                                 "row %d is bullet state %d" % (14 + state, state))
                self.assertEqual(at(100, row + 5)[3], 0,
                                 "a 24-wide bullet leaves the rest of its row clear")

    def test_the_row_names_the_raw_file_and_the_menu_palette(self):
        self.assertEqual(imp.MANIFEST["begin_menu"], ["Begin.spr"])
        self.assertEqual(imp.SPR_SHEETS["begin_menu"], (["Begin.spr"], 18, 265, 24))
        self.assertEqual(imp.SPR_COLUMNS["begin_menu"], 1)
        self.assertEqual(imp.SPR_PALETTES["begin_menu"], ["Menubak.pic"])
        self.assertNotIn("stat_buttons", imp.SPR_PALETTES,
                         "the adventure strip keeps Todpal.tr")

class TestAssembledSheets(RawStepCase):
    """THE TWO GRIDS 1997 NEVER SHIPPED AS ONE FILE, and the two that are
    OURS.

    `filter_icons` is the twenty-seven 40x40 medallions of `Dbart/` nine
    to a row in ASCII filename order, and `deck_slot_plaques` the ten
    117x100 `Bldr*` plaques five to a row — both matched cell by cell
    against s30's assembled sheet at 1.000 before being written this way,
    so `FilterBar.TYPE_CELL` keeps working. The lit and sunken filter
    sheets have no 1997 file at all: the install ships ONE state per
    medallion, so those two are DERIVED here and the summary says they
    are ours.
    """

    def test_the_filter_grid_is_27_cells_of_40_nine_to_a_row(self):
        names, cols, cell_w, cell_h = imp.PIC_SHEETS["filter_icons"]
        self.assertEqual((len(names), cols, cell_w, cell_h), (27, 9, 40, 40))
        self.assertEqual(names, sorted(names, key=str),
                         "ASCII filename order IS the grid")
        for name in names:
            self.assertTrue(name.endswith(".pic"), name)

    def test_the_plaque_sheet_is_the_b_row_over_the_c_row(self):
        names, cols, cell_w, cell_h = imp.PIC_SHEETS["deck_slot_plaques"]
        self.assertEqual((len(names), cols, cell_w, cell_h), (10, 5, 117, 100))
        self.assertTrue(all("b.pic" in n for n in names[:5]))
        self.assertTrue(all("c.pic" in n for n in names[5:]))

    def test_the_grid_is_assembled_in_cell_order(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "MagicTG" / "Dbart"
            root.mkdir(parents=True)
            names = imp.PIC_SHEETS["filter_icons"][0]
            for slot, name in enumerate(names):
                (root / name).write_bytes(
                    make_pic(40, 40, bytes([slot + 1] * 1600)))
            (root.parent / "Duelpalall.tr").write_text(
                tr_palette(ramp_palette()))
            dest = Path(tmp) / "skin"
            log = self._run(root.parent.parent, dest)
            width, height, channels, pixels = read_png(
                (dest / "filter_icons.png").read_bytes())
            self.assertEqual((width, height, channels), (360, 120, 3))
            palette = ramp_palette()
            for slot in range(len(names)):
                x = (slot % 9) * 40 + 5
                y = (slot // 9) * 40 + 5
                i = (y * 360 + x) * 3
                self.assertEqual(pixels[i:i + 3],
                                 palette[(slot + 1) * 3:(slot + 1) * 3 + 3],
                                 "cell %d" % slot)
            self.assertIn("27 files in", log)

    def test_the_two_state_sheets_are_ours_and_say_so(self):
        """0.5 and 1.26 are not invented here: `FilterBar` describes the
        split it wants as "a clean 2:1 luminance split" and lifts a hover
        by its own `HOVER_LIFT = 1.26` when no hover sheet exists, so the
        imported sheets are the ones the game would have derived."""
        self.assertEqual(imp.DERIVED_SHEETS["filter_icons_pressed"],
                         ("filter_icons", 0.5))
        self.assertEqual(imp.DERIVED_SHEETS["filter_icons_hover"],
                         ("filter_icons", 1.26))
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "MagicTG" / "Dbart"
            root.mkdir(parents=True)
            for name in imp.PIC_SHEETS["filter_icons"][0]:
                (root / name).write_bytes(
                    make_pic(40, 40, bytes([200] * 1600)))
            (root.parent / "Duelpalall.tr").write_text(
                tr_palette(ramp_palette()))
            dest = Path(tmp) / "skin"
            log = self._run(root.parent.parent, dest)
            self.assertIn("[OURS, not 1997]", log)
            self.assertIn("are OURS, not 1997: filter_icons_hover,"
                          " filter_icons_pressed", log)
            lit = read_png((dest / "filter_icons.png").read_bytes())[3]
            sunk = dest / "filter_icons_pressed.png"
            dark = read_png(sunk.read_bytes())[3]
            hover = read_png((dest / "filter_icons_hover.png").read_bytes())[3]
            self.assertEqual(dark[0], round(lit[0] * 0.5))
            self.assertEqual(hover[0], min(255, round(lit[0] * 1.26)))

    def test_a_missing_medallion_skips_the_sheet_with_a_reason(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "MagicTG" / "Dbart"
            root.mkdir(parents=True)
            for name in imp.PIC_SHEETS["filter_icons"][0][:-1]:
                (root / name).write_bytes(make_pic(40, 40, bytes(1600)))
            (root.parent / "Duelpalall.tr").write_text(
                tr_palette(ramp_palette()))
            dest = Path(tmp) / "skin"
            log = self._run(root.parent.parent, dest)
            self.assertIn("26 of 27 files, first missing Yellow.pic", log)
            self.assertFalse((dest / "filter_icons.png").exists())
            self.assertIn("  - filter_icons", log)


class TestEveryKeyIsReachableFromA1997Install(unittest.TestCase):
    """THE OWNER'S GOAL, PINNED (2026-09-09): *"all art should be
    available in original install! (If we added something new ourselves,
    we can supply it no problem…)"*

    So: no texture key may be reachable ONLY through a reimplementation's
    conversion. Every one either names a raw 1997 file first, is
    assembled from raw 1997 files, or is declared OURS — and this is the
    test that stops a new row from quietly reintroducing the problem.
    """

    def texture_keys(self) -> list[str]:
        return [k for k in imp.MANIFEST if not k.endswith((".ttf", ".wav"))]

    def test_no_texture_key_needs_a_conversion(self):
        for key in self.texture_keys():
            if key in imp.PIC_SHEETS or key in imp.DERIVED_SHEETS:
                self.assertEqual(imp.MANIFEST[key], [],
                                 "%s is assembled, not copied" % key)
                continue
            self.assertTrue(imp.MANIFEST[key], "%s names a 1997 file" % key)

    def test_the_only_assembled_or_ours_keys_are_the_named_ones(self):
        self.assertEqual(sorted(imp.PIC_SHEETS),
                         ["deck_slot_plaques", "filter_icons"])
        self.assertEqual(sorted(imp.DERIVED_SHEETS),
                         ["filter_icons_hover", "filter_icons_pressed"])
        for key in list(imp.PIC_SHEETS) + list(imp.DERIVED_SHEETS):
            self.assertIn(key, imp.MANIFEST)

    def test_every_derived_sheet_comes_from_a_1997_one(self):
        for key, (parent, _factor) in imp.DERIVED_SHEETS.items():
            self.assertIn(parent, imp.PIC_SHEETS)

    def test_the_title_face_is_the_one_font_and_the_body_is_ours(self):
        """`Magic.exe`'s string table names eight `.TTF` files and they
        are all on the disc; `Magim___.ttf` is byte-identical to the
        `MagicMedieval.ttf` a Manalink tree ships, and is imported by the
        disc's own name alone. THE BODY FACE IS NOT IMPORTED AT ALL (the
        owner, 2026-10-15: *"It is an open source font. Thats is very
        important."*): every player reads the game's own Spectral, so
        neither the 1997 `MPZurich Cn BT` (`Tt0298m_.ttf`) nor the
        Manalink `MPlantin` that led the row from 2026-09-09 is a key."""
        self.assertEqual(imp.MANIFEST["font_title.ttf"], ["Magim___.ttf"])
        self.assertNotIn("font_body.ttf", imp.MANIFEST)
        fonts = [k for k in imp.MANIFEST if k.endswith(".ttf")]
        self.assertEqual(fonts, ["font_title.ttf"])


class TestTheSkinIsBuiltOffTheDiscAlone(unittest.TestCase):
    """THE 1997 INSTALL AND NOTHING ELSE (the owner, 2026-10-15: *"Yes
    remove manalink fallbacks"*, *"Check we dont need s30 and remove any
    s30 dependency or s30 fallback"*). Measured the same day: the owner's
    own `MagicTG` alone reaches every key (164/164 once the body font
    left the skin), the 70 portraits and the coin toss, byte for byte
    what the importer wrote before the fallbacks went. This stops a row
    from quietly bringing one back."""

    ## Names that only ever came from a Manalink tree.
    # `Manalink.wav` is NOT here (2026-10-23): the 1997 game plays it as a
    # letter quest makes a mana link — the retail `Magic.exe` names
    # `x:sound\manalink.wav` in its town reward (the retail decompilation,
    # `town.c`), and `Shandalar.exe` carries the same string.
    MANALINK_ONLY = {"mplantin-regular.ttf", "garamond.ttf",
                     "magicmedieval.ttf", "goudymedieval-pre8th.ttf"}

    def every_candidate(self) -> list[tuple[str, str]]:
        out = [(k, n) for k, row in imp.MANIFEST.items() for n in row]
        for key, (names, *_rest) in imp.PIC_SHEETS.items():
            out += [(key, n) for n in names]
        for table in (imp.PIC_SCREENS, imp.VIDEOS):
            out += [(k, n) for k, row in table.items() for n in row]
        for name in (imp.PORTRAIT_SHEET_RAW + imp.PORTRAIT_PALETTE_PIC
                     + imp.PORTRAIT_PALETTE_TR + imp.ROGUE_PALETTE_TR
                     + imp.ROGUE_PALETTE_PIC):
            out.append(("portraits", name))
        return out

    def test_no_candidate_is_a_converted_png(self):
        for key, name in self.every_candidate():
            self.assertFalse(name.lower().endswith(".png"),
                             "%s names a conversion: %s" % (key, name))

    def test_no_candidate_is_a_manalink_file(self):
        for key, name in self.every_candidate():
            low = name.lower()
            self.assertFalse(low.startswith("program/"),
                             "%s names a Manalink path: %s" % (key, name))
            self.assertNotIn(low, self.MANALINK_ONLY,
                             "%s names a Manalink file: %s" % (key, name))
            # A `.bmp` is never the 1997 DUEL's or SHELL's art — with one
            # exception: `Statwin/`, the folder 1997's own `Statwin.dll`
            # (1 May 1997) loads the wizards' window's bitmaps from (dated
            # 1996 in the owner's install; THE WIZARDS' HALL).
            self.assertFalse(low.endswith(".bmp") and not low.startswith("statwin/"),
                             "%s names a .bmp (never 1997): %s" % (key, name))

    def test_the_conversion_door_is_gone(self):
        self.assertFalse(hasattr(imp, "_is_conversion"))
        self.assertFalse(hasattr(imp, "PORTRAIT_SHEET_PNG"))
        self.assertFalse(hasattr(imp, "_portraits_from_sheet"))
        argv = sys.argv
        sys.argv = ["import_original.py", "--source", ".",
                    "--allow-conversions"]
        try:
            with redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit):
                    imp.main()
        finally:
            sys.argv = argv

    def _import(self, files: dict[str, bytes]) -> tuple[Path, str]:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = Path(tmp.name) / "src"
        for name, data in files.items():
            (root / name).parent.mkdir(parents=True, exist_ok=True)
            (root / name).write_bytes(data)
        dest = Path(tmp.name) / "skin"
        argv = sys.argv
        sys.argv = ["import_original.py", "--source", str(root),
                    "--dest", str(dest), "--no-videos"]
        log = io.StringIO()
        try:
            with redirect_stdout(log):
                self.assertEqual(imp.main(), 0)
        finally:
            sys.argv = argv
        return dest, log.getvalue()

    def test_manalinks_program_sound_copies_are_refused(self):
        """No row names `Program/DuelSounds/` or `Program/Sound/`, but the
        index reaches a file there by its two-part name AND by its bare
        one — so a Manalink source tree's copy used to come in anyway
        when the 1997 folder was absent. Found by the 2026-10-17 bug
        pass; refused where the candidate is chosen."""
        dest, log = self._import({"Program/DuelSounds/Grey.wav": b"RIFF manalink",
                                  "Program/Sound/LocMus3.wav": b"RIFF manalink"})
        self.assertFalse((dest / "sfx_land_grey.wav").exists())
        self.assertFalse((dest / "music_location_3.wav").exists())
        self.assertIn("Program/", log)
        dest, _log = self._import({"Duelsounds/Grey.wav": b"RIFF installed",
                                   "Program/DuelSounds/Grey.wav": b"RIFF manalink",
                                   "Sound/LocMus3.wav": b"RIFF installed"})
        self.assertEqual((dest / "sfx_land_grey.wav").read_bytes(), b"RIFF installed")
        self.assertEqual((dest / "music_location_3.wav").read_bytes(), b"RIFF installed")

    def test_the_readback_is_the_inverse_of_write_png(self):
        """`import_derived_sheets` reads a sheet back off disk, so the
        module needs a reader as well as a writer — and it must refuse
        anything this file did not write rather than pretend to decode
        PNG."""
        pixels = bytes(bytearray(i % 256 for i in range(4 * 3 * 4)))
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "x.png"
            imp.write_png(path, 4, 3, pixels, alpha=True)
            self.assertEqual(imp.read_png(path.read_bytes()),
                             (4, 3, 4, pixels))
            path.write_bytes(b"<html>404")
            with self.assertRaises(ValueError):
                imp.read_png(path.read_bytes())


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
        # The one sound in the install's ROOT, beside the program: the
        # wizards' window's `Statscrn.wav` (`.\\statscrn.wav`, Statwin), no
        # folder to name and no other file of its name in a 1997 install.
        at_the_root = {"sfx_wizards.wav"}
        for key, candidates in imp.MANIFEST.items():
            if not imp.is_sound_key(key) or key in at_the_root:
                continue
            self.assertIn("/", candidates[0],
                          f"{key} must say which folder it means")
        self.assertEqual([imp.MANIFEST[key] for key in sorted(at_the_root)], [["Statscrn.wav"]])

    def test_the_games_own_folder_beats_the_manalink_source_copy(self):
        root = self._tree({"Duelsounds/Grey.wav": b"installed",
                           "Program/DuelSounds/Grey.wav": b"source tree"})
        index = imp.build_index([root])
        found = imp._first_of(index, imp.MANIFEST["sfx_land_grey.wav"])
        self.assertEqual(found.read_bytes(), b"installed")

    # -------------------------------------------------- what is in there --

    def test_mana_burn_imports_the_duel_sound_not_ordinary_life_loss(self):
        root = self._tree({"Duelsounds/Manaburn.wav": b"installed burn",
                           "Duelsounds/LifeLoss.wav": b"ordinary life loss"})
        candidates = imp.MANIFEST.get("sfx_mana_burn.wav", [])
        self.assertTrue(candidates, "mana burn must be included in skin imports")
        if not candidates:
            return
        index = imp.build_index([root])
        found = imp._first_of(index, candidates)
        self.assertIsNotNone(found)
        self.assertEqual(found.read_bytes(), b"installed burn")
        self.assertNotIn("Program/DuelSounds/ManaBurn.wav", candidates,
                         "the Manalink source copy is not a candidate")

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
        # And, since part B (2026-10-23), the two beds 1.3 loops after an
        # adventure duel, won or lost — kept out of the playlist below.
        music = [k for k in imp.MANIFEST if k.startswith("music_")]
        self.assertEqual(len(music), 29)
        for key in ("music_duel.wav", "music_location_0.wav",
                    "music_location_19.wav", "music_temple.wav",
                    "music_castle_white.wav", "music_castle_green.wav",
                    "music_win_duel.wav", "music_lose_duel.wav"):
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


class TestDefaultDestination(unittest.TestCase):
    """Where the loose skin goes when nobody says: the checkout's
    assets/original next to a project.godot, else the player's skin
    folder — the default of the game's `skin_folder` key, the place
    Options > Skin names (the owner, 2026-09-08: *"pointing to an
    original skin folder like we have currently now as default"*)."""

    def test_in_the_checkout_it_is_assets_original(self):
        dest = imp.default_dest()
        self.assertEqual(dest.name, "original")
        self.assertEqual(dest.parent.name, "assets")
        self.assertTrue((dest.parent.parent / "project.godot").exists())

    def test_beside_the_packaged_game_it_is_the_skin_folder(self):
        with tempfile.TemporaryDirectory() as tmp:
            was = imp.__file__
            try:
                imp.__file__ = str(Path(tmp) / "pkg" / "import_original.py")
                dest = imp.default_dest()
            finally:
                imp.__file__ = was
        self.assertEqual(dest, imp.godot_user_dir() / "original_skin")

    def test_the_user_dir_is_the_engines_own_on_linux(self):
        if not sys.platform.startswith("linux"):
            self.skipTest("Linux paths")
        was = os.environ.get("XDG_DATA_HOME")
        try:
            os.environ["XDG_DATA_HOME"] = "/srv/data"
            self.assertEqual(imp.godot_user_dir(),
                             Path("/srv/data/godot/app_userdata/Shandalar"))
            del os.environ["XDG_DATA_HOME"]
            self.assertEqual(imp.godot_user_dir(),
                             Path.home() / ".local/share/godot/app_userdata/Shandalar")
        finally:
            if was is None:
                os.environ.pop("XDG_DATA_HOME", None)
            else:
                os.environ["XDG_DATA_HOME"] = was


class TestThePortraitSheetIsNeverCut(RawStepCase):
    """s30's `16faces.spr.png` IS A CONVERSION, AND THERE IS NO DOOR.

    Bug pass 2026-10-03: the portrait step had its own way in — with no
    raw `16faces.spr` in the tree it cut the converted sheet, so a
    player's run against an s30 checkout came out wearing a
    reimplementation's faces. It was put behind `--allow-conversions`
    then; on 2026-10-15 the flag and the sheet-cutting path went
    altogether (the owner: *"remove any s30 dependency or s30
    fallback"*).
    """

    CELLS = 3

    def _tree(self, tmp: str) -> Path:
        root = Path(tmp) / "s30"
        root.mkdir()
        width, height = imp.PORTRAIT_CELL
        imp.write_png(root / "16faces.spr.png", width * self.CELLS, height,
                      bytes(width * self.CELLS * height * 3))
        return root

    def test_a_players_run_does_not_cut_a_converted_sheet(self):
        with tempfile.TemporaryDirectory() as tmp:
            dest = Path(tmp) / "skin"
            log = self._run(self._tree(tmp), dest)
            faces = sorted((dest / "portraits").glob("*.png")) \
                if (dest / "portraits").is_dir() else []
            self.assertEqual(faces, [])
            self.assertIn("portraits: no face art found", log)


class TestTheCoinSheetIsCutAtTheSizeItWasDecodedAt(unittest.TestCase):
    """THE RE-PLAN THAT SHRINKS MUST RE-DECODE (bug pass 2026-10-03).

    `import_videos` decodes at the size a first plan gives for the
    HEADER's frame count, then re-plans for the count the decoder really
    produced. When the stream held more frames than the header said and
    the second plan shrank them to fit MAX_SHEET, the RGB decoded at the
    old size was tiled as if it were the new one — every frame after the
    first sheared — and the JSON named a frame size the pixels never had.
    """

    WIDTH, HEIGHT, HEADER_FRAMES, STREAM_FRAMES = 64, 48, 20, 120

    @staticmethod
    def colour(index: int) -> bytes:
        return bytes((index % 256, (index * 7) % 256, 200))

    def test_every_frame_lands_whole_in_its_cell(self):
        decoded_at = []

        def fake_decode(_program, _path, width, height):
            decoded_at.append((width, height))
            return b"".join(self.colour(i) * (width * height)
                            for i in range(self.STREAM_FRAMES))

        header = {"width": self.WIDTH, "height": self.HEIGHT,
                  "frames": self.HEADER_FRAMES, "fps": 15.0, "codec": "CRAM"}
        with tempfile.TemporaryDirectory() as tmp, \
                mock.patch.object(imp, "MAX_SHEET", 512), \
                mock.patch.object(imp, "find_decoder", lambda: ("ffmpeg", "fake")), \
                mock.patch.object(imp, "decode_frames", fake_decode), \
                mock.patch.object(imp, "read_avi_header", lambda _p: dict(header)), \
                redirect_stdout(io.StringIO()):
            dest = Path(tmp)
            imp.import_videos({"cointoss_heads.avi": dest / "COINTOSS_Heads.AVI"}, dest)
            meta = json.loads((dest / "coin_toss_heads.json").read_text())
            width, height, channels, pixels = read_png(
                (dest / "coin_toss_heads.png").read_bytes())
        w, h = meta["frame_width"], meta["frame_height"]
        self.assertLess(w, self.WIDTH, "the fixture is one whose re-plan shrinks")
        self.assertEqual(decoded_at[-1], (w, h),
                         "the sheet is cut at the size the pixels were decoded at")
        self.assertEqual(meta["frames"], self.STREAM_FRAMES)
        self.assertEqual((width, height), (meta["cols"] * w, meta["rows"] * h))
        stride = width * channels
        for i in range(self.STREAM_FRAMES):
            col, row = i % meta["cols"], i // meta["cols"]
            for x, y in ((0, 0), (w - 1, h - 1)):
                at = (row * h + y) * stride + (col * w + x) * channels
                self.assertEqual(pixels[at:at + 3], self.colour(i),
                                 "frame %d at (%d, %d) of its cell" % (i, x, y))



class TestABadMovieHeaderIsNeverFatal(unittest.TestCase):
    """THE MOVIE STEP IS "NEVER FATAL" (hunt 2026-10-21) — `import_videos`
    says so, and the importer runs it last for that reason. A header too
    short to hold its `avih` fields was a `struct.error`, and a frame count
    no sheet can hold a ValueError from the first plan, outside the try:
    either ended the whole import with a traceback."""

    def test_an_avih_tag_at_the_end_is_not_a_readable_avi(self):
        with tempfile.TemporaryDirectory() as tmp:
            avi = Path(tmp) / "cut.avi"
            avi.write_bytes(b"RIFF\0\0\0\0AVI " + b"strf" + bytes(60) + b"avih")
            self.assertIsNone(imp.read_avi_header(avi))

    def test_a_frame_count_no_sheet_holds_skips_that_movie(self):
        header = {"width": 320, "height": 240, "frames": 100000, "fps": 15.0, "codec": "CRAM"}
        log = io.StringIO()
        with tempfile.TemporaryDirectory() as tmp, \
                mock.patch.object(imp, "find_decoder", lambda: ("ffmpeg", "fake")), \
                mock.patch.object(imp, "decode_frames", lambda *_a: b""), \
                mock.patch.object(imp, "read_avi_header", lambda _p: dict(header)), \
                redirect_stdout(log):
            dest = Path(tmp)
            imp.import_videos({"cointoss_heads.avi": dest / "COINTOSS_Heads.AVI"}, dest)
            self.assertFalse((dest / "coin_toss_heads.png").exists())
        self.assertIn("SKIPPED", log.getvalue())


if __name__ == "__main__":
    unittest.main()


class TestVisitPictures(unittest.TestCase):
    """The places' pictures (2026-10-23): what 1.3 showed as the hero
    arrived, read in `visitLocation.c` and `world_lair_monster_encounter.c`
    — decoded whole in the world frame's palette."""

    def test_every_place_has_its_1997_file(self):
        self.assertEqual(imp.VISIT_PICTURES["visit_village"], ["Village.pic"])
        self.assertEqual(imp.VISIT_PICTURES["visit_city"], ["City.pic"])
        self.assertEqual([imp.VISIT_PICTURES["visit_castle_" + c][0] for c in
                          ("black", "blue", "green", "red", "white")],
                         ["0246.pic", "0364.pic", "0335.pic", "0737.pic", "0028.pic"])
        self.assertEqual([imp.VISIT_PICTURES["visit_lair_" + c][0] for c in
                          ("black", "blue", "green", "red", "white")],
                         ["0333.pic", "0873.pic", "0281.pic", "0329.pic", "0569.pic"])
        for key in imp.VISIT_PICTURES:
            self.assertIn(key, imp.PIC_SCREENS, key + " is decoded with the screens")

    def test_they_take_the_world_frame_s_palette_whole(self):
        for key in imp.VISIT_PICTURES:
            self.assertEqual(imp.PIC_PALETTES[key][0], "Advfac64.pic")
            self.assertIn(key, imp.PIC_OPAQUE)

    def test_a_bare_picture_is_painted_whole_when_asked(self):
        palette = bytes(range(256)) * 3
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "plain.pic"
            path.write_bytes(b"not a picture")
            self.assertIsNone(imp._raw_pic_rgba("visit_city", path, palette, True),
                              "a file it cannot read is skipped, not raised")


class TestCardValues(unittest.TestCase):
    """The 1997 program's card table (2026-10-23), found by its basic lands
    and named from `Info.csv`, for the adventure's card prices."""

    @staticmethod
    def _row(name: bytes, card_id: int, kind: int, color: int, cc0: int, cc1: int,
             power: int, tough: int, code: int, extra: int, ai: int) -> bytes:
        row = bytearray(imp.CARD_ROW)
        row[1:1 + len(name)] = name
        struct.pack_into("<H", row, 0x24, card_id)
        row[0x28] = kind
        struct.pack_into("<bbb", row, 0x2a, color, cc0, cc1)
        struct.pack_into("<hh", row, 0x2e, power, tough)
        struct.pack_into("<III", row, 0x34, code, 0, extra)
        row[0x40] = 255
        row[0x42] = 1
        struct.pack_into("<i", row, 0x44, ai)
        return bytes(row)

    def test_the_table_is_found_read_and_named(self):
        lands = [b"Swamp", b"Island", b"Forest", b"Mountain", b"Plains"]
        # Each land its own code, as the program's (`card_swamp` …).
        blob = b"junk" * 9 + b"".join(self._row(n, 239 + i, 1, 2, 0, 0, 0, 0, 20 + i, 0x1000, 0)
                                      for i, n in enumerate(lands))
        blob += self._row(b"GrizzlyBear", 106, 2, 8, 1, 1, 2, 2, 9, 0, 1)
        blob += self._row(b"OtherBear", 107, 2, 8, 1, 1, 2, 2, 9, 0, 1)
        blob += b"\0" * imp.CARD_ROW
        at = imp.find_card_table(blob)
        self.assertEqual(at, 36)
        rows = imp.read_card_table(blob, at)
        self.assertEqual(len(rows), 7, "until a row without a name")
        values = imp.card_values(rows, {106: "Grizzly Bears", 239: "Swamp"}, {},
                                 {106: "Common"})
        self.assertEqual(sorted(values), ["Grizzly Bears", "Swamp"], "only what Info.csv names")
        bears = values["Grizzly Bears"]
        self.assertEqual((bears["type"], bears["color"], bears["cc0"], bears["cc1"],
                          bears["power"], bears["tough"], bears["ai"], bears["rarity"]),
                         (2, 8, 1, 1, 2, 2, 1, 1))
        self.assertTrue(bears["vanilla"], "the code most rows share is the plain creature's")
        self.assertFalse(values["Swamp"]["vanilla"])

    def test_no_table_no_file(self):
        self.assertEqual(imp.find_card_table(b"Swamp\0" + b"x" * 400), -1)
        with tempfile.TemporaryDirectory() as tmp:
            self.assertFalse(imp.import_card_values({}, Path(tmp)), "no program: nothing written")


class TestWiseWords(unittest.TestCase):
    """The wise man's tales and news (2026-10-23): `Advblocks.txt`'s blocks,
    four of news and then the tales, their pages parted by three blank
    lines."""

    TEXT = (" _qQuote[0] male\r\nSTARTBLOCK\r\nI see you have not yet defeated the\r\n"
            "%1 in his Castle.\r\n\r\n\r\n\r\nENDBLOCK\r\n"
            "STARTBLOCK\r\nLinks: %s and %s.\r\n\r\n\r\n\r\nENDBLOCK\r\n"
            "STARTBLOCK\r\nMagic %1 in %2.\r\n\r\n\r\n\r\nENDBLOCK\r\n"
            "STARTBLOCK\r\nShe has %2!d! life.\r\n\r\n\r\n\r\nENDBLOCK\r\n"
            " a tale\r\nSTARTBLOCK\r\nPage one.\r\nStill one.\r\n\r\n\r\n\r\n"
            "Page two.\r\n\r\n\r\n\r\nENDBLOCK\r\n")

    def test_the_blocks_are_read(self):
        words = imp.wise_words(self.TEXT)
        self.assertEqual(words["city"][0], "I see you have not yet defeated the\n%1 in his Castle.")
        self.assertEqual(words["city"][3], "She has %2!d! life.")
        self.assertEqual(words["tales"], [["Page one.\nStill one.", "Page two."]], "a tale in its pages")

    def test_written_beside_the_skin(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "Advblocks.txt").write_text(self.TEXT, encoding="cp1252")
            out = root / "skin"
            out.mkdir()
            self.assertTrue(imp.import_wise_words({"advblocks.txt": root / "Advblocks.txt"}, out))
            data = json.loads((out / "adventure_wise_words.json").read_text())
            self.assertEqual(len(data["tales"]), 1)
            self.assertFalse(imp.import_wise_words({}, out), "no Advblocks.txt: nothing")


class TestCardHints(unittest.TestCase):
    """The card seller's hints (2026-10-23): `Hints.txt` read with its
    cards named by `Info.csv`, for the town shop."""

    TEXT = (".51     -1\tA    \t(Crusade) ... Singles\r\n\r\n"
            "give all your white creatures extra power.\r\n\r\n"
            ".94     193\tAB    (Fungusaur/Prodigal) ... Combos\r\n\r\n"
            "damage your own Fungusaur to make it grow each turn!\r\n\r\n"
            ".500    193\tCD    (unnamed)\r\n\r\nnever read\r\n")

    def test_the_hints_are_read_and_named(self):
        names = {51: "Crusade", 94: "Fungusaur", 193: "Prodigal Sorcerer"}
        hints = imp.card_hints(self.TEXT, names)
        self.assertEqual(hints, [
            {"first": "Crusade", "second": "", "levels": 1,
             "text": "give all your white creatures extra power."},
            {"first": "Fungusaur", "second": "Prodigal Sorcerer", "levels": 3,
             "text": "damage your own Fungusaur to make it grow each turn!"}],
            "a single card, a pair by difficulty letters; a card unnamed left out")

    def test_written_beside_the_skin(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "Hints.txt").write_text(self.TEXT, encoding="cp1252")
            (root / "Info.csv").write_text("51,Crusade\n94,Fungusaur\n193,Prodigal Sorcerer\n",
                                           encoding="latin-1")
            out = root / "skin"
            out.mkdir()
            index = {"hints.txt": root / "Hints.txt", "info.csv": root / "Info.csv"}
            self.assertTrue(imp.import_card_hints(index, out))
            data = json.loads((out / "adventure_hints.json").read_text())
            self.assertEqual(len(data["hints"]), 2)
            self.assertFalse(imp.import_card_hints({}, out), "no Hints.txt: nothing")



# ------------------------------------------------------------ part B ------

REPO = Path(__file__).resolve().parent.parent

## THE CREATURES' SHEETS BY TABLE ROW, as 1.3 `LoadCreatureEncounterSprites`
## (world_lair_monster_slots.c:38-279) loads them — the part B creature
## spec's table, row: (body, shadow). Rows 0, 7, 14, 21, 28 (the lair and
## four castle wizards), 55 and 56 (Arzakon) have none; the War Mage and
## the Dragon Lord share R_AMG; the centaurs' shadows are crossed, as in
## 1997.
CREATURE_SPRITES_BY_ROW = {
    1: ("BK_FWZ", "SFWZ"), 2: ("BK_KHT", "SB_KHT"), 3: ("BK_MWZ", "SMWZ"),
    4: ("BK_LRD", "SB_LRD"), 5: ("BK_WG", "SBK_WG"), 6: ("BK_AMG", "SB_AMG"),
    8: ("W_MWZ", "SW_MWZ"), 9: ("W_FWZ", "SFWZ"), 10: ("W_KHT", "SKHT"),
    11: ("W_LRD", "SW_LRD"), 12: ("W_WG", "SW_WG"), 13: ("W_AMG", "SW_AMG"),
    15: ("BU_FWZ", "SFWZ"), 16: ("BU_LRD", "SU_LRD"), 17: ("BU_MWZ", "SMWZ"),
    18: ("BU_WRM", "SWRM"), 19: ("B_SFR", "SB_SFT"), 20: ("BU_AMG", "SU_AMG"),
    22: ("G_MWZ", "SMWZ"), 23: ("G_KHT", "SKHT"), 24: ("G_FWZ", "SFWZ"),
    25: ("G_WRM", "SWRM"), 26: ("G_LRD", "SG_LRD"), 27: ("G_AMG", "SG_AMG"),
    29: ("R_FWZ", "SR_FWZ"), 30: ("R_MWZ", "SMWZ"), 31: ("TROLL", "STRL"),
    32: ("R_LRD", "SR_LRD"), 33: ("R_WRM", "SR_WRM"), 34: ("R_AMG", "SR_AMG"),
    35: ("R_AMG", "SR_AMG"),
    36: ("M_TSK", "SM_TSK"), 37: ("M_TRL", "SM_TRL"), 38: ("M_APE", "SM_APE"),
    39: ("M_CEN2", "SM_CEN"), 40: ("M_WG", "SM_WG"), 41: ("M_FNG", "SM_FNG"),
    42: ("M_CEN", "SM_CEN2"), 43: ("M_LRD", "SM_LRD"), 44: ("M_KHT", "SKHT"),
    45: ("M_FWZ", "SFWZ"),
    46: ("BK_DJN", "SDJN"), 47: ("G_DJN", "SDJN"), 48: ("R_DJN", "SDJN"),
    49: ("BU_DJN", "SDJN"),
    50: ("DG_BRU", "S_DG"), 51: ("DG_UWB", "S_DG"), 52: ("DG_GWR", "S_DG"),
    53: ("DG_RBG", "S_DG"), 54: ("DG_WUG", "S_DG"),
}


class TestTheCreatureSheets(RawStepCase):
    """THE CREATURES WALKING THE WORLD (2026-10-23, part B): 49 bodies and
    32 shadows from `SPR/`, each the hero's grid (40 frames of 154 x 108,
    five to a row) in the world frame's palette, keyed `world_creature_` +
    the file's name in lower case."""

    def test_every_creature_of_the_table_has_its_sheets(self):
        bodies = {body for body, _shadow in CREATURE_SPRITES_BY_ROW.values()}
        shadows = {shadow for _body, shadow in CREATURE_SPRITES_BY_ROW.values()}
        self.assertEqual((len(bodies), len(shadows)), (49, 32))
        self.assertEqual(set(imp.CREATURE_BODIES), bodies)
        self.assertEqual(set(imp.CREATURE_SHADOWS), shadows)
        self.assertEqual(len(imp.CREATURE_BODIES), 49, "each body once")
        self.assertEqual(len(imp.CREATURE_SHADOWS), 32, "each shadow once")
        self.assertEqual(len(imp.CREATURE_SHEETS), 81)

    def test_the_key_is_the_file_s_name_in_lower_case(self):
        self.assertEqual(imp.creature_sheet_key("BK_FWZ"), "world_creature_bk_fwz")
        self.assertEqual(imp.creature_sheet_key("SFWZ"), "world_creature_sfwz")
        self.assertEqual(imp.creature_sheet_key("M_CEN2"), "world_creature_m_cen2")
        for stem in imp.CREATURE_BODIES + imp.CREATURE_SHADOWS:
            key = "world_creature_" + stem.lower()
            self.assertEqual(imp.CREATURE_SHEETS[key], stem + ".SPR")
            self.assertEqual(imp.MANIFEST[key], ["spr/%s.spr" % stem.lower(), "%s.spr" % stem.lower()])
            self.assertEqual(imp.WORLD_SHEETS[key], (40, 154, 108, 5), "the hero's grid")
            self.assertEqual(imp.WORLD_SHEETS[key], imp.WORLD_SHEETS["world_ego_m"])
            self.assertEqual(imp.SPR_PALETTES[key][0], "Advfac64.pic")

    def test_a_creature_sheet_is_cut_on_the_hero_s_grid_with_its_anchor(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "MagicTG"
            (root / "Spr").mkdir(parents=True)
            frames = [(4, 2, bytes([20 + i] * 8), 73 if i == 0 else -1) for i in range(40)]
            frames.append((3, 1, bytes(3), -1))   # the format's end marker
            (root / "Spr" / "Bk_Kht.spr").write_bytes(TestTheWorldSheets._anchored(self, frames))
            world = ramp_palette()
            (root / "Advfac64.pic").write_bytes(make_pic(2, 2, bytes([1, 2, 3, 4]), world))
            dest = Path(tmp) / "skin"
            log = self._run(root, dest)
            self.assertIn("world_creature_bk_kht", log)
            width, height, channels, pixels = read_png((dest / "world_creature_bk_kht.png").read_bytes())
            self.assertEqual((width, height, channels), (770, 864, 4), "5 x 8 cells of 154 x 108")
            at = ((108 * 7) * 770 + 154 * 4) * 4   # frame 39: row 7, column 4
            self.assertEqual(bytes(pixels[at:at + 4]), world[59 * 3:59 * 3 + 3] + b"\xff")
            self.assertEqual(pixels[(5 * 770 + 5) * 4 + 3], 0, "index 0 around the figure is clear")
            side = json.loads((dest / "world_creature_bk_kht.json").read_text())
            self.assertEqual((side["cols"], side["rows"], side["frames"]), (5, 8, 40))
            self.assertEqual(side["tops"], [73] + [-1] * 39, "frame 0's anchor, the rest none")

    def test_the_world_art_layout_has_every_sheet_row_for_row(self):
        """game/adventure/world/world_art.gd's LAYOUT is the importer's
        WORLD_SHEETS, creatures included, for a skin whose sidecars are
        missing; the wizards' window's creature pictures ride beside."""
        text = (REPO / "game" / "adventure" / "world" / "world_art.gd").read_text(encoding="utf-8")
        start = text.index("const LAYOUT := {")
        block = text[start:text.index("\n}\n", start)]
        rows = {m.group(1): (int(m.group(2)), int(m.group(3)), int(m.group(4))) for m in
                re.finditer(r'"(\w+)": \[(\d+), (\d+), (\d+)\]', block)}
        for key, (_cells, width, height, columns) in imp.WORLD_SHEETS.items():
            self.assertEqual(rows.get(key), (width, height, columns), key)
        self.assertEqual(rows["creature_thumbs"], (80, 64, 8))
        self.assertEqual(set(rows) - set(imp.WORLD_SHEETS), {"creature_thumbs"})
        self.assertIn('const CREATURE_PREFIX := "%s"' % imp.CREATURE_PREFIX, text)


class TestTheEncounterPictures(RawStepCase):
    """THE MEETINGS' AND THE ADVENTURE DUELS' PICTURES (2026-10-23, part B),
    each in the palette 1.3 shows it in: the grounds and the spoils their
    own, the bare ones the palette set before them, the meeting's parts
    cut with index 0 clear as the 1997 sprite cut left it."""

    def test_every_picture_names_its_1997_file(self):
        self.assertEqual(imp.ENCOUNTER_PICTURES, {
            "preduel_black": ["Prdblk.pic"], "preduel_blue": ["Prdblu.pic"],
            "preduel_green": ["Prdgrn.pic"], "preduel_red": ["Prdrd.pic"],
            "preduel_white": ["Prdwt.pic"],
            "preduel_panels": ["Prdfrma.pic"], "preduel_frame": ["Prdfrmb.pic"],
            "preduel_frame_tinted": ["Prdfrmc.pic"],
            "win_back_cards": ["Winbak01.pic"], "win_back_reward": ["Winbak02.pic"],
            "end_plaque": ["Endplak.pic"], "lose_card": ["Losedul2.pic"],
            "town_freed": ["Celeb.pic"], "game_over": ["Uth-Arz.pic"],
            "creature_thumbs": ["Creatures640.pic"]})
        for key in imp.ENCOUNTER_PICTURES:
            self.assertIn(key, imp.PIC_SCREENS, key + " is decoded with the screens")
            self.assertNotIn(key, imp.MANIFEST)

    def test_each_takes_the_palette_1997_showed_it_in(self):
        self.assertEqual(imp.PIC_CUT, {"preduel_panels", "preduel_frame", "preduel_frame_tinted"})
        for key in imp.ENCOUNTER_PICTURES:
            if key.startswith("preduel_"):
                self.assertEqual(imp.PIC_PALETTES[key][0], "Prdblk.pic", key)
            self.assertEqual(key in imp.PIC_OPAQUE, key not in imp.PIC_CUT, key)
        for key in ("win_back_reward", "end_plaque"):
            self.assertEqual(imp.PIC_PALETTES[key][:2], ["Winbak01.pic", "Advfac64.pic"])
        self.assertEqual(imp.PIC_PALETTES["creature_thumbs"][0], "Advfac64.pic")

    def _install(self, tmp: str) -> tuple[Path, Path, bytes, bytes]:
        root = Path(tmp) / "MagicTG"
        root.mkdir(parents=True)
        meeting = ramp_palette()
        spoils = bytes(255 - b for b in meeting)
        (root / "Prdblk.pic").write_bytes(make_pic(2, 2, bytes([1, 2, 3, 4]), meeting))
        (root / "Winbak01.pic").write_bytes(make_pic(2, 2, bytes([1, 2, 3, 4]), spoils))
        return root, Path(tmp) / "skin", meeting, spoils

    def test_the_tinted_frame_is_cut_in_the_meeting_s_palette(self):
        with tempfile.TemporaryDirectory() as tmp:
            root, dest, meeting, _spoils = self._install(tmp)
            (root / "Prdfrmc.pic").write_bytes(make_pic(4, 1, bytes([0, 9, 255, 0])))
            log = self._run(root, dest)
            self.assertIn("preduel_frame_tinted", log)
            width, height, channels, pixels = read_png((dest / "preduel_frame_tinted.png").read_bytes())
            self.assertEqual((width, height, channels), (4, 1, 4))
            self.assertEqual(pixels[3], 0, "index 0 is the sprite cut's clear")
            self.assertEqual(bytes(pixels[4:8]), meeting[27:30] + b"\xff")
            self.assertEqual(bytes(pixels[8:12]), meeting[765:768] + b"\xff",
                             "index 255 is a colour here, not the faces' clear")

    def test_a_frame_with_its_own_palette_keeps_it_and_clears_index_0(self):
        with tempfile.TemporaryDirectory() as tmp:
            root, dest, _meeting, spoils = self._install(tmp)
            (root / "Prdfrmb.pic").write_bytes(make_pic(2, 1, bytes([0, 9]), spoils))
            self._run(root, dest)
            _w, _h, channels, pixels = read_png((dest / "preduel_frame.png").read_bytes())
            self.assertEqual(channels, 4)
            self.assertEqual(pixels[3], 0)
            self.assertEqual(bytes(pixels[4:8]), spoils[27:30] + b"\xff")

    def test_the_reward_ground_is_painted_whole_in_the_cards_won_palette(self):
        with tempfile.TemporaryDirectory() as tmp:
            root, dest, _meeting, spoils = self._install(tmp)
            (root / "Winbak02.pic").write_bytes(make_pic(3, 1, bytes([0, 8, 255])))
            (root / "Endplak.pic").write_bytes(make_pic(1, 1, bytes([8])))
            self._run(root, dest)
            width, height, channels, pixels = read_png((dest / "win_back_reward.png").read_bytes())
            self.assertEqual((width, height, channels), (3, 1, 3), "opaque, whole")
            self.assertEqual(pixels, spoils[0:3] + spoils[24:27] + spoils[765:768])
            _w, _h, channels, pixels = read_png((dest / "end_plaque.png").read_bytes())
            self.assertEqual((channels, pixels), (3, spoils[24:27]))

    def test_a_ground_with_its_own_palette_is_opaque_in_it(self):
        with tempfile.TemporaryDirectory() as tmp:
            root, dest, meeting, spoils = self._install(tmp)
            (root / "Uth-Arz.pic").write_bytes(make_pic(2, 1, bytes([0, 255]), meeting))
            self._run(root, dest)
            _w, _h, channels, pixels = read_png((dest / "game_over.png").read_bytes())
            self.assertEqual((channels, pixels), (3, meeting[0:3] + meeting[765:768]))


class TestThePartBSounds(unittest.TestCase):
    """THE CREATURES' CRIES AND THE ADVENTURE DUELS' SOUNDS (2026-10-23,
    part B), each from the folder 1.3 reads it in."""

    CRIES = ["malewiz", "fewiz", "knight", "lord", "djinn", "troll", "wyrm",
             "dragon", "flying", "archmage"]

    def test_a_cry_per_kind_from_the_sound_folder(self):
        names = {"malewiz": "Malewiz", "fewiz": "Fewiz", "knight": "Knight",
                 "lord": "Lord", "djinn": "Djinn", "troll": "Troll", "wyrm": "Wyrm",
                 "dragon": "Dragon", "flying": "Flying", "archmage": "Archmage"}
        cries = [k for k in imp.MANIFEST if k.startswith("sfx_cry_")]
        self.assertEqual(cries, ["sfx_cry_%s.wav" % c for c in self.CRIES], "kinds 1 to 10")
        for cry, name in names.items():
            self.assertEqual(imp.MANIFEST["sfx_cry_%s.wav" % cry][0], "Sound/%s.wav" % name)

    def test_the_flyers_cry_is_the_file_that_shipped(self):
        # [ours: 1997 slip] 1.3 asks for `flyer.wav`, which no install has.
        for row in imp.MANIFEST.values():
            self.assertNotIn("flyer.wav", [name.lower().split("/")[-1] for name in row])
        self.assertEqual(imp.MANIFEST["sfx_cry_flying.wav"], ["Sound/Flying.wav", "Flying.wav"])

    def test_the_meetings_and_duels_sounds_come_from_their_folders(self):
        self.assertEqual(imp.MANIFEST["sfx_dsummon.wav"][0], "Sound/Dsummon.wav")
        self.assertEqual(imp.MANIFEST["sfx_newsflash.wav"][0], "Sound/Newsflash.wav")
        self.assertEqual(imp.MANIFEST["sfx_lair_duel.wav"][0], "DuelSounds/Aswanjag.wav",
                         "1.3 plays it from x:Duelsounds\\")
        self.assertEqual(imp.MANIFEST["sfx_dungeon_duel.wav"][0], "Sound/Dngnduel.wav")
        self.assertIn("sfx_dungeon_duel.wav", imp.NOT_READ, "the dungeons are part C")

    def test_the_duels_two_beds_are_the_adventure_s_not_the_duel_s_stings(self):
        self.assertEqual(imp.MANIFEST["music_win_duel.wav"][0], "Sound/Winduel.wav")
        self.assertEqual(imp.MANIFEST["music_lose_duel.wav"][0], "Sound/Loseduel.wav")
        self.assertEqual(imp.MANIFEST["sfx_win.wav"][0], "DuelSounds/Shell_WinDuel.wav",
                         "the duel's own sting is unchanged")

    def test_the_two_beds_stay_out_of_the_playlist(self):
        """[MusicLibrary] names its tracks one by one; a bed that belongs
        to the spoils' screens must not join the shuffle."""
        text = (REPO / "game" / "music_library.gd").read_text(encoding="utf-8")
        for key in ("music_win_duel", "music_lose_duel"):
            self.assertNotIn('"%s"' % key, text)

    def test_a_1997_install_supplies_them_all(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "MagicTG"
            files = ["Sound/%s.wav" % n for n in ("Malewiz", "Fewiz", "Knight", "Lord", "Djinn",
                                                 "Troll", "Wyrm", "Dragon", "Flying", "Archmage",
                                                 "Dsummon", "Newsflash", "Dngnduel", "Winduel",
                                                 "Loseduel")]
            files.append("Duelsounds/Aswanjag.wav")
            for name in files:
                (root / name).parent.mkdir(parents=True, exist_ok=True)
                (root / name).write_bytes(b"RIFF " + name.encode())
            index = imp.build_index([root])
            for key in [k for k in imp.MANIFEST if k.startswith("sfx_cry_")] + [
                    "sfx_dsummon.wav", "sfx_newsflash.wav", "sfx_lair_duel.wav",
                    "sfx_dungeon_duel.wav", "music_win_duel.wav", "music_lose_duel.wav"]:
                self.assertIsNotNone(imp._first_of(index, imp.MANIFEST[key]), key)


def make_bmp(width: int, height: int, rgb: bytes, top_down: bool = False) -> bytes:
    """A 24-bit BI_RGB Windows bitmap of [rgb] (rows top to bottom) — the
    exact inverse of `read_bmp`, built here so no 1997 byte travels."""
    stride = (width * 3 + 3) & ~3
    body = bytearray()
    rows = range(height) if top_down else range(height - 1, -1, -1)
    for y in rows:
        line = bytearray()
        for x in range(width):
            r, g, b = rgb[(y * width + x) * 3:(y * width + x) * 3 + 3]
            line += bytes([b, g, r])
        body += line + b"\0" * (stride - width * 3)
    header = struct.pack("<IiiHHIIiiII", 40, width, -height if top_down else height, 1, 24, 0,
                         len(body), 2835, 2835, 0, 0)
    return b"BM" + struct.pack("<IHHI", 14 + 40 + len(body), 0, 0, 54) + header + bytes(body)


class TestTheWizardsHall(RawStepCase):
    """THE WIZARDS' WINDOW'S STILLS (2026-10-27, the owner: "With 1997
    stills", no movies): `Statwin/`'s 24-bit bitmaps, made RGBA with the
    colour Statwin's blit skipped made clear — pure green for the figures,
    black for the staffs and the skulls — and `Statscrn.wav`."""

    def test_every_still_names_its_statwin_file(self):
        self.assertEqual(len(imp.STATWIN_PICTURES), 1 + 5 * 5 + 7)
        self.assertEqual(imp.STATWIN_PICTURES["wizards_ground"], ["Statwin/Wizbg.bmp"])
        self.assertEqual(imp.STATWIN_PICTURES["wizards_figure_blue"], ["Statwin/Blu-Sprt.bmp"])
        self.assertEqual(imp.STATWIN_PICTURES["wizards_staff_lit_black"], ["Statwin/S-Bkwizy.bmp"])
        self.assertEqual(imp.STATWIN_PICTURES["wizards_staff_drained_green"], ["Statwin/S-Gwizr.bmp"])
        self.assertEqual(imp.STATWIN_PICTURES["wizards_gems_blue"], ["Statwin/U-Mana.bmp"],
                         "Statwin's U is blue")
        self.assertEqual(imp.STATWIN_PICTURES["wizards_room_white"], ["Statwin/Room-Wht.bmp"])
        self.assertEqual(imp.STATWIN_PICTURES["wizards_skulls_12"], ["Statwin/12skulls.bmp"])
        for key in imp.STATWIN_PICTURES:
            self.assertIn(key, imp.PIC_SCREENS, key + " is decoded with the screens")
            self.assertNotIn(key, imp.MANIFEST)
        self.assertNotIn("wizards_room_monster", imp.STATWIN_PICTURES, "Room-Mon.bmp is never shown")

    def test_each_still_clears_the_colour_statwin_skipped(self):
        for key in imp.STATWIN_PICTURES:
            if key.startswith("wizards_figure_"):
                self.assertEqual(imp.STATWIN_CLEAR[key], (0, 255, 0), key)
            elif key.startswith(("wizards_staff_", "wizards_skulls_")):
                self.assertEqual(imp.STATWIN_CLEAR[key], (0, 0, 0), key)
            else:
                self.assertNotIn(key, imp.STATWIN_CLEAR, key + " is opaque")

    def test_a_bitmap_is_read_bottom_up_with_its_rows_padded(self):
        rgb = bytes([255, 0, 0, 0, 255, 0, 0, 0, 255, 9, 8, 7, 1, 2, 3, 250, 251, 252])
        for top_down in (False, True):
            width, height, pixels = imp.read_bmp(make_bmp(3, 2, rgb, top_down))
            self.assertEqual((width, height), (3, 2))
            self.assertEqual(pixels, rgb, "top_down %s" % top_down)
        with self.assertRaises(ValueError):
            imp.read_bmp(b"\x89PNG\r\n\x1a\n" + b"\0" * 60)
        eight = bytearray(make_bmp(3, 2, rgb))
        struct.pack_into("<H", eight, 28, 8)
        with self.assertRaises(ValueError):
            imp.read_bmp(bytes(eight))
        with self.assertRaises(ValueError):
            imp.read_bmp(make_bmp(3, 2, rgb)[:-4])

    def test_alpha_is_zero_exactly_on_the_key(self):
        rgb = bytes([0, 255, 0, 0, 254, 0, 0, 0, 0, 1, 255, 1])
        rgba = imp.clear_colour(rgb, (0, 255, 0))
        self.assertEqual([rgba[i * 4 + 3] for i in range(4)], [0, 255, 255, 255],
                         "pure green clear; a near green stays")
        self.assertEqual(rgba[4:8], bytes([0, 254, 0, 255]), "the colour kept")
        self.assertEqual([imp.clear_colour(rgb, (0, 0, 0))[i * 4 + 3] for i in range(4)], [255, 255, 0, 255])

    def test_an_install_s_statwin_is_imported_keyed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "MagicTG"
            (root / "Statwin").mkdir(parents=True)
            green, black, grey = bytes([0, 255, 0]), bytes([0, 0, 0]), bytes([90, 90, 90])
            (root / "Statwin" / "Wizbg.bmp").write_bytes(make_bmp(2, 1, green + black))
            (root / "Statwin" / "Red-Sprt.bmp").write_bytes(make_bmp(2, 1, green + grey))
            (root / "Statwin" / "S-Rwizy.bmp").write_bytes(make_bmp(2, 1, black + green))
            (root / "Statwin" / "8skulls.bmp").write_bytes(make_bmp(2, 1, grey + black))
            (root / "Statscrn.wav").write_bytes(b"RIFF statscrn")
            dest = Path(tmp) / "skin"
            log = self._run(root, dest)
            self.assertIn("wizards_ground", log)
            _w, _h, channels, pixels = read_png((dest / "wizards_ground.png").read_bytes())
            self.assertEqual((channels, pixels), (3, green + black), "the hall: opaque, green and all")
            _w, _h, channels, pixels = read_png((dest / "wizards_figure_red.png").read_bytes())
            self.assertEqual((channels, pixels), (4, green + b"\0" + grey + b"\xff"), "green clear")
            _w, _h, channels, pixels = read_png((dest / "wizards_staff_lit_red.png").read_bytes())
            self.assertEqual(pixels, black + b"\0" + green + b"\xff", "black clear, green kept")
            _w, _h, channels, pixels = read_png((dest / "wizards_skulls_8.png").read_bytes())
            self.assertEqual(pixels[7], 0, "the skulls' black clear")
            self.assertEqual((dest / "sfx_wizards.wav").read_bytes(), b"RIFF statscrn")
            self.assertFalse((dest / "wizards_room_red.png").exists(), "what is not there is not made")

    def test_no_statwin_folder_is_no_failure(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "MagicTG"
            root.mkdir(parents=True)
            (root / "Statwin.bmp").write_bytes(b"not a folder")
            dest = Path(tmp) / "skin"
            log = self._run(root, dest)
            self.assertFalse(list(dest.glob("wizards_*")), "nothing made, nothing raised")
            self.assertIn("sfx_wizards.wav", log, "named among the missing")

    def test_a_broken_bitmap_is_skipped_not_fatal(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "MagicTG"
            (root / "Statwin").mkdir(parents=True)
            (root / "Statwin" / "Wizbg.bmp").write_bytes(b"BM broken")
            log = self._run(root, Path(tmp) / "skin")
            self.assertIn("SKIPPED Wizbg.bmp", log)

    def test_the_sound_is_the_install_s_root_statscrn(self):
        self.assertEqual(imp.MANIFEST["sfx_wizards.wav"], ["Statscrn.wav"])
        self.assertNotIn("creature_thumbs", imp.NOT_READ, "the hero pane's creature page reads it")

    def test_the_game_knows_each_still_s_1997_size(self):
        source = (REPO / "game" / "skin.gd").read_text(encoding="utf-8")
        for key, size in (("wizards_ground", (640, 480)), ("wizards_figure_blue", (160, 320)),
                          ("wizards_staff_lit_black", (60, 324)), ("wizards_gems_red", (48, 48)),
                          ("wizards_skulls_12", (640, 240)), ("wizards_room_green", (640, 480))):
            self.assertIn('\t"%s": Vector2i(%d, %d),' % (key, size[0], size[1]), source, key)

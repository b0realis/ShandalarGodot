#!/usr/bin/env python3
"""THE MANALINK DOOR — an opt-in second source for a player with no 1997 CD.

The skin is built off the player's own copy of the ORIGINAL 1997 game
(import_original.py; the owner, 2026-10-15: the skin pipeline works off
the original CD install alone). On 2026-10-17 the owner added the door
this file is: *"Lets have an option for the tool to use later manalink
install for all assets if user does not have original install of 1997!"*
So `import_original.py --manalink` (and `mtg_assets.py --manalink`) runs
the 1997 rows first, exactly as without the switch, and only THEN asks a
Manalink 3 install for each key the 1997 files did not answer.

WHAT A MANALINK INSTALL HOLDS. Its top folder keeps many 1997 files under
their own names, and those the 1997 rows already take. The rest of the
duel's art lives under `Program/` in MANALINK'S OWN FORMATS AND SIZES:
Windows BMPs (`Program/DuelArt/*.bmp`), PNGs wearing a `.pic` extension
(`Program/CardArt/`, `Program/DBArt/`, most of `Program/DuelArt/`), and a
JPEG card back. Many are Manalink's restyles of the 1997 pictures rather
than the pictures themselves, and many are drawn at twice the 1997 size.
The game cuts several skin keys by pixel coordinates measured on the 1997
files, so a Manalink file is taken only where its SHAPE lets the game use
it — see MANALINK below, one row per key with the rule that applies.

A BACKUP FOR THE PLAYER, NEVER A RELEASE SKIN. The owner, 2026-10-17:
*"No the default is 1997 skin. Manalink we will ship only the tool as a
backup! - we will never generate or include manalink only skin in
releases."* The default stays the 1997 game alone; this file ships in the
release only as part of the importer. A folder it wrote into carries
LABEL, and the release build refuses a skin with the label in it — see
THE LABEL at the end.

Standard library only, like the importer: BMP and PNG are decoded here;
the one JPEG (the card back) goes through ffmpeg when it is installed,
the same optional decoder the coin toss uses, and is reported otherwise.
"""

import shutil
import struct
import subprocess
import tempfile
import zlib
from pathlib import Path

# ---------------------------------------------------------------- decoders --


def decode_bmp(data: bytes) -> tuple[int, int, bytes]:
    """`(width, height, rgba)` of a Windows BMP: 1/4/8-bit palette, 24-bit,
    or 32-bit (BI_RGB or BI_BITFIELDS), bottom-up or top-down.

    Manalink's `Program/DuelArt/*.bmp` are 24-bit; the rest is here so a
    differently saved install does not fail on a format detail.
    """
    if data[:2] != b"BM":
        raise ValueError("not a BMP")
    offset = struct.unpack_from("<I", data, 10)[0]
    header = struct.unpack_from("<I", data, 14)[0]
    if header == 12:
        width, height, _planes, bits = struct.unpack_from("<HHHH", data, 18)
        compression, colours, entry = 0, 0, 3
    else:
        width, height, _planes, bits, compression = struct.unpack_from(
            "<iiHHI", data, 18)
        colours = struct.unpack_from("<I", data, 46)[0] if header >= 40 else 0
        entry = 4
    top_down = height < 0
    height = abs(height)
    if compression not in (0, 3):
        raise ValueError("compressed BMP (RLE) is not supported")
    palette: list[tuple[int, int, int]] = []
    if bits <= 8:
        count = colours or (1 << bits)
        base = 14 + header
        for i in range(count):
            b, g, r = data[base + i * entry:base + i * entry + 3]
            palette.append((r, g, b))
    masks = (0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000)
    if bits == 32 and compression == 3:
        masks = struct.unpack_from("<IIII" if header >= 56 else "<III",
                                   data, 54) + ((0,) if header < 56 else ())

    def channel(value: int, mask: int) -> int:
        if not mask:
            return 255
        shift = (mask & -mask).bit_length() - 1
        top = mask >> shift
        return ((value & mask) >> shift) * 255 // top

    stride = ((width * bits + 31) // 32) * 4
    # A 32-bit BI_RGB file's fourth byte is "unused" by the format, and an
    # editor that wrote no alpha leaves it 0 everywhere — read that as
    # opaque, as browsers do; a file whose fourth bytes vary carries alpha.
    if bits == 32 and compression == 0:
        fourth = data[offset + 3:offset + stride * height:4]
        if not any(fourth):
            masks = masks[:3] + (0,)
    out = bytearray(width * height * 4)
    for row in range(height):
        y = row if top_down else height - 1 - row
        line = data[offset + row * stride:offset + (row + 1) * stride]
        o = y * width * 4
        for x in range(width):
            if bits == 24:
                b, g, r = line[x * 3:x * 3 + 3]
                a = 255
            elif bits == 32:
                v = struct.unpack_from("<I", line, x * 4)[0]
                r, g, b = (channel(v, masks[0]), channel(v, masks[1]),
                           channel(v, masks[2]))
                a = channel(v, masks[3]) if masks[3] else 255
            elif bits in (1, 4, 8):
                per = 8 // bits
                byte = line[x // per]
                shift = (per - 1 - x % per) * bits
                r, g, b = palette[(byte >> shift) & ((1 << bits) - 1)]
                a = 255
            else:
                raise ValueError("a %d-bit BMP is not supported" % bits)
            out[o + x * 4:o + x * 4 + 4] = bytes((r, g, b, a))
    return width, height, bytes(out)


def decode_png(data: bytes) -> tuple[int, int, bytes]:
    """`(width, height, rgba)` of any non-interlaced PNG — grey, RGB,
    palette (with `tRNS`), grey+alpha or RGBA, 1 to 16 bits a sample.

    The importer's own `read_png` refuses anything it did not write, on
    purpose; a Manalink install's PNGs are somebody else's, so this is the
    general decoder: all five scanline filters, palettes and transparency.
    """
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    width = height = depth = colour = 0
    palette = b""
    trns = b""
    idat = bytearray()
    offset = 8
    while offset + 8 <= len(data):
        length = struct.unpack_from(">I", data, offset)[0]
        tag = data[offset + 4:offset + 8]
        payload = data[offset + 8:offset + 8 + length]
        if tag == b"IHDR":
            width, height, depth, colour, _c, _f, interlace = struct.unpack(
                ">IIBBBBB", payload[:13])
            if interlace:
                raise ValueError("an interlaced PNG is not supported")
        elif tag == b"PLTE":
            palette = payload
        elif tag == b"tRNS":
            trns = payload
        elif tag == b"IDAT":
            idat += payload
        elif tag == b"IEND":
            break
        offset += 12 + length
    samples = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[colour]
    bits_per_pixel = samples * depth
    bpp = max(1, bits_per_pixel // 8)
    stride = (width * bits_per_pixel + 7) // 8
    raw = zlib.decompress(bytes(idat))
    rows: list[bytearray] = []
    prev = bytearray(stride)
    pos = 0
    for _y in range(height):
        kind = raw[pos]
        line = bytearray(raw[pos + 1:pos + 1 + stride])
        pos += 1 + stride
        for i in range(stride):
            a = line[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            if kind == 1:
                line[i] = (line[i] + a) & 0xFF
            elif kind == 2:
                line[i] = (line[i] + b) & 0xFF
            elif kind == 3:
                line[i] = (line[i] + ((a + b) >> 1)) & 0xFF
            elif kind == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[i] = (line[i] + pred) & 0xFF
        rows.append(line)
        prev = line

    def raw_sample(line: bytearray, index: int) -> int:
        if depth == 8:
            return line[index]
        if depth == 16:
            return (line[index * 2] << 8) | line[index * 2 + 1]
        per = 8 // depth
        byte = line[index // per]
        shift = (per - 1 - index % per) * depth
        return (byte >> shift) & ((1 << depth) - 1)

    top = (1 << depth) - 1

    def sample(line: bytearray, index: int) -> int:
        value = raw_sample(line, index)
        if colour == 3:
            return value
        return value >> 8 if depth == 16 else value * 255 // top

    # `tRNS` for grey and RGB names ONE colour, in the file's own sample
    # values, that is fully transparent.
    grey_key = struct.unpack(">H", trns[:2])[0] if colour == 0 and trns else -1
    rgb_key = struct.unpack(">HHH", trns[:6]) if colour == 2 and trns else None
    out = bytearray(width * height * 4)
    for y, line in enumerate(rows):
        for x in range(width):
            o = (y * width + x) * 4
            if colour == 3:
                i = sample(line, x)
                r, g, b = palette[i * 3:i * 3 + 3]
                a = trns[i] if i < len(trns) else 255
            elif colour == 0:
                r = g = b = sample(line, x)
                a = 0 if raw_sample(line, x) == grey_key else 255
            elif colour == 4:
                r = g = b = sample(line, x * 2)
                a = sample(line, x * 2 + 1)
            elif colour == 2:
                r, g, b = (sample(line, x * 3), sample(line, x * 3 + 1),
                           sample(line, x * 3 + 2))
                a = 0 if rgb_key and tuple(
                    raw_sample(line, x * 3 + k) for k in range(3)) == rgb_key \
                    else 255
            else:
                r, g, b, a = (sample(line, x * 4 + k) for k in range(4))
            out[o:o + 4] = bytes((r, g, b, a))
    return width, height, bytes(out)


def decode_jpeg(path: Path) -> tuple[int, int, bytes] | None:
    """`(width, height, rgba)` of a JPEG through ffmpeg, or None when there
    is no ffmpeg — Python has no JPEG decoder in its standard library, and
    the coin toss already treats ffmpeg as the optional decoder."""
    program = shutil.which("ffmpeg")
    if not program:
        return None
    with tempfile.TemporaryDirectory(prefix="shandalar-jpeg-") as tmp:
        out = Path(tmp) / "frame.png"
        try:
            subprocess.run([program, "-loglevel", "error", "-y", "-i",
                            str(path), "-pix_fmt", "rgba", str(out)],
                           check=True, capture_output=True, timeout=60)
        except (OSError, subprocess.SubprocessError):
            return None
        return decode_png(out.read_bytes())


def decode_any(path: Path) -> tuple[int, int, bytes] | None:
    """Whatever the file IS, by its first bytes — a Manalink `.pic` is
    usually a PNG. None for a JPEG with no ffmpeg to read it; a format
    this cannot read at all raises ValueError."""
    data = path.read_bytes()
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return decode_png(data)
    if data[:2] == b"BM":
        return decode_bmp(data)
    if data[:2] == b"\xff\xd8":
        return decode_jpeg(path)
    raise ValueError("not a PNG, BMP or JPEG")


# -------------------------------------------------------------- resampling --


def halve(width: int, height: int, rgba: bytes) -> tuple[int, int, bytes]:
    """A 2x picture back to 1x: each output pixel the alpha-weighted mean
    of its 2x2 block, so a transparent neighbour does not darken an edge."""
    w, h = width // 2, height // 2
    out = bytearray(w * h * 4)
    for y in range(h):
        for x in range(w):
            r = g = b = a = 0
            for dy in (0, 1):
                for dx in (0, 1):
                    o = ((y * 2 + dy) * width + x * 2 + dx) * 4
                    pa = rgba[o + 3]
                    r += rgba[o] * pa
                    g += rgba[o + 1] * pa
                    b += rgba[o + 2] * pa
                    a += pa
            o = (y * w + x) * 4
            if a:
                out[o:o + 4] = bytes((r // a, g // a, b // a, a // 4))
    return w, h, bytes(out)


def resize(width: int, height: int, rgba: bytes, new_w: int,
           new_h: int) -> tuple[int, int, bytes]:
    """To exactly `new_w` x `new_h`, alpha-weighted, one axis at a time
    with a tent filter widened by the shrink factor — a true average when
    shrinking (a card frame at 0.68, the counter strip at 0.70) and plain
    bilinear when enlarging (the phase bar at 1.03)."""

    def taps(src: int, dst: int) -> list[list[tuple[int, float]]]:
        scale = src / dst
        support = max(1.0, scale)
        out = []
        for i in range(dst):
            centre = (i + 0.5) * scale - 0.5
            lo = int(centre - support) + 1
            hi = int(centre + support)
            row = []
            for j in range(max(0, lo), min(src - 1, hi) + 1):
                weight = 1.0 - abs(j - centre) / support
                if weight > 0:
                    row.append((j, weight))
            if not row:
                row = [(min(src - 1, max(0, round(centre))), 1.0)]
            total = sum(w for _j, w in row)
            out.append([(j, w / total) for j, w in row])
        return out

    # premultiplied floats, so a transparent neighbour adds no colour
    pre = [0.0] * (width * height * 4)
    for i in range(width * height):
        a = rgba[i * 4 + 3] / 255.0
        pre[i * 4] = rgba[i * 4] * a
        pre[i * 4 + 1] = rgba[i * 4 + 1] * a
        pre[i * 4 + 2] = rgba[i * 4 + 2] * a
        pre[i * 4 + 3] = rgba[i * 4 + 3]
    across = taps(width, new_w)
    mid = [0.0] * (new_w * height * 4)
    for y in range(height):
        base = y * width * 4
        for x, row in enumerate(across):
            o = (y * new_w + x) * 4
            r = g = b = a = 0.0
            for j, w in row:
                k = base + j * 4
                r += pre[k] * w
                g += pre[k + 1] * w
                b += pre[k + 2] * w
                a += pre[k + 3] * w
            mid[o], mid[o + 1], mid[o + 2], mid[o + 3] = r, g, b, a
    down = taps(height, new_h)
    out = bytearray(new_w * new_h * 4)
    for y, row in enumerate(down):
        for x in range(new_w):
            r = g = b = a = 0.0
            for j, w in row:
                k = (j * new_w + x) * 4
                r += mid[k] * w
                g += mid[k + 1] * w
                b += mid[k + 2] * w
                a += mid[k + 3] * w
            o = (y * new_w + x) * 4
            if a > 0.5:
                f = 255.0 / a
                out[o] = min(255, int(r * f + 0.5))
                out[o + 1] = min(255, int(g * f + 0.5))
                out[o + 2] = min(255, int(b * f + 0.5))
                out[o + 3] = min(255, int(a + 0.5))
    return new_w, new_h, bytes(out)


def over(top: bytes, bottom: bytes) -> bytes:
    """`top` composited over `bottom` (same size, straight alpha)."""
    out = bytearray(len(top))
    for i in range(0, len(top), 4):
        ta = top[i + 3]
        if ta == 255:
            out[i:i + 4] = top[i:i + 4]
            continue
        ba = bottom[i + 3]
        if ta == 0:
            out[i:i + 4] = bottom[i:i + 4]
            continue
        a = ta + ba * (255 - ta) // 255
        for c in range(3):
            out[i + c] = (top[i + c] * ta
                          + bottom[i + c] * ba * (255 - ta) // 255) // max(a, 1)
        out[i + 3] = a
    return bytes(out)


# ------------------------------------------------------------ the rows --
#
# One row per skin key a Manalink install can answer that its 1997 files
# under their own names do not. Each RULE is what the game needs of the
# file, read off the code that draws the key (2026-10-17, a read of every
# consumer; the numbers are in the comments where they decide):
#
#   SAME  cut by pixel coordinates or margins measured on the 1997 file:
#         taken at the 1997 size, or at exactly twice it (halved), and
#         otherwise not at all.
#   FIT   resized to the 1997 size: the game's cells are FRACTIONS of the
#         file or constants that a resized file still meets.
#   OWN   taken at its own size — the game fits, stretches or tiles the
#         whole file, or measures it — except that exactly twice the 1997
#         size is halved, to draw at the scale everything else does.
#
# `opaque` drops a file's alpha: Manalink's 32-bit BMPs use that byte for
# masks of their own, not as transparency.

SAME, FIT, OWN = "same", "fit", "own"


class Row:
    def __init__(self, names: list[str], rule: str, size: tuple[int, int],
                 opaque: bool = False):
        self.names, self.rule, self.size, self.opaque = names, rule, size, opaque


COLOURS = ("white", "blue", "black", "red", "green")

MANALINK: dict[str, Row] = {
    # THE TERRITORIES. All fifteen of Manalink's are ONE picture — the
    # same green felt with a 4px frame, byte for byte — so every colour and
    # all three styles look alike. Taken because it is what a Manalink
    # player's table looks like: the picture is cover-fitted
    # (territory_ground.gd), the mana style tiled at its own size, and the
    # pattern style's nine-patch border (8 px, 20 on black) holds the 4px
    # frame.
    **{"duel_%s_%s" % (style, c): Row(
        ["DuelArt/Terr_%s%s.bmp" % (c.capitalize(), suffix)], OWN,
        (888 if (style, c) in (("pattern", "black"), ("pattern", "red"),
                               ("picture", "white"), ("picture", "black"),
                               ("picture", "green")) else 721, 381))
       for style, suffix in (("pattern", "Patt"), ("picture", "Pict"),
                             ("mana", "Mana"))
       for c in COLOURS},
    # The card back: Manalink's is a JPEG at exactly twice the 1997 size.
    "card_back": Row(["CardArt/CardBack.pic"], FIT, (228, 323)),
    # The life register: one grey gradient for every colour, at twice the
    # size; a StyleBoxTexture stretches it (duel_screen.gd).
    **{"life_panel_%s" % c: Row(["DuelArt/Life_%sPatt.bmp" % c.capitalize()],
                                OWN, (120, 88)) for c in COLOURS},
    # The dialog grounds — nine-patches with 4-5 px margins
    # (original_dialog.gd PANELS); Manalink's are plain grey restyles with
    # a bevel inside those margins.
    "panel_stone": Row(["DuelArt/WinBk_Options.pic"], OWN, (400, 350)),
    "panel_dark_stone": Row(["DuelArt/WinBk_QuestMana.pic"], OWN, (289, 274)),
    "panel_knot": Row(["DuelArt/WinBk_ChangeText.pic"], OWN, (481, 323)),
    "panel_end_duel": Row(["DuelArt/WinBk_EndDuel.bmp"], OWN, (272, 422)),
    "big_card_panel": Row(["DuelArt/WinBk_BigCard.bmp"], OWN, (552, 402),
                          opaque=True),
    "versus_background": Row(["DuelArt/WinBk_StartDuel.bmp"], OWN, (659, 394)),
    "attack_panel": Row(["DuelArt/WinBk_Attack.pic"], OWN, (888, 316)),
    # Buttons: a nine-patch with an 8 px margin and a tiled centre.
    "button_normal": Row(["DuelArt/WinBk_StartDuelButtonNormal.bmp"], SAME,
                         (131, 36)),
    "button_pressed": Row(["DuelArt/WinBk_StartDuelButtonDepressed.bmp"],
                          SAME, (131, 36)),
    "button_disabled": Row(["DuelArt/WinBk_StartDuelButtonDisabled.bmp"],
                           SAME, (131, 36)),
    # The phase and combat bars are cut by constants (phase_bar.gd,
    # combat_bar.gd: 35x40 cells at a 41 px pitch); Manalink's 80x735 and
    # 160x735 resized to 82x760 and 164x760 put every cell within 1-2 px.
    "phase_bar": Row(["DuelArt/WinBk_Phase.pic"], FIT, (82, 760)),
    "combat_bar": Row(["DuelArt/WinBk_PhaseCombat.pic"], FIT, (164, 760)),
    "attack_min": Row(["DuelArt/WinBk_AttackMin.pic"], OWN, (39, 70)),
    "mana_pool_panel": Row(["DuelArt/WinBk_ManaPool.pic"], OWN, (128, 188)),
    # Tiled at its own size under a rule the code draws: resized, so the
    # strip is the 1997 height.
    "message_panel": Row(["DuelArt/WinBk_TellUser.bmp"], FIT, (600, 35)),
    **{"grave_panel_%s" % c: Row(["DuelArt/Grave_%s.bmp" % c.capitalize()],
                                 OWN, (61, 91)) for c in COLOURS},
    # The card overlays: an image half beside a mask half, split at w/2
    # and fitted (mini_card.gd masked_sprite).
    "summon_sick": Row(["CardArt/Summon.pic"], OWN, (194, 97)),
    "state_cant_target": Row(["CardArt/CantTarget.pic"], OWN, (130, 65)),
    "state_will_untap": Row(["CardArt/WillUntap.pic"], OWN, (110, 59)),
    # Also the targeting CURSOR, cut raw at (0, 0, h, h) and shown at its
    # own size: resized, or the cursor would be 103 px.
    "target_cursor": Row(["CardArt/Target.pic"], FIT, (122, 61)),
    # Six cells, each height/6, read through a fixed 17x16 window.
    "mana_stripes": Row(["CardArt/ManaStripes.pic"], FIT, (54, 126)),
    # Twenty-five cells of 24x30 (counter_marks.gd); Manalink's 34x1075
    # holds the same twenty-five, mask included.
    "card_counters": Row(["CardArt/CardCounters.bmp"], FIT, (24, 750)),
    "deck_title_slab": Row(["DBArt/DekTit1.pic"], SAME, (291, 73)),
    "deck_bar_ground": Row(["DBArt/DekBar1.pic"], OWN, (1006, 198)),
    "deck_tile_slate": Row(["DBArt/DekTile4.pic"], SAME, (32, 32)),
    # The title face: Manalink's copy is byte for byte the disc's
    # `Magim___.ttf` (md5 6d2dac9052).
    "font_title.ttf": Row(["MagicMedieval.ttf"], OWN, (0, 0)),
}

## THE CARD FRAMES ARE TWO FILES in Manalink — `Classic/CardBk_*` (the
## stone) under `Classic/CardOv_*` (the bevels and the text plate) — at
## 337x484. Laid over each other and resized to 228x325 they meet the
## 1997 fractions the card is laid out by (mini_card.gd's 5.5 % title
## strip, card_preview.gd's plate at 0.083-0.917 x 0.603-0.915) within
## about 1 %. The art window is transparent in both; it is filled with
## the 1997 frame's dark so a card with no picture is not see-through.
FRAMES: dict[str, tuple[str, str]] = {
    "card_frame_white": ("CardBk_White", "CardOv_W"),
    "card_frame_blue": ("CardBk_Blue", "CardOv_U"),
    "card_frame_black": ("CardBk_Black", "CardOv_B"),
    "card_frame_red": ("CardBk_Red", "CardOv_R"),
    "card_frame_green": ("CardBk_Green", "CardOv_G"),
    "card_frame_gold": ("CardBk_Gold", "CardOv_Gold"),
    "card_frame_artifact": ("CardBk_Artifact", "CardOv_Artifact"),
    "card_frame_land_white": ("CardBk_Land", "CardOv_WLand"),
    "card_frame_land_blue": ("CardBk_Land", "CardOv_ULand"),
    "card_frame_land_black": ("CardBk_Land", "CardOv_BLand"),
    "card_frame_land_red": ("CardBk_Land", "CardOv_RLand"),
    "card_frame_land_green": ("CardBk_Land", "CardOv_GLand"),
}
FRAME_SIZE = (228, 325)
FRAME_WINDOW = (32, 32, 32, 255)

## What a Manalink install HAS for a key but the game cannot use — said in
## THE CHECKLIST so a player knows the gap is deliberate, and left to the
## game's own drawing.
NOT_USED: dict[str, str] = {
    **{"duelist_face_%s" % c: "Life_%sPict.bmp is a plain grey gradient "
       "with no face in it" % c.capitalize() for c in COLOURS},
    **{"hand_panel_%s" % c: "Hand_%s.bmp is one grey bar for every colour, "
       "without the borders and arrows the game cuts" % c.capitalize()
       for c in COLOURS},
    "attack_sword": "WinBk_AttackSword.pic has no mask the game can read: "
                    "it would draw nothing",
    "attack_shield": "WinBk_AttackShield.pic has no mask the game can read: "
                     "it would draw nothing",
    "attack_bones": "WinBk_AttackBones.pic is a grey gradient, not the bones",
    "ability_icons": "Abilities.pic is a 10x5 grid in another order: every "
                     "badge would come out empty",
    "versus_splash": "WinBk_Versus16.bmp has its two portrait wells "
                     "elsewhere than the game places the faces",
}


def compose_frame(index: dict[str, Path], key: str
                  ) -> tuple[tuple[int, int, bytes], Path] | None:
    """One 1997-shaped card frame out of Manalink's two Classic layers."""
    stone, plate = FRAMES[key]
    paths = [index.get(("classic/%s.png" % name).lower())
             for name in (stone, plate)]
    if None in paths:
        return None
    bw, bh, bottom = decode_png(paths[0].read_bytes())
    tw, th, top = decode_png(paths[1].read_bytes())
    if (bw, bh) != (tw, th):
        return None
    window = bytes(FRAME_WINDOW) * (bw * bh)
    layered = over(top, over(bottom, window))
    return resize(bw, bh, layered, *FRAME_SIZE), paths[1]


def fill(index: dict[str, Path], dest: Path, missing: list[str],
         write_png) -> tuple[list[tuple[str, Path, str]], dict[str, str]]:
    """Answer what `missing` can from a Manalink install's own files.

    Returns `(taken, refused)`: each key written with its source and how it
    was taken, and for a key Manalink HAS but in a shape the game cannot
    use, why it was left to the game's own drawing."""
    taken: list[tuple[str, Path, str]] = []
    refused: dict[str, str] = {}
    for key in list(missing):
        if key in NOT_USED:
            refused[key] = NOT_USED[key]
            continue
        if key in FRAMES:
            framed = compose_frame(index, key)
            if framed is not None:
                (width, height, rgba), path = framed
                write_png(dest / (key + ".png"), width, height, rgba,
                          alpha=True)
                how = "Classic stone and plate laid together, resized"
                print("  %-24s <- %s (Manalink, %s)" % (key, path, how))
                taken.append((key, path, how))
            continue
        row = MANALINK.get(key)
        if row is None:
            continue
        for name in row.names:
            path = index.get(name.lower())
            if path is None:
                continue
            if key.endswith((".wav", ".ttf")):
                shutil.copyfile(path, dest / key)
                print("  %-24s <- %s (Manalink, copied)" % (key, path))
                taken.append((key, path, "copied"))
                break
            try:
                decoded = decode_any(path)
            except (ValueError, struct.error, zlib.error, KeyError,
                    IndexError) as exc:
                refused[key] = "%s would not decode (%s)" % (path.name, exc)
                continue
            if decoded is None:
                refused[key] = ("%s is a JPEG, and reading it needs ffmpeg"
                                % path.name)
                continue
            width, height, rgba = decoded
            want_w, want_h = row.size
            if (width, height) == row.size:
                how = "as is"
            elif (width, height) == (want_w * 2, want_h * 2):
                width, height, rgba = halve(width, height, rgba)
                how = "halved from %dx%d" % (want_w * 2, want_h * 2)
            elif row.rule == FIT:
                how = "resized from %dx%d" % (width, height)
                width, height, rgba = resize(width, height, rgba, want_w,
                                             want_h)
            elif row.rule == OWN:
                how = "as is, %dx%d" % (width, height)
            else:
                refused[key] = ("%s is %dx%d; the game cuts this one at the "
                                "1997 %dx%d" % (path.name, width, height,
                                                want_w, want_h))
                continue
            if row.opaque:
                rgba = bytes(b if i % 4 != 3 else 255
                             for i, b in enumerate(rgba))
            write_png(dest / (key + ".png"), width, height, rgba, alpha=True)
            print("  %-24s <- %s (Manalink, %s)" % (key, path, how))
            taken.append((key, path, how))
            refused.pop(key, None)
            break
    return taken, refused


# --------------------------------------------------------------- the label --
#
# NEVER IN A RELEASE (the owner, 2026-10-17, in the docstring above). A
# skin folder the door wrote into carries LABEL, one key per line, and the
# release build refuses a skin with the label in it — build_release.sh's
# skin_zip before it zips assets/original, and package_release.check_skin
# on the zip itself — so a released skin is the 1997 game's and ours,
# whatever the owner's own folder once held. The label travels in a
# player's own zip too (mtg_assets.py --from-skin packs every file), which
# is what lets the packager see it there.
#
# It stays TRUE across imports into the same folder: a later run without
# --manalink writes over some of those keys with 1997 files and leaves the
# rest, so the label keeps exactly the keys no later run wrote over, and
# goes once none are left.
LABEL = "from_manalink.txt"


def write_label(dest: Path, taken: list[str], rewritten: set[str]) -> None:
    """Keep `dest/LABEL` true: the keys this run took from Manalink, plus
    those an earlier run took that this run did not write over."""
    label = dest / LABEL
    keys = set(taken)
    if label.exists():
        keys |= {line.strip() for line in label.read_text().splitlines()
                 if line.strip() and not line.startswith("#")}
    keys -= rewritten
    if not keys:
        label.unlink(missing_ok=True)
        return
    label.write_text(
        "# Skin files taken from a Manalink install (import_original.py\n"
        "# --manalink): a player's backup, never part of a release.\n"
        + "".join(key + "\n" for key in sorted(keys)))

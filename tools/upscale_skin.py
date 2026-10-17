#!/usr/bin/env python3
"""Make the hi-res skin: a 1997 skin with every picture at twice the size.

    python3 upscale_skin.py                              # assets/original -> the hi-res skin zip
    python3 upscale_skin.py --skin original_skin.zip     # a skin zip works too
    python3 upscale_skin.py --skin DIR --out DIR2        # the hi-res skin into a folder
    python3 upscale_skin.py --skin original_skin.zip --reuse original_skin_realesrgan-anime_2x.zip

The game is laid out for 1280x800 and drawn at the screen's real
resolution, so on a 4K screen the 1997 pictures are stretched about 2.7x
and look soft. This writes THE HI-RES SKIN — the zip
`original_skin_realesrgan-anime_2x.zip`, or a folder: THE SAME FILES as
the 1997 skin it is made from, under the same names — the music, sounds,
fonts, sheet layouts, movies and portraits as they were — and every
picture REPLACED by the same picture at twice the size. Built from a
242-file `original_skin.zip` it holds 242 files. The owner, 2026-10-17:
*"A skin is a skin and gets applied after game reset. No switches."*,
*"hires skin zip is hires, low res skin zip is low res oroginal -
simple"*, *"Each skin pack zip should contain all required assets. Just
in the upscaled the relevant assets are upscaled!"*. It is a skin like
the 1997 one: choose it in Options > Skin or drop it on the window and it
is worn from the next start, with the same layout — the game draws a
picture of exactly twice its place's 1997 size at the 1997 size, with all
its pixels (game/skin.gd, THE 2x PICTURES). Choose the 1997 skin again to
go back. How this was made goes in the zip's COMMENT, not in a file, so
the two skins hold the same files.

MIX AND MATCH (the owner, the same day: *"users should be able to mix and
match some upscaled and some downscaled images as they wished"*). Put a
1997 picture back into the hi-res zip under its own name, and that place
wears the 1997 picture again; or give the skin a `catalogue.txt` that
points a place at any file (SKIN.txt, THE CATALOGUE). The sizes the game
wears — 1x to 4x a place's 1997 size — are SKIN.txt's, SIZES AND SCALES.

KEY-EXACT PICTURES. A few places the game does not only draw: it takes a
colour out of them, crops them to their ink, or measures them (KEY_EXACT,
each with the cutter that needs it). With no 1x file beside a 2x
picture the game decides those on the picture brought back to its 1997
size — every 2x2 block averaged — and an upscaler's blend moves the
answer: measured on the real pictures, the mana stripes' cut-out edges
differed 0.4-9.6%, the set symbols lost their ink box, 14 of the 15
territory grounds their black-edge trim, and the exile plate's palette
drifted. So for those places every 2x2 block of the 2x picture is made
to average EXACTLY to its 1997 pixel (its RGB sums are four times the
1997 value, the correction spread over the block; its alpha is the 1997
alpha) — the whole picture for the small sheets and the grave plates,
only the outer ring of 1997 pixels (the conversion edge the game trims)
for the territory grounds — and the game's own shrink gives back the
1997 picture, so it cuts exactly what the 1997 skin cuts. Every other
picture keeps the model's pixels as they are.

REUSE (the owner, 2026-10-17: *"I already have built 2x skin so we will
reuse it"*). `--reuse` takes each picture's 2x copy from a zip or folder
already made — `<name>@2x.png` (the 0.50.28 tool's zip), or a picture of
its own name that is exactly twice its 1997 size (a hi-res skin this tool
wrote) — instead of running the engine again. A copy is taken only when
it is exactly twice its picture's size AND, brought back to 1x and
softened by REUSE_BLUR, it is within REUSE_MATCH of the picture (alpha
within REUSE_ALPHA): every copy of this method lies within 4.6 of its own
picture there, while any other picture of the same size lies 10 or more
away — so a copy made from another skin's picture is
upscaled again rather than worn over the wrong art. The key-exact step
is applied to a reused copy too. A run that reuses every picture never
fetches or starts the engine.

THE METHOD (the owner, 2026-10-17, after comparing eleven upscalers on
the skin: *"lets keep this default"*). Real-ESRGAN's anime model
(`realesrgan-x4plus-anime`, run at 4x and brought down to 2x) gives the
cleanest look of the free tools — the 256-colour dithering becomes clean
surfaces — but it pushes colour (the red duel picture came out 26 points
more saturated). So its broad colour is taken back from the 1997 picture:

    out = model + blur(1997 at 2x) - blur(model)       blur: 1 px at 1997 size

Everything finer than the blur (edges, lines, the model's surfaces) stays
the model's; everything broader (the colour of a sky, a robe, a stone) is
the original's again. Measured over the whole skin, the colour drift fell
from 3.3 to 0.9 (a plain resize scores 0.5) and the saturation push from
+4.2 to 0.0.

WHAT EVERY PICTURE GETS before the model sees it, and why:
  * transparent pixels are filled with their opaque neighbours' colours
    (BLEED_STEPS), so the model never smears the hidden colour into a
    cut-out's edge — the dark fringe;
  * PAD pixels of border, copied from the edge, cut off again afterwards,
    so the border upscales like the middle; the textures the game REPEATS
    (TILED) are padded with a whole wrapped copy of themselves instead,
    so the 2x copy still meets itself without a seam;
  * opaque colour only: the transparency is scaled here — smoothed, then
    cut at half — so a cut-out stays on/off, as the game expects, without
    its 1997 staircase.

THE ENGINE is Real-ESRGAN ncnn-vulkan (MIT; models BSD-3, Xintao Wang et
al.), one program that runs on any Vulkan GPU — NVIDIA, AMD or Intel —
without CUDA or Python packages. On Linux it is fetched once from its
GitHub release, checked against ENGINE_SHA256 and kept in
~/.cache/shandalar/; anywhere else, `--engine` names your own copy.
Pictures are read and written with Pillow (`python3-pil`, or `pip install
pillow`), the one thing this tool needs that the other skin tools do not.

TWO KNOWN LOOKS, LEFT AS THEY ARE (examined 2026-10-17; the owner: *"No
lets leave as is and document for the future"*). Fifteen pictures carry
their look in single 1997 pixels, which is the scale the anime model
redraws and the colour fix's 1 px blur does not reach:
  * the scanline duelist faces (`duelist_face_*`): one-pixel dark rows
    the model inks as near-black lines — row brightness 0.38..0.54 in
    1997, 0.17..0.66 shipped (contrast 0.16 -> 0.50). A stripe every two
    or three pixels already averages to the right colour, so the fix has
    nothing to correct;
  * the dithered grounds (`duel_mana_*`, `duel_pattern_*`): single red
    and green dots, 17% of the pixels, that the model takes for noise
    (4.6% left after the fix) and whose cluster edges it inks as strokes,
    so the carved symbols stand alone and read as embossed stone.
Measured on `duel_mana_green` and `duelist_face_green`. A player who
prefers the 1997 look there puts those 1997 files back into the hi-res
zip (MIX AND MATCH, above). The way out for the tool, if it is ever
wanted: give those fifteen keys another method — exact pixel doubling
(the 1997 look, crisp, no second engine; the one recommended) or waifu2x
CUNet (dots kept, 18.7%; stripes 0.34) — rather than a finer blur, which
would bring the dither dots back on every picture.

ONE PICTURE DOUBLED, NOT UPSCALED (the owner's playtest of 0.50.31):
the sandstone, `panel_stone`, which the game stretches over its stone
windows and squeezes into every main-menu button. The model smoothed its
one-pixel grain and streaked its edge rows, so the buttons wore streaked
strips round a smeared middle; doubled pixel for pixel (DOUBLED) it is
the 1997 stone, crisp at twice the pixels.

LEFT AS THEY ARE, under their own names: the coin-toss movie sheets
(2240x2160 already; twice that is past the 4096-pixel texture limit of
older GPUs), the sounds, the fonts, the sheet layouts and the movies.
NOT CARRIED: card pictures (`cardart/`, a zip of their own), Godot's
`.import` files, and what an earlier tool left in a skin — a
`catalogue.txt`, an `UPSCALE.txt`, `<name>@2x.png` copies (reuse those
with --reuse).

A skin the Manalink door filled (`import_original.py --manalink`) keeps
its label in the hi-res skin (`from_manalink.txt`), and a release refuses
it the same way it refuses the skin it came from (tools/import_manalink.py).
"""

from __future__ import annotations

import argparse
import hashlib
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile
from contextlib import contextmanager, nullcontext
from pathlib import Path, PurePosixPath

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))
import import_manalink  # noqa: E402  — THE LABEL a Manalink-filled skin carries
import tool_banner  # noqa: E402  — the family banner and the one version

try:
    from PIL import Image, ImageChops, ImageFilter, ImageStat
except ImportError:  # said at the door (need_pillow), not as a traceback
    Image = None

TOOL = "upscale_skin.py"
## The tool's name in the half-height box-drawing face the whole family is
## set in (DeckLab/lab_console.gd's WORDMARK is the same font).
WORDMARK = (
    "┬ ┬┌─┐┌─┐┌─┐┌─┐┬  ┌─┐",
    "│ │├─┘└─┐│  ├─┤│  ├┤ ",
    "└─┘┴  └─┘└─┘┴ ┴┴─┘└─┘",
)
CAPTION = ("Shandalar 1997 · the hi-res skin", "twice the size, the 1997 colours")

## `tools/` in a checkout, nothing beside a packaged game
## (tool_banner.here_prefix()).
WHERE = tool_banner.here_prefix(__file__)
HINT = (
    "python3 %supscale_skin.py --skin original_skin.zip   # the hi-res skin" % WHERE,
    "python3 %supscale_skin.py --skin DIR --out DIR2      # into a folder" % WHERE,
    "python3 %supscale_skin.py -h          # --reuse, --zip, --engine" % WHERE,
)

EPILOG = """\
%s
    python3 %supscale_skin.py --skin DIR --zip FILE   name the zip yourself
    python3 %supscale_skin.py --engine /path/to/realesrgan-ncnn-vulkan
    python3 %supscale_skin.py --gpu 1                 pick the Vulkan GPU
    python3 %supscale_skin.py --skin skin.zip --reuse 2x.zip   reuse a 2x zip

Writes the hi-res skin, original_skin_realesrgan-anime_2x.zip (or with
--out another folder): the same files as the 1997 skin, under the same
names, every picture replaced by the same picture at twice the size
(Real-ESRGAN's anime model, its colours taken back from the 1997
picture). Choose it in Options > Skin like the 1997 one; to mix, put a
1997 picture back into it under its name. --reuse takes the 2x pictures
of a zip or folder already made and upscales only what it lacks. Needs
Pillow and a Vulkan GPU driver; on Linux the engine is fetched once into
~/.cache/shandalar/.

%s
""" % (tool_banner.examples(HINT), WHERE, WHERE, WHERE, WHERE,
       tool_banner.BANNER_HELP)

DEFAULT_SKIN = ROOT / "assets" / "original"

SCALE = 2
## The name of the method, carried by the zip's name and by nothing the
## game reads: a second method would be a second zip beside this one.
METHOD = "realesrgan-anime"
ZIP_NAME = "original_skin_%s_%dx.zip" % (METHOD, SCALE)
## What the 0.50.28 tool called a 2x picture: `title_background.png` ->
## `title_background@2x.png`. This tool writes the picture under its OWN
## name; it reads `@2x` copies only to reuse them (--reuse), and never
## carries one over from the skin it reads. The game still wears one
## (game/skin.gd, THE @2x NAME).
SUFFIX = "@%dx" % SCALE
## What earlier tools left in a skin, never carried into the hi-res one:
## the catalogue 0.50.30's wrote, the note 0.50.28's wrote.
OLD_FILES = ("catalogue.txt", "UPSCALE.txt")
## Never copied into the hi-res skin: card pictures travel in a zip of
## their own, and a release refuses a skin that holds them.
NOT_COPIED_DIRS = ("cardart",)

## REUSE (above): a copy is taken when, brought back to 1x and both
## softened by a REUSE_BLUR px blur, its colour is within REUSE_MATCH (the
## mean of |difference| over the picture's opaque pixels, per channel, in
## 8-bit levels) of the picture, and its on/off alpha differs on no more
## than REUSE_ALPHA of the pixels. Calibrated 2026-10-17 on the 0.50.28
## zip against the released original_skin.zip: its 167 copies of the
## same art lie 0.38-4.55 away (the far one a portrait whose hidden
## pixels the blur reaches, rogue_kiska-ra); each of the 3604 copies
## against another picture of the same size, 10.04 or more; the one
## picture whose art differs (damage_marker.png, a size apart) is
## upscaled again. 7.0 sits between the two.
REUSE_BLUR = 1.0
REUSE_MATCH = 7.0
REUSE_ALPHA = 0.01

## THE KEY-EXACT PLACES (above): what the game does with each without its
## 1x file, and how much of the picture is made exact — "whole", or
## "ring", the outer 1997 pixels alone. A name ending in `_` is a family.
## Everything the game only cuts and draws, or whose key survives the
## upscale as it is (the image+mask sprites, the counter stones, the
## combat bar: within 0.01% measured), keeps the model's pixels.
KEY_EXACT = (
    # MiniCard.stripe_texture keys the near-black around each stripe:
    # the upscaler's blend at a stripe's edge is neither black nor band.
    ("mana_stripes", "whole"),
    # SetBadges.symbol keys pure black and crops the symbol to its ink.
    ("card_set_symbols", "whole"),
    # DuelScreen builds the mouse cursor from the picture's 1x pixels.
    ("target_cursor", "whole"),
    # ExilePlate paints the exile plate from the grave plate's palette,
    # counted colour by colour.
    ("grave_panel_", "whole"),
    # TerritoryGround._inner trims the 1px black conversion edge when it
    # measures one: only that ring, which is never shown, is made exact.
    ("duel_pattern_", "ring"),
    ("duel_picture_", "ring"),
    ("duel_mana_", "ring"),
)

## DOUBLED, NOT UPSCALED: every pixel made a 2x2 block, the 1997 grain
## kept exactly. The owner's playtest of 0.50.31: *"sandstone window
## backs look a bit blurry - are they stretched?, sandstone colored
## buttons look strange with top and botton stripes and blurry middle"*.
## `panel_stone` is the 400x350 sandstone the game STRETCHES over every
## stone window and SQUEEZES into every main-menu button
## (`UiChrome.stone_panel`: a 260x46 button holds 334 of its rows in
## 30). Its 1997 grain is a one-pixel dither, which a squeeze or a
## stretch leaves reading as stone; the model smooths that dither away
## and draws streaks along the edge rows it is padded from, so a button
## wore two crisp streaked strips in its 8px frame around a smeared
## middle. Doubled, it is the 1997 stone at twice the pixels.
DOUBLED = ("panel_stone",)

ENGINE_EXE = "realesrgan-ncnn-vulkan"
ENGINE_BUILD = "20220424"
ENGINE_URL = ("https://github.com/xinntao/Real-ESRGAN/releases/download/"
              "v0.2.5.0/realesrgan-ncnn-vulkan-20220424-ubuntu.zip")
ENGINE_SHA256 = "e5aa6eb131234b87c0c51f82b89390f5e3e642b7b70f2b9bbe95b6a285a40c96"
MODEL = "realesrgan-x4plus-anime"
MODEL_SCALE = 4
## What is taken out of the release zip; its demo pictures and video, and
## the models this method does not use, stay in it.
ENGINE_MEMBERS = (ENGINE_EXE, "models/%s.param" % MODEL, "models/%s.bin" % MODEL)

## The colour fix's blur, in 1997 pixels. Tuned on the skin (0.75 to 4
## tried): at 1 the stone's mottling comes back as soft texture without
## the dither dots; wider blurs flatten it again.
COLOUR_BLUR = 1.0
PAD = 8
PAD_TILED_MAX = 64
BLEED_STEPS = 16
## Repeated by the game (dialog grounds, the deck builder's floor, the
## combat window's bones), so padded by wrapping.
TILED = {"deck_tile_olive", "deck_tile_slate", "message_panel", "attack_bones"}
LEFT_ALONE = ("coin_toss_",)


# ---------------------------------------------------------------- the skin

def pictures(skin: Path) -> list[str]:
    """The keys to upscale: every top-level and portrait PNG, minus the
    movie sheets and the `@2x` copies a skin may already hold."""
    found = sorted(skin.glob("*.png")) + sorted(skin.glob("portraits/*.png"))
    return [path.relative_to(skin).as_posix()[:-4] for path in found
            if not path.name.startswith(LEFT_ALONE) and SUFFIX not in path.name]


def skin_files(skin: Path) -> list[str]:
    """Every file the hi-res skin holds, by its name under `skin/`: the
    skin's own, but card pictures, Godot's `.import` sidecars and what
    an earlier tool left (OLD_FILES, `@2x` copies)."""
    out = []
    for path in sorted(skin.rglob("*")):
        if not path.is_file():
            continue
        name = path.relative_to(skin).as_posix()
        if (name.split("/")[0] in NOT_COPIED_DIRS or name in OLD_FILES
                or name.endswith(".import")
                or (path.suffix.lower() == ".png" and path.stem.endswith(SUFFIX))):
            continue
        out.append(name)
    return out


@contextmanager
def opened(skin: Path):
    """A skin folder as it is, or a skin zip unpacked whole (but its card
    pictures) into a temporary folder for the run."""
    if skin.is_dir():
        yield skin
        return
    with tempfile.TemporaryDirectory(prefix="shandalar-skin-") as tmp, \
            zipfile.ZipFile(skin) as archive:
        folder = Path(tmp)
        for entry in archive.infolist():
            parts = PurePosixPath(entry.filename).parts
            if (len(parts) < 2 or parts[0] != "skin" or ".." in parts
                    or "\\" in entry.filename or entry.is_dir()
                    or parts[1] == "cardart"):
                continue
            inner = PurePosixPath(*parts[1:])
            target = folder.joinpath(*inner.parts)
            target.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(entry) as src, open(target, "wb") as dst:
                shutil.copyfileobj(src, dst)
        yield folder


# ---------------------------------------------------------------- pictures

def _shifted(image: "Image.Image", dx: int, dy: int) -> "Image.Image":
    """[param image] moved by (dx, dy) without wrapping; what it uncovers
    is black (and for a mask: unknown)."""
    out = Image.new(image.mode, image.size)
    out.paste(image, (dx, dy))
    return out


def bleed(picture: "Image.Image") -> "Image.Image":
    """The opaque colour of [param picture], its transparent pixels filled
    from their opaque neighbours BLEED_STEPS pixels deep (what a model can
    see from an edge), and with the mean opaque colour beyond that."""
    rgb = picture.convert("RGB")
    known = picture.getchannel("A").point(lambda v: 255 if v > 0 else 0)
    low, high = known.getextrema()
    if low == 255 or high == 0:
        return rgb
    histogram = rgb.histogram(mask=known)
    count = sum(histogram[:256])
    mean = tuple(round(sum(i * n for i, n in enumerate(histogram[c * 256:(c + 1) * 256])) / count)
                 for c in range(3))
    filled = Image.new("RGB", rgb.size, mean)
    filled.paste(rgb, mask=known)
    for _ in range(BLEED_STEPS):
        if known.getextrema()[0] == 255:
            break
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            new = ImageChops.subtract(_shifted(known, dx, dy), known)
            filled.paste(_shifted(filled, dx, dy), mask=new)
            known = ImageChops.lighter(known, new)
    return filled


def pad_size(key: str, size: tuple[int, int]) -> int:
    if PurePosixPath(key).name in TILED:
        return max(PAD, min(PAD_TILED_MAX, *size))
    return PAD


def pad(image: "Image.Image", n: int, wrap: bool) -> "Image.Image":
    """[param image] with [param n] pixels of border on every side: its
    own neighbouring copies when [param wrap] (n is at most its size),
    its edge pixels stretched outwards otherwise."""
    w, h = image.size
    out = Image.new(image.mode, (w + 2 * n, h + 2 * n))
    if wrap:
        for ty in (-1, 0, 1):
            for tx in (-1, 0, 1):
                out.paste(image, (n + tx * w, n + ty * h))
        return out
    out.paste(image, (n, n))
    out.paste(image.crop((0, 0, w, 1)).resize((w, n), Image.NEAREST), (n, 0))
    out.paste(image.crop((0, h - 1, w, h)).resize((w, n), Image.NEAREST), (n, n + h))
    out.paste(image.crop((0, 0, 1, h)).resize((n, h), Image.NEAREST), (0, n))
    out.paste(image.crop((w - 1, 0, w, h)).resize((n, h), Image.NEAREST), (n + w, n))
    for (sx, sy), (tx, ty) in (((0, 0), (0, 0)), ((w - 1, 0), (n + w, 0)),
                               ((0, h - 1), (0, n + h)), ((w - 1, h - 1), (n + w, n + h))):
        out.paste(image.getpixel((sx, sy)), (tx, ty, tx + n, ty + n))
    return out


def colour_fix(model: "Image.Image", original: "Image.Image", radius: float) -> "Image.Image":
    """model + blur(original) - blur(model), per channel, in 8 bits. Both
    are RGB of one size; the difference rides on an offset of 128, so
    anything within 127 of the model's own colour is exact."""
    blur = ImageFilter.GaussianBlur(radius)
    shift = ImageChops.subtract(original.filter(blur), model.filter(blur), 1.0, 128)
    return ImageChops.add(model, shift, 1.0, -128)


def alpha_up(alpha: "Image.Image") -> "Image.Image":
    """A 1997 on/off transparency at twice the size, still on/off."""
    w, h = alpha.size
    big = alpha.resize((w * SCALE, h * SCALE), Image.LANCZOS)
    return big.point(lambda v: 255 if v >= 128 else 0)


def prepare(skin: Path, keys: list[str], src: Path) -> dict:
    """Write each picture's opaque, padded colour to [param src] as the
    engine's input, and return what the finish needs to know of each."""
    src.mkdir(parents=True, exist_ok=True)
    meta = {}
    for key in keys:
        picture = Image.open(skin / (key + ".png"))
        picture.load()
        rgba = picture.convert("RGBA")
        n = pad_size(key, rgba.size)
        padded = pad(bleed(rgba), n, PurePosixPath(key).name in TILED)
        padded.save(src / flat(key))
        alpha = rgba.getchannel("A")
        cut = alpha.getextrema()[0] < 255
        hidden_black = cut and Image.composite(
            Image.new("RGB", rgba.size), rgba.convert("RGB"), alpha).getbbox() is None
        meta[key] = dict(mode=picture.mode, size=rgba.size, pad=n,
                         alpha=alpha if cut else None, hidden_black=hidden_black)
    return meta


def finish(key: str, info: dict, src: Path, raw: Path) -> "Image.Image":
    """The engine's result for [param key], brought to 2x, its colours
    taken back from 1997, its padding cut off and its transparency set."""
    w, h = info["size"]
    n = info["pad"]
    size = ((w + 2 * n) * SCALE, (h + 2 * n) * SCALE)
    model = Image.open(raw / flat(key)).convert("RGB")
    if model.size != size:
        model = model.resize(size, Image.LANCZOS)
    original = Image.open(src / flat(key)).convert("RGB").resize(size, Image.BICUBIC)
    fixed = colour_fix(model, original, COLOUR_BLUR * SCALE)
    box = (n * SCALE, n * SCALE, (n + w) * SCALE, (n + h) * SCALE)
    rgb = fixed.crop(box)
    if info["alpha"] is None:
        return rgb if info["mode"] == "RGB" else rgb.convert("RGBA")
    alpha = alpha_up(info["alpha"])
    if info["hidden_black"]:
        rgb = Image.composite(rgb, Image.new("RGB", rgb.size), alpha)
    rgb.putalpha(alpha)
    return rgb


def flat(key: str) -> str:
    """One file name per key in the engine's flat folders."""
    return key.replace("/", "__") + ".png"


def upscaled_name(key: str) -> str:
    """The 0.50.28 name of a 2x copy: `title_background` ->
    `title_background@2x.png` — read by --reuse, never written."""
    return key + SUFFIX + ".png"


def back_to_1x(big: "Image.Image") -> "Image.Image":
    """[param big] brought down to half: each 2x2 block averaged, every
    channel on its own — what the game does to a 2x picture it has no 1x
    file for (game/skin.gd, `shrunk`: Godot's `shrink_x2`, (a+b+c+d+2)>>2
    a channel). Band by band, because Pillow reduces an RGBA picture with
    its alpha premultiplied and a hidden pixel's colour would come back
    black."""
    return Image.merge(big.mode, [band.reduce(SCALE) for band in big.split()])


def difference(copy: "Image.Image", picture: "Image.Image") -> tuple[float, float]:
    """How far [param copy] (2x) is from [param picture] (1x): the mean of
    |difference| per channel over the picture's opaque pixels, both
    softened by REUSE_BLUR, and the share of pixels whose on/off alpha
    differs."""
    back = back_to_1x(copy.convert("RGBA"))
    small = picture.convert("RGBA")
    opaque = small.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    blur = ImageFilter.GaussianBlur(REUSE_BLUR)
    stat = ImageStat.Stat(ImageChops.difference(back.convert("RGB").filter(blur),
                                                small.convert("RGB").filter(blur)), opaque)
    colour = sum(stat.mean) / 3 if stat.count[0] else 0.0
    on = back.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    flips = ImageStat.Stat(ImageChops.difference(on, opaque)).mean[0] / 255
    return colour, flips


def reusable(source: Path, skin: Path, keys: list[str]) -> tuple[dict[str, Path], dict[str, str]]:
    """The copies in [param source] (a folder holding what skin/ holds)
    that can stand for this run's pictures — `<name>@2x.png`, else a
    picture of the key's own name — and why each other key has none:
    `({key: copy}, {key: why})`. A copy stands when it is exactly twice
    its picture's size and within REUSE_MATCH and REUSE_ALPHA of it."""
    taken: dict[str, Path] = {}
    refused: dict[str, str] = {}
    for key in keys:
        why = "no copy"
        for copy in (source / upscaled_name(key), source / (key + ".png")):
            if not copy.is_file():
                continue
            try:
                with Image.open(copy) as big, Image.open(skin / (key + ".png")) as small:
                    if big.size != (small.width * SCALE, small.height * SCALE):
                        why = "%d x %d, not twice %d x %d" % (big.size + small.size)
                        continue
                    colour, flips = difference(big, small)
            except OSError:
                why = "not a picture"
                continue
            if colour > REUSE_MATCH or flips > REUSE_ALPHA:
                why = "another picture (%.1f from it)" % colour
                continue
            taken[key] = copy
            break
        if key not in taken:
            refused[key] = why
    return taken, refused


def doubled(picture: "Image.Image") -> "Image.Image":
    """[param picture] at twice the size, each pixel a 2x2 block of itself
    (DOUBLED); its mode and transparency kept."""
    big = picture.resize((picture.width * SCALE, picture.height * SCALE), Image.NEAREST)
    if "transparency" in picture.info:
        big.info["transparency"] = picture.info["transparency"]
    return big


def exactness(key: str) -> str | None:
    """"whole", "ring" or None — how much of [param key]'s 2x picture is
    made key-exact (KEY_EXACT)."""
    if "/" in key:
        return None   # a portrait: drawn, never keyed
    for place, how in KEY_EXACT:
        if key == place or (place.endswith("_") and key.startswith(place)):
            return how
    return None


def _spread(block: list[list[int]], channel: int, total: int) -> None:
    """Make [param block]'s four values of [param channel] sum to
    [param total] (0..1020): the difference shared out evenly, kept
    within 0..255, the rest moved a level at a time where there is room."""
    step, extra = divmod(total - sum(px[channel] for px in block), 4)
    for i, px in enumerate(block):
        px[channel] = min(255, max(0, px[channel] + step + (1 if i < extra else 0)))
    left = total - sum(px[channel] for px in block)
    while left:
        for px in block:
            if left > 0 and px[channel] < 255:
                px[channel] += 1
                left -= 1
            elif left < 0 and px[channel] > 0:
                px[channel] -= 1
                left += 1


def key_exact(big: "Image.Image", picture: "Image.Image", ring: bool) -> "Image.Image":
    """[param big] with every 2x2 block over a 1997 pixel of [param
    picture] — all of them, or with [param ring] the outer ones alone —
    averaging EXACTLY to that pixel: its RGB sums are four times the 1997
    value, its alpha the 1997 alpha. Brought back to 1x, the block is the
    1997 pixel again, to the level."""
    out = big.copy()
    pixels = out.load()
    small = picture.convert("RGBA").load()
    width, height = picture.size
    alpha = out.mode == "RGBA"
    for y in range(height):
        for x in range(width):
            if ring and 0 < x < width - 1 and 0 < y < height - 1:
                continue
            want = small[x, y]
            cells = ((2 * x, 2 * y), (2 * x + 1, 2 * y), (2 * x, 2 * y + 1), (2 * x + 1, 2 * y + 1))
            block = [list(pixels[cell]) for cell in cells]
            for channel in range(3):
                _spread(block, channel, 4 * want[channel])
            for cell, px in zip(cells, block):
                if alpha:
                    px[3] = want[3]
                pixels[cell] = tuple(px)
    return out


# ---------------------------------------------------------------- the engine

def cache_dir() -> Path:
    base = os.environ.get("XDG_CACHE_HOME") or str(Path.home() / ".cache")
    return Path(base) / "shandalar" / ("%s-%s" % (ENGINE_EXE, ENGINE_BUILD))


def fetch_engine(folder: Path, url: str = ENGINE_URL, sha256: str = ENGINE_SHA256) -> Path:
    """The engine in [param folder], fetched and checked first if it is
    not there yet. Only ENGINE_MEMBERS are kept; a download whose
    checksum differs is thrown away and nothing is unpacked."""
    exe = folder / ENGINE_EXE
    if exe.is_file() and all((folder / m).is_file() for m in ENGINE_MEMBERS):
        return exe
    folder.mkdir(parents=True, exist_ok=True)
    part = folder / "download.part"
    print("fetching the engine (once): %s" % url)
    digest = hashlib.sha256()
    with urllib.request.urlopen(url, timeout=60) as response, open(part, "wb") as out:
        while chunk := response.read(1 << 20):
            digest.update(chunk)
            out.write(chunk)
    if digest.hexdigest() != sha256:
        part.unlink()
        raise RuntimeError("the engine download does not match its checksum "
                           "(%s); nothing was unpacked" % url)
    with zipfile.ZipFile(part) as archive:
        for member in ENGINE_MEMBERS:
            target = folder / member
            target.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(member) as src, open(target, "wb") as dst:
                shutil.copyfileobj(src, dst)
    part.unlink()
    exe.chmod(0o755)
    return exe


def find_engine(given: Path | None) -> Path:
    """`--engine` (the program, or the folder it is in), else the cached
    Linux release, fetched on first use."""
    if given is not None:
        exe = given / ENGINE_EXE if given.is_dir() else given
        if not exe.is_file():
            raise RuntimeError("no engine at %s" % exe)
        return exe
    if not sys.platform.startswith("linux"):
        raise RuntimeError("the engine is fetched for Linux only; get "
                           "realesrgan-ncnn-vulkan for this system from "
                           "https://github.com/xinntao/Real-ESRGAN/releases "
                           "and name it with --engine")
    return fetch_engine(cache_dir())


def run_engine(exe: Path, src: Path, dst: Path, gpu: str | None) -> None:
    """One run over the whole folder: the GPU starts once."""
    dst.mkdir(parents=True, exist_ok=True)
    command = [str(exe), "-i", str(src), "-o", str(dst), "-n", MODEL,
               "-s", str(MODEL_SCALE), "-f", "png", "-m", str(exe.parent / "models")]
    if gpu is not None:
        command += ["-g", gpu]
    done = subprocess.run(command, cwd=exe.parent, capture_output=True, text=True)
    missing = [p.name for p in src.glob("*.png") if not (dst / p.name).is_file()]
    if done.returncode != 0 or missing:
        tail = "\n".join(done.stderr.strip().splitlines()[-8:])
        raise RuntimeError("the engine failed (exit %d, %d pictures missing). It needs "
                           "a Vulkan GPU driver; --gpu picks another GPU.\n%s"
                           % (done.returncode, len(missing), tail))


# ---------------------------------------------------------------- the output

def provenance(count: int, reused: int = 0, source: str = "", exact: int = 0,
               plain: int = 0) -> str:
    """How the hi-res skin was made — the zip's comment, never a file of
    it, so it holds the same files as the skin it was made from."""
    again = ("\n  reused   %d of them taken as they were from %s\n" % (reused, source)
             if reused else "\n")
    if plain:
        again += ("  doubled  %d pixel for pixel, the 1997 grain kept (%s)\n"
                  % (plain, ", ".join(DOUBLED)))
    return (
        "A 1997 skin with its pictures at twice the size, made by upscale_skin.py\n"
        "(Shandalar %s).\n\n"
        "  files    the same files as the 1997 skin, under the same names; %d\n"
        "           pictures at twice the size, %d of them key-exact%s"
        "  engine   Real-ESRGAN ncnn-vulkan %s (MIT), model %s\n"
        "           (BSD-3, Xintao Wang et al.), run at %dx and brought down to %dx\n"
        "  colours  taken back from the 1997 picture:\n"
        "           out = model + blur(1997) - blur(model), blur %g px at 1997 size\n"
        % (tool_banner.version_text(ROOT), count, exact, again,
           ENGINE_BUILD, MODEL, MODEL_SCALE, SCALE, COLOUR_BLUR))


def write_zip(files: dict[str, Path], out: Path, comment: str = "") -> None:
    """`skin/<name>` for each, sorted and dated 1980-01-01, so one skin
    and one engine always make the same bytes; [param comment] is the
    zip's comment."""
    out.parent.mkdir(parents=True, exist_ok=True)
    part = out.with_name(out.name + ".part")
    with zipfile.ZipFile(part, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        archive.comment = comment.encode("utf-8")
        for name in sorted(files):
            info = zipfile.ZipInfo("skin/" + name, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, files[name].read_bytes())
    part.replace(out)


def upscale(skin: Path, zip_out: Path | None, folder_out: Path | None,
            engine: Path | None, gpu: str | None, reuse: Path | None = None) -> int:
    with opened(skin) as folder, \
            (opened(reuse) if reuse is not None else nullcontext()) as earlier:
        if folder_out is not None and folder_out.resolve() == folder.resolve():
            print("!! --out is the skin itself: that would write over its 1997 "
                  "pictures; name another folder", file=sys.stderr)
            return 2
        keys = pictures(folder)
        if not keys:
            print("!! no pictures to upscale in %s" % skin, file=sys.stderr)
            return 1
        if (folder / import_manalink.LABEL).exists():
            print("note: this skin holds files from a Manalink install; the hi-res skin "
                  "keeps the label (%s) and a release refuses it" % import_manalink.LABEL)
        plain = [key for key in keys if key in DOUBLED]
        modelled = [key for key in keys if key not in DOUBLED]
        taken, refused = reusable(earlier, folder, modelled) if earlier is not None else ({}, {})
        fresh = [key for key in modelled if key not in taken]
        if reuse is not None:
            print("%d of %d pictures reused from %s" % (len(taken), len(keys), reuse))
            for key in sorted(refused):
                print("  upscaled again: %s.png — %s" % (key, refused[key]))
        near = (zip_out or folder_out).resolve().parent
        near.mkdir(parents=True, exist_ok=True)
        # The work folder sits beside the output, on its disk: the engine's
        # 4x pictures are several hundred MB, more than a small /tmp holds.
        with tempfile.TemporaryDirectory(prefix=".upscale-skin-", dir=near) as tmp:
            work = Path(tmp)
            done = work / "done"
            done.mkdir()
            big: dict[str, Path] = dict(taken)
            for key in plain:
                with Image.open(folder / (key + ".png")) as picture:
                    picture.load()
                    target = done / (key + ".png")
                    target.parent.mkdir(parents=True, exist_ok=True)
                    doubled(picture).save(target)
                big[key] = target
            if fresh:
                # Only now: a run that reuses every picture never needs it.
                exe = find_engine(engine)
                print("%d pictures from %s" % (len(fresh), skin))
                meta = prepare(folder, fresh, work / "in")
                run_engine(exe, work / "in", work / "raw", gpu)
                for key in fresh:
                    target = done / (key + ".png")
                    target.parent.mkdir(parents=True, exist_ok=True)
                    finish(key, meta[key], work / "in", work / "raw").save(target)
                    big[key] = target
            exact = 0
            for key in keys:
                how = exactness(key)
                if how is None:
                    continue
                with Image.open(big[key]) as picture, Image.open(folder / (key + ".png")) as small:
                    picture.load()
                    mode = "RGBA" if "A" in small.mode or "transparency" in small.info else "RGB"
                    made = key_exact(picture.convert(mode), small, how == "ring")
                target = done / (key + ".png")
                target.parent.mkdir(parents=True, exist_ok=True)
                made.save(target)
                big[key] = target
                exact += 1
            # The skin as it was, every picture replaced by its 2x one.
            files = {name: folder / name for name in skin_files(folder)}
            for key, path in big.items():
                files[key + ".png"] = path
            note = provenance(len(keys), len(taken), reuse.name if reuse is not None else "",
                              exact, len(plain))
            if folder_out is not None:
                for name, path in sorted(files.items()):
                    target = folder_out / name
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(path, target)
                print("wrote the hi-res skin into %s (%d files, %d pictures at 2x)"
                      % (folder_out, len(files), len(keys)))
            if zip_out is not None:
                write_zip(files, zip_out, note)
                print("wrote %s (%d files, %d pictures at 2x, %.0f MB)"
                      % (zip_out, len(files), len(keys), zip_out.stat().st_size / 1e6))
            print(note.rstrip())
            print("It is a skin like the 1997 one: choose it in Options > Skin, or drop")
            print("it on the window, and it is worn from the next start; choose the")
            print("1997 skin again to go back. To wear a 1997 picture in one place, put")
            print("the 1997 file back into it under its own name.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        prog=TOOL, description=__doc__.split("\n\n")[0], epilog=EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--skin", type=Path, default=None,
                        help="the 1997 skin: a folder or a skin zip "
                             "(default: this checkout's assets/original)")
    parser.add_argument("--zip", type=Path, default=None,
                        help="write the hi-res skin zip here (default: %s in "
                             "this folder, unless --out is given)" % ZIP_NAME)
    parser.add_argument("--out", type=Path, default=None,
                        help="write the hi-res skin into this folder instead "
                             "(never the skin read)")
    parser.add_argument("--reuse", type=Path, default=None, metavar="ZIP_OR_DIR",
                        help="take each picture's 2x copy (<name>@2x.png, or its "
                             "own name at twice the size) from this zip or "
                             "folder instead of upscaling it again, when it is "
                             "a copy of the same picture; the rest are upscaled")
    parser.add_argument("--engine", type=Path, default=None,
                        help="your own realesrgan-ncnn-vulkan (the program or "
                             "its folder) instead of the fetched one")
    parser.add_argument("--gpu", default=None,
                        help="the Vulkan GPU to use, as the engine numbers them")
    tool_banner.add_version_flag(parser, TOOL, __file__)
    args = parser.parse_args()
    tool_banner.show(WORDMARK, CAPTION, __file__, hint=HINT)
    if Image is None:
        print("!! this tool needs Pillow: `sudo apt install python3-pil` "
              "or `pip install pillow`", file=sys.stderr)
        return 2
    skin = args.skin if args.skin is not None else DEFAULT_SKIN
    if not skin.exists():
        print("!! no skin at %s; name one with --skin (a folder or a skin zip)"
              % skin, file=sys.stderr)
        return 2
    zip_out = args.zip
    if zip_out is None and args.out is None:
        zip_out = Path.cwd() / ZIP_NAME
    try:
        reuse = args.reuse.expanduser().resolve() if args.reuse is not None else None
        if reuse is not None and not reuse.exists():
            print("!! nothing to reuse at %s" % args.reuse, file=sys.stderr)
            return 2
        return upscale(skin.expanduser().resolve(), zip_out, args.out, args.engine,
                       args.gpu, reuse)
    except (RuntimeError, OSError, zipfile.BadZipFile) as error:
        print("!! %s" % error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Make a 2x skin out of a 1997 one: every picture again at twice the size.

    python3 upscale_skin.py                              # assets/original -> the 2x skin zip
    python3 upscale_skin.py --skin original_skin.zip     # a skin zip works too
    python3 upscale_skin.py --skin DIR --out DIR         # the 2x skin into a folder
    python3 upscale_skin.py --skin original_skin.zip --reuse original_skin_realesrgan-anime_2x.zip

The game is laid out for 1280x800 and drawn at the screen's real
resolution, so on a 4K screen the 1997 pictures are stretched about 2.7x
and look soft. This writes a COMPLETE SKIN — the zip
`original_skin_realesrgan-anime_2x.zip`, or a folder: every file of the
1997 skin as it was (sounds, fonts, movie sheets, portraits) and beside
each picture `<name>@2x.png`, the same picture again at twice the size,
with a `catalogue.txt` that tells the game to wear the 2x one in each
place. A skin is a skin (the owner, 2026-10-17: *"A skin is a skin and
gets applied after game reset. No switches."*): choose the zip in
Options > Skin or drop it on the window and it is worn from the next
start, or put it beside the game as `skin/original_skin.zip` in place of
the 1997 one.

MIX AND MATCH (the owner, the same day: *"users should be able to mix and
match some upscaled and some downscaled images as they wished"*). The 1997
pictures stay in the skin under their own names, so wearing one of them
instead is one line of `catalogue.txt`: point it at the 1997 file
(`duelist_face_red.png = duelist_face_red.png`). Deleting the line is not
the same — with no line the game still wears `<name>@2x.png` where it
sits beside the picture (SKIN.txt, THE CATALOGUE). A line may also name
any picture you add. The catalogue's rules, and the sizes the game wears
(1x to 4x a place's 1997 size), are SKIN.txt's (`docs/skin-catalogue.txt`,
THE CATALOGUE and SIZES AND SCALES). The 1997 file under the place's own
name is also what the game decides its exact colour keys on (a black or a
white key, an image+mask sprite, a territory's edge), so a 2x picture
keys the way its 1997 picture did — the reason the 2x skin keeps them.

REUSE (the owner, 2026-10-17: *"I already have built 2x skin so we will
reuse it"*). `--reuse` takes each picture's `<name>@2x.png` from a 2x
zip or folder already made — the 0.50.28 tool's zip of copies alone, or
a skin this one wrote — instead of running the engine again. A copy is
taken only when it is exactly twice its 1997 picture's size; a picture
with none is upscaled as usual, and a run that finds every copy never
fetches or starts the engine. That turns the 0.50.28 zip into a whole
skin in seconds:

    python3 upscale_skin.py --skin original_skin.zip --reuse original_skin_realesrgan-anime_2x.zip

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
prefers the 1997 look there wears it with one catalogue line per place
(MIX AND MATCH, above). The way out for the tool, if it is ever wanted:
give those fifteen keys another method — exact pixel doubling (the 1997
look, crisp, no second engine; the one recommended) or waifu2x CUNet
(dots kept, 18.7%; stripes 0.34) — rather than a finer blur, which would
bring the dither dots back on every picture.

LEFT ALONE, copied as they are: the coin-toss movie sheets (2240x2160
already; twice that is past the 4096-pixel texture limit of older GPUs;
their catalogue lines name themselves), the sounds, the fonts, the sheet
layouts and the movies. NOT COPIED: card pictures (`cardart/`, a zip of
their own), Godot's `.import` files, and what this tool writes —
`catalogue.txt`, `UPSCALE.txt` and the `<name>@2x.png` copies a skin
already holds are made afresh (or taken through --reuse), never carried
over from the skin read.

A skin the Manalink door filled (`import_original.py --manalink`) keeps
its label in the 2x skin (`from_manalink.txt`), and a release refuses it
the same way it refuses the skin it came from (tools/import_manalink.py).
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
    from PIL import Image, ImageChops, ImageFilter
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
CAPTION = ("Shandalar 1997 · the 2x skin", "twice the size, the 1997 colours")

## `tools/` in a checkout, nothing beside a packaged game
## (tool_banner.here_prefix()).
WHERE = tool_banner.here_prefix(__file__)
HINT = (
    "python3 %supscale_skin.py --skin original_skin.zip   # the 2x skin zip" % WHERE,
    "python3 %supscale_skin.py --skin DIR --out DIR       # into a folder" % WHERE,
    "python3 %supscale_skin.py -h          # --reuse, --zip, --engine" % WHERE,
)

EPILOG = """\
%s
    python3 %supscale_skin.py --skin DIR --zip FILE   name the zip yourself
    python3 %supscale_skin.py --engine /path/to/realesrgan-ncnn-vulkan
    python3 %supscale_skin.py --gpu 1                 pick the Vulkan GPU
    python3 %supscale_skin.py --skin skin.zip --reuse 2x.zip   reuse a 2x zip

Writes a complete skin, original_skin_realesrgan-anime_2x.zip (or with
--out a folder; --out the skin folder itself adds to it in place): every
file of the 1997 skin as it was, <name>@2x.png beside every picture
(Real-ESRGAN's anime model, its colours taken back from the 1997
picture), and catalogue.txt, which wears the 2x pictures — change a line
to wear a 1997 one. --reuse takes the @2x pictures of a 2x zip or folder
already made and upscales only what it lacks. Needs Pillow and a Vulkan
GPU driver; on Linux the engine is fetched once into ~/.cache/shandalar/.

%s
""" % (tool_banner.examples(HINT), WHERE, WHERE, WHERE, WHERE,
       tool_banner.BANNER_HELP)

DEFAULT_SKIN = ROOT / "assets" / "original"

SCALE = 2
## The name of the method, carried by the zip's name and by nothing the
## game reads: a second method would be a second zip beside this one.
METHOD = "realesrgan-anime"
ZIP_NAME = "original_skin_%s_%dx.zip" % (METHOD, SCALE)
## What a 2x picture is called: `title_background.png` ->
## `title_background@2x.png`, `portraits/agnosia.png` ->
## `portraits/agnosia@2x.png` — beside its 1997 picture, which keeps its
## own name (MIX AND MATCH). The names the 0.50.28 tool gave its copies,
## kept (the owner: *"keep the previous skin filenames also valid for skin
## reader"*): the game wears `<name>@2x.png` in its place even with no
## catalogue line (game/skin.gd), and the portrait chooser skips them.
SUFFIX = "@%dx" % SCALE
## THE CATALOGUE (docs/skin-catalogue.txt): which file the game wears in
## each place. Written by this tool, read by the game (game/skin.gd) and
## by `skin_catalogue.py --check`.
CATALOGUE = "catalogue.txt"
PROVENANCE = "UPSCALE.txt"
## What a 2x skin made again is made afresh from: a skin this tool wrote
## already holds these, and they are written new rather than copied.
OWN_FILES = (CATALOGUE, PROVENANCE)
## Never copied into the 2x skin: card pictures travel in a zip of their
## own, and a release refuses a skin that holds them.
NOT_COPIED_DIRS = ("cardart",)

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

def places(skin: Path) -> list[str]:
    """Every picture place of the skin, as a key: the top-level and
    portrait PNGs, minus the `@2x` copies a skin may already hold."""
    found = sorted(skin.glob("*.png")) + sorted(skin.glob("portraits/*.png"))
    return [path.relative_to(skin).as_posix()[:-4] for path in found
            if "@" not in path.name]


def pictures(skin: Path) -> list[str]:
    """The keys to upscale: every place but the movie sheets."""
    return [key for key in places(skin)
            if not PurePosixPath(key).name.startswith(LEFT_ALONE)]


def skin_files(skin: Path) -> list[str]:
    """Every file of the skin that the 2x skin carries as it is, by its
    name under `skin/`: everything but card pictures, Godot's `.import`
    sidecars and what this tool writes (its two files, `@2x` copies)."""
    out = []
    for path in sorted(skin.rglob("*")):
        if not path.is_file():
            continue
        name = path.relative_to(skin).as_posix()
        if (name.split("/")[0] in NOT_COPIED_DIRS or name in OWN_FILES
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
    """`title_background` -> `title_background@2x.png`."""
    return key + SUFFIX + ".png"


def reusable(source: Path, skin: Path, keys: list[str]) -> dict[str, Path]:
    """The `@2x` copies in [param source] (a folder holding what skin/
    holds) that can stand for this run's: exactly twice their 1997
    picture's size. Anything else — no copy, another size, not a picture —
    is left to the engine."""
    out = {}
    for key in keys:
        copy = source / upscaled_name(key)
        if not copy.is_file():
            continue
        try:
            with Image.open(copy) as big, Image.open(skin / (key + ".png")) as small:
                fits = big.size == (small.width * SCALE, small.height * SCALE)
        except OSError:
            fits = False
        if fits:
            out[key] = copy
    return out


def catalogue(keys: list[str], upscaled: list[str]) -> str:
    """The skin's catalogue.txt: a note on how to read and change it, then
    one line per picture place, sorted — the 2x picture where there is
    one, the place's own file where it was left alone."""
    done = set(upscaled)
    lines = [
        "# THE CATALOGUE of this skin: which file the game wears in each place.",
        "# Made by upscale_skin.py; change it as you like.",
        "#",
        "#     <place> = <file>",
        "#",
        "# A place is a name the game looks for (SKIN.txt, beside the game, lists",
        "# them all); the file is any file in this skin, its path from skin/. A",
        "# place with no line, or whose file is not here, is worn from",
        "# <name>@2x.png beside it when there is one, else from the file of its",
        "# own name.",
        "#",
        "# MIX AND MATCH: to wear the 1997 picture in a place instead of the 2x",
        "# one, point its line at it:",
        "#     duelist_face_red.png = duelist_face_red.png",
        "# (Deleting the line is not the same: with no line the game still",
        "# wears <name>@2x.png where one sits beside the picture.) A line may",
        "# name any picture you add. A picture may be 1x, 2x, 3x or 4x its",
        "# place's 1997 size (SKIN.txt, SIZES AND SCALES); the game draws it at",
        "# the 1997 size with all its pixels.",
        "",
    ]
    for key in sorted(keys):
        place = key + ".png"
        lines.append("%s = %s" % (place, upscaled_name(key) if key in done else place))
    return "\n".join(lines) + "\n"


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

def provenance(count: int, reused: int = 0, source: str = "") -> str:
    again = ("\n  reused   %d of them taken as they were from\n"
             "           %s, made before by this tool\n"
             % (reused, source)) if reused else "\n"
    return (
        "A 1997 skin at twice the size, made by upscale_skin.py (Shandalar %s).\n\n"
        "  files    every file of the 1997 skin, as it was, and <name>%s.png beside\n"
        "           each picture: %d pictures again at twice the size. %s\n"
        "           says which of the two the game wears in each place; change\n"
        "           a line to wear the 1997 one%s"
        "  engine   Real-ESRGAN ncnn-vulkan %s (MIT), model %s\n"
        "           (BSD-3, Xintao Wang et al.), run at %dx and brought down to %dx\n"
        "  colours  taken back from the 1997 picture:\n"
        "           out = model + blur(1997) - blur(model), blur %g px at 1997 size\n"
        % (tool_banner.version_text(ROOT), SUFFIX, count, CATALOGUE, again,
           ENGINE_BUILD, MODEL, MODEL_SCALE, SCALE, COLOUR_BLUR))


def write_zip(files: dict[str, Path], out: Path) -> None:
    """`skin/<name>` for each, sorted and dated 1980-01-01, so one skin
    and one engine always make the same bytes."""
    out.parent.mkdir(parents=True, exist_ok=True)
    part = out.with_name(out.name + ".part")
    with zipfile.ZipFile(part, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
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
        keys = pictures(folder)
        if not keys:
            print("!! no pictures to upscale in %s" % skin, file=sys.stderr)
            return 1
        if (folder / import_manalink.LABEL).exists():
            print("note: this skin holds files from a Manalink install; the 2x skin "
                  "keeps the label (%s) and a release refuses it" % import_manalink.LABEL)
        taken = reusable(earlier, folder, keys) if earlier is not None else {}
        fresh = [key for key in keys if key not in taken]
        if reuse is not None:
            print("%d of %d pictures reused from %s" % (len(taken), len(keys), reuse))
        near = (zip_out or folder_out).resolve().parent
        near.mkdir(parents=True, exist_ok=True)
        # The work folder sits beside the output, on its disk: the engine's
        # 4x pictures are several hundred MB, more than a small /tmp holds.
        with tempfile.TemporaryDirectory(prefix=".upscale-skin-", dir=near) as tmp:
            work = Path(tmp)
            done = work / "done"
            done.mkdir()
            # What this run makes: the 2x pictures, the catalogue, the note.
            made: dict[str, Path] = {upscaled_name(key): path for key, path in taken.items()}
            if fresh:
                # Only now: a run that reuses every picture never needs it.
                exe = find_engine(engine)
                print("%d pictures from %s" % (len(fresh), skin))
                meta = prepare(folder, fresh, work / "in")
                run_engine(exe, work / "in", work / "raw", gpu)
                for key in fresh:
                    target = done / upscaled_name(key)
                    target.parent.mkdir(parents=True, exist_ok=True)
                    finish(key, meta[key], work / "in", work / "raw").save(target)
                    made[upscaled_name(key)] = target
            (done / CATALOGUE).write_text(catalogue(places(folder), keys), encoding="utf-8")
            made[CATALOGUE] = done / CATALOGUE
            (done / PROVENANCE).write_text(
                provenance(len(keys), len(taken), reuse.name if reuse is not None else ""),
                encoding="utf-8")
            made[PROVENANCE] = done / PROVENANCE
            # And the 1997 skin around them, as it was.
            files = {name: folder / name for name in skin_files(folder)}
            files.update(made)
            if folder_out is not None:
                in_place = folder_out.resolve() == folder.resolve()
                for name, path in sorted((made if in_place else files).items()):
                    target = folder_out / name
                    if target.resolve() == path.resolve():
                        continue   # a copy reused from where it already is
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(path, target)
                print("wrote %d pictures at 2x %s %s" % (
                    len(keys), "into the skin folder" if in_place else "and the skin into",
                    folder_out))
                print("A skin folder dresses the game when no skin zip is worn, or with")
                print("\"Use the skin folder instead of the zip\" in Options > Skin.")
            if zip_out is not None:
                write_zip(files, zip_out)
                print("wrote %s (%d pictures at 2x, %d files, %.0f MB)"
                      % (zip_out, len(keys), len(files), zip_out.stat().st_size / 1e6))
                print("Choose it in Options > Skin, or drop it on the window: it is worn")
                print("from the next start. Or put it beside the game as")
                print("skin/original_skin.zip, in place of the 1997 one.")
            print("To wear a 1997 picture in a place instead, point its line in %s"
                  % CATALOGUE)
            print("at the 1997 file (duelist_face_red.png = duelist_face_red.png).")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        prog=TOOL, description=__doc__.split("\n\n")[0], epilog=EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--skin", type=Path, default=None,
                        help="the 1997 skin: a folder or a skin zip "
                             "(default: this checkout's assets/original)")
    parser.add_argument("--zip", type=Path, default=None,
                        help="write the 2x skin zip here (default: %s in this "
                             "folder, unless --out is given)" % ZIP_NAME)
    parser.add_argument("--out", type=Path, default=None,
                        help="write the 2x skin into this folder instead (the "
                             "skin folder itself: add to it in place)")
    parser.add_argument("--reuse", type=Path, default=None, metavar="ZIP_OR_DIR",
                        help="take each picture's @2x copy from this 2x zip or "
                             "folder (exactly twice its size) instead of "
                             "upscaling it again; the rest are upscaled")
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

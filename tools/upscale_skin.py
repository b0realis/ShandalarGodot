#!/usr/bin/env python3
"""Make twice-the-size copies of a 1997 skin's pictures, for big screens.

    python3 upscale_skin.py                              # assets/original -> the 2x zip
    python3 upscale_skin.py --skin original_skin.zip     # a skin zip works too
    python3 upscale_skin.py --skin DIR --out DIR         # @2x files beside the 1x

The game is laid out for 1280x800 and drawn at the screen's real
resolution, so on a 4K screen the 1997 pictures are stretched about 2.7x
and look soft. This writes a copy of each picture at twice the size, as
`<key>@2x.png`, into one zip (`original_skin_realesrgan-anime_2x.zip`) or
a folder. The 1997 skin is not changed and still needed: the sounds, the
fonts and the coin-toss movie sheets are only in it, and so is every
picture's 1997 original. The game wears each copy at its picture's size
(game/skin.gd, THE 2x PICTURES): the zip beside the game as
`skin/original_skin_realesrgan-anime_2x.zip`, chosen in Options > Skin or
dropped on the window, or the copies loose beside the pictures (--out).

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

LEFT ALONE: the coin-toss movie sheets (2240x2160 already; twice that is
past the 4096-pixel texture limit of older GPUs), the sounds, the fonts,
the card pictures, and any `@2x` file already there.

A skin the Manalink door filled (`import_original.py --manalink`) keeps
its label in the copy (`from_manalink.txt`), and a release refuses it the
same way it refuses the skin it came from (tools/import_manalink.py).
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
from contextlib import contextmanager
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
    "python3 %supscale_skin.py --skin original_skin.zip   # the 2x zip" % WHERE,
    "python3 %supscale_skin.py --skin DIR --out DIR       # @2x files beside" % WHERE,
    "python3 %supscale_skin.py -h            # --zip, --engine, --gpu" % WHERE,
)

EPILOG = """\
%s
    python3 %supscale_skin.py --skin DIR --zip FILE   name the zip yourself
    python3 %supscale_skin.py --engine /path/to/realesrgan-ncnn-vulkan
    python3 %supscale_skin.py --gpu 1                 pick the Vulkan GPU

Writes <key>@2x.png for every picture of the skin (Real-ESRGAN's anime
model, its colours taken back from the 1997 picture) into
original_skin_realesrgan-anime_2x.zip, or with --out into a folder. The
1997 skin stays as it is and is still needed. Needs Pillow and a Vulkan
GPU driver; on Linux the engine is fetched once into ~/.cache/shandalar/.

%s
""" % (tool_banner.examples(HINT), WHERE, WHERE, WHERE,
       tool_banner.BANNER_HELP)

DEFAULT_SKIN = ROOT / "assets" / "original"

SCALE = 2
## The name of the method, carried by the zip's name and by nothing the
## game reads: a second method would be a second zip beside this one.
METHOD = "realesrgan-anime"
ZIP_NAME = "original_skin_%s_%dx.zip" % (METHOD, SCALE)
## `title_background.png` -> `title_background@2x.png`: the 1x and the 2x
## copy can share a folder, and a game that does not look for `@2x` never
## sees them.
SUFFIX = "@%dx" % SCALE
PROVENANCE = "UPSCALE.txt"

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
    movie sheets and anything already an upscaled copy."""
    found = sorted(skin.glob("*.png")) + sorted(skin.glob("portraits/*.png"))
    return [path.relative_to(skin).as_posix()[:-4] for path in found
            if not path.name.startswith(LEFT_ALONE) and "@" not in path.name]


@contextmanager
def opened(skin: Path):
    """A skin folder as it is, or a skin zip unpacked (its pictures and its
    label only) into a temporary folder for the run."""
    if skin.is_dir():
        yield skin
        return
    with tempfile.TemporaryDirectory(prefix="shandalar-skin-") as tmp, \
            zipfile.ZipFile(skin) as archive:
        folder = Path(tmp)
        for entry in archive.infolist():
            parts = PurePosixPath(entry.filename).parts
            if (len(parts) < 2 or parts[0] != "skin" or ".." in parts
                    or entry.is_dir()):
                continue
            inner = PurePosixPath(*parts[1:])
            if inner.suffix.lower() != ".png" and inner.name != import_manalink.LABEL:
                continue
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
    return key + SUFFIX + ".png"


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

def provenance(count: int) -> str:
    return (
        "Twice-the-size copies of a 1997 skin's pictures, made by upscale_skin.py\n"
        "(Shandalar %s).\n\n"
        "  files    <key>%s.png, %d of them, to sit beside <key>.png; the 1997\n"
        "           pictures, the sounds, the fonts and the coin-toss movie\n"
        "           sheets are not in here, and are still needed\n"
        "  engine   Real-ESRGAN ncnn-vulkan %s (MIT), model %s\n"
        "           (BSD-3, Xintao Wang et al.), run at %dx and brought down to %dx\n"
        "  colours  taken back from the 1997 picture:\n"
        "           out = model + blur(1997) - blur(model), blur %g px at 1997 size\n"
        % (tool_banner.version_text(ROOT), SUFFIX, count, ENGINE_BUILD, MODEL,
           MODEL_SCALE, SCALE, COLOUR_BLUR))


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
            engine: Path | None, gpu: str | None) -> int:
    with opened(skin) as folder:
        keys = pictures(folder)
        if not keys:
            print("!! no pictures to upscale in %s" % skin, file=sys.stderr)
            return 1
        label = folder / import_manalink.LABEL
        if label.exists():
            print("note: this skin holds files from a Manalink install; the copy "
                  "keeps the label (%s) and a release refuses it" % import_manalink.LABEL)
        exe = find_engine(engine)
        near = (zip_out or folder_out).resolve().parent
        near.mkdir(parents=True, exist_ok=True)
        # The work folder sits beside the output, on its disk: the engine's
        # 4x pictures are several hundred MB, more than a small /tmp holds.
        with tempfile.TemporaryDirectory(prefix=".upscale-skin-", dir=near) as tmp:
            work = Path(tmp)
            print("%d pictures from %s" % (len(keys), skin))
            meta = prepare(folder, keys, work / "in")
            run_engine(exe, work / "in", work / "raw", gpu)
            done = work / "done"
            files: dict[str, Path] = {}
            for key in keys:
                target = done / upscaled_name(key)
                target.parent.mkdir(parents=True, exist_ok=True)
                finish(key, meta[key], work / "in", work / "raw").save(target)
                files[upscaled_name(key)] = target
            (done / PROVENANCE).write_text(provenance(len(keys)), encoding="utf-8")
            files[PROVENANCE] = done / PROVENANCE
            if label.exists():
                files[import_manalink.LABEL] = label
            if folder_out is not None:
                for name, path in files.items():
                    target = folder_out / name
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(path, target)
                print("wrote %d pictures into %s" % (len(keys), folder_out))
            if zip_out is not None:
                write_zip(files, zip_out)
                print("wrote %s (%d pictures, %.0f MB)"
                      % (zip_out, len(keys), zip_out.stat().st_size / 1e6))
                print("Put it beside the game as skin/%s, choose it in Options > Skin,"
                      % ZIP_NAME)
                print("or drop it on the window: the game wears it beside your 1997 skin.")
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
                        help="write the @2x pictures into this folder instead")
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
        return upscale(skin.expanduser().resolve(), zip_out, args.out, args.engine, args.gpu)
    except (RuntimeError, OSError, zipfile.BadZipFile) as error:
        print("!! %s" % error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())

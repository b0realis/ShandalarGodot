#!/usr/bin/env python3
"""Build the ART ARCHIVE the game wears, from your own copy of the 1997 game.

This is the script a PLAYER runs. It has three jobs, in this order:

  1. Tell you what kind of install it needs, and what it will look for.
  2. Check an install you point it at, and say what it found.
  3. Import it and write ONE zip that the game unpacks beside itself.

    python3 mtg_assets.py                         # explain what is needed
    python3 mtg_assets.py --check  /path/to/game  # look, report, write nothing
    python3 mtg_assets.py --install /path/to/game # import and build the zip

Card art is NOT in here. That is a separate script and a separate
question, because the two kinds of art come from different places and one
of them is a download:

    python3 fetch_card_art.py --out cardart/      # 897 cards from Scryfall

WHY THE ZIP HAS A `skin/` FOLDER INSIDE IT. The game looks for its art in
three places, in order (`game/skin.gd`): the player's own
`user://original_skin/`, then a `skin/` folder BESIDE the executable, then
a development checkout's `assets/original/`. The middle one is the
portable route — it makes a build you can copy to another machine on a
stick — so the archive is built to unzip straight next to the binary with
no path to type. See `setup.txt` in a packaged build for all of them.

NOTHING HERE IS FATAL. Every asset is optional and the game is playable
with none of them: unskinned, every panel, button and card falls back to a
drawn equivalent that keeps the same geometry, which is why a missing file
is reported and skipped rather than raised. An archive built from a
partial install is a perfectly good archive.

Standard library only. Pillow is needed by exactly one FALLBACK path in
the importer (cutting a community-converted portrait sheet) and it says so
rather than failing.
"""

import argparse
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
IMPORTER = HERE / "import_original.py"

# What an install looks like from the outside. These are the names the
# importer hunts for; finding SOME of them is enough, and the check
# reports on each group rather than passing or failing as a whole.
LANDMARKS = {
    "the shell and dialog art": ["shellart", "winbk_options.pic",
                                 "winbk_shellscreen16.bmp"],
    "the card frames and mana symbols": ["cardart", "manasymbols.pic"],
    "the portraits": ["16faces.spr", "faces", "face.pic"],
    "the fonts": ["magim___.ttf", "magis___.ttf", "magicmedieval.ttf"],
    "the sounds": ["duelsounds", "sound"],
    "the card database": ["master.csv", "info.csv"],
    "the coin-toss movies": ["cointoss_heads.avi", "cointoss_tails.avi"],
}

## The one group that is a CONVERSION rather than a copy. The two coin-toss
## movies are AVIs (CRAM, not the Indeo they were long assumed to be), which
## nothing in Python or Godot reads, so the importer transcodes them into
## sprite sheets with whichever of these is installed. Neither being present
## is not an error: the toss falls back to a drawn coin.
DECODERS = ["ffmpeg", "gst-launch-1.0"]

## Editor metadata Godot writes next to an imported file. Useful in a
## checkout, meaningless in a shipped skin, and it was going into the
## archive until 2026-09-04 — `build_release.sh` had always stripped it and
## this path had not.
ZIP_SKIP = (".import", ".DS_Store", "Thumbs.db")

## WHERE THE SOURCE MOVIES RIDE. The coin toss reaches the game as two
## sprite sheets, because neither Python nor Godot can decode the AVIs —
## but the sheets are a CONVERSION, and a conversion without its source is
## a dead end: a player who installs the archive on a machine with no
## decoder, then gets one, has nothing left to convert FROM. So the two
## originals travel beside their own output, in a folder the game never
## looks in (`Skin._find` resolves flat names and `cardart/`, never this).
MOVIE_DIR = "movies"
MOVIE_NAMES = ["cointoss_heads.avi", "cointoss_tails.avi"]


def find_movies(sources: list[Path]) -> dict[str, Path]:
    """The original coin-toss AVIs, wherever they are under [param sources]."""
    wanted: dict[str, Path | None] = {name: None for name in MOVIE_NAMES}
    for root in sources:
        for path in root.rglob("*"):
            key = path.name.lower()
            if key in wanted and wanted[key] is None and path.is_file():
                wanted[key] = path
    return {k: v for k, v in wanted.items() if v is not None}


def copy_movies(sources: list[Path], skin: Path) -> int:
    """Put the original coin-toss AVIs in `<skin>/movies/`. Returns how
    many were found; none is not an error, it is a 1997-install-only file."""
    found = find_movies(sources)
    if not found:
        return 0
    out = skin / MOVIE_DIR
    out.mkdir(parents=True, exist_ok=True)
    for name, path in sorted(found.items()):
        shutil.copy2(path, out / name)
        print(f"  movie   {name:22} {path.stat().st_size / 1e6:.1f} MB")
    return len(found)


def transcode_movies(skin: Path) -> int:
    """(Re)build the coin-toss sheets from the AVIs already in a skin.

    This is the second half of `copy_movies`: it is what a player runs
    after installing ffmpeg, without needing the 1997 disc again."""
    sys.path.insert(0, str(HERE))
    try:
        import import_original as imp
    except ImportError:
        print(f"!! {IMPORTER.name} must sit next to this script.")
        return 2
    movies = skin / MOVIE_DIR
    if not movies.is_dir():
        print(f"!! no {MOVIE_DIR}/ folder in {skin}")
        print("   Nothing to transcode. An archive built before 2026-09-04,")
        print("   or one built from an install with no movies in it.")
        return 1
    index = {p.name.lower(): p for p in movies.rglob("*") if p.is_file()}
    if not index:
        print(f"!! {movies} is empty")
        return 1
    imp.import_videos(index, skin)
    return 0


GUIDE = """\
WHAT THIS NEEDS

  Your own copy of MicroProse's Magic: The Gathering (1997) — the CD
  install, or a folder someone has already unpacked it into. Point this
  script at the folder that CONTAINS the game; it searches downwards, so
  the top of the install is the right place to aim.

  Three kinds of folder work, and they can be combined (pass --install
  more than once; the first copy of each file wins):

    * a genuine 1997 install    — the best source. Its raw .SPR and .PIC
                                  files hold seventy portraits, five of
                                  which exist in no conversion anywhere.
    * a Manalink 3.0 install    — fonts and some art.
    * an s30 checkout           — the community's .pic.png conversions.

  It reads. It never writes to, moves, or modifies your install.

  ONE STEP NEEDS A HELPER: the two coin-toss movies are AVIs, which
  neither Python nor Godot can read, so they are transcoded into sprite
  sheets using ffmpeg or gst-launch-1.0 — whichever you have. With
  neither, everything else still imports and the toss draws a plain coin.
  --check tells you which of the two it can see.

  THE MOVIES TRAVEL TOO. The archive carries the two original AVIs in a
  movies/ folder beside the sheets they produced, so the conversion can
  always be redone. If you installed the archive with no decoder and have
  since got one:

      python3 mtg_assets.py --transcode-movies /path/to/the/game/skin

  and the sheets appear without needing the 1997 disc again.

WHAT IT PRODUCES

  One zip, default name shandalar-art.zip, with a `skin/` folder inside.
  Unzip it beside the game's executable and the 1997 look appears
  everywhere. Nothing else to configure.

WHAT IT DOES NOT PRODUCE

  Card art. There are 897 cards and their art is not in the 1997 install
  in any usable form, so it is downloaded separately:

      python3 fetch_card_art.py --out cardart/

  and the result goes in the same `skin/` folder.

TRY IT

  python3 mtg_assets.py --check   "/path/to/Magic"
  python3 mtg_assets.py --install "/path/to/Magic"
"""


def look_around(root: Path) -> dict[str, list[str]]:
    """Which landmarks are present, by group. Case-insensitive, recursive,
    and deliberately shallow about what it concludes: a hit means the
    importer has something to chew on, not that the group is complete."""
    found: dict[str, list[str]] = {group: [] for group in LANDMARKS}
    wanted = {name: group for group, names in LANDMARKS.items()
              for name in names}
    for path in root.rglob("*"):
        group = wanted.get(path.name.lower())
        if group is not None and path.name.lower() not in found[group]:
            found[group].append(path.name.lower())
    return found


def report(root: Path) -> bool:
    """Print what an install looks like. True if anything at all was found."""
    if not root.exists():
        print(f"  !! {root} does not exist")
        return False
    print(f"  looking in {root}")
    found = look_around(root)
    any_hit = False
    for group, names in found.items():
        if names:
            any_hit = True
            print(f"   ok  {group:34} ({', '.join(sorted(names)[:3])})")
        else:
            print(f"   --  {group:34} (not found — that part stays drawn)")
    if found["the coin-toss movies"]:
        decoder = next((d for d in DECODERS if shutil.which(d)), None)
        if decoder:
            print(f"       …and {decoder} is here to transcode them.")
        else:
            print("   !!  the movies need ffmpeg or gst-launch-1.0 to convert,")
            print("       and neither is on your PATH. Everything else still")
            print("       imports; the coin toss falls back to a drawn coin.")
    if not any_hit:
        print("\n  Nothing recognisable here. Is this the folder that")
        print("  CONTAINS the game, rather than the game's parent or a")
        print("  subfolder of it?")
    return any_hit


def run_importer(sources: list[Path], dest: Path, videos: bool) -> int:
    if not IMPORTER.exists():
        print(f"!! {IMPORTER.name} must sit next to this script.")
        return 2
    argv = [sys.executable, str(IMPORTER), "--dest", str(dest)]
    for source in sources:
        argv += ["--source", str(source)]
    if not videos:
        argv.append("--no-videos")
    print()
    return subprocess.call(argv)


def write_zip(skin: Path, out: Path,
              extras: list[tuple[Path, str]] | None = None) -> int:
    """Zip a skin folder as `skin/...`, so it unpacks beside the binary.

    [param extras] adds files from OUTSIDE that folder, each with the name
    it should take inside the archive. It exists because the first version
    of `--movies-from` built a symlink overlay instead, and `Path.rglob`
    does not descend into a symlinked DIRECTORY — which silently dropped
    all seventy portraits and shipped an archive of 169 files where 237
    were expected (caught 2026-09-04 by comparing the count)."""
    files = sorted(p for p in skin.rglob("*")
                   if p.is_file() and not p.name.endswith(ZIP_SKIP))
    if not files:
        print(f"!! nothing to archive: {skin} is empty")
        return 1
    out.parent.mkdir(parents=True, exist_ok=True)
    total = 0
    # ZIP_DEFLATED on art that is already PNG/JPG buys a few percent, but
    # it costs nothing to ask and some of these are raw sheets.
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        for path in files:
            zf.write(path, Path("skin") / path.relative_to(skin))
            total += path.stat().st_size
        for path, name in (extras or []):
            zf.write(path, Path("skin") / name)
            total += path.stat().st_size
    count = len(files) + len(extras or [])
    size = out.stat().st_size
    print(f"\narchive: {out}")
    print(f"  {count} files, {total / 1e6:.0f} MB of art"
          f" -> {size / 1e6:.0f} MB zipped")
    print(f"\nUnzip it beside the game's executable:")
    print(f"  unzip -o {out.name} -d /path/to/the/game/")
    print(f"…which puts the art in <game>/skin/, the second place the")
    print(f"game looks. See setup.txt for all three.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__.splitlines()[0],
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--install", action="append", metavar="DIR",
                        help="your 1997 install; repeatable, first match wins")
    parser.add_argument("--check", action="append", metavar="DIR",
                        help="report on an install and write nothing")
    parser.add_argument("--from-skin", metavar="DIR",
                        help="archive an ALREADY imported skin folder")
    parser.add_argument("--out", default="shandalar-art.zip", metavar="FILE",
                        help="archive to write (default: shandalar-art.zip)")
    parser.add_argument("--keep", metavar="DIR",
                        help="keep the imported files here as well as zipping")
    parser.add_argument("--no-videos", action="store_true",
                        help="skip transcoding the coin-toss movies")
    parser.add_argument("--no-bundle-movies", action="store_true",
                        help="do not carry the source AVIs in the archive")
    parser.add_argument("--movies-from", metavar="DIR",
                        help="add the coin-toss AVIs found under DIR to a "
                             "--from-skin archive")
    parser.add_argument("--transcode-movies", metavar="SKIN",
                        help="rebuild the coin-toss sheets from the AVIs "
                             "already in SKIN/movies/ (needs ffmpeg)")
    args = parser.parse_args()

    if args.transcode_movies:
        return transcode_movies(Path(args.transcode_movies).expanduser())

    if args.check:
        for source in args.check:
            report(Path(source).expanduser())
        return 0

    if args.from_skin:
        skin = Path(args.from_skin).expanduser()
        if not skin.is_dir():
            print(f"!! {skin} is not a directory")
            return 2
        extras: list[tuple[Path, str]] = []
        if args.movies_from:
            found = find_movies([Path(args.movies_from).expanduser()])
            for name, path in sorted(found.items()):
                print(f"  movie   {name:22} "
                      f"{path.stat().st_size / 1e6:.1f} MB")
                extras.append((path, f"{MOVIE_DIR}/{name}"))
            if not found:
                print(f"  no coin-toss AVIs under {args.movies_from}")
        return write_zip(skin, Path(args.out).expanduser(), extras)

    if not args.install:
        print(GUIDE)
        return 0

    sources = [Path(s).expanduser() for s in args.install]
    for source in sources:
        if not report(source):
            print("\nStopping: nothing to import from that folder.")
            return 1

    dest = Path(args.keep).expanduser() if args.keep else None
    temp = None
    if dest is None:
        temp = tempfile.mkdtemp(prefix="shandalar-skin-")
        dest = Path(temp)
    try:
        code = run_importer(sources, dest, videos=not args.no_videos)
        if code != 0:
            print(f"\n!! the importer exited {code}; archiving what it wrote")
        if not args.no_bundle_movies:
            print("\nsource movies:")
            if copy_movies(sources, dest) == 0:
                print("  none found (they ship only with the 1997 game)")
        return write_zip(dest, Path(args.out).expanduser())
    finally:
        if temp is not None:
            shutil.rmtree(temp, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())

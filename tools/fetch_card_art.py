#!/usr/bin/env python3
"""Fetch card ART for the whole pool from Scryfall into assets/cardart/.

s30 precedent (game/domain/card_image_fetcher.go): card images come from
Scryfall at runtime with an on-disk cache and a labeled blank-card
fallback. We pre-download instead — a Godot game should play offline, and
the assets/original pattern already established the policy: fetched
imagery lives in a GITIGNORED directory, never in the repo.

We take TWO variants per card:
- `art_crop` (artwork only)  -> assets/cardart/<snake_name>.jpg
  The game composes its own frames around it (battlefield mini-cards,
  the enlarged examine view).
- `border_crop` (the REAL full card scan) -> assets/cardart/<snake_name>_card.jpg
  Piles show it as their fully-visible bottom card, exactly like the
  original/s30 (GameSkin.card_scan resolves it).

Re-running skips files that already exist (resume-safe); --force
re-downloads everything.

Usage:
    python3 tools/fetch_card_art.py            # fetch missing art
    python3 tools/fetch_card_art.py --force    # re-fetch everything
    python3 fetch_card_art.py --out cardart/   # beside a shipped binary

Run next to a SHIPPED binary there is no cards/data/ to read (it lives
inside the .pck), so the pool is asked of Scryfall instead — one paged
search for each of the eight 1997 sets. Same result, one extra minute.

Uses only the standard library; polite to the API (120 ms between calls,
per Scryfall's guidelines).
"""

import argparse
import json
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

# The family banner and the one version string (tools/tool_banner.py).
# The insert is what lets this tool find it when it is run from the flat
# folder beside a PACKAGED game rather than from a checkout.
sys.path.insert(0, str(Path(__file__).resolve().parent))
import tool_banner  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "cards" / "data"
OUT_DIR = ROOT / "assets" / "cardart"

TOOL = "fetch_card_art.py"
## The tool's name in the half-height box-drawing face the whole family is
## set in (DeckLab/lab_console.gd's WORDMARK is the same font). CARD ART,
## because the sibling that fetches the card TEXT says CARD DATA.
WORDMARK = (
    "┌─┐┌─┐┬─┐┌┬┐  ┌─┐┬─┐┌┬┐",
    "│  ├─┤├┬┘ ││  ├─┤├┬┘ │ ",
    "└─┘┴ ┴┴└──┴┘  ┴ ┴┴└─ ┴ ",
)
CAPTION = ("Shandalar 1997 · Scryfall", "one picture per card")

## THE MINI-HELP under the banner (tools/tool_banner.py): what a bare run
## is about to download, the flag that aims it somewhere else, and where
## the rest is. Quoted by EPILOG below, so the two cannot drift.
## `WHERE` is `tools/` in a checkout and nothing beside a packaged game,
## which is the only way one example line is right in both — this is the
## script setup.txt names for the 897 pictures, and a player types it in
## a flat folder (tool_banner.here_prefix()).
WHERE = tool_banner.here_prefix(__file__)
HINT = (
    "python3 %sfetch_card_art.py                 # fetch what is missing" % WHERE,
    "python3 %sfetch_card_art.py --out cardart/  # the pictures elsewhere" % WHERE,
    "python3 %sfetch_card_art.py -h              # --force, and the rest" % WHERE,
)

EPILOG = """\
%s
    python3 %sfetch_card_art.py --force         # re-fetch everything

Two files per card: <name>.jpg (the artwork alone, which the game frames
itself) and <name>_card.jpg (the whole card scan, for the pile that shows
its bottom card). Re-running skips what is already there, so an
interrupted fetch resumes. Nothing here is committed — the pictures are
Scryfall's, and assets/cardart/ is gitignored.

%s
""" % (tool_banner.examples(HINT), WHERE, tool_banner.BANNER_HELP)

API = "https://api.scryfall.com/cards/named"
HEADERS = {
    "User-Agent": "ShandalarGodot/0.1 (open-source fan remake; card art tool)",
    "Accept": "application/json",
}
DELAY_S = 0.12


def snake(name: str) -> str:
    """Card name -> filename stem, matching GameSkin._snake EXACTLY
    ("Mishra's Factory" -> "mishra_s_factory").

    The game's rule is ASCII-only: every character outside [a-z0-9] becomes
    an underscore, accented letters included ("Dandân" -> "dand_n"). This
    used to use str.isalnum(), which keeps "â", so the eight accented
    Arabian Nights names were saved as files the game never looked up
    (found 2026-09-02 by tools/build_card_packs.py; the builder still
    recognises the old spelling so nothing has to be re-fetched)."""
    out = "".join(ch if ("a" <= ch <= "z" or "0" <= ch <= "9") else "_"
                  for ch in name.lower())
    while "__" in out:
        out = out.replace("__", "_")
    return out.strip("_")


def legacy_snake(name: str) -> str:
    """The stem this tool wrote before 2026-09-02 (isalnum keeps accents);
    only differs from snake() for names with non-ASCII letters."""
    out = "".join(ch if ch.isalnum() else "_" for ch in name.lower())
    while "__" in out:
        out = out.replace("__", "_")
    return out.strip("_")


## The eight sets the 1997 game shipped, in the order the shell lists
## them. Only used when there is no checkout to read the pool from — a
## PLAYER runs this script beside the binary, where `cards/data/` lives
## inside the .pck and cannot be opened as a file.
SETS_1997 = ["2ed", "4ed", "arn", "atq", "leg", "drk", "past", "phpr"]


def pool() -> list[tuple[str, str]]:
    """(name, set_code) for every card in the data files, deduped by name
    (first set wins — art differences between printings don't matter to a
    1997 remake). Falls back to asking Scryfall for the eight sets when
    there is no checkout here, so the script works next to a shipped
    binary as well as inside the repo."""
    seen: dict[str, str] = {}
    if DATA_DIR.is_dir():
        for data_file in sorted(DATA_DIR.glob("*.json")):
            # NOT EVERY cards/data/*.json IS A SET'S CARD LIST, and this
            # loop assumed it was. `sets.json` (set names, dates and
            # history, added 2026-09-03) is a DICT, and iterating a dict
            # yields its keys — so `card["name"]` raised "string indices
            # must be integers" and this tool, the one a player is told to
            # run for the 897 pictures, could not start in a checkout at
            # all from that day until 2026-09-11.
            # tools/build_card_packs.py, which calls this, went down with
            # it. A set's card file is a LIST; anything else in the folder
            # is somebody else's.
            records = json.loads(data_file.read_text())
            if not isinstance(records, list):
                continue
            for card in records:
                seen.setdefault(card["name"], card["set"])
    if seen:
        return sorted(seen.items())
    return pool_from_scryfall()


def pool_from_scryfall() -> list[tuple[str, str]]:
    """The same list, built over the network. One paged search per set."""
    print("no card data beside this script — asking Scryfall for the pool")
    seen: dict[str, str] = {}
    for code in SETS_1997:
        url = ("https://api.scryfall.com/cards/search?"
               + urllib.parse.urlencode({"q": f"set:{code}", "unique": "cards"}))
        count = 0
        while url:
            time.sleep(DELAY_S)
            request = urllib.request.Request(url, headers=HEADERS)
            with urllib.request.urlopen(request, timeout=30) as response:
                page = json.loads(response.read().decode("utf-8"))
            for card in page.get("data", []):
                seen.setdefault(card["name"], card["set"])
                count += 1
            url = page.get("next_page") if page.get("has_more") else None
        print(f"  {code}: {count} cards")
    return sorted(seen.items())


def fetch_art_url(name: str, set_code: str) -> dict | None:
    """Scryfall's whole `image_uris` map for a card — every variant, not
    just the one this function is named after — preferring the card's own
    set's printing. (The annotation said `str | None` until 2026-09-11;
    every caller already read it as the dict it is.)"""
    for params in ({"exact": name, "set": set_code}, {"exact": name}):
        url = API + "?" + urllib.parse.urlencode(params)
        time.sleep(DELAY_S)   # pace EVERY metadata call, success or not
        try:
            req = urllib.request.Request(url, headers=HEADERS)
            with urllib.request.urlopen(req, timeout=30) as resp:
                card = json.load(resp)
            uris = card.get("image_uris") or {}
            if uris.get("art_crop"):
                return uris
        except Exception:
            continue   # fall through to the set-less lookup / caller skip
        time.sleep(DELAY_S)
    return None


# The two files every card gets, as (suffix, Scryfall image variant).
VARIANTS = [(".jpg", "art_crop"), ("_card.jpg", "border_crop")]


def targets_for(name: str, out_dir: Path | None = None) -> list[tuple[Path, str]]:
    """[(destination file, Scryfall image variant)] for one card.

    THE DEFAULT IS RESOLVED WHEN CALLED, not when this module loads. It
    used to read `out_dir: Path = OUT_DIR`, which froze the folder at
    import time and made `--out` a flag that created a directory and
    wrote nothing into it (2026-09-11).
    """
    out_dir = OUT_DIR if out_dir is None else out_dir
    return [(out_dir / (snake(name) + suffix), variant)
            for suffix, variant in VARIANTS]


def fetch_missing_art(name: str, set_code: str,
                      missing: list[tuple[Path, str]]) -> tuple[int, int]:
    """Download the `missing` (destination, variant) pairs for one card.
    Returns (files written, failures); paced like everything else here."""
    uris = fetch_art_url(name, set_code)
    if uris is None:
        print(f"WARN: no images for {name}")
        time.sleep(2.0)   # back off — a metadata failure is usually a
        return 0, 1       # 429; hammering turns it into a cascade
    done = failed = 0
    for dest, variant in missing:
        url = uris.get(variant)
        if not url:
            continue
        try:
            req = urllib.request.Request(url, headers=HEADERS)
            with urllib.request.urlopen(req, timeout=60) as resp:
                dest.write_bytes(resp.read())
            done += 1
        except Exception as e:
            print(f"WARN: download failed for {name} ({variant}): {e}")
            failed += 1
    time.sleep(DELAY_S)
    return done, failed


def main(argv: list[str] | None = None) -> int:
    global OUT_DIR
    parser = argparse.ArgumentParser(
        prog=TOOL, description=__doc__.split("\n\n")[0], epilog=EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", metavar="DIR", type=Path, default=OUT_DIR,
                        help="where the pictures go (default: %(default)s)")
    parser.add_argument("--force", action="store_true",
                        help="re-download every picture, not only the missing")
    tool_banner.add_version_flag(parser, TOOL, __file__)
    args = parser.parse_args(argv)
    # THE BANNER IS stderr-AND-A-TERMINAL ONLY (tools/tool_banner.py), and
    # the mini-help under it rides the same guards: a bare run here is
    # 897 cards off Scryfall, and it should say so before it starts.
    tool_banner.show(WORDMARK, CAPTION, __file__, hint=HINT, argv=argv)
    OUT_DIR = args.out.expanduser()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    cards = pool()
    done = skipped = failed = 0
    for i, (name, set_code) in enumerate(cards):
        # OUT_DIR IS PASSED, NOT INHERITED. `targets_for`'s default
        # argument is bound when the module loads, so for as long as this
        # line read `targets_for(name)` the `--out` flag moved the folder
        # that gets CREATED and nothing else: every download still aimed
        # at assets/cardart/ (found 2026-09-11 — beside a packaged game
        # that folder does not exist, so a player following setup.txt got
        # 897 failed downloads and exit 1).
        missing = [t for t in targets_for(name, OUT_DIR)
                   if args.force or not t[0].exists()]
        if not missing:
            skipped += 1
            continue
        d, f = fetch_missing_art(name, set_code, missing)
        done += d
        failed += f
        if (i + 1) % 50 == 0:
            print(f"  {i + 1}/{len(cards)} processed...")
    print(f"card art: {done} fetched, {skipped} already present, {failed} failed"
          f" -> {OUT_DIR}")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())

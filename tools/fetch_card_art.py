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
  original/s30 (GameSkin.card_scan resolves it). Re-running skips files that already exist
(resume-safe); --force re-downloads everything.

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

import json
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "cards" / "data"
OUT_DIR = ROOT / "assets" / "cardart"

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
    if DATA_DIR.is_dir() and any(DATA_DIR.glob("*.json")):
        seen: dict[str, str] = {}
        for data_file in sorted(DATA_DIR.glob("*.json")):
            for card in json.loads(data_file.read_text()):
                seen.setdefault(card["name"], card["set"])
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


def fetch_art_url(name: str, set_code: str) -> str | None:
    """The art_crop URL for a card, preferring its own set's printing."""
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


def targets_for(name: str, out_dir: Path = OUT_DIR) -> list[tuple[Path, str]]:
    """[(destination file, Scryfall image variant)] for one card."""
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


def main() -> int:
    global OUT_DIR
    force = "--force" in sys.argv
    if "--out" in sys.argv:
        OUT_DIR = Path(sys.argv[sys.argv.index("--out") + 1]).expanduser()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    cards = pool()
    done = skipped = failed = 0
    for i, (name, set_code) in enumerate(cards):
        missing = [t for t in targets_for(name) if force or not t[0].exists()]
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

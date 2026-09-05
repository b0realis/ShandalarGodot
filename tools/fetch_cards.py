#!/usr/bin/env python3
"""Fetch the Shandalar card pool from Scryfall into cards/data/<set>.json.

The pool (mirroring s30's update_cards_json.py, plus the Duels of the
Planeswalkers expansion sets):
    2ed   Unlimited            (base game)
    4ed   Fourth Edition       (base game)
    arn   Arabian Nights       (base game / Spells of the Ancients)
    atq   Antiquities          (base game / Spells of the Ancients)
    leg   Legends              (Duels of the Planeswalkers expansion)
    drk   The Dark             (Duels of the Planeswalkers expansion)
    past  Astral               (the 12 MicroProse digital-only cards)
    phpr  HarperPrism promos   (5 book promos, included by s30 precedent)
          + the PROMO REMAINDER: Nalathni Dragon, whose Scryfall printing is
          the DragonCon 1994 promo (set `pdrc`), not a book promo — see
          EXTRA_PRINTINGS below.

Excluded outright (same list as s30): Chaos Orb and Falling Star (dexterity),
Shahrazad (subgame), Word of Command — physically/practically unimplementable.

Output: one JSON file per set with only the fields the project needs.
Re-running refreshes the data (Scryfall oracle text updates over time).
Uses only the standard library; be polite to the API (100 ms between calls).
"""

import json
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

SETS = ["2ed", "4ed", "arn", "atq", "leg", "drk", "past", "phpr"]
EXCLUDED_NAMES = {"Chaos Orb", "Shahrazad", "Word of Command", "Falling Star"}

# CARDS THE 1997 GAME HAD THAT NO WHOLE SCRYFALL SET GIVES US.
#
# The pool is defined as eight Scryfall sets, which is exactly right for the
# expansions and one card short for the PROMOS. Our `phpr` is Scryfall's
# "HarperPrism Book Promos" — Arena, Sewers of Estark, Windseeker Centaur,
# Giant Badger, Mana Crypt — and that set is complete at five. But the 1997
# game shipped a SIXTH promotional card, **Nalathni Dragon**, which is not a
# book promo at all: it was handed out at DragonCon 1994 and Scryfall files
# it under `pdrc`. Fetching whole sets could therefore never produce it, and
# it was missing from this project's pool until 2026-09-01.
#
# THE EVIDENCE that it belongs (Provenance.md's tiers):
#   * `Duel.hlp` — the game's own shipped help, Tier 1 — carries a full card
#     entry for it: "Casting Cost: 2rr / Color: Red / Type: Summon Dragon /
#     Power/Toughness: 1/1 / Banding, flying / {R}: Nalathni Dragon gets
#     +1/+0 until end of turn. If {R}{R}{R}{R} or more is spent in this way
#     during one turn, bury Nalathni Dragon at end of turn."  Duel.hlp
#     mentions no Ice Age or Homelands card, so it is the 1997 file.
#   * `shandalar-src/Program/Cards.dat` and `Program/Magic.exe` name it too,
#     but BOTH are Manalink-updated (they also contain Necropotence and
#     Lhurgoyf, which the 1997 game never had) and settle nothing on their
#     own. Do not cite them for pool questions.
#
# Each entry is `card name -> the Scryfall set to fetch it from`; the record
# is filed under our own set code so the folder layout stays one directory
# per set code, and the printed text still comes from Scryfall rather than
# from anyone's memory.
EXTRA_PRINTINGS = {"phpr": {"Nalathni Dragon": "pdrc"}}

API = "https://api.scryfall.com/cards/search"
HEADERS = {
    "User-Agent": "ShandalarGodot/0.1 (open-source fan remake; card data tool)",
    "Accept": "application/json",
}

KEEP_FIELDS = [
    "name", "mana_cost", "type_line", "oracle_text", "power", "toughness",
    "keywords", "colors", "rarity", "collector_number",
    # `artist` is the ILLUSTRATOR CREDIT the 1997 card prints in its
    # bottom-left corner as `Illus. <name>` — the sixth of the twelve parts
    # `Duel.hlp`'s "Parts of the Card" topic labels. It is taken from
    # Scryfall rather than from the original's own Master.csv on purpose:
    # the art we actually display comes from Scryfall for this same set and
    # collector number (tools/fetch_card_art.py), so this is the credit for
    # the picture on screen. Scryfall omits it for a handful of records, so
    # every reader must tolerate an empty string.
    "artist",
]


# THE ONE SCRYFALL CLIENT. Every tool that talks to api.scryfall.com goes
# through here (tools/build_card_packs.py imports it) so the etiquette
# Scryfall asks for — a real User-Agent and at least 100 ms between
# requests — lives in exactly one place.
def scryfall_get(url: str) -> dict:
    """One GET against Scryfall, parsed as JSON, followed by the pause."""
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = json.load(resp)
    time.sleep(0.1)
    return data


def trim(raw: dict, as_set: str) -> dict:
    """A full Scryfall card record -> the KEEP_FIELDS record we file."""
    card = {k: raw.get(k) for k in KEEP_FIELDS}
    card["set"] = as_set
    if raw.get("printed_in"):
        card["printed_in"] = raw["printed_in"]
    return card


def fetch_set_raw(set_code: str) -> list[dict]:
    """Every printing in one set as Scryfall's FULL record (ids, image
    URIs, legalities, flavour text …), EXCLUDED_NAMES dropped and the
    EXTRA_PRINTINGS appended — each of those carries our `printed_in` key
    naming the Scryfall set it really came from."""
    raws: list[dict] = []
    url = API + "?" + urllib.parse.urlencode(
        {"order": "set", "unique": "prints", "q": f"e:{set_code}"})
    while url:
        page = scryfall_get(url)
        for raw in page.get("data", []):
            if raw["name"] in EXCLUDED_NAMES:
                continue
            raws.append(raw)
        url = page.get("next_page") if page.get("has_more") else None
    for name, from_set in EXTRA_PRINTINGS.get(set_code, {}).items():
        raws.append(fetch_one_raw(name, from_set))
    return raws


def fetch_set(set_code: str) -> list[dict]:
    """All printings in one set, trimmed to KEEP_FIELDS (+ set code)."""
    return [trim(raw, set_code) for raw in fetch_set_raw(set_code)]


def fetch_one_raw(name: str, from_set: str) -> dict:
    """One named card's full record from another Scryfall set, with the
    `printed_in` key that keeps its honest origin."""
    url = "https://api.scryfall.com/cards/named?" + urllib.parse.urlencode(
        {"exact": name, "set": from_set})
    raw = scryfall_get(url)
    # The set code we file it under is OURS; `printed_in` keeps the honest
    # Scryfall origin so nobody has to rediscover where the record came from.
    raw["printed_in"] = from_set
    return raw


def fetch_one(name: str, from_set: str, as_set: str) -> dict:
    """One named card from another Scryfall set, filed under `as_set`."""
    return trim(fetch_one_raw(name, from_set), as_set)


def main() -> int:
    out_dir = Path(__file__).resolve().parent.parent / "cards" / "data"
    out_dir.mkdir(parents=True, exist_ok=True)
    total = 0
    for set_code in SETS:
        cards = fetch_set(set_code)
        out = out_dir / f"{set_code}.json"
        out.write_text(json.dumps(cards, indent=1, ensure_ascii=False) + "\n",
                       encoding="utf-8")
        print(f"{set_code}: {len(cards)} printings -> {out}")
        total += len(cards)
    print(f"total: {total} printings across {len(SETS)} sets")
    return 0


if __name__ == "__main__":
    sys.exit(main())

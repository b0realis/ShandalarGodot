#!/usr/bin/env python3
"""Build self-contained CARD PACKS — one `<set>.tar.gz` per Scryfall set we
have downloaded, plus ONE bundle for the purists: the whole 1997–98 Duels
of the Planeswalkers pool as a single archive.

Why: `cards/data/<set>.json` (tools/fetch_cards.py) and the gitignored
`assets/cardart/` (tools/fetch_card_art.py) are the project's only copies
of what Scryfall gave us, and both are shaped for the running game, not for
keeping. A pack freezes a set — card data, the short lists, the set symbol,
every image, and where all of it came from — in one file that can be
re-used (a future "classic" pack per docs/set-packages-plan.md, another
machine, a re-install) without asking Scryfall again.

THE FORMAT (pack_format 1) — a directory named after the set, tarred:

    <code>/
      set.json          set info + build provenance (see set_manifest)
      cards.json        cards/data/<code>.json record-for-record, in the
                        same order, each record ENRICHED with Scryfall keys
                        gen_cards.py ignores (scryfall_id, cmc,
                        color_identity, image_uris, flavor_text,
                        legalities …). Copy it to cards/data/<code>.json and
                        the existing pipeline consumes it unchanged.
      cards.txt         one UNIQUE name per line, collector-number order
      printings.tsv     every printing: collector_number, name, rarity, artist
      common.txt / uncommon.txt / rare.txt   (mythic.txt, special.txt
                        only when the set has them) — basic lands are NOT
                        in these; they get
      lands.txt         the basic lands
      by_color/         white/blue/black/red/green/multicolor/artifact/
                        land.txt (only the non-empty ones)
      icon.svg          the set symbol (Scryfall icon_svg_uri)
      icon_64.png, icon_128.png   black rasters, only when a rasteriser
                        (rsvg-convert or cairosvg) is on PATH
      art/              <snake>.jpg (art_crop) and <snake>_card.jpg
                        (border_crop) per card NAME — the exact files
                        GameSkin.card_art / card_scan look up under
                        assets/cardart/ — plus art/index.json
      README.txt        what this is, Scryfall's attribution note, reuse

The bundle (`dotp-1997.tar.gz`) has the same top-level files for the
MERGED pool (897 unique names, first set in gen_cards.POOL order wins,
exactly the registry's rule), a flat `art/` keyed by name (the drop-in
replacement for assets/cardart/), and `sets/<code>/` holding each member
set's set.json, cards.json and lists — no art there, art is by name.

Usage:
    python3 tools/build_card_packs.py                # every local set + bundle
    python3 tools/build_card_packs.py leg drk        # just these set packs
    python3 tools/build_card_packs.py --bundle-only  # just dotp-1997.tar.gz
    python3 tools/build_card_packs.py --no-bundle    # set packs only
    python3 tools/build_card_packs.py --offline      # never touch the network;
                                                     # report what is missing
    python3 tools/build_card_packs.py --force        # refetch set objects,
                                                     # icons, listings and art
                                                     # (art once per name,
                                                     # within --max-art-fetch)
    python3 tools/build_card_packs.py --out DIR      # default ../shandalar-packs
    python3 tools/build_card_packs.py --max-art-fetch N   # default 300 files

What it fetches, and only when missing (or --force): the Scryfall set
object, the set's icon SVG, the set's full card listing (for the
enrichment and the art index), and any card art missing from
assets/cardart/ — through fetch_cards.scryfall_get and
fetch_card_art.fetch_missing_art, so the rate limit and User-Agent live in
those two files. Everything fetched is cached under `<out>/cache/` so the
next build is offline-capable. Exit 1 when anything is missing.

Stdlib only.
"""

import argparse
import datetime as _dt
import hashlib
import json
import shutil
import subprocess
import sys
import tarfile
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fetch_card_art  # noqa: E402
import fetch_cards  # noqa: E402
from gen_cards import POOL  # noqa: E402  — dedupe priority, first printing wins

ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "cards" / "data"
ART_DIR = fetch_card_art.OUT_DIR
DEFAULT_OUT = ROOT.parent / "shandalar-packs"

PACK_FORMAT = 1
TOOL_VERSION = "1.0"
TOOL_NAME = "tools/build_card_packs.py"

BUNDLE_ID = "dotp-1997"
BUNDLE_NAME = "Duels of the Planeswalkers (1997–98) pool"
BUNDLE_MEMBERS = list(POOL)   # 2ed 4ed arn atq leg drk past phpr

# Scryfall keys copied onto each cards.json record beyond KEEP_FIELDS.
# Readers in this repo (gen_cards, fetch_card_art, CardRegistry) pick keys
# by name, so extra ones are invisible to them.
ENRICH_FIELDS = [
    "id", "oracle_id", "illustration_id", "cmc", "color_identity",
    "released_at", "flavor_text", "printed_name", "printed_text",
    "image_uris", "scryfall_uri", "reserved", "border_color", "frame",
]
LEGALITY_FORMATS = ["vintage", "legacy", "oldschool", "premodern"]

# The 1997 game's colour groups, which are also the deck builder's.
COLOR_FILES = {"W": "white", "U": "blue", "B": "black", "R": "red", "G": "green"}

SCRYFALL_NOTE = """Card data and card images come from Scryfall (https://scryfall.com),
fetched through its public API by the tools named in set.json. Scryfall's
image guidelines allow free use of the images in a non-commercial fan
project such as this one, ask that Scryfall be credited as the source,
and forbid selling the images or re-hosting them as a bulk service. Card
names, rules text and artwork remain the property of Wizards of the Coast;
each artist is credited per card in art/index.json and in cards.json
(`artist`). This pack is a personal local cache made by the Shandalar
project (a Godot remake of MicroProse's 1997 Magic: The Gathering) for
its own reuse; it is not to be redistributed (see the project's
Provenance.md)."""


# ---------------------------------------------------------------- naming


def snake(name: str) -> str:
    """The game's art key (GameSkin._snake), via the art fetcher."""
    return fetch_card_art.snake(name)


# ------------------------------------------------------------- data shapes


def is_basic_land(card: dict) -> bool:
    return (card.get("type_line") or "").startswith("Basic Land")


def color_group(card: dict) -> str:
    """The by_color/ file a card belongs to."""
    types = (card.get("type_line") or "").partition("—")[0]
    colors = card.get("colors") or []
    if len(colors) > 1:
        return "multicolor"
    if len(colors) == 1:
        return COLOR_FILES[colors[0]]
    if "Land" in types.split():
        return "land"
    if "Artifact" in types.split():
        return "artifact"
    return "colorless"


def unique_in_order(cards: list[dict]) -> list[dict]:
    """One record per name, first occurrence wins, order preserved."""
    seen: set[str] = set()
    out = []
    for card in cards:
        if card["name"] in seen:
            continue
        seen.add(card["name"])
        out.append(card)
    return out


def merge_pool(sets: dict[str, list[dict]], order: list[str]) -> list[dict]:
    """The registry's pool: every name once, filed under the FIRST set in
    `order` that prints it (gen_cards.py's rule; 2ed beats 4ed)."""
    merged: list[dict] = []
    for code in order:
        merged.extend(sets.get(code, []))
    return unique_in_order(merged)


def build_lists(cards: list[dict]) -> dict[str, str]:
    """Every plain-text list of a pack: {relative file name: content}.
    Names are unique; order is the order of `cards` (collector order for
    a set, pool order for the bundle)."""
    uniq = unique_in_order(cards)
    lists: dict[str, list[str]] = {"cards.txt": [n["name"] for n in uniq]}
    by_rarity: dict[str, list[str]] = {}
    lands: list[str] = []
    by_color: dict[str, list[str]] = {}
    for card in uniq:
        if is_basic_land(card):
            lands.append(card["name"])
        else:
            by_rarity.setdefault(card.get("rarity") or "unknown", []).append(card["name"])
        by_color.setdefault(color_group(card), []).append(card["name"])
    for rarity, names in by_rarity.items():
        lists[f"{rarity}.txt"] = names
    lists["lands.txt"] = lands
    for group, names in by_color.items():
        lists[f"by_color/{group}.txt"] = names
    printings = ["collector_number\tname\trarity\tartist\tset"]
    for card in cards:
        printings.append("\t".join([
            card.get("collector_number") or "", card["name"],
            card.get("rarity") or "", card.get("artist") or "", card.get("set") or ""]))
    out = {path: "\n".join(names) + ("\n" if names else "")
           for path, names in lists.items()}
    out["printings.tsv"] = "\n".join(printings) + "\n"
    return out


def rarity_counts(cards: list[dict]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for card in unique_in_order(cards):
        key = "basic_land" if is_basic_land(card) else (card.get("rarity") or "unknown")
        counts[key] = counts.get(key, 0) + 1
    return dict(sorted(counts.items()))


def enrich(cards: list[dict], raws: list[dict] | None) -> tuple[list[dict], int]:
    """cards/data records + the matching full Scryfall records (by name and
    collector number) -> enriched copies, and how many found no match."""
    if not raws:
        return [dict(c) for c in cards], len(cards)
    index = {(r["name"], r.get("collector_number")): r for r in raws}
    by_name: dict[str, dict] = {}
    for r in raws:
        by_name.setdefault(r["name"], r)
    out, unmatched = [], 0
    for card in cards:
        raw = index.get((card["name"], card.get("collector_number"))) \
            or by_name.get(card["name"])
        rec = dict(card)
        if raw is None:
            unmatched += 1
        else:
            rec["scryfall_id"] = raw.get("id")
            for key in ENRICH_FIELDS:
                if key == "id":
                    continue
                if raw.get(key) is not None:
                    rec[key] = raw[key]
            legal = raw.get("legalities") or {}
            rec["legalities"] = {f: legal[f] for f in LEGALITY_FORMATS if f in legal}
        out.append(rec)
    return out, unmatched


def art_index(cards: list[dict], art_files: dict[str, Path],
              fetched_for: dict[str, str]) -> list[dict]:
    """art/index.json rows: name -> files -> printing -> artist."""
    rows = []
    for card in unique_in_order(cards):
        stem = snake(card["name"])
        rows.append({
            "name": card["name"],
            "art_crop": stem + ".jpg" if stem + ".jpg" in art_files else None,
            "border_crop": stem + "_card.jpg" if stem + "_card.jpg" in art_files else None,
            "set": card.get("set"),
            "collector_number": card.get("collector_number"),
            "scryfall_id": card.get("scryfall_id"),
            "illustration_id": card.get("illustration_id"),
            "artist": card.get("artist") or "",
            # The image on disk was fetched ONCE per name, for the printing
            # tools/fetch_card_art.py::pool() picked (first data file in
            # alphabetical order); the artist credit above is this set's.
            "art_fetched_for": fetched_for.get(card["name"]),
        })
    return rows


# --------------------------------------------------------------- manifests


def now_iso() -> str:
    return _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat()


def set_manifest(code: str, cards: list[dict], scry_set: dict | None,
                 art_stats: dict, lists: dict[str, str], icon_files: list[str],
                 enrichment_unmatched: int, missing: list[str]) -> dict:
    scry_set = scry_set or {}
    excluded = sorted(fetch_cards.EXCLUDED_NAMES)
    return {
        "pack_format": PACK_FORMAT,
        "kind": "set",
        "code": code,
        "name": scry_set.get("name"),
        "released_at": scry_set.get("released_at"),
        "set_type": scry_set.get("set_type"),
        "block": scry_set.get("block"),
        "block_code": scry_set.get("block_code"),
        "digital": scry_set.get("digital"),
        "printings": len(cards),
        "card_count": len(unique_in_order(cards)),
        "scryfall_card_count": scry_set.get("card_count"),
        "rarity_counts": rarity_counts(cards),
        "rarity_lists_exclude_basic_lands": True,
        "excluded_names": excluded,
        "extra_printings": fetch_cards.EXTRA_PRINTINGS.get(code, {}),
        "scryfall": {
            "id": scry_set.get("id"),
            "uri": scry_set.get("uri"),
            "scryfall_uri": scry_set.get("scryfall_uri"),
            "search_uri": scry_set.get("search_uri"),
            "icon_svg_uri": scry_set.get("icon_svg_uri"),
        },
        "icon": {"svg": "icon.svg" if "icon.svg" in icon_files else None,
                 "png": [f for f in icon_files if f.endswith(".png")],
                 "rarity_colouring": None},
        "files": {"cards": "cards.json", "lists": sorted(lists)},
        "art": {
            "dir": "art",
            "index": "art/index.json",
            "naming": "GameSkin._snake(name): lower-case, every run outside "
                      "[a-z0-9] becomes one '_', trimmed",
            "variants": {variant: "<snake>" + suffix
                         for suffix, variant in fetch_card_art.VARIANTS},
            **art_stats,
        },
        "cards_json": {
            "superset_of": f"cards/data/{code}.json",
            "base_fields": list(fetch_cards.KEEP_FIELDS) + ["set", "printed_in"],
            "enrichment_fields": ["scryfall_id"] + [k for k in ENRICH_FIELDS if k != "id"]
            + ["legalities"],
            "legality_formats": LEGALITY_FORMATS,
            "records_without_enrichment": enrichment_unmatched,
        },
        "incomplete": missing,
        "build": build_provenance(),
    }


def build_provenance() -> dict:
    return {
        "date": now_iso(),
        "tool": TOOL_NAME,
        "tool_version": TOOL_VERSION,
        "sources": {
            "cards": "cards/data/<set>.json — Scryfall API /cards/search "
                     "q=e:<set> unique=prints, via tools/fetch_cards.py",
            "set_object": "Scryfall API /sets/<set>",
            "card_listing": "Scryfall API /cards/search (full records), for "
                            "the enrichment keys and the art index",
            "icon": "Scryfall set object icon_svg_uri",
            "art": "assets/cardart/ — Scryfall image_uris art_crop and "
                   "border_crop, via tools/fetch_card_art.py",
        },
    }


def bundle_manifest(members: list[dict], merged: list[dict], art_stats: dict,
                    lists: dict[str, str], missing: list[str]) -> dict:
    return {
        "pack_format": PACK_FORMAT,
        "kind": "bundle",
        "code": BUNDLE_ID,
        "name": BUNDLE_NAME,
        "description": "The eight-set pool of MicroProse's Magic: The "
                       "Gathering (1997) with its Spells of the Ancients "
                       "and Duels of the Planeswalkers expansions, the "
                       "Astral cards and the promos — the purist pool the "
                       "game loads by default.",
        "members": [m["code"] for m in members],
        "member_order": "gen_cards.POOL / CardRegistry dedupe priority",
        "sets": [{"code": m["code"], "name": m["name"],
                  "released_at": m["released_at"], "printings": m["printings"],
                  "card_count": m["card_count"], "path": f"sets/{m['code']}"}
                 for m in members],
        "printings": sum(m["printings"] for m in members),
        "card_count": len(merged),
        "dedupe": "one record per name; the first member set in `members` "
                  "order that prints it wins (tools/gen_cards.py rule, "
                  "mirrored by CardRegistry)",
        "rarity_counts": rarity_counts(merged),
        "rarity_lists_exclude_basic_lands": True,
        "files": {"cards": "cards.json", "lists": sorted(lists),
                  "per_set": "sets/<code>/{set.json,cards.json,lists,icon.svg}"},
        "art": {
            "dir": "art",
            "index": "art/index.json",
            "naming": "GameSkin._snake(name) — art/ is a drop-in for "
                      "assets/cardart/",
            "variants": {variant: "<snake>" + suffix
                         for suffix, variant in fetch_card_art.VARIANTS},
            **art_stats,
        },
        "incomplete": missing,
        "build": build_provenance(),
    }


def readme_text(manifest: dict) -> str:
    kind = manifest["kind"]
    head = (f"{manifest['name']} — Shandalar card pack ({manifest['code']})"
            if kind == "set" else f"{manifest['name']} — Shandalar card bundle")
    lines = [head, "=" * len(head), "",
             f"pack_format {PACK_FORMAT}, built {manifest['build']['date']} by "
             f"{TOOL_NAME} v{TOOL_VERSION}.", ""]
    if kind == "set":
        lines += [f"Set: {manifest['name']} ({manifest['code']}), released "
                  f"{manifest['released_at']}, type {manifest['set_type']}.",
                  f"{manifest['printings']} printings, {manifest['card_count']} "
                  f"unique card names."]
    else:
        lines += [f"Member sets: {', '.join(manifest['members'])}.",
                  f"{manifest['printings']} printings, {manifest['card_count']} "
                  f"unique card names after the registry's dedupe."]
    lines += ["", "Contents", "--------",
              "  set.json         this pack described (counts, Scryfall links, "
              "provenance)",
              "  cards.json       the card records — the same shape as "
              "cards/data/<set>.json in",
              "                   the Shandalar repo, with extra Scryfall keys",
              "  cards.txt        unique names, collector-number order",
              "  printings.tsv    every printing with number, rarity, artist",
              "  common.txt, uncommon.txt, rare.txt   by rarity (basic lands "
              "are in lands.txt)",
              "  by_color/        white, blue, black, red, green, multicolor, "
              "artifact, land",
              "  icon.svg         the set symbol"]
    if manifest["art"].get("note"):
        lines += ["  (no art here: this set is a member of a bundle whose art/ "
                  "is at the bundle",
                  "   root, keyed by card name — a reprint has one picture)"]
    else:
        lines += ["  art/             <name>.jpg = artwork crop, <name>_card.jpg = "
                  "full card scan;",
                  "                   art/index.json maps names to files, printings "
                  "and artists"]
    if kind == "bundle":
        lines += ["  sets/<code>/     each member set's own set.json, cards.json, "
                  "lists and icon"]
    lines += ["", "Reuse", "-----",
              "  cards.json  -> copy to cards/data/<set>.json; tools/gen_cards.py "
              "reads it as is.",
              "  art/*.jpg   -> copy into assets/cardart/ (gitignored); "
              "GameSkin.card_art finds",
              "                 them by card name at once, no import step.",
              "  The lists are for booster/economy/deck tooling that wants "
              "names by rarity",
              "  or colour without parsing JSON.", "",
              "Attribution", "-----------", SCRYFALL_NOTE, ""]
    return "\n".join(lines)


# ------------------------------------------------------------------ cache


class Cache:
    """`<out>/cache/` — everything fetched from Scryfall, so a rebuild is
    offline-capable. --offline reads it and never writes it."""

    def __init__(self, out_dir: Path, offline: bool, force: bool):
        self.dir = out_dir / "cache"
        self.offline = offline
        self.force = force
        self.missing: list[str] = []
        self.fetched: list[str] = []

    def _get(self, path: Path, fetch, label: str, binary: bool = False):
        if path.exists() and not self.force:
            return path.read_bytes() if binary else json.loads(path.read_text(encoding="utf-8"))
        if self.offline:
            self.missing.append(label)
            return None
        try:
            data = fetch()
        except Exception as e:   # noqa: BLE001 — report, keep building
            print(f"WARN: {label}: {e}")
            self.missing.append(label)
            return None
        self.dir.mkdir(parents=True, exist_ok=True)
        if binary:
            path.write_bytes(data)
        else:
            path.write_text(json.dumps(data, indent=1, ensure_ascii=False) + "\n",
                            encoding="utf-8")
        self.fetched.append(label)
        return data

    def set_object(self, code: str) -> dict | None:
        return self._get(self.dir / f"{code}.set.json",
                         lambda: fetch_cards.scryfall_get(
                             f"https://api.scryfall.com/sets/{code}"),
                         f"set object {code}")

    def listing(self, code: str) -> list[dict] | None:
        return self._get(self.dir / f"{code}.scryfall.json",
                         lambda: fetch_cards.fetch_set_raw(code),
                         f"card listing {code}")

    def icon(self, code: str, uri: str | None) -> bytes | None:
        if not uri:
            self.missing.append(f"icon {code} (no icon_svg_uri)")
            return None

        def fetch() -> bytes:
            import urllib.request
            req = urllib.request.Request(uri, headers=fetch_cards.HEADERS)
            with urllib.request.urlopen(req, timeout=30) as resp:
                data = resp.read()
            time.sleep(0.1)
            return data
        return self._get(self.dir / f"{code}.icon.svg", fetch, f"icon {code}",
                         binary=True)


def rasterise(svg: Path, out_dir: Path, sizes=(64, 128)) -> list[str]:
    """icon_<size>.png files when a rasteriser is on PATH; else nothing."""
    made: list[str] = []
    rsvg = shutil.which("rsvg-convert")
    cairo = shutil.which("cairosvg")
    if not (rsvg or cairo):
        return made
    for size in sizes:
        dest = out_dir / f"icon_{size}.png"
        cmd = ([rsvg, "-w", str(size), "-h", str(size), "-o", str(dest), str(svg)]
               if rsvg else
               [cairo, str(svg), "-o", str(dest), "--output-width", str(size),
                "--output-height", str(size)])
        try:
            subprocess.run(cmd, check=True, capture_output=True, timeout=60)
            made.append(dest.name)
        except Exception as e:   # noqa: BLE001
            print(f"WARN: rasterising {svg.name} at {size}px failed: {e}")
    return made


# -------------------------------------------------------------------- art


def local_art_file(name: str, suffix: str) -> Path | None:
    """The file assets/cardart/ holds for a card, under the game's name
    or the pre-2026-09-02 accented spelling."""
    for stem in (snake(name), fetch_card_art.legacy_snake(name)):
        path = ART_DIR / (stem + suffix)
        if path.exists():
            return path
    return None


_FETCHED_FOR: dict[str, str] = {}


def art_fetched_for() -> dict[str, str]:
    """name -> the set fetch_card_art.py asked Scryfall for (its pool()
    rule: first data file in alphabetical order). Read once per run."""
    if not _FETCHED_FOR:
        _FETCHED_FOR.update(fetch_card_art.pool())
    return _FETCHED_FOR


# Names whose art --force already re-fetched in this run: every pack that
# shares a name (2ed/4ed reprints, the bundle) reuses the fresh file.
_REFETCHED: set[str] = set()


def collect_art(cards: list[dict], offline: bool, force: bool,
                max_fetch: int, missing_report: list[str]) -> tuple[dict[str, Path], list[str]]:
    """{pack file name: local path} for every card, fetching what is
    absent from assets/cardart/ (bounded by max_fetch). Returns the map
    and the names still without a complete pair."""
    fetched_for = art_fetched_for()
    files: dict[str, Path] = {}
    to_fetch: list[tuple[str, list[tuple[Path, str]]]] = []
    for card in unique_in_order(cards):
        name = card["name"]
        refetch = force and not offline and name not in _REFETCHED
        want = []
        for suffix, variant in fetch_card_art.VARIANTS:
            local = None if refetch else local_art_file(name, suffix)
            if local is None:
                want.append((ART_DIR / (snake(name) + suffix), variant))
            else:
                files[snake(name) + suffix] = local
        if want:
            to_fetch.append((name, want))
    n_files = sum(len(w) for _, w in to_fetch)
    if to_fetch and (offline or (max_fetch and n_files > max_fetch)):
        why = "offline" if offline else f"{n_files} files > --max-art-fetch {max_fetch}"
        missing_report.append(f"art: {n_files} files for {len(to_fetch)} cards not fetched ({why})")
        if force:   # the files we skipped are still there to be packed
            for name, want in to_fetch:
                for suffix, _variant in fetch_card_art.VARIANTS:
                    local = local_art_file(name, suffix)
                    if local is not None:
                        files[snake(name) + suffix] = local
    elif to_fetch:
        print(f"  fetching {n_files} art files for {len(to_fetch)} cards …")
        ART_DIR.mkdir(parents=True, exist_ok=True)
        for name, want in to_fetch:
            fetch_card_art.fetch_missing_art(name, fetched_for.get(name, ""), want)
            _REFETCHED.add(name)
            for dest, _variant in want:
                if dest.exists():
                    files[dest.name] = dest
        still = [n for n, w in to_fetch if any(not d.exists() for d, _ in w)]
        if still:
            missing_report.append(f"art: Scryfall gave nothing for {len(still)} cards: "
                                  + ", ".join(still[:10]))
    incomplete = [c["name"] for c in unique_in_order(cards)
                  if any(snake(c["name"]) + s not in files for s, _ in fetch_card_art.VARIANTS)]
    return files, incomplete


def art_stats(cards: list[dict], files: dict[str, Path], incomplete: list[str]) -> dict:
    return {
        "files": len(files),
        "bytes": sum(p.stat().st_size for p in files.values()),
        "cards_with_art": len(unique_in_order(cards)) - len(incomplete),
        "cards_missing_art": incomplete,
    }


# ---------------------------------------------------------------- writing


def write_text_files(dest: Path, lists: dict[str, str]) -> None:
    for rel, content in lists.items():
        path = dest / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")


def write_json(path: Path, data) -> None:
    path.write_text(json.dumps(data, indent=1, ensure_ascii=False) + "\n",
                    encoding="utf-8")


def stage_set(code: str, cards: list[dict], cache: Cache, dest: Path,
              with_art: bool, offline: bool, force: bool,
              max_fetch: int) -> tuple[dict, dict[str, Path]]:
    """Write one set's pack directory at `dest` (everything but the art,
    which is tarred straight from assets/cardart/); return the manifest
    and {art/<file>: local path}."""
    dest.mkdir(parents=True, exist_ok=True)
    missing: list[str] = []
    before = len(cache.missing)
    scry_set = cache.set_object(code)
    raws = cache.listing(code)
    enriched, unmatched = enrich(cards, raws)
    write_json(dest / "cards.json", enriched)
    lists = build_lists(enriched)
    write_text_files(dest, lists)
    icon_files: list[str] = []
    svg = cache.icon(code, (scry_set or {}).get("icon_svg_uri"))
    if svg:
        (dest / "icon.svg").write_bytes(svg)
        icon_files = ["icon.svg"] + rasterise(dest / "icon.svg", dest)
    stats = {"files": 0, "bytes": 0, "cards_with_art": 0, "cards_missing_art": []}
    files: dict[str, Path] = {}
    if with_art:
        files, incomplete = collect_art(enriched, offline, force, max_fetch, missing)
        art_dir = dest / "art"
        art_dir.mkdir(exist_ok=True)
        write_json(art_dir / "index.json", art_index(enriched, files, art_fetched_for()))
        stats = art_stats(enriched, files, incomplete)
    missing = cache.missing[before:] + missing
    manifest = set_manifest(code, enriched, scry_set, stats, lists, icon_files,
                            unmatched, missing)
    if not with_art:
        manifest["art"] = {"dir": "../../art", "note": "art lives at the bundle "
                           "root, keyed by card name"}
    write_json(dest / "set.json", manifest)
    (dest / "README.txt").write_text(readme_text(manifest), encoding="utf-8")
    return manifest, {"art/" + f: p for f, p in files.items()}


def make_archive(src_dir: Path, archive: Path, extra: dict[str, Path] | None = None) -> None:
    """`archive` = gzip tar of `src_dir` with the directory as its root,
    plus `extra` {path inside the root: local file} — the art, which is
    never copied to disk on the way in."""
    tmp = archive.with_suffix(archive.suffix + ".partial")
    root = src_dir.name
    with tarfile.open(tmp, "w:gz", compresslevel=6) as tar:
        tar.add(src_dir, arcname=root, recursive=False)
        for path in sorted(src_dir.rglob("*")):
            tar.add(path, arcname=str(Path(root) / path.relative_to(src_dir)),
                    recursive=False)
        for rel, src in sorted((extra or {}).items()):
            tar.add(src, arcname=str(Path(root) / rel), recursive=False)
    tmp.replace(archive)


def sha256_of(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def dir_bytes(path: Path) -> int:
    return sum(p.stat().st_size for p in path.rglob("*") if p.is_file())


def index_row(manifest: dict, archive: Path, extracted_bytes: int) -> dict:
    return {
        "file": archive.name,
        "kind": manifest["kind"],
        "code": manifest["code"],
        "name": manifest["name"],
        "members": manifest.get("members"),
        "printings": manifest["printings"],
        "cards": manifest["card_count"],
        "art_files": manifest["art"].get("files", 0),
        "cards_missing_art": len(manifest["art"].get("cards_missing_art", [])),
        "incomplete": manifest["incomplete"],
        "size": archive.stat().st_size,
        "extracted_size": extracted_bytes,
        "sha256": sha256_of(archive),
        "built": manifest["build"]["date"],
        "pack_format": PACK_FORMAT,
    }


def update_index(out_dir: Path, rows: list[dict]) -> Path:
    """`<out>/index.json`: one row per archive; rebuilt rows replace old
    ones by file name, rows for archives that no longer exist are dropped."""
    path = out_dir / "index.json"
    existing: dict[str, dict] = {}
    if path.exists():
        try:
            for row in json.loads(path.read_text(encoding="utf-8")).get("packs", []):
                existing[row["file"]] = row
        except (ValueError, KeyError, TypeError):
            pass
    for row in rows:
        existing[row["file"]] = row
    kept = [r for r in existing.values() if (out_dir / r["file"]).exists()]
    kept.sort(key=lambda r: (r["kind"] != "set", r["code"]))
    write_json(path, {"pack_format": PACK_FORMAT, "generated": now_iso(),
                      "tool": TOOL_NAME, "tool_version": TOOL_VERSION,
                      "packs": kept})
    return path


def local_sets() -> list[str]:
    """Set codes with a cards/data/<code>.json, POOL order first."""
    codes = [p.stem for p in DATA_DIR.glob("*.json")]
    return sorted(codes, key=lambda c: (c not in POOL, POOL.index(c) if c in POOL else 0, c))


def load_set(code: str) -> list[dict]:
    return json.loads((DATA_DIR / f"{code}.json").read_text(encoding="utf-8"))


# ------------------------------------------------------------------- main


def build(out_dir: Path, codes: list[str], bundle: bool, offline: bool,
          force: bool, max_fetch: int) -> int:
    out_dir.mkdir(parents=True, exist_ok=True)
    if ROOT in out_dir.resolve().parents or out_dir.resolve() == ROOT:
        (out_dir / ".gdignore").touch()   # keep Godot's importer out
    cache = Cache(out_dir, offline, force)
    stage_root = out_dir / ".stage"
    if stage_root.exists():
        shutil.rmtree(stage_root)
    rows: list[dict] = []
    problems: list[str] = []
    t0 = time.time()

    for code in codes:
        t1 = time.time()
        cards = load_set(code)
        stage = stage_root / code
        manifest, art_files = stage_set(code, cards, cache, stage, True, offline,
                                        force, max_fetch)
        archive = out_dir / f"{code}.tar.gz"
        make_archive(stage, archive, art_files)
        rows.append(index_row(manifest, archive,
                              dir_bytes(stage) + manifest["art"]["bytes"]))
        shutil.rmtree(stage)
        art = manifest["art"]
        print(f"{code:5} {manifest['name'] or '?':28} {manifest['printings']:4} printings "
              f"{manifest['card_count']:4} names  art {art['files']:4} files "
              f"({art['bytes'] / 1e6:6.1f} MB)  -> {archive.name} "
              f"{archive.stat().st_size / 1e6:6.1f} MB  {time.time() - t1:5.1f}s")
        for m in manifest["incomplete"]:
            problems.append(f"{code}: {m}")

    if bundle:
        t1 = time.time()
        members = [c for c in BUNDLE_MEMBERS if (DATA_DIR / f"{c}.json").exists()]
        absent = [c for c in BUNDLE_MEMBERS if c not in members]
        stage = stage_root / BUNDLE_ID
        stage.mkdir(parents=True)
        member_manifests = []
        per_set: dict[str, list[dict]] = {}
        for code in members:
            m, _ = stage_set(code, load_set(code), cache, stage / "sets" / code,
                             False, offline, force, max_fetch)
            member_manifests.append(m)
            per_set[code] = json.loads((stage / "sets" / code / "cards.json")
                                       .read_text(encoding="utf-8"))
        merged = merge_pool(per_set, members)
        write_json(stage / "cards.json", merged)
        lists = build_lists(merged)
        write_text_files(stage, lists)
        missing: list[str] = [f"member set {c} has no cards/data/{c}.json" for c in absent]
        files, incomplete = collect_art(merged, offline, force, max_fetch, missing)
        art_dir = stage / "art"
        art_dir.mkdir()
        write_json(art_dir / "index.json", art_index(merged, files, art_fetched_for()))
        for m in member_manifests:
            missing.extend(f"{m['code']}: {x}" for x in m["incomplete"])
        manifest = bundle_manifest(member_manifests, merged,
                                   art_stats(merged, files, incomplete), lists, missing)
        write_json(stage / "set.json", manifest)
        (stage / "README.txt").write_text(readme_text(manifest), encoding="utf-8")
        archive = out_dir / f"{BUNDLE_ID}.tar.gz"
        make_archive(stage, archive, {"art/" + f: p for f, p in files.items()})
        rows.append(index_row(manifest, archive,
                              dir_bytes(stage) + manifest["art"]["bytes"]))
        shutil.rmtree(stage)
        art = manifest["art"]
        print(f"{BUNDLE_ID}: {len(members)} sets, {manifest['printings']} printings, "
              f"{manifest['card_count']} names, art {art['files']} files "
              f"({art['bytes'] / 1e6:.1f} MB) -> {archive.name} "
              f"{archive.stat().st_size / 1e6:.1f} MB  {time.time() - t1:.1f}s")
        problems.extend(f"{BUNDLE_ID}: {m}" for m in missing)

    if stage_root.exists():
        shutil.rmtree(stage_root)
    index = update_index(out_dir, rows)
    print(f"index: {index}  ({len(rows)} archive(s) rebuilt, "
          f"{len(cache.fetched)} Scryfall fetch(es), {time.time() - t0:.1f}s total)")
    if problems:
        print("MISSING / INCOMPLETE:")
        for p in problems:
            print("  " + p)
        return 1
    return 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("sets", nargs="*", help="set codes (default: every cards/data/*.json)")
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT,
                    help=f"packs directory (default {DEFAULT_OUT})")
    ap.add_argument("--offline", action="store_true", help="never fetch; report what is missing")
    ap.add_argument("--force", action="store_true",
                    help="refetch set objects, icons, listings and all art")
    ap.add_argument("--no-bundle", action="store_true", help=f"skip {BUNDLE_ID}.tar.gz")
    ap.add_argument("--bundle-only", action="store_true", help=f"build only {BUNDLE_ID}.tar.gz")
    ap.add_argument("--max-art-fetch", type=int, default=300,
                    help="most art files to download per pack (default 300; 0 = no limit)")
    args = ap.parse_args(argv)
    codes = args.sets or local_sets()
    unknown = [c for c in codes if not (DATA_DIR / f"{c}.json").exists()]
    if unknown:
        print(f"no cards/data/<code>.json for: {', '.join(unknown)} — run "
              f"tools/fetch_cards.py first (a pack is built from local data)")
        return 2
    if args.bundle_only:
        codes = []
    bundle = not args.no_bundle and (args.bundle_only or not args.sets)
    return build(args.out, codes, bundle, args.offline, args.force, args.max_art_fetch)


if __name__ == "__main__":
    sys.exit(main())

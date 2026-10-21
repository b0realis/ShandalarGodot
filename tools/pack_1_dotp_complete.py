#!/usr/bin/env python3
"""Build, fetch, or verify Pack-1-DotP-complete.zip.

This is deliberately separate from build_card_packs.py. That tool archives
card data and optional art set-by-set; this one builds the gameplay add-on
whose presence unlocks the complete named checklists of the eight card groups
already represented in ShandalarGodot.

The ZIP contains metadata plus crop and full-card art for all 373 Pack 1 set
entries, but no executable code. The four digital-adaptation implementations
ship dormant in the game and are registered only while this pack is enabled,
so a renamed archive cannot inject GDScript into the process.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import tempfile
import urllib.parse
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fetch_cards  # noqa: E402
import fetch_card_art  # noqa: E402
import tool_banner  # noqa: E402
from gen_cards import slugify  # noqa: E402

TOOL = "pack_1_dotp_complete.py"
WORDMARK = (
    "┌─┐┌─┐┌─┐┬┌─  ┬",
    "├─┘├─┤│  ├┴┐  │",
    "┴  ┴ ┴└─┘┴ ┴  ┴",
)
CAPTION = ("Shandalar 1997 · gameplay pack", "complete DotP set checklists")
HINT = (
    "python3 tools/pack_1_dotp_complete.py fetch-art # fetch Pack 1's art",
    "python3 tools/pack_1_dotp_complete.py          # build Pack 1",
    "python3 tools/pack_1_dotp_complete.py verify   # verify the built ZIP",
    "python3 tools/pack_1_dotp_complete.py -h       # every command and count",
)

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "packaging" / "card_packs" / "pack_1_dotp_complete"
BASE_DATA = ROOT / "cards" / "data"
DEFAULT_OUT = ROOT.parent / "shandalar-packs" / "Pack-1-DotP-complete.zip"
DEFAULT_ART = ROOT.parent / "shandalar-packs" / "cache" / "pack_1_art"
FILE_NAME = "Pack-1-DotP-complete.zip"
PACK_VERSION = "1.0.0"
MINIMUM_GAME_VERSION = "0.20.0"
PREFIX = "card_packs/pack_1_dotp_complete/"
SET_ORDER = ["2ed", "arn", "atq", "leg", "drk", "4ed", "past", "phpr"]
MISSING = {
    "2ed": ["Chaos Orb", "Word of Command"],
    "arn": ["Shahrazad"],
    "leg": ["Falling Star"],
}
EXPECTED = {
    "published_printings": 1305,
    "named_set_entries": 1270,
    "distinct_cards": 901,
    "pack_card_entries": 373,
    "reprint_entries": 369,
    "new_rules_identities": 4,
}
EXPECTED_SETS = {
    "2ed": (292, 302), "arn": (78, 78), "atq": (85, 100),
    "leg": (310, 310), "drk": (119, 119), "4ed": (368, 378),
    "past": (12, 12), "phpr": (6, 6),
}
ZIP_TIME = (1980, 1, 1, 0, 0, 0)


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def json_bytes(value) -> bytes:
    return (json.dumps(value, indent=2, ensure_ascii=False, sort_keys=True)
            + "\n").encode("utf-8")


def sha256(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def artwork_sha256(entries: list[tuple[str, bytes]]) -> str:
    """One stable digest over artwork paths and each file's own digest."""
    digest = hashlib.sha256()
    for name, payload in sorted(entries):
        digest.update(name.encode("utf-8"))
        digest.update(b"\0")
        digest.update(sha256(payload).encode("ascii"))
        digest.update(b"\n")
    return digest.hexdigest()


def unique_names(rows: list[dict]) -> list[str]:
    seen: set[str] = set()
    names: list[str] = []
    for row in rows:
        name = row["name"]
        if name not in seen:
            seen.add(name)
            names.append(name)
    return names


def source_cards() -> list[dict]:
    rows = read_json(SOURCE / "missing_cards.json")
    if not isinstance(rows, list):
        raise ValueError("missing_cards.json is not an array")
    got = {row.get("name") for row in rows if isinstance(row, dict)}
    wanted = {name for names in MISSING.values() for name in names}
    if got != wanted:
        raise ValueError("missing_cards.json names differ: expected %s, got %s" %
                         (sorted(wanted), sorted(got)))
    return rows


def assigned_pairs(root: Path | None = None) -> set[tuple[str, str]]:
    """The 897 base assignments, from source scripts or a packaged snapshot.

    Release tooling generates the snapshot from these same source scripts;
    players do not need a source checkout merely to construct Pack 1.
    """
    root = ROOT if root is None else root
    snapshot = root / "packaging/card_packs/pack_1_dotp_complete/base_assignments.json"
    if snapshot.is_file():
        rows = read_json(snapshot)
        if not isinstance(rows, list) or len(rows) != 897:
            raise ValueError("expected 897 portable base assignments")
        known = {code: set(unique_names(read_json(root / "cards/data" / f"{code}.json")))
                 for code in SET_ORDER}
        pairs = set()
        for row in rows:
            if (not isinstance(row, list) or len(row) != 2
                    or not all(isinstance(value, str) for value in row)
                    or row[0] not in known or row[1] not in known[row[0]]):
                raise ValueError("invalid portable base assignment")
            pairs.add(tuple(row))
        if len(pairs) != 897 or len({name for _, name in pairs}) != 897:
            raise ValueError("duplicate portable base assignments")
        return pairs
    pairs: set[tuple[str, str]] = set()
    for code in SET_ORDER:
        rows = read_json(root / "cards/data" / f"{code}.json")
        by_file: dict[str, list[str]] = {}
        for name in unique_names(rows):
            by_file.setdefault(slugify(name), []).append(name)
        for path in sorted((root / "cards" / "sets" / code).glob("*.gd")):
            if path.name.startswith("_"):
                continue
            matches = by_file.get(path.stem, [])
            if len(matches) != 1:
                raise ValueError("cannot match %s to one %s card: %s" %
                                 (path, code, matches))
            pairs.add((code, matches[0]))
    if len(pairs) != 897:
        raise ValueError("expected 897 base set assignments, found %d" % len(pairs))
    return pairs


def assembled() -> tuple[dict, dict, list[dict], str]:
    missing = source_cards()
    missing_by_set: dict[str, list[dict]] = {}
    for row in missing:
        missing_by_set.setdefault(row["set"], []).append(row)
    base_pairs = assigned_pairs()

    sets: dict[str, dict] = {}
    all_names: set[str] = set()
    pack_cards: list[dict] = []
    published = 0
    named_entries = 0
    for code in SET_ORDER:
        rows = read_json(BASE_DATA / f"{code}.json")
        rows.extend(missing_by_set.get(code, []))
        names = unique_names(rows)
        by_name = {row["name"]: row for row in reversed(rows)}
        unique_rows = [by_name[name] for name in names]
        pack_cards.extend(row for row in unique_rows
                          if (code, row["name"]) not in base_pairs)
        published += len(rows)
        named_entries += len(names)
        all_names.update(names)
        sets[code] = {
            "names": names,
            "named_cards": len(names),
            "published_printings": len(rows),
        }

    counts = {
        "published_printings": published,
        "named_set_entries": named_entries,
        "distinct_cards": len(all_names),
        "pack_card_entries": len(pack_cards),
        "reprint_entries": len(pack_cards) - len(missing),
        "new_rules_identities": len(missing),
    }
    if counts != EXPECTED:
        raise ValueError("source counts changed: expected %s, got %s" %
                         (EXPECTED, counts))

    manifest = read_json(SOURCE / "manifest.json")
    manifest["counts"] = counts
    manifest["new_rules_identities"] = [row["name"] for row in missing]
    catalog = {
        "pack_format": manifest["pack_format"],
        "pack_id": manifest["id"],
        "counts": counts,
        "sets": sets,
    }
    readme = (SOURCE / "README.txt").read_text(encoding="utf-8")
    return manifest, catalog, pack_cards, readme


def write_entry(zf: zipfile.ZipFile, name: str, payload: bytes) -> None:
    inside = name if name.startswith((PREFIX, "skin/cardart/")) else PREFIX + name
    info = zipfile.ZipInfo(inside, ZIP_TIME)
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = 0o100644 << 16
    zf.writestr(info, payload)


def art_targets(art_dir: Path, cards: list[dict] | None = None) \
        -> list[tuple[Path, dict, str]]:
    cards = assembled()[2] if cards is None else cards
    out: list[tuple[Path, dict, str]] = []
    for row in cards:
        set_dir = art_dir / row["set"]
        for path, variant in fetch_card_art.targets_for(row["name"], set_dir):
            out.append((path, row, variant))
    return out


def fetch_art(art_dir: Path) -> None:
    art_dir.mkdir(parents=True, exist_ok=True)
    fetched = skipped = failed = 0
    cards = assembled()[2]
    for index, row in enumerate(cards, 1):
        set_dir = art_dir / row["set"]
        set_dir.mkdir(parents=True, exist_ok=True)
        targets = fetch_card_art.targets_for(row["name"], set_dir)
        missing = [target for target in targets if not target[0].is_file()]
        if not missing:
            skipped += len(targets)
            continue
        done, bad = fetch_card_art.fetch_missing_art(
            row["name"], row["set"], missing)
        fetched += done
        failed += bad
        if index % 25 == 0:
            print("  %d/%d Pack 1 cards processed..." % (index, len(cards)))
    print("Pack 1 art: %d fetched, %d cached, %d failed -> %s" %
          (fetched, skipped, failed, art_dir))
    still_missing = [path for path, _row, _variant in art_targets(art_dir, cards)
                     if not path.is_file()]
    if failed or still_missing:
        raise ValueError("one or more Pack 1 images could not be fetched")


def build(out: Path, art_dir: Path = DEFAULT_ART, include_art: bool = True) -> None:
    if out.name != FILE_NAME:
        raise ValueError("pack must be named exactly %s" % FILE_NAME)
    manifest, catalog, additions, readme = assembled()
    art = art_targets(art_dir) if include_art else []
    missing = [path for path, _row, _variant in art if not path.is_file()]
    if missing:
        raise ValueError("Pack 1 art is missing; run `%s fetch-art` first (%s)" %
                         (TOOL, missing[0]))
    metadata = {
        "catalog.json": json_bytes(catalog),
        "cards.json": json_bytes(additions),
        "README.txt": readme.encode("utf-8"),
    }
    artwork: list[tuple[str, bytes]] = []
    for path, row, _variant in art:
        artwork.append((PREFIX + "art/%s/%s" % (row["set"], path.name),
                        path.read_bytes()))
    # The four genuinely new names use the ordinary art lookup too.
    new_names = {name for names in MISSING.values() for name in names}
    for path, row, _variant in art:
        if row["name"] in new_names:
            artwork.append(("skin/cardart/" + path.name, path.read_bytes()))
    manifest["checksums"] = {
        "algorithm": "sha256",
        "metadata": {name: sha256(payload)
                     for name, payload in sorted(metadata.items())},
        "artwork": {
            "files": len(artwork),
            "sha256": artwork_sha256(artwork),
        },
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    # A failed build must never damage an existing pack — the same guard
    # packs 2-5 carry. Writing straight to `out` truncated a verified
    # 75 MB Pack 1 to an unreadable stub the moment the write raised
    # (a full disk is the ordinary way), and the art fetch that built it
    # is an hour of Scryfall calls. Stage beside the target, verify the
    # staged file, then replace in one step.
    with tempfile.TemporaryDirectory(prefix=".pack-1-", dir=out.parent) as tmp:
        staged = Path(tmp) / FILE_NAME
        with zipfile.ZipFile(staged, "w") as zf:
            write_entry(zf, "manifest.json", json_bytes(manifest))
            for name, payload in metadata.items():
                write_entry(zf, name, payload)
            for name, payload in artwork:
                write_entry(zf, name, payload)
        report = verify(staged, require_art=include_art)
        os.replace(staged, out)
    print("pack: %s" % out)
    print("Pack 1: %(pack_card_entries)d card entries · %(reprint_entries)d reprints · "
          "%(new_rules_identities)d new rules identities" % report["counts"])
    print("cards: %(distinct_cards)d distinct · %(named_set_entries)d named set entries · "
          "%(published_printings)d published printings" % report["counts"])


def verify(path: Path, require_art: bool = True) -> dict:
    if path.name != FILE_NAME:
        raise ValueError("pack must be named exactly %s" % FILE_NAME)
    if not path.is_file():
        raise ValueError("pack does not exist: %s" % path)
    metadata_files = {
        PREFIX + "manifest.json", PREFIX + "catalog.json",
        PREFIX + "cards.json", PREFIX + "README.txt",
    }
    with zipfile.ZipFile(path) as zf:
        listed = zf.namelist()
        # A NAME MAY APPEAR ONCE. `zipfile` resolves a repeated name to the
        # LAST entry while a reader that walks the central directory in
        # order — Godot's `ZIPReader`, minizip under it — takes the FIRST,
        # so a second copy appended after a genuine one let a forged
        # `cards.json` pass every checksum below. Packs 2-5 refuse this;
        # collapsing the list into a set here is what hid it.
        if len(listed) != len(set(listed)):
            raise ValueError("duplicate ZIP entries")
        names = set(listed)
        metadata = {
            "catalog.json": zf.read(PREFIX + "catalog.json"),
            "cards.json": zf.read(PREFIX + "cards.json"),
            "README.txt": zf.read(PREFIX + "README.txt"),
        }
        manifest = json.loads(zf.read(PREFIX + "manifest.json"))
        catalog = json.loads(metadata["catalog.json"])
        cards = json.loads(metadata["cards.json"])
        art_files = {
            PREFIX + "art/%s/%s" % (row["set"], image.name)
            for image, row, _variant in art_targets(Path("unused"), cards)
        }
        new_names = {name for group in MISSING.values() for name in group}
        art_files.update(
            "skin/cardart/" + image.name
            for image, row, _variant in art_targets(Path("unused"), cards)
            if row["name"] in new_names)
        accepted = names == metadata_files or names == metadata_files | art_files
        if not accepted or (require_art and names != metadata_files | art_files):
            raise ValueError("unexpected ZIP entries: %s" % sorted(names))
        for name in names:
            if "\\" in name or ".." in Path(name).parts or not (
                    name.startswith(PREFIX) or name.startswith("skin/cardart/")):
                raise ValueError("unsafe ZIP entry: %s" % name)
        checksums = manifest.get("checksums", {})
        if checksums.get("algorithm") != "sha256" \
                or checksums.get("metadata") != {
                    name: sha256(payload)
                    for name, payload in sorted(metadata.items())}:
            raise ValueError("Pack 1 metadata checksum failed")
        # THE TRUSTED SOURCE, as Packs 2-9 read it (hunt 2026-10-21): the
        # checksums above are the zip's own, so a forged cards.json with
        # its checksum recomputed passed every one of them.
        _manifest, trusted_catalog, trusted_cards, trusted_readme = assembled()
        trusted = {"catalog.json": json_bytes(trusted_catalog),
                   "cards.json": json_bytes(trusted_cards),
                   "README.txt": trusted_readme.encode("utf-8")}
        for name, payload in trusted.items():
            if metadata[name] != payload:
                raise ValueError("Pack 1 metadata differs from the trusted source: " + name)
        art_entries = [(name, zf.read(name)) for name in sorted(art_files & names)]
        artwork = checksums.get("artwork", {})
        if artwork.get("files") != len(art_entries) \
                or artwork.get("sha256") != artwork_sha256(art_entries):
            raise ValueError("Pack 1 artwork checksum failed")
    if manifest.get("file_name") != FILE_NAME or manifest.get("id") != "pack-1":
        raise ValueError("wrong Pack 1 manifest")
    if manifest.get("version") != PACK_VERSION \
            or manifest.get("minimum_game_version") != MINIMUM_GAME_VERSION:
        raise ValueError("wrong Pack 1 compatibility fields")
    if manifest.get("counts") != EXPECTED or catalog.get("counts") != EXPECTED:
        raise ValueError("Pack 1 count contract failed")
    if catalog.get("pack_id") != "pack-1" \
            or set(catalog.get("sets", {})) != set(SET_ORDER):
        raise ValueError("Pack 1 catalog contract failed")
    if manifest.get("new_rules_identities") != [
            name for code in SET_ORDER for name in MISSING.get(code, [])]:
        raise ValueError("Pack 1 new identity contract failed")
    catalog_pairs: set[tuple[str, str]] = set()
    distinct: set[str] = set()
    for code, expected in EXPECTED_SETS.items():
        one = catalog["sets"].get(code, {})
        set_names = one.get("names", [])
        if not isinstance(set_names, list) or len(set_names) != expected[0] \
                or len(set(set_names)) != expected[0] \
                or one.get("named_cards") != expected[0] \
                or one.get("published_printings") != expected[1]:
            raise ValueError("Pack 1 %s checklist contract failed" % code)
        distinct.update(set_names)
        catalog_pairs.update((code, name) for name in set_names)
    if len(catalog_pairs) != 1270 or len(distinct) != 901:
        raise ValueError("Pack 1 catalog totals failed")
    pairs = {(row.get("set"), row.get("name")) for row in cards}
    wanted = {name for names in MISSING.values() for name in names}
    if len(cards) != 373 or len(pairs) != 373 \
            or not pairs.issubset(catalog_pairs) \
            or not wanted.issubset({row.get("name") for row in cards}):
        raise ValueError("Pack 1 additions contract failed")
    return manifest


def fetch() -> None:
    rows: list[dict] = []
    for code in SET_ORDER:
        for name in MISSING.get(code, []):
            url = "https://api.scryfall.com/cards/named?" + urllib.parse.urlencode(
                {"exact": name, "set": code})
            row = fetch_cards.trim(fetch_cards.scryfall_get(url), code)
            row.pop("printed_in", None)
            rows.append(row)
            print("fetched: %s (%s)" % (name, code))
    (SOURCE / "missing_cards.json").write_text(
        json.dumps(rows, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("data: %s" % (SOURCE / "missing_cards.json"))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog=TOOL, description=__doc__.split("\n\n")[0],
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=("Commands:\n"
                "  build    build the deterministic ZIP (default)\n"
                "  fetch    refresh only Pack 1's four card records from Scryfall\n"
                "  fetch-art fetch Pack 1's 746 set-specific images from Scryfall\n"
                "  verify   verify the exact file, layout, names, and counts\n\n"
                + "\n".join(HINT) + "\n\n" + tool_banner.BANNER_HELP))
    tool_banner.add_version_flag(parser, TOOL, __file__)
    parser.add_argument("command", nargs="?", default="build",
                        choices=("build", "fetch", "fetch-art", "verify"))
    parser.add_argument("path", nargs="?", type=Path,
                        help="output/input ZIP (default: %(default)s)",
                        default=DEFAULT_OUT)
    parser.add_argument("--art-dir", type=Path, default=DEFAULT_ART,
                        help="Pack-1-only art cache (default: %(default)s)")
    parser.add_argument("--metadata-only", action="store_true",
                        help=argparse.SUPPRESS)
    args = parser.parse_args(argv)
    tool_banner.show(WORDMARK, CAPTION, __file__, hint=HINT, argv=argv)
    try:
        if args.command == "fetch":
            fetch()
        elif args.command == "fetch-art":
            fetch_art(args.art_dir)
        elif args.command == "verify":
            report = verify(args.path, require_art=not args.metadata_only)
            print("ok: %s" % args.path)
            print("Pack 1: %(pack_card_entries)d card entries · %(reprint_entries)d reprints · "
                  "%(new_rules_identities)d new rules identities" % report["counts"])
            print("cards: %(distinct_cards)d distinct · %(named_set_entries)d named set "
                  "entries · %(published_printings)d published printings" % report["counts"])
        else:
            build(args.path, args.art_dir, include_art=not args.metadata_only)
    except (OSError, ValueError, json.JSONDecodeError, zipfile.BadZipFile) as exc:
        print("%s: %s" % (TOOL, exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

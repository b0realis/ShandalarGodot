#!/usr/bin/env python3
"""Self-test for tools/build_card_packs.py — no network, no real dirs.

Run from the repo root:
    python3 -m unittest discover -s tools -p 'test_*.py'

Everything runs against a fixture pool in a temp dir: two tiny sets that
share a reprint, an accented name (the naming quirk that hid eight Arabian
Nights pictures from the game), duplicate basic lands, a gold card, and one
card with no art — built --offline so the missing-report path is exercised
too.
"""

import contextlib
import io
import json
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_card_packs as bcp  # noqa: E402
import fetch_card_art  # noqa: E402


def card(name, rarity, type_line, colors, number, artist="A. Artist", **extra):
    rec = {"name": name, "mana_cost": extra.pop("mana_cost", "{1}"),
           "type_line": type_line, "oracle_text": "", "power": None,
           "toughness": None, "keywords": [], "colors": colors,
           "rarity": rarity, "collector_number": number, "artist": artist}
    rec.update(extra)
    return rec


TST = [
    card("Plains", "common", "Basic Land — Plains", [], "1", set="tst"),
    card("Plains", "common", "Basic Land — Plains", [], "2", set="tst"),
    card("Giant Growth", "common", "Instant", ["G"], "3", set="tst"),
    card("Dandân", "rare", "Creature — Fish", ["U"], "4", set="tst"),
    card("Sol Ring", "uncommon", "Artifact", [], "5", set="tst"),
    card("Mishra's Factory", "uncommon", "Land", [], "6", set="tst"),
    card("Ring of Ma'rûf", "rare", "Artifact", [], "7", set="tst"),
]
REP = [
    card("Giant Growth", "uncommon", "Instant", ["G"], "1", set="rep"),
    card("Serra Angel", "uncommon", "Creature — Angel", ["W"], "2", set="rep"),
    card("Arcades Sabboth", "rare", "Legendary Creature — Elder Dragon",
         ["G", "W", "U"], "3", set="rep"),
]
# Names with art in the fixture (Serra Angel has none). Dandân is stored
# under the PRE-FIX spelling to prove the builder still finds it.
ART_STEMS = ["plains", "giant_growth", "sol_ring", "mishra_s_factory",
             "ring_of_ma_r_f", "arcades_sabboth", "dandân"]


class Fixture:
    """A fake repo: cards/data, assets/cardart, and a packs dir."""

    def __init__(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.data = root / "data"
        self.art = root / "cardart"
        self.out = root / "packs"
        self.data.mkdir()
        self.art.mkdir()
        (self.data / "tst.json").write_text(json.dumps(TST), encoding="utf-8")
        (self.data / "rep.json").write_text(json.dumps(REP), encoding="utf-8")
        for stem in ART_STEMS:
            (self.art / f"{stem}.jpg").write_bytes(b"\xff\xd8art")
            (self.art / f"{stem}_card.jpg").write_bytes(b"\xff\xd8card")
        self.saved = (bcp.DATA_DIR, bcp.ART_DIR, bcp.BUNDLE_MEMBERS,
                      fetch_card_art.DATA_DIR, fetch_card_art.OUT_DIR)
        bcp.DATA_DIR = self.data
        bcp.ART_DIR = self.art
        bcp.BUNDLE_MEMBERS = ["tst", "rep"]
        fetch_card_art.DATA_DIR = self.data
        fetch_card_art.OUT_DIR = self.art
        bcp._FETCHED_FOR.clear()

    def close(self):
        (bcp.DATA_DIR, bcp.ART_DIR, bcp.BUNDLE_MEMBERS,
         fetch_card_art.DATA_DIR, fetch_card_art.OUT_DIR) = self.saved
        bcp._FETCHED_FOR.clear()
        self.tmp.cleanup()


class NamingTest(unittest.TestCase):
    def test_snake_matches_the_games_key(self):
        # GameSkin._snake: ASCII-only, runs of anything else -> one "_".
        self.assertEqual(bcp.snake("Mishra's Factory"), "mishra_s_factory")
        self.assertEqual(bcp.snake("Dandân"), "dand_n")
        self.assertEqual(bcp.snake("Ring of Ma'rûf"), "ring_of_ma_r_f")
        self.assertEqual(bcp.snake("El-Hajjâj"), "el_hajj_j")
        self.assertEqual(bcp.snake("Ali from Cairo"), "ali_from_cairo")

    def test_legacy_spelling_is_the_old_isalnum_rule(self):
        self.assertEqual(fetch_card_art.legacy_snake("Dandân"), "dandân")
        self.assertEqual(fetch_card_art.legacy_snake("Sol Ring"), "sol_ring")


class ListsTest(unittest.TestCase):
    def test_cards_txt_is_unique_names_in_collector_order(self):
        lists = bcp.build_lists(TST)
        self.assertEqual(lists["cards.txt"].splitlines(),
                         ["Plains", "Giant Growth", "Dandân", "Sol Ring",
                          "Mishra's Factory", "Ring of Ma'rûf"])

    def test_rarity_lists_exclude_basics_which_go_to_lands(self):
        lists = bcp.build_lists(TST)
        self.assertEqual(lists["common.txt"].splitlines(), ["Giant Growth"])
        self.assertEqual(lists["uncommon.txt"].splitlines(),
                         ["Sol Ring", "Mishra's Factory"])
        self.assertEqual(lists["rare.txt"].splitlines(), ["Dandân", "Ring of Ma'rûf"])
        self.assertEqual(lists["lands.txt"].splitlines(), ["Plains"])
        self.assertNotIn("mythic.txt", lists)

    def test_by_color_groups(self):
        lists = bcp.build_lists(TST + REP)
        self.assertEqual(lists["by_color/green.txt"].splitlines(), ["Giant Growth"])
        self.assertEqual(lists["by_color/artifact.txt"].splitlines(),
                         ["Sol Ring", "Ring of Ma'rûf"])
        self.assertEqual(lists["by_color/land.txt"].splitlines(),
                         ["Plains", "Mishra's Factory"])
        self.assertEqual(lists["by_color/multicolor.txt"].splitlines(), ["Arcades Sabboth"])
        self.assertNotIn("by_color/colorless.txt", lists)

    def test_printings_tsv_keeps_every_printing(self):
        rows = bcp.build_lists(TST)["printings.tsv"].splitlines()
        self.assertEqual(rows[0], "collector_number\tname\trarity\tartist\tset")
        self.assertEqual(len(rows), 1 + len(TST))
        self.assertEqual(rows[1], "1\tPlains\tcommon\tA. Artist\ttst")

    def test_rarity_counts_count_names_not_printings(self):
        self.assertEqual(bcp.rarity_counts(TST),
                         {"basic_land": 1, "common": 1, "rare": 2, "uncommon": 2})


class MergeTest(unittest.TestCase):
    def test_first_set_in_pool_order_wins(self):
        merged = bcp.merge_pool({"tst": TST, "rep": REP}, ["tst", "rep"])
        names = [c["name"] for c in merged]
        self.assertEqual(len(names), len(set(names)))
        self.assertEqual(len(merged), 8)   # 6 tst names + 2 new rep names
        growth = next(c for c in merged if c["name"] == "Giant Growth")
        self.assertEqual((growth["set"], growth["rarity"]), ("tst", "common"))
        # order flips the winner, exactly like gen_cards.POOL would
        merged = bcp.merge_pool({"tst": TST, "rep": REP}, ["rep", "tst"])
        growth = next(c for c in merged if c["name"] == "Giant Growth")
        self.assertEqual((growth["set"], growth["rarity"]), ("rep", "uncommon"))


class EnrichTest(unittest.TestCase):
    RAW = [{"name": "Giant Growth", "collector_number": "3", "id": "id-gg",
            "cmc": 1.0, "color_identity": ["G"], "flavor_text": "Big.",
            "image_uris": {"art_crop": "u", "border_crop": "v"},
            "legalities": {"vintage": "legal", "commander": "legal", "oldschool": "legal"}},
           {"name": "Plains", "collector_number": "1", "id": "id-p1", "cmc": 0.0,
            "legalities": {}}]

    def test_records_gain_scryfall_keys_and_keep_their_shape(self):
        out, unmatched = bcp.enrich(TST, self.RAW)
        self.assertEqual(len(out), len(TST))
        self.assertEqual([c["name"] for c in out], [c["name"] for c in TST])
        gg = out[2]
        self.assertEqual(gg["scryfall_id"], "id-gg")
        self.assertEqual(gg["cmc"], 1.0)
        self.assertEqual(gg["legalities"], {"vintage": "legal", "oldschool": "legal"})
        self.assertNotIn("id", gg)
        for key in ("name", "mana_cost", "rarity", "collector_number", "artist", "set"):
            self.assertEqual(gg[key], TST[2][key])
        # Plains #2 has no exact match -> falls back to the name's first printing
        self.assertEqual(out[1]["scryfall_id"], "id-p1")
        self.assertEqual(unmatched, 4)   # Dandân, Sol Ring, Factory, Ring
        self.assertNotIn("scryfall_id", out[3])

    def test_no_listing_means_untouched_copies(self):
        out, unmatched = bcp.enrich(TST, None)
        self.assertEqual(out, TST)
        self.assertEqual(unmatched, len(TST))


class OfflineBuildTest(unittest.TestCase):
    """The whole builder, --offline, against the fixture."""

    @classmethod
    def setUpClass(cls):
        cls.fx = Fixture()
        cls.log = io.StringIO()
        with contextlib.redirect_stdout(cls.log):   # the builder's progress lines
            cls.rc = bcp.build(cls.fx.out, ["tst", "rep"], bundle=True, offline=True,
                               force=False, max_fetch=300)

    @classmethod
    def tearDownClass(cls):
        cls.fx.close()

    def members(self, archive):
        with tarfile.open(self.fx.out / archive) as tar:
            return {m.name: m for m in tar.getmembers()}

    def read(self, archive, member):
        with tarfile.open(self.fx.out / archive) as tar:
            return tar.extractfile(member).read()

    def test_offline_with_no_cache_reports_and_fails(self):
        self.assertEqual(self.rc, 1)
        self.assertIn("MISSING / INCOMPLETE:", self.log.getvalue())
        self.assertIn("rep: art: 2 files for 1 cards not fetched (offline)", self.log.getvalue())
        manifest = json.loads(self.read("tst.tar.gz", "tst/set.json"))
        self.assertEqual(manifest["incomplete"],
                         ["set object tst", "card listing tst", "icon tst (no icon_svg_uri)"])
        self.assertIsNone(manifest["name"])
        self.assertEqual(manifest["cards_json"]["records_without_enrichment"], len(TST))
        rep = json.loads(self.read("rep.tar.gz", "rep/set.json"))
        self.assertIn("art: 2 files for 1 cards not fetched (offline)", rep["incomplete"])
        self.assertEqual(rep["art"]["cards_missing_art"], ["Serra Angel"])
        self.assertEqual(rep["art"]["cards_with_art"], 2)

    def test_set_pack_layout(self):
        names = set(self.members("tst.tar.gz"))
        for rel in ["", "set.json", "cards.json", "cards.txt", "printings.tsv",
                    "common.txt", "uncommon.txt", "rare.txt", "lands.txt",
                    "by_color/artifact.txt", "README.txt", "art/index.json"]:
            self.assertIn(("tst/" + rel).rstrip("/"), names, rel)
        self.assertNotIn("tst/icon.svg", names)   # nothing fetched offline
        self.assertEqual(len([n for n in names if n.startswith("tst/art/") and n.endswith(".jpg")]),
                         2 * 6)

    def test_art_is_named_the_way_the_game_looks_it_up(self):
        names = set(self.members("tst.tar.gz"))
        self.assertIn("tst/art/dand_n.jpg", names)
        self.assertIn("tst/art/dand_n_card.jpg", names)
        self.assertNotIn("tst/art/dandân.jpg", names)
        self.assertIn("tst/art/ring_of_ma_r_f.jpg", names)
        self.assertEqual(self.read("tst.tar.gz", "tst/art/dand_n.jpg"), b"\xff\xd8art")
        index = json.loads(self.read("tst.tar.gz", "tst/art/index.json"))
        row = next(r for r in index if r["name"] == "Dandân")
        self.assertEqual((row["art_crop"], row["border_crop"], row["art_fetched_for"]),
                         ("dand_n.jpg", "dand_n_card.jpg", "tst"))

    def test_cards_json_keeps_the_data_file_shape(self):
        cards = json.loads(self.read("tst.tar.gz", "tst/cards.json"))
        self.assertEqual(cards, TST)   # offline, no listing: verbatim

    def test_bundle_merges_dedupes_and_nests_members_without_art(self):
        names = set(self.members("dotp-1997.tar.gz"))
        manifest = json.loads(self.read("dotp-1997.tar.gz", "dotp-1997/set.json"))
        self.assertEqual(manifest["kind"], "bundle")
        self.assertEqual(manifest["members"], ["tst", "rep"])
        self.assertEqual(manifest["card_count"], 8)
        self.assertEqual(manifest["printings"], len(TST) + len(REP))
        cards = json.loads(self.read("dotp-1997.tar.gz", "dotp-1997/cards.json"))
        self.assertEqual(len(cards), 8)
        self.assertEqual([c["name"] for c in cards].count("Giant Growth"), 1)
        for code in ("tst", "rep"):
            self.assertIn(f"dotp-1997/sets/{code}/set.json", names)
            self.assertIn(f"dotp-1997/sets/{code}/cards.json", names)
            self.assertIn(f"dotp-1997/sets/{code}/cards.txt", names)
            self.assertFalse([n for n in names if n.startswith(f"dotp-1997/sets/{code}/art")])
        art = [n for n in names if n.startswith("dotp-1997/art/") and n.endswith(".jpg")]
        self.assertEqual(len(art), 2 * 7)   # 8 names, Serra Angel has none
        self.assertIn("dotp-1997/art/giant_growth.jpg", art)
        member = json.loads(self.read("dotp-1997.tar.gz", "dotp-1997/sets/rep/set.json"))
        self.assertEqual(member["art"]["dir"], "../../art")

    def test_index_json_lists_every_archive_with_its_hash(self):
        index = json.loads((self.fx.out / "index.json").read_text(encoding="utf-8"))
        rows = {r["file"]: r for r in index["packs"]}
        self.assertEqual(set(rows), {"tst.tar.gz", "rep.tar.gz", "dotp-1997.tar.gz"})
        self.assertEqual(rows["dotp-1997.tar.gz"]["cards"], 8)
        self.assertEqual(rows["tst.tar.gz"]["art_files"], 12)
        self.assertEqual(rows["rep.tar.gz"]["cards_missing_art"], 1)
        for row in rows.values():
            self.assertEqual(row["sha256"], bcp.sha256_of(self.fx.out / row["file"]))
            self.assertEqual(row["size"], (self.fx.out / row["file"]).stat().st_size)
        # kind "set" rows first, then the bundle
        self.assertEqual([r["kind"] for r in index["packs"]], ["set", "set", "bundle"])

    def test_index_drops_archives_that_are_gone(self):
        index_file = self.fx.out / "index.json"
        before = index_file.read_text(encoding="utf-8")
        (self.fx.out / "rep.tar.gz").rename(self.fx.out / "rep.gone")
        try:
            bcp.update_index(self.fx.out, [])
            index = json.loads(index_file.read_text(encoding="utf-8"))
            self.assertNotIn("rep.tar.gz", [r["file"] for r in index["packs"]])
            self.assertIn("tst.tar.gz", [r["file"] for r in index["packs"]])
        finally:
            (self.fx.out / "rep.gone").rename(self.fx.out / "rep.tar.gz")
            index_file.write_text(before, encoding="utf-8")

    def test_no_stage_or_partial_files_are_left(self):
        left = [p.name for p in self.fx.out.iterdir()
                if p.name.startswith(".stage") or p.name.endswith(".partial")]
        self.assertEqual(left, [])
        self.assertFalse((self.fx.out / "cache").exists())   # offline never writes it


if __name__ == "__main__":
    unittest.main()

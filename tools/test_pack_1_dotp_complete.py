#!/usr/bin/env python3
"""Regression tests for the dedicated Pack 1 builder."""

from __future__ import annotations

import tempfile
import json
import unittest.mock
import shutil
import unittest
import warnings
import zipfile
from pathlib import Path

import pack_1_dotp_complete as pack


class PackOneTests(unittest.TestCase):
    def test_portable_base_assignments_without_game_scripts(self):
        expected = pack.assigned_pairs()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            shutil.copytree(pack.BASE_DATA, root / 'cards/data')
            snapshot = root / 'packaging/card_packs/pack_1_dotp_complete/base_assignments.json'
            snapshot.parent.mkdir(parents=True)
            snapshot.write_text(json.dumps(sorted(expected)), encoding='utf-8')
            self.assertEqual(pack.assigned_pairs(root), expected)
            self.assertFalse((root / 'cards/sets').exists())
            for bad in ([], sorted(expected) + [sorted(expected)[0]],
                        [['2ed', 'not a real card']] + sorted(expected)[1:]):
                snapshot.write_text(json.dumps(bad), encoding='utf-8')
                with self.assertRaises(ValueError):
                    pack.assigned_pairs(root)

    def test_assembled_counts_and_complete_set_membership(self):
        manifest, catalog, cards, _readme = pack.assembled()
        self.assertEqual(manifest["counts"], pack.EXPECTED)
        self.assertEqual(manifest["version"], pack.PACK_VERSION)
        self.assertEqual(manifest["minimum_game_version"],
                         pack.MINIMUM_GAME_VERSION)
        self.assertEqual(catalog["sets"]["2ed"]["named_cards"], 292)
        self.assertEqual(catalog["sets"]["4ed"]["named_cards"], 368)
        self.assertEqual(catalog["sets"]["arn"]["named_cards"], 78)
        self.assertEqual(catalog["sets"]["atq"]["named_cards"], 85)
        self.assertEqual(catalog["sets"]["leg"]["named_cards"], 310)
        self.assertEqual(catalog["sets"]["drk"]["named_cards"], 119)
        self.assertEqual(len(cards), 373)
        self.assertEqual(len({(row["set"], row["name"]) for row in cards}), 373)
        self.assertEqual(len(pack.art_targets(Path("unused"), cards)), 746)
        self.assertTrue({"Chaos Orb", "Word of Command", "Shahrazad", "Falling Star"}
                        .issubset({row["name"] for row in cards}))

    def test_build_is_deterministic_and_verifies(self):
        with tempfile.TemporaryDirectory() as tmp:
            first = Path(tmp) / pack.FILE_NAME
            second = Path(tmp) / "again" / pack.FILE_NAME
            art = Path(tmp) / "art"
            art.mkdir()
            for path, _row, _variant in pack.art_targets(art):
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b"\xff\xd8Pack One test image\xff\xd9")
            pack.build(first, art)
            pack.build(second, art)
            self.assertEqual(first.read_bytes(), second.read_bytes())
            self.assertEqual(pack.verify(first)["counts"], pack.EXPECTED)
            report = pack.verify(first)
            self.assertEqual(report["checksums"]["artwork"]["files"], 754)
            self.assertEqual(len(report["checksums"]["artwork"]["sha256"]), 64)
            self.assertEqual(set(report["checksums"]["metadata"]),
                             {"catalog.json", "cards.json", "README.txt"})
            with zipfile.ZipFile(first) as built:
                names = built.namelist()
            self.assertEqual(len(names), 758)
            self.assertEqual(sum(name.startswith(pack.PREFIX + "art/")
                                 for name in names), 746)
            self.assertEqual(sum(name.startswith("skin/cardart/")
                                 for name in names), 8)

    def test_verify_rejects_wrong_name_and_extra_entry(self):
        with tempfile.TemporaryDirectory() as tmp:
            good = Path(tmp) / pack.FILE_NAME
            pack.build(good, include_art=False)
            wrong = Path(tmp) / "wrong.zip"
            wrong.write_bytes(good.read_bytes())
            with self.assertRaisesRegex(ValueError, "named exactly"):
                pack.verify(wrong, require_art=False)
            with zipfile.ZipFile(good, "a") as zf:
                zf.writestr("outside.txt", "no")
            with self.assertRaisesRegex(ValueError, "unexpected ZIP entries"):
                pack.verify(good, require_art=False)

    def test_verify_rejects_a_duplicate_entry(self):
        # `zipfile` resolves a repeated name to the LAST entry; a reader
        # that walks the central directory in order (Godot's ZIPReader)
        # takes the FIRST. So a forged copy appended BEFORE the genuine
        # one passed every checksum here while being what the game read.
        with tempfile.TemporaryDirectory() as tmp:
            good = Path(tmp) / pack.FILE_NAME
            pack.build(good, include_art=False)
            with zipfile.ZipFile(good) as source:
                entries = [(info.filename, source.read(info.filename))
                           for info in source.infolist()]
            forged = Path(tmp) / "forged" / pack.FILE_NAME
            forged.parent.mkdir()
            target = pack.PREFIX + "cards.json"
            # The duplicate is the point; zipfile's "Duplicate name" warning
            # is not news in every gate log (packs 2-5 quiet it the same way).
            with warnings.catch_warnings(), zipfile.ZipFile(forged, "w") as out:
                warnings.simplefilter("ignore", UserWarning)
                for name, payload in entries:
                    if name == target:
                        pack.write_entry(out, name, b'[{"name": "Evil", "set": "2ed"}]')
                    pack.write_entry(out, name, payload)
            with zipfile.ZipFile(forged) as built:
                self.assertEqual(len(built.namelist()), len(entries) + 1)
            with self.assertRaisesRegex(ValueError, "duplicate"):
                pack.verify(forged, require_art=False)

    def test_a_failed_build_leaves_the_previous_pack_untouched(self):
        # Pack 1 used to write straight to the target: one raise while the
        # entries were going in (a full disk is the ordinary way) truncated
        # a verified pack to an unreadable stub, and rebuilding it means
        # fetching 746 images again. Packs 2-5 already staged and replaced.
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / pack.FILE_NAME
            pack.build(out, include_art=False)
            before = out.read_bytes()
            calls = []
            real = pack.write_entry

            def failing(zf, name, payload):
                calls.append(name)
                if len(calls) == 3:
                    raise OSError("No space left on device")
                real(zf, name, payload)

            with unittest.mock.patch.object(pack, "write_entry", failing):
                with self.assertRaises(OSError):
                    pack.build(out, include_art=False)
            self.assertEqual(out.read_bytes(), before)
            self.assertEqual(pack.verify(out, require_art=False)["counts"],
                             pack.EXPECTED)
            self.assertEqual([p.name for p in out.parent.iterdir()],
                             [pack.FILE_NAME])

    def test_build_refuses_a_wrong_output_name_before_writing_anything(self):
        with tempfile.TemporaryDirectory() as tmp:
            wrong = Path(tmp) / "my-pack.zip"
            with self.assertRaisesRegex(ValueError, "named exactly"):
                pack.build(wrong, include_art=False)
            self.assertEqual(list(Path(tmp).iterdir()), [])

    def test_verify_rejects_metadata_forged_with_fresh_checksums(self):
        # HUNT 2026-10-21: Pack 1 compared cards.json only with the
        # checksums in the zip's own manifest, so a changed card whose
        # checksums were recomputed passed `verify` — Packs 2-9 compare
        # with the trusted source and refuse it.
        with tempfile.TemporaryDirectory() as tmp:
            good = Path(tmp) / pack.FILE_NAME
            pack.build(good, include_art=False)
            with zipfile.ZipFile(good) as source:
                entries = {info.filename: source.read(info.filename) for info in source.infolist()}
            cards = json.loads(entries[pack.PREFIX + "cards.json"])
            for row in cards:
                if row.get("name") == "Chaos Orb":
                    row["oracle_text"] = "You win the game."
            entries[pack.PREFIX + "cards.json"] = pack.json_bytes(cards)
            manifest = json.loads(entries[pack.PREFIX + "manifest.json"])
            manifest["checksums"]["metadata"]["cards.json"] = pack.sha256(entries[pack.PREFIX + "cards.json"])
            entries[pack.PREFIX + "manifest.json"] = pack.json_bytes(manifest)
            with zipfile.ZipFile(good, "w") as out:
                for name, payload in entries.items():
                    out.writestr(name, payload)
            with self.assertRaisesRegex(ValueError, "trusted source"):
                pack.verify(good, require_art=False)

    def test_verify_rejects_tampered_metadata(self):
        with tempfile.TemporaryDirectory() as tmp:
            good = Path(tmp) / pack.FILE_NAME
            pack.build(good, include_art=False)
            changed = Path(tmp) / "changed.zip"
            with zipfile.ZipFile(good) as source, zipfile.ZipFile(changed, "w") as out:
                for info in source.infolist():
                    payload = source.read(info.filename)
                    if info.filename == pack.PREFIX + "README.txt":
                        payload = b"changed"
                    out.writestr(info, payload)
            changed.replace(good)
            with self.assertRaisesRegex(ValueError, "checksum|unexpected ZIP"):
                pack.verify(good, require_art=False)


if __name__ == "__main__":
    unittest.main()

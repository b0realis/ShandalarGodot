#!/usr/bin/env python3
"""tools/adventure_plugin.py — the adventure plugins' authoring tool and its
validator twin of the game's own loader.

THE CORPUS (tools/plugin_fixtures/expected.json) is the meeting point: every
case is built here from its recipe exactly as tests/unit/test_plugin_corpus.gd
builds it for the game, and both must reach the verdict and the first reason
the file gives. So the two validators agree case for case, and neither can
drift alone.

THE TWINS: the manifest rules, the package's limits, the reserved flags, the
engine's default texts, the palettes and the faces live in the game's
GDScript, not in schema_v1.json; the tool carries copies, and DriftTest reads
the .gd sources and fails the moment one copy stops matching.

No Godot, no network. Run from the repo root:
    python3 -m unittest discover -s tools -p 'test_adventure_plugin.py'

Also exercise the game's parser in a compiled PCK (no export templates
needed): set SHANDALAR_PLUGIN_EXPORT_GODOT to the Godot editor binary.
"""
from __future__ import annotations

import ast
import contextlib
import hashlib
import io
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
import zipfile
import zlib
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent
sys.path.insert(0, str(TOOLS))
import adventure_plugin as ap  # noqa: E402

FIXTURES = TOOLS / "plugin_fixtures"
EXPECTED = FIXTURES / "expected.json"
SCRIPT = TOOLS / "adventure_plugin.py"
PROTOTYPE = ROOT / "expanded_adventure" / "Fallen_Empires_Refuge_prototype"
## The two sites plugins the game ships (API 2); their pictures may be
## missing from a checkout while they are painted, so the tests that play
## them lay small stand-ins of the same names over a copy.
SHIPPED_SITES = {"Old_Adventurers_Hut": "old_hut", "Conjuration_Wizard_Guild": "conjuration_guild"}
# The hut's five dungeons, in the order the old man sells them.
HUT_CHAIN = ["forgotten_vault", "drowned_library", "sunken_forge", "hall_of_echoes", "planeswalkers_rest"]


def run_tool(*args: str, cwd: Path | None = None, tool: Path = SCRIPT) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, "-I", str(tool), *args], capture_output=True, text=True,
                          encoding="utf-8", timeout=300, cwd=str(cwd) if cwd else None)


# --------------------------------------------------------------------------
# THE CORPUS BUILDER — the same steps as tests/unit/test_plugin_corpus.gd
# --------------------------------------------------------------------------

def expand(value):
    """A recipe value: {$repeat: [text, n]}, {$list: [value, n]}, {$nest: n}."""
    if isinstance(value, dict) and len(value) == 1:
        key = next(iter(value))
        if key == "$repeat":
            return value[key][0] * int(value[key][1])
        if key == "$list":
            return [expand(value[key][0]) for _ in range(int(value[key][1]))]
        if key == "$nest":
            out: list = []
            for _ in range(int(value[key]) - 1):
                out = [out]
            return out
    if isinstance(value, dict):
        return {k: expand(v) for k, v in value.items()}
    if isinstance(value, list):
        return [expand(v) for v in value]
    return value


def _set(data, path: list, value) -> None:
    for key in path[:-1]:
        data = data[int(key)] if isinstance(data, list) else data[key]
    last = path[-1]
    if isinstance(data, list):
        if int(last) == len(data):
            data.append(value)
        else:
            data[int(last)] = value
    else:
        data[last] = value


def _remove(data, path: list) -> None:
    for key in path[:-1]:
        data = data[int(key)] if isinstance(data, list) else data[key]
    if isinstance(data, list):
        data.pop(int(path[-1]))
    else:
        del data[path[-1]]


def png_header(width: int, height: int) -> bytes:
    def chunk(kind: bytes, body: bytes) -> bytes:
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)) + chunk(b"IEND", b"")


def _items(items: list):
    for item in items:
        count = item.get("count")
        if count is None:
            yield item
            continue
        for n in range(int(count)):
            yield {k: (v.replace("{n}", str(n)) if isinstance(v, str) and k in ("rel", "name") else v)
                   for k, v in item.items() if k != "count"}


def _add(folder: Path, items: list) -> None:
    for item in _items(items):
        target = folder / item["rel"]
        target.parent.mkdir(parents=True, exist_ok=True)
        if "prefix_hex" in item:
            target.write_bytes(bytes.fromhex(item["prefix_hex"]) + target.read_bytes())
        elif "append" in item:
            target.write_bytes(target.read_bytes() + item["append"].encode("utf-8"))
        elif item.get("delete"):
            target.unlink()
        elif "link" in item:
            os.symlink(item["link"], target)
        elif "dirs" in item:
            target.mkdir(parents=True, exist_ok=True)
        elif "png" in item:
            target.write_bytes(png_header(*item["png"]))
        elif "repeat" in item:
            target.write_bytes((item["repeat"][0] * int(item["repeat"][1])).encode("utf-8"))
        elif "hex" in item:
            target.write_bytes(bytes.fromhex(item["hex"]))
        else:
            target.write_bytes(item["text"].encode("utf-8"))


def files_of(folder: Path, under: str = "") -> list:
    """tests/support/plugin_zips.gd files_of: each folder's files by name,
    then its folders, hidden names left out (DirAccess's default)."""
    here = folder / under if under else folder
    names = sorted(os.listdir(here))
    out = [(under + "/" + n if under else n) for n in names
           if not n.startswith(".") and not (here / n).is_dir()]
    for name in names:
        if not name.startswith(".") and (here / name).is_dir():
            out += files_of(folder, under + "/" + name if under else name)
    return out


def raw_zip(entries: list) -> bytes:
    """Stored entries, byte for byte as the GDScript side writes them:
    {name (bytes), data, method, flags, made_by, external, size}."""
    out, central = bytearray(), bytearray()
    for entry in entries:
        name, data = entry["name"], entry["data"]
        claimed = entry.get("size")
        size = len(data) if claimed is None else claimed
        crc = zlib.crc32(data) & 0xFFFFFFFF if claimed is None else 0
        offset = len(out)
        out += struct.pack("<IHHHHHIIIHH", 0x04034B50, 20, entry.get("flags", 0), entry.get("method", 0), 0, 0, crc,
                           len(data), size, len(name), 0) + name + data
        central += struct.pack("<IHHHHHHIIIHHHHHII", 0x02014B50, entry.get("made_by", 0x0014), 20,
                               entry.get("flags", 0), entry.get("method", 0), 0, 0, crc, len(data), size, len(name),
                               0, 0, 0, 0, entry.get("external", 0), offset) + name
    at = len(out)
    out += central
    out += struct.pack("<IHHHHIIH", 0x06054B50, 0, 0, len(entries), len(entries), len(central), at, 0)
    return bytes(out)


def zip64(data: bytes) -> bytes:
    """The zip with zip64 end records: its classic end record's counts and
    offset set to the 'see zip64' marks."""
    count = struct.unpack_from("<H", data, len(data) - 12)[0]
    size, offset = struct.unpack_from("<II", data, len(data) - 10)
    body = data[:-22]
    record_at = len(body)
    record = struct.pack("<IQHHIIQQQQ", 0x06064B50, 44, 45, 45, 0, 0, count, count, size, offset)
    locator = struct.pack("<IIQI", 0x07064B50, 0, record_at, 1)
    end = struct.pack("<IHHHHIIH", 0x06054B50, 0, 0, 0xFFFF, 0xFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0)
    return body + record + locator + end


def build_case(case: dict, work: Path, top: str) -> Path:
    """The plugin [case] describes, under [work]: its path (a folder or a zip)."""
    staging = work / "staging" / case["name"]
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir(parents=True)
    for layer in (case.get("base"), case.get("folder")):
        if layer:
            shutil.copytree(FIXTURES / layer, staging, dirs_exist_ok=True)
    for rel, change in case.get("edit", {}).items():
        data = json.loads((staging / rel).read_text(encoding="utf-8"))
        for step in change.get("set", []):
            _set(data, step["path"], expand(step["value"]))
        for path in change.get("remove", []):
            _remove(data, path)
        (staging / rel).write_text(json.dumps(data, indent="\t", ensure_ascii=False) + "\n", encoding="utf-8")
    _add(staging, case.get("add", []))
    for rel in case.get("remove", []):
        (staging / rel).unlink()
    if case.get("hash_files"):
        files = ap.read_package(str(staging))["files"]
        manifest = json.loads((staging / ap.MANIFEST).read_text(encoding="utf-8"))
        manifest["files"] = {rel: hashlib.sha256(files[rel]).hexdigest() for rel in sorted(files) if rel != ap.MANIFEST}
        (staging / ap.MANIFEST).write_text(json.dumps(manifest, indent="\t", ensure_ascii=False) + "\n", encoding="utf-8")
    _add(staging, case.get("after", []))
    out = work / "cases" / case["name"]
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    recipe = case.get("zip")
    if recipe is None:
        target = out / top
        shutil.copytree(staging, target, symlinks=True)
        return target
    zip_top = recipe.get("top", top)
    target = out / (zip_top + ".zip")
    if "raw_text" in recipe:
        target.write_bytes(recipe["raw_text"].encode("utf-8"))
        return target
    entries = [{"name": (zip_top + "/" + rel).encode("utf-8"), "data": (staging / rel).read_bytes()}
               for rel in files_of(staging)]
    for extra in _items(recipe.get("extra", [])):
        name = bytes.fromhex(extra["name_hex"]) if "name_hex" in extra else extra["name"].encode("utf-8")
        data = bytes.fromhex(extra["hex"]) if "hex" in extra else extra.get("text", "").encode("utf-8")
        entries.append({"name": name, "data": data, **{k: extra[k] for k in ("method", "flags", "made_by", "external", "size")
                                                         if k in extra}})
    data = raw_zip(entries)
    target.write_bytes(zip64(data) if recipe.get("zip64") else data)
    return target


def corpus() -> dict:
    return json.loads(EXPECTED.read_text(encoding="utf-8"))


def shipped_sites_copy(folder: str, work: Path) -> Path:
    """A copy of the shipped sites plugin [folder] under [work], every
    picture its sites.json names that the checkout lacks a small stand-in."""
    target = work / folder
    shutil.copytree(ROOT / "expanded_adventure" / folder, target)
    sites = json.loads((target / "sites.json").read_text(encoding="utf-8"))
    pictures = list(sites.get("pictures", {}).values()) + [s["sprite"]["file"] for s in sites["sites"].values()]
    for rel in pictures:
        if not (target / rel).is_file():
            (target / rel).parent.mkdir(parents=True, exist_ok=True)
            (target / rel).write_bytes(ap._sprite(ap.SHRINE_ROWS, ap.SHRINE_COLORS))
    return target


def expected_reason(case: dict, game: ap.Game) -> str | None:
    reason = case.get("reason")
    return reason.replace("{game_version}", game.version) if isinstance(reason, str) else None


# --------------------------------------------------------------------------

class CorpusTest(unittest.TestCase):
    """Every case of the corpus: the tool's verdict and first reason are the file's."""

    @classmethod
    def setUpClass(cls):
        cls.game = ap.find_game()
        cls.data = corpus()
        cls.work = Path(tempfile.mkdtemp(prefix="plugin-corpus-"))

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.work, ignore_errors=True)

    def test_the_corpus_is_big_enough_and_named_once(self):
        names = [case["name"] for case in self.data["cases"]]
        self.assertEqual(len(names), len(set(names)))
        self.assertGreaterEqual(len(names), 25)
        self.assertGreaterEqual(sum(1 for c in self.data["cases"] if c["valid"]), 5)
        for case in self.data["cases"]:
            with self.subTest(case=case["name"]):
                self.assertIn("valid", case)
                self.assertTrue(case["valid"] == (case.get("reason") == "") or "reason_prefix" in case,
                                "a valid case has no reason; a refused one has one")

    def test_the_corpus_covers_what_the_brief_asks(self):
        names = {case["name"] for case in self.data["cases"]}
        for wanted in ("good_minimal", "good_music", "litter_folder", "litter_zip", "zip_dotdot", "zip_absolute",
                       "zip_backslash", "folder_symlink", "zip_symlink", "zip64", "zip_encrypted", "zip_duplicate",
                       "zip_two_tops", "hash_mismatch", "unknown_condition", "unknown_effect", "bad_card_name",
                       "bad_placeholder", "manifest_unknown_pack", "manifest_newer_api", "manifest_newer_game",
                       "picture_too_large", "ogg_not_vorbis", "text_not_utf8", "content_too_deep", "manifest_too_deep",
                       "too_many_files", "zip_too_big", "text_file_too_big", "ogg_too_big", "text_too_long",
                       "zip_path_too_long", "too_many_folders"):
            self.assertIn(wanted, names)
        for extension in ("gd", "gdc", "gdextension", "tscn", "scn", "tres", "res", "import", "remap", "pck", "so",
                          "dll", "dylib", "exe"):
            self.assertIn("kind_" + extension, names)
        # API 2: the manifest's kind and the sites plugins' content.
        for wanted in ("good_sites", "good_sites_zip", "good_sites_exported_zip", "good_sites_every_condition_and_effect",
                       "good_island_kind", "good_island_api_two", "kind_unknown", "kind_not_text", "sites_with_region",
                       "sites_api_one", "sites_island_files_only", "sites_spawn_no_dungeon",
                       "sites_used_up_without_prices", "sites_undeclared_flag", "sites_undeclared_flag_condition",
                       "sites_card_of_a_pack_not_required", "sites_bad_card_name", "sites_dungeon_condition_unknown",
                       "sites_action_id_twice", "sites_effects_on_a_leave", "sites_unknown_condition",
                       "sites_unknown_effect", "sites_bad_placeholder", "sites_picture_prefix"):
            self.assertIn(wanted, names)

    def test_the_sites_cases_reach_every_condition_and_effect(self):
        """The good sites case uses every sites condition and effect, so
        both validators read each of them at least once."""
        # API 3's words stand in a case of their own (2026-11-22): the first
        # case stays what a game of API 2 read.
        text = "".join(json.dumps(c) for c in self.data["cases"]
                       if c["name"] in ("good_sites_every_condition_and_effect", "good_sites_api3_every_word"))
        schema = ap.find_game().schema()["types"]
        for group in ("sites_condition", "sites_effect"):
            for option in schema[group]["options"]:
                self.assertIn('{"%s": ' % option, text, option)
        for do in schema["sites_action"]["fields"]["do"]["values"]:
            self.assertIn('"do": "%s"' % do, text, do)

    def test_every_case_is_judged_as_the_file_says(self):
        top = self.data["base_top"]
        for case in self.data["cases"]:
            with self.subTest(case=case["name"]):
                path = build_case(case, self.work, top)
                result = ap.judge(str(path), self.game)
                first = result["problems"][0] if result["problems"] else ""
                self.assertEqual(result["valid"], case["valid"], "\n".join(result["problems"]))
                if "reason_prefix" in case:
                    self.assertTrue(first.startswith(case["reason_prefix"]), first)
                else:
                    self.assertEqual(first, expected_reason(case, self.game))

    def test_the_command_line_says_the_same(self):
        top = self.data["base_top"]
        for name in ("good_minimal", "good_exported_zip", "zip_symlink", "manifest_newer_api", "bad_card_name",
                     "good_sites", "sites_with_region", "sites_spawn_no_dungeon"):
            case = next(c for c in self.data["cases"] if c["name"] == name)
            with self.subTest(case=name):
                path = build_case(case, self.work, top)
                result = run_tool("validate", str(path), "--json")
                self.assertEqual(result.returncode, 0 if case["valid"] else 1, result.stderr)
                report = json.loads(result.stdout)
                self.assertEqual(report["valid"], case["valid"])
                self.assertEqual(report["problems"][0] if report["problems"] else "", expected_reason(case, self.game))
                plain = run_tool("validate", str(path))
                self.assertEqual(plain.returncode, result.returncode)
                if not case["valid"]:
                    self.assertEqual(plain.stdout.splitlines()[0], expected_reason(case, self.game))


class SkeletonTest(unittest.TestCase):
    """`new`: a plugin that loads and plays, and the corpus's good_minimal is it."""

    def test_the_corpus_minimal_plugin_is_what_new_writes(self):
        files = ap.skeleton("corpus_isle", "Corpus Isle", "Shandalar Godot tests", "")
        on_disk = {rel: (FIXTURES / "good_minimal" / rel).read_bytes() for rel in files_of(FIXTURES / "good_minimal")}
        self.assertEqual(sorted(on_disk), sorted(files))
        for rel in files:
            self.assertEqual(on_disk[rel], files[rel], rel + " differs from what new writes: rebuild good_minimal")

    def test_new_writes_a_valid_plugin_with_one_quest_two_foes_a_port_and_a_castle(self):
        with tempfile.TemporaryDirectory() as work:
            folder = Path(work) / "Salt_Isle"
            result = run_tool("new", str(folder), "--id", "salt_isle", "--name", "Salt Isle", "--author", "A. Author")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            judged = ap.judge(str(folder), ap.find_game())
            self.assertTrue(judged["valid"], judged["problems"])
            data = judged["data"]
            self.assertEqual(len(data["quests"]["quests"]), 1)
            self.assertEqual(sorted(data["foes"]["foes"]), ["smuggler", "warden"])
            self.assertEqual(sorted(data["places"]["markers"]), ["castle", "port"])
            manifest = judged["manifest"]
            self.assertEqual(manifest["minimum_game_version"], ap.find_game().version)
            self.assertEqual(manifest["authors"], ["A. Author"])
            for kind in ("port", "castle"):
                sprite = data["places"]["markers"][kind]["sprite"]["file"]
                self.assertTrue(sprite.startswith("art/salt_isle_"), sprite)
                self.assertEqual(ap.picture_kind((folder / sprite).read_bytes()), "png")
            for deck in data["foes"]["foes"].values():
                self.assertEqual(sum(deck["deck"].values()), 40)

    def test_the_corpus_sites_plugin_is_what_new_kind_sites_writes(self):
        files = ap.site_skeleton("corpus_sites", "Corpus Sites", "Shandalar Godot tests", "")
        on_disk = {rel: (FIXTURES / "good_sites" / rel).read_bytes() for rel in files_of(FIXTURES / "good_sites")}
        self.assertEqual(sorted(on_disk), sorted(files))
        for rel in files:
            self.assertEqual(on_disk[rel], files[rel], rel + " differs from what new --kind sites writes: rebuild good_sites")

    def test_new_kind_sites_writes_a_valid_sites_plugin_of_one_place(self):
        with tempfile.TemporaryDirectory() as work:
            folder = Path(work) / "Way_Places"
            result = run_tool("new", str(folder), "--id", "way_places", "--name", "Way Places", "--kind", "sites")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            judged = ap.judge(str(folder), ap.find_game())
            self.assertTrue(judged["valid"], judged["problems"])
            manifest = judged["manifest"]
            self.assertEqual((manifest["kind"], manifest["api_version"]), ("sites", 2))
            self.assertNotIn("region", manifest)
            self.assertEqual(manifest["minimum_game_version"], ap.find_game().version)
            self.assertEqual(sorted(p.name for p in folder.iterdir()), ["README.txt", "art", "plugin.json", "sites.json", "text.json"],
                             "no island file in a sites plugin")
            data = judged["data"]
            self.assertEqual(data["kind"], "sites")
            self.assertEqual(list(data["sites"]["sites"]), ["shrine"])
            shrine = data["sites"]["sites"]["shrine"]
            self.assertEqual(shrine["where"], ["mainland", "islands"])
            for rel in (shrine["sprite"]["file"], data["sites"]["pictures"][shrine["picture"]]):
                self.assertTrue(rel.startswith("art/way_places_"), rel)
                self.assertEqual(ap.picture_kind((folder / rel).read_bytes()), "png")
            self.assertEqual(ap.picture_size((folder / data["sites"]["pictures"][shrine["picture"]]).read_bytes()),
                             (128, 70), "the pane's shape")
            self.assertEqual(shrine["panes"][1]["actions"][0]["prices"], [20, 40, 80])

    def test_new_is_an_island_unless_asked(self):
        with tempfile.TemporaryDirectory() as work:
            folder = Path(work) / "Isle"
            self.assertEqual(run_tool("new", str(folder), "--id", "isle", "--name", "Isle").returncode, 0)
            manifest = json.loads((folder / "plugin.json").read_text(encoding="utf-8"))
            self.assertNotIn("kind", manifest, "an island skeleton is what API 1's was")
            self.assertEqual(manifest["api_version"], 1)
            refused = run_tool("new", str(Path(work) / "Other"), "--id", "other", "--name", "Other", "--kind", "town")
            self.assertEqual(refused.returncode, 2)

    def test_new_without_a_schema_writes_nothing(self):
        with tempfile.TemporaryDirectory() as work:
            alone = Path(work) / "game" / "tools"
            alone.mkdir(parents=True)
            shutil.copy(SCRIPT, alone / "adventure_plugin.py")
            result = run_tool("new", str(Path(work) / "my_isle"), "--id", "my_isle", "--name", "My Isle",
                              tool=alone / "adventure_plugin.py")
            self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
            self.assertIn("schema_v1.json) was not found", result.stderr)
            self.assertFalse((Path(work) / "my_isle").exists(), "no half-written folder")

    def test_new_refuses_a_bad_id_a_used_folder_and_an_empty_name(self):
        with tempfile.TemporaryDirectory() as work:
            for args in (["--id", "Bad-Id", "--name", "X"], ["--id", "mainland", "--name", "X"],
                         ["--id", "fine", "--name", "  "]):
                result = run_tool("new", str(Path(work) / "x"), *args)
                self.assertEqual(result.returncode, 2, args)
            (Path(work) / "used").mkdir()
            (Path(work) / "used" / "keep.txt").write_text("mine", encoding="utf-8")
            result = run_tool("new", str(Path(work) / "used"), "--id", "fine", "--name", "Fine")
            self.assertEqual(result.returncode, 2)
            self.assertIn("already exists", result.stderr)
            self.assertEqual((Path(work) / "used" / "keep.txt").read_text(encoding="utf-8"), "mine")


class ExportTest(unittest.TestCase):
    def test_export_is_deterministic_hashed_sorted_and_validated(self):
        with tempfile.TemporaryDirectory() as work:
            folder = Path(work) / "Corpus_Isle"
            shutil.copytree(FIXTURES / "good_minimal", folder)
            (folder / ".DS_Store").write_bytes(b"\x00\x01")
            first = run_tool("export", str(folder), "--out", str(Path(work) / "a"))
            second = run_tool("export", str(folder), "--out", str(Path(work) / "b"))
            self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
            a = (Path(work) / "a" / "Corpus_Isle.zip").read_bytes()
            self.assertEqual(a, (Path(work) / "b" / "Corpus_Isle.zip").read_bytes(), "the same folder, the same bytes")
            self.assertIn(hashlib.sha256(a).hexdigest(), first.stdout)
            with zipfile.ZipFile(io.BytesIO(a)) as archive:
                names = archive.namelist()
                self.assertEqual(names, sorted(names))
                self.assertTrue(all(n.startswith("Corpus_Isle/") for n in names))
                self.assertNotIn("Corpus_Isle/.DS_Store", names, "litter is left out")
                for info in archive.infolist():
                    self.assertEqual(info.date_time, ap.ZIP_TIME)
                    self.assertEqual(info.compress_type, zipfile.ZIP_DEFLATED)
                manifest = json.loads(archive.read("Corpus_Isle/plugin.json"))
                listed = manifest["files"]
                self.assertEqual(sorted(listed), sorted(n[len("Corpus_Isle/"):] for n in names
                                                        if n != "Corpus_Isle/plugin.json"))
                for rel, digest in listed.items():
                    self.assertEqual(hashlib.sha256(archive.read("Corpus_Isle/" + rel)).hexdigest(), digest)
                self.assertEqual(manifest["region"]["salt"], 1855988140, "whole numbers stay whole")
            self.assertNotIn("files", json.loads((folder / "plugin.json").read_text(encoding="utf-8")),
                             "the folder itself is left as it was")
            self.assertTrue(ap.judge(str(Path(work) / "a" / "Corpus_Isle.zip"), ap.find_game())["valid"])

    def test_export_goes_to_dist_and_never_beside_the_folder_it_would_hide(self):
        with tempfile.TemporaryDirectory() as work:
            folder = Path(work) / "Corpus_Isle"
            shutil.copytree(FIXTURES / "good_minimal", folder)
            result = run_tool("export", str(folder), cwd=Path(work))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue((Path(work) / "dist" / "Corpus_Isle.zip").is_file())
            self.assertEqual([p.name for p in (Path(work) / "dist").iterdir()], ["Corpus_Isle.zip"], "no .part left")
            beside = run_tool("export", str(folder), "--out", work)
            self.assertEqual(beside.returncode, 2)
            self.assertIn("passes over the folder you are editing", beside.stderr)
            self.assertFalse((Path(work) / "Corpus_Isle.zip").exists())

    def test_export_writes_a_fresh_files_list_over_a_folders_stale_one(self):
        """A folder unzipped from an exported plugin (the shipped Refuge)
        carries the files list: editing it must not block the export,
        which writes its own (RV3-1)."""
        with tempfile.TemporaryDirectory() as work:
            folder = Path(work) / "Corpus_Isle"
            shutil.copytree(FIXTURES / "good_minimal", folder)
            manifest = json.loads((folder / "plugin.json").read_text(encoding="utf-8"))
            manifest["files"] = {"world.json": "0" * 64, "gone.json": "1" * 64}
            (folder / "plugin.json").write_text(json.dumps(manifest, indent="\t") + ",\n".join([""]) + "\n",
                                                encoding="utf-8")
            judged = run_tool("validate", str(folder))
            self.assertEqual(judged.returncode, 1, "the game checks a folder's list too")
            self.assertIn("note: remove the files list from plugin.json (it is written by export)", judged.stderr)
            exported = run_tool("export", str(folder), "--out", str(Path(work) / "dist"))
            self.assertEqual(exported.returncode, 0, exported.stdout + exported.stderr)
            with zipfile.ZipFile(Path(work) / "dist" / "Corpus_Isle.zip") as archive:
                listed = json.loads(archive.read("Corpus_Isle/plugin.json"))["files"]
                self.assertNotIn("gone.json", listed)
                self.assertEqual(listed["world.json"], hashlib.sha256(archive.read("Corpus_Isle/world.json")).hexdigest())
                self.assertEqual(json.loads(archive.read("Corpus_Isle/plugin.json"))["region"]["salt"], 1855988140)
            text = (folder / "plugin.json").read_text(encoding="utf-8").replace('"palette": "shandalar"\n',
                                                                                '"palette": "shandalar",\n')
            (folder / "plugin.json").write_text(text, encoding="utf-8")
            again = run_tool("export", str(folder), "--out", str(Path(work) / "dist2"))
            self.assertEqual(again.returncode, 0, "a trailing comma the game reads, export reads: " + again.stdout + again.stderr)

    def test_the_exported_zip_is_readable_by_everyone(self):
        with tempfile.TemporaryDirectory() as work:
            folder = Path(work) / "Corpus_Isle"
            shutil.copytree(FIXTURES / "good_minimal", folder)
            self.assertEqual(run_tool("export", str(folder), "--out", str(Path(work) / "dist")).returncode, 0)
            mode = (Path(work) / "dist" / "Corpus_Isle.zip").stat().st_mode & 0o777
            self.assertEqual(mode, 0o644, oct(mode))

    def test_export_refuses_an_invalid_folder_and_a_zip_inside_the_folder(self):
        with tempfile.TemporaryDirectory() as work:
            folder = Path(work) / "Corpus_Isle"
            shutil.copytree(FIXTURES / "good_minimal", folder)
            inside = run_tool("export", str(folder), "--out", str(folder / "dist"))
            self.assertEqual(inside.returncode, 2)
            (folder / "evil.gd").write_text("extends Node", encoding="utf-8")
            refused = run_tool("export", str(folder), "--out", str(Path(work) / "out"))
            self.assertEqual(refused.returncode, 1)
            self.assertIn("evil.gd: this kind of file is not allowed", refused.stdout)
            self.assertFalse((Path(work) / "out" / "Corpus_Isle.zip").exists())
            self.assertEqual(run_tool("export", str(Path(work) / "nowhere")).returncode, 2)

    def test_the_prototype_exports_valid_and_under_the_limits(self):
        data, top, result = ap.export_bytes(str(PROTOTYPE), ap.find_game())
        self.assertTrue(result["valid"], result["problems"])
        self.assertEqual(top, "Fallen_Empires_Refuge_prototype")
        self.assertLess(len(data), ap.MAX_TOTAL)
        with tempfile.TemporaryDirectory() as work:
            target = Path(work) / (top + ".zip")
            target.write_bytes(data)
            judged = ap.judge(str(target), ap.find_game())
            self.assertTrue(judged["valid"], judged["problems"])
            self.assertEqual(judged["manifest"]["id"], "refuge")
            self.assertEqual(len(judged["manifest"]["files"]), len(judged["files"]) - 1)


class SitesTest(unittest.TestCase):
    """The shipped sites plugins (API 2) as the tool reads them."""

    def test_the_shipped_sites_plugins_are_valid_and_export(self):
        with tempfile.TemporaryDirectory() as work:
            for folder, ident in SHIPPED_SITES.items():
                with self.subTest(plugin=folder):
                    copy = shipped_sites_copy(folder, Path(work))
                    judged = ap.judge(str(copy), ap.find_game())
                    self.assertTrue(judged["valid"], judged["problems"])
                    self.assertEqual((judged["manifest"]["id"], judged["data"]["kind"]), (ident, "sites"))
                    data, top, result = ap.export_bytes(str(copy), ap.find_game())
                    self.assertTrue(result["valid"])
                    self.assertEqual(top, folder)
                    target = Path(work) / "dist" / (folder + ".zip")
                    target.parent.mkdir(exist_ok=True)
                    target.write_bytes(data)
                    self.assertTrue(ap.judge(str(target), ap.find_game())["valid"])

    def test_the_hut_and_the_guild_say_what_their_readmes_say(self):
        with tempfile.TemporaryDirectory() as work:
            hut = ap.judge(str(shipped_sites_copy("Old_Adventurers_Hut", Path(work))), ap.find_game())["data"]
            vault = hut["sites"]["dungeons"]["forgotten_vault"]
            self.assertEqual(vault["cards"], ["Old Man of the Sea", "Planar Gate", "Mirror Universe"])
            secret = ap._site_actions(hut["sites"]["sites"]["hut"])["secret"]
            self.assertEqual((secret["do"], secret["prices"]), ("effects", [1000]))
            self.assertIn({"spawn_dungeon": "forgotten_vault"}, secret["effects"])
            # Since 1.1.0 he sells five secrets, one after another, each for 1000 gold.
            readme = " ".join((ROOT / "expanded_adventure" / "Old_Adventurers_Hut" / "README.txt").read_text(encoding="utf-8").split())
            self.assertEqual(list(hut["sites"]["dungeons"]), HUT_CHAIN)
            for number, key in enumerate(HUT_CHAIN, 1):
                dungeon = hut["sites"]["dungeons"][key]
                self.assertIn(dungeon["name"].removeprefix("The "), readme)
                for card in dungeon["cards"]:
                    self.assertIn(card, readme)
                action = ap._site_actions(hut["sites"]["sites"]["hut"])["secret" if number == 1 else "secret%d" % number]
                self.assertEqual((action["do"], action["prices"], action["effects"][0]),
                                 ("effects", [1000], {"spawn_dungeon": key}))
            guild = ap.judge(str(shipped_sites_copy("Conjuration_Wizard_Guild", Path(work))), ap.find_game())["data"]
            tower = guild["sites"]["sites"]["tower"]
            self.assertEqual(tower["where"], ["mainland", "islands"])
            copy = ap._site_actions(tower)["copy"]
            self.assertEqual((copy["do"], copy["prices"]), ("copy_card", [2000, 4000, 8000, 12000]))

    def test_info_of_a_sites_plugin(self):
        with tempfile.TemporaryDirectory() as work:
            copy = shipped_sites_copy("Old_Adventurers_Hut", Path(work))
            result = run_tool("info", str(copy))
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("kind:                 sites\n", result.stdout)
            self.assertIn("1 place, 5 dungeons, 0 flags, 1 picture", result.stdout)
            self.assertIn("place hut:            Old Adventurer's Hut, on mainland, gap 3; 12 panes; "
                          "actions leave, secret, secret2, secret3, secret4, secret5\n", result.stdout)
            for line in ("dungeon forgotten_vault: The Forgotten Vault, holding Old Man of the Sea, Planar Gate, Mirror Universe",
                         "dungeon drowned_library: The Drowned Library, holding Library of Alexandria, Candelabra of Tawnos, "
                         "Transmute Artifact",
                         "dungeon sunken_forge: The Sunken Forge, holding Mishra's Workshop, Su-Chi, Triskelion",
                         "dungeon hall_of_echoes: The Hall of Echoes, holding Fork, Wheel of Fortune, Mana Flare",
                         "dungeon planeswalkers_rest: The Planeswalker's Rest, holding The Abyss, Moat, Nether Void"):
                self.assertIn("  " + line + "\n", result.stdout)
            facts = json.loads(run_tool("info", str(copy), "--json").stdout)
            self.assertEqual(facts["plugin_kind"], "sites")
            descriptor = facts["content"]["descriptor"]
            self.assertEqual(descriptor["sprites"], {"hut": ["art/old_hut_map.png", 104.0]})
            self.assertEqual(descriptor["sites"], {"hut": {"name": "Old Adventurer's Hut", "where": ["mainland"], "gap": 3}})
            self.assertEqual((descriptor["kind"], descriptor["salt"], descriptor["pack"]), ("sites", 1213141, ""))
            report = json.loads(run_tool("validate", str(copy), "--json").stdout)
            self.assertEqual((report["valid"], report["plugin_kind"]), (True, "sites"))

    def test_export_of_a_sites_plugin_is_deterministic(self):
        with tempfile.TemporaryDirectory() as work:
            folder = Path(work) / "Corpus_Sites"
            shutil.copytree(FIXTURES / "good_sites", folder)
            first = run_tool("export", str(folder), "--out", str(Path(work) / "a"))
            second = run_tool("export", str(folder), "--out", str(Path(work) / "b"))
            self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
            a = (Path(work) / "a" / "Corpus_Sites.zip").read_bytes()
            self.assertEqual(a, (Path(work) / "b" / "Corpus_Sites.zip").read_bytes())
            with zipfile.ZipFile(io.BytesIO(a)) as archive:
                manifest = json.loads(archive.read("Corpus_Sites/plugin.json"))
                self.assertEqual(sorted(manifest["files"]), ["README.txt", "art/corpus_sites_shrine.png",
                                                             "art/corpus_sites_shrine_map.png", "sites.json", "text.json"])
                self.assertEqual((manifest["kind"], manifest["api_version"]), ("sites", 2))
                self.assertEqual(json.loads(archive.read("Corpus_Sites/sites.json"))["salt"], 216285643,
                                 "whole numbers stay whole")


def filtered_png(width: int, height: int, pixels: list, color: int = 6, kinds=(0, 1, 2, 3, 4), palette: bytes = b"",
                 trns: bytes | None = None) -> bytes:
    """A PNG of [pixels] (rows of tuples, one tuple a pixel in the color
    type's own channels), row y written with filter kinds[y % len(kinds)]:
    the encoder side of ap.png_alpha's five filters."""
    bpp = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[color]
    raw, prev = bytearray(), bytes(width * bpp)
    for y, row in enumerate(pixels):
        line = bytes(channel for pixel in row for channel in pixel)
        kind = kinds[y % len(kinds)]
        out = bytearray()
        for i, value in enumerate(line):
            a = line[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            p = a + b - c
            pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
            guess = [0, a, b, (a + b) >> 1, a if pa <= pb and pa <= pc else b if pb <= pc else c][kind]
            out.append((value - guess) & 255)
        raw += bytes([kind]) + out
        prev = line

    def chunk(kind: bytes, body: bytes) -> bytes:
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, color, 0, 0, 0))
            + (chunk(b"PLTE", palette) if palette else b"") + (chunk(b"tRNS", trns) if trns is not None else b"")
            + chunk(b"IDAT", zlib.compress(bytes(raw))) + chunk(b"IEND", b""))


class PlaceToolsTest(unittest.TestCase):
    """add-place, add-dungeon, walk and art: the tools a community builds places with."""

    def setUp(self):
        self.work = Path(tempfile.mkdtemp(prefix="plugin-places-"))
        self.folder = self.work / "Corpus_Sites"
        shutil.copytree(FIXTURES / "good_sites", self.folder)
        self.game = ap.find_game()

    def tearDown(self):
        shutil.rmtree(self.work, ignore_errors=True)

    def snapshot(self) -> dict:
        return {rel: (self.folder / rel).read_bytes() for rel in files_of(self.folder)}

    def test_add_place_adds_a_valid_place_for_each_service(self):
        for key, args, actions in (("tower", ["--service", "copy", "--prices", "300,600", "--where", "mainland,islands"],
                                    ["copy", "leave"]),
                                   ("stall", [], ["leave", "service"]),
                                   ("spring", ["--service", "effects", "--prices", "0"], ["leave", "service"]),
                                   ("well", ["--service", "none", "--where", "islands"], ["leave"])):
            with self.subTest(place=key):
                result = run_tool("add-place", str(self.folder), "--id", key, "--name", "The " + key.title(), *args)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertIn("Added the place %s" % key, result.stdout)
                judged = ap.judge(str(self.folder), self.game)
                self.assertTrue(judged["valid"], judged["problems"])
                site = judged["data"]["sites"]["sites"][key]
                self.assertEqual(sorted(ap._site_actions(site)), actions)
                self.assertEqual(site["picture"], "corpus_sites_" + key)
                for rel in (judged["data"]["sites"]["pictures"][site["picture"]], site["sprite"]["file"]):
                    self.assertEqual(ap.picture_kind((self.folder / rel).read_bytes()), "png", rel)
                self.assertIn(key + ".intro", judged["data"]["text"])
        data = ap.judge(str(self.folder), self.game)["data"]["sites"]["sites"]
        self.assertEqual(list(data), ["shrine", "tower", "stall", "spring", "well"], "the places before it stay, in order")
        self.assertEqual(data["tower"]["where"], ["mainland", "islands"])
        self.assertEqual(ap._site_actions(data["tower"])["copy"]["prices"], [300, 600])
        self.assertEqual(ap._site_actions(data["stall"])["service"]["prices"], [100])
        self.assertEqual(data["well"]["where"], ["islands"])
        self.assertEqual(len(data["tower"]["panes"]), 2, "a priced service gets its used-up pane")
        self.assertEqual(json.loads((self.folder / "sites.json").read_text(encoding="utf-8"))["salt"], 216285643)

    def test_add_place_refuses_with_one_clear_line_and_changes_nothing(self):
        before = self.snapshot()
        for args, wanted in ((["--id", "shrine", "--name", "Again"], "already has a place shrine."),
                             (["--id", "Bad-Id", "--name", "X"], "--id must be 1 to 32"),
                             (["--id", "x", "--name", "  "], "--name must be non-empty"),
                             (["--id", "x", "--name", "X", "--where", "sea"], "--where takes mainland, islands"),
                             (["--id", "x", "--name", "X", "--service", "none", "--prices", "5"], "--prices needs a service"),
                             (["--id", "x", "--name", "X", "--prices", "5,-1"], "--prices takes whole numbers")):
            with self.subTest(args=args):
                result = run_tool("add-place", str(self.folder), *args)
                self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
                self.assertIn(wanted, result.stderr)
                self.assertEqual(len(result.stderr.strip().splitlines()), 1)
                self.assertEqual(self.snapshot(), before)
        island = run_tool("add-place", str(FIXTURES / "good_minimal"), "--id", "x", "--name", "X")
        self.assertEqual(island.returncode, 2)
        self.assertIn("is an island plugin: add-place works on a sites plugin (new --kind sites makes one).", island.stderr)
        (self.folder / "text.json").write_text("{", encoding="utf-8")
        broken = run_tool("add-place", str(self.folder), "--id", "x", "--name", "X")
        self.assertEqual(broken.returncode, 2)
        self.assertIn("is refused at the content stage", broken.stderr)

    def test_add_place_puts_everything_back_when_the_result_is_refused(self):
        for n in range(7):
            self.assertEqual(run_tool("add-place", str(self.folder), "--id", "p%d" % n, "--name", "P", "--service",
                                      "none").returncode, 0)
        before = self.snapshot()
        ninth = run_tool("add-place", str(self.folder), "--id", "ninth", "--name", "Ninth")
        self.assertEqual(ninth.returncode, 1, ninth.stdout + ninth.stderr)
        self.assertIn("sites.json.sites: 9 entries; 1 to 8 are allowed.", ninth.stdout)
        self.assertIn("nothing was changed", ninth.stderr)
        self.assertEqual(self.snapshot(), before)

    def test_add_dungeon_alone_and_raised_by_a_new_button_with_the_huts_three_panes(self):
        alone = run_tool("add-dungeon", str(self.folder), "--id", "crypt", "--name", "The Crypt", "--cards",
                         "Lightning Bolt, Llanowar Elves", "--color", "black", "--size", "large", "--rules",
                         "no_artifacts,life_adds", "--min", "4", "--max", "12")
        self.assertEqual(alone.returncode, 0, alone.stdout + alone.stderr)
        self.assertIn("No place raises it yet", alone.stdout)
        self.assertEqual(run_tool("add-place", str(self.folder), "--id", "well", "--name", "Old Well", "--service",
                                  "none").returncode, 0)
        raised = run_tool("add-dungeon", str(self.folder), "--id", "cellar", "--name", "The Dry Cellar", "--cards",
                          "Swamp", "--place", "well", "--price", "250")
        self.assertEqual(raised.returncode, 0, raised.stdout + raised.stderr)
        data = ap.judge(str(self.folder), self.game)["data"]
        self.assertEqual(data["sites"]["dungeons"]["crypt"], {
            "name": "The Crypt", "color": "black", "size": "large", "rules": ["no_artifacts", "life_adds"],
            "cards": ["Lightning Bolt", "Llanowar Elves"], "distance": {"min": 4, "max": 12}})
        well = data["sites"]["sites"]["well"]
        self.assertEqual([pane["when"] for pane in well["panes"]],
                         [[{"dungeon": {"dungeon": "cellar", "state": "cleared"}}],
                          [{"dungeon": {"dungeon": "cellar", "state": "open"}}], []], "cleared, open, then its own")
        action = ap._site_actions(well)["cellar"]
        self.assertEqual((action["do"], action["prices"], action["effects"][0]), ("effects", [250], {"spawn_dungeon": "cellar"}))
        self.assertEqual([a["id"] for a in well["panes"][2]["actions"]], ["cellar", "leave"], "before the Leave")
        run = ap.walk_site(data, "well", 1000)
        self.assertEqual([s["pane"] for s in run["steps"] if s["kind"] == "pane"], [2, 2, 1, 0])
        # Counted for the land (finding 1.1 of 2026-11-22: a priced action that raises a dungeon).
        self.assertEqual(run["steps"][-1]["state"], {"gold": 750, "food": 0, "uses": {"well.cellar@mainland": 1}, "flags": [],
                                                    "dungeons": {"cellar": "cleared"}})

    def test_add_dungeon_extends_an_action_and_checks_cards_as_validate_does(self):
        before = self.snapshot()
        bad = run_tool("add-dungeon", str(self.folder), "--id", "crypt", "--name", "Crypt", "--cards", "Lightning Blot")
        self.assertEqual(bad.returncode, 1)
        self.assertEqual(bad.stdout.splitlines()[0], "sites.json.dungeons.crypt.cards[0]: Lightning Blot is not a card "
                         "of the base game or of a required pack (none).")
        self.assertEqual(self.snapshot(), before, "a refused edit changes nothing")
        for args, wanted in ((["--price", "5"], "--action and --price need --place"),
                             (["--place", "nowhere"], "has no place nowhere (its places: shrine)."),
                             (["--place", "shrine", "--action", "leave"], "only an effects action can raise a dungeon"),
                             (["--min", "30", "--max", "10"], "--min 30 is more than --max 10.")):
            result = run_tool("add-dungeon", str(self.folder), "--id", "pit", "--name", "The Pit", "--cards", "Swamp", *args)
            self.assertEqual(result.returncode, 2, args)
            self.assertIn(wanted, result.stderr)
            self.assertEqual(self.snapshot(), before)
        done = run_tool("add-dungeon", str(self.folder), "--id", "pit", "--name", "The Pit", "--cards", "Swamp",
                        "--place", "shrine", "--action", "bless", "--price", "999")
        self.assertEqual(done.returncode, 0, done.stdout + done.stderr)
        self.assertIn("the action bless now raises it", done.stdout)
        shrine = ap.judge(str(self.folder), self.game)["data"]["sites"]["sites"]["shrine"]
        bless = ap._site_actions(shrine)["bless"]
        self.assertEqual(bless["effects"][0], {"spawn_dungeon": "pit"})
        self.assertEqual(bless["prices"], [20, 40, 80], "its own prices stay")
        self.assertEqual(len(shrine["panes"]), 4)
        again = run_tool("add-dungeon", str(self.folder), "--id", "pit", "--name", "The Pit", "--cards", "Swamp")
        self.assertEqual(again.returncode, 2)
        self.assertIn("already has a dungeon pit.", again.stderr)

    def test_walk_plays_the_hut_to_its_cleared_pane(self):
        result = run_tool("walk", str(ROOT / "expanded_adventure" / "Old_Adventurers_Hut"), "--json")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        run = json.loads(result.stdout)["sites"][0]
        kinds = [step["kind"] for step in run["steps"]]
        # No gold, gold, then five times: pay, the waiting pane, the dungeon cleared, the pane after it.
        self.assertEqual(kinds, ["pane", "pane"] + ["press", "pane", "clear", "pane"] * 5)
        poor, rich, press, waiting, _, second_offer = run["steps"][:6]
        cleared = run["steps"][-1]
        self.assertEqual((poor["note"], poor["pane"]), ("with no gold", 2))
        self.assertEqual(poor["buttons"][0], {"id": "secret", "do": "effects", "ready": False,
                                              "why": "You need 1000 gold for this; you carry 0.",
                                              "label": "Pay 1000 gold for the secret"})
        self.assertTrue(rich["buttons"][0]["ready"])
        self.assertEqual((rich["title"], rich["subtitle"]), ("Old Adventurer's Hut", "A hut in the woods"))
        self.assertEqual((press["paid"], press["raised"], press["state"]["gold"]), (1000, ["forgotten_vault"], 99000))
        self.assertEqual(press["journal"][0], "The old man in the woods told you where The Forgotten Vault lies.")
        self.assertEqual(press["lines"][1], "The way to The Forgotten Vault is marked on your map.")
        self.assertEqual(press["buttons"], ["Return", "Leave"])
        self.assertEqual(waiting["pane"], 1)
        self.assertIn("You know the way to The Forgotten Vault", waiting["lines"][0])
        self.assertEqual([b["id"] for b in waiting["buttons"]], ["leave"], "nothing is sold while a dungeon stands open")
        # The chain: each cleared dungeon brings the next offer, which names the one just cleared.
        self.assertEqual(second_offer["pane"], 4)
        self.assertIn("You came back from The Forgotten Vault alive", second_offer["lines"][0])
        self.assertEqual([(b["id"], b["ready"]) for b in second_offer["buttons"]], [("secret2", True), ("leave", True)])
        self.assertEqual([step["pane"] for step in run["steps"] if step["kind"] == "pane"],
                         [2, 2, 1, 4, 3, 6, 5, 8, 7, 10, 9, 0])
        presses = [step for step in run["steps"] if step["kind"] == "press"]
        self.assertEqual([p["raised"] for p in presses], [[key] for key in HUT_CHAIN])
        self.assertEqual([p["paid"] for p in presses], [1000] * 5)
        self.assertEqual([p["state"]["gold"] for p in presses], [99000, 98000, 97000, 96000, 95000])
        self.assertEqual(presses[4]["journal"], [
            "The old man in the woods told you where The Planeswalker's Rest lies.",
            "Paid the old man in the woods 1000 gold for the way to The Planeswalker's Rest."])
        self.assertIn("The Drowned Library. It may be a long road", presses[1]["lines"][0])
        self.assertEqual(cleared["pane"], 0)
        self.assertIn("So you have found them all", cleared["lines"][0])
        self.assertEqual([b["id"] for b in cleared["buttons"]], ["leave"], "each secret is sold once")
        self.assertEqual(cleared["state"]["dungeons"], {key: "cleared" for key in HUT_CHAIN})
        self.assertEqual(cleared["state"]["gold"], 95000, "5000 gold in all")
        text = run_tool("walk", str(ROOT / "expanded_adventure" / "Old_Adventurers_Hut"))
        self.assertEqual(text.returncode, 0)
        self.assertIn("( ) Pay 1000 gold for the secret   not ready: You need 1000 gold for this; you carry 0.", text.stdout)
        self.assertIn('Press "Pay 1000 gold for the secret": 1000 gold paid, 99000 left; secret used 1 time', text.stdout)
        self.assertIn('Press "Pay 1000 gold for the secret": 1000 gold paid, 95000 left; secret5 used 1 time', text.stdout)
        self.assertIn("The hero clears The Forgotten Vault (forgotten_vault): cleared", text.stdout)
        self.assertIn("End: 95000 gold; uses hut.secret 1, hut.secret2 1, hut.secret3 1, hut.secret4 1, hut.secret5 1; "
                      "flags none; dungeons forgotten_vault cleared, drowned_library cleared, sunken_forge cleared, "
                      "hall_of_echoes cleared, planeswalkers_rest cleared.", text.stdout)

    def test_a_hero_who_cleared_only_the_first_vault_is_offered_the_second(self):
        """The state a save of the hut's 1.0.0 holds: the secret bought once
        and the vault cleared. `--press` plays exactly that and no more."""
        hut = str(ROOT / "expanded_adventure" / "Old_Adventurers_Hut")
        result = run_tool("walk", hut, "--site", "hut", "--press", "secret,clear", "--json")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        last = [step for step in json.loads(result.stdout)["sites"][0]["steps"] if step["kind"] == "pane"][-1]
        self.assertEqual(last["pane"], 4)
        self.assertEqual([b["id"] for b in last["buttons"]], ["secret2", "leave"])
        self.assertEqual(last["state"]["dungeons"], {"forgotten_vault": "cleared"})

    def test_a_place_may_have_16_panes_and_a_dungeon_lies_64_tiles_away_at_most(self):
        """Since 0.70.9 a place may have 16 panes (8 before). A dungeon's
        distance keeps its limits, min 40 and max 64: a land's tiles lie in
        a square of some sixty, so nothing farther could ever be raised."""
        with tempfile.TemporaryDirectory() as work:
            folder = shipped_sites_copy("Old_Adventurers_Hut", Path(work))
            path = folder / "sites.json"
            shipped = json.loads(path.read_text(encoding="utf-8"))

            def judged(panes: int, least: int, most: int) -> dict:
                sites = json.loads(json.dumps(shipped))
                hut = sites["sites"]["hut"]
                hut["panes"] = hut["panes"] + [json.loads(json.dumps(hut["panes"][-1])) for _ in range(panes - 12)]
                sites["dungeons"]["planeswalkers_rest"]["distance"] = {"min": least, "max": most}
                path.write_text(json.dumps(sites), encoding="utf-8")
                return ap.judge(str(folder), ap.find_game())

            self.assertEqual(len(shipped["sites"]["hut"]["panes"]), 12)
            for dungeon in shipped["dungeons"].values():
                self.assertLessEqual(dungeon["distance"]["min"], 40)
                self.assertLessEqual(dungeon["distance"]["max"], 64)
            for panes, least, most in ((16, 40, 64), (16, 2, 4), (13, 40, 40)):
                report = judged(panes, least, most)
                self.assertTrue(report["valid"], report["problems"])
            for panes, least, most, wanted in (
                    (17, 32, 64, "sites.json.sites.hut.panes: 17 entries; 1 to 16 are allowed."),
                    (16, 32, 65, "sites.json.dungeons.planeswalkers_rest.distance.max: 65 is outside 4..64."),
                    (16, 41, 64, "sites.json.dungeons.planeswalkers_rest.distance.min: 41 is outside 2..40."),
                    (16, 40, 30, None)):
                report = judged(panes, least, most)
                self.assertFalse(report["valid"], (panes, least, most))
                if wanted:
                    self.assertEqual(report["problems"], [wanted])

    def test_walk_copies_four_cards_at_the_guild_and_then_never(self):
        guild = str(ROOT / "expanded_adventure" / "Conjuration_Wizard_Guild")
        run = json.loads(run_tool("walk", guild, "--json").stdout)["sites"][0]
        presses = [step for step in run["steps"] if step["kind"] == "press"]
        self.assertEqual([p["paid"] for p in presses], [2000, 4000, 8000, 12000])
        self.assertEqual([p["label"] for p in presses], ["Copy a card (%d gold, %d left)" % pair for pair
                                                         in ((2000, 4), (4000, 3), (8000, 2), (12000, 1))])
        self.assertTrue(all(p["copied"] == ap.WALK_CARD for p in presses))
        self.assertIn("A copy of Stand-in Card is yours, for 12000 gold.", presses[-1]["lines"][0])
        self.assertEqual(presses[0]["journal"], ["Stand-in Card copied for 2000 gold."], "site.copied_log, the game's words")
        last = run["steps"][-1]
        self.assertEqual((last["pane"], [b["id"] for b in last["buttons"]], last["state"]["gold"]), (0, ["leave"], 74000))
        second = [s for s in run["steps"] if s["kind"] == "pane"][2]
        self.assertIn("\"Welcome back. The conjurers remember your face.\"", second["lines"], "a line behind used min 1")
        short = json.loads(run_tool("walk", guild, "--gold", "3000", "--site", "tower", "--json").stdout)["sites"][0]
        self.assertEqual([s["paid"] for s in short["steps"] if s["kind"] == "press"], [2000])
        self.assertEqual(short["steps"][-1]["buttons"][0]["why"], "You need 4000 gold for this; you carry 1000.")

    def test_walk_reads_every_condition_and_effect_and_refuses_what_it_cannot_walk(self):
        case = next(c for c in corpus()["cases"] if c["name"] == "good_sites_every_condition_and_effect")
        path = build_case(case, self.work, "Every")
        data = ap.judge(str(path), self.game)["data"]
        run = ap.walk_site(data, "cellar", 5000)
        self.assertEqual(run["land"], "island")
        state = run["steps"][-1]["state"]
        self.assertEqual(state["dungeons"], {"vault": "cleared"})
        self.assertEqual(state["uses"], {"cellar.tell": 2, "cellar.copy": 2, "cellar.raise@island": 1},
                         "the raise is counted for its land (finding 1.1 of 2026-11-22)")
        self.assertEqual(state["flags"], ["spent", "told"], "set, cleared by the raise, set again")
        self.assertEqual(state["gold"], 5000 - 100 - 200 - 50 + 10)
        self.assertEqual(run_tool("walk", str(path)).returncode, 0)
        island = run_tool("walk", str(FIXTURES / "good_minimal"))
        self.assertEqual(island.returncode, 2)
        self.assertIn("is an island plugin: walk plays a sites plugin's places.", island.stderr)
        self.assertEqual(run_tool("walk", str(self.folder), "--site", "nowhere").returncode, 2)
        (self.folder / "text.json").unlink()
        refused = run_tool("walk", str(self.folder))
        self.assertEqual(refused.returncode, 1)
        self.assertEqual(refused.stdout.splitlines()[0], "text.json is missing.")

    def test_the_walk_is_data_sites_mirrored(self):
        """SiteWalk's rules are DataSites': the lines it mirrors are in the
        game's source, and it reads every condition and effect of the schema."""
        source = gd("game/adventure/plugins/data_sites.gd")
        for line in ("const MOST_USES := %d" % ap.MOST_USES, "const MOST_AMULETS := %d" % ap.MOST_AMULETS,
                     "return int(prices[done]) if done < prices.size() else -1",
                     "return maxi(0, prices.size() - uses(player, site_key, String(action[\"id\"])))",
                     '"gold_at_least": return player.gold >= int(value)',
                     '"on_mainland": return AdventureRegions.mainland(player) == bool(value)',
                     'return done >= int(value.get("min", 0)) and done <= int(value.get("max", MOST_USES))',
                     'return done >= int(value.get("min", 1)) and done <= int(value.get("max", MOST_USES))',
                     '"has_card": return held(player, String(value["card"])) >= int(value.get("min", 1))',
                     '"gold_below": return player.gold < int(value)',
                     '"gift_waiting": return player.duel_gift_waiting() == bool(value)',
                     'return say("site.no_gold", {"price": cost, "gold": player.gold})',
                     'return say("site.done")',
                     'out["uses_left"] = left if left >= 0 else ""',
                     '"gold": player.gold = maxi(0, player.gold + int(value))',
                     '_per_land[key] = not (entry.get("prices", []) as Array).is_empty() and not spawned(entry).is_empty()',
                     '_count_key(player, site_key + "." + action + ("@" + land(player) if per_land(site_key, action) else ""))',
                     'var turn := day(player) if String(entry.get("by", "day")) == "day" else site_uses(player, site_key)',
                     'if not option.has("id") and holds(player, site_key, option.get("when", [])):',
                     'return say("site.needs_any_amulets", {"count": int(value.get("count", 1)), "amulets": player.amulet_count()})',
                     'return say("site.dungeon_open", {"dungeon": dungeon_word(player, String(value))})',
                     'player.amulets[color] = maxi(have, mini(MOST_AMULETS, have + count)) if count > 0 else maxi(0, have + count)',
                     'if String(entry.get("count", "press")) != "win":',
                     'pane["actions"] = [[id + AdventureSites.BACK + site_key, say("site.back"), true], [id + AdventureSites.LEAVE, say("site.leave"), true]]',
                     'var filled := values(player, site_key, {}, {"price": cost, "card": card})',
                     'return result_place(player, site_key, lines if not lines.is_empty() else [say("site.copied", filled)])',
                     'var lines: Array = (entry.get("result", []) as Array) + (now["result"] as Array)',
                     'return result_place(player, site_key, _lines(player, site_key, lines, after))'):
            self.assertIn(line, source, "DataSites no longer says: " + line)
        self.assertEqual(ap.DEFAULT_LABELS, gd_const(source, "LABELS"))
        self.assertEqual(ap.AMULET_COLORS, gd_const(source, "COLORS"))
        schema = ap.find_game().schema()["types"]
        holds = source[source.index("func _holds("):source.index("static func _named_condition(")]
        self.assertEqual([w for pair in re.findall(r'^\t\t"(\w+)"(?:, "(\w+)")?:', holds, re.M) for w in pair if w],
                         list(schema["sites_condition"]["options"]))
        apply = source[source.index("func apply("):source.index("func _reveal(")]
        self.assertEqual(sorted(re.findall(r'^\t\t\t"(\w+)"', apply, re.M) + ["roll", "teleport"]),
                         sorted(schema["sites_effect"]["options"]),
                         "a roll is drawn before apply (effects_now); a teleport moves the hero on the world screen")
        tool = SCRIPT.read_text(encoding="utf-8")
        walk = tool[tool.index("class SiteWalk:"):tool.index("def walk_site(")]
        for option in list(schema["sites_condition"]["options"]) + list(schema["sites_effect"]["options"]) \
                + list(schema["sites_need"]["options"]) + schema["sites_action"]["fields"]["do"]["values"]:
            self.assertIn('"%s"' % option, walk, option)
        for key in ("site.leave", "site.back", "site.pay", "site.no_gold", "site.done", "site.copied", "site.copied_log"):
            self.assertIn('"%s"' % key, walk)
            self.assertIn(key, ap.TEXT_DEFAULTS)

    def test_png_alpha_reads_every_filter_and_color_type(self):
        pixels = [[((x * 37 + y * 11) & 255, (x * 5) & 255, (y * 91) & 255, (x * y * 13 + x) & 255) for x in range(9)]
                  for y in range(10)]
        alpha = [bytes(p[3] for p in row) for row in pixels]
        self.assertEqual(ap.png_alpha(filtered_png(9, 10, pixels)), (9, 10, alpha))
        for kind in range(5):
            self.assertEqual(ap.png_alpha(filtered_png(9, 10, pixels, kinds=(kind,)))[2], alpha, "filter %d" % kind)
        gray = [[(p[0], p[3]) for p in row] for row in pixels]
        self.assertEqual(ap.png_alpha(filtered_png(9, 10, gray, color=4))[2], alpha)
        indexed = [[(x % 3,) for x in range(9)] for _ in range(10)]
        self.assertEqual(ap.png_alpha(filtered_png(9, 10, indexed, color=3, palette=bytes(9), trns=b"\x00\x80"))[2],
                         [bytes((0, 128, 255)[x % 3] for x in range(9))] * 10)
        self.assertEqual(ap.png_alpha(filtered_png(9, 10, [[p[:3] for p in row] for row in pixels], color=2)), (9, 10, None))
        self.assertEqual(ap.png_alpha(filtered_png(9, 10, indexed, color=3, palette=bytes(9))), (9, 10, None))
        sixteen = bytearray(filtered_png(9, 10, pixels))
        sixteen[24] = 16
        self.assertEqual(ap.png_alpha(bytes(sixteen)), "a 16-bit PNG")
        laced = bytearray(filtered_png(9, 10, pixels))
        laced[28] = 1
        self.assertEqual(ap.png_alpha(bytes(laced)), "an interlaced PNG")
        self.assertEqual(ap.png_alpha(ap._sprite(ap.SHRINE_ROWS, ap.SHRINE_COLORS))[2][10], bytes(9) + b"\xff" * 14 + bytes(9))

    def test_sprite_advice_measures_the_trim_the_scale_and_the_foot(self):
        def sprite(box, foot=None, size=(40, 30)):
            rows = [[(90, 60, 30, 255) if box[0] <= x < box[2] and box[1] <= y < box[3] else (0, 0, 0, 0)
                     for x in range(size[0])] for y in range(size[1])]
            if foot:
                for x in range(size[0]):
                    rows[box[3] - 1][x] = (90, 60, 30, 255 if foot[0] <= x < foot[1] else (40 if box[0] <= x < box[2] else 0))
            return filtered_png(size[0], size[1], rows)

        good = ap.sprite_advice("art/a.png", sprite((10, 4, 30, 24)), 20)
        self.assertEqual((good["used"], good["scale"], good["drawn_height"], good["foot_offset"], good["warnings"]),
                         ([10, 4, 20, 20], 1.0, 20.0, 0.0, []))
        self.assertIn("a whole number", good["notes"][0])
        self.assertEqual(good["transparent"], round(1 - 400 / 1200.0, 3))
        odd = ap.sprite_advice("art/a.png", sprite((10, 4, 30, 24)), 16)
        self.assertEqual(odd["scale"], 1.25)
        self.assertIn("1.25 source pixels to a world pixel", odd["notes"][0])
        self.assertIn("width 10 or 20", odd["notes"][0])
        leaning = ap.sprite_advice("art/a.png", sprite((10, 4, 30, 24), foot=(10, 14)), 20)
        self.assertEqual(leaning["foot_offset"], -8.0)
        self.assertIn("its foot stands 8 world pixels to the left of the middle", leaning["warnings"][0])
        wide = ap.sprite_advice("art/a.png", sprite((10, 4, 30, 24)), 160)
        self.assertIn("it is drawn 160 world pixels wide; a tile is 128 x 64", wide["warnings"][0])
        self.assertIn("each source pixel is drawn 8 world pixels wide", wide["notes"][0])
        block = ap.sprite_advice("art/a.png", sprite((0, 0, 40, 30)), 40)
        self.assertIn("no pixel is transparent", block["warnings"][0])
        flat = ap.sprite_advice("art/a.png", filtered_png(4, 4, [[(1, 2, 3)] * 4] * 4, color=2), 16)
        self.assertIn("it has no transparency", flat["warnings"][0])
        empty = ap.sprite_advice("art/a.png", sprite((0, 0, 0, 0)), 16)
        self.assertIn("every pixel is transparent", empty["warnings"][0])
        jpeg = ap.sprite_advice("art/a.jpg", bytes.fromhex("ffd8ffc0000b080010002003011100"), 32)
        self.assertFalse(jpeg["checked"])
        self.assertIn("not checked (a JPG picture)", jpeg["notes"][0])
        self.assertIn("a JPEG has no transparency", jpeg["warnings"][0])

    def test_pane_picture_advice_knows_the_panes_frame(self):
        self.assertEqual(ap.pane_picture_advice("a.png", png_header(1024, 560))["warnings"], [])
        small = ap.pane_picture_advice("a.png", png_header(128, 70))
        self.assertEqual((small["width"], small["height"], small["aspect"]), (128, 70, 1.83))
        self.assertIn("it is 128 pixels wide; under 512", small["warnings"][0])
        square = ap.pane_picture_advice("a.png", png_header(800, 800))
        self.assertIn("its shape is 1.00 : 1; the pane's frame is 512 x 280, about 1.83 : 1", square["warnings"][0])
        self.assertIn("top and bottom are cut", square["warnings"][0])
        self.assertIn("the sides are cut", ap.pane_picture_advice("a.png", png_header(2000, 500))["warnings"][0])

    def test_art_gives_advice_and_never_refuses(self):
        hut = run_tool("art", str(ROOT / "expanded_adventure" / "Old_Adventurers_Hut"), "--json")
        self.assertEqual(hut.returncode, 0, hut.stdout + hut.stderr)
        facts = json.loads(hut.stdout)
        row = facts["art"][0]
        self.assertEqual((row["place"], row["picture"]["key"], row["picture"]["aspect"]), ("hut", "old_hut_hut", 1.83))
        self.assertEqual((row["sprite"]["file"], row["sprite"]["drawn_width"]), ("art/old_hut_map.png", 104))
        self.assertTrue(row["sprite"]["checked"])
        self.assertGreater(row["sprite"]["transparent"], 0.2)
        self.assertEqual(row["sprite"]["scale"], round(row["sprite"]["used"][2] / 104.0, 3))
        skeleton = run_tool("art", str(self.folder))
        self.assertEqual(skeleton.returncode, 0, "advice is not a refusal")
        self.assertIn("advice: it is 128 pixels wide; under 512", skeleton.stdout)
        self.assertIn("each source pixel is drawn 5 world pixels wide", skeleton.stdout)
        self.assertIn("1 piece of advice. Advice only", skeleton.stdout)
        refuge = run_tool("art", str(PROTOTYPE))
        self.assertEqual(refuge.returncode, 0, refuge.stdout + refuge.stderr)
        self.assertIn("Refuge Harbor (port)", refuge.stdout)
        self.assertIn("art/refuge_castle_map.png: 1536 x 1024, drawn 192 world pixels wide", refuge.stdout)
        island = run_tool("art", str(FIXTURES / "good_minimal"))
        self.assertIn("visit_city, a skin picture", island.stdout)
        (self.folder / "sites.json").unlink()
        refused = run_tool("art", str(self.folder))
        self.assertEqual(refused.returncode, 1)
        self.assertEqual(refused.stdout.splitlines()[0], "sites.json is missing.")


class Review20261121Test(unittest.TestCase):
    """The whole-project review of 2026-11-21: the tool's seven findings."""

    def setUp(self):
        self.work = Path(tempfile.mkdtemp(prefix="plugin-review-"))
        self.folder = self.work / "Corpus_Sites"
        shutil.copytree(FIXTURES / "good_sites", self.folder)
        self.game = ap.find_game()

    def tearDown(self):
        shutil.rmtree(self.work, ignore_errors=True)

    def snapshot(self) -> dict:
        return {rel: (self.folder / rel).read_bytes() for rel in files_of(self.folder)}

    def everything(self) -> list:
        """Every file and folder under the plugin folder, the dotted ones too."""
        return sorted(str(p.relative_to(self.folder)) for p in self.folder.rglob("*"))

    def test_png_alpha_never_unpacks_more_than_the_picture(self):
        """A 1 x 1 picture whose data unpacks to 64 MiB was unpacked whole."""
        import tracemalloc

        def chunk(kind: bytes, body: bytes) -> bytes:
            return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

        bomb = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 6, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(bytes(64 * 1024 * 1024), 9)) + chunk(b"IEND", b""))
        self.assertLess(len(bomb), 128 * 1024)
        tracemalloc.start()
        try:
            read = ap.png_alpha(bomb)
            peak = tracemalloc.get_traced_memory()[1]
        finally:
            tracemalloc.stop()
        self.assertEqual(read, (1, 1, [b"\x00"]), "its one pixel is read")
        self.assertLess(peak, 4 * 1024 * 1024, "and no more than that is unpacked")
        # A picture cut short is damaged, as before; a whole one reads as before.
        pixels = [[(1, 2, 3, 200 + x) for x in range(4)] for _ in range(3)]
        whole = filtered_png(4, 3, pixels)
        self.assertEqual(ap.png_alpha(whole)[2], [bytes(200 + x for x in range(4))] * 3)
        short = filtered_png(4, 2, pixels[:2]).replace(struct.pack(">II", 4, 2), struct.pack(">II", 4, 3), 1)
        self.assertEqual(ap.png_alpha(short), "a damaged PNG")

    def compat(self, was: list, now: list) -> tuple:
        old = ap.judge(str(self.folder), self.game)["data"]
        new = json.loads(json.dumps(old))
        for data, prices in ((old, was), (new, now)):
            for pane in data["sites"]["sites"]["shrine"]["panes"]:
                for action in pane["actions"]:
                    if action["id"] == "bless":
                        action["prices"] = list(prices)
        return ap.compatibility(old, new)

    def test_compat_warns_when_a_save_may_find_an_action_used_up(self):
        """DataSites._count counts a free action's uses too."""
        self.assertIn('counted[key] = mini(MOST_USES, int(counted.get(key, 0)) + 1)',
                      gd("game/adventure/plugins/data_sites.gd"), "every use is counted, a free one too")
        warnings, notes = self.compat([], [100, 200])
        self.assertEqual(len(warnings), 1, (warnings, notes))
        self.assertIn("the action bless was free and now has prices (100, 200)", warnings[0])
        self.assertIn("used it 2 times or more finds it used up", warnings[0])
        self.assertEqual(notes, [])
        warnings, notes = self.compat([20, 40, 80], [20])
        self.assertEqual(len(warnings), 1, (warnings, notes))
        self.assertIn("prices changed (20, 40, 80 -> 20)", warnings[0])
        self.assertIn("finds it used up", warnings[0])
        # What loses nothing stays a note: a longer list, other prices, free again.
        for was, now, said in (([20, 40], [20, 40, 80], "(20, 40 -> 20, 40, 80)"), ([20, 40], [30, 50], "(20, 40 -> 30, 50)"),
                               ([20, 40], [], "(20, 40 -> free)")):
            warnings, notes = self.compat(was, now)
            self.assertEqual(warnings, [], (was, now))
            self.assertEqual(len(notes), 1)
            self.assertIn(said, notes[0])
            self.assertNotIn("used up", notes[0])
        self.assertEqual(self.compat([20, 40], [20, 40]), ([], []))

    def test_an_edit_that_is_stopped_puts_every_file_back(self):
        before, listed = self.snapshot(), self.everything()
        args = ap.parser().parse_args(["add-place", str(self.folder), "--id", "tower", "--name", "The Tower"])
        judge, write = ap.judge, ap._write_whole
        # The judgement of the edited folder fails (the second judgement:
        # the first is of the folder as it was).
        calls = []

        def failing_judge(*a, **k):
            calls.append(1)
            if len(calls) == 2:
                self.assertNotEqual(self.snapshot(), before, "the edit was written when it is judged")
                raise KeyboardInterrupt()
            return judge(*a, **k)

        ap.judge = failing_judge
        try:
            with self.assertRaises(KeyboardInterrupt):
                ap.command_add_place(args, self.game)
        finally:
            ap.judge = judge
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(self.everything(), listed, "no new picture, no art folder of its own, no .part file")

        # A file that cannot be written, after others were.
        def failing_write(target, data):
            if target.name == "text.json":
                raise OSError(28, "No space left on device")
            write(target, data)

        ap._write_whole = failing_write
        try:
            with self.assertRaises(ap.UsageError) as raised:
                ap.command_add_place(args, self.game)
        finally:
            ap._write_whole = write
        self.assertIn("could not be edited", str(raised.exception))
        self.assertIn("nothing was changed", str(raised.exception))
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(self.everything(), listed)
        # And the edit itself still goes through, whole.
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(ap.command_add_place(args, self.game), 0)
        self.assertTrue(ap.judge(str(self.folder), self.game)["valid"])
        self.assertFalse([name for name in self.everything() if name.endswith(".part")])

    @unittest.skipIf(os.name == "nt" or (hasattr(os, "geteuid") and os.geteuid() == 0), "needs file permissions")
    def test_an_edit_leaves_a_read_only_file_alone(self):
        (self.folder / "text.json").chmod(0o444)
        before, listed = self.snapshot(), self.everything()
        result = run_tool("add-place", str(self.folder), "--id", "tower", "--name", "The Tower")
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn("text.json is read-only", result.stderr)
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(self.everything(), listed)
        # A written file keeps the permissions it had.
        (self.folder / "text.json").chmod(0o640)
        self.assertEqual(run_tool("add-place", str(self.folder), "--id", "tower", "--name", "The Tower").returncode, 0)
        self.assertEqual((self.folder / "text.json").stat().st_mode & 0o777, 0o640)

    def test_add_place_says_at_once_when_its_picture_key_would_be_too_long(self):
        """corpus_sites + _ + the place's id is the picture's key, 40 characters at most."""
        before, listed = self.snapshot(), self.everything()
        long_id = "a" * 28
        result = run_tool("add-place", str(self.folder), "--id", long_id, "--name", "Far")
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertEqual(len(result.stderr.strip().splitlines()), 1)
        self.assertIn("--id %s is too long for this plugin" % long_id, result.stderr)
        self.assertIn("would be 41 characters, and 40 are the most; choose an id of at most 27 characters", result.stderr)
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(self.everything(), listed)
        fits = run_tool("add-place", str(self.folder), "--id", "a" * 27, "--name", "Near")
        self.assertEqual(fits.returncode, 0, fits.stdout + fits.stderr)

    def test_add_dungeon_writes_each_dungeons_own_name(self):
        """{dungeon} is the last dungeon raised on the land: with two, the
        first one's panes named the second."""
        for key, name in (("cellar", "The Dry Cellar"), ("attic", "The Dusty Attic")):
            done = run_tool("add-dungeon", str(self.folder), "--id", key, "--name", name, "--cards", "Swamp",
                            "--place", "shrine", "--price", "10")
            self.assertEqual(done.returncode, 0, done.stdout + done.stderr)
        data = ap.judge(str(self.folder), self.game)["data"]
        words = data["text"]
        for key, name in (("cellar", "The Dry Cellar"), ("attic", "The Dusty Attic")):
            for part in ("open", "cleared", "told", "clue"):
                self.assertIn(name, words["%s.%s" % (key, part)])
                self.assertNotIn("{dungeon}", words["%s.%s" % (key, part)])
        walk = ap.SiteWalk(data, 1000)
        walk.dungeons = {"cellar": "open", "attic": "open"}
        # {dungeon} with nothing to say which is the plugin's first now
        # (finding 1.6 of 2026-11-22; it was the last one raised), and a
        # pane that asks about a dungeon names that one.
        self.assertEqual(walk.values("shrine")["dungeon"], "The Dry Cellar")
        attic = next(p for p in data["sites"]["sites"]["shrine"]["panes"]
                     if p["when"] == [{"dungeon": {"dungeon": "attic", "state": "open"}}])
        self.assertEqual(walk.values("shrine", None, None, attic)["dungeon"], "The Dusty Attic")
        panes = data["sites"]["sites"]["shrine"]["panes"]
        cellar = next(p for p in panes if p["when"] == [{"dungeon": {"dungeon": "cellar", "state": "open"}}])
        self.assertTrue(walk.lines("shrine", cellar["lines"], walk.values("shrine"))[0].startswith(
            "The way to The Dry Cellar is known to you."))

    def test_walk_plays_a_place_on_each_land_it_stands_on(self):
        """A pane behind on_mainland false was never shown: a place on both
        lands was walked on the mainland alone."""
        sites = json.loads((self.folder / "sites.json").read_text(encoding="utf-8"))
        self.assertEqual(sites["sites"]["shrine"]["where"], ["mainland", "islands"])
        sites["sites"]["shrine"]["panes"].insert(0, {"when": [{"on_mainland": False}], "lines": ["shrine.far"],
                                                     "actions": [{"id": "leave", "do": "leave", "label": "shrine.leave"}]})
        (self.folder / "sites.json").write_text(json.dumps(sites, indent="\t") + "\n", encoding="utf-8")
        text = json.loads((self.folder / "text.json").read_text(encoding="utf-8"))
        text["shrine.far"] = "The shrine of the far shore."
        (self.folder / "text.json").write_text(json.dumps(text, indent="\t") + "\n", encoding="utf-8")
        result = run_tool("walk", str(self.folder), "--json")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        runs = json.loads(result.stdout)["sites"]
        self.assertEqual([(run["site"], run["land"]) for run in runs], [("shrine", "mainland"), ("shrine", "island")])
        home, far = runs
        self.assertNotIn(0, [s["pane"] for s in home["steps"] if s["kind"] == "pane"])
        self.assertEqual([s["pane"] for s in far["steps"] if s["kind"] == "pane"], [0])
        self.assertEqual(far["steps"][0]["lines"], ["The shrine of the far shore."])
        said = run_tool("walk", str(self.folder)).stdout
        self.assertLess(said.index("Wayside Shrine (shrine), on the mainland"), said.index("Wayside Shrine (shrine), on an island"))
        data = ap.judge(str(self.folder), self.game)["data"]
        self.assertEqual(ap.walk_lands(data, "shrine"), ["mainland", "island"])
        self.assertEqual(ap.walk_site(data, "shrine", 100)["land"], "mainland", "one walk alone: the first land")
        # A place on one land is walked once, as before.
        hut = json.loads(run_tool("walk", str(ROOT / "expanded_adventure" / "Old_Adventurers_Hut"), "--json").stdout)["sites"]
        self.assertEqual([run["land"] for run in hut], ["mainland"])

    def test_export_keeps_the_zip_already_there_when_the_new_one_is_refused(self):
        out = self.work / "dist"

        def export() -> int:
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                return ap.main(["export", str(self.folder), "--out", str(out)])

        self.assertEqual(export(), 0)
        target = out / "Corpus_Sites.zip"
        good = target.read_bytes()
        (self.folder / "text.json").write_text((self.folder / "text.json").read_text(encoding="utf-8") + "\n", encoding="utf-8")
        judge = ap.judge
        judged = []

        def refusing(path, *a, **k):
            result = judge(path, *a, **k)
            if str(path).endswith(".zip"):
                judged.append(Path(path))
                self.assertEqual(Path(path).name, "Corpus_Sites.zip", "judged under the name it will have")
                self.assertNotEqual(Path(path), target, "and not in the place of the old one")
                result = dict(result, valid=False, problems=["refused for the test"])
            return result

        ap.judge = refusing
        try:
            self.assertEqual(export(), 1)
        finally:
            ap.judge = judge
        self.assertEqual(len(judged), 1)
        self.assertEqual(target.read_bytes(), good, "the zip that was there is still there")
        self.assertEqual(sorted(p.name for p in out.iterdir()), ["Corpus_Sites.zip"], "nothing else is left in --out")
        # A zip the game takes replaces it.
        self.assertEqual(export(), 0)
        self.assertNotEqual(target.read_bytes(), good)
        self.assertEqual(sorted(p.name for p in out.iterdir()), ["Corpus_Sites.zip"])
        self.assertEqual(target.stat().st_mode & 0o777, 0o644)


class InfoTest(unittest.TestCase):
    def test_info_names_the_manifest_and_counts(self):
        result = run_tool("info", str(PROTOTYPE))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("refuge", result.stdout)
        self.assertIn("pack-2", result.stdout)
        self.assertIn("5 quests", result.stdout)
        self.assertIn("api_version:          1\n", result.stdout)
        facts = json.loads(run_tool("info", str(PROTOTYPE), "--json").stdout)
        self.assertEqual(facts["manifest"]["id"], "refuge")
        self.assertEqual(facts["content"]["quests"], 5)
        self.assertEqual(facts["by_kind"]["pictures"], 4)
        self.assertTrue(facts["valid"])


class CompatTest(unittest.TestCase):
    """`compat OLD NEW`: the corpus's pairs."""

    @classmethod
    def setUpClass(cls):
        cls.work = Path(tempfile.mkdtemp(prefix="plugin-compat-"))
        cls.data = corpus()

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.work, ignore_errors=True)

    def test_every_pair(self):
        top = self.data["base_top"]
        self.assertGreaterEqual(len(self.data["compat"]), 8)
        self.assertGreaterEqual(sum(1 for pair in self.data["compat"] if pair["name"].startswith("sites_")), 8)
        for pair in self.data["compat"]:
            with self.subTest(pair=pair["name"]):
                old = build_case(dict(pair["old"], name=pair["name"] + "_old"), self.work, top)
                new = build_case(dict(pair["new"], name=pair["name"] + "_new"), self.work, top)
                result = run_tool("compat", str(old), str(new))
                self.assertEqual(result.returncode, 0 if pair["compatible"] else 1, result.stdout + result.stderr)
                warnings = [l for l in result.stdout.splitlines() if not l.startswith("note: ")][:-1]
                self.assertEqual(len(warnings), len(pair.get("warnings", [])), result.stdout)
                for wanted in pair.get("warnings", []):
                    self.assertTrue(any(wanted in line for line in warnings), (wanted, result.stdout))
                for wanted in pair.get("notes", []):
                    self.assertIn(wanted, result.stdout)
                if not pair.get("notes"):
                    self.assertNotIn("note: ", result.stdout)

    def test_a_refused_plugin_is_said_and_exit_1(self):
        with tempfile.TemporaryDirectory() as work:
            bad = Path(work) / "bad"
            shutil.copytree(FIXTURES / "good_minimal", bad)
            (bad / "foes.json").unlink()
            result = run_tool("compat", str(FIXTURES / "good_minimal"), str(bad))
            self.assertEqual(result.returncode, 1)
            self.assertIn("The new plugin", result.stdout)
            self.assertIn("foes.json is missing.", result.stdout)


class GuideTest(unittest.TestCase):
    def test_the_reference_page_is_up_to_date(self):
        result = run_tool("guide", "--check")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_the_reference_page_names_every_file_type_and_placeholder(self):
        page = ap.guide_html(ap.find_game().schema(), ROOT / "expanded_adventure" / "GUIDE")
        schema = ap.find_game().schema()
        for anchor in ("file-world-json", "file-places-json", "file-quests-json", "file-foes-json",
                       "file-rewards-json", "file-text-json", "type-condition", "type-effect", "type-step",
                       "type-target", "limits", "placeholders", "manifest", "file-sites-json", "type-sites_file",
                       "type-sites_condition", "type-sites_effect", "type-sites_action", "type-sites_dungeon"):
            self.assertIn('id="%s"' % anchor, page)
        self.assertEqual(page.count('id="file-text-json"'), 1, "text.json is one section, the island's and the sites'")
        for name in schema["site_files"]:
            self.assertIn("<code>%s</code>" % name, page[page.index('id="file-sites-json"'):page.index('id="types"')])
        for name in schema["types"]:
            self.assertIn('id="type-%s"' % name, page)
        for placeholder in schema["placeholders"]:
            self.assertIn("{%s}" % placeholder, page)
        for option in schema["types"]["condition"]["options"]:
            self.assertIn("<code>%s</code>" % option, page)
        for option in schema["types"]["effect"]["options"]:
            self.assertIn("<code>%s</code>" % option, page)
        for group in ("sites_condition", "sites_effect"):
            section = page[page.index('id="type-%s"' % group):]
            section = section[:section.index("</section>")]
            for option in schema["types"][group]["options"]:
                self.assertIn("<code>%s</code>" % option, section, option)
        for key in ap.TEXT_DEFAULTS:
            self.assertIn("<code>%s</code>" % key, page)
        tables = re.findall(r'<table class="fields">(.*?)</table>', page, re.S)
        self.assertGreater(len(tables), 20)
        for table in tables:
            cells = re.findall(r"<td\b[^>]*>", table)
            self.assertTrue(cells)
            self.assertEqual([c for c in cells if "data-label=" not in c], [], "every cell names its column")
        hrefs = re.findall(r'href="#([^"]+)"', page)
        ids = set(re.findall(r'id="([^"]+)"', page))
        self.assertEqual([h for h in hrefs if h not in ids], [], "every in-page link lands")

    def test_the_manifest_table_uses_the_schemas_own_kinds(self):
        page = ap.guide_html(ap.find_game().schema(), ROOT / "expanded_adventure" / "GUIDE")
        manifest = page[page.index('id="manifest"'):page.index('id="file-world-json"')]
        kinds = [" ".join(re.findall(r'<span class="kind">([^<]*)</span>', cell))
                 for cell in re.findall(r'data-label="Kind">(.*?)</td>', manifest)]
        self.assertEqual(kinds, ["int", "int", "enum", "string", "string", "string", "string", "list of string",
                                 "string", "string", "string", "object", "object", "map"], "the schema's own kind words")
        names = re.findall(r'data-label="Field"><code>([^<]*)</code>', manifest)
        self.assertEqual(names, ap.FIELDS, "every manifest field, in the game's order")
        self.assertIn("required</span> of an island", manifest, "region: an island's alone")
        self.assertNotIn("whole number", manifest)
        self.assertNotIn(">text<", manifest, "a literal string is a string; text is a key of text.json")
        self.assertNotIn("misspelt", page)

    def test_the_page_is_local_and_follows_the_guide_skeleton(self):
        page = ap.guide_html(ap.find_game().schema(), ROOT / "expanded_adventure" / "GUIDE")
        self.assertNotIn("http://", page)
        self.assertNotIn("https://", page)
        self.assertNotIn("<script", page)
        self.assertIn('<link rel="stylesheet" href="guide.css">', page)
        self.assertIn("<title>Reference · Adventure plugin guide</title>", page)
        self.assertIn('<main class="page" id="top">', page)
        self.assertIn('<p class="generated">', page)
        self.assertEqual(page.count('aria-current="page"'), 1)
        self.assertRegex(page, r'<a[^>]*href="reference\.html"[^>]*aria-current="page"')
        self.assertIn('<a class="prev" href="cheatsheet.html">', page)
        self.assertIn('<a class="next" href="faq.html">', page)

    def test_without_an_index_page_it_falls_back_to_its_own_toc(self):
        with tempfile.TemporaryDirectory() as work:
            page = ap.guide_html(ap.find_game().schema(), Path(work))
            for page_name, _ in ap.GUIDE_PAGES:
                self.assertIn('href="%s"' % page_name, page)
            result = run_tool("guide", "--out", work)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue((Path(work) / "reference.html").is_file())
            self.assertEqual(run_tool("guide", "--out", work, "--check").returncode, 0)
            (Path(work) / "reference.html").write_text("old", encoding="utf-8")
            self.assertEqual(run_tool("guide", "--out", work, "--check").returncode, 1)


class CommandLineTest(unittest.TestCase):
    def test_help_version_and_usage_errors(self):
        result = run_tool("--help")
        self.assertEqual(result.returncode, 0)
        for command in ("new", "validate", "export", "info", "compat", "guide", "add-place", "add-dungeon", "walk",
                        "art"):
            self.assertIn(command, result.stdout)
            self.assertEqual(run_tool(command, "--help").returncode, 0, command)
        self.assertIn("Exit codes", result.stdout)
        version = run_tool("--version")
        self.assertEqual(version.returncode, 0)
        self.assertEqual(version.stdout.strip(), "adventure_plugin.py — Shandalar %s (adventure plugin API 3)"
                         % ap.find_game().version)
        self.assertEqual(run_tool().returncode, 2)
        self.assertEqual(run_tool("frobnicate").returncode, 2)
        self.assertEqual(run_tool("validate").returncode, 2)
        missing = run_tool("validate", "/nonexistent/plugin", "--json")
        self.assertEqual(missing.returncode, 2)
        self.assertEqual(json.loads(missing.stdout)["error"]["exit"], 2)
        self.assertIn("no such file or folder", missing.stderr)

    def test_the_game_folder_may_follow_any_command(self):
        for args in (["validate", "--game", str(ROOT), str(FIXTURES / "good_minimal")],
                     ["--game", str(ROOT), "validate", str(FIXTURES / "good_minimal")],
                     ["info", str(FIXTURES / "good_minimal"), "--game", str(ROOT)],
                     ["compat", "--game", str(ROOT), str(FIXTURES / "good_minimal"), str(FIXTURES / "good_minimal")]):
            with self.subTest(args=args):
                self.assertEqual(run_tool(*args).returncode, 0, args)
        with tempfile.TemporaryDirectory() as work:
            for command in (["new", str(Path(work) / "x"), "--id", "x", "--name", "X"], ["validate", work],
                            ["export", work], ["info", work], ["compat", work, work], ["guide", "--check"]):
                with self.subTest(command=command[0]):
                    result = run_tool(*command, "--game", work)
                    self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
                    self.assertIn("neither a game checkout nor a release folder", result.stderr)

    def test_a_file_that_is_neither_zip_nor_folder_is_refused_as_the_game_does(self):
        with tempfile.TemporaryDirectory() as work:
            stray = Path(work) / "plugin.txt"
            stray.write_text("hello", encoding="utf-8")
            result = run_tool("validate", str(stray))
            self.assertEqual(result.returncode, 1)
            self.assertEqual(result.stdout.splitlines()[0], "plugin.txt: not a .zip file or a folder.")


class GameFolderTest(unittest.TestCase):
    """Where the schema and the card lists come from."""

    def test_a_checkout_gives_the_base_cards_and_every_packs_list(self):
        game = ap.find_game()
        self.assertEqual(game.kind, "checkout")
        self.assertIn("Lightning Bolt", game.base)
        self.assertIn("Swamp", game.base)
        self.assertNotIn("Thallid", game.base, "a pack's own card is no base card")
        self.assertIn("Thallid", game.packs["pack-2"])
        self.assertEqual(len(game.packs["pack-2"]), 102, "FallenEmpiresPack.COUNTS distinct_cards")
        self.assertIn("pack-1", game.known_packs)
        self.assertIn("pack-10", game.known_packs)
        self.assertNotIn("pack-1", game.packs)
        self.assertEqual(game.version, ap._project_version(ROOT))

    def test_a_release_folder_reads_its_card_list(self):
        with tempfile.TemporaryDirectory() as work:
            release = Path(work) / "Shandalar-release"
            (release / "tools").mkdir(parents=True)
            shutil.copy(SCRIPT, release / "tools" / "adventure_plugin.py")
            (release / "tools" / ap.CARDS_FILE).write_bytes(ap.catalogue_bytes(ROOT))
            (release / ap.SCHEMA_REL).parent.mkdir(parents=True)
            shutil.copy(ROOT / ap.SCHEMA_REL, release / ap.SCHEMA_REL)
            folder = Path(work) / "Corpus_Isle"
            shutil.copytree(FIXTURES / "good_minimal", folder)
            tool = release / "tools" / "adventure_plugin.py"
            good = run_tool("validate", str(folder), tool=tool)
            self.assertEqual(good.returncode, 0, good.stdout + good.stderr)
            self.assertNotIn("not checked", good.stderr)
            foes = json.loads((folder / "foes.json").read_text(encoding="utf-8"))
            foes["foes"]["smuggler"]["deck"]["Thallid"] = 1
            (folder / "foes.json").write_text(json.dumps(foes), encoding="utf-8")
            bad = run_tool("validate", str(folder), tool=tool)
            self.assertEqual(bad.returncode, 1)
            self.assertIn("Thallid is not a card of the base game or of a required pack (none).", bad.stdout)
            self.assertIn("Shandalar " + ap.find_game().version, run_tool("--version", tool=tool).stdout)

    def test_without_card_lists_the_tool_says_it_did_not_check_them(self):
        with tempfile.TemporaryDirectory() as work:
            alone = Path(work) / "game"
            (alone / "tools").mkdir(parents=True)
            shutil.copy(SCRIPT, alone / "tools" / "adventure_plugin.py")
            (alone / ap.SCHEMA_REL).parent.mkdir(parents=True)
            shutil.copy(ROOT / ap.SCHEMA_REL, alone / ap.SCHEMA_REL)
            tool = alone / "tools" / "adventure_plugin.py"
            result = run_tool("validate", str(FIXTURES / "good_minimal"), tool=tool)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("Card names were not checked", result.stderr)
            self.assertIn("version unknown", run_tool("--version", tool=tool).stdout)
            (alone / ap.SCHEMA_REL).unlink()
            nothing = run_tool("validate", str(FIXTURES / "good_minimal"), tool=tool)
            self.assertEqual(nothing.returncode, 2)
            self.assertIn("schema_v1.json) was not found", nothing.stderr)
            self.assertEqual(run_tool("--game", str(ROOT), "validate", str(FIXTURES / "good_minimal"),
                                      tool=tool).returncode, 0)

    def test_the_release_card_list_is_names_only(self):
        listed = json.loads(ap.catalogue_bytes(ROOT))
        self.assertEqual(sorted(listed), ["about", "base", "format", "known_packs", "packs", "version"])
        self.assertTrue(all(isinstance(n, str) for n in listed["base"]))
        for names in listed["packs"].values():
            self.assertTrue(all(isinstance(n, str) for n in names))


# --------------------------------------------------------------------------
# THE TWINS against the game's GDScript
# --------------------------------------------------------------------------

def gd(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def gd_const(text: str, name: str):
    """A `const NAME ... = value` of a GDScript file: a list or a string as
    JSON, a whole number as arithmetic of literals."""
    found = re.search(r"^const %s\b[^=\n]*:?=\s*" % re.escape(name), text, re.M)
    if not found:
        raise AssertionError("no const " + name)
    rest = text[found.end():]
    if rest[0] in "[{":
        opening, closing = rest[0], "]" if rest[0] == "[" else "}"
        level, end = 0, 0
        for end, character in enumerate(rest):
            level += character == opening
            level -= character == closing
            if level == 0:
                break
        return json.loads(rest[:end + 1].replace("\t", " ").replace(",\n", ",").replace("\n", " ").replace(", }", "}")
                          .replace(", ]", "]"))
    line = rest.split("\n", 1)[0].split("#", 1)[0].strip()
    if line.startswith('"'):
        return json.loads(line)
    return eval(compile(ast.parse(line, mode="eval"), "<const>", "eval"), {"__builtins__": {}})


class DriftTest(unittest.TestCase):
    """The tool's copies of the game's rules are the game's rules."""

    def test_the_package_rules(self):
        text = gd("game/adventure/plugins/plugin_package.gd")
        for name in ("ALLOWED", "PICTURES", "TEXTS", "MAX_TOTAL", "MAX_FILES", "MAX_JSON", "MAX_OGG", "MAX_SIDE",
                     "MAX_PATH", "MAX_DEPTH", "MAX_FOLDERS", "MANIFEST", "LITTER", "LITTER_FOLDER"):
            self.assertEqual(getattr(ap, name), gd_const(text, name), name)

    def test_the_manifest_rules(self):
        text = gd("game/adventure/plugins/adventure_plugins.gd")
        for name in ("API_VERSION", "PLUGIN_FORMAT", "FOLDER_NAME", "ID_PATTERN", "RESERVED_IDS", "REQUIRED_FIELDS",
                     "FIELDS", "REGION_FIELDS", "MAX_NAME", "MAX_LINE", "MAX_TEXT", "MAX_AUTHORS", "MAX_PACKS",
                     "KIND_ISLAND", "KIND_SITES", "SITES_API"):
            self.assertEqual(getattr(ap, name), gd_const(text, name), name)
        # KINDS is written in the game by its two names.
        self.assertIn("const KINDS: Array[String] = [KIND_ISLAND, KIND_SITES]", text)
        self.assertEqual(ap.KINDS, [ap.KIND_ISLAND, ap.KIND_SITES])

    def test_the_content_rules(self):
        schema_gd = gd("game/adventure/plugins/plugin_schema.gd")
        self.assertEqual(ap.RESERVED_FLAGS, gd_const(schema_gd, "RESERVED_FLAGS"))
        self.assertEqual(ap.MARKERS, gd_const(schema_gd, "MARKERS"))
        self.assertIn('"res://%s"' % ap.SCHEMA_REL, schema_gd)
        text_gd = gd("game/adventure/plugins/plugin_text.gd")
        self.assertEqual(ap.PLACEHOLDERS, gd_const(text_gd, "PLACEHOLDERS"))
        block = text_gd[text_gd.index("const DEFAULTS := {"):]
        block = block[:block.index("\n}\n") + 3]
        pairs = re.findall(r'^\t"((?:[^"\\]|\\.)*)":\s*"((?:[^"\\]|\\.)*)",?$', block, re.M)
        self.assertEqual({json.loads('"%s"' % k): json.loads('"%s"' % v) for k, v in pairs}, ap.TEXT_DEFAULTS)
        self.assertEqual(list(ap.TEXT_DEFAULTS), [json.loads('"%s"' % k) for k, _ in pairs], "in the game's order")
        schema = json.loads((ROOT / ap.SCHEMA_REL).read_text(encoding="utf-8"))
        self.assertEqual(list(schema["placeholders"]), ap.PLACEHOLDERS)
        # The sites plugin's own checks are the game's _check_sites, line by line.
        self.assertIn("static func _check_sites(", schema_gd)
        self.assertIn("static func _check_site_conditions(", schema_gd)
        self.assertIn('var listed: Dictionary = spec["site_files"] if sites else spec["files"]', schema_gd)
        self.assertEqual(schema["api_version"], ap.API_VERSION)
        limits = schema["limits"]
        self.assertEqual((limits["plugin_bytes"], limits["files"], limits["json_bytes"], limits["json_depth"],
                          limits["picture_side"], limits["ogg_bytes"], limits["text_chars"], limits["id_pattern"],
                          limits["reserved_ids"], limits["path_chars"]),
                         (ap.MAX_TOTAL, ap.MAX_FILES, ap.MAX_JSON, ap.MAX_DEPTH, ap.MAX_SIDE, ap.MAX_OGG, ap.MAX_TEXT,
                          ap.ID_PATTERN, ap.RESERVED_IDS, ap.MAX_PATH))
        self.assertEqual(schema["extensions"]["allowed"], ["." + e for e in ap.ALLOWED])

    def test_the_palettes_packs_faces_and_card_folders(self):
        palette = gd("game/adventure/world/world_terrain_palette.gd")
        block = palette[palette.index("const PROFILES := {"):]
        block = block[:block.index("\n}\n")]
        constants = dict(re.findall(r'^const (\w+) := "([^"]*)"', palette, re.M))
        keys = [constants[k] for k in re.findall(r"^\t(\w+): \{", block, re.M)]
        self.assertEqual(ap.PALETTES, keys)
        self.assertEqual(ap.PALETTE_LAYERS, gd_const(palette, "LAYERS"))
        self.assertEqual(ap.PALETTE_PREFIX, gd_const(palette, "PLUGIN_PREFIX"))
        self.assertIn('if not key in ["name", "grass", "foliage", "water", "plain", "tints"]', palette)
        self.assertEqual(ap.IGNORED_PACKS, gd_const(gd("game/adventure/adventure_setup.gd"), "IGNORED_PACKS"))
        book = gd("game/adventure/creature_book.gd")
        rows = book[book.index("const ROWS: Array[Array] = ["):]
        rows = rows[:rows.index("\n]\n")]
        self.assertEqual(ap.CREATURE_ROWS, len(re.findall(r"^\t\[", rows, re.M)))
        self.assertEqual(ap.LAIR, gd_const(book, "LAIR"))
        self.assertEqual(ap.SET_ORDER, gd_const(gd("engine/card_registry.gd"), "SET_ORDER"))

    def test_the_messages_the_corpus_does_not_reach_are_still_the_games(self):
        """Each problem sentence of the tool appears in the game's own source
        (its format, the placeholders aside): a reworded game message fails
        here even when no corpus case reaches it."""
        sources = "".join(gd(rel) for rel in ("game/adventure/plugins/plugin_package.gd",
                                             "game/adventure/plugins/adventure_plugins.gd",
                                             "game/adventure/plugins/plugin_schema.gd",
                                             "game/adventure/world/world_terrain_palette.gd"))
        tool = SCRIPT.read_text(encoding="utf-8")
        body = tool[tool.index("# STAGE 1"):tool.index("# THE GAME'S LISTS")] \
            + tool[tool.index("# STAGE 2"):tool.index("# THE STAGES, in the game's order")]
        body = "\n".join(line for line in body.splitlines() if "notes.append" not in line)
        phrases = set()
        for literal in re.findall(r'"((?:[^"\\\n]|\\.)*%[sd](?:[^"\\\n]|\\.)*)"', body):
            words = re.split(r"%[sd.0-9f]+", literal)
            phrases.update(w for w in words if len(w) >= 18)
        self.assertGreater(len(phrases), 40)
        sources_flat = sources.replace('\\"', '"')
        missing = [p for p in sorted(phrases) if p.replace('\\"', '"') not in sources_flat]
        self.assertEqual(missing, [], "tool sentences the game does not say")


@unittest.skipUnless(os.environ.get("SHANDALAR_PLUGIN_EXPORT_GODOT"),
                     "set SHANDALAR_PLUGIN_EXPORT_GODOT for the compiled-export check")
class CompiledExportTest(unittest.TestCase):
    def test_plugin_json_survives_compiled_export(self):
        # A source-only test cannot catch a BOM constant decoded as an empty
        # string in Godot's token buffer (4.7.2). Exercise the actual loader,
        # with BOM bytes constructed at runtime so the fixture survives too.
        godot = os.environ["SHANDALAR_PLUGIN_EXPORT_GODOT"]
        with tempfile.TemporaryDirectory(prefix="plugin-export-") as work:
            folder = Path(work)
            shutil.copyfile(ROOT / "game/adventure/plugins/plugin_package.gd", folder / "package.gd")
            (folder / "project.godot").write_text(
                'config_version=5\n[application]\n'
                'config/name="Shandalar Plugin Export Regression"\n'
                'run/main_scene="res://probe.tscn"\n', encoding="utf-8")
            (folder / "probe.tscn").write_text(
                '[gd_scene load_steps=2 format=3]\n'
                '[ext_resource type="Script" path="res://probe.gd" id="1"]\n'
                '[node name="Probe" type="Node"]\nscript = ExtResource("1")\n', encoding="utf-8")
            (folder / "probe.gd").write_text('''extends Node
const Package = preload("res://package.gd")
func _ready():
	var checks := 0
	for value in ['{"plugin_format":1}', "{}", "[]", "null", '{"title":"Éire"}']:
		for bom in [false, true]:
			var bytes = value.to_utf8_buffer()
			if bom:
				bytes = PackedByteArray([0xef, 0xbb, 0xbf]) + bytes
			var result = Package.json("probe.json", bytes)
			if result.problem != "" or result.value != JSON.parse_string(value):
				printerr("PLUGIN JSON FAILED: ", result)
				get_tree().quit(1)
				return
			checks += 1
	for value in ["{", "[1,]bad", "invalid"]:
		if Package.json("probe.json", value.to_utf8_buffer()).problem == "":
			printerr("INVALID PLUGIN JSON ACCEPTED")
			get_tree().quit(1)
			return
		checks += 1
	print("PLUGIN JSON EXPORT: ", checks, " checks passed")
	get_tree().quit()
''', encoding="utf-8")
            (folder / "export_presets.cfg").write_text(
                '[preset.0]\nname="Parser"\nplatform="Linux"\n'
                'export_filter="all_resources"\ninclude_filter=""\nexclude_filter="*.pck,*.log"\n'
                'script_export_mode=2\n[preset.0.options]\n'
                'binary_format/architecture="x86_64"\n', encoding="utf-8")
            env = dict(os.environ)
            env.pop("GODOT_EDITOR_CUSTOM_FEATURES", None)
            pack = folder / "parser.pck"
            for label, args in [
                ("export", ["--path", str(folder), "--export-pack", "Parser", str(pack)]),
                ("run", ["--main-pack", str(pack), "--quit-after", "30"]),
            ]:
                result = subprocess.run(
                    [godot, "--headless", "--log-file", str(folder / (label + ".log")), *args],
                    cwd=folder, env=env, stdin=subprocess.DEVNULL,
                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                    text=True, encoding="utf-8", timeout=180)
                self.assertEqual(result.returncode, 0, result.stdout)
                self.assertNotIn("ERROR:", result.stdout)
                if label == "run":
                    self.assertIn("PLUGIN JSON EXPORT: 13 checks passed", result.stdout)


if __name__ == "__main__":
    unittest.main()

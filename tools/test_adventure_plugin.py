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
"""
from __future__ import annotations

import ast
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
        for name in ("good_minimal", "good_exported_zip", "zip_symlink", "manifest_newer_api", "bad_card_name"):
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
                       "type-target", "limits", "placeholders", "manifest"):
            self.assertIn('id="%s"' % anchor, page)
        for name in schema["types"]:
            self.assertIn('id="type-%s"' % name, page)
        for placeholder in schema["placeholders"]:
            self.assertIn("{%s}" % placeholder, page)
        for option in schema["types"]["condition"]["options"]:
            self.assertIn("<code>%s</code>" % option, page)
        for option in schema["types"]["effect"]["options"]:
            self.assertIn("<code>%s</code>" % option, page)
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
        self.assertEqual(kinds, ["int", "int", "string", "string", "string", "string", "list of string", "string",
                                 "string", "string", "object", "object", "map"], "the schema's own kind words")
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
        self.assertIn('<a class="prev" href="refuge.html">', page)
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
        for command in ("new", "validate", "export", "info", "compat", "guide"):
            self.assertIn(command, result.stdout)
        self.assertIn("Exit codes", result.stdout)
        version = run_tool("--version")
        self.assertEqual(version.returncode, 0)
        self.assertEqual(version.stdout.strip(), "adventure_plugin.py — Shandalar %s (adventure plugin API 1)"
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
                     "FIELDS", "REGION_FIELDS", "MAX_NAME", "MAX_LINE", "MAX_TEXT", "MAX_AUTHORS", "MAX_PACKS"):
            self.assertEqual(getattr(ap, name), gd_const(text, name), name)

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


if __name__ == "__main__":
    unittest.main()

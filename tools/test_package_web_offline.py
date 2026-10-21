"""Offline packaging never silently rebuilds the game or ships personal art."""
import hashlib
import json
import re
import struct
import subprocess
import sys
import tempfile
import unittest
import warnings
import zipfile
from pathlib import Path

import package_web_offline as offline


class OfflinePackageTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.folder = self.root / "input"
        self.folder.mkdir()
        self.files = {
            "VERSION.txt": b"0.50.34\n", "README.txt": b"Original source: public commit\n",
            "index.html": b"<html><head><title>Game</title></head><body>game</body></html>", "index.js": b"engine-js",
            "index.pck": b"game-pck", "index.wasm": b"engine-wasm",
            "index.icon.png": b"\x89PNG\r\n\x1a\n" + bytes(8) + struct.pack(">II", 256, 256),
            "index.apple-touch-icon.png": b"icon", "tools/tool_banner.py": b"# placeholder",
        }

    def source(self, skin=False):
        files = dict(self.files)
        if skin:
            files["skin/original_skin.zip"] = b"original skin unchanged"
        files["SHA256SUMS"] = "".join(f"{offline.digest(data)}  {name}\n"
                                      for name, data in sorted(files.items())).encode()
        path = self.root / f"Shandalar-0.50.34-web{'-with-skin' if skin else ''}.zip"
        with zipfile.ZipFile(path, "w") as archive:
            for name, data in files.items():
                archive.writestr("Shandalar-0.50.34-web/" + name, data)
        return path

    def unpack(self, path):
        with zipfile.ZipFile(path) as archive:
            return {name.split("/", 1)[1]: archive.read(name) for name in archive.namelist()}

    def test_plain_and_skin_keep_every_game_byte_and_cover_all_files(self):
        for skin in (False, True):
            with self.subTest(skin=skin):
                source = self.source(skin)
                output = offline.package(source, self.root / "out")
                data = self.unpack(output)
                for name in offline.REQUIRED:
                    self.assertEqual(data[name], self.files[name])
                self.assertEqual(offline.original_html(data["index.html"].decode()).encode(), self.files["index.html"])
                self.assertNotIn("play.html", data)
                self.assertFalse(any("launcher" in name for name in data))
                self.assertEqual(data["index.html"].split(b"<body>")[1], self.files["index.html"].split(b"<body>")[1])
                self.assertEqual("skin/original_skin.zip" in data, skin)
                self.assertIn(offline.digest(source.read_bytes()).encode(), data["README.txt"])
                self.assertIn(b"HTTPS", data["OFFLINE-SETUP.txt"])
                self.assertIn(b"device OS", data["OFFLINE-SETUP.txt"])
                for name in ("index.html", "offline.js", "OFFLINE-SETUP.txt"):
                    self.assertNotIn(b"ipad", data[name].lower())
                self.assertIn("tools/web_offline/sha256.js", data)
                sums = dict((name, value) for value, name in
                            (line.split("  ", 1) for line in data["SHA256SUMS"].decode().splitlines()))
                self.assertEqual(set(sums), set(data) - {"SHA256SUMS"})
                for name, value in sums.items():
                    self.assertEqual(value, offline.digest(data[name]))
                config = json.loads(re.search(rb'const CONFIG = (.*);', data["offline-sw.js"])[1])
                listed = {file["url"] for file in config["files"]}
                self.assertEqual("skin/original_skin.zip" in listed, skin)
                self.assertNotIn("README.txt", listed)
                self.assertNotIn("tools/tool_banner.py", listed)

    def test_reproducible_and_will_not_overwrite(self):
        source = self.source()
        first = offline.package(source, self.root / "a")
        second = offline.package(source, self.root / "b")
        self.assertEqual(first.read_bytes(), second.read_bytes())
        with self.assertRaisesRegex(ValueError, "already exists"):
            offline.package(source, self.root / "a")

    def test_packaged_tool_runs_in_isolated_python(self):
        output = offline.package(self.source(), self.root / "out")
        with zipfile.ZipFile(output) as archive:
            archive.extractall(self.folder)
        script = next(self.folder.iterdir()) / "tools/package_web_offline.py"
        for option in ("-h", "--version"):
            result = subprocess.run([sys.executable, "-I", str(script), option],
                                    cwd=self.root, text=True, capture_output=True, timeout=20)
            self.assertEqual(result.returncode, 0, result.stderr)
            # Like the other packaged Python tools, no checkout means the
            # shared banner may report version unknown rather than guess.
            self.assertIn("package_web_offline.py" if option == "--version" else "--refresh", result.stdout)

    def test_modified_input_refused(self):
        source = self.source()
        with zipfile.ZipFile(source, "a") as archive:
            archive.writestr("Shandalar-0.50.34-web/unlisted.txt", b"surprise")
        with self.assertRaisesRegex(ValueError, "SHA256SUMS"):
            offline.package(source, self.root / "a")

    def test_private_art_and_override_refused(self):
        for name in ("skin/cardart.zip", "cardpacks/Pack-9-Tempest.zip", "override.cfg"):
            with self.subTest(name=name):
                self.files[name] = b"private"
                with self.assertRaises(ValueError):
                    offline.package(self.source(), self.root / "a")
                self.files.pop(name)

    def test_path_traversal_and_duplicates_refused(self):
        for name in ("../escape", "Shandalar-0.50.34-web/../escape", "Shandalar-0.50.34-web/index.js"):
            with self.subTest(name=name):
                source = self.source()
                with warnings.catch_warnings():
                    warnings.simplefilter("ignore", UserWarning)
                    with zipfile.ZipFile(source, "a") as archive:
                        archive.writestr(name, b"bad")
                with self.assertRaisesRegex(ValueError, "Unsafe|duplicate"):
                    offline.package(source, self.root / "a")

    def test_threaded_input_refused(self):
        self.files["index.worker.js"] = b"thread worker"
        with self.assertRaisesRegex(ValueError, "threaded"):
            offline.package(self.source(), self.root / "a")

    def test_refresh_only_runtime_changes_change_cache_version(self):
        output = offline.package(self.source(), self.root / "out")
        with zipfile.ZipFile(output) as archive:
            archive.extractall(self.folder)
        folder = next(self.folder.iterdir())
        first = offline.prepare(folder)
        self.assertEqual(first, offline.prepare(folder))
        (folder / "local-private-note.txt").write_text("not a browser asset")
        (folder / "index.private-note.txt").write_text("not a browser asset either")
        self.assertEqual(first, offline.prepare(folder))
        (folder / "index.js").write_bytes(b"changed-engine")
        changed = offline.prepare(folder)
        self.assertNotEqual(first["build"], changed["build"])
        (folder / "skin").mkdir()
        (folder / "skin/cardart.zip").write_bytes(b"private-host-only")
        refreshed = offline.prepare(folder)
        self.assertNotEqual(changed["build"], refreshed["build"])
        self.assertIn("skin/cardart.zip", [file["url"] for file in refreshed["files"]])


if __name__ == "__main__":
    unittest.main()

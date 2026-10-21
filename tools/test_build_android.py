"""Offline gates for the separate experimental phone/tablet export."""
import configparser
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest

import build_android as build
import package_release as pack


def guide_text(path: Path) -> str:
    """The guide with its line breaks folded, so a sentence reads whole."""
    return " ".join(path.read_text(encoding="utf-8").split())


class AndroidBuildTest(unittest.TestCase):
    def test_version_code(self):
        self.assertEqual(build.version_code("0.50.34"), 50034)
        self.assertGreater(build.version_code("0.51.0"), build.version_code("0.50.999"))
        for version in ("0.50", "0.50.1000", "1.1000.0", "0.0.0", "2101.0.0"):
            with self.subTest(version=version), self.assertRaises(ValueError):
                build.version_code(version)

    def test_recipe_is_separate_from_quest(self):
        recipe = (build.ROOT / "packaging/android/export-preset.cfg").read_text()
        version = build.tool_banner.project_version(build.ROOT)
        self.assertIsNotNone(version)
        code = build.version_code(version)
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = root / "export_presets.cfg"
            path.write_text(recipe)
            build.check_preset(root, version)
            path.write_text('[preset.0.options]\nssh="a\nb"\n' + recipe)
            build.check_preset(root, version)
            for old, new in ((build.PACKAGE, pack.QUEST_PACKAGE),
                             ('custom_features=""', 'custom_features="shandalar_test"'),
                             ('architectures/x86_64=false', 'architectures/x86_64=true'),
                             (f'version/code={code}', 'version/code=1')):
                path.write_text(recipe.replace(old, new))
                with self.subTest(old=old), self.assertRaises(ValueError):
                    build.check_preset(root, version)
            path.write_text(recipe.split('[preset.9.options]')[0])
            with self.assertRaisesRegex(ValueError, "missing its options"):
                build.check_preset(root, version)
            path.write_text((build.ROOT / "export_presets.cfg.example").read_text())
            build.check_preset(root, version)
        cfg = configparser.ConfigParser(interpolation=None)
        cfg.read_string(recipe)
        self.assertEqual(cfg['preset.9.options']['permissions/internet'], 'true')
        self.assertNotIn("push_to_quest.sh", pack.HANDHELD_FILES['android-arm64-experimental'])

    def test_the_guide_sends_numbered_packs_to_the_card_folder(self):
        # Review of 2026-10-21 (nettools-1): ANDROID.md told players to import
        # "completed optional card packs" through the game's chooser, which
        # takes only skin and card-picture ZIPs (SkinPack.inspect refuses an
        # entry outside skin/, and every numbered pack is card_packs/<pack>/).
        # The packs are read from the app's own cardpacks folder, which only
        # adb reaches; the guide now says so, with the folder the game reads.
        guide = guide_text(build.ROOT / "docs/android-experimental.md")
        self.check_pack_route(guide)

    def check_pack_route(self, guide: str):
        paths = (build.ROOT / "game/paths.gd").read_text(encoding="utf-8")
        self.assertIn('DEFAULT_CARDPACKS := "user://cardpacks"', paths)
        folder = f"/sdcard/Android/data/{build.PACKAGE}/files/cardpacks/"
        self.assertIn("adb push Pack-1-DotP-complete.zip /sdcard/Download/", guide)
        self.assertIn(f"adb shell cp /sdcard/Download/Pack-1-DotP-complete.zip {folder}", guide)
        self.assertIn("That chooser takes only skin and card-picture ZIPs", guide)
        self.assertNotIn("import them through the game's chooser", guide)

    def test_isolated_help_and_version(self):
        with tempfile.TemporaryDirectory() as tmp:
            for flag in ("-h", "--version"):
                result = subprocess.run(
                    [sys.executable, "-I", str(build.ROOT / "tools/build_android.py"), flag],
                    cwd=tmp, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=30)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stderr, "")
                if flag == "--version":
                    self.assertIn(build.tool_banner.project_version(build.ROOT), result.stdout)

    def test_arm64_and_16k_alignment(self):
        data = bytearray(120)
        data[:6] = b"\x7fELF\x02\x01"
        struct.pack_into("<H", data, 18, 183)
        struct.pack_into("<Q", data, 32, 64)
        struct.pack_into("<HH", data, 54, 56, 1)
        struct.pack_into("<I", data, 64, 1)
        struct.pack_into("<Q", data, 112, 16384)
        build.check_elf(data)
        struct.pack_into("<Q", data, 112, 4096)
        with self.assertRaisesRegex(ValueError, "16 KiB"):
            build.check_elf(data)
        with self.assertRaises(ValueError):
            build.check_elf(b"truncated")


if __name__ == "__main__":
    unittest.main()

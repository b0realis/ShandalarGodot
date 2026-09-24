"""Offline regression tests for the public release package boundary."""
import hashlib
import json
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
import zipfile

import package_release as pack


class PackageReleaseTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "source"
        self.folder = Path(self.temp.name) / "export"
        self.out = Path(self.temp.name) / "packages"
        self.folder.mkdir()
        self.skin = Path(self.temp.name) / "original_skin.zip"
        with zipfile.ZipFile(self.skin, "w") as archive:
            archive.writestr("skin/frame.png", b"frame")
        for name in (*("tools/" + n for n in pack.TOOLS), "LICENSE",
                     "docs/setup.txt", "docs/skin-catalogue.txt",
                     "docs/releases/1.2.3.md", "DeckLab/README.md", "game/icon.png",
                     "docs/setup-web.txt", "docs/card-art-and-packs.md"):
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"fixture")
        (self.root / "project.godot").write_text('config/version="1.2.3"\n')
        for name in (*("tools/" + n for n in pack.TOOLS), *pack.BUILDER_DATA):
            dest = self.root / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(pack.ROOT / name, dest)
        (self.root / pack.BASE_ASSIGNMENTS).write_text(
            json.dumps(sorted(pack.pack_one.assigned_pairs())), encoding='utf-8')
        shutil.copyfile(pack.ROOT / 'docs/card-art-and-packs.md',
                        self.root / 'docs/card-art-and-packs.md')

    def make_export(self, platform):
        family = "macos" if platform in pack.MAC_PLATFORMS else platform
        names = {
            "linux64": ("Shandalar.x86_64", "Shandalar.pck"),
            "raspberry-pi5-arm64": ("Shandalar.arm64", "Shandalar.pck"),
            "windows64": ("Shandalar.exe", "Shandalar.console.exe", "Shandalar.pck"),
            "web": ("index.html", "index.js", "index.wasm", "index.pck", "index.audio.worklet.js"),
            "macos": ("Shandalar.app/Contents/MacOS/Shandalar",
                      "Shandalar.app/Contents/Resources/Shandalar.pck",
                      "Shandalar.app/Contents/Info.plist",
                      "Shandalar.app/Contents/_CodeSignature/CodeResources"),
        }[family]
        for name in names:
            path = self.folder / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"export bytes")
        (self.folder / "cardart.zip").write_bytes(b"private card pictures")
        (self.folder / "smoke.log").write_text("diagnostic log")
        return names

    def build(self, platform):
        return pack.package(self.folder, self.out, platform, self.skin,
                            "a" * 40, self.root)

    def test_all_platforms_two_packages_checksums_and_metadata(self):
        for platform in pack.PLATFORMS:
            with self.subTest(platform=platform):
                names = self.make_export(platform)
                for output, included in zip(self.build(platform), (False, True)):
                    with zipfile.ZipFile(output) as archive:
                        prefix = f"Shandalar-1.2.3-{platform}/"
                        entries = archive.namelist()
                        for name in names:
                            self.assertIn(prefix + name, entries)
                        for name in (*pack.BUILDER_DATA, pack.BASE_ASSIGNMENTS):
                            self.assertIn(prefix + name, entries)
                        self.assertEqual(prefix + "skin/original_skin.zip" in entries, included)
                        self.assertFalse(any("cardart.zip" in name or ".log" in name for name in entries))
                        for entry in archive.infolist():
                            self.assertEqual(entry.extra, b"")
                            self.assertFalse(stat.S_ISLNK(entry.external_attr >> 16))
                        for line in archive.read(prefix + "SHA256SUMS").decode().splitlines():
                            checksum, name = line.split("  ", 1)
                            self.assertEqual(hashlib.sha256(archive.read(prefix + name)).hexdigest(), checksum)
                        readme = archive.read(prefix + "README.txt").decode()
                        self.assertIn('tools/fetch_card_art.py --out cache/cardart', readme)
                        self.assertIn('build cardpacks/Pack-5-Alliances.zip', readme)
                        self.assertIn('build cardpacks/Pack-6-Portal.zip', readme)
                        self.assertIn('browser import/auto-fetch path', readme)
                        self.assertIn("LAN SGManalink", readme)
                        self.assertNotIn("Manalink multiplayer are future features", readme)
                        if platform in pack.LINUX_BINARIES or platform in pack.MAC_PLATFORMS:
                            self.assertEqual(archive.getinfo(prefix + "run.sh").external_attr >> 16 & 0o777, 0o755)
                        if platform in pack.LINUX_BINARIES:
                            binary = pack.LINUX_BINARIES[platform]
                            self.assertEqual(archive.getinfo(prefix + binary).external_attr >> 16 & 0o777, 0o755)
                            self.assertIn(binary, archive.read(prefix + "run.sh").decode())
                            self.assertIn(binary, archive.read(prefix + "deck_lab.sh").decode())
                        if platform in pack.MAC_PLATFORMS:
                            entry = archive.getinfo(prefix + "Shandalar.app/Contents/MacOS/Shandalar")
                            self.assertEqual(entry.external_attr >> 16 & 0o777, 0o755)
                        if platform == "web" and included:
                            self.assertIn("fetches it into browser storage", readme)
                        if platform == "raspberry-pi5-arm64":
                            launcher = archive.read(prefix + "run.sh").decode()
                            self.assertIn("--rendering-driver opengl3_es", launcher)
                            self.assertIn("--max-fps 60", launcher)

    def test_architecture_specific_launch_instructions(self):
        self.assertIn("arm64", pack.START["macos-arm64"])
        self.assertIn("x86-64", pack.START["macos-intel"])
        self.assertNotIn("Universal:", pack.START["macos-intel"])
        self.assertIn("64-bit desktop OS", pack.START["raspberry-pi5-arm64"])

    def test_all_numbered_builders_are_bundled(self):
        self.make_export('linux64')
        ignored = self.root / 'packaging/card_packs/pack_1_dotp_complete'
        (ignored / 'download-cache.jpg').write_bytes(b'private art')
        (ignored / pack.LOCAL_PACK).write_bytes(b'local only')
        with zipfile.ZipFile(self.build('linux64')[0]) as archive:
            prefix = 'Shandalar-1.2.3-linux64/tools/'
            for name in ('pack_1_dotp_complete.py', 'pack_2_fallen_empires.py',
                         'pack_3_ice_age.py', 'pack_4_homelands.py',
                         'pack_5_alliances.py', 'fetch_cards.py', 'gen_cards.py'):
                self.assertIn(prefix + name, archive.namelist())
            self.assertFalse(any(name.endswith(('.jpg', pack.LOCAL_PACK))
                                 for name in archive.namelist()))

    def test_extracted_builders_work_without_source_checkout(self):
        self.make_export('linux64')
        extracted = Path(self.temp.name) / 'unpacked'
        with zipfile.ZipFile(self.build('linux64')[0]) as archive:
            archive.extractall(extracted)
        standalone = extracted / 'Shandalar-1.2.3-linux64'
        self.assertFalse((standalone / 'cards/sets').exists())
        self.assertFalse((standalone / 'project.godot').exists())
        for builder in pack.PACK_BUILDERS:
            script = standalone / 'tools' / (builder + '.py')
            for args in (['--help'], ['--version']):
                result = subprocess.run([sys.executable, '-I', str(script), *args],
                                        cwd=standalone, capture_output=True, text=True, timeout=20)
                self.assertEqual(result.returncode, 0, result.stderr)
        # Build/verify fixture-only metadata ZIPs offline, exercising all source
        # dependencies; real-art rebuilds are also run when refreshing releases.
        for builder, filename in zip(pack.PACK_BUILDERS, (
                'Pack-1-DotP-complete.zip', 'Pack-2-Fallen-Empires.zip',
                'Pack-3-Ice_Age.zip', 'Pack-4-Homelands.zip', 'Pack-5-Alliances.zip',
                'Pack-6-Portal.zip')):
            for command in ('build', 'verify'):
                result = subprocess.run([
                    sys.executable, '-I', str(standalone / 'tools' / (builder + '.py')),
                    command, str(standalone / 'cardpacks' / filename), '--metadata-only'],
                    cwd=standalone, capture_output=True, text=True, timeout=20)
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_missing_builder_metadata_refuses_before_output(self):
        self.make_export('linux64')
        (self.root / pack.BUILDER_DATA[-1]).unlink()
        with self.assertRaises(OSError):
            self.build('linux64')
        self.assertFalse(self.out.exists())

    def test_legacy_staging_uses_same_bundle_and_is_safe_to_repeat(self):
        pack.stage_player_tools(self.folder, self.root)
        for name in (*pack.player_tool_files(self.root), pack.BASE_ASSIGNMENTS):
            self.assertTrue((self.folder / name).is_file(), name)
        before = (self.folder / 'README.txt').read_bytes()
        pack.stage_player_tools(self.folder, self.root)
        self.assertEqual((self.folder / 'README.txt').read_bytes(), before)
        changed = self.folder / 'tools/fetch_cards.py'
        changed.write_text('player change', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'Refusing to overwrite'):
            pack.stage_player_tools(self.folder, self.root)
        self.assertEqual(changed.read_text(), 'player change')
        source = (pack.ROOT / 'build_release.sh').read_text(encoding='utf-8')
        self.assertEqual(source.count('stage_player_tools(Path(sys.argv[1]))'), 2)

    def test_card_pack_and_traversal_are_refused(self):
        for name in ("skin/cardart/island.jpg", "skin/../secret", "/skin/frame.png", "skin\\frame.png"):
            with self.subTest(name=name):
                with zipfile.ZipFile(self.skin, "w") as archive:
                    archive.writestr(name, b"payload")
                with self.assertRaises(ValueError):
                    pack.check_skin(self.skin)

    def test_missing_payload_refuses_before_output(self):
        with self.assertRaises(ValueError):
            self.build("linux64")
        self.assertFalse(self.out.exists())

    def test_overwrite_is_refused(self):
        self.make_export("linux64")
        outputs = self.build("linux64")
        before = [pack.digest(p) for p in outputs]
        with self.assertRaises(ValueError):
            self.build("linux64")
        self.assertEqual(before, [pack.digest(p) for p in outputs])

    def test_override_inside_mac_app_is_refused(self):
        self.make_export("macos")
        (self.folder / "Shandalar.app/Contents/Resources/override.cfg").write_text("test profile")
        with self.assertRaises(ValueError):
            self.build("macos")

    def test_local_pack_inside_mac_app_is_refused(self):
        self.make_export("macos")
        path = self.folder / "Shandalar.app/Contents/Resources" / pack.LOCAL_PACK
        path.write_bytes(b"must remain a local construction artifact")
        with self.assertRaisesRegex(ValueError, "must not be released"):
            self.build("macos")

    def test_fallen_empires_pack_inside_mac_app_is_refused(self):
        self.make_export("macos")
        path = self.folder / "Shandalar.app/Contents/Resources/Pack-2-Fallen-Empires.zip"
        path.write_bytes(b"local only")
        with self.assertRaisesRegex(ValueError, "must not be released"):
            self.build("macos")

    def test_card_art_inside_mac_app_is_refused(self):
        # The macOS payload is the only one gathered by rglob, so a ZIP
        # dropped where the README says not to ("Keep skin/ BESIDE
        # Shandalar.app") rode into both release ZIPs and their
        # SHA256SUMS. The card art is the one file this project never
        # publishes (licence), so it must stop the package.
        for name in ("cardart.zip", "original_skin.zip", "my_pictures.zip"):
            with self.subTest(name=name):
                self.make_export("macos")
                path = self.folder / "Shandalar.app/Contents/Resources" / name
                path.write_bytes(b"pictures that are not ours to publish")
                with self.assertRaisesRegex(ValueError, "must not be released"):
                    self.build("macos")
                self.assertFalse(self.out.exists())
                path.unlink()

    def test_home_path_in_binary_is_refused(self):
        self.make_export("linux64")
        (self.folder / "Shandalar.x86_64").write_bytes(str(Path.home()).encode())
        with self.assertRaises(ValueError):
            self.build("linux64")

    def test_symlink_payload_is_refused(self):
        self.make_export("linux64")
        binary = self.folder / "Shandalar.x86_64"
        binary.unlink()
        binary.symlink_to(self.root / "LICENSE")
        with self.assertRaises(ValueError):
            self.build("linux64")


if __name__ == "__main__":
    unittest.main()

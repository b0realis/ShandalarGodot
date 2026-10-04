"""Offline checks for the dedicated Alliances construction tool."""
import tempfile
import subprocess
import unittest
import warnings
from unittest.mock import patch
import zipfile
from pathlib import Path

import pack_5_alliances as pack
import pack_1_dotp_complete as first

class PackFiveTests(unittest.TestCase):
    def test_release_guard_refuses_each_numbered_pack_but_allows_source(self):
        source = (pack.ROOT / 'build_release.sh').read_text(encoding='utf-8')
        guard = 'guard_stage() {' + source.split('guard_stage() {', 1)[1].split('\n}\n', 1)[0] + '\n}\n'
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'pack_5_alliances.py').write_text('# construction source\n')
            def check():
                # build_release.sh runs from its own folder (it cd's there), and
                # guard_stage names tools/package_release.py from it: so does this.
                return subprocess.run(['bash', '-c', guard + 'guard_stage "$1"', 'guard-test', str(root)],
                                      capture_output=True, text=True, cwd=str(pack.ROOT))
            self.assertEqual(check().returncode, 0)
            for filename in ['Pack-1-DotP-complete.zip', 'Pack-2-Fallen-Empires.zip', 'Pack-3-Ice_Age.zip', 'Pack-4-Homelands.zip', pack.FILE_NAME]:
                archive = root / filename
                archive.write_bytes(b'local only')
                result = check()
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('local artifacts', result.stderr)
                archive.unlink()

    def test_full_checklist_and_independent_names(self):
        manifest, catalog, cards, _ = pack.assembled()
        names = {row['name'] for row in cards}
        self.assertEqual(len(names), 144)
        self.assertEqual(len(pack.read_json(pack.SOURCE / 'cards.json')), 199)
        self.assertEqual(set(catalog['sets']), {'all'})
        self.assertEqual(set(catalog['sets']['all']['names']), names)
        self.assertEqual(names & {name for _, name in first.assigned_pairs()},
                         set(pack.read_json(pack.SOURCE / 'reprint_names.json')))
        self.assertEqual(len(manifest['new_rules_identities']), 144)
        self.assertEqual(len(set(manifest['new_rules_identities'])), 144)
        self.assertEqual(manifest['id'], 'pack-5')
        self.assertEqual(len(pack.art_targets(Path('unused'))), 288)

    def test_deterministic_art_archive_and_no_scripts(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for path, _, _ in pack.art_targets(root / 'art'):
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b'\xff\xd8test\xff\xd9')
            out = root / pack.FILE_NAME
            again = root / 'again' / pack.FILE_NAME
            pack.build(out, root / 'art')
            pack.build(again, root / 'art')
            self.assertEqual(out.read_bytes(), again.read_bytes())
            self.assertEqual(pack.verify(out)['checksums']['artwork']['files'], 576)
            with zipfile.ZipFile(out) as archive:
                self.assertEqual(len(archive.namelist()), 580)
                self.assertFalse(any(name.endswith('.gd') for name in archive.namelist()))
                for name in pack.read_json(pack.SOURCE / 'reprint_names.json'):
                    self.assertNotIn('skin/cardart/' + pack.fetch_card_art.snake(name) + '.jpg', archive.namelist())

    def test_metadata_only_is_not_a_player_pack(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / pack.FILE_NAME
            pack.build(out, include_art=False)
            pack.verify(out, require_art=False)
            with self.assertRaises(ValueError):
                pack.verify(out)

    def test_extra_and_duplicate_entries_are_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / pack.FILE_NAME
            pack.build(out, include_art=False)
            with zipfile.ZipFile(out, 'a') as archive:
                archive.writestr('injected.gd', 'extends Node')
            with self.assertRaisesRegex(ValueError, 'unexpected'):
                pack.verify(out, require_art=False)
            pack.build(out, include_art=False)
            with warnings.catch_warnings():
                warnings.simplefilter('ignore', UserWarning)
                with zipfile.ZipFile(out, 'a') as archive:
                    archive.writestr(pack.PREFIX + 'README.txt', 'duplicate')
            with self.assertRaisesRegex(ValueError, 'duplicate'):
                pack.verify(out, require_art=False)

    def test_failed_verification_does_not_replace_previous_pack(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / pack.FILE_NAME
            pack.build(out, include_art=False)
            before = out.read_bytes()
            with patch.object(pack, 'verify', side_effect=ValueError('test failure')):
                with self.assertRaises(ValueError):
                    pack.build(out, include_art=False)
            self.assertEqual(out.read_bytes(), before)
            self.assertEqual(list(out.parent.iterdir()), [out])

if __name__ == '__main__':
    unittest.main()

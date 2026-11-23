#!/usr/bin/env python3
"""The in-game pack builder against the Python pack tools (2026-11-23).

The game builds the numbered packs and the 1997 card pictures itself
(game/pack_builder/). Its recipes are a port of these tools, and
tests/unit/test_c1123_pack_recipes.gd holds the port to what the tools
say: the SHA-256 of every metadata file, of the manifest before its
checksums, and of the sorted lists of zip entries and downloaded files.
Those digests live in tests/fixtures/c1123_pack_digests.json; this test
keeps that fixture equal to what the tools compute today, so a change to
a pack's trusted data shows here first, with the way to refresh it:

    python3 tools/test_c1123_pack_digests.py --write
"""
from __future__ import annotations

import hashlib
import importlib
import json
import sys
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent
FIXTURE = ROOT / 'tests' / 'fixtures' / 'c1123_pack_digests.json'
MODULES = ['pack_1_dotp_complete', 'pack_2_fallen_empires', 'pack_3_ice_age',
           'pack_4_homelands', 'pack_5_alliances', 'pack_6_portal',
           'pack_7_fifth_edition', 'pack_8_mirage_block', 'pack_9_tempest_block',
           'pack_10_urza_block']
sys.path.insert(0, str(TOOLS))


def sha(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def lines(names) -> str:
    return sha('\n'.join(sorted(names)).encode('utf-8'))


def pack(number: int) -> dict:
    tool = importlib.import_module(MODULES[number - 1])
    manifest, catalog, cards, readme = tool.assembled()
    prefix = tool.PREFIX
    unused = Path('unused')
    if number == 1:
        art = tool.art_targets(unused, cards)
        new = {name for group in tool.MISSING.values() for name in group}
        names = [prefix + 'art/%s/%s' % (row['set'], path.name) for path, row, _ in art]
        names += ['skin/cardart/' + path.name for path, row, _ in art if row['name'] in new]
        pictures = {row['set'] + '/' + path.name for path, row, _ in art}
    elif number <= 5:
        code = manifest['set_order'][0]
        art = tool.art_targets(unused, cards)
        names = []
        for path, row, _ in art:
            names.append(prefix + 'art/%s/%s' % (code, path.name))
            if number == 2 or row['name'] in manifest['new_rules_identities']:
                names.append('skin/cardart/' + path.name)
        pictures = {code + '/' + path.name for path, _, _ in art}
    else:
        if number == 6:
            fallback = set(manifest['new_rules_identities']) | tool.SHARED_NAMES
        elif number == 7:
            fallback = tool.shared_names()
        else:
            fallback = tool.fallback_names(manifest)
        names = [name for name, _ in tool.archive_art_targets(unused, cards, fallback)]
        pictures = {row['set'] + '/' + path.name
                    for path, row, _ in tool.art_targets(unused, cards)}
    if len(names) != len(set(names)):
        raise ValueError('Pack %d lists a zip entry twice' % number)
    return {
        'file_name': tool.FILE_NAME,
        'name': manifest['name'],
        'catalog.json': sha(tool.json_bytes(catalog)),
        'cards.json': sha(tool.json_bytes(cards)),
        'README.txt': sha(readme.encode('utf-8')),
        'manifest': sha(tool.json_bytes(manifest)),
        'art_entries': len(names),
        'art_names': lines(names),
        'pictures': len(pictures),
        'picture_names': lines(pictures),
        'jobs': len(cards),
    }


def base() -> dict:
    import fetch_card_art
    pool = fetch_card_art.pool()
    files = [path.name for name, _ in pool
             for path, _ in fetch_card_art.targets_for(name, Path('unused'))]
    return {
        'jobs': len(pool),
        'pictures': len(set(files)),
        'picture_names': lines(set(files)),
        'pool': sha('\n'.join('%s|%s' % pair for pair in pool).encode('utf-8')),
    }


def digests() -> dict:
    out = {str(number): pack(number) for number in range(1, len(MODULES) + 1)}
    out['base'] = base()
    return out


def fixture_text(value: dict) -> str:
    return json.dumps(value, indent=1, ensure_ascii=False, sort_keys=True) + '\n'


class PackDigests(unittest.TestCase):
    def test_fixture_is_what_the_pack_tools_compute(self):
        self.assertTrue(FIXTURE.is_file(), 'missing %s' % FIXTURE.name)
        kept = json.loads(FIXTURE.read_text(encoding='utf-8'))
        now = digests()
        for key in sorted(now):
            self.assertEqual(kept.get(key), now[key],
                             'the digests of %s changed: refresh the fixture with '
                             'python3 tools/test_c1123_pack_digests.py --write, then run '
                             'tests/unit/test_c1123_pack_recipes.gd' % key)
        self.assertEqual(sorted(kept), sorted(now))

    def test_every_pack_has_a_tool_and_the_exact_file_name(self):
        now = digests()
        self.assertEqual(len(now), 11)
        for number in range(1, 11):
            self.assertRegex(now[str(number)]['file_name'], r'^Pack-%d-.+\.zip$' % number)


if __name__ == '__main__':
    if '--write' in sys.argv[1:]:
        FIXTURE.parent.mkdir(parents=True, exist_ok=True)
        FIXTURE.write_text(fixture_text(digests()), encoding='utf-8')
        print('wrote', FIXTURE.name)
    else:
        unittest.main()

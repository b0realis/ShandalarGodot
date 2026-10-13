#!/usr/bin/env python3
"""Build, fetch, or verify the separate Alliances gameplay pack.

Only construction source is distributed. Card art and the built ZIP stay
local; the archive contains data and images, never executable scripts.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fetch_cards
import fetch_card_art
import tool_banner

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'packaging/card_packs/pack_5_alliances'
PREFIX = 'card_packs/pack_5_alliances/'
FILE_NAME = 'Pack-5-Alliances.zip'
DEFAULT_OUT = ROOT.parent / 'shandalar-packs' / FILE_NAME
DEFAULT_ART = ROOT.parent / 'shandalar-packs/cache/pack_5_art'
TOOL = 'pack_5_alliances.py'
WORDMARK = ('┌─┐┌─┐┌─┐┬┌─  ┌─┐', '├─┘├─┤│  ├┴┐  └─┐', '┴  ┴ ┴└─┘┴ ┴  └─┘')
CAPTION = ('Shandalar · gameplay pack 5', 'Alliances — local construction')
HINT = (
    'python3 tools/pack_5_alliances.py fetch      # refresh the set data',
    'python3 tools/pack_5_alliances.py fetch-art  # fetch the set artwork',
    'python3 tools/pack_5_alliances.py            # build the local ZIP',
    'python3 tools/pack_5_alliances.py verify     # validate the ZIP',
)

def read_json(path):
    return json.loads(path.read_text(encoding='utf-8'))

def json_bytes(value):
    return (json.dumps(value, indent=2, ensure_ascii=False, sort_keys=True) + '\n').encode('utf-8')

def sha256(payload):
    return hashlib.sha256(payload).hexdigest()

def artwork_sha256(entries):
    digest = hashlib.sha256()
    for name, payload in sorted(entries):
        digest.update(name.encode('utf-8') + b'\0' + sha256(payload).encode('ascii') + b'\n')
    return digest.hexdigest()

def fetch():
    meta = fetch_cards.scryfall_get('https://api.scryfall.com/sets/all')
    url = meta['search_uri']
    rows = []
    while url:
        page = fetch_cards.scryfall_get(url)
        rows.extend(page['data'])
        url = page.get('next_page') if page.get('has_more') else None
    if len(rows) != page['total_cards'] or any(row['set'] != 'all' for row in rows):
        raise ValueError('incomplete or mixed Scryfall response')
    records = [fetch_cards.trim(row, 'all') for row in rows]
    SOURCE.mkdir(parents=True, exist_ok=True)
    (SOURCE / 'cards.json').write_bytes(json_bytes(records))
    (SOURCE / 'set.json').write_bytes(json_bytes({
        'code': 'all', 'name': meta['name'], 'released_at': meta['released_at'],
        'standard_printings': meta['card_count'], 'all_printings': len(records),
        'unique_names': len({row['name'] for row in records}),
        'source_url': meta['search_uri'],
    }))
    print('Alliances: %d printings, %d unique names' %
          (len(records), len({row['name'] for row in records})))

def assembled():
    rows = read_json(SOURCE / 'cards.json')
    by_name = {}
    for row in rows:
        if row.get('set') != 'all':
            raise ValueError('Pack 5 must contain only Alliances')
        by_name.setdefault(row['name'], row)
    cards = list(by_name.values())
    if len(rows) != 199 or len(cards) != 144:
        raise ValueError('Alliances checklist changed; review before building')
    # Checked against the original 897-card registry and preceding packs.
    # The trusted snapshot avoids needing a running Godot registry or other
    # installed packs; the source metadata and sibling Python helpers remain
    # required when distributing this construction tool.
    reprints = set(read_json(SOURCE / 'reprint_names.json'))
    if len(reprints) != 0 or not reprints <= set(by_name):
        raise ValueError('Alliances reprint checklist changed; review before building')
    added = sorted(set(by_name) - reprints)
    counts = {'published_printings': len(rows), 'named_set_entries': len(cards),
              'distinct_cards': len(cards), 'pack_card_entries': len(cards),
              'reprint_entries': len(cards) - len(added), 'new_rules_identities': len(added)}
    manifest = read_json(SOURCE / 'manifest.json')
    manifest['counts'] = counts
    manifest['new_rules_identities'] = added
    catalog = {'pack_format': 1, 'pack_id': 'pack-5', 'counts': counts,
               'sets': {'all': {'names': sorted(by_name), 'named_cards': len(cards),
                                'published_printings': len(rows)}}}
    return manifest, catalog, cards, (SOURCE / 'README.txt').read_text(encoding='utf-8')

def art_targets(art_dir, cards=None):
    cards = assembled()[2] if cards is None else cards
    return [(path, row, variant) for row in cards
            for path, variant in fetch_card_art.targets_for(row['name'], art_dir / 'all')]

def fetch_art(art_dir):
    failed = 0
    cards = assembled()[2]
    for index, row in enumerate(cards, 1):
        targets = fetch_card_art.targets_for(row['name'], art_dir / 'all')
        missing = [(path, variant) for path, variant in targets if not path.is_file()]
        if missing:
            for path, _ in missing:
                path.parent.mkdir(parents=True, exist_ok=True)
            _, bad = fetch_card_art.fetch_missing_art(row['name'], 'all', missing)
            failed += bad
        if index % 10 == 0 or index == len(cards):
            print('Alliances artwork: %d/%d names' % (index, len(cards)), flush=True)
    if failed or any(not path.is_file() for path, _, _ in art_targets(art_dir)):
        raise ValueError('artwork is incomplete; rerun fetch-art to resume')

def _write(zf, name, payload):
    info = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = 0o100644 << 16
    zf.writestr(info, payload)

def build(out, art_dir=DEFAULT_ART, include_art=True):
    if out.name != FILE_NAME:
        raise ValueError('pack must be named exactly ' + FILE_NAME)
    manifest, catalog, cards, readme = assembled()
    metadata = {'catalog.json': json_bytes(catalog), 'cards.json': json_bytes(cards),
                'README.txt': readme.encode('utf-8')}
    artwork = []
    if include_art:
        for path, row, _ in art_targets(art_dir, cards):
            if not path.is_file():
                raise ValueError('missing artwork; run %s fetch-art first' % TOOL)
            payload = path.read_bytes()
            artwork.append((PREFIX + 'art/all/' + path.name, payload))
            if row['name'] in manifest['new_rules_identities']:
                artwork.append(('skin/cardart/' + path.name, payload))
    manifest['checksums'] = {
        'algorithm': 'sha256',
        'metadata': {name: sha256(payload) for name, payload in metadata.items()},
        'artwork': {'files': len(artwork), 'sha256': artwork_sha256(artwork)},
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    # A failed fetch/build/verification must never damage an existing pack.
    with tempfile.TemporaryDirectory(prefix='.pack-5-', dir=out.parent) as tmp:
        staged = Path(tmp) / FILE_NAME
        with zipfile.ZipFile(staged, 'w') as zf:
            _write(zf, PREFIX + 'manifest.json', json_bytes(manifest))
            for name, payload in metadata.items():
                _write(zf, PREFIX + name, payload)
            for name, payload in artwork:
                _write(zf, name, payload)
        verify(staged, require_art=include_art)
        os.replace(staged, out)
    print('Pack 5: 144 unique cards · 199 printings -> %s' % out)

def verify(path, require_art=True):
    if path.name != FILE_NAME:
        raise ValueError('pack must be named exactly ' + FILE_NAME)
    manifest, catalog, cards, readme = assembled()
    metadata = {'catalog.json': json_bytes(catalog), 'cards.json': json_bytes(cards),
                'README.txt': readme.encode('utf-8')}
    with zipfile.ZipFile(path) as zf:
        names = zf.namelist()
        if len(names) != len(set(names)):
            raise ValueError('duplicate ZIP entries')
        art_names = set()
        for target, row, _variant in art_targets(Path('unused'), cards):
            art_names.add(PREFIX + 'art/all/' + target.name)
            if row['name'] in manifest['new_rules_identities']:
                art_names.add('skin/cardart/' + target.name)
        base = {PREFIX + name for name in metadata} | {PREFIX + 'manifest.json'}
        if set(names) != base | art_names:
            if require_art or set(names) != base:
                raise ValueError('unexpected or missing ZIP entries')
            art_names.clear()
        actual = json.loads(zf.read(PREFIX + 'manifest.json'))
        for key, value in manifest.items():
            if actual.get(key) != value:
                raise ValueError('manifest contract mismatch: ' + key)
        for name, payload in metadata.items():
            if zf.read(PREFIX + name) != payload:
                raise ValueError('metadata differs from the trusted source: ' + name)
        expected_checksums = {
            'algorithm': 'sha256',
            'metadata': {name: sha256(payload) for name, payload in metadata.items()},
            'artwork': {'files': len(art_names), 'sha256': artwork_sha256(
                [(name, zf.read(name)) for name in art_names])},
        }
        if actual.get('checksums') != expected_checksums:
            raise ValueError('checksum mismatch')
    return actual

def main(argv=None):
    parser = argparse.ArgumentParser(prog=TOOL, description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='\n'.join(HINT) + '\n\n' + tool_banner.BANNER_HELP)
    tool_banner.add_version_flag(parser, TOOL, __file__)
    parser.add_argument('command', nargs='?', default='build',
                        choices=['fetch', 'fetch-art', 'build', 'verify'])
    parser.add_argument('path', nargs='?', type=Path, default=DEFAULT_OUT)
    parser.add_argument('--art-dir', type=Path, default=DEFAULT_ART)
    parser.add_argument('--metadata-only', action='store_true', help=argparse.SUPPRESS)
    args = parser.parse_args(argv)
    tool_banner.show(WORDMARK, CAPTION, __file__, hint=HINT, argv=argv)
    try:
        if args.command == 'fetch':
            fetch()
        elif args.command == 'fetch-art':
            fetch_art(args.art_dir)
        elif args.command == 'verify':
            verify(args.path, require_art=not args.metadata_only)
            print('ok: ' + str(args.path))
        else:
            build(args.path, args.art_dir, include_art=not args.metadata_only)
    except (OSError, ValueError, zipfile.BadZipFile, KeyError) as error:
        print('%s: %s' % (TOOL, error), file=sys.stderr)
        return 1
    return 0

if __name__ == '__main__':
    raise SystemExit(main())

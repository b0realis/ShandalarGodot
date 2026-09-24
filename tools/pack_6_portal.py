#!/usr/bin/env python3
"""Build, fetch, or verify the separate Portal gameplay pack.

Only construction source is distributed. Card art and the built ZIP stay
local; the archive contains data and images, never executable scripts.
"""
from __future__ import annotations

import argparse
from datetime import date
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile
import urllib.parse
import urllib.request
import time
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fetch_cards
import fetch_card_art
import tool_banner

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'packaging/card_packs/pack_6_portal'
PREFIX = 'card_packs/pack_6_portal/'
FILE_NAME = 'Pack-6-Portal.zip'
DEFAULT_OUT = ROOT.parent / 'shandalar-packs' / FILE_NAME
DEFAULT_ART = ROOT.parent / 'shandalar-packs/cache/pack_6_art'
TOOL = 'pack_6_portal.py'
SHARED_NAMES = {'Dry Spell', 'Elvish Ranger', 'Mountain Goat', "Nature's Lore", 'Pyroclasm', 'Storm Crow'}
WORDMARK = ('┌─┐┌─┐┌─┐┬┌─  ┌─┐', '├─┘├─┤│  ├┴┐  ├─┐', '┴  ┴ ┴└─┘┴ ┴  └─┘')
CAPTION = ('Shandalar · gameplay pack 6', 'Portal — local construction')
HINT = (
    'python3 tools/pack_6_portal.py fetch      # refresh the set data',
    'python3 tools/pack_6_portal.py fetch-art  # fetch the set artwork',
    'python3 tools/pack_6_portal.py            # build the local ZIP',
    'python3 tools/pack_6_portal.py verify     # validate the ZIP',
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
    meta = fetch_cards.scryfall_get('https://api.scryfall.com/sets/por')
    url = meta['search_uri']
    rows = []
    while url:
        page = fetch_cards.scryfall_get(url)
        rows.extend(page['data'])
        url = page.get('next_page') if page.get('has_more') else None
    if len(rows) != page['total_cards'] or any(row['set'] != 'por' for row in rows):
        raise ValueError('incomplete or mixed Scryfall response')
    records = select_original(rows)
    SOURCE.mkdir(parents=True, exist_ok=True)
    (SOURCE / 'cards.json').write_bytes(json_bytes(records))
    (SOURCE / 'set.json').write_bytes(json_bytes({
        'code': 'por', 'name': meta['name'], 'released_at': meta['released_at'],
        'standard_printings': 215, 'all_printings': len(records),
        'unique_names': len({row['name'] for row in records}),
        'source_url': meta['search_uri'],
        'selection': 'Original English numbered printings 1–215; excludes demo/starter and foreign variants.',
        'retrieved_at': date.today().isoformat(),
    }))
    print('Portal: %d printings, %d unique names' %
          (len(records), len({row['name'] for row in records})))

def select_original(rows):
    """The original English numbered set, not starter/demo/foreign variants."""
    selected = [r for r in rows if r.get('lang') == 'en'
                and r.get('collector_number', '').isascii()
                and r.get('collector_number', '').isdigit()]
    if (len(selected) != 215 or {int(r['collector_number']) for r in selected}
            != set(range(1, 216))):
        raise ValueError('Portal original checklist changed; review before building')
    return [fetch_cards.trim(r, 'por') | {'scryfall_id': r['id']}
            for r in sorted(selected, key=lambda r: int(r['collector_number']))]

def assembled():
    rows = read_json(SOURCE / 'cards.json')
    by_name = {}
    for row in rows:
        if row.get('set') != 'por':
            raise ValueError('Pack 6 must contain only Portal')
        by_name.setdefault(row['name'], row)
    cards = rows
    if len(rows) != 215 or len(by_name) != 200:
        raise ValueError('Portal checklist changed; review before building')
    # Checked against the original 897-card registry and preceding packs.
    # The trusted snapshot avoids needing a running Godot registry or other
    # installed packs; the source metadata and sibling Python helpers remain
    # required when distributing this construction tool.
    reprints = set(read_json(SOURCE / 'reprint_names.json'))
    if len(reprints) != 27 or not reprints <= set(by_name):
        raise ValueError('Portal reprint checklist changed; review before building')
    added = sorted(set(by_name) - reprints)
    counts = {'published_printings': len(rows), 'named_set_entries': len(by_name),
              'distinct_cards': len(by_name), 'pack_card_entries': len(cards),
              'reprint_entries': len(by_name) - len(added), 'new_rules_identities': len(added)}
    manifest = read_json(SOURCE / 'manifest.json')
    manifest['counts'] = counts
    manifest['new_rules_identities'] = added
    catalog = {'pack_format': 1, 'pack_id': 'pack-6', 'counts': counts,
               'sets': {'por': {'names': sorted(by_name), 'named_cards': len(by_name),
                                'published_printings': len(rows)}}}
    return manifest, catalog, cards, (SOURCE / 'README.txt').read_text(encoding='utf-8')

def art_targets(art_dir, cards=None):
    cards = assembled()[2] if cards is None else cards
    seen = set()
    targets = []
    for row in cards:
        alternate = row['name'] in seen
        seen.add(row['name'])
        stem = fetch_card_art.snake(row['name'])
        if alternate:
            stem += '__' + row['collector_number']
        for suffix, variant in [('.jpg', 'art_crop'), ('_card.jpg', 'border_crop')]:
            targets.append((art_dir / 'por' / (stem + suffix), row, variant))
    return targets

def fetch_art(art_dir):
    failed = 0
    cards = assembled()[2]
    by_number = {}
    for path, row, variant in art_targets(art_dir, cards):
        by_number.setdefault(row['collector_number'], []).append((path, variant))
    for index, row in enumerate(cards, 1):
        targets = by_number[row['collector_number']]
        missing = [(path, variant) for path, variant in targets if not path.is_file()]
        if missing:
            for path, _ in missing:
                path.parent.mkdir(parents=True, exist_ok=True)
            try:
                # Pin the same printing as the metadata/artist credit. A named
                # lookup may select a foreign or starter variant of a land.
                raw = fetch_cards.scryfall_get('https://api.scryfall.com/cards/' + row['scryfall_id'])
                if raw.get('set') != 'por' or raw.get('collector_number') != row['collector_number']:
                    raise ValueError('printing mismatch for ' + row['name'])
                for path, variant in missing:
                    req = urllib.request.Request(raw['image_uris'][variant], headers=fetch_cards.HEADERS)
                    with urllib.request.urlopen(req, timeout=45) as response:
                        payload = response.read()
                    if not payload.startswith(b'\xff\xd8') or not payload.endswith(b'\xff\xd9'):
                        raise ValueError('invalid JPEG for ' + row['name'])
                    staged = path.with_suffix('.download')
                    staged.write_bytes(payload)
                    os.replace(staged, path)
                time.sleep(fetch_card_art.DELAY_S)
            except (OSError, ValueError, KeyError) as error:
                print('WARN:', row['name'], error, flush=True)
                failed += 1
        if index % 10 == 0 or index == len(cards):
            print('Portal artwork: %d/%d printings' % (index, len(cards)), flush=True)
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
            artwork.append((PREFIX + 'art/por/' + path.name, payload))
            if row['name'] in manifest['new_rules_identities'] or row['name'] in SHARED_NAMES:
                artwork.append(('skin/cardart/' + path.name, payload))
    manifest['checksums'] = {
        'algorithm': 'sha256',
        'metadata': {name: sha256(payload) for name, payload in metadata.items()},
        'artwork': {'files': len(artwork), 'sha256': artwork_sha256(artwork)},
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    # A failed fetch/build/verification must never damage an existing pack.
    with tempfile.TemporaryDirectory(prefix='.pack-6-', dir=out.parent) as tmp:
        staged = Path(tmp) / FILE_NAME
        with zipfile.ZipFile(staged, 'w') as zf:
            _write(zf, PREFIX + 'manifest.json', json_bytes(manifest))
            for name, payload in metadata.items():
                _write(zf, PREFIX + name, payload)
            for name, payload in artwork:
                _write(zf, name, payload)
        verify(staged, require_art=include_art)
        os.replace(staged, out)
    print('Pack 6: 200 unique cards · 215 printings -> %s' % out)

def verify(path, require_art=True):
    if path.name != FILE_NAME:
        raise ValueError('pack must be named exactly ' + FILE_NAME)
    manifest, catalog, cards, readme = assembled()
    metadata = {'catalog.json': json_bytes(catalog), 'cards.json': json_bytes(cards),
                'README.txt': readme.encode('utf-8')}
    with zipfile.ZipFile(path) as zf:
        entries = zf.infolist()
        if (len(entries) > 792 or any(info.file_size > 8 * 1024 * 1024 for info in entries)
                or sum(info.file_size for info in entries) > 256 * 1024 * 1024):
            raise ValueError('ZIP exceeds Pack 6 size limits')
        names = zf.namelist()
        if len(names) != len(set(names)):
            raise ValueError('duplicate ZIP entries')
        art_names = set()
        for target, row, _variant in art_targets(Path('unused'), cards):
            art_names.add(PREFIX + 'art/por/' + target.name)
            if row['name'] in manifest['new_rules_identities'] or row['name'] in SHARED_NAMES:
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

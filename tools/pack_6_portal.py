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
CAPTION = ('Shandalar · gameplay pack 6', 'Portal & Second Age — local construction')
SETS = {'por': (215, 200), 'p02': (165, 155)}
MAX_ENTRIES = 1356
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
    for code in SETS:
        fetch_set(code)

def fetch_set(code):
    meta = fetch_cards.scryfall_get('https://api.scryfall.com/sets/' + code)
    url = meta['search_uri']
    rows = []
    while url:
        page = fetch_cards.scryfall_get(url)
        rows.extend(page['data'])
        url = page.get('next_page') if page.get('has_more') else None
    if len(rows) != page['total_cards'] or any(row['set'] != code for row in rows):
        raise ValueError('incomplete or mixed Scryfall response')
    records = select_original(rows, code)
    suffix = '' if code == 'por' else '_' + code
    SOURCE.mkdir(parents=True, exist_ok=True)
    (SOURCE / ('cards' + suffix + '.json')).write_bytes(json_bytes(records))
    (SOURCE / ('set' + suffix + '.json')).write_bytes(json_bytes({
        'code': code, 'name': meta['name'], 'released_at': meta['released_at'],
        'standard_printings': SETS[code][0], 'all_printings': len(records),
        'unique_names': len({row['name'] for row in records}),
        'source_url': meta['search_uri'],
        'selection': 'Original English numbered printings 1–%d; excludes demo/starter and foreign variants.' % SETS[code][0],
        'retrieved_at': date.today().isoformat(),
    }))
    print('%s: %d printings, %d unique names' %
          (meta['name'], len(records), len({row['name'] for row in records})))

def select_original(rows, code='por'):
    """The original English numbered set, not starter/demo/foreign variants."""
    selected = [r for r in rows if r.get('lang') == 'en'
                and r.get('collector_number', '').isascii()
                and r.get('collector_number', '').isdigit()]
    if (len(selected) != SETS[code][0] or {int(r['collector_number']) for r in selected}
            != set(range(1, SETS[code][0] + 1)) or any(r['set'] != code for r in selected)):
        raise ValueError(code + ' original checklist changed; review before building')
    return [fetch_cards.trim(r, code) | {'scryfall_id': r['id']}
            for r in sorted(selected, key=lambda r: int(r['collector_number']))]

def assembled():
    rows = read_json(SOURCE / 'cards.json') + read_json(SOURCE / 'cards_p02.json')
    sets = {}
    for code, (printings, named) in SETS.items():
        members = [r for r in rows if r.get('set') == code]
        names = sorted({r['name'] for r in members})
        if len(members) != printings or len(names) != named or {r['collector_number'] for r in members} != {str(n) for n in range(1, printings + 1)}:
            raise ValueError(code + ' checklist changed; review before building')
        sets[code] = {'names': names, 'named_cards': named, 'published_printings': printings}
    by_name = {}
    for row in rows:
        if row.get('set') not in SETS:
            raise ValueError('Pack 6 must contain only Portal and Portal Second Age')
        by_name.setdefault(row['name'], row)
    cards = rows
    if len(rows) != 380 or len(by_name) != 318:
        raise ValueError('Portal checklist changed; review before building')
    # Checked against the original 897-card registry and preceding packs.
    # The trusted snapshot avoids needing a running Godot registry or other
    # installed packs; the source metadata and sibling Python helpers remain
    # required when distributing this construction tool.
    reprints = set(read_json(SOURCE / 'reprint_names.json'))
    if len(reprints) != 28 or not reprints <= set(by_name):
        raise ValueError('Portal reprint checklist changed; review before building')
    added = sorted(set(by_name) - reprints)
    named_entries = sum(s['named_cards'] for s in sets.values())
    counts = {'published_printings': len(rows), 'named_set_entries': named_entries,
              'distinct_cards': len(by_name), 'pack_card_entries': len(cards),
              'reprint_entries': named_entries - len(added), 'new_rules_identities': len(added)}
    manifest = read_json(SOURCE / 'manifest.json')
    manifest['counts'] = counts
    manifest['new_rules_identities'] = added
    catalog = {'pack_format': 1, 'pack_id': 'pack-6', 'counts': counts,
               'sets': sets}
    return manifest, catalog, cards, (SOURCE / 'README.txt').read_text(encoding='utf-8')

def art_targets(art_dir, cards=None):
    cards = assembled()[2] if cards is None else cards
    seen = set()
    targets = []
    for row in cards:
        key = (row['set'], row['name'])
        alternate = key in seen
        seen.add(key)
        stem = fetch_card_art.snake(row['name'])
        if alternate:
            stem += '__' + row['collector_number']
        for suffix, variant in [('.jpg', 'art_crop'), ('_card.jpg', 'border_crop')]:
            targets.append((art_dir / row['set'] / (stem + suffix), row, variant))
    return targets

def fetch_art(art_dir):
    failed = 0
    cards = assembled()[2]
    by_number = {}
    for path, row, variant in art_targets(art_dir, cards):
        by_number.setdefault((row['set'], row['collector_number']), []).append((path, variant))
    for index, row in enumerate(cards, 1):
        targets = by_number[row['set'], row['collector_number']]
        missing = [(path, variant) for path, variant in targets if not path.is_file()]
        if missing:
            for path, _ in missing:
                path.parent.mkdir(parents=True, exist_ok=True)
            try:
                # Pin the same printing as the metadata/artist credit. A named
                # lookup may select a foreign or starter variant of a land.
                raw = fetch_cards.scryfall_get('https://api.scryfall.com/cards/' + row['scryfall_id'])
                if raw.get('set') != row['set'] or raw.get('collector_number') != row['collector_number']:
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

def archive_art_targets(art_dir, cards, additions):
    """Every printing is namespaced; only the earliest identity supplies fallback art."""
    seen = set()
    for path, row, variant in art_targets(art_dir, cards):
        yield PREFIX + 'art/' + row['set'] + '/' + path.name, path
        key = (row['name'], variant)
        if key not in seen and row['name'] in additions:
            yield 'skin/cardart/' + path.name, path
        seen.add(key)

def build(out, art_dir=DEFAULT_ART, include_art=True):
    if out.name != FILE_NAME:
        raise ValueError('pack must be named exactly ' + FILE_NAME)
    manifest, catalog, cards, readme = assembled()
    metadata = {'catalog.json': json_bytes(catalog), 'cards.json': json_bytes(cards),
                'README.txt': readme.encode('utf-8')}
    artwork = []
    if include_art:
        for name, path in archive_art_targets(art_dir, cards, set(manifest['new_rules_identities']) | SHARED_NAMES):
            if not path.is_file():
                raise ValueError('missing artwork; run %s fetch-art first' % TOOL)
            payload = path.read_bytes()
            artwork.append((name, payload))
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
    print('Pack 6: 318 unique cards · 380 printings -> %s' % out)

def verify(path, require_art=True):
    if path.name != FILE_NAME:
        raise ValueError('pack must be named exactly ' + FILE_NAME)
    manifest, catalog, cards, readme = assembled()
    metadata = {'catalog.json': json_bytes(catalog), 'cards.json': json_bytes(cards),
                'README.txt': readme.encode('utf-8')}
    with zipfile.ZipFile(path) as zf:
        entries = zf.infolist()
        if (len(entries) > MAX_ENTRIES or any(info.file_size > 8 * 1024 * 1024 for info in entries)
                or sum(info.file_size for info in entries) > 256 * 1024 * 1024):
            raise ValueError('ZIP exceeds Pack 6 size limits')
        names = zf.namelist()
        if len(names) != len(set(names)):
            raise ValueError('duplicate ZIP entries')
        art_names = {name for name, _ in archive_art_targets(Path('unused'), cards,
                    set(manifest['new_rules_identities']) | SHARED_NAMES)}
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

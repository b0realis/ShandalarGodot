# Generate card artwork and optional card packs

Packages from 0.32.0 on for every platform include the Python tools,
their helper modules and the trusted card metadata. No source checkout,
Godot editor or pip packages are needed. Install Python 3.10 or newer and
run the commands below from the **extracted game folder** (the folder
containing `tools/`, not from inside the ZIP or Mac app).

On Linux/macOS use `python3`; on Windows replace it with `py -3` (or your
Python 3 command). Downloads require Internet access. Completed downloads
are cached, so rerun an interrupted `fetch-art` command to resume.
The Python tools included with the web package run on your computer, not
inside the browser. Keep `tools/`, `cards/data/` and `packaging/card_packs/`
together: the builders need all three directories.

## Base card pictures: cardart.zip

```sh
python3 tools/fetch_card_art.py --out cache/cardart
python3 tools/mtg_assets.py --from-cardart cache/cardart --out skin/cardart.zip
```

Run the second command only after the download command succeeds. Each card
has two images: the artwork crop and the full-card scan; these are different
views of the same card, not two playable identities. The result is
`skin/cardart.zip`. Keep it zipped. It provides pictures, not extra rules
or new playable cards. `cache/cardart/` is only a reusable download cache.

## Numbered gameplay packs

Choose any of the following sets. Each three-command block downloads its
art, builds the exact-name ZIP directly into `cardpacks/`, then verifies
its contents and checksums. Building a pack does not enable it in the game.
Folders are created automatically. Do not rename the generated ZIPs.

Pack 1 — 1-tDotP, completes the original set checklists:

```sh
python3 tools/pack_1_dotp_complete.py fetch-art
python3 tools/pack_1_dotp_complete.py build cardpacks/Pack-1-DotP-complete.zip
python3 tools/pack_1_dotp_complete.py verify cardpacks/Pack-1-DotP-complete.zip
```

Pack 2 — Fallen Empires:

```sh
python3 tools/pack_2_fallen_empires.py fetch-art
python3 tools/pack_2_fallen_empires.py build cardpacks/Pack-2-Fallen-Empires.zip
python3 tools/pack_2_fallen_empires.py verify cardpacks/Pack-2-Fallen-Empires.zip
```

Pack 3 — Ice Age:

```sh
python3 tools/pack_3_ice_age.py fetch-art
python3 tools/pack_3_ice_age.py build cardpacks/Pack-3-Ice_Age.zip
python3 tools/pack_3_ice_age.py verify cardpacks/Pack-3-Ice_Age.zip
```

Pack 4 — Homelands:

```sh
python3 tools/pack_4_homelands.py fetch-art
python3 tools/pack_4_homelands.py build cardpacks/Pack-4-Homelands.zip
python3 tools/pack_4_homelands.py verify cardpacks/Pack-4-Homelands.zip
```

Pack 5 — Alliances:

```sh
python3 tools/pack_5_alliances.py fetch-art
python3 tools/pack_5_alliances.py build cardpacks/Pack-5-Alliances.zip
python3 tools/pack_5_alliances.py verify cardpacks/Pack-5-Alliances.zip
```

Pack 6 — Portal & Second Age (requires game 0.40.9 or later).
Revision 2.0.0 includes all 215 Portal and 165 Second Age printings, with
four and three illustrations respectively for each basic land. Use the
**Card variant** stone medallion just below the lower-right
corner of the Deck Builder's large preview to
choose and save artwork, including reprints from other enabled sets.
Rebuild an older local Pack 6 ZIP to include both sets; saved decks are unchanged:

```sh
python3 tools/pack_6_portal.py fetch-art
python3 tools/pack_6_portal.py build cardpacks/Pack-6-Portal.zip
python3 tools/pack_6_portal.py verify cardpacks/Pack-6-Portal.zip
```

Pack 7 — Fifth Edition (requires game 0.40.13 or later). The 1997 core
set: 434 names and 449 printings, every one a reprint of the base game or
of Packs 2 to 4, with four illustrations for each basic land. The pack adds
pictures and a Fifth Edition source for the 147 Ice Age, Homelands and
Fallen Empires cards it reprints; it adds no rules of its own:

```sh
python3 tools/pack_7_fifth_edition.py fetch-art
python3 tools/pack_7_fifth_edition.py build cardpacks/Pack-7-Fifth-Edition.zip
python3 tools/pack_7_fifth_edition.py verify cardpacks/Pack-7-Fifth-Edition.zip
```

Run `build` only after `fetch-art` succeeds. Each builder's default artwork
cache is `../shandalar-packs/cache/pack_N_art/`, relative to the game folder.
To put it elsewhere, pass the same `--art-dir PATH` to `fetch-art` and `build`.
Without an explicit output filename, `build` instead writes its ZIP under
`../shandalar-packs/`; that is a construction folder, **not** the game's
automatic portable installation folder.

Use the metadata supplied with this game version. The separate `fetch`
command is a developer operation that refreshes metadata; it is not needed
to construct a pack and may make it incompatible with an older game.
`--help` describes each tool's options. Only known, trusted pack definitions
work: creating or renaming an arbitrary ZIP does not add rules to the engine.

## Where to put the ZIPs on desktop

```text
extracted-game-folder/
├── Shandalar.x86_64 / Shandalar.arm64 / Shandalar.exe / Shandalar.app
├── tools/
├── cards/data/                    bundled construction metadata
├── packaging/card_packs/          bundled pack definitions
├── skin/
│   ├── original_skin.zip          optional original interface and sounds
│   └── cardart.zip                base card pictures
└── cardpacks/
    ├── Pack-1-DotP-complete.zip
    ├── Pack-2-Fallen-Empires.zip
    ├── Pack-3-Ice_Age.zip
    ├── Pack-4-Homelands.zip
    ├── Pack-5-Alliances.zip
    ├── Pack-6-Portal.zip
    └── Pack-7-Fifth-Edition.zip
```

On Mac, `skin/` and `cardpacks/` go **beside Shandalar.app**, never inside
its signed Contents. On Linux, Pi and Windows they go beside the executable.
Leave every ZIP intact. The numbered packs already contain their own set
artwork; do not unpack it into `skin/` or mix it into `cardart.zip`.

Restart the game, or use **Options > Card Packs > Rescan**, then enable
the desired packs. Alternatively, **Open Folder** on that page opens the
configured per-user card-pack directory; ZIPs placed there are also detected.
The original pool remains playable with no numbered packs present.
`packaging/card_packs/` contains builder inputs; it is not the installation
directory `cardpacks/`.

The `-with-skin` game ZIP already supplies `skin/original_skin.zip`; a plain
package does not. Add the separate original-skin ZIP there if desired.
You can also import the original skin or base cardart ZIP via Options > Skin.
An already-installed skin can still appear when running a plain package.

## Web differs from desktop

Serve the extracted web folder over HTTP(S), for example with
`python3 -m http.server 8000`, then visit `http://localhost:8000/`.
For local testing, `skin/original_skin.zip` and `skin/cardart.zip` can sit
beside `index.html`; the game fetches them into browser storage. Manual
import through Options > Skin is also available.

This build does **not** provide a browser import/auto-fetch path for the
numbered gameplay packs. Putting `Pack-*.zip` on a web server is not enough
to install them, and the skin importer does not accept their metadata.
The web ZIP includes all construction tools, but use the generated numbered
packs with the desktop builds for now.

Artwork and completed numbered-pack ZIPs are personal/local construction
outputs, not release downloads. Do not add them to public release archives
or publicly host your card-art downloads.

# Pack 7 — Fifth Edition

**Fifth Edition (1997)** is the core set of Shandalar's own year: the cards a
1997 player met at the table. It gathers the familiar core pool and 147
cards that had first appeared in Ice Age, Homelands and Fallen Empires,
so the pack is a way to play those expansions' cards with the white-bordered
core look, and to see the four Fifth Edition illustrations of every basic
land.

The pack is **reprints alone**. Every card already has a script in the game
or in Packs 2 to 4; Fifth Edition adds no rules identity. It adds its
**449 original English printings** with artwork and a Fifth Edition source
for the 147 expansion cards it reprints: **434 names / 449 printings**,
common 185, uncommon 132, rare 132. Core plus Pack 7 has 1,331 set
entries / 1,044 unique cards; all seven packs have 2,793 set entries and
the same **1,898 unique cards** as six. The core remains 897 cards.

Requires **Shandalar 0.40.13 or later**. The snapshot contains the English
numbered printings 1–449 only; the five `†` misprint variants and foreign
printings are excluded. Serra Angel, famously, is not in Fifth Edition and
is not in the pack.

## Build and enable

Using Python 3.10+ from the matching source or extracted game folder:

```sh
python3 tools/pack_7_fifth_edition.py fetch-art
python3 tools/pack_7_fifth_edition.py build cardpacks/Pack-7-Fifth-Edition.zip
python3 tools/pack_7_fifth_edition.py verify cardpacks/Pack-7-Fifth-Edition.zip
```

On Windows, `py -3` may replace `python3`. Leave the ZIP intact and enable
it through **Options → Card Packs → Rescan**. On Mac, `cardpacks/` belongs
beside the app, not inside it. Web players construct the ZIP on their own
computer and use the existing card-pack upload flow.

With no explicit output path, the builder writes
`../shandalar-packs/Pack-7-Fifth-Edition.zip`; its reusable cache is
`../shandalar-packs/cache/pack_7_art/`. An explicit `--art-dir` overrides
the cache. `fetch` is a maintainer operation: it refreshes trusted metadata
and requires rebuilding the matching game.

The menu badge is **7-5ED**. In Deck Builder → **Extras**, leave Fifth
Edition on and turn the other sources off to browse exactly its 434 names.
No printed Fifth Edition card wears a set symbol; the emblem is the game's
own gold Roman **V**, the Fourth Edition numeral's sibling, drawn by
`tools/draw_our_art.gd` in the existing gold and carved-stone styles for
the card icon and the On/Off medallions.

## Art and printings

All 449 printings are pinned by Scryfall ID: an art crop plus a full-card
scan, **898 pictures** under the pack's own `art/5ed/` namespace. Each basic
land has all four Fifth Edition illustrations, chosen as `5ed:<number>`
variants (Plains 430–433, Island 434–437, Swamp 438–441, Mountain 442–445,
Forest 446–449) through the **Card variant** stone medallion below the Deck
Builder's preview, exactly as Portal's lands are. Every other name has one
printing, chosen as `5ed`. The inventory shows 434 distinct cards and
reports 449 printings; alternate art never adds copies to the pool.

The 147 shared names also travel as `skin/cardart/` fallbacks (294 files),
so an Ice Age card renders with its Fifth Edition picture when Pack 7 is the
only pack that supplies it. The archive holds **1,196 entries**: four
metadata files and 1,192 pictures, never a script. The artwork ZIP and
downloaded pictures stay local; only builder source and metadata are
distributed.

## Rules and providers

The pack reuses the reviewed scripts in `cards/sets/ice/`, `cards/sets/hml/`
and `cards/sets/fem/` for its 147 expansion reprints (Ice Age 89, Homelands
29, Fallen Empires 29), keyed in
`packaging/card_packs/pack_7_fifth_edition/shared_names.json`. With Pack 7
alone those cards wear the Fifth Edition symbol and count as its identities;
with the original expansion also enabled, the original's script and symbol
win, and Fifth Edition remains a printing of the same card.

A deck that uses such a card needs **any one** enabled provider. Disabling
Pack 7 while Ice Age is on raises no warning; disabling the last provider
warns, exactly as Portal's six shared reprints have since 0.40.9. Mountain
Goat and Nature's Lore are shared by Ice Age, Portal and Fifth Edition
alike. The 287 core reprints keep their core scripts and need no pack.

Draft pools group cards by the set that supplies their identity, so with
the originals enabled Fifth Edition contributes no separate draft group;
its printings are cosmetic. LAN compatibility fingerprints include `pack-7`
like every other pack, and protocol 24 is unchanged.

## Archive contract

The loader (`game/fifth_edition_pack.gd`) checks the exact inventory,
trusted metadata, minimum version and SHA-256 hashes, with uncompressed
sizes checked before reading members: 8 MiB per member, 256 MiB total,
1,196 entries at most. Builds are staged, verified and atomically replaced;
identical inputs produce identical ZIP bytes. Metadata-only archives are
accepted solely under the isolated test feature, never as player packs.

## Verification (2026-09-25)

The full gate passed: 504 scripts, **7,757 GUT tests / 346,186
assertions**, exit 0 in 246 s over six shards; **307 Python tests** (eight
for this builder); boot smoke clean. The real artwork ZIP (1,196 entries,
116 MB) was built from the 449 pinned printings, passed `verify`, and was
checked through the trusted loader in Godot: full inventory and hashes,
the numbered Forest scans resolving as `5ed:446`–`5ed:449`, an Ice Age
reprint drawing its Fifth Edition picture. See the
[ROADMAP](ROADMAP.md#2026-09-25--pack-7-fifth-edition-04013) entry.

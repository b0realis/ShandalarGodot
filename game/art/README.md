# `game/art/` — the look this project ships as its own

Everything in this folder travels inside the game's own pack, and it is
ours in one of exactly two ways. The **pictures** were *drawn by this
project* and carry its GPL-3.0. The **body face**, in `fonts/`, was drawn
by somebody else and *given away under the SIL Open Font Licence*, which
is a licence to redistribute it — its `OFL.txt` sits beside it. Nothing
here came out of the 1997 game, out of a later reimplementation of it, or
out of anybody else's restyle of either.

One shipped file that is ours the FIRST way — the Deck Builder's stone
grind, made by code the same as the pictures are — lives outside this
folder and is inventoried at the foot of this page all the same, because
the inventory is what the test reads.

That distinction is the whole reason the folder exists. The 1997 art is
the player's own copy and is never redistributed (`Provenance.md`,
`README.md` § Legal); a Manalink install's flat gold set glyphs and its
damage dagger are a **third party's restyle** of MicroProse's drawings
and are not ours to copy either. So the game's default look does not
borrow from either of them: it is drawn here, and a player who imports
their own 1997 files still gets the 1997 files, because the loader
checks every skin directory first and only then falls through to this
folder (`GameSkin.our_art`, `GameSkin.our_font`, `GameSkin.set_icon`,
`MiniCard.masked_sprite`).

**Ours is the floor, never the ceiling.**

## Why the files live under `game/` and not under `assets/`

`assets/` is gitignored *and* excluded from every export preset
(`export_presets.cfg.example`, `exclude_filter`), because that is where
the player's own copy of the 1997 art lands. Art that SHIPS therefore
has to live somewhere the pack includes, and `game/` is that place —
`game/icon.png` and `game/boot_splash.png` are the precedent. Nothing in
`exclude_filter` matches `game/art/*`, and the presets export
`all_resources`, so these files are in the pack without a preset change.

They are read with `load()` (the import pipeline) rather than
`Image.load_from_file` or `FontFile.load_dynamic_font`, because inside an
exported pack there is no filesystem path to open — which is exactly the
opposite of how the skin loader reads a skin, and why `GameSkin.our_art`
and `GameSkin.our_font` are separate accessors.

`OFL.txt` is the one file here that has to be in the pack as a FILE and
not as an imported resource, because it is the licence the font travels
under. `export_filter="all_resources"` alone would leave it out — Godot
does not consider a `.txt` a resource — but every preset's
`include_filter` already names `*.txt` (it is how `cards/data/dck_ids.txt`
ships), so the licence goes wherever the face goes. `tests/ui/test_our_art.gd`
asserts that rather than trusting it.

## How to change a picture

Do not paint over the PNG. Edit the shape in
[`tools/draw_our_art.gd`](../../tools/draw_our_art.gd) — every glyph is a
handful of polygons, arcs and capsules in unit coordinates — and run

    ../tools/godot --headless --path . -s res://tools/draw_our_art.gd

which rewrites every PNG it draws — it never touches `fonts/`, whose one
file is fetched, not drawn, and it never touches `manalink_globe.png`,
which is the owner's own picture and not a drawing of the generator's
(see its row below; to change it, supply a new picture and move the
hash). The generator has no input but itself: run it on a machine with
no 1997 game and no Manalink install and it produces exactly its bytes.

## The pictures

Portal follows the original set's circular gate: a solid center, two
concentric rings and ten radial divisions. `_portal` draws it from our own
geometry, with the same gold bevel and lit/dark carved-stone treatment as
the earlier packs. The original card symbol is the reference, not a generic
arched doorway; no downloaded SVG or scan is embedded in these pictures.

| File | Artwork | Generator | License | SHA-256 |
|---|---|---|---|---|
| `set_icon_por.png` | Portal — segmented circular gold gate, 48x48 | `tools/draw_our_art.gd` (`_portal`) | GPL-3.0 | `17e96ba63092397274be1fcff166de67cb05b9b6cebba8b44549fb2ce3e9b85c` |
| `filter_por_on.png` | Portal — circular gate carved into lit stone, 48x48 | `tools/draw_our_art.gd` | GPL-3.0 | `3773788eac04da5731e2cd0c8260791f9c8175a02fbc2ecd5ec8f39b5f2cfd12` |
| `filter_por_off.png` | Portal — matching dim stone gate, 48x48 | `tools/draw_our_art.gd` | GPL-3.0 | `8090a968ecf3ebf110018b04039f39fb607e5717af69e89baaf39e68d597590e` |

Second Age uses original procedural five-notched concentric gates, inspired
by its printed set emblem. No reference bitmap or SVG is copied into these assets.

| File | Description | Generator | License | SHA-256 |
|---|---|---|---|---|
| `set_icon_p02.png` | Second Age gold gate, 48x48 | `tools/draw_our_art.gd` (`_second_age`) | GPL-3.0 | `c91a8f22bdce69b53756df56c41eab59ccbf255d8042eab1b00c3d0ee98d7d2e` |
| `filter_p02_on.png` | Lit carved gate medallion, 48x48 | `tools/draw_our_art.gd` | GPL-3.0 | `a143ca9be87d83b033e37e92426b6cb820b8f38fe68692193754c617df233998` |
| `filter_p02_off.png` | Dim carved gate medallion, 48x48 | `tools/draw_our_art.gd` | GPL-3.0 | `9552ee240dd7b567533bf05d6e89e73c75b1c1ccc29a47017bfe9f493c6d1be9` |
| `card_variant_on.png` | Card variants — two picture frames carved into a round stone medallion, 48x48 | `tools/draw_our_art.gd` (`_variant_medallion`) | GPL-3.0 | `e9479fd2cc33a330f880ba9f73b4f39c56e78403ed955513c51e8fe039c0072a` |
| `card_variant_off.png` | Card variants — matching recessed/dim medallion, 48x48 | `tools/draw_our_art.gd` (`_variant_medallion`) | GPL-3.0 | `1d036fde388f708a42e77e337e405b2a132e3048b7f96ae0185128d05aa51034` |

The card-variant medallion floats at 32px just below the large card's lower-right
corner, over the unchanged information area. Its overlapping frames distinguish artwork selection
from Pack 1's fanned-card pool emblem. The transparent circular edge,
blue-grey stone, carved recesses and antique-gold rim are drawn by the same
generator; no external image or original skin is needed.

Alliances uses an original forked-banner silhouette drawn by `_alliances`,
with the same gold card emblem and bevelled stone on/off tiles as the other packs.

| file | what it is | drawn by | licence | SHA-256 |
|---|---|---|---|---|
| `set_icon_all.png` | Alliances — gold forked banner, 48x48 | `tools/draw_our_art.gd` (`_alliances`) | GPL-3.0 | `b0d3d2e5f531ba5c42e0a6d176707e3de3c6dcd1b6a540838bcf056ba46cb966` |
| `filter_all_on.png` | Alliances — lit stone filter medallion, 48x48 | `tools/draw_our_art.gd` | GPL-3.0 | `0d86e56cc5068aa3b73bc507c6430071eea3ac165fdc7bbfa63a1a4809ba573a` |
| `filter_all_off.png` | Alliances — dark stone filter medallion, 48x48 | `tools/draw_our_art.gd` | GPL-3.0 | `a412236039275e4c258785cf356cc5e4ca94cc76292530047a4e2da77232b1ac` |
| `set_icon_arn.png` | Arabian Nights — a scimitar, 48x48 | `tools/draw_our_art.gd` (`_scimitar`) | GPL-3.0, with the rest of this project | `80e3adf1ef4e377d67f980bfbe7ce5395c6a4a9a69735c02d3e4896eb1432a3e` |
| `set_icon_atq.png` | Antiquities — an anvil, 48x48 | `tools/draw_our_art.gd` (`_anvil`) | GPL-3.0 | `9a59e3a87a1e480b65c022dd4d3c5d26d998ad11d8d49a5c348dac3755574f7c` |
| `set_icon_leg.png` | Legends — a broken column, 48x48 | `tools/draw_our_art.gd` (`_column`) | GPL-3.0 | `94911cc3d00508aeb43988d481e8b9c2f7849cf7466aa054f3b82e2285a73732` |
| `set_icon_drk.png` | The Dark — a crescent moon, 48x48 | `tools/draw_our_art.gd` (`_crescent`) | GPL-3.0 | `34c59d84623f7cab65e6a094721008caf7322af53bba892806a821e2788eacbe` |
| `set_icon_2ed.png` | Unlimited — a Roman `II`, the IV's sibling, 48x48 | `tools/draw_our_art.gd` (`_roman_two`) | GPL-3.0 | `a5aa2e8bdd611a26fb1fb94865c9838ba8c6dda690f60145a2f88a50255012e5` |
| `set_icon_4ed.png` | Fourth Edition — a Roman `IV`, 48x48 | `tools/draw_our_art.gd` (`_roman_four`) | GPL-3.0 | `5f96fd74203791f0dd19b873eae13f38b6c2f120831915a7654fabf19a7b5654` |
| `set_icon_past.png` | Astral — a comet trailing sparks, 48x48 | `tools/draw_our_art.gd` (`_comet`) | GPL-3.0 | `c2df70e8fad0f9d4512fe0218d2643f0bf7c9c21f0e3abbbc4fb8049bc8c7ec0` |
| `set_icon_fem.png` | Fallen Empires — gold three-point crown, oval opening and detached base, 48x48 | `tools/draw_our_art.gd` (`_crown`) | GPL-3.0 | `c0530b7529fa800099b3f1903103b0aef2f006bf1d810954d50af8d6bdbb1970` |
| `filter_fem_on.png` | Fallen Empires — dark crown in a gold ring on a square bevelled stone tile, 48x48 | `tools/draw_our_art.gd` (`_crown_medallion`) | GPL-3.0 | `c8ba81d5128eb8067788480991df9ef7572e792924bea96bc1f248f708acefcf` |
| `filter_fem_off.png` | Fallen Empires — dim crown tile, 48x48 | `tools/draw_our_art.gd` (`_crown_medallion`) | GPL-3.0 | `5a60af350d1eca1441a655331dc557acc0f20d31556937b4612e0a8f06e89491` |
| `filter_source_on.png` | 1997 — bright square stone and gold ring beneath live 97 lettering, 48x48 | `tools/draw_our_art.gd` (`_stone_medallion`) | GPL-3.0 | `1440cdce66ed47d31be21e0b1f96f28e46f9322853d04d7be18aa86ac62cc14d` |
| `filter_source_off.png` | 1997 — dim square stone tile, 48x48 | `tools/draw_our_art.gd` (`_stone_medallion`) | GPL-3.0 | `fd1493ca4c561fe70e8ebf61880b1cc136766b3eee164ad61e1a67096b08f21f` |
| `filter_pack1_on.png` | Pack 1 — fanned cards and a glint in a gold ring on bevelled stone, 48x48 | `tools/draw_our_art.gd` (`_completed_cards`, `_stone_medallion`) | GPL-3.0 | `e1aa3902bba5dca5b2208f533ad308acac8708150d3049bbc20053f42bd6e5e7` |
| `filter_pack1_off.png` | Pack 1 — dim fanned-card tile, 48x48 | `tools/draw_our_art.gd` (`_completed_cards`, `_stone_medallion`) | GPL-3.0 | `db1332b0fdf37398780ceb032c1d47388630fd07566d10ebe929d594899fe36b` |
| `set_icon_ice.png` | Ice Age — six-armed gold snow crystal, 48x48 | `tools/draw_our_art.gd` (`_snowflake`) | GPL-3.0 | `265d6e37fc8f8c87dae371a614c4b39e5458bf90f30d4b7f38527eef06b7b2af` |
| `filter_ice_on.png` | Ice Age — carved snow crystal on bright stone and gold ring, 48x48 | `tools/draw_our_art.gd` (`_snowflake`, `_stone_medallion`) | GPL-3.0 | `0366a6227e85f407f801f5309336e3816133588b083b1c2247c07020fbda2dd2` |
| `filter_ice_off.png` | Ice Age — dim snow crystal tile, 48x48 | `tools/draw_our_art.gd` (`_snowflake`, `_stone_medallion`) | GPL-3.0 | `2e6688b9b7439fe5b91de83c4ed692bf92b3c20a92b11bf730d978b7efd20372` |
| `set_icon_hml.png` | Homelands — gold globe with meridians and equator, 48x48 | `tools/draw_our_art.gd` (`_globe`) | GPL-3.0 | `f3b11d4f6c7f0ec738d27db3dff06eee788f4b9873e3da7cdb2285d3bcf24553` |
| `filter_hml_on.png` | Homelands — globe on bright stone and gold ring, 48x48 | `tools/draw_our_art.gd` (`_globe`, `_stone_medallion`) | GPL-3.0 | `aa0b940ad78c4ea0eb674d4d6edce777a7d5002c4604c99f9455cfb35a14920e` |
| `filter_hml_off.png` | Homelands — dim globe tile, 48x48 | `tools/draw_our_art.gd` (`_globe`, `_stone_medallion`) | GPL-3.0 | `91b3aa4ebefdbbbdc2dbb1050e50c0daeced7993e1802b54fb3eba647b1824b4` |
| `damage_marker.png` | the dagger on a wounded creature, 64x40 | `tools/draw_our_art.gd` (`_dagger_blade`, `_dagger_hilt`) | GPL-3.0 | `771a24e7139e7df3757728350e0acf5e2fffb553e1a78bc48e1b04c20c52d489` |
| `manalink_globe.png` | the Manalink button's mark — a green wire globe and a starred violet sky sharing one disc under a rainbow rim, 256x256 | the owner's own picture, supplied 2026-09-17; cropped to its outline and reduced to 256 px, NOT drawn by `tools/draw_our_art.gd` | GPL-3.0, with the rest of this project | `08ba71afe94739d45fe55210cac43442150a399b5d909a62bc6a1eadebbd765d` |

`manalink_globe.png` is the one picture here that no code drew. It is
the owner's own, handed over on 2026-09-17 as a 1254 px master with a
transparent ground, cropped to its outline and reduced to 256 px with a
Lanczos filter for the pack — the button draws it at 52 px and the lobby
heading at 56, and `ManalinkGlobe` builds its own mipmaps for that
(`game/manalink_globe.gd`), so the import settings of an ignored
`.import` file are not what keeps it from shimmering. The master is not
in the repository; `branding/` ships in the pack, and a 1.7 MB picture
that nothing loads is 1.7 MB of pack for nothing.

The eight set glyphs are the sets' own marks — an anvil, a scimitar, a
comet, a crescent, a numeral, a column, a crown and a snow crystal. What is drawn here is this
project's own drawing of each; the shapes themselves belong to nobody's
file.

The Fallen Empires crown follows the owner's supplied silhouette: three
points, a central oval opening and a separate lower band. It is redrawn
as polygons by the same renderer as the other gold symbols; the reference
JPG is not embedded or required. The Extras filter uses that same crown
incised into procedurally textured blue-grey stone with an antique-gold ring
and square bevel, following the owner's set-strip reference. Pack 1 uses
fanned cards with a glint; the original pool has live 97 numerals. On/Off
captions sit below each tile, leaving the emblems unobscured. The faces
retain the original strip's 2:1 brightness convention. The Ice Age snow
crystal and Homelands globe use the same gold, stone, ring and bevel treatment.
These textures ship with the game independently of a skin or external artwork ZIP.

TWO WERE REVISED ON 2026-09-09, both to the owner's brief, and the two
hashes above moved with them.

`set_icon_leg.png` was a standing fluted column on a plinth and is now a
BROKEN one — a splayed capital chamfered at 45°, two incised grooves,
three arched flutes with 45° arches, and the whole shaft sheared away by
a diagonal running up from the lower left. The shear is the point: it is
the only asymmetry on a row of symmetrical marks, and it is what tells
the column from the anvil beside it at fourteen pixels, where the flutes
and the grooves have long since closed up.

`damage_marker.png` turned end for end and changed metal: a pale steel
blade pointing up and to the right is now a RED and salmon one pointing
down and to the left, INTO the card it is drawn on. Its gold furniture
also moved in FRONT of the blade instead of behind it — as one unbroken
bar across the diagonal rather than two lobes either side of it — which
is the whole of what keeps a crossguard legible at the eighteen pixels
the small card draws it at.

## The face

The rules text, the duel log and every dialog are set in `font_body`.
With the 1997 files imported that is MPlantin, the commercial Monotype
face the original names — **which this project may not redistribute**, so
without an import there was nothing under it but Godot's own sans, and a
Magic card set in a UI sans is not a Magic card. This is what stands
under it now.

| file | what it is | source | licence | SHA-256 |
|---|---|---|---|---|
| `fonts/Spectral-Regular.ttf` | Spectral Regular 2.005, the shipped body face | `github.com/google/fonts/blob/main/ofl/spectral/Spectral-Regular.ttf` (Production Type) | OFL-1.1 | `c89021dc20720c8d0dcf40b0b2f6e00c13665fa8041717f581396f51b8c78f5d` |
| `fonts/OFL.txt` | the licence that file travels under | `github.com/google/fonts/blob/main/ofl/spectral/OFL.txt` | OFL-1.1 | `501d6ceca8e552630fe3aa9442b9a818565680a1a2f79f3fb8c13d6f309a9e98` |

Both were fetched from the family's own upstream directory over HTTPS on
2026-09-09 and checked against the blob hashes that directory publishes
before either entered the checkout. The TTF is a real sfnt (`0x00010000`,
18 tables), its name table reads `Spectral / Regular / Version 2.005`,
and its own OS/2 gives x-height 450 and cap-height 660 on a 1000-unit em.

WHY SPECTRAL, out of the twenty-two free serifs surveyed on 2026-09-09:
it is the one that matches the face it stands in for. **x-height 0.450 of
the em against MPlantin's 0.450** — the same to three decimals, and the
x-height is what the eye reads a body face by — with a text width within
1.2%. Nothing else in the field came as close on both.

It first read as a BAD face and was not. The card's auto-fit used to pick
a size by shrinking until the face's LINE BOX stood inside the cell the
1997 font table ports, and Spectral bakes half an em of leading into that
box (1.522 em, where MPlantin's is 1.000), so the same cell bought a much
smaller letter: a base of 12 where MPlantin gets 18. That is a defect of
the fit, not of the face, and it was fixed first — `docs/ROADMAP.md`, *"A
cell is not a letter"*. With the fit measuring the LETTER, Spectral takes
MPlantin's own sizes on every card: base 18, 10 px on Rock Hydra, P/T 26,
credit 13, checked by looking at all three comparison cards with no skin
present.

Only the REGULAR weight ships, and there is no italic, because nothing in
the game asks for one: bold is a `FontVariation` emboldening the face in
place (`UiChrome.menu_button`, `DuelLog`, the Deck Builder), and no
surface sets italics. A face that nothing loads is 260 kB of pack for
nothing.

There is no `font_title` of ours and that is deliberate. The original's
display face is MagicMedieval; nothing free is near it, and a serif
standing in for a blackletter would be a worse lie than the default face
a title already gets without a skin.

No table on this page may drift. `tests/ui/test_our_art.gd` holds every
row to the file it names: it must exist, be non-empty, carry the hash
written beside it, load through the accessor that reaches it, and sit
somewhere the export cannot silently drop.

*Where a name is a skin key* (`set_icon_<code>`, `damage_marker`), it is
deliberately the SAME key `tools/skin_catalogue.py` publishes, so a skin
that supplies its own simply replaces ours, one file at a time.

## Shipped outside this folder

One asset ships in the pack and does NOT live here, and the row for it is
here anyway. `README.md` § Legal promises what ships file by file, and a
promise kept in two documents is a promise that drifts: this file is the
inventory `tests/ui/test_our_art.gd` reads, so anything the pack carries
that is not code has to be in it, wherever the bytes actually sit.

| file | what it is | source | licence | SHA-256 |
|---|---|---|---|---|
| `game/deck_builder/stone_grind.wav` | the Deck Builder's filter-button cue: 0.250 s, 22 050 Hz, mono, 16-bit PCM, 11 068 B | ours — generated, not recorded | ours (GPL-3.0) | `4e61a797760ae9ccfd550073c0ca6233b094c5f2128ad9bd21d256ee9644da6e` |

A row whose name begins `game/` is a path from the project root rather
than a file in this folder; that is the only difference the test makes
between it and the rows above.

IT DOES NOT MOVE HERE, and the reason is not tidiness. `DeckAudio.GRIND`
names it by path (`game/deck_builder/deck_audio.gd`), it sits beside the
screen that plays it, and it is the ONE sound in this game that did not
come out of the 1997 install — which is why it is in the pack at all
while every other sound is read off the player's own copy.

**AND SINCE 2026-09-09 IT IS OURS THE WAY THE PICTURES ARE.** The
pictures carry this project's GPL-3.0 because this project drew them in
code; the face carries the OFL because its authors gave it away under
one; and this sound now carries the GPL-3.0 for the same reason as the
pictures — it is noise, a filter and an envelope, generated to simulate
the sound of stone scraping on stone. The generator that makes it is kept
outside this repository, with the samples and the method.
`Provenance.md` § *Our own assets* has what was there before and why it
went.

`b0realis`, 2026-09-09.

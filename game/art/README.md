# `game/art/` — the pictures this project ships as its own

Everything in this folder was **drawn by this project** and travels
inside the game's own pack. Nothing here came out of the 1997 game, out
of a later reimplementation of it, or out of anybody else's file.

That distinction is the whole reason the folder exists. The 1997 art is
the player's own copy and is never redistributed (`Provenance.md`,
`README.md` § Legal); a Manalink install's flat gold set glyphs and its
damage dagger are a **third party's restyle** of MicroProse's drawings
and are not ours to copy either. So the game's default look does not
borrow from either of them: it is drawn here, and a player who imports
their own 1997 files still gets the 1997 files, because the loader
checks every skin directory first and only then falls through to this
folder (`GameSkin.our_art`, `GameSkin.set_icon`,
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
`Image.load_from_file`, because inside an exported pack there is no
filesystem path to open — which is exactly the opposite of how the skin
loader reads a skin, and why `GameSkin.our_art` is a separate accessor.

## How to change one

Do not paint over the PNG. Edit the shape in
[`tools/draw_our_art.gd`](../../tools/draw_our_art.gd) — every glyph is a
handful of polygons, arcs and capsules in unit coordinates — and run

    ../tools/godot --headless --path . -s res://tools/draw_our_art.gd

which rewrites every file here. The generator has no input but itself:
run it on a machine with no 1997 game and no Manalink install and it
produces exactly these bytes.

## The files

| file | what it is | drawn by | licence | SHA-256 |
|---|---|---|---|---|
| `set_icon_arn.png` | Arabian Nights — a scimitar, 48x48 | `tools/draw_our_art.gd` (`_scimitar`) | GPL-3.0, with the rest of this project | `80e3adf1ef4e377d67f980bfbe7ce5395c6a4a9a69735c02d3e4896eb1432a3e` |
| `set_icon_atq.png` | Antiquities — an anvil, 48x48 | `tools/draw_our_art.gd` (`_anvil`) | GPL-3.0 | `9a59e3a87a1e480b65c022dd4d3c5d26d998ad11d8d49a5c348dac3755574f7c` |
| `set_icon_leg.png` | Legends — a broken column, 48x48 | `tools/draw_our_art.gd` (`_column`) | GPL-3.0 | `94911cc3d00508aeb43988d481e8b9c2f7849cf7466aa054f3b82e2285a73732` |
| `set_icon_drk.png` | The Dark — a crescent moon, 48x48 | `tools/draw_our_art.gd` (`_crescent`) | GPL-3.0 | `34c59d84623f7cab65e6a094721008caf7322af53bba892806a821e2788eacbe` |
| `set_icon_4ed.png` | Fourth Edition — a Roman `IV`, 48x48 | `tools/draw_our_art.gd` (`_roman_four`) | GPL-3.0 | `5f96fd74203791f0dd19b873eae13f38b6c2f120831915a7654fabf19a7b5654` |
| `set_icon_past.png` | Astral — a comet trailing sparks, 48x48 | `tools/draw_our_art.gd` (`_comet`) | GPL-3.0 | `c2df70e8fad0f9d4512fe0218d2643f0bf7c9c21f0e3abbbc4fb8049bc8c7ec0` |
| `damage_marker.png` | the dagger on a wounded creature, 64x40 | `tools/draw_our_art.gd` (`_dagger_blade`, `_dagger_hilt`) | GPL-3.0 | `771a24e7139e7df3757728350e0acf5e2fffb553e1a78bc48e1b04c20c52d489` |

The six set glyphs are the sets' own marks — an anvil, a scimitar, a
comet, a crescent, a numeral, a column. What is drawn here is this
project's own drawing of each; the shapes themselves belong to nobody's
file.

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

`tests/ui/test_our_art.gd` holds this table to the folder: every file
named here must exist, be non-empty, carry the hash written above, load
as a texture, and sit somewhere the export cannot silently drop.

*Where a name is a skin key* (`set_icon_<code>`, `damage_marker`), it is
deliberately the SAME key `tools/skin_catalogue.py` publishes, so a skin
that supplies its own simply replaces ours, one file at a time.

`b0realis`, 2026-09-09.

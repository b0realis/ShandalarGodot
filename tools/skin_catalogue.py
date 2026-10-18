#!/usr/bin/env python3
"""Write `docs/skin-catalogue.txt` — everything a skin has to contain.

And beside it `docs/skin-catalogue.csv`, the same catalogue as a table:
one row per file of a complete `original_skin.zip`, by its concrete name
(see THE TABLE below).

A SKIN is one zip, `original_skin.zip`, with a `skin/` folder inside it
and every picture, font, sound, tune, movie and portrait the game dresses
itself in; the CARD ART is a second zip, `cardart.zip`, with one picture
per card under `skin/cardart/`. The game mounts both in place
(`game/skin_pack.gd`) and reads from them as if the files were on disk;
nothing is unpacked. The owner, 2026-09-08: *"a text file that
catalogues all art, music, movies needed — their format, dimensions and
naming so users/players can create new/free skins for the project that
contain everything the game needs."* And later that day: *"the skin
assets should be a separate zip, card art pack should be separate!"*

The catalogue is GENERATED, not typed, so it cannot drift from the code:
the names come from `import_original.py`'s MANIFEST (the one list the
importer, the loader and the tests share), the dimensions are measured
off an imported skin folder, and every key must have a note here or the
script refuses to write. `tools/test_skin_catalogue.py` holds the
committed text to the manifest.

    python3 tools/skin_catalogue.py                  # rewrite docs/skin-catalogue.txt + .csv
    python3 tools/skin_catalogue.py --skin DIR       # measure a different folder
    python3 tools/skin_catalogue.py --check my_skin.zip   # what a skin is missing
    python3 tools/skin_catalogue.py --check my_skin/      # a folder works too

Standard library only.
"""
from __future__ import annotations

import argparse
import csv
import io
import json
import re
import struct
import sys
import textwrap
import wave
import tarfile
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))
import import_original as importer  # noqa: E402
import import_manalink as manalink  # noqa: E402
import tool_banner  # noqa: E402  — the family banner and the one version

TOOL = "skin_catalogue.py"
## The tool's name in the half-height box-drawing face the whole family is
## set in (DeckLab/lab_console.gd's WORDMARK is the same font).
WORDMARK = (
    "┌─┐┌─┐┌┬┐┌─┐┬  ┌─┐┌─┐┬ ┬┌─┐",
    "│  ├─┤ │ ├─┤│  │ ││ ┬│ │├┤ ",
    "└─┘┴ ┴ ┴ ┴ ┴┴─┘└─┘└─┘└─┘└─┘",
)
CAPTION = ("Shandalar 1997 · skin spec", "what a skin has to contain")

## THE MINI-HELP under the banner (tools/tool_banner.py): the two lines
## somebody actually types — a bare run REWRITES docs/skin-catalogue.txt,
## which is worth saying before it happens — and where the rest is. The
## first two open EPILOG below, one source for both. `WHERE` is `tools/`
## in a checkout and nothing beside a packaged game, where this tool also
## ships and a player runs it from a flat folder
## (tool_banner.here_prefix()).
WHERE = tool_banner.here_prefix(__file__)
HINT = (
    "python3 %sskin_catalogue.py                   # rewrite the catalogue" % WHERE,
    "python3 %sskin_catalogue.py --check my.zip    # what a skin is missing" % WHERE,
    "python3 %sskin_catalogue.py -h                # --stdout, --skin, --out" % WHERE,
)

EPILOG = """\
%s
    python3 %sskin_catalogue.py --skin DIR        measure another folder
    python3 %sskin_catalogue.py --stdout          print it, write nothing
    python3 %sskin_catalogue.py --check my_skin/  a folder works too

The catalogue is GENERATED from import_original.py's MANIFEST and
measured off an imported skin, so it cannot drift from the code; a key
with no note in this script makes the run refuse to write. --check
reads a skin's own catalogue.txt the way the game does, and says how
many of its pictures are worn at 1x, 2x, 3x or 4x their 1997 size. Every run that
writes the text writes the same catalogue as a table beside it, one row
per file of the skin zip (--out X.txt writes X.csv too).
--stdout IS the catalogue, so it goes to stdout alone and the banner
never joins it.

%s
""" % (tool_banner.examples(HINT), WHERE, WHERE, WHERE,
       tool_banner.BANNER_HELP)

DEFAULT_SKIN = ROOT / "assets" / "original"
DEFAULT_CARDART = ROOT / "assets" / "cardart"
DEFAULT_OUT = ROOT / "docs" / "skin-catalogue.txt"

ZIP_NAME = "original_skin.zip"
ART_ZIP_NAME = "cardart.zip"
PREFIX = "skin/"
ART_PREFIX = "skin/cardart/"
WIDTH = 78


# ------------------------------------------------------- the drawn floor --
# THE SEVEN KEYS THE GAME ALREADY HAS A PICTURE FOR. Since 2026-09-09 this
# project ships art of its own — `game/art/`, drawn from scratch by
# `tools/draw_our_art.gd`, never anybody else's file — and for these seven
# the game uses ITS OWN whatever the skin holds (the set symbols since
# 2026-09-10, the dagger since 2026-10-15). So a skin that leaves one of
# these out is not missing anything. Every other absent file is drawn in
# code instead, which is a different (and plainer) thing, and `--check`
# says which is which.

SHIPPED_BY_THE_GAME = {
    "set_icon_arn.png", "set_icon_atq.png", "set_icon_leg.png",
    "set_icon_drk.png", "set_icon_4ed.png", "set_icon_past.png",
    "damage_marker.png",
}


# ------------------------------------------------------------- the notes --
# One note per key, or per family of keys (a prefix). A key without a note
# is an error: the catalogue exists so that a skin maker is never left
# guessing what a file is for.

FAMILIES: list[tuple[str, str, str]] = [
    # (section, prefix-or-key, note)
    ("Backdrops", "title_background",
     "The title screen, stretched to the window. The menu is drawn over "
     "its right-hand side."),
    ("Backdrops", "menu_background",
     "Behind the Options, Deck Builder and Gauntlet screens."),
    ("Backdrops", "character_select_background",
     "Imported from the 1997 game (Advfac64.pic) for the day the "
     "character screen is built. NOT READ by the game yet."),

    ("The duel table", "duel_pattern_",
     "The table under each player's cards, one per deck colour: a "
     "wallpaper that repeats. Which of the three the table wears is the "
     "player's choice (Options > Territory); the opponent's side always "
     "matches its deck colour."),
    ("The duel table", "duel_picture_",
     "The second territory choice, a picture: its middle is stretched "
     "rather than repeated, keeping its own aspect."),
    ("The duel table", "duel_mana_",
     "The third territory choice, a repeating mana-symbol wallpaper."),

    ("Cards", "card_back",
     "The back of every face-down card: the library, a hidden hand."),
    ("Cards", "card_frame_",
     "The enlarged card's frame, one per colour, plus gold (multicolour), "
     "artifact and one land frame per colour. Name, cost, text and art "
     "are drawn on top at fixed anchors, so the layout must match the "
     "1997 frame: art window at the top, text box below."),

    ("The life panels", "life_panel_",
     "Each duelist's life plaque at the table's edge, in the deck's "
     "colour; the life total is printed on it."),
    ("The life panels", "duelist_face_",
     "The portrait's frame beside the life plaque, one per colour."),

    ("Windows and panels", "panel_stone",
     "The stone slab most windows and the main menu's buttons sit on "
     "(Options, Magic Battle, the Deck Builder's menus, prompts). The "
     "game makes it a seamless tile (its light evened out, its edges run "
     "into each other, its 3 px bevel kept) and lays it at its own size; "
     "a window that fits inside it wears it as drawn."),
    ("Windows and panels", "panel_dark_stone",
     "The darker slab: the match and gauntlet screens between duels, "
     "questions, fields and lists. Tiled like the sandstone: made "
     "seamless (light evened out, edges run into each other, 3 px bevel "
     "kept) and laid at its own size; a window that fits inside it wears "
     "it as drawn."),
    ("Windows and panels", "panel_knot",
     "The knotwork slab behind text-change prompts, the duel log and "
     "library searches. A pattern repeating every 94 x 52 px: the game "
     "tiles it in whole repeats inside its 3 px bevel, its light as drawn."),
    ("Windows and panels", "panel_end_duel",
     "The end-of-duel window's ground. Tiled like the sandstone; the "
     "duel's own verdict window fits inside it and wears it as drawn."),
    ("Windows and panels", "versus_background",
     "The opening window (the two duelists face to face) — a picture, "
     "so its middle is stretched, not tiled."),
    ("Windows and panels", "versus_splash",
     "The 'versus' splash inside the opening window."),
    ("Windows and panels", "message_panel",
     "The one-line message strip at the bottom of the table."),
    ("Windows and panels", "big_card_panel",
     "Behind the enlarged card."),
    ("Windows and panels", "mana_pool_panel",
     "The mana pool window's ground."),
    ("Windows and panels", "spell_chain_panel",
     "The 1997 spell-chain window's ground. NOT READ by the game yet — "
     "the stack is drawn its own way."),
    ("Windows and panels", "attack_panel",
     "The combat window's ground, drawn with a ruled border."),

    ("Buttons", "button_normal",
     "The stone button every window uses, at rest. Its top two pixel "
     "rows are the bevel; text is centred on it."),
    ("Buttons", "button_pressed",
     "The same button pressed."),
    ("Buttons", "button_disabled",
     "The same button greyed out."),
    ("Buttons", "stat_buttons",
     "The 1997 statistics buttons sheet. NOT READ by the game yet."),
    ("Buttons", "begin_menu",
     "The 1997 title menu's sprite, every frame, one column of 265x24 "
     "cells: the six menu words at rest and lit (0-13; Load Saved Game "
     "and Resume Game also greyed), then the Celtic-knot bullet at the "
     "cell's left — at rest, hovered, pressed (22x22, NOT READ) and "
     "dimmed (14-17). The bullet stands beside the title screen's menu "
     "buttons; the words are NOT READ yet."),

    ("The phase bars", "phase_bar",
     "The turn's steps down the table's edge: two columns of 41 px "
     "(the lit and the unlit state), rows of 41 px, each cell's picture "
     "35x40 at x offset 2. Eight slots top to bottom: untap, upkeep, "
     "draw, main, combat, second main, end, cleanup."),
    ("The phase bars", "combat_bar",
     "The combat steps, same rows: two seats of 82 px (attacker's and "
     "defender's), each a lit and an unlit column of 41 px, cell 35x40 "
     "at x offset 3."),

    ("The combat window's sprites", "attack_min",
     "The minimised combat window's tab."),
    ("The combat window's sprites", "attack_sword",
     "The attacker's sword: an IMAGE+MASK pair, the picture in the left "
     "half and its mask in the right half (see 'Masks' above)."),
    ("The combat window's sprites", "attack_shield",
     "The blocker's shield, image+mask left/right."),
    ("The combat window's sprites", "attack_bones",
     "The bone strip between attackers and blockers, image+mask TOP over "
     "BOTTOM."),

    ("The hand", "hand_panel_",
     "The hand's plaque, one per deck colour."),

    ("Graveyards", "grave_panel_",
     "The graveyard and exile plates beside the table, one per colour."),

    ("Marks on a card", "mana_stripes",
     "The diagonal mana stripes on a card's title bar: six rows of 21 px "
     "in the order W U B R G, then colourless. Each stripe is cut 17x16 "
     "and drawn 9 px apart so they interleave."),
    ("Marks on a card", "summon_sick",
     "The summoning-sickness spiral drawn over a creature that cannot "
     "attack yet: image+mask left/right."),
    ("Marks on a card", "state_dying",
     "The cracks over a creature that is about to die (image+mask)."),
    ("Marks on a card", "state_cant_target",
     "The 'cannot be targeted' mark (image+mask)."),
    ("Marks on a card", "state_will_untap",
     "The 'will untap' mark (image+mask)."),
    ("Marks on a card", "damage_marker",
     "The dagger on a wounded creature, image+mask left/right; the damage "
     "count is printed beside it. THE GAME ALWAYS USES ITS OWN (64x40, "
     "real alpha, no mask half), the same for every player: a file here "
     "is not read."),
    ("Marks on a card", "card_counters",
     "The counter stones: one column of 25 cells, 24 oval stones (a "
     "scythe, five lightning bolts, a gear, five ankhs, yin-yangs in "
     "five colours, grapes, a bird, tombstones, a drone, a whirl) and the "
     "one mask they share in the 25th; a permanent wears one per kind of "
     "counter with the count beside it."),
    ("Marks on a card", "target_cursor",
     "The mouse cursor while a target is being chosen: image+mask "
     "left/right, the hotspot at the arrow's tip."),
    ("Marks on a card", "ability_icons",
     "The keyword badges on a card, ONE COLUMN of 18 square cells "
     "(22x22). Cells used: 5 protection from green, 6 red, 7 blue, "
     "8 black, 9 white, 10 protection from artifacts, 11 flying, "
     "12 trample, 13 banding, 14 first strike, 15 regeneration, "
     "16 reach. Cell 17 is blank in the original and stays blank."),

    ("Symbols", "mana_symbols",
     "Every mana symbol in one row of 19 square cells (18x18): cell 0 "
     "{X}, cells 1-11 {0}-{10}, 12 {W}, 13 {R}, 14 {U}, 15 {B}, 16 {G}, "
     "17 {T} (tap). Cells sit on opaque black; the symbols are round."),
    ("Symbols", "card_set_symbols",
     "The set symbol printed on the enlarged card: five 33x15 cells at a "
     "66 px pitch, left to right The Dark, Legends, Arabian Nights, "
     "Antiquities, Astral."),
    ("Symbols", "set_icon_",
     "The Deck Builder's set filter icons, one per set code (atq, arn, "
     "past, drk, leg, 4ed). The original's own are 40x40 bevelled stone "
     "tiles carrying a gold-ringed medallion — the same art as cells of "
     "the filter sheet — and the game cuts each one down to that "
     "medallion's circle before drawing it on a card. "
     "THE GAME ALWAYS USES SIX OF ITS OWN (48x48, gold glyph, "
     "transparent ground), the same for every player: files here are "
     "not read."),

    ("The Deck Builder", "filter_icons",
     "The filter bar's medallions: 9 columns x 3 rows of 40 px cells, "
     "each icon 34x34 inside its cell, as (row, column). Row 0: ability "
     "(0,0), gold (0,1), Antiquities (0,2), Arabian Nights (0,3), "
     "artifact (0,4), artist (0,5), Astral (0,6), blue (0,7), cost "
     "(0,8). Row 1: creature (1,1), The Dark (1,2), enchantment (1,3), "
     "Fourth Edition (1,4), green (1,5), black (1,6), instant (1,7). "
     "Row 2: land (2,0), Legends (2,1), power (2,2), rarity (2,3), red "
     "(2,4), sorcery (2,6), toughness (2,7), white (2,8). The sheet is "
     "the twenty-seven 40x40 medallions of the original's Dbart folder, "
     "nine to a row in filename order. The _hover and _pressed sheets "
     "are OURS, not the original's: 1997 ships one state per medallion, "
     "so those two are this one scaled to 1.26 and 0.5."),
    ("The Deck Builder", "deck_slot_plaques",
     "The empty deck slot watermarks: 5 columns of 117 px x 2 rows of "
     "100 px, in the order black, white, red, green, blue."),
    ("The Deck Builder", "deck_title_slab",
     "The slab the deck's name sits on."),
    ("The Deck Builder", "deck_bar_ground",
     "The ground under the Deck Builder's bottom bar."),
    ("The Deck Builder", "deck_tile_slate",
     "The Deck Builder's tiling ground (32x32, repeats)."),
    ("The Deck Builder", "deck_tile_olive",
     "The olive tile of the 1997 Deck Builder. NOT READ by the game yet."),

    ("Fonts", "font_title",
     "The display face: titles, headings, the card's name "
     "(the original's MagicMedieval)."),
    # NO `font_body` NOTE: there is no such key. The reading face — card
    # text, menus, the log — is the game's own Spectral (OFL, shipped in
    # the game) for every player; a skin's body font is not read
    # (2026-10-15).

    ("Sounds", "sfx_",
     "Sound effects. The names say when they play: sfx_tap, sfx_untap, "
     "sfx_draw, sfx_shuffle, sfx_summon, sfx_attack, sfx_block, "
     "sfx_damage, sfx_buried (a card to the graveyard), sfx_counter, "
     "sfx_discard, sfx_end_turn, sfx_life_loss, sfx_mana_burn "
     "(life lost to unspent mana), sfx_button, sfx_toss "
     "(the coin), sfx_win and sfx_lose (the fanfares), one sfx_cast_* "
     "per spell type, and one sfx_land_* per land colour or colour pair "
     "(a dual land plays its pair; sfx_land_grey is a colourless land)."),

    ("Music", "music_duel",
     "The duel's tune."),
    ("Music", "music_temple",
     "The shell's tune for a temple."),
    ("Music", "music_castle_",
     "One shell tune per castle colour."),
    ("Music", "music_location_",
     "The twenty overworld location tunes, 0 to 19. The title screen and "
     "the shell pick from these; Options > Music lists every tune the "
     "skin and the player's own music/ folder provide."),

    ("Movies", "coin_toss_",
     "The coin toss, as a SPRITE SHEET the game plays frame by frame: "
     "the frames left to right, top to bottom, and a .json sidecar of "
     "the same name with cols, rows, frames, frame_width, frame_height "
     "and fps. The sheet is what the game reads; the AVI it was cut from "
     "may ride along in movies/ (see below) but is not required."),
]

SECTION_ORDER = [
    "Backdrops", "The duel table", "Cards", "The life panels",
    "Windows and panels", "Buttons", "The phase bars",
    "The combat window's sprites", "The hand", "Graveyards",
    "Marks on a card", "Symbols", "The Deck Builder", "Fonts", "Sounds",
    "Music", "Movies",
]

PREAMBLE = """\
THE SKIN — what original_skin.zip and cardart.zip contain
=========================================================

Shandalar dresses itself in a SKIN: the pictures, fonts, sounds, tunes,
movies and portraits of the 1997 game, or any set drawn to the same
shapes. Without one the game is complete and playable in its own plain
drawing; with one, every panel, card and button wears the art. Every
file is optional: a file that is missing falls back, one file at a
time, to a shape drawn in code, and the skin's own file wins whenever
it is there. Seven names below are the exception — the six set symbols
and the damage dagger: the game always wears its OWN picture for those,
drawn by the project itself, and a skin's file under those names is not
read.

TWO ZIPS. The skin and the card art travel apart, because they come
from different places (a 1997 disc; a download) and are different
sizes (84 MB; 193 MB). Each is a zip with ONE folder inside it, skin/,
and nothing outside that folder:

    original_skin.zip                   the 1997 art
      skin/
        title_background.png
        card_back.png
        ...
        font_title.ttf
        sfx_tap.wav
        music_duel.wav
        coin_toss_heads.png  +  coin_toss_heads.json
        portraits/agnosia.png ...
        movies/cointoss_heads.avi ...        (optional)

    cardart.zip                         one picture per card
      skin/
        cardart/lightning_bolt.jpg ...

The game tells the two apart by what they HOLD, not by their names: a
zip whose every entry is under skin/cardart/ is card art, any other is
a skin. (A skin zip that carries a cardart/ folder of its own is still
a skin, and its pictures are read too.) A zip with a loose file at its
top is refused whole, because the game mounts the zip into its own
resource tree and a stray file would land among the game's scripts.

WHERE THEY GO. The game reads the zips in place; nothing is unpacked.
  * Beside the game: <the game's folder>/skin/original_skin.zip and
    <the game's folder>/skin/cardart.zip. Neither is in the game's
    own zip: the skin zip is a download of its own beside it, to be
    put there (or chosen, below); the card art is nobody's to ship —
    the pictures are Scryfall's — and is built by the scripts in the
    game's folder (fetch_card_art.py, then mtg_assets.py
    --from-cardart) in a few minutes.
  * Chosen in Options > Skin: the Skin row says which zip dresses the
    game now, by its path, and its Choose... button opens a file box.
    A skin zip chosen is copied into the game's skins folder
    (user://skins/, under its own name) and worn from the next start;
    a card art zip goes into the card folder (user://cardpacks/), where
    EVERY zip is a pack the game wears, in name order, the first to
    hold a picture winning — so packs for card sets of the future sit
    beside the first. The Card folder row names the folder and every
    pack in it; to go back to what shipped, delete the zip from the
    folder the row names. In a browser the file box is the browser's
    own, and Forget my zips (there is no folder to open) deletes them
    all.
  * Dropped on the window: drag any zip onto the running game. The
    same as choosing it.
  * A tar.gz (or .tgz, or a plain .tar) works at every door a zip
    does — chosen, dropped, or read in by a browser. The game cannot
    mount a tar, so it repacks one into a zip of the same name, once,
    in the folder of its kind (my_skin.tar.gz -> skins/my_skin.zip),
    and from then on it is that zip; the tar itself is left where it
    was. Beside the game the same: skin/original_skin.tar.gz (or
    skin/cardart.tar.gz) where the zip would go is repacked at the
    first start into the game's own folder and read from there.
  * ONE SKIN IS WORN, never two mixed: your own skin zip (chosen,
    dropped or fetched; the skin_zip key names it) or, without one, the
    one beside the game. A skin chosen or dropped is worn from the next
    start, and the notice that says so offers the restart; only on the
    title screen, with no skin worn yet, does the title simply start
    again in it.
  * In a browser: the same choosing and dropping, or a skin zip served
    beside the page as skin/original_skin.zip (and, on a page served
    on your own machine, skin/cardart.zip), which the game fetches
    once and keeps.
  * A loose folder works too, when no skin zip is worn: the skin
    folder, user://original_skin/ (what import_original.py fills),
    then <the game's folder>/skin/ with the same files unzipped. "Use
    the skin folder instead of the zip" in Options > Skin leaves every
    skin zip closed, so the folder dresses the game even where a zip
    is there.
  * Every one of those places — the skin zip, the skin folder, the
    card folder, and the portraits and music folders — is shown by
    its path in Options > Skin and can be moved in settings.cfg
    (skin_zip, skin_folder, cardpacks_folder, portraits_folder,
    music_folder under [options]); the screen names the file.

NAMING. The names below are the PLACES the game looks for: exact,
lower case, snake_case, with the extensions given here. The file of a
place's own name is worn there, unless the skin's catalogue (below)
puts another file there. A picture is a PNG (RGB, or RGBA where a mask
is wanted); a font is TrueType; a sound is a WAV. The sizes below are
the 1997 originals'; SIZES AND SCALES says what else a picture may be.

THE CATALOGUE. A skin may carry skin/catalogue.txt, which says which of
its files the game wears in each place, one line a place:

    title_background.png = title_background@2x.png
    duelist_face_red.png = duelist_face_red.png
    portraits/agnosia.png = faces/my_agnosia.png

The place on the left is a name from the lists below (a portrait's
too); the file on the right is any file of the same skin, its path from
skin/. Blank lines and lines starting with # are notes; spaces around
the = do not matter; a line with no =, with nothing on one side, or
with a file that starts with /, holds a \\ or climbs out with .., is
ignored; a place named twice takes its last line, and a line whose file
is not in the skin counts as no line. For a place with no line the game
takes, for a picture, <name>@2x.png beside it when the skin holds one
(the name the 0.50.28 tool gave its 2x pictures), and otherwise the
file of the place's own name — so a skin without a catalogue, every
1997 skin and the hi-res skin among them, is worn as it always was.

MIX AND MATCH. The hi-res skin (below) is the 1997 skin's files with
the pictures at twice the size, under the same names: to wear a 1997
picture in one place, put the 1997 file back into it under its name.
A catalogue does the same without replacing anything: keep the 1997
picture under another name, or the 2x one as <name>@2x.png beside the
1997 <name>.png, and point the place's line where you want it — a line
naming the place itself (duelist_face_red.png = duelist_face_red.png)
wears the 1x file over an @2x one. Unzip, edit, zip again — or edit a
loose skin folder; the game reads it at the next start. --check (below)
reads it too.

SIZES AND SCALES. Every picture place has the 1997 size listed below,
and the game lays its screens out at that size. The hi-res skin's
pictures are its places' own names at twice it. A picture may be:
  * that size (1x): worn as it is;
  * exactly 2, 3 or 4 times it, in both directions (2x, 3x, 4x): drawn
    at the 1997 size with all its pixels, so on a big screen it is
    sharp where a 1x picture is stretched. Everything the game cuts out
    of a picture (a sheet's cells, a panel's border, a badge, a sprite)
    it cuts at the picture's own resolution, from the same place;
  * any other size: drawn at its own size, as a skin always could be —
    fine for a backdrop or a panel the game stretches, but a SHEET (a
    file the game cuts into cells) must keep its grid, and frames and
    panels their proportions, or the text drawn on them lands wrong.
A few pictures are KEYED: the game takes a colour out of them (the
black around the mana stripes and the set symbols, the white of the
combat bar), reads an image+mask pair's mask (below), or measures them
(a territory's black edge, the grave plate's colours, the target
cursor). For a 2x, 3x or 4x picture it decides those on the picture
brought back to its 1997 size — every 2x2 block averaged — and carries
the result up; the mana stripes on the cards, the set symbols and the
territories' edges stay hi-res. tools/upscale_skin.py makes those
pictures KEY-EXACT: each block averages to its 1997 pixel, so what the
game brings back is the 1997 picture and it cuts exactly what the 1997
skin cuts. A plain upscale does not (measured on the real 2x pictures:
the stripes' cut-out edges moved by up to a tenth, the set symbols lost
their ink box, the territories their black-edge trim). For a skin of
your own at 2x, keep the key colours clean — the black around the
stripes and symbols, the white of the combat bar, a territory's 1px
black edge — or keep the 1x file beside the 2x one: <name>.png at the
1997 size, <name>@2x.png at twice it, and the game keys on the 1x file.
The keyed places: mana_stripes, card_set_symbols, combat_bar,
card_counters, the image+mask sprites (summon_sick, state_*, attack_*,
target_cursor), and every duel_pattern_*, duel_picture_*, duel_mana_*
and grave_panel_*. --check says when a skin wears keyed places above
1x with no 1x file.

Portraits and card art are fitted to their frames at any size (a 2x
portrait — its own name at twice the size, or <name>@2x.png beside its
1x file — is one face, drawn at the 1x size); the
coin-toss sheets are read as their .json describes them, in their own
pixels.

MASKS. Some 1997 sprites carry their transparency as a second picture:
the file is twice as wide as the sprite, the left half the image and
the right half its mask (or, for attack_bones, twice as tall, image over
mask). The mask's top-left pixel is background; whichever tone it has
means "transparent". A new skin may instead ship the sprite at half the
size with real alpha — the game reads both.

TO DRAW YOUR OWN. Make a folder named skin/ and put in it, under the
exact names below, whatever you have drawn — a few files or all of
them; for each one missing the game falls back to its own (see
above). Zip the folder so that skin/ is the top of the zip (from the
folder above it:
    zip -r my_skin.zip skin
or, just as well, tar czf my_skin.tar.gz skin
) and check it:
    python3 tools/skin_catalogue.py --check my_skin.zip
then choose it in Options > Skin, or drop it on the game's window. Card
pictures go the same way, under skin/cardart/, in a zip of their own —
a card pack, one of any number in the card folder.

TO BUILD THE 1997 ONES from your own disc, and the card art:
    python3 tools/mtg_assets.py --install /path/to/the/1997/game
    python3 tools/fetch_card_art.py --out cardart/
    python3 tools/mtg_assets.py --from-cardart cardart/ --out cardart.zip
The 1997 skin is the default, and the only one a release carries. With
no 1997 disc, the tool can read a later Manalink install as a backup,
where its own pictures fit, for your own copy only; see first, file by
file, what you would get:
    python3 tools/mtg_assets.py --check /path/to/manalink --manalink
    python3 tools/mtg_assets.py --install /path/to/manalink --manalink
And from your own 1997 skin, THE HI-RES SKIN: the same files as your
1997 skin, under the same names, every picture at twice the size
(Real-ESRGAN's anime model, with the 1997 colours, the keyed places
made exact), original_skin_realesrgan-anime_2x.zip. Choose it in
Options > Skin like the 1997 one, and choose the 1997 one to go back:
    python3 tools/upscale_skin.py --skin original_skin.zip
With 2x pictures made before (the zip the 0.50.28 tool wrote), --reuse
takes each one that is a copy of the same picture as it is and upscales
only the rest:
    python3 tools/upscale_skin.py --skin original_skin.zip \\
        --reuse original_skin_realesrgan-anime_2x.zip
"""

PORTRAITS_NOTE = """\
The duelists' faces, one PNG per portrait, chosen in Options > Portrait
and shown beside the life plaque. The file's name is the portrait's id,
lower case with underscores between words; the chooser shows it with
the underscores as spaces and each word capitalised
(ali_of_willoshire.png -> "Ali Of Willoshire"). Any
number of files, any size close to the original's — they are scaled to
fit the frame. The 1997 game had 70: the 15 of its character sheet
(137x169) and the 55 rogues (138x170)."""

CARDART_NOTE = """\
The picture in the enlarged card's art window, one file per card, named
by the card's name in snake_case: lower case, every run of characters
that is not a letter or a digit replaced by one underscore, leading and
trailing underscores dropped ("Ali from Cairo" -> ali_from_cairo,
"Jandor's Saddlebags" -> jandor_s_saddlebags, "Ley Druid" -> ley_druid).
PNG or JPG, any size — it is fitted to the frame's art window. A card
without a file shows the frame's plain window. These travel in their
own zip, cardart.zip, as skin/cardart/<card_name>.jpg;
tools/fetch_card_art.py fetches the pool from Scryfall and
tools/mtg_assets.py --from-cardart zips it."""

MOVIES_NOTE = """\
The original coin-toss AVIs (COINTOSS_Heads.AVI, COINTOSS_Tails.AVI),
kept beside the sheets they were cut from so a player can re-cut them
(tools/mtg_assets.py --transcode-movies). The game plays the SHEETS, not
the AVIs; a skin that ships only the sheets is complete."""


# ---------------------------------------------------------- measuring --

def png_size(path: Path) -> tuple[int, int, str] | None:
    """Width, height and colour kind from the header alone."""
    try:
        head = path.read_bytes()[:33]
    except OSError:
        return None
    return png_shape(head)


def png_shape(head: bytes) -> tuple[int, int, str] | None:
    """[method png_size] of a PNG's first 33 bytes, wherever they were read."""
    if len(head) < 26 or head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
        return None
    width, height = struct.unpack(">II", head[16:24])
    kind = {0: "grey", 2: "RGB", 3: "palette", 4: "grey+alpha",
            6: "RGBA"}.get(head[25], "?")
    return width, height, kind


def wav_shape(path: Path) -> str | None:
    """'22050 Hz 16-bit mono, 1.2 s' or None."""
    try:
        with wave.open(str(path), "rb") as w:
            channels = w.getnchannels()
            rate = w.getframerate()
            bits = w.getsampwidth() * 8
            seconds = w.getnframes() / float(rate) if rate else 0.0
    except (wave.Error, EOFError, OSError):
        return None
    voice = {1: "mono", 2: "stereo"}.get(channels, "%d ch" % channels)
    return "%d Hz %d-bit %s, %.1f s" % (rate, bits, voice, seconds)


def font_shape(path: Path) -> str | None:
    try:
        head = path.read_bytes()[:4]
    except OSError:
        return None
    if head in (b"\x00\x01\x00\x00", b"true"):
        return "TrueType"
    if head == b"OTTO":
        return "OpenType (CFF)"
    return None


def sidecar_shape(path: Path) -> str | None:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    if not isinstance(data, dict):
        return None
    keys = ("cols", "rows", "frames", "frame_width", "frame_height", "fps")
    parts = []
    for key in keys:
        if key in data:
            value = data[key]
            parts.append("%s %s" % (key, ("%.2f" % value).rstrip("0").rstrip(".")
                                    if isinstance(value, float) else value))
    return ", ".join(parts) if parts else "json"


def file_name(key: str) -> str:
    """The file a manifest key names: pictures get `.png`, the rest carry
    their extension in the key (`sfx_tap.wav`, `font_title.ttf`)."""
    return key if "." in key else key + ".png"


def measure(path: Path) -> str:
    """One line about the file: its size and kind, or '(not on this
    machine)' when the skin folder has no such file."""
    if not path.is_file():
        return "(not on this machine)"
    ext = path.suffix.lower()
    if ext == ".png":
        shape = png_size(path)
        return "%d x %d px, %s" % shape if shape else "PNG?"
    if ext == ".wav":
        return wav_shape(path) or "WAV?"
    if ext == ".ttf":
        return font_shape(path) or "font?"
    if ext == ".json":
        return sidecar_shape(path) or "json?"
    if ext == ".avi":
        head = importer.read_avi_header(path)
        if head:
            return "%d x %d, %d frames, %.2f fps, %s" % (
                head["width"], head["height"], head["frames"],
                head["fps"], head["codec"])
        return "AVI?"
    return "%d bytes" % path.stat().st_size


# ------------------------------------------------------------- the keys --

def all_keys() -> list[str]:
    """Every name the importer writes, in the importer's order."""
    return (list(importer.MANIFEST) + list(importer.PIC_SCREENS)
            + list(importer.VIDEOS))


def note_for(key: str) -> tuple[str, str] | None:
    """(section, note) — an exact key first, then the longest prefix."""
    stem = key.split(".")[0]
    best: tuple[str, str] | None = None
    best_len = -1
    for section, prefix, note in FAMILIES:
        if prefix == stem:
            return section, note
        if stem.startswith(prefix) and len(prefix) > best_len:
            best, best_len = (section, note), len(prefix)
    return best


def sections() -> dict[str, list[str]]:
    """Keys grouped by section, the sections in SECTION_ORDER; raises on
    a key nobody wrote a note for."""
    out: dict[str, list[str]] = {name: [] for name in SECTION_ORDER}
    for key in all_keys():
        found = note_for(key)
        if found is None:
            raise KeyError("no catalogue note for %r — add one to FAMILIES" % key)
        out[found[0]].append(key)
    return out


def families_of(keys: list[str]) -> list[tuple[str, list[str]]]:
    """The keys of one section grouped under their note, families in the
    order the manifest first reaches them — so a family the importer
    lists in two runs (the set icons, split by the symbol strip) is
    catalogued once."""
    out: list[tuple[str, list[str]]] = []
    for key in keys:
        note = note_for(key)[1]
        for entry in out:
            if entry[0] == note:
                entry[1].append(key)
                break
        else:
            out.append((note, [key]))
    return out


def expected_files() -> list[str]:
    """Every file a complete skin has, relative to skin/ (the sheets'
    sidecars included; portraits and card art are open-ended)."""
    files = [file_name(key) for key in all_keys()]
    for key in importer.VIDEOS:
        files.append(key + ".json")
    return files


# ------------------------------------------------------------- writing --

def wrap(text: str, indent: int) -> list[str]:
    return textwrap.wrap(text, WIDTH, initial_indent=" " * indent,
                         subsequent_indent=" " * indent)


def render(skin: Path, cardart: Path) -> str:
    lines: list[str] = [PREAMBLE]
    grouped = sections()
    for section in SECTION_ORDER:
        keys = grouped[section]
        if not keys:
            continue
        lines.append("")
        lines.append(section.upper())
        lines.append("-" * len(section))
        for note, family in families_of(keys):
            lines.append("")
            lines.extend(wrap(note, 2))
            for key in family:
                name = file_name(key)
                lines.append("    %-34s %s" % (name, measure(skin / name)))
                if key in importer.VIDEOS:
                    side = key + ".json"
                    lines.append("    %-34s %s" % (side, measure(skin / side)))
    # The open-ended folders.
    lines.append("")
    lines.append("PORTRAITS — portraits/<id>.png")
    lines.append("---------")
    lines.append("")
    lines.extend(wrap(PORTRAITS_NOTE.replace("\n", " "), 2))
    faces = sorted(p for p in (skin / "portraits").glob("*.png")) \
        if (skin / "portraits").is_dir() else []
    if faces:
        sizes: dict[tuple[int, int], int] = {}
        for face in faces:
            shape = png_size(face)
            if shape:
                sizes[shape[:2]] = sizes.get(shape[:2], 0) + 1
        lines.append("")
        lines.append("    on this machine: %d portraits — %s" % (
            len(faces), ", ".join("%d at %dx%d" % (n, w, h)
                                  for (w, h), n in sorted(sizes.items(), key=lambda i: -i[1]))))
        lines.append("    e.g. " + ", ".join(p.name for p in faces[:4]) + " ...")
    lines.append("")
    lines.append("CARD ART — cardart.zip: cardart/<card_name>.jpg|png")
    lines.append("--------")
    lines.append("")
    lines.extend(wrap(CARDART_NOTE.replace("\n", " "), 2))
    art = sorted(p for p in cardart.iterdir()
                 if p.suffix.lower() in (".jpg", ".png")) if cardart.is_dir() else []
    if art:
        kinds: dict[str, int] = {}
        for p in art:
            kinds[p.suffix.lower()] = kinds.get(p.suffix.lower(), 0) + 1
        lines.append("")
        lines.append("    on this machine: %d pictures — %s" % (
            len(art), ", ".join("%d %s" % (n, k) for k, n in sorted(kinds.items()))))
        lines.append("    e.g. " + ", ".join(p.name for p in art[:3]) + " ...")
    lines.append("")
    lines.append("MOVIES — movies/*.avi (optional)")
    lines.append("------")
    lines.append("")
    lines.extend(wrap(MOVIES_NOTE.replace("\n", " "), 2))
    movies = sorted((skin / "movies").glob("*.avi")) if (skin / "movies").is_dir() else []
    if movies:
        lines.append("")
        for movie in movies:
            lines.append("    %-34s %s" % ("movies/" + movie.name, measure(movie)))
    lines.append("")
    lines.append("-" * WIDTH)
    lines.append("Generated by tools/skin_catalogue.py from the importer's manifest;")
    lines.append("%d named files, plus portraits/ and movies/ in original_skin.zip,"
                 % len(expected_files()))
    lines.append("and cardart/ in cardart.zip.")
    return "\n".join(lines) + "\n"


# ------------------------------------------------------------- the table --
#
# THE SAME CATALOGUE AS A TABLE. The owner, 2026-10-17: *"Create also a
# csv list of all assets (also concrete filenames) in the skin zip
# (folder) so we have a catalogue!"* One row per file a complete
# `original_skin.zip` holds, by the name it has inside the zip: every
# named file and sheet layout, each of the seventy portraits by its own
# name, and the two movies. The notes and the measurements are the text's
# own, so the two cannot disagree. Card art is its own zip, one picture
# per card, and is left out. Written beside the text
# (`docs/skin-catalogue.csv`, shipped as `skin/SKIN.csv`).
#
# `from_the_1997_game` is the file (or files) the importer takes it from;
# `manalink_backup` is what `import_original.py --manalink` would take
# instead for a player with no 1997 copy — a backup in the tool for a
# player's own folder, never a release skin (tools/import_manalink.py).
CSV_COLUMNS = ("file", "section", "kind", "read_by_game", "format",
               "from_the_1997_game", "manalink_backup", "description")

KINDS = {".png": "picture", ".json": "sheet layout", ".ttf": "font",
         ".wav": "sound", ".avi": "movie"}


def read_by_game(key: str) -> str:
    if file_name(key) in SHIPPED_BY_THE_GAME:
        return "no: the game always uses its own"
    if key in importer.NOT_READ or key in importer.PIC_SCREENS:
        return "no: nothing reads it yet"
    return "yes"


def from_1997(key: str) -> str:
    if key in importer.PIC_SHEETS:
        cells = importer.PIC_SHEETS[key][0]
        return "assembled from %d cells: %s" % (len(cells), " ".join(cells))
    if key in importer.DERIVED_SHEETS:
        return "ours, drawn from %s.png" % importer.DERIVED_SHEETS[key][0]
    if key in importer.VIDEOS:
        return "cut from " + " or ".join(importer.VIDEOS[key])
    names = importer.MANIFEST.get(key) or importer.PIC_SCREENS.get(key) or []
    return " or ".join(names)


def manalink_backup(key: str) -> str:
    if key in manalink.NOT_USED:
        return "not used: " + manalink.NOT_USED[key]
    if key in manalink.FRAMES:
        return "Classic %s + %s, laid together" % manalink.FRAMES[key]
    if key in manalink.MANALINK:
        return " or ".join(manalink.MANALINK[key].names)
    if importer.is_sound_key(key):
        return "Manalink's own copy of the same file, where it has one"
    return ""


def portrait_rows() -> list[tuple[str, str, str]]:
    """(file name, the 1997 source, description) for every face a
    complete 1997 install gives, in the importer's own names."""
    rows = [(importer.portrait_name(i) + ".png", "16faces.spr frame %d" % i,
             "A player's face, from the 1997 character sheet")
            for i in range(len(importer.PORTRAIT_NAMES))]
    rows.append((importer.PLAYER_FACE_NAME + ".png", "Face.pic",
                 "The Facemaker face, the one the 1997 face builder wrote"))
    rows += [(importer.rogue_name(slot) + ".png", "Faces/%03d.pic" % slot,
              "An enemy's face (@DECKFACES entry %d)" % slot)
             for slot in range(1, len(importer.ROGUE_NAMES) + 1)]
    return rows


def table_rows(skin: Path) -> list[dict[str, str]]:
    def shape(path: Path) -> str:
        return measure(path) if path.is_file() else ""

    rows: list[dict[str, str]] = []
    grouped = sections()
    for section in SECTION_ORDER:
        for note, family in families_of(grouped[section]):
            for key in family:
                names = [file_name(key)]
                if key in importer.VIDEOS:
                    names.append(key + ".json")
                for name in names:
                    rows.append({
                        "file": PREFIX + name, "section": section,
                        "kind": KINDS.get(Path(name).suffix, "file"),
                        "read_by_game": read_by_game(key),
                        "format": shape(skin / name),
                        "from_the_1997_game": from_1997(key),
                        "manalink_backup": manalink_backup(key),
                        "description": note})
    for name, source, what in portrait_rows():
        rows.append({
            "file": PREFIX + "portraits/" + name, "section": "Portraits",
            "kind": "portrait", "read_by_game": "yes",
            "format": shape(skin / "portraits" / name),
            "from_the_1997_game": source, "manalink_backup": "",
            "description": what})
    for key, sources in importer.VIDEOS.items():
        name = sources[0].lower()
        rows.append({
            "file": PREFIX + "movies/" + name, "section": "Movies",
            "kind": "movie",
            "read_by_game": "no: kept to re-cut %s.png" % key,
            "format": shape(skin / "movies" / name),
            "from_the_1997_game": sources[0], "manalink_backup": "",
            "description": "The original coin-toss movie (optional)"})
    return rows


def render_csv(skin: Path) -> str:
    out = io.StringIO()
    writer = csv.DictWriter(out, fieldnames=CSV_COLUMNS, lineterminator="\n")
    writer.writeheader()
    writer.writerows(table_rows(skin))
    return out.getvalue()


# -------------------------------------------------------------- checking --

## THE GAME'S DOOR, MIRRORED (bug pass 2026-10-03). `--check` approved —
## "skin, 0 files", exit 0 — an empty zip, a zip of folders alone, a
## backslashed name and a `.tar.xz`, every one of which the game refuses.
## What it takes is two functions of game/, and these follow them:
##   * `TarPack.is_tar`: a tar is a GZIP header or `ustar` at byte 257 —
##     by its bytes, never its name, so xz and bzip2 are not tars;
##   * `SkinPack._take`/`adopt`: a file NAMED as a tar (TAR_TAILS) whose
##     bytes are none is refused before it is ever read as a zip;
##   * `TarPack`: regular files only, a name's `./` and `/` at the front
##     dropped and its backslashes made slashes; no file at all is a refusal;
##   * `SkinPack.inspect` (over the zip a tar becomes, too): at least one
##     file, every one under `skin/`, none with `..` or a backslash.
TAR_TAILS = (".tar.gz", ".tgz", ".tar")
NOT_A_TAR = "is not a tar the game can read"


def is_tar(target: Path) -> bool:
    """`TarPack.is_tar`: gzipped (the two magic bytes) or plain (`ustar`
    at 257), by content."""
    with target.open("rb") as handle:
        head = handle.read(262)
    return head[:2] == b"\x1f\x8b" or head[257:262] == b"ustar"


def tidy(name: str) -> str:
    """`TarPack._tidy`: an entry's name as the zip made of it carries it."""
    out = name.replace("\\", "/")
    while out.startswith("./"):
        out = out[2:]
    while out.startswith("/"):
        out = out[1:]
    return out


def archive_names(target: Path) -> tuple[list[str] | None, str]:
    """(every file the game would mount, with its `skin/`; "") — or
    (None, the game's reason for refusing it)."""
    if is_tar(target):
        names = []
        try:
            with tarfile.open(target) as tf:
                for member in tf.getmembers():
                    if member.type not in (tarfile.REGTYPE, tarfile.AREGTYPE):
                        continue   # a directory, a link, a device
                    name = tidy(member.name)
                    if name and not name.endswith("/"):
                        names.append(name)
        except (tarfile.TarError, OSError, EOFError) as err:
            return None, "%s (%s)" % (NOT_A_TAR, err)
        if not names:
            return None, "holds no files"
    elif target.name.lower().endswith(TAR_TAILS):
        return None, NOT_A_TAR
    elif zipfile.is_zipfile(target):
        with zipfile.ZipFile(target) as zf:
            names = [n for n in zf.namelist() if not n.endswith("/")]
    else:
        return None, "not a zip file"
    for name in names:
        if not name.startswith(PREFIX) or ".." in name or "\\" in name:
            return None, "an entry outside skin/: " + name
    if not names:
        return None, "no skin/ folder inside"
    return names, ""


def names_in(target: Path) -> list[str] | None:
    """The files a skin zip, tar (plain or gzipped) or folder holds,
    relative to skin/; None when the game would refuse the archive (the
    reason is printed) or the target is none of those."""
    if target.is_dir():
        return sorted(str(p.relative_to(target)).replace("\\", "/")
                      for p in target.rglob("*")
                      if p.is_file() and not p.name.endswith(".import"))
    if not target.is_file():
        return None
    names, why = archive_names(target)
    if names is None:
        print("!! %s: %s" % (target.name, why))
        return None
    return sorted(name[len(PREFIX):] for name in names)


def kind_of(names: list[str]) -> str:
    """"cardart" when every file is a card picture, else "skin" — the
    same rule the game applies (`SkinPack.inspect`)."""
    if names and all(n.startswith("cardart/") for n in names):
        return "cardart"
    return "skin"


# ------------------------------------------------------------ the catalogue --
#
# THE SKIN'S OWN CATALOGUE (2026-10-17). The owner: *"game should just
# pickup images according to some catalogue in the skin where every image
# is assigned to a specific location game looks for (not looking for
# specific image file names) - maybe the key should be original file
# names but modders can then put any image to these names"*. So a skin may
# carry `skin/catalogue.txt`, one line a place, `<place> = <file>`: the
# place a name the game looks for (this catalogue's lists), the file any
# file of the same skin. A place with no line, or whose file is not there,
# is worn from the file of its own name — which is every skin made before
# it. The game reads it in game/skin.gd; [method parse_catalogue] is that
# reading, rule for rule, so `--check` says what the game will do.
CATALOGUE = "catalogue.txt"
## Files a skin carries that are no place of the game's: the catalogue
## itself, and the note the 0.50.28 upscale tool wrote with its copies.
SKIN_NOTES = (CATALOGUE, "UPSCALE.txt")

## THE @2x NAME. The 0.50.28 tool called a 2x picture `<name>@2x.png`,
## beside `<name>.png` (tools/upscale_skin.py now writes a picture at 2x
## under its own name), and the owner kept those names valid (2026-10-17:
## *"I already have built 2x skin so we will reuse it also so keep the
## previous skin filenames also valid for skin reader"*). So for a picture place the game looks, in order, for the
## catalogue line's file, then `<name>@2x.png` beside the place, then the
## place's own name ([method worn_file]) — a line `x.png = x.png` is what
## wears the 1x file over an @2x one. `@2x` only: a 3x or 4x picture is
## worn through a catalogue line.
SCALED_SUFFIX = "@2x"


def scaled_name(place: str) -> str:
    """`portraits/agnosia.png` -> `portraits/agnosia@2x.png`."""
    return place[:-len(".png")] + SCALED_SUFFIX + ".png"


def is_scaled(name: str) -> bool:
    return name.endswith(SCALED_SUFFIX + ".png")


def worn_file(place: str, places: dict[str, str], have: set[str]) -> str | None:
    """The file the game wears in [param place]: its catalogue line's file
    when that is in the skin; for a picture, else `<name>@2x.png` beside
    it; else the place's own name; None when the skin holds none of them."""
    line = places.get(place)
    if line is not None and line in have:
        return line
    if place.endswith(".png") and scaled_name(place) in have:
        return scaled_name(place)
    return place if place in have else None


def parse_catalogue(text: str) -> tuple[dict[str, str], list[str]]:
    """(place -> file, the lines the game ignores). Blank lines and lines
    whose first non-space character is `#` are notes. A line is split at
    its first `=`, both sides stripped; one with no `=`, an empty side, or
    a file that starts with `/`, holds a backslash or has a `..` part is
    ignored. A place named twice takes its last line."""
    places: dict[str, str] = {}
    ignored: list[str] = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        place, equals, file = line.partition("=")
        place, file = place.strip(), file.strip()
        if (not equals or not place or not file or file.startswith("/")
                or "\\" in file or ".." in file.split("/")):
            ignored.append(line)
            continue
        places[place] = file
    return places, ignored


def read_catalogue(text: str) -> dict[str, str]:
    """The places a catalogue's text gives files for (parse_catalogue)."""
    return parse_catalogue(text)[0]


def read_files(target: Path, names: set[str], limit: int | None = None) -> dict[str, bytes]:
    """The bytes of each of [param names] (paths under `skin/`) that a
    skin folder, zip or tar holds — the first [param limit] of each, or
    all of it. One pass over a tar."""
    out: dict[str, bytes] = {}
    size = -1 if limit is None else limit
    if target.is_dir():
        for name in names:
            path = target / name
            if path.is_file():
                with path.open("rb") as handle:
                    out[name] = handle.read(size)
        return out
    if is_tar(target):
        with tarfile.open(target) as tf:
            for member in tf.getmembers():
                if member.type not in (tarfile.REGTYPE, tarfile.AREGTYPE):
                    continue
                name = tidy(member.name)
                if name.startswith(PREFIX) and name[len(PREFIX):] in names:
                    handle = tf.extractfile(member)
                    if handle is not None:
                        out[name[len(PREFIX):]] = handle.read(size)
        return out
    with zipfile.ZipFile(target) as zf:
        for name in names:
            try:
                with zf.open(PREFIX + name) as handle:
                    out[name] = handle.read(size)
            except KeyError:
                pass
    return out


# ------------------------------------------------------ sizes and scales --
#
# WHAT A PICTURE MAY MEASURE (2026-10-17, the owner: *"document what kind
# of resolutions are supported so croppers in game know what to do"*).
# Every picture place has its 1997 size, the size the game lays the
# screens out at (game/skin.gd's SIZES, held to the table below by
# tools/test_skin_catalogue.py). A picture exactly 1, 2, 3 or 4 times it
# is drawn at that size with all its pixels, and the game's cutters cut it
# at its own resolution; any other size is drawn at its own size, as a
# skin always could be. `--check` reads them against the catalogue's own
# table: docs/skin-catalogue.csv in a checkout, SKIN.csv in the skin/
# folder beside a packaged game, where this tool ships flat.
SIZE_TABLES = (ROOT / "docs" / "skin-catalogue.csv", HERE / "skin" / "SKIN.csv")
MAX_SCALE = 4

## THE KEYED PLACES: the pictures a game cutter takes a colour out of,
## reads a mask from or measures, and what does it. For a 2x, 3x or 4x
## picture the cutter decides on the 1x file of the place's own name when
## the skin holds one, and on the picture brought back to 1x (every 2x2
## block averaged) without it. Measured on the real 2x pictures
## (2026-10-17; the owner: *"that is important, tell the player"*): a
## plain upscale brought back moves the mana stripes' cut-out edges by
## 0.4-9.6%, loses the set symbols' ink box and 14 of the 15 territory
## grounds' black-edge trim (the image+mask sprites and the counter
## stones stay within 0.01%) — so tools/upscale_skin.py makes those
## pictures KEY-EXACT (each block averages to its 1997 pixel) and the
## game cuts them exactly. `--check` says once when a skin wears keyed
## places above 1x with no 1x file: it cannot tell exact from not. A
## name ending in `_` is a family.
KEYED = (
    ("mana_stripes", "MiniCard.stripe_texture keys the black around each stripe"),
    ("card_set_symbols", "SetBadges.symbol_from_sheet keys black, measures the ink"),
    ("combat_bar", "CombatBar.keyed_texture keys its near-white"),
    ("card_counters", "CounterMarks.tile reads the mask cell every stone wears"),
    ("summon_sick", "MiniCard.masked_sprite reads its mask half"),
    ("state_dying", "MiniCard.masked_sprite reads its mask half"),
    ("state_cant_target", "MiniCard.masked_sprite reads its mask half"),
    ("state_will_untap", "MiniCard.masked_sprite reads its mask half"),
    ("attack_sword", "MiniCard.masked_sprite reads its mask half"),
    ("attack_shield", "MiniCard.masked_sprite reads its mask half"),
    ("attack_bones", "MiniCard.masked_sprite reads its mask half (image over mask)"),
    ("target_cursor", "MiniCard.masked_sprite and the mouse cursor read its mask half"),
    ("duel_pattern_", "TerritoryGround._inner measures the 1px black edge"),
    ("duel_picture_", "TerritoryGround._inner measures the 1px black edge"),
    ("duel_mana_", "TerritoryGround._inner measures the 1px black edge"),
    ("grave_panel_", "ExilePlate.plate counts the plate's colours"),
)


def keyed_by(place: str) -> str | None:
    """Which cutter keys or measures [param place] (`mana_stripes.png`),
    or None for a picture that is only cut and drawn."""
    stem = place[:-len(".png")] if place.endswith(".png") else place
    for name, cutter in KEYED:
        if stem == name or (name.endswith("_") and stem.startswith(name)):
            return cutter
    return None


def sizes_1997(tables: tuple[Path, ...] = SIZE_TABLES) -> dict[str, tuple[int, int]]:
    """Place (`title_background.png`) -> its 1997 (width, height), for
    every picture place the first table found lists — not the coin-toss
    sheets, whose .json gives their frames in their own pixels, nor the
    portraits, which are fitted. Empty when no table is found."""
    for table in tables:
        if not table.is_file():
            continue
        out: dict[str, tuple[int, int]] = {}
        with table.open(encoding="utf-8", newline="") as handle:
            for row in csv.DictReader(handle):
                name = row.get("file", "")
                if not name.startswith(PREFIX) or row.get("kind") != "picture":
                    continue
                name = name[len(PREFIX):]
                if "/" in name or name.startswith("coin_toss_"):
                    continue
                found = re.match(r"(\d+) x (\d+) px", row.get("format", ""))
                if found:
                    out[name] = (int(found.group(1)), int(found.group(2)))
        return out
    return {}


def scale_of(width: int, height: int, size: tuple[int, int]) -> int | None:
    """1 to MAX_SCALE when (width, height) is that many times [param
    size] in both directions, else None (drawn at its own size)."""
    for scale in range(1, MAX_SCALE + 1):
        if (width, height) == (size[0] * scale, size[1] * scale):
            return scale
    return None


def check(target: Path) -> int:
    names = names_in(target)
    if names is None:
        print("!! %s is not a skin zip or folder" % target)
        return 1
    have = set(names)
    portraits = [n for n in names if n.startswith("portraits/") and n.endswith(".png")
                 and not is_scaled(n)]
    art = [n for n in names if n.startswith("cardart/")]
    if kind_of(names) == "cardart":
        odd = [n for n in art if not n.lower().endswith((".jpg", ".jpeg", ".png"))]
        count = len(art) - len(odd)
        print("%s: card art, %d picture%s" % (target, count, "" if count == 1 else "s"))
        if odd:
            print("  not pictures (ignored by the game):")
            for name in odd:
                print("    " + name)
        return 0
    places: dict[str, str] = {}
    ignored: list[str] = []
    if CATALOGUE in have:
        text = read_files(target, {CATALOGUE}).get(CATALOGUE, b"")
        places, ignored = parse_catalogue(text.decode("utf-8-sig", "replace"))
    # What each catalogued place is worn from; a line naming a file that
    # is not here counts as no line.
    worn = {place: file for place, file in places.items() if file in have}
    dangling = {place: file for place, file in places.items() if file not in have}
    expected = expected_files()
    known = set(expected)
    missing = [f for f in expected if worn_file(f, places, have) is None]
    print("%s: skin, %d files" % (target, len(names)))
    print("  %d of %d named files present, %d portraits, %d card pictures"
          % (len(expected) - len(missing), len(expected), len(portraits), len(art)))
    if any(is_scaled(n) for n in names) and all(
            is_scaled(n) or n in SKIN_NOTES or n == manalink.LABEL for n in names):
        print("  pictures only: the 2x pictures of a 1997 skin (<name>%s.png), no 1997"
              % SCALED_SUFFIX)
        print("  sounds or fonts with them. The hi-res skin of them — the same files")
        print("  as your 1997 skin, these pictures in place, nothing upscaled again:")
        print("    python3 %supscale_skin.py --skin original_skin.zip --reuse %s"
              % (tool_banner.here_prefix(__file__), target.name))
    if CATALOGUE in have:
        nowhere = [place for place in places if place not in known
                   and not place.startswith(("portraits/", "cardart/"))]
        moved = sum(1 for place, file in worn.items()
                    if file != place and place not in nowhere)
        print("  %s: %d place%s, %d worn from a file of another name"
              % (CATALOGUE, len(places), "" if len(places) == 1 else "s", moved))
        if ignored:
            print("  catalogue lines the game ignores (no '=', an empty side, "
                  "or a file outside skin/):")
            for line in ignored:
                print("    " + line)
        if dangling:
            print("  catalogue lines naming a file that is not here (the game "
                  "looks for the place under its own name instead):")
            for place, file in dangling.items():
                print("    %s = %s" % (place, file))
        if nowhere:
            print("  places the game never looks for (those lines do nothing):")
            for place in nowhere:
                print("    " + place)
    report_scales(target, have, places, expected)
    stood_in = [f for f in missing if f in SHIPPED_BY_THE_GAME]
    drawn = [f for f in missing if f not in SHIPPED_BY_THE_GAME]
    if stood_in:
        print("  not here, and the game's OWN picture stands in "
              "(nothing is lost):")
        for name in stood_in:
            print("    " + name)
    if drawn:
        print("  missing (the game draws its own for each):")
        for name in drawn:
            print("    " + name)
    worn_from = set(worn.values())
    unknown = [n for n in names if "/" not in n and n not in known
               and n not in worn_from and n not in SKIN_NOTES
               and not (is_scaled(n) and n.replace(SCALED_SUFFIX + ".png", ".png") in known)]
    if unknown:
        print("  not in the catalogue (ignored by the game):")
        for name in unknown:
            print("    " + name)
    return 0


def report_scales(target: Path, have: set[str], places: dict[str, str],
                  expected: list[str]) -> None:
    """How many of the pictures worn are 1x, 2x, 3x and 4x their place's
    1997 size, which are another size (SIZES AND SCALES), and how many
    keyed pictures are worn above 1x with no 1x file to key on (KEYED)."""
    sizes = sizes_1997()
    wearing = {}
    for place in expected:
        file = worn_file(place, places, have) if place in sizes else None
        if file is not None:
            wearing[place] = file
    if not wearing:
        return
    heads = read_files(target, set(wearing.values()) | set(wearing), 33)
    counts: dict[int, int] = {}
    odd: list[str] = []
    rough: list[str] = []
    for place, file in wearing.items():
        shape = png_shape(heads.get(file, b""))
        scale = scale_of(shape[0], shape[1], sizes[place]) if shape else None
        shown = place if file == place else "%s = %s" % (place, file)
        if scale is None:
            measured = "%d x %d" % shape[:2] if shape else "not a PNG, not measured"
            odd.append("    %-34s %s (1997: %d x %d)" % ((shown, measured) + sizes[place]))
            continue
        counts[scale] = counts.get(scale, 0) + 1
        # The 1x file the cutter keys on: the place's own name, at the 1997
        # size — the file worn in it when it is not the picture itself.
        own = png_shape(heads.get(place, b"")) if file != place else None
        if scale > 1 and keyed_by(place) and (own is None or own[:2] != sizes[place]):
            rough.append("    %-24s %s" % (place, keyed_by(place)))
    if counts:
        print("  pictures by size: %s — drawn at the 1997 size"
              % ", ".join("%d at %dx" % (counts[k], k) for k in sorted(counts)))
    if odd:
        print("  pictures at another size (drawn at their own size; a sheet "
              "must keep its grid):")
        for line in odd:
            print(line)
    if rough:
        print("  %d keyed place%s at 2x-4x with no 1x file: cut from the picture brought"
              % (len(rough), "" if len(rough) == 1 else "s"))
        print("  back to 1x (upscale_skin.py makes them exact; for your own art keep the")
        print("  key colours clean — SKIN.txt, SIZES AND SCALES)")


def main() -> int:
    parser = argparse.ArgumentParser(
        prog=TOOL, description=__doc__.split("\n\n")[0], epilog=EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--skin", type=Path, default=DEFAULT_SKIN,
                        help="the imported skin folder to measure")
    parser.add_argument("--cardart", type=Path, default=DEFAULT_CARDART,
                        help="the card art folder to count")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT,
                        help="where to write the catalogue")
    parser.add_argument("--check", type=Path, metavar="ZIP_OR_DIR",
                        help="report what a skin is missing; writes nothing; "
                             "exit 1 for an archive the game would refuse")
    parser.add_argument("--stdout", action="store_true",
                        help="print the catalogue instead of writing it")
    tool_banner.add_version_flag(parser, TOOL, __file__)
    args = parser.parse_args()
    # THE BANNER IS stderr-AND-A-TERMINAL ONLY (tools/tool_banner.py), and
    # here that rule earns its keep: `--stdout` IS the catalogue. The
    # mini-help rides the same guards, and `--stdout` is an argument, so
    # the run whose output is data never draws one anyway.
    tool_banner.show(WORDMARK, CAPTION, __file__, hint=HINT)
    if args.check:
        return check(args.check)
    text = render(args.skin, args.cardart)
    if args.stdout:
        sys.stdout.write(text)
        return 0
    args.out.write_text(text, encoding="utf-8")
    print("wrote %s (%d lines)" % (args.out, text.count("\n")))
    table = render_csv(args.skin)
    args.out.with_suffix(".csv").write_text(table, encoding="utf-8")
    print("wrote %s (%d files)" % (args.out.with_suffix(".csv"),
                                   table.count("\n") - 1))
    return 0


if __name__ == "__main__":
    sys.exit(main())

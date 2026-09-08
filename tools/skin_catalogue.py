#!/usr/bin/env python3
"""Write `docs/skin-catalogue.txt` — everything a skin has to contain.

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
script refuses to write. `tests/tools/test_skin_catalogue.py` holds the
committed text to the manifest.

    python3 tools/skin_catalogue.py                  # rewrite docs/skin-catalogue.txt
    python3 tools/skin_catalogue.py --skin DIR       # measure a different folder
    python3 tools/skin_catalogue.py --check my_skin.zip   # what a skin is missing
    python3 tools/skin_catalogue.py --check my_skin/      # a folder works too

Standard library only.
"""
from __future__ import annotations

import argparse
import json
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

DEFAULT_SKIN = ROOT / "assets" / "original"
DEFAULT_CARDART = ROOT / "assets" / "cardart"
DEFAULT_OUT = ROOT / "docs" / "skin-catalogue.txt"

ZIP_NAME = "original_skin.zip"
ART_ZIP_NAME = "cardart.zip"
PREFIX = "skin/"
ART_PREFIX = "skin/cardart/"
WIDTH = 78


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
     "The stone slab most windows sit on (Options, the Deck Builder's "
     "menus, prompts); tiled, with a 5 px margin."),
    ("Windows and panels", "panel_dark_stone",
     "The darker slab: the match and gauntlet screens between duels."),
    ("Windows and panels", "panel_knot",
     "The knotwork slab behind text-change prompts."),
    ("Windows and panels", "panel_end_duel",
     "The end-of-duel window's ground."),
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
     "count is printed beside it."),
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
     "past, drk, leg, 4ed). Black is treated as transparent."),

    ("The Deck Builder", "filter_icons",
     "The filter bar's medallions: 9 columns x 3 rows of 40 px cells, "
     "each icon 34x34 inside its cell, as (row, column). Row 0: ability "
     "(0,0), gold (0,1), Antiquities (0,2), Arabian Nights (0,3), "
     "artifact (0,4), artist (0,5), Astral (0,6), blue (0,7), cost "
     "(0,8). Row 1: creature (1,1), The Dark (1,2), enchantment (1,3), "
     "Fourth Edition (1,4), green (1,5), black (1,6), instant (1,7). "
     "Row 2: land (2,0), Legends (2,1), power (2,2), rarity (2,3), red "
     "(2,4), sorcery (2,6), toughness (2,7), white (2,8). The _hover and "
     "_pressed sheets are the same grid in those states."),
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
    ("Fonts", "font_body",
     "The reading face: card text, menus, the log (the original's "
     "MPlantin)."),

    ("Sounds", "sfx_",
     "Sound effects. The names say when they play: sfx_tap, sfx_untap, "
     "sfx_draw, sfx_shuffle, sfx_summon, sfx_attack, sfx_block, "
     "sfx_damage, sfx_buried (a card to the graveyard), sfx_counter, "
     "sfx_discard, sfx_end_turn, sfx_life_loss, sfx_button, sfx_toss "
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
file is optional: a file that is missing falls back to the drawn
equivalent, one file at a time.

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
    (user://skins/, under its own name) and worn from then on; a card
    art zip goes into the card folder (user://cardpacks/), where EVERY
    zip is a pack the game wears, in name order, the first to hold a
    picture winning — so packs for card sets of the future sit beside
    the first. The Card folder row names the folder and every pack in
    it; to go back to what shipped, delete the zip from the folder the
    row names. In a browser the file box is the browser's own, and
    Forget my zips (there is no folder to open) deletes them all.
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
  * A zip of your own (chosen, dropped or fetched) has precedence over
    the one beside the game. One chosen on the title screen shows at
    once; one chosen anywhere else shows from the next start.
  * In a browser: the same choosing and dropping, or a skin zip served
    beside the page as skin/original_skin.zip (and, on a page served
    on your own machine, skin/cardart.zip), which the game fetches
    once and keeps.
  * A loose folder still works too: <the game's folder>/skin/ with the
    same files unzipped, or the skin folder, user://original_skin/
    (what import_original.py fills). The game looks in the skin
    folder, then beside itself, then in the mounted zips. "Use the
    skin folder instead of the zip" in Options > Skin leaves the skin
    zip closed and lets the folder alone dress the game.
  * Every one of those places — the skin zip, the skin folder, the
    card folder, and the portraits and music folders — is shown by
    its path in Options > Skin and can be moved in settings.cfg
    (skin_zip, skin_folder, cardpacks_folder, portraits_folder,
    music_folder under [options]); the screen names the file.

NAMING. Names are exact, lower case, snake_case, with the extensions
given here. A picture is a PNG (RGB, or RGBA where a mask is wanted);
a font is TrueType; a sound is a WAV. The sizes below are the 1997
originals' — a skin may use other sizes where a note does not say
otherwise, but SHEETS (files the game cuts into cells) must keep their
grid, and frames and panels keep their proportions or the text drawn on
them lands wrong.

MASKS. Some 1997 sprites carry their transparency as a second picture:
the file is twice as wide as the sprite, the left half the image and
the right half its mask (or, for attack_bones, twice as tall, image over
mask). The mask's top-left pixel is background; whichever tone it has
means "transparent". A new skin may instead ship the sprite at half the
size with real alpha — the game reads both.

TO DRAW YOUR OWN. Make a folder named skin/ and put in it, under the
exact names below, whatever you have drawn — a few files or all of
them; the game draws its own for each one missing. Zip the folder so
that skin/ is the top of the zip (from the folder above it:
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
    if head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
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
    their extension in the key (`sfx_tap.wav`, `font_body.ttf`)."""
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


# -------------------------------------------------------------- checking --

def names_in(target: Path) -> list[str] | None:
    """The files a skin zip, tar (plain or gzipped) or folder holds,
    relative to skin/; None when the target is none of those, or the
    archive has an entry outside skin/."""
    if target.is_dir():
        return sorted(str(p.relative_to(target)).replace("\\", "/")
                      for p in target.rglob("*")
                      if p.is_file() and not p.name.endswith(".import"))
    if zipfile.is_zipfile(target):
        with zipfile.ZipFile(target) as zf:
            names = [n for n in zf.namelist() if not n.endswith("/")]
    elif target.is_file() and tarfile.is_tarfile(target):
        # The game repacks a tar into a zip at the door (game/tar_pack.gd)
        # with the same names — `./` at the front dropped — so a tar is
        # checked as the zip it will become.
        with tarfile.open(target) as tf:
            names = [m.name[2:] if m.name.startswith("./") else m.name
                     for m in tf.getmembers() if m.isfile() and not m.name.endswith("/")]
    else:
        return None
    out = []
    for name in names:
        if not name.startswith(PREFIX) or ".." in name:
            print("!! %s: entry outside skin/: %s" % (target.name, name))
            return None
        out.append(name[len(PREFIX):])
    return sorted(out)


def kind_of(names: list[str]) -> str:
    """"cardart" when every file is a card picture, else "skin" — the
    same rule the game applies (`SkinPack.inspect`)."""
    if names and all(n.startswith("cardart/") for n in names):
        return "cardart"
    return "skin"


def check(target: Path) -> int:
    names = names_in(target)
    if names is None:
        print("!! %s is not a skin zip or folder" % target)
        return 1
    have = set(names)
    portraits = [n for n in names if n.startswith("portraits/") and n.endswith(".png")]
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
    missing = [f for f in expected_files() if f not in have]
    print("%s: skin, %d files" % (target, len(names)))
    print("  %d of %d named files present, %d portraits, %d card pictures"
          % (len(expected_files()) - len(missing), len(expected_files()),
             len(portraits), len(art)))
    if missing:
        print("  missing (the game draws its own for each):")
        for name in missing:
            print("    " + name)
    unknown = [n for n in names if "/" not in n and n not in set(expected_files())]
    if unknown:
        print("  not in the catalogue (ignored by the game):")
        for name in unknown:
            print("    " + name)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--skin", type=Path, default=DEFAULT_SKIN,
                        help="the imported skin folder to measure")
    parser.add_argument("--cardart", type=Path, default=DEFAULT_CARDART,
                        help="the card art folder to count")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT,
                        help="where to write the catalogue")
    parser.add_argument("--check", type=Path, metavar="ZIP_OR_DIR",
                        help="report what a skin is missing; writes nothing")
    parser.add_argument("--stdout", action="store_true",
                        help="print the catalogue instead of writing it")
    args = parser.parse_args()
    if args.check:
        return check(args.check)
    text = render(args.skin, args.cardart)
    if args.stdout:
        sys.stdout.write(text)
        return 0
    args.out.write_text(text, encoding="utf-8")
    print("wrote %s (%d lines)" % (args.out, text.count("\n")))
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Import original MicroProse Magic (1997) art into a local skin.

Faithful-graphics layer 3 (docs/duel-screen-design.md §2): the original's
art is copyrighted and NEVER ships in this repo. Owners of the original
game run this importer against their own copy; the game then picks the
skin up at runtime (game/skin.gd) and the 1997 look appears everywhere the
clean fallback skin would otherwise show.

Accepted --source directories (searched recursively, case-insensitive):
  * an s30 checkout           (converted .pic.png / .spr.png files)
  * a Manalink 3.0 install    (fonts; .PIC decoding itself is future work —
                               see notes at the bottom of this docstring)
  * a genuine 1997 install    (the portrait step reads its raw .SPR and
                               .PIC files — seventy faces, of which five
                               exist in no conversion)
Multiple --source flags may be given; first match per file wins.

Default destination is <project>/assets/original (gitignored — dev builds
load it via res://). For EXPORTED builds, players import into Godot's user
dir instead:  --dest "$HOME/.local/share/godot/app_userdata/Shandalar/original_skin"

The MANIFEST below is the single place that maps skin keys (what the game
asks for) to original filenames (what the importer hunts for). Extending
the skin = adding a row here + using the key in game code.

One step is a CONVERSION rather than a copy: the two coin-toss movies are
Indeo Video 4.1 AVIs, which nothing in Python or Godot can read, so they
are transcoded into sprite sheets with whichever of ffmpeg /
gst-launch-1.0 is installed. The decoder is DETECTED, never assumed, and
its absence is reported and skipped rather than fatal. See the VIDEOS
block for the whole argument.

Note on raw .PIC/.SPR decoding: most of this importer still consumes the
PNG conversions the Manalink/s30 communities produced, but BOTH original
formats are now decoded here with nothing but the standard library, and
the portraits are the proof that it was worth doing.

  * `.SPR` (decode_spr) reads the raw `16faces.spr` and finds FIVE
    player faces the community conversion drops.
  * `.PIC` (decode_pic, ported 2026-09-03) reads the LZW+RLE picture
    format. It is what the FIFTY-FIVE enemy faces of `Faces/*.pic`
    needed, and it makes any full-screen `.pic` importable — see
    PIC_SCREENS for the first one.

Both formats are from `mp_pic_tools` (Provenance.md Tier 2,
https://github.com/benprew/mp_pic_tools); the code here is a rewrite for
speed and for the standard library, verified byte for byte against it.
"""

import argparse
import datetime
import json
import math
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib
from pathlib import Path

# ======================================================= WHERE A SOUND LIVES ==
#
# A CANDIDATE MAY NAME ITS DIRECTORY, and for audio it always does.
#
# `build_index` keys every file by its bare filename AND by every trailing
# piece of its path, so a candidate written `DuelSounds/Button.wav`
# matches only a `Button.wav` that is actually in a `DuelSounds` folder,
# and `Program/DuelSounds/Button.wav` names the other one exactly.
# That is not decoration. A 1997 install has THREE files called
# `Button.wav` — `Duelsounds/Button.wav` and `Sound/Button.wav` (75 270
# bytes, the game's own click) and `autoplay/Button.wav` (1 732 bytes,
# 1996-06-13, the CD's Windows AutoPlay blip) — and a flat filename index
# picks whichever one `Path.rglob` happens to reach first, which is
# directory hash order and therefore differs per machine. On the owner's
# install it picked autoplay's, so every button in the duel played a
# 39-millisecond installer blip. Found 2026-09-03; this is the fix.
#
# THE ORDER IS THE GAME'S OWN FOLDER FIRST. `DuelSounds/` and `Sound/`
# are the directories the 1997 executables read (`windows.c:1228` builds
# `DuelSounds\%s`; `deckdll.cpp:2047` builds `Sound\LocMus%d.wav`), so
# they are what the player's copy actually plays. `Program/DuelSounds/`
# and `Program/Sound/` exist only inside a Manalink 3 SOURCE tree, and
# hold a different MASTERING of the same recordings — see the audio
# section of `Provenance.md`. They are the fallback, never the first
# choice, so that pointing this at a checkout and pointing it at a real
# install give the same answer wherever both are present.


def duel_sound(name: str, bare: bool = True) -> list[str]:
    """`DuelSounds/` first, the Manalink source copy second."""
    out = ["DuelSounds/" + name, "Program/DuelSounds/" + name]
    return out + [name] if bare else out


def shell_sound(name: str, bare: bool = True) -> list[str]:
    """`Sound/` — the adventure shell's folder, where all the music is."""
    out = ["Sound/" + name, "Program/Sound/" + name]
    return out + [name] if bare else out


# skin key -> candidate source filenames (checked in order, case-insensitive)
MANIFEST: dict[str, list[str]] = {
    # menus
    "title_background":      ["Title.pic.png", "Title.png"],
    "menu_background":       ["Menubak.pic.png"],
    # ------------------------------------------- YOUR TERRITORY BACKGROUND --
    # `@DIALOG_DUELOPTIONS` (UIStrings.txt:598, latin-1 — grep needs -a)
    # ends with `Your &territory background` and NINE choices, which
    # `Duel.hlp`, topic **Dueling Options**, explains are TWO lists:
    # *"The list on the left simply allows you to pick the predominant
    # color of your background. The list on the right includes the
    # different types of background art available for each color. Select
    # one option from each."* Five colours + `Deck color` on the left,
    # `Line drawing` / `Pattern` / `Mana symbols` on the right — and the
    # original stores them as two registry values, `PlayerTerritoryColor`
    # and `PlayerTerritoryType` (both visible in `Program/Magic.exe`'s
    # string table under `Software\MicroProse\Magic: The Gathering\
    # DuelOptions`). So the art is a TRIO per colour, fifteen files, and
    # `Magic.exe` builds their names itself: its string table holds
    # `TERR_BLACK TERR_WHITE TERR_GREEN TERR_BLUE TERR_RED` followed
    # immediately by `pict patt mana` and the format `%s\%s.bmp`
    # (Manalink's patched extension; 1997 shipped `.pic`).
    #
    # ALL FIFTEEN ARE NOW IMPORTED. A CORRECTION, recorded so it is not
    # undone (2026-09-02): the note this file and `docs/ROADMAP.md` used
    # to carry — *"the only copies of the other two in ../shandalar-src
    # are Manalink `.bmp`s"* — was TRUE of `shandalar-src` and IRRELEVANT,
    # because the importer does not read `shandalar-src` for art. It reads
    # the s30 conversions, and `s30/assets/art/screens/duel/` holds all
    # fifteen `Terr_*.pic.png` files sitting in the same directory as the
    # five `patt` files that were already being imported from it. Nothing
    # had to be decoded; the rows below simply had never been written.
    #
    # WHAT EACH OF THE THREE ACTUALLY IS, opened with PIL at 3-8x
    # (2026-09-02) rather than inferred from the `Life_*` trio's comment
    # further down — and two of the three descriptions there do NOT
    # survive at territory size:
    #
    #   `Terr_<c>patt.pic`  A FRAMED PANEL, not a bare wallpaper. Its
    #       field is a seamless damask (white: cherubs and urns; blue: a
    #       violet knot over an orb; black: swans and lyres; red: rosettes;
    #       green: a quilt of leaf tiles), but every one of the five is
    #       ringed by a DECORATIVE BORDER — measured 8px on white, blue,
    #       red and green, and ~20px on black, which carries a corner
    #       ornament (a small square with a star) and a double rule. That
    #       border is why an earlier pass saw "a seam a third of the way
    #       across" when it tiled the file whole: the seam was the frame.
    #       Trim the border and the field tiles perfectly, which is what
    #       `game/duel/territory_ground.gd` does with a NinePatchRect —
    #       border at native size, field tiled inside it.
    #   `Terr_<c>pict.pic`  ONE PICTURE filling the frame, and the
    #       original's word for it is `Line drawing`: white is a frieze of
    #       carved standing angels, blue a winged orb, black a hooded
    #       figure with a lantern meeting a girl on a jetty, green a
    #       sleeping nymph with a bird, and red — the only one in full
    #       colour rather than a monochrome engraving — a dragon breathing
    #       fire over a magenta sea. Never tiled and never stretched out of
    #       shape; it is a picture.
    #   `Terr_<c>mana.pic`  THE MANA SYMBOLS, and it is NOT "a repeat of
    #       that colour's mana symbol" (which is what the `Life_*` comment
    #       below claims for its own trio, and what this one was assumed
    #       to inherit). It is a staggered wallpaper of medallions
    #       carrying ALL FIVE glyphs — sun, dragon, tree, drop, skull —
    #       embossed on speckled stone and tinted to the colour. This is
    #       the grey stone-and-mana-symbol table in the owner's own 1997
    #       screenshot. It carries no decorative border (only the 1px
    #       black edge every converted file has) and tiles as-is.
    #
    # SIZES, measured on the s30 conversions: 381 tall throughout, and
    # either 721 or 888 wide — 888 on Blackpatt, Redpatt, Whitepict,
    # Blackpict and Greenpict, 721 on the other ten. The Manalink `.bmp`
    # restyles are a uniform 735x367 and are not used. Fourteen of the
    # fifteen carry a 1px BLACK edge from the conversion; `Terr_Redpict`
    # is the exception (it is also the only one with a full-colour
    # palette, 92 colours against 7-28 for the rest).
    "duel_pattern_white":    ["Terr_Whitepatt.pic.png"],
    "duel_pattern_blue":     ["Terr_Bluepatt.pic.png"],
    "duel_pattern_black":    ["Terr_Blackpatt.pic.png"],
    "duel_pattern_red":      ["Terr_Redpatt.pic.png"],
    "duel_pattern_green":    ["Terr_Greenpatt.pic.png"],
    "duel_picture_white":    ["Terr_Whitepict.pic.png"],
    "duel_picture_blue":     ["Terr_Bluepict.pic.png"],
    "duel_picture_black":    ["Terr_Blackpict.pic.png"],
    "duel_picture_red":      ["Terr_Redpict.pic.png"],
    "duel_picture_green":    ["Terr_Greenpict.pic.png"],
    "duel_mana_white":       ["Terr_Whitemana.pic.png"],
    "duel_mana_blue":        ["Terr_Bluemana.pic.png"],
    "duel_mana_black":       ["Terr_Blackmana.pic.png"],
    "duel_mana_red":         ["Terr_Redmana.pic.png"],
    "duel_mana_green":       ["Terr_Greenmana.pic.png"],
    # card frames (the in-duel card backgrounds) + the card back
    #
    # THERE IS NO BLANK / PAPER CARD IN THE ORIGINAL'S SET, and the search
    # is finished — recorded here so nobody runs it again (2026-09-01, the
    # proxy pass, which needed one). The whole 1997 card-art set is these
    # 23 `Cardbk_*` frames, the card back, and ten overlays (`Summon`,
    # `Damage`, `Dying`, `WillUntap`, `Target`, `CantTarget`, `Poison`,
    # `Cardcounters`, `Cardsets`, `Manastripes`, `Manasymbols`). Every
    # frame IS a colour — there is no colourless one to stand in for a
    # card we know nothing about. The two near misses, both rejected:
    #   * `Program/CardArt/Blank.png` is a 1x1 TRANSPARENT PIXEL, i.e.
    #     Manalink's "no art here" placeholder — and a `.png` in a
    #     Manalink install is never a 1997 file anyway (Provenance.md).
    #   * `s30/assets/art/blank-card.png` really is a blank paper card
    #     (300x418, tan border, two empty boxes) — but it is s30's OWN
    #     drawing (Tier 3), and it is not among the converted `.pic.png`
    #     files in `s30/assets/art/card/`. That s30 had to draw one is
    #     evidence the original ships none, not permission to use theirs.
    # `game/deck_builder/proxy_face.gd` therefore draws its paper itself,
    # in the era's idiom: the geometry is these frames' own measured
    # regions and the palette is `Cardbk_White`'s pale stone with the
    # colour taken out of it.
    "card_back":             ["Cardback.pic.png"],
    "card_frame_white":      ["Cardbk_White.pic.png"],
    "card_frame_blue":       ["Cardbk_Blue.pic.png"],
    "card_frame_black":      ["Cardbk_Black.pic.png"],
    "card_frame_red":        ["Cardbk_Red.pic.png"],
    "card_frame_green":      ["Cardbk_Green.pic.png"],
    "card_frame_gold":       ["Cardbk_Gold.pic.png"],
    "card_frame_artifact":   ["Cardbk_Artifact.pic.png"],
    "card_frame_land_white": ["Cardbk_Whiteland.pic.png"],
    "card_frame_land_blue":  ["Cardbk_Blueland.pic.png"],
    "card_frame_land_black": ["Cardbk_Blackland.pic.png"],
    "card_frame_land_red":   ["Cardbk_Redland.pic.png"],
    "card_frame_land_green": ["Cardbk_Greenland.pic.png"],
    # ------------------------------------- THE LIFE REGISTER, BOTH FACES --
    # `Duel.hlp`, topic **Duelist's Face**: *"When the Life Register flips
    # around to show a face, one of two things is the case. Either you have
    # chosen the `Flip to Face` option from the mini-menu, or there is a
    # spell or effect being cast that could target a player."* So the panel
    # has TWO grounds, and the original ships exactly two 120x88 files per
    # colour to be them.
    #
    # WHICH IS WHICH — settled by opening all fifteen `Life_*` files with
    # PIL at 3-4x (2026-09-01), because the earlier reading had both faces
    # of the panel wearing the same picture and the flip would have shown
    # nothing:
    #   `Life_<c>patt.pic`  a seamless REPEAT — the white cherub-and-ruff
    #                       motif, the blue orb, the BLACK SKULL, the red
    #                       rings, the green hedge — i.e. wallpaper, which
    #                       is what a big yellow numeral wants behind it.
    #   `Life_<c>pict.pic`  ONE PICTURE filling the frame: a woman's face
    #                       in cloud (white), a winged merfolk in profile
    #                       (blue), a robed figure with a staff (black), a
    #                       face with flaming hair (red), a green sprout
    #                       (green) — the colour's own duelist, portrait
    #                       -cropped to the register. THE FACE.
    #   `Life_<c>mana.pic`  a repeat of that colour's MANA SYMBOL — black
    #                       is skulls, blue drops, green trees, red
    #                       dragons, white suns, one glyph per file
    #                       (re-checked at 3x, 2026-09-02). The mana
    #                       pool's ground, not the register's. Not
    #                       imported.
    # The `Terr_<c>` trio is the SAME THREE NAMES at territory size and it
    # settles the naming — `patt` is the pattern, `pict` the picture,
    # `mana` the symbols — but it is NOT the same art scaled up, and one
    # of the three differs in kind: `Terr_<c>mana` carries ALL FIVE glyphs
    # in a staggered quilt where `Life_<c>mana` carries only its own. The
    # territory block at the top of this MANIFEST has the full survey.
    #
    # A CORRECTION, recorded so it is not undone: `life_panel_*` used to
    # name `Life_<c>pict`, so the register wore the FACE permanently with
    # the life total written across it. It now names the wallpaper, and the
    # face has its own key below. Swapping these two rows puts the old look
    # back.
    #
    # `Life_Liched.pic` (the LICH REGISTER — `Duel.hlp` has a topic for it)
    # is surveyed and NOT imported: Lich is not in our card pool, so the
    # substitute register has nothing to substitute for. §6.5 tracks it.
    "life_panel_white":      ["Life_Whitepatt.pic.png"],
    "life_panel_blue":       ["Life_Bluepatt.pic.png"],
    "life_panel_black":      ["Life_Blackpatt.pic.png"],
    "life_panel_red":        ["Life_Redpatt.pic.png"],
    "life_panel_green":      ["Life_Greenpatt.pic.png"],
    # THE DUELIST'S FACE — the register's other side (manual p.119: *"You
    # can right-click on either life register and select Flip to Face if
    # you'd rather see your opponent's face."*).
    #
    # `Program/DuelArt/Face_*.pic` IS NOT THIS ART, and the search for it
    # is finished — do not run it again (surveyed 2026-09-01, twice,
    # independently):
    #
    #  * The five files in the install are **byte-identical to each other**
    #    (one md5, 88f7c83f7dfae9608ea9aa2d8bc43920): a 468x312 RGBA PNG
    #    wearing a `.pic` extension, 83 unique colours and every one of
    #    them achromatic — a flat grey gradient with noise. Manalink's
    #    placeholder, the same restyle-not-original trap the dialog grounds
    #    above warn about. s30 never converted them; there is no
    #    `Face_*.pic.png` anywhere.
    #  * The REAL 1997 `Face_*.pic` does survive, but not as a file: six
    #    240x170 BMPs (White, Blue, Black, Red, Green **and Multi** — the
    #    only Multi duelist in the game, and `Magic.exe`'s own string table
    #    names all six) inside `Mods/Art/Duel_DB Microprose 1997.7z`, which
    #    exists only in `shandalar-src`'s git OBJECT STORE (that checkout is
    #    a `blob:none` partial clone with a sparse working tree). Getting
    #    them out needs `git cat-file` plus a 7z reader, which no tool on a
    #    player's machine is required to have, and four of the six were
    #    colour-reduced to 4bpp by the mod author — `Face_Green` is down to
    #    THREE colours, a flat two-tone dither. Not imported: the route is
    #    fragile and the art that arrives is worse than what is below.
    #  * They are a DIFFERENT asset anyway. 240x170 is not the 120x88 life
    #    register, `Life_*pict` has no Multi, and two 240x170 portraits
    #    side by side is 480px against `Winbk_Versus.pic`'s 500x400 — so
    #    that set is the pre-duel VERSUS portrait pair, not the register's
    #    flip side. If the versus screen ever wants faces, that is the
    #    archive to go back to, and this is the note that says so.
    "duelist_face_white":    ["Life_Whitepict.pic.png"],
    "duelist_face_blue":     ["Life_Bluepict.pic.png"],
    "duelist_face_black":    ["Life_Blackpict.pic.png"],
    "duelist_face_red":      ["Life_Redpict.pic.png"],
    "duelist_face_green":    ["Life_Greenpict.pic.png"],
    # Window chrome: the original's beveled sandstone dialog panel (a
    # 9-patch behind every dialog, the duel-opening coin toss included),
    # and the pre-duel Start Duel screen's own backdrop.
    "panel_stone":           ["Winbk_Options.pic.png"],
    "versus_background":     ["Winbk_Startduel.pic.png"],
    # The PRE-DUEL SPLASH (500x400): brown marble with two sunken wells at
    # (50, 59) and (281, 59), each 162x192 — measured 2026-09-03, and the
    # numbers `DuelIntro` lays itself out with. s30's own art notes call
    # this file "Player vs opponent splash".
    "versus_splash":         ["Winbk_Versus.pic.png"],
    # ------------------------------------------------------- 1997 DIALOGS --
    # Every one of these is a DIALOG GROUND with the era's bevel baked
    # into its own edge pixels: a 2-4px highlight along top+left and the
    # same width of shadow along bottom+right, so a 9-patch of that width
    # reproduces the window frame at any size. Measured per file (the
    # numbers live in game/duel/original_dialog.gd PANELS).
    #
    # ALWAYS take the s30 `.pic.png` conversion of the 1997 file. The
    # same-named `.bmp` in a Manalink install is Manalink 3's own flat
    # restyle — WinBk_TellUser.bmp is a plain grey gradient at 900x53
    # where the 1997 .pic is 600x35 of mottled red-brown stone, and
    # WinBk_EndDuel.bmp / WinBk_StartDuelButton*.bmp are likewise flat
    # grey and flat olive. Filename candidates below never name a .bmp.
    #
    # Winbk_Questmana: the mana-question window's DARK GREY STONE, the
    # ground the original puts under a question that must not compete
    # with the card art beside it (our X, library-search and game-over
    # dialogs).
    "panel_dark_stone":      ["Winbk_Questmana.pic.png"],
    # Winbk_Changetext: the blue celtic-knot ground of the "change word /
    # to" dialog (@DIALOG_CHANGETEXT) — the original's ground for a
    # dialog that asks the player to pick from a LIST.
    "panel_knot":            ["Winbk_Changetext.pic.png"],
    # Winbk_Endduel: the end-of-duel window's dark blue-and-gold rings.
    # Its bevel is INSET (dark top/left, light bottom/right) — the only
    # sunken window in the set, which is why the duel's last word looks
    # carved rather than raised.
    "panel_end_duel":        ["Winbk_Endduel.pic.png"],
    # THE 1997 BUTTON, three states (131x36 each). The only generic
    # button art in DuelArt, and the source of the era's button
    # language: a DOUBLE rule — 2px highlight (207,209,209) on top+left
    # and 2px slate shadow (82,111,140) on bottom+right, 3px of speckled
    # face, then the same pair again at 5-6px in, then the face. Normal
    # is raised twice; Depressed inverts BOTH rules; Disabled inverts
    # only the inner one.
    "button_normal":         ["Winbk_Startduelbuttonnormal.pic.png"],
    "button_pressed":        ["Winbk_Startduelbuttondepressed.pic.png"],
    "button_disabled":       ["Winbk_Startduelbuttondisabled.pic.png"],
    # duel chrome: the original's vertical phase bar and graveyard piles
    "phase_bar":             ["Winbk_Phase.pic.png"],
    # ---------------------------------------------------------- THE COMBAT --
    # Winbk_Phasecombat 164x760 — THE COMBAT BAR (manual p.117, Duel.hlp
    # topic "Combat Bar"): the miniature Phase Bar that REPLACES the Phase
    # Bar for the duration of an attack. Opened with PIL (2026-08-31): it
    # is Winbk_Phase's own 82px [normal | active] pair laid down TWICE —
    # x 0..81 in the opponent's gold, x 82..163 in the player's blue — each
    # column 760 tall so it drops straight into the Phase Bar's slot. Icon
    # cells are 35x40 at x 3 / 44 (+82 for the player) and y 2+41*row.
    # SEVEN icons, at rows 0-5 and row 7 (row 6 is bare stone, the gap
    # before the exit): sword, sword+rays, shield, shield+rays, split
    # shield, sword-through-shield, and the Phase Bar's own mirrored
    # crescent. They line up one-for-one with the last seven
    # @CUECARD_PHASEBAR strings and with Duel.hlp's own list.
    "combat_bar":            ["Winbk_Phasecombat.pic.png"],
    # Winbk_Attack 888x316 — the COMBAT WINDOW's ground, a field of
    # SKULLS. Like Winbk_Telluser it carries NO bevel of its own (every
    # edge row is plain texture), so the window is RULED by
    # OriginalDialog's own frame routine.
    "attack_panel":          ["Winbk_Attack.pic.png"],
    # Winbk_Attackmin 39x70 — the MINIMISED Combat window: a dagger on
    # dark green inside a blue rule. 39 wide against a 41-wide Phase Bar
    # column and 70 tall against its ~100px centre band: this is the
    # "window icon in the center area of the Phase Bar" (manual p.126)
    # that restores the window, drawn at 1:1.
    "attack_min":            ["Winbk_Attackmin.pic.png"],
    # The window's furniture, all IMAGE+MASK pairs (MiniCard.masked_sprite):
    #   Winbk_Attacksword  56x132 -> a 28x132 steel sword, hilt up: the
    #                               ATTACKERS' lane marker
    #   Winbk_Attackshield 44x128 -> a 22x128 green kite shield: the
    #                               BLOCKERS' lane marker
    #   Winbk_Attackbones 777x70  -> a 777x35 strip of bones, split TOP
    #                               image / BOTTOM mask: the window's floor
    "attack_sword":          ["Winbk_Attacksword.pic.png"],
    "attack_shield":         ["Winbk_Attackshield.pic.png"],
    "attack_bones":          ["Winbk_Attackbones.pic.png"],
    # The hand window's title bar, per seat color (s30: drawHandPanel).
    "hand_panel_white":      ["Hand_White.pic.png"],
    "hand_panel_blue":       ["Hand_Blue.pic.png"],
    "hand_panel_black":      ["Hand_Black.pic.png"],
    "hand_panel_red":        ["Hand_Red.pic.png"],
    "hand_panel_green":      ["Hand_Green.pic.png"],
    # The sidebar mana-pool panel (s30: drawManaPool).
    "mana_pool_panel":       ["Winbk_Manapool.pic.png"],
    # Statbutt sprite sheet: 16 x 48px cells. Opened cell by cell
    # (2026-08-31): 0-4 the five mana symbols, then THREE STATES EACH of
    # "WIZ STATS" (5-7), "JOURNAL" (8-10) and "DONE" (11-13), a dark bar
    # (14) and a small square (15). Its neighbours name it: this is the
    # ADVENTURE's button strip, not the duel's, and its DONE is a flat
    # 48x22 grey tile with DARK letters — where the duel's Situation Bar
    # button is bevelled with a pale label. s30 uses cells 11-13 for the
    # duel Done; we use the era's own three-state button art instead
    # (button_normal/pressed/disabled) and keep this sheet for the
    # adventure layer. Its dark-on-light lettering IS our evidence for
    # how the original letters a button face.
    "stat_buttons":          ["Statbutt.spr.png"],
    # The stack window, the message bar, and the enlarged-card window
    # (s30: spellChainBg / messageBg / the examine view).
    "spell_chain_panel":     ["Winbk_Spellchain.pic.png"],
    "message_panel":         ["Winbk_Telluser.pic.png"],
    "big_card_panel":        ["Winbk_Bigcard.pic.png"],
    # SURVEYED AND DELIBERATELY NOT IMPORTED (2026-08-31) — opened with
    # PIL, one by one, so the next pass need not guess again:
    #   Winbk_Attackrats.pic      142x210  SIX 71x35 frames (image+mask) of
    #                                      a rat scurrying: the Combat
    #                                      window's live decoration. Pure
    #                                      atmosphere; not built
    #   Winbk_Spellmin.pic         39x70   the MINIMISED spell chain (a
    #                                      wand on green) — the Spell Chain's
    #                                      own window icon. Ours has no
    #                                      minimise yet (duel-todo.md §6.5)
    #   Winbk_Manaburn.pic        260x170  an illustration, not chrome: the
    #                                      mana-burn flash. We have no mana
    #                                      burn (docs/glossary-1997.md §2)
    #   Winbk_Questmanaselection   36x57   one grey beveled CELL of the
    #     .pic                             mana-question grid
    #   Winbk_Fireball.pic        545x410  the X-spell dialog's red spiral.
    #                                      Beautiful, but it is a picture
    #                                      the size of a whole window and
    #                                      our X dialog is a two-line
    #                                      question — panel_dark_stone
    #                                      carries it without shouting
    #   Winbk_Phasecombat.pic     164x760  the COMBAT BAR (the phase bar's
    #                                      combat replacement) — a real
    #                                      to-do, docs/duel-todo.md §6.5,
    #                                      but not popup chrome
    # Diagonal mana stripes marking what colours a card can produce,
    # drawn on its hand row (54x126: 6 cells of 54x21, W U B R G C).
    "mana_stripes":          ["Manastripes.pic.png", "ManaStripes.pic.png"],
    # ------------------------------------------- THE SMALL-CARD STATE ART --
    # `@CUECARD_SMALLCARD` (UIStrings.txt:732, latin-1 — grep needs -a)
    # names TEN states a card on the table can be in, and FIVE of them ship
    # as art. All five are IMAGE+MASK pairs in MiniCard.masked_sprite()'s
    # format; every one was opened with PIL before it was wired
    # (thirty-eighth pass) and the sizes/looks are recorded per key.
    #
    # A FOURTH PROVENANCE RULE, and this one bites here specifically:
    # `Program/CardArt/` in a Manalink install is the SAME trap as
    # `Program/DBArt/` — every `*.pic` there is a PNG wearing a `.pic`
    # extension, and it is Manalink's own RESCALE: Summon/Dying are
    # 254x127 where the 1997 file is 194x97, CantTarget/Target 206x103
    # against 130x65 / 122x61, WillUntap 152x76 against 110x59. They are
    # the same drawings, upscaled, and their masks are two-tone
    # silhouettes rather than real alpha. So the s30 `.pic.png`
    # conversion goes FIRST in every candidate list below and the
    # Manalink file is the fallback (masked_sprite handles both, see its
    # doc comment). One more wrinkle: `Dying.pic` also exists at a
    # Manalink install's ROOT as a genuine raw 1997 X0 container
    # (magic `X0`, u16 len, u16 w=194, u16 h=97) which nothing here can
    # decode — if that one is what the index finds, the overlay simply
    # does not draw. It never crashes.
    #
    # The SUMMONING-SICKNESS spiral drawn over a creature's art. 194x97:
    # left half the image, right half its mask (black = opaque). A grey
    # spiral. Cue card: "Summoning sickness".
    "summon_sick":           ["Summon.pic.png", "Summon.pic"],
    # Dying 194x97 -> a 97x97 field of SILVER CRACKS spreading across the
    # card, the original's "this dies at the next check" mark. Cue card:
    # "Dying".
    "state_dying":           ["Dying.pic.png", "Dying.pic"],
    # CantTarget 130x65 -> a 65x65 ORANGE CIRCLE-SLASH (a no-entry sign).
    # Cue card: "Can't target this".
    "state_cant_target":     ["Canttarget.pic.png", "CantTarget.pic"],
    # WillUntap 110x59 -> a 55x59 BLUE CURVED ARROW (the untap symbol's
    # ancestor). Note the halves are NOT square. Cue card: "This card
    # will untap".
    "state_will_untap":      ["Willuntap.pic.png", "WillUntap.pic"],
    # SURVEYED AND DELIBERATELY NOT IMPORTED — Poison.pic. Reason (1) below
    # was CORRECTED on 2026-09-01 and the pairing with "Damage to player"
    # with it: that cue is @CUECARD_SMALLCARD's, and @CUECARD_LIFE
    # (UIStrings.txt:678) declares eight entries without it, so it is the
    # DAMAGE MARKER's state (docs/duel-todo.md §2.10, §6.20b) and this file
    # is not the marker's art on any evidence we hold. Reason (2) is
    # unaffected and is on its own sufficient:
    # (1) [WRONG, kept so it is not re-derived] "it is a PLAYER state, not
    # a card state — it belongs to the life register"; (2) s30's conversion
    # is 42x26 with an ALL-BLACK right
    # half (one colour, 546/546 px), i.e. a dead mask that decodes to a
    # fully transparent sprite. Only Manalink's 60x30 rescale has a
    # working mask. Whoever builds the poison counter takes that one.
    # The ORIGINAL's own set symbols (DBArt, 35x36) — drawn on a card's
    # type strip. Unlimited (2ed) and the promos have no symbol, exactly
    # as the printed cards don't.
    "set_icon_atq":          ["Antiquit.pic.png", "Antiquit.pic"],
    "set_icon_arn":          ["ArabNite.pic.png", "ArabNite.pic"],
    "set_icon_past":         ["Astral.pic.png", "Astral.pic"],
    "set_icon_drk":          ["Dark.pic.png", "Dark.pic"],
    "set_icon_4ed":          ["Fourth.pic.png", "Fourth.pic"],
    # THE 1997 EXPANSION-SYMBOL STRIP — the sheet the game stamps on CARDS,
    # as opposed to the `set_icon_*` medallions above, which are the Deck
    # Builder's filter buttons. 330x15 = five 66-wide slots, each an image
    # half and a MASK half of 33x15 (measured 2026-09-02, and the mask is
    # the exact complement of the image's ink). Slot order is The Dark,
    # Legends, Arabian Nights, Antiquities, Astral — matched against the
    # named DBArt glyphs at 8x, not read off the 15px strip.
    #
    # Only five sets have one, and that is the printed truth, not a gap:
    # Unlimited, Fourth Edition and the promos carried no expansion symbol,
    # which is why `SetBadges` letters those three instead.
    "card_set_symbols":      ["Cardsets.pic.png"],
    "set_icon_leg":          ["Legends.pic.png", "Legends.pic"],
    # --------------------------------------------------- THE DECK BUILDER --
    # The 1997 Deck Builder was its own module (Program/Deckdll.dll), so
    # there is no C source for it — but its ART survives, and the manual's
    # ch.10 names every region it dresses: the Deck Header, the Showcase,
    # the Deck area, the four Filter groups and the Inventory.
    #
    # A THIRD PROVENANCE RULE, found the hard way (2026-08-31). The .bmp
    # rule above is not enough here: EVERY file in a Manalink install's
    # `Program/DBArt/` is a PNG WEARING A .pic EXTENSION — Manalink 3's own
    # flat restyle, hiding behind the 1997 name. Opened all 37 with PIL:
    # StatBak1 (800x600), FilterBkg (287x486) and InfoBkg (488x405) are
    # FLAT GREY NOISE; DekBar1, DekTit1 and BtnBkg are FLAT GREY GRADIENTS;
    # Bldr01C-05C render the mana glyphs flat black on flat grey. Check the
    # MAGIC BYTES, not the extension. The s30 .pic.png conversions below
    # are the 1997 art, and they carry the era's palette — Dekbar1's
    # speckle includes (82,111,140), the same slate as the 1997 button
    # shadow above.
    #
    # sprite_sheet.png 360x120 — THE FILTER STRIP: a 9x3 grid of 40x40
    # bevelled stone tiles, each holding a recessed medallion, in three
    # sheets (normal/hover/pressed). The cell->filter map was DECODED, not
    # guessed: Manalink's DBArt icons are the same glyphs RECOLOURED, so
    # each 35x36 DBArt file was rendered beside each cell and matched by
    # shape. Eighteen match exactly, which fixes the grid as
    #   row 0: Ability(eye) Gold(5-dot palette) Antiquities(anvil)
    #          ArabianNights(scimitar) Artifact(chalice) Other(fan of cards)
    #          Astral(comet) BLUE(drop) CastCost(X)
    #   row 1: [lit-X exemplar] Creature(bat) TheDark(crescent) [spare
    #          crescent] FourthEdition(IV) GREEN(tree) BLACK(skull)
    #          Instant(bolt) Interrupt(open hand)
    #   row 2: Land(mountains) Legends(column) Power(sword) Rarity(gem)
    #          RED(dragon) ?(exclamation mark) Enchantment(rising sun)
    #          Toughness(cross-shield) WHITE(sun)
    # The five COLOUR cells are the only ones drawn as a coloured glyph on
    # a BLACK disc, which is what confirms them. This map CORRECTS s30's
    # (edit_deck_filter_ui.go:73-79), which reads (2,7) as Artifact and
    # (1,3) as Sorcery; DBArt puts the chalice on Artifact and the shield
    # on Toughness, and (1,3) is a second crescent moon — a SET medallion.
    #
    # THE 2026-08-31 AUDIT PASS RE-READ THE TWO UNCERTAIN CELLS by
    # rendering every cell's glyph as a black-on-white silhouette beside
    # every DBArt glyph, and moved Sorcery to (0,5) and Enchantment to
    # (2,6). THE SCREENSHOT PASS (same day, later) OVERTURNS BOTH, and
    # this time from a render of the real program rather than from
    # shape-matching. The owner's 1997 screenshot shows the whole filter
    # strip in the original's own order — six colour medallions, then the
    # SEVEN type buttons the manual lists (Land, Artifacts, Creatures,
    # Enchantments, Instants, Interrupts, Sorceries), then the five Other
    # Filters (Casting Cost, Power, Toughness, Ability, Rarity) — and each
    # of the eighteen was cut out and correlated against all 27 cells:
    #   position  4 (Enchantments) -> (1,3), r=0.57, the ringless crescent
    #   position  7 (Sorceries)    -> (2,6), r=0.60
    # Rendered side by side the match is exact, and the discriminator is
    # THE GOLD RING: every SET medallion wears one and no type button
    # does. (1,2) is a crescent WITH the ring — The Dark. (1,3) is the same
    # crescent WITHOUT it — Enchantments. (2,5)'s exclamation mark has the
    # ring, so the audit was right that it is a set (@RESTRICTED) and wrong
    # that Enchantment was ever near it. (0,5), a dark disc closing on a
    # bright bead, is left unassigned again; (1,0) is a lit exemplar of
    # CastCost's X.
    #
    # THE SAME SCREENSHOT FIXES THE FIVE COLOUR CELLS as buttons in their
    # own right — W (2,8), U (0,7), B (1,6), R (2,4), G (1,5), each a
    # coloured glyph on a black disc — and shows that the Colour Filters
    # are these medallions, NOT the big carved Bldr plaques (see
    # `deck_slot_plaques` above).
    #
    # AND IT FIXES WHICH SHEET IS "ON". Every filter in the screenshot is
    # depressed (a fresh screen shows the whole collection), and the mean
    # luminance of its medallions is 122-128 — the NORMAL sheet's 120-127,
    # not the `_pressed` sheet's 62-66. So the original draws an ON filter
    # from `sprite_sheet` and sinks it into the dark `_pressed` sheet when
    # it goes OFF, which is a clean 2:1 luminance split that needs no tint
    # at all. The warm/cool `ON_TINT`/`OFF_TINT` pair the building pass
    # invented to separate the states is therefore retired.
    # game/deck_builder/filter_bar.gd's TYPE_CELL is the live map.
    "filter_icons":          ["sprite_sheet.png"],
    "filter_icons_hover":    ["sprite_sheet_hover.png"],
    "filter_icons_pressed":  ["sprite_sheet_pressed.png"],
    # Bldr_sheet 585x200 (s30's assembly of DBArt's Bldr01C..05C, from the
    # 1997 originals): 5 cells of 117 x 2 rows of 100. Top row warm
    # brown-gold sandstone, bottom row cool blue slate, each with a mana
    # glyph carved into it. Column order B W R G U (skull, sun,
    # fire-dragon, tree, drop).
    #
    # WHAT THEY ACTUALLY ARE, settled 2026-08-31 by the owner's 1997
    # screenshot of the in-Shandalar Deck screen (scratchpad deckref.png,
    # 1024x768). The earlier passes called these "the colour filter
    # plaques" and put them on the Colour Filter buttons. They are not
    # buttons at all: they are THE DECK AREA'S EMPTY-SLOT WATERMARKS. The
    # screenshot's deck grid is these five cells laid edge to edge and
    # cycling `index = (row * columns + col) % 5`, which is what produces
    # the diagonal drift of tree / drop / skull / sun / dragon across the
    # grid, and a crop of the screenshot next to `Bldr_sheet`'s BOTTOM row
    # is a pixel-for-pixel match — same carving, same slate, same ring.
    #
    # And the two rows pair with the two DECK TILES: the blue-slate row
    # sits on Dektile4 (the navy weave the screenshot's whole screen is
    # tiled with), the warm brown-gold row on Dektile1 (the olive-brown
    # weave s30 uses). One quilt per ground.
    #
    # The Colour Filter buttons in the same screenshot are plain 40x40
    # `sprite_sheet` medallions like every other filter — see the cell map
    # below.
    "deck_slot_plaques":     ["Bldr_sheet.png"],
    # Dektit1 291x73 — the DECK HEADER's slab, veined blue-grey marble in a
    # 2px pale bevel. The manual: "At the top left corner of the screen is
    # the Deck Header box… the title of your deck is displayed."
    "deck_title_slab":       ["Dektit1.pic.png"],
    # Dekbar1 1006x198 — the INVENTORY's ground ("Along the bottom of the
    # screen, in the Inventory area, is every card you can put into a
    # deck"). A 14-colour 50/50 dither of dark teal (42,83,92) and slate
    # (82,106,111) with NO bevel and NO frame anywhere on its edges: a
    # field to lay a row of cards on, never a widget. s30 uses the same
    # file behind its 1024x180 collection carousel.
    "deck_bar_ground":       ["Dekbar1.pic.png"],
    # The seamless 32x32 grounds the screen tiles: Dektile1 olive-brown
    # (s30 tiles it over the whole edit-deck screen) and Dektile4 navy
    # slate (its deck area). Both verified tileable by PIL.
    "deck_tile_olive":       ["Dektile1.pic.png"],
    "deck_tile_slate":       ["Dektile4.pic.png"],
    # SURVEYED, NOT IMPORTED (2026-08-31):
    #   Program/seedeck.pic       640x480  THE genuine 1997 full-screen deck
    #                                      screen, and the one thing here we
    #                                      cannot have: raw X0 container
    #                                      (magic + u16 len + u16 w + u16 h,
    #                                      payload at 8), never converted by
    #                                      s30, and the payload codec is
    #                                      undecoded — raw deflate, byte
    #                                      LZSS and 9-bit LZW are all ruled
    #                                      out. docs/ROADMAP.md carries it
    #   Program/statbak.pic       640x480  same story, M1 container with a
    #                                      768-byte palette at offset 6
    #   ui/Infobar.pic.png        640x480  the era's SCROLLBAR atlas (track,
    #                                      thumb, 3x4 grid of up/down arrows)
    #                                      — real 1997 art, but slicing it
    #                                      wrongly is worse than Godot's own
    #                                      bar styled by OriginalDialog
    #   ui/Tradscrn.pic.png       640x480  the 1997 two-list + card-preview
    #                                      screen. The closest surviving
    #                                      ground to a deck-builder backdrop,
    #                                      but it is the TRADE screen's, and
    #                                      its panes are sized for 640x480
    #   edit_deck/Dekbtn1-3       78x23    the DECK SLOT buttons, `@DECKNUMBERS`
    #                                      "Deck1/Deck2/Deck3". Re-opened with
    #                                      PIL after an earlier pass filed them
    #                                      as "the adventure's, not ours": a
    #                                      light blue-grey stone tile carrying a
    #                                      fan-of-cards glyph AND the numeral,
    #                                      framed by the era's double rule (2px
    #                                      pale 210,234,242 top+left, dark
    #                                      44,48,110 bottom+right, sunken inner
    #                                      panel from 4px in — the same geometry
    #                                      OriginalDialog 9-patches out of
    #                                      Winbk_Startduelbutton*). STILL not
    #                                      imported, and now for a reason from
    #                                      the screenshot rather than a guess:
    #                                      the 1997 deck screen's own command
    #                                      bar does NOT wear this art. Its three
    #                                      slots are plain LETTERED buttons —
    #                                      `Deck1 | Deck2 | * Deck3 *` — so the
    #                                      glyph belongs to some other deck
    #                                      chooser, and using it in the command
    #                                      bar would be less faithful, not more
    #   edit_deck/Statbak1.pic.png 48x48   flat dark-grey noise; no character
    #   edit_deck/Statbak.pic.png  32x32   the same noise at tile size, and
    #                                      likewise characterless — the deck
    #                                      screen's grounds are Dektile1/4
    #   edit_deck/Bkgrnd2.pic.png  16x16   a fine olive-and-tan weave, seamless
    #                                      but far lighter than anything in the
    #                                      screenshot; it is not the deck
    #                                      screen's ground and nothing else on
    #                                      this screen wants a 16px tile
    #   edit_deck/Winbk_Spellchain 139x200 s30 files a copy of the DUEL's spell
    #     .pic.png                         chain panel in its edit_deck folder;
    #                                      already imported as
    #                                      `spell_chain_panel` from DuelArt
    "grave_panel_white":     ["Grave_White.pic.png"],
    "grave_panel_blue":      ["Grave_Blue.pic.png"],
    "grave_panel_black":     ["Grave_Black.pic.png"],
    "grave_panel_red":       ["Grave_Red.pic.png"],
    "grave_panel_green":     ["Grave_Green.pic.png"],
    # NO EXILE PLATE EXISTS — surveyed 2026-08-31, do not hunt again.
    #   The 1997 table drew no "removed from the game" pile: the zone was
    #   reached from the graveyard's own right-click menu, @MENU_GRAVEYARD
    #   (UIStrings.txt:901, latin-1 — grep needs -a), whose four lines are
    #   "View the graveyard / View exiled cards / View both antes /
    #   Help...", and Duel.hlp (the shipped help file, 11 Nov 1997) says as
    #   much in words: "You can also right-click on either graveyard ... to
    #   view cards removed from the game." Filename and string searches for
    #   exile/remov/rfg/banish/void across Program/ (DuelArt, DBArt,
    #   CardArt, Exp1Art), the Manalink src/ tree and s30's whole art tree
    #   return Grave_* and the ante SCREEN art (Winbk_Ante 336x500,
    #   Winbk_Antelabel 149x30, duel_ante/Prd*) and nothing else; s30's Go
    #   source has no exile pile either. Our sidebar exile pile is a
    #   deliberate divergence and its empty plate is DERIVED at runtime
    #   from these five files by game/duel/exile_plate.gd.
    # sheets (mana_symbols layout, decoded from the original sheet itself:
    # 19 cells of 18x18 — X, 0..10, W, R, U, B, G, tap — consumed by
    # game/duel/mana_icons.gd)
    "mana_symbols":          ["Manasymbols.pic.png"],
    # Abilities.pic 22x396 — ONE COLUMN of 18 cells of 22x22, consumed by
    # MiniCard.badge_from_slot. Every cell is a DISC on an opaque black
    # square, so the cell is masked to its inscribed circle before use
    # (measured: across all 18 cells the furthest non-black pixel sits at
    # r=11.068 and the nearest black one at r=11.34, so a cut at
    # r = cell*0.51 = 11.22 separates icon from backdrop exactly).
    # Cell map, read off the sheet at 4x: 0-4 the mana glyphs (tree /
    # dragon / drop / skull / sun), 5-9 the colour PROTECTION shields
    # (green red blue black white), 10 a BROWN shield = protection from
    # ARTIFACTS, 11 a wing = flying, 12 a red foot = trample, 13 a blue
    # cross = banding, 14 sword-and-shield = first strike, 15 a GREEN
    # TRIDENT = regeneration, 16 a pale star = reach.
    # **CELL 17 IS SOLID BLACK** — 484/484 px of (0,0,0,255), one unique
    # colour. s30 maps Menace there (duel.go:1047-1121); the 1997 game had
    # no menace keyword and no icon for it, so that mapping would blit a
    # black square. Do not "complete" the map.
    "ability_icons":         ["Abilities.pic.png"],
    # Prefer the RAW .pic: it is a clean image+mask pair (84x26, white
    # background / black silhouette), while the converted copy is a
    # different size and decodes as neither a sprite nor a pair.
    # Cue card: "Damage: %d".
    "damage_marker":         ["Damage.pic", "Damage.pic.png"],
    # Target.pic 122x61 -> a 61x61 RED CROSSHAIR. ONE FILE, TWO USES: the
    # duel screen's targeting CURSOR (DuelScreen._set_target_cursor takes
    # the image half raw) and the small card's "Is a target" STAMP
    # (MiniCard.STATE_OVERLAYS, via masked_sprite). Imported once under
    # this key — a second key would be a second copy of the same bytes.
    "target_cursor":         ["Target.pic.png", "Target.pic"],
    # fonts (from an original/Manalink install)
    "font_title.ttf":        ["MagicMedieval.ttf", "GoudyMedieval-Pre8th.ttf"],
    "font_body.ttf":         ["MPlantin-Regular.ttf", "Garamond.ttf"],
    # sounds (the original's Duelsounds/ and Sound/ folders). Keys are
    # what GameSkin.sound() serves; game/duel/duel_audio.gd maps game
    # events to them and game/music_player.gd plays the tunes.
    #
    # ================== THE WHOLE 1997 AUDIO INVENTORY ==================
    # Surveyed 2026-09-02 by walking the enum against the shipped folders
    # AND against the executables' own string tables, so that nobody has
    # to search for these files again.
    #
    # `Duelsounds/` — THE DUEL. `strings Magic.exe` names exactly 69 .wav
    # files, which is WAV_ARTIFACT=0 .. WAV_EXP1_BACKINPACK=68, i.e. the
    # enum up to its own `WAV_HIGHEST_EXE` marker. That is the 1997 duel
    # vocabulary, entire. Everything ABOVE 68 in defs.h (Bloodthirst,
    # Devour, Monstrosity, Evolve, Plus_Counter, Minus_Counter, Mill,
    # Raise_Dead, Bushido, Equip, LifeGain, Transform) is MANALINK's, and
    # `Duelsounds/sounds.txt` credits every one of them to freesound.org
    # or to a re-edit of an adventure sound. `sfx_life_gain` was imported
    # here until 2026-09-02 on that mistake: `WAV_LIFEGAIN = 79` sits
    # ABOVE `WAV_HIGHEST_EXE = 68`, sounds.txt credits it to a freesound
    # choir chord, and nothing ever played it. Do not put it back.
    # `ManaBall.wav`, `Deep.wav` and `Counter.ogg` are in the folder but
    # not in Magic.exe's list either.
    #
    # `Sound/` — THE ADVENTURE SHELL. `strings Shandalar.exe` carries a
    # resource list (`x:sound\...`) naming 60-odd files, and it is where
    # ALL the music lives:
    #   Dueltune.wav          the duel's bed — the ONE tune a duel has,
    #                         and it is TEN SECONDS long (22 050 Hz
    #                         16-bit STEREO: 10.08 s, not the 20 a mono
    #                         reading of the byte count gives)
    #   LocMus0..LocMus19     twenty location tracks, 25-39 s each. The
    #                         deck builder picks one at random and loops
    #                         it (deckdll.cpp:2047, RANDRANGE(1,19) — so
    #                         LocMus0 is the adventure's, not the deck
    #                         builder's). Imported as music_location_N,
    #                         zero included since 2026-09-03.
    #   Tmplmus1.wav          the Temple — terrain slot 19 in that same
    #                         table                      music_temple
    #   B/G/R/U/Wcastle.wav   near a castle, by colour, looped
    #                                                music_castle_<colour>
    #   Dngnduel.wav          NOT dungeon-duel music: a ONE-SHOT stinger
    #                         on the "Exploring the Dungeon...you
    #                         encounter" text            [M5, not imported]
    #   Wingame.wav           winning the whole game   [M5, not imported]
    #                         — a fanfare, not a bed, so it stays out of
    #                         the playlist as well
    #   Winduel.wav /         the shell's own copies of the duel stings;
    #   Loseduel.wav          the DUEL plays the Duelsounds/Shell_* pair
    #                         instead, which is why those are first below.
    #                         Same length, DIFFERENT audio (md5 + cmp).
    #
    # WHAT DATE THESE FILES CARRY, and why the importer says so out loud.
    # The owner's own 1997 install (`../shandalar-xp/MagicTG/`, surveyed
    # 2026-09-03) has NOT ONE audio file dated 1997 in either folder:
    # every `Duelsounds/*.wav` and `Sound/*.wav` in it is dated
    # 2009-03-03, the Manalink patch that overwrote them. The only
    # 1996-97 audio anywhere in that tree is the CD AutoPlay shell's
    # three wavs and the PCM tracks inside `Cointoss_*.avi`,
    # `Mtgend.avi` and `WinSealedTournament.avi`.
    #
    # That does NOT make the sounds fake — 71 of the 91 files in `Sound/`
    # are byte-identical to an independently distributed Manalink 3 tree,
    # `Dueltune.wav` among them — but it does mean the importer must not
    # claim a date it cannot support. `report_audio_dates` below prints
    # the source path and mtime of every sound it took, and names the
    # ones that are later than 1997. See Provenance.md, "The audio".
    #
    # The DECOMPILATION (Tier 2) is where the WHEN of that table comes
    # from, and it is cited by entry address because its function names
    # are machine guesses: `MAGIC.EXE` picks the location track by terrain
    # index (`index % 20`, wrapping to LocMus0) and loops it (entry
    # `004e7f51`); Dueltune / Winduel / Loseduel are one three-entry
    # pointer table behind a single function (entry `004ebfef`) called
    # with 0 on entering a duel, 1 beside `winbak01.pic` and 2 beside
    # `losedul2.pic`; Wingame is case 6 of the castle-victory switch
    # (entry `004ebeeb`). NOTE the decomp has NO `WAV_*` enum at all —
    # every sound call site there passes a bare integer — so defs.h below
    # remains the only NAMED table anyone has.
    #
    # and the adventure's effects, all [M5, not imported]: five world-map
    # ambiences (*wm), per-region
    # land and bird loops (*land*, *bird*), footsteps (*walkl/*walkr),
    # Dice, Treasure, Reward, Scroll, Findcard, Newsflash, Death, Horse,
    # Knight, Lord, Wolf, Troll, Dragon, Wyrm, Djinn, Archmage, Malewiz,
    # Fewiz, Flying, Dsummon, Damb1-5+Dambloop, Manaball, Button2.
    # `Manalink.wav` is Manalink's own sting — never 1997.
    #
    # `Program/statscrn.wav` exists too; nothing in the sources plays it.
    #
    # THE KEYS ARE THE ORIGINAL'S OWN EVENTS, not our guesses at them.
    # `shandalar-src/src/defs.h:2179-2265` is the 1997 sound enum, with a
    # header saying the constants are "Named identically to their filenames
    # in DuelSounds/", and the call sites in src/functions/ say which event
    # each one belongs to. Two of them are labelled in the source itself
    # and both labels contradicted what we had assumed:
    #   WAV_COUNTER  = 37  // "a counter has been added to a card", not
    #                      // "a spell has been countered"
    #   WAV_DESTROY  = 23  // "This is the rfg sound effect, despite its
    #                      // name" (deck.c:1158)
    # And the five COLOUR files are LAND sounds (the enum groups them under
    # "// Land sounds."), chosen by `play_land_sound_effect`
    # (functions.c:14382-14453) when a land RESOLVES. They were imported
    # here as `sfx_cast_<colour>` until 2026-09-01 and played on every
    # spell cast, which is why casting a Mountain and casting Lightning
    # Bolt used to sound identical. A spell's sound is by card TYPE
    # (engine.c:1784-1802). See duel-todo.md §3.8.
    "sfx_toss.wav":          duel_sound("Toss.wav"),
    # NO BARE FALLBACK — see the note above MANIFEST. An unqualified
    # `Button.wav` in a 1997 tree finds `autoplay/Button.wav`, the CD
    # AutoPlay shell's 39 ms blip, and that is what the duel's buttons
    # played until 2026-09-03.
    "sfx_button.wav":        (duel_sound("Button.wav", bare=False)
                              + shell_sound("Button.wav", bare=False)),
    "sfx_tap.wav":           duel_sound("Tap.wav"),
    "sfx_untap.wav":         duel_sound("Untap.wav"),
    "sfx_summon.wav":        duel_sound("Summon.wav"),
    "sfx_attack.wav":        duel_sound("Attack2.wav"),
    "sfx_block.wav":         duel_sound("Block2.wav"),
    "sfx_damage.wav":        duel_sound("Damage.wav"),
    "sfx_buried.wav":        duel_sound("Buried.wav"),
    "sfx_counter.wav":       duel_sound("Counter.wav"),
    "sfx_draw.wav":          duel_sound("Draw.wav"),
    "sfx_shuffle.wav":       duel_sound("Shuffle.wav"),
    "sfx_discard.wav":       duel_sound("Discard.wav"),
    "sfx_end_turn.wav":      duel_sound("EndTurn.wav"),
    "sfx_life_loss.wav":     duel_sound("LifeLoss.wav"),
    # `EndPhase.wav` IS DELIBERATELY NOT IMPORTED, and this note is here so
    # that nobody adds it back on the strength of the enum.
    #
    # It is genuine: `WAV_ENDPHASE = 4` (`defs.h:2186`) is the fifth entry
    # of the 1997 duel enum and one of the sixty-nine `.wav` names
    # `Magic.exe` carries, so it is the EXE's own and not Manalink's. A
    # `sfx_phase` key over it existed here for part of 2026-09-03. The
    # owner then settled what a phase should sound like:
    #
    #   "The changing phases or combat phases have no sound by
    #    themselves. Card action and other actions that happen in phases
    #    have sound effects."
    #
    # So every sound this game plays must be traceable to an ACTION, never
    # to the clock, and there is nothing for this file to be played BY.
    # Importing it would only tempt a future pass into wiring it to a step
    # boundary. See `game/audio.gd`, "NOT A PHASE CUE".
    # The DUEL's own win/lose stings are WAV_SHELL_WINDUEL = 45 and
    # WAV_SHELL_LOSEDUEL = 44, i.e. DuelSounds/Shell_WinDuel.wav and
    # Shell_LoseDuel.wav (windows.c:1228-1229 lists the filenames in enum
    # order). Sound/Winduel.wav and Sound/Loseduel.wav are the ADVENTURE
    # shell's copies: the same length and format but genuinely different
    # audio (`cmp` reports ~964k differing bytes), so they are the
    # fallback rather than the first choice.
    "sfx_win.wav":           (duel_sound("Shell_WinDuel.wav", bare=False)
                              + shell_sound("Winduel.wav")),
    "sfx_lose.wav":          (duel_sound("Shell_LoseDuel.wav", bare=False)
                              + shell_sound("Loseduel.wav")),
    # A SPELL sounds like its card TYPE (engine.c:1784-1802, in the
    # resolve path: WAV_SUMMON / WAV_ARTIFACT / WAV_ENCHANT / WAV_INSTANT /
    # WAV_INTERUPT / WAV_SORCERY). Creatures reuse sfx_summon above.
    "sfx_cast_artifact.wav":    duel_sound("Artifact.wav"),
    "sfx_cast_enchantment.wav": duel_sound("Enchant.wav"),
    "sfx_cast_instant.wav":     duel_sound("Instant.wav"),
    "sfx_cast_sorcery.wav":     duel_sound("Sorcery.wav"),
    # 1997 had INTERRUPT as a card type (Counterspell, Power Sink, the
    # Elemental Blasts). We type them all as instants per the modern
    # oracle, so this plays for a spell that COUNTERS — see
    # DuelScreen._cast_sound_key.
    "sfx_cast_interrupt.wav":   duel_sound("Interupt.wav"),
    # A LAND sounds like the COLOURS IT MAKES (play_land_sound_effect,
    # functions.c:14387-14453): colourless -> Grey, one colour -> that
    # colour, two -> the pair's own file. A five-colour land (City of
    # Brass) is SILENT in the original — the Manalink comment at :14446
    # says so while choosing GemBazar for itself, and we keep the 1997
    # silence. Three- and four-colour lands do not exist in this pool.
    #
    # `Grey.wav` IS THE FILE THAT PROVED THE DIRECTORY RULE WAS NEEDED:
    # three copies across the local trees, all 144 464 bytes, all
    # 22 050 Hz mono 16-bit, and THREE different md5s. They are one
    # recording at three gain stagings (Provenance.md, "Three masterings,
    # no original"), and a flat index picked between them at random.
    "sfx_land_grey.wav":        duel_sound("Grey.wav"),
    "sfx_land_white.wav":       duel_sound("White.wav"),
    "sfx_land_blue.wav":        duel_sound("Blue.wav"),
    "sfx_land_black.wav":       duel_sound("Black.wav"),
    "sfx_land_red.wav":         duel_sound("Red.wav"),
    "sfx_land_green.wav":       duel_sound("Green.wav"),
    "sfx_land_white_blue.wav":  duel_sound("WhiteBlue.wav"),
    "sfx_land_blue_black.wav":  duel_sound("BlueBlack.wav"),
    "sfx_land_black_red.wav":   duel_sound("BlackRed.wav"),
    "sfx_land_red_green.wav":   duel_sound("GreenRed.wav"),
    "sfx_land_green_white.wav": duel_sound("WhiteGreen.wav"),
    "sfx_land_white_black.wav": duel_sound("BlackWhite.wav"),
    "sfx_land_black_green.wav": duel_sound("GreenBlack.wav"),
    "sfx_land_green_blue.wav":  duel_sound("GreenBlue.wav"),
    "sfx_land_blue_red.wav":    duel_sound("RedBlue.wav"),
    "sfx_land_red_white.wav":   duel_sound("Whitered.wav"),
    # ============================== MUSIC ==============================
    # TWENTY-SEVEN TRACKS, and until 2026-09-03 this list took twenty.
    #
    # The owner's verdict on what that bought: *"Music in the duel is
    # wrong — now it is repeating a short sample — unacceptable. Check
    # music songs available."* `Dueltune.wav` is TEN SECONDS. Looping it
    # is what the 1997 duel did, and in a ten-minute duel that is sixty
    # repeats of the same bar, with a click on every wrap.
    #
    # So every LOOPABLE BED in `Sound/` is imported now, and
    # [MusicLibrary] plays them as a playlist. The one-shots are still
    # left out, because a stinger in a shuffle is a jump-scare:
    # `Dngnduel.wav` (the "you encounter" text), `Wingame.wav` (winning
    # the whole adventure), `Winduel.wav`/`Loseduel.wav` (the duel
    # stings, already imported as sfx_win/sfx_lose).
    #
    # WHAT EACH BED IS, from `MAGIC.EXE` (Tier 2, cited by entry address
    # because the decompilation's function names are machine guesses):
    #   Dueltune       the duel bed; one of a three-entry pointer table
    #                  with Winduel and Loseduel behind entry `004ebfef`,
    #                  called with 0 on entering a duel.
    #   LocMus0..19    the location tracks, picked by terrain index
    #                  (`index % 20`) and looped, at entry `004e7f51`.
    #                  The deck builder takes 1..19 only
    #                  (`deckdll.cpp:2047`, `RANDRANGE(1, 19)`), which is
    #                  why LocMus0 was left out until now; it is a track
    #                  like the others and belongs in a playlist.
    #   Tmplmus1       the Temple — terrain slot 19 of that same table.
    #   [BGRUW]castle  near a castle, by the castle's colour, looped.
    "music_duel.wav":        shell_sound("Dueltune.wav"),
    "music_location_0.wav":  shell_sound("LocMus0.wav"),
    "music_location_1.wav":  shell_sound("LocMus1.wav"),
    "music_location_2.wav":  shell_sound("LocMus2.wav"),
    "music_location_3.wav":  shell_sound("LocMus3.wav"),
    "music_location_4.wav":  shell_sound("LocMus4.wav"),
    "music_location_5.wav":  shell_sound("LocMus5.wav"),
    "music_location_6.wav":  shell_sound("LocMus6.wav"),
    "music_location_7.wav":  shell_sound("LocMus7.wav"),
    "music_location_8.wav":  shell_sound("LocMus8.wav"),
    "music_location_9.wav":  shell_sound("LocMus9.wav"),
    "music_location_10.wav": shell_sound("LocMus10.wav"),
    "music_location_11.wav": shell_sound("LocMus11.wav"),
    "music_location_12.wav": shell_sound("LocMus12.wav"),
    "music_location_13.wav": shell_sound("LocMus13.wav"),
    "music_location_14.wav": shell_sound("LocMus14.wav"),
    "music_location_15.wav": shell_sound("LocMus15.wav"),
    "music_location_16.wav": shell_sound("LocMus16.wav"),
    "music_location_17.wav": shell_sound("LocMus17.wav"),
    "music_location_18.wav": shell_sound("LocMus18.wav"),
    "music_location_19.wav": shell_sound("LocMus19.wav"),
    "music_temple.wav":         shell_sound("TmplMus1.wav"),
    "music_castle_white.wav":   shell_sound("WCastle.wav"),
    "music_castle_blue.wav":    shell_sound("UCastle.wav"),
    "music_castle_black.wav":   shell_sound("BCastle.wav"),
    "music_castle_red.wav":     shell_sound("RCastle.wav"),
    "music_castle_green.wav":   shell_sound("GCastle.wav"),
}


# ============================================================ THE MOVIES ==
#
# THE 1997 COIN TOSS WAS NOT AN ANIMATION. IT WAS A MOVIE, and that is why
# no coin art exists anywhere in the asset set to import.
#
# The evidence, from three sources that agree:
#
#  * The decompilation: the toss opens its own dialog and embeds an AVI in
#    it through Win32's MCIWnd control — `MCIWndCreateA(...)` on
#    `COINTOSS_Heads.AVI` / `COINTOSS_Tails.AVI`, with a 10ms poll timer
#    and a 15-second timeout (`DUEL.EXE`, the dialog proc at entry
#    `004492ad`).
#  * `Program/Magic.exe`'s own string table, which holds the dialog tag
#    and its two movies in three consecutive literals:
#        DIALOG_COINFLIP
#        %s\COINTOSS_Tails.AVI
#        %s\COINTOSS_Heads.AVI
#  * `UIStrings.txt:593-596`, where `@DIALOG_COINFLIP` is exactly two
#    strings — `Coin flip results: Heads` and `Coin flip results: Tails`,
#    one caption per movie.
#
# --------------------------------------------------------------------------
# WHY THIS IS THE IMPORTER'S FIRST TRANSCODING STEP, AND NOT A COPY
# --------------------------------------------------------------------------
#
# **THE CODEC IS NOT ONE CODEC — corrected 2026-09-03.** The claim here
# used to be flatly "the 1997 video codec is Indeo Video 4.1", read out of
# the original's own video DLL (`magvid.dll` imports `AVIFileOpenA`,
# `AVIStreamRead`, `AVIStreamReadFormat`, carries `LoadAVI` / `PlayAVI` /
# `StopAVI` / `UnloadAVI`, and holds the fourcc literals `iv41`, `IV41`,
# `iv41j` beside them) and confirmed across the 69 AVIs of a MANALINK
# install: all IV41, 24-bit, 15fps.
#
# The owner's own 1997 CD says otherwise for the file that matters. In
# `MagicTG/Duelart/` — timestamped 1997-01-28, four months before the
# release — `Cointoss_Heads.avi` and `Cointoss_Tails.avi` declare
# **`CRAM`**, which is Microsoft Video 1: an 8x8 RLE-ish codec from 1992
# that every ffmpeg and GStreamer build decodes. The Manalink survey was
# right about the files it looked at and wrong as a general claim; the
# 69 IV41 movies are the ones a 2001+ patch shipped.
#
# WHAT FOLLOWS FROM IT. The decoder is chosen by the FILE, not by us:
# `decodebin` auto-plugs whatever a given AVI declares, so one pipeline
# reads the 1997 coin (CRAM) and the Manalink animations (IV41) alike.
# Indeo 4 is still a wavelet codec nobody should write a Python decoder
# for, and Godot 4 still plays only Ogg Theora — `VideoStreamPlayer` has
# never heard of AVI — so the movie still cannot be read at run time by
# the game, and this step still produces a SPRITE SHEET.
#
# THE CHOICE: an external decoder, DETECTED and never assumed, producing a
# SPRITE SHEET.
#
#  * A sheet is what every other original asset in this project already is
#    — `Manasymbols.pic`, the badge strips, the filter bar, the set icons
#    — so the game plays the movie with the region walk it already knows
#    ([CoinToss]) instead of gaining a video subsystem it has never had.
#  * It removes Theora from the picture. Transcoding to `.ogv` would need
#    the decoder AND a libtheora-enabled encoder, i.e. two things to
#    detect instead of one; frames are frames.
#  * The decoder only ever has to emit RAW RGB, which both candidates do
#    natively, so nothing here depends on a particular filter graph or
#    muxer being compiled in. The PNG is then written from the standard
#    library (`zlib`), so the importer keeps its "stdlib only" promise —
#    Pillow is NOT required.
#
# TWO CANDIDATES, in preference order. `ffmpeg` first: it is the one a
# player is most likely to have and the one that exists on every platform.
# `gst-launch-1.0` second, with `avdec_indeo4` — the same libav decoder
# wearing a GStreamer name, present on most Linux desktops through
# `gstreamer1.0-libav`. If neither is installed the movies are SKIPPED with
# a message naming both, and the game falls back to our own coin animation
# ([method CoinToss.effective_style]) instead of failing.
#
# **NOTHING HERE SHIPS.** The two AVIs exist only in a genuine 1997
# install — they are in no reference tree, checked 2026-09-02 — and the
# sheets this writes land in the same gitignored skin directory as
# everything else.

## skin key -> the original filename, and which caption it belongs to.
VIDEOS: dict[str, list[str]] = {
    "coin_toss_heads": ["COINTOSS_Heads.AVI"],
    "coin_toss_tails": ["COINTOSS_Tails.AVI"],
}

## No sheet may exceed this on either axis. Well inside every renderer's
## texture limit, including the Compatibility one the project targets.
MAX_SHEET = 4096


def read_avi_header(path: Path) -> dict | None:
    """Width, height, frame count, rate and codec fourcc — pure Python.

    Only the RIFF headers are parsed, never the picture data, so this
    answers "what IS this file" even on a machine with no decoder at all.
    `avih` (the main AVI header) carries microseconds-per-frame and the
    total frame count; the video stream's `strf` is a BITMAPINFOHEADER
    whose `biCompression` is the fourcc.
    """
    head = path.read_bytes()[:65536]
    if head[:4] != b"RIFF" or head[8:12] != b"AVI ":
        return None
    main = head.find(b"avih")
    fmt = head.find(b"strf")
    if main < 0 or fmt < 0 or len(head) < fmt + 48:
        return None
    micros, _rate, _pad, _flags, frames = struct.unpack(
        "<IIIII", head[main + 8:main + 28])
    _size, width, height, _planes, bits = struct.unpack(
        "<IiiHH", head[fmt + 8:fmt + 24])
    codec = head[fmt + 24:fmt + 28].decode("latin-1")
    return {
        "width": abs(width), "height": abs(height), "bits": bits,
        "frames": frames, "codec": codec,
        "fps": round(1_000_000 / micros, 4) if micros else 15.0,
    }


def find_decoder() -> tuple[str, str] | None:
    """(program, human name) for the first usable decoder, or None."""
    if shutil.which("ffmpeg"):
        return ("ffmpeg", "ffmpeg")
    gst = shutil.which("gst-launch-1.0")
    if gst:
        try:
            # `decodebin`, not a named decoder: the 1997 files are not all
            # one codec (see the block above — the coin is CRAM and the
            # Manalink-era movies are IV41), and decodebin auto-plugs
            # whichever decoder the file actually needs. Requiring
            # `avdec_indeo4` by name is what made this machine report "no
            # decoder" while holding a perfectly decodable coin toss.
            probe = subprocess.run(["gst-inspect-1.0", "decodebin"],
                                   capture_output=True, timeout=30)
            if probe.returncode == 0:
                return ("gst-launch-1.0", "gst-launch-1.0 (decodebin)")
        except (OSError, subprocess.SubprocessError):
            pass
    return None


def decode_frames(program: str, avi: Path, width: int, height: int) -> bytes:
    """Every frame of `avi` as packed RGB24 at `width` x `height`.

    Raises CalledProcessError / OSError if the decoder fails; the caller
    turns that into a skip rather than a crash.
    """
    if program == "ffmpeg":
        # The `scale` filter runs even at 1:1, so what comes back is
        # always exactly `width` x `height` and the tiler can trust it.
        argv = ["ffmpeg", "-nostdin", "-v", "error", "-i", str(avi),
                "-vf", f"scale={width}:{height}:flags=lanczos",
                "-f", "rawvideo", "-pix_fmt", "rgb24", "-"]
        # `-nostdin` AND a closed stdin: ffmpeg reads the terminal by
        # default, and a decoder that stops to ask a question would wedge
        # the importer — this project has already lost most of a day to a
        # command that could block.
        return subprocess.run(argv, capture_output=True, check=True,
                              timeout=600,
                              stdin=subprocess.DEVNULL).stdout
    # GStreamer will not write raw video to stdout cleanly, so it goes
    # through a temp file. Its raw RGB rows are padded to a multiple of
    # four bytes (`GST_ROUND_UP_4`), which ffmpeg's are not — that padding
    # is stripped below, and getting it wrong is what shears an image.
    with tempfile.TemporaryDirectory() as tmp:
        raw = Path(tmp) / "frames.rgb"
        # EACH ARGV ELEMENT IS ONE TOKEN. `gst_parse_launchv` does not
        # re-split on spaces, so "filesrc location=X" as a single element
        # is a syntax error — the property has to be its own word.
        argv = ["gst-launch-1.0", "-q",
                "filesrc", f"location={avi}", "!", "decodebin", "!",
                "videoconvert", "!", "videoscale", "!",
                f"video/x-raw,format=RGB,width={width},height={height}", "!",
                "filesink", f"location={raw}"]
        subprocess.run(argv, capture_output=True, check=True, timeout=600,
                       stdin=subprocess.DEVNULL)
        padded = raw.read_bytes()
    stride = ((width * 3 + 3) // 4) * 4
    if stride == width * 3:
        return padded
    tight = bytearray()
    for row in range(len(padded) // stride):
        tight += padded[row * stride:row * stride + width * 3]
    return bytes(tight)


def plan_sheet(width: int, height: int, frames: int) -> tuple[int, int, int, int]:
    """cols, rows, frame width, frame height for a sheet inside MAX_SHEET.

    Aims for a roughly SQUARE sheet (cols = sqrt(frames * h / w)), then
    shrinks the frames if that still does not fit. A 1997 AVI is small
    enough that the shrink almost never fires — the surviving ones run
    144x300 to 576x340 — but a 15-second toss at 15fps is 225 frames and
    the arithmetic has to hold anyway.
    """
    for step in range(10):
        scale = 1.0 - step * 0.1
        w = max(1, round(width * scale))
        h = max(1, round(height * scale))
        cols = max(1, min(frames, round(math.sqrt(frames * h / w)) or 1))
        rows = math.ceil(frames / cols)
        if cols * w <= MAX_SHEET and rows * h <= MAX_SHEET:
            return cols, rows, w, h
    raise ValueError("no sheet layout fits %d %dx%d frames"
                     % (frames, width, height))


def write_png(path: Path, width: int, height: int, pixels: bytes,
              alpha: bool = False) -> None:
    """An 8-bit RGB (or, with `alpha`, RGBA) PNG, from the standard
    library and nothing else.

    Filter type 0 on every scanline: the sheets are small, the importer
    runs once, and a filter-free file is one whose correctness can be read
    off this function. `alpha` is what the portraits need — their
    transparency is the sprite's own and has to survive the trip.
    """
    channels = 4 if alpha else 3
    stride = width * channels
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        raw += pixels[y * stride:(y + 1) * stride]

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8,
                                     6 if alpha else 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b""))


def tile_frames(rgb: bytes, cols: int, rows: int, w: int, h: int,
                frames: int) -> bytes:
    """Lay `frames` RGB frames out ROW-MAJOR on one sheet.

    Row-major is the order `CoinToss.video_frame_rect` reads them back in;
    the two must not drift apart.
    """
    sheet = bytearray(cols * w * rows * h * 3)
    sheet_stride = cols * w * 3
    frame_stride = w * 3
    for index in range(frames):
        col, row = index % cols, index // cols
        base = index * frame_stride * h
        for y in range(h):
            dst = (row * h + y) * sheet_stride + col * frame_stride
            src = base + y * frame_stride
            sheet[dst:dst + frame_stride] = rgb[src:src + frame_stride]
    return bytes(sheet)


def import_videos(index: dict[str, Path], dest: Path) -> None:
    """Transcode each original AVI into `<key>.png` + `<key>.json`.

    Never fatal: a missing movie, a missing decoder or a decoder that
    fails all leave the sheets absent, and the game presents the toss with
    its own animation instead.
    """
    wanted = {key: index[name.lower()]
              for key, names in VIDEOS.items()
              for name in names if name.lower() in index}
    if not wanted:
        print("\nno original movies found "
              "(COINTOSS_*.AVI ship only with the 1997 game) — "
              "the coin toss will use our own animation")
        return

    decoder = find_decoder()
    if decoder is None:
        print("\nfound %d original movie(s) but NO DECODER."
              % len(wanted))
        for key, path in sorted(wanted.items()):
            header = read_avi_header(path) or {}
            print("  %-18s %s (%s)" % (key, path.name,
                                       header.get("codec", "unknown codec")))
        # THE CODEC LINE WAS WRONG FOR A YEAR. These were called Indeo
        # 4.1 everywhere, including here, and the advice that followed
        # named `avdec_indeo4` — a decoder that cannot open them. The
        # header says CRAM (Microsoft Video 1); `decodebin` auto-plugs the
        # right one, which is why the pipeline works and the message did
        # not. Corrected 2026-09-04 against the files' own headers.
        print("  These are %s, which neither Python nor Godot can\n"
              "  decode. Install ffmpeg (any platform) or\n"
              "  gstreamer1.0-libav (which brings gst-launch-1.0), then\n"
              "  run this importer again. Until then the coin toss uses\n"
              "  our own animation, which needs nothing."
              % ", ".join(sorted({(read_avi_header(p) or {}).get("codec",
                                  "an unknown codec")
                                  for p in wanted.values()})))
        return

    program, label = decoder
    print("\nmovies (decoding with %s):" % label)
    for key, path in sorted(wanted.items()):
        header = read_avi_header(path)
        if header is None:
            print("  %-18s SKIPPED — not a readable AVI: %s" % (key, path))
            continue
        # A first pass only to settle the DECODE size — the frames may
        # need shrinking to fit a sheet, and the decoder has to be told
        # before it starts. The grid itself is re-planned below, against
        # the frame count the decoder actually produced.
        _, _, w, h = plan_sheet(header["width"], header["height"],
                                max(1, header["frames"]))
        try:
            rgb = decode_frames(program, path, w, h)
        except (OSError, subprocess.SubprocessError) as err:
            print("  %-18s SKIPPED — %s could not decode %s (%s): %s"
                  % (key, program, path.name, header["codec"], err))
            continue
        # The decoder is the authority on how many frames there ACTUALLY
        # are; an AVI header's count and its stream have been known to
        # disagree, and trusting the header would tile garbage.
        frames = len(rgb) // (w * h * 3)
        if frames <= 0:
            print("  %-18s SKIPPED — %s produced no frames from %s"
                  % (key, program, path.name))
            continue
        cols, rows, w, h = plan_sheet(w, h, frames)
        sheet = tile_frames(rgb, cols, rows, w, h, frames)
        write_png(dest / (key + ".png"), cols * w, rows * h, sheet)
        (dest / (key + ".json")).write_text(json.dumps({
            "cols": cols, "rows": rows, "frames": frames,
            "frame_width": w, "frame_height": h, "fps": header["fps"],
            "source": path.name, "codec": header["codec"],
            "decoder": label,
        }, indent=1) + "\n")
        print("  %-18s <- %s  (%d frames, %dx%d, %s, %gfps -> %dx%d sheet)"
              % (key, path, frames, w, h, header["codec"], header["fps"],
                 cols * w, rows * h))


# ------------------------------------------------------------ portraits --
#
# THE FACE SHEET HOLDS FOURTEEN FACES, NOT NINE.
#
# `16faces.spr` (1997-01-09) is the pool the 1997 character-select screen
# draws from, and it decodes to **14** frames of 137x169. Three witnesses
# agree on that number and no source anywhere says sixteen — the file name
# is simply wrong, or two faces were cut before release:
#
#   * the file itself — 14 frame headers, then the 0xFFFFFFFF terminator;
#   * the decompilation (Provenance.md Tier 2), `MAGIC.EXE` entry
#     `0047b899`: it calls `Sprite_LoadAll(..., "16faces.spr")`, builds a
#     button table with `FUN_0040b441(&DAT_005263f0, 0xe)` and then draws
#     `for (i = 0; i < 0xe; i++)` — 0xe = 14;
#   * `Advstrings.txt` (1997-05-12, the owner's own install, Tier 1), tag
#     `@PLAYERNAMES`, whose count line reads `14`.
#
# WHY THE CONVERSION IS SHORT. s30's `16faces.spr.png` is 1233x169 = 9
# cells, and its nine are byte-identical (palette indices, cell for cell)
# to frames 0-8 here. The five missing ones are a bug in the converter,
# not a difference in the file: `mp_pic_tools/spr2png.py` tiles frames
# with `modulo = min(1240 // width, len(bitmaps))` and then
# `sheet_height = height * (len(bitmaps) // modulo)` — integer division.
# 1240 // 137 = 9, and 14 // 9 = 1, so it allocates ONE row of nine and
# drops frames 9-13 on the floor. Any 137-wide sheet with 10-17 frames
# loses the tail the same way. (Found 2026-09-03; reported here, not
# fixed — it is someone else's repository.)
#
# EACH FACE HAS A NAME, and it is not ours. Picking face *i* seeds the
# player's name with entry *i* of `@PLAYERNAMES`: the loader at `0047b899`
# does `strcpy(name_buf, *(char **)(DAT_00525f28 * 4 + 0x5268dc))` with
# the same 1-based button id it uses for the sprite,
# `(&DAT_00676d7c)[DAT_00525f28]` — one table, one index, so name *i* goes
# with frame *i*. The decompiled `MAGIC.EXE` carries all fourteen as
# string literals at consecutive addresses (`0x526944` "Melody Whisp" ...
# `0x5269ec` "Keleena") in exactly the order `Advstrings.txt` prints them,
# which is the cross-check. The art agrees too: frame 0 is a woman with a
# FLUTE (Melody Whisp), frame 1 the only armoured knight (Sir Van Popple),
# frame 12 the only East-Asian figure (Wu Wei).
#
# THE PALETTE IS `Pedstls.pic`'s, not a `.tr` file. `0047b899` calls
# `LoadPalNoPic("pedstls.pic")` immediately before loading the sheet.
# That palette equals `DuelPalAll.tr` for every entry the `.tr` defines
# (1-235) but fills the ones it leaves out, and index 255 is WHITE there
# where the `.tr` reader defaults it to black — two pixels in the whole
# sheet, but they are two pixels the original draws white.
#
# WHAT IT IS NOT. The 66 `rogues/*.png` are the ENEMY faces — `Menus.txt`
# `@DECKFACES` names 55 of them and the exe reads `faces\%03d.pic` by deck
# id; the raw set is `Faces/000.pic`..`056.pic` (1996-10-10), 276x170 =
# 138 image + 138 mask, and those decode with `DuelPalAll.tr`.
# `Ego_M/Ego_F.spr` are the overworld WALKING sprites (5x8 frames of
# 248x174). `Faceart/Fb1`..`Fb17` are 664 SPR frames of face PARTS — the
# layer sets for `Facemaker.exe`, the 1997 face builder — and `Face.pic`
# (274x169 = 137 image + 137 mask) is one finished face, the chosen one
# written back out. Neither is a portrait pool this can cut.
PORTRAIT_SHEET_RAW: list[str] = ["16faces.spr", "16faceslow.spr"]
PORTRAIT_SHEET_PNG: list[str] = ["16faces.spr.png", "16faceslow.spr.png"]
PORTRAIT_CELL = (137, 169)
## The palette the character-select screen loads before the sheet, then
## the plain text palette that covers all but its undefined entries.
PORTRAIT_PALETTE_PIC: list[str] = ["pedstls.pic", "menu4.pic"]
PORTRAIT_PALETTE_TR: list[str] = ["duelpalall.tr"]
## `@PLAYERNAMES` (Advstrings.txt), in frame order — see the block above.
## `dina_bin-barq` -> "Dina Bin Barq" and `ali_of_willoshire` -> "Ali Of
## Willoshire" through PortraitLibrary.title_of, which is as close as a
## file name gets.
PORTRAIT_NAMES: list[str] = [
    "melody_whisp", "sir_van_popple", "muriallisa", "goya",
    "lady_dragetta", "ali_of_willoshire", "snow_blight", "baba_bue",
    "dina_bin-barq", "inniscor", "gauldron", "agnosia", "wu_wei",
    "keleena",
]
## Anything past the named fourteen: `face_15.png` -> "Face 15".
PORTRAIT_PREFIX = "face_"


def portrait_name(index: int) -> str:
    """Frame number (0-based) -> file base name."""
    if index < len(PORTRAIT_NAMES):
        return PORTRAIT_NAMES[index]
    return "%s%d" % (PORTRAIT_PREFIX, index + 1)


# ------------------------------------------------------------- the rogues --
#
# THE 57 ENEMY FACES, AND WHY THERE ARE ONLY 55 OF THEM.
#
# `Faces/000.pic` .. `Faces/056.pic` (1996-10-10, the owner's own install)
# are the enemy portraits — 276x170 apiece, which is a 138-wide picture
# beside a 138-wide MASK, the same pairing `game/set_badges.gd` documents
# for the other 1997 sheets. They carry NO palette block and take
# `DuelPalAll.tr`; `Todpal`, `Advpal` and `Palall9` render garbage.
#
# **THE INDEX IS ONE-BASED, and `000.pic` and `056.pic` are padding.**
# Fifty-seven files, fifty-five pictures: `000.pic` is byte-identical to
# `001.pic` and `056.pic` to `055.pic` (md5, 2026-09-03). Line them up
# one-based and every one of `@DECKFACES`'s 55 names lands on a distinct
# picture — `001.pic` the Witch, `055.pic` the Uber Villain — with a copy
# of each end hanging off it, which is exactly the shape of a table
# written to survive an index of 0 or 56.
#
# THAT ALIGNMENT IS NOT A GUESS. s30 ships all 55 as named PNGs
# (`assets/art/rogues/MPS_*.png`, 138x170 — the picture half of these
# very files, palette-reduced). Hashing each PNG's transparent-pixel set
# against each `.pic`'s matches ALL FIFTY-FIVE, one-based, with no
# collisions and nothing left over: `002.pic` = `MPS_Undead_Knight` =
# `@DECKFACES` #2, ... `054.pic` = `MPS_Kiska-Ra` = #54. Two independent
# tables agreeing on 55 rows is as close to proof as this gets, and the
# art itself is the third witness — #12 Arch Angel is the only winged
# woman with a sword, #36 Tusk Guardian the only elephant.
#
# **THE THREE COUNTS, RECONCILED** — 57 files, 55 names, 66 s30 PNGs:
#
#   57  files in `Faces/`, of which two are the duplicate end-caps above.
#   55  pictures, and 55 `@DECKFACES` names. One-based, exactly.
#   66  `s30/assets/art/rogues/*.png` — and NOT the same 66 as anything
#       in the install; the number is a coincidence, twice over. Of
#       s30's: 55 are `MPS_*` and are the picture half of these very
#       files, palette-reduced; `Face.png` is 137x169 and is `Face.pic`,
#       the player face below, not a rogue; the other TEN (`Chunk`,
#       `Cutiepie`, `Desdemona`, `Greenie`, `Lance`, `Lizzy`, `Lumpy`,
#       `Medusa`, `Ophelia`, `Splinter`) match nothing in a 1997 tree,
#       wear a different and more painterly style, and are named by no
#       1997 table. They are s30's own (Tier 3).
#
#       The larger MicroProse set is `MagicTG/Exp1art/Rogues/`, the
#       *Duels of the Planeswalkers* expansion: `Rogue01.pic`..
#       `Rogue72.pic` with six numbers absent = 66 files (coincidence
#       two). Its dates and its md5s partition it identically, which is
#       the check: 50 files dated 1996-10-10 are byte-identical to
#       `Faces/` (46 at their own slot, 4 moved to new slots 67-70), and
#       16 dated 1997-08/09 are 5 REDRAWN base slots (10, 15, 24, 39,
#       42) plus ELEVEN faces `Faces/` does not have. Those eleven have
#       no name in any 1997 table, so the expansion set is NOT imported
#       here: inventing names is the one thing this project does not do.
#
# THE NAMES ARE `@DECKFACES`, `s30/assets/text/Menus.txt:78` (count line
# `55`) — the genuine 1997 copy; `MagicTG/Menus.txt:88` is the 2009 patch
# and carries the identical block, which is the cross-check. They are
# ROLES, not people: entry 55 reads `Uber Villain`, and everywhere the
# player meets him (`Advstrings.txt:218`, `Advblocks.txt:27`) he is
# **Arzakon**. The table wins — this file names what the table names.
ROGUE_SLOTS = range(57)
ROGUE_CELL = (138, 170)
## The duel screen's palette, which is what these are drawn in. The
## character-select `Pedstls.pic` is the same table for every entry that
## matters (they differ at 191 and 255 only) and stands in for it.
ROGUE_PALETTE_TR: list[str] = ["duelpalall.tr"]
ROGUE_PALETTE_PIC: list[str] = ["pedstls.pic"]
## `@DECKFACES` in order, so `ROGUE_NAMES[0]` is entry 1 = `001.pic`.
ROGUE_NAMES: list[str] = [
    "witch", "undead_knight", "warlock", "vampirelord", "nether_fiend",
    "necromancer", "greater_lich", "cleric", "priestess", "crusader",
    "paladin", "arch_angel", "high_priest", "sainted_one", "seer",
    "merfolk_shaman", "conjurer", "sea_dragon", "shapeshifter",
    "thought_invoker", "astral_visionary", "druid", "elvish_magi",
    "enchantress", "forest_dragon", "beastmaster", "summoner",
    "great_druid", "sorceress", "sorcerer", "troll_shaman", "goblin_lord",
    "hydra", "war_mage", "dragon_lord", "tusk_guardian", "sedge_beast",
    "ape_lord", "centaur_shaman", "winged_stallion", "fungus_master",
    "centaur_warchief", "mind_stealer", "lord_of_fate", "elementalist",
    "aga_galneer", "alt-a-kesh", "queltosh", "saltrem_tor", "mandurang",
    "whim", "prismat", "dracur", "kiska-ra", "uber_villain",
]
## THE PREFIX, and the reason for it. The chooser
## ([method PortraitLibrary.all]) sorts one flat list by DISPLAY name, so
## fifty-five more faces land among the fourteen unless something groups
## them — and half of `@DECKFACES` is a bare job title (`Seer`, `Druid`,
## `Cleric`) that reads oddly beside a person's name. `rogue_witch.png`
## becomes "Rogue Witch" and the 55 sit together.
##
## `Rogue` IS THE ORIGINAL'S OWN WORD for them, not ours: the expansion
## ships this art as `Exp1art/Rogues/Rogue01.pic` and its screen backdrop
## as `Winbk_Rogue.pic`. s30 and mage-go use it too (`assets/art/rogues/`,
## `rogue_dck/`).
##
## The fourteen keep their bare `@PLAYERNAMES` — those ARE names, and a
## saved `portrait` id in `settings.cfg` is a file base name. The cost is
## that the block of 55 lands mid-alphabet and splits the fourteen into
## two runs (Agnosia..Dina, then Gauldron..Wu Wei). Grouping the enemies
## was the half worth having; prefixing a person's own name to fix the
## other half would cost more than it bought.
ROGUE_PREFIX = "rogue_"
## A slot with no `@DECKFACES` name and a picture nothing else has —
## `rogue_face_00.png` -> "Rogue Face 00". Honest, and it says by its
## shape that nobody named it. No 1997 install should ever produce one.
ROGUE_UNNAMED_PREFIX = "rogue_face_"


def rogue_name(slot: int) -> str:
    """`Faces/<slot>.pic` -> file base name. Slots are ONE-BASED."""
    if 1 <= slot <= len(ROGUE_NAMES):
        return ROGUE_PREFIX + ROGUE_NAMES[slot - 1]
    return "%s%02d" % (ROGUE_UNNAMED_PREFIX, slot)


## Every block tag PicV3 defines. `C0`/`E0` are legal and unimplemented —
## no file in a 1997 Magic install uses them, and one that did would be
## reported rather than half-decoded.
PIC_TAGS = (b"C0", b"E0", b"M0", b"M1", b"X0", b"X1")


def iter_pic_blocks(data: bytes):
    """Walk a PicV3 file: yield `(tag, payload)` per block.

    A `.pic` is a chain of `<2-byte tag><uint16 length><data>`. Two
    details are not guessable from that sentence and both come from
    `mp_pic_tools/pic_headers.py` + `pic2png.py` (Provenance.md Tier 2):

      * the IMAGE block (`X0`/`X1`) is always last, and its `length` is
        sometimes an overflowed `uint16` — `0028.pic` in the owner's own
        install is the example the reference names — so the image payload
        is "the rest of the file", never `length` bytes;
      * anything whose tag is not one of the six is not a PicV3 file at
        all, which is how a PNG-wearing-a-`.pic`-name gets caught
        (`Program/DBArt/*.pic`, Provenance.md).

    Raises ValueError on a tag it does not recognise, so every caller can
    tell "not a PicV3 file" from "a PicV3 file I could not read".
    """
    offset = 0
    while offset + 4 <= len(data):
        tag = data[offset:offset + 2]
        length = struct.unpack_from("<H", data, offset + 2)[0]
        if tag not in PIC_TAGS:
            raise ValueError("not a PicV3 block: %r" % (tag,))
        if tag in (b"X0", b"X1"):
            yield tag, data[offset + 4:]
            return
        yield tag, data[offset + 4:offset + 4 + length]
        offset += 4 + length


def read_pic_palette(path: Path) -> bytes | None:
    """The 768-byte RGB palette out of a PicV3 `M0`/`M1` block, or None.

    The palette block is `first, last` then `last - first + 1` RGB
    triples. Only a full 0-255 palette is any use here, so a partial one
    is refused rather than padded. This reads the palette block only and
    never decompresses the image, which is what makes it cheap enough to
    call on a 640x480 screen just for its colours.
    """
    try:
        data = path.read_bytes()
    except OSError:
        return None
    try:
        for tag, payload in iter_pic_blocks(data):
            if tag not in (b"M0", b"M1"):
                continue
            first, last = payload[0], payload[1]
            if first != 0 or last != 255:
                return None
            palette = payload[2:2 + 768]
            return palette if len(palette) == 768 else None
    except (ValueError, IndexError, struct.error):
        return None                        # not a PicV3 file at all
    return None


def read_tr_palette(path: Path) -> bytes | None:
    """A `.tr` text palette -> 768 RGB bytes. `<index> - <r> <g> <b> ...`

    Entries the file never names stay black. `spr2png.py` leaves them
    bright green to make them obvious; here they are simply unused, and
    black is the quieter wrong answer.
    """
    table = bytearray(768)
    try:
        text = path.read_text(errors="replace")
    except OSError:
        return None
    seen = 0
    for line in text.splitlines():
        parts = line.replace("-", " ").split()
        if len(parts) < 4:
            continue
        try:
            values = [int(x) for x in parts[:4]]
        except ValueError:
            continue
        index = values[0]
        if not 0 <= index <= 255 or any(not 0 <= v <= 255 for v in values[1:]):
            continue
        table[index * 3:index * 3 + 3] = bytes(values[1:4])
        seen += 1
    return bytes(table) if seen >= 200 else None


def decode_spr(data: bytes) -> list[tuple[int, int, bytes]]:
    """A MicroProse `.SPR` -> `[(width, height, palette indices), ...]`.

    The algorithm is `parse_spr` in `mp_pic_tools/spr2png.py`
    (Provenance.md Tier 2) minus its sheet-tiling step, which is the step
    that loses frames. Per frame: a 16-byte header (`uint32` byte length
    INCLUDING the header, `uint16` width, height, two unknowns, then the
    count of fully transparent lines at the top and the line at which
    transparency resumes), then one variable-length run per remaining
    line — `0xFF` padding to skip, a count of leading transparent pixels,
    a count of data pixels (`0xFE`/`0xFF` meaning "the count is the next
    byte"), then that many palette indices. Index 0 is transparent and
    everything past the run is too. The list ends at a length of
    `0xFFFFFFFF`.

    Raises ValueError on anything it cannot read, so the caller can fall
    back to the converted sheet.
    """
    frames: list[tuple[int, int, bytes]] = []
    offset = 0
    while offset + 4 <= len(data):
        size = struct.unpack_from("<I", data, offset)[0]
        if size == 0xFFFFFFFF:
            break
        if size < 16 or offset + size > len(data):
            raise ValueError("frame %d: bad length %d" % (len(frames), size))
        width, height = struct.unpack_from("<HH", data, offset + 4)
        empty_lines = struct.unpack_from("<H", data, offset + 12)[0]
        if not 0 < width <= 4096 or not 0 < height <= 4096 \
                or empty_lines > height:
            raise ValueError("frame %d: bad %dx%d"
                             % (len(frames), width, height))
        end = offset + size
        pixels = bytearray(width * empty_lines)
        pos = offset + 16
        for _ in range(empty_lines, height):
            while pos < end and data[pos] == 0xFF:
                pos += 1
            if pos + 1 >= end:
                break
            transparent = data[pos]
            control = data[pos + 1]
            pos += 2
            if control in (0xFE, 0xFF):
                if pos >= end:
                    break
                count = data[pos]
                pos += 1
            else:
                count = control
            if transparent + count > width:
                raise ValueError("frame %d: run %d+%d over width %d"
                                 % (len(frames), transparent, count, width))
            pixels += bytes(transparent)
            pixels += data[pos:pos + count]
            pixels += bytes(width - transparent - count)
            pos += count
        if len(pixels) < width * height:
            pixels += bytes(width * height - len(pixels))
        frames.append((width, height, bytes(pixels[:width * height])))
        offset = end
    if not frames:
        raise ValueError("no frames")
    return frames


# ------------------------------------------------------------ .PIC images --
#
# THE OTHER HALF OF THE 1997 ART FORMAT, ported 2026-09-03. `.SPR` above
# is the sprite format; `.PIC` is the picture format, and until now this
# importer could only read a `.pic`'s PALETTE. It now decodes the image
# too, which is what the 57 enemy faces in `Faces/*.pic` needed.
#
# THE COMPRESSION IS LZW WRAPPED AROUND RLE, in that order on the way in,
# so LZW comes off first on the way out. Both layers are from JCivED by
# way of `mp_pic_tools/lzw.py` and `rle.py` (Provenance.md Tier 2); this
# is a rewrite for speed and for the standard library, not a copy — the
# reference serialises every dictionary entry to a `str` to key a `dict`,
# which a decoder does not need at all.
#
# THE LZW IS NOT THE TEXTBOOK ONE, and the three ways it differs are the
# whole difficulty:
#
#   1. CODES ARE PACKED LEAST-SIGNIFICANT-BIT FIRST, low byte first.
#   2. THE CODE WIDTH IS ON A FIXED SCHEDULE, not "grow when the table
#      fills". It starts at 9 bits; after 256 codes it becomes 10, after
#      512 more 11, after 1024 more it would be 12 — and 12 is past the
#      file's declared maximum (the `max_bits` byte in the image header,
#      always 11 in Magic's files), so instead the WHOLE THING RESETS:
#      width back to 9, dictionary back to empty. A decoder that grows on
#      table-full instead drifts one code out of step and produces noise.
#   3. THE DICTIONARY STARTS AT 257, NOT 256. Entry 256 exists and is
#      empty. That single off-by-one is the difference between a picture
#      and a smear, and it is why the reference's comment reads
#      "257... For some reason...".
#
# The two schedules are designed to coincide: 256 + 512 + 1024 = 1792
# codes per group, and a dictionary that starts at 257 fills at 2048
# after exactly 1791 additions — one per code after the first. So the
# width reset and the dictionary reset happen on the same code, and
# neither side has to tell the other.
#
# THE RLE IS TRIVIAL BY COMPARISON: `0x90` is the repeat marker, the byte
# after it is the run length INCLUDING the byte already emitted, and
# `0x90 0x00` is a literal `0x90`.
#
# VERIFIED AGAINST THE REFERENCE, byte for byte: all 57 `Faces/*.pic`,
# `Advfac64.pic`, `Face.pic` and `Pedstls.pic` decode to exactly the
# pixels `mp_pic_tools/pic2png.py` produces (2026-09-03), and the faces
# were then LOOKED AT on a contact sheet, which is the check no test
# replaces — a decoder one code out of step passes every assertion you
# would think to write and draws static.

## The LZW dictionary is empty below this and the code stream restarts.
LZW_FIRST_CODE = 0x0101
## PicV3's RLE repeat marker.
RLE_MARKER = 0x90


def _lzw_codes(data: bytes, max_bits: int) -> list[int]:
    """Packed bits -> LZW codes, on PicV3's fixed width schedule.

    See schedule note 2 in the block above: 9 bits for 256 codes, 10 for
    the next 512, 11 for the next 1024, then back to 9.
    """
    codes: list[int] = []
    bits = 0
    held = 0
    width = 9
    threshold = 0x100
    counter = 0
    for byte in data:
        bits |= byte << held
        held += 8
        while held >= width:
            codes.append(bits & ((1 << width) - 1))
            bits >>= width
            held -= width
            counter += 1
            if counter == threshold:
                counter = 0
                width += 1
                threshold <<= 1
                if width > max_bits:
                    width = 9
                    threshold = 0x100
    return codes


def _lzw_expand(codes: list[int], max_bits: int) -> bytes:
    """LZW codes -> bytes. The dictionary restarts with the code width."""
    limit = 1 << max_bits
    literals = [bytes([value]) for value in range(256)]
    out = bytearray()
    position = 0
    total = len(codes)
    while position < total:
        first = codes[position]
        if first > 255:
            raise ValueError("code %d starts a group but is not a literal"
                             % first)
        # Entry 256 exists and is empty; the next free slot is 257.
        table = literals + [b""]
        cursor = LZW_FIRST_CODE
        previous = literals[first]
        out += previous
        while cursor < limit and position < total - 1:
            position += 1
            code = codes[position]
            if code < cursor:
                entry = table[code]
            elif code == cursor:
                entry = previous + previous[:1]
            else:
                raise ValueError("code %d ahead of dictionary (%d)"
                                 % (code, cursor))
            out += entry
            table.append(previous + entry[:1])
            cursor += 1
            previous = entry
        position += 1
    return bytes(out)


def _rle_decode(data: bytes) -> bytes:
    """PicV3's RLE: `0x90 <count>` repeats, `0x90 0x00` is a literal."""
    if not data:
        return b""
    out = bytearray(data[:1])
    index = 1
    total = len(data)
    while index < total:
        byte = data[index]
        if byte != RLE_MARKER or index + 1 >= total:
            out.append(byte)
        elif data[index + 1] == 0:
            out.append(RLE_MARKER)
            index += 1
        else:
            count = data[index + 1]
            index += 1
            if count > 1:                  # the count includes out[-1]
                out += bytes([out[-1]]) * (count - 1)
        index += 1
    return bytes(out)


## Nothing the original shipped is anywhere near this on either axis; a
## header claiming more is a corrupt or misidentified file.
PIC_MAX_SIDE = 8192


def decode_pic(data: bytes) -> tuple[int, int, bytes, bytes | None]:
    """A PicV3 `.pic` -> `(width, height, palette indices, palette)`.

    The palette is 768 RGB bytes when the file carries an `M0`/`M1`
    block and None when it does not — the enemy faces do not, and take
    `DuelPalAll.tr` instead (see the ROGUES block).

    Short images are padded with index 255, which is what the reference
    does and what three files in a 1997 install need (`Cstline1.pic`,
    `Dungeon.pic`, `Magic.pic`). Raises ValueError on anything it cannot
    read, so every caller can report and carry on.
    """
    palette = None
    for tag, payload in iter_pic_blocks(data):
        if tag in (b"M0", b"M1"):
            first, last = payload[0], payload[1]
            table = bytearray(768)
            count = (last - first + 1) * 3
            table[first * 3:first * 3 + count] = payload[2:2 + count]
            palette = bytes(table)
        elif tag in (b"X0", b"X1"):
            width, height, max_bits = struct.unpack_from("<HHB", payload)
            max_bits = abs(max_bits)
            if not 0 < width <= PIC_MAX_SIDE or not 0 < height <= PIC_MAX_SIDE:
                raise ValueError("bad image size %dx%d" % (width, height))
            if not 9 <= max_bits <= 12:
                raise ValueError("bad LZW code width %d" % max_bits)
            pixels = _rle_decode(_lzw_expand(
                _lzw_codes(payload[5:], max_bits), max_bits))
            wanted = width * height
            if len(pixels) < wanted:
                pixels += bytes([255]) * (wanted - len(pixels))
            return width, height, pixels[:wanted], palette
        else:
            raise ValueError("PicV3 block %s is not implemented"
                             % tag.decode("ascii"))
    raise ValueError("no image block")


def split_image_mask(width: int, height: int,
                     indices: bytes) -> tuple[int, bytes, bytes]:
    """A `<image><mask>` picture -> `(half width, indices, alpha)`.

    The 1997 sheets that need transparency store it as a second image of
    the same size beside the first — `game/set_badges.gd` documents the
    same pairing for the badge strips. The mask half is binary, and its
    two values are 0 and 255.

    **THE POLARITY IS NOT A CONSTANT, so it is MEASURED.** Provenance.md
    says flatly that image/mask pairs disagree about which value means
    transparent, and these files prove it: every `Faces/*.pic` uses
    **255 = transparent**, while `Face.pic` in the same install uses
    **0 = transparent**. Hard-coding either one silently inverts half the
    art. What is true of both, and of any portrait, is that the OUTER
    EDGE of the picture is transparent — so whichever value holds the
    majority of the one-pixel border is the transparent one. A mask with
    only one value is taken as fully opaque.

    Raises ValueError if the halves are not a picture and a binary mask.
    """
    if width % 2:
        raise ValueError("odd width %d cannot split into image and mask"
                         % width)
    half = width // 2
    image = bytearray()
    mask = bytearray()
    for y in range(height):
        row = indices[y * width:(y + 1) * width]
        image += row[:half]
        mask += row[half:]
    values = set(mask)
    if len(values) > 2:
        raise ValueError("mask half has %d values, not a binary mask"
                         % len(values))
    if len(values) < 2:
        return half, bytes(image), bytes([255]) * len(image)
    border: dict[int, int] = {}
    for x in range(half):
        for y in (0, height - 1):
            value = mask[y * half + x]
            border[value] = border.get(value, 0) + 1
    for y in range(height):
        for x in (0, half - 1):
            value = mask[y * half + x]
            border[value] = border.get(value, 0) + 1
    clear = max(border, key=lambda value: border[value])
    alpha = bytes(0 if value == clear else 255 for value in mask)
    return half, bytes(image), alpha


def paint(indices: bytes, palette: bytes, alpha: bytes | None = None) -> bytes:
    """Palette indices -> RGBA.

    Without `alpha`, index 0 is the transparency — the `.SPR` convention.
    With it, the picture's own mask half decides and index 0 is a real
    colour, which it sometimes is: 020.pic has 55 opaque black pixels and
    054.pic has 219, and dropping them notches the outline.
    """
    out = bytearray(len(indices) * 4)
    for i, index in enumerate(indices):
        base = index * 3
        out[i * 4:i * 4 + 3] = palette[base:base + 3]
        out[i * 4 + 3] = (0 if index == 0 else 255) if alpha is None \
            else alpha[i]
    return bytes(out)


def _first_of(index: dict[str, Path], names: list[str]) -> Path | None:
    for name in names:
        path = index.get(name.lower())
        if path:
            return path
    return None


def _portraits_from_raw(index: dict[str, Path], out_dir: Path) -> int:
    """Cut the RAW `16faces.spr`. Returns how many faces were written.

    Zero means "could not"; every reason is printed and none of them is
    fatal, because a player whose install is missing the palette still
    has the converted sheet path below.
    """
    source = _first_of(index, PORTRAIT_SHEET_RAW)
    if source is None:
        return 0
    palette, origin = _resolve_palette(
        index, PORTRAIT_PALETTE_PIC + PORTRAIT_PALETTE_TR)
    if palette is None:
        print("\nportraits: found %s but no palette beside it (looked for"
              " %s); falling back to a converted sheet"
              % (source.name, origin))
        return 0
    try:
        frames = decode_spr(source.read_bytes())
    except (ValueError, OSError, struct.error) as err:
        print("\nportraits: %s is not a sprite file this can read (%s);"
              " falling back to a converted sheet" % (source, err))
        return 0

    out_dir.mkdir(parents=True, exist_ok=True)
    written = 0
    for i, (width, height, indices) in enumerate(frames):
        if (width, height) != PORTRAIT_CELL:
            continue                       # not a face; leave it alone
        write_png(out_dir / (portrait_name(i) + ".png"), width, height,
                  paint(indices, palette), alpha=True)
        written += 1
    if written == 0:
        print("\nportraits: %s decoded but holds no %dx%d frames"
              % (source.name, PORTRAIT_CELL[0], PORTRAIT_CELL[1]))
        return 0
    print("\nportraits: %d faces <- %s (palette: %s) -> %s"
          % (written, source, origin, out_dir))
    return written


def _portraits_from_sheet(index: dict[str, Path], out_dir: Path) -> int:
    """Cut s30's converted `16faces.spr.png`. Returns how many.

    NEEDS PILLOW, and says so rather than failing: this is the same policy
    the videos follow with their decoder. Reading an arbitrary PNG back is
    the one thing the standard library will not do, and a hand-rolled
    decoder for one sheet would be a worse trade than an optional
    dependency. The RAW path above needs no such thing.
    """
    source = _first_of(index, PORTRAIT_SHEET_PNG)
    if source is None:
        return 0
    try:
        from PIL import Image
    except ImportError:
        print("\nportraits: found %s but Pillow is not installed;"
              " `pip install pillow` and re-run to cut it" % source.name)
        return 0
    try:
        sheet = Image.open(source).convert("RGBA")
    except Exception as err:
        # A raw 1997 file whose name happens to end `.png` is not an
        # image any library reads. Say which file was refused instead of
        # ending the whole import in a traceback, which is what it did
        # the first time a real install was handed to it (2026-09-03).
        print("\nportraits: %s is not a readable image (%s);"
              " point --source at a converted sheet" % (source, err))
        return 0
    width, height = PORTRAIT_CELL
    count = sheet.width // width if sheet.height == height else 0
    if count == 0:
        print("\nportraits: %s is %dx%d, not a row of %dx%d cells"
              % (source.name, sheet.width, sheet.height, width, height))
        return 0

    out_dir.mkdir(parents=True, exist_ok=True)
    for i in range(count):
        cell = sheet.crop((i * width, 0, (i + 1) * width, height))
        cell.save(out_dir / (portrait_name(i) + ".png"))
    print("\nportraits: %d faces <- %s -> %s" % (count, source, out_dir))
    if count < len(PORTRAIT_NAMES):
        print("  this is a CONVERTED sheet and it is short: the 1997"
              " `16faces.spr` holds %d faces, this one %d. Point --source"
              " at your own install to get the rest."
              % (len(PORTRAIT_NAMES), count))
    return count


def _resolve_palette(index: dict[str, Path],
                     names: list[str]) -> tuple[bytes | None, str]:
    """First readable palette in `names`, and where it came from.

    The reader is chosen by extension, so a caller states its preference
    once, in order, and mixes the two kinds freely.
    """
    for name in names:
        path = index.get(name.lower())
        if path is None:
            continue
        palette = read_tr_palette(path) if name.lower().endswith(".tr") \
            else read_pic_palette(path)
        if palette is not None:
            return palette, path.name
    return None, ", ".join(names)


def _cut_masked_pic(path: Path, palette: bytes,
                    cell: tuple[int, int]) -> bytes | None:
    """One `<image><mask>` `.pic` -> RGBA, or None with a reason printed.

    NEVER RAISES. A player's install can hold a file this cannot read —
    a truncated copy, a later patch's replacement, or something that only
    shares the name — and one of those must not end the import. That
    guard is the same one the `.spr` path has carried since a real CD was
    first handed to this importer (2026-09-03).
    """
    try:
        width, height, indices, own = decode_pic(path.read_bytes())
        half, image, alpha = split_image_mask(width, height, indices)
    except (ValueError, IndexError, OSError, struct.error) as err:
        print("  skipped %s (%s)" % (path.name, err))
        return None
    if (half, height) != cell:
        print("  skipped %s (%dx%d, not %dx%d)"
              % (path.name, half, height, cell[0], cell[1]))
        return None
    return paint(image, own or palette, alpha)


def _rogues_from_raw(index: dict[str, Path], out_dir: Path) -> int:
    """Cut `Faces/000.pic`..`056.pic`. Returns how many were written.

    Slots 1-55 are written under their `@DECKFACES` names; the duplicate
    end-caps 0 and 56 are dropped, but only after being compared with
    what has already been written — see the ROGUES block. A slot that is
    NOT a duplicate is written under an index name rather than dropped,
    so an install that disagrees with this one loses nothing quietly.
    """
    found = {slot: index.get("%03d.pic" % slot) for slot in ROGUE_SLOTS}
    found = {slot: path for slot, path in found.items() if path}
    if not found:
        return 0
    palette, origin = _resolve_palette(index,
                                       ROGUE_PALETTE_TR + ROGUE_PALETTE_PIC)
    if palette is None:
        print("\nrogues: found %d enemy faces but no palette beside them"
              " (looked for %s); skipped" % (len(found), origin))
        return 0

    out_dir.mkdir(parents=True, exist_ok=True)
    written = 0
    seen: set[bytes] = set()
    # Named slots first, so an unnamed one can recognise itself as a copy
    # of a face that already has a name.
    order = sorted(found, key=lambda slot: (not 1 <= slot <= len(ROGUE_NAMES),
                                            slot))
    for slot in order:
        pixels = _cut_masked_pic(found[slot], palette, ROGUE_CELL)
        if pixels is None:
            continue
        named = 1 <= slot <= len(ROGUE_NAMES)
        if not named and pixels in seen:
            continue                       # the 000/056 end-caps
        seen.add(pixels)
        write_png(out_dir / (rogue_name(slot) + ".png"),
                  ROGUE_CELL[0], ROGUE_CELL[1], pixels, alpha=True)
        written += 1
        if not named:
            print("  %s has no @DECKFACES name; written by index as %s"
                  % (found[slot].name, rogue_name(slot) + ".png"))
    if written == 0:
        print("\nrogues: found %d enemy faces but none decoded" % len(found))
        return 0
    print("\nrogues: %d enemy faces <- %s (palette: %s) -> %s"
          % (written, found[order[0]].parent, origin, out_dir))
    return written


## THE FIFTEENTH PLAYER FACE. `Face.pic` (274x169 = 137 picture + 137
## mask, 1996-10-18) is what `Facemaker.exe` writes: the face the player
## is currently wearing, composed from the part layers in
## `Faceart/Fb1..Fb17.spr`. This install's copy is the one MicroProse
## shipped, and it is NOT any of the fourteen — it shares frame 7's body
## (Baba Bue's collar and jewels) under a different head, and differs
## from the closest sheet frame in 5 972 of 23 153 pixels. So it is a
## real face nobody has, and on a player's own install it is THEIR face.
## It is also the one file here whose mask reads 0 = transparent, which
## is why `split_image_mask` measures polarity instead of assuming it.
PLAYER_FACE_PIC: list[str] = ["face.pic"]
PLAYER_FACE_NAME = "facemaker_face"


def _player_face_from_pic(index: dict[str, Path], out_dir: Path) -> int:
    """Cut `Face.pic`, the Facemaker face. Returns 1 or 0."""
    source = _first_of(index, PLAYER_FACE_PIC)
    if source is None:
        return 0
    palette, origin = _resolve_palette(
        index, PORTRAIT_PALETTE_PIC + PORTRAIT_PALETTE_TR)
    if palette is None:
        return 0
    pixels = _cut_masked_pic(source, palette, PORTRAIT_CELL)
    if pixels is None:
        return 0
    out_dir.mkdir(parents=True, exist_ok=True)
    write_png(out_dir / (PLAYER_FACE_NAME + ".png"),
              PORTRAIT_CELL[0], PORTRAIT_CELL[1], pixels, alpha=True)
    print("\nportraits: 1 Facemaker face <- %s (palette: %s) -> %s"
          % (source, origin, out_dir))
    return 1


def import_portraits(index: dict[str, Path], dest: Path) -> None:
    """Write `<dest>/portraits/<name>.png`, one per face.

    THREE POOLS, and every one of them optional:

      * the fourteen PLAYER faces of `16faces.spr` (`@PLAYERNAMES`);
      * the fifty-five ROGUES of `Faces/*.pic` (`@DECKFACES`);
      * `Face.pic`, the Facemaker face — one more, and on a player's own
        install it is the one they made.

    THE RAW FILES COME FIRST and the converted sheet second, which is the
    opposite of every other step in this importer. Everywhere else a
    converted PNG is the only thing that can be read; here the 1997 files
    are readable with nothing but the standard library, they carry five
    faces the conversion lost, and they are the player's own copy rather
    than a third party's rendering of it. No path can fail the import:
    each reports and returns.
    """
    out_dir = dest / "portraits"
    written = _portraits_from_raw(index, out_dir)
    if written == 0:
        written = _portraits_from_sheet(index, out_dir)
    written += _player_face_from_pic(index, out_dir)
    written += _rogues_from_raw(index, out_dir)
    if written == 0:
        print("\nportraits: no face art found (skipped)")
        return
    print("\nportraits: %d in total -> %s" % (written, out_dir))


# --------------------------------------------------------- .pic screens --
#
# FULL-SCREEN 1997 PICTURES THIS CAN NOW DECODE, and one of them.
#
# The MANIFEST above COPIES files, so every one of its rows needs a PNG
# that somebody else already converted — which is why a run against a
# real 1997 install reports a dozen keys "skipped — these are RAW 1997
# files". With `decode_pic` in the file that stops being a hard limit.
# This table is the first row of the other kind: a raw `.pic` DECODED
# into the skin.
#
# `Advfac64.pic` (640x480, 1996-10-21) is the character-select backdrop —
# a stone floor and a framed MAGIC: The Gathering panel with the face
# tools ranged down the left edge. It carries its own `M0` palette, so it
# needs nothing beside it, and it is the screen `Pedstls.pic` and
# `16faces.spr` belong to.
#
# **NOTHING READS THIS KEY YET.** It is written so the art is there and
# proven decodable; wiring a screen to it is somebody else's change.
PIC_SCREENS: dict[str, list[str]] = {
    "character_select_background": ["Advfac64.pic"],
}


def import_pic_screens(index: dict[str, Path], dest: Path) -> None:
    """Decode each raw `.pic` screen into `<dest>/<key>.png`.

    Opaque RGB: these are backdrops, and none of them carries a mask.
    Like every other optional step, it reports and returns.
    """
    for key, candidates in PIC_SCREENS.items():
        source = _first_of(index, candidates)
        if source is None:
            continue
        try:
            width, height, indices, palette = decode_pic(source.read_bytes())
        except (ValueError, IndexError, OSError, struct.error) as err:
            print("\n%s: %s is not a .pic this can read (%s); skipped"
                  % (key, source.name, err))
            continue
        if palette is None:
            print("\n%s: %s carries no palette of its own; skipped"
                  % (key, source.name))
            continue
        rgb = bytearray(len(indices) * 3)
        for i, value in enumerate(indices):
            rgb[i * 3:i * 3 + 3] = palette[value * 3:value * 3 + 3]
        write_png(dest / (key + ".png"), width, height, bytes(rgb))
        print("\n%s: %dx%d <- %s -> %s"
              % (key, width, height, source, dest / (key + ".png")))


def build_index(sources: list[Path]) -> dict[str, Path]:
    """lowercase name -> path, keyed by the filename AND by every trailing
    piece of its directory path.

    `Duelsounds/Button.wav` under the source root is reachable as
    `button.wav`, as `duelsounds/button.wav`, and by its whole relative
    path. A bare name can never contain a `/`, so the key spaces cannot
    collide, and a MANIFEST candidate can therefore say WHICH copy it
    means.

    **SHALLOWEST WINS, AND THE WALK IS SORTED.** Both matter and both are
    bug fixes. `Path.rglob` yields in directory hash order, so which of
    the three `Button.wav` in a 1997 install answered to `button.wav` was
    a property of the machine's filesystem — the duel's click was the CD
    AutoPlay blip here and something else elsewhere. Sorting by DEPTH
    first makes `Duelsounds/Button.wav` beat
    `Program/DuelSounds/Button.wav` for the two-part key, whether the
    player points `--source` at the install or at the folder above it;
    sorting by path second makes the rest reproducible. See the note
    above MANIFEST.
    """
    index: dict[str, Path] = {}
    for source in sources:
        if not source.is_dir():
            print(f"warning: source '{source}' is not a directory, skipping")
            continue
        walk = sorted((p for p in source.rglob("*") if p.is_file()),
                      key=lambda p: (len(p.parts), str(p).lower()))
        for path in walk:
            index.setdefault(path.name.lower(), path)
            parts = path.relative_to(source).parts
            for depth in range(2, len(parts) + 1):
                index.setdefault("/".join(parts[-depth:]).lower(), path)
    return index


## Everything in the original's sound folders that this importer takes is
## a plain PCM `.wav`; nothing else in the MANIFEST is.
def is_sound_key(key: str) -> bool:
    return key.endswith(".wav")


def report_audio_dates(chosen: dict[str, Path]) -> None:
    """Say where each sound came from and WHEN the file is dated.

    THE POINT IS TO MAKE A PATCH VISIBLE. A previous pass imported an
    install's `Duelsounds/` believing it was 1997 material and had to put
    57 files back by hand. The dates were there to be read the whole
    time; nothing printed them. Now every run does, grouped by year, and
    anything later than 1997 is called what it is.

    Never fatal, never a prompt: it is the player's own copy of their own
    game and a patched install is the normal case — Manalink is how most
    surviving copies still run. This tells them what they have.
    """
    sounds = {k: v for k, v in chosen.items() if is_sound_key(k)}
    if not sounds:
        return
    by_year: dict[int, list[str]] = {}
    for key, path in sorted(sounds.items()):
        year = datetime.date.fromtimestamp(path.stat().st_mtime).year
        by_year.setdefault(year, []).append(key)
    print("\naudio: %d file(s), by the date on the file" % len(sounds))
    for year in sorted(by_year):
        keys = by_year[year]
        tag = "" if year <= 1997 else "   <- LATER THAN 1997, a patch"
        print("  %d: %3d file(s)%s" % (year, len(keys), tag))
    later = sorted(k for k, v in sounds.items()
                   if datetime.date.fromtimestamp(v.stat().st_mtime).year > 1997)
    if not later:
        return
    print("  Either your copy has been patched — Manalink and the 2009")
    print("  re-release both rewrite Duelsounds/ and Sound/ — or the source")
    print("  is a git checkout, which keeps no original dates at all. The")
    print("  sounds themselves are almost certainly the originals at a")
    print("  different mastering; see Provenance.md, \"The audio\". Imported")
    print("  either way: it is what your game plays.")
    print("  Example: %s <- %s" % (later[0], sounds[later[0]]))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--source", action="append", required=True,
                        help="directory to search (repeatable)")
    parser.add_argument("--dest",
                        default=str(Path(__file__).resolve().parent.parent
                                    / "assets" / "original"),
                        help="skin output directory")
    parser.add_argument("--no-videos", action="store_true",
                        help="skip the AVI transcoding step (see VIDEOS)")
    args = parser.parse_args()

    index = build_index([Path(s).expanduser() for s in args.source])
    dest = Path(args.dest).expanduser()
    dest.mkdir(parents=True, exist_ok=True)

    found, missing = 0, []
    # Raw `.pic` files whose names matched a texture key — reported at the
    # end so a player pointing this at their own CD is told WHY nothing
    # arrived, rather than getting a skin of undecodable files.
    skipped_raw: list[tuple[str, str]] = []
    # key -> the file it actually came from, so the audio step can report
    # dates without hunting for the source a second time.
    chosen: dict[str, Path] = {}
    for key, candidates in MANIFEST.items():
        source_path = None
        for name in candidates:
            source_path = index.get(name.lower())
            if source_path:
                break
        if source_path is None:
            missing.append(key)
            continue
        # Texture keys become <key>.png; font/sound keys keep extensions.
        out_name = key if key.endswith((".ttf", ".wav")) else key + ".png"
        # A TEXTURE KEY MUST BE HANDED A REAL PNG. This importer reads
        # CONVERTED trees (s30's `*.pic.png`), and a raw 1997 install has
        # files whose basenames match anyway — `Damage.pic`, `Dying.pic`,
        # the set icons. Copying one to `<key>.png` writes a file the game
        # cannot decode and the skin quietly breaks: on 2026-09-03 a run
        # against a real CD produced twelve of them, and the suite found it
        # as "Not a PNG file" rather than as anything about importing.
        if not out_name.endswith((".ttf", ".wav")) \
                and source_path.read_bytes()[:8] != b"\x89PNG\r\n\x1a\n":
            skipped_raw.append((key, source_path.name))
            continue
        shutil.copyfile(source_path, dest / out_name)
        print(f"  {key:24s} <- {source_path}")
        chosen[key] = source_path
        found += 1

    print(f"\nimported {found}/{len(MANIFEST)} skin assets -> {dest}")
    if skipped_raw:
        print("skipped — these are RAW 1997 files, not the converted PNGs")
        print("this step needs (s30's art tree carries those):")
        for key, name in skipped_raw:
            print(f"  - {key:22s} ({name})")
    if missing:
        print("missing (the clean fallback skin covers these):")
        for key in missing:
            print(f"  - {key}")
    report_audio_dates(chosen)

    # The movies come last because they are the only step that can need a
    # program the player does not have — see the VIDEOS block above. It
    # reports and returns; it never fails the import.
    if not args.no_videos:
        import_videos(index, dest)
    # The portraits are their own step for the same reason: sheets and
    # `.pic`s cut rather than copied, and skippable without failing the
    # import.
    import_portraits(index, dest)
    # Raw `.pic` screens, decoded rather than copied — see PIC_SCREENS.
    import_pic_screens(index, dest)
    return 0


if __name__ == "__main__":
    sys.exit(main())

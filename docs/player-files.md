# Where the game keeps your files

Everything the built game reads or writes that a player may touch, in one
place. Paths are as the game names them (`user://` and `res://`) and as
your file manager names them.

`user://` is **`~/.local/share/godot/app_userdata/Shandalar/`** on Linux
(`%APPDATA%\Godot\app_userdata\Shandalar\` on Windows,
`~/Library/Application Support/Godot/app_userdata/Shandalar/` on macOS).
It is the only place the game WRITES. Nothing is written beside the
executable, and nothing outside your home directory is touched.

`res://` is inside `Shandalar.pck`, the pack beside the executable. It is
read-only and the game ships everything it needs there — except art, which
is never shipped (see *The skin*).

*A note for anyone working in the source checkout:* a dev run of this
project has the same project name, so its `user://` is the same directory
— it reads and writes YOUR files. `run_tests.sh` and `duel_soak.sh`
therefore point `XDG_DATA_HOME` at a scratch directory of their own
(`SHANDALAR_TEST_DATA_HOME`) and cannot touch it; anything else run by
hand (`../tools/godot --path .`, `tools/screenshot_tour.tscn`) still can,
so give it the same treatment when it writes.

## What you can put there

| What | Where | Notes |
|---|---|---|
| **Your decks** | `user://decks/*.deck` | Everything the Deck Builder saves. Plain text, one `count name` per line; the format is `DeckLab/README.md`. Drop a `.deck` file in and it appears in the pickers under **User-created**. The Deck Builder writes **here and nowhere else** — the decks the game ships are never written over and never shadowed, so a deck of yours may not take one of their names (see below). |
| **Deck exports** | `user://decks/export/` | Where `Export` writes, so an export can never shadow a save. |
| **A deck anywhere else** | any path you point at | The Deck Builder's **Load** button lists the decks the game knows; its **From disk…** button opens a file browser onto the whole machine, for a `.deck`, a `.dec` or a 1997 `.dck` that lives somewhere else entirely — a real install's `Decks\` folder, a download, a friend's file. Nothing is copied into `user://decks/` by opening it: the deck lands on the surface and `Save deck` is still what writes a file of yours. A file that will not parse is refused in a window that says why. |
| **Your portraits** | `user://portraits/*.png` | The face you pick on the Magic Battle screen. PNG/JPG/WEBP, any size, ~120×150 reads best; the file name becomes the name (`grey_wizard.png` → "Grey Wizard"). The folder holds a `README.txt` saying exactly this — the game writes it the first time you open the setup screen. A file here **beats** an imported one of the same name. |
| **Your music** | `user://music/*.{wav,ogg,mp3}` | Your own soundtrack. Whole tracks, any length — the game plays one through and crossfades into the next, it never loops a fragment. Pick one, or shuffle everything, under **Options -> Music**. The file name becomes the name (`windswept_march.ogg` -> "Windswept March"), and a file named after one of the original's tracks (`music_duel`, `music_location_1`..`_19`, `music_location_0`, `music_temple`, `music_castle_white`/`_blue`/`_black`/`_red`/`_green`) **replaces** that one. The folder holds a `README.txt` saying exactly this — the game writes it the first time you open Options. |
| **The original graphics** | `user://original_skin/` | What `tools/import_original.py` takes out of YOUR copy of the 1997 game: panels, duelist faces, territory art, fonts, **sixty-five sounds** (thirty-eight duel effects and the **twenty-seven** music tracks — `Dueltune`, `LocMus0`..`19`, the Temple and the five castle themes), and `portraits/` — **seventy** faces, cut and decoded rather than copied. Those are the **fourteen** player faces of `16faces.spr` (the character-select pool, named for the `@PLAYERNAMES` entry each one seeds), the **fifty-five** enemy faces of `Faces/*.pic` (named for `@DECKFACES`, so `rogue_witch.png` → "Rogue Witch"), and `Face.pic`, the Facemaker face you are wearing. A converted sheet instead of the raw files yields only the first nine, and no enemies at all. Absent, the game draws its own clean skin and plays identically. |
| **Card art** | `user://original_skin/cardart/<snake_name>.jpg` | Scryfall art crops fetched by `tools/fetch_card_art.py`, or your own: `shivan_dragon.jpg`. Missing art is a graceful placeholder, never an error. |
| **Your settings** | `user://settings.cfg` | Options, rules forks, phase stops, territory background, chosen portraits, and the Deck Builder's own two sound switches (`deck_builder_music`, `deck_builder_sfx` — the boxes on its **Q**/**Esc** menu; they silence that screen only, and turning the game-wide Music or Sound Effects off still silences it whatever they say). Delete it to go back to the shipped defaults. A key that is ABSENT means its default applies — which is why a duel you have never changed the Stops in starts with the three red dots and leaves no `phase_stoppers` row behind, while clearing every Stop DOES write one, and why ticking a Deck Builder box back ON removes its row rather than writing `true`. A `phase_stoppers` row also carries a fifth number, the generation of the defaults it was a decision about: a row written by a build that shipped no defaults is a leftover rather than an opt-out, and the current defaults apply over it (`docs/ROADMAP.md`, "WHY THE THREE DOTS DID NOT REACH THE OWNER"). |
| **Logs** | `user://logs/` | Godot's own. Where a crash would show up. |
| **Screenshots** | `user://screenshot_<ms>.png` | What the duel screen's screenshot key writes. |

## What ships inside the pack (read-only)

| What | Where |
|---|---|
| The 317 shipped decks | `res://decks/` — starters at the top, then `1997/`, `tournament/`, `community/`, `extended_community/` (`docs/decks-1997.md`). **Read-only, and not shadowable either** — see below |
| Card data | `res://cards/data/*.json` (one per set), `dck_ids.txt` (the 1997 `.dck` id table), `sets.json` (set names, dates, sizes, the blurb a title-screen badge shows) |
| The card scripts | `res://cards/sets/<set>/*.gd` — one file per card, 897 of them |
| The game itself | `res://game/`, `res://engine/` |
| The one sound we ship | `res://game/deck_builder/stone_grind.wav` — the Deck Builder's filter-button grind, a quarter of a second of it. Every OTHER sound comes out of your own copy of the 1997 game (see *The skin*) |

**No art is in the pack.** `GameSkin` and `PortraitLibrary` read pictures
off the filesystem instead (`user://` first), which is what lets you add
your own after the game is built — and what keeps the 1997 files yours
rather than something this project redistributes.

## The game's own decks stay the game's own

You can open any of the 317 shipped decks in the Deck Builder, change it,
and duel with it. What you cannot do is save it back over itself, or save
it under its own name — because the 1997 manual says so, at p.148:

> *"If you load and change one of the creature decks used in the full
> game, you must save your version of the deck under a new name."*

So `Save deck` on one of them becomes a **save-as**: the game says which
deck it is, quotes that sentence, and offers you *"My Cleric"* with the
cursor in the box. Press OK and your version is written to
`user://decks/my_cleric.deck` as your own deck, under **User-created** in
every picker, while `res://decks/1997/originals/cleric.deck` stays exactly
as it shipped.

The name is refused whether it is the shipped **file** name or the shipped
**title**, and case and punctuation make no difference (`Cleric`,
`cleric` and `Cleric!` are one name) — otherwise the deck lists would hold
two decks called Cleric with no way to tell which one is the 1997
original. That is the whole reason for the rule: **provenance**.

Every door that writes obeys it — `Save deck`, the **Q**/**Esc** menu's
`Save current deck`, **Ctrl+S**, and the *"Do you wish to save…?"* prompt
on the way out, which is the one that runs a save on your behalf. `Delete`
refuses a shipped deck too. `Export` is the one exception and is not an
exception at all: it writes to `user://decks/export/`, which no picker
lists, so exporting the game's own Cleric as a `.dck` for the original
1997 program to open changes nothing here.

`Import deck` writes nothing — it puts a deck on the surface — but it now
asks *"Do you wish to save…?"* before it replaces what you were building,
which `Load` has always done and this door did not.

## Search order, when the same name exists twice

Portraits: `user://portraits/` → `user://original_skin/portraits/` →
`res://assets/original/portraits/` (a development checkout only).
Music: `user://music/` → `user://original_skin/` →
`res://assets/original/` — so a track of yours named after one of the
original's replaces it, exactly as a portrait does.
Skin art and card art: `user://original_skin/` → `res://assets/original/`.
Decks: the shipped folders and `user://decks` are listed together, with
the five starters always first. Nothing can collide here, because a deck
of yours may not take a shipped deck's name (above).

First match wins, so your own file always replaces an imported one.

## Filling it from your own copy of the 1997 game

```bash
python3 tools/import_original.py \
    --source "/path/to/your/Shandalar" \
    --dest "$HOME/.local/share/godot/app_userdata/Shandalar/original_skin"
```

Reports what it found and what it could not; every asset is optional. The
portrait step reads the raw 1997 files with nothing but the standard
library — `16faces.spr` for the fourteen player faces, `Faces/000.pic`
..`056.pic` for the fifty-five enemies, `Face.pic` for the Facemaker
face. Only its fallback — cutting a community-CONVERTED sheet, which is
nine faces rather than fourteen and no enemies — needs Pillow
(`pip install pillow`), and it says so instead of failing. A file it
cannot read is named and skipped; nothing about the import is fatal. In a
development checkout the default `--dest` is `assets/original/`, which is
gitignored for the same reason.

**In the chooser** the seventy sort into one alphabetical list, and the
fifty-five enemies carry a `rogue_` prefix so they stay together
("Rogue Aga Galneer" ... "Rogue Witch") instead of scattering through the
player names. `Rogue` is the original's own word for them — the 1998
expansion ships this art as `Exp1art/Rogues/Rogue01.pic`.

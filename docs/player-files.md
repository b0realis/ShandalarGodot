# Where the game keeps your files

Everything the built game reads or writes that a player may touch, in one
place. Paths are as the game names them (`user://` and `res://`) and as
your file manager names them.

`user://` is **`~/.local/share/godot/app_userdata/Shandalar/`** on Linux
(`%APPDATA%\Godot\app_userdata\Shandalar\` on Windows,
`~/Library/Application Support/Godot/app_userdata/Shandalar/` on macOS).
It is where the game WRITES, with one exception asked for by name: the
running duel log, `duel_log.txt`, is kept beside the executable so it is
where you look for it (and under `user://` instead when that directory
cannot be written). Draft and tournament saves can also use a folder you explicitly choose.

In configurable paths, `~` uses `HOME`, or `USERPROFILE` when `HOME` is
absent (a native Windows launch). If neither is known, the spelling is
left unchanged rather than turned into a root-relative path. In the browser,
prefer `user://` paths. A settings save that fails stays pending in memory
and is retried by the next save or options-screen flush; it is not durable
until a write succeeds, so resolve the storage problem before quitting.

On macOS, "beside the executable" means **beside `Shandalar.app`**:
`duel_log.txt` and the optional `skin/` folder live alongside the bundle.
They are never written inside its signed `Contents/` directory. The packaged
`Shandalar.pck` itself lives inside `Shandalar.app/Contents/Resources/`.

`res://` is inside `Shandalar.pck`, the pack beside the executable. It is
read-only and the game ships everything it needs there. Of ART it ships
exactly nine pictures, all of them this project's own (below); the 1997
material is never shipped and is read off your own copy at runtime (see
*The skin*).

*A note for anyone working in the source checkout:* a dev run of this
project has the same project name, so its `user://` is the same directory
— it reads and writes YOUR files. `run_tests.sh` and `duel_soak.sh`
therefore point `XDG_DATA_HOME` at a scratch directory of their own
(`SHANDALAR_TEST_DATA_HOME`) on Linux. On macOS, Godot ignores XDG; the
wrappers instead select a separate `Shandalar Pack Tests` profile using their
`shandalar_test` runtime feature. Anything else run by
hand (`../tools/godot --path .`, `tools/screenshot_tour.tscn`) still can,
so give it the same treatment when it writes.

## What you can put there

Release folders also contain `VERSION.txt`, generated from the game's
version when packaged. Keep it beside the executable: the Windows MCP
server reads it to identify Shandalar rather than the Godot engine. It is
release metadata, not a player setting, and the game does not write it.

| What | Where | Notes |
|---|---|---|
| **Your decks** | `user://decks/*.deck` | Everything the Deck Builder saves. Plain text, one `count name` per line; the format is `DeckLab/README.md`. Drop a `.deck` file in and it appears in the pickers under **User-created**. The Deck Builder writes **here and nowhere else** — the decks the game ships are never written over and never shadowed, so a deck of yours may not take one of their names (see below). |
| **Deck exports** | `user://decks/export/` | Where `Export` writes, so an export can never shadow a save. |
| **A deck anywhere else** | any path you point at | The Deck Builder's **Load → From disk…** and **Deck → Import deck → From a file…** open a `.txt`, `.deck`, `.dec` or 1997 `.dck` anywhere on disk. Nothing is copied into `user://decks/` by opening it: the deck lands on the surface and **Save deck** writes your own `.deck`. A file that will not parse is refused in a window that says why. |
| **Your portraits** | `user://portraits/*.png` | The face you pick on the Magic Battle screen. PNG/JPG/WEBP, any size, ~120×150 reads best; the file name becomes the name (`grey_wizard.png` → "Grey Wizard"). The folder holds a `README.txt` saying exactly this — the game writes it the first time you open the setup screen. A file here **beats** an imported one of the same name (and one of the sixteen the game ships), and a new name is **added** to the shipped and the 1997 faces in the chooser, not put in their place. **Options → Skin** shows the folder by its path with how many of yours are in it; the `portraits_folder` key moves it (below). |
| **Your music** | `user://music/*.{wav,ogg,mp3}` | Your own soundtrack. Whole tracks, any length — the game plays one through and crossfades into the next, it never loops a fragment. Pick one, or shuffle everything, under **Options -> Music**. The file name becomes the name (`windswept_march.ogg` -> "Windswept March"), and a file named after one of the original's tracks (`music_duel`, `music_location_1`..`_19`, `music_location_0`, `music_temple`, `music_castle_white`/`_blue`/`_black`/`_red`/`_green`) **replaces** that one. A new name is **added** to the original scores and played among them. The folder holds a `README.txt` saying exactly this — the game writes it the first time you open Options, whose **Skin** section shows the folder by its path with how many tracks of yours are in it; the `music_folder` key moves it (below). |
| **The skin folder** | `user://original_skin/` | The 1997 material as loose files — what `tools/import_original.py` takes out of YOUR copy of the 1997 game: panels, duelist faces, territory art, fonts, **sixty-five sounds** (thirty-eight duel effects and the **twenty-seven** music tracks — `Dueltune`, `LocMus0`..`19`, the Temple and the five castle themes), and `portraits/` — **seventy** faces, cut and decoded rather than copied. Those are the **fourteen** player faces of `16faces.spr` (the character-select pool, named for the `@PLAYERNAMES` entry each one seeds), the **fifty-five** enemy faces of `Faces/*.pic` (named for `@DECKFACES`, so `rogue_witch.png` → "Rogue Witch"), and `Face.pic`, the Facemaker face you are wearing. A converted sheet instead of the raw files yields only the first nine, and no enemies at all. Absent, the game draws its own clean skin and plays identically. A file here overrides the same file in the skin zip; with **Use the skin folder instead of the zip** ticked in **Options → Skin** the zip stays closed and this folder alone dresses the game. The screen shows the folder by its path; the `skin_folder` key moves it (below). |
| **Your skin zips** | `user://skins/*.zip` | The 1997 material as ONE ZIP — a `skin/` folder inside with everything the catalogue (`docs/skin-catalogue.txt`) lists — mounted in place at boot by `SkinPack` (`game/skin_pack.gd`) and read as `res://skin/...`; nothing is unpacked. A zip arrives through **Options → Skin → Choose...** (a file box) or by being dropped on the game's window (on the title screen the art shows at once; anywhere else the game offers a restart), is kept here **under its own name**, and the `skin_zip` key is written to name it as the one worn — the **Skin** row shows that path. With no key the game wears `original_skin.zip` here (what the browser build fetches once from beside the page), else the `skin/original_skin.zip` beside the executable — the release's own download (the game's zip carries no art), put there by hand. To go back to what shipped, delete the zip here (the row shows the path with your home folder as `~`); the browser build, with no folder to open, has a **Forget my zips** button that deletes every zip here and clears the key. A zip with an entry outside `skin/` is refused whole. A **tar.gz** (`.tgz`, or a plain `.tar`) at any of those doors is repacked ONCE into a zip of the same name here (`my_skin.tar.gz` → `skins/my_skin.zip`, by `game/tar_pack.gd`, a chunk per frame with the Skin section saying *Repacking…*) and worn as that zip; the tar itself is left where it was. Beside the executable the same: `skin/original_skin.tar.gz` where the zip would go is repacked into `skins/original_skin.zip` at the first start with no skin zip of yours (`SkinPack.repack_beside`), `skin/cardart.tar.gz` into the card folder. (The first two-zip build kept its zip in `user://skin/`; it is moved here at the next start.) |
| **The card folder** | `user://cardpacks/*.zip` | Ordinary art ZIPs contain `skin/cardart/<snake_name>.jpg\|png`; they are mounted at boot in name order, the first to hold a picture winning. Two exact gameplay packs are recognized: `Pack-1-DotP-complete.zip` (`1-tDotP`) completes the original sets; `Pack-2-Fallen-Empires.zip` (`2-FEM`) independently adds 102 unique cards. `CardPacks` validates versions, minimum game version, trusted metadata and artwork checksums. **Options → Card Packs** provides enabled state, rejection reasons, Open Folder and Rescan. With neither enabled there are 897 identities; Pack 1 alone has `1,270 set entries · 901 unique cards`; both have `1,372 set entries · 1,003 unique cards`. Deck Builder's **Extras** immediately left of **Stats** holds the Fallen Empires medallion; the original eight-set strip is unchanged. Saved decks declare required packs and offer to enable them on load, remaining name-based. Build these ZIPs locally with `tools/pack_1_dotp_complete.py` and `tools/pack_2_fallen_empires.py`; neither is a release payload. `cardpacks_folder` may move the folder; browser **Forget my zips** clears only the managed `user://` folder. |
| **Card art** | `user://original_skin/cardart/<snake_name>.jpg` | Loose Scryfall art crops fetched by `tools/fetch_card_art.py` (which `mtg_assets.py --from-cardart` zips into a card pack), or your own: `shivan_dragon.jpg`. Missing art is a graceful placeholder, never an error. |
| **Your settings** | `user://settings.cfg` | Options, rules forks, **the places above** — `skin_zip`, `use_skin_folder`, `skin_folder`, `cardpacks_folder`, `portraits_folder`, `music_folder` under `[options]` (`game/paths.gd`); an absolute path, `user://...`, or `~/...`; read at start, never written until you change one, and named on the Options → Skin screen — phase stops, territory background, chosen portraits, and the Deck Builder's own two sound switches (`deck_builder_music`, `deck_builder_sfx` — the boxes on its **Q**/**Esc** menu; they silence that screen only, and turning the game-wide Music or Sound Effects off still silences it whatever they say). Delete it to go back to the shipped defaults. A hand-edited file that no longer parses is never written over: it is copied to `settings.cfg.bad` (then `.bad2`, …) before the game saves again, and the message names both files (2026-10-03). A key that is ABSENT means its default applies — which is why a duel you have never changed the Stops in starts with the three red dots and leaves no `phase_stoppers` row behind, while clearing every Stop DOES write one, and why ticking a Deck Builder box back ON removes its row rather than writing `true`. A `phase_stoppers` row also carries a fifth number, the generation of the defaults it was a decision about: a row written by a build that shipped no defaults is a leftover rather than an opt-out, and the current defaults apply over it (`docs/ROADMAP.md`, "WHY THE THREE DOTS DID NOT REACH THE OWNER"). The `touch_controls` row (**Options -> Display -> Touch controls**) is `auto`, `on` or `off` — `auto`, the default and absent, turns the touch layer on only where there is a touchscreen or a mobile browser; `on` forces it for a touch laptop the engine did not report; `off` keeps a finger as the plain click Godot gives it. Anything else in the row reads as `auto`. |
| **Logs** | `user://logs/` | Godot's own. Where a crash would show up. |
| **The running duel log** | `duel_log.txt` beside the executable | Every duel, appended as it happens — the same lines the duel log window (`L`) shows, with `[Step]` markers and `Player 1 (name)` labels — each game under a `**********  GAME at <date time>  —  A vs B  (seed N)  **********` banner. Capped at 1 MB: past that the oldest game drops off the front. Under `user://` when the executable's directory is read-only, or when the editor runs the project. This is the file to attach to a bug report; the seed on its banner replays the duel. |
| **A saved duel log** | `user://duel_log_<ms>.txt` | What the duel log window's **Save** writes: one duel, on request. |
| **Screenshots** | `user://screenshot_<ms>.png` | What the duel screen's screenshot key writes. |

### Plain-text deck imports

In a `.txt` file, write one quantity and card name per line, such as
`4 Lightning Bolt`. The first blank line **after the main-deck cards start**
separates the sideboard; every subsequent card belongs to it. Leading blanks,
blank lines after a title but before the first card, and trailing blanks are
harmless. Whitespace-only lines count as blank, and Windows line endings work.
The same convention applies to **Import deck → Paste a decklist…**.

If any lines have explicit `SB:` prefixes, those markers take precedence:
only marked lines are sideboard and blank lines are formatting. Existing
`.deck` and `.dec` files still require `SB:`; `.dck` is unchanged. Comments
beginning `#` or `//` do not themselves start a sideboard. In a plain list
without `SB:`, do not separate main-deck categories with blank lines.

Unavailable cards remain visible as proxies and block gameplay until replaced
or implemented. Saving an imported list writes explicit sideboard markers, so
the split survives later loads. Ordinary `.txt` files are not automatically
indexed from the decks folder, keeping unrelated notes and ratings out of deck
pickers; open them explicitly, then save the deck.

### SGManalink display-name preference

The **Identity** window can remember a temporary display name on this device.
It writes only `sgmanalink_nickname` under `[options]` in `user://settings.cfg`,
and only when **Use this identity** is confirmed with **Remember** checked.
Confirming with Remember unchecked removes that key. This does not create a
verified account or reserve the name. Invitations, private keys and seat-resume
credentials are never saved there; closing SGManalink forgets the temporary seat.

SGManalink's duel history is audience-filtered and kept in memory, with bounded
host catch-up on reconnect. Unlike offline duels, it is not automatically appended
to the running `duel_log.txt` (the raw referee log can contain hidden information).
The normal log window's **Save** button explicitly saves only your received history
to `user://duel_log_<ms>.txt`. Such a saved log can include private looks that card
rules authorized for your seat; consider that before sharing it.

### Private LAN tournament progress

The organiser's checkpoints live in **`user://tournaments/`**, or the folder
selected in **Tournament setup → Save folder** (the optional
`tournaments_folder` settings key). Browse, type a path or restore Default;
the saved-event list follows the chosen folder. Existing saves are not moved
and the path is never sent to other players. Each tournament has
a random filename ending in `.json`, with a last-good `.json.bak` backup; a
`.json.tmp` may remain after an interrupted write. **Keep these files private:**
they contain registered decklists, names, the welcome message, pairings, scores and recovery-code
hashes. They contain no live hands, library order, duel seeds, TLS private keys,
invitations or plaintext recovery codes. Nothing is uploaded.

Players can explicitly copy their own recovery code from the Tournament Hall
and save it privately. The game does not put plaintext codes in settings or
logs; clipboard history may retain a copied code. Reopening an application
requires the current host invitation and this code to recover the entry.
Restoring a tournament on the host preserves completed scores but restarts
interrupted games. Use the same build for checkpoint recovery. A pairing the
organiser ruled on keeps its flag (`Organiser's ruling` or `Corrected by
organiser`) in the checkpoint; the organiser's pause is not saved, so a
restarted host resumes play.
Tournament welcome support uses protocol 11. Earlier protocol-8/9/10 checkpoints are
not migrated or deleted; they require their original compatible build to recover.
Computer entries also save their level, separate Unfair flag, pace and deck;
their seats are recreated without issuing player recovery codes.

### Booster Draft decks and dealt pools

**Options → Booster Draft** saves to `user://decks` by default, or an explicitly
chosen `drafts_folder`. Each session creates a unique `draft-….deck` plus a
`draft-….pool.json` receipt of all dealt cards. Recovery writes use `.pending`
files; successful writes replace them. `draft_pool_cards` and `draft_options`
remember eligibility and launch settings in `settings.cfg`. No directory is
created and no default key is written merely by opening setup.

Desktop results can open the save folder. Web keeps the files in browser storage
and offers Download deck/Download pool for external copies. See
[Booster Draft](booster-draft.md) for timer, pack and recovery behavior.
The pool receipt is written before building. **Verify saved deck…** in draft
setup compares main deck plus sideboard quantities against an original receipt,
without changing either file. Organisers should keep that original themselves;
player-editable files are not tamper-proof.
New draft decks also carry `# draft-…` comments with a seed, pack settings,
fingerprint and complete replay recipe. **Reconstruct deck** regenerates all
packs from the deck alone; a judge can compare a separately retained pre-draft
fingerprint. The pool receipt contains that same commitment before construction.
Native load/save/copy preserves the comments. Older drafts remain membership-only.

## What ships inside the pack (read-only)

| What | Where |
|---|---|
| The 317 shipped decks | `res://decks/` — starters at the top, then `1997/`, `tournament/`, `community/`, `extended_community/` (`docs/decks-1997.md`). **Read-only, and not shadowable either** — see below |
| Card data | `res://cards/data/*.json` (one per set), `dck_ids.txt` (the 1997 `.dck` id table), `sets.json` (set names, dates, sizes, the blurb a title-screen badge shows) |
| The card scripts | `res://cards/sets/<set>/*.gd` — one file per default card, 897 of them; `res://cards/optional/pack_1/*.gd` — four trusted dormant implementations; `res://cards/sets/fem/*.gd` — 102 dormant Fallen Empires implementations. These scripts ship with the game, never inside an external pack ZIP. |
| The game itself | `res://game/`, `res://engine/` |
| The one sound we ship | `res://game/deck_builder/stone_grind.wav` — the Deck Builder's filter-button grind, a quarter of a second of it. **Ours**, under this project's own GPL-3.0: it is generated, not recorded. Every OTHER sound comes out of your own copy of the 1997 game (see *The skin*) |
| The pictures we ship | `res://game/art/` — the set symbols (`set_icon_*.png`), the filter medallions, the damage dagger (`damage_marker.png`), drawn from scratch by `tools/draw_our_art.gd`, and the Manalink mark (`manalink_globe.png`), the owner's own picture; plus `res://game/icon.png` (the window icon) and `res://game/boot_splash.png` (the loading picture). **Every one of them is ours**, under this project's own GPL-3.0 — no 1997 file and no reimplementation's redrawing of one is here. `game/art/README.md` lists each with its SHA-256 |

**No art of the 1997 game is in the pack, and none of anybody else's
redrawing of it either.** `GameSkin` and `PortraitLibrary` read pictures
off the filesystem instead (`user://` first), which is what lets you add
your own after the game is built — and what keeps the 1997 files yours
rather than something this project redistributes.

The nine pictures above are the exception that proves it, and they are
the FLOOR rather than the ceiling: they are what a set symbol and a
wounded creature's dagger look like when you have imported nothing, and
the moment your skin supplies `set_icon_<code>.png` or `damage_marker.png`
the loader takes yours instead, one file at a time, exactly as it does
for every other key in the catalogue (`GameSkin.our_art` is checked LAST,
after every skin directory). A skin that leaves those keys out is not
missing anything: it simply keeps the drawn ones.

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
`<game>/skin/portraits/` → the mounted zip's `skin/portraits/` →
`res://assets/original/portraits/` (a development checkout only) → the
sixteen faces the game ships (`game/art/portraits/`, inside the pack —
last, so anything of yours or of the 1997 game's wins over them).
Music: `user://music/` → `user://original_skin/` → `<game>/skin/` → the
mounted zip's → `res://assets/original/` — so a track of yours named
after one of the original's replaces it, exactly as a portrait does.
Skin art and card art: `user://original_skin/` → `<game>/skin/` (loose
files beside the executable) → the mounted zips (`res://skin/`, your own
mounted before the shipped ones, `original_skin.zip` before
`cardart.zip`) → `res://assets/original/`.
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

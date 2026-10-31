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
only pictures this project drew itself (each listed with its SHA-256 in
`game/art/README.md`); the 1997 material is never shipped and is read off
your own copy at runtime (see *The skin*).

*A note for anyone working in the source checkout:* a dev run of this
project has the same project name, so its `user://` is the same directory
— it reads and writes YOUR files. `run_tests.sh` and `duel_soak.sh`
therefore point `XDG_DATA_HOME` at a scratch directory of their own
(`SHANDALAR_TEST_DATA_HOME`) on Linux. On macOS, Godot ignores XDG; the
wrappers instead select a separate `Shandalar Integration Tests` profile using their
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
| **Your card back** | `user://card_back.png` | The picture on the back of every card: the library, a face-down card, the hand a hot-seat duel hides, the big card's empty slot. **Options → Card back → Choose...** takes a **PNG, JPG or WEBP**, upright, and keeps the game's own copy here at **456 × 646 pixels**, the shape of a card and twice the 1997 back's 228 × 323, so that is the size to make one at. A picture of a card's shape, or a hair off it like a 63 × 88 mm scan, is used whole; any other shape is trimmed from the middle to fit (a landscape photo loses its sides, a tall one its top and bottom), a bigger picture is shrunk and a smaller one stretched, which softens it. A phone photo is turned the way it was held. An iPhone's HEIC photo is not read; save it as a JPG first. The copy is written whole beside the old one and only then takes its place, so a full disk or a crash part-way leaves the old back (2026-10-21). The picture you chose is not touched, and **Remove** deletes only this copy, after which the skin's back is worn again. You can also put a picture here yourself as `card_back.png` (or `.jpg`, `.jpeg`, `.webp`); the game fits it the same way when it starts. On the Meta Quest it is `/sdcard/Android/data/com.b0realis.shandalar/files/card_back.png`. Your picture is worn over the skin's back. |
| **Your music** | `user://music/*.{wav,ogg,mp3}` | Your own soundtrack. Whole tracks, any length — the game plays one through and crossfades into the next, it never loops a fragment. Pick one, or shuffle everything, under **Options -> Music**. The file name becomes the name (`windswept_march.ogg` -> "Windswept March"), and a file named after one of the original's tracks (`music_duel`, `music_location_1`..`_19`, `music_location_0`, `music_temple`, `music_castle_white`/`_blue`/`_black`/`_red`/`_green`) **replaces** that one. A new name is **added** to the original scores and played among them. The folder holds a `README.txt` saying exactly this — the game writes it the first time you open Options, whose **Skin** section shows the folder by its path with how many tracks of yours are in it; the `music_folder` key moves it (below). |
| **The skin folder** | `user://original_skin/` | The 1997 material as loose files — what `tools/import_original.py` takes out of YOUR copy of the 1997 game: panels, duelist faces, territory art, the title font, **sixty-six sounds** (thirty-nine duel effects and the **twenty-seven** music tracks — `Dueltune`, `LocMus0`..`19`, the Temple and the five castle themes), and `portraits/` — **seventy** faces, cut and decoded rather than copied. Those are the **fourteen** player faces of `16faces.spr` (the character-select pool, named for the `@PLAYERNAMES` entry each one seeds), the **fifty-five** enemy faces of `Faces/*.pic` (named for `@DECKFACES`, so `rogue_witch.png` → "Rogue Witch"), and `Face.pic`, the Facemaker face you are wearing. It needs only your own copy of the 1997 game: nothing from a later re-release or another project is read — unless you have no 1997 copy and ask for a Manalink install with `--manalink`, a backup in the tool that takes Manalink's own files where they fit the shape the game draws; a folder it filled carries `from_manalink.txt`, listing those files, and is yours alone — no release carries a Manalink skin. `--check` lists every asset and where it would come from, and writes nothing; `tools/upscale_skin.py` makes a second, hi-res skin of it (`original_skin_realesrgan-anime_2x.zip`, or `--out` into another folder): the same files under the same names, every picture at twice the size, chosen like any skin; a skin's `catalogue.txt` may say which of its files stands in which place, and a `<name>@2x.png` beside a picture (0.50.28's copies) is still worn in its place; `SKIN.csv` beside the game (`docs/skin-catalogue.csv`) lists every file a complete skin holds, by name. Absent, the game draws its own clean skin and plays identically. One skin is worn: while a skin zip is, this folder is not read (until 0.50.30 a file here overrode the same file in the zip); with **Use the skin folder instead of the zip** ticked in **Options → Skin** the zip stays closed and this folder alone dresses the game. The screen shows the folder by its path; the `skin_folder` key moves it (below). |
| **Your skin zips** | `user://skins/*.zip` | The 1997 material as ONE ZIP — a `skin/` folder inside with everything the catalogue (`docs/skin-catalogue.txt`) lists — mounted in place at boot by `SkinPack` (`game/skin_pack.gd`) and read as `res://skin/...`; nothing is unpacked. A zip arrives through **Options → Skin → Choose...** (a file box) or by being dropped on the game's window (on the title screen the art shows at once; anywhere else the game offers a restart), is kept here **under its own name** — written whole beside the zip it replaces and only then renamed over it, so a copy that fails part-way leaves the old zip working (2026-10-21) — and the `skin_zip` key is written to name it as the one worn — the **Skin** row shows that path. With no key the game wears `original_skin.zip` here (what the browser build fetches once from beside the page), else the `skin/original_skin.zip` beside the executable — the release's own download (the game's zip carries no art), put there by hand. To go back to what shipped, delete the zip here (the row shows the path with your home folder as `~`); the browser build, with no folder to open, has a **Forget my zips** button that deletes every zip here and clears the key. A zip with an entry outside `skin/` is refused whole. A **tar.gz** (`.tgz`, or a plain `.tar`) at any of those doors is repacked ONCE into a zip of the same name here (`my_skin.tar.gz` → `skins/my_skin.zip`, by `game/tar_pack.gd`, a chunk per frame with the Skin section saying *Repacking…*) and worn as that zip; the tar itself is left where it was. Beside the executable the same: `skin/original_skin.tar.gz` where the zip would go is repacked into `skins/original_skin.zip` at the first start with no skin zip of yours (`SkinPack.repack_beside`), `skin/cardart.tar.gz` into the card folder. (The first two-zip build kept its zip in `user://skin/`; it is moved here at the next start.) A chosen zip is copied here a piece a frame, the Skin section saying *Copying… N%*; it is worn from the next start — "Restart now" is offered on the title and in Options only (on a handheld: "Quit and start again"), and the restart keeps the options the game was started with. Choosing the shipped `skin/original_skin.zip` beside the game again copies nothing: it is worn where it is, and your own copies (`skins/original_skin.zip`, the zip the `skin_zip` key named) are removed — at once, or at the next start when worn this run, listed meanwhile in `skins/retired.txt`. (0.60.0) |
| **The card folder** | `user://cardpacks/*.zip` | Ordinary art ZIPs contain `skin/cardart/<snake_name>.jpg\|png`; they are mounted at boot in name order, the first to hold a picture winning. Nine exact gameplay packs are recognized, from `Pack-1-DotP-complete.zip` (`1-tDotP`), which completes the original sets, to `Pack-9-Tempest-Block.zip` (`9-TMP`); [card-art-and-packs.md](card-art-and-packs.md) gives every exact name. `CardPacks` validates versions, minimum game version, trusted metadata and artwork checksums. **Options → Card Packs** provides enabled state, rejection reasons, Open Folder, Rescan and **Add pack...** (2026-10-21; not in the browser), which takes a numbered pack ZIP from anywhere, recognises it by what it holds rather than its name, checks it in `user://cardpack_incoming/` with its pack's own contract and only then copies it here, whole, under its exact name — a refused ZIP never replaces a pack that works. With none enabled there are 897 identities; Pack 1 alone has `1,270 set entries · 901 unique cards`; all nine have `4,083 set entries · 3,093 unique cards`. The Deck Builder's **Extras**, immediately left of **Stats**, opens a window with a medallion for the 1997 originals, Pack 1 and each pack's sets, live for every enabled pack; the original eight-set strip is unchanged. Saved decks declare required packs and offer to enable them on load, remaining name-based. Build these ZIPs locally with the `tools/pack_N_*.py` builders; none is a release payload. `cardpacks_folder` may move the folder; browser **Forget my zips** clears only the managed `user://` folder. |
| **Card art** | `user://original_skin/cardart/<snake_name>.jpg` | Loose Scryfall art crops fetched by `tools/fetch_card_art.py` (which `mtg_assets.py --from-cardart` zips into a card pack), or your own: `shivan_dragon.jpg`. Missing art is a graceful placeholder, never an error. |
| **Your settings** | `user://settings.cfg` | Options, rules forks, **the places above** — `skin_zip`, `use_skin_folder`, `skin_folder`, `cardpacks_folder`, `portraits_folder`, `music_folder` under `[options]` (`game/paths.gd`); an absolute path, `user://...`, or `~/...`; read at start, never written until you change one, and named on the Options → Skin screen — phase stops, territory background, the Situation Bar's frame (`bar_frame`: `shandalargodot`, the default and absent, `classic`, `classic_pale` or `classic_thin`; anything else reads as the default), chosen portraits, Magic Battle's **Test hands** (`test_hands_last`, the test the bench opens on, written when **Go test!** is pressed; `test_hands_saved`, the tests you saved by name, written by **Save** and **Delete**), the duel screen's own options (`duel_log_targets`, `duel_colorblind_mana`, `duel_ui_scale`, `duel_attack_all_key` — Duel Screen Options, the button under the large card, 0.50.65), the world's Creature names switch (`world_creature_names`), and the Deck Builder's own two sound switches (`deck_builder_music`, `deck_builder_sfx` — the boxes on its **Q**/**Esc** menu; they silence that screen only, and turning the game-wide Music or Sound Effects off still silences it whatever they say). Delete it to go back to the shipped defaults. A hand-edited file that no longer parses is never written over: it is copied to `settings.cfg.bad` (then `.bad2`, …) before the game saves again, and the message names both files (2026-10-03). A value of the wrong kind reads as meant where it can (yes/no/on/off/true/false/1/0 for a switch, a number in quotes for a number) and as the default where it cannot; a file kept aside, one that could not be read, or a save that failed is shown once on the title screen and as a line at the top of Options; a settings.cfg or deck that is a link is written where the link points, a read-only one is left alone and the refusal is shown, and a rewritten file keeps its permissions; two copies of the game on one profile no longer undo each other's options (2026-10-12). The same holds inside lists and tables (2026-10-21): an entry of `enabled_card_packs` or `sealed_sets` that is not text is skipped, a saved test whose name is a number keeps it as its digits, and a Deck Builder Extras switch reads yes/no/on/off as meant. A key that is ABSENT means its default applies — which is why a duel you have never changed the Stops in starts with the three red dots and leaves no `phase_stoppers` row behind, while clearing every Stop DOES write one, and why ticking a Deck Builder box back ON removes its row rather than writing `true`. A `phase_stoppers` row also carries a fifth number, the generation of the defaults it was a decision about: a row written by a build that shipped no defaults is a leftover rather than an opt-out, and the current defaults apply over it (`docs/ROADMAP.md`, "WHY THE THREE DOTS DID NOT REACH THE OWNER"). The `touch_controls` row (**Options -> Display -> Touch controls**) is `auto`, `on` or `off` — `auto`, the default and absent, turns the touch layer on only where there is a touchscreen or a mobile browser; `on` forces it for a touch laptop the engine did not report; `off` keeps a finger as the plain click Godot gives it. Anything else in the row reads as `auto`. |
| **Logs** | `user://logs/` | Godot's own. Where a crash would show up. |
| **The running duel log** | `duel_log.txt` beside the executable | Every duel but a **Test hands** test (its log stays in the log window, whose **Save** keeps it), appended as it happens — the same lines the duel log window (`L`) shows, with `[Step]` markers and `Player 1 (name)` labels — each game under a `**********  GAME at <date time>  —  A vs B  (seed N)  **********` banner. Capped at 1 MB: past that the oldest game drops off the front, the trimmed file written whole beside the old one and swapped in, so a crash or a full disk never leaves it cut. Under `user://` when the executable's directory is read-only, or when the editor runs the project. This is the file to attach to a bug report; the seed on its banner replays the duel. |
| **A saved duel log** | `user://duel_log_<ms>.txt` | What the duel log window's **Save** writes: one duel, on request. |
| **Public game records (MPN)** | `user://records/*.mpn` | Local duels and the LAN host keep a separate public-only archive here; **Test hands** and automated tests do not. The `records_folder` key under `[options]` can move this folder. **Export MPN** in the result popup saves a copy wherever you choose (a download in the browser); either LAN player can export before leaving the finished table. **Options → View past-played games** opens an MPN file in the history viewer, with **Watch duel** for graphical playback. See [the MPN guide](mpn-v0.1.md). |
| **Your adventures** | `user://adventures/<id>.autosave.json`, `<id>.quickslot.json`, `<id>.slot01.json` … `<id>.slot10.json` | The Shandalar adventures: each one's autosave (written when its world is made and whenever you leave a place), the separate blue **Quickslot** written by **Ctrl+S**, and the ten named slots **Save** fills. Each has a `.bak` of its last good version beside it. Quickslot never overwrites an autosave or a named slot. A save is written whole beside the old one and only then takes its place, and it is read field by field, so one damaged field costs that field and not the adventure. **Load** lists them; **Resume** opens the highlighted save. Delete an adventure's files to forget it. Saves are written in the save format's version 3 (since 0.50.65): an older game lists them as saved by a newer version and never writes over them. |
| **The Hall of Fame** | `user://hall_of_fame.json` | Every adventure won, best score first: the hero's name, color, difficulty, score, days and the date (at most 100 lines; one per adventure, its better score kept). It also remembers which **One life** adventures have begun their final battle, so an older save of one cannot try it again. Written whole beside the old file and only then put in its place; a file that no longer reads is kept aside as `hall_of_fame.json.bad` (then `.bad2`) and never written over, and the Hall of Fame says it could not be read. |
| **A saved match / Gauntlet run** | `user://saved_match.json`, `user://saved_gauntlet.json` | A best-of match from Magic Battle (not an AI Demo) and a Gauntlet run, each saved the moment each duel ends (never during one). Resume match on Magic Battle and the Gauntlet's own window take them up again. A finished one removes its file; a new one replaces it once it has been saved. Written whole beside the old file; a file that no longer reads is kept aside as `.bad` (then `.bad2`) and never written over. |
| **Screenshots** | `user://screenshot_<ms>.png` | What the duel screen's screenshot key writes. |

### Plain-text deck imports

In a `.txt` file, write one quantity and card name per line, such as
`4 Lightning Bolt`. The first blank line **after the main-deck cards start**
separates the sideboard; every subsequent card belongs to it. Leading blanks,
blank lines after a title but before the first card, and trailing blanks are
harmless. Whitespace-only lines count as blank, and Windows line endings work.
The same convention applies to **Import deck → Paste a decklist…**, which
also reads other programs' exports: MTG Arena (`Deck`/`Sideboard`,
`4 Lightning Bolt (M10) 146`), Moxfield/MTGO (`SIDEBOARD:`) and Forge `.dck`
(`[Main]`, `Name=`, `4 Lightning Bolt|M10`) (2026-10-12).

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
A checkpoint belongs to the build that wrote it: it carries that build's
compatibility fingerprint (game version, LAN protocol, rules revision and
the card catalogue its enabled packs make). One written by any other build,
or with other packs enabled, is refused — never migrated or deleted; recover
it with the build and packs that wrote it.
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
| The shipped decks | `res://decks/` — starters at the top, then `1997/`, `tournament/`, `community/`, `extended_community/`, `portal/`, `portal_second_age/`, `variants/` (`docs/decks-1997.md`; `packaging/bundled_decks.txt` lists every file). **Read-only, and not shadowable either** — see below |
| Card data | `res://cards/data/*.json` (one per set), `dck_ids.txt` (the 1997 `.dck` id table), `sets.json` (set names, dates, sizes, the blurb a title-screen badge shows) |
| The card scripts | `res://cards/sets/<set>/*.gd` — one file per default card, 897 of them; `res://cards/optional/pack_1/*.gd` — four trusted dormant implementations; `res://cards/sets/<code>/*.gd` for the numbered packs' sets (fem, ice, hml, all, por, p02, mir, vis, wth, tmp, sth, exo; Pack 7, Fifth Edition, is all reprints and brings no scripts of its own) — dormant until that pack is enabled. These scripts ship with the game, never inside an external pack ZIP. |
| The game itself | `res://game/`, `res://engine/` |
| The one sound we ship | `res://game/deck_builder/stone_grind.wav` — the Deck Builder's filter-button grind, a quarter of a second of it. **Ours**, under this project's own GPL-3.0: it is generated, not recorded. Every OTHER sound comes out of your own copy of the 1997 game (see *The skin*) |
| The pictures we ship | `res://game/art/` — the set symbols (`set_icon_*.png`), the filter medallions, the damage dagger (`damage_marker.png`), drawn from scratch by `tools/draw_our_art.gd`, and the Manalink mark (`manalink_globe.png`), the owner's own picture; plus `res://game/icon.png` (the window icon) and `res://game/boot_splash.png` (the loading picture). **Every one of them is ours**, under this project's own GPL-3.0 — no 1997 file and no reimplementation's redrawing of one is here. `game/art/README.md` lists each with its SHA-256 |

**No art of the 1997 game is in the pack, and none of anybody else's
redrawing of it either.** `GameSkin` and `PortraitLibrary` read pictures
off the filesystem instead (`user://` first), which is what lets you add
your own after the game is built — and what keeps the 1997 files yours
rather than something this project redistributes.

The pictures above are the exception that proves it, and since
2026-10-15 they are what EVERY player sees, skin or no skin: a set
symbol, a wounded creature's dagger and the text face are always the
game's own, and a skin's `set_icon_<code>.png`, `damage_marker.png` or
`font_body.ttf` is not read (`GameSkin.set_icon`, `MiniCard.ALWAYS_OURS`,
`GameSkin.font`). Every other key in the catalogue is still your skin's
when it has one. A skin that leaves those three out is not missing
anything.

## The game's own decks stay the game's own

You can open any of the shipped decks in the Deck Builder, change it,
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
face. A file it cannot read is named and skipped; nothing about the import is fatal. In a
development checkout the default `--dest` is `assets/original/`, which is
gitignored for the same reason.

**In the chooser** the seventy sort into one alphabetical list, and the
fifty-five enemies carry a `rogue_` prefix so they stay together
("Rogue Aga Galneer" ... "Rogue Witch") instead of scattering through the
player names. `Rogue` is the original's own word for them — the 1998
expansion ships this art as `Exp1art/Rogues/Rogue01.pic`.

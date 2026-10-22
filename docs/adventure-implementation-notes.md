# Adventure mode — implementation notes (M5)

**Started 2026-10-04.** These are living notes for the future adventure mode:
the Shandalar overworld, towns, enemies, dungeons, castles, world magics and
Arzakon. Nothing is built yet. The ROADMAP's M5 entry says the milestone
"gets its own design doc before code", and this is where that design doc
grows. Add findings as they come, with sources, and log them at the bottom.

Companion: [`world-builder-adventure-notes.md`](world-builder-adventure-notes.md),
on how the 1997 game generated its world (a new one every game).

## Ground rules

- **Fidelity labels,** as in `tier2-plan.md`: **[1997]** means the original
  did it; **[s30]** means the 30th-anniversary remake added it; **[QoL]**
  means it is ours.
- **Our own implementation, from the decompilation (owner ruling,
  2026-10-04):** "We will use s30 only as a guide and reimplement our own
  from decompilation and we will introduce our own QoL!"
  - *What the game does:* first **the matching decompilation of version
    1.3**, the game with MicroProse's patches
    (https://github.com/rlerrr/shandalar-decomp). Its adventure is
    `src/shandalar/`, with human-assigned names, and it recompiles to about
    90% of the original machine code. Then the decompilation of the 1997
    retail release (https://github.com/benprew/microprose-shandalar-source,
    "Tier 2"), to cross-check and to see what the patches changed. Then the
    original data files (`../shandalar-src/Program/`, `Advstrings.txt`),
    then the manual, the 1997 FAQ and dos486.com.
  - *s30 is a guide only:* read it to see how a modern remake solved a
    screen or a system, and to compare. **No s30 code is translated into
    this project.** This also keeps s30's GPL-2.0 out of our GPL-3.0 tree.
    The duel-era "lean on s30" rule does not apply to the adventure.
  - *Our own improvements* are welcome and labelled **[QoL]**. Where one
    changes 1997 behaviour, the 1997 behaviour is written down beside it.
- **The decompilations:** neither has a licence. Cite addresses, quote short
  excerpts as evidence, and write the game's code ourselves. The 1.3 names
  were given by people and are usually right. The 1997 retail names were
  guessed by a machine and are often wrong (`gauntlet-design.md` §0.4), so
  ignore them.
- **Original art never enters the repository.** Adventure pictures,
  sprites and sounds come from the player's own install through the skin
  importer, as the duel's do (`Provenance.md`).
- **Headless first:** the rules and state live in plain, tested scripts, and
  screens sit on top. That is how the Gauntlet was built
  (`gauntlet_state.gd`), and it keeps the adventure playable by tests, the
  MCP server and decision models.

## Already in place to build on

| What | Where | Use in the adventure |
|---|---|---|
| Ante zone, `change_owner`, ante cards | `MtgGame` / `MtgPlayer.ante` (ROADMAP, "ANTE") | the card economy: winning and losing cards for real |
| `outside_the_game` | `MtgPlayer` (ROADMAP, wave 47) | the player's collection, which Ring of Ma'rûf reaches into |
| 1997 rules preset, Enemy Levels, AI difficulty | `docs/ai-difficulty.md`, `--rules fifth` | enemy strength by tier and difficulty |
| A run of opponents | the Gauntlet, `docs/gauntlet-design.md` | a worked example of a mode built on the duel |
| 1997 preconstructed decks | `decks/1997/`, `docs/decks-1997.md` | a start for enemy decks (the roster itself is separate) |
| Deck builder | `game/deck_builder/` | Inventory editing; `@DECKSURFACE_ADVENTURE`'s "move by colour" pair belongs here (ROADMAP) |
| Adventure strings | `Advstrings.txt`, registered in `Provenance.md` | names, prompts, town and wiseman text |
| Overworld music, 16 faces | `game/music_library.gd` (the `Sound/` folder), `game/portrait_library.gd` (`16faces.spr`) | world tracks, the player's face |
| Lore and systems tables | `../docs/SHANDALAR_LORE.md` | enemy tiers, world magics, economy, dungeons |
| Arzakon | `docs/arzakon.strategy` | how players beat the final boss: rules and AI checks |
| Player files | `docs/player-files.md` | where a campaign save belongs |
| Card packs | `game/card_packs.gd` (`available_ids`, `has_pack`, `is_enabled`, `info`), `game/card_packs_screen.tscn`, `docs/adding-card-packs.md` | the new-game card-pack step (below) |

## New game — the player's choices (owner design, 2026-10-04)

The 1997 retail New Game asks three things and then makes the world:
difficulty (`menu2`), colour (`menu3`) and face (`16faces`, `0047b899`).
Choosing a face also chose the name, since each of the 14 portraits has its
own name in `Advstrings.txt` `@PLAYERNAMES`. **Version 1.3 changed the
third step:** the face is designed in a separate program, `Facemaker.exe`,
and the name is typed (see "New game in the sources" below). Ours asks, in
this order:

1. **Difficulty** [1997]
2. **Colour of the player** [1997]
3. **Appearance**, the portrait [1997; 1.3 designs it]
4. **Player name** [1.3: typed, up to 25 letters, digits and spaces].
   Suggestion [QoL]: start from the chosen portrait's 1997 name, and let
   the player change it.
5. **Card packs** [QoL]. Which installed expansions (Packs 1–9 so far) join
   this adventure.
6. The button **"Start Magic the Gathering adventure!"**, which makes the
   world and starts the campaign.

**On one screen (owner design, 2026-10-22):** *"we will implement from
scratch a new selection screen where all settings will be on one screen"*,
on the 1997 portrait screen's dark ground with red arrows: the title
"Embark to the world of Shandalar…", the face (also the hero's face in
adventure duels, from every face the game has), the name, a Male / Female /
Other toggle for the map figure (Other is one of the two at random), the
hero's colour, emphasised, the playmat (any ground the duel has), the card
packs, the difficulty, and the buttons **Adventure** and **Leave**. Built
the same day; see "Built: the Embark screen".

**Card pool (owner rulings, 2026-10-04 and 2026-10-22):**
- A campaign starts with the original cards, plus whichever installed packs
  the player selects (all or some). Pack support is there from the first
  version.
- **The starting deck is original cards only** (2026-10-22), as in 1997
  and 1.3.
- **The base cards are always present; the packs are additional
  challenges, and Pack 1 is never one** (owner, 2026-10-22: *"Pack one is
  just a couple of problem cards and should always be ignored"*). Pack 1
  completes the base set with the few cards the original left out; an
  adventure offers Packs 2 onwards (`AdventureSetup.IGNORED_PACKS`), and
  the screen says *"These are additional challenges. The base cards are
  always present."*
- **Each selected pack is a world of its own** (2026-10-22): it adds a
  location to the main map that takes the player to the pack's sub-world,
  where that pack's cards are available. Each pack world has its own
  **World Lord**. Defeating that lord makes the pack's cards available
  everywhere in the campaign: shops, enemy decks, rewards, dungeons.
  *(This replaces the 2026-10-04 ruling that a selected pack's cards are
  available everywhere from the start.)*
- **A campaign started with packs can be resumed only with those packs
  installed.** Without them it does not load (the game should name the
  missing packs). A campaign without packs always resumes.
- **A newer version of the same pack still resumes** the campaign (owner,
  2026-10-04). The pack's id must match; its version may be newer than the
  one the campaign recorded. `card_packs.gd` already compares versions
  (`_version_less`). An older version than the one recorded is not decided.
- The selected packs, with their versions, belong to the campaign and are
  saved with it.

## Built: the Embark screen (2026-10-22)

`game/adventure/embark_screen.gd` (the screen, opened by the title's
`Shandalar`), `game/adventure/adventure_setup.gd` (every choice, headless,
and the record), `game/adventure/red_arrow.gd`. Tests:
`tests/unit/test_adventure_setup.gd`, `tests/ui/test_embark_screen.gd`.

- **The ground** is `Menu4.pic`, imported as the skin picture
  `adventure_hero_background` (`tools/import_original.py` `PIC_SCREENS`);
  without it the same dark, flat. `character_select_background`
  (`Advfac64.pic`) turned out to be the world-map frame, not the character
  screen; it keeps its name and waits for the overworld.
- **The red arrows are drawn** ([QoL]): no arrow survives in the files we
  have (1.3's face-designer buttons were in `FaceArt/`).
- **The faces**: the fourteen 1997 heroes first, in frame order, then every
  other face the portrait library finds. A hero brings their 1997 name and
  walker; the name follows the face until the player types one.
- **The colour** wears the five `stat_buttons` symbols (`Statbutt.spr`),
  shows the colour menu's line and the world magic and amulet the hero
  starts with.
- **The playmat**: your colour or any other, in any of the three styles, or
  Random (1.3's own choice, drawn by the world's seed).
- **The difficulty** says how hard it is in plain words — Apprentice a
  training game, Magician easy, Sorcerer normal, Wizard hard (owner,
  2026-10-22) — and shows the starting gold, food, amulets and first deck.
- **The world seed.** The 1997 game seeded every world from the clock
  (`SeedRandomFromTickCount`: `GetTickCount() & 0x7fff`, a 15-bit number)
  and made it at random from that, without showing the number. Here it is
  shown and may be typed [QoL]: empty for a new world, a number for the
  same world again. Not remembered, like a duel's.
- **The three windows are one size and lined up** (owner, 2026-10-22):
  equal thirds of the row, the full height down to the buttons.
- **Adventure** refuses a nameless hero, remembers every other choice
  (`adventure_*` settings) and makes the record below; for now it then
  says the world itself is still being built. **Leave** and Escape go back
  to the title.

**The record** (`AdventureSetup.resolve`, `RECORD_VERSION` 1) is what the
world generator will take: `seed`; `hero` (`portrait`, `name`, the walker
drawn and the one chosen); `color`; `difficulty` (0–3); `playmat` (colour
and style, Random already drawn); `packs` (each id with the version
installed, for the resume rule); `start` (gold, food, amulets, the first
deck's size and colours, the world magic and the amulet's colour); and the
game's version. One seeded stream draws the walker for Other, then the
playmat style for Random; the generator goes on drawing from the same
seed.

**Next:** the starting deck needs the 1997 rarity of every original card,
which our card data does not carry (`AddRandomStarterDeckCards` rejects by
rarity, ante and "complex" flags); then the world generator
(`world-builder-adventure-notes.md`) from the record's seed.

## Built: the world (2026-10-22)

**The 1997 world generator, exactly** (`game/adventure/world/`):
`WorldGenerator` makes the original's world from the original's dice
(`MsvcRandom`), on the original's work page (`ShandalarWorld`), proven
against the 1.3 decompilation world for world (`world-builder-adventure-notes.md`,
"Exactness"). The record's seed is the dice's state as the world begins,
and its `slot_start` (the original's clock) follows from it.

**The world screen, full screen** (the owner, 2026-10-22: *"we will omit
the original border around the world screen and try to render it full
screen"*): `WorldScreen` draws the world as 1.3 drew it (`WorldView`,
"Drawing the world" in the companion notes), with a zoom, and the hero
standing at the start. Adventure on the Embark screen now makes the world
(an hourglass runs in the bottom strip, "Conjuration of Shandalar World")
and opens it. The player can look around (arrows, a
drag), zoom (wheel, + and −), come back to the hero (Space) and open the
map of the world (M; it shows the whole world until walking exists).

**Next:** walking (the original's pace and terrain costs, read), towns,
the encounters; the starting deck (the 1997 rarities).

## New game in the sources (cross-reference, 2026-10-22)

Read in the 1.3 decompilation (`rlerrr`, commit `fda3230`) and checked
against the 1997 retail one (`benprew`) and the 1997 FAQ.

**The order** (`RunAdventureSession`, 0055db50). Escape on any step goes
back one step:

1. Opening menu (`RunOpeningMenu`): Start New Game, Load Saved Game, Resume
   Game, Set Options, Exit (`Advbuttons.txt` `[openingMenu]`). Load is
   greyed when no `magic4.map`…`magicd.map` exists, Resume when
   `magic3.map` does not.
2. Difficulty (`RunDifficultyMenu`, `menu2.pic`): "Select Difficulty
   Level", Apprentice, Magician, Sorceror, Wizard (`[diffCaption]`,
   `[diffs]`; `@DIFFICULTYLEVELS` spells it Sorcerer).
3. Colour (`RunColorMenu`, `menu3.pic`): "Select Your Color", shown as Red,
   White, Black, Green, Blue, each with a line of flavour text
   (`[colorMenuColors]`, `[colorMenuFlavor]`). The internal colour numbers
   are Black 1, Blue 2, Green 3, Red 4, White 5
   (`g_color_menu_selection_to_deck_color = {4, 5, 1, 3, 2}`). Choosing a
   colour also picks the duel playmat's territory: that colour, and a
   random one of its three types.
4. Face (`RunFacemakerFlow`): starts `Facemaker.exe /S`. The designer offers
   17 face sets (`FaceData.txt`: a display name, a folder `fb1`…`fb17`
   under `FaceArt/`, and `m` or `f`). Each set has a base picture and several
   layers; each layer is one of its variants or none, six layers on screen
   at a time. The result is a 137 × 169 picture, saved with the
   game. The set's `m` or `f` decides the hero's figure on the map
   (`ego_m.spr` or `ego_f.spr`) and the gendered texts.
5. Name (`RunNameEntryDialog`, `namepick.pic`): "Enter Your Name"
   (`@STARTUP`). It starts from the face set's display name; up to 25
   characters, letters, digits and spaces only; arrows, Home, End, Insert,
   Delete and Backspace edit it. Escape goes back to the face designer.
6. "Shandalar Materializing..." while the game is made:
   `InitializeNewGameState`, then the world (`GenerateAdventureWorldMap`,
   `InitializeCastleDungeonSlots`), then the gold, then a starting tile:
   random, on land of the player's own colour, never on a tile flagged
   `0x10`. The new game is saved at once to slot 3, the one Resume reads.

**What a new hero starts with** (1.3 and the retail release agree unless
said otherwise):

| | Apprentice | Magician | Sorcerer | Wizard |
|---|---|---|---|---|
| Gold, (5 − difficulty) × 50 | 250 | 200 | 150 | 100 |
| Food (`g_food`'s starting value) | 50 | 50 | 50 | 50 |
| Amulets: one of the player's colour, then (3 − difficulty) of random colours | 4 | 3 | 2 | 1 |
| Deck, own colour: lands, spells, creatures, + 1 rare | 13, 12, 10 | 11, 4, 12 | 9, 3, 9 | 6, 3, 5 |
| Deck, more colours | — | one random colour: 4, 3, 4 | two random colours: 5, 3, 4 and 4, 3, 3 | any colour: 11, 5, 14 |
| Cards (retail count) | 36 | 39 | 44 | 45 |

- **One world magic of the player's colour** from the start: the first of
  that colour's pair — Black Conjurer's Will, Blue Leap of Fate, Green
  Quickening, Red Staff of Thunder, White Sword of Resistance. It is taken
  out of the towns so it cannot be offered again (`g_world_magic_bitmap`,
  `Scards[colour × 2].worldmagic_city = 0`). Neither our notes nor the
  1997 FAQ mention this.
- **How the deck is drawn** (`AddRandomStarterDeckCards`): random cards are
  drawn and thrown back until one fits. Lands are basic lands of the
  colour. Each spell slot is, by a coin toss, a spell of the colour or a
  colourless artifact. Slots alternate between "common only" and "up to
  uncommon"; the rare slot wants rarity 3 or more, of the colour or
  colourless. Creatures and the rare respect the deck's copy limit
  (`GetRemainingAllowedCardCopies`: one copy while the deck holds under 40
  cards, two from 40, three from 60, one more with Tome of Enlightenment;
  basic lands are free); spells are not checked. Cards flagged as ante or barred (`extra_ability & 0x900`) never
  come; on Apprentice, spells and the rare also skip cards flagged complex
  (`static_ability & 3`), and creatures skip them on every level. Only the
  base sets count (`expansion & 0xc1`).
- **Starting life is not part of the new game.** The retail spec's "life
  total 8" is the four AI combat weights that are set to 8 there. Life is
  worked out per duel; it belongs with the duel hand-off.
- **Two places to check against the 1.3 binary before copying them:**
  1. Apprentice has a second quota, 13, 7, 15, behind a test the
     decompilation renders as `(mask < 1) & 0x20`. As written it is never
     true; if it means "the colour is White" (bit `0x20`), white
     apprentices start with fewer spells and more creatures. The retail
     release has no such branch.
  2. The 1.3 function adds a card after the rare block even when there is
     no rare, which puts a second copy of the last creature into each
     extra colour's cards. The retail release adds the rare only inside
     the block.
- **The face designer's art is not in our copy of the game files.**
  `../shandalar-src/` has `Facemaker.exe`, `FaceData.txt`,
  `FaceButtons.txt`, `namepick.pic` and the pedestals, but no `FaceArt/`
  folder; s30's assets have `Ego_M` and `Ego_F` (the map figures) but no
  face layers either. What we can offer today is the retail 16-face pool
  (`16faces.spr`, cut by `tools/import_original.py`) plus the player's own
  and our shipped faces (`game/portrait_library.gd`).

## Systems and where to read them

| System | 1.3, matching (`rlerrr`, `src/shandalar/src/`) | 1997 retail (`benprew`, Tier 2) | s30 (guide only) |
|---|---|---|---|
| World generation | `world_generation.c` (`GenerateAdventureWorldMap` 004f6d90) | `Pic_Subsystem_0044d680` and the functions it calls; full notes in the companion file | `game/world/generate.go`, `castle_place.go`, `dungeon_place.go` |
| Overworld view, movement, day and night, minimap | `adventureWorldUi.c`, `adventure_input.c`, `mapScreen.c` | `src/magic/sid/glue_adventure.c` (`Adventure_UpdateWorldMapLoop`, `Adventure_Map_RedrawViewport`, `Adventure_Map_UpdateLightingAndPalette`) | `game/world/level.go`, `autotiling.go`, `game/minimap/`, `screens/level.go`, `world_frame.go` |
| New game: difficulty, colour, face, starting deck and gold | `shandalar.c` (`RunAdventureSession` 0055db50: the order), `openingMenu.c` (the menus, `RunFacemakerFlow`, `RunNameEntryDialog`), `adventure_new_game.c` (`InitializeNewGameState` 004bdd0a: deck, amulets, world magic), `src/facemaker/src/main.c` (the face designer) | main menu case 0 in `glue_adventure.c`; `docs/STARTING_RESOURCES_SPECIFICATION.md` in the decompilation; gold = (5 − difficulty) × 50 | `screens/start.go`, `domain/starting_deck.go` |
| Towns and villages: cards, food, quests, wisemen | `cityInfoScreen.c`, `visitLocation.c` | `src/magic/world/town.c` | `screens/city.go`, `buycards.go`, `wiseman.go`, `quest_*.go`, `domain/city.go`, `quest*.go` |
| Roaming enemies and encounters | `world_lair_monster_slots.c`, `world_lair_monster_encounter.c` | `Ai_Overworld_ChooseRoamDirection`, `Ai_Overworld_EvaluateEncounterThreat` | `world/enemy_spawn.go`, `domain/enemy.go`, `rogue.go` |
| Random events and lairs | `world_lair_monster_*.c` | (to find) | `world/random_encounters.go`, `screens/random_encounter.go` |
| Dungeons | `dungeonEncounter.c`, `dungeonCluesScreen.c` | `Dungeon_Process_*` | `domain/dungeon*.go`, `screens/dungeon*.go`, `docs/dungeons.md` |
| Wizards' castles | `InitializeCastleDungeonSlots` (`world_generation.c`) | `Castle_Process_*` | `domain/castle.go`, `world/castle_place.go` |
| World magics (12) | `Scards[].worldmagic_city` (`world_generation.c`) | the 12-entry table in site placement (companion file, step 8) | `domain/worldmagic.go` |
| Amulets and mana links | (to find) | (to find) | `domain/amulet.go` |
| Card prices, collection | (to find) | (to find) | `domain/collection.go`, `card_tiers.go` |
| Enemy AI in duels | `src/magic/` (the duel code `magic.exe` shares) | `docs/SHANDALAR_AI_FAQ.md` in the decompilation | — |
| Save and load | `adventure_save.c`; `docs/shandalar_save_files.txt` | `SaveGame_SaveCampaignFile`, `Overworld_SaveMapFile`: slot 3 is the running game, slots 4–9 and a–d are saves | `game/save/` |
| Arzakon and the ending | (to find) | (to find) | (to find) |

## A possible order (a proposal; the owner decides)

1. **Campaign state, new-game choices and world generator,** headless and
   tested: the six-step new game above, and a seeded generator, so the same
   seed gives the same world in tests and playtests.
2. **The overworld:** draw the grid with skin tiles, walk, minimap, day
   and night.
3. **Towns and the duel hand-off:** buy and sell cards, food, a duel against
   an enemy with ante, the collection, save and load.
4. **The rest of the world:** roaming enemies and encounters, then dungeons,
   castles, world magics, quests and amulets, then Arzakon.
5. **An adventure driver for agents,** like the duel referee, so playtests
   and decision models can play a campaign (an idea, not a commitment).

## Open decisions

- ~~Licences~~ — **decided 2026-10-04:** s30 is a guide only and the
  adventure is our own implementation (Ground rules). s30 is GPL-2.0 without
  "or later" and this project is GPL-3.0, so no s30 code is translated.
- ~~Which world~~ — **follows from that ruling:** the 1997 generator from the
  decompilation (a new world each game, companion file), with our own
  [QoL] on top (for example, showing a world's seed so it can be replayed).
- ~~Card pool~~ — **decided 2026-10-04, revised 2026-10-22:** the original
  cards plus the packs selected at new game; the first deck is original
  cards only, each pack is a world of its own whose World Lord unlocks its
  cards everywhere, and a pack campaign resumes only with its packs
  installed ("New game" above).
- **Scope of the first playable version,** and which platforms it must
  run on (handhelds, Quest and Web each have limits).
- ~~Character creation~~ — **decided 2026-10-22** (owner design, "On one
  screen" above): the face from every face the game has, on the 1997 portrait
  screen's ground with red arrows; the walker its own toggle, Male / Female / Other. Still
  to check in the 1.3 binary before the starting deck is built: the
  Apprentice quota and the extra creature copy.

## Log

- **2026-10-04** — Notes started. World generation researched from the
  decompilation: the original makes a new world per game (companion file).
  Found that s30's terrain uses a fixed seed. Raised the s30 licence question.
- **2026-10-04** — Owner ruling: s30 is a guide only; the adventure is
  reimplemented from the decompilation, with our own QoL. Ground rules and
  open decisions updated.
- **2026-10-04** — Owner design for New Game: difficulty, colour,
  appearance, player name, card packs, then "Start Magic the Gathering
  adventure!". Original cards to begin with, card-pack support from the start.
- **2026-10-04** — Owner ruling on packs: a campaign can start with selected
  packs, their cards are available everywhere, and a pack campaign cannot be
  resumed without its packs. A newer version of the same pack still resumes.
- **2026-10-04** — Found the matching decompilation of version 1.3
  (`rlerrr/shandalar-decomp`, via r/Shandalar). It is now the first source
  for the adventure. It confirmed the world notes and answered most of their
  open questions.
- **2026-10-22** — Owner ruling on packs: the starting deck is original
  cards only; each selected pack adds a location on the main map leading to
  the pack's sub-world, where its cards are available, and its World Lord;
  defeating the lord makes the pack's cards available everywhere.
- **2026-10-22** — Character creation cross-referenced with the 1.3
  decompilation (now with `magic.exe` at about 89% as well): the order of
  the menus, the face designer and the typed name, the starting resources
  including a free world magic of the player's colour, and what still needs
  checking. "New game in the sources" above.
- **2026-10-22** — Owner design: everything on one screen, "Embark to the
  world of Shandalar…", on the 1997 portrait screen's ground with red
  arrows, Male / Female / Other for the walker, the colour emphasised, any
  playmat. Built the same day ("Built: the Embark screen").
- **2026-10-22** — Owner ruling: the base cards are always present; Pack 1
  is never offered to an adventure; Packs 2 onwards are additional
  challenges, and the screen says so.
- **2026-10-22** — Owner: world building next, "exactly like the
  original", full screen without the frame. The generator ported and
  proven exact against the 1.3 decompilation (40 worlds); the world screen
  draws it as 1.3 did, full screen, from the 1997 sheets now imported
  (`world_*`). "Built: the world".
- **2026-10-22** — Owner: the seed is filled in from the clock, "akin to
  the original 1997", then "the hour, minute and seconds … to be more
  human readable". The Embark screen's World seed now opens with the time
  of day, HHMMSS on the 24-hour clock (midnight `240000`), as 1.3 seeded
  its dice from the clock (`srand(GetTickCount())`); the same time on
  another day makes the same world, and any number up to ten digits (every
  32-bit seed) may be typed. And every seed makes a world: the generator's GUARDs make
  the world again where the original hangs, and the world is made on a
  thread (`world-builder-adventure-notes.md`, "Never stuck").
- **2026-10-22** — Owner: "we can use also letters as user typed seeds or
  whatever number", and "let's make our generator deterministic". A seed
  is now any text: digits making 1 to 4,294,967,295 are the dice's state
  as they read, anything else is hashed (FNV-1a, 32 bits, lower case);
  the record keeps `seed_text` as typed, shown on the world screen and in
  the arrival note. The generator was deterministic already: the dice
  continue through every failed site pass, every land made again and every
  GUARD, so one seed makes one world on every machine. The one difference
  from 1997 is the slot start, kept for every pass where the original read
  its clock again.
- **2026-10-22** — Owner: a wider seed field, and while the world is made
  "some beautiful mtg hourglass animation at the position where 'enter
  seed' was along with words beneath … and one to 5 '*' … and to one
  again", the words then renamed "Conjuration of Shandalar World". Built:
  `Hourglass` (drawn: gilded caps set with the five colours' gems, sand
  running 2.6 s, the glass turned over in 0.6 s), the stars 1→5→1 every
  0.28 s, the choices held still; the world screen follows the moment the
  world is made. Owner, on a first try as a card over the screen: "it
  should not be a popup … just the bottom strip. Left center hourglass,
  right center the text and stars": so `Leave`, the seed and `Adventure`
  give way to the hourglass and, beside it, the words and stars on one
  line, the strip keeping its height. It replaces our full-screen
  veil, which had borrowed the original's "Shandalar Materializing...".
- **2026-10-22** — Owner: "a randomize button to the left of Adventure to
  randomize every setting", then "randomize a name also from a set of
  wonderful (sometimes funny) 100 magical names and 100 magical surname
  combinations": `randomize_all` draws the face, a name
  (`AdventureSetup.FIRST_NAMES` × `SURNAMES`, ours, every pair within 25
  characters), the figure, the colour, the playmat, the packs, the
  difficulty and a seed (a time of day). And on the view, "maybe we show
  too much now": of four shown, the owner chose fog over unseen land, a 2×
  default zoom and an explored-only map
  (`world-builder-adventure-notes.md`, "Drawing the world").
- **2026-10-22** — 0.50.49: CI (no skin, eight packs, 1280 × 800) found
  the Journey window taller than the screen allows, so the columns
  scrolled and the scrollbar broke the line-up with the buttons. All and
  None moved beside the Card packs heading: a row saved, the three windows
  one size again.

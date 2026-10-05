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

The 1997 New Game asks three things and then makes the world: difficulty
(`menu2`), colour (`menu3`) and face (`16faces`, `0047b899`). Choosing a
face also chose the name, since each of the 14 portraits has its own name
in `Advstrings.txt` `@PLAYERNAMES`. Ours diverges a little and asks, in
this order:

1. **Difficulty** [1997]
2. **Colour of the player** [1997]
3. **Appearance**, the portrait [1997]
4. **Player name** [QoL]. Suggestion: start from the chosen portrait's 1997
   name, and let the player change it.
5. **Card packs** [QoL]. Which installed expansions (Packs 1–8 so far) join
   this adventure.
6. The button **"Start Magic the Gathering adventure!"**, which makes the
   world and starts the campaign.

**Card pool (owner ruling, 2026-10-04):**
- A campaign starts with the original cards, plus whichever installed packs
  the player selects. Pack support is there from the first version.
- **The selected packs' cards are available everywhere** in that campaign:
  shops, enemy decks, rewards, dungeons, everywhere the original cards
  appear.
- **A campaign started with packs can be resumed only with those packs
  installed.** Without them it does not load (the game should name the
  missing packs). A campaign without packs always resumes.
- **A newer version of the same pack still resumes** the campaign (owner,
  2026-10-04). The pack's id must match; its version may be newer than the
  one the campaign recorded. `card_packs.gd` already compares versions
  (`_version_less`). An older version than the one recorded is not decided.
- The selected packs, with their versions, belong to the campaign and are
  saved with it.

## Systems and where to read them

| System | 1.3, matching (`rlerrr`, `src/shandalar/src/`) | 1997 retail (`benprew`, Tier 2) | s30 (guide only) |
|---|---|---|---|
| World generation | `world_generation.c` (`GenerateAdventureWorldMap` 004f6d90) | `Pic_Subsystem_0044d680` and the functions it calls; full notes in the companion file | `game/world/generate.go`, `castle_place.go`, `dungeon_place.go` |
| Overworld view, movement, day and night, minimap | `adventureWorldUi.c`, `adventure_input.c`, `mapScreen.c` | `src/magic/sid/glue_adventure.c` (`Adventure_UpdateWorldMapLoop`, `Adventure_Map_RedrawViewport`, `Adventure_Map_UpdateLightingAndPalette`) | `game/world/level.go`, `autotiling.go`, `game/minimap/`, `screens/level.go`, `world_frame.go` |
| New game: difficulty, colour, face, starting deck and gold | `adventure_new_game.c`, `adventure_main_menu.c`, `src/facemaker/` (the face designer) | main menu case 0 in `glue_adventure.c`; `docs/STARTING_RESOURCES_SPECIFICATION.md` in the decompilation; gold = (5 − difficulty) × 50 | `screens/start.go`, `domain/starting_deck.go` |
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
- ~~Card pool~~ — **decided 2026-10-04:** the original cards plus the packs
  selected at new game. Pack cards are available everywhere, and a pack
  campaign resumes only with its packs installed ("New game" above).
- **Scope of the first playable version,** and which platforms it must
  run on (handhelds, Quest and Web each have limits).

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

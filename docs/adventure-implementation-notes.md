# Adventure mode — implementation notes (M5)

**Started 2026-10-04.** These are living notes for the future adventure mode:
the Shandalar overworld, towns, enemies, dungeons, castles, world magics and
Arzakon. Nothing is built yet. (2026-10-27: no longer so — the Embark
screen, the world, parts A and B and the world's last pieces are built,
0.50.48–0.50.61, each in a "Built:" section below; and since 0.50.62–0.50.64
part C too — the castles, the dungeons, Arzakon and the end: the adventure
is played from Embark to the Hall of Fame.) The ROADMAP's M5 entry says the milestone
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
and opens it. The player can look around (W A S D since
0.50.66, a drag), zoom (wheel, + and −), come back to the hero (Space) and open the
map of the world (M; it shows the whole world until walking exists).

**Next:** walking (the original's pace and terrain costs, read), towns,
the encounters; the starting deck (the 1997 rarities).

## Built: the adventurer, walking and the saves (2026-10-22)

The owner: *"a structured commented and human readable AdventurePlayer
class where all current player data is recorded along with all items and
stats and current world state"*, an autosave when the game starts *"by
player name and time hash"*, a walking figure *"we will guide … with
pathfinding by clicking on a map"* with a walking-man pointer and an open
door over a town, and a load.

**What a game keeps** (`AdventurePlayer`): the parts of the 1.3 save
(`magicN.SVE`; the decompilation's `docs/shandalar_save_files.txt`, after
"Per" on slightlymagic.net), each field naming its offset — the hero
(name, gender as the map figure, colour, difficulty), where they stand
(world units, facing, step), what they carry (gold 0x21D20, food 0x21D24,
the five amulets 0x21D0C, the World Magics 0x22110, the cards with their
three decks 0x1420), the duels (life added to the next, a card in play in
the next, victories over roaming creatures 0x21D28, the last colours), the
record (the journal 0x224C8, from which wins and losses are read, the
wizards beaten 0x221D4, lairs explored 0x224AC, the quest 0x21CF8), the
clocks (monster 0x1EAF4, quest and restock 0x224B0, siege 0x224A8) and the
world (its recipe, the page's tiles, flags and roads, the 128 sites, the
World Magics' towns, the castles and dungeons, the lairs and roaming
creatures 0x1EA2C). The parts nothing uses yet are there, empty.
- A new hero gets what `InitializeNewGameState` gives: (5 − difficulty) ×
  50 gold, 50 food, an amulet of their colour and (3 − difficulty) more,
  whose colours are drawn with the original's `internal_rand(5) + 1` on the
  adventure's dice where the world left them, and the colour's first World
  Magic. The starting deck waits for the 1997 rarity table. (2026-10-27:
  dealt since 0.50.51, `StarterDeck`, "Built: the first deck…" below.)
- **Mana links** are kept on the hero, not read from a site's status bit 1
  as the save's notes would have it: the generator sets that bit on the
  first ten towns and cities with World Magic as it makes the world, so
  there it means something else, not yet read. (2026-10-27: superseded in
  part A — the bit IS the mana link, `TownStatus.LINKED` (0x0001); the
  hero keeps no list, and `AdventurePlayer.mana_links()` is a method that
  counts the linked towns and cities no wizard holds, the hero's life in
  a duel.)
- **The saves** are JSON in `user://adventures`, `<Name>-<hash>.autosave.json`,
  the hash the 32-bit FNV-1a of the name and the moment the adventure
  began; the world's page is kept as 128 rows of 64 hex bytes (the tiles
  with their flags, then the roads), so a load needs no generator, and
  `world_intact` checks it against the fingerprint it was made with. The
  autosave is written as the world screen opens (`EmbarkScreen.set_out`);
  Save / Load on the title lists the saves, `LoadAdventureScreen`.

**Walking** (`HeroWalk`), read in `UpdateAdventureWorldInputAndMovement`
(0055e808) and the loop in `shandalar.c` that runs it:
- **The tick** is 60 ms (`while (clock() - last_tick < 0x3c)`); the 1997
  loop reset `last_tick` every pass, so the retail game ran as fast as it
  could draw, which the decompilation's `MODERN_FIXES` mends. The monster
  timer counts the ticks.
- A step is a unit (32 to a tile) in one of eight ways, a diagonal no
  longer than a straight. The tile ahead decides the pace: forest (2),
  swamp (3) without Amulet of Swampwalk, mountains (4, 5) without Dwarven
  Pick take a stride of two every third tick; a road leaving the hero's
  tile the way they go, or coming in from behind, is never slow, and on
  odd ticks adds a unit. No food: the divisor two more, at most 4.
- Every 32nd tick a walking hero eats a food (Fruit of Sustenance gives two
  back on forest) and the quest and siege clocks step on (the sieges
  themselves are not made yet; 2026-10-27: made in part B, `Sieges`, which
  `HeroWalk` calls on each step of the clock). A step into the sea within 12 units of a
  tile's middle is taken back.
- The figure is `EGO_M`/`EGO_F` frame `((direction + 2) & 7) * 5 + step`,
  the step 1–4 while walking, 0 standing; the shadow the same.
- **Ours [QoL]**: the original walked one of eight ways from a click
  (`MapWorldClickToMovementKey`, keys for the eight) or the arrows; a
  click is a destination here and the way round the water is found
  (`AStarGrid2D`, costed by the same pace), walked tile middle to tile
  middle, never past one. The keys walk as 1997's did (0.50.66, the owner's ruling of 2026-10-29): the arrows, Home, PgUp, PgDn, End and the keypad set one of the eight ways (adventure_input.c 328–353) and the hero walks it a tile at a time while held, no way found (`HeroWalk.key_toward`); two arrows walk the diagonal between; every place stepped onto is entered and the sea stops the walk. [ours: let go, the hero stops on the tile's middle — 1997's heading stayed until Space, the shore or a town.] W A S D and a drag look around; the keypad's digits walk rather than cast (1997's keypad never cast). Path arrows [ours, 0.50.66, the owner's HoMM3 reference]: `WorldPath` draws `HeroWalk.path` on the explored land with `HeroWalk.forecast`, which runs `step`'s own `pace`/`stride`/`meal` ahead on copies (orange fed, red hungry; creatures met and siege news not foreseen); the preview after a 150 ms rest; nothing for key walks or while the world waits; switch "Path arrows", on by default.
- **Not yet**: the dice the original draws each step for the footstep's
  sound and the roaming creatures, so the adventure's dice stand still.
  (2026-10-28: built since — the footsteps and the roaming creatures draw
  on the adventure's dice, 0.50.52–0.50.54; `HeroWalk`, `WorldCreatures`.)
- **The pointers** are ours: the 1997 window class loads `IDC_ARROW`; the
  walking man and the open door are drawn (`WorldCursors`), the door shown
  over a site the hero can see.

**The walking figure's colours** (`HeroColors`, the owner: *"boots, pants,
body, arms, hair, skin … one of the choices in the adventure menu starting
screen … randomized also"*, and *"a default button that reuses the OG old
game figures"*) [QoL]. `EGO_M` and `EGO_F` are single painted sprites of
some 140 colours, the figure about 20 × 36 pixels in a 154 × 108 frame:
the man black-haired in a red vest, white sleeves with green cuffs, a
green belt, blue trousers and black boots; the woman long black hair, a
blue bodice with purple, white sleeves, a red sash, a green skirt, black
boots. The parts are found by colour and by height in each frame's figure
(black high is hair, low is boots), on the player's own sheets as the game
reads them; the cuffs, belt and sash are trim and stay. A part is dressed
by laying its shades along the chosen colour's ramp, its usual shade on the
colour itself. The Embark screen has a swatch a part (each opening its
colours), `1997` and a walking preview under them; the choice is
remembered, carried in the record and the save, and worn on the map.

**The floating icons** (`WorldHud`; the owner: floating icons *"based on old
1997 frame icons for old feel"*, then one row, then *"a floating rectangle
panel with round corners … but the panel occupies whole horizontal
space"*, the room shared between its three groups; ? holds the keys that
were a line under the world; the painted book that was Save opens the
options — save, load (over the world), the panel to the bottom or back,
exit the game, saving first; the name and difficulty by the panel in the
hero's colour of magic; an icon's name floats beside the panel when the
pointer rests), from 1.3's `DrawAdventureInterfaceLayout`
(adventureWorldUi.c) and the frame's controls (`g_main_menu_controls`,
`QueuePendingMenuActionInput`):
- **The strip** under the window (`Advinter.pic`, its 1024 × 768 version
  imported as `world_frame`): painted gold, food, an ankh and a book, the
  numbers drawn beside them — gold, food, `CountDuelPoolEligibleTowns` (the
  mana links) and the deck as cards in use / cards owned. They sit on the
  frame's glass, sharing its colours, so they are cut as small glass tiles.
- **The amulets** (`Amsprite.spr`: white, blue, black, red, green) drawn
  with their counts in the order black, blue, green, red, white.
- **The World Magics** (`Worlds.spr`: four rows of twelve — normal, lit,
  the active five pressed, their keys 1–5) at fixed places: an owned active
  one whose colour has no amulet shows pressed.
- **The four round buttons** on the frame's left (`Worlds.spr` frames
  48–55, normal and lit): the spellbook = the deck builder (F1), the
  scroll = the map (F2), the gate = the dungeon clues (F4), the faces = the
  hero's menu (F5). Ours: deck, map, hero, and Save on the frame's painted
  book (1997 saved from its menus); the clues come with the dungeons.

**Next:** towns (entering, buying, the quests), the encounters, the
starting deck; a save made from the world screen.

## Built: casting, the panes and what calls the hero (2026-10-23)

The owner: *"implement all items you suggest"*, then *"follow the same
unobtrusive style with popup or hover panes with rounded corners that can
be moved at will … and it should be togglable on/off in options"*.

- **Casting** (`WorldMagic`), read in `UpdateAdventureWorldInputAndMovement`
  (keys `1`–`5`) and `HandleWorldMagicChoiceControlEvent` (004ff888, a
  click on the frame's icon, which plays `…wm.wav` and queues the key):
  key N casts the magic of bit 2N when it is owned and an amulet of its
  colour is left; `internal_rand(4 − difficulty) == 0` takes the amulet,
  drawn before the magic works and even when it finds nothing. Leap of
  Fate draws x then y (`internal_rand(64)`) until land; Quickening sets
  `worldmagic_duration` 150 and every step goes a unit further while it
  runs (in place of the road's odd-tick unit), counted down once a loop
  pass (`TickWorldMagicSlotTimers`); Staff of Thunder frees the nearest of
  roaming slots 0–5 by `ApproximateDistance`, however far; Sword of
  Resistance sets the hero by slot 7's tile, `(x & ~31) + 16`,
  `(y & ~31) + 31`; Conjurer's Will opens the deck builder with the cards
  free to move. Journal lines from `@LOGSTRINGS` ("JUMP!", "SPEED!",
  "THUNDERED on: %s!", "Went to aid of %s"). The icons: an active one with
  an amulet wears its key (row 3) over row 0, none left row 2. Ours
  [QoL]: nothing to work on risks nothing, and Quickening's icon is lit
  while it runs. Retail's F1 quirk (Amulet of Swampwalk's bit) is not
  copied.
- **The quest panel** (`DrawAdventureQuestStatusPanel`, 0054baaa): ours is
  a pane (`WorldStatus`), only when something calls. The quest's five
  saved numbers (type, destination, colour, data = quarter, deadline);
  "Go North/East/South/West to %s" until the hero leaves the quarter, then
  "Take letter/card to %s", "Find a %1 %2 spell", "Defeat %s", "Return to
  %s"; days left `(deadline − timer) / 16 + 1` (a day = 16 quest-clock
  steps: `VisitTownWiseman`'s letter is 32 steps, "4 days"); at the
  deadline "The people of %s are sorry their quest was not completed." and
  the giver's status bit 4. The giver is not in the 1.3 save; ours keeps
  it. 1997 counted no days; "days on the road" is the quest clock in those
  days [QoL]. No day and night: `todpal.tr` is one palette.
- **Sieges and Dominion** (`StartWizardTownSiege` 005616f9,
  `ResolveWizardTownSiege` 00562169): the attacker stands in slot 7; a
  fallen city's status high byte is the wizard's colour, a "mana tap"; a
  wizard with 3 taps (5 with Ring of the Guardian; difficulty only speeds
  the clock) casts Dominion. NOT RUN YET: with no duels to lift a siege,
  the clock would take cities the hero cannot save. The pane, the arrows,
  the small map and Sword of Resistance read the state when it comes.
  (2026-10-27: run since part B, 0.50.54 — `Sieges`, with the duels that
  lift them.)
- **Next duel** (`next_duel_card`: −1 none, 0 first move, 1–5 lives, a
  card above 5; `next_duel_life` carried lives): ours as
  `next_duel_life`, `next_duel_first_move`, `next_duel_card`;
  "Next Duel: +%d lives / First Move / the card".
- **The clues** (F4, `ShowDungeonCluesScreen` 00509244, the detail
  0050caa0; `WorldClues`): slots with `clues_bitmap` (ours `clues`, 1
  where, 2 creatures, 4 rules), dungeons only while they hold cards;
  `@CAVE_SHOWCLUES` lines, the way from the slot's town by the signs of
  dx and dy. 1997 showed an empty list with nothing known; ours says how
  clues are found. Clues come from wise men, Ruined Tower, beaten
  creatures (`RevealRandomCastleDungeonClue`), not made yet. (2026-10-27:
  made — `WorldClues.reveal` / `reveal_for_hint`, called by the wise man,
  the Ruined Tower, a beaten creature's spoils and a creature's meeting.)
- **The names** (`WorldNames`): `BuildTownDisplayName` (00550220) —
  `@CITYNAMES_FIRSTHALF[(slot / 8) mod 16]` + `@CITYNAMES_SECONDHALF[slot
  mod 16]`, a village "%1 Village"; castles `@CITYNAME_MANACASTLE`;
  `@DUNGEON_NAMES` by slot.
- **1.3 had no small map** (the decompilation's `minimap` variables are
  tile sizes); `WorldMinimap` and the guide arrows (`WorldGuides`) are
  ours [QoL]. The F3 city list and F6 wizards' window are not built.
  (2026-10-27: both built — F3 `CityListPane` in part A, F6
  `WizardsPicture` on the hero pane's Wizards tab in 0.50.60.)
- **The panes** move where they are dragged and are found there again
  (`world_pane_<name>`); the options switch the small map, the quest pane
  and the arrows, set the pace (the world's clock ×1, 1.5 or 2 [QoL]),
  the music and the sound, and return to the main menu; leaving saves.

## Built: the first deck, the deck builder and the hero's stats (2026-10-23)

The owner: *"a player stats panel (modern but reuse some elements from
1997) and deckbuilder for the player — the deck builder should be adapted
to adventure mode where cards on the bottom are player stack accumulated
during play! (Extras button absent, and any other conflicting buttons)
… the top left deck name pane … with GOLD and amount of player gold"*.

- **The rarities.** 1.3 reads `Rarity.csv` at startup
  (`LoadRarityCsvCardData`, 005231ec): column 8's first letter C/U/R
  (common, uncommon, rare), kept as 1/4/2 and mapped to 1/2/3, 4 special
  (Astral, promos: `GetCardRarity` 0056c5ea); `Info.csv`'s "Occuran." only
  as a fallback. Its rarity is the card's ORIGINAL set's — what our card
  data gives as the first printing's (`CardRegistry.rarity_of`), so ours
  needs no file of the player's. The base set (`expansion & 0x01`) is ours
  as printed in Unlimited or Fourth Edition.
- **The first deck** (`StarterDeck`, `AddRandomStarterDeckCards` 004be0bf):
  the quotas by difficulty (retail's: Apprentice 13/12/10 + rare;
  Magician 11/4/12 + rare and one colour 4/3/4; Sorcerer 9/3/9 + rare,
  5/3/4, 4/3/3; Wizard 6/3/5 + rare and any colour 11/5/14); lands the
  basic land; spells a coin toss between an artifact (`0x40`) and a spell
  of the colour; even slots up to uncommon, odd common; creatures never
  swamp- or islandwalk (`static_ability & 3`), one copy under 40 cards
  (`GetRemainingAllowedCardCopies`) until 1000 draws found none new; the
  rare a creature, enchantment or sorcery (`0xe`) of the colour or
  colourless, rarity ≥ 3; Apprentice's spells and rare skip the walkers;
  no `extra_ability & 0x900` (the dungeon cards and the card picker's
  barred — ours: the dungeon treasures and the ante cards). Every card in
  Deck 1 (`deck[i] |= 0x10000`). Ours: the dice draw among the cards that
  fit (1997 drew any card and threw back), after the amulets (1997 dealt
  first). OPEN against the binary: 1.3's coloured spell mask reads 0x04
  (enchantments only) where the retail spec says instants, sorceries and
  enchantments — ours follows the retail spec. (2026-10-27: settled in the
  machine code — both releases deal enchantments only; ours now does too,
  0.50.60, "The two places once to check" below.)
- **The deck builder in the adventure** (`DeckBuilderMain` with
  `DBFLAGS_SHANDALAR`; `db_flags_2` bit 0 moves, bit 1 sells): F1 opens it
  look-only (`(1,0)`), Conjurer's Will and the final castle with moves
  (`(1,1)`), a town with moves and selling (`(1,3)`). Its menus are
  `@MAINMENU_ADVENTURE` / `@DECKSURFACE_ADVENTURE` (no New, Load, Save,
  Clear); Deck1–3 with "* DeckN *"; the title field "GOLD: %d"
  (`@GOLDTITLE`); no minimum size; `check_card_count` on close; selling
  `SellPrice` (004f1bcc) from `CalculateCardShopPrice`. Ours
  (`AdventureBuilder`): the sealed pool's machinery over the hero's cards,
  the three decks written back per copy, the doors to outside cards
  closed, "GOLD: %d" on the title slab. [QoL until the towns]: F1 moves
  cards too. Selling comes with the towns.
- **The stats** (`RunAdventureStatsMenu` 00549002, `Statbak.pic`,
  `statbut1.pic`, the creature sheets): the face 137 × 169 in a frame of
  the colour, the difficulty and name, gold, food, mana links, deck
  active/total, the amulets; World Magics (the five cast on the top row);
  "Wizard's Castles Conquered" (castle icons) with "Attempts at Each
  Castle"; "Cities Saved" (journal 13), "Cities Recovered" (7), "Quest
  Record" (16/17), "Overall Won/Loss" (2 with arg & 0x80), "Dungeon
  Treasures" (19); "Record vs the Creatures of Shandalar" (W/L, coloured
  by how it goes); tabs "Wiz Stats" (`Statwin.dll`), "Journal" (walked on
  the map), "Done". Ours (`HeroStats`): one movable pane, tabs Hero /
  Wizards / Journal, the frame's icons and the world's castle sprites
  (`Statbak.pic`, `statbut1.pic` and the creature sheets are not imported).
  Our journal events: `duel` (won, creature), `saved`, `freed`, `quest`
  (done), `treasure`, `magic`.

## Built: visiting the places (2026-10-23)

The owner: *"analyze every possible map location that can be visited and
what screen the original game used in visiting (i remember one screen was
sunken ship also) … upon visiting that location an original graphic is
displayed in a central pane in modern gui with original assets and
feel"*, and *"for each unique place … a mouse cursor that changes to that
place"*.

**What 1.3 showed on arrival** — every picture 512 × 280 without a palette
of its own (the world frame's, `Advfac64.pic`), blitted into the map
window at (64, 48)–(576, 328) of 640 × 480 (`LoadVisitBackdropAndCopyToPage0`
004ed44b), zoomed in (`AnimateVisitBackdropZoomIn` 004ed525), revealed in
staggered tiles for a castle (`ShowWizardVisitBackdrop` 004ed6b9) or random
5 × 5 tiles for a lair (`ShowLairBackdropTransition` 004ed7c8), words in
`Dbox.spr` boxes over it:

| Place | 1.3 | Picture | Words |
|---|---|---|---|
| village | `VisitTownSlot` 004eda50, `RunTownServicesMenu` 004ef1ea | `Village.pic` (`GET_TOWN_PIC`) | the name; five icon buttons (`Icons.spr` in `Iconb.spr`), `@CITYSCREEN_BUTTONS` |
| town, city | the same | `City.pic` | Buy Cards (`Buycards.pic`), Edit deck/Sell cards, Speak to Wise Man (`Wiseman3.pic`) / Begin a Quest / Trade, Buy 10 food for (type + 2) × 5 gold, Leave the village; World Magic offers on `Worlbak1.pic` |
| a town a wizard rules | status >> 8 | the town's, the ante cards and the guardian's face (`Prdfrmc.pic`) | "This place is ruled by the %s." … win `Celeb.pic`, loss `Losedul2.pic` |
| wizard's castle (4), beaten (5) | visitLocation.c:4364 | by colour: `0246`, `0364`, `0335`, `0737`, `0028` | "Who dares to challenge the Mighty %s? …" / "The Mighty %s was crushed …" |
| dungeon (clues known, a card inside) | `RunCastleDungeonBoard` 00443940 | none: the board on `CaveBkgd.pic`, `Dungeon1-3.spr` / `DungeonB/U/G/R/W.spr` | "Exploring the Dungeon… you encounter %s!" |
| lair | `RunLairExplorationEvent` 0052fae0 | by colour (`lair_backdrop_paths`): `0333`, **`0873` the sunken ship**, `0281`, `0329`, `0569` | two times in three a colour's treasure; otherwise "You happen upon a %s!" and one of the 14 named events (Ruined Tower … Diamond Mine) |
| roaming creature | `RunWorldLairMonsterEncounter` | full screen `Prdblk/blu/grn/rd/wt.pic`, `Prdfrma/b.pic`, the face | `@ENCOUNTER_PREDUEL` |

Siege news flashes ride `Newsback.pic`; the end, `5thwiz.pic`, `Wingame.pic`
and `Uth-Arz.pic`.

**Ours**: `VisitPane`, a rounded pane in the middle of the screen over the
waiting world: the place's name, its 1997 picture up to 1.5 × and its
words and choices as buttons. Live now: Edit deck/Sell cards (the deck
builder), Buy 10 food (the 1997 price), Leave; waiting, shown dim: Buy
Cards, the wise man, the duels, entering a castle or a dungeon. The
pictures are imported as `visit_*` (`VISIT_PICTURES`, painted whole in the
world frame's palette). [QoL] a place is visited at the end of the walk to
it (1997 entered every town stepped on; the way found for the hero would
wander into towns not chosen), and a click on the place the hero stands on
visits again. Lairs are not placed in our world yet, so none is met. The
pointers over a place it can see and visit are the place (`WorldCursors`),
a gold arrow over the panel; the owner kept the system's hand and four
arrows over what is clicked and dragged.

## Built: the card shop and the prices (2026-10-23)

The owner: *"lets build the card shop … study how, which cards are
available where and how the price of the cards is determined (we will
need this card value formula for future packs). If no formula is
available try to devise a formula based on card stats that mimics the
prices in the original"*, then *"check also if card ruling/abilities can
be incorporated into pricing … a general formula (not a lookup table)"*,
and *"use uv … to install numpy and other libraries needed to derive a
good formula"*.

- **The offers** (`RunTownServicesMenu` 004ef1ea): `type + 3` cards (+1
  Haggler's Coin), drawn on the first visit and kept (`card_slots`); a
  bought place empty until the quest clock passes `(difficulty + 3) · 5`
  steps after `now + rand(5) · (difficulty + 2)`; one random place a basic
  land (`rand(5)`); the town tile's colours (`GetWorldTileMagicMask`) with
  `is_card_color_compatible_with_mask` at level 1 for black, green, white
  (own colour) and 3 for blue (+black, +white) and red (+green, +black),
  colourless always, a gold card by its first colour; places `i % 3` cap
  the rarity (common, uncommon, rare), odd places no artifact; only
  `expansion & 0xC1` (the core set, 438 cards), never `extra & 0x900`
  (dungeon, picker-barred) or `0x180` (power, restricted);
  `GetRemainingAllowedCardCopies` ≥ 1 counting the active deck. Bought:
  `deck[]` with 0x4000 (no deck). 1.3 drew 649–664 too (tokens, effect
  pseudo-cards): ours never. The `trade` byte and the Trade button
  (`BuyTownSpecialCardOffer`), the card hints (`Hints.txt`,
  `FindHintPairIndexForOfferCard`) and the bazaars' `BuyAnyCardFromTown`
  are read and not built. (2026-10-28: built since — the trades, the hints
  and the bazaars, 0.50.52; `CardTrade`, `CardHints`, `CardShop`.)
- **The price** (`CalculateCardShopPrice` 004f1cce): see `CardValue`'s doc;
  town `× (type + 2)`, off-colour ×1.5 when compatible (colourless
  always), else ×2, then `⌊/50⌋ · 5` within 5–1000; sold (`SellPrice`
  004f1bcc) ×4/3 compatible, ×3/2 otherwise, unless exactly the tile's
  colours, `⌊/50⌋ · 5`. Rarity from `Concise.csv` (else `Info.csv`'s
  "Occuran."), special for 0x180 and Astral (`GetCardRarity`).
- **The program's own numbers**: `tools/import_original.py`
  `import_card_values` finds the card table in the player's
  `Shandalar.exe` (or `Magic.exe`) by its five basic lands 72 bytes apart
  (1.3 at file offset 0x192608, the Manalink `Magic.exe` too), names rows
  from `Info.csv` by card id → `adventure_cards.json` in the skin (654
  cards). With it 653 of 654 prices equal the decompilation's formula on
  the decompilation's data; the one apart, Mana Crypt, is the row whose
  hand-tuned value the decompilation reads −2 and the program holds 1.
- **The formula for cards the program never had** (studied with numpy,
  pandas and scikit-learn in a scratch uv environment, ten-fold
  cross-validation, the 339 cards a 1997 shop can sell): the 1997
  structure on the card's own inputs, the hand-tuned value at its type's
  usual: median 20% off, 59 in 100 within a quarter, 79 within a half
  (with the 1997 rarity and no staple: 14%, 71, 89). Rarity agreement:
  first printing 86%, Fourth Edition 76%. The hand-tuned values follow
  nothing read off a card: rank correlation with the engine's rating
  (`AutoDeck.score`) −0.15 to 0.21 by type; ridge on all features of
  the price 40 in 100 within a quarter, the structure times a fitted
  correction 51, gradient boosting (an upper bound, no formula) 47, a
  compact formula 33 — none beat the structure. Ours adds half a step of
  the hand-tuned value per two median deviations of the engine's rating
  from its type's middle (`STRENGTH_MIDDLE`): 56 in 100 within a quarter,
  79 within a half — abilities count for pack cards, at three in a
  hundred of the match.

## Built: trades, the seller's hints, lairs (2026-10-23)

The owner: *"Build all trade features and lets iterate on card formula
more! Maybe we can design a better option?"*

- **A town's trade** (`BuyTownSpecialCardOffer` 004f18c0,
  `BuyAnyCardFromTown` 00530b90, `RunCardBrowser` 00532aeb): the colour
  wanted is rolled once per visit (199 draws of `rand(5) + 1`, the last of
  the land's colours winning — after draw 80 any of them: one draw among
  the land's colours); the button (towns and cities only) needs an amulet
  of it, `trade != 0` and `now − special_card_restock_timer > (d + 3) ·
  18` on the quest clock (−1000 at first); it stands before "Begin a
  Quest" and the wise man; closing the browser restarts the wait, traded
  or not. Cards: below `g_card_count − 57`, not `extra & 0x900`,
  available; a colour town by colour bit, a type town by type bit
  (instants with interrupts); no copy limit (at the limit drawn grey).
  Price `GetCardRarity` amulets, +1 for a 0x400 common, basic lands four
  for one; only the town's colour spent. Our browser: chips for 1997's two
  columns (its colourless rarity column replaced by an Artifact chip) and
  a name search.
- **The hints** (`LoadTownHintMetadata` 004184d2,
  `FindHintPairIndexForOfferCard` 0041879d, `ShowTownHintTextPopup`
  0041905e): `Hints.txt` 245 entries (243 pairs, 2 singles), A–D bits for
  the difficulties; per offered card a random candidate (the offer one of
  a pair whose other card is owned, not both owned); one random offer with
  a hint; "Buy Cards/Card Hints". Mended 1.3 slips: singles never shown
  (`result_hint_pair_index` lost), the hint not cleared on purchase (the
  pair index stored as the offer slot), no hint on re-entering the same
  town. Imported as `adventure_hints.json`.
- **Lairs** (`UpdateWorldLairAndMonsterSlots` 0055fd27): see
  `WorldLairs`' doc. A lair is drawn within a tile of the hero
  (LOCATN07 `{0,4,0,3,2,1}[colour]`, ground half +6, at −(64, 96)),
  entered under 26 in `ApproximateDistance`; slot emptied, its respawn
  stamp now, `g_monster_timer |= 0x1F`, saved before and after.
  Creatures: until the duels a creature's draw holds its slot unseen (no
  type picked, never met), so lairs come as often as in 1997; Staff of
  Thunder passes them by.
- **The events** (`RunLairExplorationEvent` 0052fae0): see `LairEvent`'s
  doc; the riddle `RunCardRiddleChallenge` 00534530 in `CardRiddle`'s.
  Pre-rolled each lair: the lair's rare (`reward_cards[3]`, rarity exactly
  3: 2/3 a non-artifact of the colour, 1/3 an artifact; its common and
  uncommon pre-rolls unused) and the Oasis card (a collection card of
  rarity ≥ 2 — 1.3 tested availability on the slot index and looped
  forever without one: ours offers none). The 25% `PickRandomRareAvailableCard`
  (rarity ≥ 3, special too, even a dungeon card) is set as the fourteen
  begin and given at the end unless replaced: Thieves/Lost City luck clear
  it, their thieves replace it, a right riddle replaces it (Loremaster's
  and the Ruined Tower's fallback: the lair's rare; the Pyramids: any
  rare). Ours names the five treasure lairs by the five unshown names, each
  to the colour it names (graveyard black, lagoon blue, glade green,
  volcano red, hallowed ground white — 1997's order is B, W, R, G, U).
  The four duels (9 Shrine `RunRandomCreatureAnteDuel(8,2)` or `(13,3)`
  past siege 256, 10 Dragon `(18,4)`, 11 Sultan King Suleiman + `(13,2)`,
  13 Arena a copied creature `(16,3)`) and 16 the Ghost's deck view wait
  for the duels.
- **Names**: 51 rows of the 1997 card table are not the engine's names —
  case, marks and accents (bridged by a key) and 19 misspellings
  (`CardValue.SPELLED_1997`); ten are tokens or empty rows. Without the
  bridge those cards lost their exact price and their hints.
- **The formula, again** (scratch uv study, ten-fold CV): type defaults
  tuned on the 1997 prices (creature 1, enchantment 0, sorcery 0, instant
  −1, artifact 1; the type's commonest value had priced creatures and
  sorceries a fifth too dear, the rest a fifth too cheap): 60 in 100 within
  a quarter, 82 within a half (held out 59/82), staples at the 53rd
  percentile of their type and rarity. Tried and left: a larger ability
  step (49–45), a continuous step (57/76), a multiplier on strong cards
  (≤ 58, staples no higher), a multiplier above a threshold (56–59, staples
  at ≤ 45th), re-tuning all eighteen constants of the structure (held out
  58/77 — and the fit came back to 1997's own: ×1.5 per keyword class,
  ×3.3 per pump, 253 for artifacts, ×2 uncommon). The structure's
  constants are right; only the type defaults moved.

## Built: part A — the towns' life (2026-10-23)

The owner: *"Yes do the A and do it with quality and meticulously —
implement features in code modularly so they can easy be reused and
accessed and that are commented and structured to be humanly readable!"*
Rulings: the world's sound *"Soundscape + title music"*, the saves *"Add 10
named slots"*, the wise man's two dead gifts *"Enable them"*.

- **Status bits** (`status_and_ruling_wizard`): 0x01 the mana link, 0x02
  visited, 0x04 a failed quest (the wise man refuses for good), 0x08
  1997's shop stocked, 0xFF00 the ruler; 0x10–0x80 unused in 1.3. All read
  and written through `TownStatus`. The generator's "unread" bit on the
  first ten towns and cities is the hero's ten starting links; the duel's
  life is the count of linked, unruled towns and cities
  (`CountDuelPoolEligibleTowns`). `AdventurePlayer.mana_links` the array
  is gone (old saves' sites already carry the bit).
- **Quests** (`Quests`'s doc): deliveries built — letters for a link or an
  amulet, cards of a colour and class; generation only on a visit to a town
  other than the last; `(d + 3) · 16` steps between a town's quests. The
  creature branch (towns and cities always, a third of villages) waits for
  creatures: no offer there yet. Ours: the giver, the offer, the last
  town, each town's quest time and the wise man's stage are saved (1997
  kept them in memory); a card quest takes a card no deck holds first;
  white's blank spell word mended; the failure keeps 1997's text and bit.
- **The wise man** (`WiseMan`'s doc): the stages and odds of
  `RunWisemanAdviceSequence`; tales and news from the player's
  `Advblocks.txt` (`adventure_wise_words.json`); the six gifts by
  `GIFTS[x % 2][y % 3]` (1997's four where it gave them, the companion and
  the copy on the two places that gave lives and a clue again); the copy
  only with three amulets, taken once a card is picked; the news fixed
  (fair picks, the real castle life `max(20 + 5d + 10 − wins + towns · d,
  5d + 20)`, the towns the wizard holds).
- **World Magics** (`WorldMagicShop`): on leaving any town or city, the
  nearest unowned World Magic (2·max + min, ties to the lower index): an
  advert ("Travel West to …") or, in its town, the offer at half the table
  (400, 500, 350, 100, 400, 750, 200, 250, 300, 150, 300, 600); bought, its
  seller cleared and "Bought WM: %s" journaled. On `Worlbak1.pic`.
- **The city list** (F3, `CityListPane`) and **the map** (F2, `WorldMap`):
  on their own 1997 screens (`Cityinfo.pic`, `Infobar.pic`, `Mapback.pic`,
  `Mapbttns.pic`, `Ttsprite.spr`), the layouts and inks as specified;
  ours: the wheel, Escape closing the map, a black wizard's towns dark grey
  (1997 drew them black on black), the map hides the panel while open,
  and the journal walked on the map (1997's stats journal, map mode 4)
  from the Hero pane's Journal tab.
- **Town entry and leaving**: on arrival the quest completed, "Completed
  quest at %s" or "Visited %s", the visited bit, the favoured colour, a
  new quest if another town, the shop and the hint; on leaving, the last
  town, the World Magic offer, `monster_timer |= 0x1F` and the autosave.
- **Saves** (`SaveSlots`): `<id>.slot01`–`slot10.json` with their names
  inside, the autosave as 1997's slot 3 (Resume); an older `.save.json`
  becomes slot 1. Leaving, Exit and the window's close write the autosave.
- **Sound** (`WorldSoundscape`): footsteps, calls, the places' tunes by
  `clamp(128 − d, 0, 100)` (0.4 dB a step), clicks and stings, the title's
  tune 12 dB under the world and 12 more under a place's tune at full
  voice; the sounds' own dice (not the world's); calls let ring.
- **Polish**: the quest clock (`Clocknew`, `Sunmoon`, `Daysnew`) and the
  next duel's icons (`Worlds.spr` 56–59) on the quest pane; the reveal
  dissolve (16-pixel squares, 0.6 s) on a new adventure, Leap of Fate and
  Sword of Resistance; 1997's palette fades (8-bit modes only) left out.
- **Also**: the Guardian's Ghost shows a creature's deck (`CreatureBook`,
  `CardListPane`); every pane's look in one place (`PaneStyle`); the card
  shop's price tags lit by rarity (black on white, silver, gold, purple —
  the owner's).

## Campaign: bugs, smoothness, robustness (2026-10-23)

Owner: *"Implement the same 1997 here … it could only be edited in towns, or
outdoors with Conjurer's Will ! And after do one bug-hunt and bug fix and
smoothness of gameplay and robustness campaigns!"*

- **The spellbook only looks** (`AdventureBuilder.looking`): 1997 opened
  the builder three ways (`DeckBuilderMain(…, 1, flags)`): F1 with no card
  moves (`adventure_input.c` 368), Conjurer's Will with moves (444), a
  town's Edit deck/Sell cards with moves and selling (visitLocation.c
  1030). [Ours: 1997's F1 cast Conjurer's Will itself when owned; here F1
  only looks and the cast is the World Magic's own.]
- **Six read-only hunters, seven fixers on disjoint files**; 62 findings
  (5 HIGH: the shop's click freed its own card mid-signal; a trade paid
  with amulets spent meanwhile; the hero stuck for good on a sea corner a
  diagonal step had grazed; a failed save write destroyed the autosave;
  saving inside a lair let it be entered again).
- **Rulings** (the lead's, from 1997's modal town menu): a place's pane
  is modal — the panel shows but waits (`WorldScreen.modal`, the
  PaneShield, `WorldHud.rest`); the map is modal (its keys, Escape,
  Ctrl+S); a lair is spent the moment it is entered (`WorldLairs.explored`
  in `enter_lair`, before the autosave); M on the Main Map closes the map;
  shops restock and the seller hints only in a town other than the last
  (visitLocation.c 1685/1689); non-basic lands sold as 1997's flags allow
  (Mishra's Factory, Strip Mine), basics only in the land place [ours]; the
  journal stops at 10,000 lines [ours, owner "extend that"; 1997's
  `AddJournalEntry` stopped at 2,000] — the record is counted from it, so
  the oldest never go; the limit bounds a save's cost (~4 ms to save and
  ~8 ms to load per thousand lines, measured).
- **Saves**: written aside and renamed over, read back byte for byte, the
  previous file kept as `.bak` and taken up when the save is damaged;
  `from_dict` reads every field through typed readers; the lists cache by
  path, size and hash; slot files read by name; the autosave carries no
  slot name; a failed save is told, and Exit asks.
- **Smoothness** (measured): towns 33 → 1.4 ms at 600 cards (deck counted
  once), the first shop 131 → 30 ms (facts cached, pack cards skipped),
  save/load lists 86 → 4 ms, the hero pane's food step 448 → 0.3 ms at
  2,000 journal lines, the open map 0 paints a second when still (the
  blinking hero is its own node), the adventure builder's later openings
  83 → 55 ms (no whole-library first fill).

- **After the campaign (owner, 2026-10-23)**: the journal's limit raised
  to 10,000 lines; the first deck builder of a session warmed — its card
  pictures decoded on a worker thread a second after the world opens
  ([CardArtWarmer]; measured: the first F1 210 → 89 ms to open, its first
  five frames 290 → 172 ms; later openings ~27 ms; the filter bar (22 ms)
  and the builder's tune (20 ms) are still read on the first opening);
  the adventure builder's sideboard strip became the worth strip (what
  the card under the mouse sells for here, or the range out in the wilds;
  the best price among places visited; copies owned, in the deck, to
  sell). Then a bug pass (four read-only reviewers, r1-r4): 14 findings,
  1 MED (look-only's side doors: the complaint line's Remove Extra Cards
  and the artwork picker), 13 LOW — the warm's printing table off the main
  thread and its cards in the builder's order; Undo/Restore after a sale;
  the Sell button following the deck; Consolidate a view; the pointer read
  where the land is drawn (`WorldView.unproject_drawn`); no pointer read
  under a pane a walk's last step opened; a second Escape on the Load list
  taken; the slot name box focused only while there; quests, offers, the
  wise man and victories read by kind; the small map's culling box a slide
  wider; the worth range over the lands the generator makes
  (`ShandalarWorld.LANDS_MADE`). Each fix has a test that fails without
  it. Found faithful, left: a starter deck may hold three of a spell
  (1997 checks copies for creatures only), which the builder then flags.

## Built: part B — the creatures and their duels (2026-10-23)

The owner: *"lets crack on to work package B!"* — the gap audit's B (the
creatures, the meetings and the duels with them, and what the duels
unlock). Specs from four read-only researchers on the 1.3 and retail
decompilations; built in three stages by seven builders on disjoint files.
Rulings (2026-10-23):
- *"1997 as played but fix clear slips to what was obviously meant. Each
  fix marked. But document abundantly all designed features … so they can
  be implemented later. Comment also how each of these features can change
  the game!"* — dead 1997 code stays dead; each such feature is in
  `docs/adventure-unused-1997-features.md` (what 1997 computed, why it never
  took effect, what it would change, how to switch it on) and in its
  module's doc; each slip fix is marked `[ours: 1997 slip — …]`.
- The creatures are drawn over their whole 4-tile range [QoL] (1997:
  within 1 tile of the hero).
- The creature decks are exact 1997: the maindeck, plus the hero's
  colours' sections once a colour of creature has learned the hero's deck;
  `.vNone` never (only the title demo read it).
- Quitting mid-duel is as 1997: the autosave made as the creature is met
  keeps it on the map; reloading meets it again.

- **The table and the decks**: `CreatureBook` (the 57 rows with their flags
  by name, strength, bribe, the duel's lives, `pick` — 1997's 999 draws on
  the adventure's dice —, the sprite and cry keys), `CreatureDeck` (the
  maindeck and the colour sections read from the deck files' tables, the
  creature's ante draw, the 0179 fallback). Our 55 lists match the
  1996-09-27 `.dck` files in the owner's install card for card.
- **The map**: `WorldCreatures` — 1997's eight slots (six roaming, the
  siege's seventh), the refill on the ring four tiles out (tiers by the
  hero's experience, the respawn wait, the gates), the movement (always at
  the hero, led by difficulty, fleeing at d + 3 wins, the 8-way quantiser
  and its 4-tick cadence, the colour stop), contact at 16 (lairs 26), the
  cries, the push-back on entering a place; drawn by `WorldView` with the
  hero ("movers") from the player's imported sheets (81).
- **The meeting** (`CreatureMeeting`, `EncounterPane` on `EncounterStage`):
  the antes, the words by relation and wins, Duel / Pay / Riddle / Change
  ante / Tribute, the special meetings (Summons, First Strike, a card in
  play, Try this deck, Mind Control); the duel set-up (the hero's life =
  links + next-duel lives; the creature's by `duel_life`; the deck padded
  to 30/35/40/40 — the code's numbers, not the manual's —; the coin toss;
  1997's mulligan; the player's own rules options); the duel held over the
  world (`WorldDuels`, `DuelScreen.held`); the spoils (`DuelSpoils`: the
  victory log, the journal, the quest, the reward cards by strength, the
  dungeon-clue plaque, the amulet, the reward bits, the colour learning,
  the lost ante, the draw).
- **The engine** (opt-in, every other duel as before): `DuelConfig`
  `ante_cards`, `ante_extras`, `first_player`, `start_in_play`,
  `mirror_seat0`, `mulligan_rule = "1997"`, `ai_random_play_or_draw`;
  `DuelReport`; `HeadlessDuel` for tests.
- **What the duels unlock**: the four lair duels (`LairDuels`), ruled towns
  and freeing them (`RuledTowns`, `RuledTownPane`), creature quests
  (`Quests`), the sieges (`Sieges`: the clock, the news flash, the town
  falling, the lost link, the taps, Dominion), the end
  (`AdventureEndScreen`: Dominion, or no card to stake — back to the title,
  the saves untouched, as played).

Slips fixed (each marked in the code): the flyer's cry plays `Flying.wav`
(1997 asked for a `flyer.wav` never shipped); a cry pans by where the
creature stands; only live creatures block one another; the spawn tick's
distance is read at the new place; a slot emptied by the colour stop is not
met; the lurk test is centred on the hero's feet; slot 0 is held for the
quest creature only while its quest runs, and that creature neither flees
nor stops spawning (1997 could make the quest impossible); the bribe is
not hidden for the bag's first card; tribute jewels are of the colour the
words name; the quest creature's tribute reads "Duel this %s"; the
henchmen's hand modifier is 0; Mind Control only when announced; the deck
filter survives Summons and Try this deck; Escape at the cards/clue choice
takes the cards; Escape at a riddle waits for an answer; the reward may
exceed ten cards; the copy staked is the copy lost; a castle wizard's three
stakes are three cards; the besieger's words name its town; the hero's
deck colours are counted fresh at each meeting; a draw changes no cards
anywhere (a lair draw won the hoard, a ruled-town draw lost the stake); the
Spectral Arena fights a random creature as a Spectre (its own deck and
face, 16 + 2d life; 1997 copied it into row 56 and never picked it); the
ruled town's words name the creature; a ruled town's stake is capped at
the cards there; every ruled-town stake stays out of the deck after the
mulligan; the besieged town is the one that falls (1997: the site nearest
the creature); a wizard past the taps casts Dominion; a retaliation with
no castle and a siege with no town start nothing; a quest creature the
pick cannot find gives no quest; "Acquired spell" is written only for a
card kept; an unknown card drawn for the creature's ante is drawn again.

Ours: the entry latch (the place stood on opens again at a click, our QoL,
but is no new arrival: no push-back, the ruled town's creature and stakes
kept); the news flash stops the walk; the Hall of the Sultan says "(King
Suleiman starts in play!)" with 1997's own `@DUNGEON` string; the save as
a ruled town's duel begins; a reward line in the quest pane; a tribute's
payment shown with a Leave; a henchman's defeat shown; the ruled town's
pane laid out side by side; siege_count saved (1997 never saved it); the
wizards' window after a win or a fall is not shown (1997's
`ShowStatsWindow`; the hero pane's Wizards tab holds the same — the owner's
ruling B-3/B-4 of 2026-10-27: it never opens by itself; F6 and the Wizards
tab show it, with 1997's Statwin stills since 0.50.60). A place's
pane fits itself again as it is resized: a test caught the wise man's
"whose deck" with big buttons held at 843 px of 800 under load.

The bug pass of part B (four read-only reviewers, q1–q4): 6 MED, 13 LOW,
all fixed with tests that fail without the fix — the entry latch now holds
only the place the hero ARRIVED at while still on its tile (a town stood on
but never entered — a walk stopped on it, a teleport, a town just freed —
is arrived at by the click; leaving and coming back is no reroll), and a
ruled town opened again reads the hero's stake anew; a duel already won is
not turned into a loss by Exit duel; a double click answers no riddle
unseen; the quest's deadline waits for a step's news and the place it
reached; the reward pick's result is said on the town's pane; every card
the hero gets goes through the bag (the shop, the lairs, the trades and the
wise man's copy too; a full bag refuses a paid card [ours]); without the
player's card table a reward type no card has is drawn again (no interrupt
is typed then); the spawn ring draws its side's sign before the offset, as
1997; two part B suites no longer need the skin; the unused-features page
corrected against the decompilation (and a seventh creature on the hard
levels added).

The copies in a deck (the owner, 2026-10-24, on a first deck dealt with
three of a spell): the adventure's builder judges as the 1997 deck builder's
code did (deckdll `check_card_count`; `DeckModel.copies_allowed_1997`) —
three copies under 59 cards, four from 59, Tome of Enlightenment one more
and no limit from 59, basic lands aside — not the manual's table (two at
20–39), which the 1997 builder never applied; checked as the builder is
left (Done, Return to the world, Exit game), with the 1997 Extra Cards box
(Remove Extra Cards / Edit Deck); nothing before a duel checks copies. The
first deal checks copies for creatures and the rare only, as 1997's. The
acquisition cap (`GetRemainingAllowedCardCopies`: 1 under 40, 2 from 40, 3
from 60, the Tome +1) is the player's choice at the Embark (the owner,
2026-10-24: "This should be an on off setting during shandalar embark
construction!"): Your rules › Copy limit — on, as 1997 meant it (the shop,
the rewards and the trader's dimming count the deck in use's copies); off,
as 1997 shipped it (its count matched no owned card — every entry carries
a deck or no-deck flag — so none is counted and only its special and
outside-the-base-sets cases stay); `AdventurePlayer.copy_limit` (saved;
older saves on), `CardShop.counted_copies`. The starter's creatures are
checked as 1997 did either way (the count worked during the deal).

Open for part C: the castles' and dungeons' insides, the castle wizards'
duels, a beaten wizard (`Sieges.free_all` ready), the retaliation siege
(`Sieges.start(player, wizard)` ready), Arzakon, the end score. The 2×
skin built on 2026-10-24 holds the part B sheets and pictures, worn and
looked at in the running game; the upscaler invents marks on two kinds
of picture (the frame studs and the plain red field of `preduel_frame`,
the dithered world ground), which pixel doubling as for `panel_stone`
would keep at the 1997 grain.

## Built: part B played and fixed (2026-10-24)

The owner, after 0.50.54: *"do a playtesting campaign and a bug find bug
fix campaign over B workpack features"*. Four played the running game
(about 1,000 meetings over 26 adventures, some duels played out computer
against computer; six long siege runs, about 90 sieges, 55 falls and two
Dominions; every lair event; every part B screen at four sizes in the
1997, the 2× and no skin, with the big buttons, the keys, the mouse and
touch) and three read the code (the duel engine's opt-in changes, saves and
races, the rest of the 0.50.54 diff). Nothing was lost or doubled, no save
failed to come back, and the game itself printed no error; the ordinary
duels, gauntlets, Deck Lab, Test hands and LAN duels were untouched by the
opt-in engine. What was found and fixed:

- **Fidelity.** The cards won took the colour test the other way round
  from 1997 (`is_card_color_compatible_with_mask(1 << monster_color,
  card.color, level)`, E:2282–2284; the table is lopsided): a green
  creature gave white cards, a white one never green
  ([method DuelSpoils.reward_cards]). The black wise man's companion was
  spelled "Khabal Ghoul" and never came to the duel (the registry's
  "Khabál Ghoul"). A lair's rare ignored the copy limit; with it on, a
  candidate with fewer than no copies left is thrown back as 1997 did
  (E:997–1001, [method LairEvent]). The trader dims by 1997's own
  allowance (`GetRemainingAllowedCardCopies(card) <= 0`, visitLocation.c
  3822: basic lands always lit, the cards outside the base sets halved) and
  writes "-N" only after a card the hero owns (3804–3808). The plaque of
  the clue told keeps the word it was asked with (E:2336–2356).
- **Keys and clicks.** A key pressed in the half second after a pane
  closed reached the world (one Escape too many left for the title, a digit
  cast a World Magic): the world hears no key while the pane's shield is
  up, the map's own keys aside. A double click's second press no longer
  answers a place's pane (a town, a ruled town — a duel never chosen —, the
  news flash, a lair, the wise man) or skips a lost card's picture, as the
  meeting's pane already refused it (q2-2). The end screen's button waits
  its moment as a click or a key does.
- **The held duel.** Return to main menu (or Exit duel) on a duel already
  over keeps its result: the spoils are shown, then the adventure is saved
  and left ([method WorldScreen.leave_after_panes]); the two doors say so
  once the duel is over. A lair's duel asks a lair's questions: nothing is
  staked, so Concede loses no ante, and the menu does not promise the
  creature again (the lair is spent as it is entered). A duel over as it is
  dealt (a hero at no life) reaches its pane (its end deferred while it is
  dealt). [Ours: 1997 slip] a ruled town's duel rests the town's tune, as a
  meeting's and a lair's do — 1997 played both tunes at once.
- **Saves.** Closing the window under a news flash saves nothing (it held
  half a tick; the last save stands and its dice bring the news again).
  The autosave made as a creature is met with no card to stake is kept, as
  1997 kept its slot 3: that adventure has ended, and opening it ends it
  again.
- **What is said.** [Ours] what a full bag loses is said: the cards won
  (named), the reward card, a lair's find, the wise man's copy — whose gift
  turns into the lives when the bag is full, as with too few amulets — and
  no "any card" list is forced on a full bag. The panel follows what a
  meeting pays at once.
- **The look.** With the big buttons the meeting's and the ruled town's
  page was held at two thirds by a guess of the words' room (300·k, 260·k):
  it now takes what the words and choices really leave, and [ours] keeps
  its size from step to step, giving way to more words, never swelling
  back. Without the skin the quest scroll is lettered in the panes' ink,
  the purse's four boxes stand apart and say what they count, the creature
  is a disc of its colour and the amulet a rimmed stone.
- Marked, not changed: [ours] the creatures' turn ends at a meeting
  ([WorldCreatures]; 1997 went on through the later slots).

## Built: the Classic MTG rules, a third card rule (2026-10-24)

The owner: *"I want to add one more rule as an alternative to Adventure
limit o cards (as intended in 1997) and No limit (as shipped in 1997) to the
depart menu - also classic MTG rules (max 4 same cards in deck, limited
cards as per rules only one per deck). Traders stop offering the cards if
you have 4 copies all-ready in your possession"*, *"Also name the rules as
i named them!"*. The Embark's copy limit became one choice of three, named
as the owner named them ("CardRule", [member AdventurePlayer.card_rule]):
"Adventure limit of cards (as intended in 1997)" (the copy limit on, the
default), "No limit (as shipped in 1997)" (off) and "Classic MTG rules"
[ours]. Saves keep the rule; a save or a remembered choice from before it
keeps its on/off limit, and a save writes that limit beside the rule (on for
the classic rules) for an older game to read.

The classic rules, by the owner's rulings: a deck holds four copies of a
card, basic lands aside, one of a restricted card and none of a banned one
(`DeckFormat`'s lists, the ones the duel setup's Restricted (Type 1)
format reads); with Tome of Enlightenment a restricted card four times, a
banned one still never (*"No my mistake, banned are not allowed.
Restricted to 4 copies!"*). The adventure's deck builder judges by them
([constant DeckModel.CLASSIC]) and asks as it is left, as under the 1997
rule — adding is never refused. EVERY source stops offering a card once the
hero owns, in any deck or none, as many copies as a deck may hold: the
shops' draws (and a card already on a shelf is not sold then), the
traders' lists (the Bazaar, a town's trade, a quest's reward pick — listed
only what the rules allow, so nothing is dimmed), the cards a creature
gives (counting the copies the same reward draws), its reward card, the
any-card and duplicate picks, the tribute's spell, a lair's rare and its
treasure, the wise man's copy, and the first deck dealt. A creature's stake
won — the lairs' hoards, a freed town's prize — is never limited.

## Decided: the world's last pieces and part C (2026-10-27)

The owner: *"We will make any key decision together - 1997 bugs, the shape
of the end, the world…etc. we will improve the original game and make it
robust, fun, bug-less and modern smooth feeling!"* The decisions below were
taken with the owner in eight rounds of questions, on research specs read
from the 1.3 decompilation and checked against retail. Each fix of a 1997
slip is marked `[ours: 1997 slip — …]` where it is built; our additions are
`[ours]`/`[QoL]`.

**The world (built in 0.50.60).**
- A dungeon is drawn on the world once the hero holds any clue to it, even
  on land not yet seen [QoL] (1997 drew it only inside the explored window),
  and marked on the small map [QoL]; a dungeon that moved after a visit keeps
  showing, as in 1997. The F2 map shows none, as played.
- Escape or Q with nothing open asks "Ready to Quit?" (1997): Yes saves and
  leaves, No or Escape stays.
- Entering a castle or a dungeon empties the roaming creature slots 0–4, as
  1997 did; leaving never wipes the next-duel gifts the world gave
  [ours: 1997 slip — the board's exit cleared them, duel or none].
- Stepping onto a known dungeon opens its pane, "Enter the dungeon" /
  "Leave" [QoL] (1997 entered at once); coming out autosaves [ours].
- The first deck is exactly 1997's: the extra creature copy (36/40/46/46
  cards from Apprentice to Wizard) and enchantments only as its coloured
  spells, as both releases dealt.
- The wizards' window: 1997's Statwin stills imported (each wizard, his
  staff, his gems), no movies; it never opens by itself (after a win or a
  fall); F6 and the hero pane's Wizards tab show it.
- Keys: Save stays Ctrl+S (W A S D keeps looking); while the hero pane is
  open W / J / D switch its tabs; a right click on the world opens the
  options (1997's "Will you…" menu); a question's choices answer to their
  first letter; F6 the wizards; L loads.
- The record's creature page: 1997's creature pictures and inks for the
  creatures met, with a switch on the page itself to show the whole grid,
  never-fought creatures as blank cells.
- The journal on the map opens on the newest line [ours]; the city list (F3)
  lists the castles the hero has stood before [ours; 1997's rows were never
  reached].
- 1997's transitions (the backdrop's zoom-in, the castle's staggered tiles,
  the visit overlays, the tile reveals) are back: short, skippable, on by
  default, with an Options switch.
- Kept as played: the 199 draws for the favoured colour (same odds); the
  retaliation siege is wired behind the board and comes alive with it.

**Inside castles and dungeons (part C).**
- A castle's duels each start fresh, as 1997 played (the second castle rule
  zeroes the life carried): the hero's life plus the dice's lives found
  since the last duel. A dungeon carries its losses (rule 0x01).
- A draw in a room is no result: the hero is pushed back, the creature
  stays, the stake is kept, nothing is written [ours: 1997 slip — it counted
  as a win] (as 1.3's draw with a castle wizard, and part B's "a draw changes
  nothing").
- A beaten castle wizard counts in the victory record and pays the end
  score's designed +25 [ours: 1997 slip — never paid]; room wins stay out.
- Fixed 1997 slips: a dungeon lasts while any of its cards remains; the
  stake is drawn only from cards the dungeon allows; the deck's minimum is
  counted after a ban, padded with allowed basic lands; the dice never give a
  banned card; nothing hangs (the maze generator's endless case about 1 entry
  in 2,500, the dice with no creature or artifact in the deck); a dungeon
  moving away never lands on another; a large dungeon's clue says "large";
  "No black cards" bars gold black cards too.
- A dungeon card found with a full bag offers a swap in the deck builder.
- The board: a rounded pane over the world, at most 1.25× the 1997 page.
  Moving: 1997's Home/PgUp/PgDn/End plus the arrows and W A S D turned to the
  diagonals, the keypad 7/9/3/1, a click on a neighbouring room, a click
  along a seen straight corridor [QoL]. Helpers [ours]: a creature's name on
  hover, "Leave?" asked first, the life carried shown, the rooms left shown.
- Saving: an autosave at the door; quitting inside puts the hero back at the
  door, a new maze next time.
- Before a room duel a pane shows the creature, its minion, the card in
  effect and the hero's stake [ours]. The clue screens become a rich pane:
  1997's icons, the cards' pictures, the creatures' faces, "Show on map".
- A castle wizard beaten: his room still, the castle-win words over the
  trade backdrop, the three card picks, a news line for the freed towns.

**The end (part C).**
- When the fifth wizard falls Arzakon appears and asks: face him now, or
  return to Shandalar first; returning, a portal stands on the world (a
  guide arrow, a quest line) for the hero to enter when ready [ours].
- A lost final battle ends the quest (1997's quest-failed end); the win
  screens, the stats and the score only for a real win [ours: 1997 slip —
  the result was never read]. A setting at Embark: "Reload allowed" (an
  autosave at Arzakon's door) or "One life" (the loss closes the adventure).
- The win: 1997's movie (converted by the importer where the machine can,
  skippable), the win picture, the words, the stats, full screen; the win
  tune plays once; the duel names him "Arzakon".
- After the win the hero chooses to end, or to return and roam: the owner's
  words, *"If you return to roam you can still explore only other cretures
  do not hunt you always, some do not or are passive and do not cocer towns
  etc - the game is passive just letting you battle creatires or explore the
  unexplored. The Arzakon portal is shown as petrified monument!"* The
  adventure is saved and marked won with its score.
- A Hall of Fame of won adventures (name, face, colour, difficulty, score,
  days, wins, date), best first, after the win and from a button inside
  Save / Load, never on the main menu (the owner: *"Only hall of fame button
  should be inside save/load as not to clutter the main menu!"*); the
  score so far shown on the hero's record. The score counts the sieges over
  the whole adventure and its small slips are fixed (the final years added
  after the floor at zero, no stale stake in the final battle, the movie
  centred).

## Built: the world's last pieces (0.50.60, 2026-10-27)

Built to the owner's decisions above ("The world"), by three builders on
disjoint files, from a research spec read in the 1.3 decompilation and
checked against retail.

**Dungeons on the world** (`WorldClues.on_world`, `WorldView.dungeons`,
`WorldMinimap`). 1997 drew a dungeon only where the hero's explored window
reached; ours draws every dungeon the hero holds any clue to, with 1997's
own sprite, over unexplored land too [QoL], and a dot on the small map
[QoL]. A dungeon that moved after a visit (its clues `(c & ~1) | 6`: where
it lies forgotten) still shows, as 1997's did. Hovering names it.

**The doors** (`DungeonDoors`, the class header tells the whole story).
Going in: the journal ("Explored %s", "Entered %s (%s)"), the slot's
`entered` count raised (1997's `times_entered`, which started at −1 and was
raised first thing on every board — ours counts the entries, 0 at the
start, saved), roaming slots 0–4 emptied. Coming out: the next-duel gifts
kept [ours: 1997 slip], a dungeon moved to a fresh tile — never onto
another dungeon or under the hero [ours: 1997 slip], never forever (a
guard) — and, on Wizard, a castle left unbeaten sends its retaliation
siege at once (`Sieges.start`). The world screen's seam (`_enter_board`,
`_board_done`, `_open_board`) holds the world under the board and autosaves
as the hero comes out [ours, the owner's D-3]. The two Enter buttons stay
disabled behind `DungeonDoors.BOARD_READY` until part C's board exists;
the tests stand a stub board in. Castles are marked visited as their pane
opens (the city list reads it).

**The keys** (`WorldScreen`, `WorldHud.KEYS`). F6 the wizards; L loads;
Escape or Q with nothing open asks "Ready to Quit?" (1997's words, "No." /
"Yes."; Y and N answer, Yes saves and leaves); Space stops the walk and
looks back at the hero; a right click (or a long press) opens the options
at the pointer, 1997's "Will you…" menu; while the hero pane is open W, J
and D turn it to the wizards, the journal, or close it. Save stays Ctrl+S
(W A S D keep looking). The options list "Load (L)" and "Wizards (F6)".

**The wizards' window** (`HeroStats` Wizards tab, `WizardsPicture`,
`WorldStatus.wizard_rows`). 1997's Statwin stills, imported by the
importer's 24-bit BMP reader (`STATWIN_PICTURES`, 35 keys): the throne hall
with each wizard; his staff drained by `30 − min(wins, 10 + d · towns)`
steps of 1997's bands as the hero beats his creatures; his mana gems; the
skulls of the hero's wins (1997's steps 1–5, 8, 12); a ring round the
wizard chosen; below, 1997's table — life in his stronghold, mana domes,
won against, beaten. `Statscrn.wav` plays once as the window opens, never
as it is only drawn again. A beaten wizard's castle clicked on the Hero
page opens his room. It never opens by itself (B-3/B-4); without the skin
the tab is the table alone. Not taken: the movies, the *-Mask erasers,
`Room-Mon.bmp` (unused-features doc).

**The record's creature page.** 1997's `Creatures640.pic` cells
(`creature_thumbs`) for each creature met with its wins and losses in
1997's own inks, on pale chips so they read on our glass [ours]; the page's
own "All creatures" switch shows the whole 55-cell grid, the never-fought
ones blank (the owner's G). The Hero page lists the castles with their
attempts ("Attempts at Each Castle", `DungeonDoors.entered`).

**Small pieces.** The next-duel line as 1997 wrote it, carried and gifted
lives apart ("Next Duel: -2 lives, +3 lives, First Move"; `QuestClock.gifts`
draws them); the map's silver ornament; the amulet panel's black corners
gone; the journal on the map opens on the newest line [ours]; the city list
glides and lists the castles stood before, their wizard, beaten or not, and
the attempts [ours — 1997's castle rows were never reached].

**The first deck, exactly 1997's** (`StarterDeck`). 36/40/46/46 cards; the
extra creature copy where both releases put it; enchantments only as the
coloured spells (see "New game in the sources"). The 199 draws for a
town's favoured colour stay as played: one even draw among the land's
colours (pinned by `test_q3_favoured_colour`; the amulet preference 1997
meant never worked — unused-features doc).

**The transitions** (`TileReveal`, H7). One small node for all of 1997's
picture effects, drawn by a shader with a byte per tile: a town's, the
wise man's, the news' and a dungeon's picture zooms in from a quarter size
(0.2 s; 1997's `AnimateVisitBackdropZoomIn` grew it in seven steps); a castle comes in by 1997's
staggered 32-pixel strips (three at a time, 0.5 s); a lair by random
tiles (0.4 s) with its card or hoard above at once; a creature's face and
a ruled town's face by 3×3 tiles (0.3 s). Any click, key, pad button or
touch ends it, and the press still reaches what it was for; words and
choices answer from the first frame [QoL: 1997 held 0.73 s after the
tiles]. On by default; "Transitions" in the Options screen and in the
world's options book turns them off; never headless, so no test waits on
one. 1997's visit overlays have no place: our panes have no frame.

**A choice's first letter** (`VisitPane.letter_choice`, C-5). On the pane
on top, a letter lights the next choice beginning with it (a gold rim);
Enter or Space takes it; a letter alone never chooses. A text field keeps
its letters; a letter no choice begins with goes on to the world. Every
place's pane, the lair, the meeting, the ruled town, the wise man and the
news.

**Tests.** `test_q1_*` (the doors, the dungeons on the world with and
without the skin, the keys), `test_q2_*` (the wizards' record, the hero
pane, the city list, the map), `test_q3_*` (the tile reveal, the favoured
colour, the transitions, the letters), and the first deck's counts and
order in `test_starter_deck`.

**The bug pass** (three read-only reviewers, one per builder's files;
no HIGH, four MED, the LOWs fixed too, each with a test where it can fail):
D that closed the hero pane drifted the view right while still held (the
letter is the pane's until let go, `WorldScreen._pane_letters`); Space with
the pane open closed it instead of stopping the walk (Space is the
world's again); A and S look while the pane is open (only W and D are its
letters); F6 opened on the ring and the room a beaten castle's click had
left, and the Wizards tab pressed again restarted `Statscrn.wav`; the
wizards' keyed stills, drawn scaled and filtered, wore a green fringe (the
clear pixels now take their opaque neighbours' colour, `WizardsPicture.
picture`); the city list reads the attempts through `DungeonDoors.entered`;
`WorldStatus.taps` with no world; under the Classic MTG rules an
Apprentice's deck came out a card short one deal in nine (the base sets'
one common artifact, Amulet of Kroog, refused a fifth time — the toss's
other side is dealt then [ours]); a click on a choice a letter had lit left
it lit for a later Enter (a lit choice is unlit as it loses the keys); a
slow frame before a transition ate it (a frame counts a thirtieth at
most); Leap of Fate read the screen back with the transitions off; the
World Magic seller and "Not saved" answer to their first letters too.
And from the owner's eye on the meeting:
the quest's words hung from the scroll's top roll — 1997's `DrawTextAt`
centres its words on its point both ways, the scroll's at (543, 409), the
parchment's middle — so they are centred on the parchment between the
rolls, a size smaller each until they fit, and the purse's numbers sit on
1997's own points (`EncounterStage.centred`).

## Built: the owner's follow-ups (0.50.61, 2026-10-27)

- *"upon esc key not just question to quit but also offer save/load in
  the same popup!"* — "Ready to Quit?" holds Save and Load under No. /
  Yes. (`WorldScreen.QuitAsk.chose`; S and L too), as 1997's right-click
  "Will you …" menu held them beside Quit [ours].
- *"on the embark Menu gray out lack options as they are not
  implemented!"* — the one choice that did nothing yet was the card packs
  (each pack's world and its World Lord are not built; the packs were
  chosen and saved, never read): greyed, unticked, out of Randomize and
  of the record (`EmbarkScreen.packs_ready`, false). The card rule and
  the difficulty work; the playmat is saved with the hero but no adventure
  duel reads it yet (the duel wears the Duel Options' territory) — found
  by the feature-state pass of 2026-10-27, first on the bug campaign's
  list.
- *"when you click Shandalar in the main menu make a popup that this is
  still in development and ask the player to report observations and
  issues on the projects repository! Then offer button go test and
  back!"* — the main menu's Shandalar opens that notice first
  (`main.gd` `_open_shandalar_notice`, `SHANDALAR_NOTICE`, the GitHub
  issues page); Go test opens the Embark screen, Back (or Escape) stays.

## Built: the bug campaign c12 (0.50.61, 2026-10-27)

The owner: *"Do one pass over all planned features and their state of
implementation and a bug pass bug fix campaign when current work package is
done!"* First the feature pass: four read-only reviewers checked every
planned feature against the code (the owner's ledger page, by part: the
adventure, the duel engine and cards, the deck builder and records, network
and platforms) and listed the docs that said the wrong thing; a docs fixer
corrected 28 of them. Then six hunters (the world and its panes, the
adventure's duels and economy, the engine and cards — the 25 suspected card
bugs of 2026-10-21 probed one by one, 18,000 fuzzed card runs —, the duel
screen and shell, the builder and records, network and robustness) and
eight fixers on disjoint files, each fix with a test that fails without it.

For the adventure:
- **The playmat** chosen on the Embark screen is worn in every adventure
  duel (`DuelConfig.territories`, set by `CreatureMeeting.hero_playmat`;
  the duel screen's ground reads it, `DuelOptions.ground_for`) — it was
  saved and never read.
- **The town latch is saved** (`AdventurePlayer.entered_tile`, the save's
  `where.entered`): closing the window inside a town, or a Resume or Load
  beside it, no longer makes the next click a new arrival — no second
  "Visited", no quest, trade, hint or shop drawn again, no second push-back.
  A ruled town's creature is still drawn again on a Resume, as a step off
  and back draws it.
- **The carried lives — the owner's ruling (2026-10-27): "Carry the life
  you ended with"**: a creature's reward "You get your lives (N) carried
  over to the next duel" starts the next duel at exactly N [ours: 1997 slip
  — 1997 carried end − start, so a gift that had raised the start was taken
  off again]; the carry is now the end life less the mana links. With no
  gift and no earlier carry it is 1997's own.
- Under the Classic MTG rules every lair rare obeys the rules too (the
  waiting rare, the Thieves Hideout, the Lost City, the Pyramids); a lair
  duel's hoard stays unlimited (a stake).
- A freed town shows the card won ("Won this card") and says when a full
  bag loses it [ours]; a reward step with no line is skipped [ours: 1997
  slip — its title stood alone]; the news flash answers to C.
- Help promises nothing a player cannot reach before part C (the castles'
  attempts, a beaten wizard's room, the dungeon treasures "come with the
  insides of the castles and the dungeons").

Across the game (the release note lists them for the player): the engine's
one HIGH — no spell with no life cost could be cast below 0 life (Lich, the
1997 end-of-phase life check) —, "whenever ~ deals damage" once per damage
event (`SOURCE_DEALT_DAMAGE`), every "destroy all" sweeper as one departure,
Whimsy and protection, the Laces' timestamps, a stolen spell's reflected
damage, the attack tax order, the AI's damage forecast never reading a
masked creature; the duel screen (the computer waits under the quit and
concede questions, the Spell Chain on the screen, a skipped combat not
resting in Main 2, two-human Test hands, face-down exile at a private
hotseat, Original type on a copy, Pause holding the opening and the coin
toss); the windows between duels, Escape on the title's popups, the Combat
window's lanes; the 1997 .dck read and written as the original game does;
atomic writes for records, drafts and tournaments; the LAN host's seats per
computer and idle reclaim; the web file boxes; Open Folder on Android; a skin
replaced under its own name; quiet reads of a damaged seal list.

Not done here, for the owner: the pack zips' notes (Pack 5's, Packs 8 and
9's counts) are corrected in the repository but take effect only with a pack
rebuild, which waits for the owner's word; the status line at an open
hotseat still reads seat 0.

## Built: part C, stage C1 — the rules inside and the end (2026-10-27)

The rules of the castles, the dungeons and the end, built headless and
tested against 1997's own numbers; the screens that show them are stage C2,
and `DungeonDoors.BOARD_READY` stays false until then, so a player meets
none of it yet except one Embark choice. The specs and the owner's rulings
are the part C plan's; every class header cites the 1.3 decompilation and
marks what is ours.

- **The board** (`DungeonBoard`): 1997's maze on its lattice of 38 rooms,
  carved in 1997's dice order, with a guard that starts again from the
  lattice when 1997's loop could never end — it changes no maze 1997
  finishes (tested on 150 starts) and a fresh maze is made at every entry
  on the board's own dice, never the adventure's. The creatures by tier (a
  castle's wizard in slot 4), the line of sight down the corridors, the
  keys (1997's, the arrows, W A S D, the keypad) and the mouse's quadrants.
  The dice (lives, or a card of the deck in use by copies, never one the
  rules bar), the riddle (a wrong answer wakes a creature at once), the
  treasure (a card, or gold and jewels; with a full bag the hero may swap —
  the owner: the card put back **stays as treasure** in that dungeon, found
  again on a later visit), "rooms left" counting every room (the owner's
  choice), a dungeon kept while any card remains in it, and "large" on a
  large dungeon's clue (D11).
- **The duels inside** (`DungeonDuels`): the minion table and the card in
  effect as 1997; a dungeon's rule bars cards from the hero's deck by their
  **real colors** (the owner: a dual land with the color barred; the Moxen,
  Celestial Prism and Black Lotus colorless) and the deck is made up with
  allowed basic lands, counted after the ban [ours: 1997 slip i]; the
  stake drawn only from allowed cards [ours: slip f]; a dungeon's losses
  carry room to room, a castle's duels start fresh (a1); a draw changes
  nothing (g3b). One rule each for the ban and the next duel's life: the
  board asks the duels.
- **A castle won** (`CastleWin`): the journal and the victory log (a castle
  wizard counts, and pays 25 more years at the end — SC2), his towns freed,
  his creatures and besieger gone, his color beaten, the castle a ruin, the
  1997 words and three cards of his color to pick.
- **The end** (`FinalBattle`): Arzakon's duel (his 138-card deck, life
  100 × (difficulty + 1), Black Lotus and Celestial Prism in play, named
  "Arzakon", no stake), the score as 1997 counted it with its slips fixed
  (every siege of the game, 25 years a castle wizard, 10 years a life
  Arzakon loses — **overkill counts**, the owner —, the years added after
  the floor), the world's next-duel gifts **reaching Arzakon** (the owner,
  D-4), the portal near the map's middle (the owner: *"somewhere in the
  middle of the map approximately"*; the guide arrows, the panel and the
  journal point to it), 1997's empty world while it waits (the owner), and the result read at last [ours: 1997 slip C3-1 —
  a loss played the win]. **Embark's "Final battle"**: *Reload allowed*
  (saved at the door; a loss leaves the hero there, every attempt in the
  record) or *One life* (a loss ends the quest; the owner: **quitting
  mid-battle counts as a loss** — "True ironman … no way to retry": the save
  at the door marks the battle begun and a map beside the Hall of Fame
  keeps it, so no older save can try again — `FinalBattle.on_load`).
- **The Hall of Fame** (`HallOfFame`, `user://hall_of_fame.json`): every
  adventure won, best first (score, then harder difficulty, fewer days, the
  earlier date), one line an adventure, 100 lines; written whole, a damaged
  file kept aside. Its screen opens inside Save / Load and after the win
  (the owner), in stage C2.
- **After the win**: no sieges; creatures and lairs of every color come
  back, each creature hunting the hero, wandering or standing still (1 / 2 /
  1), the quest's creature always hunting; the portal stands as a stone
  monument (the owner: *"a monument made of stone (make it as a new
  asset)"* — our own picture, as 1997 had none on the map; from three
  pairs of mockups the owner chose the horned arch: open, a dark arch with
  a glowing violet swirl; after the win, grey limestone, one horn broken,
  sealed — drawn on the world in stage C2), and the arrows and the journal
  still point to it.
- **The assets**: the importer brings the board's tile sheets (three
  dungeon looks, five castles, the plaques), the clue screens, the
  treasure cave, the castle-won ground, the banner, 5thwiz, Wingame, the
  cave's sounds, the dice, scroll and card-found sounds and the win tune;
  `Mtgend.avi` becomes `win_movie.ogv` when ffmpeg or GStreamer with Theora
  is found. None is read until stage C2. The white castle's floor will show
  **all its marks** (the owner) — 1997 painted two of them over.

Lead's defaults (listed to the owner): the dice's lives replace a waiting
dice card (1997's one slot); a room draw spends the next-duel gifts, the
pool kept; a world card gift a dungeon bans still goes into play (1997).

## Built: part C, stage C2 — the screens (2026-10-28)

The castles and the dungeons open (`DungeonDoors.BOARD_READY` true), and
the adventure can be won. Every screen was looked at in the running game,
with the 1997 skin, without it and with Big buttons, and the owner chose
from the shots where a choice was his.

- **The board** (`DungeonView`, `DungeonPane`, `DungeonSound`): the page as
  1997 drew it — the cave ground, the title plaque, the green next-duel
  line, the cells drawn back to front (the back frame, then the front with
  the odd-row offset), the rock tops, the dice, scrolls and chests, a
  castle's wizard, the creatures facing the way in, the hero's walk of
  eight frames (ending on the cell, where 1997 stopped 4 pixels short) —
  in a rounded pane at most 1.25× the 1997 page that never changes size.
  The name in the middle of the plaque's green field (with the next-duel
  line, the two as one block there), the pane's header saying only what
  the place is — "Dungeon", "Red Castle" (the owner, 2026-10-30: "Bottom
  title should be in the middle", "Top title should just say Dungeon").
  The white castle's floor as 1997 showed it (the owner, after seeing all
  its marks in play). Moves: 1997's keys, the arrows, W A S D, the keypad,
  a held key walks on, a click on a neighbour or along a seen corridor.
  [ours] The life in the next duel and the rooms left on the page's foot,
  a creature's name on hover, newly seen corridors fading in (with
  Transitions on). The cave's bed and its five noises on their own dice.
  The events' pages: the dice, the riddle, the treasure on Staceybk coming
  in tile by tile, the full-bag swap in the adventure's deck builder
  (`TreasureSwapBuilder`, "Leave it here"), gold. The adventure is saved
  at the door (D2).
- **Before a room duel** (`RoomDuelPane`, on `StagePane` — the meeting
  pane's layout once, shared by the new panes): the creature's face on
  the place's ground, the stake or "No stake", the cards starting in play,
  the minion and the card in effect in the board's marble frame, the
  purse with the duel's own starting life (the owner), one choice: Duel.
  Then `WorldDuels.host`, `DungeonDuels.settle` once, `room_done`. Its
  header, as the meeting's, says only what the creature is — "Creature", a
  castle's wizard "Wizard" (`CreatureBook.kind_word`) — and its face's
  banner names it (the owner, 2026-10-30: "Yes, header = kind").
- **A castle won** (`CastleWinPane`): his room's still, the 1997 words on
  Tradscrn with the news of the freed towns, the three picks (`CastleWin.
  offered` / `take`), a full bag said; his tune throughout.
- **The clues** (`CluesPane`, `ClueMap`; F4): our glass list of the places
  (the owner) with 1997's icons; a place's page on Clueback with its clue
  lines in 1997's inks, its treasure cards, its creatures' faces once known
  (all of a castle's, the owner), and Show on map — the F2 map with the
  place ringed. The old HUD clue panel is gone.
- **The end** (`AdventureFinale`): the fifth wizard's page on 5thwiz with
  "Face me now" / "Return to Shandalar first"; the portal near the map's
  middle, our horned arch (the owner's pair 2, `tools/draw_world_portal.gd`,
  `game/art/world_portal_*`), its own pointers and pane; the banish words
  with the years so far; the deck builder; the save at the door; the
  battle with each Embark rule's questions; the quest-failed end in 1997's
  words — under Reload allowed back at the door, where the hero may face
  him again or return to Shandalar first (the owner); the win: the movie
  (`GameSkin.movie`, skippable, absent → straight on), Wingame revealed,
  the words, the record with the years explained, the Hall of Fame with the
  new line lit, then End or Return to Shandalar (`FinalBattle.roam`; the
  monument). The journal says the portal opened only when the hero goes
  back to the world (the owner). Loading a won adventure asks End or Return
  again (the owner).
- **The Hall of Fame** (`HallOfFamePane`): inside Save / Load and beside
  the save slots, and after the win — never on the main menu (the owner);
  the load list marks a won adventure with its years and a failed quest.
- **The record page** (`HeroStats`): "Arzakon Banished" — the years so far,
  then the final years — and "Final Battles Lost" [ours: 1997's page had
  neither]; the castles' attempts, a beaten wizard's room and the dungeon
  treasures, built before and now reachable.

## Built: part C, stage C3 — the playtest and the hunt (2026-10-28)

Six hunters played and read part C: the board, the duels inside and the
castle win, the end, a playthrough from Embark to the Hall of Fame through
the real screens (seven runs: both Embark rules, with and without the
skin, 1280×800, 800×600, 1920×1080, Big buttons), saves and robustness, and
the rules against 1997 (1,920 boards cell for cell the same as a port of
1997's maze code; the end score on 40 random states the same as 1997's
formula). No crash, lost save or soft-lock; four fixers on disjoint files
mended what they found, each with a test that fails without its fix.

- **The board**: a double click's second press is no click, and a box or
  page cannot be dismissed in its first 300 ms (the found card's page until
  it stands whole); Return to main menu after a FINISHED room duel shows its
  result, ends the visit (saved on the way out) and leaves — with its own
  question — and after the fifth wizard it saves and leaves for the title
  (the load opens at Arzakon's question); of two held directions the newer
  turns the hero after the step; "Leave?" in a dungeon with no card left
  says it will be gone; "Leave it here" asks first even on a double click.
- **The end**: a won battle left through the menu still walks on from the
  Hall's Return to Shandalar; a save that fails is always said; the load
  list marks a One-life quest that began or lost its battle in every save
  of it, and Resume passes a failed quest by; the Hall says when its file
  cannot be read and refits on a resized window; saves are format 2 (an
  older game will not write over them), and a save's end marks are made
  consistent as they are read.
- **The owner's rulings of the hunt**: the hero stands in front of a
  castle (or its ruins) and the portal on its own tile — towns, villages,
  cities and dungeon markers as 1997 drew them [ours]; without the
  1997 card table the cards carry 1997's own marks — the 28 treasures
  special, the 22 cards 1997 never traded kept back — so trades and castle
  picks are the same with the skin and without; a beaten wizard's
  creatures say their master has fallen ("Pay, or fight."; with five wins
  "…tremble before you. Accept our tribute.") and near his ruins meet the
  hero as anywhere else — ruins are no stronghold [ours]; the 2×
  skin's board sheets are upscaled frame by frame amid their board
  neighbours, so walls and floors meet without seams (decision 9), and
  the pre-duel pane's frames (plain and tinted) and the world's ground
  layer (the land diamonds, the coastlines, the roads) doubled pixel for
  pixel, as the sandstone is (ledger row 121; `tools/upscale_skin.py`);
  shown real-size mockups of the whole world doubled or upscaled, the
  owner kept the mix: "As is now."
- **Also**: the quest's creature keeps coming after its color's wizard
  falls; the arrival words fade when a HUD pane opens; Power Struggle and
  Rainbow Knights are known by their 1997 names ("Power Junction",
  "Knights of the Rainbow Vale"); the Deck Lab's shared AI caches are
  thread-safe (a rare crash with several games at once) and the MCP server
  names a crashed run's signal and reason; the test runner never collects
  the git-excluded probes, and `-gdir=<folder>` narrows a run.

## Built: after part C — the owner's rulings of 2026-10-28 (0.50.65)

After the ledger was brought up to date the owner settled the open items
(scratchpad rounds "after the ledger", "open items" and "unused 1997
features"). What this version builds of them:

- **Card hold** (a new Embark rule): *the 1997 card hold limit* — the bag
  of 500, as everywhere until now — or *unlimited*: no card is refused or
  lost to a full bag, and the full-bag messages and the treasure swap never
  appear (`AdventurePlayer.card_hold`, `bag_room`, `bag_limited`). An older
  save reads the 1997 limit.
- **Ban list** (a new Embark rule, for the Classic MTG card rule only, and
  for the adventure only — Magic Battle's formats are untouched):
  *1998* (The Duelist #22's Classic lists, with Strip Mine's restriction of
  1 January 1998), *modern* (today's Vintage lists) or *1998 + modern*, the
  default, never looser than either (`ClassicBans`). An older Classic save
  reads the default.
- **"-One deck for all duels."** is no longer a clue line (the owner: *"the
  player can have multiple decks"*): the rule stays dead, as in 1997.
- The Embark screen makes room for the two rules (a smaller playmat
  preview), whole at 1280×800 and 800×600, with and without the skin.
- **The polish pass** (the owner: "the polish pass before commit and
  push!"): inside a village, town or city M/F2, F5 and Ctrl+S open over
  the town's pane and bring it back as it was (1997's `OpenTownWorldMap` /
  `OpenTownAdventureStats`; ledger adventure-032); the creature names on
  the map, the only unused 1997 feature the owner wanted (§5), small and on
  1997's beat, with their own switch "Creature names" (off to begin with);
  the purple line at the end of the "Your Ante" plaque gone (the frame's
  pieces cut with `filter_clip`, `EncounterStage.cut_of`); the skin check
  counts the adventure's data files; best-of matches and Gauntlet runs
  saved between duels (`MatchSaves`); in the adventure's deck builder
  1997's sell from a card's menu ("Sell Card for %d", "How many to
  Sell?"), Move by color into deck (1997's own adventure command, a
  color's basic land moving with it as in 1997's code), the card hold and
  the copy rule always shown; the deck builder, the duel screen's
  own options and the engine's checks (their own sections of the code map
  and the release note).
- **Sieges** (a new Embark rule, the owner's ruling of 2026-10-28 on a
  1997 complaint — *"creatures siege towns too much and they cannot
  explore"*; the Slightly Magic forum, 2017 and 2021: 1.3's clock jumps by
  `d + T/256` after a start and `2d + T/64` after a resolve, so every
  siege brings the next sooner, from 63 steps apart (24 to lift it) to 16
  (8 to lift), one about every thirty seconds of walking): *As 1997*,
  *Steady* — the default — (the jumps by the difficulty alone, the first
  siege's pace all game: 64/24 steps on Apprentice, 55/21 on Wizard),
  *Rare* (Steady's jumps, the clock stepping every 64 walking ticks
  instead of 32 — so the clock's other readers, the ruled towns' and
  besiegers' tiers, the shrine's late check, the thieves, run half as fast
  too) or *None* (no siege ever, the Wizard-difficulty retaliation
  included: no town lost, no Dominion; the clock still climbs, without
  jumps). `AdventurePlayer.sieges`, `Sieges.calm` / `start_jump` /
  `resolve_jump` / `clock_steps`. A save without it plays As 1997, as it
  was played.
- **Dungeon treasures under the Classic rules** (the owner: *"Skip it"*):
  a treasure the chosen ban list bans (Mind Twist under 1998 and
  1998 + modern) is never placed; the dungeon holds another of the 28 the
  list allows and it does not already hold, drawn from the world's seed
  (`AdventurePlayer.treasures_by_the_ban_list`, at the Embark and when an
  older Classic save loads). Modern, the other card rules and a list that
  bans none of the 28 keep 1997's placement.
- **The bug campaign's fixes** (c19): a ruled town's stake walks the whole
  bag under an unlimited card hold (`RuledTowns.walked`; 1997's 500-place
  walk unchanged under the 1997 hold); a draw over a bag past 32,768
  places always ends (`MsvcRandom.below_wide`, 1997's `rand() % n` die
  for die below it); without the 1997 card table the shops stock by the
  same marks the table carries (`CardValue.expansion`, `named_marks`);
  the save format is version 3.
- **The Campaign Settings** (the owner's rulings of 2026-10-29 on the choke
  points). The Embark keeps 1997's own choices; the modern ones sit behind
  "Campaign Settings..." (`EmbarkScreen.open_settings`), a dark-stone window
  of eight rows — Final battle, Card rule, Ban list, Card hold, Sieges,
  Creatures, Starting life, Ascetic hero — each with a plain line, `As 1997`
  and `Done`. Three new rows: *Creatures* (`AdventurePlayer.creatures`; Hunt
  = 1997 as shipped, Notice = the default): unused-features §6–§7 switched
  on in `WorldCreatures.goes/speed_of/pace` — out of range a creature
  wanders its lands at half its stride [ours], in range it hurries at its
  stride (Hunt's walk), slowed to the amble on the lands its flags name; the
  nearest keeps its range, the others half; besieger and quest creature as
  Hunt. Two departures, by the owner's intent ("within 1.5–4.5 tiles, then
  hurry"): the range read in world units (`NOTICE_SCALE` 2; 1997 compared it
  with its ApproximateDistance, about twice a straight distance, so 48
  reached three quarters of a tile), and 1997's "far ones hurry" doubling
  read once, as the hurry of a creature that noticed (read as written it is
  a chase from anywhere). Henchmen, no case in 1997's switch, take 48
  [ours]. *Starting life* (`life_start`; Links only = default, Base 10 +
  links = §1): one reader, `AdventurePlayer.duel_start_life` (10 + Haggler's
  Coin 2 + Ring of the Guardian 3 + Fruit of Sustenance 5 + links), feeding
  `CreatureMeeting.hero_life` (meetings, lairs, ruled towns, the final
  battle), `DungeonDuels.life_parts` (rooms and castles; the pool counts
  from it), the carried-lives reward and the purse/hero panel/ankh tip.
  *Ascetic hero* (`ascetic`, off): a food every other walking clock step,
  the half kept in `meal_half` (saved). And *lost links come back* under
  Steady, Rare and None: `Sieges.resolve` remembers a town taken while
  linked (`links_taken`, saved in the record; old saves none),
  `RuledTowns.settle` and `Sieges.free_all` give the link back
  (`restore_link`; "Your mana link here is restored.", castle win "Its mana
  link is restored.", journal "Mana link restored at %s"); under As 1997 it
  stays lost. All saved in FORMAT_VERSION 3.
- Decided, built later: the World Lords' shape (gate → island → keep),
  built once the adventure is finished with the original cards.

## Built: the smoothness pass (0.50.66)

The owner (2026-10-29): *"One critique of og game was clunkiness. I really
want our adventure to play silky butter smooth and high fps if needed."*
Measured first on the desk's GPU (RTX 4060, every scene 380–1300 FPS
uncapped: not the frame rate but stalls and uneven motion), then mended,
the 60 ms tick, the 1997 pace, the dice and the meetings untouched — only
how the world is drawn, loaded and scheduled:

- [QoL] The hero, the creatures and the view glide at an even speed over
  1997's stop-and-start steps (each drawn at its average place over the
  last three ticks, two for a creature; at most about 90 ms behind the
  tick); the map is drawn ahead over frames, in fewer draw calls with the
  same pixels; a town's flags no longer redraw the world.
- [QoL] The zoom eases (1−e^(−18·dt) in log space) and lands on the
  jump's zoom; the board's hero slides between 1997's 66 ms walk frames,
  the poses and timing 1997's.
- [ours] The world reads its pictures, sounds and tunes before they are
  wanted — the places' sheets, the meeting's pictures and the walk's
  sounds as the world opens, and every 4 ticks the tunes, pane pictures,
  meeting grounds and lair sounds near the hero — decoded on a worker
  (`SkinWarmer`); a new creature is drawn once its sheets are ready (1–4
  frames later); F5, F6 and the map's pictures are made before they open
  (`PaneWarmer`); every adventure duel is warmed on arrival and again as a
  meeting opens (`DuelWarmup`), so a duel opens in about 40–80 ms instead
  of 0.4–1.3 s.
- [ours, owner 2026-10-29] Path arrows and their X only on explored tiles.

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
| Cards (as both releases dealt them, the extra creature copy in) | 36 | 40 | 46 | 46 |

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
- **The two places once to check, settled in the machine code (2026-10-27,
  built in 0.50.60):**
  1. The Apprentice's second quota, 13, 7, 15, sits behind a test that can
     never be true (1.3 at 0x4bde0e–0x4bde16 compares the mask with 1,
     turns the result into 0 or 1, then tests it against 0x20); retail
     carries the same dead block (Ghidra drops it as unreachable). Every
     Apprentice gets 13 lands, 12 spells, 10 creatures and the rare, 36
     cards. Listed in docs/adventure-unused-1997-features.md.
  2. The card added after the rare block even when there is no rare is in
     BOTH releases (1.3 at 0x4be3f8; retail's raw output adds it outside
     the block too — a cleaned transcription had moved it inside): every
     share without a rare ends on one more copy of its last creature, with
     no copy limit checked. Built as 1997 dealt it (the owner's I-2); under
     the Classic MTG rules the copy is skipped once the allowance is
     reached [ours].
  3. The coloured non-creature spells are ENCHANTMENTS only in both
     releases (the type mask 0x04 for a coloured spell, 0x40 for an
     artifact; 1.3 at 0x4be1b1–0x4be1ba, retail the same) — built (the
     owner's I-3): no instant or sorcery in a first deck but the rare.
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
| Amulets and mana links | `status_and_ruling_wizard` bit 1 (`TownStatus`), `CountDuelPoolEligibleTowns` (`duel.c` 1893), the amulets in `InitializeNewGameState` | (to find) | `domain/amulet.go` |
| Card prices, collection | `CalculateCardShopPrice` (004f1cce), `RunTownBuyCardsScreen` (004f0d09) (`CardValue`, `CardShop`) | (to find) | `domain/collection.go`, `card_tiers.go` |
| Enemy AI in duels | `src/magic/` (the duel code `magic.exe` shares) | `docs/SHANDALAR_AI_FAQ.md` in the decompilation | — |
| Save and load | `adventure_save.c`; `docs/shandalar_save_files.txt` | `SaveGame_SaveCampaignFile`, `Overworld_SaveMapFile`: slot 3 is the running game, slots 4–9 and a–d are saves | `game/save/` |
| Arzakon and the ending | `dungeonEncounter.c` (`HandleDefeatedWizardCastle`, `CalculateDungeonEndgameScore`) | `src/magic/world/database.c` | (to find) |

(2026-10-27: the 1.3 column's "(to find)" cells are filled from the
functions the built code cites. The retail and s30 cells still marked
"(to find)" were never traced: the adventure was ported from 1.3, and
s30 is a guide only.)

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
  Apprentice quota and the extra creature copy. (2026-10-27: both settled
  in the machine code and built in 0.50.60 — "The two places once to
  check" above.)

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
- **2026-10-22** — Owner: AdventurePlayer, the autosave by name and time
  hash, a walking figure guided by clicks with a walking-man and an
  open-door pointer, and a load. Built (0.50.50): `AdventurePlayer` (the
  1.3 save's parts, readable JSON), `HeroWalk` (the 1.3 pace, tick for
  tick, on a way found round the sea), `WorldCursors`,
  `LoadAdventureScreen`; Save / Load on the title is live. "Built: the
  adventurer, walking and the saves".
- **2026-10-22** — Owner: the walking figure colored part by part on the
  Embark screen, randomized, with a 1997 default. Built: `HeroColors`
  (parts found by colour and height, dressed along each colour's ramp),
  `FigurePreview`, the swatches and their popups, `1997`; the colours in
  the record, the save and on the map.
- **2026-10-22** — Owner: the red arrows either side of the portrait, the
  room gained for the figure's preview under the colour swatches. The
  face's name now sits on a band across the portrait's foot.
- **2026-10-22** — Owner ruling on the world screen's interface: *"it is
  the modern way to have floating icons as a gui and lets keep this design
  for world building"* — no 1997 frame round the world; what the frame
  held (the hero's purse, food, amulets, the World Magics, the map, the
  journal, the deck) comes as small floating elements over the full-screen
  world, minimal, as the HUD and hint do today.
- **2026-10-23** — 0.50.50 committed and pushed. Owner: "implement all
  items you suggest", then panes "with rounded corners that can be moved
  at will … togglable on/off in options". Built (0.50.51): casting the
  five World Magics (`WorldMagic`), the quest pane and what calls the hero
  (`WorldStatus`), the clues (`WorldClues`), the places' names
  (`WorldNames`), the small map (`WorldMinimap`), the guide arrows
  (`WorldGuides`), movable panes and the new options. "Built: casting, the
  panes and what calls the hero".
- **2026-10-23** — Owner: the hero's stats "modern but reuse some
  elements from 1997", the adventure's deck builder over the hero's own
  cards with no Extras and "GOLD" on the deck name pane. Built (0.50.51):
  `StarterDeck` (the first deck by the 1997 rules), `AdventureBuilder`,
  `HeroStats`. "Built: the first deck, the deck builder and the hero's
  stats".
- **2026-10-23** — Owner: the journal scrolls (gold bar); every tab of the
  hero pane the Hero tab's size; "check how whole gui/map works on
  different resolutions", "smaller (steam deck) resolutions" and touch,
  "bigger buttons on the pane with left and right arrows at the distal
  ends". Checked from the running game at 640 × 400, 800 × 600,
  1024 × 600, 1024 × 640, 1280 × 800 (Steam Deck), 1280 × 1024,
  1920 × 1080, 2400 × 1080, 800 × 1280 and 3440 × 1440 (the stretch keeps
  the logical screen at least 1280 × 800: wider or taller, never smaller);
  one fault: the quest pane stayed by the panel when it moved to the
  bottom (fixed). Big buttons (`WorldHud.big`, ×1.6, the row scrolling
  between red arrows, on where the touch layer is), a pinch (touch layer's
  `magnify`) and a touchpad's pinch and slide zoom and look.
- **2026-10-23** — Bug hunt over the new features (two readers): 22
  findings fixed — panes dragged after being hidden, notices cut short or
  off the screen, panes growing off the screen and stranded by a resize,
  the 2x skin's castle trims, a long creature record, a cast on a release
  off the icon, arrows under the panes, a remembered pane over the moved
  panel, a look stuck after the map, the hero pane stale, needless
  re-layout, the world drawn under the deck builder; and in the deck
  builder Remove Extra Cards without the Tome, deck notes lost, a card of
  a switched-off pack thrown out of its decks, Clear deck renaming, Ctrl+S,
  the Stats window's tournament words, `current_deck` unchecked, and the
  window's close saving nothing. Then visiting the places ("Built:
  visiting the places") and a pointer for each.
- **2026-10-23** — 0.50.51 committed and pushed (554bf54). Owner: the card
  shop, which cards are where and how prices are set, a general formula
  for packs. Built (0.50.52): `CardValue`, `CardShop`, `CardShopPane`,
  selling in the town's deck builder, the program's card table imported.
  "Built: the card shop and the prices".
- **2026-10-23** — Owner: "Build all trade features and lets iterate on
  card formula more!" Built: the town trade (`CardTrade`,
  `CardTradePane`), the seller's hints (`CardHints`, imported
  `Hints.txt`), lairs on the map (`WorldLairs`) and their events
  (`LairEvent`, `CardRiddle`, `LairPane`); the formula's type defaults
  tuned; the 1997 card names bridged. "Built: trades, the seller's hints,
  lairs".
- **2026-10-23** — Owner: "Right click on card should have large card
  render as in the duel! If right click is free on card? And add to on/off
  to options dropdown. And add to help if enabled." Right-click was free
  on the shop's, the trader's and a lair's cards (the deck builder's is its
  bulk move and keeps it); they open the duel's `FullscreenCard`
  (`open_instance`); "Large card on right-click: on/off" in the options;
  the help says so.
- **2026-10-23** — 0.50.52 committed and pushed (d75d43d), CI green. Owner:
  "Yes do the A … quality and meticulously … modularly". Built (0.50.53):
  "Built: part A — the towns' life".
- **2026-10-23** — Owner: F1 as in 1997, then "one bug-hunt and bug fix and
  smoothness of gameplay and robustness campaigns". Done in 0.50.53:
  "Campaign: bugs, smoothness, robustness".
- **2026-10-23** — 0.50.53 committed and pushed (c486eca), CI green. Owner:
  "lets crack on to work package B!" Rulings: 1997 as played with the
  slips fixed and the designed-but-unused features documented; creatures
  drawn over their 4-tile range; creature decks exact 1997; quitting
  mid-duel as 1997. Built (0.50.54): "Built: part B — the creatures and
  their duels", and `docs/adventure-unused-1997-features.md`.
- **2026-10-24** — 0.50.54 committed and pushed (aa38022). Owner: a
  playtest and a bug campaign over part B. Done in 0.50.55 (3b867c7):
  "Built: part B played and fixed"; 0.50.56 kept a pane that fits with
  its foot on the screen.
- **2026-10-24** — Owner: a third card rule, the Classic MTG rules.
  Built (0.50.57): "Built: the Classic MTG rules, a third card rule".
  0.50.58 brought the docs up to date against the 1997 code.
- **2026-10-27** — Owner: every key decision taken together, in eight
  rounds: "Decided: the world's last pieces and part C". Built (0.50.60,
  267dab2): "Built: the world's last pieces"; then the owner's follow-ups
  (0.50.61): "Built: the owner's follow-ups". Part C
  — the wizards' castles, their duels and Arzakon — is next.
- **2026-10-27** — The bug campaign c12 (0.50.61, 3f27466): "Built: the bug
  campaign c12".
- **2026-10-27/28** — Part C in three stages: the rules (0.50.62, dd29a4b),
  the screens (0.50.63, 2e79711), the playtest and the hunt (0.50.64,
  4f65cdd): "Built: part C, stage C1 / C2 / C3". The adventure is played
  from Embark to the Hall of Fame.
- **2026-10-28** — The owner settled the open items and the unused 1997
  features; the World Lords' shape decided and postponed until the
  adventure is finished with the original cards. 0.50.65: "Built: after
  part C" — the card hold and ban list rules, the polish pass and a bug
  campaign, one version.

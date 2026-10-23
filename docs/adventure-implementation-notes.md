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
  Magic. The starting deck waits for the 1997 rarity table.
- **Mana links** are kept on the hero, not read from a site's status bit 1
  as the save's notes would have it: the generator sets that bit on the
  first ten towns and cities with World Magic as it makes the world, so
  there it means something else, not yet read.
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
  themselves are not made yet). A step into the sea within 12 units of a
  tile's middle is taken back.
- The figure is `EGO_M`/`EGO_F` frame `((direction + 2) & 7) * 5 + step`,
  the step 1–4 while walking, 0 standing; the shadow the same.
- **Ours [QoL]**: the original walked one of eight ways from a click
  (`MapWorldClickToMovementKey`, keys for the eight) or the arrows; a
  click is a destination here and the way round the water is found
  (`AStarGrid2D`, costed by the same pace), walked tile middle to tile
  middle, never past one. The arrows still look around.
- **Not yet**: the dice the original draws each step for the footstep's
  sound and the roaming creatures, so the adventure's dice stand still.
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
  creatures (`RevealRandomCastleDungeonClue`), not made yet.
- **The names** (`WorldNames`): `BuildTownDisplayName` (00550220) —
  `@CITYNAMES_FIRSTHALF[(slot / 8) mod 16]` + `@CITYNAMES_SECONDHALF[slot
  mod 16]`, a village "%1 Village"; castles `@CITYNAME_MANACASTLE`;
  `@DUNGEON_NAMES` by slot.
- **1.3 had no small map** (the decompilation's `minimap` variables are
  tile sizes); `WorldMinimap` and the guide arrows (`WorldGuides`) are
  ours [QoL]. The F3 city list and F6 wizards' window are not built.
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
  enchantments — ours follows the retail spec.
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
  are read and not built.
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


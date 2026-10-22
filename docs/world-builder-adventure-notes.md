# The 1997 adventure world — how MicroProse built it

Research notes for a future adventure mode, written 2026-10-04 so the
question "did the original generate the world, or ship one map?" is not
researched twice. **Short answer: every new game generated a fresh world.**
Shandalar has no fixed map; the world is made from random numbers when the
player has chosen difficulty, colour and face, and is then saved with the
game.

**Implemented 2026-10-22, exactly:** `game/adventure/world/world_generator.gd`
(`WorldGenerator`) makes the original's world from the original's dice
(`MsvcRandom`), held in `ShandalarWorld`; see "Exactness" below for how
that is proven.

## Sources

- **The matching decompilation of version 1.3** — https://github.com/rlerrr/shandalar-decomp
  (rlerrr, read at commit `fda3230`, 2026-10-04). Version 1.3 is the game
  with MicroProse's patches; the adventure is its own executable,
  `shandalar.exe`. "Matching" means the C recompiles to almost the same
  machine code: about 90% for `shandalar.exe`, and over 97% for most of the
  libraries. The names are human-assigned, so this is **the best source for
  the adventure**. World generation is
  `src/shandalar/src/world_generation.c`, which agrees with the reading
  below line for line. It has no licence: the same rule as the next source.
  The same author makes `rlerrr/shandalar-patch`, binary fixes that let the
  original run on Windows 10/11.
- **The decompiled 1997 retail release** — https://github.com/benprew/microprose-shandalar-source
  (Ben Prew, read at commit `0328cbb`, 2026-08-31): a Ghidra decompilation of
  the 1997 executables into C, known to this project since 2026-09-02 (the
  "Tier 2" survey in `gauntlet-design.md` §0.4). **It has no licence**: cite
  addresses and quote short excerpts as evidence, and write the game's code
  ourselves.
  Its names are machine-assigned and often wrong for the world code (table
  below). `src/magic/sid/Test.c` is a hand-written stand-in, not decompiled;
  its `GenerateWorldMap` is **not** the original.
- **The original install** (the local `shandalar-src` reference copy):
  `MAGIC3.map` … `MAGICd.map`, one per save slot beside `MAGICn.SVE`. All
  eleven have the same header (`58 30 ?? ?? 40 01 c8 00`, a 320×200 picture)
  and all differ in content: a world per game, saved with it.
- **s30** (https://github.com/benprew/s30, read at `317efd1`): the
  30th-anniversary remake's own world generator, compared below.
- Wikipedia ("a randomly generated landscape", citation needed). The Player's
  Manual does not say; the 1997 FAQ and dos486.com describe in-game
  randomness only (dungeons relocate when left unfinished, the Winged Pegasus
  and Leap of Fate teleport you, lairs and events appear at random).

## Where it happens

In the matching decompilation (1.3, `shandalar.exe`), all in
`world_generation.c` unless noted:

| Name | Address |
|---|---|
| `GenerateAdventureWorldMap` (steps 1–6) | 004f6d90 |
| `InitializeAnimatedNoiseGrid` (the lattice) | 004f8101 |
| `CalculateWorldTerrainValue` (height) | 004f7fb9 |
| `SampleAnimatedNoiseGridBilinear` | 004f82f2 |
| `PropagatePathConnectivity` / `FloodFillPathConnectivity` | 004f7c7d / 004f7eb2 |
| `GenerateWorldTownSlots` (sites, World Magics, trade) | 004f717a |
| `GenerateTownConnections` / `CreateTownConnectionPath` (roads) | 004f78d3 / 004f7a3c |
| `GetWorldTileType` / `GetWorldTileMagicMask` (terrain, its colours) | 0043146b / 005611c8 |
| `WorldNode g_town_slots[128]`, 100 bytes each (`magic/src/global_state.h`) | — |
| `g_neighbor_dx/dy[9]` (`shandalar.c`): 0 none, 1 N, 2 NE, 3 E, 4 SE, 5 S, 6 SW, 7 W, 8 NW | — |
| New game | `adventure_new_game.c` |
| Save files | `adventure_save.c`; `docs/shandalar_save_files.txt` (the `.SVE` layout) |

In the decompilation of the 1997 retail release (machine-guessed names, so
the right-hand column is what each one actually is):

| Decompiler name | Address | What it actually is |
|---|---|---|
| `glue_adventure.c` main menu, case 0 | — | New Game: difficulty (`menu2`), colour (`menu3`), face (`16faces`), then the world, then starting gold = (5 − difficulty) × 50 |
| `Pic_Subsystem_0044d680` | 0044d680 | **the world generator** (loops until a world passes) |
| `Pic_Subsystem_0044e9ac` | 0044e9ac | fills the random noise lattice |
| `Pic_Subsystem_0044e864` | 0044e864 | height of one tile |
| `Pic_Subsystem_0044eb9d` | 0044eb9d | bilinear value-noise sample |
| `Pic_Subsystem_0044e528` / `0044e75d` | 0044e528 | keeps one connected landmass (flood fill) |
| `Pic_Subsystem_0044da25` | 0044da25 | places the 128 sites and the 12-entry table |
| `Pic_Subsystem_0044e17e` / `0044e2e7` | 0044e17e | roads between sites |
| `Util_SeedRandomGenerator` | 0040a2c0 | `srand((GetTickCount() & 0x7fff) * 67)`, once per run |
| `FUN_0040a36f` | 0040a36f | site distance: 2·max(\|dx\|,\|dy\|) + min(…), so about 2× tiles |
| `Surface_GetPixelColor` | 0040c761 | terrain of tile (x, y): low 4 bits of the grid |
| `Overworld_SaveMapFile` | 0048d087 | writes the grid surface as `magicN.map` |
| `g_DungeonMapTileX/Y`, `g_CardSlot_CreatureType` | — | site x, y and **site type** (100-byte records, 128 of them) |
| `g_OverworldPlayerDirection` | — | the player's **colour** |

## How the world is stored

The world is a **64 × 64 tile grid** held in a 320 × 200 work surface. The
low 4 bits of a tile are its terrain, and higher bits are flags (set and
cleared by `FUN_0040c81c` / `FUN_0040c889`). Further 64-wide layers sit
beside the grid (x + 64, x + 128, y + 64) and the generator uses them as
scratch. The whole surface is saved as `magicN.map`:
- slot 3 is the game in progress;
- slots 4–9 and a–d are the ten save slots the Load menu scans.

## The algorithm, step by step

1. **Lattice.** An 18 × 18 table of random values 0–15 is made, wrapping at
   the edges. A copy then goes to a second table. The original computes a
   smoothing sum (4 × the centre plus its 8 neighbours) and then never uses
   it: the matching source shows the unsmoothed value being copied. That
   is MicroProse's own leftover, not a decompiler loss.
2. **Height per tile, 0–100.** Three samples of bilinear value noise are
   taken:
   - a smooth one over 8-tile cells, weight 4;
   - a per-tile one, weight 2;
   - a half-tile one, weight 1.

   From that sum, a falloff is subtracted. The falloff grows with the
   squared Manhattan distance from the centre (32, 32), plus |x − y| / 16,
   clamped to 0–12, ×512. Land therefore gathers in the middle, stretched
   along the x = y diagonal: the screen's horizontal in the isometric
   view. The result is scaled (×7 / 256) and clamped to 0–100.
3. **Shape.** Ocean is forced in two places:
   - the outer 2-tile border;
   - every tile whose isometric screen position, (3(x+y) − 32,
     3(y−x) + 100), falls outside a 320 × 200 frame with a 4-pixel margin.

   The island always fits the overview map.
4. **Terrain from height,** by 8-point bands:

   | Height | Code | Colours (`GetWorldTileMagicMask`) |
   |---|---|---|
   | 0–15 | 0 | ocean |
   | 16–21 | 1 | blue |
   | 22–23 | 8 | blue + black |
   | 24–31 | 3 | black |
   | 32–33 | 13 | black + white |
   | 34–39 | 6 | white |
   | 40–42 | 10 | white + green |
   | 43–55 | 2 | green |
   | 56–59 | 15 | green + red |
   | 60–95 | 5 | red |

   The terrain therefore climbs from water through blue, black, white and
   green to red. Each in-between code is a **two-colour terrain**: the mask
   uses the colour bits 2 black, 4 blue, 8 green, 0x10 red and 0x20 white.
   The mask also names codes the generator never makes: 4 red + white,
   7 white + blue, 9 red + blue, 11 black + green, 12 red + black and
   14 blue + green. The 1.3 source also shows dead code in the 56–63 band
   (codes 4 and 12 are set and then overwritten), so 15 and 5 are what
   actually lands.

   Quirk: a height of 96–100 hits no case and keeps the previous tile's
   code — but the highest height the sum can reach is 91 (three samples
   of at most 480, weighted 4 + 2 + 1, times 7/256), so it never does.
5. **Enough land?** Fewer than 1,750 land tiles (of 4,096) means starting
   again at step 1, with a new lattice from the dice as they now stand.
   The count is taken before step 6, so a finished world may hold fewer.
6. **Tidy up.** A one-tile pond with no water among its four orthogonal
   neighbours becomes code 6, in place, x outer and y inner. Then the
   connectivity flood: from tile (40, 24) a flood of depth 8 (seven steps)
   walks N, E, S and W through land; every tile it reaches on the 4-tile
   lattice (x and y multiples of 4, 4–60) becomes a source of its own, and
   so on until nothing new is reached. Land never reached becomes ocean, so
   the world is one landmass joined through land to (40, 24). The flood
   keeps its depths at x + 64 on the page and what it reached at x + 128
   (the sources at y + 64). Directions are `g_neighbor_dx/dy`
   (`shandalar.c`): dx 0, 0, 1, 1, 1, 0, −1, −1, −1 and dy 0, −1, −1, 0, 1,
   1, 1, 0, −1 for 0 none, 1 N … 8 NW.
7. **Sites** (128 `WorldNode` records). They are filled in the order
   i → (5i + 1) mod 128, **starting at `clock() % 128`** — the
   milliseconds the program has run, not the dice, so not even the
   original replays a world from its dice alone. A site is drawn as two
   dice of 64; an ocean tile is drawn again and does not count as a try. Each site goes on a random land tile at least 7
   distance units from every other site; that limit relaxes by 1 per 100
   failed tries. Its type depends on the distance to the nearest type-3
   site (d3) and to the nearest site (d):
   - d3 ≥ 33: type 3;
   - otherwise d < 11: type 1;
   - otherwise: type 2.

   A site more than 16 from every type-3 site becomes **type 4**, if its
   terrain has a colour that has no type 4 yet. That gives one type 4 per
   colour: the five wizards' castles. Names use the city-name tables, and
   type 4 uses the "mana castle" names.

   The types: **1 village, 2 town, 3 city** (the matching source names the
   type-3 distance `nearest_city_distance`), **4 castle**, and **5 a castle
   in its other state**. A type-5 castle is drawn with another castle
   sprite, and at load it marks its colour in `g_world_magic_town_flags`;
   most likely a defeated wizard.

   In 1.3 a world is also rejected unless all five castles were placed
   (mask `0x3e`) and at least 30 sites are towns or cities. The 1997
   retail decompilation has the same two checks (`Pic_Subsystem_0044da25`,
   read again 2026-10-22; an earlier reading missed them), and its site
   placement reads as 1.3's step for step. Quirk: the town count
   reads the slot numbered like the turn of the loop, not the slot just
   filled, so it counts whatever stands there at that moment.

   The colour of a terrain code is 3 → black, 1 → blue, 2 → green,
   5 → red, 6 → white. That is Manalink's colour order (1–5 = B, U, G, R, W),
   and it matches the terrain ambience files `k*`, `b*`, `g*`, `r*`, `w*`.
8. **The twelve World Magics** (`Scards[0..11].worldmagic_city` in the
   matching source). Each town or city draws a random slot from 2 to 11.
   It takes the slot if the slot is free and the town's terrain has the
   slot's colour (slot / 2: 1 black, 2 blue, 3 green, 4 red, 5 white), so
   there are two World Magics per colour. After 99 failed draws, the town
   takes slot 0 or 1, the two colourless ones (overwriting whichever town
   had it). Only a site in slot 1–127 is considered: slot 0 never offers a
   World Magic, since 0 means "none". Slots for World Magics the player
   already owns (`g_world_magic_bitmap`; a new hero owns the first of
   their colour's pair) are cleared. If any slot
   stays empty, placement retries; after 4 failed placements the whole
   world is generated again.

   The first ten towns and cities also get bit 1 of
   `status_and_ruling_wizard`; that bit is not decoded.

   **Trade** (`trade_color_and_type`): six random towns or cities get the
   colour bits 0–5. Then every town and city, in turn, gets either a colour
   bit or a trade type, (n mod 10 / 2 + 1) × 256, alternating from a random
   start. As written, the second pass overwrites the first.
9. **Roads.** Each site gets as many road links as its type number. For
   each link it samples 42 random sites and keeps a running best; quirk:
   the road goes to the best **before the last improvement**, and both are
   carried on from one link to the next (the original never set them
   first). The road is laid greedily: of the eight neighbours, only land
   strictly closer to the target counts; the score is the distance, +1 on
   green (code 2, or 11), +4 on red (4, 5), −4 on a tile already a road
   (after the first step); the lowest wins, earliest direction on a tie.
   A road that meets a road after its first step ends there. A road that
   cannot get closer is taken back whole (the page's grid and road layer
   are copied aside at x + 64 and back), and the link tries again, three
   times at most. Each step sets the direction bit at both ends in the road
   layer (y + 64; bit d − 1, the way back is ((d + 3) & 7) + 1) and flag
   0x20 on both tiles. Last, the seven lair slots get their first respawn
   times, (4 − difficulty) × i × −100.

At game start, type-5 castles mark their terrain's colour. After the
generator, the game runs the castle set-up (`Castle_Process_0046c8b0`;
`InitializeCastleDungeonSlots` in 1.3) and draws the map.

## Castles, dungeons and the start (read 2026-10-22)

`InitializeCastleDungeonSlots` (005081fa) runs right after the generator,
on the same dice:

1. **The dungeon cards.** Every card of the 1.3 card table flagged `0x100`
   (`EA_UNK100`, "card may be put in a dungeon"), in table order, is put in
   a random dungeon (`internal_rand(10) + 5`, again while that dungeon has
   three). The table is compiled into the executable (`carddata.c`, 722
   records; the scan stops at `g_card_count − 57` = 649): 28 cards — Copy
   Artifact, Braingeyser, Regrowth, Sol Ring, Ancestral Recall, Berserk,
   the five Moxen, Black Lotus, Ali from Cairo, Demonic Tutor, Mind Twist,
   Forcefield, Wheel of Fortune, Ivory Tower, Timetwister, Library of
   Alexandria, Mishra's Workshop, Candelabra of Tawnos, Feldon's Cane, Time
   Walk, Time Vault, Balance, Cyclopean Tomb and Fork.
2. **Fifteen places.** For each slot, two dice of 64 until a land tile that
   is neither site nor road, at least 4 from every town and city (not
   villages or castles) and every earlier slot. Slots 0–4 are the wizards'
   castles: black, blue, green, red, white; they draw a place like the rest
   but then stand on the castle site of their colour (quirk: the drawn tile
   still gets the dungeon flag 0x40). Slots 5–14 are the dungeons, each with
   a random colour (dice of 5), the nearest town or city, and its monsters
   and rules from further dice (the weight from its monster flags and how
   many cards it holds; `g_dungeon_card_effect_by_color` is indexed 1–5
   though it holds four, so red and green read on into the next table).
3. **The start** (`RunAdventureSession`): two dice of 64 until a tile of
   the hero's colour (two-colour terrain counts) that is not a site; the
   hero stands at its middle, 32 world units to a tile.

## The dice

Every draw is `internal_rand(n)` = `rand() % n` (0 for n ≤ 1), and `rand()`
is the C runtime's: the 32-bit state times 214013 plus 2531011, bits 16–30
out. 1.3 seeds it once, `srand(GetTickCount())`, when the program starts
(`shandalar.c`; the 1997 retail release `srand((GetTickCount() & 0x7fff) * 67)`;
1.3's `SeedRandomFromTickCount` only keeps a copy of the tick count and
seeds nothing); the menus,
the playmat's style and the starting deck draw from it before the world
does. So the world's **seed** here is the dice's state as the generator
begins, the one number that decides a world; with the slot start (the
original's clock) and the hero's colour (whose World Magic is withheld) it
makes the original's world exactly.

## Exactness

A scratch harness — the decompiled generator compiled as C with the C
runtime's `rand()` and stub pixel functions, never part of this project —
printed every world's tiles and roads (a fingerprint of the page's grid and
road layer), 128 sites, 12 World Magics, 15 castles and dungeons, the start
and the dice after. Our port agreed on all of it for 40 worlds of varied
seed, slot start, colour and difficulty (2026-10-22), worlds that between
them restarted for land 47 times, failed a site pass 180 times, redid the
world at the sites 37 times, took back 368 roads and fell back to a
colourless World Magic 4,906 times. `tests/unit/test_world_generator.gd`
keeps four of those worlds as golden values, with the original's rules as
invariants.

**The saves in our reference copy are not 1.3's.** The local
`Shandalar.exe` (md5 944d0b9f…) is the "Shandalar 2015" community build, a
modified 2012 binary that loads Korath's `Shandalar.dll`, which patches the
game at run time (the decompilation's `docs/BINARIES.md`). Its nine saved
worlds keep every rule above — the frame, the bands, one landmass, 128
sites placed (5i + 1) mod 128 from one start each, the town-count quirk,
the five stray dungeon flags — but a search of all 2^32 dice states finds
no 1.3 lattice that makes their terrain, so that build draws its world
differently. A save from an untouched 1.3 install would let a world be
held to the game itself; until then the decompilation is the reference.

**A world saved by the game itself, matched in full** (2026-10-22). The
owner's Windows XP install (a Manalink build, `Shandalar.exe` of 2009, md5
5938ea92…) keeps one world. A search of the 2^20 states that decide the
lattice found exactly one that makes all 64 sampled tiles (the next best,
about 32: chance); a search of the dice for its first five sites found the
slot start, 31; and the two join up — the sites' dice follow straight on
from the lattice's. From dice state 17281995 and slot start 31 the
generator, with every 1.3 rule in force, makes that save's world whole:
all 4,096 tiles, the 128 sites in their slots with their trade, every road
and the site, road and dungeon flags. Manalink kept the original's world
generator untouched.

**And the "Shandalar 2012" archive** (`Shandalar.exe` of 2011, md5
318955b0…) keeps ten more worlds, each with its terrain from one 1.3
lattice. Five match whole from one slot start, bar a few road-layer bytes
that hold the same value, 0x0B, on every tile where they differ, which the
game most likely wrote in play. A sixth (slot a) matches whole once its
second site pass is given a slot start of its own: 127, then 8. **The
original reads `clock()` again for every pass**, so a world that took more
than one pass started each from a new slot. The other four took more
passes (a search of every three-pass reading finds none for slot 5, so it
took all four). But a pass leaves nothing behind but spent dice, so they
too are the original's worlds whole from the dice at the start of their
last pass: from those (found from the first five sites) and that pass's
slot start, the generator lays all 128 sites with their trade, every flag
and every road. In play the game writes too: one site's status reads 10
in each of those four, and a few road-layer bytes read 0x0B, 0x2B or 0x8B.
So all eleven Manalink worlds are the original generator's. Ours keeps
one slot start for every pass, since a record holds one number; that is
the original's world whenever its clock did not move between passes.

**The "Shandalar 2015" saves follow a different random generator.** No
1.3 lattice makes their terrain, and no dice state of the C runtime's
`rand()` lays even their first five sites by the rules above, though the
worlds keep every rule's shape (the frame, the bands, one landmass, the
slot order). The rules are the original's; the dice are not.

**Compared with the other remakes.** s30 (below) keeps one landscape for
every game. Forge's adventure (its Shandalar plane, read 2026-10-22) makes
a new 700 × 700-tile top-down world each game from seven fixed biome blobs
— a colourless waste in the middle, the five colours round it in the order
of the colour wheel — with about 750 points of interest (424 towns, a
capital per colour, castles, dungeons, caves), straight roads to the
nearest town and the start at the centre, and no seed to type. Both are
re-imaginings; neither makes the 1997 world.

## Never stuck [QoL] (2026-10-22)

A few seeds hang the original on "Shandalar Materializing..." for good;
two turned up when the harness itself never finished:
- **No land.** The tidy-up keeps only the land joined to tile (40, 24).
  When that tile is cut off by sea, all the land is sunk (seed 1654867920
  at slot start 63, in its second world), and the site placement draws for
  a land tile forever.
- **An islet.** When a little land survives (30 tiles for seed 1893184459
  at slot start 111), all 128 sites crowd onto it, fewer than six are towns
  or cities, and the loop handing out the six trade goods looks for another
  town forever.
- In principle, too: no free tile far enough off for a dungeon, or none of
  the hero's colour to start on. Never seen.

`WorldGenerator` (each marked GUARD) makes the world again from the dice
as they stand wherever the original would loop forever, and nowhere else,
so every world the original finishes is unchanged. A site pass counts the
room left for towns and cities, and gives up as soon as six can no longer
be had. A town stands more than 10 from every site and a city more than
32 from every city, so a 4 × 4 block of tiles holds one town at most and
an 11 × 11 block one city. The dungeon and start placements look over the
whole map once after 65,536 draws in vain. The guarded harness agrees with
ours on both seeds, and ours with the unguarded harness on 20 ordinary
worlds.

Over 5,000 random seeds no guard fired. The original's own retries make
some worlds slow, though: half draw fewer than 46,000 dice (about half a
second here), one in a hundred more than 400,000 (about 5 s), and the
slowest 1.1 million (about 13 s). So the Embark screen makes the world on a
thread of its own while an hourglass runs in its bottom strip.

## Drawing the world (read 2026-10-22)

`DrawWorldTileRange` (0054d619) and `RenderAdventureWorldScene` (0054ac08)
in `adventureWorldUi.c`; ours is `game/adventure/world/world_view.gd`,
drawn on the whole screen instead of the original's 512 × 280 hole at
(64, 48) in `Advinter.pic` (`Advfac64.pic` is the title picture, loaded
only for its palette).

- **Projection.** A world unit (32 to a tile) is 2 px across and 1 down:
  a tile is a 128 × 64 diamond, the tile's corner its left vertex. The
  camera is the hero's exact position, the feet 20 px below the window's
  middle. Tiles are drawn by screen row (ty − tx) top to bottom, then
  across. Off the map is ocean.
- **Art**, `Program/SPR/` (640; `SPR800/`, `SPR1024/` 1.25x and 1.6x),
  painted with `Advfac64.pic`'s palette — `Todpal.tr` leaves out indices
  250–254, which the lairs, towns and castles use. Imported as `world_*`
  (`tools/import_original.py`, WORLD_SHEETS), each with its frames'
  anchors: LANDTILE ground (water for 0 and 8, sand for 1, grey rock for
  3, grass for the rest), CSTLINE1 edge pieces, LAND/LAND2 trees and
  rocks with SLAND/SLAND2 ground halves, ROADS, LOCATN01–07 sites and
  lairs, CASTLES1–2, EGO_M/EGO_F the hero (8 directions × 5 frames,
  anchor 77, 61) and SEGO_F the shadow for both.
- **Edges.** Each land diamond's four quarters read three of the eight
  neighbours each (top N NE E, bottom S SW W, left W NW N, right E SE S);
  a coast bit where the neighbour is ocean or marsh, or differs and either
  is blue; a black bit where the neighbour is black and this is not.
  Black pieces first, then coast (rows 4–7 and 0–3 of CSTLINE1).
- **Trees and rocks**, two per tile not a site, placed by
  pattern = |ty|·3 + |tx|·7 (no dice): column by terrain, row pattern % 11
  and (pattern + tx) % 11, offsets 128 / ((pattern % 5)·2 + 4) across and
  (pattern % 4)·2 + 5 down, none for blue.
- **Sites.** Towns and cities share sixteen looks by slot (slot % 16),
  villages two by column parity; a wizard-held town wears his dome; a
  castle its colour's picture, a beaten wizard's ruin for type 5. A
  dungeon shows only once the hero holds a clue to it.
- **No lighting.** No day and night, no animated water; retail's
  "lighting" function is the stats window. SUNMOON is the quest clock.
- **The hero sees around them**: drawing marks every tile within seven
  screen rows and three screen columns of the camera explored (flag
  0x80), on the 640 grid; the overview map shows only explored tiles.
- **Tied to the 640 screen**, for later: monsters are drawn only within a
  tile of the hero, and the click zones and the explore radius are the
  640 grid's. A full-screen view keeps the explore radius as the
  original's; the monster radius is to decide when monsters arrive.
- **What the whole screen shows** (the owner's choice, 2026-10-22, of four
  shown from the running game): the 1997 window showed about 4 × 4 tiles,
  all of it marked explored; the whole screen at 1:1 showed some seven
  times that, unexplored land and all. So unseen land is drawn dark with
  nothing on it (`WorldView.fog`), the view starts at twice the 1997
  pixels (`DEFAULT_ZOOM`), and the map (M) shows explored land only, as
  the original's did.

## Compared with s30 (the 30th-anniversary remake)

s30 builds its own world, a reconstruction rather than a port of the
original:
- **Terrain:** Perlin noise with a **fixed seed (12345)**, so the landscape
  is the same in every game.
- **Map:** 47 × 63 tiles in a zig-zag isometric layout.
- **Castles:** one per colour, seeded from the clock.
- **Sites:** 35 cities, all of one tier, and five dungeons; the start is
  the map's centre; no seed can be typed (read again 2026-10-22).
- **Bands:** water, sand, marsh, plains, forest, mountains, snow.

The original instead has:
- **Terrain:** value noise, new each game, with the island falloff;
- **Map:** a 64 × 64 grid;
- **Bands:** five colour bands plus transitions, as above.

**Owner ruling (2026-10-04):** the adventure is reimplemented from the
decompilation, with s30 as a guide only and our own [QoL] on top. The world
builder therefore follows these notes. s30's generator is a point of
comparison, and none of its code is translated.

## Open questions

Answered 2026-10-04 by the matching decompilation: the in-between terrain
codes, the site types, the 12-entry table, the per-site trade values, the
direction table, and the step-1 "empty loop". Still open:

- Whether type 5 is exactly "wizard defeated" (read the castle code).
- What a trade type of (n + 1) × 256 offers, and what status bit 1 means
  (`cityInfoScreen.c`, `visitLocation.c`).
- ~~Where dungeons and the starting position come from~~ — read
  2026-10-22 ("Castles, dungeons and the start"). Lairs and roaming
  monsters (`world_lair_monster_slots.c`) are still to read.
- ~~The `X0` map-file encoding~~ — decoded 2026-10-22: `magicN.map` is
  the whole 320 × 200 page through `EncodeRpBitsImage` (runs of more than
  three as `v, 0x90, k`, a literal 0x90 as `0x90, 0`, then LZW packed
  least-significant bit first from 9 bits, first free code 0x101, no clear
  or end codes, reset past 11 bits); `tools/import_original.py`
  `decode_pic` already reads it. The 128 sites sit in the `.SVE` at
  0x1EAF8 (100 bytes each), the castle and dungeon slots at 0x221D8.
- Which other differences between the 1997 retail release and 1.3 matter,
  beyond the two extra world checks found here.

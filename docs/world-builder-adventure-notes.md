# The 1997 adventure world — how MicroProse built it

Research notes for a future adventure mode, written 2026-10-04 so the
question "did the original generate the world, or ship one map?" is not
researched twice. **Short answer: every new game generated a fresh world.**
Shandalar has no fixed map; the world is made from random numbers when the
player has chosen difficulty, colour and face, and is then saved with the
game.

ShandalarGodot has no adventure mode yet (duel, deck builder, LAN,
tournaments), so nothing here is implemented. These are notes, not a plan.

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
   code.
5. **Enough land?** Fewer than 1,750 land tiles (of 4,096) means starting
   again at step 1.
6. **Tidy up.** A one-tile pond with no water among its four orthogonal
   neighbours becomes code 6. Then a flood fill starts from tile (40, 24)
   and walks through land in hops of up to 8 orthogonal steps. Land it never
   reaches becomes ocean, so the world is one connected landmass. Both use
   directions 1, 3, 5 and 7 of the direction table: N, E, S and W
   (`g_neighbor_dx/dy` in the matching source).
7. **Sites** (128 `WorldNode` records). They are filled in the order
   i → (5i + 1) mod 128. Each site goes on a random land tile at least 7
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
   (mask `0x3e`) and at least 30 sites are towns or cities. These checks
   were not seen in the 1997 retail decompilation.

   The colour of a terrain code is 3 → black, 1 → blue, 2 → green,
   5 → red, 6 → white. That is Manalink's colour order (1–5 = B, U, G, R, W),
   and it matches the terrain ambience files `k*`, `b*`, `g*`, `r*`, `w*`.
8. **The twelve World Magics** (`Scards[0..11].worldmagic_city` in the
   matching source). Each town or city draws a random slot from 2 to 11.
   It takes the slot if the slot is free and the town's terrain has the
   slot's colour (slot / 2: 1 black, 2 blue, 3 green, 4 red, 5 white), so
   there are two World Magics per colour. After 99 failed draws, the town
   takes slot 0 or 1, the two colourless ones. Slots for World Magics the
   player already owns (`g_world_magic_bitmap`) are cleared. If any slot
   stays empty, placement retries; after 4 failed placements the whole
   world is generated again.

   The first ten towns and cities also get bit 1 of
   `status_and_ruling_wizard`; that bit is not decoded.

   **Trade** (`trade_color_and_type`): six random towns or cities get the
   colour bits 0–5. Then every town and city, in turn, gets either a colour
   bit or a trade type, (n mod 10 / 2 + 1) × 256, alternating from a random
   start. As written, the second pass overwrites the first.
9. **Roads.** Each site gets as many road links as its type number. For
   each link it samples 42 random sites, picks a near one, and tries to lay
   the road (up to 3 attempts per link).

At game start, type-5 castles mark their terrain's colour. After the
generator, the game runs the castle set-up (`Castle_Process_0046c8b0`;
`InitializeCastleDungeonSlots` in 1.3) and draws the map.

## Compared with s30 (the 30th-anniversary remake)

s30 builds its own world, a reconstruction rather than a port of the
original:
- **Terrain:** Perlin noise with a **fixed seed (12345)**, so the landscape
  is the same in every game.
- **Map:** 47 × 63 tiles in a zig-zag isometric layout.
- **Castles:** one per colour, seeded from the clock.
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
- Where dungeons, lairs and the starting position come from
  (`InitializeCastleDungeonSlots`, `world_lair_monster_slots.c`,
  `adventure_new_game.c`).
- The `X0` map-file encoding (`adventure_save.c`).
- Which other differences between the 1997 retail release and 1.3 matter,
  beyond the two extra world checks found here.

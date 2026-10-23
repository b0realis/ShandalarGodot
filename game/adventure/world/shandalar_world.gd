class_name ShandalarWorld
extends RefCounted
## ONE WORLD OF SHANDALAR, as the 1997 game held it — made by
## [WorldGenerator] from a seed, the same world the original makes when its
## dice stand at that seed (`docs/world-builder-adventure-notes.md`).
##
## THE PAGE IS THE WORLD. The original builds and keeps its world on a
## 320 × 200 work picture (graphics page 2) and saves that picture as
## `magicN.map`; every layer below is a region of it, so it is kept whole:
##  - tiles (x, y), 0–63: the tile byte — terrain in the low four bits
##    ([method terrain]), then [constant SITE], [constant ROAD] and
##    [constant DUNGEON];
##  - (x, y + 64): the roads leaving the tile, one bit per direction
##    1–8 ([method road_bits]);
##  - x + 64 and x + 128: the generator's scratch (the connectivity flood
##    and the backup a failed road restores from).

const TILES := 64
const PAGE_WIDTH := 320
const PAGE_HEIGHT := 200

## The tile byte's flags above the terrain.
const SITE := 0x10
const ROAD := 0x20
const DUNGEON := 0x40

## Terrain codes (`GetWorldTileType`). The generator makes 0, 1, 2, 3, 5,
## 6 and the in-betweens 8, 10, 13 and 15; the colour mask names the rest.
const OCEAN := 0
## The land codes the generator makes ([method WorldGenerator.terrain_for]),
## so the lands a place can stand on.
const LANDS_MADE: Array[int] = [1, 2, 3, 5, 6, 8, 10, 13, 15]

## Site types (`WorldNode.location_type`): 1 village, 2 town, 3 city,
## 4 a wizard's castle, 5 a castle in its other state.
const VILLAGE := 1
const TOWN := 2
const CITY := 3
const CASTLE := 4

## The eight directions (`g_neighbor_dx/dy`, 1.3 `shandalar.c`):
## 1 N, 2 NE, 3 E, 4 SE, 5 S, 6 SW, 7 W, 8 NW; 0 is none.
const DX: Array[int] = [0, 0, 1, 1, 1, 0, -1, -1, -1]
const DY: Array[int] = [0, -1, -1, 0, 1, 1, 1, 0, -1]

## The 28 cards a dungeon may hold, in the 1.3 card table's order (the
## cards flagged `0x100`, "may be put in a dungeon"), by their internal
## index there and their name here.
const DUNGEON_CARDS: Array[Array] = [
	[106, "Copy Artifact"], [155, "Braingeyser"], [167, "Regrowth"],
	[187, "Sol Ring"], [215, "Ancestral Recall"], [223, "Berserk"],
	[238, "Mox Emerald"], [239, "Mox Jet"], [240, "Mox Pearl"],
	[241, "Mox Ruby"], [242, "Mox Sapphire"], [243, "Black Lotus"],
	[280, "Ali from Cairo"], [307, "Demonic Tutor"], [308, "Mind Twist"],
	[313, "Forcefield"], [324, "Wheel of Fortune"], [335, "Ivory Tower"],
	[338, "Timetwister"], [342, "Library of Alexandria"],
	[347, "Mishra's Workshop"], [383, "Candelabra of Tawnos"],
	[389, "Feldon's Cane"], [408, "Time Walk"], [409, "Time Vault"],
	[410, "Balance"], [411, "Cyclopean Tomb"], [422, "Fork"],
]

## What made it: the seed the dice stood at, the slot the site placement
## began with (the original's `clock() % 128`), the hero's colour (1 black,
## 2 blue, 3 green, 4 red, 5 white) and the difficulty, 0–3.
var seed := 0
var slot_start := 0
var color := 1
var difficulty := 0

var page := PackedByteArray()
## The 128 sites, by slot: `{x, y, type, trade, status}`.
var sites: Array[Dictionary] = []
## The twelve World Magics: the slot of the town or city offering each,
## 0 for none (a World Magic the hero already owns is offered nowhere).
var world_magic_sites: Array[int] = []
## The fifteen encounter slots: 0–4 the wizards' castles (black, blue,
## green, red, white), 5–14 the dungeons. `{x, y, town, color,
## monster_flags, rules, card_in_effect, cards}`; `cards` are dungeon card
## indices ([constant DUNGEON_CARDS]), and `card_in_effect` the 1.3 card
## id the encounter plays under, -1 for none. `clues` (absent for none) is
## what the hero has learned of it (`clues_bitmap`): 1 where it lies, 2 its
## creatures, 4 its rules ([WorldClues]).
var encounters: Array[Dictionary] = []
## Where the hero starts, in the original's world units (32 to a tile).
var start := Vector2i.ZERO
## The seven lair slots' first respawn times.
var lair_respawn: Array[int] = []
## The dice after the world was made, for whatever draws next.
var rand_state := 0


func terrain(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= TILES or y >= TILES:
		return OCEAN
	return page[y * PAGE_WIDTH + x] & 0xF


func tile_flags(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= TILES or y >= TILES:
		return 0
	return page[y * PAGE_WIDTH + x] & 0xF0


## The roads leaving tile (x, y): bit (d − 1) for direction d.
func road_bits(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= TILES or y >= TILES:
		return 0
	return page[(y + TILES) * PAGE_WIDTH + x]


func is_land(x: int, y: int) -> bool:
	return terrain(x, y) != OCEAN


func land_count() -> int:
	var count := 0
	for y in TILES:
		for x in TILES:
			if is_land(x, y):
				count += 1
	return count


func start_tile() -> Vector2i:
	return Vector2i(start.x / 32, start.y / 32)


## The site at tile (x, y), or `{}`.
func site_at(x: int, y: int) -> Dictionary:
	for site in sites:
		if int(site["x"]) == x and int(site["y"]) == y:
			return site
	return {}


## THE HERO SEES AROUND THEM (`DrawWorldTileRange`): every tile within
## seven screen rows and three screen columns of [param tile] is marked
## explored — what the overview map shows. The original does it as it
## draws, on its 640 × 480 screen's grid (a row is a step of ty − tx, a
## column two steps of tx + ty), and so does this, whatever the screen.
const EXPLORED := 0x80


func explore_around(tile: Vector2i) -> void:
	for y in TILES:
		for x in TILES:
			var row := (y - x) - (tile.y - tile.x)
			var column := ((x + y) - (tile.x + tile.y) - (row & 1)) / 2
			if absi(row) <= 7 and absi(column) <= 3:
				page[y * PAGE_WIDTH + x] = page[y * PAGE_WIDTH + x] | EXPLORED


func is_explored(x: int, y: int) -> bool:
	return tile_flags(x, y) & EXPLORED != 0


## THE COLOURS OF A TERRAIN (`GetWorldTileMagicMask`, 005611c8): bit 1
## black, 2 blue, 3 green, 4 red, 5 white — a single colour, or two for
## the in-between terrains.
static func magic_mask(code: int) -> int:
	match code:
		3: return 0x02
		1: return 0x04
		2: return 0x08
		5: return 0x10
		6: return 0x20
		8: return 0x06
		10: return 0x28
		13: return 0x22
		15: return 0x18
		4: return 0x30
		7: return 0x24
		9: return 0x14
		11: return 0x0A
		12: return 0x12
		14: return 0x0C
	return 0


## A fingerprint of the world's tiles and roads (32-bit FNV-1a over the
## page's first 128 rows, 64 bytes each), for tests that hold a world to
## the original's.
func fingerprint() -> String:
	var h := 2166136261
	for y in TILES * 2:
		for x in TILES:
			h = ((h ^ page[y * PAGE_WIDTH + x]) * 16777619) & 0xFFFFFFFF
	return "%08x" % h

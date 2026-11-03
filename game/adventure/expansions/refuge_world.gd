class_name RefugeWorld
extends RefCounted
## PROTOTYPE GAME DESIGN TEST: the smaller island explores region geography,
## pacing and readable quest routes using the existing Shandalar world systems.
## A compact island made from the mainland generator's terrain, with its
## own places. Mainland generation and its random stream are untouched.

const SIDE := 32
const OFFSET := 16
const TOWNS := ["Leitbur's Rest", "Vodalian Haven", "Freehold of the Hand", "Dwarven Hearth", "Havenwood"]
## The island's own names for its other places, Sarpadian in feeling and none
## a mainland name (the owner's ruling of 2026-11-03, 0.60.13 bug campaign;
## they took the mainland's names by slot before). The extra towns by slot,
## each keeping the word of the picture its slot shows ([WorldView] draws a
## town by its slot) — the temple city stands on the shore, where the
## Vodalian channel quest prefers it …
const PLACES := {22: "Svyelun's Temple", 43: "Thelon's Oasis", 58: "Trokair Bazaar",
	76: "Delif's Shrine", 80: "Zelyon Tower", 103: "Farrel's Mill"}
## … and the six to nine villages, slots 8, 16 … 72: the first near the
## mountains, where the Dwarven Hearth's raider waits. Names consume no dice,
## so every seed's island is laid out as before.
const VILLAGES := ["Anvilholm", "Thrullwick", "Moonwater", "Brassclaw Hollow", "Shellcove",
	"Tourach's Fall", "Sporeford", "New Icatia", "Warrenmouth"]
const COLORS := [6, 1, 3, 5, 2]  # plains, island, swamp, mountain, forest

static func component(world: ShandalarWorld, start: Vector2i) -> Array[Vector2i]:
	return RegionGeography.component(world, start)

static func coast(world: ShandalarWorld, tile: Vector2i) -> bool:
	return RegionGeography.coast(world, tile)

static func port_for(world: ShandalarWorld, from: Vector2i) -> Vector2i:
	return RegionGeography.port_for(world, from)

static func generate(seed_value: int, color: int, difficulty: int) -> ShandalarWorld:
	var source := WorldGenerator.generate(seed_value, 0, color, difficulty)
	var world := ShandalarWorld.new()
	world.seed = seed_value
	world.color = color
	world.difficulty = difficulty
	world.rand_state = source.rand_state
	world.page.resize(ShandalarWorld.PAGE_WIDTH * ShandalarWorld.PAGE_HEIGHT)
	for y in SIDE:
		for x in SIDE:
			world.page[(y + OFFSET) * ShandalarWorld.PAGE_WIDTH + x + OFFSET] = source.terrain(x * 2, y * 2)
	# Keep one connected island. Every town and the return ship is reachable
	# without walking across water or relying on a late-game world magic.
	var largest: Array[Vector2i] = []
	var seen := {}
	for y in range(OFFSET, OFFSET + SIDE):
		for x in range(OFFSET, OFFSET + SIDE):
			var tile := Vector2i(x, y)
			if seen.has(tile) or not world.is_land(x, y):
				continue
			var part := component(world, tile)
			for p in part:
				seen[p] = true
			if part.size() > largest.size():
				largest = part
	var land := {}
	for tile in largest:
		land[tile] = true
	for tile in seen:
		if not land.has(tile):
			world.page[tile.y * ShandalarWorld.PAGE_WIDTH + tile.x] = 0
	var dice := MsvcRandom.new(source.rand_state ^ 0x524546)
	var middle := _nearest(largest, Vector2i(30 + dice.below(5), 30 + dice.below(5)), [])
	var shore: Array[Vector2i] = []
	for tile in largest:
		if coast(world, tile):
			shore.append(tile)
	var port := _nearest(shore, Vector2i(23 + dice.below(19), 48), [middle])
	var used: Array[Vector2i] = [middle, port]
	var aims := [Vector2i(-9, -8), Vector2i(9, -9), Vector2i(9, 3), Vector2i(3, 10), Vector2i(-10, 5)]
	var rotation := dice.below(4)
	for slot in 128:
		world.sites.append({"x": 0, "y": 0, "type": 0, "trade": 0, "status": 0})
	var names := {}
	var traders: Array[int] = []
	for i in 5:
		var aim: Vector2i = aims[i]
		for turn in rotation:
			aim = Vector2i(-aim.y, aim.x)
		aim += Vector2i(32 + dice.below(7) - 3, 32 + dice.below(7) - 3)
		var tile := _nearest(largest, aim, used)
		used.append(tile)
		_put_site(world, i + 1, tile, ShandalarWorld.TOWN)
		world.page[tile.y * 320 + tile.x] = COLORS[i] | ShandalarWorld.SITE
		names[str(i + 1)] = TOWNS[i]
		traders.append(i + 1)
	# The mainland's town, city and village services, with its temple/oasis/
	# bazaar/shrine/tower/mill pictures, in randomized places under the
	# island's own names.
	for slot in [22, 43, 58, 76, 80, 103]:
		var pool := shore if slot == 22 else largest
		var tile := _random_place(pool, used, dice, 4.0)
		if tile.x < 0: tile = _random_place(largest, used, dice, 1.0)
		used.append(tile)
		_put_site(world, slot, tile, ShandalarWorld.CITY if slot in [22, 58] else ShandalarWorld.TOWN)
		names[str(slot)] = PLACES[slot]
		traders.append(slot)
	var villages := 6 + dice.below(4)
	for i in villages:
		var pool: Array[Vector2i] = []
		if i == 0:
			for point in largest:
				if RegionObjectives.matches(world, point, {"near_terrain": 5, "radius": 2}): pool.append(point)
		var tile := _random_place(pool if not pool.is_empty() else largest, used, dice, 3.0)
		if tile.x < 0: tile = _random_place(largest, used, dice, 1.0)
		used.append(tile)
		_put_site(world, (i + 1) * 8, tile, ShandalarWorld.VILLAGE)
		names[str((i + 1) * 8)] = VILLAGES[i]
	# Every mainland trade category appears: six colors and five card types.
	var goods := [1, 2, 4, 8, 16, 32, 0x100, 0x200, 0x300, 0x400, 0x500]
	for slot in traders:
		world.sites[slot]["trade"] = goods.pop_at(dice.below(goods.size()))
	world.world_magic_sites.assign([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	var sellers := traders.duplicate()
	var magics: Array[int] = []
	for magic in 12:
		if magic != color * 2: magics.append(magic)
	for offer in 3:
		world.world_magic_sites[magics.pop_at(dice.below(magics.size()))] = sellers.pop_at(dice.below(sellers.size()))
	RegionRoads.build(world, used, dice)
	# Keep the five wizard slots empty; the shared dungeon system reserves
	# indices 0-4 for the mainland's lords. Only slot 5 is a real encounter.
	for i in 5:
		world.encounters.append({"x": 0, "y": 0, "cards": [], "clues": 0})
	var dungeon: Dictionary = source.encounters[5 + dice.below(10)].duplicate(true)
	var away: Array[Vector2i] = []
	for tile in largest:
		if world.tile_flags(tile.x, tile.y) & (ShandalarWorld.SITE | ShandalarWorld.ROAD) == 0:
			away.append(tile)
	var door := _random_place(away, used, dice, 3.0)
	dungeon["x"] = door.x
	dungeon["y"] = door.y
	dungeon["town"] = _nearest_town(world, door, traders)
	dungeon["clues"] = WorldClues.LOCATION
	world.encounters.append(dungeon)
	world.page[door.y * 320 + door.x] |= ShandalarWorld.DUNGEON
	world.lair_respawn.assign([0, 0, 0, 0, 0, 0, 0])
	world.start = port * 32 + Vector2i(16, 16)
	world.expansion = {"region": "refuge", "layout_version": 4, "port": [port.x, port.y],
		"castle": [middle.x, middle.y], "town_names": names,
		"dungeon_names": {"5": "Vaults of the First Crossing"}}
	world.rand_state = dice.state
	return world

static func _put_site(world: ShandalarWorld, slot: int, tile: Vector2i, kind: int) -> void:
	world.sites[slot] = {"x": tile.x, "y": tile.y, "type": kind, "trade": 0, "status": 0}
	world.page[tile.y * 320 + tile.x] |= ShandalarWorld.SITE

static func _random_place(tiles: Array[Vector2i], used: Array[Vector2i], dice: MsvcRandom, gap: float) -> Vector2i:
	var choices: Array[Vector2i] = []
	while choices.is_empty() and gap >= 1.0:
		for tile in tiles:
			var clear := true
			for other in used:
				if tile.distance_to(other) < gap:
					clear = false
					break
			if clear: choices.append(tile)
		gap -= 0.5
	return choices[dice.below(choices.size())] if not choices.is_empty() else Vector2i(-1, -1)

static func _nearest_town(world: ShandalarWorld, tile: Vector2i, traders: Array[int]) -> int:
	var chosen := traders[0]
	var distance := INF
	for slot in traders:
		var site: Dictionary = world.sites[slot]
		var gap := tile.distance_squared_to(Vector2i(site["x"], site["y"]))
		if gap < distance:
			distance = gap
			chosen = slot
	return chosen

static func _nearest(tiles: Array[Vector2i], aim: Vector2i, used: Array[Vector2i]) -> Vector2i:
	var best := Vector2i(-1, -1)
	var score := INF
	for tile in tiles:
		var clear := true
		for other in used:
			if tile.distance_to(other) < 4.0:
				clear = false
		var distance := tile.distance_squared_to(aim)
		if clear and distance < score:
			score = distance
			best = tile
	return best

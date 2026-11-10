class_name IslandGenerator
extends RefCounted
## ADVENTURE PLUGINS — the island recipe's interpreter (`world.json`,
## `"generator": "island"`). A compact island cut from the mainland
## generator's own terrain, its places laid out by the adventure's dice.
## Every constant of the Last Refuge's built-in generator (0.60.5–0.60.19)
## is a recipe field here, and the Refuge's recipe makes its island to the
## bit (tests/unit/test_island_generator_golden.gd: 70 cases captured from
## the old generator before it went). Mainland generation and its random
## stream are untouched; names and objectives consume no dice.
##
## The order of the draws IS the island: the castle's aim (x, then y), the
## port's, the towns' quarter turns, each town's aim (x, then y), the extra
## places, the villages' count and each village, the trade goods, the
## world magic, the roads, the dungeon's source and its door. A span of 0
## or 1 draws nothing ([method MsvcRandom.below]).

## The recipe a plugin's world.json is normalized into ([PluginSchema]),
## with the Last Refuge's values — every field a plugin may set.
const DEFAULTS := {
	"generator": "island",
	"layout_version": 1,
	"side": 32, "offset": 16, "step": 2, "slot_start": 0,
	"dice_salt": 0x524546,
	"spacing": 4.0,
	"castle": {"from": [30, 30], "span": [5, 5]},
	"port": {"from": [23, 48], "span": [19, 0]},
	"towns": {"center": [32, 32], "spread": 7, "turns": 4, "list": []},
	"places": {"gap": 4.0, "list": []},
	"villages": {"names": [], "count": [0, 0], "slot_step": 8, "gap": 3.0, "first_rule": {}},
	"trade": [1, 2, 4, 8, 16, 32, 0x100, 0x200, 0x300, 0x400, 0x500],
	"world_magic": {"offers": 3},
	"roads": true,
	"dungeon": {"name": "", "from": 5, "choices": 10, "gap": 3.0},
	"objectives": {},
}

const KINDS := {"village": ShandalarWorld.VILLAGE, "town": ShandalarWorld.TOWN, "city": ShandalarWorld.CITY}


## The island of [param recipe] for [param seed_value] (the mainland's seed
## already salted by the region, [method AdventureExpansions.generate]),
## the hero's [param color] and [param difficulty]. Its
## `world.expansion.region` is the recipe's `region` (the plugin id).
static func generate(recipe: Dictionary, seed_value: int, color: int, difficulty: int) -> ShandalarWorld:
	var source := WorldGenerator.generate(seed_value, int(recipe["slot_start"]), color, difficulty)
	var world := ShandalarWorld.new()
	world.seed = seed_value
	world.color = color
	world.difficulty = difficulty
	world.rand_state = source.rand_state
	world.page.resize(ShandalarWorld.PAGE_WIDTH * ShandalarWorld.PAGE_HEIGHT)
	var side := int(recipe["side"])
	var offset := int(recipe["offset"])
	var step := int(recipe["step"])
	for y in side:
		for x in side:
			world.page[(y + offset) * ShandalarWorld.PAGE_WIDTH + x + offset] = source.terrain(x * step, y * step)
	# Keep one connected island: every place and the ship are reachable
	# without walking across water or a late-game world magic.
	var largest: Array[Vector2i] = []
	var seen := {}
	for y in range(offset, offset + side):
		for x in range(offset, offset + side):
			var tile := Vector2i(x, y)
			if seen.has(tile) or not world.is_land(x, y):
				continue
			var part := RegionGeography.component(world, tile)
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
	var dice := MsvcRandom.new(source.rand_state ^ int(recipe["dice_salt"]))
	var spacing := float(recipe["spacing"])
	var middle := _nearest(largest, _aim(recipe["castle"], dice), [], spacing)
	var shore: Array[Vector2i] = []
	for tile in largest:
		if RegionGeography.coast(world, tile):
			shore.append(tile)
	var port := _nearest(shore, _aim(recipe["port"], dice), [middle], spacing)
	var used: Array[Vector2i] = [middle, port]
	var towns: Dictionary = recipe["towns"]
	var center: Array = towns["center"]
	var spread := int(towns["spread"])
	var rotation := dice.below(int(towns["turns"]))
	for slot in 128:
		world.sites.append({"x": 0, "y": 0, "type": 0, "trade": 0, "status": 0})
	var names := {}
	var traders: Array[int] = []
	for town in towns["list"]:
		var aim := Vector2i(int(town["aim"][0]), int(town["aim"][1]))
		for turn in rotation:
			aim = Vector2i(-aim.y, aim.x)
		var dx := int(center[0]) + dice.below(spread) - spread / 2
		var dy := int(center[1]) + dice.below(spread) - spread / 2
		aim += Vector2i(dx, dy)
		var tile := _nearest(largest, aim, used, spacing)
		used.append(tile)
		var slot := int(town["slot"])
		_put_site(world, slot, tile, ShandalarWorld.TOWN)
		world.page[tile.y * ShandalarWorld.PAGE_WIDTH + tile.x] = int(town["terrain"]) | ShandalarWorld.SITE
		names[str(slot)] = String(town["name"])
		traders.append(slot)
	# The mainland's town, city and village services, with the pictures
	# their slots show ([WorldView] draws a town by its slot), in
	# randomized places under the island's own names.
	var places: Dictionary = recipe["places"]
	for place in places["list"]:
		var pool := shore if bool(place.get("coastal", false)) else largest
		var tile := _random_place(pool, used, dice, float(places["gap"]))
		if tile.x < 0: tile = _random_place(largest, used, dice, 1.0)
		used.append(tile)
		var slot := int(place["slot"])
		_put_site(world, slot, tile, int(KINDS[String(place["kind"])]))
		names[str(slot)] = String(place["name"])
		traders.append(slot)
	var villages: Dictionary = recipe["villages"]
	var low := int(villages["count"][0])
	var count := low + dice.below(int(villages["count"][1]) - low + 1)
	var first_rule := site_rule(villages["first_rule"]) if not villages["first_rule"].is_empty() else {}
	for i in count:
		var pool: Array[Vector2i] = []
		if i == 0 and not first_rule.is_empty():
			for point in largest:
				if RegionObjectives.matches(world, point, first_rule): pool.append(point)
		var tile := _random_place(pool if not pool.is_empty() else largest, used, dice, float(villages["gap"]))
		if tile.x < 0: tile = _random_place(largest, used, dice, 1.0)
		used.append(tile)
		var slot := (i + 1) * int(villages["slot_step"])
		_put_site(world, slot, tile, ShandalarWorld.VILLAGE)
		names[str(slot)] = String(villages["names"][i])
	# Every listed trade category, one to each trading place.
	var goods: Array = recipe["trade"].duplicate()
	for slot in traders:
		world.sites[slot]["trade"] = int(goods.pop_at(dice.below(goods.size()))) if not goods.is_empty() else 0
	world.world_magic_sites.assign([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	var sellers := traders.duplicate()
	var magics: Array[int] = []
	for magic in 12:
		if magic != color * 2: magics.append(magic)
	for offer in int(recipe["world_magic"]["offers"]):
		if sellers.is_empty(): break
		world.world_magic_sites[magics.pop_at(dice.below(magics.size()))] = sellers.pop_at(dice.below(sellers.size()))
	if bool(recipe["roads"]):
		RegionRoads.build(world, used, dice)
	# The five wizard slots stay empty: the shared dungeon system reserves
	# indices 0-4 for the mainland's lords. Only slot 5 is an encounter.
	for i in 5:
		world.encounters.append({"x": 0, "y": 0, "cards": [], "clues": 0})
	var cave: Dictionary = recipe["dungeon"]
	var dungeon: Dictionary = source.encounters[int(cave["from"]) + dice.below(int(cave["choices"]))].duplicate(true)
	var away: Array[Vector2i] = []
	for tile in largest:
		if world.tile_flags(tile.x, tile.y) & (ShandalarWorld.SITE | ShandalarWorld.ROAD) == 0:
			away.append(tile)
	var door := _random_place(away, used, dice, float(cave["gap"]))
	if door.x < 0: door = _random_place(largest, used, dice, 1.0)
	dungeon["x"] = door.x
	dungeon["y"] = door.y
	dungeon["town"] = _nearest_town(world, door, traders)
	dungeon["clues"] = WorldClues.LOCATION
	world.encounters.append(dungeon)
	world.page[door.y * ShandalarWorld.PAGE_WIDTH + door.x] |= ShandalarWorld.DUNGEON
	world.lair_respawn.assign([0, 0, 0, 0, 0, 0, 0])
	world.start = port * 32 + Vector2i(16, 16)
	world.expansion = {"region": String(recipe["region"]), "layout_version": int(recipe["layout_version"]),
		"port": [port.x, port.y], "castle": [middle.x, middle.y], "town_names": names,
		"dungeon_names": {"5": String(cave["name"])}}
	world.rand_state = dice.state
	return world


## The recipe's named objectives on [param world] (`{name: slot}`, -1 for
## none): each the first site its rule matches, its preferred slot when that
## one matches ([method RegionObjectives.site]). No dice; nothing moves.
static func objectives(world: ShandalarWorld, recipe: Dictionary) -> Dictionary:
	var out := {}
	for name in recipe.get("objectives", {}):
		var rule: Dictionary = recipe["objectives"][name]
		out[name] = RegionObjectives.site(world, site_rule(rule), int(rule.get("prefer", -1)))
	return out


## A recipe's site rule in [RegionObjectives]' terms: the kinds by name
## (village, town, city) as site types.
static func site_rule(rule: Dictionary) -> Dictionary:
	var out := rule.duplicate(true)
	out.erase("prefer")
	if out.has("types"):
		var types: Array[int] = []
		for kind in out["types"]: types.append(int(KINDS.get(String(kind), int(kind) if kind is int else 0)))
		out["types"] = types
	if out.has("exclude"):
		var slots: Array[int] = []
		for slot in out["exclude"]: slots.append(int(slot))
		out["exclude"] = slots
	return out


## A castle's or port's aim: `from` plus a draw under each axis's `span`.
static func _aim(spec: Dictionary, dice: MsvcRandom) -> Vector2i:
	var x := int(spec["from"][0]) + dice.below(int(spec["span"][0]))
	var y := int(spec["from"][1]) + dice.below(int(spec["span"][1]))
	return Vector2i(x, y)


static func _put_site(world: ShandalarWorld, slot: int, tile: Vector2i, kind: int) -> void:
	world.sites[slot] = {"x": tile.x, "y": tile.y, "type": kind, "trade": 0, "status": 0}
	world.page[tile.y * ShandalarWorld.PAGE_WIDTH + tile.x] |= ShandalarWorld.SITE


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
	var chosen := traders[0] if not traders.is_empty() else 0
	var distance := INF
	for slot in traders:
		var site: Dictionary = world.sites[slot]
		var gap := tile.distance_squared_to(Vector2i(site["x"], site["y"]))
		if gap < distance:
			distance = gap
			chosen = slot
	return chosen


static func _nearest(tiles: Array[Vector2i], aim: Vector2i, used: Array[Vector2i], spacing: float) -> Vector2i:
	var best := Vector2i(-1, -1)
	var score := INF
	for tile in tiles:
		var clear := true
		for other in used:
			if tile.distance_to(other) < spacing:
				clear = false
		var distance := tile.distance_squared_to(aim)
		if clear and distance < score:
			score = distance
			best = tile
	return best

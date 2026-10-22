extends GutTest
## THE 1997 WORLD, EXACTLY (2026-10-22): [WorldGenerator] makes the
## original's world from the original's dice. The golden worlds below were
## made by a scratch harness built from the matching decompilation of 1.3
## (never part of this project) and agree with ours on every tile, road,
## site, World Magic, castle, dungeon and start, and on the dice after;
## 40 worlds were compared the same way when the port was written
## (`docs/world-builder-adventure-notes.md`, "Exactness"). The invariants
## below hold any world to the original's rules without the harness.


func test_the_dice_are_the_c_runtime_s() -> void:
	var dice := MsvcRandom.new(1)
	var first: Array[int] = []
	for i in 5:
		first.append(dice.rand())
	assert_eq(first, [41, 18467, 6334, 26500, 19169] as Array[int], "MSVC rand() after srand(1)")
	dice.reseed(1)
	assert_eq(dice.below(16), 41 % 16)
	assert_eq(dice.below(1), 0, "a maximum of 1 draws nothing")
	assert_eq(dice.state, 1 * 214013 + 2531011, "one draw so far")


func test_the_distance_and_the_bands() -> void:
	assert_eq(WorldGenerator.distance(3, -5), 13, "twice the longer leg plus the shorter")
	assert_eq(WorldGenerator.distance(-4, 4), 12)
	var bands := {0: 0, 15: 0, 16: 1, 21: 1, 22: 8, 23: 8, 24: 3, 31: 3, 32: 13, 33: 13,
		34: 6, 39: 6, 40: 10, 42: 10, 43: 2, 55: 2, 56: 15, 59: 15, 60: 5, 95: 5}
	for height in bands:
		assert_eq(WorldGenerator.terrain_for(height, -1), bands[height], "height %d" % height)
	assert_eq(WorldGenerator.terrain_for(96, 7), 7, "over 95 keeps the last code (never reached)")


## [seed, slot start, colour, difficulty, tiles and roads, sites (md5 of
## their lines), World Magic sites, castles and dungeons (md5), start, dice].
const GOLDEN := [
	[12345, 0, 4, 1, "3d685b38", "d99ce1234d46e947ec468e1aa46e8012", [125, 91, 79, 12, 13, 28, 75, 89, 0, 66, 118, 112], "fd6e96149cef23bbd77e4896c8420c94", Vector2i(1040, 1424), 1819030352],
	[1, 127, 1, 0, "36a347fe", "1c82c6c8ab37eb2ce2420e4a7a0e68ea", [10, 66, 0, 80, 43, 30, 109, 124, 17, 29, 108, 72], "e1e7e273ce766304029a83d6d82e83ec", Vector2i(1712, 784), 844689407],
	[2026102200, 64, 5, 3, "941ca9c0", "9f23b181a029977af41b4e0ce3165a07", [23, 127, 25, 126, 40, 48, 77, 11, 56, 15, 0, 76], "ce265651dd52610bb33a1a8a89336505", Vector2i(528, 720), 3688262486],
	[4294967295, 13, 3, 2, "34f9a2bd", "1d6378e2dc615147e9d02b55b5d1adcc", [121, 33, 75, 101, 102, 103, 0, 112, 123, 13, 89, 122], "3fa0ab14641d28d3e7406a441360524b", Vector2i(1264, 560), 3281094254],
]


func test_the_golden_worlds_are_the_original_s() -> void:
	for row in GOLDEN:
		var world := WorldGenerator.generate(row[0], row[1], row[2], row[3])
		var label := "seed %d" % row[0]
		assert_eq(world.fingerprint(), row[4], label + ": tiles and roads")
		assert_eq(_site_lines(world).md5_text(), row[5], label + ": sites")
		assert_eq(Array(world.world_magic_sites), row[6], label + ": World Magics")
		assert_eq(_encounter_lines(world).md5_text(), row[7], label + ": castles and dungeons")
		assert_eq(world.start, row[8], label + ": start")
		assert_eq(world.rand_state, row[9], label + ": the dice after")


## A WORLD THE 1997 GAME SAVED (2026-10-22): the one world in the owner's
## Windows XP install (a Manalink build of the original). From the dice and
## slot start found for it, the save agrees with ours on every tile, road
## and flag and on every site's place, kind, trade and status. What the
## save does not hold (the hero's colour, so the World Magic withheld and
## the start) is left out; its difficulty was 2.
const SAVED_BY_THE_GAME := [17281995, 31, 1, 2, "0e626e76", "aa081c6a3c9fdc9bf8b4edb9b66967a9"]


func test_a_world_the_1997_game_saved_is_ours() -> void:
	var row := SAVED_BY_THE_GAME
	var world := WorldGenerator.generate(row[0], row[1], row[2], row[3])
	assert_eq(world.fingerprint(), row[4], "every tile, road and flag")
	assert_eq(_site_lines(world).md5_text(), row[5], "every site")


## NEVER STUCK. On this seed the original keeps a 30-tile islet and hangs
## picking the trade goods' towns; ours sees the islet has no room for six
## towns and cities and makes the world again. The row is the guarded
## harness's, which shares the guards (`world-builder-adventure-notes.md`,
## "Never stuck").
const ONCE_STUCK := [1893184459, 111, 1, 0, "da734929", "4f5f53d7b72f12c0723fdb3cebb04ed1", [110, 14, 0, 82, 106, 12, 8, 93, 127, 20, 36, 53], "4115d44671db8776cddcbf45b75d0e32", Vector2i(912, 1872), 536479082]


func test_a_world_the_original_never_finishes_is_made_again() -> void:
	var row := ONCE_STUCK
	var world := WorldGenerator.generate(row[0], row[1], row[2], row[3])
	assert_eq(world.fingerprint(), row[4], "tiles and roads")
	assert_eq(_site_lines(world).md5_text(), row[5], "sites")
	assert_eq(Array(world.world_magic_sites), row[6], "World Magics")
	assert_eq(_encounter_lines(world).md5_text(), row[7], "castles and dungeons")
	assert_eq(world.start, row[8], "start")
	assert_eq(world.rand_state, row[9], "the dice after")
	_check_terrain(world)
	_check_sites(world)


func test_each_guard_sees_a_loop_the_original_never_leaves() -> void:
	# No land at all: no site can be placed.
	var maker := _maker_on_ocean()
	assert_false(maker._place_sites(), "no land: the sites are given up")
	assert_true(maker._doomed, "and the world is to be made again")
	# A 3 × 3 islet: room for fewer towns and cities than trade goods.
	maker = _maker_on_ocean()
	for y in range(30, 33):
		for x in range(30, 33):
			maker._page[y * WorldGenerator.W + x] = 2
	assert_false(maker._place_sites(), "an islet: the sites are given up")
	assert_true(maker._doomed)
	for i in 128:
		assert_eq(maker._site_x[i], -1, "before a single site is placed")
	# No free tile of the hero's colour, no room for a dungeon.
	maker = _maker_on_ocean()
	assert_eq(maker._starting_point(1), Vector2i(-1, -1), "no start: the world is made again")
	assert_eq(maker._place_castles_and_dungeons(0), [] as Array[Dictionary], "no dungeon: the same")


func _maker_on_ocean() -> WorldGenerator:
	var maker := WorldGenerator.new()
	maker._page.resize(WorldGenerator.W * WorldGenerator.H)
	maker._page.fill(0)
	maker._rng.reseed(1)
	maker._site_type.resize(128)
	maker._site_type.fill(-1)
	maker._site_x.resize(128)
	maker._site_y.resize(128)
	return maker


func test_the_same_seed_makes_the_same_world() -> void:
	var a := WorldGenerator.generate(777, 5, 2, 0)
	var b := WorldGenerator.generate(777, 5, 2, 0)
	assert_eq(a.page, b.page)
	assert_eq(a.encounters, b.encounters)
	var c := WorldGenerator.generate(778, 5, 2, 0)
	assert_ne(a.fingerprint(), c.fingerprint(), "another seed, another world")


func test_a_world_keeps_the_original_s_rules() -> void:
	for row in [[12345, 0, 4, 1], [99, 77, 2, 0]]:
		var world := WorldGenerator.generate(row[0], row[1], row[2], row[3])
		_check_terrain(world)
		_check_sites(world)
		_check_encounters(world)
		var tile := world.start_tile()
		assert_ne(ShandalarWorld.magic_mask(world.terrain(tile.x, tile.y)) & (1 << world.color), 0,
			"the hero starts on their own colour")
		assert_eq(world.tile_flags(tile.x, tile.y) & ShandalarWorld.SITE, 0, "and not on a site")
		assert_eq(world.lair_respawn, [0, -100 * (4 - world.difficulty), -200 * (4 - world.difficulty),
			-300 * (4 - world.difficulty), -400 * (4 - world.difficulty), -500 * (4 - world.difficulty),
			-600 * (4 - world.difficulty)] as Array[int])


func _check_terrain(world: ShandalarWorld) -> void:
	# The original counts its 1,750 land tiles BEFORE the ponds are filled
	# and the land the flood never reaches is sunk, so a finished world may
	# hold fewer (seed 12345 keeps 1,591).
	assert_gt(world.land_count(), 0, "land")
	var made := [0, 1, 2, 3, 5, 6, 8, 10, 13, 15]
	var bad: Array[String] = []
	for y in 64:
		for x in 64:
			var code := world.terrain(x, y)
			if not code in made:
				bad.append("code %d at %d,%d" % [code, x, y])
			var sx := (x + y) * 3 - 32
			var sy := (y - x) * 3 + 100
			var outside := x < 2 or y < 2 or x >= 62 or y >= 62 \
				or sx < 4 or sy < 4 or sx >= 316 or sy >= 196
			if outside and code != 0:
				bad.append("land outside the frame at %d,%d" % [x, y])
	# ONE LANDMASS: every land tile reaches the flood's first tile through
	# land, the first tile itself counted whatever it is.
	var reached := {Vector2i(40, 24): true}
	var queue: Array[Vector2i] = [Vector2i(40, 24)]
	while not queue.is_empty():
		var at: Vector2i = queue.pop_back()
		for d in [1, 3, 5, 7]:
			var next := at + Vector2i(ShandalarWorld.DX[d], ShandalarWorld.DY[d])
			if not reached.has(next) and world.is_land(next.x, next.y):
				reached[next] = true
				queue.append(next)
	for y in 64:
		for x in 64:
			if world.is_land(x, y) and not reached.has(Vector2i(x, y)):
				bad.append("land cut off at %d,%d" % [x, y])
	assert_eq(bad, [] as Array[String], "seed %d: the terrain keeps the rules" % world.seed)


func _check_sites(world: ShandalarWorld) -> void:
	assert_eq(world.sites.size(), 128)
	var castle_colors := 0
	for site in world.sites:
		var x: int = site["x"]
		var y: int = site["y"]
		assert_true(world.is_land(x, y), "a site is on land")
		assert_ne(world.tile_flags(x, y) & ShandalarWorld.SITE, 0, "and flagged")
		assert_true(int(site["type"]) in [1, 2, 3, 4])
		if int(site["type"]) == ShandalarWorld.CASTLE:
			var colors := ShandalarWorld.magic_mask(world.terrain(x, y))
			assert_true(colors in [0x02, 0x04, 0x08, 0x10, 0x20], "a castle stands on one colour")
			castle_colors |= colors
	assert_eq(castle_colors, WorldGenerator.ALL_CASTLES, "one castle of each colour")
	for i in 12:
		var site: int = world.world_magic_sites[i]
		if world.color * 2 == i:
			assert_eq(site, 0, "the hero's own World Magic is offered nowhere")
			continue
		assert_gt(site, 0, "World Magic %d is offered" % i)
		assert_true(int(world.sites[site]["type"]) in [2, 3], "by a town or a city")


func _check_encounters(world: ShandalarWorld) -> void:
	assert_eq(world.encounters.size(), 15)
	var cards := 0
	for e in 15:
		var slot: Dictionary = world.encounters[e]
		cards += (slot["cards"] as Array).size()
		if e < 5:
			assert_eq(slot["color"], e + 1, "castle %d's colour" % e)
			var site := world.site_at(slot["x"], slot["y"])
			assert_eq(site.get("type"), ShandalarWorld.CASTLE, "castle %d stands on its castle" % e)
			continue
		assert_true(world.is_land(slot["x"], slot["y"]), "a dungeon is on land")
		assert_eq(world.tile_flags(slot["x"], slot["y"]) & (ShandalarWorld.SITE | ShandalarWorld.ROAD), 0,
			"off sites and roads")
		assert_ne(world.tile_flags(slot["x"], slot["y"]) & ShandalarWorld.DUNGEON, 0, "and flagged")
		assert_lte((slot["cards"] as Array).size(), 3)
	assert_eq(cards, ShandalarWorld.DUNGEON_CARDS.size(), "all 28 dungeon cards are hidden")


## The lines the harness prints, in its format.
func _site_lines(world: ShandalarWorld) -> String:
	var lines: Array[String] = []
	for i in 128:
		var s: Dictionary = world.sites[i]
		lines.append("site %d %d %d %d %d %d" % [i, s["x"], s["y"], s["type"], s["trade"], s["status"]])
	return "\n".join(lines)


func _encounter_lines(world: ShandalarWorld) -> String:
	var lines: Array[String] = []
	for e in 15:
		var slot: Dictionary = world.encounters[e]
		var ids: Array = []
		for k in slot["cards"]:
			ids.append(ShandalarWorld.DUNGEON_CARDS[k][0])
		while ids.size() < 3:
			ids.append(-1)
		lines.append("slot %d %d %d %d %d %d %d %d %d %d %d" % [e, slot["x"], slot["y"], slot["town"],
			slot["color"], slot["monster_flags"], slot["rules"], slot["card_in_effect"], ids[0], ids[1], ids[2]])
	return "\n".join(lines)

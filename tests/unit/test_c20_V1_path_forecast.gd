extends GutTest
## THE FOOD FORESEEN FOR THE PATH ARROWS (0.50.66; the owner's ruling of
## 2026-10-29: a click's way drawn on the land, the steps the food covers
## orange, the hungry ones red). [method HeroWalk.forecast] runs the walk's
## own ticks ahead — the pace, the stride and the meal [method
## HeroWalk.step] takes, one function each — so what it foresees for every
## tile is what a real walk then ticks: on seeded worlds over road, forest
## and plain, fed and hungry, an ascetic hero, Fruit of Sustenance and
## Quickening. And every mark's shape ([method WorldPath.shape]) is made.


## A seeded adventure, its hero on the world's start.
func _adventure(seed_text: String) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = seed_text
	var record := setup.resolve({})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	player.sieges = AdventurePlayer.SIEGES_NONE
	return player


## A world of one terrain [param code] everywhere, the walker in tile
## [param at]'s middle (test_hero_walk's).
func _walker(code: int, at: Vector2i) -> HeroWalk:
	var world := ShandalarWorld.new()
	world.page.resize(ShandalarWorld.PAGE_WIDTH * ShandalarWorld.PAGE_HEIGHT)
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			world.page[y * ShandalarWorld.PAGE_WIDTH + x] = code
	var player := AdventurePlayer.new()
	player.world = world
	player.sieges = AdventurePlayer.SIEGES_NONE
	player.position = at * 32 + Vector2i(16, 16)
	return HeroWalk.new(player)


static func _middle(tile: Vector2i) -> Vector2i:
	return tile * 32 + Vector2i(16, 16)


## Land tiles the hero can walk to from where they stand: [param count] of
## them, 8 to 18 steps off, the way found to each longer than 8.
func _targets(walk: HeroWalk, count: int) -> Array[Vector2i]:
	var world := walk.player.world
	var from := walk.player.tile()
	var out: Array[Vector2i] = []
	for reach in [10, 14, 18, 8, 12, 16]:
		for d in range(1, 9):
			var tile: Vector2i = from + Vector2i(ShandalarWorld.DX[d], ShandalarWorld.DY[d]) * reach
			tile = tile.clamp(Vector2i.ZERO, Vector2i(ShandalarWorld.TILES - 1, ShandalarWorld.TILES - 1))
			if not world.is_land(tile.x, tile.y) or tile in out:
				continue
			var way := walk.plan(tile)
			if way.size() > 8 and way.back() == tile:
				out.append(tile)
				if out.size() == count:
					return out
	return out


## THE REAL WALK to the end of [param tiles] (the way still to walk, the
## next first): for each tile, 1 when the hero reached its middle with food
## left, else 0 — read after every tick, as the walk itself ticks.
func _walked(walk: HeroWalk, tiles: Array[Vector2i]) -> PackedByteArray:
	var got := PackedByteArray()
	var i := 0
	for n in 40000:
		if not walk.is_walking() or i >= tiles.size():
			break
		walk.tick()
		walk.take_news()
		if walk.player.position == _middle(tiles[i]):
			got.append(1 if walk.player.food > 0 else 0)
			i += 1
	return got


## The hero's state the forecast must leave as it found it.
func _state(player: AdventurePlayer) -> Array:
	return [player.position, player.food, player.monster_timer, player.quickening, player.meal_half,
		player.step, player.facing, player.quest_timer, player.siege_timer]


## Forecast and walk compared for [param target] from where the hero stands,
## at [param food]: true when they agree tile for tile. [param seen] counts
## road, slow and plain tiles walked, and fed and hungry ones.
func _agrees(walk: HeroWalk, target: Vector2i, food: int, seen: Dictionary, label: String) -> bool:
	var player := walk.player
	# From a tile's middle: the way found starts on the tile stood on.
	player.position = _middle(player.tile())
	var start := player.position
	var timer := player.monster_timer
	var quick := player.quickening
	var half := player.meal_half
	player.food = food
	var tiles := walk.plan(target)
	tiles.remove_at(0)
	var before := _state(player)
	var want := walk.forecast(tiles)
	assert_eq(_state(player), before, "%s: the forecast leaves the hero as they were" % label)
	walk.walk_to(target)
	var got := _walked(walk, tiles)
	for i in tiles.size():
		var t := tiles[i]
		var kind := "road" if player.world.road_bits(t.x, t.y) != 0 \
			else ("slow" if walk._slow(player.world.terrain(t.x, t.y)) else "plain")
		seen[kind] = int(seen.get(kind, 0)) + 1
		if i < want.size():
			seen["fed" if want[i] == 1 else "hungry"] = int(seen.get("fed" if want[i] == 1 else "hungry", 0)) + 1
	walk.stop()
	player.position = start
	player.monster_timer = timer
	player.quickening = quick
	player.meal_half = half
	assert_eq(got, want, "%s: the walk ticks what was foreseen, tile for tile" % label)
	return got == want


func test_the_forecast_is_the_walk_tile_for_tile_on_several_worlds() -> void:
	var seen := {}
	var ways := 0
	for seed_text in ["145729", "12345", "6606", "31337"]:
		var player := _adventure(seed_text)
		var walk := HeroWalk.new(player)
		var targets := _targets(walk, 3)
		assert_eq(targets.size(), 3, "control: three far tiles on world %s" % seed_text)
		for target in targets:
			for food in [0, 2, 5, 9, 40]:
				# Each from another tick of the clock: the meals fall elsewhere.
				player.monster_timer = 1000 + food * 7 + ways
				_agrees(walk, target, food, seen, "world %s to %s, food %d" % [seed_text, target, food])
				ways += 1
	assert_gt(int(seen.get("road", 0)), 20, "control: roads walked %s" % seen)
	assert_gt(int(seen.get("slow", 0)), 20, "control: slow land walked %s" % seen)
	assert_gt(int(seen.get("plain", 0)), 20, "control: plain land walked %s" % seen)
	assert_gt(int(seen.get("fed", 0)), 20, "control: steps the food covered %s" % seen)
	assert_gt(int(seen.get("hungry", 0)), 20, "control: hungry steps %s" % seen)


func test_from_the_middle_of_a_step_too() -> void:
	var player := _adventure("6606")
	var walk := HeroWalk.new(player)
	var target := _targets(walk, 1)[0]
	player.food = 4
	walk.walk_to(target)
	for i in 45:
		walk.tick()
	assert_ne(player.position, _middle(player.tile()), "control: between two tiles' middles")
	var tiles: Array[Vector2i] = walk.path.duplicate()
	var want := walk.forecast(tiles)
	assert_eq(_walked(walk, tiles), want, "the way still to walk, foreseen from half a step")
	assert_true(want.has(0) and want.has(1), "control: fed, then hungry: %s" % want)


func test_an_ascetic_hero_eats_every_other_step() -> void:
	var seen := {}
	var player := _adventure("12345")
	player.ascetic = true
	var walk := HeroWalk.new(player)
	var target := _targets(walk, 1)[0]
	for half in [0, 1]:
		player.meal_half = half
		_agrees(walk, target, 4, seen, "ascetic, half-meal %d" % half)
		assert_eq(player.meal_half, half, "the half-meal put back after the forecast")
	player.ascetic = false
	player.meal_half = 0
	var plain := walk.plan(target)
	plain.remove_at(0)
	player.food = 2
	var eater := walk.forecast(plain)
	player.ascetic = true
	var ascetic := walk.forecast(plain)
	assert_gt(ascetic.count(1), eater.count(1), "control: the ascetic's food lasts longer (%s, %s)" % [
		ascetic, eater])


func test_fruit_of_sustenance_feeds_the_hungry_again_in_a_forest() -> void:
	# Plain land to x 13, forest from x 14: hungry over the plain, the fruit's
	# two given back at the first meal in the forest.
	var walk := _walker(6, Vector2i(10, 10))
	for y in ShandalarWorld.TILES:
		for x in range(14, ShandalarWorld.TILES):
			walk.player.world.page[y * ShandalarWorld.PAGE_WIDTH + x] = 2
	walk.player.world_magics.append("Fruit of Sustenance")
	walk.player.monster_timer = 1
	var target := Vector2i(20, 10)
	var seen := {}
	assert_true(_agrees(walk, target, 0, seen, "fruit, from hungry"))
	var tiles := walk.plan(target)
	tiles.remove_at(0)
	walk.player.food = 0
	var fed := walk.forecast(tiles)
	assert_eq(fed[0], 0, "control: the plain walked hungry: %s" % fed)
	assert_eq(fed[fed.size() - 1], 1, "the fruit's meal in the forest: fed again: %s" % fed)
	var player := _adventure("145729")
	player.world_magics.append("Fruit of Sustenance")
	walk = HeroWalk.new(player)
	for target_tile in _targets(walk, 2):
		_agrees(walk, target_tile, 1, seen, "fruit on world 145729 to %s" % target_tile)


func test_quickening_runs_ahead_and_out() -> void:
	var player := _adventure("31337")
	var walk := HeroWalk.new(player)
	var target := _targets(walk, 1)[0]
	var seen := {}
	for quick in [400, 90]:
		player.quickening = quick
		_agrees(walk, target, 3, seen, "Quickening %d ticks" % quick)
	player.quickening = 0
	var tiles := walk.plan(target)
	tiles.remove_at(0)
	player.food = 3
	var slow := walk.forecast(tiles)
	player.quickening = 400
	var quick := walk.forecast(tiles)
	assert_gt(quick.count(1), slow.count(1), "control: quicker, so further on the same food")


func test_the_walk_keeps_its_1997_pace_through_the_shared_rules() -> void:
	# The step's pace read through [method HeroWalk.pace] / [method
	# HeroWalk.stride]: a unit a tick on plain land, two every third tick on
	# forest, and hungry slower (test_hero_walk pins the whole walk).
	var walk := _walker(6, Vector2i(10, 10))
	var at := _middle(Vector2i(10, 10))
	assert_eq(walk.pace(at, 3, false), 1, "plain land")
	assert_eq(walk.pace(at, 3, true), 3, "hungry on plain land: two more")
	assert_eq(walk.stride(at, 3, 1, 0, 0, _middle(Vector2i(11, 10))), at + Vector2i(1, 0))
	walk = _walker(2, Vector2i(10, 10))
	assert_eq(walk.pace(at, 3, false), HeroWalk.SLOW, "forest")
	assert_eq(walk.pace(at, 3, true), 4, "hungry in forest: at most four")
	assert_eq(walk.stride(at, 3, HeroWalk.SLOW, 0, 0, _middle(Vector2i(11, 10))), at + Vector2i(2, 0))
	assert_eq(walk.stride(at, 3, HeroWalk.SLOW, 0, 5, _middle(Vector2i(11, 10))), at + Vector2i(3, 0),
		"a unit more under Quickening")
	assert_eq(walk.stride(_middle(Vector2i(11, 10)) - Vector2i(1, 0), 3, HeroWalk.SLOW, 0, 0,
		_middle(Vector2i(11, 10))), _middle(Vector2i(11, 10)), "never past the middle")


# ------------------------------------------------------------ the marks --

func test_every_mark_s_shape_is_made_once() -> void:
	for into in range(0, 9):
		for out in range(0, 9):
			var layers := WorldPath.shape(into, out)
			assert_eq(layers.size(), 5, "five layers for %d > %d" % [into, out])
			for layer in layers:
				assert_gt((layer as PackedVector2Array).size(), 2, "a polygon for %d > %d" % [into, out])
			assert_true(is_same(WorldPath.shape(into, out), layers), "kept, not made again")
	var straight := WorldPath.shape(3, 3)[2] as PackedVector2Array
	var bent := WorldPath.shape(3, 4)[2] as PackedVector2Array
	assert_ne(straight, bent, "a turn bends the arrow")
	assert_true(is_same(WorldPath.shape(5, 0), WorldPath.shape(0, 0)), "one X for every last tile")
	# A straight arrow points its way: the farthest point is its head.
	var tip := Vector2.ZERO
	for p in straight:
		if p.length() > tip.length():
			tip = p
	assert_gt(tip.dot(WorldPath._on_screen(3)), 0.0, "way 3 points along the screen's way 3")

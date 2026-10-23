extends GutTest
## WALKING (2026-10-22): [HeroWalk] walks the hero at the 1997 pace, tick
## for tick (1.3 `UpdateAdventureWorldInputAndMovement`) — a unit a tick on
## plain land, two every third on forest, half again on a road, slower
## hungry, a food every 32nd tick — along a way found around the sea [QoL].


## A world of one terrain [param code] everywhere, with the sea where
## [param sea] says, and a walker standing in tile [param at]'s middle.
func _walker(code: int, at: Vector2i, sea: Array[Vector2i] = []) -> HeroWalk:
	var world := ShandalarWorld.new()
	world.page.resize(ShandalarWorld.PAGE_WIDTH * ShandalarWorld.PAGE_HEIGHT)
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			world.page[y * ShandalarWorld.PAGE_WIDTH + x] = code
	for tile in sea:
		world.page[tile.y * ShandalarWorld.PAGE_WIDTH + tile.x] = ShandalarWorld.OCEAN
	var player := AdventurePlayer.new()
	player.world = world
	player.food = 50
	player.position = at * 32 + Vector2i(16, 16)
	return HeroWalk.new(player)


## Ticks until the walk ends (at most [param most]).
func _ticks(walk: HeroWalk, most := 1000) -> int:
	var count := 0
	while walk.is_walking() and count < most:
		walk.tick()
		count += 1
	return count


func test_plain_land_is_a_unit_a_tick_and_a_diagonal_no_longer() -> void:
	var walk := _walker(6, Vector2i(10, 10))
	assert_true(walk.walk_to(Vector2i(12, 10)))
	assert_eq(_ticks(walk), 64, "two tiles east: 64 units, 64 ticks")
	assert_eq(walk.player.position, Vector2i(12, 10) * 32 + Vector2i(16, 16))
	walk = _walker(6, Vector2i(10, 10))
	walk.walk_to(Vector2i(12, 12))
	assert_eq(_ticks(walk), 64, "two tiles south-east: the same")


func test_forest_is_two_units_every_third_tick() -> void:
	var walk := _walker(2, Vector2i(10, 10))
	walk.walk_to(Vector2i(12, 10))
	assert_eq(_ticks(walk), 94, "32 strides of two, on ticks 0, 3 … 93")


func test_an_amulet_of_swampwalk_or_a_dwarven_pick_keeps_the_pace() -> void:
	var walk := _walker(3, Vector2i(10, 10))
	walk.walk_to(Vector2i(12, 10))
	assert_eq(_ticks(walk), 94, "swamp is slow")
	walk = _walker(3, Vector2i(10, 10))
	walk.player.world_magics.append("Amulet of Swampwalk")
	walk.walk_to(Vector2i(12, 10))
	assert_eq(_ticks(walk), 64, "not with the amulet")
	walk = _walker(5, Vector2i(10, 10))
	walk.player.world_magics.append("Dwarven Pick")
	walk.walk_to(Vector2i(12, 10))
	assert_eq(_ticks(walk), 64, "nor mountains with the pick")


func test_a_road_is_quicker_even_through_forest() -> void:
	var walk := _walker(2, Vector2i(10, 10))
	var world := walk.player.world
	for x in range(10, 13):
		world.page[10 * ShandalarWorld.PAGE_WIDTH + x] |= ShandalarWorld.ROAD
		world.page[(10 + 64) * ShandalarWorld.PAGE_WIDTH + x] = (1 << 2) | (1 << 6)
	walk.walk_to(Vector2i(12, 10))
	var ticks := _ticks(walk)
	assert_lt(ticks, 64, "quicker than plain land: %d" % ticks)
	assert_gt(ticks, 40, "half again, not more")


func test_a_walker_eats_and_the_clocks_move_on() -> void:
	var walk := _walker(6, Vector2i(10, 10))
	walk.walk_to(Vector2i(12, 10))
	_ticks(walk)
	assert_eq(walk.player.food, 48, "a food on ticks 0 and 32")
	assert_eq([walk.player.quest_timer, walk.player.siege_timer], [2, 2])
	assert_eq(walk.player.monster_timer, 64, "the world's clock, a tick each")


func test_with_no_food_the_pace_is_slower() -> void:
	var walk := _walker(6, Vector2i(10, 10))
	walk.player.food = 0
	walk.walk_to(Vector2i(12, 10))
	assert_eq(_ticks(walk), 94, "plain land as slow as forest")
	assert_eq(walk.player.food, 0, "and no lower")


func test_the_way_goes_round_the_sea() -> void:
	var sea: Array[Vector2i] = []
	for y in range(0, 20):
		if y != 15:
			sea.append(Vector2i(12, y))
	var walk := _walker(6, Vector2i(10, 10), sea)
	assert_true(walk.walk_to(Vector2i(14, 10)))
	var way := walk.path.duplicate()
	assert_true(Vector2i(12, 15) in way, "through the gap: %s" % str(way))
	for i in way.size():
		assert_true(walk.player.world.is_land(way[i].x, way[i].y), "on land")
		if i > 0:
			assert_lte(maxi(absi(way[i].x - way[i - 1].x), absi(way[i].y - way[i - 1].y)), 1, "a step at a time")
	_ticks(walk, 5000)
	assert_eq(walk.player.tile(), Vector2i(14, 10), "and arrives")


func test_a_click_on_the_sea_walks_to_the_nearest_shore() -> void:
	var sea: Array[Vector2i] = []
	for y in ShandalarWorld.TILES:
		for x in range(20, ShandalarWorld.TILES):
			sea.append(Vector2i(x, y))
	var walk := _walker(6, Vector2i(10, 10), sea)
	assert_true(walk.walk_to(Vector2i(40, 10)))
	assert_eq(walk.path.back(), Vector2i(19, 10), "the shore nearest the click")


func test_the_hero_faces_the_way_and_steps_then_stands() -> void:
	var walk := _walker(6, Vector2i(10, 10))
	walk.walk_to(Vector2i(13, 10))
	for i in 10:
		walk.tick()
	assert_eq(walk.player.facing, 3, "east is way 3")
	assert_true(walk.player.step >= 1 and walk.player.step <= 4, "a walking step")
	_ticks(walk)
	assert_eq(walk.player.step, 0, "standing at the end")
	assert_eq(walk.player.facing, 3, "still facing the way walked")


## Quickening (1.3: `worldmagic_duration` 150): every step goes a unit
## further while it runs, and it runs down a tick at a time.
func test_quickening_is_a_unit_more_every_step_while_it_runs() -> void:
	var walk := _walker(6, Vector2i(10, 10))
	walk.player.quickening = WorldMagic.QUICKENING_TICKS
	walk.walk_to(Vector2i(12, 10))
	assert_eq(_ticks(walk), 32, "two tiles east: 64 units, two a tick")
	assert_eq(walk.player.quickening, WorldMagic.QUICKENING_TICKS - 32, "a tick less each tick")
	walk.player.quickening = 1
	walk.walk_to(Vector2i(10, 10))
	assert_eq(_ticks(walk), 63, "the last tick of it, then the plain pace")
	assert_eq(walk.player.quickening, 0)

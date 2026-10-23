extends GutTest
## A HERO CAUGHT ON THE SEA, AND THE WAY-FINDER'S GRID (the adventure
## campaign of 2026-10-23, h2-1 and h5-12).
##
## A diagonal step between two land tiles north-east or south-west passes
## the corner of a third tile for one tick: from (x, y) to (x + 1, y − 1)
## the hero stands for a tick on (32 (x + 1), 32 y), which is tile
## (x + 1, y). The way-finder often cuts across the coast's corners, so
## that tile is often the sea, and the shore rule (a step into the sea near
## a tile's middle is taken back) lets the step stand, the corner being 16
## units from the middle. A click on that tick planned the way from the
## sea tile; the hero walked toward its middle, the shore rule took the
## step back and ended the walk — every later click the same, and an
## autosave kept them there: stuck for good. Now the way starts on the land
## the hero stands by, the shore rule refuses only a step from land into
## the sea, and a hero loaded on the sea is set back on land.
##
## The way-finder's grid of the world (4,096 tiles) is kept between clicks
## and built again only when what shapes it changes.


## A seeded adventure: the world the hunt found the corners in.
func _adventure(seed_text := "145729") -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = seed_text
	var record := setup.resolve({})
	return AdventurePlayer.begin(record, AdventureSetup.make_world(record))


## A land tile of [param world] whose north-east neighbour is land and
## whose east neighbour is the sea, with no road on it: the step north-east
## crosses the sea tile's corner. (-1, -1) for none.
func _corner(world: ShandalarWorld) -> Vector2i:
	for y in range(2, ShandalarWorld.TILES - 2):
		for x in range(2, ShandalarWorld.TILES - 2):
			if world.is_land(x, y) and world.is_land(x + 1, y - 1) and not world.is_land(x + 1, y) \
					and world.road_bits(x, y) == 0 and world.tile_flags(x, y) & ShandalarWorld.SITE == 0 \
					and world.tile_flags(x + 1, y - 1) & ShandalarWorld.SITE == 0:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## The hero of [param player] set on [param from]'s middle and walked
## north-east until they stand on the sea tile's corner; the walk.
func _walk_onto_the_corner(player: AdventurePlayer, from: Vector2i) -> HeroWalk:
	player.position = from * 32 + Vector2i(16, 16)
	var walk := HeroWalk.new(player)
	walk.walk_to(from + Vector2i(1, -1))
	for i in 60:
		var here := player.tile()
		if not player.world.is_land(here.x, here.y):
			break
		walk.tick()
	return walk


## A land tile 6 to 12 steps from [param from] the walk can reach.
func _far_land(walk: HeroWalk, from: Vector2i) -> Vector2i:
	var world := walk.player.world
	for reach in range(6, 13):
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var tile := from + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) != reach or not world.is_land(tile.x, tile.y):
					continue
				var way := walk.plan(tile)
				if way.size() > 4 and way.back() == tile:
					return tile
	return from


## Walk [param walk] to [param target] and tick until the walk ends; true
## when the hero arrived there.
func _walks_there(walk: HeroWalk, target: Vector2i) -> bool:
	if not walk.walk_to(target):
		return false
	for i in 20000:
		if not walk.is_walking():
			break
		walk.tick()
	return walk.player.tile() == target


func test_a_click_on_a_sea_corner_walks_on() -> void:
	var player := _adventure()
	var from := _corner(player.world)
	assert_ne(from, Vector2i(-1, -1), "the world has a coast corner to cross")
	var walk := _walk_onto_the_corner(player, from)
	var here := player.tile()
	assert_false(player.world.is_land(here.x, here.y), "the hero stands on the sea tile's corner: %s" % str(player.position))
	var way := walk.plan(from)
	assert_true(player.world.is_land(way[0].x, way[0].y), "the way starts on land, not on the sea tile")
	var target := _far_land(walk, from)
	assert_ne(target, from, "somewhere to walk")
	assert_true(_walks_there(walk, target), "the hero walks on from the corner (stood at %s)" % str(player.position))
	assert_true(_walks_there(walk, from), "and back again")


func test_a_save_on_a_sea_corner_loads_on_land_and_walks() -> void:
	var player := _adventure()
	var from := _corner(player.world)
	_walk_onto_the_corner(player, from)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	var loaded := AdventurePlayer.from_dict(saved)
	assert_not_null(loaded)
	var at_load := loaded.tile()
	assert_false(loaded.world.is_land(at_load.x, at_load.y), "saved on the sea tile's corner")
	var walk := HeroWalk.new(loaded)
	var here := loaded.tile()
	assert_true(loaded.world.is_land(here.x, here.y), "taken up again, the hero stands on land")
	assert_eq(loaded.position, here * 32 + Vector2i(16, 16), "on the land tile's middle")
	assert_lte(maxi(absi(here.x - at_load.x), absi(here.y - at_load.y)), 1, "beside the corner")
	var target := _far_land(walk, here)
	assert_true(_walks_there(walk, target), "and walks")


## An autosave written before the fix: the hero stopped deep in a sea
## tile, where every click was taken back.
func test_a_hero_saved_stuck_in_the_sea_is_set_back_on_land() -> void:
	var player := _adventure()
	var from := _corner(player.world)
	var sea := from + Vector2i(1, 0)
	player.position = sea * 32 + Vector2i(4, 4)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	var loaded := AdventurePlayer.from_dict(saved)
	var walk := HeroWalk.new(loaded)
	var here := loaded.tile()
	assert_true(loaded.world.is_land(here.x, here.y), "set back on land")
	assert_eq(loaded.position, here * 32 + Vector2i(16, 16))
	assert_true(_walks_there(walk, _far_land(walk, here)), "and walks")


## Caught on the sea while the walker lives (no load between): a click
## still walks them out — the way starts on land and the steps from the
## sea back to land stand.
func test_a_hero_on_a_sea_tile_walks_out_when_clicked() -> void:
	var player := _adventure()
	var from := _corner(player.world)
	var walk := HeroWalk.new(player)
	var sea := from + Vector2i(1, 0)
	player.position = sea * 32 + Vector2i(4, 4)
	var target := _far_land(walk, from)
	assert_true(_walks_there(walk, target), "walked out of the sea and on")


## The 1997 rule still holds where it came from: a step from land into the
## sea near the tile's middle is taken back and the walk ends.
func test_a_step_from_land_into_the_sea_is_still_taken_back() -> void:
	var world := ShandalarWorld.new()
	world.page.resize(ShandalarWorld.PAGE_WIDTH * ShandalarWorld.PAGE_HEIGHT)
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			world.page[y * ShandalarWorld.PAGE_WIDTH + x] = 6
	world.page[10 * ShandalarWorld.PAGE_WIDTH + 11] = ShandalarWorld.OCEAN
	var player := AdventurePlayer.new()
	player.world = world
	player.food = 50
	player.position = Vector2i(10, 10) * 32 + Vector2i(16, 16)
	var walk := HeroWalk.new(player)
	var into_the_sea: Array[Vector2i] = [Vector2i(11, 10)]
	walk.path = into_the_sea
	for i in 40:
		if not walk.is_walking():
			break
		walk.tick()
	assert_false(walk.is_walking(), "the walk ended at the shore")
	assert_eq(player.tile(), Vector2i(10, 10), "still on land")


## h5-12: a click built a new grid of the whole world each time (2.8 ms on
## the desk, about 10 on a handheld). It is kept, and built again only for
## a new world or when Amulet of Swampwalk or Dwarven Pick change what is
## slow.
func test_the_way_finder_keeps_its_grid_between_clicks() -> void:
	var world := ShandalarWorld.new()
	world.page.resize(ShandalarWorld.PAGE_WIDTH * ShandalarWorld.PAGE_HEIGHT)
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			world.page[y * ShandalarWorld.PAGE_WIDTH + x] = 3 if x == 12 else 6
	world.page[20 * ShandalarWorld.PAGE_WIDTH + 12] = 5
	var player := AdventurePlayer.new()
	player.world = world
	player.food = 50
	player.position = Vector2i(10, 10) * 32 + Vector2i(16, 16)
	var walk := HeroWalk.new(player)
	assert_true(walk.walk_to(Vector2i(14, 10)))
	var grid: AStarGrid2D = walk._grid
	assert_not_null(grid, "built for the first click")
	assert_eq(grid.get_point_weight_scale(Vector2i(12, 10)), HeroWalk.SLOW_COST, "swamp is slow")
	walk.walk_to(Vector2i(14, 12))
	walk.plan(Vector2i(3, 3))
	assert_same(walk._grid, grid, "the next clicks use the same grid")
	player.world_magics.append("Amulet of Swampwalk")
	walk.plan(Vector2i(14, 10))
	assert_not_same(walk._grid, grid, "the amulet changes the grid")
	assert_eq(walk._grid.get_point_weight_scale(Vector2i(12, 10)), 1.0, "swamp is no longer slow")
	assert_eq(walk._grid.get_point_weight_scale(Vector2i(12, 20)), HeroWalk.SLOW_COST, "mountains still are")
	grid = walk._grid
	player.world_magics.append("Dwarven Pick")
	walk.plan(Vector2i(14, 10))
	assert_eq(walk._grid.get_point_weight_scale(Vector2i(12, 20)), 1.0, "nor mountains with the pick")
	grid = walk._grid
	var other := ShandalarWorld.new()
	other.page = world.page.duplicate()
	other.page[10 * ShandalarWorld.PAGE_WIDTH + 13] = ShandalarWorld.OCEAN
	player.world = other
	walk.plan(Vector2i(14, 10))
	assert_not_same(walk._grid, grid, "a new world, a new grid")
	assert_true(walk._grid.is_point_solid(Vector2i(13, 10)), "of the new world's land")

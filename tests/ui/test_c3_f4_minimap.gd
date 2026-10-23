extends GutTest
## THE SMALL MAP'S FRAMES (the adventure campaign of 2026-10-23, h5-3).
## The whole small map was drawn again every frame for its pulse — 1.3 to
## 2.5 ms a frame with the hero standing still, under a town's pane too.
## [WorldMinimap] now draws its land, roads and towns once and moves that
## picture under the hero, drawing it again only on another tile, new land
## seen or another world; only the pulsing marks and the hero's dot are
## drawn each frame.

var minimap: WorldMinimap
var world: ShandalarWorld


func before_each() -> void:
	world = WorldGenerator.generate(777, 5, 2, 0)
	world.explore_around(Vector2i(32, 32))
	minimap = WorldMinimap.new()
	add_child_autofree(minimap)
	minimap.world = world
	minimap.hero = Vector2(32 * 32 + 16, 32 * 32 + 16)
	await wait_process_frames(3)


## How many times [param node] is drawn from now on: a one-cell counter.
func _draws(node: CanvasItem) -> Array[int]:
	var count: Array[int] = [0]
	node.draw.connect(func() -> void: count[0] += 1)
	return count


func test_standing_still_only_the_pulse_is_drawn() -> void:
	var ground := minimap.find_child("Ground", true, false) as CanvasItem
	var marks := minimap.find_child("Marks", true, false) as CanvasItem
	assert_not_null(ground, "the land is a picture of its own")
	assert_not_null(marks, "the marks and the dot another")
	var land := _draws(ground)
	var pulse := _draws(marks)
	for i in 10:
		# The world screen gives the hero again every tick, moved or not.
		minimap.hero = minimap.hero
		await get_tree().process_frame
	assert_eq(land[0], 0, "the land is not drawn again")
	assert_gte(pulse[0], 8, "the pulse is, every frame")


func test_walking_moves_the_land_and_draws_it_again_on_another_tile() -> void:
	var ground := minimap.find_child("Ground", true, false) as Node2D
	var land := _draws(ground)
	var start := minimap.hero
	minimap.hero = start + Vector2(5, 0)
	await wait_process_frames(2)
	assert_eq(land[0], 0, "within the tile the picture is only moved")
	assert_almost_eq(ground.position, Vector2(-1.875, 0.9375), Vector2(0.001, 0.001),
		"five units east: the land slides west and down, as the projection goes")
	minimap.hero = start + Vector2(32, 0)
	await wait_process_frames(2)
	assert_eq(land[0], 1, "another tile: drawn again, round it")
	assert_almost_eq(ground.position, Vector2.ZERO, Vector2(0.001, 0.001), "in the tile's middle")
	world.explore_around(Vector2i(40, 26))
	minimap.hero = minimap.hero
	await wait_process_frames(2)
	assert_eq(land[0], 2, "new land seen: drawn again")
	minimap.world = WorldGenerator.generate(778, 5, 2, 0)
	await wait_process_frames(2)
	assert_eq(land[0], 3, "another world: drawn again")


## A world point lands where [method WorldMinimap.project] (which the
## clicks go by) says, whatever part of a tile the hero stands on.
func test_the_moved_land_stands_where_the_clicks_read_it() -> void:
	var ground := minimap.find_child("Ground", true, false) as Node2D
	for step in [Vector2(3, -7), Vector2(-11, 9), Vector2(15, 15)]:
		minimap.hero = Vector2(32 * 32 + 16, 32 * 32 + 16) + step
		for point in [Vector2(30 * 32, 33 * 32), Vector2(35 * 32 + 16, 28 * 32 + 5)]:
			assert_almost_eq(minimap._on_ground(point) + ground.position, minimap.project(point),
				Vector2(0.001, 0.001), "%s with the hero %s off the middle" % [str(point), str(step)])
		assert_eq(minimap.tile_at(minimap.project(Vector2(31 * 32 + 16, 34 * 32 + 16))), Vector2i(31, 34))


## The bug pass after the campaign (r4-1): with the hero anywhere in a tile
## — its middle, where the picture is drawn round, or its corners, where the
## picture has slid furthest — every tile whose diamond shows on the small
## map is drawn: its left point lies in [method WorldMinimap.ground_box].
## The box was a slide short on the left, and a black sawtooth ran down the
## map's left edge while walking west or north.
func test_every_tile_on_the_map_is_drawn_wherever_the_hero_stands() -> void:
	var tile := Vector2i(32, 32)
	var map := Rect2(Vector2.ZERO, minimap.size)
	var t := WorldMinimap.TILE
	for offset in [Vector2(16, 16), Vector2(0, 0), Vector2(31, 0), Vector2(0, 31), Vector2(31, 31), Vector2(0, 16)]:
		minimap.hero = Vector2(tile * 32) + offset
		await get_tree().process_frame
		var ground := minimap.find_child("Ground", true, false) as Node2D
		var missing := 0
		for y in range(tile.y - 12, tile.y + 13):
			for x in range(tile.x - 12, tile.x + 13):
				var left := minimap._on_ground(Vector2(x * 32, y * 32))
				var diamond := Rect2(left + ground.position + Vector2(0, -t), Vector2(t * 4.0, t * 2.0))
				if diamond.intersects(map) and not minimap.ground_box().has_point(left):
					missing += 1
		assert_eq(missing, 0, "no tile on the map left out with the hero %s into the tile" % offset)

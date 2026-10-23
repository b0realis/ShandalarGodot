extends GutTest
## THE WORLD VIEW'S FRAMES (the adventure campaign of 2026-10-23, h5-1 and
## h5-11). The whole visible world was drawn again on every 60 ms tick even
## standing still, every frame while looking or zooming, and each time all
## 7,744 tiles were projected to keep the hundred to thirteen hundred on
## the screen: 4 to 27 ms a time. [WorldView] now keeps the ground and the
## uprights as pictures drawn round one point, moves and scales them, and
## draws them again only when the screen leaves their margin or what they
## show changes; the tiles drawn are worked out from the screen's corners.
## And the hero, who moved only on the tick, slides between ticks
## ([method WorldView.frame]) while the game reads the tick's places.

var view: WorldView
var world: ShandalarWorld
var start := Vector2.ZERO


## A skin without the world's sheets: the world drawn plain.
class NoSheets extends WorldArt:
	func texture(_key: String) -> Texture2D:
		return null


func before_each() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.seed_text = "145729"
	var record := setup.resolve({})
	world = AdventureSetup.make_world(record)
	var player := AdventurePlayer.begin(record, world)
	start = Vector2(player.position)
	view = WorldView.new()
	add_child_autofree(view)
	view.size = Vector2(1280, 800)
	view.world = world
	view.hero = start
	view.camera = start
	await wait_process_frames(3)


## The view's four pictures by name: Ground, Shadow, Uprights, Figure.
func _pictures() -> Dictionary:
	var found := {}
	for child in view.get_children(true):
		if child is Node2D:
			found[String(child.name)] = child
	return found


## How many times each picture is drawn from now on.
func _counting() -> Dictionary:
	var counts := {}
	var pictures := _pictures()
	for called in pictures:
		var count: Array[int] = [0]
		counts[called] = count
		(pictures[called] as CanvasItem).draw.connect(func() -> void: count[0] += 1)
	return counts


func _drawn(counts: Dictionary, called: String) -> int:
	return (counts[called] as Array[int])[0]


## What the world screen does every tick: everything given again, moved or
## not, and a redraw asked for.
func _tick() -> void:
	view.hero = view.hero
	view.hero_facing = view.hero_facing
	view.hero_step = view.hero_step
	var lairs: Array[Dictionary] = []
	view.lairs = lairs
	view.queue_redraw()


func test_the_view_is_four_pictures() -> void:
	assert_eq(_pictures().keys(), ["Ground", "Shadow", "Uprights", "Figure"],
		"the ground, the hero's shadow, the uprights, the hero — in that order")
	assert_eq(view.get_child_count(), 0, "kept inside the view: the screen's own children are its own")


func test_standing_still_nothing_is_drawn_again() -> void:
	var counts := _counting()
	for i in 12:
		_tick()
		await get_tree().process_frame
	for called in counts:
		assert_eq(_drawn(counts, called), 0, "%s not drawn again" % called)


func test_walking_draws_only_the_hero() -> void:
	var counts := _counting()
	var pictures := _pictures()
	for i in 20:
		view.camera = view.hero + Vector2(1, 0)
		view.hero = view.hero + Vector2(1, 0)
		_tick()
		await get_tree().process_frame
	assert_eq(_drawn(counts, "Ground"), 0, "the ground is only moved")
	assert_eq(_drawn(counts, "Uprights"), 0, "nor the uprights")
	assert_gte(_drawn(counts, "Figure"), 19, "the hero is drawn where they walk")
	assert_gte(_drawn(counts, "Shadow"), 19, "with their shadow")
	var ground := pictures["Ground"] as Node2D
	assert_almost_eq(ground.position, view.feet() + view._lay(Vector2(view._anchor) - view.camera) * view.zoom,
		Vector2(0.001, 0.001), "moved with the camera")
	assert_eq(view.drawn_at(view.hero), view.feet(), "the hero at the screen's feet")


func test_the_camera_past_the_margin_draws_again_round_it() -> void:
	var counts := _counting()
	view.camera = start + Vector2(200, 0)
	await wait_process_frames(2)
	assert_eq(_drawn(counts, "Ground"), 1, "the ground drawn again")
	assert_eq(_drawn(counts, "Uprights"), 1, "and the uprights")
	assert_eq(view._anchor, Vector2i(start + Vector2(200, 0)), "round the camera")


func test_new_land_seen_draws_the_ground_again() -> void:
	var counts := _counting()
	var seen := hash(world.page)
	world.explore_around(Vector2i(view.hero / 32.0) + Vector2i(2, 2))
	assert_ne(hash(world.page), seen, "new land seen")
	_tick()
	await wait_process_frames(2)
	assert_eq(_drawn(counts, "Ground"), 1, "the dark lifted")
	_tick()
	await wait_process_frames(2)
	assert_eq(_drawn(counts, "Ground"), 1, "once")


func test_zooming_in_only_scales_and_zooming_out_draws() -> void:
	var counts := _counting()
	var ground := _pictures()["Ground"] as Node2D
	view.zoom = 2.5
	await wait_process_frames(2)
	assert_eq(_drawn(counts, "Ground"), 0, "closer: the picture is only scaled")
	assert_eq(ground.scale, Vector2(2.5, 2.5))
	view.zoom = 1.0
	await wait_process_frames(2)
	assert_eq(_drawn(counts, "Ground"), 1, "further: drawn again for the wider screen")


## The tiles drawn: a window of the original's whole order, and every tile
## the old drawing found by trying all 7,744 of them is in it.
func test_the_tiles_drawn_are_the_screen_s_in_the_original_order() -> void:
	var place := {}
	var order := WorldView.draw_order()
	for i in order.size():
		place[order[i]] = i
	var corner := Vector2(-200, 100)
	for look in [[2.0, start], [0.5, start], [3.0, start], [0.5, corner], [1.0, Vector2(2100, 2050)]]:
		view.zoom = look[0]
		view.camera = look[1]
		await wait_process_frames(2)
		var tiles := view._tiles
		var last := -1
		var in_order := true
		for tile in tiles:
			in_order = in_order and int(place[tile]) > last
			last = int(place[tile])
		assert_true(in_order, "in the original's order at zoom %s" % look[0])
		# The old drawing's test, tile by tile.
		var screen := Rect2(-view.feet() / view.zoom, view.size / view.zoom)
		var drawn := {}
		for tile in tiles:
			drawn[tile] = true
		var missing := 0
		var wanted := 0
		for tile in order:
			var left := view.project(Vector2(tile.x * 32, tile.y * 32))
			if Rect2(left.x - 96, left.y - 32 - 200, 128 + 192, 64 + 240).intersects(screen):
				wanted += 1
				if not drawn.has(tile):
					missing += 1
		assert_eq(missing, 0, "every tile on the screen at zoom %s (%d of them)" % [look[0], wanted])
		assert_lt(tiles.size(), wanted * 2 + 200, "and not the whole map: %d drawn" % tiles.size())


func test_frame_slides_the_hero_and_the_camera_between_ticks() -> void:
	var counts := _counting()
	var step := start + Vector2(3, 0)
	view.hero = step
	view.camera = step
	view.frame(0.0)
	await get_tree().process_frame
	assert_eq(view._shown_hero(), start, "just after the tick: where the last one left them")
	assert_eq(view.drawn_at(start), view.feet(), "the camera with them")
	view.frame(0.5)
	assert_eq(view._shown_hero(), start + Vector2(1.5, 0), "half way")
	assert_eq(view.drawn_at(start + Vector2(1.5, 0)), view.feet())
	view.frame(1.0)
	assert_eq(view._shown_hero(), step, "and there by the next")
	assert_eq(view.hero, step, "the game reads the tick's place")
	assert_eq(view.camera, step)
	assert_eq(view.project(step), Vector2.ZERO, "and projects by it")
	assert_almost_eq(view.unproject(view.feet()), step, Vector2(0.001, 0.001))
	await get_tree().process_frame
	var figure := _drawn(counts, "Figure")
	view.frame(1.0)
	await get_tree().process_frame
	assert_eq(_drawn(counts, "Figure"), figure, "nothing moved: nothing drawn")
	assert_eq(_drawn(counts, "Ground"), 0, "the ground only moved, all along")
	view.hero = step
	view.frame(0.0)
	assert_eq(view._shown_hero(), step, "standing at the next tick: they stand")


func test_a_leap_is_not_slid_and_a_camera_looking_elsewhere_stays() -> void:
	view.hero = start + Vector2(400, 0)
	view.frame(0.0)
	assert_eq(view._shown_hero(), start + Vector2(400, 0), "a leap is shown at once")
	var looking := start + Vector2(-50, 80)
	view.camera = looking
	view.hero = view.hero + Vector2(2, 2)
	view.frame(0.25)
	assert_eq(view._shown_hero(), start + Vector2(400.5, 0.5), "the hero slides")
	assert_eq(view.drawn_at(looking), view.feet(), "the camera stays where it looks")


func test_frame_is_safe_at_any_time() -> void:
	var loose := WorldView.new()
	loose.frame(0.3)
	loose.frame(1.0)
	loose.world = world
	loose.frame(0.0)
	loose.free()
	view.frame(-1.0)
	view.frame(7.0)
	view.world = null
	view.frame(0.5)
	await wait_process_frames(2)
	assert_true(view._tiles.is_empty(), "no world, nothing kept")
	view.world = world
	view.frame(0.5)
	await wait_process_frames(2)
	assert_false(view._tiles.is_empty(), "the world back")


## Without the 1997 sheets the world is drawn plain, kept the same way.
func test_the_plain_world_is_kept_the_same_way() -> void:
	var plain := WorldView.new()
	plain.art = NoSheets.new()
	add_child_autofree(plain)
	plain.size = Vector2(1280, 800)
	plain.world = world
	plain.hero = start
	plain.camera = start
	await wait_process_frames(3)
	assert_true(plain._plain, "drawn plain")
	assert_false(plain._tiles.is_empty())
	view = plain
	var counts := _counting()
	for i in 6:
		view.camera = view.hero + Vector2(1, 0)
		view.hero = view.hero + Vector2(1, 0)
		_tick()
		await get_tree().process_frame
	assert_eq(_drawn(counts, "Ground"), 0, "the plain ground is only moved")
	assert_gte(_drawn(counts, "Figure"), 5, "the hero's mark is drawn where they walk")

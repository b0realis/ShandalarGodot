extends GutTest
## THE WORLD SCREEN (2026-10-22): a new adventure's world, drawn full screen
## as 1.3 drew it ([WorldView]) — the projection, the draw order, the
## sheets' lookups, what the hero sees, looking around, zooming, the map,
## leaving, and the Embark screen's hand-over. Without the 1997 sheets
## (CI) the same world is drawn plain.

var screen: WorldScreen


func _record(seed_text := "12345") -> Dictionary:
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = seed_text
	return setup.resolve({})


func before_each() -> void:
	screen = load("res://game/adventure/world/world_screen.tscn").instantiate()
	screen.record = _record()
	add_child_autofree(screen)
	await get_tree().process_frame


func test_the_record_s_world_is_shown_from_the_hero_s_place() -> void:
	assert_not_null(screen.world, "made from the record")
	var made := WorldGenerator.generate(12345, 12345 % 128, 4, 1)
	made.explore_around(made.start_tile())
	assert_eq(screen.world.fingerprint(), made.fingerprint(), "the record's world, the start explored")
	assert_eq(screen.view.world, screen.world)
	assert_eq(screen.view.hero, Vector2(screen.world.start))
	assert_eq(screen.view.camera, Vector2(screen.world.start), "the camera on the hero")
	assert_eq(screen.view.hero_walker, "male")


func test_the_projection_is_the_original_s() -> void:
	var view := screen.view
	view.camera = Vector2(100, 100)
	assert_eq(view.project(Vector2(100, 100)), Vector2.ZERO, "the camera at the feet")
	assert_eq(view.project(Vector2(132, 100)), Vector2(64, -32), "a tile east: 64 across, 32 up")
	assert_eq(view.project(Vector2(100, 132)), Vector2(64, 32), "a tile south: 64 across, 32 down")
	for zoom in [0.5, 1.0, 2.0]:
		view.zoom = zoom
		for point in [Vector2(37, 211), Vector2(1500, 900)]:
			var screen_at: Vector2 = view.feet() + view.project(point) * zoom
			assert_almost_eq(view.unproject(screen_at), point, Vector2(0.01, 0.01), "back again at %s" % zoom)


func test_the_tiles_are_drawn_in_the_original_s_order() -> void:
	var order := WorldView.draw_order()
	var size := ShandalarWorld.TILES + WorldView.MARGIN * 2
	assert_eq(order.size(), size * size, "the map and its margin of ocean")
	for i in range(1, order.size()):
		var a := order[i - 1]
		var b := order[i]
		var ra := a.y - a.x
		var rb := b.y - b.x
		assert_true(ra < rb or (ra == rb and a.x + a.y < b.x + b.y), "row by row, then across")
		if not (ra < rb or (ra == rb and a.x + a.y < b.x + b.y)):
			return


func test_the_sheets_lookups() -> void:
	# The six location sheets read as one, each counting its end marker.
	assert_eq(WorldView._location(1), ["world_locatn01", 1])
	assert_eq(WorldView._location(36), ["world_locatn02", 11])
	assert_eq(WorldView._location(38), ["world_locatn03", 0])
	assert_eq(WorldView._location(63), ["world_locatn04", 0])
	assert_eq(WorldView._location(84), ["world_locatn05", 8])
	assert_eq(WorldView._location(101), ["world_locatn06", 0])
	assert_eq(WorldView._castle_ref(11), ["world_castles1", 11])
	assert_eq(WorldView._castle_ref(12), ["world_castles2", 0])
	assert_eq([WorldView._color_index(3), WorldView._color_index(1), WorldView._color_index(2),
		WorldView._color_index(5), WorldView._color_index(6)], [0, 1, 2, 3, 4], "black blue green red white")
	var art := WorldArt.new()
	assert_eq(art.frame_rect("world_cstline1", 8), Rect2(64, 32, 64, 32), "seven to a row")
	assert_eq(art.frame_size("world_ego_m"), Vector2(154, 108))


func test_the_hero_sees_around_them() -> void:
	var world := WorldGenerator.generate(777, 5, 2, 0)
	var at := Vector2i(32, 32)
	world.explore_around(at)
	var seen := 0
	for y in 64:
		for x in 64:
			if world.is_explored(x, y):
				seen += 1
	assert_eq(seen, 15 * 7, "seven screen rows each way, three columns each way")
	assert_true(world.is_explored(32, 32))
	assert_true(world.is_explored(32 + 3, 32 + 3), "three columns to the right on the hero's row")
	assert_false(world.is_explored(32 + 4, 32 + 4), "not four")
	assert_true(screen.world.is_explored(screen.world.start_tile().x, screen.world.start_tile().y),
		"the screen marks the hero's surroundings when it opens")


func test_looking_zooming_and_coming_back() -> void:
	screen.set_zoom(1.0)
	var start := screen.view.camera
	screen.look(Vector2(400, 0))
	assert_almost_eq(screen.view.camera, start + Vector2(100, 100), Vector2(0.01, 0.01),
		"400 pixels right is 100 world units on each axis")
	screen.set_zoom(2.0)
	screen.look(Vector2(0, 200))
	assert_almost_eq(screen.view.camera, start + Vector2(50, 150), Vector2(0.01, 0.01),
		"at 2x the same pixels look half as far")
	screen.set_zoom(10.0)
	assert_eq(screen.view.zoom, WorldView.ZOOM_MAX)
	screen.set_zoom(0.01)
	assert_eq(screen.view.zoom, WorldView.ZOOM_MIN)
	screen.look(Vector2(-100000, -100000))
	assert_gte(screen.view.camera.x, -256.0, "no further than a little ocean past the map")
	screen.back_to_hero()
	assert_eq(screen.view.camera, screen.view.hero)


## The owner's choice, 2026-10-22: the whole screen shows only what the
## hero has seen, as the 1997 window did, at twice the 1997 pixels.
func test_unseen_land_stays_dark_and_the_view_starts_at_twice() -> void:
	assert_true(screen.view.fog, "unseen land is dark")
	assert_eq(screen.view.zoom, WorldView.DEFAULT_ZOOM)
	assert_eq(WorldView.DEFAULT_ZOOM, 2.0)
	var map := screen.find_child("Map", true, false) as WorldMap
	var start := screen.world.start_tile()
	assert_true(map.shows(start.x, start.y), "the map shows where the hero stands")
	var shown := 0
	var explored := 0
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			if map.shows(x, y):
				shown += 1
			if screen.world.is_explored(x, y):
				explored += 1
	assert_eq(shown, explored, "and only what the hero has seen")
	assert_lt(shown, ShandalarWorld.TILES * ShandalarWorld.TILES / 4, "a small part of the world")


func test_the_map_and_leaving() -> void:
	var map := screen.find_child("Map", true, false) as Control
	assert_false(map.visible)
	screen.toggle_map()
	assert_true(map.visible)
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	screen._unhandled_input(escape)
	assert_false(map.visible, "Escape closes the map first")
	screen._unhandled_input(escape)
	assert_true(screen._leaving, "then leaves")
	assert_true(screen.is_inside_tree(), "but not the test runner's tree")


func test_the_embark_screen_opens_the_world() -> void:
	AdventureSetup.forget()
	var embark: EmbarkScreen = load("res://game/adventure/embark_screen.tscn").instantiate()
	add_child_autofree(embark)
	await get_tree().process_frame
	var record := _record("4242")
	var opened := embark.open_world(record)
	assert_eq(opened.record, record)
	assert_eq(opened.world.seed, 4242)
	assert_string_contains(opened.arrival, "Goya sets out as a red mage")
	opened.free()
	AdventureSetup.forget()


func test_the_world_is_made_aside_while_the_veil_is_up() -> void:
	var embark: EmbarkScreen = load("res://game/adventure/embark_screen.tscn").instantiate()
	add_child_autofree(embark)
	await get_tree().process_frame
	var record := _record("4242")
	var made: ShandalarWorld = await embark._make_world_aside(record)
	assert_eq(made.fingerprint(), AdventureSetup.make_world(record).fingerprint(),
		"the same world as made in place")
	var opened := embark.open_world(record, made)
	assert_eq(opened.world, made, "the world made aside is the one opened")
	opened.free()


func test_a_screen_leaving_waits_for_its_world() -> void:
	var embark: EmbarkScreen = load("res://game/adventure/embark_screen.tscn").instantiate()
	add_child(embark)
	await get_tree().process_frame
	embark._make_world_aside(_record("4242"))
	assert_not_null(embark._worker, "the world is being made")
	remove_child(embark)
	assert_null(embark._worker, "the thread was waited for as the screen left")
	await get_tree().process_frame
	embark.free()

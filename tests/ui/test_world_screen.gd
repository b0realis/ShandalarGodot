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


## A land tile two to four steps from [param from] the hero can walk to.
func _land_near(from: Vector2i) -> Vector2i:
	for reach in range(2, 5):
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var tile := from + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) != reach or not screen.world.is_land(tile.x, tile.y):
					continue
				var way := screen.walk.plan(tile)
				if not way.is_empty() and way.back() == tile:
					return tile
	return from


func _mouse(point: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = point
	return event


## The owner, 2026-10-22: "we will guide that figure with pathfinding by
## clicking on a map".
func test_a_click_walks_the_hero_there() -> void:
	var target := _land_near(screen.player.tile())
	assert_ne(target, screen.player.tile(), "somewhere to walk")
	var point := screen.view.feet() + screen.view.project(Vector2(target * 32 + Vector2i(16, 16))) * screen.view.zoom
	assert_eq(screen.tile_at(point), target, "the click lands on the tile")
	screen._gui_input(_mouse(point, true))
	screen._gui_input(_mouse(point, false))
	assert_true(screen.walk.is_walking(), "a click is where to go")
	for i in 400:
		if not screen.walk.is_walking():
			break
		screen.advance(0.25)
	assert_eq(screen.player.tile(), target, "and the hero walks there")
	assert_eq(screen.view.hero, Vector2(screen.player.position), "drawn where they stand")
	assert_eq(screen.view.camera, Vector2(screen.player.position), "the view went with them")
	assert_true(screen.world.is_explored(target.x, target.y), "seeing the land they pass")
	assert_gt(screen.player.monster_timer, 0, "the world's clock ran")


func test_a_drag_looks_and_does_not_walk() -> void:
	var camera := screen.view.camera
	var from := screen.size * 0.5
	screen._gui_input(_mouse(from, true))
	var motion := InputEventMouseMotion.new()
	motion.position = from + Vector2(80, 0)
	motion.relative = Vector2(80, 0)
	screen._gui_input(motion)
	screen._gui_input(_mouse(from + Vector2(80, 0), false))
	assert_false(screen.walk.is_walking(), "a drag is no click")
	assert_ne(screen.view.camera, camera, "it looks around")


## The owner, 2026-10-22: "for walking normally a cursor of the mouse
## displays a small walking man. For entering town it changes to an open
## door when hovering over a town".
func test_the_pointer_is_a_walker_and_a_door_over_a_site_seen() -> void:
	var start := screen.player.tile()
	assert_eq(screen.pointer_for(start), WorldCursors.Kind.WALK, "walking on")
	var site: Dictionary = screen.world.sites[0]
	var at := Vector2i(int(site["x"]), int(site["y"]))
	if not screen.world.is_explored(at.x, at.y):
		assert_eq(screen.pointer_for(at), WorldCursors.Kind.WALK, "a site unseen gives nothing away")
		screen.world.explore_around(at)
	assert_eq(screen.pointer_for(at), WorldCursors.Kind.DOOR, "a door on a site seen")
	for kind in [WorldCursors.Kind.WALK, WorldCursors.Kind.DOOR]:
		var picture := WorldCursors.image(kind)
		assert_eq(picture.get_size(), Vector2i(WorldCursors.SIZE, WorldCursors.SIZE))
		assert_gt(picture.get_pixelv(Vector2i(WorldCursors.hotspot(kind))).a + picture.get_pixel(16, 16).a, 0.0,
			"something is drawn")


## The owner, 2026-10-22: floating icons "based on old 1997 frame icons" —
## the purse, the five amulets, the World Magics lit when owned, and round
## buttons for the deck, the map, the hero and saving; then "put all in one
## row", the name and difficulty under it, the line of keys into a help.
func test_the_floating_icons_show_what_the_hero_carries() -> void:
	var hud := screen.hud
	var row := hud.find_child("Row", true, false) as HBoxContainer
	for part in ["Strip_gold", "Strip_book", "Amulet_black", "Amulet_white", "WorldMagics", "Buttons"]:
		assert_true(row.is_ancestor_of(hud.find_child(part, true, false)), part + " in the one row")
	assert_false(row.is_ancestor_of(hud.find_child("HeroLine", true, false)), "the name is not")
	# Then "a floating rectangle panel with round corners … but the panel
	# occupies whole horizontal space", room between its 3 groups of icons.
	screen.size = Vector2(1280, 800)
	await get_tree().process_frame
	await get_tree().process_frame
	var bar := (hud.find_child("Bar", true, false) as Control).get_global_rect()
	var line := (hud.find_child("HeroLine", true, false) as Control).get_global_rect()
	var at := hud.get_global_rect().position
	assert_eq(bar.position - at, Vector2(12, 8), "floating near the top left corner")
	assert_eq(bar.size.x, 1256.0, "as wide as the screen, a margin each side")
	var face := (hud.find_child("Bar", true, false) as Control).get_theme_stylebox("panel") as StyleBoxFlat
	assert_gt(face.corner_radius_top_left, 0, "round corners")
	assert_gte(line.position.y, bar.end.y, "the name under the row")
	assert_lt(line.position.x - at.x, 40.0, "at its left")
	var edge := func(part: String) -> Rect2:
		return (hud.find_child(part, true, false) as Control).get_global_rect()
	var carried_to_magics: float = edge.call("WorldMagics").position.x - edge.call("Amulet_white").end.x
	var magics_to_buttons: float = edge.call("Buttons").position.x - edge.call("WorldMagics").end.x
	assert_gt(carried_to_magics, 30.0, "room between what is carried and the World Magics")
	assert_almost_eq(magics_to_buttons, carried_to_magics, 1.5, "the same room before the buttons")
	assert_almost_eq(bar.end.x - edge.call("Buttons").end.x, 10.0, 1.0, "the buttons at its right end")
	assert_null(screen.find_child("Hint", true, false), "no line of keys under the world")
	assert_eq((hud.find_child("HeroLine", true, false) as Label).text, "Goya · Magician")
	assert_eq((hud.find_child("HeroLine", true, false) as Label).get_theme_color("font_color"),
		WorldHud.NAME_INKS["red"][0], "in the hero's colour of magic")
	var number := func(slot: String) -> String:
		return ((hud.find_child(slot, true, false) as Node).find_child("Number", true, false) as Label).text
	assert_eq(number.call("Strip_gold"), str(screen.player.gold))
	assert_eq(number.call("Strip_food"), str(screen.player.food))
	assert_eq(number.call("Strip_ankh"), "0", "no mana linked yet")
	assert_eq(number.call("Strip_book"), "0/0", "no cards yet")
	for color in ["black", "blue", "green", "red", "white"]:
		assert_eq(number.call("Amulet_" + color), str(int(screen.player.amulets[color])), color)
	# Red: Staff of Thunder (bit 8) is the hero's, lit while a red amulet is left.
	assert_true(hud.magic_lit(8), "the hero's own World Magic, lit")
	assert_false(hud.magic_lit(4), "Leap of Fate is not theirs")
	screen.player.amulets["red"] = 0
	assert_false(hud.magic_lit(8), "no red amulet: pressed, as in 1997")
	screen.player.food -= 7
	screen.advance(HeroWalk.TICK)
	assert_eq(number.call("Strip_food"), str(screen.player.food), "the numbers follow the hero")


func test_the_round_buttons() -> void:
	var hud := screen.hud
	for name in ["Deck", "Map", "Hero", "Options", "Help"]:
		assert_not_null(hud.buttons.get(name), name)
	assert_null(hud.buttons.get("Save"), "saving is among the options now")
	(hud.buttons["Map"] as BaseButton).pressed.emit()
	assert_true((screen.find_child("Map", true, false) as Control).visible, "the map's scroll opens the map")
	screen.toggle_map()
	(hud.buttons["Hero"] as BaseButton).pressed.emit()
	assert_true(hud.hero_shown(), "the hero's faces open the journal and stats")
	var said := "\n".join(hud.hero_lines())
	assert_string_contains(said, "Goya, a red mage")
	assert_string_contains(said, "%d gold" % screen.player.gold)
	assert_string_contains(said, "World seed")
	(hud.buttons["Help"] as BaseButton).pressed.emit()
	assert_true(hud.help_shown(), "? shows the keys")
	assert_false(hud.hero_shown(), "one panel at a time")
	var keys := "\n".join(hud.key_lines())
	for said_key in ["Click: walk there", "Space: back to your hero", "Ctrl+S: save the adventure",
			"H: these keys"]:
		assert_string_contains(keys, said_key)
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	screen._unhandled_input(escape)
	assert_false(hud.help_shown(), "Escape closes it first")
	assert_false(screen._leaving, "and stays in the world")
	(hud.buttons["Deck"] as BaseButton).pressed.emit()
	assert_string_contains(hud.notice(), "starting deck", "the deck says why it is empty")
	AdventurePlayer.saves_folder = "user://adventure_tests_hud"
	var path := screen.save_now()
	assert_true(FileAccess.file_exists(path), "Save writes the adventure")
	assert_true(path.ends_with(".save.json"), "beside its autosave")
	assert_eq(hud.notice(), "Saved.")
	DirAccess.remove_absolute(path)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


## The owner: "an options icon besides help. When you click it you get a
## dropdown menu — exit game, save, load, and an option to drop this panel
## to bottom of the screen"; the painted book that was Save opens it.
func test_the_options() -> void:
	var hud := screen.hud
	var option := func(entry: String) -> Button:
		return hud.find_child("Option_" + entry, true, false) as Button
	(hud.buttons["Options"] as BaseButton).pressed.emit()
	assert_true(hud.options_shown(), "the book opens the options")
	assert_eq([option.call("Save").text, option.call("Load").text, option.call("Bar").text, option.call("Exit").text],
		["Save", "Load", "Panel at the bottom", "Exit game"])
	# Save.
	AdventurePlayer.saves_folder = "user://adventure_tests_options"
	(option.call("Save") as Button).pressed.emit()
	assert_false(hud.options_shown(), "a choice closes the options")
	var path := screen.player.save_path("save")
	assert_true(FileAccess.file_exists(path), "Save writes the adventure")
	DirAccess.remove_absolute(path)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
	# Load: the saves over the world; Back comes back to it.
	(hud.buttons["Options"] as BaseButton).pressed.emit()
	(option.call("Load") as Button).pressed.emit()
	assert_true(screen.loading(), "the saved adventures, over the world")
	var walked := screen.player.monster_timer
	screen._process(1.0)
	assert_eq(screen.player.monster_timer, walked, "the world waits under them")
	var listing := screen.find_child("Saves", true, false)
	assert_not_null(listing)
	(screen.find_child("Back", true, false) as BaseButton).pressed.emit()
	await get_tree().process_frame
	assert_false(screen.loading(), "Back: the world again")
	assert_false(screen._leaving, "still in it")
	# A click on the land closes the options instead of walking there.
	(hud.buttons["Options"] as BaseButton).pressed.emit()
	assert_true(hud.close_options(), "closed by a click outside")
	assert_false(hud.close_options(), "and only once")
	# The panel to the bottom, the name over it; and back.
	screen.size = Vector2(1280, 800)
	(option.call("Bar") as Button).pressed.emit()
	assert_true(hud.bar_at_bottom)
	assert_true(bool(Settings.get_value(WorldHud.BAR_SETTING, false)), "remembered")
	assert_eq(option.call("Bar").text, "Panel at the top")
	await get_tree().process_frame
	await get_tree().process_frame
	var at := hud.get_global_rect()
	var bar := (hud.find_child("Bar", true, false) as Control).get_global_rect()
	var line := (hud.find_child("HeroLine", true, false) as Control).get_global_rect()
	assert_almost_eq(bar.end.y, at.end.y - 8.0, 1.0, "at the bottom")
	assert_lte(line.end.y, bar.position.y, "the name over it")
	(hud.buttons["Hero"] as BaseButton).pressed.emit()
	var panel := (hud.find_child("HeroPanel", true, false) as Control).get_global_rect()
	assert_lte(panel.end.y, bar.position.y, "the hero's panel opens over it")
	hud.place_bar(false)
	assert_false(bool(Settings.get_value(WorldHud.BAR_SETTING, true)))
	# Exit game: saved, then the game ends.
	hud.exit_pressed.disconnect(screen.exit_game)
	var exits := [0]
	hud.exit_pressed.connect(func() -> void: exits[0] += 1)
	(hud.buttons["Options"] as BaseButton).pressed.emit()
	(option.call("Exit") as Button).pressed.emit()
	assert_eq(exits[0], 1, "Exit game asks to end it")


## The owner: "if you hover over the icon for a bit longer — help/icon name
## floats under it".
func test_a_resting_pointer_floats_the_name_under_the_row() -> void:
	var hud := screen.hud
	var part := hud.find_child("Strip_gold", true, false) as Control
	part.mouse_entered.emit()
	hud._process(WorldHud.HOVER_SECONDS * 0.5)
	assert_eq(hud.tip_shown(), "", "not at once")
	hud._process(WorldHud.HOVER_SECONDS)
	assert_eq(hud.tip_shown(), "Gold", "then its name")
	var tip := hud.find_child("Tip", true, false) as Control
	var bar := (hud.find_child("Bar", true, false) as Control).get_global_rect()
	assert_gte(tip.get_global_rect().position.y, bar.end.y, "under the row")
	part.mouse_exited.emit()
	assert_eq(hud.tip_shown(), "", "gone when the pointer leaves")
	assert_eq(hud.tip_for("magic:8")[0], "Staff of Thunder")
	assert_string_contains(hud.tip_for("magic:4")[1], "Not yours yet")
	assert_eq(hud.tip_for("amulet:red"), ["Red amulet", "Each one powers Staff of Thunder once."] as Array[String])
	assert_eq(hud.tip_for("button:Map")[0], "Map (M)")
	assert_eq(hud.tip_for("button:Help")[0], "Keys (H)")
	for key in hud.buttons:
		assert_eq(String((hud.buttons[key] as Control).tooltip_text), "", key + ": no tooltip at the pointer")


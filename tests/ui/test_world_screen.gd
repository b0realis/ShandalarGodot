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


## The settings the world screen's options and panes write, put back
## after each test.
const WORLD_SETTINGS: Array[String] = [WorldHud.BAR_SETTING, WorldHud.MINIMAP_SETTING,
	WorldHud.QUEST_SETTING, WorldHud.GUIDES_SETTING, WorldHud.PACE_SETTING, WorldHud.BIG_SETTING,
	WorldHud.PLACES_SETTING, TileReveal.SETTING,
	"world_pane_HeroPanel", "world_pane_HelpPanel",
	"world_pane_QuestPane", "world_pane_Minimap"]
const SAVES := "user://adventure_tests_world"
var _music := true
var _sound := true


func before_each() -> void:
	_music = Settings.music_enabled()
	_sound = Settings.sound_enabled()
	for key in WORLD_SETTINGS:
		Settings.clear_value(key)
	# Leaving the world saves it: into a folder of the tests' own.
	AdventurePlayer.saves_folder = SAVES
	screen = load("res://game/adventure/world/world_screen.tscn").instantiate()
	screen.record = _record()
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	for key in WORLD_SETTINGS:
		Settings.clear_value(key)
	Settings.set_value("music_enabled", _music)
	Settings.set_value("sound_enabled", _sound)
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


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
	assert_false(screen._leaving, "not yet")
	assert_true(screen.quit_asked(), "then asks Ready to Quit?")
	screen._quit_ask.answered.emit(true)
	await get_tree().process_frame
	assert_true(screen._leaving, "Yes.: then leaves")
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
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	screen._gui_input(motion)
	screen._gui_input(_mouse(from + Vector2(80, 0), false))
	assert_false(screen.walk.is_walking(), "a drag is no click")
	assert_ne(screen.view.camera, camera, "it looks around")


## The owner, 2026-10-22: "for walking normally a cursor of the mouse
## displays a small walking man"; and 2026-10-23: "for each unique place
## that can be visited design a mouse cursor that changes to that place …
## for the town a little house cursor, for dungeon a skull", and "over
## panes the cursor is normal gold mouse".
func test_the_pointer_is_the_walker_the_place_or_the_gold_arrow() -> void:
	var player := screen.player
	var start := player.tile()
	assert_eq(screen.pointer_for(start), WorldCursors.Kind.WALK, "walking on")
	var first := {}
	for slot in screen.world.sites.size():
		var kind := int(screen.world.sites[slot]["type"])
		if kind > 0 and not first.has(kind):
			first[kind] = Vector2i(int(screen.world.sites[slot]["x"]), int(screen.world.sites[slot]["y"]))
	var village: Vector2i = first[ShandalarWorld.VILLAGE]
	if not screen.world.is_explored(village.x, village.y):
		assert_eq(screen.pointer_for(village), WorldCursors.Kind.WALK, "a place unseen gives nothing away")
	for at in first.values():
		screen.world.explore_around(at)
	assert_eq(screen.pointer_for(village), WorldCursors.Kind.VILLAGE, "a little house")
	assert_eq(screen.pointer_for(first[ShandalarWorld.TOWN]), WorldCursors.Kind.TOWN)
	assert_eq(screen.pointer_for(first[ShandalarWorld.CITY]), WorldCursors.Kind.CITY)
	assert_eq(screen.pointer_for(first[ShandalarWorld.CASTLE]), WorldCursors.Kind.CASTLE)
	var dungeon: Dictionary = screen.world.encounters[5]
	var cave := Vector2i(int(dungeon["x"]), int(dungeon["y"]))
	screen.world.explore_around(cave)
	assert_eq(screen.pointer_for(cave), WorldCursors.Kind.WALK, "a dungeon not known: nothing")
	dungeon["clues"] = WorldClues.LOCATION
	assert_eq(screen.pointer_for(cave), WorldCursors.Kind.DUNGEON, "known: a skull")
	var seen: Array = []
	for kind in WorldCursors.Kind.values():
		var picture := WorldCursors.image(kind)
		assert_eq(picture.get_size(), Vector2i(WorldCursors.SIZE, WorldCursors.SIZE))
		assert_gt(picture.get_pixelv(Vector2i(WorldCursors.hotspot(kind))).a + picture.get_pixel(16, 16).a, 0.0,
			"something is drawn")
		assert_false(picture.get_data() in seen, "each its own")
		seen.append(picture.get_data())
	(screen.hud.find_child("Bar", true, false) as Control).mouse_entered.emit()
	assert_eq(screen._pointer, WorldCursors.Kind.ARROW, "over the panel: the gold arrow")
	# The owner: "when you hover over a place … a floating helper text with
	# place category and name … turned on/off in menu drop down pane".
	screen.size = Vector2(1280, 800)
	await get_tree().process_frame
	screen.view.camera = Vector2(village * 32 + Vector2i(16, 16))
	var over := InputEventMouseMotion.new()
	over.position = screen.view.feet() + screen.view.project(Vector2(village * 32 + Vector2i(16, 16))) * screen.view.zoom
	screen._gui_input(over)
	assert_eq(screen._pointer, WorldCursors.Kind.VILLAGE)
	assert_eq(screen.hud.place_shown(), WorldNames.site_name(screen.world, VisitPane.site_slot(screen.world, village)),
		"the village's name by the pointer")
	assert_eq((screen.hud.find_child("PlaceTipKind", true, false) as Label).text, "Village")
	var away := InputEventMouseMotion.new()
	away.position = screen.view.feet() + screen.view.project(Vector2(start * 32 + Vector2i(16, 16))) * screen.view.zoom
	screen.view.camera = Vector2(start * 32 + Vector2i(16, 16))
	away.position = screen.view.feet()
	screen._gui_input(away)
	assert_eq(screen.hud.place_shown(), "", "gone off the place")
	screen.hud._choose("Places")
	screen.view.camera = Vector2(village * 32 + Vector2i(16, 16))
	screen._gui_input(over)
	assert_eq(screen.hud.place_shown(), "", "switched off in the options")


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
	assert_false((hud.find_child("ArrowLeft", true, false) as Control).visible, "no arrows with a mouse")
	assert_eq((hud.find_child("HeroLine", true, false) as Label).text, "Goya · Magician")
	assert_eq((hud.find_child("HeroLine", true, false) as Label).get_theme_color("font_color"),
		WorldHud.NAME_INKS["red"][0], "in the hero's colour of magic")
	var number := func(slot: String) -> String:
		return ((hud.find_child(slot, true, false) as Node).find_child("Number", true, false) as Label).text
	assert_eq(number.call("Strip_gold"), str(screen.player.gold))
	assert_eq(number.call("Strip_food"), str(screen.player.food))
	assert_eq(number.call("Strip_ankh"), "10", "the world's first ten towns and cities: ten mana links")
	assert_eq(number.call("Strip_book"), "40/40", "a Magician's first deck, all of it in Deck 1")
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
	for name in ["Deck", "Map", "Clues", "Hero", "Options", "Help"]:
		assert_not_null(hud.buttons.get(name), name)
	assert_null(hud.buttons.get("Save"), "saving is among the options now")
	(hud.buttons["Map"] as BaseButton).pressed.emit()
	assert_true((screen.find_child("Map", true, false) as Control).visible, "the map's scroll opens the map")
	screen.toggle_map()
	(hud.buttons["Hero"] as BaseButton).pressed.emit()
	assert_true(hud.hero_shown(), "the hero's faces open the journal and stats")
	var stats := hud.hero_stats
	for caption in ["World_Magics", "Wizards_Castles_Conquered", "Record_vs_the_Creatures_of_Shandalar"]:
		assert_not_null(stats.find_child("Caption_" + caption, true, false), caption + ", the 1997 caption")
	assert_eq((stats.find_child("HeroName", true, false) as Label).text, "Goya")
	assert_eq((stats.find_child("Value_Overall_Won_Loss", true, false) as Label).text, "0/0")
	await get_tree().process_frame
	var pane := hud.find_child("HeroPanel", true, false) as Control
	var hero_size := pane.size
	screen.player.log_event("magic", "JUMP!")
	(stats.find_child("Tab_Journal", true, false) as Button).pressed.emit()
	assert_eq(stats.journal_lines(), ["Day 0: JUMP!"] as Array[String], "the journal tab")
	await get_tree().process_frame
	assert_eq(pane.size, hero_size, "the journal keeps the Hero tab's size")
	(stats.find_child("Tab_Wizards", true, false) as Button).pressed.emit()
	assert_not_null(stats.find_child("Wizards", true, false), "the wizards' tab")
	await get_tree().process_frame
	assert_eq(pane.size, hero_size, "and the wizards' tab")
	for i in 40:
		screen.player.log_event("magic", "A long line for the journal, the day the hero went far and wide %d" % i)
	stats.show_tab("Journal")
	await get_tree().process_frame
	assert_eq(pane.size, hero_size, "however long the journal grows")
	assert_true((stats.find_child("JournalBar", true, false) as Control).visible, "a scroll bar for a long one")
	stats.show_tab("Hero")
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
	assert_true(screen.building(), "the spellbook opens the deck builder over the world")
	var builder := screen.find_child("DeckBuilder", true, false) as AdventureBuilder
	assert_not_null(builder)
	assert_eq(builder.gold_text(), "GOLD: %d" % screen.player.gold, "the hero's gold on its title")
	var ticked := screen.player.monster_timer
	screen._process(1.0)
	assert_eq(screen.player.monster_timer, ticked, "the world waits under it")
	builder._exit()
	await get_tree().process_frame
	assert_false(screen.building(), "Done: the world again")
	assert_eq(hud.notice(), "Deck 1: 40 cards")
	AdventurePlayer.saves_folder = "user://adventure_tests_hud"
	var path := screen.save_into_slot(1, "Before the duel")
	assert_true(FileAccess.file_exists(path), "a slot written")
	assert_true(path.ends_with(".slot01.json"), "beside its autosave, slot 1")
	assert_eq(hud.notice(), "Saved.")
	assert_eq(String(SaveSlots.slots_of(screen.player.adventure_id)[0]["name"]), "Before the duel", "by its name")
	DirAccess.remove_absolute(path)
	AdventurePlayer.saves_folder = SAVES


## The owner: "an options icon besides help. When you click it you get a
## dropdown menu — exit game, save, load, and an option to drop this panel
## to bottom of the screen"; the painted book that was Save opens it.
func test_the_options() -> void:
	var hud := screen.hud
	var option := func(entry: String) -> Button:
		return hud.find_child("Option_" + entry, true, false) as Button
	(hud.buttons["Options"] as BaseButton).pressed.emit()
	assert_true(hud.options_shown(), "the book opens the options")
	var words: Array[String] = []
	for entry in WorldHud.OPTIONS:
		words.append(option.call(entry[0]).text)
	var on_off := func(on: bool) -> String: return "on" if on else "off"
	assert_eq(words, ["Save", "Load (L)", "City list (F3)", "Wizards (F6)", "Panel at the bottom", "Small map: on",
		"Quest pane: on", "Guide arrows: on", "Path arrows: on", "Place names: on", "Creature names: off",
		"Large card on right-click: on", "Big buttons: off",
		"Pace: as in 1997", "Transitions: " + on_off.call(Settings.transitions()), "Music: " + on_off.call(_music),
		"Sound: " + on_off.call(_sound), "Return to main menu", "Exit game"] as Array[String])
	# Save.
	AdventurePlayer.saves_folder = "user://adventure_tests_options"
	(option.call("Save") as Button).pressed.emit()
	assert_false(hud.options_shown(), "a choice closes the options")
	var slots := screen.find_child("SaveSlots", true, false) as SaveSlotsPane
	assert_not_null(slots, "the ten slots")
	assert_eq(slots.find_child("Slots", true, false).get_child_count(), 10)
	var path := slots.save_into(2, "")
	assert_true(FileAccess.file_exists(path), "Save writes the adventure")
	assert_string_contains(slots.note(), "Saved to slot 2: Day 0 near", "a blank name: the day and the place")
	slots.done.emit()
	await get_tree().process_frame
	DirAccess.remove_absolute(path)
	AdventurePlayer.saves_folder = SAVES
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
	# The switches leave the options open and say how they now stand.
	(hud.buttons["Options"] as BaseButton).pressed.emit()
	(option.call("Minimap") as Button).pressed.emit()
	assert_true(hud.options_shown(), "a switch leaves the options open")
	assert_false(hud.minimap_shown(), "the small map hides")
	assert_eq(option.call("Minimap").text, "Small map: off")
	assert_false(bool(Settings.get_value(WorldHud.MINIMAP_SETTING, true)), "remembered")
	(option.call("Minimap") as Button).pressed.emit()
	assert_true(hud.minimap_shown())
	for step in ["brisk", "swift", "as in 1997"]:
		(option.call("Pace") as Button).pressed.emit()
		assert_eq(option.call("Pace").text, "Pace: " + step)
	(option.call("Pace") as Button).pressed.emit()
	assert_eq(WorldHud.pace(), 1.5, "brisk: the world's clock half as fast again")
	var ticked := screen.player.monster_timer
	screen._tick_left = 0.0
	screen._process(HeroWalk.TICK * 2.1)
	assert_eq(screen.player.monster_timer, ticked + 3, "three ticks where 1997 ran two")
	var transitions := Settings.transitions()
	(option.call("Transitions") as Button).pressed.emit()
	assert_eq(Settings.transitions(), not transitions, "the transitions switched, the Options screen's too")
	assert_eq(option.call("Transitions").text, "Transitions: " + on_off.call(not transitions))
	(option.call("Music") as Button).pressed.emit()
	assert_eq(Settings.music_enabled(), not _music, "music switched")
	assert_eq(option.call("Music").text, "Music: " + on_off.call(not _music))
	(option.call("Sound") as Button).pressed.emit()
	assert_eq(Settings.sound_enabled(), not _sound, "sound switched")
	(option.call("Guides") as Button).pressed.emit()
	assert_false(WorldHud.guides_wanted())
	(option.call("Quest") as Button).pressed.emit()
	assert_false(hud.quest_pane_wanted())
	hud.close_options()
	# Return to main menu: saved first, then the title.
	(hud.buttons["Options"] as BaseButton).pressed.emit()
	(option.call("Menu") as Button).pressed.emit()
	assert_true(screen._leaving, "on the way to the title")
	assert_true(FileAccess.file_exists(screen.player.save_path()), "autosaved as it left")
	screen._leaving = false
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
	assert_eq(hud.tip_for("amulet:red"), ["Red amulet", "Casting Staff of Thunder risks one."] as Array[String])
	assert_eq(hud.tip_for("magic:8")[1], "Risk one red amulet to destroy the nearest creature. Click, or press 4.",
		"the 1997 words, and how to cast it")
	assert_eq(hud.tip_for("button:Map")[0], "Map (M)")
	assert_eq(hud.tip_for("button:Help")[0], "Keys (H)")
	for key in hud.buttons:
		assert_eq(String((hud.buttons[key] as Control).tooltip_text), "", key + ": no tooltip at the pointer")



func _key(code: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = code
	press.pressed = true
	screen._unhandled_input(press)


## The owner: "implement all items you suggest" — the five World Magics
## that risk an amulet are cast with 1–5 or a click on their icon, as 1.3
## cast them (`UpdateAdventureWorldInputAndMovement`).
func test_the_world_magics_are_cast() -> void:
	var player := screen.player
	var hud := screen.hud
	player.amulets["blue"] = 2
	_key(KEY_2)
	assert_string_contains(hud.notice(), "Leap of Fate is not yours yet")
	assert_eq(int(player.amulets["blue"]), 2, "nothing risked")
	# Leap of Fate: the dice draw a tile, x then y, until it is land.
	player.world_magics.append("Leap of Fate")
	var dice := MsvcRandom.new(player.dice)
	var risked := dice.below(4 - player.difficulty) == 0
	var x := 0
	var y := 0
	while true:
		x = dice.below(64)
		y = dice.below(64)
		if player.world.is_land(x, y):
			break
	_key(KEY_2)
	assert_eq(player.position, Vector2i(x * 32 + 16, y * 32 + 16), "a land tile drawn by the dice, its middle")
	assert_eq(player.dice, dice.state, "the adventure's dice went on")
	assert_eq(int(player.amulets["blue"]), 1 if risked else 2, "the amulet risked: one time in three for a Magician")
	assert_eq(String(player.journal[-1]["text"]), "JUMP!", "the 1997 journal line")
	assert_true(player.world.is_explored(x, y), "the land round them seen")
	assert_eq(screen.view.camera, Vector2(player.position), "the view goes with them")
	assert_string_contains(hud.notice(), "Leap of Fate")
	# Quickening.
	player.world_magics.append("Quickening")
	player.amulets["green"] = 1
	_key(KEY_3)
	assert_eq(player.quickening, WorldMagic.QUICKENING_TICKS, "a burst of speed")
	if hud.find_child("Magic_6", true, false) != null:
		assert_true(hud.magic_working(6), "its icon lit while it runs")
	# Staff of Thunder (the red hero's own): nothing to strike, nothing risked.
	var red := int(player.amulets["red"])
	_key(KEY_4)
	assert_eq(hud.notice(), "No creature roams near enough to strike.")
	assert_eq(int(player.amulets["red"]), red)
	player.monsters = [
		{"slot": 0, "kind": "creature", "creature": 31, "x": player.position.x + 600, "y": player.position.y},
		{"slot": 1, "kind": "creature", "creature": 32, "x": player.position.x + 40, "y": player.position.y + 40},
		{"slot": 7, "kind": "creature", "creature": 5, "x": player.position.x, "y": player.position.y, "town": 0}]
	screen.cast(4)
	assert_eq(player.monsters.size(), 2, "one struck")
	assert_eq(String(player.journal[-1]["text"]), "THUNDERED on: Goblin Lord!", "the nearest roaming one")
	assert_eq(int(player.monsters[1]["creature"]), 5, "never the siege's creature")
	# Sword of Resistance: to the creature besieging a city.
	player.world_magics.append("Sword of Resistance")
	player.amulets["white"] = 1
	player.monsters = []
	_key(KEY_5)
	assert_eq(hud.notice(), "No town is under siege.")
	player.monsters = [{"slot": 7, "name": "Shade", "x": 500, "y": 700, "town": 9}]
	player.amulets["white"] = 1
	_key(KEY_5)
	assert_eq(player.position, Vector2i(480 + 16, 672 + 31), "by its tile, as 1.3 sets the hero down")
	assert_eq(String(player.journal[-1]["text"]), "Went to aid of " + WorldNames.site_name(player.world, 9))
	# Conjurer's Will: the deck builder, out here.
	player.world_magics.append("Conjurer's Will")
	player.amulets["black"] = 1
	_key(KEY_1)
	assert_true(screen.building(), "the deck to change out in the wilds")
	(screen.find_child("DeckBuilder", true, false) as AdventureBuilder)._exit()
	await get_tree().process_frame
	# A click on a lit icon casts it (with the 1997 sheets).
	var icon := hud.find_child("Magic_8", true, false) as Control
	if icon != null:
		player.amulets["red"] = 1
		hud.refresh()
		assert_true((icon.find_child("Key", true, false) as Control).visible, "its key over it, as 1997 drew it")
		watch_signals(hud)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = false
		icon.gui_input.emit(click)
		assert_signal_emitted_with_parameters(hud, "cast_pressed", [4])


## The owner: "popup or hover panes with rounded corners that can be
## moved at will … for example 6, and it should be togglable on/off in
## options".
func test_the_panes_move_where_they_are_dragged_and_stay() -> void:
	var hud := screen.hud
	screen.size = Vector2(1280, 800)
	await get_tree().process_frame
	await get_tree().process_frame
	var drag := func(pane: Control, from: Vector2, to: Vector2, part: Control = null) -> void:
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.global_position = from
		press.position = from - (part if part != null else pane).get_global_rect().position
		var move := InputEventMouseMotion.new()
		move.global_position = to
		move.button_mask = MOUSE_BUTTON_MASK_LEFT
		var let_go := press.duplicate() as InputEventMouseButton
		let_go.pressed = false
		let_go.global_position = to
		for event in [press, move, let_go]:
			hud._pane_input(pane, event)
	hud.toggle_hero()
	var panel := hud.find_child("HeroPanel", true, false) as Control
	var face := panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert_gt(face.corner_radius_top_left, 0, "a pane with round corners")
	var was := panel.position
	drag.call(panel, was + Vector2(20, 20), was + Vector2(-280, 220))
	assert_eq(panel.position, was + Vector2(-300, 200), "where it was dragged")
	assert_eq(Settings.get_value("world_pane_HeroPanel", null), [panel.position.x, panel.position.y], "remembered")
	hud.toggle_hero()
	hud.toggle_hero()
	assert_eq(panel.position, was + Vector2(-300, 200), "and there again next time")
	drag.call(panel, panel.position + Vector2(10, 10), Vector2(5000, -5000))
	assert_true(Rect2(Vector2.ZERO, hud.size).encloses(panel.get_rect()), "never off the screen")
	# Hidden under the press (F5 again), it does not follow a pointer that
	# merely moves when it shows again.
	var press_only := InputEventMouseButton.new()
	press_only.button_index = MOUSE_BUTTON_LEFT
	press_only.pressed = true
	press_only.global_position = panel.position + Vector2(10, 10)
	hud._pane_input(panel, press_only)
	hud.toggle_hero()
	hud.toggle_hero()
	var resting := panel.position
	var hover := InputEventMouseMotion.new()
	hover.global_position = resting + Vector2(200, 100)
	hud._pane_input(panel, hover)
	assert_eq(panel.position, resting, "no drag left armed")
	hud.close_panels()
	# The small map: a click walks there, a drag moves it.
	var minimap := hud.minimap
	assert_true(minimap.visible, "on at first")
	var corner := minimap.get_global_rect()
	assert_almost_eq(corner.end.x, 1268.0, 1.0, "in the corner away from the panel")
	assert_almost_eq(corner.end.y, 788.0, 1.0)
	watch_signals(hud)
	var point := Vector2(180, 40)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = point
	press.global_position = corner.position + point
	hud._pane_input(minimap, press)
	var let_go := press.duplicate() as InputEventMouseButton
	let_go.pressed = false
	hud._pane_input(minimap, let_go, func(at: Vector2) -> void: hud.walk_requested.emit(minimap.tile_at(at)))
	assert_signal_emitted_with_parameters(hud, "walk_requested", [minimap.tile_at(point)])
	drag.call(minimap, corner.position + point, corner.position + point - Vector2(600, 400))
	assert_eq(minimap.get_global_rect().position, corner.position - Vector2(600, 400), "dragged across")
	assert_not_null(Settings.get_value("world_pane_Minimap", null), "and remembered")
	var face_map := (minimap.find_child("Glass", true, false) as Control).get_theme_stylebox("panel") as StyleBoxFlat
	assert_gt(face_map.corner_radius_top_left, 0, "round corners")
	assert_eq((minimap.find_child("Glass", true, false) as CanvasItem).clip_children,
		CanvasItem.CLIP_CHILDREN_AND_DRAW, "the land kept inside them")
	_key(KEY_N)
	assert_false(hud.minimap_shown(), "N hides it")
	_key(KEY_N)
	assert_true(hud.minimap_shown())


## What calls the hero: the 1997 quest panel's lines in a pane, and the
## guide arrows to the places.
func test_the_quest_pane_and_the_guides() -> void:
	var player := screen.player
	var hud := screen.hud
	screen.size = Vector2(1280, 800)
	await get_tree().process_frame
	assert_false(hud.quest_pane_shown(), "nothing calls: no pane")
	assert_false(screen.guides.visible, "and no arrows")
	var towns: Array[int] = []
	for slot in player.world.sites.size():
		if int(player.world.sites[slot]["type"]) in [ShandalarWorld.TOWN, ShandalarWorld.CITY]:
			towns.append(slot)
	var town := towns[0]
	var giver := towns[1]
	var called := WorldNames.site_name(player.world, town)
	var there := Vector2i(int(player.world.sites[town]["x"]), int(player.world.sites[town]["y"]))
	var way := WorldNames.quadrant(there.x - player.tile().x, there.y - player.tile().y)
	player.quest = {"type": 0, "destination": town, "color": 2, "data": way,
		"deadline": player.quest_timer + 32, "giver": giver}
	screen.advance(HeroWalk.TICK)
	assert_true(hud.quest_pane_shown(), "a quest: the pane")
	var lines := func() -> String: return (hud.find_child("QuestLines", true, false) as Label).text
	assert_eq(lines.call(), "Go %s to %s\nReward: Mana Link\n3 days left" % [WorldNames.DIRECTIONS[way], called])
	player.quest["data"] = -1
	hud.refresh()
	assert_string_contains(lines.call(), "Take letter to " + called)
	# The arrows: a ring on the place on the screen, an arrow when it is not.
	assert_true(screen.guides.visible)
	var target: Dictionary = screen.guides.targets[0]
	assert_eq(target["kind"], "quest")
	assert_eq(target["name"], called)
	var site: Dictionary = player.world.sites[town]
	var tile := Vector2i(int(site["x"]), int(site["y"]))
	screen.view.camera = Vector2(tile * 32 + Vector2i(16, 16))
	assert_false(screen.guides.guide_for(tile)["arrow"], "on the screen: ringed where it stands")
	screen.view.camera = Vector2(tile * 32) + Vector2(0, 40 * 32)
	var guide: Dictionary = screen.guides.guide_for(tile)
	assert_true(guide["arrow"], "off it: an arrow")
	assert_true(screen.guides.room().grow(1.0).has_point(guide["at"]), "at the edge, clear of the panel")
	assert_gt(Vector2(guide["way"]).dot(screen.guides.on_screen(tile) - screen.guides.room().get_center()), 0.0,
		"pointing its way")
	assert_eq(hud.minimap.marks.size(), 1, "the small map marks it")
	# A siege, a bonus, a wizard's tap.
	player.monsters = [{"slot": 7, "kind": "creature", "creature": 31, "x": tile.x * 32, "y": tile.y * 32,
		"color": 4, "town": town}]
	player.next_duel_life = 2
	player.next_duel_first_move = true
	player.world.sites[giver]["status"] = int(player.world.sites[giver]["status"]) | (4 << 8)
	hud.refresh()
	screen._show_hero()
	var said: String = lines.call()
	assert_string_contains(said, "Troll Shaman attacking %s!" % called, "its name, no article (part B)")
	assert_string_contains(said, "Next Duel: +2 lives, First Move")
	assert_string_contains(said, "Red Wizardess: 1 of 3 mana taps")
	assert_eq(screen.guides.targets[0]["kind"], "siege", "the siege first")
	player.world_magics.append("Ring of the Guardian")
	hud.refresh()
	assert_string_contains(lines.call(), "1 of 5 mana taps", "the Ring: five")
	# The panel to the bottom: the quest pane goes to the top, off it.
	var quest_pane := hud.find_child("QuestPane", true, false) as Control
	assert_gt(quest_pane.get_global_rect().position.y, 400.0, "at the bottom left, the panel at the top")
	hud.place_bar(true)
	await get_tree().process_frame
	var panel := (hud.find_child("Bar", true, false) as Control).get_global_rect()
	assert_false(quest_pane.get_global_rect().intersects(panel), "never over the panel")
	assert_lt(quest_pane.get_global_rect().position.y, 100.0, "at the top left now")
	hud.place_bar(false)
	await get_tree().process_frame
	assert_gt(quest_pane.get_global_rect().position.y, 400.0, "and back")
	# Switched off, it stays away.
	hud.show_quest_pane(false)
	assert_false(hud.quest_pane_shown())
	hud.show_quest_pane(true)
	hud.show_guides(false)
	screen._show_hero()
	assert_false(screen.guides.visible, "the arrows switched off")
	hud.show_guides(true)
	# Time runs out.
	player.monsters = []
	player.quest_timer = int(player.quest["deadline"])
	screen.advance(HeroWalk.TICK)
	assert_eq(hud.notice(), "The people of %s are sorry their quest was not completed."
		% WorldNames.site_name(player.world, giver))
	assert_true(player.quest.is_empty(), "the quest is lost")
	assert_true(TownStatus.refuses_quests(player.world, giver), "the town gives no other (0x04)")


## F4, the frame's gate: what is known of the castles and the dungeons.
func test_the_clues() -> void:
	_key(KEY_F4)
	await get_tree().process_frame
	assert_true(screen.clues_shown(), "F4 opens the clues")
	assert_true(screen.modal(), "the clues' pane holds the world")
	var pane := screen.find_child("CluesPane", false, false) as CluesPane
	assert_eq(pane.words(), WorldClues.NONE_YET, "none known yet")
	# F4 again is the pane's own key (it holds the world, the screen's keys
	# rest under it); the screen's door closes it too.
	assert_null(screen.show_clues(), "asked again: closed")
	await get_tree().process_frame
	assert_false(screen.clues_shown(), "and closes them")
	var world := screen.world
	world.encounters[0]["clues"] = WorldClues.CREATURES
	world.encounters[5]["clues"] = WorldClues.CREATURES | WorldClues.RULES | WorldClues.LOCATION
	(screen.hud.buttons["Clues"] as BaseButton).pressed.emit()
	await get_tree().process_frame
	pane = screen.find_child("CluesPane", false, false) as CluesPane
	assert_eq(pane.listed(), [0, 5] as Array[int], "the castle, then the dungeon")
	pane.show_clue(5)
	var said := "\n".join(pane.clue_lines(5))
	var color: int = world.encounters[5]["color"]
	assert_string_contains(said, "-Contains small %s creatures." % WorldClues.COLOR_WORDS[color])
	assert_string_contains(said, "Dungeon Rules:")
	assert_string_contains(said, "Location:")
	assert_string_contains(said, " of %s." % WorldNames.site_name(world, int(world.encounters[5]["town"])))
	assert_eq(pane.stage.cards_shown(), WorldClues.treasures(world, 5), "the treasure as cards")
	pane.close()
	await get_tree().process_frame
	assert_false(screen.clues_shown())
	assert_false(screen.modal(), "the world again")



## The owner: "touch-pad support? Maybe we can have bigger buttons on the
## pane with left and right arrows at the distal ends for touch" — big
## buttons, the row scrolling between two red arrows; a pinch zooms and a
## touchpad's slide looks.
func test_big_buttons_and_gestures_for_a_finger() -> void:
	screen.size = Vector2(1280, 800)
	var hud := screen.hud
	assert_false(hud.big, "a desk with a mouse: the panel as it was")
	(hud.buttons["Options"] as BaseButton).pressed.emit()
	(hud.find_child("Option_Big", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	hud = screen.hud
	assert_true(hud.big, "made again with big buttons")
	assert_true(bool(Settings.get_value(WorldHud.BIG_SETTING, false)), "remembered")
	assert_eq(screen.find_children("Hud*", "WorldHud", false, false).size(), 1, "one panel, the old one gone")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_gte((hud.buttons["Map"] as Control).size.y, 44.0, "a finger's target")
	# A narrow screen, so the row overflows with the 1997 icons or without.
	screen.size = Vector2(720, 800)
	await get_tree().process_frame
	await get_tree().process_frame
	var right := hud.find_child("ArrowRight", true, false) as RedArrow
	var left := hud.find_child("ArrowLeft", true, false) as RedArrow
	assert_true(right.visible and left.visible, "the arrows at the panel's ends when the row overflows")
	assert_true(left.disabled, "nothing to the left yet")
	var bar := (hud.find_child("Bar", true, false) as Control).get_global_rect()
	assert_almost_eq(right.get_global_rect().end.x, bar.end.x - 10.0, 1.0, "at the far end")
	var scroll := hud.row_scroll()
	right.pressed.emit()
	assert_gt(scroll.scroll_horizontal, 0, "the row moves on")
	assert_false(left.disabled)
	left.pressed.emit()
	assert_eq(scroll.scroll_horizontal, 0, "and back")
	screen.size = Vector2(4000, 800)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(right.visible, "room for it all: no arrows")
	screen.size = Vector2(1280, 800)
	# The gestures.
	var zoom := screen.view.zoom
	var pinch := InputEventMagnifyGesture.new()
	pinch.factor = 1.2
	screen._gui_input(pinch)
	assert_almost_eq(screen.view.zoom, minf(zoom * 1.2, WorldView.ZOOM_MAX), 0.001, "a pinch zooms")
	var camera := screen.view.camera
	var slide := InputEventPanGesture.new()
	slide.delta = Vector2(3, 0)
	screen._gui_input(slide)
	assert_ne(screen.view.camera, camera, "a touchpad's slide looks")

extends GutTest
## THE DUNGEON & CASTLE CLUES, THE RICH PANE (part C, stage C2, W7; the
## owner's c4-3): [CluesPane] — the list (castles then dungeons, what is
## known, a "?" where it lies is not, how clues are found when nothing
## is), a place's page (1997's words in their inks, the treasure cards
## always, the creatures' faces only once known, a castle's wizard, 1997's
## Done back to the list), "Show on map" only once where it lies is known
## and the map it opens ([ClueMap]: the place ringed, City Info put away),
## the keys (Escape back then closed, F4, the arrows from place to place),
## `done` once, and the pane on the window at 1280 × 800 and 800 × 600,
## with and without the Big buttons.

var base: Dictionary
var player: AdventurePlayer
var viewport: SubViewport
var closed := 0


func before_all() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Seeker"
	setup.color = "blue"
	setup.difficulty = 1
	setup.walker = "female"
	setup.seed_text = "5150"
	var record := setup.resolve({})
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	base = JSON.parse_string(JSON.stringify(hero.to_dict()))


func before_each() -> void:
	player = AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(base)))
	for slot in player.world.encounters:
		(slot as Dictionary)["clues"] = 0
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	closed = 0


func _frames(count := 3) -> void:
	for i in count:
		await get_tree().process_frame


func _tell(told: Dictionary) -> void:
	for index in told:
		(player.world.encounters[index] as Dictionary)["clues"] = told[index]


## A dungeon slot that holds cards (the list shows only those).
func _dungeon_with_cards() -> int:
	for index in range(5, 15):
		if WorldClues.holds_cards(player.world.encounters[index]):
			return index
	return -1


func _open(k := 1.0) -> CluesPane:
	var pane := CluesPane.make(player)
	assert_false(pane.is_inside_tree(), "make: not yet in the tree")
	pane.k = k
	pane.done.connect(func() -> void: closed += 1)
	viewport.add_child(pane)
	PaneStyle.centre(pane)
	await _frames()
	return pane


func _key(code: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	viewport.push_input(down, true)
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	viewport.push_input(up, true)
	await _frames()


func _press(node: Control) -> void:
	var at := node.get_global_rect().get_center()
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.position = at
		click.global_position = at
		viewport.push_input(click, true)
	await _frames()


func _lines(pane: CluesPane) -> Array[String]:
	var out: Array[String] = []
	for i in 40:
		var line := pane.stage.part("ClueLine%d" % i) as Label
		if line == null:
			break
		out.append(line.text)
	return out


# ------------------------------------------------------------- the list --

func test_nothing_known_says_how_clues_are_found() -> void:
	var pane := await _open()
	assert_eq(pane.title_text(), CluesPane.TITLE, "Dungeon & Castle Clues")
	assert_eq(pane.listed(), [] as Array[int])
	assert_eq(pane.words(), WorldClues.NONE_YET)
	assert_eq(pane.choice_ids(), ["done"] as Array[String])


func test_the_list_is_what_is_known_castles_first_each_with_its_icon_where_it_lies() -> void:
	var dungeon := _dungeon_with_cards()
	_tell({3: WorldClues.CREATURES, 0: WorldClues.LOCATION, dungeon: WorldClues.LOCATION | WorldClues.RULES})
	player.defeated_wizards.append("black")
	var pane := await _open()
	assert_eq(pane.listed(), WorldClues.known(player.world), "castles 0–4, then dungeons")
	assert_eq(pane.listed(), [0, 3, dungeon] as Array[int])
	assert_false(pane.page_shown(), "the list in the page's place")
	var castle := pane.find_child("Clue_0", true, false)
	assert_eq((castle.find_child("Name", true, false) as Label).text, WorldNames.dungeon_name(0))
	assert_eq((castle.find_child("Kind", true, false) as Label).text, "Black Castle, beaten")
	assert_true((castle.find_child("Icon", true, false) as CluesPane.ClueIcon).located, "where it lies known")
	var red := pane.find_child("Clue_3", true, false)
	assert_false((red.find_child("Icon", true, false) as CluesPane.ClueIcon).located, "not known: a ?")
	assert_eq((pane.find_child("Clue_%d" % dungeon, true, false).find_child("Kind", true, false) as Label).text,
		CluesPane.DUNGEON)


func test_a_click_on_a_place_opens_its_page_and_1997_s_done_goes_back() -> void:
	_tell({0: 7})
	var pane := await _open()
	await _press(pane.find_child("Clue_0", true, false) as Control)
	assert_eq(pane.slot, 0, "its page")
	assert_true(pane.page_shown())
	assert_eq(pane.stage.ground_key(), "clue_detail", "1997's misty cave (Clueback)")
	assert_eq(pane.title_text(), WorldNames.dungeon_name(0))
	assert_eq(pane.subtitle_text(), "Black Castle")
	await _press(pane.stage.part("PageDone") as Control)
	assert_eq(pane.slot, -1, "Done: back to the list (1997's)")
	assert_eq(closed, 0)


# ------------------------------------------------------------- the page --

func test_the_page_says_what_is_known_in_1997_s_inks_without_the_treasure_line() -> void:
	var dungeon := _dungeon_with_cards()
	_tell({dungeon: 7})
	var pane := await _open()
	pane.show_clue(dungeon)
	var expected: Array[String] = []
	for line in WorldClues.lines(player.world, dungeon):
		if not line.begins_with("Treasure: "):
			expected.append(line)
	assert_eq(_lines(pane), expected, "the clue's words, a line each")
	assert_eq(_lines(pane)[0], "Creatures:")
	var heading := pane.stage.part("ClueLine0") as Label
	var line := pane.stage.part("ClueLine1") as Label
	assert_eq(heading.get_theme_color("font_color"), CluesPane.HEADING_INK, "#a5443f")
	assert_eq(line.get_theme_color("font_color"), CluesPane.LINE_INK, "#cdb08f")
	assert_eq(heading.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT)


func test_the_treasure_cards_show_always_and_the_faces_only_once_known() -> void:
	var dungeon := _dungeon_with_cards()
	_tell({dungeon: WorldClues.RULES})
	var pane := await _open()
	pane.show_clue(dungeon)
	assert_eq(pane.stage.cards_shown(), WorldClues.treasures(player.world, dungeon),
		"every card the dungeon holds, whatever is known")
	var rows := CluesPane.creatures_of(player.world, dungeon)
	assert_null(pane.stage.part("Face%dName" % rows[0]), "its creatures not known: no faces")
	_tell({dungeon: WorldClues.RULES | WorldClues.CREATURES})
	pane.show_clue(dungeon)
	for row in rows:
		var named := pane.stage.part("Face%dName" % row) as Label
		assert_not_null(named, "the face of %s" % CreatureBook.name_of(row))
		if named != null:
			assert_eq(named.text, CreatureBook.name_of(row))


func test_a_castle_shows_its_wizard_and_no_cards() -> void:
	_tell({2: WorldClues.CREATURES})
	var pane := await _open()
	pane.show_clue(2)
	assert_eq(pane.stage.cards_shown(), [] as Array[String], "a castle holds no cards")
	assert_eq((pane.stage.part("CreatureName") as Label).text, CreatureBook.name_of(CreatureBook.castle_row(3)),
		"the green castle's wizard waits in it")
	for row in CluesPane.creatures_of(player.world, 2):
		assert_not_null(pane.stage.part("Face%dName" % row))


# ---------------------------------------------------------- show on map --

func test_show_on_map_only_once_where_it_lies_is_known() -> void:
	_tell({1: WorldClues.RULES})
	var pane := await _open()
	pane.show_clue(1)
	assert_true(pane.choice("map").disabled, "where it lies not known")
	assert_eq(pane.note(), CluesPane.NOT_WHERE)
	assert_null(pane.show_on_map())
	_tell({1: WorldClues.RULES | WorldClues.LOCATION})
	pane.show_clue(1)
	assert_false(pane.choice("map").disabled)
	assert_eq(pane.note(), "")


func test_the_map_rings_the_place_and_closing_it_brings_the_page_back() -> void:
	var dungeon := _dungeon_with_cards()
	_tell({dungeon: 7})
	var pane := await _open()
	pane.show_clue(dungeon)
	await _press(pane.choice("map"))
	var map := pane.map_shown()
	assert_not_null(map, "the map over the screen")
	assert_false(pane.visible, "the pane hidden under it")
	var slot: Dictionary = player.world.encounters[dungeon]
	assert_eq(map.mark_tile, Vector2i(int(slot["x"]), int(slot["y"])), "the place ringed")
	assert_true(map.mark_dungeon)
	assert_eq(map.mark_name, WorldNames.dungeon_name(dungeon))
	assert_string_contains(map.mark_line, WorldNames.dungeon_name(dungeon))
	assert_false((map.find_child("Map_CityInfo", true, false) as Control).visible, "City Info put away")
	assert_true(map.key(KEY_C), "its key does nothing here")
	assert_eq(pane.map_shown(), map)
	await _key(KEY_ESCAPE)
	assert_null(pane.map_shown(), "Escape closes the map")
	assert_true(pane.visible, "the page again")
	assert_eq(pane.slot, dungeon)
	pane.show_on_map()
	await _key(KEY_D)
	assert_null(pane.map_shown(), "the map's own keys close it (D, Done)")
	assert_eq(closed, 0)


# ------------------------------------------------------------- the keys --

func test_escape_goes_back_then_closes_once() -> void:
	_tell({0: 7})
	var pane := await _open()
	pane.show_clue(0)
	await _key(KEY_ESCAPE)
	assert_eq(pane.slot, -1, "the page back to the list")
	assert_eq(closed, 0)
	await _key(KEY_ESCAPE)
	assert_eq(closed, 1, "the list closed")
	assert_false(is_instance_valid(pane), "the pane gone")


func test_done_closes_once() -> void:
	var pane := await _open()
	pane.choose("done")
	assert_true(pane.closed())
	assert_false(pane.is_inside_tree(), "taken away at once")
	pane.close()
	assert_eq(closed, 1, "once")


func test_f4_closes_and_the_arrows_go_from_place_to_place() -> void:
	var dungeon := _dungeon_with_cards()
	_tell({0: 7, 4: 2, dungeon: 1})
	var pane := await _open()
	pane.show_clue(0)
	await _key(KEY_RIGHT)
	assert_eq(pane.slot, 4)
	await _key(KEY_RIGHT)
	assert_eq(pane.slot, dungeon)
	await _key(KEY_RIGHT)
	assert_eq(pane.slot, 0, "round again")
	await _key(KEY_LEFT)
	assert_eq(pane.slot, dungeon)
	await _key(KEY_F4)
	assert_eq(closed, 1, "F4 closes, as it opened")


# ------------------------------------------------------------- the fit --

func test_the_pane_fits_the_window_with_and_without_big_buttons() -> void:
	var told := {}
	for index in 15:
		if index < 5 or WorldClues.holds_cards(player.world.encounters[index]):
			told[index] = 7
	_tell(told)
	for size in [Vector2i(1280, 800), Vector2i(800, 600)]:
		for k in [1.0, WorldHud.BIG]:
			viewport.size = size
			var pane := await _open(k)
			var room := Rect2(Vector2.ZERO, Vector2(size))
			await _frames(4)
			assert_true(room.encloses(pane.get_rect()), "%s at k %s, the list of %d: %s" % [size, k,
				pane.listed().size(), pane.get_rect()])
			for index in [0, pane.listed()[-1]]:
				pane.show_clue(index)
				await _frames(4)
				assert_true(room.encloses(pane.get_rect()), "%s at k %s, page %d: %s" % [size, k, index,
					pane.get_rect()])
			pane.free()


# ------------------------------------------------ the world's free area --

const SAVES := "user://adventure_tests_pc_w7_clues"


func _world(size: Vector2i) -> WorldScreen:
	AdventurePlayer.saves_folder = SAVES
	viewport.size = size
	var setup := AdventureSetup.new()
	setup.player_name = "Seeker"
	setup.color = "blue"
	setup.difficulty = 1
	setup.walker = "female"
	setup.seed_text = "5150"
	var screen := load("res://game/adventure/world/world_screen.tscn").instantiate() as WorldScreen
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames()
	for index in 15:
		var slot: Dictionary = screen.world.encounters[index]
		slot["clues"] = 7 if index < 5 or WorldClues.holds_cards(slot) else 0
	return screen


func _drop_saves() -> void:
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


## What the pane must keep clear of on [param screen]: the panel's band (its
## bar and the name), the message line beside it, and the small map.
func _clear_of(screen: WorldScreen, pane: Control, what: String, map_too: bool) -> void:
	var hud := screen.hud
	var room := Rect2(Vector2.ZERO, Vector2(viewport.size))
	var rect := pane.get_global_rect()
	assert_true(room.encloses(rect), "%s: %s on the window %s" % [what, rect, room])
	var band := (hud.find_child("Top", false, false) as Control).get_global_rect()
	assert_false(rect.intersects(band), "%s: %s clear of the panel %s" % [what, rect, band])
	var notice := hud.find_child("Notice", false, false) as Control
	if notice.visible:
		assert_false(rect.intersects(notice.get_global_rect()),
			"%s: %s clear of the message line %s (free %s, region %s, band %s)" % [what, rect,
				notice.get_global_rect(), (pane as StagePane).free_rect(), (pane as StagePane).region(), band])
	if map_too and hud.minimap_shown():
		assert_false(rect.intersects(hud.minimap.get_global_rect()),
			"%s: %s clear of the small map %s" % [what, rect, hud.minimap.get_global_rect()])


func test_in_the_world_the_list_and_the_page_keep_clear_of_the_panel_and_the_small_map() -> void:
	for size in [Vector2i(1280, 800), Vector2i(800, 600)]:
		var screen := await _world(size)
		for at_bottom in [false, true]:
			screen.hud.place_bar(at_bottom, false)
			# The panel laid out where it now stands before the line is said
			# beside it (said in the same frame, it stands where the bar was).
			await _frames()
			screen.hud.say("Arzakon's Portal opened in the middle of Shandalar, south of Celestine Spire")
			await _frames()
			for k in [1.0, WorldHud.BIG]:
				var pane := CluesPane.make(screen.player)
				pane.k = k
				screen.add_child(pane)
				PaneStyle.centre(pane)
				await _frames(4)
				var what := "%s, panel %s, k %s" % [size, "below" if at_bottom else "above", k]
				# The list of fifteen is too wide to stand beside the small map
				# in a window of 800: there it may cover the map, never the panel.
				_clear_of(screen, pane, what + ", the list", size.x >= 1280)
				for index in [0, pane.listed()[-1]]:
					pane.show_clue(index)
					await _frames(4)
					_clear_of(screen, pane, what + ", page %d" % index, true)
					assert_true(pane.factor() >= StagePane.LEAST - 0.001, "the page shrinks, never under the least")
				pane.queue_free()
				await _frames()
		screen.queue_free()
		await _frames()
	_drop_saves()

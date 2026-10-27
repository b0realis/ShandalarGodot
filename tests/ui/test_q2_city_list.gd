extends GutTest
## THE CITY LIST'S NEW PIECES (the quick world package, 2026-10-27, H4 and
## H5): the castles the hero has stood before, listed with their wizard,
## beaten or not, and the attempts at them [ours: the owner's "Yes, list
## castles" — 1997's castle rows were never reached]; and a row's step
## gliding as 1997's list slid, eight rows at a time jumping.

var list: CityListPane


## A world of [param towns] visited towns, then the five castles (sites
## after them, each on its castle slot's tile), none visited.
func _player(towns: int) -> AdventurePlayer:
	var world := ShandalarWorld.new()
	world.page.resize(ShandalarWorld.PAGE_WIDTH * ShandalarWorld.PAGE_HEIGHT)
	for i in towns:
		world.sites.append({"x": 2 + i, "y": 3, "type": ShandalarWorld.TOWN, "trade": 0,
			"status": TownStatus.VISITED})
	for c in 5:
		world.sites.append({"x": 40 + c, "y": 40, "type": ShandalarWorld.CASTLE, "trade": 0, "status": 0})
	for i in 15:
		world.encounters.append({"x": 40 + i if i < 5 else 60, "y": 40 if i < 5 else 60, "clues": 0,
			"cards": []})
	var player := AdventurePlayer.new()
	player.world = world
	return player


func _open(player: AdventurePlayer) -> CityListPane:
	list = CityListPane.new()
	list.player = player
	add_child_autofree(list)
	await get_tree().process_frame
	return list


func _words(pane: CityListPane) -> Array[String]:
	var out: Array[String] = []
	for line in pane.find_child("Rows", true, false).find_children("*", "Label", true, false):
		if not (line as Label).is_queued_for_deletion() and (line as Label).text != "":
			out.append((line as Label).text)
	return out


func test_a_castle_stood_before_is_listed_with_its_wizard_and_attempts() -> void:
	var player := _player(2)
	var world := player.world
	var black := 2
	var red := 2 + 3
	assert_eq(CityListPane.towns(world), [0, 1] as Array[int], "no castle stood before: towns alone")
	TownStatus.put(world, black, TownStatus.VISITED)
	TownStatus.put(world, red, TownStatus.VISITED)
	world.encounters[0]["entered"] = 2
	player.defeated_wizards.append("red")
	assert_eq(CityListPane.towns(world), [0, 1, black, red] as Array[int], "in slot order")
	await _open(player)
	assert_eq(list.shown().slice(2), ["Black Castle", "Red Castle"] as Array[String])
	var words := _words(list)
	assert_has(words, "Black Wizard", "his wizard")
	assert_has(words, "Attempts: 2", "the attempts there (the slot's entered)")
	assert_has(words, "Red Wizardess, beaten", "a beaten one says so")
	assert_has(words, "Attempts: 0")
	var row := list.find_child("Row_%d" % red, true, false)
	var name := row.find_children("*", "Label", true, false)[0] as Label
	assert_eq(name.text, "Red\nCastle", "the castle's name in two lines")
	assert_eq(name.get_theme_color("font_color"), CityListPane.RULER_INKS[3], "in its wizard's ink")


func test_a_row_s_step_glides_and_a_page_jumps() -> void:
	await _open(_player(14))
	var step: float = CityListPane.ROW_HEIGHT * float(list.get("_scale"))
	list.scroll(1)
	assert_eq(list.top, 1, "a row down")
	assert_almost_eq(list.slide_offset(), step, 0.01, "the rows start where they stood")
	var leaving := list.get("_leaving") as Control
	assert_not_null(leaving, "the row leaving is drawn as it goes")
	assert_eq((leaving.find_children("*", "Label", true, false)[0] as Label).text, "Amanaxis\nTower",
		"the old top row, above the window")
	await get_tree().create_timer(CityListPane.SLIDE + 0.1).timeout
	assert_almost_eq(list.slide_offset(), 0.0, 0.01, "and come to rest")
	await get_tree().process_frame
	assert_false(is_instance_valid(leaving), "the row that left is gone")
	assert_eq(list.shown().size(), CityListPane.ROWS)
	list.scroll(-1)
	assert_almost_eq(list.slide_offset(), -step, 0.01, "up: from a row above")
	list.scroll(8)
	assert_eq(list.top, 5, "a page: as far as the list goes")
	assert_almost_eq(list.slide_offset(), 0.0, 0.01, "a page jumps, as 1997's did")
	list.instant = true
	list.scroll(-1)
	assert_almost_eq(list.slide_offset(), 0.0, 0.01, "instant: no glide")


func test_the_list_is_clipped_to_its_nine_rows() -> void:
	await _open(_player(3))
	var window := list.find_child("List", true, false) as Control
	assert_true(window.clip_contents)
	var scale: float = list.get("_scale")
	assert_eq(window.size, Vector2(CityListPane.SCREEN.x, CityListPane.ROWS * CityListPane.ROW_HEIGHT) * scale)
	assert_eq(window.position, Vector2(0, CityListPane.ROW_TOP) * scale)


## 1997's row panel (`Cinfopce.pic`) lies under every row and slides with it.
func test_each_row_lies_on_1997_s_row_panel() -> void:
	var kept := GameSkin._texture_cache.duplicate()
	var sheet := Image.create(562, 68, false, Image.FORMAT_RGB8)
	sheet.fill(Color8(44, 44, 44))
	GameSkin._texture_cache["city_list_row"] = ImageTexture.create_from_image(sheet)
	await _open(_player(3))
	var row := list.find_child("Row_1", true, false) as Control
	var panel := row.find_child("Panel", false, false) as TextureRect
	assert_not_null(panel, "the panel under the row")
	assert_eq((panel.texture as AtlasTexture).region, CityListPane.ROW_PANEL, "the empty row, 26 down")
	var scale: float = list.get("_scale")
	assert_eq(panel.position, Vector2(CityListPane.ROW_LEFT, CityListPane.ROW_TOP + CityListPane.ROW_HEIGHT) * scale)
	assert_eq(panel.size, Vector2(561, 42) * scale)
	GameSkin._texture_cache = kept
	list.queue_free()
	GameSkin._texture_cache["city_list_row"] = null
	await _open(_player(3))
	assert_null((list.find_child("Row_1", true, false) as Control).find_child("Panel", false, false),
		"without the picture, the ground's own rows")
	GameSkin._texture_cache = kept


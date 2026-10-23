extends GutTest
## THE WORLD'S PART A ON SCREEN (2026-10-23): the wise man's room and the
## town's quest ([WiseManPane]), a quest completed on arrival, the World
## Magic seller as a town is left ([WorldMagicPane]), the city list (F3,
## [CityListPane]), the map's three maps and the journal walked on it
## ([WorldMap]), the ten save slots ([SaveSlotsPane]), a creature's deck
## seen ([CardListPane]) and the soundscape's rules ([WorldSoundscape]).

var screen: WorldScreen
const SAVES := "user://adventure_tests_part_a"


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	screen = load("res://game/adventure/world/world_screen.tscn").instantiate()
	screen.record = setup.resolve({})
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _first(kind: int) -> int:
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == kind:
			return slot
	return -1


func _tile(slot: int) -> Vector2i:
	return Vector2i(int(screen.world.sites[slot]["x"]), int(screen.world.sites[slot]["y"]))


func _button(node: Node, button_name: String) -> Button:
	return node.find_child(button_name, true, false) as Button


func test_the_wise_man_and_the_town_s_quest() -> void:
	var player := screen.player
	var village := _first(ShandalarWorld.VILLAGE)
	var destination := -1
	for slot in screen.world.sites.size():
		if TownStatus.is_town(screen.world, slot) and not TownStatus.linked(screen.world, slot):
			destination = slot
			break
	# The town's quest is offered: Begin a Quest.
	screen.visit(_tile(village))
	screen._left_place("")
	await get_tree().process_frame
	player.quest_offer = {"type": Quests.LETTER_AMULET, "destination": destination, "color": 2, "at": village}
	var pane := screen.visit(_tile(village), false)
	var begin := _button(pane, "Choice_quest")
	assert_not_null(begin, "Begin a Quest")
	begin.pressed.emit()
	await get_tree().process_frame
	var wise := screen.find_child("WiseManPane", true, false) as WiseManPane
	assert_not_null(wise, "the wise man's room")
	assert_eq(wise.picture_key(), "visit_wiseman")
	assert_string_contains(wise.words(), "He will reward you with a blue amulet.")
	_button(wise, "Choice_accept").pressed.emit()
	assert_eq(wise.words(), "You have 4 days to complete the quest.")
	assert_true(Quests.has_quest(player))
	_button(wise, "Choice_leave").pressed.emit()
	await get_tree().process_frame
	assert_not_null(screen.find_child("VisitPane", true, false), "back in the town")
	screen._left_place("")
	await get_tree().process_frame
	var seller := screen.find_child("WorldMagicPane", true, false) as WorldMagicPane
	if seller != null:
		seller.done.emit()
		await get_tree().process_frame
	# The quest done on arrival: the keeper's words, the amulet.
	var blue := int(player.amulets["blue"])
	var town_pane := screen.visit(_tile(destination))
	assert_string_contains(town_pane.words(), "The keeper is pleased to receive his brother's letter.")
	assert_eq(int(player.amulets["blue"]), blue + 1)
	assert_false(Quests.has_quest(player))
	assert_eq(String(player.journal[-1]["text"]), "Completed quest at %s" % WorldNames.site_name(screen.world, destination))
	assert_true(TownStatus.visited(screen.world, destination), "visited: on the city list")


func test_the_world_magic_seller_as_a_town_is_left() -> void:
	var town := _first(ShandalarWorld.TOWN)
	screen.visit(_tile(town))
	screen._left_place("")
	await get_tree().process_frame
	var seller := screen.find_child("WorldMagicPane", true, false) as WorldMagicPane
	assert_not_null(seller, "the nearest World Magic not owned")
	assert_true(screen.visiting(), "the world waits")
	seller.done.emit()
	await get_tree().process_frame
	assert_false(screen.visiting())
	assert_eq(screen.player.last_town, town)
	assert_true(FileAccess.file_exists(screen.player.save_path()), "autosaved as the town was left")


func test_the_city_list() -> void:
	var player := screen.player
	var towns: Array[int] = []
	for slot in screen.world.sites.size():
		if TownStatus.is_town(screen.world, slot):
			TownStatus.put(screen.world, slot, TownStatus.VISITED)
			towns.append(slot)
	var event := InputEventKey.new()
	event.keycode = KEY_F3
	event.pressed = true
	screen._unhandled_input(event)
	var list := screen.find_child("CityList", true, false) as CityListPane
	assert_not_null(list, "F3: the city list")
	assert_eq(list.shown().size(), mini(9, towns.size()), "nine rows at a time")
	assert_eq(list.shown()[0], WorldNames.site_name(screen.world, towns[0]), "in slot order")
	if towns.size() > 9:
		list.scroll(1)
		assert_eq(list.shown()[0], WorldNames.site_name(screen.world, towns[1]), "a row down")
	(list.find_child("Done", true, false) as BaseButton).pressed.emit()
	await get_tree().process_frame
	assert_false(screen.city_list_shown())


func test_the_map_s_three_maps_and_the_journal() -> void:
	var map := screen.find_child("Map", true, false) as WorldMap
	screen.toggle_map()
	assert_true(map.visible)
	assert_eq(map.mode, WorldMap.Mode.MAIN)
	assert_true(map.key(KEY_I))
	assert_eq(map.mode, WorldMap.Mode.INFO)
	assert_true(map.key(KEY_P))
	assert_eq(map.mode, WorldMap.Mode.PLAIN)
	assert_true((map.find_child("Map_MainMap", true, false) as Control).visible, "the other two maps' buttons")
	assert_false((map.find_child("Map_PlainMap", true, false) as Control).visible)
	assert_eq(WorldMap.tile_look(Vector2i(1, 2)), 2, "the primes: P[3 mod 6] · P[2 mod 6] = 7 · 5, mod 3")
	map.key(KEY_D)
	assert_false(map.visible, "Done")
	screen.player.log_event("visit", "Visited Somewhere")
	screen.player.log_event("magic", "SPEED!")
	screen.walk_journal()
	assert_true(map.visible)
	assert_eq(map.mode, WorldMap.Mode.JOURNAL)
	assert_eq(map.journal_index, screen.player.journal.size() - 1, "from its last line")
	map.step_journal(-1)
	assert_eq(map.journal_index, screen.player.journal.size() - 2)


func test_the_ten_save_slots() -> void:
	var pane := screen.save_now()
	assert_not_null(pane)
	pane.edit(5)
	await get_tree().process_frame
	var field := pane.find_child("SlotName", true, false) as LineEdit
	assert_not_null(field, "the slot's name to type")
	field.text = "Before the Witch"
	field.text_submitted.emit(field.text)
	assert_string_contains(pane.note(), "Saved to slot 5: Before the Witch.")
	assert_eq(String(SaveSlots.slots_of(screen.player.adventure_id)[4]["name"]), "Before the Witch")


func test_a_creature_s_deck_seen() -> void:
	var player := screen.player
	var hero := player.tile()
	player.monsters = [{"slot": 1, "kind": "lair", "color": 1, "x": hero.x * 32 + 16, "y": (hero.y + 1) * 32 + 16}]
	var made := LairEvent.begin(player, player.monsters[0])
	made["event"] = LairEvent.GHOST
	made["name"] = LairEvent.NAMES[LairEvent.GHOST]
	made["reward"] = ""
	player.amulets["black"] = 2
	var pane := LairPane.new()
	pane.player = player
	pane.event = made
	pane.place = LairPane.place_of(made)
	screen._visit = pane
	screen.add_child(pane)
	pane.deck_wanted.connect(screen.show_creature_deck)
	await get_tree().process_frame
	_button(pane, "Choice_ghost").pressed.emit()
	assert_string_contains(pane.words(), "Whose deck would you like to see?")
	_button(pane, "Choice_deck_1").pressed.emit()
	await get_tree().process_frame
	var list := screen.find_child("CardList", true, false) as CardListPane
	assert_not_null(list, "the Witch's deck")
	assert_true(list.names().has("Swamp"))
	assert_false(pane.visible, "over the lair")
	list.done.emit()
	await get_tree().process_frame
	assert_true(pane.visible, "the lair again")


func test_the_soundscape_s_rules() -> void:
	assert_almost_eq(WorldSoundscape.db(100), 0.0, 0.001)
	assert_almost_eq(WorldSoundscape.db(75), -10.0, 0.001)
	assert_eq(WorldSoundscape.step_key(1, 2), "sfx_step_black_left")
	assert_eq(WorldSoundscape.step_key(5, 3), "sfx_step_white_right")
	assert_eq(WorldSoundscape.call_key(3, 1), "sfx_call_green_land_1")
	var village := _first(ShandalarWorld.VILLAGE)
	assert_eq(WorldSoundscape.tune_key(screen.world, village), "music_location_0", "every village LocMus0")
	var town := _first(ShandalarWorld.TOWN)
	var k := town % 20
	assert_eq(WorldSoundscape.tune_key(screen.world, town),
		"music_temple" if k == 19 else "music_location_%d" % (k + 1), "a town by its slot")
	var castle := _first(ShandalarWorld.CASTLE)
	assert_eq(WorldSoundscape.tune_key(screen.world, castle),
		"music_castle_" + AdventurePlayer.COLORS[WorldNames.castle_of_site(screen.world, castle)])
	var near := WorldSoundscape.nearest(screen.world, _tile(town) * 32 + Vector2i(16, 16))
	assert_eq([near["slot"], near["percent"]], [town, 100], "in its middle: full voice")
	assert_eq(WorldSoundscape.card_key("Grizzly Bears"), "sfx_summon")
	assert_eq(WorldSoundscape.card_key("Swamp"), "sfx_land_black")

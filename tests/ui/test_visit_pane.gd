extends GutTest
## A PLACE VISITED (2026-10-23): the owner's *"upon visiting that location
## an original graphic is displayed in a central pane in modern gui with
## original assets and feel"* — [VisitPane] shows what the 1.3 game showed
## on arrival (`VisitTownSlot`, the castles, the lairs): the picture, the
## place's name, the 1997 words and choices; the world screen opens it
## when a walk ends on the place.

var screen: WorldScreen
const SAVES := "user://adventure_tests_visit"


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


## The first site of [param kind], its slot.
func _site(kind: int) -> int:
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == kind:
			return slot
	return -1


func _tile(slot: int) -> Vector2i:
	var site: Dictionary = screen.world.sites[slot]
	return Vector2i(int(site["x"]), int(site["y"]))


func test_a_town_village_or_city_as_1997_showed_it() -> void:
	var player := screen.player
	for kind in [ShandalarWorld.VILLAGE, ShandalarWorld.TOWN, ShandalarWorld.CITY]:
		var slot := _site(kind)
		var place := VisitPane.describe(player, _tile(slot))
		assert_eq(place["kind"], VisitPane.KINDS[kind - 1])
		assert_eq(place["name"], WorldNames.site_name(screen.world, slot))
		assert_eq(place["picture"], "visit_village" if kind == ShandalarWorld.VILLAGE else "visit_city",
			"Village.pic for a village, City.pic for the rest (GET_TOWN_PIC)")
		var words: Array = place["actions"].map(func(action: Array) -> String: return action[1])
		assert_eq(words, ["Buy Cards", "Edit deck/Sell cards", "Speak to Wise Man",
			"Buy 10 food for %d gold" % ((kind + 2) * 5), "Leave the village"], "@CITYSCREEN_BUTTONS")
	assert_eq(VisitPane.describe(player, Vector2i(-5, -5)), {}, "nothing there")


func test_a_ruled_town_a_castle_a_lair_and_a_dungeon() -> void:
	var player := screen.player
	var town := _site(ShandalarWorld.TOWN)
	screen.world.sites[town]["status"] = int(screen.world.sites[town]["status"]) | (4 << 8)
	var ruled := VisitPane.describe(player, _tile(town))
	assert_eq(ruled["kind"], "ruled")
	assert_eq(ruled["lines"][0], "This place is ruled by the Red Wizardess.")
	var castle_slot := _site(ShandalarWorld.CASTLE)
	var castle := VisitPane.describe(player, _tile(castle_slot))
	var index := WorldNames.castle_of_site(screen.world, castle_slot)
	assert_eq(castle["kind"], "castle")
	assert_eq(castle["picture"], "visit_castle_" + AdventurePlayer.COLORS[index])
	assert_eq(castle["lines"][0], "Who dares to challenge the Mighty %s?" % WorldNames.WIZARDS[index])
	player.defeated_wizards.append(AdventurePlayer.COLORS[index])
	assert_eq(VisitPane.describe(player, _tile(castle_slot))["kind"], "fallen", "a beaten wizard's castle")
	player.monsters = [{"kind": "lair", "slot": 0, "color": 2, "x": 3 * 32 + 16, "y": 4 * 32 + 16}]
	player.position = Vector2i(10, 10) * 32 + Vector2i(16, 16)
	assert_eq(VisitPane.describe(player, Vector2i(3, 4)), {}, "a lair is seen only from beside it")
	player.position = Vector2i(4, 4) * 32 + Vector2i(16, 16)
	var lair := VisitPane.describe(player, Vector2i(3, 4))
	assert_eq(lair["picture"], "visit_lair_blue", "the blue lair: the sunken ship")
	assert_eq([lair["name"], lair["subtitle"]], ["Lair", "Blue lair"], "its tip")
	var dungeon: Dictionary = screen.world.encounters[5]
	var at := Vector2i(int(dungeon["x"]), int(dungeon["y"]))
	assert_eq(VisitPane.describe(player, at), {}, "a dungeon unknown is not entered")
	dungeon["clues"] = WorldClues.LOCATION
	assert_eq(VisitPane.describe(player, at)["kind"], "dungeon", "known, it is")


func test_the_walk_ends_in_a_town_and_its_pane_opens() -> void:
	var player := screen.player
	var slot := _site(ShandalarWorld.TOWN)
	var town := _tile(slot)
	var beside := town
	for d in range(1, 9):
		var near := town + Vector2i(ShandalarWorld.DX[d], ShandalarWorld.DY[d])
		if screen.world.is_land(near.x, near.y) and VisitPane.site_slot(screen.world, near) < 0:
			beside = near
			break
	player.position = beside * 32 + Vector2i(16, 16)
	# No amulet: the town's trade is not offered, the wise man stands there.
	for hue in AdventurePlayer.COLORS:
		player.amulets[hue] = 0
	player.monsters = [] as Array
	screen.show_player(player)
	assert_true(screen.walk_to_tile(town))
	for i in 20:
		screen.advance(0.6)
		if screen.visiting():
			break
	assert_true(screen.visiting(), "arrived: the town's pane")
	var pane := screen.find_child("VisitPane", true, false) as VisitPane
	assert_eq((pane.find_child("PlaceName", true, false) as Label).text, WorldNames.site_name(screen.world, slot))
	assert_eq(pane.picture_key(), "visit_city")
	assert_eq(String(player.journal[-1]["text"]), "Visited %s" % WorldNames.site_name(screen.world, slot),
		"the 1997 journal line")
	var ticked := player.monster_timer
	screen._process(1.0)
	assert_eq(player.monster_timer, ticked, "the world waits")
	# Buy 10 food.
	var gold := player.gold
	var food := player.food
	(pane.find_child("Choice_food", true, false) as Button).pressed.emit()
	assert_eq([player.gold, player.food], [gold - 20, food + 10], "10 food for (2 + 2) × 5 gold in a town")
	assert_string_contains(pane.note(), "You buy 10 food")
	assert_false((pane.find_child("Choice_buy", true, false) as Button).disabled, "the card shop is open")
	var fifth := pane.find_child("Choice_wiseman", true, false) as Button
	if fifth == null:
		fifth = pane.find_child("Choice_quest", true, false) as Button
	assert_false(fifth.disabled, "the wise man, or the town's quest")
	# Escape leaves — the World Magic seller first, as a town is left; a
	# click on the town the hero stands on comes back.
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	pane._unhandled_input(escape)
	await get_tree().process_frame
	var seller := screen.find_child("WorldMagicPane", true, false) as WorldMagicPane
	if seller != null:
		seller.done.emit()
		await get_tree().process_frame
	assert_false(screen.visiting(), "left")
	assert_true(screen.walk_to_tile(town), "a click on it")
	assert_true(screen.visiting(), "visits again")
	# Edit deck/Sell cards: the deck builder.
	pane = screen.find_child("VisitPane", true, false) as VisitPane
	(pane.find_child("Choice_deck", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	assert_false(screen.visiting())
	assert_true(screen.building(), "the deck, from the town")

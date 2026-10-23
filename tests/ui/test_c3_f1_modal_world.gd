extends GutTest
## A PANE HOLDS THE WORLD SCREEN, AND SO DOES THE MAP (adventure campaign
## 2026-10-23, the lead's rulings A and B from 1997's modal town menu;
## findings h1-2, h2-3, h3-2, h6-3, h2-4, h3-3, h3-9, h3-10, h3-14, h2-5,
## h6-6). The floating panel stayed live under every pane: Leap of Fate cast
## from its icon moved the hero thirty tiles with the town's pane open, its
## Map opened the map under the pane, a click on the small map queued a walk
## the hero took after leaving, Hero, Clues and Help opened behind the pane.
## The map let the world's keys through (F1 opened the deck builder over it,
## 2 cast under it, N and H worked in the hidden panel). The second click of
## a double click on a closing pane's Done walked the hero. The place's name
## by the pointer named the place that WAS under it while the land moved,
## and stayed under the panes that F3, Ctrl+S and the World Magic seller
## opened. The small map's name floated by the panel, far from it. Every Leap
## of Fate key read the whole screen back before the cast was even checked.
## The panel's numbers stood still while food was bought in a town.
##
## Every click and key here is a real one, pushed through the viewport.

## A world screen that counts what it would otherwise do for real: the walks
## asked, the pictures taken for the reveal, the game's end.
class Probe extends WorldScreen:
	var walked: Array[Vector2i] = []
	var pictures := 0
	var ends := 0

	func walk_to_tile(tile: Vector2i) -> bool:
		walked.append(tile)
		return super(tile)

	func _picture_for_reveal() -> Texture2D:
		pictures += 1
		return null

	func _end_process() -> void:
		ends += 1


const SAVES := "user://adventure_tests_c3_f1_modal"
## The settings the world screen's options and panes write, put back after
## each test.
const WORLD_SETTINGS: Array[String] = [WorldHud.BAR_SETTING, WorldHud.MINIMAP_SETTING,
	WorldHud.QUEST_SETTING, WorldHud.GUIDES_SETTING, WorldHud.PACE_SETTING, WorldHud.BIG_SETTING,
	WorldHud.PLACES_SETTING, WorldHud.READER_SETTING,
	"world_pane_HeroPanel", "world_pane_HelpPanel", "world_pane_CluesPanel",
	"world_pane_QuestPane", "world_pane_Minimap"]

var viewport: SubViewport
var screen: Probe


func before_each() -> void:
	for key in WORLD_SETTINGS:
		Settings.clear_value(key)
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	# The pointer is in this viewport, as a container would say: without it
	# a motion pushed here reaches no control.
	viewport.notification(Viewport.NOTIFICATION_VP_MOUSE_ENTER)
	screen = Probe.new()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)
	# Nothing roams near enough to be walked into while a test runs.
	screen.player.monsters = [] as Array


func after_each() -> void:
	for key in WORLD_SETTINGS:
		Settings.clear_value(key)
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


## The shield's moment after a pane closes, waited out.
func _after_pane() -> void:
	await get_tree().create_timer(WorldScreen.AFTER_PANE_MS / 1000.0 + 0.1).timeout
	await _frames(2)


func _move(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	viewport.push_input(motion, true)


func _button(at: Vector2, pressed: bool, double := false) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = pressed
	click.double_click = double and pressed
	click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	click.position = at
	click.global_position = at
	viewport.push_input(click, true)


## A real left click at [param at], through the viewport.
func _click(at: Vector2) -> void:
	_move(at)
	_button(at, true)
	_button(at, false)
	await _frames(2)


func _click_node(node: Control) -> void:
	await _click(node.get_global_rect().get_center())


## A real key, pressed and let go, through the viewport.
func _key(code: Key, ctrl := false) -> void:
	var press := InputEventKey.new()
	press.keycode = code
	press.physical_keycode = code
	press.ctrl_pressed = ctrl
	press.pressed = true
	viewport.push_input(press, true)
	var up := press.duplicate() as InputEventKey
	up.pressed = false
	viewport.push_input(up, true)
	await _frames(2)


func _first(kind: int) -> int:
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == kind:
			return slot
	return -1


func _tile(slot: int) -> Vector2i:
	return Vector2i(int(screen.world.sites[slot]["x"]), int(screen.world.sites[slot]["y"]))


## Where tile [param tile]'s middle stands on the screen.
func _point_of(tile: Vector2i) -> Vector2:
	return screen.view.feet() + screen.view.project(Vector2(tile * 32 + Vector2i(16, 16))) * screen.view.zoom


func _map() -> WorldMap:
	return screen.find_child("Map", true, false) as WorldMap


## Ruling A: while a town's pane is up the panel shows but does nothing, and
## no click reaches the world.
func test_a_place_s_pane_holds_the_world() -> void:
	var player := screen.player
	var hud := screen.hud
	player.world_magics.append("Leap of Fate")
	player.amulets["blue"] = 3
	var town := _first(ShandalarWorld.TOWN)
	var pane := screen.visit(_tile(town))
	await _frames()
	assert_true(screen.modal(), "the town's pane holds the screen")
	var at := player.position
	# The panel's parts, clicked: nothing.
	await _click_node(hud.buttons["Map"] as Control)
	assert_false(_map().visible, "no map under the town's pane")
	await _click_node(hud.buttons["Hero"] as Control)
	assert_false(hud.hero_shown(), "no hero's pane behind it")
	await _click_node(hud.buttons["Clues"] as Control)
	assert_false(hud.clues_shown(), "no clues behind it")
	await _click_node(hud.buttons["Help"] as Control)
	assert_false(hud.help_shown(), "no keys behind it")
	await _click_node(hud.buttons["Options"] as Control)
	assert_false(hud.options_shown(), "no options: no save, load or exit from them")
	await _click_node(hud.buttons["Deck"] as Control)
	assert_false(screen.building(), "no spellbook over it")
	var icon := hud.find_child("Magic_4", true, false) as Control
	if icon != null:
		await _click_node(icon)
		assert_eq(player.position, at, "Leap of Fate's icon casts nothing under the pane")
	await _click_node(hud.minimap.land())
	assert_eq(screen.walked, [] as Array[Vector2i], "a click on the small map queues no walk")
	await _click(Vector2(40, 400))
	assert_eq(screen.walked, [] as Array[Vector2i], "nor a click on the land beside the pane")
	assert_false(screen.walk.is_walking())
	# The keys: nothing either.
	for code in [KEY_2, KEY_M, KEY_F1, KEY_F3, KEY_F4, KEY_F5, KEY_H, KEY_N]:
		await _key(code)
	assert_eq(player.position, at, "2 casts nothing")
	assert_false(_map().visible)
	assert_true(hud.minimap_shown(), "N does not flip the small map")
	assert_false(hud.help_shown() or hud.hero_shown() or hud.clues_shown())
	# The handlers themselves refuse, however they are reached.
	assert_eq(screen.cast(2), {}, "no cast")
	assert_eq([player.position, int(player.amulets["blue"])], [at, 3], "nothing moved, nothing risked")
	screen.toggle_map()
	screen.walk_journal()
	assert_false(_map().visible, "no map, no journal on it")
	assert_null(screen.save_now(), "no save")
	assert_null(screen.show_city_list(), "no city list")
	assert_null(screen.open_load(), "no load")
	assert_null(screen.open_spellbook(), "no spellbook")
	screen.toggle_hero()
	hud.toggle_hero()
	screen.show_clues()
	hud.toggle_clues()
	hud.toggle_help()
	hud.toggle_options()
	assert_false(hud.hero_shown() or hud.clues_shown() or hud.help_shown() or hud.options_shown(),
		"the panel's panes stay shut")
	assert_false(screen.walk_to_tile(player.tile() + Vector2i(1, 0)), "no walk")
	screen.return_to_menu()
	assert_false(screen._leaving, "no return to the title from under the pane")
	screen.exit_game()
	assert_eq(screen.ends, 0, "no exit from under the pane")
	watch_signals(hud)
	hud._choose("Exit")
	hud._choose("Save")
	assert_signal_not_emitted(hud, "exit_pressed")
	assert_signal_not_emitted(hud, "save_pressed")
	assert_true(is_instance_valid(pane) and pane.visible, "the town's pane is still there")
	# The pane itself still answers.
	pane.choose("leave")
	await _frames()
	var seller := screen.find_child("WorldMagicPane", true, false) as WorldMagicPane
	if seller != null:
		seller.done.emit()
		await _frames()
	assert_false(screen.modal(), "left")
	assert_false(hud.resting, "the panel answers again")


## Finding h6-6: what a pane changes shows on the panel at once.
func test_the_panel_s_numbers_follow_what_a_pane_changes() -> void:
	var player := screen.player
	var pane := screen.visit(_tile(_first(ShandalarWorld.TOWN)))
	await _frames()
	player.gold = 500
	(pane.find_child("Choice_food", true, false) as Button).pressed.emit()
	await _frames(2)
	var food := screen.hud.find_child("Strip_food", true, false).find_child("Number", true, false) as Label
	var gold := screen.hud.find_child("Strip_gold", true, false).find_child("Number", true, false) as Label
	assert_eq(food.text, str(player.food), "the food bought, on the panel")
	assert_eq(gold.text, str(player.gold), "the gold paid, on the panel")


## Ruling B: while the map is up only its own keys, Escape and Ctrl+S act.
func test_the_map_holds_the_world() -> void:
	var player := screen.player
	var hud := screen.hud
	player.world_magics.append("Leap of Fate")
	player.amulets["blue"] = 3
	for slot in screen.world.sites.size():
		if TownStatus.is_town(screen.world, slot):
			TownStatus.put(screen.world, slot, TownStatus.VISITED)
	await _key(KEY_M)
	assert_true(_map().visible, "M: the map")
	var at := player.position
	for code in [KEY_F1, KEY_2, KEY_KP_2, KEY_1, KEY_3, KEY_F3, KEY_F4, KEY_F5, KEY_H, KEY_N, KEY_PLUS]:
		await _key(code)
	assert_false(screen.building(), "F1: no deck builder over the map")
	assert_eq(player.position, at, "2: no Leap of Fate under the map")
	assert_eq(int(player.amulets["blue"]), 3, "nothing risked")
	assert_false(screen.city_list_shown(), "F3: no city list (the map's own C has it)")
	assert_false(hud.clues_shown() or hud.hero_shown() or hud.help_shown(), "no pane in the hidden panel")
	assert_true(hud.minimap_shown(), "N: the small map's setting untouched")
	assert_true(bool(Settings.get_value(WorldHud.MINIMAP_SETTING, true)))
	assert_true(_map().visible, "the map stays up")
	assert_false(hud.visible, "the panel rests under it")
	# The map's own key: City Info.
	await _key(KEY_C)
	assert_true(screen.city_list_shown(), "C: the map's City Info")
	await _key(KEY_ESCAPE)
	assert_false(screen.city_list_shown())
	assert_true(_map().visible, "Escape closed the list, the map is up")
	# Ctrl+S saves over the map.
	await _key(KEY_S, true)
	var slots := screen.find_child("SaveSlots", true, false) as SaveSlotsPane
	assert_not_null(slots, "Ctrl+S: the ten slots over the map")
	slots.done.emit()
	await _frames()
	# A screen over the whole world gives the map back, not the panel over it.
	screen._cover_world(true)
	screen._cover_world(false)
	assert_false(hud.visible, "the panel stays under the map")
	assert_false(screen.guides.visible)
	# Escape closes the map.
	await _key(KEY_ESCAPE)
	assert_false(_map().visible, "Escape: the map closed")
	assert_false(screen._leaving, "and the world stays")
	assert_true(hud.visible)


## Finding h3-9: the second click of a double click on a closing pane's Done
## lands on the world under it — and walks no one.
func test_a_double_click_on_a_closing_pane_walks_no_one() -> void:
	var list := screen.show_city_list()
	await _frames()
	var at := (list.find_child("Done", true, false) as Control).get_global_rect().get_center()
	_move(at)
	_button(at, true)
	_button(at, false)
	await _frames(2)
	assert_false(screen.city_list_shown(), "the first click: Done")
	_button(at, true, true)
	_button(at, false)
	await _frames(2)
	assert_eq(screen.walked, [] as Array[Vector2i], "the second click walks no one")
	# The same for the World Magic seller's Done.
	var offer := WorldMagicShop.offer(screen.player, _first(ShandalarWorld.TOWN))
	if not offer.is_empty():
		await _after_pane()
		var seller := screen.open_magic_seller(offer)
		await _frames()
		var done := seller.find_child("Done", true, false) as Control
		if done == null:
			done = seller.find_child("Never", true, false) as Control
		at = done.get_global_rect().get_center()
		_move(at)
		_button(at, true)
		_button(at, false)
		await _frames(2)
		_button(at, true, true)
		_button(at, false)
		await _frames(2)
		assert_eq(screen.walked, [] as Array[Vector2i], "nor after the seller")
	# A moment later a click on the land is a walk again.
	await _after_pane()
	await _click(at)
	assert_eq(screen.walked.size(), 1, "a click a moment later walks")


## Finding h3-10: the place's name follows the land under a still pointer,
## and goes as a pane opens.
func test_the_place_s_name_follows_the_land_and_goes_under_a_pane() -> void:
	var hud := screen.hud
	var village := _first(ShandalarWorld.VILLAGE)
	var spot := _tile(village)
	screen.world.explore_around(spot)
	var called := WorldNames.site_name(screen.world, village)
	var show_it := func() -> void:
		screen.view.camera = Vector2(spot * 32 + Vector2i(16, 16))
		await _frames()
		_move(_point_of(spot))
		await _frames()
	await show_it.call()
	assert_eq(hud.place_shown(), called, "the village named by the pointer")
	# The land moves under the still pointer.
	screen.look(Vector2(0, 400))
	await _frames(2)
	assert_eq(hud.place_shown(), "", "looked away: the name goes with the land")
	screen.view.camera = Vector2(spot * 32 + Vector2i(16, 16))
	await _frames(2)
	assert_eq(hud.place_shown(), called, "looked back: named again, with no motion")
	screen.set_zoom(screen.view.zoom * 3.0)
	screen.view.camera += Vector2(0, 200)
	await _frames(2)
	assert_eq(hud.place_shown(), "", "zoomed away")
	# A pane opened by a key, the saves, the seller: the name goes.
	await show_it.call()
	await _key(KEY_F3)
	assert_true(screen.city_list_shown())
	assert_eq(hud.place_shown(), "", "F3: the name gone under the city list")
	await _key(KEY_ESCAPE)
	await _after_pane()
	await show_it.call()
	assert_eq(hud.place_shown(), called)
	await _key(KEY_S, true)
	assert_eq(hud.place_shown(), "", "Ctrl+S: gone under the saves")
	await _key(KEY_ESCAPE)
	await _after_pane()
	await show_it.call()
	assert_eq(hud.place_shown(), called)
	var offer := WorldMagicShop.offer(screen.player, _first(ShandalarWorld.TOWN))
	if not offer.is_empty():
		screen.open_magic_seller(offer)
		await _frames()
		assert_eq(hud.place_shown(), "", "gone under the World Magic seller")


## Finding h3-14: a part away from the panel names itself beside it.
func test_the_small_map_s_name_floats_beside_it() -> void:
	var hud := screen.hud
	await _frames(2)
	var land := hud.minimap.land()
	hud.show_tip(land)
	var tip := hud.find_child("Tip", true, false) as Control
	assert_true(tip.visible)
	assert_true(land.get_global_rect().grow(24.0).intersects(tip.get_global_rect()),
		"by the small map, not by the panel across the screen")
	assert_true(Rect2(Vector2.ZERO, hud.size).encloses(tip.get_global_rect()), "on the screen")
	# A part of the panel still names itself under the row.
	var gold := hud.find_child("Strip_gold", true, false) as Control
	hud.show_tip(gold)
	var bar := (hud.find_child("Bar", true, false) as Control).get_global_rect()
	assert_gte(tip.get_global_rect().position.y, bar.end.y, "under the row")


## Finding h2-5: the screen is read back for the reveal only when a cast
## will set the hero down elsewhere.
func test_the_screen_is_pictured_only_for_a_cast_that_moves_the_hero() -> void:
	var player := screen.player
	player.amulets["blue"] = 2
	player.amulets["white"] = 2
	screen.cast(2)
	assert_eq(screen.pictures, 0, "Leap of Fate not owned: no picture")
	player.world_magics.append("Sword of Resistance")
	screen.cast(5)
	assert_eq(screen.pictures, 0, "no town besieged: no picture")
	player.world_magics.append("Leap of Fate")
	player.amulets["blue"] = 0
	screen.cast(2)
	assert_eq(screen.pictures, 0, "no blue amulet: no picture")
	player.amulets["blue"] = 2
	var at := player.position
	var result := screen.cast(2)
	assert_true(result["moved"])
	assert_ne(player.position, at)
	assert_eq(screen.pictures, 1, "a leap: the old view pictured for the reveal")

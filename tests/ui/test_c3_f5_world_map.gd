extends GutTest
## THE MAP (F2), THE CITY LIST (F3) AND THE WORLD MAGIC SELLER, held to
## the adventure campaign's fixes (2026-10-23), each driven as the player
## drives it — keys and clicks pushed through the viewport:
##  - site slot 0 sells nothing: a town in slot 0 never shows a World
##    Magic for sale, though 0 is also what "sold nowhere" reads as
##    (1.3 `DrawCityInfoTownRow`, cityInfoScreen.c 756; mapScreen.c 736);
##  - an open, still map is not painted again every frame for the hero's
##    blinking square;
##  - M closes the Main Map, and brings the Main Map back from the others;
##  - Previous (or the wheel) on the journal's first line stays there;
##  - without the painted sheets the amulet counts keep their colors.

var screen: WorldScreen
const SAVES := "user://adventure_tests_c3_f5"


## A world screen for a red hero on the world of [param seed_text].
func _open(seed_text := "12345") -> void:
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = seed_text
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


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


## Key [param code] pressed and let go, through the viewport.
func _key(code: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	get_viewport().push_input(down)
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	get_viewport().push_input(up)


## A left click (or a wheel turn, [param button]) at [param at] (the
## viewport's own units), through the viewport.
func _click(at: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	get_viewport().push_input(motion, true)
	var press := InputEventMouseButton.new()
	press.button_index = button
	press.position = at
	press.global_position = at
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else 0
	get_viewport().push_input(press, true)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	release.button_mask = 0
	get_viewport().push_input(release, true)


func _map() -> WorldMap:
	return screen.find_child("Map", true, false) as WorldMap


## The words on the city list's rows.
func _row_words(list: CityListPane) -> Array[String]:
	var out: Array[String] = []
	for line in list.find_child("Rows", true, false).find_children("*", "Label", true, false):
		out.append((line as Label).text)
	return out


# ------------------------------------------------- slot 0 sells nothing --

func test_slot_0_sells_no_world_magic_on_the_city_list() -> void:
	# Seed 32676 puts a town in site slot 0 (Amanaxis Tower); the red
	# hero's own Staff of Thunder, and the two magics the generator seldom
	# places, read 0 — "sold nowhere".
	await _open("32676")
	var world := screen.world
	assert_true(TownStatus.is_town(world, 0), "slot 0 is a town in this world")
	assert_true(world.world_magic_sites.has(0), "and some World Magic is sold nowhere")
	var seller := -1
	var sold := -1
	for i in world.world_magic_sites.size():
		if world.world_magic_sites[i] > 0 and TownStatus.is_town(world, world.world_magic_sites[i]):
			seller = world.world_magic_sites[i]
			sold = i
			break
	for slot in world.sites.size():
		TownStatus.put(world, slot, TownStatus.VISITED, slot == 0 or slot == seller)
	_key(KEY_F3)
	await _frames(2)
	var list := screen.find_child("CityList", true, false) as CityListPane
	assert_not_null(list, "F3: the city list")
	assert_eq(list.shown(), [WorldNames.site_name(world, 0), WorldNames.site_name(world, seller)] as Array[String])
	var words := _row_words(list)
	var magics_shown: Array[String] = []
	for magic in AdventurePlayer.WORLD_MAGICS:
		if magic in words:
			magics_shown.append(magic)
	assert_eq(magics_shown, [AdventurePlayer.WORLD_MAGICS[sold]] as Array[String],
		"only the town that sells one shows it; slot 0 shows none")
	_key(KEY_ESCAPE)
	await _frames(2)
	assert_false(screen.city_list_shown())


# ------------------------------------------------- the map's repainting --

func test_an_open_still_map_is_not_painted_every_frame() -> void:
	await _open()
	var map := _map()
	screen.toggle_map()
	await _frames(3)
	var draws := [0]
	map.draw.connect(func() -> void: draws[0] += 1)
	var started := Time.get_ticks_msec()
	await _frames(20)
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	# The hero's square blinks every 0.33 s; nothing else changes.
	assert_lte(draws[0], int(seconds / 0.33) + 1, "%d paints in %.2f s" % [draws[0], seconds])


# ------------------------------------------------------------- the keys --

func test_m_closes_the_main_map_and_brings_it_back_from_the_others() -> void:
	await _open()
	var map := _map()
	_key(KEY_M)
	await _frames(1)
	assert_true(map.visible, "M: the map")
	assert_eq(map.mode, WorldMap.Mode.MAIN)
	_key(KEY_I)
	await _frames(1)
	assert_eq(map.mode, WorldMap.Mode.INFO)
	_key(KEY_M)
	await _frames(1)
	assert_true(map.visible, "M on the Info Map: back to the Main Map")
	assert_eq(map.mode, WorldMap.Mode.MAIN)
	_key(KEY_P)
	_key(KEY_M)
	await _frames(1)
	assert_true(map.visible, "M on the Plain Map: back to the Main Map")
	assert_eq(map.mode, WorldMap.Mode.MAIN)
	_key(KEY_M)
	await _frames(1)
	assert_false(map.visible, "M on the Main Map closes it")


# ------------------------------------------------------ the journal walk --

func test_previous_and_the_wheel_stop_at_the_journal_s_first_line() -> void:
	await _open()
	var player := screen.player
	player.journal.clear()
	for words in ["Visited Somewhere", "SPEED!", "JUMP!"]:
		player.log_event("magic", words)
	screen.walk_journal()
	await _frames(1)
	var map := _map()
	assert_eq(map.journal_index, 2, "from the last line")
	var previous := map.find_child("JournalPrevious", true, false) as Control
	var next := map.find_child("JournalNext", true, false) as Control
	assert_not_null(previous)
	for i in 3:
		_click(previous.get_global_rect().get_center())
		await _frames(1)
	assert_eq(map.journal_index, 0, "Previous on the first line stays there")
	_click(map.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_UP)
	await _frames(1)
	assert_eq(map.journal_index, 0, "and so does the wheel")
	for i in 3:
		_click(next.get_global_rect().get_center())
		await _frames(1)
	assert_eq(map.journal_index, 2, "Next on the last line stays there")


func test_slot_0_sells_no_world_magic_on_the_info_map() -> void:
	await _open("32676")
	var map := _map()
	assert_eq(map.info_words(0).size(), 1, "slot 0: what it trades, no World Magic")
	for i in screen.world.world_magic_sites.size():
		var slot := screen.world.world_magic_sites[i]
		if slot > 0 and TownStatus.is_town(screen.world, slot):
			assert_eq(map.info_words(slot)[-1], AdventurePlayer.WORLD_MAGICS[i], "its seller shows it")


func test_the_hero_s_square_blinks_on_their_tile() -> void:
	await _open()
	var map := _map()
	screen.toggle_map()
	await _frames(1)
	var mark := map.find_child("HeroMark", true, false) as Control
	assert_not_null(mark, "a small node of its own")
	var at := map.stage()
	assert_eq(mark.position, at * (WorldMap.tile_point(screen.player.tile()) - Vector2(1, 1)))
	assert_eq(mark.size, Vector2(4, 4) * at.get_scale())
	var lit := mark.visible
	map._process(WorldMap.BLINK)
	assert_ne(mark.visible, lit, "a blink later it is the other way")
	map._process(WorldMap.BLINK)
	assert_eq(mark.visible, lit, "and back")
	map.hero_tile = screen.player.tile() + Vector2i(2, 0)
	assert_eq(mark.position, at * (WorldMap.tile_point(map.hero_tile) - Vector2(1, 1)), "it follows the hero")


func test_the_map_s_buttons_are_cut_clipped() -> void:
	await _open()
	var done := _map().find_child("Map_Done", true, false)
	if done is TextureButton:
		assert_true(((done as TextureButton).texture_normal as AtlasTexture).filter_clip, "no purple frame")
	else:
		pass_test("without the 1997 skin the buttons are words")


# ---------------------------------------- the amulets without the sheets --

func test_without_the_sheets_the_amulet_counts_keep_their_colors() -> void:
	var kept := GameSkin._texture_cache.duplicate()
	for key in ["map_buttons", "city_list", "city_list_buttons", "world_amulets"]:
		GameSkin._texture_cache[key] = null
	await _open()
	var map := _map()
	assert_eq(map.amulet_discs().size(), 5, "a colored square beside each count")
	_key(KEY_F3)
	await _frames(1)
	var list := screen.find_child("CityList", true, false) as CityListPane
	assert_not_null(list)
	for i in 5:
		var disc := list.find_child("Amulet_" + AdventurePlayer.COLORS[i], true, false) as ColorRect
		assert_not_null(disc, AdventurePlayer.COLORS[i])
		if disc != null:
			assert_eq(disc.color, WorldArt.AMULET_INKS[i])
	GameSkin._texture_cache = kept
	assert_eq(_map().amulet_discs().size(), 0 if GameSkin.texture("map_buttons") != null else 5,
		"with the panel its painted stones show them")


# --------------------------------------------------- the World Magic seller --

func test_the_world_magic_seller_closes_once() -> void:
	await _open()
	var town := -1
	for slot in screen.world.sites.size():
		if WorldMagicShop.asks_at(screen.world, slot):
			town = slot
			break
	var pane := screen.open_magic_seller(WorldMagicShop.offer(screen.player, town))
	var closed := [0]
	pane.done.connect(func() -> void: closed[0] += 1)
	_key(KEY_ESCAPE)
	_key(KEY_ESCAPE)
	var button := pane.find_child("Done", true, false) as BaseButton
	if button == null:
		button = pane.find_child("Never", true, false) as BaseButton
	button.pressed.emit()
	assert_eq(closed[0], 1, "Escape twice and a click: the town is left once")
	await _frames(2)
	assert_false(is_instance_valid(pane) and pane.is_inside_tree(), "the pane is gone")

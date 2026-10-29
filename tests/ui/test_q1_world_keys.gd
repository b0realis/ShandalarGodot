extends GutTest
## THE WORLD'S KEYS (the quick world package, 2026-10-27, step 5 — item
## C; 1997's `UpdateAdventureWorldInputAndMovement`, adventure_input.c
## 304–503): F6 the hero's pane on its Wizards tab, F5 its Hero tab, L the
## saved adventures, Escape or Q with nothing open "Ready to Quit?" (the
## owner's ruling C-1: Yes saves and leaves, No or Escape stays), Space
## stops the walk, a right click on the world opens the options (C-4), the
## letters W A S D look no more while the hero's pane is open (C-3), and
## the help and the options say all of it.

const SAVES := "user://adventure_tests_q1_world_keys"


class Probe extends WorldScreen:
	var saves := 0
	var titles := 0

	func _write_autosave() -> String:
		saves += 1
		return super()

	func _go_to_title() -> void:
		titles += 1
		_leaving = true


var viewport: SubViewport
var screen: Probe


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Inniscor"
	setup.color = "green"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	screen = Probe.new()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)
	screen.set_process(false)
	screen.player.food = 50
	_quiet_slots()
	screen.saves = 0


func after_each() -> void:
	Input.action_release("ui_cancel")
	for code in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP]:
		var up := InputEventKey.new()
		up.keycode = code
		up.physical_keycode = code
		up.pressed = false
		Input.parse_input_event(up)
	Input.flush_buffered_events()
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


## Every roaming slot held by a lair off the hero's way (nothing refills,
## nothing comes); no besieger.
func _quiet_slots() -> void:
	var player := screen.player
	player.monsters = [] as Array
	for slot in WorldLairs.SLOTS:
		var tile := player.tile() + Vector2i(-4, -3 + slot)
		player.monsters.append({"slot": slot, "kind": "lair", "x": tile.x * 32 + 16, "y": tile.y * 32 + 16,
			"color": 1})
	for i in player.world.lair_respawn.size():
		player.world.lair_respawn[i] = -1000000
	player.siege_active = false


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


## The shield's moment after a pane closes, waited out.
func _after_pane() -> void:
	await get_tree().create_timer(WorldScreen.AFTER_PANE_MS / 1000.0 + 0.1).timeout
	await _frames(2)


func _key(code: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = code
	press.physical_keycode = code
	press.pressed = true
	viewport.push_input(press, true)
	var up := press.duplicate() as InputEventKey
	up.pressed = false
	viewport.push_input(up, true)
	await _frames()


func _click(at: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = button
		click.pressed = pressed
		click.button_mask = (MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) \
			if pressed else 0
		click.position = at
		click.global_position = at
		viewport.push_input(click, true)
	await _frames()


func _press(node: Control) -> void:
	await _click(node.get_global_rect().get_center())


func _ask() -> Control:
	return screen.find_child("QuitAsk", true, false) as Control


# ------------------------------------------------------------- the panes --

func test_f6_opens_the_wizards_and_f5_the_hero() -> void:
	var hud := screen.hud
	await _key(KEY_F6)
	assert_true(hud.hero_shown(), "F6: the hero's pane")
	assert_eq(hud.hero_stats.tab, "Wizards", "on its Wizards tab")
	await _key(KEY_F6)
	assert_false(hud.hero_shown(), "F6 again closes it")
	await _key(KEY_F5)
	assert_eq(hud.hero_stats.tab, "Hero", "F5: the Hero tab")
	assert_true(hud.hero_shown())
	await _key(KEY_F6)
	assert_true(hud.hero_shown(), "F6 on the Hero tab turns to the wizards")
	assert_eq(hud.hero_stats.tab, "Wizards")
	await _key(KEY_F5)
	assert_true(hud.hero_shown(), "F5 on the Wizards tab turns to the hero")
	assert_eq(hud.hero_stats.tab, "Hero")
	await _key(KEY_F5)
	assert_false(hud.hero_shown(), "F5 on the Hero tab closes it")


func test_f6_sounds_once_and_d_closes_the_pane() -> void:
	var hud := screen.hud
	var before := hud.hero_stats.sounded
	await _key(KEY_F6)
	assert_eq(hud.hero_stats.sounded, before + 1, "Statscrn.wav once as the window opens, never twice")
	await _key(KEY_J)
	assert_eq(hud.hero_stats.tab, "Journal", "J: the journal")
	await _key(KEY_W)
	assert_eq(hud.hero_stats.tab, "Wizards", "W: the wizards")
	await _key(KEY_D)
	assert_false(hud.hero_shown(), "D: done, the pane closed")


func test_the_d_that_closed_the_pane_does_not_look_while_held() -> void:
	var hud := screen.hud
	hud.toggle_hero()
	assert_true(hud.hero_shown())
	var camera := screen.view.camera
	# D held: the Input's state, and the press through the screen's
	# viewport, where the pane and the world hear it.
	Input.parse_input_event(_held(KEY_D, true))
	viewport.push_input(_held(KEY_D, true), true)
	await _frames()
	assert_false(hud.hero_shown(), "D: done")
	screen._look_with_keys(0.5)
	assert_eq(screen.view.camera, camera, "still held: no look to the right")
	Input.parse_input_event(_held(KEY_D, false))
	viewport.push_input(_held(KEY_D, false), true)
	await _frames()
	screen._look_with_keys(0.1)
	assert_eq(screen._pane_letters, [] as Array[int], "let go: the world's again")
	# With the pane open, A still looks.
	hud.toggle_hero()
	Input.parse_input_event(_held(KEY_A, true))
	await _frames(1)
	screen._look_with_keys(0.2)
	assert_lt(screen.view.camera.x, camera.x, "A looks left, the pane open")
	Input.parse_input_event(_held(KEY_A, false))
	await _frames(1)


## A fresh key event for [param code], down or up.
func _held(code: Key, down: bool) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = down
	return key


func test_f6_waits_while_a_pane_holds_the_world_or_the_map_is_up() -> void:
	assert_not_null(screen.show_city_list(), "control: a pane over the world")
	await _key(KEY_F6)
	assert_false(screen.hud.hero_shown(), "no hero's pane under the city list")
	await _key(KEY_ESCAPE)
	await _after_pane()
	screen.toggle_map()
	await _key(KEY_F6)
	assert_false(screen.hud.hero_shown(), "none under the map")
	assert_true(screen._map.visible, "the map stays up")


func test_the_options_hold_the_wizards() -> void:
	var hud := screen.hud
	var entry := hud.find_child("Option_Wizards", true, false) as Button
	assert_not_null(entry, "the options' Wizards entry")
	assert_eq(entry.text, "Wizards (F6)")
	hud.toggle_options()
	hud._choose("Wizards")
	assert_false(hud.options_shown(), "the options close")
	assert_true(hud.hero_shown(), "the hero's pane")
	assert_eq(hud.hero_stats.tab, "Wizards", "on the wizards")
	# The Hero page measured for the pane's size goes on the next frame.
	await _frames()


func test_l_opens_the_saved_adventures() -> void:
	await _key(KEY_L)
	assert_true(screen.loading(), "L: the saved adventures over the world")


# ------------------------------------------------------ ready to quit? --

func test_q_asks_and_no_stays() -> void:
	await _key(KEY_Q)
	var ask := _ask()
	assert_not_null(ask, "Q: Ready to Quit?")
	assert_true(screen.quit_asked())
	assert_true(screen.modal(), "the question holds the world")
	assert_string_contains((ask.find_child("QuitYes", true, false) as Button).text, "Yes.")
	await _press(ask.find_child("QuitNo", true, false) as Control)
	await _frames()
	assert_null(_ask(), "No.: gone")
	assert_eq(screen.titles, 0, "still in the world")
	assert_eq(screen.saves, 0, "nothing saved")


## The owner (2026-10-27): "upon esc key not just question to quit but also
## offer save/load in the same popup!"
func test_the_question_offers_save_and_load() -> void:
	await _key(KEY_ESCAPE)
	var ask := _ask()
	assert_not_null(ask)
	assert_eq((ask.find_child("QuitSave", true, false) as Button).text, "Save")
	assert_eq((ask.find_child("QuitLoad", true, false) as Button).text, "Load")
	await _press(ask.find_child("QuitSave", true, false) as Control)
	await _frames()
	assert_null(_ask(), "Save: the question put away")
	assert_not_null(screen.find_child("SaveSlots", true, false), "the ten slots instead")
	assert_eq(screen.titles, 0, "still in the world")
	await _key(KEY_ESCAPE)
	await _frames()
	await _after_pane()
	await _key(KEY_Q)
	assert_not_null(_ask(), "asked again")
	await _key(KEY_L)
	await _frames()
	assert_null(_ask(), "L: the question put away")
	assert_true(screen.loading(), "the saved adventures instead")
	assert_eq(screen.titles, 0)


func test_escape_asks_and_escape_on_the_question_stays() -> void:
	await _key(KEY_ESCAPE)
	assert_not_null(_ask(), "Escape with nothing open: Ready to Quit?")
	await _key(KEY_ESCAPE)
	await _frames()
	assert_null(_ask(), "Escape on the question: stays")
	assert_eq(screen.titles, 0)
	await _after_pane()
	await _key(KEY_ESCAPE)
	assert_not_null(_ask(), "asked again")
	await _key(KEY_N)
	await _frames()
	assert_null(_ask(), "N: No.")
	assert_eq(screen.titles, 0)


func test_yes_saves_and_leaves() -> void:
	await _key(KEY_ESCAPE)
	var ask := _ask()
	await _press(ask.find_child("QuitYes", true, false) as Control)
	await _frames()
	assert_eq(screen.saves, 1, "saved")
	assert_eq(screen.titles, 1, "and on the way to the title")


func test_y_answers_yes() -> void:
	await _key(KEY_Q)
	await _key(KEY_Y)
	await _frames()
	assert_eq(screen.titles, 1, "Y: Yes.")


func test_escape_or_q_close_what_is_open_first() -> void:
	var hud := screen.hud
	await _key(KEY_F5)
	assert_true(hud.hero_shown(), "control: the hero's pane")
	await _key(KEY_ESCAPE)
	assert_false(hud.hero_shown(), "Escape closes it")
	assert_null(_ask(), "and asks nothing")
	await _key(KEY_H)
	assert_true(hud.help_shown(), "control: the keys")
	await _key(KEY_Q)
	assert_false(hud.help_shown(), "Q closes them")
	assert_null(_ask(), "and asks nothing")
	screen.toggle_map()
	await _key(KEY_Q)
	assert_null(_ask(), "Q under the map: nothing (the map's own keys only)")
	await _key(KEY_ESCAPE)
	assert_false(screen._map.visible, "Escape closes the map")
	assert_null(_ask(), "and asks nothing")


# ------------------------------------------------------------- the walk --

func test_space_stops_the_walk_and_comes_back() -> void:
	var player := screen.player
	var target := Vector2i(-1, -1)
	# East and south, away from the quiet lairs west of the hero.
	for dx in range(0, 13):
		for dy in range(0, 13):
			var tile := player.tile() + Vector2i(dx, dy)
			if absi(dx) + absi(dy) >= 8 and screen.world.is_land(tile.x, tile.y) \
					and screen.walk.plan(tile).size() > 6:
				target = tile
				break
		if target.x >= 0:
			break
	assert_gt(target.x, -1, "control: a place a few steps away")
	assert_true(screen.walk_to_tile(target), "control: walking")
	screen.advance(HeroWalk.TICK * 4)
	assert_true(screen.walk.is_walking(), "control: still on the way")
	screen.look(Vector2(300, 200))
	assert_ne(screen.view.camera, screen.view.hero, "control: looked away")
	await _key(KEY_SPACE)
	assert_false(screen.walk.is_walking(), "Space: the walk stopped (1997)")
	assert_eq(screen.view.camera, screen.view.hero, "and the camera back on the hero")
	var at := player.position
	screen.advance(HeroWalk.TICK * 4)
	assert_eq(player.position, at, "the hero stands")


## The letters look while the hero's pane is closed, and are the pane's
## while it is open; the arrows look either way no more — they walk the
## hero (0.50.66, the owner's ruling of 2026-10-29).
func test_the_letters_are_the_hero_pane_s_while_it_is_open() -> void:
	var w := InputEventKey.new()
	w.keycode = KEY_W
	w.physical_keycode = KEY_W
	w.pressed = true
	Input.parse_input_event(w)
	Input.flush_buffered_events()
	assert_true(Input.is_key_pressed(KEY_W), "control: W held")
	var camera := screen.view.camera
	screen._look_with_keys(0.1)
	assert_ne(screen.view.camera, camera, "W looks")
	screen.hud.toggle_hero()
	camera = screen.view.camera
	screen._look_with_keys(0.1)
	assert_eq(screen.view.camera, camera, "the hero's pane open: W is the pane's, no look")
	var w_up := w.duplicate() as InputEventKey
	w_up.pressed = false
	Input.parse_input_event(w_up)
	var arrow := InputEventKey.new()
	arrow.keycode = KEY_UP
	arrow.physical_keycode = KEY_UP
	arrow.pressed = true
	Input.parse_input_event(arrow)
	Input.flush_buffered_events()
	screen._look_with_keys(0.1)
	assert_eq(screen.view.camera, camera, "the arrows look no more: they walk")


# ------------------------------------------------------- the right click --

func test_a_right_click_on_the_world_opens_the_options() -> void:
	var hud := screen.hud
	# High enough for the whole list under the pointer, with or without the
	# skin's lettering (lower down it is kept whole on the screen, below).
	var at := Vector2(640, 200)
	await _click(at, MOUSE_BUTTON_RIGHT)
	assert_true(hud.options_shown(), "a right click on the world: the options")
	var menu := hud.find_child("OptionsMenu", true, false) as Control
	assert_eq(menu.get_global_rect().position, at, "at the pointer")
	await _click(Vector2(200, 300), MOUSE_BUTTON_RIGHT)
	assert_false(hud.options_shown(), "again: closed")
	for corner in [Vector2(1275, 420), Vector2(900, 795)]:
		await _click(corner, MOUSE_BUTTON_RIGHT)
		assert_true(hud.options_shown(), "opened at %s" % corner)
		menu = hud.find_child("OptionsMenu", true, false) as Control
		assert_true(Rect2(Vector2.ZERO, Vector2(1280, 800)).encloses(menu.get_global_rect()),
			"by the screen's edge: kept whole on it")
		hud.close_options()
	hud.close_options()
	hud.toggle_hero()
	var pane := hud.find_child("HeroPanel", true, false) as Control
	await _click(pane.get_global_rect().get_center(), MOUSE_BUTTON_RIGHT)
	assert_false(hud.options_shown(), "a right click on a pane is the pane's")


func test_a_right_click_waits_under_a_pane() -> void:
	assert_not_null(screen.show_city_list())
	screen._gui_input(_right_at(Vector2(640, 520)))
	assert_false(screen.hud.options_shown(), "no options while a pane holds the world")


func _right_at(at: Vector2) -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = at
	return click


# ------------------------------------------------------- the help's words --

func test_the_help_says_the_keys() -> void:
	var keys := "\n".join(screen.hud.key_lines())
	for said in ["M or F2: the map", "F3: the cities", "F6: the wizards", "L: load", "Right click: the options",
			"Escape or Q: close what is open, or ask to leave the world", "Space: back to your hero; stops the walk",
			"W, J, D:"]:
		assert_string_contains(keys, said)

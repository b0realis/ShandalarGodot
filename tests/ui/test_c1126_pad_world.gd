extends GutTest
## THE ADVENTURE WITH A CONTROLLER ALONE (campaign 2026-11-26; a player:
## *"All the controller configuration options seem to be related to the
## actual games of Magic, not moving around the Shandalar world map"*; the
## owner: *"lets implement full controller support"*).
##
##   1. ONE RULE for the D-pad ([method PadControls.dpad_walks], asked of
##      [method WorldScreen.pad_dpad_walks]): on the free world it types the
##      arrow keys — held is step by step, two directions a diagonal, let
##      go stops on the tile under way — and hops no pointer; with a pane,
##      the options, the hero's pane, the map or a text field up it hops as
##      everywhere else and walks no one.
##   2. A direction held as a pane opens is let go as a key when the pad
##      lets it go: no arrow key is left down.
##   3. The world map's actions on their buttons ([constant
##      Controls.WORLD_ACTIONS]): Y the map, Back the hero's pane, Start
##      the options, RB stops the walk, B closes or asks to quit, X the
##      pane's first choice, a button given to Quicksave saves.
##   4. A dungeon's board steps by the D-pad as by its arrow keys, and
##      hops again at its questions.
##   5. With the keys nothing changed: M, F5 and Space do what they did; a
##      key given another action answers no more.
##
## Every pad event is the engine's own (`Input.parse_input_event`), the
## layer flushed by hand; the world stands in the window's own viewport,
## where the layer's keys and pointer go.

const SAVES := "user://adventure_tests_c1126_pad_world"
const HELD := [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]
const DPAD := [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]
const LAIRS := [Vector2i(3, 0), Vector2i(0, 3), Vector2i(-3, 0), Vector2i(0, -3), Vector2i(3, -3),
	Vector2i(-3, 3)]


class Probe extends WorldScreen:
	var quicksaves := 0

	func _board_seed() -> int:
		return 4242

	func _write_quicksave() -> String:
		quicksaves += 1
		return "user://nowhere.sav"

	func _show_quicksave_notice(_success: bool, _words := "") -> void:
		pass

	func _go_to_title() -> void:
		_leaving = true


var screen: Probe
var layer: Node
var _saved_pad: Variant = null
var _saved_controls: Variant = null
var _made: Array[InputEvent] = []


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	DungeonView.frame_seconds = 0.0
	TileReveal.forced = 0
	Settings.clear_value(WorldHud.PACE_SETTING)
	layer = get_tree().root.get_node_or_null("PadControls")
	_saved_pad = Settings.get_value(PadControls.KEY, null) if Settings.has_value(PadControls.KEY) else null
	_saved_controls = Settings.get_value(Controls.SETTINGS_KEY, null) \
		if Settings.has_value(Controls.SETTINGS_KEY) else null
	Controls.reset()
	Settings.set_value(PadControls.KEY, PadControls.ON)
	layer.apply_settings()
	_made.clear()
	layer.synthesized.connect(_on_made)
	get_viewport().gui_release_focus()
	var setup := AdventureSetup.new()
	setup.player_name = "Inniscor"
	setup.color = "green"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	screen = Probe.new()
	screen.record = setup.resolve({})
	add_child_autofree(screen)
	await wait_process_frames(3)
	screen.set_process(false)
	screen.player.food = 50
	screen.player.sieges = AdventurePlayer.SIEGES_NONE
	screen._tick_left = 0.0
	screen._shield_until = 0
	_quiet_slots()


func after_each() -> void:
	for button in DPAD:
		_pad(button, false)
	layer.flush()
	for code in HELD:
		var up := InputEventKey.new()
		up.keycode = code
		up.physical_keycode = code
		up.pressed = false
		Input.parse_input_event(up)
	Input.flush_buffered_events()
	layer.synthesized.disconnect(_on_made)
	if _saved_pad == null:
		Settings.clear_value(PadControls.KEY)
	else:
		Settings.set_value(PadControls.KEY, _saved_pad)
	layer.apply_settings()
	Controls.reset()
	if _saved_controls != null:
		Settings.set_value(Controls.SETTINGS_KEY, _saved_controls)
		Controls.apply()
	DungeonView.frame_seconds = DungeonView.FRAME_SECONDS
	TileReveal.forced = -1
	Settings.clear_value(WorldHud.PACE_SETTING)
	await wait_process_frames(2)
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _on_made(event: InputEvent) -> void:
	_made.append(event)


func _quiet_slots() -> void:
	var player := screen.player
	player.monsters = [] as Array
	for slot in WorldLairs.SLOTS:
		var tile: Vector2i = player.tile() + LAIRS[slot]
		player.monsters.append({"slot": slot, "kind": "lair", "x": tile.x * 32 + 16, "y": tile.y * 32 + 16,
			"color": 1})
	for i in player.world.lair_respawn.size():
		player.world.lair_respawn[i] = -1000000


func _run(ticks: int) -> void:
	for i in ticks:
		_quiet_slots()
		screen._process(HeroWalk.TICK)


func _until_standing(most := 400) -> void:
	for i in most:
		if not screen.walk.is_walking():
			return
		_run(1)


## A pad button down or up, through the engine; the layer spends it at once.
func _pad(button: int, pressed: bool) -> void:
	var jb := InputEventJoypadButton.new()
	jb.device = 0
	jb.button_index = button as JoyButton
	jb.pressed = pressed
	Input.parse_input_event(jb)
	Input.flush_buffered_events()
	layer.flush()
	Input.flush_buffered_events()


func _press(button: int) -> void:
	_pad(button, true)
	_pad(button, false)


func _key(code: Key, ctrl := false) -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.pressed = pressed
		key.ctrl_pressed = ctrl
		Input.parse_input_event(key)
		Input.flush_buffered_events()


func _middle(tile: Vector2i) -> Vector2i:
	return tile * 32 + Vector2i(16, 16)


## A straight line of plain land [param way] (1–8), [param length] tiles
## and one beyond; the hero set down on its first tile.
func _line(way: int, length: int) -> Vector2i:
	var player := screen.player
	var step := Vector2i(ShandalarWorld.DX[way], ShandalarWorld.DY[way])
	var home := player.tile()
	for radius in range(0, 20):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var start := home + Vector2i(dx, dy)
				var ok := true
				for k in length + 2:
					var tile := start + step * k
					if not screen.world.is_land(tile.x, tile.y) or not screen.place_at(tile).is_empty() \
							or not VisitPane.describe(player, tile).is_empty():
						ok = false
						break
				if ok:
					player.position = _middle(start)
					screen.view.hero = Vector2(player.position)
					screen.view.camera = screen.view.hero
					_quiet_slots()
					return start
	return Vector2i(-1, -1)


func _motions() -> int:
	var count := 0
	for event in _made:
		if event is InputEventMouseMotion:
			count += 1
	return count


func _keys_typed() -> Array:
	var out := []
	for event in _made:
		if event is InputEventKey:
			out.append([(event as InputEventKey).keycode, (event as InputEventKey).pressed])
	return out


# ------------------------------------------------------- the one rule --

func test_the_rule_is_true_only_on_the_free_world() -> void:
	assert_true(screen.is_in_group(PadControls.WALK_GROUP), "the world stands in the walkers' group")
	assert_eq(WorldScreen.PAD_WALK_GROUP, PadControls.WALK_GROUP, "one word for the group")
	assert_true(screen.pad_dpad_walks(), "the free world: the D-pad is the world's")
	assert_true(layer.dpad_walks(), "and the layer hears it")
	screen.hud.toggle_options()
	assert_false(screen.pad_dpad_walks(), "the options open: buttons to hop over")
	screen.hud.close_panels()
	screen.toggle_hero()
	assert_false(screen.pad_dpad_walks(), "the hero's pane")
	screen.hud.close_panels()
	screen.toggle_help()
	assert_false(screen.pad_dpad_walks(), "the keys' help")
	screen.hud.close_panels()
	assert_true(screen.pad_dpad_walks(), "all closed: the world's again")
	screen.toggle_map()
	assert_false(screen.pad_dpad_walks(), "the map")
	screen.toggle_map()
	var asked := screen.ask_quit()
	assert_not_null(asked)
	assert_false(screen.pad_dpad_walks(), "a question")
	assert_false(layer.dpad_walks())
	asked.answered.emit(false)
	await wait_process_frames(2)
	assert_true(screen.pad_dpad_walks(), "answered: the world's again")
	var field := LineEdit.new()
	screen.add_child(field)
	field.grab_focus()
	assert_false(screen.pad_dpad_walks(), "a text field has the keys")
	field.free()
	screen.visible = false
	assert_false(screen.pad_dpad_walks(), "a world not shown walks no one")
	screen.visible = true


func test_no_walker_on_the_stage_means_a_hop() -> void:
	screen.remove_from_group(PadControls.WALK_GROUP)
	assert_false(layer.dpad_walks(), "nobody says the D-pad is theirs")
	_pad(JOY_BUTTON_DPAD_RIGHT, true)
	assert_eq(_keys_typed(), [], "no arrow key typed")
	assert_false(Input.is_key_pressed(KEY_RIGHT))
	_pad(JOY_BUTTON_DPAD_RIGHT, false)
	screen.add_to_group(PadControls.WALK_GROUP)


# ----------------------------------------------------------- the walk --

func test_the_dpad_held_walks_tile_by_tile_and_stops_on_release() -> void:
	var player := screen.player
	var start := _line(4, 4)
	assert_gt(start.x, -1, "control: a line of land to walk")
	_pad(JOY_BUTTON_DPAD_RIGHT, true)
	assert_true(Input.is_key_pressed(KEY_RIGHT), "the D-pad holds the arrow key down")
	assert_true(screen.walk.is_walking(), "D-pad right: the hero walks at once")
	assert_true(screen.walk.by_keys, "the keys' own walk, no way found")
	assert_eq(_motions(), 0, "the pointer did not hop")
	assert_false(layer.is_awake(), "and no arrow came up")
	var middles: Array[Vector2i] = []
	for i in 600:
		_run(1)
		if screen.walk.at_middle:
			middles.append(player.tile())
		if middles.size() == 3:
			break
	assert_eq(middles, [start + Vector2i(1, 1), start + Vector2i(2, 2), start + Vector2i(3, 3)] as Array[Vector2i],
		"held: one tile after another, the way the right arrow walks")
	assert_true(screen.walk.is_walking(), "still held: walking on")
	_pad(JOY_BUTTON_DPAD_RIGHT, false)
	assert_false(Input.is_key_pressed(KEY_RIGHT), "let go: the key is up")
	_until_standing()
	assert_eq(player.position, _middle(start + Vector2i(4, 4)), "the tile under way walked to its middle")
	var at := player.position
	_run(40)
	assert_eq(player.position, at, "and the hero stands")
	assert_eq(_keys_typed(), [[KEY_RIGHT, true], [KEY_RIGHT, false]], "one key down, one up")


func test_a_tap_walks_one_tile() -> void:
	var start := _line(8, 2)
	assert_gt(start.x, -1, "control: land to the left")
	_press(JOY_BUTTON_DPAD_LEFT)
	_until_standing()
	assert_eq(screen.player.position, _middle(start + Vector2i(-1, -1)), "one tile, the way Left walks")


func test_two_directions_walk_the_diagonal() -> void:
	var start := _line(3, 3)
	assert_gt(start.x, -1, "control: a line of land up and right")
	_pad(JOY_BUTTON_DPAD_UP, true)
	_run(1)
	_pad(JOY_BUTTON_DPAD_RIGHT, true)
	assert_eq(screen.walk.keyed, 3, "up and right: the way between them, as two arrows")
	_pad(JOY_BUTTON_DPAD_UP, false)
	_pad(JOY_BUTTON_DPAD_RIGHT, false)
	_until_standing()
	assert_eq(screen.player.facing, 3)


func test_the_dpad_walk_matches_the_arrow_key_walk() -> void:
	var start := _line(4, 3)
	assert_gt(start.x, -1)
	var player := screen.player
	_pad(JOY_BUTTON_DPAD_RIGHT, true)
	_run(30)
	_pad(JOY_BUTTON_DPAD_RIGHT, false)
	_until_standing()
	var by_pad := [player.position, player.facing, screen.walk.by_keys]
	player.position = _middle(start)
	player.food = 50
	screen.view.hero = Vector2(player.position)
	var held := InputEventKey.new()
	held.keycode = KEY_RIGHT
	held.physical_keycode = KEY_RIGHT
	held.pressed = true
	Input.parse_input_event(held)
	Input.flush_buffered_events()
	_run(30)
	var up := held.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	_until_standing()
	assert_eq([player.position, player.facing, screen.walk.by_keys], by_pad, "the same walk: place and facing")


func test_with_a_pane_open_the_dpad_hops_and_walks_no_one() -> void:
	var start := _line(4, 3)
	assert_gt(start.x, -1)
	var asked := screen.ask_quit()
	await wait_process_frames(2)
	_made.clear()
	_pad(JOY_BUTTON_DPAD_RIGHT, true)
	assert_eq(_keys_typed(), [], "no arrow key typed under a question")
	assert_false(Input.is_key_pressed(KEY_RIGHT))
	assert_gt(_motions(), 0, "the pointer hopped")
	assert_true(layer.is_awake(), "the arrow is up")
	_pad(JOY_BUTTON_DPAD_RIGHT, false)
	_run(10)
	assert_false(screen.walk.is_walking(), "nobody walked")
	assert_eq(screen.player.position, _middle(start))
	asked.answered.emit(false)


func test_a_direction_held_as_a_pane_opens_is_let_go_as_a_key() -> void:
	var start := _line(4, 4)
	assert_gt(start.x, -1)
	_pad(JOY_BUTTON_DPAD_RIGHT, true)
	assert_true(Input.is_key_pressed(KEY_RIGHT))
	var asked := screen.ask_quit()
	assert_not_null(asked)
	_made.clear()
	_pad(JOY_BUTTON_DPAD_RIGHT, false)
	assert_false(Input.is_key_pressed(KEY_RIGHT), "the arrow is up again though a pane is open")
	assert_eq(_keys_typed(), [[KEY_RIGHT, false]])
	assert_eq(_motions(), 0, "a release hops nowhere")
	asked.answered.emit(false)


func test_turning_the_layer_off_lets_the_arrow_go() -> void:
	_line(4, 4)
	_pad(JOY_BUTTON_DPAD_RIGHT, true)
	assert_true(Input.is_key_pressed(KEY_RIGHT))
	layer.set_active(false)
	Input.flush_buffered_events()
	assert_false(Input.is_key_pressed(KEY_RIGHT), "nothing is left held")
	layer.set_active(true)


# --------------------------------------------------------- the actions --

func test_y_opens_and_closes_the_map() -> void:
	_press(JOY_BUTTON_Y)
	assert_true(screen._map.visible, "Y: the map")
	_press(JOY_BUTTON_Y)
	assert_false(screen._map.visible, "Y again closes it")
	_press(JOY_BUTTON_Y)
	_press(JOY_BUTTON_B)
	assert_false(screen._map.visible, "B closes it too")


func test_back_opens_the_hero_and_start_the_options() -> void:
	_press(JOY_BUTTON_BACK)
	assert_true(screen.hud.hero_shown(), "Back: the hero's pane")
	_press(JOY_BUTTON_B)
	assert_false(screen.hud.hero_shown(), "B closes it")
	_press(JOY_BUTTON_START)
	assert_true(screen.hud.options_shown(), "Start: the options")
	assert_false(screen.pad_dpad_walks(), "and the D-pad hops over them")
	_press(JOY_BUTTON_START)
	assert_false(screen.hud.options_shown(), "Start again closes them")
	_press(JOY_BUTTON_START)
	_press(JOY_BUTTON_B)
	assert_false(screen.hud.options_shown(), "B closes them")
	assert_false(screen.quit_asked(), "and asked nothing")


func test_b_with_nothing_open_asks_to_quit_and_b_stays() -> void:
	_press(JOY_BUTTON_B)
	assert_true(screen.quit_asked(), "B on the free world: Ready to Quit?")
	_press(JOY_BUTTON_B)
	await wait_process_frames(2)
	assert_false(screen.quit_asked(), "B again: No.")
	assert_false(screen._leaving)


func test_rb_stops_the_walk() -> void:
	var start := _line(4, 5)
	assert_gt(start.x, -1)
	screen.walk_to_tile(start + Vector2i(5, 5))
	_run(3)
	assert_true(screen.walk.is_walking(), "control: walking")
	screen.look(Vector2(200, 0))
	_press(JOY_BUTTON_RIGHT_SHOULDER)
	_until_standing(5)
	assert_false(screen.walk.is_walking(), "RB: the walk stopped")
	assert_eq(screen.view.camera, screen.view.hero, "and the view is back on the hero")


func test_a_button_given_to_quicksave_saves_and_the_file_remembers() -> void:
	var l3 := InputEventJoypadButton.new()
	l3.button_index = JOY_BUTTON_LEFT_STICK
	l3.pressed = true
	assert_true(Controls.bind("world_quicksave", l3))
	assert_eq((Settings.get_value(Controls.SETTINGS_KEY, {}) as Dictionary).get("world_quicksave"),
		["key:Ctrl+S", "pad:L3"], "remembered")
	_press(JOY_BUTTON_LEFT_STICK)
	assert_eq(screen.quicksaves, 1, "L3 saves to the Quickslot")
	_key(KEY_S, true)
	assert_eq(screen.quicksaves, 2, "Ctrl+S still does")
	screen.toggle_map()
	_press(JOY_BUTTON_LEFT_STICK)
	assert_eq(screen.quicksaves, 3, "over the map too")
	screen.toggle_map()


func test_x_points_at_a_pane_s_first_choice_then_takes_it() -> void:
	var asked := screen.ask_quit()
	await wait_process_frames(2)
	var no := asked.find_child("QuitNo", true, false) as Button
	assert_eq(screen._first_choice(), no, "control: No. is the first choice")
	_press(JOY_BUTTON_X)
	await wait_process_frames(1)
	assert_true(layer.is_awake(), "X woke the pointer")
	assert_true(no.get_global_rect().has_point(layer.pointer()), "on the first choice")
	assert_true(screen.quit_asked(), "nothing taken yet")
	_press(JOY_BUTTON_X)
	layer.flush()
	await wait_process_frames(2)
	assert_false(screen.quit_asked(), "X again there: taken")
	assert_false(screen._leaving, "No.: the hero stays")


func test_x_in_a_text_field_is_its_enter() -> void:
	var asked := screen.ask_quit()
	var field := LineEdit.new()
	asked.add_child(field)
	field.text = "Day 3"
	field.grab_focus()
	var got: Array[String] = []
	field.text_submitted.connect(func(text: String) -> void: got.append(text))
	_press(JOY_BUTTON_X)
	assert_eq(got, ["Day 3"] as Array[String], "the name taken as it stands")
	field.free()
	asked.answered.emit(false)


func test_x_and_the_dpad_do_nothing_new_on_the_free_world() -> void:
	_made.clear()
	_press(JOY_BUTTON_X)
	assert_eq(_made.size(), 0, "X: no pane, no choice")
	assert_false(screen.modal())


# ------------------------------------------------------------ the keys --

func test_the_keys_do_what_they_did() -> void:
	_key(KEY_M)
	assert_true(screen._map.visible, "M: the map")
	_key(KEY_M)
	assert_false(screen._map.visible, "M closes it")
	_key(KEY_F2)
	assert_true(screen._map.visible, "F2 too")
	_key(KEY_F2)
	_key(KEY_F5)
	assert_true(screen.hud.hero_shown(), "F5: the hero")
	_key(KEY_F5)
	assert_false(screen.hud.hero_shown())
	_key(KEY_S, true)
	assert_eq(screen.quicksaves, 1, "Ctrl+S")
	_key(KEY_F10)
	assert_true(screen.hud.options_shown(), "F10, a handheld's menu key: the options")
	screen.hud.close_panels()


func test_a_key_given_another_action_answers_no_more() -> void:
	var k := InputEventKey.new()
	k.keycode = KEY_K
	k.pressed = true
	assert_true(Controls.bind("world_map", k))
	_key(KEY_M)
	assert_false(screen._map.visible, "M is the map's no more")
	_key(KEY_K)
	assert_true(screen._map.visible, "K is")
	_key(KEY_K)
	assert_false(screen._map.visible, "and closes it")
	_key(KEY_F2)
	assert_true(screen._map.visible, "F2 stays the map's own")
	_key(KEY_F2)
	Controls.reset()
	_key(KEY_M)
	assert_true(screen._map.visible, "reset: M again")
	_key(KEY_M)


# --------------------------------------------------------- the dungeon --

func _enter_dungeon() -> DungeonPane:
	screen.player.cards = []
	for i in 20:
		screen.player.cards.append({"card": "Forest", "decks": [0]})
	screen.player.current_deck = 0
	screen.world.encounters[8]["clues"] = WorldClues.RULES | WorldClues.CREATURES
	screen._enter_board({"kind": "dungeon", "slot": 8})
	await wait_process_frames(3)
	var pane := screen._board as DungeonPane
	if pane != null and pane.step == "first":
		assert_false(screen.pad_dpad_walks(), "the first view: a button to press, the D-pad hops")
		pane.choose("go")
		await wait_process_frames(2)
	return pane


func test_the_dpad_steps_the_hero_on_a_dungeon_s_board() -> void:
	var pane := await _enter_dungeon()
	assert_not_null(pane, "control: the board's pane")
	if pane == null:
		return
	assert_eq(pane.step, "idle")
	assert_true(screen.pad_dpad_walks(), "free on the board: the D-pad is the board's")
	var way := 0
	for candidate in [1, 3, 7, 5]:
		var to: Vector2i = pane.board.hero + DungeonBoard.STEPS[candidate]
		if pane.board.is_open(to) and pane.board.event_at(to) == 0 and to != DungeonBoard.ENTRANCE:
			way = candidate
			break
	assert_ne(way, 0, "control: a free neighbour")
	# The arrows' ways on the board ([method DungeonBoard.direction_of_key]).
	var buttons := {DungeonBoard.direction_of_key(KEY_UP): JOY_BUTTON_DPAD_UP,
		DungeonBoard.direction_of_key(KEY_RIGHT): JOY_BUTTON_DPAD_RIGHT,
		DungeonBoard.direction_of_key(KEY_DOWN): JOY_BUTTON_DPAD_DOWN,
		DungeonBoard.direction_of_key(KEY_LEFT): JOY_BUTTON_DPAD_LEFT}
	var from := pane.board.hero
	_made.clear()
	_press(buttons[way])
	await wait_process_frames(3)
	# With no frame time a held key walks on to the corridor's end at once.
	var gone: Vector2i = pane.board.hero - from
	var step: Vector2i = DungeonBoard.STEPS[way]
	assert_ne(gone, Vector2i.ZERO, "the D-pad stepped the hero")
	assert_eq(gone.sign(), step.sign(), "the way its arrow key steps")
	assert_eq(_motions(), 0, "the pointer did not hop")
	assert_false(Input.is_key_pressed(DungeonBoard.direction_of_key(KEY_UP)), "control: nothing held")
	if pane.step != "idle":
		return
	pane.ask_leave()
	await wait_process_frames(1)
	assert_eq(pane.step, "leave")
	assert_false(screen.pad_dpad_walks(), "Leave? asked: the D-pad hops to its answers")
	var here := pane.board.hero
	_press(buttons[way])
	await wait_process_frames(2)
	assert_eq(pane.board.hero, here, "and steps no one")
	_press(JOY_BUTTON_B)
	await wait_process_frames(2)
	assert_eq(pane.step, "idle", "B: Stay")


# ------------------------------------------------------------- a town --

func _town_tile() -> Vector2i:
	for site: Dictionary in screen.world.sites:
		if int(site["type"]) == ShandalarWorld.TOWN:
			return Vector2i(int(site["x"]), int(site["y"]))
	return Vector2i(-1, -1)


func test_in_a_town_the_pad_opens_the_map_and_the_hero_over_it_and_x_points() -> void:
	var tile := _town_tile()
	assert_gt(tile.x, -1, "control: a town")
	screen.player.gold = 500
	var pane := screen.visit(tile)
	await wait_process_frames(2)
	assert_not_null(pane, "control: the town's pane")
	if pane == null:
		return
	assert_true(screen.town_on_top())
	assert_false(screen.pad_dpad_walks(), "in a town the D-pad hops")
	_press(JOY_BUTTON_Y)
	assert_true(screen._map.visible, "Y: the map over the town")
	_press(JOY_BUTTON_Y)
	await wait_process_frames(2)
	assert_false(screen._map.visible, "Y closes it")
	assert_true(screen.town_on_top(), "and the town is back")
	_press(JOY_BUTTON_BACK)
	assert_true(screen.hud.hero_shown(), "Back: the hero over the town")
	_press(JOY_BUTTON_B)
	await wait_process_frames(2)
	assert_false(screen.hud.hero_shown(), "B closes the hero's pane")
	assert_true(screen.town_on_top(), "and the town is back, not left")
	_press(JOY_BUTTON_X)
	await wait_process_frames(1)
	var first := screen._first_choice()
	assert_not_null(first, "control: the town has choices")
	assert_true(first != null and first.get_global_rect().has_point(layer.pointer()),
		"X: the pointer on the town's first choice")
	assert_true(screen.town_on_top(), "nothing chosen yet")
	_press(JOY_BUTTON_B)
	await wait_process_frames(3)
	# (The World Magic's seller may stand in the door as the town is left.)
	assert_false(WorldScreen._alive(screen._visit), "B leaves the town")

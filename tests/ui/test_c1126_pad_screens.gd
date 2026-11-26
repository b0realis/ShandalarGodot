extends GutTest
## THE WHOLE GAME WITH A CONTROLLER ALONE (campaign 2026-11-26, the owner:
## *"implement full controller support"*) — what the pad layer and the
## screens outside the adventure gained:
##
##   1. A page of words that scrolls (a window's summary, a "?" popup) is a
##      hop's target, and the D-pad scrolls it up and down before it hops on.
##   2. Help turns its pages with LB and RB, pad pointer on or off; LB is no
##      right click there.
##   3. The Deck Builder hears B as Escape and Start as its menu key.
##   4. A file box opens inside the game while the pad's pointer is awake
##      ([method Controls.system_file_box]); inside an engine window the
##      layer reads the pad itself: stick, wheel, RT.
##   5. A text field the pad clicks gets the board of keys under `auto`;
##      the mouse's click never does.
##   6. Options says all this under "Menus and screens:".

var layer: Node
var board: Node
var _stage: CanvasLayer
var _table: Control
var _saved_pad: Variant = null
var _saved_board: Variant = null
var _made: Array[InputEvent] = []


func before_each() -> void:
	layer = get_tree().root.get_node_or_null("PadControls")
	board = get_tree().root.get_node_or_null("ScreenKeyboard")
	_saved_pad = Settings.get_value(PadControls.KEY, null) if Settings.has_value(PadControls.KEY) else null
	_saved_board = Settings.get_value(ScreenKeyboard.KEY, null) if Settings.has_value(ScreenKeyboard.KEY) else null
	Settings.clear_value(ScreenKeyboard.KEY)
	Settings.set_value(PadControls.KEY, PadControls.ON)
	layer.apply_settings()
	_made.clear()
	layer.synthesized.connect(_on_made)
	get_viewport().gui_release_focus()


func after_each() -> void:
	_tilt(JOY_AXIS_LEFT_X, 0.0)
	_tilt(JOY_AXIS_LEFT_Y, 0.0)
	_tilt(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	layer.flush()
	layer.synthesized.disconnect(_on_made)
	for pair in [[PadControls.KEY, _saved_pad], [ScreenKeyboard.KEY, _saved_board]]:
		if pair[1] == null:
			Settings.clear_value(pair[0])
		else:
			Settings.set_value(pair[0], pair[1])
	layer.apply_settings()
	board.apply_settings()
	get_viewport().gui_release_focus()
	await wait_process_frames(2)


func _on_made(event: InputEvent) -> void:
	_made.append(event)


func _build_stage() -> void:
	_stage = CanvasLayer.new()
	_stage.layer = 200
	add_child_autofree(_stage)
	_table = Control.new()
	_table.size = Vector2(1280, 800)
	_stage.add_child(_table)


func _pad(button: int, pressed: bool) -> void:
	var jb := InputEventJoypadButton.new()
	jb.device = 0
	jb.button_index = button as JoyButton
	jb.pressed = pressed
	Input.parse_input_event(jb)
	Input.flush_buffered_events()
	layer.flush()


func _press(button: int) -> void:
	_pad(button, true)
	_pad(button, false)


func _tilt(axis: int, value: float) -> void:
	var jm := InputEventJoypadMotion.new()
	jm.device = 0
	jm.axis = axis as JoyAxis
	jm.axis_value = value
	Input.parse_input_event(jm)
	Input.flush_buffered_events()


func _button_event(button: JoyButton) -> InputEventJoypadButton:
	var jb := InputEventJoypadButton.new()
	jb.button_index = button
	jb.pressed = true
	return jb


# ------------------------------------------------ a page of words (1) --

func _page(at: Vector2, with_button := false) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.position = at
	scroll.size = Vector2(300, 120)
	var column := VBoxContainer.new()
	scroll.add_child(column)
	for i in 30:
		var line := Label.new()
		line.text = "Line %d of the summary" % i
		column.add_child(line)
	if with_button:
		var inner := Button.new()
		inner.text = "inside"
		column.add_child(inner)
	_table.add_child(scroll)
	return scroll


func test_a_scrolling_page_of_words_is_a_hop_s_target_and_the_dpad_scrolls_it() -> void:
	_build_stage()
	var top := Button.new()
	top.text = "above"
	top.position = Vector2(500, 100)
	top.size = Vector2(120, 40)
	_table.add_child(top)
	var page := _page(Vector2(410, 250))
	var below := Button.new()
	below.text = "below"
	below.position = Vector2(500, 500)
	below.size = Vector2(120, 40)
	_table.add_child(below)
	await wait_process_frames(2)
	assert_true(PadControls._is_reading(page), "control: words only, taller than its window")
	top.grab_focus()
	_press(JOY_BUTTON_DPAD_DOWN)        # wakes on the focused button, hops down
	await wait_process_frames(1)
	assert_true(page.get_global_rect().has_point(layer.pointer()), "the hop lands on the page of words")
	assert_eq(page.scroll_vertical, 0)
	_press(JOY_BUTTON_DPAD_DOWN)
	await wait_process_frames(1)
	assert_gt(page.scroll_vertical, 0, "down scrolls it")
	assert_true(page.get_global_rect().has_point(layer.pointer()), "the pointer stays on it")
	var mid := page.scroll_vertical
	_press(JOY_BUTTON_DPAD_UP)
	await wait_process_frames(1)
	assert_lt(page.scroll_vertical, mid, "up scrolls it back")
	for i in 60:
		_press(JOY_BUTTON_DPAD_DOWN)
		await wait_process_frames(1)
		if below.get_global_rect().has_point(layer.pointer()):
			break
	assert_true(below.get_global_rect().has_point(layer.pointer()), "at its end the hop goes on to the next button")


func test_a_scroll_with_buttons_in_it_is_no_page_of_words() -> void:
	_build_stage()
	var list := _page(Vector2(410, 250), true)
	await wait_process_frames(2)
	assert_false(PadControls._is_reading(list), "its lines are the targets, as before")
	var short := ScrollContainer.new()
	short.size = Vector2(300, 120)
	short.add_child(Label.new())
	_table.add_child(short)
	await wait_process_frames(2)
	assert_false(PadControls._is_reading(short), "nothing to scroll: no target")


# ------------------------------------------------------------ Help (2) --

func test_help_turns_its_pages_with_the_shoulders() -> void:
	var help: Control = load("res://game/help/help_screen.tscn").instantiate()
	add_child_autofree(help)
	await wait_process_frames(2)
	assert_true(layer.shoulders_page(), "Help is a screen of pages")
	assert_false(layer.owns(_button_event(JOY_BUTTON_LEFT_SHOULDER)), "LB is Help's there, no right click")
	assert_true(layer.owns(_button_event(JOY_BUTTON_A)), "A is still the click")
	var first: int = help._page
	_made.clear()
	_press(JOY_BUTTON_RIGHT_SHOULDER)
	assert_eq(help._page, first + 1, "RB: the next page")
	_press(JOY_BUTTON_RIGHT_SHOULDER)
	assert_eq(help._page, first + 2)
	_press(JOY_BUTTON_LEFT_SHOULDER)
	assert_eq(help._page, first + 1, "LB: the page before")
	for event in _made:
		assert_false(event is InputEventMouseButton, "and no right click was made")
	layer.set_active(false)
	_press(JOY_BUTTON_LEFT_SHOULDER)
	assert_eq(help._page, first, "with the pad pointer off too")
	layer.set_active(true)
	help.visible = false
	assert_false(layer.shoulders_page(), "put away, LB is the right button again")


# ---------------------------------------------------- Deck Builder (3) --

func test_the_deck_builder_hears_b_and_start() -> void:
	CardRegistry.ensure_loaded()
	var builder: DeckBuilderScreen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(builder)
	builder.set_deferred("size", Vector2(1280, 800))
	await wait_process_frames(2)
	assert_false(builder.is_menu_open(), "control: no menu")
	_press(JOY_BUTTON_START)
	assert_true(builder.is_menu_open(), "Start: the menu, as Q")
	_press(JOY_BUTTON_START)
	assert_false(builder.is_menu_open(), "Start again closes it")
	_press(JOY_BUTTON_B)
	assert_true(builder.is_menu_open(), "B with nothing pending: the menu, as Escape")
	_press(JOY_BUTTON_B)
	assert_false(builder.is_menu_open(), "B again: closed, as Escape")
	builder._filter_bar.search_field.text = "bolt"
	builder.filter.text = "bolt"
	_press(JOY_BUTTON_B)
	assert_eq(builder.filter.text, "", "B empties the search first, as Escape")
	assert_false(builder.is_menu_open())


# ------------------------------------------------------ file boxes (4) --

func test_a_file_box_is_the_game_s_own_while_the_pad_points() -> void:
	_build_stage()
	var mouse := InputEventMouseMotion.new()
	mouse.position = Vector2(30, 30)
	mouse.global_position = mouse.position
	mouse.device = 0
	Input.parse_input_event(mouse)
	Input.flush_buffered_events()
	assert_false(layer.is_awake(), "control: the mouse has the pointer")
	assert_true(Controls.system_file_box(), "a mouse: the system's file window, as ever")
	_press(JOY_BUTTON_DPAD_DOWN)
	assert_true(layer.is_awake(), "control: the pad has it")
	assert_eq(Controls.system_file_box(), OS.has_feature("mobile"), "a pad: the box inside the game")
	layer.set_active(false)
	assert_true(Controls.system_file_box(), "layer off: the system's")
	layer.set_active(true)


func test_inside_an_engine_window_the_layer_reads_the_pad_itself() -> void:
	_build_stage()
	var window := Window.new()
	window.size = Vector2i(400, 300)
	window.position = Vector2i(300, 200)
	var inside := Button.new()
	inside.text = "Select Current Folder"
	inside.position = Vector2(100, 200)
	inside.size = Vector2(200, 40)
	var presses := [0]
	inside.pressed.connect(func() -> void: presses[0] += 1)
	window.add_child(inside)
	_table.add_child(window)
	window.show()
	window.grab_focus()
	await wait_process_frames(3)
	if not window.has_focus() or not get_tree().root.get_embedded_subwindows().has(window):
		pending("no embedded window with the focus on this display")
		window.queue_free()
		return
	assert_eq(layer._focused_window(), window, "control: the window has the pad")
	layer._wake()
	layer.flush()
	_tilt(JOY_AXIS_LEFT_X, 1.0)
	var before: Vector2 = layer.pointer()
	layer.flush(0.1)
	assert_gt(layer.pointer().x, before.x, "the stick's tilt was read off the pad: the pointer moves")
	_tilt(JOY_AXIS_LEFT_X, 0.0)
	layer.flush(0.1)
	# Onto the button, then RT.
	var aim := Vector2(window.position) + inside.position + inside.size * 0.5
	layer._hover(aim)
	await wait_process_frames(1)
	_tilt(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	layer.flush()
	_tilt(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	layer.flush()
	await wait_process_frames(1)
	assert_eq(presses[0], 1, "RT clicked the window's button")
	window.hide()
	layer.flush()
	assert_null(layer._focused_window())
	window.queue_free()


func test_a_mini_menu_is_still_left_to_itself() -> void:
	_build_stage()
	var menu := PopupMenu.new()
	menu.add_item("First", 11)
	_table.add_child(menu)
	await wait_process_frames(2)
	menu.position = Vector2i(400, 300)
	menu.popup()
	await wait_process_frames(2)
	assert_null(layer._focused_window(), "a popup walks itself: nothing is read off the pad")
	menu.hide()


# ------------------------------------------------- the board of keys (5) --

func test_a_field_the_pad_clicks_gets_the_board_and_the_mouse_s_does_not() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		pending("this system has its own keyboard")
		return
	_build_stage()
	var field := LineEdit.new()
	field.position = Vector2(500, 300)
	field.size = Vector2(240, 36)
	_table.add_child(field)
	await wait_process_frames(2)
	assert_false(ScreenKeyboard.should_be_active(), "control: a desk, the board on auto")
	assert_true(board.is_active(), "the focus is watched while the pad layer is on")
	# The mouse clicks the field: no board.
	var at := get_tree().root.get_final_transform() * (field.position + field.size * 0.5)
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.position = at
		mb.global_position = at
		mb.device = 0
		Input.parse_input_event(mb)
		Input.flush_buffered_events()
	await wait_process_frames(1)
	assert_true(field.has_focus(), "control: the click took the field")
	assert_false(board.is_shown(), "the mouse's click: no board")
	field.release_focus()
	await wait_process_frames(1)
	# The pad clicks it, a moment later (a press within a tenth of a second
	# of the mouse's is its copy): the board.
	await get_tree().create_timer(0.25).timeout
	layer._wake()
	layer._hover(field.position + field.size * 0.5)
	await wait_process_frames(1)
	_press(JOY_BUTTON_A)
	await wait_process_frames(1)
	assert_true(field.has_focus(), "control: A took the field")
	assert_true(board.is_shown(), "the pad's click: the board of keys")
	assert_eq(board.target(), field)
	field.release_focus()
	await wait_process_frames(2)
	assert_false(board.is_shown(), "and it goes with the focus")
	Settings.set_value(ScreenKeyboard.KEY, ScreenKeyboard.OFF)
	board.apply_settings()
	assert_false(board.is_active(), "Off is off, pad or no pad")
	layer.set_active(false)
	Settings.clear_value(ScreenKeyboard.KEY)
	board.apply_settings()
	assert_false(board.is_active(), "no pad layer: a desk never sees the board")
	layer.set_active(true)


# ------------------------------------------------------- Options (6) --

func test_options_says_what_a_controller_does_on_the_menus() -> void:
	var options: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(options)
	await wait_process_frames(1)
	var texts: Array[String] = []
	for node in options.find_children("*", "Label", true, false):
		texts.append((node as Label).text)
	var at := texts.find("Menus and screens:")
	assert_gt(at, texts.find("World map:"), "the third title, after World map")
	var lines: Array = options.MENU_PAD_LINES
	for line: String in lines:
		assert_gt(texts.find(line), at, "said: " + line)
	var said := " ".join(lines)
	for words in ["B closes or cancels on every screen", "Start opens the screen's menu",
			"LB and RB turn the pages", "a keyboard comes up on the screen", "In a file window"]:
		assert_string_contains(said, words)
	var reset := options.find_child("ResetControls", true, false) as Control
	var head := options.find_child("MenuControlsHead", true, false) as Control
	assert_gt(reset.get_index(), head.get_index())

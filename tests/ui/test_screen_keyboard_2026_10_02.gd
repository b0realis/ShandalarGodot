extends GutTest
## THE ON-SCREEN KEYBOARD — the `ScreenKeyboard` autoload
## (`game/input/screen_keyboard.gd`), the stored key behind it
## (`Settings.screen_keyboard`) and the Options row that shows it.
##
## `[QoL]`, 2026-10-02, the ArkOS tester on an R36 Ultra: *"I also don't
## have a USB keyboard, so it'd be nice to have a virtual keyboard
## option."* Driven like the touch and pad layers' tests, against real
## fields on a stage of their own:
##
##   1. INERT unless asked: `auto` is a named handheld whose system has
##      no keyboard of its own, `on` everywhere, `off` nowhere; the
##      getter refuses any other word.
##   2. A field with the focus brings the board; its keys type into it
##      down the engine's own path — `text_changed`, `text_submitted`,
##      a Backspace, a Space, a one-shot Shift; a `TextEdit` takes
##      Enter as a new line.
##   3. The board goes: on Enter in a one-line field, on `Done` (the
##      field keeps the focus), when the focus moves to a button, when
##      the field leaves the tree; a click on the field brings it back.
##   4. The keys take no focus, and a real click on one types.
##   5. Placed where the field is not: the bottom, or the top when the
##      field is down there.
##   6. The switch: the Options row is a view of the key.

const ENV := "SHANDALAR_HANDHELD"

var _xform: Transform2D
var _stage: CanvasLayer
var board: Node
var _saved: Variant = null
var _saved_env := ""
var _table: Control
var _changed: Array[String] = []
var _submitted: Array[String] = []


func before_each() -> void:
	board = get_tree().root.get_node_or_null("ScreenKeyboard")
	assert_not_null(board, "the autoload is in the tree")
	_xform = get_tree().root.get_final_transform()
	_saved = Settings.get_value(ScreenKeyboard.KEY, null) \
		if Settings.has_value(ScreenKeyboard.KEY) else null
	_saved_env = OS.get_environment(ENV)
	Settings.clear_value(ScreenKeyboard.KEY)
	board.apply_settings()
	_changed.clear()
	_submitted.clear()


func after_each() -> void:
	OS.set_environment(ENV, _saved_env)
	if _saved == null:
		Settings.clear_value(ScreenKeyboard.KEY)
	else:
		Settings.set_value(ScreenKeyboard.KEY, _saved)
	board.apply_settings()
	get_viewport().gui_release_focus()
	await get_tree().process_frame


# ------------------------------------------------------------- helpers --

func _build_stage() -> void:
	_stage = CanvasLayer.new()
	_stage.layer = 200
	add_child_autofree(_stage)
	_table = Control.new()
	_table.size = Vector2(1280, 800)
	_stage.add_child(_table)


func _add_field(at: Vector2, size := Vector2(300, 36)) -> LineEdit:
	var field := LineEdit.new()
	field.position = at
	field.size = size
	field.text_changed.connect(func(text: String) -> void: _changed.append(text))
	field.text_submitted.connect(func(text: String) -> void: _submitted.append(text))
	_table.add_child(field)
	return field


func _add_button(at: Vector2) -> Button:
	var button := Button.new()
	button.text = "elsewhere"
	button.position = at
	button.size = Vector2(120, 40)
	_table.add_child(button)
	return button


## The board on, a field in the middle of the stage holding the focus.
func _focused_field() -> LineEdit:
	board.choose(ScreenKeyboard.ON)
	_build_stage()
	var field := _add_field(Vector2(490, 300))
	field.grab_focus()
	await _settle()
	return field


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _panel() -> Control:
	return board._panel


func _key(label: String) -> Button:
	for button in board._keys:
		if button.text == label:
			return button
	return null


## Press a key the way its `pressed` signal is raised, and let the
## engine deliver the event it sent.
func _press(label: String) -> void:
	var button := _key(label)
	assert_not_null(button, "a key reads " + label)
	if button == null:
		return
	if button.toggle_mode:
		button.button_pressed = not button.button_pressed
	else:
		button.pressed.emit()
	await _settle()


## A real left click at [param at] — the stage's own coordinates.
func _click(at: Vector2) -> void:
	for down in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = down
		mb.position = _xform * at
		mb.global_position = mb.position
		mb.device = 0
		get_viewport().push_input(mb)
	await _settle()


# =============================================================== inert (1) ==

func test_the_getter_refuses_any_other_word() -> void:
	assert_eq(Settings.screen_keyboard(), "auto", "nothing stored is auto")
	for word in ["auto", "on", "off"]:
		Settings.set_value(ScreenKeyboard.KEY, word)
		assert_eq(Settings.screen_keyboard(), word)
	Settings.set_value(ScreenKeyboard.KEY, "always")
	assert_eq(Settings.screen_keyboard(), "auto", "a strange word reads as auto")
	Settings.set_value(ScreenKeyboard.KEY, 1)
	assert_eq(Settings.screen_keyboard(), "auto", "so does a number")


func test_auto_is_a_handheld_without_a_keyboard_of_its_own() -> void:
	OS.set_environment(ENV, "")
	if OS.has_feature("android"):
		return
	assert_false(ScreenKeyboard.should_be_active(), "a desk never sees it")
	OS.set_environment(ENV, "arkos")
	assert_eq(ScreenKeyboard.should_be_active(),
		not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD),
		"a named handheld whose system has no keyboard does")
	Settings.set_value(ScreenKeyboard.KEY, "off")
	assert_false(ScreenKeyboard.should_be_active(), "off is off there too")
	OS.set_environment(ENV, "")
	Settings.set_value(ScreenKeyboard.KEY, "on")
	assert_true(ScreenKeyboard.should_be_active(), "on is on at a desk")


func test_off_watches_nothing_and_builds_nothing() -> void:
	board.choose(ScreenKeyboard.OFF)
	assert_false(board.is_active())
	_build_stage()
	var field := _add_field(Vector2(490, 300))
	field.grab_focus()
	await _settle()
	assert_false(board.is_shown())
	assert_false(get_viewport().gui_focus_changed.is_connected(board._on_focus_changed),
		"off: the focus is not even watched")


func test_switching_off_while_shown_puts_the_board_away() -> void:
	var field: LineEdit = await _focused_field()
	assert_true(board.is_shown())
	board.choose(ScreenKeyboard.OFF)
	assert_false(board.is_shown())
	assert_true(field.has_focus(), "the field keeps the focus")


# =============================================================== typing (2) ==

func test_a_focused_field_brings_the_board_and_its_keys_type() -> void:
	var field: LineEdit = await _focused_field()
	assert_true(board.is_shown(), "the field with the focus brought the board")
	assert_eq(board.target(), field)
	await _press("q")
	assert_eq(field.text, "q", "the key typed into the field")
	assert_eq(_changed, ["q"], "down the engine's own path — text_changed said so")
	await _press("Shift")
	assert_true(board._shift, "Shift holds")
	assert_eq(_key("Q").text, "Q", "and the keys show their shifted faces")
	await _press("Q")
	assert_eq(field.text, "qQ")
	assert_false(board._shift, "for one key")
	assert_eq(_key("q").text, "q")
	await _press("Space")
	await _press("3")
	await _press("Shift")
	await _press("!")
	assert_eq(field.text, "qQ 3!", "Space, a digit, a shifted digit")
	await _press("Backspace")
	assert_eq(field.text, "qQ 3", "Backspace is Backspace")
	assert_true(field.has_focus(), "the field held the focus throughout")
	assert_eq(_submitted, [], "nothing was submitted")


func test_enter_submits_a_line_and_puts_the_board_away() -> void:
	var field: LineEdit = await _focused_field()
	await _press("w")
	await _press("Enter")
	assert_eq(_submitted, ["w"], "Enter is text_submitted")
	assert_false(board.is_shown(), "and the board went")
	assert_true(field.has_focus(), "the field keeps the focus")


func test_a_text_edit_takes_enter_as_a_new_line() -> void:
	board.choose(ScreenKeyboard.ON)
	_build_stage()
	var edit := TextEdit.new()
	edit.position = Vector2(490, 200)
	edit.size = Vector2(300, 120)
	_table.add_child(edit)
	edit.grab_focus()
	await _settle()
	assert_true(board.is_shown(), "a TextEdit brings the board too")
	await _press("a")
	await _press("Enter")
	await _press("b")
	assert_eq(edit.text, "a\nb", "Enter is a new line there")
	assert_true(board.is_shown(), "and the board stays")


func test_a_field_that_cannot_be_edited_brings_nothing() -> void:
	board.choose(ScreenKeyboard.ON)
	_build_stage()
	var field := _add_field(Vector2(490, 300))
	field.editable = false
	field.grab_focus()
	await _settle()
	assert_false(board.is_shown(), "nothing to type into")


# ================================================================ going (3) ==

func test_done_puts_the_board_away_and_a_click_brings_it_back() -> void:
	var field: LineEdit = await _focused_field()
	await _press("Done")
	assert_false(board.is_shown())
	assert_true(field.has_focus(), "Done leaves the focus where it was")
	assert_eq(board.target(), field, "and the field stays watched")
	await _click(Vector2(500, 318))
	assert_true(board.is_shown(), "a click on the field brings the board back")
	assert_eq(board.target(), field)


func test_the_focus_moving_to_a_button_puts_the_board_away() -> void:
	var field: LineEdit = await _focused_field()
	var button := _add_button(Vector2(100, 700))
	button.grab_focus()
	await _settle()
	assert_false(board.is_shown(), "a button has nothing to type into")
	assert_null(board.target())
	field.grab_focus()
	await _settle()
	assert_true(board.is_shown(), "and back on the field, back")


func test_the_focus_moving_to_another_field_moves_the_board() -> void:
	var field: LineEdit = await _focused_field()
	var other := _add_field(Vector2(490, 400))
	other.grab_focus()
	await _settle()
	assert_true(board.is_shown(), "still shown")
	assert_eq(board.target(), other, "for the other field")
	await _press("z")
	assert_eq(other.text, "z")
	assert_eq(field.text, "", "the first field got nothing")


func test_the_field_leaving_the_tree_puts_the_board_away() -> void:
	var field: LineEdit = await _focused_field()
	field.get_parent().remove_child(field)
	field.queue_free()
	await _settle()
	assert_false(board.is_shown(), "no field, no board — and no error")
	assert_null(board.target())
	assert_null(get_viewport().gui_get_focus_owner())


func test_the_field_hidden_puts_the_board_away() -> void:
	var field: LineEdit = await _focused_field()
	field.hide()
	await _settle()
	assert_false(board.is_shown())


# ============================================================ real keys (4) ==

func test_the_keys_take_no_focus_and_a_real_click_types() -> void:
	var field: LineEdit = await _focused_field()
	for button in board._keys:
		assert_eq(button.focus_mode, Control.FOCUS_NONE,
			"no key takes the focus: " + button.text)
	var key := _key("h")
	var centre := key.get_global_rect().get_center()
	await _click(centre)
	assert_eq(field.text, "h", "a real click on the key typed")
	assert_true(field.has_focus(), "and the field kept the focus")
	assert_true(board.is_shown())


func test_every_key_sends_the_engine_a_key_event_of_its_own() -> void:
	var field: LineEdit = await _focused_field()
	var seen: Array[InputEventKey] = []
	field.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventKey:
			seen.append(ev))
	await _press("e")
	assert_eq(seen.size(), 2, "down and up")
	assert_eq(seen[0].keycode, KEY_E)
	assert_eq(seen[0].unicode, "e".unicode_at(0))
	assert_true(seen[0].pressed)
	assert_false(seen[1].pressed)
	assert_eq(seen[0].device, InputEventKey.new().device,
		"the keyboard's own device: the engine's text actions match no other")
	assert_eq(seen[0].device, board.SYNTH_DEVICE)
	assert_false(seen[0].shift_pressed)
	seen.clear()
	await _press("Shift")
	await _press("E")
	assert_eq(seen[0].keycode, KEY_E)
	assert_eq(seen[0].unicode, "E".unicode_at(0))
	assert_true(seen[0].shift_pressed, "a shifted letter carries Shift")
	seen.clear()
	await _press("-")
	assert_eq(seen[0].keycode, KEY_NONE, "a symbol: no keycode, the character itself")
	assert_eq(seen[0].unicode, "-".unicode_at(0))
	assert_eq(field.text, "eE-")


# ================================================================ place (5) ==

func test_the_board_sits_at_the_bottom_or_over_a_field_down_there() -> void:
	var field: LineEdit = await _focused_field()
	var panel := _panel()
	var area := get_viewport().get_visible_rect().size
	assert_true(panel.size.y > 100, "five rows of keys")
	assert_true(panel.size.x <= area.x, "never wider than the window")
	assert_true(panel.size.y <= area.y * ScreenKeyboard.HEIGHT_SHARE + 1.0,
		"and never more than its share of the height")
	assert_almost_eq(panel.position.y, area.y - panel.size.y, 0.5,
		"across the bottom, under a field in the middle")
	assert_almost_eq(panel.position.x, (area.x - panel.size.x) * 0.5, 0.5, "centred")
	var low := _add_field(Vector2(490, area.y - 50))
	low.grab_focus()
	await _settle()
	assert_eq(panel.position.y, 0.0, "a field at the bottom puts the board at the top")
	field.grab_focus()
	await _settle()
	assert_almost_eq(panel.position.y, area.y - panel.size.y, 0.5, "and back")


func test_the_keys_cover_the_board_and_the_space_is_the_widest() -> void:
	var _field: LineEdit = await _focused_field()
	var side: float = board._key_side
	assert_true(side >= ScreenKeyboard.KEY_MIN and side <= ScreenKeyboard.KEY_MAX)
	assert_almost_eq(_key("q").size.x, side, 0.5, "a letter is one key wide")
	assert_almost_eq(_key("Space").size.x, side * 8 + ScreenKeyboard.GAP * 7, 0.5,
		"the Space is eight")
	assert_almost_eq(_key("Enter").size.x, side * 2 + ScreenKeyboard.GAP, 0.5)
	assert_eq(board._keys.size(), 11 * 4 + 2, "the five rows")


# =============================================================== switch (6) ==

func test_the_options_row_is_a_view_of_the_key() -> void:
	var screen: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var row: OptionButton = screen.find_child("ScreenKeyboard", true, false)
	assert_not_null(row, "the Display rows carry an On-screen keyboard choice")
	assert_eq(row.item_count, 3)
	assert_eq(row.selected, 0, "Auto, with nothing stored")
	row.select(1)
	row.item_selected.emit(1)
	assert_eq(Settings.screen_keyboard(), "on", "the key follows the row")
	assert_true(board.is_active(), "and the board follows the key at once")
	row.select(2)
	row.item_selected.emit(2)
	assert_eq(Settings.screen_keyboard(), "off")
	assert_false(board.is_active())
	Settings.set_value(ScreenKeyboard.KEY, "on")
	var fresh: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(fresh)
	await get_tree().process_frame
	var again: OptionButton = fresh.find_child("ScreenKeyboard", true, false)
	assert_eq(again.selected, 1, "a stored `on` opens the row on On")


func test_the_choice_survives_a_reload_of_the_file() -> void:
	board.choose(ScreenKeyboard.ON)
	Settings.reload_file()
	assert_eq(Settings.screen_keyboard(), "on", "the file carries it")

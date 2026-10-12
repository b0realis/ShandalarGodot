extends GutTest
## THE CARD READER AND THE PAD POINTER, AND WHICH KEYS SWITCH ITS TEXT
## (bug campaign 2026-10-12, findings b1-1, b1-2, b1-3, b6-3, b6-4).
##
## The reader's `_input` runs before the `PadControls` autoload's and used
## to mark EVERY joypad event handled: the A that opened it lost its
## release (the next A was dropped as a copy), the stick could not move
## the pointer over it (the Text toggle was out of reach) and a stick let
## go under it left the pointer drifting afterwards; A, with the pointer
## on, switched the text instead of clicking. Now the pad layer's own
## events (A, LB, the D-pad, the sticks, the triggers) pass to the layer
## while it is active; B, R3 and Escape stay the reader's.
##
## And: a RIGHT click closes the reader too (ArkOS's B is a right click),
## and only Enter / keypad Enter (or a pad's A with the pointer off)
## switches the text box — not Space, the keyboard's one button.

var layer: Node
var source: CardPreview
var viewer: FullscreenCard
var _stage: CanvasLayer
var _table: Control
var _presses := 0
var _saved_cards: Variant
var _saved_text: Variant
var _saved_pad: Variant


func _keep(key: String) -> Variant:
	return Settings.get_value(key, null) if Settings.has_value(key) else null


func _put_back(key: String, value: Variant) -> void:
	if value == null:
		Settings.clear_value(key)
	else:
		Settings.set_value(key, value, false)


func before_each() -> void:
	CardRegistry.ensure_loaded()
	_saved_cards = _keep("fullscreen_cards")
	_saved_text = _keep(FullscreenCard.FULL_TEXT_SETTING)
	_saved_pad = _keep(PadControls.KEY)
	Settings.set_value("fullscreen_cards", true, false)
	Settings.clear_value(FullscreenCard.FULL_TEXT_SETTING)
	layer = get_tree().root.get_node("PadControls")


func after_each() -> void:
	if viewer != null and is_instance_valid(viewer):
		viewer.dismiss()
	_tilt(JOY_AXIS_LEFT_X, 0.0)
	await _settle()
	_put_back("fullscreen_cards", _saved_cards)
	_put_back(FullscreenCard.FULL_TEXT_SETTING, _saved_text)
	_put_back(PadControls.KEY, _saved_pad)
	layer.set_active(false)
	layer.apply_settings()
	await _settle()


func _settle(frames := 2) -> void:
	for i in frames:
		await get_tree().process_frame


func _pad(button: int, pressed: bool) -> void:
	var jb := InputEventJoypadButton.new()
	jb.device = 0
	jb.button_index = button
	jb.pressed = pressed
	Input.parse_input_event(jb)


func _tilt(axis: int, value: float) -> void:
	var jm := InputEventJoypadMotion.new()
	jm.device = 0
	jm.axis = axis
	jm.axis_value = value
	Input.parse_input_event(jm)


func _mouse_move(at: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = get_tree().root.get_final_transform() * at
	mm.global_position = mm.position
	mm.device = 0
	Input.parse_input_event(mm)


## A sidebar card and its reader on the ROOT viewport, where the pad
## layer listens, above the runner's own panel; a button to press after.
func _build(pad_mode: String) -> void:
	layer.choose(pad_mode)
	_stage = CanvasLayer.new()
	_stage.layer = 200
	add_child_autofree(_stage)
	_table = Control.new()
	_table.size = Vector2(1280, 800)
	_table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_table)
	source = CardPreview.new()
	source.docked = true
	source.position = Vector2(40, 40)
	_table.add_child(source)
	source.show_card(CardInstance.new(CardRegistry.get_card("Shivan Dragon"), 1, 0))
	viewer = FullscreenCard.new()
	add_child_autofree(viewer)
	viewer.layer = 300
	viewer.watch(source, func() -> bool: return true)
	var button := Button.new()
	button.text = "after"
	button.position = Vector2(900, 100)
	button.size = Vector2(120, 40)
	button.pressed.connect(func() -> void: _presses += 1)
	_table.add_child(button)
	_presses = 0
	await _settle()


# ------------------------------------------- the pad pointer on (b1-*) --

func test_the_a_that_opened_the_reader_is_let_go() -> void:
	await _build(PadControls.ON)
	_mouse_move(source.get_global_rect().get_center())
	await _settle()
	_pad(JOY_BUTTON_A, true)
	await _settle()
	assert_true(viewer.is_open(), "pad A clicked the sidebar card: the reader opened")
	_pad(JOY_BUTTON_A, false)
	await _settle()
	assert_false(bool(layer._pad_down.get(JOY_BUTTON_A, false)), "the layer saw A's release")
	viewer.dismiss()
	await _settle()
	_mouse_move(Vector2(960, 120))
	await _settle()
	_pad(JOY_BUTTON_A, true)
	await _settle()
	_pad(JOY_BUTTON_A, false)
	await _settle()
	assert_eq(_presses, 1, "one A on a button after the reader closed presses it")


func test_with_the_pad_pointer_on_a_clicks_and_the_toggle_answers_it() -> void:
	await _build(PadControls.ON)
	assert_true(viewer.open_card(true))
	await _settle()
	var made: Array = []
	var on_made := func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			made.append(ev)
	layer.synthesized.connect(on_made)
	_mouse_move(viewer._text_toggle.get_global_rect().get_center())
	await _settle()
	_pad(JOY_BUTTON_A, true)
	await _settle()
	_pad(JOY_BUTTON_A, false)
	await _settle()
	layer.synthesized.disconnect(on_made)
	assert_eq(made.size(), 2, "pad A is the pointer's click (press and release)")
	assert_true(viewer.is_open(), "a click on the toggle keeps the card up")
	assert_true(viewer._card.text_is_expanded(), "and switches its text: the click landed on Text")
	_mouse_move(viewer._card.get_global_rect().get_center())
	await _settle()
	_pad(JOY_BUTTON_A, true)
	await _settle()
	_pad(JOY_BUTTON_A, false)
	await _settle()
	assert_false(viewer.is_open(), "A on the card is a click on it: the reader closes")
	assert_true(FullscreenCard.full_text_wanted(), "and A was not read as the text switch on the way")


func test_the_stick_moves_the_pointer_over_the_reader_and_rests_after() -> void:
	await _build(PadControls.ON)
	assert_true(viewer.open_card(true))
	_mouse_move(Vector2(640, 400))
	await _settle()
	var from: Vector2 = layer.pointer()
	_tilt(JOY_AXIS_LEFT_X, -0.9)
	await _settle(4)
	assert_ne(layer.pointer(), from, "the stick moves the pointer while the card is up")
	_tilt(JOY_AXIS_LEFT_X, 0.0)
	await _settle(3)
	viewer.dismiss()
	await _settle(2)
	var rested: Vector2 = layer.pointer()
	await _settle(6)
	assert_eq(layer.pointer(), rested, "the pointer stays put with the stick at rest")


func test_b_r3_and_escape_stay_the_readers() -> void:
	await _build(PadControls.ON)
	for button in [JOY_BUTTON_B, JOY_BUTTON_RIGHT_STICK]:
		assert_true(viewer.open_card(true))
		_pad(button, true)
		await _settle()
		_pad(button, false)
		await _settle()
		assert_false(viewer.is_open(), "pad %d closes the reader" % button)
	assert_true(viewer.open_card(true))
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await _settle()
	assert_false(viewer.is_open(), "Escape closes it")


func test_the_hint_says_how_the_pad_switches_the_text() -> void:
	await _build(PadControls.ON)
	assert_true(viewer.open_card(true))
	assert_false(viewer._hint.text.contains("Enter: text"), "Enter means nothing on a pad")
	assert_string_contains(viewer._hint.text, "A")
	viewer.dismiss()
	layer.choose(PadControls.OFF)
	assert_true(viewer.open_card(true))
	assert_string_contains(viewer._hint.text, "Enter: text", "the keyboard's hint is unchanged")


# --------------------------------------- the pad pointer off, the keys --

func test_with_the_pad_pointer_off_pad_a_switches_the_text() -> void:
	await _build(PadControls.OFF)
	assert_true(viewer.open_card(true))
	_pad(JOY_BUTTON_A, true)
	await _settle()
	_pad(JOY_BUTTON_A, false)
	await _settle()
	assert_true(viewer.is_open())
	assert_true(viewer._card.text_is_expanded(), "a pad's A while the pointer is off — the doc's word")


func test_space_does_not_switch_the_text_and_enter_does() -> void:
	await _build(PadControls.OFF)
	assert_true(viewer.open_card(true))
	for down in [true, false]:
		var space := InputEventKey.new()
		space.keycode = KEY_SPACE
		space.pressed = down
		Input.parse_input_event(space)
	await _settle()
	assert_true(viewer.is_open(), "Space leaves the card up")
	assert_false(viewer._card.text_is_expanded(), "Space (R1, the one button) is not the Text switch")
	assert_false(Settings.has_value(FullscreenCard.FULL_TEXT_SETTING), "and wrote nothing")
	for code in [KEY_ENTER, KEY_KP_ENTER]:
		var enter := InputEventKey.new()
		enter.keycode = code
		enter.pressed = true
		Input.parse_input_event(enter)
		await _settle()
	assert_false(viewer._card.text_is_expanded(), "Enter, then keypad Enter: switched twice")
	assert_true(Settings.has_value(FullscreenCard.FULL_TEXT_SETTING), "and kept")


func test_a_right_click_closes_the_reader() -> void:
	await _build(PadControls.OFF)
	assert_true(viewer.open_card(true))
	for down in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_RIGHT
		click.pressed = down
		click.position = get_tree().root.get_final_transform() * Vector2(640, 400)
		click.global_position = click.position
		Input.parse_input_event(click)
	await _settle()
	assert_false(viewer.is_open(), "B on ArkOS (a right click) closes the reader")

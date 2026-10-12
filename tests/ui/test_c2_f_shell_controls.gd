extends GutTest
## OPTIONS → CONTROLS AND THE INPUT MAP (bug campaign 2026-10-12,
## findings r2-3, r2-10, b6-5 and b1-8).
##
##  * r2-3: with the pad pointer on (a Steam Deck in its gamepad layout)
##    the `Press the controller button` popup took the A meant to click
##    its Cancel and bound it: the one button became A, which the pad
##    layer eats, and nothing on the pad could advance the game any more.
##    The layer's own buttons (A, LB, the D-pad) are the pointer's while
##    it is on — not offered, and they reach the pointer.
##  * r2-10: binding a listed action to a digit took that digit off the
##    numbered choice answers for good.
##  * b6-5: `Show invisible effects` was offered for rebinding although
##    its command does nothing yet.
##  * b1-8: ArkOS's Select types F10, a key no text field types, which
##    opens the duel's pause menu and the Deck Builder's menu like Q.

var screen: Control
var layer: Node
var _saved_controls: Variant = null
var _saved_pad: Variant = null


func _keep(key: String) -> Variant:
	return Settings.get_value(key, null) if Settings.has_value(key) else null


func before_each() -> void:
	_saved_controls = _keep(Controls.SETTINGS_KEY)
	_saved_pad = _keep(PadControls.KEY)
	Controls.reset()
	layer = get_tree().root.get_node("PadControls")


func after_each() -> void:
	Controls.reset()
	if _saved_controls != null:
		Settings.set_value(Controls.SETTINGS_KEY, _saved_controls)
		Controls.apply()
	if _saved_pad == null:
		Settings.clear_value(PadControls.KEY)
	else:
		Settings.set_value(PadControls.KEY, _saved_pad, false)
	layer.set_active(false)
	layer.apply_settings()
	await get_tree().process_frame


func _options() -> void:
	screen = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func _named(name: String) -> Node:
	return screen.find_child(name, true, false)


func _parse_pad(button: JoyButton, pressed: bool) -> void:
	var jb := InputEventJoypadButton.new()
	jb.device = 0
	jb.button_index = button
	jb.pressed = pressed
	Input.parse_input_event(jb)


func _key(code: Key) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = true
	return k


# ------------------------------------------------------------- r2-3 --

func test_with_the_pad_pointer_on_a_clicks_the_popups_cancel() -> void:
	layer.choose(PadControls.ON)
	await _options()
	(_named("Pad_duel_space") as Button).pressed.emit()
	await get_tree().process_frame
	var veil := _named("ControlsListener") as Control
	assert_not_null(veil, "the popup is up")
	var cancel := veil.find_child("Cancel", true, false) as Button
	layer._pointer = cancel.get_global_transform_with_canvas() * (cancel.size / 2.0)
	layer._mouse_fresh = true
	_parse_pad(JOY_BUTTON_A, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_parse_pad(JOY_BUTTON_A, false)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(Controls.pad_text("duel_space"), "RB", "Cancel left the one button on RB")
	assert_null(_named("ControlsListener"), "and closed the popup")


func test_with_the_pad_pointer_on_the_pointers_buttons_are_not_bound() -> void:
	layer.choose(PadControls.ON)
	await _options()
	(_named("Pad_duel_hand") as Button).pressed.emit()
	await get_tree().process_frame
	# The pointer rests on the veil, clear of Cancel: A there clicks nothing.
	layer._pointer = Vector2(8, 8)
	layer._mouse_fresh = true
	for button in [JOY_BUTTON_A, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_DPAD_DOWN]:
		_parse_pad(button, true)
		await get_tree().process_frame
		_parse_pad(button, false)
		await get_tree().process_frame
		assert_eq(Controls.pad_text("duel_hand"), "Y", "pad %d is the pointer's, not a binding" % button)
	var veil := _named("ControlsListener") as Control
	assert_not_null(veil, "still listening")
	var said := ""
	for label in veil.find_children("*", "Label", true, false):
		said += (label as Label).text + " "
	assert_string_contains(said, "pointer", "the popup says why those buttons are not taken")
	_parse_pad(JOY_BUTTON_X, true)
	await get_tree().process_frame
	_parse_pad(JOY_BUTTON_X, false)
	await get_tree().process_frame
	assert_eq(Controls.pad_text("duel_hand"), "X", "any other button binds")


func test_with_the_pad_pointer_off_every_button_still_binds() -> void:
	layer.choose(PadControls.OFF)
	await _options()
	(_named("Pad_duel_hand") as Button).pressed.emit()
	var veil := _named("ControlsListener")
	var listener: Node = null
	for node in veil.find_children("*", "Node", true, false):
		if node.has_signal("bound"):
			listener = node
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	a.pressed = true
	listener._input(a)
	await get_tree().process_frame
	assert_eq(Controls.pad_text("duel_hand"), "A", "with no pointer, A is a button like any other")


func test_escape_under_the_pad_popup_is_its_cancel() -> void:
	await _options()
	(_named("Pad_duel_hand") as Button).pressed.emit()
	await get_tree().process_frame
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_null(_named("ControlsListener"), "Escape is no pad button: it cancels the pad popup")
	assert_true(screen.is_inside_tree(), "and leaves Options where it is")
	(_named("Pad_duel_log") as Button).pressed.emit()
	assert_not_null(_named("ControlsListener"), "a slot listens again afterwards")


# ------------------------------------------------------------ r2-10 --

func test_a_digit_tried_on_a_listed_action_does_not_cost_a_choice_key() -> void:
	assert_true(Controls.bind("duel_log", _key(KEY_1)))
	assert_eq(Controls.key_text("duel_choice_1"), "1", "the first choice still answers to 1")
	assert_true(Controls.pressed(_key(KEY_1), "duel_log"), "and 1 opens the log outside a choice")
	assert_eq(Controls.choice_index(_key(KEY_1)), 0, "while a choice list reads it as its first answer")
	Controls.bind("duel_log", _key(KEY_L))
	assert_eq(Controls.key_text("duel_choice_1"), "1")


func test_a_file_that_lost_a_digit_gets_it_back() -> void:
	Settings.set_value(Controls.SETTINGS_KEY, {"duel_choice_3": [], "duel_log": ["key:F6"]})
	Controls.apply()
	assert_eq(Controls.key_text("duel_choice_3"), "3", "the choices are the project's, always")
	assert_eq(Controls.key_text("duel_log"), "F6", "the player's own rows still apply")


# ------------------------------------------------------------- b6-5 --

func test_show_invisible_effects_is_listed_but_not_offered() -> void:
	var entry: Dictionary = {}
	for one in Controls.ACTIONS:
		if one["name"] == "duel_invisible":
			entry = one
	assert_false(Controls.available("duel_invisible"), "the command does nothing yet")
	assert_true(Controls.available("duel_id_tags"))
	assert_string_contains(String(entry["tip"]), "not available yet")
	await _options()
	for slot in ["Key_duel_invisible", "Pad_duel_invisible"]:
		var button := _named(slot) as Button
		assert_true(button.disabled, "%s is greyed" % slot)
	assert_false((_named("Key_duel_id_tags") as Button).disabled)


# ------------------------------------------------------------- b1-8 --

func test_the_handhelds_menu_key_opens_the_pause_menu_and_types_nothing() -> void:
	var f10 := _key(Controls.MENU_KEY)
	assert_true(Controls.pressed(f10, "duel_pause"), "Select (F10) is the pause key")
	assert_false(Controls.pressed(f10, "duel_cancel"))
	assert_eq(f10.unicode, 0, "a key with no character: no text field types it")
	var rebound := _key(KEY_P)
	Controls.bind("duel_pause", rebound)
	assert_true(Controls.pressed(f10, "duel_pause"), "and it stays the pause key after Q moves")
	var stolen := _key(Controls.MENU_KEY)
	assert_false(Controls.bind("duel_log", stolen), "and is not offered to another action")

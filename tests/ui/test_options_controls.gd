extends GutTest
## `[QoL]` CONTROLS ON THE OPTIONS SCREEN — the `Controls:` section of
## `game/options_screen.gd`: one row an action, a key slot and a pad
## slot, the `Press a key` popup behind each slot and `Reset controls`.
##
## Asked for on 2026-09-18 (*"implement also controls in options"*).
## The rows are VIEWS of the input map the way the Display switch is a
## view of its key (`tests/ui/test_options_display.gd`): they show what
## is bound, and a press under the popup binds at once, through
## [Controls], which also writes the file. What these pin:
##
##   1. Every listed action has a row, and the rows say what the map
##      says — `Space` and `A` for the one button, `—` where nothing is.
##   2. A slot opens ONE popup, named for the action, that takes the
##      next press of its kind — a key for the key slot, a pad button
##      for the pad slot, not the other — binds it, and closes.
##   3. Cancel leaves the binding alone; Esc under the popup is a KEY
##      (bindable), not a way out.
##   4. `Reset controls` is the defaults again, and the rows follow.

var screen: Control
var _saved: Variant = null


func before_each() -> void:
	_saved = Settings.get_value(Controls.SETTINGS_KEY, null) \
		if Settings.has_value(Controls.SETTINGS_KEY) else null
	Controls.reset()
	screen = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	Controls.reset()
	if _saved != null:
		Settings.set_value(Controls.SETTINGS_KEY, _saved)
		Controls.apply()


func _walk(node: Node) -> Array:
	var out := [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out


func _named(name: String) -> Node:
	for node in _walk(screen):
		if node.name == name:
			return node
	return null


func _slot(action: String, kind: String) -> Button:
	return _named(("Key_" if kind == "key" else "Pad_") + action) as Button


func _listener_veil() -> Control:
	return _named("ControlsListener") as Control


## The listener node under the popup — the thing that takes the press.
func _listener() -> Node:
	var veil := _listener_veil()
	if veil == null:
		return null
	for node in _walk(veil):
		if node.has_signal("bound"):
			return node
	return null


func _key(code: Key, ctrl := false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.ctrl_pressed = ctrl
	ev.pressed = true
	return ev


func _pad(button: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = true
	return ev


## Every label's text in tree order.
func _label_texts() -> Array[String]:
	var out: Array[String] = []
	for node in _walk(screen):
		if node is Label:
			out.append(node.text)
	return out


# ====================================================== the rows (1) ==

func test_every_listed_action_has_a_row_that_says_what_the_map_says() -> void:
	var texts := _label_texts()
	assert_gte(texts.find("Controls:"), 0, "there is a Controls section")
	for entry in Controls.ACTIONS:
		var action := String(entry["name"])
		assert_gte(texts.find(String(entry["label"])), 0, "%s has its word on a row" % action)
		var key := _slot(action, "key")
		var pad := _slot(action, "pad")
		assert_not_null(key, "%s has a key slot" % action)
		assert_not_null(pad, "%s has a pad slot" % action)
		assert_eq(key.text, Controls.key_text(action), "%s key slot" % action)
		assert_eq(pad.text, Controls.pad_text(action), "%s pad slot" % action)
	assert_eq(_slot("duel_space", "key").text, "Space")
	assert_eq(_slot("duel_space", "pad").text, "RB")
	assert_eq(_slot("duel_id_tags", "key").text, "Ctrl+T")
	assert_eq(_slot("duel_mute", "pad").text, Controls.UNBOUND, "nothing is a dash")
	assert_null(_slot("duel_choice_1", "key"),
		"the digits answer numbered prompts and have no row — nine rows of 1..9 would say nothing")
	assert_not_null(_named("ResetControls"))


func test_the_section_sits_after_display_and_has_its_tip() -> void:
	var texts := _label_texts()
	assert_lt(texts.find("Display:"), texts.find("Controls:"), "the window, then its keys")
	for node in _walk(screen):
		if node is Label and node.text == "Controls:":
			assert_string_contains(node.tooltip_text, "Click a slot")
		if node is Label and node.text == "Show ID tags":
			assert_false(node.tooltip_text.is_empty(), "each action's word carries its tip")


func test_the_rows_open_on_what_is_stored() -> void:
	Settings.set_value(Controls.SETTINGS_KEY, {"duel_mute": ["key:N", "pad:RB"]})
	Controls.apply()
	var fresh: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(fresh)
	await get_tree().process_frame
	var key: Button = null
	var pad: Button = null
	for node in _walk(fresh):
		if node.name == "Key_duel_mute":
			key = node
		if node.name == "Pad_duel_mute":
			pad = node
	assert_eq(key.text, "N")
	assert_eq(pad.text, "RB")


# ===================================================== the popup (2) ==

func test_a_key_slot_listens_for_a_key_binds_it_and_closes() -> void:
	assert_null(_listener_veil(), "no popup until asked")
	_slot("duel_mute", "key").pressed.emit()
	var veil := _listener_veil()
	assert_not_null(veil, "the slot opens the listener popup")
	var words := ""
	for node in _walk(veil):
		if node is Label:
			words += node.text + "\n"
	assert_string_contains(words, "Mute", "named for the action")
	assert_string_contains(words, "(now M)", "and says what is there")
	var listener := _listener()
	assert_not_null(listener)
	listener._input(_key(KEY_N))
	await get_tree().process_frame
	assert_eq(Controls.key_text("duel_mute"), "N", "bound at once")
	assert_eq(_slot("duel_mute", "key").text, "N", "and the row follows")
	assert_eq(_slot("duel_mute", "pad").text, Controls.UNBOUND, "the pad slot is untouched")
	assert_null(_listener_veil(), "the popup is gone")
	assert_eq(Settings.get_value(Controls.SETTINGS_KEY, {}), {"duel_mute": ["key:N"]},
		"and the file remembers")


func test_the_key_slot_ignores_the_pad_and_the_pad_slot_the_keys() -> void:
	_slot("duel_mute", "key").pressed.emit()
	var listener := _listener()
	listener._input(_pad(JOY_BUTTON_A))
	await get_tree().process_frame
	assert_not_null(_listener_veil(), "a pad button is not a key: still listening")
	assert_eq(Controls.pad_text("duel_space"), "RB", "and RB stayed where it was")
	listener._input(_key(KEY_CTRL))
	await get_tree().process_frame
	assert_not_null(_listener_veil(), "a bare modifier is the start of a key, not one")
	listener._input(_key(KEY_N, true))
	await get_tree().process_frame
	assert_null(_listener_veil())
	assert_eq(_slot("duel_mute", "key").text, "Ctrl+N")
	_slot("duel_mute", "pad").pressed.emit()
	listener = _listener()
	listener._input(_key(KEY_K))
	await get_tree().process_frame
	assert_not_null(_listener_veil(), "a key is not a pad button: still listening")
	listener._input(_pad(JOY_BUTTON_RIGHT_SHOULDER))
	await get_tree().process_frame
	assert_null(_listener_veil())
	assert_eq(_slot("duel_mute", "pad").text, "RB")
	assert_eq(_slot("duel_mute", "key").text, "Ctrl+N", "the key slot is untouched")


func test_a_press_moves_the_key_off_the_other_action_and_both_rows_say_so() -> void:
	_slot("duel_mute", "key").pressed.emit()
	_listener()._input(_key(KEY_H))
	await get_tree().process_frame
	assert_eq(_slot("duel_mute", "key").text, "H")
	assert_eq(_slot("duel_hand", "key").text, Controls.UNBOUND, "the hand lost its H")
	assert_eq(_slot("duel_hand", "pad").text, "Y", "and kept its Y")


func test_one_popup_at_a_time() -> void:
	_slot("duel_mute", "key").pressed.emit()
	var first := _listener_veil()
	_slot("duel_log", "key").pressed.emit()
	assert_eq(_listener_veil(), first, "a second slot does not open a second popup")
	var veils := 0
	for node in _walk(screen):
		if node.name == "ControlsListener":
			veils += 1
	assert_eq(veils, 1)


# ===================================================== cancel (3) ==

func test_cancel_leaves_the_binding_alone() -> void:
	_slot("duel_mute", "key").pressed.emit()
	var veil := _listener_veil()
	var cancel: Button = null
	for node in _walk(veil):
		if node is Button and node.name == "Cancel":
			cancel = node
	assert_not_null(cancel, "the popup's one button")
	cancel.pressed.emit()
	await get_tree().process_frame
	assert_null(_listener_veil(), "closed")
	assert_eq(_slot("duel_mute", "key").text, "M", "unchanged")
	assert_false(Settings.has_value(Controls.SETTINGS_KEY), "nothing written")
	_slot("duel_mute", "key").pressed.emit()
	assert_not_null(_listener_veil(), "and the slot listens again afterwards")


func test_escape_under_the_popup_is_a_key_not_a_way_out() -> void:
	_slot("duel_mute", "key").pressed.emit()
	_listener()._input(_key(KEY_ESCAPE))
	await get_tree().process_frame
	assert_null(_listener_veil())
	assert_eq(_slot("duel_mute", "key").text, "Escape", "Esc is now Mute")
	assert_eq(_slot("duel_cancel", "key").text, Controls.UNBOUND, "and left Cancel")


# ======================================================= reset (4) ==

func test_reset_controls_is_the_defaults_again_and_the_rows_follow() -> void:
	_slot("duel_mute", "key").pressed.emit()
	_listener()._input(_key(KEY_H))
	await get_tree().process_frame
	_slot("duel_space", "pad").pressed.emit()
	_listener()._input(_pad(JOY_BUTTON_RIGHT_STICK))
	await get_tree().process_frame
	assert_true(Settings.has_value(Controls.SETTINGS_KEY))
	(_named("ResetControls") as Button).pressed.emit()
	assert_eq(_slot("duel_mute", "key").text, "M")
	assert_eq(_slot("duel_hand", "key").text, "H")
	assert_eq(_slot("duel_space", "pad").text, "RB")
	assert_false(Settings.has_value(Controls.SETTINGS_KEY), "and the file forgets")
	for action in Controls.names():
		assert_true(Controls.is_default(action), "%s is back" % action)

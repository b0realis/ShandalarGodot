extends GutTest
## THE WORLD MAP'S ACTIONS in the input map (campaign 2026-11-26, [constant
## Controls.WORLD_ACTIONS]): declared in `project.godot [input]` like the
## duel's, a second group — its defaults collide with nothing the pad
## pointer owns nor with each other, a binding moves only inside its group,
## the file remembers, and the duel's list is what it was.

var _saved: Variant = null


func before_each() -> void:
	_saved = Settings.get_value(Controls.SETTINGS_KEY, null) \
		if Settings.has_value(Controls.SETTINGS_KEY) else null
	Controls.reset()


func after_each() -> void:
	Controls.reset()
	if _saved != null:
		Settings.set_value(Controls.SETTINGS_KEY, _saved)
		Controls.apply()


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


func test_every_world_action_is_declared_by_the_project() -> void:
	assert_eq(Controls.world_names(), ["world_map", "world_hero", "world_stop", "world_menu",
		"world_confirm", "world_quicksave"] as Array[String])
	for action in Controls.world_names():
		assert_true(InputMap.has_action(action), "%s is in the input map" % action)
		assert_false(Controls.defaults(action).is_empty(), "%s has a default" % action)
		assert_true(Controls.is_default(action), "%s starts as the project says" % action)
		assert_eq(Controls.group_of(action), Controls.WORLD_GROUP)
		assert_ne(String(Controls.entry_of(action).get("label", "")), "", "%s has its word" % action)
	assert_eq(Controls.group_of("duel_done"), Controls.DUEL_GROUP)
	assert_eq(Controls.names().size(), 22, "the duel's own list is what it was")
	assert_eq(Controls.all_names().size(), 28)


func test_the_defaults_are_the_world_s_old_keys_and_the_duel_s_sense() -> void:
	assert_eq(Controls.text("world_map"), "M or Y")
	assert_eq(Controls.text("world_hero"), "F5 or Back")
	assert_eq(Controls.text("world_stop"), "Space or RB")
	assert_eq(Controls.text("world_menu"), "Start")
	assert_eq(Controls.text("world_confirm"), "X")
	assert_eq(Controls.text("world_quicksave"), "Ctrl+S")
	assert_eq(Controls.pad_text("duel_pause"), Controls.pad_text("world_menu"), "Start is the menu in both")
	assert_eq(Controls.pad_text("duel_space"), Controls.pad_text("world_stop"), "RB the one button in both")
	assert_eq(Controls.pad_text("duel_done"), Controls.pad_text("world_confirm"), "X confirms in both")


func test_no_default_collides_inside_a_group_or_with_the_pointer() -> void:
	for group: Array in [Controls.world_names(), Controls.names()]:
		var seen := {}
		for action: String in group:
			if Controls.CHOICES.has(action):
				continue
			for event in Controls.defaults(action):
				if event is InputEventJoypadButton:
					assert_false(Controls.POINTER_BUTTONS.has(event.button_index),
						"%s is not on a button of the pad pointer's" % action)
				# Space and Enter are the engine's own ui_accept beside the duel's.
				var word := Controls.encode(event)
				assert_false(seen.has(word), "%s: %s is on %s already" % [action, word, seen.get(word, "")])
				seen[word] = action
	for button in [PadControls.CLICK_BUTTON, PadControls.MENU_BUTTON]:
		assert_true(Controls.POINTER_BUTTONS.has(button))
	for button in PadControls.HOPS:
		assert_true(Controls.POINTER_BUTTONS.has(button))


func test_an_event_names_its_world_action_exactly() -> void:
	assert_eq(Controls.world_action(_key(KEY_M)), "world_map")
	assert_eq(Controls.world_action(_key(KEY_M, true)), "", "Ctrl+M is not M")
	assert_eq(Controls.world_action(_key(KEY_S, true)), "world_quicksave")
	assert_eq(Controls.world_action(_key(KEY_S)), "", "a bare S saves nothing")
	assert_eq(Controls.world_action(_pad(JOY_BUTTON_Y)), "world_map")
	assert_eq(Controls.world_action(_pad(JOY_BUTTON_START)), "world_menu")
	assert_eq(Controls.world_action(_key(Controls.MENU_KEY)), "world_menu", "a handheld's menu key")
	assert_eq(Controls.world_action(_pad(JOY_BUTTON_A)), "", "A is the pointer's")
	assert_eq(Controls.world_action(InputEventMouseButton.new()), "")
	var echo := _key(KEY_M)
	echo.echo = true
	assert_eq(Controls.world_action(echo), "", "a repeat is no press")


func test_a_binding_moves_inside_its_group_only() -> void:
	assert_true(Controls.bind("world_quicksave", _pad(JOY_BUTTON_Y)))
	assert_eq(Controls.pad_text("world_quicksave"), "Y")
	assert_eq(Controls.pad_text("world_map"), Controls.UNBOUND, "the map lost Y to it")
	assert_eq(Controls.pad_text("duel_hand"), "Y", "the duel's Y is untouched")
	assert_true(Controls.bind("duel_mute", _pad(JOY_BUTTON_BACK)))
	assert_eq(Controls.pad_text("duel_log"), Controls.UNBOUND, "the duel's Back moved in the duel")
	assert_eq(Controls.pad_text("world_hero"), "Back", "the world's Back is untouched")
	assert_false(Controls.bind("world_nothing", _pad(JOY_BUTTON_Y)), "an unknown action binds nothing")


func test_a_rebinding_persists_and_reset_forgets() -> void:
	Controls.bind("world_map", _key(KEY_K))
	Controls.bind("world_quicksave", _pad(JOY_BUTTON_LEFT_STICK))
	var stored: Dictionary = Settings.get_value(Controls.SETTINGS_KEY, {})
	assert_eq(stored, {"world_map": ["pad:Y", "key:K"], "world_quicksave": ["key:Ctrl+S", "pad:L3"]},
		"only what differs is written")
	# A new start: the project's map, then the file laid over it.
	for action in Controls.all_names():
		InputMap.action_erase_events(action)
	Controls.apply()
	assert_eq(Controls.key_text("world_map"), "K")
	assert_eq(Controls.pad_text("world_map"), "Y")
	assert_eq(Controls.pad_text("world_quicksave"), "L3")
	assert_eq(Controls.key_text("duel_done"), "Enter", "the duel's as the project says")
	Controls.reset()
	assert_false(Settings.has_value(Controls.SETTINGS_KEY))
	assert_eq(Controls.text("world_map"), "M or Y")


func test_a_default_key_taken_off_its_action_is_retired() -> void:
	assert_false(Controls.world_key_retired(_key(KEY_M)), "nothing rebound: nothing retired")
	assert_false(Controls.world_key_retired(null))
	Controls.bind("world_map", _key(KEY_K))
	assert_true(Controls.world_key_retired(_key(KEY_M)), "M was the map's and is no more")
	assert_false(Controls.world_key_retired(_key(KEY_K)))
	assert_false(Controls.world_key_retired(_key(KEY_F2)), "F2 was never a listed key")
	Controls.reset()
	Controls.bind("world_hero", _key(KEY_M))
	assert_true(Controls.world_key_retired(_key(KEY_F5)), "F5 left the hero")
	assert_eq(Controls.world_action(_key(KEY_M)), "world_hero", "M is the hero's now")
	assert_eq(Controls.key_text("world_map"), Controls.UNBOUND, "and the map shows the gap")


func test_the_pad_hint_shows_only_with_a_controller() -> void:
	if Input.get_connected_joypads().is_empty():
		assert_eq(Controls.pad_hint("world_map"), "", "no controller: no hint")
	else:
		assert_eq(Controls.pad_hint("world_map"), "  [Y]")
	assert_eq(Controls.pad_hint("world_quicksave"), "", "nothing bound: nothing said")

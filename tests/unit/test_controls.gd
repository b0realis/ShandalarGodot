extends GutTest
## THE INPUT MAP — the duel's keys as actions (`project.godot [input]`,
## [Controls]), the two slots each action has (a key and a controller
## button), the exact-modifier match, the one place a player changes
## them ([method Controls.bind]) and the file that remembers it
## (`Settings.controls`).
##
## Asked for on 2026-09-18: *"implement also controls in options: 8.
## Input map + controller. project.godot has no [input] section; keys
## are hard-coded in duel_screen.gd. Declaring actions is prerequisite
## for rebinding, gamepad, and Steam Deck."*
##
## What these pin, and why:
##
##   1. The project declares every action with the 1997 keys as its
##      defaults — the defaults live in ONE place, `project.godot`, and
##      [Controls] reads them from there rather than keeping a second
##      table that could drift.
##   2. The match is exact: a Ctrl+T action ignores a bare T and a Q
##      action ignores Ctrl+Q. Before the map, the handler tested the
##      modifier by hand; the map must not be looser than that.
##   3. A binding replaces the slot of its kind and leaves the other —
##      a new key for Space keeps the pad's A — and takes the same
##      event off any other action, so one press never does two things.
##   4. The file holds only what differs from the defaults, and nothing
##      when nothing does; `reset` is the defaults again and forgets.
##   5. An old file cannot lose the keyboard: unknown actions and words
##      that no longer decode are skipped.
##   6. The Help page reads the live bindings, not a memory of them.

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


func _key(code: Key, ctrl := false, shift := false, alt := false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.ctrl_pressed = ctrl
	ev.shift_pressed = shift
	ev.alt_pressed = alt
	ev.pressed = true
	return ev


func _pad(button: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = true
	return ev


## What the file on disk says, read fresh — not what Settings remembers.
static func _on_disk() -> Variant:
	var file := ConfigFile.new()
	file.load(Settings.PATH)
	if not file.has_section_key("options", Controls.SETTINGS_KEY):
		return null
	return file.get_value("options", Controls.SETTINGS_KEY)


# ============================================= the project declares (1) ==

func test_the_project_declares_every_action_with_the_1997_keys() -> void:
	var expected := {
		"duel_space": ["Space", "A"],
		"duel_done": ["Enter", "X"],
		"duel_cancel": ["Escape", "B"],
		"duel_pause": ["Q", "Start"],
		"duel_hand": ["H", "Y"],
		"duel_log": ["L", "Back"],
		"duel_mute": ["M", Controls.UNBOUND],
		"duel_id_tags": ["Ctrl+T", Controls.UNBOUND],
		"duel_invisible": ["Ctrl+I", Controls.UNBOUND],
		"duel_sickness": ["Ctrl+U", Controls.UNBOUND],
		"duel_screenshot": ["F12", Controls.UNBOUND],
	}
	assert_eq(Controls.ACTIONS.size(), expected.size(), "the listed actions")
	for entry in Controls.ACTIONS:
		var action := String(entry["name"])
		assert_true(InputMap.has_action(action), "%s is declared" % action)
		assert_true(expected.has(action), "%s is expected" % action)
		assert_eq(Controls.key_text(action), expected[action][0], "%s key" % action)
		assert_eq(Controls.pad_text(action), expected[action][1], "%s pad" % action)
		assert_true(Controls.is_default(action), "%s is as the project declares" % action)
		assert_false(String(entry["label"]).is_empty(), "%s has a word" % action)
		assert_false(String(entry["tip"]).is_empty(), "%s has a tip" % action)
	for i in Controls.CHOICES.size():
		var choice := Controls.CHOICES[i]
		assert_true(InputMap.has_action(choice), "%s is declared" % choice)
		assert_eq(Controls.key_text(choice), str(i + 1), "%s is the digit" % choice)
	assert_eq(Controls.names().size(), 20, "eleven listed actions and nine choices")


func test_done_also_answers_to_the_keypads_enter() -> void:
	# The 1997 handler took both Enters; the map keeps both, and the
	# key slot the rows show is the main one.
	assert_true(Controls.pressed(_key(KEY_ENTER), "duel_done"))
	assert_true(Controls.pressed(_key(KEY_KP_ENTER), "duel_done"))
	assert_eq(Controls.key_text("duel_done"), "Enter")


func test_the_defaults_come_from_project_godot_not_a_second_table() -> void:
	var space := Controls.defaults("duel_space")
	assert_eq(space.size(), 2, "Space and A")
	assert_true(space[0] is InputEventKey and space[0].keycode == KEY_SPACE)
	assert_true(space[1] is InputEventJoypadButton and space[1].button_index == JOY_BUTTON_A)
	assert_eq(Controls.defaults("no_such_action").size(), 0, "an unknown action has none")
	var setting: Variant = ProjectSettings.get_setting("input/duel_space", null)
	assert_true(setting is Dictionary, "the project setting is the source")
	for event in setting["events"]:
		if event is InputEventKey:
			assert_eq(event.physical_keycode, KEY_NONE,
				"the map compares keycodes, so the project declares keycodes")


# ================================================== the exact match (2) ==

func test_a_key_presses_its_action_and_only_its_action() -> void:
	assert_true(Controls.pressed(_key(KEY_SPACE), "duel_space"))
	assert_false(Controls.pressed(_key(KEY_SPACE), "duel_done"))
	assert_true(Controls.pressed(_key(KEY_ESCAPE), "duel_cancel"))
	assert_true(Controls.pressed(_key(KEY_Q), "duel_pause"))
	assert_true(Controls.pressed(_key(KEY_H), "duel_hand"))
	assert_true(Controls.pressed(_key(KEY_L), "duel_log"))
	assert_true(Controls.pressed(_key(KEY_M), "duel_mute"))
	assert_true(Controls.pressed(_key(KEY_F12), "duel_screenshot"))
	assert_false(Controls.pressed(_key(KEY_SPACE), "no_such_action"),
		"an unknown action is never pressed, and never an error")


func test_the_modifiers_must_match_exactly() -> void:
	assert_true(Controls.pressed(_key(KEY_T, true), "duel_id_tags"), "Ctrl+T")
	assert_false(Controls.pressed(_key(KEY_T), "duel_id_tags"), "a bare T is not Ctrl+T")
	assert_false(Controls.pressed(_key(KEY_T, true, true), "duel_id_tags"),
		"Ctrl+Shift+T is not Ctrl+T either")
	assert_true(Controls.pressed(_key(KEY_I, true), "duel_invisible"))
	assert_true(Controls.pressed(_key(KEY_U, true), "duel_sickness"))
	assert_false(Controls.pressed(_key(KEY_Q, true), "duel_pause"), "Ctrl+Q is not Q")
	assert_false(Controls.pressed(_key(KEY_SPACE, false, true), "duel_space"),
		"Shift+Space is not Space")


func test_a_release_or_an_echo_presses_nothing() -> void:
	var up := _key(KEY_SPACE)
	up.pressed = false
	assert_false(Controls.pressed(up, "duel_space"), "a release")
	var echo := _key(KEY_SPACE)
	echo.echo = true
	assert_false(Controls.pressed(echo, "duel_space"), "an echo — holding Space is one press")
	var pad_up := _pad(JOY_BUTTON_A)
	pad_up.pressed = false
	assert_false(Controls.pressed(pad_up, "duel_space"), "a pad release")


func test_the_pad_buttons_press_the_duels_actions() -> void:
	assert_true(Controls.pressed(_pad(JOY_BUTTON_A), "duel_space"), "A is the one button")
	assert_true(Controls.pressed(_pad(JOY_BUTTON_X), "duel_done"))
	assert_true(Controls.pressed(_pad(JOY_BUTTON_B), "duel_cancel"))
	assert_true(Controls.pressed(_pad(JOY_BUTTON_START), "duel_pause"))
	assert_true(Controls.pressed(_pad(JOY_BUTTON_Y), "duel_hand"))
	assert_true(Controls.pressed(_pad(JOY_BUTTON_BACK), "duel_log"))
	assert_false(Controls.pressed(_pad(JOY_BUTTON_A), "duel_done"), "A is not X")
	assert_false(Controls.pressed(_pad(JOY_BUTTON_RIGHT_SHOULDER), "duel_space"),
		"a shoulder is nothing by default")


func test_choice_index_is_the_digit_less_one() -> void:
	assert_eq(Controls.choice_index(_key(KEY_1)), 0)
	assert_eq(Controls.choice_index(_key(KEY_5)), 4)
	assert_eq(Controls.choice_index(_key(KEY_9)), 8)
	assert_eq(Controls.choice_index(_key(KEY_0)), -1, "there is no tenth answer")
	assert_eq(Controls.choice_index(_key(KEY_1, true)), -1, "Ctrl+1 is not 1")
	assert_eq(Controls.choice_index(_key(KEY_SPACE)), -1)
	assert_eq(Controls.choice_index(_pad(JOY_BUTTON_A)), -1, "the pad has no digits")


# ======================================================== binding (3) ==

func test_a_key_replaces_the_key_and_keeps_the_pad() -> void:
	assert_true(Controls.bind("duel_space", _key(KEY_K)))
	assert_eq(Controls.key_text("duel_space"), "K")
	assert_eq(Controls.pad_text("duel_space"), "A", "the pad slot is untouched")
	assert_true(Controls.pressed(_key(KEY_K), "duel_space"))
	assert_false(Controls.pressed(_key(KEY_SPACE), "duel_space"), "Space is gone")
	assert_true(Controls.pressed(_pad(JOY_BUTTON_A), "duel_space"), "A still is")
	assert_false(Controls.is_default("duel_space"))


func test_a_pad_button_replaces_the_pad_button_and_keeps_the_key() -> void:
	assert_true(Controls.bind("duel_mute", _pad(JOY_BUTTON_RIGHT_SHOULDER)))
	assert_eq(Controls.key_text("duel_mute"), "M")
	assert_eq(Controls.pad_text("duel_mute"), "RB")
	assert_true(Controls.pressed(_pad(JOY_BUTTON_RIGHT_SHOULDER), "duel_mute"))
	assert_true(Controls.bind("duel_mute", _pad(JOY_BUTTON_LEFT_SHOULDER)))
	assert_eq(Controls.pad_text("duel_mute"), "LB", "one pad slot: the new one replaces it")
	assert_false(Controls.pressed(_pad(JOY_BUTTON_RIGHT_SHOULDER), "duel_mute"))


func test_a_binding_takes_the_same_event_off_any_other_action() -> void:
	assert_true(Controls.bind("duel_mute", _key(KEY_H)))
	assert_eq(Controls.key_text("duel_mute"), "H")
	assert_eq(Controls.key_text("duel_hand"), Controls.UNBOUND, "H left the hand")
	assert_eq(Controls.pad_text("duel_hand"), "Y", "but the hand keeps its Y")
	assert_true(Controls.pressed(_key(KEY_H), "duel_mute"))
	assert_false(Controls.pressed(_key(KEY_H), "duel_hand"), "one press, one action")
	assert_true(Controls.bind("duel_log", _pad(JOY_BUTTON_A)))
	assert_eq(Controls.pad_text("duel_space"), Controls.UNBOUND, "A left the one button")
	assert_eq(Controls.key_text("duel_space"), "Space", "which keeps its Space")


func test_the_choices_are_actions_too_and_a_digit_moves_like_any_key() -> void:
	assert_true(Controls.bind("duel_mute", _key(KEY_3)))
	assert_eq(Controls.choice_index(_key(KEY_3)), -1, "3 answers nothing now")
	assert_eq(Controls.key_text("duel_choice_3"), Controls.UNBOUND)
	Controls.reset()
	assert_eq(Controls.choice_index(_key(KEY_3)), 2, "and reset gives it back")


func test_the_binding_carries_the_modifiers() -> void:
	assert_true(Controls.bind("duel_mute", _key(KEY_M, true, true)))
	assert_eq(Controls.key_text("duel_mute"), "Ctrl+Shift+M")
	assert_true(Controls.pressed(_key(KEY_M, true, true), "duel_mute"))
	assert_false(Controls.pressed(_key(KEY_M), "duel_mute"), "the bare M is not the binding")
	assert_false(Controls.pressed(_key(KEY_M, true), "duel_mute"))


func test_what_cannot_be_a_binding_is_refused() -> void:
	assert_false(Controls.bindable(_key(KEY_CTRL)), "a modifier on its own")
	assert_false(Controls.bindable(_key(KEY_SHIFT)))
	assert_false(Controls.bindable(_key(KEY_NONE)), "no key at all")
	var up := _key(KEY_K)
	up.pressed = false
	assert_false(Controls.bindable(up), "a release")
	var echo := _key(KEY_K)
	echo.echo = true
	assert_false(Controls.bindable(echo), "an echo")
	var pad_up := _pad(JOY_BUTTON_A)
	pad_up.pressed = false
	assert_false(Controls.bindable(pad_up), "a pad release")
	assert_false(Controls.bindable(InputEventMouseButton.new()), "the mouse is not a binding")
	assert_true(Controls.bindable(_key(KEY_K)))
	assert_true(Controls.bindable(_key(KEY_ESCAPE)), "Escape is a key like any other")
	assert_true(Controls.bindable(_pad(JOY_BUTTON_A)))
	assert_false(Controls.bind("duel_space", _key(KEY_CTRL)), "and bind says no")
	assert_false(Controls.bind("no_such_action", _key(KEY_K)), "as for an unknown action")
	assert_true(Controls.is_default("duel_space"), "nothing changed")
	assert_false(Settings.has_value(Controls.SETTINGS_KEY), "and nothing was written")


func test_the_binding_is_a_copy_that_is_not_a_press() -> void:
	# The map holds the KEY; an event that was pressed at the moment it
	# was bound must not press its action forever.
	var ev := _key(KEY_K)
	assert_true(Controls.bind("duel_mute", ev))
	var bound := Controls.key_of("duel_mute")
	assert_false(bound.pressed, "stored released")
	assert_eq(bound.device, -1, "from any keyboard")
	ev.keycode = KEY_J
	assert_eq(Controls.key_text("duel_mute"), "K", "a copy, not the caller's event")


# ======================================================== the file (4) ==

func test_the_file_holds_only_what_differs_from_the_defaults() -> void:
	assert_false(Settings.has_value(Controls.SETTINGS_KEY), "nothing to say at first")
	assert_true(Controls.bind("duel_mute", _key(KEY_N)))
	var stored: Dictionary = Settings.get_value(Controls.SETTINGS_KEY, {})
	assert_eq(stored, {"duel_mute": ["key:N"]}, "one action, in words")
	assert_eq(_on_disk(), {"duel_mute": ["key:N"]}, "on disk at once")
	assert_true(Controls.bind("duel_space", _pad(JOY_BUTTON_RIGHT_SHOULDER)))
	stored = Settings.get_value(Controls.SETTINGS_KEY, {})
	assert_eq(stored, {"duel_mute": ["key:N"], "duel_space": ["key:Space", "pad:RB"]},
		"both slots of a changed action, in the map's order")


func test_binding_the_default_back_forgets_the_action() -> void:
	assert_true(Controls.bind("duel_mute", _key(KEY_N)))
	assert_true(Settings.has_value(Controls.SETTINGS_KEY))
	assert_true(Controls.bind("duel_mute", _key(KEY_M)))
	assert_true(Controls.is_default("duel_mute"))
	assert_false(Settings.has_value(Controls.SETTINGS_KEY),
		"the file says nothing when nothing differs")
	assert_null(_on_disk())


func test_reset_is_the_defaults_again_and_forgets() -> void:
	assert_true(Controls.bind("duel_mute", _key(KEY_H)))
	assert_true(Controls.bind("duel_log", _pad(JOY_BUTTON_A)))
	assert_false(Controls.is_default("duel_hand"), "H moved off the hand")
	Controls.reset()
	for action in Controls.names():
		assert_true(Controls.is_default(action), "%s is back" % action)
	assert_false(Settings.has_value(Controls.SETTINGS_KEY))
	assert_true(Controls.pressed(_key(KEY_H), "duel_hand"))
	assert_true(Controls.pressed(_pad(JOY_BUTTON_A), "duel_space"))


func test_apply_lays_a_stored_file_over_the_defaults() -> void:
	Settings.set_value(Controls.SETTINGS_KEY, {
		"duel_log": ["key:Ctrl+L", "pad:RB"],
		"duel_mute": [],
	})
	Controls.apply()
	assert_eq(Controls.key_text("duel_log"), "Ctrl+L")
	assert_eq(Controls.pad_text("duel_log"), "RB")
	assert_true(Controls.pressed(_key(KEY_L, true), "duel_log"))
	assert_false(Controls.pressed(_key(KEY_L), "duel_log"))
	assert_eq(Controls.key_text("duel_mute"), Controls.UNBOUND, "an empty list is unbound")
	assert_eq(Controls.text("duel_mute"), Controls.UNBOUND)
	assert_true(Controls.is_default("duel_space"), "an action the file does not name is the default")


func test_an_old_file_cannot_lose_the_keyboard() -> void:
	Settings.set_value(Controls.SETTINGS_KEY, {
		"duel_teleport": ["key:X"],        # an action that no longer exists
		"duel_mute": ["key:NoSuchKey", "pad:Button 7", "flute:F"],
		"duel_pause": 42,                  # not even a list
	})
	Controls.apply()
	assert_false(InputMap.has_action("duel_teleport"), "an unknown action is not created")
	assert_eq(Controls.key_text("duel_mute"), Controls.UNBOUND,
		"a word that does not decode is skipped")
	assert_eq(Controls.pad_text("duel_mute"), "L3", "and the one that does is kept")
	assert_true(Controls.pressed(_key(KEY_SPACE), "duel_space"), "the keyboard still works")
	assert_true(Controls.pressed(_key(KEY_Q), "duel_pause"),
		"a value that is not a list leaves the defaults")


# ======================================================== the words --

func test_encode_and_decode_round_trip() -> void:
	var events: Array[InputEvent] = [
		_key(KEY_T, true), _key(KEY_KP_ENTER), _key(KEY_F12), _key(KEY_K, false, true, true),
		_key(KEY_SPACE), _key(KEY_ESCAPE), _pad(JOY_BUTTON_A), _pad(JOY_BUTTON_START),
		_pad(JOY_BUTTON_DPAD_LEFT), _pad(JOY_BUTTON_TOUCHPAD), _pad(25 as JoyButton),
	]
	var words: Array[String] = []
	for event in events:
		var word := Controls.encode(event)
		words.append(word)
		var back := Controls.decode(word)
		assert_not_null(back, "%s decodes" % word)
		assert_true(Controls._same(event, back), "%s is the same event again" % word)
		assert_eq(Controls.encode(back), word, "and encodes to the same word")
	# The OS calls Alt Option on macOS; the event round-trip above is identical.
	var alt_name := "Option" if OS.has_feature("macos") else "Alt"
	assert_eq(words, ["key:Ctrl+T", "key:Kp Enter", "key:F12", "key:%s+Shift+K" % alt_name,
		"key:Space", "key:Escape", "pad:A", "pad:Start", "pad:D-pad left", "pad:Touchpad",
		"pad:Button 25"] as Array[String])
	assert_null(Controls.decode("key:NoSuchKey"))
	assert_null(Controls.decode("pad:NoSuchButton"))
	assert_null(Controls.decode("flute:F"))
	assert_null(Controls.decode(""))
	assert_eq(Controls.encode(InputEventMouseButton.new()), "", "the mouse has no word")


func test_the_players_words_for_the_bindings() -> void:
	assert_eq(Controls.describe(_key(KEY_T, true)), "Ctrl+T")
	assert_eq(Controls.describe(_key(KEY_KP_ENTER)), "Kp Enter")
	assert_eq(Controls.describe(_pad(JOY_BUTTON_GUIDE)), "Guide")
	assert_eq(Controls.text("duel_space"), "Space or A", "both slots for a sentence")
	assert_eq(Controls.text("duel_mute"), "M", "one slot alone")
	assert_eq(Controls.hint("duel_space"), "  [Space]", "the tooltip's hint is the key")
	assert_eq(Controls.hint("duel_cancel"), "  [Escape]")
	assert_true(Controls.bind("duel_log", _pad(JOY_BUTTON_A)))
	assert_eq(Controls.text("duel_log"), "L or A")
	assert_true(Controls.bind("duel_mute", _key(KEY_L)))
	assert_eq(Controls.text("duel_log"), "A", "the pad alone when the key moved")
	assert_eq(Controls.hint("duel_log"), "", "and no hint without a key")
	var physical := InputEventKey.new()
	physical.physical_keycode = KEY_W
	assert_eq(Controls.describe(physical), "W", "a physical key still has a name")


# ======================================================= the help (6) ==

func test_the_help_page_reads_the_live_bindings() -> void:
	var before := _keys_handy()
	assert_true(before.begins_with("Enter: Done · Escape: Cancel · Space: press the sole available action button."),
		"the 1997 keys, as the page always said: %s" % before)
	assert_string_contains(before, "On a controller A is that button, X is Done, B is Cancel and Start opens the pause menu.")
	assert_string_contains(before, "Options, Controls")
	assert_true(Controls.bind("duel_done", _key(KEY_D)))
	assert_true(Controls.bind("duel_space", _pad(JOY_BUTTON_RIGHT_SHOULDER)))
	var after := _keys_handy()
	assert_true(after.begins_with("D: Done · Escape: Cancel · Space:"), "the new key: %s" % after)
	assert_string_contains(after, "On a controller RB is that button")


## The `Keep these keys handy` text of the Dueling Table page.
func _keys_handy() -> String:
	for page in HelpPages.pages():
		if page["title"] != "The Dueling Table":
			continue
		var blocks: Array = page["blocks"]
		for i in blocks.size():
			if blocks[i].get("text", "") == "Keep these keys handy":
				return String(blocks[i + 1]["text"])
	return ""

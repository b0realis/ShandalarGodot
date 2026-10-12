extends GutTest
## THE HELP SCREEN'S KEYS AND A FEW OF ITS SENTENCES (bug campaign
## 2026-10-12, findings r2-1, r2-9, b6-5, b6-10, b6-11).
##
##  * Escape on Help (the R36's Start, the Quest's back gesture) left for
##    the title and then marked the key handled on a screen that had no
##    viewport any more: a SCRIPT ERROR on every Escape.
##  * With the pad pointer off, Help read keyboard keycodes only: the
##    D-pad and pad B did nothing, and nothing held the focus ring.
##  * A handful of sentences said what the build does not do.

var _was: Node = null
var _saved_pad: Variant = null
var _saved_controls: Variant = null


func _keep(key: String) -> Variant:
	return Settings.get_value(key, null) if Settings.has_value(key) else null


func before_each() -> void:
	_was = get_tree().current_scene
	_saved_pad = _keep(PadControls.KEY)
	_saved_controls = _keep(Controls.SETTINGS_KEY)
	Settings.set_value(PadControls.KEY, PadControls.OFF, false)
	PadControls.apply_settings()


func after_each() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var scene := get_tree().current_scene
	if scene != null and scene != _was and scene.scene_file_path == "res://game/main.tscn":
		scene.queue_free()
	get_tree().current_scene = _was if is_instance_valid(_was) else null
	if _saved_pad == null:
		Settings.clear_value(PadControls.KEY)
	else:
		Settings.set_value(PadControls.KEY, _saved_pad, false)
	PadControls.set_active(false)
	PadControls.apply_settings()
	Controls.reset()
	if _saved_controls != null:
		Settings.set_value(Controls.SETTINGS_KEY, _saved_controls)
		Controls.apply()
	get_viewport().gui_release_focus()
	await get_tree().process_frame


func _open_as_scene() -> Control:
	var screen: Control = load("res://game/help/help_screen.tscn").instantiate()
	get_tree().root.add_child(screen)
	get_tree().current_scene = screen
	await get_tree().process_frame
	return screen


func _pad(button: JoyButton) -> InputEventJoypadButton:
	var jb := InputEventJoypadButton.new()
	jb.device = 0
	jb.button_index = button
	jb.pressed = true
	return jb


# ------------------------------------------------------------- r2-1 --

func test_escape_leaves_help_for_the_title_without_a_script_error() -> void:
	var screen := await _open_as_scene()
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	screen._input(esc)
	assert_false(screen.is_inside_tree(), "the screen left for the title")
	await get_tree().process_frame
	assert_eq(get_tree().current_scene.scene_file_path, "res://game/main.tscn")
	if is_instance_valid(screen):
		screen.queue_free()


func test_pad_b_leaves_help_too() -> void:
	var screen := await _open_as_scene()
	screen._input(_pad(JOY_BUTTON_B))
	assert_false(screen.is_inside_tree(), "pad B (ui_cancel) is Help's Close")
	await get_tree().process_frame
	if is_instance_valid(screen):
		screen.queue_free()


# ------------------------------------------------------------- r2-9 --

func test_the_d_pad_turns_pages_with_the_pad_pointer_off() -> void:
	var screen: HelpScreen = load("res://game/help/help_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.go_to(1)
	screen._input(_pad(JOY_BUTTON_DPAD_RIGHT))
	assert_eq(screen.current_page(), 2, "D-pad right turns forward")
	screen._input(_pad(JOY_BUTTON_DPAD_LEFT))
	assert_eq(screen.current_page(), 1, "D-pad left turns back")


func test_with_the_pad_pointer_on_the_d_pad_is_the_pointers() -> void:
	PadControls.choose(PadControls.ON)
	var screen: HelpScreen = load("res://game/help/help_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.go_to(1)
	screen._input(_pad(JOY_BUTTON_DPAD_RIGHT))
	assert_eq(screen.current_page(), 1, "the D-pad hops the pad pointer, it does not turn the page")


func test_help_opens_with_the_ring_on_its_contents() -> void:
	var screen: HelpScreen = load("res://game/help/help_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var focus := get_viewport().gui_get_focus_owner()
	assert_not_null(focus, "something on Help holds the ring")
	assert_true(focus != null and screen.is_ancestor_of(focus), "and it is Help's")
	assert_true(focus is Button and String((focus as Button).name).begins_with("HelpTopic"),
		"the first topic of the contents (focus=%s)" % focus)


func test_the_ring_stays_on_help_after_a_topic_is_chosen() -> void:
	var screen: HelpScreen = load("res://game/help/help_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var topic := get_viewport().gui_get_focus_owner() as Button
	assert_not_null(topic)
	topic.pressed.emit()
	await get_tree().process_frame
	assert_ne(screen.current_page(), 0, "the topic opened its page")
	var focus := get_viewport().gui_get_focus_owner()
	assert_true(focus != null and screen.is_ancestor_of(focus),
		"the ring is still on Help after its button left with the page (focus=%s)" % focus)


# ------------------------------------------------- the words (b6-*) --

func _page_text(title: String) -> String:
	for page: Dictionary in HelpPages.pages():
		if String(page.get("title", "")) != title:
			continue
		var words := PackedStringArray()
		for block: Dictionary in page.get("blocks", []):
			words.append(String(block.get("text", "")))
			for entry: Dictionary in block.get("entries", []):
				words.append(String(entry.get("name", "")) + " " + String(entry.get("text", "")))
		return " ".join(words)
	return ""


func test_the_tapped_entry_names_the_1997_rule_for_artifacts() -> void:
	var page := _page_text("Icons — the small card")
	assert_false(page.contains("non-creature artifact stops working entirely."),
		"under the default rules a tapped artifact keeps working")
	assert_string_contains(page, "Tapped artifacts stop working",
		"the switch that makes it stop is named")


func test_the_mana_page_sends_the_player_to_options() -> void:
	var page := _page_text("Mana — the fuel of every spell")
	assert_false(page.contains("in Settings"), "there is no Settings screen")
	assert_string_contains(page, "Options")


func test_the_combat_bar_page_promises_no_done_on_a_mini_menu() -> void:
	var page := _page_text("Icons — the Combat Bar")
	assert_false(page.contains("and the mini-menu"), "no duel mini-menu has a Done entry")


func test_the_mana_symbol_count_is_the_symbols_listed() -> void:
	var page := _page_text("Icons — the mana symbols")
	assert_false(page.contains("nineteen symbols"))
	assert_string_contains(page, "eighteen symbols")
	assert_eq(ManaIcons.CELL.size(), 18, "the eighteen the page lists")


func test_the_hotseat_page_names_the_hand_key_that_is_bound() -> void:
	var f7 := InputEventKey.new()
	f7.keycode = KEY_F7
	f7.pressed = true
	assert_true(Controls.bind("duel_hand", f7))
	var page := _page_text("The Dueling Table")
	assert_string_contains(page, "Hide hand (or F7", "the hotseat line names the bound key")
	assert_false(page.contains("(or H)"))

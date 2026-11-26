extends GutTest
## OPTIONS › CONTROLS SAYS HOW THE WORLD MAP IS PLAYED (campaign 2026-11-26;
## a player: *"I've looked all over the options and can't find anything
## related to 'classic arrow movement' or controller support"*): a second
## group titled `World map:` under the duel's rows — plain lines that are
## always true (the arrows, the click, the D-pad, the stick and A), then a
## row an action, rebound like the duel's — and the world's Help page and
## the handhelds guide say the same.

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


func _label_texts() -> Array[String]:
	var out: Array[String] = []
	for node in _walk(screen):
		if node is Label:
			out.append(node.text)
	return out


func _listener() -> Node:
	var veil := _named("ControlsListener")
	if veil == null:
		return null
	for node in _walk(veil):
		if node.has_signal("bound"):
			return node
	return null


func test_the_world_map_group_stands_under_the_duel_s_rows() -> void:
	var texts := _label_texts()
	var at := texts.find("World map:")
	assert_gt(at, texts.find("Controls:"), "after the Controls title")
	assert_gt(at, texts.find("Screenshot"), "and after the duel's last row")
	var last_line := -1
	var lines: Array = screen.WORLD_WALK_LINES
	assert_eq(lines.size(), 4)
	for line: String in lines:
		var found := texts.find(line)
		assert_gt(found, at, "said under the title: " + line)
		last_line = maxi(last_line, found)
	var said := " ".join(lines)
	for words in ["Arrow keys or the keypad walk", "two keys walk a diagonal", "finds the way around water",
			"the D-pad walks your hero", "the left stick moves the pointer and A walks there"]:
		assert_string_contains(said, words)
	for entry in Controls.WORLD_ACTIONS:
		var action := String(entry["name"])
		assert_gt(texts.find(String(entry["label"])), last_line, "%s has a row under the lines" % action)
		var key := _named("Key_" + action) as Button
		var pad := _named("Pad_" + action) as Button
		assert_not_null(key)
		assert_not_null(pad)
		if key == null or pad == null:
			continue
		assert_eq(key.text, Controls.key_text(action))
		assert_eq(pad.text, Controls.pad_text(action))
		assert_false(key.disabled)
	assert_eq((_named("Pad_world_map") as Button).text, "Y")
	assert_eq((_named("Key_world_menu") as Button).text, Controls.UNBOUND)
	var reset := _named("ResetControls") as Control
	var head := _named("WorldControlsHead") as Control
	assert_gt(reset.get_index(), head.get_index(), "Reset controls ends both groups")


func test_a_world_row_rebinds_like_a_duel_s_and_reset_restores() -> void:
	(_named("Pad_world_quicksave") as Button).pressed.emit()
	var veil := _named("ControlsListener")
	assert_not_null(veil, "the slot opens the listener")
	var words := ""
	for node in _walk(veil):
		if node is Label:
			words += node.text + "\n"
	assert_string_contains(words, "Quicksave", "named for the action")
	var listener := _listener()
	var l3 := InputEventJoypadButton.new()
	l3.button_index = JOY_BUTTON_LEFT_STICK
	l3.pressed = true
	listener._input(l3)
	await get_tree().process_frame
	assert_eq(Controls.pad_text("world_quicksave"), "L3", "bound at once")
	assert_eq((_named("Pad_world_quicksave") as Button).text, "L3", "and the row follows")
	assert_null(_named("ControlsListener"))
	# The duel's Y for the world's map: both keep it.
	(_named("Pad_world_hero") as Button).pressed.emit()
	var y := InputEventJoypadButton.new()
	y.button_index = JOY_BUTTON_Y
	y.pressed = true
	_listener()._input(y)
	await get_tree().process_frame
	assert_eq((_named("Pad_world_hero") as Button).text, "Y")
	assert_eq((_named("Pad_world_map") as Button).text, Controls.UNBOUND, "the map's row shows the gap")
	assert_eq((_named("Pad_duel_hand") as Button).text, "Y", "the duel's hand keeps its Y")
	(_named("ResetControls") as Button).pressed.emit()
	assert_eq((_named("Pad_world_map") as Button).text, "Y", "reset: the defaults, the rows follow")
	assert_eq((_named("Pad_world_quicksave") as Button).text, Controls.UNBOUND)
	assert_false(Settings.has_value(Controls.SETTINGS_KEY))


func test_the_help_page_and_the_guide_say_the_same() -> void:
	var page: Dictionary = HelpPages._page_adventure_world()
	var words := ""
	for block: Dictionary in page["blocks"]:
		words += String(block.get("text", "")) + "\n"
	assert_string_contains(words, "With a controller")
	assert_string_contains(words, "The D-pad walks your hero as the arrow keys do")
	assert_string_contains(words, "Y opens the map, Back your hero's pane")
	assert_string_contains(words, "Start the options")
	assert_string_contains(words, "RB stops the walk")
	assert_string_contains(words, "Click where your hero should go", "the page it always was")
	var guide := FileAccess.get_file_as_string("res://docs/handhelds.md")
	if guide == "":
		pending("the guide is not in this build")
		return
	for said in ["Walks the hero as the arrow keys do", "| Y | The map (M)", "| Start | The options menu",
			"| RB | Stops the walk", "| X | First choice", "under *World map*"]:
		assert_string_contains(guide, said)

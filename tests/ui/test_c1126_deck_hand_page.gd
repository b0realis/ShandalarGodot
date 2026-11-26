extends GutTest
## Campaign 2026-11-26, bugs2 #2: after "1000 hands" the Hand page went on
## describing the one hidden hand above the table — "Turn 3 — after 1
## mulligan", its count line, and the orange no-land advice.

var screen: DeckBuilderScreen
var _had_layout_setting: bool
var _old_layout_setting: Variant


func before_each() -> void:
	_had_layout_setting = Settings.has_value(DeckBuilderScreen.BIG_CARDS_SETTING)
	_old_layout_setting = Settings.get_value(DeckBuilderScreen.BIG_CARDS_SETTING, true)
	Settings.set_value(DeckBuilderScreen.BIG_CARDS_SETTING, false, false)
	CardRegistry.ensure_loaded()
	screen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)


func after_each() -> void:
	if _had_layout_setting:
		Settings.set_value(DeckBuilderScreen.BIG_CARDS_SETTING, _old_layout_setting)
	else:
		Settings.clear_value(DeckBuilderScreen.BIG_CARDS_SETTING)


func _walk(node: Node) -> Array:
	var out := [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out


func _said() -> String:
	var out := PackedStringArray()
	for node in _walk(screen._stats_pages):
		if node is Label:
			out.append(String((node as Label).text).strip_edges())
	return "\n".join(out)


func _button(text_prefix: String) -> Button:
	for node in _walk(screen._stats_pages):
		if node is Button and String((node as Button).text).begins_with(text_prefix):
			return node as Button
	return null


func test_the_one_hand_s_lines_leave_with_its_cards() -> void:
	# No land at all: the one hand earns the advice line.
	for i in 40:
		screen.deck.add("Grizzly Bears")
	screen._run_command("Stats")
	var tabs := screen._stats_pages.get_parent().get_parent().get_child(0) as HBoxContainer
	screen._show_stats_page(5, tabs)
	_button("Mulligan").pressed.emit()
	_button("Next turn").pressed.emit()
	_button("Next turn").pressed.emit()
	var before := _said()
	assert_string_contains(before, "Turn 3")
	assert_string_contains(before, "after 1 mulligan")
	assert_string_contains(before, "in the library.")
	assert_string_contains(before, "No land in hand")
	(screen._stats_pages.find_child("StatsThousandHands", true, false) as Button).pressed.emit()
	var counted := _said()
	assert_string_contains(counted, "1000 opening hands of 7, dealt and counted")
	for words in ["Turn 3", "mulligan", "in the library.", "No land in hand", "1997 rule"]:
		assert_false(counted.contains(words), "'%s' is the one hand's, not the thousand's" % words)
	# The buttons stay, and a new hand brings its own lines back.
	assert_not_null(_button("Mulligan"))
	_button("New hand").pressed.emit()
	var after := _said()
	assert_string_contains(after, "Turn 1")
	assert_string_contains(after, "7 cards in hand, 0 lands;  33 in the library.")
	assert_string_contains(after, "No land in hand")

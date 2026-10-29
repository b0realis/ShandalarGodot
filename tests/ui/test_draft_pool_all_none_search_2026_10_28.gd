extends GutTest
## THE DRAFT POOL'S All AND None ACT ON WHAT THE SEARCH SHOWS (owner,
## 2026-10-28, round "open items": *"Draft pool All/None: act on what the
## search shows"*). They used to set the whole pool whatever the finder
## held, so "find Bolt, None" emptied every set. Now they check or uncheck
## the cards the search leaves in view and leave every hidden choice as it
## was; with the finder empty every card is in view, as before.

var _had_selection := false
var _old_selection: Variant = null


func before_each() -> void:
	CardRegistry.ensure_loaded()
	_had_selection = Settings.has_value(DraftPoolConfig.SETTING)
	_old_selection = Settings.get_value(DraftPoolConfig.SETTING, [])
	Settings.clear_value(DraftPoolConfig.SETTING)


func after_each() -> void:
	if _had_selection:
		Settings.set_value(DraftPoolConfig.SETTING, _old_selection, false)
	else:
		Settings.clear_value(DraftPoolConfig.SETTING)


func _dialog() -> DraftPoolDialog:
	var panel := DraftPoolDialog.new()
	add_child_autofree(panel)
	await get_tree().process_frame
	return panel


## The buttons as a player meets them: found by their text on the window.
func _button(panel: DraftPoolDialog, text: String) -> Button:
	for button in panel.find_children("*", "Button", true, false):
		if (button as Button).text == text:
			return button
	return null


func _press(panel: DraftPoolDialog, text: String) -> void:
	var button := _button(panel, text)
	assert_not_null(button, "the %s button" % text)
	if button != null:
		button.pressed.emit()


func _type(panel: DraftPoolDialog, typed: String) -> void:
	# By its placeholder: the Tree keeps an editor LineEdit of its own.
	var field: LineEdit = null
	for edit in panel.find_children("*", "LineEdit", true, false):
		if (edit as LineEdit).placeholder_text.begins_with("Find a card"):
			field = edit
	assert_not_null(field, "the finder")
	if field != null:
		field.text = typed
		field.text_changed.emit(typed)


func test_none_unchecks_only_the_cards_the_search_shows() -> void:
	var panel: DraftPoolDialog = await _dialog()
	var everything := panel.rows.size()
	assert_eq(panel.selected_cards.size(), everything, "an unsaved pool is every card")
	_type(panel, "Lightning Bolt")
	_press(panel, "None")
	assert_false(panel.selected_cards.has("Lightning Bolt"), "the card in view goes")
	assert_true(panel.selected_cards.has("Mountain"), "a hidden card stays checked")
	assert_true(panel.selected_cards.has("Llanowar Elves"), "and another")
	assert_false((panel.rows["Lightning Bolt"] as TreeItem).is_checked(0))
	assert_true((panel.rows["Mountain"] as TreeItem).is_checked(0))
	assert_eq(panel.selected_cards.size(), everything - 1,
		"exactly the one card the finder showed")


func test_all_checks_only_the_cards_the_search_shows() -> void:
	var panel: DraftPoolDialog = await _dialog()
	_press(panel, "None")
	assert_true(panel.selected_cards.is_empty(), "an empty finder shows every card: None clears all")
	_type(panel, "Basic lands")
	_press(panel, "All")
	var basics: Array = []
	for row in (panel.groups[DraftPoolDialog.BASICS_GROUP] as TreeItem).get_children():
		basics.append(String(row.get_metadata(0)["card"]))
	assert_eq(basics.size(), 5, "the five basic lands, found by their group's name")
	for land in basics:
		assert_true(panel.selected_cards.has(land), land)
	assert_eq(panel.selected_cards.size(), basics.size(),
		"nothing the search hid was checked")
	assert_false(panel.selected_cards.has("Lightning Bolt"))


func test_a_reprint_shown_under_one_set_is_one_choice() -> void:
	# The choice is the NAME: a card the search shows under any of its
	# sets is in view, and its rows under the other sets follow it.
	var panel: DraftPoolDialog = await _dialog()
	_press(panel, "None")
	_type(panel, "Lightning Bolt")
	_press(panel, "All")
	assert_eq(panel.selected_cards.keys(), ["Lightning Bolt"])
	for row: TreeItem in panel.name_rows["Lightning Bolt"]:
		assert_true(row.is_checked(0), "every row of the name")


func test_an_empty_search_still_means_every_card() -> void:
	var panel: DraftPoolDialog = await _dialog()
	var everything := panel.rows.size()
	_type(panel, "Bolt")
	_type(panel, "")
	_press(panel, "None")
	assert_true(panel.selected_cards.is_empty())
	_press(panel, "All")
	assert_eq(panel.selected_cards.size(), everything)


func test_a_search_that_shows_nothing_changes_nothing() -> void:
	var panel: DraftPoolDialog = await _dialog()
	var everything := panel.rows.size()
	_type(panel, "no card is called this")
	_press(panel, "None")
	assert_eq(panel.selected_cards.size(), everything)

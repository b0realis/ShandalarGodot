extends GutTest
## THE CARD CREATOR SCREEN, the pass of 2026-11-22: nothing unsaved is
## replaced unasked, Undo stays inside the card on screen, a deleted card is
## no clean card, a refused card is not "opened"; the status line names the
## card first, a rename asks, disabled buttons say why, prompts are modal
## and answer to Enter, typing is one undo step, what a type has no use for
## is gray, Import counts what it did not take, the Open list counts, sorts,
## marks examples and deletes, files can be dropped, effects are searched
## and reordered, and the suggestions table shows a row that is no level.

const ROOT := "user://c1122_editor_test"
const NAMES := ["Editor Test Wolf", "Editor Test Fox", "Editor Test Owl", "Battle Apothecary Cart"]

var _root := ""
var _options: Control


func before_each() -> void:
	_root = ProjectSettings.globalize_path(ROOT)
	DirAccess.make_dir_recursive_absolute(_root)
	CommunityCards.folders_override = [CommunityCards.ensure_own_folder()]
	_options = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(_options)
	await get_tree().process_frame


func after_each() -> void:
	var left := get_tree().root.find_child("CardForgeLayer", true, false)
	if left != null:
		left.free()
	for card in NAMES:
		CommunityCards.delete_own(card)
	CommunityCards.folders_override = []
	CommunityCards.clear_draft()
	CommunityCards.refresh()
	CardForgeScreen._open_sort = "name"
	if _root.contains("c1122_editor_test") and DirAccess.dir_exists_absolute(_root):
		for file in DirAccess.get_files_at(_root):
			DirAccess.remove_absolute(_root.path_join(file))
		DirAccess.remove_absolute(_root)


func _picture(file: String, w: int, h: int) -> String:
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.8, 0.2, 0.1))
	var path := _root.path_join(file)
	image.save_png(path)
	return path


func _open() -> CardForgeScreen:
	(_options.find_child("CreateCard", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	var forge := get_tree().root.find_child("CardForgeScreen", true, false) as CardForgeScreen
	forge.take_picture("icon", _picture("icon.png", 64, 64))
	return forge


func _name(forge: CardForgeScreen, card_name: String) -> void:
	(forge._fields["name"] as LineEdit).text = card_name
	forge._changed()


func _saved(forge: CardForgeScreen, card_name: String) -> void:
	_name(forge, card_name)
	forge.save_card()
	assert_true(CardRegistry.has_card(card_name), card_name + " is saved")


func _button(forge: CardForgeScreen, button: String) -> Button:
	return forge._dialog.find_child(button, true, false) as Button


func test_a_cleared_icon_is_an_undo_step_and_an_unsaved_change() -> void:
	var forge: CardForgeScreen = await _open()
	forge.take_picture("icon_rare", _picture("rare.png", 64, 64))
	_saved(forge, "Editor Test Wolf")
	assert_false(forge.has_unsaved())
	var steps := forge._history.size()
	forge.clear_icon("rare")
	assert_true(forge.has_unsaved(), "the icon taken back is a change")
	assert_eq(forge._history.size(), steps + 1, "and an undo step")
	forge.undo()
	assert_true(forge.icon.has("rare"), "undone, the icon is back")
	assert_eq(String(forge.spec["name"]), "Editor Test Wolf", "and nothing else was undone")
	assert_false(forge.has_unsaved())


func test_unsaved_work_is_asked_about_before_another_card_takes_its_place() -> void:
	var forge: CardForgeScreen = await _open()
	_saved(forge, "Editor Test Wolf")
	_saved(forge, "Editor Test Fox")
	var single := _root.path_join("wolf.zip")
	forge.open_card("Editor Test Wolf")
	forge.export_to(single)
	# New.
	_name(forge, "Editor Test Owl")
	(forge.find_child("ForgeNew", true, false) as Button).pressed.emit()
	assert_not_null(forge.find_child("ForgeLeaveWindow", true, false), "New asks")
	assert_eq(String(forge.spec["name"]), "Editor Test Owl", "nothing replaced yet")
	forge._close_dialog()
	# Open, and an example.
	forge.open_list()
	_button(forge, "ForgeOpen_editor_test_fox").pressed.emit()
	assert_eq(forge._dialog.name, &"ForgeLeaveWindow", "Open asks")
	assert_eq(String(forge.spec["name"]), "Editor Test Owl")
	assert_eq(get_viewport().gui_get_focus_owner().text, "Stay", "Stay is the default")
	forge._close_dialog()
	forge.open_list()
	_button(forge, "ForgeOpenExample_battle_apothecary_cart").pressed.emit()
	assert_eq(forge._dialog.name, &"ForgeLeaveWindow", "an example asks")
	forge._close_dialog()
	# Import (the button's and a drop's way in).
	forge.import_asked(single)
	assert_eq(forge._dialog.name, &"ForgeLeaveWindow", "Import asks")
	forge._close_dialog()
	forge.drop_files(PackedStringArray([single]))
	assert_eq(forge._dialog.name, &"ForgeLeaveWindow", "a dropped zip asks the same")
	assert_eq(String(forge.spec["name"]), "Editor Test Owl")
	# Going on does it.
	forge._close_dialog()
	forge.open_list()
	_button(forge, "ForgeOpen_editor_test_fox").pressed.emit()
	_button(forge, "ForgeLeaveGo").pressed.emit()
	assert_eq(String(forge.spec["name"]), "Editor Test Fox", "Go on opens it")
	assert_false(forge.has_unsaved())
	# A clean card is replaced without a word.
	(forge.find_child("ForgeNew", true, false) as Button).pressed.emit()
	assert_false(is_instance_valid(forge._dialog), "nothing to ask")
	assert_eq(String(forge.spec["name"]), "My Card")


func test_undo_never_steps_into_the_card_that_was_here_before() -> void:
	var forge: CardForgeScreen = await _open()
	_saved(forge, "Editor Test Wolf")
	_saved(forge, "Editor Test Fox")
	forge.open_card("Editor Test Wolf")
	assert_true(forge._history.is_empty() and forge._future.is_empty(), "a card opened has no past")
	assert_true((forge.find_child("ForgeUndo", true, false) as Button).disabled)
	forge.undo()
	assert_eq(String(forge.spec["name"]), "Editor Test Wolf", "Undo leaves it be")
	assert_eq(forge._saved_name, "Editor Test Wolf")
	(forge._fields["power"] as SpinBox).value = 6
	forge.new_card()
	assert_true(forge._history.is_empty(), "a new card has none either")
	forge.open_list()
	_button(forge, "ForgeOpenExample_battle_apothecary_cart").pressed.emit()
	assert_true(forge._history.is_empty(), "nor an example")


func test_the_open_card_deleted_is_not_a_clean_card() -> void:
	var forge: CardForgeScreen = await _open()
	_saved(forge, "Editor Test Wolf")
	forge.ask_delete()
	assert_eq(get_viewport().gui_get_focus_owner().text, "Cancel", "Cancel is the default")
	(forge._dialog as OriginalDialog).foot_buttons()[0].pressed.emit()
	assert_false(CardRegistry.has_card("Editor Test Wolf"), "deleted")
	assert_eq(forge._saved_name, "")
	assert_true(forge.has_unsaved(), "the card on screen is saved nowhere")
	assert_string_contains(forge._status.text, "still on screen")
	forge.close()
	assert_not_null(forge.find_child("ForgeLeaveWindow", true, false), "Done asks")
	forge._close_dialog()
	forge.save_card()
	assert_true(CardRegistry.has_card("Editor Test Wolf"), "Save keeps it")
	assert_false(forge.has_unsaved())


func test_a_refused_card_is_not_reported_opened() -> void:
	var forge: CardForgeScreen = await _open()
	_saved(forge, "Editor Test Wolf")
	assert_false(forge.load_spec({"name": 7}, {}, {}), "a card of the wrong shape is refused")
	assert_eq(String(forge.spec["name"]), "Editor Test Wolf", "the screen is as it was")
	assert_false(forge.open_card("No Such Card Anywhere"))
	assert_eq(forge._saved_name, "Editor Test Wolf", "the saved name is the card on screen's")
	assert_string_contains(forge._status.text, "cannot be opened")
	assert_false(forge._status.text.contains("opened."), "no success said over the refusal")
	assert_true(forge.load_spec(CardForgeScreen.blank(), {}, forge.icon))


func test_the_status_line_names_the_card_first_and_keeps_the_path_for_the_tooltip() -> void:
	var forge: CardForgeScreen = await _open()
	_saved(forge, "Editor Test Wolf")
	assert_true(forge._status.text.begins_with("Editor Test Wolf saved"), forge._status.text)
	assert_false(forge._status.text.contains("community_cards"), "no path on the short line")
	assert_string_contains(forge._status.tooltip_text, "Saved in ")
	assert_eq(forge._status.mouse_filter, Control.MOUSE_FILTER_PASS, "the tooltip can show")
	var out := _root.path_join("shared.zip")
	forge.export_to(out)
	assert_true(forge._status.text.begins_with("Editor Test Wolf exported to shared.zip"), forge._status.text)
	assert_string_contains(forge._status.tooltip_text, "shared.zip")
	forge.open_card("Editor Test Wolf")
	assert_eq(forge._status.text, "Editor Test Wolf opened.")


func test_a_renamed_card_asks_rename_or_keep_both() -> void:
	var forge: CardForgeScreen = await _open()
	_saved(forge, "Editor Test Wolf")
	_name(forge, "Editor Test Fox")
	forge.press_save()
	var prompt := forge.find_child("ForgeRenameWindow", true, false)
	assert_not_null(prompt, "asked")
	assert_false(CardRegistry.has_card("Editor Test Fox"), "nothing saved yet")
	assert_string_contains((prompt as OriginalDialog).body().get_child(0).text,
		"Rename Editor Test Wolf to Editor Test Fox, or keep both?")
	_button(forge, "ForgeRenameYes").pressed.emit()
	assert_true(CardRegistry.has_card("Editor Test Fox"))
	assert_false(CardRegistry.has_card("Editor Test Wolf"), "renamed: the old one is gone")
	assert_eq(forge._saved_name, "Editor Test Fox")
	_name(forge, "Editor Test Owl")
	forge.press_save()
	_button(forge, "ForgeRenameBoth").pressed.emit()
	assert_true(CardRegistry.has_card("Editor Test Fox") and CardRegistry.has_card("Editor Test Owl"), "both kept")
	# The same name saved again asks nothing.
	(forge._fields["power"] as SpinBox).value = 4
	forge.press_save()
	assert_false(is_instance_valid(forge._dialog))
	assert_eq(int(CommunityCards.spec_of("Editor Test Owl")["power"]), 4)
	# A rename chosen, then given up at the next prompt, renames nothing later.
	_name(forge, "Editor Test Fox")
	forge.press_save()
	_button(forge, "ForgeRenameYes").pressed.emit()
	assert_eq(forge._dialog.name, &"ForgeOverwriteWindow", "the Fox is another saved card")
	forge._close_dialog()
	forge.save_as("Editor Test Wolf")
	assert_true(CardRegistry.has_card("Editor Test Owl"), "Save as never renames away")


func test_a_disabled_button_says_why() -> void:
	var forge: CardForgeScreen = await _open()
	var save := forge.find_child("ForgeSave", true, false) as Button
	var tip := save.tooltip_text
	assert_string_contains(tip, "community_cards")
	_name(forge, "Lightning Bolt")
	assert_true(save.disabled)
	assert_string_contains(save.tooltip_text, "already in the game")
	assert_string_contains((forge.find_child("ForgeExport", true, false) as Button).tooltip_text, "already in the game")
	assert_string_contains((forge.find_child("ForgeDelete", true, false) as Button).tooltip_text, "No saved card")
	_name(forge, "")
	assert_true((forge.find_child("ForgeValidate", true, false) as Button).disabled)
	assert_eq((forge.find_child("ForgeValidate", true, false) as Button).tooltip_text, forge.problems()[0])
	_name(forge, "Editor Test Wolf")
	assert_eq(save.tooltip_text, tip, "enabled again, its own tooltip")


func test_prompts_are_modal_and_answer_to_enter() -> void:
	var forge: CardForgeScreen = await _open()
	_name(forge, "Editor Test Wolf")
	(forge._fields["name"] as LineEdit).grab_focus()
	forge.ask_save_as()
	var shade := forge.find_child("ForgeShade", true, false) as Control
	assert_not_null(shade, "a shade under the prompt")
	assert_eq(shade.mouse_filter, Control.MOUSE_FILTER_STOP, "it takes the clicks")
	assert_lt(shade.get_index(), forge._dialog.get_index(), "under the prompt, over the screen")
	assert_gt(shade.get_index(), forge._tabs.get_index())
	var edit := forge.find_child("ForgeSaveAsName", true, false) as LineEdit
	assert_eq(get_viewport().gui_get_focus_owner(), edit, "the name field has the keyboard")
	# A field of the screen beneath never keeps the keyboard.
	(forge._fields["name"] as LineEdit).grab_focus()
	await get_tree().process_frame
	assert_eq(get_viewport().gui_get_focus_owner(), edit, "the keyboard is back with the prompt")
	edit.text = "Editor Test Fox"
	edit.text_submitted.emit(edit.text)
	assert_true(CardRegistry.has_card("Editor Test Fox"), "Enter saves the copy")
	await get_tree().process_frame
	assert_null(forge.find_child("ForgeShade", true, false), "the shade goes with the prompt")
	forge.validate_card()
	assert_eq(get_viewport().gui_get_focus_owner().text, "Close")
	forge._close_dialog()
	# Files dropped while a prompt is up are left alone.
	forge.ask_delete()
	forge.drop_files(PackedStringArray([_picture("art.png", 765, 594)]))
	assert_true(forge.art.is_empty())
	assert_eq(forge._dialog.name, &"ForgeDeleteWindow")


func test_typing_is_one_undo_step_a_field() -> void:
	var forge: CardForgeScreen = await _open()
	var steps := forge._history.size()
	for text in ["W", "Wo", "Wol", "Wolf", "Wolfs"]:
		_name(forge, text)
	assert_eq(forge._history.size(), steps + 1, "five letters, one step")
	var flavor := forge._fields["flavor"] as TextEdit
	for text in ["a", "ab", "abc"]:
		flavor.text = text
		forge._changed()
	assert_eq(forge._history.size(), steps + 2, "another field, another step")
	(forge._fields["power"] as SpinBox).value = 3
	(forge._fields["power"] as SpinBox).value = 4
	assert_eq(forge._history.size(), steps + 4, "numbers are a step each")
	forge.undo()
	forge.undo()
	forge.undo()
	assert_eq(String(forge.spec["flavor"]), "", "the whole flavor text undone at once")
	assert_eq(String(forge.spec["name"]), "Wolfs")
	forge.undo()
	assert_eq(String(forge.spec["name"]), "My Card")
	forge.redo()
	assert_eq(String(forge.spec["name"]), "Wolfs")
	# After a pause it is a new step; so it is after a save.
	forge._merge_ms = -1
	_name(forge, "Wolfss")
	_name(forge, "Wolfsss")
	assert_eq(forge._history.size(), steps + 3)
	forge._merge_ms = 1000
	_name(forge, "Editor Test Wolf")
	forge.save_card()
	_name(forge, "Editor Test Wolfx")
	forge.undo()
	assert_eq(String(forge.spec["name"]), "Editor Test Wolf", "Undo after a save stops at the saved card")
	assert_eq(CardForgeScreen._changed_path({"a": [{"cost": "x"}]}, {"a": [{"cost": "y"}]}), "/a/0/cost")
	assert_eq(CardForgeScreen._changed_path({"rarity": "rare"}, {"rarity": "common"}), "", "a choice is no typing")
	assert_eq(CardForgeScreen._changed_path({"name": "a", "cost": "b"}, {"name": "x", "cost": "y"}), "")


func test_what_the_types_have_no_use_for_is_gray() -> void:
	var forge: CardForgeScreen = await _open()
	var cost := forge._fields["cost"] as LineEdit
	var power := forge._fields["power"] as SpinBox
	var flying := forge._fields["keywords"]["flying"] as CheckBox
	assert_true(cost.editable and power.editable and not flying.disabled, "a creature uses them all")
	flying.button_pressed = true
	(forge._fields["types"]["creature"] as CheckBox).button_pressed = false
	(forge._fields["types"]["land"] as CheckBox).button_pressed = true
	assert_false(cost.editable, "a land has no cost")
	assert_true((forge.find_child("ForgeAdd{R}", true, false) as Button).disabled)
	assert_eq(cost.text, "{1}{R}", "the text stays for when Land is unticked")
	assert_eq(String(forge.spec["cost"]), "")
	assert_false(power.editable, "no power for what is no creature")
	assert_false(flying.disabled, "a ticked keyword stays live, to untick it")
	assert_true((forge._fields["keywords"]["trample"] as CheckBox).disabled)
	flying.button_pressed = false
	assert_true(flying.disabled)
	(forge._fields["types"]["land"] as CheckBox).button_pressed = false
	(forge._fields["types"]["creature"] as CheckBox).button_pressed = true
	assert_true(cost.editable and power.editable and not flying.disabled)
	assert_eq(String(forge.spec["cost"]), "{1}{R}", "the cost is back")


func test_import_counts_what_it_did_not_take() -> void:
	var forge: CardForgeScreen = await _open()
	var not_zip := _picture("picture.png", 64, 64)
	var done := forge.import_from(not_zip)
	assert_eq((done["problems"] as Array).size(), 1)
	assert_eq(forge._status.text, "Imported nothing, 1 not taken.")
	var list := forge.find_child("ForgeNotTaken", true, false)
	assert_not_null(list, "what was not taken, listed")
	assert_string_contains((list.get_child(0) as Label).text, "not a .zip file")
	assert_string_contains(forge._status.tooltip_text, "not a .zip file")
	forge._close_dialog()
	# A set with one card here already and one new: the count, and the question.
	_saved(forge, "Editor Test Wolf")
	forge.save_as("Editor Test Fox")
	var out := _root.path_join("set.zip")
	forge.export_set_to(out)
	assert_true(forge._status.text.begins_with("My set: 2 cards exported to set.zip"), forge._status.text)
	CommunityCards.delete_own("Editor Test Fox")
	CommunityCards.refresh()
	done = forge.import_from(out)
	assert_eq(forge._status.text, "Imported Editor Test Fox, 1 here already.")
	assert_eq(forge._dialog.name, &"ForgeReplaceWindow")
	assert_eq(get_viewport().gui_get_focus_owner().text, "Keep mine")


func test_the_open_list_counts_sorts_marks_examples_and_deletes() -> void:
	var forge: CardForgeScreen = await _open()
	(forge._fields["set_name"] as LineEdit).text = "Zebra set"
	_saved(forge, "Editor Test Fox")
	(forge._fields["set_name"] as LineEdit).text = "Alpha set"
	(forge._fields["cost"] as LineEdit).text = "{1}{W}"
	forge._changed()
	forge.save_as("Editor Test Wolf")
	forge.open_list()
	var grid := forge.find_child("ForgeOpenGrid", true, false) as GridContainer
	var search := forge.find_child("ForgeOpenSearch", true, false) as LineEdit
	var count := forge.find_child("ForgeOpenCount", true, false) as Label
	assert_eq(get_viewport().gui_get_focus_owner(), search, "the search has the keyboard")
	assert_eq(count.text, "%d cards" % grid.get_child_count())
	var example := grid.find_child("ForgeOpenExample_battle_apothecary_cart", true, false)
	assert_eq((example.find_child("ForgeExampleRibbon", true, false) as Label).text, "Example")
	assert_null(example.find_child("ForgeOpenDelete", true, false), "an example is not deleted")
	search.text = "editor"
	search.text_changed.emit("editor")
	assert_eq(count.text, "2 of %d" % grid.get_child_count())
	search.text = ""
	search.text_changed.emit("")
	var names := func() -> Array:
		return grid.get_children().map(func(t: Node) -> String: return String(t.name))
	assert_eq(names.call(), ["ForgeOpenExample_battle_apothecary_cart", "ForgeOpen_editor_test_fox",
		"ForgeOpen_editor_test_wolf"], "by name, the examples first")
	var sort := forge.find_child("ForgeOpenSort", true, false) as OptionButton
	for pick in [["set", "wolf"], ["color", "wolf"], ["name", "fox"]]:
		CardForgeScreen._select(sort, String(pick[0]))
		sort.item_selected.emit(sort.selected)
		assert_eq(names.call()[1], "ForgeOpen_editor_test_" + String(pick[1]), "by " + String(pick[0]))
	CardForgeScreen.sort_open_list(grid, "newest")
	assert_eq(names.call()[0], "ForgeOpenExample_battle_apothecary_cart", "the examples stay first")
	# Enter opens the one card the search leaves.
	search.text_changed.emit("fox")
	search.text_submitted.emit("fox")
	assert_eq(String(forge.spec["name"]), "Editor Test Fox")
	# Delete from the list asks, and the list is back after.
	forge.open_list()
	(_button(forge, "ForgeOpen_editor_test_wolf").find_child("ForgeOpenDelete", true, false) as Button).pressed.emit()
	assert_eq(forge._dialog.name, &"ForgeDeleteWindow", "asked first")
	assert_true(CardRegistry.has_card("Editor Test Wolf"))
	(forge._dialog as OriginalDialog).foot_buttons()[0].pressed.emit()
	assert_false(CardRegistry.has_card("Editor Test Wolf"), "deleted")
	assert_eq(forge._dialog.name, &"ForgeOpenWindow", "the list again")
	assert_null(forge._dialog.find_child("ForgeOpen_editor_test_wolf", true, false))
	assert_eq(forge._saved_name, "Editor Test Fox", "the card on screen is another: untouched")
	assert_false(forge.has_unsaved())


func test_dropped_files_a_zip_a_picture_an_icon() -> void:
	var forge: CardForgeScreen = await _open()
	var art := _picture("art.png", 765, 594)
	var small := _picture("small.png", 48, 48)
	assert_eq(CardForgeScreen.drop_role(art), "art")
	assert_eq(CardForgeScreen.drop_role(small), "icon")
	assert_eq(CardForgeScreen.drop_role(_picture("square.png", 600, 600)), "art", "a large square is art to crop")
	forge.clear_icon("common")
	assert_true(forge.icon.is_empty())
	forge.drop_files(PackedStringArray([_root.path_join("notes.txt"), small]))
	assert_false(forge.icon.is_empty(), "a small square dropped is the set icon")
	forge.drop_files(PackedStringArray([art]))
	assert_eq(String(forge.art.get("kind", "")), "png", "a picture dropped is the art")
	forge.drop_files(PackedStringArray([_root.path_join("notes.txt")]))
	assert_string_contains(forge._status.text, "Drop a card zip")
	_saved(forge, "Editor Test Wolf")
	var out := _root.path_join("wolf.zip")
	forge.export_to(out)
	CommunityCards.delete_own("Editor Test Wolf")
	CommunityCards.refresh()
	forge.new_card()
	forge.drop_files(PackedStringArray([out]))
	assert_true(CardRegistry.has_card("Editor Test Wolf"), "a zip dropped is imported")
	assert_eq(forge._saved_name, "Editor Test Wolf", "and opened")


func test_effects_are_searched_and_abilities_and_effects_reordered() -> void:
	var forge: CardForgeScreen = await _open()
	(forge._fields["types"]["creature"] as CheckBox).button_pressed = false
	(forge._fields["types"]["sorcery"] as CheckBox).button_pressed = true
	forge.add_ability("spell")
	var effects: Array = forge.spec["abilities"][0]["effects"]
	assert_null(forge.find_child("ForgeMoveUp", true, false), "one of a kind is not moved")
	(forge.find_child("ForgeEffectPick", true, false) as Button).pressed.emit()
	var list := forge.find_child("ForgeEffectList", true, false) as VBoxContainer
	assert_not_null(list, "the effect list")
	var search := forge.find_child("ForgeEffectSearch", true, false) as LineEdit
	assert_eq(get_viewport().gui_get_focus_owner(), search)
	var offered := list.get_children().filter(func(l: Node) -> bool: return l is Button)
	var allowed := CommunityCard.EFFECTS.keys().filter(func(id: Variant) -> bool:
		return CommunityCard.effect_allowed(String(id), "spell"))
	assert_eq(offered.size(), allowed.size(), "every effect the ability may use, once")
	assert_null(list.find_child("ForgeEffect_animate", true, false), "and none it may not")
	search.text_changed.emit("gain")
	var seen := list.get_children().filter(func(l: Node) -> bool: return l is Button and (l as Control).visible)
	assert_eq(seen.map(func(l: Node) -> String: return String(l.name)), ["ForgeEffect_gain_life", "ForgeEffect_steal"])
	var headers := list.get_children().filter(func(l: Node) -> bool: return not l is Button and (l as Control).visible)
	assert_eq(headers.size(), 2, "only the groups that still show an effect")
	search.text_submitted.emit("gain")
	assert_eq(String(effects[0]["effect"]), "gain_life", "Enter takes the first")
	await get_tree().process_frame
	assert_null(forge.find_child("ForgeEffectWindow", true, false))
	assert_string_contains((forge.find_child("ForgeEffectPick", true, false) as Button).text, "Gain life")
	# Reorder the effects, then the abilities; each is undone.
	effects.append({"effect": "draw", "amount": 1})
	forge._rebuild_abilities()
	forge.refresh()
	var row := forge._abilities_box.get_child(0).find_children("ForgeMoveDown", "", true, false)
	assert_false((row[0] as Button).disabled)
	assert_true((row[1] as Button).disabled, "the last cannot go down")
	(row[0] as Button).pressed.emit()
	assert_eq(String(forge.spec["abilities"][0]["effects"][0]["effect"]), "draw")
	assert_string_contains(forge._preview._oracle.text, "Draw a card")
	forge.undo()
	assert_eq(String(forge.spec["abilities"][0]["effects"][0]["effect"]), "gain_life", "undone")
	forge.add_ability("spell")
	forge.move_item(forge.spec["abilities"], 1, -1)
	assert_eq(String(forge.spec["abilities"][0]["effects"][0]["effect"]), "damage", "the second ability first")
	forge.move_item(forge.spec["abilities"], 0, -1)
	assert_eq(String(forge.spec["abilities"][0]["effects"][0]["effect"]), "damage", "the first stays first")
	forge.undo()
	assert_eq(String(forge.spec["abilities"][0]["effects"][0]["effect"]), "gain_life")


func test_the_suggestions_table_shows_a_row_that_is_no_level() -> void:
	var forge: CardForgeScreen = await _open()
	forge.show_advice([{"level": CardBalance.OK, "topic": "Summary", "text": "Fits."},
		{"level": "not_compared", "topic": "Text", "text": "Nothing in the game to set it beside.", "yours": ""},
		{"level": CardBalance.HIGH, "topic": "Size", "text": "Big; yours has 9.", "yours": "9"}])
	var advice := forge.find_child("ForgeAdvice", true, false) as VBoxContainer
	assert_eq(advice.get_child_count(), 2)
	var last := (advice.get_child(1).get_child(0) as HBoxContainer).get_children()
	assert_eq((last[0] as Label).text, "Not compared", "after the levels, in plain words")
	assert_eq((last[0] as Label).get_theme_color("font_color"), CardForgeScreen.ADVICE_PLAIN)
	assert_eq((last[2] as Label).text, "", "no number: the column is empty")
	assert_eq((last[2] as Label).custom_minimum_size.x, 84.0, "and keeps its width")
	assert_eq((last[3] as Label).text, "Nothing in the game to set it beside.")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq((last[0] as Label).get_line_count(), 1, "the verdict fits its column")
	assert_lte(forge._dialog.size.x, 1260.0)
	assert_eq(CardForgeScreen._level_words(CardBalance.HIGH), "High")


func test_the_screen_still_fits_and_the_file_box_starts_where_it_was_last_used() -> void:
	var forge: CardForgeScreen = await _open()
	for kind in ["activated", "modal", "trigger"]:
		forge.add_ability(kind)
	await get_tree().process_frame
	await get_tree().process_frame
	var footer := forge.find_child("ForgeFooter", true, false) as HBoxContainer
	assert_lte(footer.get_combined_minimum_size().x, 1260.0, "the footer fits 1280")
	for i in forge._tabs.get_tab_count():
		assert_lte(forge._page(i).get_combined_minimum_size().x, 926.0, "page %d fits beside the card" % i)
	CardForgeScreen._last_folder = _root
	var box := forge._file_box("ForgeTestBox", FileDialog.FILE_MODE_OPEN_FILE, ["*.zip ; Card zip"])
	assert_eq(box.current_dir.trim_suffix("/"), _root.trim_suffix("/"))
	box.file_selected.emit("/somewhere/else/card.zip")
	assert_eq(CardForgeScreen._last_folder, "/somewhere/else")
	box.free()
	CardForgeScreen._last_folder = ""


func test_the_skin_drop_leaves_a_zip_alone_while_this_screen_is_open() -> void:
	var skins := get_node_or_null(^"/root/SkinPack")
	assert_not_null(skins, "the drop's other listener")
	var forge: CardForgeScreen = await _open()
	_saved(forge, "Editor Test Wolf")
	var out := _root.path_join("wolf.zip")
	forge.export_to(out)
	var before := [skins.get_child_count(), get_tree().root.get_child_count()]
	skins.call("_on_files_dropped", PackedStringArray([out]))
	assert_eq([skins.get_child_count(), get_tree().root.get_child_count()], before,
		"nothing adopted, and no \"is not a skin\" notice over the screen")
	assert_true(get_tree().root.has_node(^"CardForgeLayer"), "the layer the skin drop looks for")


func test_the_test_duel_button_says_when_it_cannot() -> void:
	var forge: CardForgeScreen = await _open()
	var test := forge.find_child("ForgeTest", true, false) as Button
	assert_false(test.disabled, "a whole card can be tested, saved or not")
	forge.clear_icon("common")
	assert_false(test.disabled, "its set icon is for saving only")
	assert_string_contains(test.tooltip_text, "Nothing is saved")
	_name(forge, "")
	assert_true(test.disabled)
	assert_eq(test.tooltip_text, forge.problems()[0], "the first problem")
	_name(forge, "Lightning Bolt")
	assert_true(test.disabled, "the game's own card is never stood in for")
	assert_string_contains(test.tooltip_text, "already in the game")
	assert_null(forge.test_duel())
	_name(forge, "Editor Test Wolf")
	assert_false(test.disabled)
	var reader := forge.find_child("ForgeReader", true, false) as Button
	var reasons := forge.find_child("ForgeProblemsScroll", true, false) as Control
	assert_lte(test.position.y + test.size.y, reasons.offset_top, "beside the small card, over the reasons")
	assert_gte(test.position.y, (forge.find_child("ForgeUndo", true, false) as Button).position.y + 30.0, "under Undo")
	assert_eq(test.position.x, reader.position.x)


func test_what_a_test_duel_is_dealt() -> void:
	assert_eq(CardForgeScreen.test_lands({"cost": "{2}{R}{G}"}),
		["Mountain", "Forest", "Mountain", "Forest", "Mountain", "Forest", "Mountain"] as Array[String],
		"its colors, the generic shared, three spare")
	assert_eq(CardForgeScreen.test_lands({"cost": ""}).size(), 3, "a land: the spare ones")
	assert_eq(CardForgeScreen.test_lands({"cost": "{X}{U}"}).count("Island"), 6, "X counts two")
	assert_eq(CardForgeScreen.test_lands({"cost": "{20}{B}"}).size(), CardForgeScreen.TEST_MAX_LANDS, "capped")
	assert_false(CardForgeScreen.test_wants_creatures(CardForgeScreen.blank()))
	assert_true(CardForgeScreen.test_wants_creatures({"abilities": [{"kind": "enchant", "enchant": "creature"}]}))
	assert_true(CardForgeScreen.test_wants_creatures({"abilities": [{"kind": "modal", "modes": [
		{"effects": [{"effect": "draw", "amount": 1}]}, {"effects": [{"effect": "destroy", "target": "creature"}]}]}]}))


func test_the_test_duel_plays_the_draft_and_returns_to_the_card_untouched() -> void:
	var forge: CardForgeScreen = await _open()
	_saved(forge, "Editor Test Wolf")
	# The draft differs from the saved card, and is another card by name.
	_name(forge, "Editor Test Owl")
	(forge._fields["power"] as SpinBox).value = 7
	forge.add_ability("enchant")   # a problem-free Aura part is not needed: remove it again
	forge.undo()
	var steps := forge._history.size()
	var redo := forge._future.size()
	var card := forge.spec.duplicate(true)
	var names := CardRegistry.all_names()
	var community := CardRegistry.community_names()
	var revision := CardRegistry.revision
	var mark := SgCompatibility.fingerprint()
	var files := Array(DirAccess.get_files_at(CommunityCards.own_folder()))
	var settings_before: Variant = Settings.get_value(TestHandsScreen.LAST_KEY, {})
	assert_true(forge.has_unsaved())
	var duel := forge.test_duel() as DuelScreen
	assert_not_null(duel, "the duel")
	if duel == null:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(forge.is_visible_in_tree(), "the screen waits under the duel")
	assert_true(duel.config.is_test(), "a test position: no match, no record")
	assert_eq(duel.config.ante, 0)
	assert_false(duel.config.is_ai(0))
	assert_true(duel.config.is_ai(1), "against the computer")
	var me: Variant = duel.game.players[0]
	var held: Array = me.hand.filter(func(i: CardInstance) -> bool: return i.data.card_name == "Editor Test Owl")
	assert_eq(held.size(), 2, "two of it in hand")
	assert_eq(me.hand.size(), 2, "and nothing else")
	assert_eq((held[0] as CardInstance).data.power, 7, "the card as it stands on screen, not a saved one")
	assert_true(duel.game.could_afford(0, (held[0] as CardInstance).data), "castable at once with its lands")
	assert_true(me.battlefield.all(func(i: CardInstance) -> bool: return not i.tapped), "all untapped")
	assert_eq(duel.game.active_player, 0)
	assert_eq(me.battlefield.size(), 5, "{1}{R} and three spare")
	assert_eq(CardRegistry.community_names(), community, "the set's list is as it was")
	assert_eq(CardRegistry.revision, revision)
	assert_false(FileAccess.file_exists(CommunityCards.own_path_of("Editor Test Owl")) \
		and CommunityCards.own_path_of("Editor Test Owl") != "", "nothing written")
	# Restart test keeps it held; the end of the test is the way back.
	var again: Array = []
	duel.handed_over.connect(func(next: Control) -> void: again.append(next))
	duel.restart_test()
	assert_eq(again.size(), 1)
	assert_true(again[0] is DuelScreen and forge._test_duel == again[0], "the same test again, still held")
	await get_tree().process_frame
	(again[0] as DuelScreen).edit_test()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(forge.is_visible_in_tree(), "back in the screen")
	assert_null(get_tree().root.find_child("CardForgeTest", true, false), "the duel is gone")
	assert_null(get_tree().root.find_child("TestHandsScreen", true, false), "and no bench is left")
	assert_eq(forge.spec, card, "the card as it was")
	assert_eq(forge._history.size(), steps, "its undo steps")
	assert_eq(forge._future.size(), redo, "its redo steps")
	assert_true(forge.has_unsaved(), "still unsaved")
	assert_eq(forge._saved_name, "Editor Test Wolf")
	assert_eq(CardRegistry.all_names(), names, "the pool as it was")
	assert_false(CardRegistry.has_card("Editor Test Owl"))
	assert_eq(CardRegistry.revision, revision)
	assert_eq(SgCompatibility.fingerprint(), mark, "the table fingerprint as it was")
	assert_eq(Array(DirAccess.get_files_at(CommunityCards.own_folder())), files, "the saved files as they were")
	assert_eq(str(Settings.get_value(TestHandsScreen.LAST_KEY, {})), str(settings_before), "no test remembered")
	forge.redo()
	assert_eq((forge.spec["abilities"] as Array).size(), 1, "Redo still knows the step undone before the duel")
	# A draft under its saved card's own name: the saved card answers again after.
	forge.undo()
	_name(forge, "Editor Test Wolf")
	duel = forge.test_duel() as DuelScreen
	assert_eq(CardRegistry.get_card("Editor Test Wolf").power, 7, "the draft plays")
	duel.menu_confirmed.emit()
	await get_tree().process_frame
	assert_eq(CardRegistry.get_card("Editor Test Wolf").power, 2, "the saved card is the pool's again")
	assert_true(forge.is_visible_in_tree())


# ------------------------------------------------------------ round 2b --

func _pick(pick: OptionButton, value: String) -> void:
	CardForgeScreen._select(pick, value)
	pick.item_selected.emit(pick.selected)


func _control(forge: CardForgeScreen, control: String) -> Control:
	return forge._abilities_box.find_child(control, true, false) as Control


func test_the_new_vocabulary_has_its_controls_and_leaves_no_key_at_the_default() -> void:
	var forge: CardForgeScreen = await _open()
	# A trigger: must / may / up to; "for each" on its effect.
	forge.add_ability("trigger")
	var trigger: Dictionary = forge.spec["abilities"][0]
	assert_false(trigger.has("choice"), "nothing written by showing the control")
	_pick(_control(forge, "ForgeChoice") as OptionButton, "may")
	assert_eq(String(trigger.get("choice", "")), "may")
	assert_string_contains(forge._preview._oracle.text, "you may")
	forge.undo()
	assert_false((forge.spec["abilities"][0] as Dictionary).has("choice"), "undone")
	forge.redo()
	_pick(_control(forge, "ForgeChoice") as OptionButton, "must")
	assert_false((forge.spec["abilities"][0] as Dictionary).has("choice"), "the default is not written")
	var effect: Dictionary = forge.spec["abilities"][0]["effects"][0]
	var count := String(CommunityCard.counts()[0])
	_pick(_control(forge, "ForgePer") as OptionButton, count)
	assert_eq(String(effect.get("per", "")), count)
	assert_string_contains(forge._preview._oracle.text, "for each")
	_pick(_control(forge, "ForgePer") as OptionButton, "")
	assert_false(effect.has("per"))
	assert_null(_control(forge, "ForgeFlag_enchanted"), "no Aura: nothing is the enchanted creature's")
	# A token's end.
	forge.set_effect("trigger", effect, "token")
	_pick(_control(forge, "ForgeEnds") as OptionButton, "sacrifice")
	assert_eq(String(effect.get("ends", "")), "sacrifice")
	_pick(_control(forge, "ForgeEnds") as OptionButton, "")
	assert_false(effect.has("ends"))
	# The color or type filter, for the targets it fits only.
	forge.set_effect("trigger", effect, "destroy")
	assert_eq(String(effect["target"]), "creature")
	_pick(_control(forge, "ForgeOnly") as OptionButton, "white")
	assert_eq(String(effect.get("only", "")), "white")
	var picker := _control(forge, "ForgeEffectPick")
	_pick(picker.get_parent().get_child(picker.get_index() + 1) as OptionButton, "artifact")
	assert_false(effect.has("only"), "it goes with the target it fitted")
	assert_null(_control(forge, "ForgeOnly"), "and is not offered for an artifact")
	assert_null(_control(forge, "ForgePer"), "nor \"for each\" for Destroy")
	# Power and toughness equal to a count: a choice, never a bare tick.
	(forge.find_child("ForgeRule_pt_count", true, false) as CheckBox).button_pressed = true
	assert_true((CommunityCard.counts() as Array).has(forge.spec["rules"]["pt_count"]), str(forge.spec["rules"]))
	_pick(forge.find_child("ForgeRuleCount_pt_count", true, false) as OptionButton, "swamp_you")
	assert_eq(String(forge.spec["rules"]["pt_count"]), "swamp_you")
	assert_eq(forge.problems(), [] as Array[String])
	(forge.find_child("ForgeRule_pt_count", true, false) as CheckBox).button_pressed = false
	assert_false((forge.spec["rules"] as Dictionary).has("pt_count"))


func test_an_aura_s_abilities_and_the_two_new_statics() -> void:
	var forge: CardForgeScreen = await _open()
	(forge._fields["types"]["creature"] as CheckBox).button_pressed = false
	(forge._fields["types"]["enchantment"] as CheckBox).button_pressed = true
	forge.add_ability("enchant")
	forge.add_ability("activated")
	forge.add_ability("trigger")
	var flags := forge._abilities_box.find_children("ForgeFlag_enchanted", "", true, false)
	assert_eq(flags.size(), 1, "the activated ability; not a trigger on entering")
	(flags[0] as CheckBox).button_pressed = true
	assert_true(bool(forge.spec["abilities"][1].get("enchanted", false)))
	(forge._abilities_box.find_children("ForgeFlag_enchanted", "", true, false)[0] as CheckBox).button_pressed = false
	assert_false((forge.spec["abilities"][1] as Dictionary).has("enchanted"), "off is not written")
	var trigger: Dictionary = forge.spec["abilities"][2]
	var when := forge._abilities_box.get_child(2).find_children("*", "OptionButton", true, false)[0] as OptionButton
	_pick(when, "attacks")
	assert_eq(forge._abilities_box.find_children("ForgeFlag_enchanted", "", true, false).size(), 2,
		"a trigger the creature can be watched for")
	trigger["enchanted"] = true
	when = forge._abilities_box.get_child(2).find_children("*", "OptionButton", true, false)[0] as OptionButton
	_pick(when, "enters")
	assert_false(trigger.has("enchanted"), "it goes with the event it fitted")
	# Spells cost more; the attack tax.
	forge.new_card()
	forge.add_ability("static")
	var static_one: Dictionary = forge.spec["abilities"][0]
	var what := forge._abilities_box.get_child(0).find_children("*", "OptionButton", true, false)[0] as OptionButton
	_pick(what, "cost_more")
	assert_true((CommunityCard.COST_SPELL_TYPES as Array).has(static_one.get("spell_type")), "a spell type it offers")
	assert_false(static_one.has("who") or static_one.has("spell_color"), "the defaults are not written")
	var said := forge._abilities_box.find_children("*", "Label", true, false).map(func(l: Node) -> String: return (l as Label).text)
	assert_true(said.has("more by") and not said.has("less by"), str(said))
	_pick(_control(forge, "ForgeWho") as OptionButton, "opponents")
	_pick(_control(forge, "ForgeSpellColor") as OptionButton, "red")
	assert_eq([static_one.get("who"), static_one.get("spell_color")], ["opponents", "red"])
	assert_eq(CommunityCard.problems(forge.spec), [] as Array[String])
	_pick(_control(forge, "ForgeWho") as OptionButton, String(CommunityCard.COST_WHO[0]))
	assert_false(static_one.has("who"))
	what = forge._abilities_box.get_child(0).find_children("*", "OptionButton", true, false)[0] as OptionButton
	_pick(what, "attack_tax")
	assert_false(static_one.has("spell_color") or static_one.has("spell_type"), "what the tax has no use for is gone")
	assert_null(_control(forge, "ForgeWho"))
	(_control(forge, "ForgeStaticAmount") as SpinBox).value = 2
	assert_eq(int(static_one["amount"]), 2)
	assert_eq(CommunityCard.problems(forge.spec), [] as Array[String])
	forge.undo()
	assert_eq(int(forge.spec["abilities"][0]["amount"]), 1, "undoable")


func test_warnings_are_shown_and_block_nothing() -> void:
	var forge: CardForgeScreen = await _open()
	assert_false(forge._warnings.visible, "none for the blank card")
	(forge._fields["toughness"] as SpinBox).value = 0
	assert_true(forge._warnings.visible)
	assert_string_contains(forge._warnings.text, "toughness 0")
	assert_false(forge._problems.visible, "it is no problem")
	assert_false((forge.find_child("ForgeSave", true, false) as Button).disabled, "the card still saves")
	assert_ne(forge._warnings.get_theme_color("font_color"), forge._problems.get_theme_color("font_color"))
	_name(forge, "")
	assert_false(forge._warnings.visible, "a card with problems shows those")


func test_opening_and_saving_an_old_card_never_changes_what_plays_of_it() -> void:
	var forge: CardForgeScreen = await _open()
	var example: Dictionary = CommunityCards.examples()[0]
	var old := CardForgeScreen.blank()
	old.merge({"name": "Editor Test Owl", "types": ["enchantment"], "subtypes": [], "cost": "{2}{G}",
		"abilities": [{"kind": "enchant", "enchant": "creature", "power": 1, "toughness": 1, "keywords": []},
			{"kind": "trigger", "when": "enters", "effects": [{"effect": "token", "amount": 1, "power": 1,
				"toughness": 1, "color": "green", "subtype": "saproling", "keywords": []},
				{"effect": "destroy", "target": "creature"}, {"effect": "gain_life", "amount": 2, "target": "you"}]},
			{"kind": "activated", "cost": "{1}", "tap": false, "sacrifice": true, "life": 0,
				"effects": [{"effect": "damage", "amount": 1, "target": "any"}]},
			{"kind": "static", "what": "cost_less", "spell_type": "creature", "amount": 1}]}, true)
	assert_eq(CommunityCard.problems(old), [] as Array[String], "an old-style card, whole")
	for card: Dictionary in [example["spec"], old]:
		var files: Dictionary = example["files"]
		assert_true(forge.load_spec(card, files.get("art", {}), files.get("icon", {})))
		assert_eq(SgCompatibility.card_digest(forge.spec), SgCompatibility.card_digest(card), "opened: the same card")
		assert_eq(JSON.stringify(forge.spec.get("abilities")), JSON.stringify(card.get("abilities")), "not a key more")
		forge.save_card()
		var saved := CommunityCards.spec_of(String(card["name"]))
		assert_false(saved.is_empty(), "saved")
		assert_eq(SgCompatibility.card_digest(saved), SgCompatibility.card_digest(card), "saved: the same card")
		assert_false(saved.has("author") or saved.has("card_version"), "no maker's key unasked")
	# The maker's own keys: written when filled, gone when emptied, and no other card at a table.
	var before := SgCompatibility.card_digest(forge.spec)
	(forge._fields["author"] as LineEdit).text = "A Maker"
	(forge._fields["card_version"] as SpinBox).value = 3
	forge._changed()
	assert_eq([forge.spec.get("author"), forge.spec.get("card_version")], ["A Maker", 3])
	forge.save_card()
	assert_eq(String(CommunityCards.spec_of("Editor Test Owl").get("author", "")), "A Maker")
	assert_eq(SgCompatibility.card_digest(forge.spec), before, "the same card to play")
	forge.open_card("Editor Test Owl")
	assert_eq((forge._fields["author"] as LineEdit).text, "A Maker", "read back")
	assert_eq(int((forge._fields["card_version"] as SpinBox).value), 3)
	(forge._fields["author"] as LineEdit).text = ""
	(forge._fields["card_version"] as SpinBox).value = 0
	forge._changed()
	assert_false(forge.spec.has("author") or forge.spec.has("card_version"))


func test_the_validator_s_power_its_new_verdicts_and_the_whole_set() -> void:
	var forge: CardForgeScreen = await _open()
	assert_lt(int(CardForgeScreen.ADVICE_ORDER[CardBalance.NOT_COMPARED]), int(CardForgeScreen.ADVICE_ORDER[CardBalance.LOW]))
	assert_lt(int(CardForgeScreen.ADVICE_ORDER[CardBalance.RARE]), int(CardForgeScreen.ADVICE_ORDER[CardBalance.OK]))
	assert_true(CardForgeScreen.ADVICE_COLORS.has(CardBalance.NOT_COMPARED) and CardForgeScreen.ADVICE_COLORS.has(CardBalance.RARE))
	assert_string_contains(CardForgeScreen.power_words(0), "nothing")
	assert_string_contains(CardForgeScreen.power_words(50), "Power 50 of 100 — usual")
	assert_string_contains(CardForgeScreen.power_words(90), "beyond")
	_saved(forge, "Editor Test Wolf")
	(forge._fields["power"] as SpinBox).value = 9
	forge.save_as("Editor Test Fox")
	forge.validate_card()
	var power := forge.find_child("ForgeAdvicePower", true, false) as Label
	assert_eq(power.text, CardForgeScreen.power_words(CardBalance.power(forge.spec)), "the card's one number")
	# A summary that is "Not compared" wears its own color.
	forge.show_advice([{"level": CardBalance.NOT_COMPARED, "topic": "Summary", "text": "Not everything could be compared."},
		{"level": CardBalance.OK, "topic": "Cost", "text": "Usual."},
		{"level": CardBalance.RARE, "topic": "Color", "text": "Rare in red.", "yours": ""},
		{"level": CardBalance.NOT_COMPARED, "topic": "Text", "text": "Nothing to set it beside.", "yours": ""}])
	var banner := forge._dialog.find_child("ForgeAdviceSummary", true, false).get_child(0) as Label
	assert_eq(banner.get_theme_color("font_color"), CardForgeScreen.ADVICE_COLORS[CardBalance.NOT_COMPARED])
	var advice := forge._dialog.find_child("ForgeAdvice", true, false) as VBoxContainer
	var verdicts := advice.get_children().map(func(row: Node) -> String:
		return ((row.get_child(0) as HBoxContainer).get_child(0) as Label).text)
	assert_eq(verdicts, ["Not compared", "Rare in color", "Usual"], "the order")
	# The whole set.
	(forge._dialog.find_child("ForgeValidateSet", true, false) as Button).pressed.emit()
	assert_eq(forge._dialog.name, &"ForgeSetAdviceWindow")
	var table := forge._dialog.find_child("ForgeSetAdvice", true, false) as VBoxContainer
	var cards := table.find_children("ForgeSetCard*", "", false, false)
	assert_eq(cards.size(), 2, "a line a card of the set")
	var first := (cards[0].get_child(0) as HBoxContainer).get_children()
	assert_eq((first[1] as Label).text, "Editor Test Fox", "the worst first: the 9/2 for two")
	assert_true((first[2] as Label).text.is_valid_int(), "its power")
	assert_gt(table.find_children("ForgeSetRemark*", "", false, false).size(), 0, "and the set's own remarks")
	await get_tree().process_frame
	assert_lte(forge._dialog.size.y, 720.0)
	forge.show_set_advice("A set", [{"kind": "card", "name": "Broken", "level": "invalid", "power": -1,
		"topic": "Problem", "text": "It needs a name."},
		{"kind": "set", "name": "", "level": "low", "power": -1, "topic": "Colors", "text": "No blue card."}])
	table = forge._dialog.find_child("ForgeSetAdvice", true, false) as VBoxContainer
	var cells := (table.get_child(0).get_child(0) as HBoxContainer).get_children()
	assert_eq([(cells[0] as Label).text, (cells[2] as Label).text, (cells[3] as Label).text], ["Problem", "", "It needs a name."])
	assert_eq(((table.get_child(1).get_child(0) as HBoxContainer).get_child(0) as Label).text, "Gap")


func test_import_tells_card_by_card_and_an_address_is_written_as_given() -> void:
	var lines := CardForgeScreen.import_lines({"cards": [
		{"name": "A", "result": "taken", "problem": "", "differs": ""},
		{"name": "B", "result": "here", "problem": "", "differs": "look"},
		{"name": "C", "result": "here", "problem": "", "differs": "plays"},
		{"name": "D", "result": "here", "problem": "", "differs": "identical"},
		{"name": "E", "result": "refused", "problem": "Its cost is wrong.", "differs": ""}],
		"problems": ["E: Its cost is wrong."], "notes": ["1 folder was left out."]})
	assert_eq(lines, ["A — taken.", "B — here already (only the look differs from yours).",
		"C — here already (plays differently from yours).", "D — here already (identical to yours).",
		"E — not taken: Its cost is wrong.", "1 folder was left out."] as Array[String])
	assert_eq(CardForgeScreen.import_lines({"problems": ["x is not a .zip file."]}), ["x is not a .zip file."] as Array[String])
	var forge: CardForgeScreen = await _open()
	_saved(forge, "Editor Test Wolf")
	var out := _root.path_join("wolf.zip")
	forge.export_to(out)
	(forge._fields["power"] as SpinBox).value = 5
	forge.save_card()
	forge.import_from(out)
	assert_eq(forge._dialog.name, &"ForgeReplaceWindow")
	var listed := forge._dialog.find_child("ForgeNotTaken", true, false)
	assert_not_null(listed, "card by card in the question too")
	assert_string_contains((listed.get_child(0) as Label).text, "Editor Test Wolf — here already (plays differently from yours)")
	forge._close_dialog()
	# A document's address (a phone's file box) gets no ".zip" put after it.
	var address := "content://com.example.documents/document/77"
	assert_true(AdventureTransfer.is_uri(address))
	forge.export_to(address)
	assert_false(forge._status.text.contains("77.zip") or forge._status.tooltip_text.contains("77.zip"), forge._status.text)
	forge.export_set_to(address)
	assert_false(forge._status.text.contains("77.zip") or forge._status.tooltip_text.contains("77.zip"), forge._status.text)


func test_the_set_aside_shelf() -> void:
	var forge: CardForgeScreen = await _open()
	_saved(forge, "Editor Test Wolf")
	forge.save_as("Editor Test Fox")
	var shelf := CommunityCards.aside_folder()
	DirAccess.make_dir_recursive_absolute(shelf)
	for card in ["Editor Test Wolf", "Editor Test Fox"]:
		forge.open_card(card)
		forge.export_to(shelf.path_join(CommunityCards.file_name(card) + ".zip"))
		CommunityCards.delete_own(card)
	CommunityCards.refresh()
	forge.new_card()
	assert_false(CardRegistry.has_card("Editor Test Wolf"))
	forge.open_list()
	var door := forge._dialog.find_child("ForgeOpenShelf", true, false) as Button
	assert_eq(door.text, "Set aside (2)...")
	door.pressed.emit()
	assert_eq(forge._dialog.name, &"ForgeShelfWindow")
	var rows := forge._dialog.find_children("ForgeShelfRow*", "", true, false)
	assert_eq(rows.size(), 2)
	var words := rows[0].find_children("*", "Label", true, false).map(func(l: Node) -> String: return (l as Label).text)
	assert_eq(words[0], "Editor Test Fox")
	assert_string_contains(words[1], "set aside 2")
	assert_string_contains(((forge._dialog as OriginalDialog).get_child(1).get_child(0) as Label).text, "Set aside — 2 cards, ")
	# Delete asks; Cancel is the default and leads back to the shelf.
	(rows[0].find_child("ForgeShelfDelete", true, false) as Button).pressed.emit()
	assert_eq(forge._dialog.name, &"ForgeShelfDeleteWindow")
	assert_eq(get_viewport().gui_get_focus_owner().text, "Cancel")
	assert_eq(CommunityCards.set_aside_count(), 2, "nothing deleted yet")
	(forge._dialog as OriginalDialog).foot_buttons()[0].pressed.emit()
	assert_eq(CommunityCards.set_aside_count(), 1, "deleted")
	assert_eq(forge._dialog.name, &"ForgeShelfWindow", "the shelf again")
	# Put back: in play again.
	(forge._dialog.find_child("ForgeShelfBack", true, false) as Button).pressed.emit()
	assert_true(CardRegistry.has_card("Editor Test Wolf"), "back in the pool")
	assert_eq(CommunityCards.set_aside_count(), 0)
	assert_string_contains(forge._status.text, "back in play")
	assert_not_null(forge._dialog.find_child("ForgeShelf", true, false).get_child(0) as Label, "\"Nothing is set aside.\"")
	(forge._dialog as OriginalDialog).foot_buttons()[0].pressed.emit()
	assert_eq(forge._dialog.name, &"ForgeOpenWindow", "Back is the Open list")
	for file in DirAccess.get_files_at(shelf):
		DirAccess.remove_absolute(shelf.path_join(file))

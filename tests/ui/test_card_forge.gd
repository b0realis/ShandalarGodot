extends GutTest
## THE CARD CREATOR ([CardForgeScreen]): opened from Options, a card made
## from scratch is shown live — large, small and in the card reader — says
## why it cannot be saved yet (its set icon first), takes its art and icon
## only by the guidelines, places the art with the crop, validates against
## the game's cards, saves into the community_cards folder (and joins the
## set at once) and exports a zip that reads back whole.

const ROOT := "user://card_forge_test"

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
	CommunityCards.delete_own("Forge Test Wolf")
	CommunityCards.delete_own("Forge Test Wolf II")
	CommunityCards.delete_own("Battle Apothecary Cart")
	CommunityCards.delete_own("Forge Test Fox")
	CommunityCards.delete_own("Forge Set One")
	var own := CommunityCards.ensure_own_folder()
	for name in DirAccess.get_files_at(own):
		if name.begins_with("forge_"):
			DirAccess.remove_absolute(own.path_join(name))
	CommunityCards.folders_override = []
	CommunityCards.clear_draft()
	CommunityCards.refresh()
	_wipe(_root)


func _wipe(dir: String) -> void:
	if not dir.contains("card_forge_test") or not DirAccess.dir_exists_absolute(dir):
		return
	var here := DirAccess.open(dir)
	for name in here.get_files():
		DirAccess.remove_absolute(dir.path_join(name))
	DirAccess.remove_absolute(dir)


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
	assert_not_null(forge, "over everything, on its own layer")
	assert_false(_options.visible, "Options waits under it")
	return forge


func test_options_opens_the_creator_with_a_card_to_start_from() -> void:
	var forge: CardForgeScreen = await _open()
	assert_eq(forge.problems(), ["Choose the set icon (Card page)."] as Array[String],
		"the blank card is whole but for its set icon")
	assert_true((forge.find_child("ForgeSave", true, false) as Button).disabled)
	assert_false((forge.find_child("ForgeValidate", true, false) as Button).disabled, "it can be validated")
	assert_string_contains(forge.take_picture("icon", _picture("huge.png", 512, 512)), "32 to 128")
	assert_eq(forge.take_picture("icon", _picture("icon.png", 64, 64)), "")
	assert_eq(forge.problems(), [] as Array[String])
	assert_false((forge.find_child("ForgeSave", true, false) as Button).disabled)
	assert_eq(forge._preview._name_label.text, "My Card")
	var mini := forge.find_child("ForgeMini", true, false).get_child(0) as MiniCard
	assert_not_null(mini, "the small card as the table shows it")
	assert_string_contains(mini.tooltip_text, "Set: My set (community card)")
	forge.open_reader()
	assert_not_null(forge.find_child("ForgeReaderShade", true, false), "the card reader, large")


func test_the_card_changes_live_and_says_why_it_cannot_be_saved() -> void:
	var forge: CardForgeScreen = await _open()
	forge.take_picture("icon", _picture("icon.png", 64, 64))
	(forge._fields["name"] as LineEdit).text = "Forge Test Wolf"
	forge._changed()
	assert_eq(forge._preview._name_label.text, "Forge Test Wolf")
	forge.add_ability("spell")
	assert_string_contains(forge._problems.text, "only an instant or a sorcery has a spell effect")
	assert_true((forge.find_child("ForgeSave", true, false) as Button).disabled)
	(forge._fields["types"]["creature"] as CheckBox).button_pressed = false
	(forge._fields["types"]["instant"] as CheckBox).button_pressed = true
	assert_eq(forge.problems(), [] as Array[String])
	assert_string_contains(forge._preview._oracle.text, "Forge Test Wolf deals 2 damage to any target.")
	(forge._fields["name"] as LineEdit).text = "Lightning Bolt"
	forge._changed()
	assert_string_contains(forge._problems.text, "already in the game")


func test_card_rules_and_the_validator() -> void:
	var forge: CardForgeScreen = await _open()
	forge.take_picture("icon", _picture("icon.png", 64, 64))
	(forge.find_child("ForgeRule_echo", true, false) as CheckBox).button_pressed = true
	assert_string_contains(forge._preview._oracle.text, "Echo {1}")
	var echo_cost := forge.find_child("ForgeRule_echo", true, false).get_parent().get_child(1) as LineEdit
	assert_eq(echo_cost.text, "{1}", "the field shows the cost it took")
	(forge._fields["power"] as SpinBox).value = 40
	(forge._fields["toughness"] as SpinBox).value = 40
	forge.validate_card()
	var advice := forge.find_child("ForgeAdvice", true, false) as VBoxContainer
	assert_not_null(advice, "the suggestions window")
	var said := ""
	var first_level := ""
	for row in advice.get_children():
		var cells := (row.get_child(0) as HBoxContainer).get_children()
		assert_eq(cells.size(), 4, "verdict, check, yours, the game's cards")
		if first_level == "":
			first_level = (cells[0] as Label).text
		said += " | ".join(PackedStringArray(cells.map(func(c: Node) -> String: return (c as Label).text))) + "\n"
	assert_eq(first_level, "Very high", "the worst first")
	assert_string_contains(said, "Very high | Size | 40/40 (80) | ")
	assert_false(said.contains("yours"), "the card's number has a column of its own")
	var summary := forge.find_child("ForgeAdviceSummary", true, false) as PanelContainer
	assert_not_null(summary, "the summary on top")
	assert_string_contains((summary.get_child(0) as Label).text, "Probably too strong")
	var header := forge.find_child("ForgeAdviceHeader", true, false) as PanelContainer
	assert_eq(((header.get_child(0) as HBoxContainer).get_child(2) as Label).text, "Yours")
	assert_false((forge.find_child("ForgeSave", true, false) as Button).disabled, "only a suggestion")


func test_art_crop_save_and_export() -> void:
	var forge: CardForgeScreen = await _open()
	assert_string_contains(forge.take_picture("art", _picture("small.png", 30, 20)), "pixels",
		"art off the guidelines is not taken")
	assert_eq(forge.take_picture("art", _picture("art.png", 860, 594)), "")
	assert_eq(forge.take_picture("icon", _picture("icon.png", 64, 64)), "")
	assert_true(forge._preview._art.visible, "the art is on the card")
	var shown := forge._preview._art.texture as AtlasTexture
	assert_not_null(shown, "cut to the art window")
	assert_almost_eq(shown.region.size.x / shown.region.size.y, CommunityCards.ART_ASPECT, 0.01)
	(forge._fields["art_x"] as HSlider).value = 0.0
	assert_eq((forge._preview._art.texture as AtlasTexture).region.position.x, 0.0, "moved to the left")
	(forge._fields["name"] as LineEdit).text = "Forge Test Wolf"
	(forge._fields["artist"] as LineEdit).text = "A Painter"
	forge._changed()
	forge.add_ability("trigger")
	forge.save_card()
	assert_true(CardRegistry.has_card("Forge Test Wolf"), "saved and in the pool at once")
	assert_true(CardRegistry.names_in_set(CommunityCard.SET_CODE).has("Forge Test Wolf"))
	assert_eq(CardRegistry.get_card("Forge Test Wolf").artist, "A Painter", "the illustration line")
	assert_string_contains(CardRegistry.get_card("Forge Test Wolf").oracle_text,
		"When Forge Test Wolf enters the battlefield, you gain 2 life.")
	var out := _root.path_join("shared.zip")
	forge.export_to(out)
	var row := CommunityCards.read(out)
	assert_eq(row["problems"], [] as Array[String], "the shared zip reads back whole")
	assert_eq(row["files"]["art"]["kind"], "png")
	assert_eq(row["files"]["icon"]["kind"], "png")
	assert_eq(float(row["spec"]["look"]["art"]["x"]), 0.0, "the crop travels with the card")
	forge.open_list()
	assert_not_null(forge.find_child("ForgeOpen_forge_test_wolf", true, false), "the Open list shows small cards")
	forge.close()
	await get_tree().process_frame
	assert_null(get_tree().root.find_child("CardForgeScreen", true, false))
	assert_true(_options.visible, "Options is back")
	assert_true(CommunityCards.spec_of("My Card").is_empty(), "the draft is gone")


func test_undo_save_as_the_open_search_and_a_set_out_and_back_in() -> void:
	var forge: CardForgeScreen = await _open()
	forge.take_picture("icon", _picture("icon.png", 64, 64))
	(forge._fields["name"] as LineEdit).text = "Forge Test Wolf"
	forge._changed()
	assert_true((forge.find_child("ForgeRedo", true, false) as Button).disabled, "nothing to redo yet")
	(forge._fields["power"] as SpinBox).value = 5
	forge.undo()
	assert_eq(int(forge.spec["power"]), 2, "undone")
	assert_eq(int((forge._fields["power"] as SpinBox).value), 2, "the widgets show it")
	forge.redo()
	assert_eq(int(forge.spec["power"]), 5, "redone")
	forge.save_card()
	forge.save_as("Forge Test Wolf II")
	assert_true(CardRegistry.has_card("Forge Test Wolf") and CardRegistry.has_card("Forge Test Wolf II"),
		"the copy is saved beside the first")
	forge.open_list()
	var grid := forge.find_child("ForgeOpenGrid", true, false) as GridContainer
	CardForgeScreen.filter_open_list(grid, "wolf ii")
	assert_eq(grid.get_children().filter(func(t: Control) -> bool: return t.visible).size(), 1, "the search")
	CardForgeScreen.filter_open_list(grid, "")
	assert_eq(grid.get_children().filter(func(t: Control) -> bool: return t.visible).size(), 3, "two and the example")
	forge._close_dialog()
	var out := _root.path_join("set.zip")
	forge.export_set_to(out)
	assert_true(CommunityCards.is_set_zip(out), "the whole set in one zip")
	assert_eq(CommunityCards.read_set(out).size(), 2)
	CommunityCards.delete_own("Forge Test Wolf")
	CommunityCards.delete_own("Forge Test Wolf II")
	CommunityCards.refresh()
	assert_false(CardRegistry.has_card("Forge Test Wolf"))
	var done := forge.import_from(out)
	assert_eq((done["names"] as Array).size(), 2, "both cards of the set are taken")
	assert_true(CardRegistry.has_card("Forge Test Wolf") and CardRegistry.has_card("Forge Test Wolf II"))
	assert_ne(CommunityCards.own_path_of("Forge Test Wolf"), "", "each into a zip of its own")
	done = forge.import_from(out)
	assert_eq((done["here"] as Array).size(), 2, "the second time they are here already")
	assert_not_null(forge.find_child("ForgeReplaceWindow", true, false), "asked before replacing")
	forge._close_dialog()
	var single := _root.path_join("one.zip")
	forge.export_to(single)
	CommunityCards.delete_own(String(forge.spec["name"]))
	CommunityCards.refresh()
	done = forge.import_from(single)
	assert_eq((done["names"] as Array).size(), 1, "a single card zip imports too")


func test_the_example_card_opens_whole_and_saves() -> void:
	var forge: CardForgeScreen = await _open()
	forge.open_list()
	var tile := forge.find_child("ForgeOpenExample_battle_apothecary_cart", true, false) as Button
	assert_not_null(tile, "the example card in the Open list")
	tile.pressed.emit()
	assert_eq(String(forge.spec["name"]), "Battle Apothecary Cart")
	assert_eq(forge.problems(), [] as Array[String], "whole, its set icon too")
	assert_string_contains(forge._preview._oracle.text, "Prevent the next 1 damage that would be dealt to target creature this turn.")
	forge.save_card()
	assert_true(CardRegistry.has_card("Battle Apothecary Cart"), "saved, it plays")



func test_the_file_fixes_of_the_round_4_hunt() -> void:
	var forge: CardForgeScreen = await _open()
	forge.take_picture("icon", _picture("icon.png", 64, 64))
	(forge._fields["name"] as LineEdit).text = "Forge Test Wolf"
	forge._changed()
	forge.save_card()
	# Renamed and saved, the Fox is a card beside the Wolf; Save as onto the
	# Wolf's name asks first, and changes nothing until then.
	(forge._fields["name"] as LineEdit).text = "Forge Test Fox"
	forge._changed()
	forge.save_card()
	assert_true(CardRegistry.has_card("Forge Test Wolf") and CardRegistry.has_card("Forge Test Fox"))
	forge.save_as("Forge Test Wolf")
	assert_not_null(forge.find_child("ForgeOverwriteWindow", true, false), "asked before replacing another card")
	assert_eq(String(forge.spec["name"]), "Forge Test Fox", "nothing changed yet")
	forge._close_dialog()
	# A card of a set zip saved alone never rewrites its set.
	var own := CommunityCards.ensure_own_folder()
	var set_path := own.path_join("forge_set.zip")
	var icon := {"bytes": FileAccess.get_file_as_bytes(_picture("i.png", 64, 64)), "kind": "png"}
	var one := forge.spec.duplicate(true)
	one["name"] = "Forge Set One"
	var two := forge.spec.duplicate(true)
	two["name"] = "Forge Set Two"
	assert_eq(CommunityCards.write_set_zip(set_path, "My set", [{"spec": one, "art": {}, "icon": icon},
		{"spec": two, "art": {}, "icon": icon}]), "")
	assert_string_contains(CommunityCards.write_set_zip(own.path_join("forge_twice.zip"), "My set",
		[{"spec": one, "art": {}, "icon": icon}, {"spec": one, "art": {}, "icon": icon}]), "Two cards of the set")
	CommunityCards.refresh()
	forge.open_card("Forge Set One")
	(forge._fields["toughness"] as SpinBox).value = 5
	forge.save_card()
	assert_eq(CommunityCards.read_set(set_path).size(), 2, "the set zip is whole")
	assert_true(CardRegistry.has_card("Forge Set Two"), "its other card still plays")
	# A zip from elsewhere holds a card's own files only.
	var stray := _root.path_join("stray.zip")
	var zip := ZIPPacker.new()
	zip.open(stray)
	for entry in [["x/card.json", JSON.stringify(one).to_utf8_buffer()], ["x/icon.png", icon["bytes"]],
			["x/notes.png", icon["bytes"]]]:
		zip.start_file(entry[0])
		zip.write_file(entry[1])
		zip.close_file()
	zip.close()
	assert_string_contains(String(CommunityCards.install(FileAccess.get_file_as_bytes(stray))["problem"]), "notes.png")
	assert_string_contains(String(CommunityCards.install(FileAccess.get_file_as_bytes(set_path))["problem"]), "set zip")
	# The search: words of the rules whole, names by their beginning.
	forge.open_list()
	var grid := forge.find_child("ForgeOpenGrid", true, false) as GridContainer
	CardForgeScreen.filter_open_list(grid, "ield")
	assert_eq(grid.get_children().filter(func(t: Control) -> bool: return t.visible).size(), 0,
		"no card is found by letters inside a word")
	CardForgeScreen.filter_open_list(grid, "set one")
	assert_eq(grid.get_children().filter(func(t: Control) -> bool: return t.visible).size(), 1, "words by their beginning")
	forge._close_dialog()
	DirAccess.remove_absolute(set_path)


func test_the_fixes_of_the_round_5_pass() -> void:
	var forge: CardForgeScreen = await _open()
	forge.take_picture("icon", _picture("icon.png", 64, 64))
	# Opening a card never changes it: an Aura that only steals stays so.
	var thief := CardForgeScreen.blank()
	thief.merge({"name": "Forge Test Wolf", "types": ["enchantment"], "subtypes": [], "cost": "{2}{U}{U}",
		"abilities": [{"kind": "enchant", "control": true}]}, true)
	forge.load_spec(thief, {}, forge.icon)
	assert_false((forge.spec["abilities"][0] as Dictionary).has("power"), "no -10/-10 written in")
	assert_string_contains(forge._preview._oracle.text, "You control enchanted creature.")
	# One Escape never throws unsaved work away.
	forge.close()
	assert_not_null(forge.find_child("ForgeLeaveWindow", true, false), "asked first")
	assert_true(is_instance_valid(forge) and forge.is_inside_tree(), "still open")
	forge._close_dialog()
	# Leave to replace is for the card the prompt named only.
	forge.save_card()
	(forge._fields["name"] as LineEdit).text = "Forge Test Fox"
	forge._changed()
	forge.save_card()
	forge.save_as("Forge Test Wolf")
	assert_not_null(forge.find_child("ForgeOverwriteWindow", true, false))
	forge._close_dialog()
	forge.save_card("Forge Test Wolf")
	assert_eq(CommunityCards.spec_of("Forge Test Fox").get("name"), "Forge Test Fox", "a leave for the Wolf saves no Fox over")

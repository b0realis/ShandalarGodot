extends GutTest
## STARTING FROM A GAME CARD in the card screen: Import's two ways in; one
## window with the Deck Builder's sources on the left and the chosen one's
## cards on the right (tiles made as they come into view); a card chosen
## shows what comes over and what is left out; Start loads a new card with
## no picture and no saved name, the keyboard in its Name field.

const ROOT := "user://c1122_import_test"


## What reads a game card when the engine's reader is not there: its
## name, cost-less frame and first line, the rest left out.
class StandIn:
	extends RefCounted
	var asked := 0

	func can_start(data: CardData) -> bool:
		return data.card_name != "Black Lotus"

	func quality(data: CardData) -> int:
		asked += 1
		return 100 if data.oracle_text == "" else (60 if data.is_creature() else 0)

	func from_card(data: CardData) -> Dictionary:
		var spec := CardForgeScreen.blank()
		spec.merge({"name": data.card_name, "cost": "{3}{W}{W}" if data.card_name == "Serra Angel" else "{2}",
			"subtypes": ["angel"], "power": 4, "toughness": 4, "keywords": ["flying"]}, true)
		return {"spec": spec, "exact": false, "kept": ["Flying"] as Array[String],
			"dropped": ["Vigilance, in the card's own words."] as Array[String],
			"notes": ["A stand-in read this card."] as Array[String]}


var _options: Control
var _reader: StandIn


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	CommunityCards.folders_override = [CommunityCards.ensure_own_folder()]
	_reader = StandIn.new()
	if not ResourceLoader.exists(CardForgeScreen.IMPORT_SCRIPT):
		CardForgeScreen.importer_override = _reader
	CardForgeScreen._last_source = "Original"
	_options = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(_options)
	await get_tree().process_frame


func after_each() -> void:
	var left := get_tree().root.find_child("CardForgeLayer", true, false)
	if left != null:
		left.free()
	CardForgeScreen.importer_override = null
	CommunityCards.delete_own("Import Test Wolf")
	CommunityCards.folders_override = []
	CommunityCards.clear_draft()
	CommunityCards.refresh()
	var root := ProjectSettings.globalize_path(ROOT)
	for file in DirAccess.get_files_at(root):
		DirAccess.remove_absolute(root.path_join(file))
	DirAccess.remove_absolute(root)


func _open() -> CardForgeScreen:
	(_options.find_child("CreateCard", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	return get_tree().root.find_child("CardForgeScreen", true, false) as CardForgeScreen


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func test_import_offers_two_ways_in() -> void:
	var forge: CardForgeScreen = await _open()
	(forge.find_child("ForgeImport", true, false) as Button).pressed.emit()
	assert_eq(forge._dialog.name, &"ForgeImportChoice")
	var texts := (forge._dialog as OriginalDialog).foot_buttons().map(func(b: Button) -> String: return b.text)
	assert_eq(texts, ["From a file...", "From a game card...", "Cancel"])
	assert_eq(get_viewport().gui_get_focus_owner().text, "From a file...", "today's import is the default")
	(forge._dialog.find_child("ForgeImportGame", true, false) as Button).pressed.emit()
	assert_eq(forge._dialog.name, &"ForgeGameCardWindow", "the second way in")
	forge._close_dialog()
	(forge.find_child("ForgeImport", true, false) as Button).pressed.emit()
	(forge._dialog.find_child("ForgeImportFile", true, false) as Button).pressed.emit()
	var box := forge.find_child("ForgeImportBox", true, false)
	assert_not_null(box, "the first: the file box")
	box.free()


func test_the_sources_are_the_deck_builder_s() -> void:
	var sources := CardForgeScreen.game_sources()
	var ids := sources.map(func(s: Dictionary) -> String: return String(s["id"]))
	var theirs := FilterBar.SOURCE_KEYS.keys().filter(func(id: String) -> bool: return id != "Community")
	assert_eq(ids, theirs, "the Extras rows, in their order, without the players' own cards")
	var total := 0
	for source in sources:
		var id := String(source["id"])
		var code := String(FilterBar.SOURCE_KEYS[id])
		if id == "Original":
			assert_true(bool(source["available"]))
			assert_eq((source["names"] as Array).size(), 897, "the 1997 cards")
		elif id == "Pack1":
			assert_eq(bool(source["available"]), CardRegistry.optional_pack_enabled())
		else:
			assert_eq(bool(source["available"]), CardRegistry.extra_set_order().has(code), id)
			if bool(source["available"]):
				assert_eq((source["names"] as Array).size(), CardRegistry.names_in_set(code).size(), id)
		total += (source["names"] as Array).size()
		assert_false((source["names"] as Array).any(func(n: String) -> bool: return CardRegistry.has_community(n)))
	assert_gt(total, 0)
	# The titles are the Extras window's own.
	var theirs_text := FileAccess.get_file_as_string("res://game/deck_builder/deck_builder_screen.gd")
	for id: String in CardForgeScreen.SOURCE_TITLES:
		assert_string_contains(theirs_text, "\"%s\", \"%s\"" % [id, CardForgeScreen.SOURCE_TITLES[id]])


func test_the_window_lists_sets_and_makes_tiles_as_they_come_into_view() -> void:
	var forge: CardForgeScreen = await _open()
	var began := Time.get_ticks_msec()
	forge.open_game_cards()
	var opened := Time.get_ticks_msec() - began
	gut.p("start-from-a-game-card window with 897 tiles: %d ms" % opened)
	assert_lt(opened, 400, "it opens at once (bare tiles)")
	var sets := forge._dialog.find_child("ForgeGameSets", true, false)
	assert_eq(sets.get_child_count(), CardForgeScreen.game_sources().size())
	var original := sets.find_child("ForgeGameSet_Original", true, false) as Button
	assert_true(original.button_pressed, "the first source is chosen")
	for row in sets.get_children():
		assert_eq((row as Button).disabled, not CardForgeScreen.game_sources().filter(
			func(s: Dictionary) -> bool: return "ForgeGameSet_" + String(s["id"]) == String(row.name))[0]["available"])
	assert_eq(get_viewport().gui_get_focus_owner(), forge._game_search, "the search has the keyboard")
	assert_eq(forge._game_grid.get_child_count(), 897)
	assert_eq(forge._game_count.text, "897 cards")
	await _frames(30)
	var dressed := forge._game_grid.get_children().filter(func(t: Node) -> bool: return t.has_meta("dressed"))
	assert_between(dressed.size(), 10, 60, "only the tiles in view have their small card")
	assert_true(forge._game_grid.get_child(0).get_child(0) is MiniCard)
	assert_eq(forge._game_grid.get_child(800).get_child_count(), 0, "one far down has none yet")
	if CardForgeScreen.importer_override != null:
		assert_eq(_reader.asked, dressed.size(), "and only they were measured")
	var first := forge._game_grid.get_child(0) as Button
	assert_not_null(first.find_child("ForgeGameMark", true, false), "its mark")
	assert_true(CardForgeScreen.QUALITY_WORDS.any(func(w: String) -> bool: return first.tooltip_text.ends_with(w)) \
		or first.tooltip_text.ends_with("cannot be started from"), first.tooltip_text)
	assert_eq([CardForgeScreen.game_quality(0), CardForgeScreen.game_quality(40), CardForgeScreen.game_quality(100)], [0, 1, 2])
	# Scrolled, the ones now in view are made.
	forge._game_scroll.scroll_vertical = 100000
	await _frames(30)
	assert_gt(forge._game_grid.get_child(896).get_child_count(), 0)
	# The search and the color row.
	forge._game_search.text = "serra angel"
	forge._game_search.text_changed.emit("serra angel")
	assert_eq(forge._game_count.text, "1 of 897")
	forge._game_search.text = ""
	forge._game_search.text_changed.emit("")
	(forge._game_colors["white"] as Button).button_pressed = true
	var white := forge._game_grid.get_children().filter(func(t: Node) -> bool: return (t as Control).visible)
	assert_between(white.size(), 50, 400)
	assert_true(white.all(func(t: Node) -> bool:
		return CardRegistry.get_card(String(t.get_meta("card"))).color_mask() & int(CommunityCard.COLORS["white"]) != 0),
		"white cards only (no White Mana Battery)")
	# The source chosen is remembered.
	var other: Button = null
	for row in sets.get_children():
		if not (row as Button).disabled and row != original:
			other = row
			break
	if other != null:
		other.button_pressed = true
		other.pressed.emit()
		assert_ne(forge._game_grid.get_child_count(), 897)
		forge._close_dialog()
		forge.open_game_cards()
		assert_true((forge._dialog.find_child(String(other.name), true, false) as Button).button_pressed)
	# Plain letters everywhere in the window.
	await _frames(3)
	for label in forge._dialog.find_children("*", "Label", true, false):
		var above := label.get_parent()
		var on_card := false
		while above != null and above != forge:
			on_card = on_card or above is MiniCard or above is CardPreview
			above = above.get_parent()
		if on_card:
			continue
		var text := label as Label
		assert_true(text.get_theme_color("font_shadow_color").a == 0.0
			or (text.get_theme_constant("shadow_offset_x") == 0 and text.get_theme_constant("shadow_offset_y") == 0),
			"no seat under \"%s\"" % text.text)


func test_a_card_shows_what_comes_over_and_start_begins_a_new_card() -> void:
	var forge: CardForgeScreen = await _open()
	forge.take_picture("icon", _icon())
	(forge._fields["name"] as LineEdit).text = "Import Test Wolf"
	forge._changed()
	forge.save_card()
	var saved := SgCompatibility.card_digest(CommunityCards.saved_spec("Import Test Wolf"))
	var names := CardRegistry.all_names()
	forge.open_game_cards()
	(forge._game_grid.find_child("ForgeGame_serra_angel", true, false) as Button).pressed.emit()
	assert_true(forge._game_detail.visible and not forge._game_browse.visible, "the same window, its summary")
	assert_eq(forge._dialog.name, &"ForgeGameCardWindow")
	var head := forge._game_detail.find_child("ForgeGameHead", true, false) as Label
	assert_string_contains(head.text, "Serra Angel — ")
	var result: Dictionary = CardForgeScreen._importer().from_card(CardRegistry.get_card("Serra Angel"))
	for part in [["ForgeGameKept", "kept", "Comes over"], ["ForgeGameDropped", "dropped", "Left out — add them yourself or leave them"]]:
		var list := forge._game_detail.find_child(String(part[0]), true, false)
		var lines: Array = result[part[1]]
		if lines.is_empty():
			assert_null(list)
			continue
		assert_eq((list.get_child(0) as Label).text, String(part[2]))
		assert_eq(list.get_child_count(), lines.size() + 1)
		assert_eq((list.get_child(1) as Label).text, "• " + String(lines[0]))
	assert_true(forge._game_detail.find_children("*", "CardPreview", true, false).size() == 1, "the draft, large")
	assert_eq(get_viewport().gui_get_focus_owner().name, &"ForgeGameStart")
	# Back, then Escape: one level each.
	(forge._game_detail.find_child("ForgeGameBack", true, false) as Button).pressed.emit()
	assert_true(forge._game_browse.visible and not forge._game_detail.visible)
	forge.show_game_card("Serra Angel")
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	forge._unhandled_input(escape)
	assert_true(is_instance_valid(forge._dialog) and forge._game_browse.visible, "Escape: back to the cards")
	forge._unhandled_input(escape)
	assert_false(is_instance_valid(forge._dialog), "Escape again: the window closes")
	# Start, from a clean card: no question.
	forge.open_game_cards()
	forge.show_game_card("Serra Angel")
	(forge._game_detail.find_child("ForgeGameStart", true, false) as Button).pressed.emit()
	assert_false(is_instance_valid(forge._dialog))
	assert_eq(String(forge.spec["name"]), "Serra Angel", "the game card's own name, to be changed")
	assert_eq(forge._saved_name, "", "a new card")
	assert_true(forge.art.is_empty() and forge.icon.is_empty(), "no picture comes over")
	assert_null(forge._art_texture)
	assert_true(forge._history.is_empty() and forge._future.is_empty(), "no past")
	var name_field := forge._fields["name"] as LineEdit
	assert_eq(get_viewport().gui_get_focus_owner(), name_field, "the keyboard is in the Name field")
	assert_eq(name_field.get_selected_text(), "Serra Angel", "the name selected")
	assert_eq(forge._tabs.current_tab, 0)
	assert_eq(forge._status.text, "Started from Serra Angel — give it a name of its own and your own art.")
	assert_string_contains(forge._problems.text, "A card named Serra Angel is already in the game.")
	assert_true((forge.find_child("ForgeSave", true, false) as Button).disabled, "until it is renamed")
	assert_eq(SgCompatibility.card_digest(CommunityCards.saved_spec("Import Test Wolf")), saved, "nothing saved changed")
	assert_eq(CardRegistry.all_names(), names, "nor the pool")
	assert_false(CardRegistry.has_community("Serra Angel"), "the game's card is the game's")
	# With unsaved work the question comes first.
	(forge._fields["power"] as SpinBox).value = 9
	assert_true(forge.has_unsaved())
	forge.open_game_cards()
	forge.show_game_card("Savannah Lions")
	(forge._game_detail.find_child("ForgeGameStart", true, false) as Button).pressed.emit()
	assert_eq(forge._dialog.name, &"ForgeLeaveWindow", "asked first")
	assert_eq(String(forge.spec["name"]), "Serra Angel")
	(forge._dialog.find_child("ForgeLeaveGo", true, false) as Button).pressed.emit()
	assert_eq(String(forge.spec["name"]), "Savannah Lions")


func _icon() -> String:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.8, 0.2, 0.1))
	var path := ProjectSettings.globalize_path(ROOT).path_join("icon.png")
	image.save_png(path)
	return path

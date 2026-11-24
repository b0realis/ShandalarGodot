extends GutTest
## OPTIONS' SKIN ROWS AND THEIR "?" WINDOW (0.70.9), after the bug pass of
## 2026-11-24: a place with a space in its path is still named by its last
## part, and the window fits a 720-line screen however many packs are named.

const OPTIONS := preload("res://game/options_screen.gd")


func test_a_place_with_spaces_is_named_by_its_last_part() -> void:
	var mac := "/Users/ann/Library/Application Support/Shandalar/cardpacks"
	assert_eq(OPTIONS.short_places("Card folder: %s — cardart.zip (300 pictures, your own)" % mac, [mac, ""]),
		"Card folder: cardpacks — cardart.zip (300 pictures, your own)")
	var win := "C:\\Users\\Deck Tester\\AppData\\Roaming\\Shandalar\\skins\\original_skin.zip"
	assert_eq(OPTIONS.short_places("Skin: %s — 972 files, your own" % win, ["", win]),
		"Skin: original_skin.zip — 972 files, your own")
	var folder := "/home/zz b/cardpacks"
	var loose := "/home/zz b/game dir/assets/cardart"
	assert_eq(OPTIONS.short_places("Card folder: %s — no card pack; a loose folder, %s" % [folder, loose], [folder, loose]),
		"Card folder: cardpacks — no card pack; a loose folder, cardart")
	# As before where nothing is known of the line.
	assert_eq(OPTIONS.short_places("Skin: a loose folder, /a/b/original — 972 files"),
		"Skin: a loose folder, original — 972 files")
	assert_eq(OPTIONS.short_places("Skin: none — the game draws its own", ["", ""]), "Skin: none — the game draws its own")


func test_the_rows_of_the_screen_keep_no_piece_of_a_spaced_path() -> void:
	var screen: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	for kind in SkinPack.KINDS:
		var status := screen.find_child("SkinStatus_" + kind, true, false) as Label
		var about: Dictionary = SkinPack.describe(kind)
		for key in ["folder", "name"]:
			var place := String(about.get(key, ""))
			if not place.contains("/"):
				continue
			assert_string_contains(status.tooltip_text, place, "the whole place is the tooltip")
			var parent := place.get_base_dir().get_file()
			if parent.contains(" "):
				assert_false(status.text.contains(parent.get_slice(" ", 0) + " " + place.get_file()),
					"%s: no word of the folder above it (%s)" % [kind, status.text])
			assert_string_contains(status.text, place.get_file())
			assert_false(status.text.contains(place))


func _window(size: Vector2i, packs: int) -> Array:
	var view := SubViewport.new()
	view.size = size
	add_child_autofree(view)
	var screen: Control = load("res://game/options_screen.tscn").instantiate()
	view.add_child(screen)
	await get_tree().process_frame
	var status := screen.find_child("SkinStatus_cardart", true, false) as Label
	var named := PackedStringArray()
	for i in packs:
		named.append("Pack-%d-Some-Block-Of-Cards.zip (591 pictures, your own)" % (i + 1))
	if packs > 0:
		status.tooltip_text = "Card folder: /home/somebody/.local/share/Shandalar/cardpacks — " + "; ".join(named)
	var popup: Control = screen.show_skin_places()
	await get_tree().process_frame
	await get_tree().process_frame
	return [view, screen, popup]


func test_the_window_fits_the_screen_with_every_pack_named() -> void:
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1280, 800)]:
		for packs in [0, 11, 30]:
			var got: Array = await _window(size, packs)
			var popup: Control = got[2]
			var ok := popup.find_child("OK", true, false) as Button
			var panel := popup.get_child(1) as Control
			var all := Rect2(Vector2.ZERO, Vector2(size))
			assert_true(all.encloses(panel.get_global_rect()),
				"%s, %d packs: the window is on the screen (%s)" % [size, packs, panel.get_global_rect()])
			assert_true(all.encloses(ok.get_global_rect()), "%s, %d packs: OK can be pressed" % [size, packs])
			var said := "\n".join(popup.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text))
			assert_string_contains(said, "Additional music folder:")
			# Eleven zips named fill a 720-line screen; thirty fill any.
			if packs >= 30 or (packs >= 11 and size.y <= 720):
				var scroll := popup.find_child("SkinPlacesScroll", true, false) as ScrollContainer
				assert_not_null(scroll, "its words scroll")
				if scroll != null:
					var press := InputEventAction.new()
					press.action = "ui_down"
					press.pressed = true
					ok.gui_input.emit(press)
					assert_gt(scroll.scroll_vertical, 0, "Down on OK walks the words")
			got[0].queue_free()
			await get_tree().process_frame


func test_the_tooltips_point_to_the_game_s_own_builder() -> void:
	var screen: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var choose := screen.find_child("Choose_skin", true, false) as Button
	assert_string_contains(choose.tooltip_text, SkinBuilderWindow.OPTIONS_BUTTON)
	assert_false(choose.tooltip_text.contains(".py"))
	assert_false(screen.skin_places_words().contains(".py"), "no tool is the only way")

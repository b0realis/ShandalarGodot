extends GutTest
## [QoL] The owner's alternate, duel-sized Showcase (2026-09-13).
## Big cards is the default; an explicit classic choice survives a reload.

const SETTING := "deck_big_cards"
var screen: DeckBuilderScreen
var _had_setting: bool
var _old_setting: Variant
var _had_extras: bool
var _old_extras: Variant


func before_each() -> void:
	_had_setting = Settings.has_value(SETTING)
	_old_setting = Settings.get_value(SETTING, false)
	# Layout tests must not inherit a prior Portal-only browsing session.
	_had_extras = Settings.has_value(DeckBuilderScreen.EXTRAS_SETTING)
	_old_extras = Settings.get_value(DeckBuilderScreen.EXTRAS_SETTING, {})
	Settings.clear_value(DeckBuilderScreen.EXTRAS_SETTING)
	# Most tests exercise the transition from classic to big explicitly.
	Settings.set_value(SETTING, false)
	await _open()


func after_each() -> void:
	if _had_extras:
		Settings.set_value(DeckBuilderScreen.EXTRAS_SETTING, _old_extras)
	else:
		Settings.clear_value(DeckBuilderScreen.EXTRAS_SETTING)
	if _had_setting:
		Settings.set_value(SETTING, _old_setting)
	else:
		Settings.clear_value(SETTING)


func _open() -> void:
	screen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.size = Vector2(1280, 800)
	await _settle()


func _settle() -> void:
	for _i in 4:
		await get_tree().process_frame


func test_big_cards_is_the_default_without_writing_a_setting() -> void:
	Settings.clear_value(SETTING)
	screen.queue_free()
	await _settle()
	await _open()
	assert_eq(screen._showcase.scale, Vector2.ONE)
	assert_eq(screen._deck_area.position.x, 330.0)
	assert_false(Settings.has_value(SETTING), "opening does not materialize defaults")
	assert_eq(screen._menu_text("Big cards"), "[x] Big cards")
	assert_true(screen._command_labels().has("Big cards"))


func test_extras_precedes_compact_stats_and_done_gets_the_spare_width() -> void:
	for big in [false, true]:
		Settings.set_value(SETTING, big)
		screen.queue_free()
		await _settle()
		await _open()
		var extras := screen._command_row.get_node("ExtrasButton") as Button
		var stats := screen._stats_button
		var done := screen._command_row.get_node("DoneButton") as Button
		assert_eq(extras.get_index() + 1, stats.get_index(), "Extras immediately left of Stats")
		assert_eq(stats.size_flags_horizontal, Control.SIZE_FILL)
		assert_almost_eq(stats.size.x, 128.0, 1.0, "Stats no longer expands")
		assert_gt(done.size.x, stats.size.x, "Done is the larger primary action")
		assert_eq(done.get_index(), screen._command_row.get_child_count() - 1)
		assert_lte(done.get_global_rect().end.x, screen.get_global_rect().end.x - 7.0)
		var face := done.get_theme_stylebox("normal")
		var tint: Color = face.modulate_color if face is StyleBoxTexture else face.bg_color
		assert_gt(tint.g, tint.r * 2.0, "emerald face")
		assert_gt(tint.g, tint.b, "emerald remains greener than blue")
		assert_gt(done.get_theme_color("font_color").get_luminance(), 0.8)


func test_emerald_done_also_styles_the_skinless_button() -> void:
	var button := Button.new()
	add_child_autofree(button)
	OriginalDialog._flat_button(button)
	DeckBuilderScreen._style_emerald_done(button)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var face := button.get_theme_stylebox(state) as StyleBoxFlat
		assert_not_null(face)
		assert_gt(face.bg_color.g, face.bg_color.r)
	assert_ne(button.get_theme_stylebox("normal").bg_color, button.get_theme_stylebox("pressed").bg_color)


func test_a_saved_classic_choice_still_wins_after_a_settings_reload() -> void:
	Settings.reload()
	screen.queue_free()
	await _settle()
	await _open()
	assert_eq(screen._showcase.scale, Vector2.ONE * DeckBuilderScreen.SHOWCASE_SCALE)
	assert_eq(screen._deck_area.position.x, 270.0)
	assert_eq(screen._menu_text("Big cards"), "[  ] Big cards")
	assert_false(bool(Settings.get_value(SETTING, true)))


func test_big_cards_match_the_duel_and_widen_both_card_surfaces() -> void:
	var inventory_rect := screen._inventory.get_rect()
	screen._run_command("Big cards")
	await _settle()
	assert_eq(screen._showcase.scale, Vector2.ONE, "the duel's unscaled CardPreview")
	assert_eq(screen._proxy_showcase.scale, Vector2.ONE, "proxy faces match real ones")
	assert_eq(screen._header_slab.size.x, CardPreview.SIZE.x)
	assert_eq(screen._deck_area.position.x, 330.0)
	assert_eq(screen._sideboard_area.position.x, screen._deck_area.position.x)
	assert_eq(screen._inventory.get_rect(), inventory_rect, "bottom cards stay unchanged")
	assert_eq(screen._menu_text("Big cards"), "[x] Big cards")


func test_the_choice_survives_a_settings_reload_and_screen_reopen() -> void:
	screen._run_command("Big cards")
	Settings.reload()
	assert_true(bool(Settings.get_value(SETTING, false)), "written to disk, not just cached")
	screen.queue_free()
	await _settle()
	await _open()
	assert_eq(screen._showcase.scale, Vector2.ONE)
	screen._run_command("Big cards")
	Settings.reload()
	assert_false(bool(Settings.get_value(SETTING, true)))


func test_toggling_back_restores_the_classic_geometry_without_accumulating_width() -> void:
	var controls: Array[Control] = [screen._header_slab, screen._deck_area,
		screen._sideboard_area, screen._command_row, screen._left_column, screen._well]
	var original: Array[Rect2] = []
	for control in controls:
		original.append(control.get_global_rect())
	for _i in 3:
		screen._run_command("Big cards")
		await _settle()
		screen._run_command("Big cards")
		await _settle()
		for i in controls.size():
			assert_eq(controls[i].get_global_rect(), original[i], "classic region %d restored" % i)
		assert_eq(screen._proxy_showcase.scale, Vector2.ONE * DeckBuilderScreen.SHOWCASE_SCALE)


func test_layout_changes_preserve_deck_filters_selection_and_undo() -> void:
	screen.filter.text = "bolt"
	screen._refresh_inventory()
	screen._inventory.set_cursor(0)
	var selected := screen._inventory.cursor_entry().card_name
	screen._add_one(selected)
	screen.deck.add_side("Mountain")
	screen.refresh()
	var undo := screen._undo
	var passes := screen.filter_passes
	screen._run_command("Big cards")
	await _settle()
	assert_eq(screen.filter.text, "bolt")
	assert_eq(screen._inventory.cursor_entry().card_name, selected)
	assert_eq(screen.deck.count_of(selected), 1)
	assert_eq(screen.deck.side_count_of("Mountain"), 1)
	assert_eq(screen._undo, undo, "layout is not a deck edit")
	assert_true(screen._dirty)
	assert_eq(screen.filter_passes, passes, "no pool walk or filter reset")
	screen._undo_last()
	assert_eq(screen.deck.count_of(selected), 0, "the earlier card addition is still undoable")


func test_big_card_information_scrolls_without_covering_the_filters() -> void:
	for card_name in ["Lightning Bolt", "Giant Growth", "Craw Wurm", "Grizzly Bears"]:
		for _i in 8:
			screen._add_one(card_name)
	screen.deck.add_side("Mountain")
	screen.refresh()
	screen._run_command("Big cards")
	for height in [800.0, 720.0, 1080.0]:
		screen.size = Vector2(1280.0, height)
		await _settle()
		var info := screen._left_scroll.get_global_rect()
		assert_lte(info.end.y, screen._filter_bar.global_position.y - 5.0)
		assert_eq(screen._showcase.scale, Vector2.ONE, "the card never shrinks")
		assert_lte(screen._well.get_global_rect().end.x, screen._deck_area.global_position.x)
		assert_lte(screen._command_row.get_global_rect().end.x, 1272.0)
		if height == 720.0:
			assert_true(screen._left_scroll.get_v_scroll_bar().visible)
			screen._left_scroll.scroll_vertical = 1000
			await _settle()
			assert_lte(screen._status_label.get_global_rect().end.y, info.end.y)
			assert_gte(screen._status_label.global_position.y, info.position.y,
				"the complete status line remains reachable")
	screen._run_command("Big cards")
	await _settle()
	assert_eq(screen._left_scroll.scroll_vertical, 0)
	assert_false(screen._left_scroll.get_v_scroll_bar().visible)


func test_menu_button_changes_layout_and_reopens_checked() -> void:
	screen._open_mini_menu()
	await _settle()
	var dialog := screen.open_dialogs()[0]
	var found := false
	for node in dialog.body().get_children():
		if node is Button and node.text == "[  ] Big cards":
			node.pressed.emit()
			found = true
	assert_true(found, "a real clickable menu entry, not just a command handler")
	await _settle()
	assert_eq(screen.open_dialogs().size(), 0)
	assert_eq(screen._showcase.scale, Vector2.ONE)
	screen._open_mini_menu()
	await _settle()
	dialog = screen.open_dialogs()[0]
	assert_gte(dialog.get_global_rect().position.y, 0.0)
	assert_lte(dialog.get_global_rect().end.y, screen.size.y)
	found = false
	for node in dialog.body().get_children():
		if node is Button and node.text == "[x] Big cards":
			found = true
	assert_true(found)


func test_big_layout_is_independent_of_the_existing_expanded_text_option() -> void:
	screen._showcase.set_text_expanded(true)
	screen._run_command("Big cards")
	assert_true(screen._showcase.text_is_expanded())
	screen._showcase.set_text_expanded(false)
	assert_eq(screen._showcase.scale, Vector2.ONE)
	screen._run_command("Big cards")
	assert_false(screen._showcase.text_is_expanded())


func test_a_selected_proxy_uses_the_same_big_card_slot() -> void:
	screen._show_in_showcase(ProxyCard.data_for("Layout test proxy"))
	screen._run_command("Big cards")
	await _settle()
	assert_true(screen._proxy_showcase.visible)
	assert_false(screen._showcase.visible)
	assert_eq(screen._proxy_showcase.position, screen._showcase.position)
	assert_eq(screen._proxy_showcase.size * screen._proxy_showcase.scale, CardPreview.SIZE)
	screen._show_in_showcase(CardRegistry.get_card("Shivan Dragon"))
	assert_false(screen._proxy_showcase.visible)
	assert_true(screen._showcase.visible)
	assert_eq(screen._showcase.scale, Vector2.ONE)


func test_arrows_enter_and_backspace_still_target_the_inventory_in_big_mode() -> void:
	screen._run_command("Big cards")
	await _settle()
	screen._stats_button.grab_focus()
	_press(KEY_RIGHT)
	var selected := screen._inventory.cursor_entry().card_name
	screen._deck_area.grab_focus()
	_press(KEY_ENTER)
	assert_eq(screen.deck.count_of(selected), 1)
	screen._stats_button.grab_focus()
	_press(KEY_BACKSPACE)
	assert_eq(screen.deck.count_of(selected), 0)
	assert_eq(screen._inventory.cursor_entry().card_name, selected)
	screen._stats_button.grab_focus()
	_press(KEY_RIGHT)
	assert_eq(screen._inventory.cursor_index(), 1)
	_press(KEY_LEFT)
	assert_eq(screen._inventory.cursor_index(), 0)


func _press(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	get_viewport().push_input(event)
	event = event.duplicate()
	event.pressed = false
	get_viewport().push_input(event)

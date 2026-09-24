extends GutTest
## Portal uses the same pack and independent filter contract.

func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-6", true)

func after_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_current_deck_names([])
	ShellMusic.stop()
	Settings.clear_value(DeckBuilderScreen.EXTRAS_SETTING)   # remembered since 2026-09-17

func test_main_menu_has_compact_pack_six_information_and_live_counts() -> void:
	var title = load("res://game/main.tscn").instantiate()
	add_child_autofree(title)
	await get_tree().process_frame
	var button := title.find_child("Pack6", true, false) as Button
	assert_not_null(button)
	if button == null: return
	assert_eq(button.text, "6-POR")
	assert_lt(button.size.y, button.size.x)
	assert_string_contains(title.find_child("Version", true, false).text, "1,097 set entries · 1,076 unique cards")
	button.pressed.emit()
	await get_tree().process_frame
	assert_not_null(title._pack_notice)
	assert_false(title._pack_notice.find_child("Disable", true, false).disabled)

func test_extras_has_portal_radio_medallions_and_live_filtering() -> void:
	var screen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.filter.original_cards_on = false
	screen.filter.completion_pack_on = false
	screen._open_extra_sets()
	await get_tree().process_frame
	var off := screen.find_child("ExtraPack6Off", true, false) as Button
	var on := screen.find_child("ExtraPack6On", true, false) as Button
	assert_not_null(off)
	assert_not_null(on)
	if off == null or on == null: return
	assert_eq(screen.filter.apply(screen._pool).size(), 200)
	off.pressed.emit()
	assert_eq(screen.filter.apply(screen._pool).size(), 0)
	on.pressed.emit()
	assert_eq(screen.filter.apply(screen._pool).size(), 200)
	assert_eq(on.custom_minimum_size, Vector2(48, 48))
	for button in [on, off]:
		var normal := button.get_theme_stylebox("normal") as StyleBoxTexture
		var pressed := button.get_theme_stylebox("pressed") as StyleBoxTexture
		assert_not_null(normal)
		assert_not_null(pressed)
		if normal != null and pressed != null:
			assert_eq(normal.texture, GameSkin.our_art("filter_por_off"))
			assert_eq(pressed.texture, GameSkin.our_art("filter_por_on"))
	for child in screen.get_children():
		if child is OriginalDialog and child.has_meta("extra_sets"):
			assert_true(child.get_global_rect().encloses(child._buttons.get_global_rect()), "Close remains inside the Extras frame")

func test_options_exposes_pack_six_and_deck_requirements_survive_disable() -> void:
	var page := CardPacksScreen.new()
	add_child_autofree(page)
	await get_tree().process_frame
	assert_not_null(page.find_child("Pack6Status", true, false))
	assert_not_null(page.find_child("EnablePack6", true, false))
	assert_not_null(page.find_child("DisablePack6", true, false))
	CardPacks.set_current_deck_names(["Alabaster Dragon"])
	assert_string_contains(CardPacks.disable_warning("pack-6"), "Alabaster Dragon")
	CardPacks.set_enabled("pack-6", false)
	assert_eq(CardPacks.packs_required_by(["Alabaster Dragon"]), ["pack-6"])
	assert_eq(CardPacks.missing_requirements(["pack-6"]), ["pack-6"])

func test_portal_gold_emblem_and_two_stone_faces_ship() -> void:
	for key in ["set_icon_por", "filter_por_on", "filter_por_off"]:
		var texture := GameSkin.our_art(key)
		assert_not_null(texture, key)
		if texture != null: assert_eq(texture.get_size(), Vector2(48, 48))

func test_portal_is_in_draft_selection_and_lan_compatibility() -> void:
	var page := DraftPoolDialog.new()
	add_child_autofree(page)
	await get_tree().process_frame
	assert_true(page.groups.has("por"))
	assert_true(SgCompatibility.enabled_packs().has("pack-6"))
	var stamp := SgCompatibility.fingerprint()
	CardPacks.set_enabled("pack-6", false)
	assert_ne(stamp, SgCompatibility.fingerprint())

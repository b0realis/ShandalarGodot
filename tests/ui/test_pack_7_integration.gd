extends GutTest
## Fifth Edition uses the same pack surfaces: title badge, Extras, Options.

func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-7", true)

func after_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_current_deck_names([])
	ShellMusic.stop()
	Settings.clear_value(DeckBuilderScreen.EXTRAS_SETTING)

func test_main_menu_has_compact_pack_seven_information_and_live_counts() -> void:
	var title = load("res://game/main.tscn").instantiate()
	add_child_autofree(title)
	await get_tree().process_frame
	var button := title.find_child("Pack7", true, false) as Button
	assert_not_null(button)
	if button == null: return
	assert_eq(button.text, "7-5ED")
	assert_lt(button.size.y, button.size.x)
	assert_string_contains(title.find_child("Version", true, false).text, "1,331 set entries · 1,044 unique cards")
	button.pressed.emit()
	await get_tree().process_frame
	assert_not_null(title._pack_notice)
	assert_false(title._pack_notice.find_child("Disable", true, false).disabled)

func test_extras_has_fifth_edition_radio_medallions_and_live_filtering() -> void:
	var screen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.filter.original_cards_on = false
	screen.filter.completion_pack_on = false
	screen._open_extra_sets()
	await get_tree().process_frame
	var off := screen.find_child("ExtraPack7Off", true, false) as Button
	var on := screen.find_child("ExtraPack7On", true, false) as Button
	assert_not_null(off)
	assert_not_null(on)
	if off == null or on == null: return
	assert_eq(screen.filter.apply(screen._pool).size(), 434)
	off.pressed.emit()
	assert_eq(screen.filter.apply(screen._pool).size(), 0)
	on.pressed.emit()
	assert_eq(screen.filter.apply(screen._pool).size(), 434)
	assert_eq(on.custom_minimum_size, Vector2(48, 48))
	for button in [on, off]:
		var normal := button.get_theme_stylebox("normal") as StyleBoxTexture
		var pressed := button.get_theme_stylebox("pressed") as StyleBoxTexture
		assert_not_null(normal)
		assert_not_null(pressed)
		if normal != null and pressed != null:
			assert_eq(normal.texture, GameSkin.our_art("filter_5ed_off"))
			assert_eq(pressed.texture, GameSkin.our_art("filter_5ed_on"))
	for child in screen.get_children():
		if child is OriginalDialog and child.has_meta("extra_sets"):
			assert_true(child.get_global_rect().encloses(child._buttons.get_global_rect()), "Close remains inside the Extras frame")

func test_options_exposes_pack_seven_and_deck_requirements_survive_disable() -> void:
	var page := CardPacksScreen.new()
	add_child_autofree(page)
	await get_tree().process_frame
	assert_not_null(page.find_child("Pack7Status", true, false))
	assert_not_null(page.find_child("EnablePack7", true, false))
	assert_not_null(page.find_child("DisablePack7", true, false))
	var status := page.find_child("Pack7Status", true, false) as Label
	if status != null:
		assert_string_contains(status.text, "434 names · 449 printings · 0 new identities")
	CardPacks.set_current_deck_names(["Abyssal Specter"])
	assert_string_contains(CardPacks.disable_warning("pack-7"), "Abyssal Specter")
	CardPacks.set_enabled("pack-7", false)
	assert_eq(CardPacks.packs_required_by(["Abyssal Specter"]), ["pack-3"])
	assert_eq(CardPacks.missing_requirements(["pack-3"]), ["pack-3"])

func test_fifth_edition_gold_numeral_and_two_stone_faces_ship() -> void:
	for key in ["set_icon_5ed", "filter_5ed_on", "filter_5ed_off"]:
		var texture := GameSkin.our_art(key)
		assert_not_null(texture, key)
		if texture != null: assert_eq(texture.get_size(), Vector2(48, 48))
	assert_eq(DeckFilter.SET_LABELS["5ed"], "Fifth Edition")

func test_fifth_edition_is_in_lan_compatibility_and_its_reused_identities_draft() -> void:
	var page := DraftPoolDialog.new()
	add_child_autofree(page)
	await get_tree().process_frame
	assert_true(page.groups.has("5ed"))
	assert_true(SgCompatibility.enabled_packs().has("pack-7"))
	var stamp := SgCompatibility.fingerprint()
	CardPacks.set_enabled("pack-7", false)
	assert_ne(stamp, SgCompatibility.fingerprint())

extends GutTest
## The Mirage block uses the same pack surfaces: title badge, Extras (one
## row per set, as Portal's two sets have), Options, Rescan, LAN stamp.

func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-8", true)

func after_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_current_deck_names([])
	ShellMusic.stop()
	Settings.clear_value(DeckBuilderScreen.EXTRAS_SETTING)

func test_main_menu_has_compact_pack_eight_information_and_live_counts() -> void:
	var title = load("res://game/main.tscn").instantiate()
	add_child_autofree(title)
	await get_tree().process_frame
	var button := title.find_child("Pack8", true, false) as Button
	assert_not_null(button)
	if button == null: return
	assert_eq(button.text, "8-MIR")
	assert_lt(button.size.y, button.size.x)
	assert_string_contains(title.find_child("Version", true, false).text, "1,566 set entries · 1,549 unique cards")
	button.pressed.emit()
	await get_tree().process_frame
	assert_not_null(title._pack_notice)
	assert_false(title._pack_notice.find_child("Disable", true, false).disabled)

func test_extras_has_a_row_per_set_with_medallions_and_live_filtering() -> void:
	var screen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.filter.original_cards_on = false
	screen.filter.completion_pack_on = false
	screen._open_extra_sets()
	await get_tree().process_frame
	assert_eq(screen.filter.apply(screen._pool).size(), 669)
	var rows := {"Pack8": ["mir", 335], "Visions": ["vis", 167], "Weatherlight": ["wth", 167]}
	for id in rows:
		var off := screen.find_child("Extra%sOff" % id, true, false) as Button
		var on := screen.find_child("Extra%sOn" % id, true, false) as Button
		assert_not_null(off, id)
		assert_not_null(on, id)
		if off == null or on == null: continue
		assert_false(on.disabled, id)
		off.pressed.emit()
		assert_eq(screen.filter.apply(screen._pool).size(), 669 - int(rows[id][1]), id)
		on.pressed.emit()
		assert_eq(screen.filter.apply(screen._pool).size(), 669, id)
		assert_eq(on.custom_minimum_size, Vector2(48, 48))
		for button in [on, off]:
			var normal := button.get_theme_stylebox("normal") as StyleBoxTexture
			var pressed := button.get_theme_stylebox("pressed") as StyleBoxTexture
			assert_not_null(normal)
			assert_not_null(pressed)
			if normal != null and pressed != null:
				assert_eq(normal.texture, GameSkin.our_art("filter_%s_off" % rows[id][0]))
				assert_eq(pressed.texture, GameSkin.our_art("filter_%s_on" % rows[id][0]))
	for id in rows:
		(screen.find_child("Extra%sOff" % id, true, false) as Button).pressed.emit()
	assert_eq(screen.filter.apply(screen._pool).size(), 0)
	for child in screen.get_children():
		if child is OriginalDialog and child.has_meta("extra_sets"):
			assert_true(child.get_global_rect().encloses(child._buttons.get_global_rect()), "Close remains inside the Extras frame")

func test_options_exposes_pack_eight_and_rescan_keeps_it() -> void:
	var page := CardPacksScreen.new()
	add_child_autofree(page)
	await get_tree().process_frame
	var status := page.find_child("Pack8Status", true, false) as Label
	var enable := page.find_child("EnablePack8", true, false) as Button
	var disable := page.find_child("DisablePack8", true, false) as Button
	assert_not_null(status)
	assert_not_null(enable)
	assert_not_null(disable)
	if status == null or enable == null or disable == null: return
	assert_string_contains(status.text, "Status: Enabled")
	assert_string_contains(status.text, "669 names · 684 printings · 621 new identities")
	assert_string_contains(status.text, "Mirage 335 · Visions 167 · Weatherlight 167")
	assert_true(enable.disabled)
	assert_false(disable.disabled)
	assert_string_contains((page.find_child("LocalOnly", true, false) as Label).text, "tools/pack_8_mirage_block.py")
	disable.pressed.emit()
	assert_false(CardPacks.is_enabled("pack-8"))
	assert_string_contains(status.text, "Status: Disabled")
	CardPacks.rescan()
	assert_true(CardPacks.has_pack("pack-8"), "Rescan finds the ZIP again")
	assert_false(CardPacks.is_enabled("pack-8"), "and keeps the player's choice")
	assert_string_contains(status.text, "Status: Disabled")
	assert_false(enable.disabled)
	enable.pressed.emit()
	assert_true(CardPacks.is_enabled("pack-8"))
	CardPacks.rescan()
	assert_true(CardPacks.is_enabled("pack-8"))
	assert_eq(CardRegistry.names_in_set("vis").size(), 167)

func test_deck_requirements_survive_disable() -> void:
	CardPacks.set_current_deck_names(["Bösium Strip", "Disenchant"])
	assert_string_contains(CardPacks.disable_warning("pack-8"), "Bösium Strip")
	assert_false(CardPacks.disable_warning("pack-8").contains("Disenchant"))
	CardPacks.set_enabled("pack-8", false)
	assert_eq(CardPacks.packs_required_by(["Bösium Strip", "Disenchant"]), ["pack-8"])
	assert_eq(CardPacks.missing_requirements(["pack-8"]), ["pack-8"])

func test_mirage_block_gold_emblems_and_stone_faces_ship() -> void:
	for code in ["mir", "vis", "wth"]:
		for key in ["set_icon_" + code, "filter_%s_on" % code, "filter_%s_off" % code]:
			var texture := GameSkin.our_art(key)
			assert_not_null(texture, key)
			if texture != null: assert_eq(texture.get_size(), Vector2(48, 48))
		assert_not_null(GameSkin.set_icon(code), code)
	assert_eq(DeckFilter.SET_LABELS["mir"], "Mirage")
	assert_eq(DeckFilter.SET_LABELS["vis"], "Visions")
	assert_eq(DeckFilter.SET_LABELS["wth"], "Weatherlight")

func test_mirage_block_is_in_draft_selection_and_lan_compatibility() -> void:
	var page := DraftPoolDialog.new()
	add_child_autofree(page)
	await get_tree().process_frame
	for code in ["mir", "vis", "wth"]:
		assert_true(page.groups.has(code), code)
	assert_true(SgCompatibility.enabled_packs().has("pack-8"))
	var stamp := SgCompatibility.fingerprint()
	CardPacks.set_enabled("pack-8", false)
	assert_ne(stamp, SgCompatibility.fingerprint())

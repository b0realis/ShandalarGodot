extends GutTest
## The Urza block uses the same pack surfaces: title badge, Extras (one
## row per set, as the Mirage and Tempest blocks' three sets have), Options,
## Rescan, LAN stamp. And Pack 10 is the FIRST TWO-DIGIT PACK (2026-11-06):
## every list of packs keeps it after Pack 9 — never between Packs 1 and 2,
## where a text sort puts `pack-10` — and `10` is read as one number.

func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-10", true)

func after_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_current_deck_names([])
	ShellMusic.stop()
	Settings.clear_value(DeckBuilderScreen.EXTRAS_SETTING)

func test_main_menu_has_compact_pack_ten_information_and_live_counts() -> void:
	var title = load("res://game/main.tscn").instantiate()
	add_child_autofree(title)
	await get_tree().process_frame
	var button := title.find_child("Pack10", true, false) as Button
	assert_not_null(button)
	if button == null: return
	assert_eq(button.text, "10-USG")
	assert_lt(button.size.y, button.size.x)
	assert_string_contains(title.find_child("Version", true, false).text, "1,518 set entries · 1,506 unique cards")
	button.pressed.emit()
	await get_tree().process_frame
	assert_not_null(title._pack_notice)
	assert_false(title._pack_notice.find_child("Disable", true, false).disabled)

## The badge row: Pack 10 last, after Pack 9, on the second line of five;
## its wider label "10-USG" still fits the compact button.
func test_the_badges_run_in_pack_number_order_and_ten_fits() -> void:
	var badges := CardPackBadges.new()
	add_child_autofree(badges)
	await get_tree().process_frame
	await get_tree().process_frame
	var names: Array[String] = []
	for child in badges.get_children(): names.append(String(child.name))
	var wanted: Array[String] = []
	for id in CardPacks.available_ids(): wanted.append("Pack" + id.trim_prefix("pack-"))
	assert_eq(names, wanted)
	assert_eq(names.back(), "Pack10", "the newest pack is last")
	if names.has("Pack1") and names.has("Pack2"):
		assert_eq(names.find("Pack2"), names.find("Pack1") + 1, "Pack 10 is not between Packs 1 and 2")
	assert_eq(badges.columns, 5)
	var ten := badges.find_child("Pack10", false, false) as Button
	assert_not_null(ten)
	if ten == null: return
	assert_eq(ten.text, "10-USG")
	assert_lte(ten.get_minimum_size().x, CardPackBadges.SIZE.x, "the label fits the badge")
	assert_eq(ten.size, CardPackBadges.SIZE)
	if names.size() > 5:
		var first := badges.get_child(0) as Control
		assert_gt(ten.position.y, first.position.y, "wrapped after five buttons")

func test_extras_has_a_row_per_set_with_medallions_and_live_filtering() -> void:
	var screen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.filter.original_cards_on = false
	screen.filter.completion_pack_on = false
	screen._open_extra_sets()
	await get_tree().process_frame
	assert_eq(screen.filter.apply(screen._pool).size(), 621)
	var rows := {"Pack10": ["usg", 335], "Legacy": ["ulg", 143], "Destiny": ["uds", 143]}
	for id in rows:
		var off := screen.find_child("Extra%sOff" % id, true, false) as Button
		var on := screen.find_child("Extra%sOn" % id, true, false) as Button
		assert_not_null(off, id)
		assert_not_null(on, id)
		if off == null or on == null: continue
		assert_false(on.disabled, id)
		off.pressed.emit()
		assert_eq(screen.filter.apply(screen._pool).size(), 621 - int(rows[id][1]), id)
		on.pressed.emit()
		assert_eq(screen.filter.apply(screen._pool).size(), 621, id)
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

func test_options_exposes_pack_ten_and_rescan_keeps_it() -> void:
	var page := CardPacksScreen.new()
	add_child_autofree(page)
	await get_tree().process_frame
	var status := page.find_child("Pack10Status", true, false) as Label
	var enable := page.find_child("EnablePack10", true, false) as Button
	var disable := page.find_child("DisablePack10", true, false) as Button
	assert_not_null(status)
	assert_not_null(enable)
	assert_not_null(disable)
	if status == null or enable == null or disable == null: return
	assert_string_contains(status.text, "Status: Enabled")
	assert_string_contains(status.text, "621 names · 636 printings · 591 new identities")
	assert_string_contains(status.text, "Urza's Saga 335 · Urza's Legacy 143 · Urza's Destiny 143")
	assert_true(enable.disabled)
	assert_false(disable.disabled)
	assert_string_contains((page.find_child("LocalOnly", true, false) as Label).text, "tools/pack_10_urza_block.py")
	disable.pressed.emit()
	assert_false(CardPacks.is_enabled("pack-10"))
	assert_string_contains(status.text, "Status: Disabled")
	CardPacks.rescan()
	assert_true(CardPacks.has_pack("pack-10"), "Rescan finds the ZIP again")
	assert_false(CardPacks.is_enabled("pack-10"), "and keeps the player's choice")
	assert_string_contains(status.text, "Status: Disabled")
	assert_false(enable.disabled)
	enable.pressed.emit()
	assert_true(CardPacks.is_enabled("pack-10"))
	CardPacks.rescan()
	assert_true(CardPacks.is_enabled("pack-10"))
	assert_eq(CardRegistry.names_in_set("ulg").size(), 143)

func test_pack_ten_buttons_follow_the_lan_catalogue_lock() -> void:
	var page := CardPacksScreen.new()
	add_child_autofree(page)
	await get_tree().process_frame
	var owner := Node.new()
	add_child_autofree(owner)
	CardPacks.lock_catalogue(owner)
	page._refresh()
	assert_true((page.find_child("EnablePack10", true, false) as Button).disabled)
	assert_true((page.find_child("DisablePack10", true, false) as Button).disabled)
	CardPacks.unlock_catalogue(owner)
	page._refresh()
	assert_false((page.find_child("DisablePack10", true, false) as Button).disabled)

func test_deck_requirements_survive_disable() -> void:
	CardPacks.set_current_deck_names(["Gaea's Cradle", "Dark Ritual"])
	assert_string_contains(CardPacks.disable_warning("pack-10"), "Gaea's Cradle")
	assert_false(CardPacks.disable_warning("pack-10").contains("Dark Ritual"))
	CardPacks.set_enabled("pack-10", false)
	assert_eq(CardPacks.packs_required_by(["Gaea's Cradle", "Dark Ritual"]), ["pack-10"])
	assert_eq(CardPacks.missing_requirements(["pack-10"]), ["pack-10"])

func test_urza_block_gold_emblems_and_stone_faces_ship() -> void:
	for code in ["usg", "ulg", "uds"]:
		for key in ["set_icon_" + code, "filter_%s_on" % code, "filter_%s_off" % code]:
			var texture := GameSkin.our_art(key)
			assert_not_null(texture, key)
			if texture != null: assert_eq(texture.get_size(), Vector2(48, 48))
		assert_not_null(GameSkin.set_icon(code), code)
	assert_eq(DeckFilter.SET_LABELS["usg"], "Urza's Saga")
	assert_eq(DeckFilter.SET_LABELS["ulg"], "Urza's Legacy")
	assert_eq(DeckFilter.SET_LABELS["uds"], "Urza's Destiny")

func test_urza_block_is_in_draft_selection_and_lan_compatibility() -> void:
	var page := DraftPoolDialog.new()
	add_child_autofree(page)
	await get_tree().process_frame
	for code in ["usg", "ulg", "uds"]:
		assert_true(page.groups.has(code), code)
	assert_true(SgCompatibility.enabled_packs().has("pack-10"))
	var stamp := SgCompatibility.fingerprint()
	CardPacks.set_enabled("pack-10", false)
	assert_ne(stamp, SgCompatibility.fingerprint())

# -------------------------------------------------- the two-digit audit --

func test_pack_ids_sort_by_number_not_by_text() -> void:
	var ids: Array[String] = ["pack-10", "pack-2", "pack-1", "pack-9"]
	CardPacks.sort_ids(ids)
	assert_eq(ids, ["pack-1", "pack-2", "pack-9", "pack-10"] as Array[String])
	var odd: Array = ["custom", "pack-10", "pack-x", "pack-3"]
	CardPacks.sort_ids(odd)
	assert_eq(odd, ["pack-3", "pack-10", "custom", "pack-x"], "an id that is no numbered pack goes after them")
	assert_eq(CardPacks.number_of("pack-10"), 10)
	assert_eq(CardPacks.number_of("pack-1"), 1)
	assert_eq(CardPacks.number_of("pack-"), 0)
	assert_eq(CardPacks.number_of("10"), 0, "a bare number is not an id")
	var found := CardPacks.available_ids()
	assert_eq(found.back(), "pack-10", "the found packs end with Pack 10")
	var sorted := found.duplicate()
	sorted.sort_custom(func(a, b): return CardPacks.number_of(a) < CardPacks.number_of(b))
	assert_eq(found, sorted)

func test_a_deck_of_pack_two_and_pack_ten_cards_names_them_in_number_order() -> void:
	CardPacks.set_enabled("pack-2", true)
	var names: Array[String] = ["Gaea's Cradle", "Hymn to Tourach"]
	assert_eq(CardPacks.packs_required_by(names), ["pack-2", "pack-10"] as Array[String])
	var model := DeckModel.new()
	assert_eq(model.add("Gaea's Cradle"), "")
	assert_eq(model.add("Hymn to Tourach"), "")
	assert_eq(model.required_pack_ids(), ["pack-2", "pack-10"] as Array[String])

func test_the_lan_stamp_names_pack_ten_after_pack_two() -> void:
	CardPacks.set_enabled("pack-2", true)
	assert_eq(SgCompatibility.enabled_packs(), ["pack-2", "pack-10"])
	assert_eq(SgCompatibility.pack_labels(SgCompatibility.enabled_packs()), "Packs 2, 10")
	assert_true(SgCompatibility.valid_stamp(SgCompatibility.stamp()))

func test_pack_ten_is_its_own_file_and_environment_variable() -> void:
	assert_eq(CardPacks._id_for("/somewhere/Pack-10-Urza-Block.zip"), "pack-10")
	assert_eq(CardPacks._id_for("/somewhere/Pack-1-DotP-complete.zip"), "pack-1")
	assert_eq(CardPacks.file_name_for("pack-10"), UrzaBlockPack.FILE_NAME)
	assert_eq(CardPacks.label_for("pack-10"), "Pack 10")
	var explicit := OS.get_environment("SHANDALAR_PACK_10")
	assert_ne(explicit, "", "the runner exports the Pack 10 fixture")
	assert_eq(CardPacks.candidate_paths("pack-10")[0], explicit)
	assert_ne(CardPacks.candidate_paths("pack-1")[0], explicit, "Pack 1 reads SHANDALAR_PACK_1, not _10")
	# The zip is known by what it holds: Pack 10's folder is not Pack 1's.
	assert_eq(CardPacks.pack_in(explicit), "pack-10")
	var refused := CardPacks.install_pack(ProjectSettings.globalize_path("res://project.godot"), "user://nowhere")
	assert_string_contains(String(refused.message), "(Pack-1 to Pack-10)")

func test_a_campaign_offers_pack_ten_by_its_number_and_name() -> void:
	assert_eq(AdventurePacks.title("pack-10"), "Pack 10 · The Urza Block")

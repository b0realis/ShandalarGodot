extends GutTest
## Robustness campaign 2026-10-12 — Booster Draft.
##
##   * b2-2: the timed draft's shelf shows every dealt card, whatever Extras
##     switches the ordinary builder remembers, and the draft never writes
##     that memory.
##   * b2-3: `Card pool…` groups by what each set PRINTED (reprints, Fifth
##     Edition, the basic lands); a whole-set pool can be dealt; the setup
##     counts sets the same way.
##   * b2-12: `Clear deck` in a draft keeps the draft's title.

const FOLDER := "user://test_c2_f_deck_draft"
var files: Array[String] = []
var _had_extras := false
var _old_extras: Variant
var _had_selection := false
var _old_selection: Variant
var _enabled_before: Array[String] = []


func before_each() -> void:
	CardRegistry.ensure_loaded()
	_had_extras = Settings.has_value(DeckBuilderScreen.EXTRAS_SETTING)
	_old_extras = Settings.get_value(DeckBuilderScreen.EXTRAS_SETTING, null)
	_had_selection = Settings.has_value(DraftPoolConfig.SETTING)
	_old_selection = Settings.get_value(DraftPoolConfig.SETTING, [])


func after_each() -> void:
	await get_tree().process_frame
	if _had_extras: Settings.set_value(DeckBuilderScreen.EXTRAS_SETTING, _old_extras, false)
	else: Settings.clear_value(DeckBuilderScreen.EXTRAS_SETTING)
	if _had_selection: Settings.set_value(DraftPoolConfig.SETTING, _old_selection, false)
	else: Settings.clear_value(DraftPoolConfig.SETTING)
	for path in files:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	files.clear()


func _all_packs_on() -> void:
	_enabled_before.clear()
	for id in CardPacks.available_ids():
		if CardPacks.is_enabled(id):
			_enabled_before.append(id)
		CardPacks.set_enabled(id, true)


func _packs_back() -> void:
	for id in CardPacks.available_ids():
		CardPacks.set_enabled(id, _enabled_before.has(id))


func _session(counts: Dictionary) -> DraftSession:
	var pool := SealedPool.new()
	pool.counts = counts
	var cards: Array[String] = []
	for card_name in pool.counts:
		for _i in pool.counts[card_name]: cards.append(card_name)
	pool.packs = [{"title": "Test pack", "cards": cards}]
	var store := DraftStore.new()
	assert_eq(store.prepare(FOLDER, pool, DraftPoolConfig.defaults()), "")
	files.append_array([store.deck_path, store.pool_path,
		store.deck_path + ".pending", store.pool_path + ".pending"])
	var session := DraftSession.new()
	session.pool = pool
	session.store = store
	session.seconds = 600
	add_child_autofree(session)
	return session


# ------------------------------------------------------------- b2-2 --

func test_the_draft_shelf_ignores_the_builder_s_remembered_extras() -> void:
	var remembered := {"original": false, "pack1": false, "sets": {}}
	Settings.set_value(DeckBuilderScreen.EXTRAS_SETTING, remembered, false)
	var session := _session({"Lightning Bolt": 2, "Mountain": 20, "Forest": 1})
	session.start_building()
	await get_tree().process_frame
	assert_eq(session.builder._copies_listed(), 23, "every dealt card is on the shelf")
	assert_true(session.builder.filter.original_cards_on, "the draft opens with every source on")
	# Whatever the draft does with Extras stays in the draft.
	session.builder.filter.original_cards_on = false
	session.builder.filter.revision += 1
	session.builder._refresh_inventory()
	assert_eq(Settings.get_value(DeckBuilderScreen.EXTRAS_SETTING, {}), remembered,
		"the builder's memory is untouched")
	session.finish("done")


func test_the_ordinary_builder_still_remembers_its_extras() -> void:
	Settings.set_value(DeckBuilderScreen.EXTRAS_SETTING,
		{"original": false, "pack1": true, "sets": {}}, false)
	var builder: DeckBuilderScreen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(builder)
	await get_tree().process_frame
	assert_false(builder.filter.original_cards_on, "restored as before")


# ------------------------------------------------------------ b2-12 --

func test_clear_deck_in_a_draft_keeps_the_draft_title() -> void:
	var session := _session({"Lightning Bolt": 2, "Mountain": 20})
	session.start_building()
	await get_tree().process_frame
	var title := session.builder.deck.deck_name
	assert_true(title.begins_with("Draft "), title)
	session.builder._add_one("Lightning Bolt")
	session.builder._run_command("Clear deck")
	assert_eq(session.builder.deck.total(), 0, "cleared")
	assert_eq(session.builder.deck.deck_name, title, "the title stays")
	session.builder._run_command("Restore deck")
	assert_eq(session.builder.deck.total(), 1, "Restore still restores")
	session.builder._run_command("Clear deck")
	session.builder._add_one("Mountain")
	session.finish("done")
	var saved := DeckStore.title_in(FileAccess.get_file_as_string(session.store.deck_path))
	assert_eq(saved, title, "the saved draft deck keeps its title")


# ------------------------------------------------------------- b2-3 --

func test_card_pool_groups_every_set_by_what_it_printed() -> void:
	_all_packs_on()
	var panel := DraftPoolDialog.new()
	add_child_autofree(panel)
	await get_tree().process_frame
	var short: Array[String] = []
	for code in CardRegistry.active_set_order():
		var members := 0
		for card_name in CardRegistry.all_names():
			if SealedPool.slot_of(card_name) != "" and CardRegistry.card_in_set(card_name, code):
				members += 1
		if members == 0:
			continue
		if not panel.groups.has(code):
			short.append("%s missing (%d cards)" % [code, members])
			continue
		var listed: int = (panel.groups[code] as TreeItem).get_child_count()
		if listed != members:
			short.append("%s: %d of %d" % [code, listed, members])
	assert_eq(short, [] as Array[String], "each set lists exactly what it printed")
	if CardPacks.is_enabled("pack-7"):
		assert_true(panel.groups.has("5ed"), "Fifth Edition has its group")
	_packs_back()


func test_basic_lands_head_the_list_and_a_reprint_is_one_choice() -> void:
	_all_packs_on()
	var panel := DraftPoolDialog.new()
	add_child_autofree(panel)
	await get_tree().process_frame
	var basics: TreeItem = panel.groups.get(DraftPoolDialog.BASICS_GROUP)
	assert_not_null(basics, "a Basic lands group")
	if basics != null:
		var names: Array[String] = []
		for row in basics.get_children():
			names.append(String(row.get_metadata(0)["card"]))
		assert_eq(names.size(), 5)
		for land in SealedPool.LAND_NAMES:
			assert_true(names.has(String(land)), land)
		assert_eq(panel.tree.get_root().get_first_child(), basics, "first in the list")
	panel.choose(["Lightning Bolt"])
	var bolt_rows: Array = panel.name_rows.get("Lightning Bolt", [])
	assert_gt(bolt_rows.size(), 1, "Lightning Bolt is listed under each set that printed it")
	for row: TreeItem in bolt_rows:
		assert_true(row.is_checked(0), "checked everywhere")
	assert_string_contains(panel.summary.text, "1 cards")
	_packs_back()


func test_a_single_set_pool_can_be_dealt() -> void:
	_all_packs_on()
	var panel := DraftPoolDialog.new()
	add_child_autofree(panel)
	await get_tree().process_frame
	for code in ["4ed", "5ed"]:
		var group: TreeItem = panel.groups.get(code)
		if group == null:
			continue
		var names: Array = []
		for row in group.get_children():
			names.append(row.get_metadata(0)["card"])
		# The basic lands come from their own group, as the window offers them.
		for row in (panel.groups[DraftPoolDialog.BASICS_GROUP] as TreeItem).get_children():
			names.append(row.get_metadata(0)["card"])
		panel.choose(names)
		panel._save()
		assert_eq(DraftPoolConfig.validate(DraftPoolConfig.defaults(), DraftPoolConfig.selected()), "",
			"%s with the basic lands can be dealt" % code)
	_packs_back()


func test_the_setup_counts_sets_by_what_they_printed() -> void:
	_all_packs_on()
	Settings.set_value(DraftPoolConfig.SETTING, ["Mountain"], false)
	var setup := DraftSetup.new()
	add_child_autofree(setup)
	await get_tree().process_frame
	var expected := 0
	for code in CardRegistry.active_set_order():
		if CardRegistry.card_in_set("Mountain", code):
			expected += 1
	assert_gt(expected, 1, "Mountain was printed in more than one set")
	assert_string_contains(setup.pool_summary.text, "1 eligible cards from %d sets" % expected)
	_packs_back()

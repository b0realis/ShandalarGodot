extends GutTest
## THE SEALED DECK'S CARD POOL (2026-09-25): the sets its packs are dealt
## from, chosen in the window the way the AutoDeck window chooses its
## sets — the owner's brief: *"Sealed deck tournament simulation needs a
## card pool selection similar as AutoDeck. (So tournaments for a
## specific set can be simulated)"*. Every set in play is ticked until
## the player says otherwise, so the deal is the whole library's, as it
## was before the window had a pool; the choice is remembered with the
## four numbers; the Extras window's two switches are honoured the way
## the Inventory honours them; and no set ticked greys the dice.


var screen: DeckBuilderScreen
var _saved: Dictionary = {}


func before_each() -> void:
	CardRegistry.ensure_loaded()
	var settings: Array = DeckBuilderScreen.SEALED_SETTINGS.values()
	settings.append(DeckBuilderScreen.SEALED_FRESH_SETTING)
	settings.append(DeckBuilderScreen.SEALED_SETS_SETTING)
	for setting in settings:
		_saved[setting] = Settings.get_value(setting, 0) if Settings.has_value(setting) else null
		Settings.clear_value(setting)
	screen = load("res://game/deck_builder/deck_builder_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	for setting in _saved:
		if _saved[setting] == null:
			Settings.clear_value(setting)
		else:
			Settings.set_value(setting, _saved[setting], false)


func _window() -> OriginalDialog:
	for dialog in screen.open_dialogs():
		if dialog.has_meta("sealed_window"):
			return dialog
	return null


func _in_window(name: String) -> Node:
	var window := _window()
	return null if window == null else window.find_child(name, true, false)


func _open() -> void:
	screen._dice_button.pressed.emit()
	await get_tree().process_frame
	assert_not_null(_window(), "the sealed window")


func _ticked() -> Array[String]:
	var out: Array[String] = []
	for code in CardRegistry.active_set_order():
		var line: Button = _in_window("Set_" + code)
		if line != null and line.text.begins_with("[x] "):
			out.append(code)
	return out


func _set_cards(code: String) -> Array[String]:
	var out: Array[String] = []
	for card_name in CardRegistry.all_names():
		if CardRegistry.card_in_set(card_name, code):
			out.append(card_name)
	return out


func _defaults() -> Dictionary:
	return {"boosters": 3, "starters": 1, "free_lands": 0, "extras": 0}


# ------------------------------------------------------------ the pool --

func test_every_set_in_play_is_ticked_until_the_player_says_otherwise() -> void:
	await _open()
	var texts: Array = []
	for node in _window().find_children("*", "Label", true, false):
		texts.append((node as Label).text)
	assert_true(texts.has(DeckBuilderScreen.SEALED_POOL_HEAD), "the pool's heading")
	var active := CardRegistry.active_set_order()
	assert_gt(active.size(), 1, "more than one set in play")
	for code in active:
		var line: Button = _in_window("Set_" + code)
		assert_not_null(line, "a line for " + code)
		assert_eq(line.text, "[x] " + String(DeckFilter.SET_LABELS.get(code, code.to_upper())))
	assert_eq(_ticked(), active, "all of them, nothing remembered")
	var sheet := SealedPool.sheets(screen._pool)
	var pool_line: Label = _in_window("PoolLine")
	assert_eq(pool_line.text, "Every set — %d cards: %d rare, %d uncommon, %d common, %d land" % [
		sheet["rare"].size() + sheet["uncommon"].size() + sheet["common"].size() + sheet["land"].size(),
		sheet["rare"].size(), sheet["uncommon"].size(), sheet["common"].size(), sheet["land"].size()],
		"the whole library on the sheets")
	assert_false((_in_window("DealButton") as Button).disabled, "the dice are live")
	assert_not_null(_in_window("AllSetsButton"))
	assert_not_null(_in_window("NoSetsButton"))


func test_clear_all_greys_the_dice_and_select_all_brings_them_back() -> void:
	await _open()
	_in_window("NoSetsButton").pressed.emit()
	assert_eq(_ticked(), [] as Array[String], "nothing ticked")
	assert_eq((_in_window("PoolLine") as Label).text, DeckBuilderScreen.SEALED_EMPTY_POOL)
	assert_true((_in_window("DealButton") as Button).disabled, "no set, no deal")
	_in_window("AllSetsButton").pressed.emit()
	assert_eq(_ticked(), CardRegistry.active_set_order())
	assert_false((_in_window("DealButton") as Button).disabled)
	assert_true((_in_window("PoolLine") as Label).text.begins_with("Every set — "))


func test_one_set_ticked_deals_that_set_alone_and_is_remembered() -> void:
	await _open()
	_in_window("NoSetsButton").pressed.emit()
	_in_window("Set_4ed").pressed.emit()
	assert_eq(_ticked(), ["4ed"] as Array[String])
	var pool_line: Label = _in_window("PoolLine")
	assert_true(pool_line.text.begins_with("Fourth Edition — "), pool_line.text)
	_in_window("DealButton").pressed.emit()
	await get_tree().process_frame
	var tally: Label = _in_window("PoolTally")
	assert_true(tally.text.begins_with("105 cards — "), tally.text)
	assert_eq(Settings.get_value(DeckBuilderScreen.SEALED_SETS_SETTING, []), ["4ed"],
		"the choice is remembered with the numbers")
	var fourth := _set_cards("4ed")
	fourth.append_array(SealedPool.LAND_NAMES)
	var packs: Node = _in_window("PackList")
	assert_eq(packs.get_child_count(), 4, "one starter, three boosters")
	for pack in packs.get_children():
		(pack as Button).pressed.emit()
		for line in (_in_window("PackCards") as Node).get_children():
			var card_name := (line as Button).text.substr(2).strip_edges()
			assert_true(fourth.has(card_name), "%s is Fourth Edition's" % card_name)
	# Done puts that pool in force; every card of it is Fourth Edition's.
	for node in _window().find_children("*", "Button", true, false):
		if (node as Button).text == "Done":
			(node as Button).pressed.emit()
	await get_tree().process_frame
	assert_not_null(screen.sealed)
	for card_name in screen.sealed.names():
		assert_true(fourth.has(card_name), card_name)
	# And the window opens on the remembered choice.
	screen._dice_button.pressed.emit()
	await get_tree().process_frame
	assert_null(screen.sealed, "the medallion up again")
	await _open()
	assert_eq(_ticked(), ["4ed"] as Array[String], "remembered")


func test_the_basics_are_on_every_set_land_sheet() -> void:
	# The registry files the five basics under Unlimited; a Fourth
	# Edition booster still has its land slot.
	assert_false(CardRegistry.card_in_set("Plains", "4ed"), "the premise: Plains is filed elsewhere")
	var sheet := SealedPool.sheets(screen._sealed_source(["4ed"]))
	var lands: Array = SealedPool.LAND_NAMES.duplicate()
	lands.sort()
	assert_eq(sheet["land"], lands, "and still on the sheet, sorted as sheets are")
	var pool := screen._deal_sealed(_defaults(), 1997, ["4ed"])
	assert_eq(pool.total(), 105, "the owner's 105, lands dealt")
	assert_gt(pool.slot_counts()["land"], 0)


func test_a_remembered_set_no_longer_in_play_is_dropped() -> void:
	Settings.set_value(DeckBuilderScreen.SEALED_SETS_SETTING, ["4ed", "zzz", "leg"], false)
	assert_eq(screen._sealed_sets(), ["4ed", "leg"] as Array[String], "in play, in the registry's order")
	Settings.set_value(DeckBuilderScreen.SEALED_SETS_SETTING, ["zzz"], false)
	assert_eq(screen._sealed_sets(), [] as Array[String], "none in play: nothing ticked")
	await _open()
	assert_eq(_ticked(), [] as Array[String])
	assert_true((_in_window("DealButton") as Button).disabled, "and the dice grey, not a surprise library")
	Settings.set_value(DeckBuilderScreen.SEALED_SETS_SETTING, "not a list", false)
	assert_eq(screen._sealed_sets(), [] as Array[String], "a broken setting is no sets")


func test_the_extras_switches_are_honoured_like_the_inventory() -> void:
	var fourth := _set_cards("4ed")
	for land in SealedPool.LAND_NAMES:
		if not fourth.has(land):
			fourth.append(land)
	var source: Array = screen._sealed_source(["4ed"])
	assert_eq(source.size(), fourth.size(), "Fourth Edition's cards and the five basics")
	for data in source:
		assert_true(fourth.has((data as CardData).card_name))
	assert_true(fourth.size() > SealedPool.LAND_NAMES.size() + 100, "a whole set")
	screen.filter.original_cards_on = false
	var without: Array = screen._sealed_source(["4ed"])
	assert_lt(without.size(), source.size(), "the 1997 originals off: fewer cards on the sheets")
	screen.filter.original_cards_on = true
	assert_eq(screen._sealed_source(["4ed"]).size(), source.size(), "and back")


func test_no_sets_at_all_is_the_whole_library_and_remembers_nothing() -> void:
	var pool := screen._deal_sealed(_defaults(), 1997)
	var whole := SealedPool.new()
	whole.deal(screen._pool, 1997)
	assert_eq(pool.names(), whole.names(), "the deal before the window had a pool")
	assert_false(Settings.has_value(DeckBuilderScreen.SEALED_SETS_SETTING))
	var fourth := screen._deal_sealed(_defaults(), 1997, ["4ed"])
	var again := screen._deal_sealed(_defaults(), 1997, ["4ed"])
	assert_eq(fourth.names(), again.names(), "a seed over a set is a pool")
	assert_ne(fourth.names(), whole.names(), "and not the whole library's")
	assert_eq(Settings.get_value(DeckBuilderScreen.SEALED_SETS_SETTING, []), ["4ed"])


func test_the_pool_is_named_the_autodeck_way() -> void:
	var active := CardRegistry.active_set_order()
	assert_eq(DeckBuilderScreen._sealed_pool_name([]), "No set")
	assert_eq(DeckBuilderScreen._sealed_pool_name(active), "Every set")
	assert_eq(DeckBuilderScreen._sealed_pool_name(["4ed"]), "Fourth Edition")
	assert_eq(DeckBuilderScreen._sealed_pool_name(["leg", "4ed"]), "Legends, Fourth Edition",
		"in the registry's order, not the ticking's")
	assert_eq(DeckBuilderScreen._sealed_pool_name(["2ed", "arn", "atq", "leg"]), "4 sets")
	assert_eq(DeckBuilderScreen._sealed_pool_name(["zzz"]), "No set", "a set not in play is no set")

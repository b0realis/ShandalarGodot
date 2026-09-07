extends GutTest
## THE SEALED DECK (2026-09-07): the dice medallion left of Stats, the
## window it opens, the packs [SealedPool] deals, and the Inventory that
## then offers only what was dealt — the owner's brief on the 1997
## string table's roughed-in screen (`@SEALEDDECK_FOILPACKSCREEN`).


var screen: DeckBuilderScreen
var _saved: Dictionary = {}


func before_each() -> void:
	CardRegistry.ensure_loaded()
	# The window remembers its numbers; the tests must not.
	var settings: Array = DeckBuilderScreen.SEALED_SETTINGS.values()
	settings.append(DeckBuilderScreen.SEALED_FRESH_SETTING)
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


func _library() -> Array:
	var out: Array = []
	for card_name in CardRegistry.all_names():
		out.append(CardRegistry.get_card(card_name))
	return out


func _pool(boosters: int, starters: int, free_lands: int, extras: int,
		roll := 1997) -> SealedPool:
	var pool := SealedPool.new()
	pool.boosters = boosters
	pool.starters = starters
	pool.free_lands = free_lands
	pool.extras = extras
	pool.deal(_library(), roll)
	return pool


func _pack(pool: SealedPool, title: String) -> Array:
	for pack in pool.packs:
		if pack["title"] == title:
			return pack["cards"]
	return []


func _slots(cards: Array) -> Dictionary:
	var tally := {"rare": 0, "uncommon": 0, "common": 0, "land": 0}
	for card_name in cards:
		tally[SealedPool.slot_of(card_name)] += 1
	return tally


func _window() -> OriginalDialog:
	for dialog in screen.open_dialogs():
		if dialog.has_meta("sealed_window"):
			return dialog
	return null


func _in_window(name: String) -> Node:
	var window := _window()
	return null if window == null else window.find_child(name, true, false)


func _foot(text: String) -> Button:
	for node in _window().find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node
	return null


# ---------------------------------------------------------- the packs --

func test_the_four_sheets_split_the_library_by_slot() -> void:
	var sheet := SealedPool.sheets(_library())
	assert_eq(sheet["land"].size(), 5, "the five basics are the land sheet")
	for land in SealedPool.LAND_NAMES:
		assert_true(sheet["land"].has(land), land)
		assert_false(sheet["common"].has(land), "%s is no common" % land)
	assert_true(sheet["rare"].has("Tetsuo Umezawa"), "a legend is dealt in the rare slot")
	assert_true(sheet["rare"].has("Shivan Dragon"))
	assert_true(sheet["uncommon"].has("Serra Angel"))
	assert_true(sheet["common"].has("Lightning Bolt"))
	for slot in SealedPool.SLOT_ORDER:
		var sorted: Array = sheet[slot].duplicate()
		sorted.sort()
		assert_eq(sheet[slot], sorted, "%s sheet sorted, so a seed means one pool" % slot)


func test_a_booster_and_a_starter_hold_what_the_owner_said() -> void:
	var pool := _pool(1, 1, 0, 0)
	assert_eq(pool.packs.size(), 2)
	assert_eq(String(pool.packs[0]["title"]), "Starter Pack 1", "starters first")
	assert_eq(String(pool.packs[1]["title"]), "Booster Pack 1")
	var booster := _pack(pool, "Booster Pack 1")
	assert_eq(booster.size(), 15)
	assert_eq(_slots(booster), {"rare": 1, "uncommon": 3, "common": 10, "land": 1},
		"1 rare or legend, 3 uncommons, 1 land, 10 commons")
	var starter := _pack(pool, "Starter Pack 1")
	assert_eq(starter.size(), 60)
	assert_eq(_slots(starter), {"rare": 3, "uncommon": 9, "common": 26, "land": 22},
		"3 rare, 9 uncommon, 26 common, 22 lands")
	assert_eq(pool.total(), 75)
	assert_eq(pool.card_total(), 75, "the count line's arithmetic agrees")


func test_free_lands_and_random_cards_are_packs_of_their_own() -> void:
	var pool := _pool(0, 0, 2, 7)
	assert_eq(pool.packs.size(), 2)
	var lands := _pack(pool, "Free Lands")
	assert_eq(lands.size(), 10, "two of EACH type")
	for land in SealedPool.LAND_NAMES:
		assert_eq(lands.count(land), 2, land)
	assert_eq(_pack(pool, "Random Cards").size(), 7)
	assert_eq(pool.total(), 17)
	assert_eq(pool.card_total(), 17)


func test_the_defaults_deal_the_owners_105() -> void:
	var pool := SealedPool.new()
	assert_eq(pool.boosters, 3)
	assert_eq(pool.starters, 1)
	assert_eq(pool.free_lands, 0)
	assert_eq(pool.extras, 0)
	assert_eq(pool.card_total(), 105)
	pool.deal(_library(), 7)
	assert_eq(pool.total(), 105)
	assert_eq(pool.summary(), "105 cards — 6 rare, 18 uncommon, 56 common, 25 land")


func test_a_seed_is_a_pool() -> void:
	var one := _pool(2, 1, 1, 3, 42)
	var again := _pool(2, 1, 1, 3, 42)
	var other := _pool(2, 1, 1, 3, 43)
	assert_eq(again.names(), one.names(), "same roll, same pool")
	assert_eq(again.counts, one.counts)
	assert_ne(other.names(), one.names(), "another roll, another pool")


func test_a_pack_never_repeats_a_spell_within_a_slot() -> void:
	var pool := _pool(4, 2, 0, 0, 11)
	for pack in pool.packs:
		var seen := {}
		for card_name in pack["cards"]:
			if SealedPool.slot_of(card_name) == "land":
				continue
			assert_false(seen.has(card_name), "%s twice in %s" % [card_name, pack["title"]])
			seen[card_name] = true


func test_copies_are_counted_across_packs() -> void:
	var pool := _pool(0, 0, 3, 0)
	assert_eq(pool.copies_of("Plains"), 3)
	assert_eq(pool.copies_of("Shivan Dragon"), 0)
	assert_eq(pool.names(), _sorted(SealedPool.LAND_NAMES))


func _sorted(names: Array) -> Array[String]:
	var out: Array[String] = []
	for n in names:
		out.append(String(n))
	out.sort()
	return out


# ------------------------------------------------------ the medallion --

func test_the_dice_medallion_sits_left_of_stats_on_the_command_row() -> void:
	var dice: Button = screen._dice_button
	assert_not_null(dice)
	assert_eq(dice.get_meta("icon_cell"), FilterBar.DICE_CELL, "the dice, composed on the X stone")
	assert_eq(dice.size, Vector2(FilterBar.DICE_SIZE, FilterBar.DICE_SIZE))
	assert_true(dice.toggle_mode, "it latches")
	assert_false(dice.button_pressed, "up while the whole library is on offer")
	assert_null(screen.sealed)
	var stats: Button = screen._stats_button
	assert_lt(dice.position.x + dice.size.x, stats.global_position.x, "left of Stats")
	# Centred on the row: it is taller than the row and overhangs it evenly.
	assert_gt(float(FilterBar.DICE_SIZE), screen.COMMAND_BAR_H)
	var row_centre: float = screen._command_row.position.y + screen.COMMAND_BAR_H / 2.0
	assert_almost_eq(dice.position.y + dice.size.y / 2.0, row_centre, 0.51, "centred on the row")


func test_the_medallion_opens_the_window_and_stays_up() -> void:
	screen._dice_button.pressed.emit()
	await get_tree().process_frame
	var window := _window()
	assert_not_null(window, "the sealed window")
	var texts: Array = []
	for node in window.find_children("*", "Label", true, false):
		texts.append((node as Label).text)
	assert_true(texts.has(DeckBuilderScreen.SEALED_TITLE), "the title")
	assert_eq(texts.count(DeckBuilderScreen.SEALED_BRIEF % DeckModel.MIN_CARDS), 1,
		"the one subtitle, the owner's brief")
	assert_false(screen._dice_button.button_pressed, "down only once a pool is in force")
	assert_null(screen.sealed)
	assert_true(_foot("Done").disabled, "nothing dealt yet")
	assert_not_null(_foot("Cancel"))
	var count: Label = _in_window("CountLine")
	assert_eq(count.text, "Each player gets 105 cards", "the 1997 count line, for the defaults")
	for name in ["BoostersField", "StartersField", "FreeLandsField", "ExtrasField"]:
		assert_not_null(_in_window(name), name)
	assert_eq((_in_window("BoostersField") as SpinBox).value, 3.0)
	assert_eq((_in_window("StartersField") as SpinBox).value, 1.0)
	assert_eq((_in_window("FreeLandsField") as SpinBox).value, 0.0)
	assert_eq((_in_window("ExtrasField") as SpinBox).value, 0.0)
	assert_true(texts.has(DeckBuilderScreen.SEALED_PACKS_HEAD), "@SEALEDDECK_FOILPACKSCREEN")
	assert_true(texts.has(DeckBuilderScreen.SEALED_CARDS_HEAD))
	screen._on_escape()
	await get_tree().process_frame
	assert_null(_window(), "Escape is Cancel")
	assert_null(screen.sealed)


func test_the_count_line_follows_the_spinners() -> void:
	screen._dice_button.pressed.emit()
	await get_tree().process_frame
	var boosters: SpinBox = _in_window("BoostersField")
	var lands: SpinBox = _in_window("FreeLandsField")
	boosters.value = 1
	lands.value = 2
	assert_eq((_in_window("CountLine") as Label).text, "Each player gets %d cards" % (15 + 60 + 10))


func test_the_dice_in_the_window_deal_and_deal_again() -> void:
	screen._dice_button.pressed.emit()
	await get_tree().process_frame
	(_in_window("ExtrasField") as SpinBox).value = 2
	_in_window("DealButton").pressed.emit()
	await get_tree().process_frame
	var tally: Label = _in_window("PoolTally")
	assert_true(tally.text.begins_with("107 cards — "), tally.text)
	var packs: Node = _in_window("PackList")
	assert_eq(packs.get_child_count(), 5, "one starter, three boosters, the random cards")
	assert_true((packs.get_child(0) as Button).text.begins_with("Starter Pack 1"))
	assert_true((packs.get_child(0) as Button).button_pressed, "the first pack is selected")
	var cards: Node = _in_window("PackCards")
	assert_eq(cards.get_child_count(), 60, "its sixty cards")
	assert_false(_foot("Done").disabled)
	assert_eq(int(Settings.get_value("sealed_extras", -1)), 2, "the numbers are remembered")
	var first_names := []
	for line in cards.get_children():
		first_names.append((line as Button).text)
	(packs.get_child(1) as Button).pressed.emit()
	assert_eq(cards.get_child_count(), 15, "a booster's fifteen")
	assert_true((packs.get_child(1) as Button).button_pressed)
	assert_false((packs.get_child(0) as Button).button_pressed)
	_in_window("DealButton").pressed.emit()
	await get_tree().process_frame
	var again := []
	for line in (_in_window("PackCards") as Node).get_children():
		again.append((line as Button).text)
	assert_ne(again, first_names, "another click, another selection")


func test_done_puts_the_pool_in_force_and_the_medallion_down() -> void:
	screen._dice_button.pressed.emit()
	await get_tree().process_frame
	_in_window("DealButton").pressed.emit()
	_foot("Done").pressed.emit()
	await get_tree().process_frame
	assert_null(_window())
	assert_not_null(screen.sealed)
	assert_true(screen._dice_button.button_pressed, "the medallion shows pressed")
	assert_eq(screen.sealed.total(), 105)
	assert_true(screen._count_label.text.begins_with("105 pool cards"), screen._count_label.text)
	assert_eq(screen._inventory.copies_shown(), 105, "the Inventory is the pool")
	assert_eq(screen._inventory.entry_count(), screen.sealed.names().size(),
		"one entry per name, copies on the badge")
	# Depress it: the whole library again.
	screen._dice_button.pressed.emit()
	await get_tree().process_frame
	assert_null(screen.sealed)
	assert_false(screen._dice_button.button_pressed)
	assert_true(screen._count_label.text.begins_with("%d cards" % CardRegistry.size()),
		screen._count_label.text)


func test_done_starts_from_an_empty_deck_unless_told_not_to() -> void:
	screen._set_deck(DeckModel.from_deck_list(
		DeckList.load_file("res://decks/white_knights.deck", true)))
	screen.refresh()
	var held := screen.deck.total()
	assert_gt(held, 0)
	screen._dice_button.pressed.emit()
	await get_tree().process_frame
	var fresh: Button = _in_window("FreshLine")
	assert_true(fresh.text.begins_with("[x]"), "on by default")
	_in_window("DealButton").pressed.emit()
	_foot("Done").pressed.emit()
	await get_tree().process_frame
	assert_eq(screen.deck.total(), 0, "cleared for the new pool")
	assert_eq(screen._clear_button.text, "Restore deck", "by Clear deck's own route")
	screen._clear_deck()
	assert_eq(screen.deck.total(), held, "and Restore deck brings it back")
	# Off, the deck is left as it is.
	screen._dice_button.pressed.emit()
	await get_tree().process_frame
	screen._dice_button.pressed.emit()
	await get_tree().process_frame
	fresh = _in_window("FreshLine")
	fresh.pressed.emit()
	assert_true(fresh.text.begins_with("[  ]"))
	_in_window("DealButton").pressed.emit()
	_foot("Done").pressed.emit()
	await get_tree().process_frame
	assert_eq(screen.deck.total(), held, "kept")


# ------------------------------------------------------ the inventory --

func _enter(boosters: int, starters: int, free_lands: int, extras: int) -> SealedPool:
	var pool := _pool(boosters, starters, free_lands, extras)
	screen._enter_sealed(pool)
	return pool


func test_the_inventory_is_the_pool_less_what_is_placed() -> void:
	var pool := _enter(0, 0, 3, 0)
	assert_eq(screen._inventory.entry_count(), 5, "the five basics")
	assert_eq(screen._inventory.copies_shown(), 15)
	var cells: Array = screen._inventory.cell_nodes()
	assert_eq(cells[0].card_name, "Forest")
	assert_true(cells[0].badge.visible, "three in hand")
	assert_eq(cells[0].badge_label.text, "3")
	screen._add_one("Forest")
	cells = screen._inventory.cell_nodes()
	assert_eq(cells[0].badge_label.text, "2", "two left")
	screen._add_one_side("Forest")
	cells = screen._inventory.cell_nodes()
	assert_false(cells[0].badge.visible, "one left wears no badge, like a single")
	assert_eq(screen._inventory.copies_shown(), 13)
	screen._add_one("Forest")
	assert_eq(screen._inventory.entry_count(), 4, "the last copy placed, the card is gone")
	assert_eq(screen._inventory.cell_nodes()[0].card_name, "Island")
	assert_eq(pool.copies_of("Forest"), 3, "the pool itself is untouched")
	assert_true(screen._count_label.text.begins_with("12 pool cards"), screen._count_label.text)


func test_every_door_refuses_more_than_the_pool_holds() -> void:
	_enter(0, 0, 2, 0)
	assert_true(screen._add_one("Plains"))
	assert_true(screen._add_one("Plains"))
	assert_false(screen._add_one("Plains"), "a third of two")
	assert_eq(screen._status_label.text, "Your sealed pool holds only 2 Plains")
	assert_eq(screen.deck.count_of("Plains"), 2)
	screen._add_one_side("Plains")
	assert_eq(screen.deck.side_count_of("Plains"), 0, "the sideboard door too")
	screen._add_playset("Island")
	assert_eq(screen.deck.count_of("Island"), 2, "a playset stops at what is held")
	screen._add_basic_land("Swamp", 5)
	assert_eq(screen.deck.count_of("Swamp"), 2, "the land dialog too")
	assert_false(screen._add_one("Shivan Dragon"), "not dealt at all")
	assert_eq(screen._status_label.text, "Your sealed pool has no Shivan Dragon")
	assert_eq(screen.deck.count_of("Shivan Dragon"), 0)
	assert_eq(screen._sealed_refusal("Mountain"), "", "and what is held is welcome")


func test_the_pool_is_filtered_like_the_library() -> void:
	_enter(2, 1, 0, 0)
	var all := screen._inventory.entry_count()
	screen.filter.text = "a"
	screen.filter.revision += 1
	screen._refresh_inventory()
	assert_lt(screen._inventory.entry_count(), all, "the search narrows the pool")
	for entry in screen._inventory._visible_entries():
		assert_true(String(entry[0].card_name).to_lower().contains("a"))


func test_leaving_the_pool_restores_the_deck_count_badge() -> void:
	_enter(0, 0, 1, 0)
	assert_eq(screen._inventory.badge_min, 2)
	assert_false(screen._inventory.count_source.is_valid())
	screen._leave_sealed()
	assert_eq(screen._inventory.badge_min, 1)
	assert_true(screen._inventory.count_source.is_valid())
	screen._add_one("Plains")
	screen._add_one("Plains")
	screen._add_one("Plains")
	assert_eq(screen.deck.count_of("Plains"), 3, "no pool, no ceiling")


func test_the_pool_survives_a_deck_change_without_a_pool_walk_of_the_library() -> void:
	_enter(1, 1, 0, 0)
	var before := screen.filter_passes
	var first: String = screen._inventory.cell_nodes()[0].card_name
	screen._add_one(first)
	assert_gt(screen.filter_passes, before, "the pool is re-read (it is 75 cards, not 897)")
	assert_eq(screen._inventory.copies_shown(), 74)

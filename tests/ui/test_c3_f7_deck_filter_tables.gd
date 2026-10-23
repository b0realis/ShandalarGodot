extends GutTest
## Adventure campaign fix pass 2026-10-23, h5-10 round 2: THE FILTER'S
## TABLES. With every card pack on, a walk of the library through
## [method DeckFilter.matches] cost 70 ms, 59 of it in [method
## DeckFilter.matches_set] asking the registry, set by set, whether each
## card is in it — and every new builder sorted the library again. Two
## tables now answer instead, both kept by card NAME for one registry load:
## the sets each name is in ([method DeckFilter._sets_holding]) and the
## library in each sort order ([method DeckFilter._pool_in_order]).
##
## THE PROOF IS THE WHOLE LIBRARY: every card, under every combination of
## the two source switches and several set selections, answers exactly as
## the registry walk it replaced (copied here as the reference). Run with
## every card pack this machine has switched on, so the expansions' and
## Pack 1's sets are in it; a machine without them proves the 1997 sets.

var _packs_before: Array = []
var _pool: Array[CardData] = []


func before_all() -> void:
	_packs_before = Settings.enabled_card_packs().duplicate()
	for id in CardPacks.available_ids():
		CardPacks.set_enabled(id, true)
	CardRegistry.ensure_loaded()


func after_all() -> void:
	for id in CardPacks.available_ids():
		if CardPacks.is_enabled(id) != _packs_before.has(id):
			CardPacks.set_enabled(id, _packs_before.has(id))
	CardRegistry.ensure_loaded()


func before_each() -> void:
	CardRegistry.ensure_loaded()
	_pool.clear()
	for card_name in CardRegistry.all_names():
		_pool.append(CardRegistry.get_card(card_name))


# ---------------------------------------------- the walks they replaced --

func _walked_matches_set(f: DeckFilter, d: CardData) -> bool:
	if not CardRegistry.has_card(d.card_name):
		return f.original_cards_on and f.set_on(d.set_code)
	for code in CardRegistry.active_set_order():
		if f.set_on(code) and CardRegistry.card_in_set(d.card_name, code,
				f.completion_pack_on, f.original_cards_on):
			return true
	return false


func _walked_preferred_printing(f: DeckFilter, d: CardData) -> String:
	if not CardRegistry.has_card(d.card_name):
		return d.set_code
	var first := ""
	for code in CardRegistry.active_set_order():
		if not f.set_on(code) or not CardRegistry.card_in_set(d.card_name, code,
				f.completion_pack_on, f.original_cards_on):
			continue
		if code == d.set_code:
			return code
		if first == "":
			first = code
	return first if first != "" else d.set_code


func _sorted_walk(f: DeckFilter, pool: Array) -> Array[CardData]:
	var column: int = DeckFilter.SORT_COLUMN.get(f.sort_mode, DeckFilter.FACT_NAME)
	var keyed: Array = []
	for d in pool:
		var facts := DeckFilter._facts_for(d)
		keyed.append([0 if column == DeckFilter.FACT_NAME else int(facts[column]),
			facts[DeckFilter.FACT_NAME], d])
	keyed.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return a[0] < b[0]
		return a[1] < b[1])
	var out: Array[CardData] = []
	for row in keyed:
		out.append(row[2])
	return out


func _walked_apply(f: DeckFilter, pool: Array) -> Array[String]:
	var lead: Array[String] = []
	var rest: Array[String] = []
	for d in _sorted_walk(f, pool):
		if not (_walked_matches_set(f, d) and f.matches_text(d) and f.matches_cost(d)
				and f.matches_power(d) and f.matches_toughness(d) and f.matches_rarity(d)
				and f.matches_artist(d) and f.matches_ability(d) and f.matches_color(d)
				and f.matches_type(d)):
			continue
		if f._needle != "" and String(DeckFilter._facts_for(d)[DeckFilter.FACT_NAME]).begins_with(f._needle):
			lead.append(d.card_name)
		else:
			rest.append(d.card_name)
	lead.append_array(rest)
	return lead


func _names(cards: Array) -> Array[String]:
	var out: Array[String] = []
	for d in cards:
		out.append((d as CardData).card_name)
	return out


## The set selections each check runs under: everything on, every other set
## off, and one expansion (or 1997 set) alone.
func _selections() -> Array[Dictionary]:
	var codes := CardRegistry.active_set_order()
	var every_other := {}
	for i in codes.size():
		every_other[codes[i]] = i % 2 == 0
	var alone := {}
	var pick: String = codes[codes.size() - 1]
	for code in codes:
		alone[code] = code == pick
	return [{}, every_other, alone]


func _filter(completion: bool, original: bool, selection: Dictionary) -> DeckFilter:
	var f := DeckFilter.new()
	f.completion_pack_on = completion
	f.original_cards_on = original
	for code in selection:
		f.sets[code] = bool(selection[code])
	f.revision += 1
	return f


# ----------------------------------------------------------- the proofs --

func test_matches_set_answers_as_the_registry_walk_for_every_card() -> void:
	var pool: Array = _pool.duplicate()
	pool.append(ProxyCard.data_for("No Such Card"))
	var wrong: Array[String] = []
	for completion in [true, false]:
		for original in [true, false]:
			for selection in _selections():
				var f := _filter(completion, original, selection)
				for d in pool:
					if f.matches_set(d) != _walked_matches_set(f, d):
						wrong.append("%s (pack1 %s, 1997 %s, %d sets off)" % [d.card_name, completion,
							original, selection.values().count(false)])
	assert_eq(wrong.size(), 0, "every card, every switch: %s" % [wrong.slice(0, 5)])


func test_the_printing_shown_is_the_registry_walk_s_for_every_card() -> void:
	var wrong: Array[String] = []
	for completion in [true, false]:
		for original in [true, false]:
			for selection in _selections():
				var f := _filter(completion, original, selection)
				for d in _pool:
					if f.preferred_printing(d) != _walked_preferred_printing(f, d):
						wrong.append(d.card_name)
	assert_eq(wrong.size(), 0, "every card, every switch: %s" % [wrong.slice(0, 5)])


func test_apply_lists_the_library_exactly_as_before() -> void:
	var cases: Array[Callable] = [
		func(_f: DeckFilter) -> void: pass,
		func(f: DeckFilter) -> void: f.text = "bo",
		func(f: DeckFilter) -> void: f.toggle_color(Mtg.ManaColor.R),
		func(f: DeckFilter) -> void: f.toggle_type(Mtg.CardType.CREATURE),
		func(f: DeckFilter) -> void: f.original_cards_on = false,
		func(f: DeckFilter) -> void: f.toggle_set(CardRegistry.active_set_order()[0]),
	]
	for mode in DeckFilter.Sort.values():
		for i in cases.size():
			var f := DeckFilter.new()
			f.sort_mode = mode
			cases[i].call(f)
			assert_eq(_names(f.apply(_pool)), _walked_apply(f, _pool),
				"sort %d, case %d: the same cards in the same order" % [mode, i])


func test_the_library_s_order_is_kept_for_the_next_builder() -> void:
	var first := DeckFilter.new()
	var order := _names(first._pool_in_order(_pool))
	assert_eq(order, _names(_sorted_walk(first, _pool)), "the sort itself is unchanged")
	assert_true(DeckFilter._library_orders.has(DeckFilter.Sort.NAME), "kept")
	# The next builder: a new filter and a new array of the same cards.
	var again: Array[CardData] = []
	for card_name in CardRegistry.all_names():
		again.append(CardRegistry.get_card(card_name))
	assert_eq(_names(DeckFilter.new()._pool_in_order(again)), order, "the same order")
	# Read from the table, not sorted again: a doctored table is what the
	# next filter gets.
	var doctored: PackedInt32Array = (DeckFilter._library_orders[DeckFilter.Sort.NAME] as PackedInt32Array).duplicate()
	doctored.reverse()
	DeckFilter._library_orders[DeckFilter.Sort.NAME] = doctored
	var backwards := order.duplicate()
	backwards.reverse()
	assert_eq(_names(DeckFilter.new()._pool_in_order(again)), backwards, "the kept order, as kept")
	# A list that is not the library is sorted on its own and kept out.
	var few: Array[CardData] = [CardRegistry.get_card("Shivan Dragon"), CardRegistry.get_card("Forest")]
	assert_eq(_names(DeckFilter.new()._pool_in_order(few)), ["Forest", "Shivan Dragon"] as Array[String])
	assert_eq(DeckFilter._library_orders[DeckFilter.Sort.NAME], doctored, "the library's order untouched")
	# A library array in another order is not the one the table indexes.
	var shuffled := again.duplicate()
	shuffled.reverse()
	assert_eq(_names(DeckFilter.new()._pool_in_order(shuffled)), order, "sorted afresh, not mis-indexed")
	DeckFilter._library_orders.clear()


func test_the_tables_are_let_go_when_the_registry_reloads() -> void:
	var f := DeckFilter.new()
	f.apply(_pool)
	assert_false(DeckFilter._library_orders.is_empty())
	assert_not_null(DeckFilter._set_tables[3], "the sets of each name kept")
	# A pack switched on or off, or a rescan, reloads the registry, and
	# that moves its revision: what was read from the old load is dropped.
	CardRegistry.revision += 1
	assert_true(CardValue.pool_moved(DeckFilter._tables_read_at), "read against the old load")
	var fresh := DeckFilter.new()
	fresh.apply(_pool)
	assert_eq(DeckFilter._tables_read_at, CardRegistry.revision, "read again against this load")
	assert_eq(_names(fresh.apply(_pool)), _walked_apply(fresh, _pool))

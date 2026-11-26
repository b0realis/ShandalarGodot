extends GutTest
## Campaign 2026-11-26, smooth2 #3: [method DeckFilter.apply] keeps each
## filter group's answers and narrows the type-ahead from the last needle
## instead of walking the whole pool through every rule on every letter.
## The list it returns must be the plain walk's, card for card, in every
## state and after every kind of move — which is what this compares.

var filter: DeckFilter
var pool: Array = []


func before_each() -> void:
	CardRegistry.ensure_loaded()
	filter = DeckFilter.new()
	pool.clear()
	for card_name in CardRegistry.all_names():
		pool.append(CardRegistry.get_card(card_name))


## The walk [method DeckFilter.apply] was before the campaign.
func _plain() -> Array[CardData]:
	var needle := filter._needle
	var lead: Array[CardData] = []
	var rest: Array[CardData] = []
	for d in filter._pool_in_order(pool):
		if not filter.matches(d):
			continue
		if needle != "" and String(DeckFilter._facts_for(d)[DeckFilter.FACT_NAME]).begins_with(needle):
			lead.append(d)
		else:
			rest.append(d)
	lead.append_array(rest)
	return lead


func _same(what: String) -> int:
	var got := filter.apply(pool)
	var want := _plain()
	var same := got.size() == want.size()
	if same:
		for i in got.size():
			if got[i] != want[i]:
				same = false
				break
	assert_true(same, "%s: %d cards against the plain walk's %d" % [what, got.size(), want.size()])
	return got.size()


func test_typing_narrows_to_the_plain_walk_s_list_letter_by_letter() -> void:
	assert_eq(_same("everything"), pool.size())
	var typed := ""
	for letter in "serra angel":
		typed += letter
		filter.text = typed
		_same("'%s'" % typed)
	assert_eq(_same("serra angel"), 1)
	# Back a letter, another word, a needle that is not a continuation, none.
	for text in ["serra ange", "serra", "angel", "an", "a", "ang", "zzzz", "zzzzz", "", "Juzam", "  bolt "]:
		filter.text = text
		_same("'%s'" % text)
	filter.text = "bolt"
	var hits := filter.apply(pool)
	assert_true(hits.size() >= 1)
	assert_true(String(hits[0].card_name).to_lower().begins_with("bolt") or not String(
		hits[hits.size() - 1].card_name).to_lower().begins_with("bolt"), "prefix matches lead")


func test_rules_text_search_narrows_too() -> void:
	filter.search_rules = true
	for text in ["g", "ga", "gai", "gain", "gain l", "gain life", "gain", "fly", "flying"]:
		filter.text = text
		_same("rules '%s'" % text)
	# The switch goes off under a needle that only grew.
	filter.text = "fl"
	_same("rules 'fl'")
	filter.search_rules = false
	filter.text = "fly"
	_same("names only 'fly'")
	filter.search_rules = true
	filter.text = "flyi"
	_same("rules again 'flyi'")


func test_every_group_s_move_is_seen_with_a_needle_held() -> void:
	filter.text = "a"
	_same("a")
	filter.toggle_color(Mtg.ManaColor.R)
	_same("red off")
	filter.text = "an"
	_same("an, red off")
	filter.toggle_type(Mtg.CardType.CREATURE)
	_same("creatures off")
	filter.gold = false
	_same("gold off")
	filter.gold = true
	filter.gold_mode = DeckFilter.Gold.MATCH_ALL
	_same("gold match all")
	filter.toggle_set(String(CardRegistry.active_set_order()[0]))
	_same("a set off")
	filter.original_cards_on = false
	_same("original cards off")
	filter.original_cards_on = true
	filter.cost_mode = DeckFilter.Cost.LE
	filter.cost_value = 2
	_same("cost <= 2")
	filter.power_mode = DeckFilter.Rank.GE
	filter.power_value = 2
	_same("power >= 2")
	filter.power_mode = DeckFilter.Rank.OFF
	filter.rarity_on = true
	filter.tick_rarity(DeckFilter.Rarity.COMMON, false)
	_same("no commons")
	filter.ability_on = true
	_same("abilities on")
	filter.land_mode = DeckFilter.Land.LAND_AND_MANA
	_same("land and mana")
	filter.creature_list_on = true
	_same("creature list")
	filter.sort_mode = DeckFilter.Sort.COST
	_same("sorted by cost")
	filter.text = ""
	_same("no needle")
	filter.reset()
	assert_eq(_same("reset"), pool.size())
	filter.clear_all()
	_same("clear all")
	filter.select_all()
	assert_eq(_same("select all"), pool.size())


func test_a_switch_written_straight_into_the_table_is_seen() -> void:
	# The screen and several tests write `filter.sets[code] = false`
	# without moving [member DeckFilter.revision].
	var all := _same("everything")
	var code := String(CardRegistry.active_set_order()[0])
	filter.sets[code] = false
	var fewer := _same("a set written off")
	assert_true(fewer < all, "%d of %d" % [fewer, all])
	filter.sets[code] = true
	assert_eq(_same("and on again"), all)


func test_another_pool_and_the_same_pool_again() -> void:
	filter.text = "se"
	var whole := _same("the library")
	var few: Array = pool.slice(0, 50)
	var kept := pool
	pool = few
	_same("fifty cards")
	pool = kept
	assert_eq(_same("the library again"), whole)
	# The list handed back is the caller's own to change.
	var mine := filter.apply(pool)
	mine.clear()
	filter.text = ""
	var all := filter.apply(pool)
	all.clear()
	assert_eq(_same("after the caller emptied its lists"), pool.size())

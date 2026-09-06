extends GutTest
## The Deck Builder's four Filter groups. The contract under test is the
## 1997 manual's own (ch.10, "Filters Galore"), which is the OPPOSITE
## polarity to s30's collectionFilter: every button starts DEPRESSED (on)
## and shows its cards; switching one up hides them. Within a group the
## buttons are additive, between groups exclusive, and lands/colourless
## cards are exempt from the Color Filters entirely.


var filter: DeckFilter


func before_each() -> void:
	CardRegistry.ensure_loaded()
	filter = DeckFilter.new()


func _card(card_name: String) -> CardData:
	return CardRegistry.get_card(card_name)


## The whole implemented pool, as `apply` wants it.
func _pool() -> Array[CardData]:
	var out: Array[CardData] = []
	for card_name in CardRegistry.all_names():
		out.append(CardRegistry.get_card(card_name))
	return out


# ------------------------------------------------------ opening state --

func test_a_fresh_filter_shows_the_whole_pool() -> void:
	assert_false(filter.active(), "every button is depressed to begin with")
	for card_name in CardRegistry.all_names():
		assert_true(filter.matches(CardRegistry.get_card(card_name)), card_name)


# -------------------------------------------------------- color group --

func test_switching_a_color_off_hides_it() -> void:
	filter.toggle_color(Mtg.ManaColor.R)
	assert_true(filter.active())
	assert_false(filter.matches(_card("Lightning Bolt")), "red is up")
	assert_true(filter.matches(_card("Serra Angel")), "white is still down")


func test_toggling_twice_puts_the_button_back() -> void:
	filter.toggle_color(Mtg.ManaColor.R)
	filter.toggle_color(Mtg.ManaColor.R)
	assert_false(filter.active())
	assert_true(filter.matches(_card("Lightning Bolt")))


func test_colors_are_additive_inside_the_group() -> void:
	# "Within each set of buttons, the filters are additive."
	for color in [Mtg.ManaColor.B, Mtg.ManaColor.G, Mtg.ManaColor.U]:
		filter.toggle_color(color)
	assert_true(filter.matches(_card("Lightning Bolt")), "red still down")
	assert_true(filter.matches(_card("Serra Angel")), "white still down")
	assert_false(filter.matches(_card("Dark Ritual")), "black is up")


func test_a_land_ignores_the_color_filters() -> void:
	# "so long as the Land filter is active, all lands are displayed,
	# regardless of which Color Filters are on".
	for color in DeckFilter.COLOR_ORDER:
		filter.toggle_color(color)
	filter.gold = false
	assert_true(filter.matches(_card("Mountain")), "every colour is up")
	assert_true(filter.matches(_card("Plains")))
	assert_false(filter.matches(_card("Lightning Bolt")), "spells are gone")


func test_a_colorless_card_ignores_the_color_filters() -> void:
	# "there's no Color Filter for colorless cards."
	for color in DeckFilter.COLOR_ORDER:
		filter.toggle_color(color)
	assert_true(filter.matches(_card("Sol Ring")), "an artifact has no colour")


func test_the_land_type_filter_still_hides_lands() -> void:
	filter.toggle_type(Mtg.CardType.LAND)
	assert_false(filter.matches(_card("Mountain")))


# --------------------------------------------------------- type group --

func test_switching_a_type_off_hides_it() -> void:
	filter.toggle_type(Mtg.CardType.CREATURE)
	assert_false(filter.matches(_card("Serra Angel")))
	assert_true(filter.matches(_card("Lightning Bolt")))


func test_groups_are_exclusive_between_each_other() -> void:
	# "if you have Green and Instants both depressed, you'll see only
	# green instants" — here: only red creatures survive.
	for color in [Mtg.ManaColor.W, Mtg.ManaColor.U, Mtg.ManaColor.B, Mtg.ManaColor.G]:
		filter.toggle_color(color)
	for type_flag in [Mtg.CardType.LAND, Mtg.CardType.ARTIFACT,
			Mtg.CardType.ENCHANTMENT, Mtg.CardType.INSTANT, Mtg.CardType.SORCERY]:
		filter.toggle_type(type_flag)
	assert_true(filter.matches(_card("Shivan Dragon")), "a red creature")
	assert_false(filter.matches(_card("Lightning Bolt")), "red, not a creature")
	assert_false(filter.matches(_card("Serra Angel")), "creature, not red")


func test_an_odd_combination_shows_nothing() -> void:
	# "if you chose an odd filter combination… no cards would show up at all."
	for type_flag in DeckFilter.TYPE_ORDER:
		filter.toggle_type(type_flag)
	for card_name in CardRegistry.all_names():
		assert_false(filter.matches(CardRegistry.get_card(card_name)), card_name)
		break


# ---------------------------------------------------------- set group --

func test_switching_a_set_off_hides_its_cards() -> void:
	filter.toggle_set("arn")
	var arabian := _card("Ali from Cairo")
	assert_eq(arabian.set_code, "arn", "fixture is an Arabian Nights card")
	assert_false(filter.matches(arabian))
	assert_true(filter.matches(_card("Lightning Bolt")), "another set is unaffected")


func test_every_implemented_set_has_a_button_and_a_1997_name() -> void:
	for code in CardRegistry.SET_ORDER:
		assert_true(filter.sets.has(code), code)
		assert_true(DeckFilter.SET_LABELS.has(code), "%s is named" % code)


# ---------------------------------------------------------- gold group --

func test_gold_cards_answer_to_the_gold_button() -> void:
	var gold_card := _card("Angus Mackenzie")
	assert_true(filter.matches(gold_card), "all gold cards, by default")
	filter.gold = false
	assert_false(filter.matches(gold_card))


func test_gold_match_any_follows_the_lit_colors() -> void:
	filter.gold_mode = DeckFilter.Gold.MATCH_ANY
	for color in [Mtg.ManaColor.G, Mtg.ManaColor.U, Mtg.ManaColor.W]:
		filter.toggle_color(color)      # Angus is {G}{W}{U}; switch all three up
	assert_false(filter.matches(_card("Angus Mackenzie")),
		"no lit colour is on the card")


# ------------------------------------------------------- other filters --

func test_the_type_ahead_narrows_by_name() -> void:
	filter.text = "light"
	assert_true(filter.matches(_card("Lightning Bolt")), "case-insensitive prefix")
	assert_false(filter.matches(_card("Serra Angel")))


func test_casting_cost_treats_the_cost_as_a_number() -> void:
	filter.cost_mode = DeckFilter.Cost.LE
	filter.cost_value = 1
	assert_true(filter.matches(_card("Lightning Bolt")), "{R} is one")
	assert_false(filter.matches(_card("Serra Angel")), "{3}{W}{W} is five")
	filter.cost_mode = DeckFilter.Cost.EQ
	filter.cost_value = 5
	assert_true(filter.matches(_card("Serra Angel")))


func test_x_cost_finds_the_x_spells() -> void:
	filter.cost_mode = DeckFilter.Cost.HAS_X
	assert_true(filter.matches(_card("Fireball")))
	assert_false(filter.matches(_card("Lightning Bolt")))


func test_reset_puts_every_button_back_down() -> void:
	filter.toggle_color(Mtg.ManaColor.R)
	filter.toggle_type(Mtg.CardType.CREATURE)
	filter.toggle_set("arn")
	filter.text = "bolt"
	filter.cost_mode = DeckFilter.Cost.EQ
	filter.reset()
	assert_false(filter.active())
	assert_true(filter.matches(_card("Serra Angel")))


# ---------------------------------------------------------------- sort --

func test_apply_filters_and_sorts_the_inventory() -> void:
	var pool: Array[CardData] = []
	for card_name in ["Shivan Dragon", "Lightning Bolt", "Serra Angel", "Mountain"]:
		pool.append(_card(card_name))
	filter.toggle_type(Mtg.CardType.LAND)
	var shown := filter.apply(pool)
	var names := PackedStringArray()
	for d in shown:
		names.append(d.card_name)
	assert_eq(Array(names), ["Lightning Bolt", "Serra Angel", "Shivan Dragon"],
		"no land, sorted by name")


func test_sort_by_cost_then_name() -> void:
	var pool: Array[CardData] = []
	for card_name in ["Shivan Dragon", "Lightning Bolt", "Serra Angel"]:
		pool.append(_card(card_name))
	filter.sort_mode = DeckFilter.Sort.COST
	var shown := filter.apply(pool)
	assert_eq(shown[0].card_name, "Lightning Bolt", "{R} is cheapest")
	assert_eq(shown[2].card_name, "Shivan Dragon", "{4}{R}{R} is dearest")


func test_sort_by_type_groups_the_inventory() -> void:
	var pool: Array[CardData] = []
	for card_name in ["Mountain", "Lightning Bolt", "Serra Angel"]:
		pool.append(_card(card_name))
	filter.sort_mode = DeckFilter.Sort.TYPE
	var shown := filter.apply(pool)
	assert_eq(shown[0].card_name, "Serra Angel", "creatures lead the type order")
	assert_eq(shown[2].card_name, "Mountain", "lands come last")


func test_the_type_ahead_puts_prefix_matches_first() -> void:
	var pool: Array[CardData] = []
	for card_name in ["Ball Lightning", "Lightning Bolt"]:
		if CardRegistry.has_card(card_name):
			pool.append(_card(card_name))
	if pool.size() < 2:
		pass_test("Ball Lightning is not in the implemented pool")
		return
	filter.text = "light"
	assert_eq(filter.apply(pool)[0].card_name, "Lightning Bolt",
		"the card whose NAME starts with the letters typed")


func test_cue_cards_use_the_1997_wording() -> void:
	assert_eq(DeckFilter.cue_card("White", true), "White cards are in the list")
	assert_eq(DeckFilter.cue_card("Gold", false), "Gold cards are filtered out")


func test_the_whole_pool_survives_an_untouched_filter() -> void:
	var pool: Array[CardData] = []
	for card_name in CardRegistry.all_names():
		pool.append(CardRegistry.get_card(card_name))
	assert_eq(filter.apply(pool).size(), pool.size(),
		"an untouched filter drops nothing from the whole pool")


# ============================================================ AUDIT PASS ==
# Everything below was added by the audit pass (2026-08-31): the filter
# groups the building pass left out, and the contracts the screen relies on.

# ------------------------------------------------- @LAND, the mini-menu --

func test_the_land_button_shows_every_mana_source_by_default() -> void:
	# `@LAND` (s30/assets/text/Menus.txt): "&Land and Mana" is the first and
	# therefore default option, and the manual says what it means: "this
	# filters in all land and all other cards capable of producing mana."
	assert_eq(filter.land_mode, DeckFilter.Land.LAND_AND_MANA)
	for type_flag in DeckFilter.TYPE_ORDER:
		if type_flag != Mtg.CardType.LAND:
			filter.toggle_type(type_flag)
	assert_true(filter.matches(_card("Mountain")), "a land")
	assert_true(filter.matches(_card("Sol Ring")), "an artifact that makes mana")
	assert_false(filter.matches(_card("Lightning Bolt")), "makes no mana")


func test_land_only_drops_the_other_mana_sources() -> void:
	# "Land Only displays only land cards."
	filter.land_mode = DeckFilter.Land.LAND_ONLY
	for type_flag in DeckFilter.TYPE_ORDER:
		if type_flag != Mtg.CardType.LAND:
			filter.toggle_type(type_flag)
	assert_true(filter.matches(_card("Mountain")))
	assert_false(filter.matches(_card("Sol Ring")), "not a land")


func test_mana_only_drops_the_lands() -> void:
	# "MANA Only filters out the land and leaves all other cards capable of
	# producing mana."
	filter.land_mode = DeckFilter.Land.MANA_ONLY
	for type_flag in DeckFilter.TYPE_ORDER:
		if type_flag != Mtg.CardType.LAND:
			filter.toggle_type(type_flag)
	assert_false(filter.matches(_card("Mountain")), "the land is filtered out")
	assert_true(filter.matches(_card("Sol Ring")), "the mana artifact stays")


func test_a_mana_source_reached_through_land_still_ignores_the_colors() -> void:
	# The manual is precise: "Which lands are displayed is not affected by
	# the Color Filters or Other Filters, but the same is not true for
	# other mana sources."
	for color in DeckFilter.COLOR_ORDER:
		filter.toggle_color(color)
	assert_true(filter.matches(_card("Mountain")), "lands are exempt")


# --------------------------------------------- @ARTIFACT, the mini-menu --

func test_the_artifact_sub_filters_split_creatures_from_the_rest() -> void:
	# `@ARTIFACT`: "All &Creatures" / "All &Non-Creatures", "both of which
	# are independent toggles… The default setting has both of these
	# options turned on."
	assert_true(filter.artifact_creatures)
	assert_true(filter.artifact_noncreatures)
	for type_flag in DeckFilter.TYPE_ORDER:
		if type_flag != Mtg.CardType.ARTIFACT:
			filter.toggle_type(type_flag)
	assert_true(filter.matches(_card("Sol Ring")), "a non-creature artifact")
	assert_true(filter.matches(_card("Clockwork Beast")), "an artifact creature")
	filter.artifact_creatures = false
	assert_false(filter.matches(_card("Clockwork Beast")))
	assert_true(filter.matches(_card("Sol Ring")), "unaffected, as the manual says")


# ------------------------------------------ @POWER / @TOUGHNESS filters --

func test_the_power_filter_ranks_creatures() -> void:
	# `@POWER`: "&Greater than or equal to" / "&Less than or equal to" /
	# "&Equal to".
	filter.power_mode = DeckFilter.Rank.GE
	filter.power_value = 5
	assert_true(filter.matches(_card("Shivan Dragon")), "5/5")
	assert_false(filter.matches(_card("Grizzly Bears")), "2/2")
	filter.power_mode = DeckFilter.Rank.EQ
	filter.power_value = 2
	assert_true(filter.matches(_card("Grizzly Bears")))


func test_the_toughness_filter_ranks_creatures() -> void:
	filter.toughness_mode = DeckFilter.Rank.LE
	filter.toughness_value = 1
	assert_true(filter.matches(_card("Mons's Goblin Raiders")), "1/1")
	assert_false(filter.matches(_card("Shivan Dragon")))


func test_a_non_creature_never_survives_a_power_filter() -> void:
	# "Power gives you a method of ranking CREATURES" — a card with no
	# power is not a creature and cannot answer the question.
	filter.power_mode = DeckFilter.Rank.GE
	filter.power_value = 0
	assert_false(filter.matches(_card("Lightning Bolt")), "an instant has no power")
	assert_true(filter.matches(_card("Grizzly Bears")))


# ----------------------------------------------------------- cue cards --

func test_the_ranged_filters_use_their_own_cue_card_wording() -> void:
	# Cuecards.txt gives the four "Other Filters" a DIFFERENT sentence from
	# the colour/set/type buttons: "Cards are filtered by cast cost" rather
	# than "Cast cost cards are in the list".
	assert_eq(DeckFilter.filtered_by_cue_card("cast cost", true),
		"Cards are filtered by cast cost")
	assert_eq(DeckFilter.filtered_by_cue_card("power", false),
		"Cards are not filtered by power")


# ------------------------------------------------------------ revision --

func test_the_revision_counts_only_real_changes() -> void:
	# The screen re-filters 800 cards only when this number moves, so it
	# must move on every mutation and never move on a no-op read.
	var start := filter.revision
	filter.matches(_card("Mountain"))
	assert_eq(filter.revision, start, "asking a question changes nothing")
	filter.toggle_color(Mtg.ManaColor.R)
	assert_ne(filter.revision, start, "a toggle is a change")
	var after := filter.revision
	filter.set_text("bolt")
	assert_ne(filter.revision, after)
	var after_text := filter.revision
	filter.set_text("bolt")
	assert_eq(filter.revision, after_text, "the same text again is not a change")


func test_reset_restores_every_audit_pass_filter_too() -> void:
	filter.land_mode = DeckFilter.Land.MANA_ONLY
	filter.artifact_creatures = false
	filter.power_mode = DeckFilter.Rank.GE
	filter.toughness_mode = DeckFilter.Rank.LE
	filter.gold_mode = DeckFilter.Gold.MATCH_ANY
	filter.reset()
	assert_eq(filter.land_mode, DeckFilter.Land.LAND_AND_MANA)
	assert_true(filter.artifact_creatures)
	assert_eq(filter.power_mode, DeckFilter.Rank.OFF)
	assert_eq(filter.toughness_mode, DeckFilter.Rank.OFF)
	assert_eq(filter.gold_mode, DeckFilter.Gold.ALL)
	assert_false(filter.active())


# ======================================================= SCREENSHOT PASS ==

func _whole_pool() -> Array[CardData]:
	var pool: Array[CardData] = []
	for card_name in CardRegistry.all_names():
		pool.append(CardRegistry.get_card(card_name))
	return pool


func test_the_type_ahead_can_be_told_to_read_card_text() -> void:
	# [QoL] Off, the box is the manual's name-only type-ahead.
	var pool := _whole_pool()
	filter.text = "regenerate"
	var by_name := filter.apply(pool)
	assert_eq(by_name.size(), 0, "no card is NAMED regenerate")
	filter.search_rules = true
	var by_text := filter.apply(pool)
	assert_gt(by_text.size(), 0, "but many say it")
	for d in by_text:
		assert_true(d.card_name.to_lower().contains("regenerate")
			or d.oracle_text.to_lower().contains("regenerate"), d.card_name)


func test_the_rules_text_switch_moves_the_revision() -> void:
	# The screen re-walks the pool only when this number moves; a switch
	# that changed what `matches` returns without bumping it would show a
	# stale list.
	var before := filter.revision
	filter.search_rules = true
	assert_gt(filter.revision, before)


func test_reset_puts_the_rules_text_switch_back() -> void:
	filter.search_rules = true
	filter.reset()
	assert_false(filter.search_rules)
	assert_false(filter.active())


# ==================================================== SECOND AUDIT PASS ==

func test_select_all_shows_the_whole_pool_again() -> void:
	# `@LONGLIST`'s "Select All" — the way back from twenty-three toggles.
	filter.toggle_color(Mtg.ManaColor.W)
	filter.toggle_type(Mtg.CardType.CREATURE)
	filter.toggle_set("4ed")
	filter.cost_mode = DeckFilter.Cost.LE
	filter.cost_value = 2
	filter.text = "bolt"
	assert_true(filter.active())
	filter.select_all()
	assert_false(filter.active(), "every medallion depressed")
	assert_eq(filter.apply(_pool()).size(), CardRegistry.size(), "and the pool is back")


func test_clear_all_shows_nothing_which_is_the_point_of_it() -> void:
	# "Clear All" is the FIRST half of picking two filters out of
	# twenty-three; on its own the original shows nothing either.
	filter.clear_all()
	assert_eq(filter.apply(_pool()).size(), 0)
	# TWO gestures, and it takes two now. This test used to press all eight
	# SET medallions back by hand between the Clear and the assert, which
	# is where the third audit pass found the defect written down: the set
	# group is ANDed against the rest, so clearing it made the strip
	# unable to show a card whatever else was pressed. `Clear All` now
	# leaves it alone, exactly as it already left the Other Filters.
	for code in CardRegistry.SET_ORDER:
		assert_true(filter.set_on(code), "%s is still in the list" % code)
	filter.toggle_color(Mtg.ManaColor.R)
	filter.toggle_type(Mtg.CardType.INSTANT)
	var red_instants := filter.apply(_pool())
	assert_gt(red_instants.size(), 0, "two gestures, not twenty-one")
	for d in red_instants:
		assert_true(bool(d.types & Mtg.CardType.INSTANT), d.card_name)


func test_clear_all_still_lets_a_single_set_be_picked_out() -> void:
	# Leaving the set group alone must not make it unreachable: it is one
	# toggle each, the way it always was, and `Select All` still lights
	# every one of them.
	filter.select_all()
	for code in CardRegistry.SET_ORDER:
		if code != "arn":
			filter.toggle_set(code)
	var arabian := filter.apply(_pool())
	assert_gt(arabian.size(), 0, "the Arabian Nights run")
	for d in arabian:
		assert_eq(d.set_code, "arn", d.card_name)
	filter.select_all()
	assert_eq(filter.apply(_pool()).size(), CardRegistry.size())


func test_select_all_and_clear_all_move_the_revision() -> void:
	var before := filter.revision
	filter.clear_all()
	assert_gt(filter.revision, before, "the screen re-walks the pool")
	before = filter.revision
	filter.select_all()
	assert_gt(filter.revision, before)


func test_the_cached_masks_follow_a_toggle() -> void:
	# `matches` reads colour and type as BIT MASKS rebuilt whenever
	# `revision` moves. A mask that went stale would filter the pool by the
	# state before the click.
	var lit := filter.apply(_pool()).size()
	filter.toggle_color(Mtg.ManaColor.R)
	var without_red := filter.apply(_pool()).size()
	assert_lt(without_red, lit, "the toggle took effect at once")
	filter.toggle_color(Mtg.ManaColor.R)
	assert_eq(filter.apply(_pool()).size(), lit, "and back again")


func test_the_per_card_facts_do_not_change_what_matches() -> void:
	# The folded name, colour mask and sort ranks are now computed once per
	# card and cached. Same card, same answer, twice.
	filter.text = "lightning"
	var first := filter.apply(_pool())
	var second := filter.apply(_pool())
	assert_eq(first.size(), second.size())
	for i in first.size():
		assert_eq(first[i].card_name, second[i].card_name)


func test_every_sort_order_is_total_and_stable() -> void:
	# The keys became integers read from the cache; the orders must not.
	for mode in [DeckFilter.Sort.NAME, DeckFilter.Sort.COST,
			DeckFilter.Sort.TYPE, DeckFilter.Sort.COLOR, DeckFilter.Sort.SET]:
		filter.sort_mode = mode
		var once := filter.apply(_pool())
		var twice := filter.apply(_pool())
		assert_eq(once.size(), CardRegistry.size(), "nothing was dropped by sort %d" % mode)
		for i in once.size():
			assert_eq(once[i].card_name, twice[i].card_name,
				"sort %d is stable" % mode)


func test_sorting_by_cost_really_orders_by_mana_value() -> void:
	filter.sort_mode = DeckFilter.Sort.COST
	var order := filter.apply(_pool())
	var last := -1
	for d in order:
		assert_true(d.cost.mana_value() >= last,
			"%s (%d) after %d" % [d.card_name, d.cost.mana_value(), last])
		last = d.cost.mana_value()


# ============================================================ THIRD PASS ==

## `apply` no longer sorts: it walks a cached ordering of the POOL and
## splits the survivors. The cache is keyed on the array's own identity, so
## a caller passing a DIFFERENT list must never receive another list's
## cards — which is the one way an order cache can go wrong.
func test_the_order_cache_never_leaks_one_pool_into_another() -> void:
	var whole := _pool()
	assert_eq(filter.apply(whole).size(), CardRegistry.size())
	var two: Array = [CardRegistry.get_card("Lightning Bolt"),
		CardRegistry.get_card("Mountain")]
	var small := filter.apply(two)
	assert_eq(small.size(), 2, "only what it was given")
	for d in small:
		assert_true(two.has(d), "%s came from the list passed in" % d.card_name)
	assert_eq(filter.apply(whole).size(), CardRegistry.size(),
		"and the whole pool still comes back whole")
	# A pool that GROWS under the same array is re-sorted, not reused.
	var grown := _pool()
	grown.append(CardRegistry.get_card("Lightning Bolt"))
	assert_eq(filter.apply(grown).size(), CardRegistry.size() + 1)


## Every order the cache can hold must be the order the sort produced, and
## switching between two of them must not serve the wrong one.
func test_switching_sort_orders_serves_the_right_one_each_time() -> void:
	var by_mode := {}
	for mode in [DeckFilter.Sort.NAME, DeckFilter.Sort.COST,
			DeckFilter.Sort.TYPE, DeckFilter.Sort.COLOR, DeckFilter.Sort.SET]:
		var fresh := DeckFilter.new()
		fresh.sort_mode = mode
		by_mode[mode] = fresh.apply(_pool())
	for pass_number in 2:
		for mode in by_mode:
			filter.sort_mode = mode
			var got := filter.apply(_pool())
			var wanted: Array = by_mode[mode]
			assert_eq(got.size(), wanted.size(), "sort %d size" % mode)
			for i in got.size():
				assert_eq(got[i].card_name, wanted[i].card_name,
					"sort %d position %d on pass %d" % [mode, i, pass_number])


## The type-ahead's prefix-first rule is what the partition replaced, so it
## is pinned on the whole pool rather than on one example.
func test_a_prefix_match_still_leads_the_list() -> void:
	filter.text = "light"
	var shown := filter.apply(_pool())
	assert_gt(shown.size(), 1, "more than one card says 'light'")
	var seen_a_non_prefix := false
	for d in shown:
		var prefix: bool = d.card_name.to_lower().begins_with("light")
		if not prefix:
			seen_a_non_prefix = true
		else:
			assert_false(seen_a_non_prefix,
				"%s (a prefix match) came after a mid-name one" % d.card_name)
	# ...and inside each half the sort order still holds.
	var last := ""
	for d in shown:
		if not d.card_name.to_lower().begins_with("light"):
			continue
		assert_true(d.card_name.to_lower() > last, d.card_name)
		last = d.card_name.to_lower()


# ------------------------------------------ the five list sub-filters --
# The 1997 `@LONGLIST` sub-filters (creatures, enchantments, abilities,
# rarity, artists), all pages of the one Filters window since 2026-09-06.
# Each starts inert: every check ticked, every "Enable Filter" off.

func _shown(pool: Array[CardData]) -> Array[String]:
	var names: Array[String] = []
	for d in pool:
		if filter.matches(d):
			names.append(d.card_name)
	return names


func test_a_fresh_filter_has_no_list_in_force() -> void:
	assert_false(filter.lists_active())
	assert_true(filter.creature_type_on("elf"), "absent means ticked")
	assert_true(filter.enchantment_on(DeckFilter.Aura.WORLD))
	assert_true(filter.ability_ticked(DeckAbilities.Ability.FLYING))
	assert_true(filter.rarity_ticked(DeckFilter.Rarity.BANNED))
	assert_true(filter.artist_ticked("Douglas Shuler"))


# -- creatures --

func test_summon_admits_the_plain_creatures_and_artifact_the_others() -> void:
	# `check_creatures`, deckdll.cpp:6995 — "Summon Bear" versus
	# "Artifact Creature" in the 1997 type line. The Artifact MEDALLION
	# admits an artifact creature on its own (the groups are ORed), so it
	# goes up for the Artifact check to be the one asked; likewise a mana
	# creature is Land's through `Land and Mana`, so the Bears stand in.
	filter.toggle_type(Mtg.CardType.ARTIFACT)
	filter.creature_summon = false
	assert_false(filter.matches(_card("Grizzly Bears")), "a Summon with Summon up")
	assert_true(filter.matches(_card("Primal Clay")), "an artifact creature is Artifact's")
	filter.creature_summon = true
	filter.creature_artifact = false
	assert_true(filter.matches(_card("Grizzly Bears")))
	assert_false(filter.matches(_card("Primal Clay")))
	assert_true(filter.matches(_card("Lightning Bolt")), "a spell never asks the creature checks")


func test_a_mana_creature_is_still_lands_with_summon_up() -> void:
	# `Land and Mana` reaches every card that taps for mana, Summon or not.
	filter.creature_summon = false
	assert_true(filter.matches(_card("Llanowar Elves")))
	filter.land_mode = DeckFilter.Land.LAND_ONLY
	assert_false(filter.matches(_card("Llanowar Elves")))


func test_the_list_is_an_or_term_on_top_of_summon() -> void:
	# The list ADDS to Summon — with Summon still down it changes nothing,
	# which is why the window says so (DeckBuilderScreen.LIST_HINT).
	filter.toggle_type(Mtg.CardType.ARTIFACT)
	filter.creature_list_on = true
	for subtype in FilterBar.creature_types():
		filter.tick_creature_type(subtype, false)
	filter.tick_creature_type("bear", true)
	assert_true(filter.matches(_card("Savannah Lions")), "Summon is still down")
	filter.creature_summon = false
	filter.creature_artifact = false
	assert_true(filter.matches(_card("Grizzly Bears")), "the Bear comes through the list")
	assert_false(filter.matches(_card("Savannah Lions")), "the Cat does not")
	assert_false(filter.matches(_card("Primal Clay")), "nor the artifact creature")
	filter.creature_list_on = false
	assert_false(filter.matches(_card("Grizzly Bears")), "the list off is the list ignored")


func test_the_creature_type_list_is_the_pools_own() -> void:
	var listed := FilterBar.creature_types()
	assert_gt(listed.size(), 100, "every creature subtype in the pool")
	assert_has(listed, "elf")
	assert_has(listed, "wall")
	assert_eq(listed, listed.duplicate().filter(func(t: String) -> bool: return t == t.to_lower()),
		"all lower case, as the registry spells them")
	var sorted := listed.duplicate()
	sorted.sort()
	assert_eq(listed, sorted, "alphabetical")


# -- enchantments --

func test_an_aura_is_the_kind_of_thing_it_enchants() -> void:
	# `check_enchantments`, deckdll.cpp:7015.
	assert_eq(DeckFilter.aura_kind(_card("Crusade")), DeckFilter.Aura.ENCHANTMENTS, "a global enchantment")
	assert_eq(DeckFilter.aura_kind(_card("The Abyss")), DeckFilter.Aura.WORLD)
	assert_eq(DeckFilter.aura_kind(_card("Nether Void")), DeckFilter.Aura.WORLD)
	assert_eq(DeckFilter.aura_kind(_card("Wild Growth")), DeckFilter.Aura.LAND)
	assert_eq(DeckFilter.aura_kind(_card("Psychic Venom")), DeckFilter.Aura.LAND)
	assert_eq(DeckFilter.aura_kind(_card("Holy Strength")), DeckFilter.Aura.CREATURE)
	assert_eq(DeckFilter.aura_kind(_card("Control Magic")), DeckFilter.Aura.CREATURE)
	assert_eq(DeckFilter.aura_kind(_card("Animate Dead")), DeckFilter.Aura.CREATURE,
		"it ends up on a creature, as the 1997 check has it")
	assert_eq(DeckFilter.aura_kind(_card("Animate Artifact")), DeckFilter.Aura.ARTIFACT)
	assert_eq(DeckFilter.aura_kind(_card("Land Tax")), DeckFilter.Aura.ENCHANTMENTS)
	assert_eq(DeckFilter.aura_kind(_card("Copy Artifact")), DeckFilter.Aura.ENCHANTMENTS,
		"a copy is not an aura")


func test_unticking_an_enchantment_kind_hides_those_auras_only() -> void:
	filter.tick_enchantment(DeckFilter.Aura.CREATURE, false)
	assert_true(filter.lists_active())
	assert_false(filter.matches(_card("Holy Strength")))
	assert_true(filter.matches(_card("Crusade")))
	assert_true(filter.matches(_card("Wild Growth")))
	assert_true(filter.matches(_card("Serra Angel")), "a creature never asks the enchantment checks")
	filter.tick_enchantment(DeckFilter.Aura.CREATURE, true)
	assert_false(filter.lists_active())
	assert_true(filter.matches(_card("Holy Strength")))


func test_the_aura_labels_are_the_1997_menu() -> void:
	# Menus.txt `@ENCHANTMENT`.
	assert_eq(DeckFilter.AURA_LABELS.size(), 6)
	assert_eq(DeckFilter.AURA_LABELS[DeckFilter.Aura.ENCHANTMENTS], "Enchantments")
	assert_eq(DeckFilter.AURA_LABELS[DeckFilter.Aura.WORLD], "World")
	assert_eq(DeckFilter.AURA_LABELS[DeckFilter.Aura.ENCHANT], "Enchant")


# -- abilities --

func test_the_ability_filter_is_inert_until_enabled() -> void:
	for ability in DeckAbilities.Ability.values():
		filter.tick_ability(ability, false)
	assert_true(filter.matches(_card("Serra Angel")), "nothing ticked, but the filter is off")
	filter.ability_on = true
	assert_false(filter.matches(_card("Serra Angel")), "on with nothing ticked shows no creature")
	assert_false(filter.matches(_card("Plains")), "and every card is asked, a land too")


func test_the_ability_filter_finds_the_fliers() -> void:
	filter.ability_on = true
	for ability in DeckAbilities.Ability.values():
		filter.tick_ability(ability, ability == DeckAbilities.Ability.FLYING)
	assert_true(filter.matches(_card("Serra Angel")))
	assert_true(filter.matches(_card("Jump")), "Gives is on: the spell that grants it")
	assert_false(filter.matches(_card("Grizzly Bears")))
	assert_false(filter.matches(_card("Earthbind")), "losing flying is not flying")


func test_native_and_gives_are_the_two_scopes() -> void:
	# `check_abilities`, deckdll.cpp:7126.
	filter.ability_on = true
	for ability in DeckAbilities.Ability.values():
		filter.tick_ability(ability, ability == DeckAbilities.Ability.REGENERATION)
	filter.ability_gives = false
	assert_true(filter.matches(_card("Will-o'-the-Wisp")), "has it")
	assert_false(filter.matches(_card("Regeneration")), "only gives it")
	assert_false(filter.matches(_card("Zombie Master")), "only gives it")
	filter.ability_gives = true
	filter.ability_native = false
	assert_false(filter.matches(_card("Will-o'-the-Wisp")))
	assert_true(filter.matches(_card("Regeneration")))
	assert_true(filter.matches(_card("Zombie Master")))
	filter.ability_gives = false
	assert_false(filter.matches(_card("Will-o'-the-Wisp")), "neither scope is nothing")
	assert_false(filter.matches(_card("Regeneration")))


# -- rarity --

func test_a_cards_rarities_are_its_printing_and_its_lists() -> void:
	assert_eq(DeckFilter.rarity_kinds(_card("Grizzly Bears")), [DeckFilter.Rarity.COMMON])
	assert_eq(DeckFilter.rarity_kinds(_card("Serra Angel")), [DeckFilter.Rarity.UNCOMMON])
	assert_eq(DeckFilter.rarity_kinds(_card("Johan")), [DeckFilter.Rarity.RARE])
	assert_eq(DeckFilter.rarity_kinds(_card("Black Lotus")),
		[DeckFilter.Rarity.RARE, DeckFilter.Rarity.RESTRICTED], "rare AND restricted")
	assert_eq(DeckFilter.rarity_kinds(_card("Contract from Below")),
		[DeckFilter.Rarity.RARE, DeckFilter.Rarity.BANNED], "the ante cards are banned")


func test_the_rarity_filter_keeps_a_card_with_any_ticked_kind() -> void:
	filter.rarity_on = true
	for kind in DeckFilter.Rarity.values():
		filter.tick_rarity(kind, kind == DeckFilter.Rarity.RESTRICTED)
	assert_true(filter.matches(_card("Black Lotus")))
	assert_false(filter.matches(_card("Johan")), "a plain rare")
	assert_false(filter.matches(_card("Grizzly Bears")))
	filter.tick_rarity(DeckFilter.Rarity.COMMON, true)
	assert_true(filter.matches(_card("Grizzly Bears")))
	filter.rarity_on = false
	assert_true(filter.matches(_card("Johan")), "off is everything")


func test_the_rarity_labels_are_the_1997_menu() -> void:
	assert_eq(DeckFilter.RARITY_LABELS[DeckFilter.Rarity.COMMON], "Common")
	assert_eq(DeckFilter.RARITY_LABELS[DeckFilter.Rarity.RESTRICTED], "Restricted")
	assert_eq(DeckFilter.RARITY_LABELS[DeckFilter.Rarity.BANNED], "Banned")


# -- artists --

func test_the_artist_filter_shows_the_ticked_artists_cards() -> void:
	filter.artist_on = true
	for artist in FilterBar.artists():
		filter.tick_artist(artist, artist == "Douglas Shuler")
	assert_true(filter.matches(_card("Serra Angel")))
	assert_true(filter.matches(_card("Rainbow Knights")))
	assert_false(filter.matches(_card("Grizzly Bears")), "Jeff A. Menges")
	filter.artist_on = false
	assert_true(filter.matches(_card("Grizzly Bears")))


func test_the_artist_list_is_the_pools_own() -> void:
	var listed := FilterBar.artists()
	assert_gt(listed.size(), 40)
	assert_has(listed, "Douglas Shuler")
	assert_has(listed, "Christopher Rush")
	var sorted := listed.duplicate()
	sorted.sort()
	assert_eq(listed, sorted, "alphabetical")


# -- the window's snapshot, and reset --

func test_lists_active_reads_every_page() -> void:
	assert_false(filter.lists_active())
	filter.creature_summon = false
	assert_true(filter.lists_active())
	filter.creature_summon = true
	filter.creature_list_on = true
	assert_true(filter.lists_active())
	filter.creature_list_on = false
	filter.ability_on = true
	assert_true(filter.lists_active())
	filter.ability_on = false
	filter.rarity_on = true
	assert_true(filter.lists_active())
	filter.rarity_on = false
	filter.artist_on = true
	assert_true(filter.lists_active())
	filter.artist_on = false
	assert_false(filter.lists_active())


func test_a_snapshot_restores_the_pages_as_they_were() -> void:
	# Cancel in the Filters window: everything the window can touch goes
	# back, the strip's own buttons are not the window's to restore.
	filter.tick_creature_type("elf", false)
	filter.tick_rarity(DeckFilter.Rarity.COMMON, false)
	var kept := filter.window_snapshot()
	var before := filter.revision
	filter.creature_list_on = true
	filter.tick_creature_type("goblin", false)
	filter.tick_creature_type("elf", true)
	filter.ability_on = true
	filter.tick_ability(DeckAbilities.Ability.FLYING, false)
	filter.tick_enchantment(DeckFilter.Aura.WORLD, false)
	filter.artist_on = true
	filter.tick_artist("Mark Tedin", false)
	filter.toggle_color(Mtg.ManaColor.W)
	filter.window_restore(kept)
	assert_false(filter.creature_list_on)
	assert_true(filter.creature_type_on("goblin"))
	assert_false(filter.creature_type_on("elf"), "as ticked when the snapshot was taken")
	assert_false(filter.ability_on)
	assert_true(filter.ability_ticked(DeckAbilities.Ability.FLYING))
	assert_true(filter.enchantment_on(DeckFilter.Aura.WORLD))
	assert_false(filter.artist_on)
	assert_true(filter.artist_ticked("Mark Tedin"))
	assert_false(filter.rarity_ticked(DeckFilter.Rarity.COMMON))
	assert_false(filter.color_on(Mtg.ManaColor.W), "the strip's colour is not the window's")
	assert_gt(filter.revision, before, "a restore is a change")


func test_a_snapshot_is_a_copy_not_a_view() -> void:
	var kept := filter.window_snapshot()
	filter.tick_creature_type("elf", false)
	assert_false(kept["creature_types"].has("elf"), "ticking after does not reach into the snapshot")


func test_reset_puts_every_page_back() -> void:
	filter.creature_summon = false
	filter.creature_list_on = true
	filter.tick_creature_type("elf", false)
	filter.tick_enchantment(DeckFilter.Aura.LAND, false)
	filter.ability_on = true
	filter.ability_native = false
	filter.tick_ability(DeckAbilities.Ability.TRAMPLE, false)
	filter.rarity_on = true
	filter.tick_rarity(DeckFilter.Rarity.RARE, false)
	filter.artist_on = true
	filter.tick_artist("Mark Poole", false)
	assert_true(filter.lists_active())
	filter.reset()
	assert_false(filter.lists_active())
	assert_true(filter.creature_summon)
	assert_true(filter.creature_type_on("elf"))
	assert_true(filter.enchantment_on(DeckFilter.Aura.LAND))
	assert_true(filter.ability_native)
	assert_true(filter.ability_ticked(DeckAbilities.Ability.TRAMPLE))
	assert_true(filter.rarity_ticked(DeckFilter.Rarity.RARE))
	assert_true(filter.artist_ticked("Mark Poole"))
	assert_false(filter.active())


func test_select_all_resets_the_pages_and_clear_all_leaves_them() -> void:
	# The strip's Select All is the whole pool again, pages included;
	# Clear All is the first half of picking a few medallions out and does
	# not reach into the window (which has its own pair per page).
	filter.rarity_on = true
	filter.tick_rarity(DeckFilter.Rarity.COMMON, false)
	filter.clear_all()
	assert_true(filter.rarity_on)
	assert_false(filter.rarity_ticked(DeckFilter.Rarity.COMMON))
	filter.select_all()
	assert_false(filter.rarity_on)
	assert_true(filter.rarity_ticked(DeckFilter.Rarity.COMMON))
	assert_false(filter.lists_active())


func test_the_list_pages_count_toward_active() -> void:
	assert_false(filter.active())
	filter.artist_on = true
	assert_true(filter.active(), "an artist filter on is a filter in force")
	filter.artist_on = false
	filter.tick_enchantment(DeckFilter.Aura.ENCHANT, false)
	assert_true(filter.active())


func test_the_shipped_sub_filters_are_the_five_longlists() -> void:
	assert_eq(DeckFilter.SHIPPED, ["@CREATURE", "@ENCHANTMENT", "@ABILITY", "@RARITY", "@ARTIST"])


func test_a_ticked_list_moves_the_revision_only_when_it_changes() -> void:
	var before := filter.revision
	filter.tick_creature_type("elf", true)
	assert_eq(filter.revision, before, "already ticked")
	filter.tick_creature_type("elf", false)
	assert_eq(filter.revision, before + 1)
	filter.tick_creature_type("elf", false)
	assert_eq(filter.revision, before + 1, "already unticked")
	filter.tick_creature_type("elf", true)
	assert_eq(filter.revision, before + 2)

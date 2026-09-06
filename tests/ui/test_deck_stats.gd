extends GutTest
## [QoL] The deck builder's probability page.
##
## *"Expand the basic deck statistics with game theory and chance
## predictions on one/two/three/four/five/six lands in hand"* (2026-09-05).
##
## EXACT, NOT SIMULATED, and these tests are what makes that claim mean
## something: the hypergeometric is checked against values computed by
## hand, so a refactor that quietly turns it into an approximation fails
## here rather than in a player's judgement of a deck.

var deck: DeckModel


func before_each() -> void:
	CardRegistry.ensure_loaded()
	deck = DeckModel.new()


func _fill(card_name: String, n: int) -> void:
	for i in range(n):
		deck.add(card_name)


# --------------------------------------------------- the exact core --

func test_the_hypergeometric_matches_values_computed_by_hand() -> void:
	# A 60-card deck, 24 lands, opening seven. C(24,3)*C(36,4)/C(60,7).
	# = 2024 * 58905 / 386206920 = 0.30867...
	assert_almost_eq(DeckStats.hypergeometric(60, 24, 7, 3), 0.30867, 0.0005)
	# Exactly zero lands from that deck: C(36,7)/C(60,7) = 8347680/386206920
	assert_almost_eq(DeckStats.hypergeometric(60, 24, 7, 0), 0.02161, 0.0005)
	# The whole distribution is a distribution.
	var total := 0.0
	for k in range(8):
		total += DeckStats.hypergeometric(60, 24, 7, k)
	assert_almost_eq(total, 1.0, 0.0001)


func test_it_survives_a_deck_too_big_for_a_factorial() -> void:
	# C(250, 7) overflows a 64-bit int, and a 250-card deck is a legal
	# thing to build here. The product form must still answer.
	var p := DeckStats.hypergeometric(250, 100, 7, 3)
	assert_gt(p, 0.0, "a real probability")
	assert_lt(p, 1.0, "…and a possible one")
	var total := 0.0
	for k in range(8):
		total += DeckStats.hypergeometric(250, 100, 7, k)
	assert_almost_eq(total, 1.0, 0.0001, "still sums to one at that size")


func test_impossible_draws_are_zero_and_not_errors() -> void:
	assert_eq(DeckStats.hypergeometric(60, 24, 7, 8), 0.0, "more than drawn")
	assert_eq(DeckStats.hypergeometric(60, 3, 7, 4), 0.0, "more than exist")
	assert_eq(DeckStats.hypergeometric(0, 0, 7, 0), 0.0, "an empty deck")
	assert_eq(DeckStats.hypergeometric(60, 24, 61, 3), 0.0, "drawing past the deck")


func test_at_least_is_the_upper_tail() -> void:
	var exact := 0.0
	for k in range(2, 8):
		exact += DeckStats.hypergeometric(60, 24, 7, k)
	assert_almost_eq(DeckStats.at_least(60, 24, 7, 2), exact, 0.0001)
	assert_almost_eq(DeckStats.at_least(60, 24, 7, 0), 1.0, 0.0001,
		"at least none is certain")


# ------------------------------------------------------ opening hands --

func test_the_land_row_is_a_distribution_over_the_real_deck() -> void:
	_fill("Forest", 17)
	_fill("Grizzly Bears", 23)
	var odds := DeckStats.land_odds(deck)
	assert_eq(odds.size(), 8, "zero through seven")
	var total := 0.0
	for p in odds:
		total += p
	assert_almost_eq(total, 1.0, 0.0001)
	assert_eq(odds[0] > 0.0, true, "a landless hand is possible")


func test_keepable_is_the_two_to_five_band() -> void:
	_fill("Forest", 17)
	_fill("Grizzly Bears", 23)
	var odds := DeckStats.land_odds(deck)
	var band := odds[2] + odds[3] + odds[4] + odds[5]
	assert_almost_eq(DeckStats.keepable(deck), band, 0.0001)
	assert_gt(DeckStats.keepable(deck), 0.7,
		"a 17/40 deck keeps most of its hands")


func test_more_land_moves_the_odds_the_right_way() -> void:
	_fill("Forest", 10)
	_fill("Grizzly Bears", 30)
	var lean := DeckStats.land_odds(deck)[0]
	deck = DeckModel.new()
	_fill("Forest", 20)
	_fill("Grizzly Bears", 20)
	var fat := DeckStats.land_odds(deck)[0]
	assert_lt(fat, lean, "more land, fewer landless hands")


func test_the_draw_is_worth_a_card() -> void:
	# Not pedantry: it is a whole extra card and it moves the number.
	_fill("Forest", 17)
	_fill("Grizzly Bears", 23)
	var on_play := DeckStats.land_drop_odds(deck, 4, true)
	var on_draw := DeckStats.land_drop_odds(deck, 4, false)
	assert_gt(on_draw, on_play, "the draw sees one more card")


func test_land_drops_get_harder_the_further_out_you_look() -> void:
	_fill("Forest", 17)
	_fill("Grizzly Bears", 23)
	var last := 1.1
	for turn in range(1, DeckStats.HORIZON + 1):
		var p := DeckStats.land_drop_odds(deck, turn)
		assert_lt(p, last, "turn %d is no easier than turn %d" % [turn, turn - 1])
		last = p


# ---------------------------------------------------- colour and mana --

func test_pips_count_symbols_and_not_cards() -> void:
	# Dark Ritual is {B}: one pip. Three copies, three pips.
	_fill("Dark Ritual", 3)
	var pips := DeckStats.color_pips(deck)
	assert_eq(int(pips.get(Mtg.ManaColor.B, 0)), 3)
	# A card asking twice counts twice per copy — that is the whole point
	# of measuring pips rather than cards.
	deck = DeckModel.new()
	_fill("Hypnotic Specter", 2)   # {1}{B}{B}
	assert_eq(int(DeckStats.color_pips(deck).get(Mtg.ManaColor.B, 0)), 4)


func test_a_colour_with_no_sources_is_never_available() -> void:
	_fill("Forest", 20)
	_fill("Hypnotic Specter", 20)
	assert_eq(DeckStats.color_by_turn(deck, Mtg.ManaColor.B, 4), 0.0,
		"no black source, no black mana, however long you wait")
	assert_gt(DeckStats.color_by_turn(deck, Mtg.ManaColor.G, 1), 0.9,
		"…and twenty Forests are there when you need them")


func test_the_hardest_cast_is_named() -> void:
	_fill("Forest", 20)
	_fill("Hypnotic Specter", 4)   # {1}{B}{B} — two pips
	_fill("Dark Ritual", 4)        # {B}       — one
	var worst := DeckStats.hardest_cast(deck)
	assert_eq(String(worst["card"]), "Hypnotic Specter")
	assert_eq(int(worst["pips"]), 2)


func test_a_colourless_deck_has_no_hardest_cast() -> void:
	_fill("Mountain", 20)
	assert_true(DeckStats.hardest_cast(deck).is_empty())


# ------------------------------------------------------------- speed --

func test_creature_and_spell_costs_are_kept_apart() -> void:
	_fill("Grizzly Bears", 4)      # {1}{G}, mv 2
	_fill("Dark Ritual", 4)        # {B},    mv 1
	var s := DeckStats.speed(deck)
	assert_almost_eq(float(s["creature_cost"]), 2.0, 0.001)
	assert_almost_eq(float(s["spell_cost"]), 1.0, 0.001)
	assert_eq(int(s["creatures"]), 4)
	assert_almost_eq(float(s["average_power"]), 2.0, 0.001)


func test_land_is_left_out_of_every_average() -> void:
	_fill("Grizzly Bears", 4)
	var without: float = DeckStats.speed(deck)["creature_cost"]
	_fill("Forest", 20)
	assert_almost_eq(float(DeckStats.speed(deck)["creature_cost"]),
		without, 0.001, "twenty Forests do not make the deck cheaper")


func test_a_cheap_creature_arrives_sooner_than_a_dear_one() -> void:
	_fill("Forest", 20)
	_fill("Grizzly Bears", 20)          # mv 2
	var early := DeckStats.creature_by_turn(deck, 2)
	deck = DeckModel.new()
	_fill("Forest", 20)
	_fill("Craw Wurm", 20)              # mv 6
	assert_eq(DeckStats.creature_by_turn(deck, 2), 0.0,
		"nothing castable on turn two")
	assert_gt(early, 0.9, "…where Bears are almost always there")


# ------------------------------------------- what the deck fights --

func test_colour_hate_is_read_off_the_oracle_not_a_list() -> void:
	_fill("Karma", 2)
	var hate := DeckStats.color_hate(deck)
	assert_eq(hate.size(), 1, "Karma names a colour")
	assert_eq(String(hate[0]["card"]), "Karma")
	assert_true((hate[0]["colors"] as Array).has(Mtg.ManaColor.B),
		"and the colour it names is black")


func test_a_plain_creature_names_no_colour() -> void:
	_fill("Grizzly Bears", 4)
	assert_eq(DeckStats.color_hate(deck).size(), 0)


func test_the_colour_scan_reads_whole_words() -> void:
	# Caught by looking at the Matchups page (2026-09-06): a substring
	# search found RED in "declared" and "reduce", BLACK in "Blackblade"
	# and in "nonblack". Ten cards were "aimed at red" that never name it.
	_fill("Blaze of Glory", 1)      # "...before blockers are declared"
	_fill("Ali from Cairo", 1)      # "...reduce your life total..."
	_fill("Dakkon Blackblade", 1)   # its own name in its own text
	_fill("Terror", 1)              # "nonblack creature"
	assert_eq(DeckStats.color_hate(deck).size(), 0,
		"none of these names a colour: %s" % str(DeckStats.color_hate(deck)))
	# ...and the words that ARE the colour still count, plural and walk.
	_fill("Karma", 1)               # "Swamps"
	var hate := DeckStats.color_hate(deck)
	assert_eq(hate.size(), 1)
	assert_eq(String(hate[0]["card"]), "Karma")


func test_the_blind_spots_are_the_non_colour_cards() -> void:
	# The opposite question from colour hate, and the more painful one in
	# a game whose opponents have known colours: Terror is a dead card
	# against a black deck.
	_fill("Terror", 2)
	_fill("Karma", 1)
	var blind := DeckStats.color_blind_spots(deck)
	assert_eq(blind.size(), 1, "Karma is aimed at black; Terror is blunted by it")
	assert_eq(String(blind[0]["card"]), "Terror")
	assert_eq(int(blind[0]["count"]), 2)
	assert_true((blind[0]["colors"] as Array).has(Mtg.ManaColor.B))


func test_ante_cards_are_flagged_because_ante_is_real_here() -> void:
	# Shandalar duels are played for a card, so these change what losing
	# costs. Not a curiosity in this game.
	_fill("Contract from Below", 1)
	var ante := DeckStats.ante_cards(deck)
	assert_eq(ante.size(), 1)
	assert_eq(String(ante[0]["card"]), "Contract from Below")


func test_ante_is_a_word_and_not_the_middle_of_enchanted() -> void:
	# "enchANTEd": a substring search put Holy Strength — and ninety other
	# cards — on the ante list (caught by looking, 2026-09-06).
	_fill("Holy Strength", 3)
	_fill("Demonic Attorney", 1)    # "...antes the top card..."
	var ante := DeckStats.ante_cards(deck)
	assert_eq(ante.size(), 1, "one ante card, not two: %s" % str(ante))
	assert_eq(String(ante[0]["card"]), "Demonic Attorney")


func test_evasion_counts_the_creatures_a_wall_cannot_stop() -> void:
	_fill("Air Elemental", 3)      # flying
	_fill("Grizzly Bears", 4)      # ground
	var e := DeckStats.evasion(deck)
	assert_eq(int(e.get(Mtg.Keyword.FLYING, 0)), 3)
	assert_false(e.has(Mtg.Keyword.TRAMPLE), "and claims nothing it has not got")


# ------------------------------------------------------------ rarity --

func test_rarity_comes_from_the_pool_data_not_the_card_objects() -> void:
	# CardData has no rarity field and the 897 card files are hand-written,
	# so it is read from cards/data/*.json — which ships in the .pck.
	# A card from outside the eight 1997 sets. (Black Lotus is NOT such a
	# card — 2ed is Unlimited and it is in there, which this test asserted
	# the wrong way round on its first run.)
	assert_eq(DeckStats.rarity_of("Tarmogoyf"), "",
		"a card outside this pool has no rarity here")
	var bears := DeckStats.rarity_of("Grizzly Bears")
	assert_ne(bears, "", "a card in the pool has one")
	assert_true(bears in ["common", "uncommon", "rare", "special"],
		"and it is one of the real values, not a stray string: %s" % bears)


func test_rarity_counts_the_copies_not_the_names() -> void:
	_fill("Grizzly Bears", 4)
	var tally := DeckStats.rarity_counts(deck)
	var total := 0
	for key in tally:
		total += int(tally[key])
	assert_eq(total, 4, "four copies, counted four times")


func test_every_card_in_a_real_deck_has_a_known_rarity() -> void:
	# The lookup is only worth having if it covers the pool; an "unknown"
	# row on a shipped deck would mean the data and the cards disagree.
	var loaded := DeckList.load_file("res://decks/big_green.deck")
	assert_eq(loaded.errors.size(), 0, "the deck loads: %s" % str(loaded.errors))
	var missing := PackedStringArray()
	for card_name in loaded.cards:
		if DeckStats.rarity_of(String(card_name)) == "":
			missing.append(String(card_name))
	assert_eq(missing.size(), 0,
		"every card has a rarity; these do not: %s" % str(missing))


# ---------------------------------------------------- the four tiers --
#
# *"C symbol (common), U (uncommon, silver), R (rare, gold) and L
# (legendary, purple)"* (2026-09-06). The letter on the card and the bar
# in the Stats window both come from here.

func test_a_legend_is_a_legend_before_it_is_a_rare_or_an_uncommon() -> void:
	# Jedit Ojanen was printed at UNCOMMON in Legends; Lady Orca too. The
	# tier says what the card is.
	assert_eq(DeckStats.rarity_of("Jedit Ojanen"), "uncommon", "the sheet")
	assert_eq(DeckStats.rarity_tier(CardRegistry.get_card("Jedit Ojanen")),
		"legendary", "the tier")
	assert_eq(DeckStats.rarity_tier(CardRegistry.get_card("Serra Angel")), "uncommon")
	assert_eq(DeckStats.rarity_tier(CardRegistry.get_card("Savannah Lions")), "rare")
	assert_eq(DeckStats.rarity_tier(CardRegistry.get_card("Grizzly Bears")), "common")
	assert_eq(DeckStats.rarity_tier(null), "", "no card, no tier")


func test_the_tier_tally_counts_a_legend_once_and_as_a_legend() -> void:
	_fill("Jedit Ojanen", 2)
	_fill("Serra Angel", 3)
	_fill("Savannah Lions", 4)
	_fill("Plains", 10)
	var tiers := DeckStats.rarity_tiers(deck)
	assert_eq(int(tiers.get("legendary", 0)), 2)
	assert_eq(int(tiers.get("uncommon", 0)), 3, "the legend is NOT here too")
	assert_eq(int(tiers.get("rare", 0)), 4)
	assert_eq(int(tiers.get("common", 0)), 10)
	assert_false(tiers.has("unknown"), "every one of these is in the pool")
	# ...whereas the printed count files the legend under its sheet.
	assert_eq(int(DeckStats.rarity_counts(deck).get("uncommon", 0)), 5)

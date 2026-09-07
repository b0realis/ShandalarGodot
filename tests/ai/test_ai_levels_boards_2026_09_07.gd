extends GameTest
## THE LEVELLER (2026-09-07, "The Deck, second pass"). Balance is the
## one card in this pool that levels every player down to the smallest
## count of lands, cards in hand and creatures, and the pilot cast it
## the way it casts any two-mana sorcery: for its printed worth, at the
## first main phase it could afford it. The census of The Deck against
## the starters caught it at fifteen lands to their eight with four
## cards to their none — seven lands and four cards sacrificed for
## nothing, in a deck whose every card is a card it needs. Measured on
## The Deck against the five shipped starters (docs/ROADMAP.md, "The
## Deck, second pass").
##
## Everything here acts through AiPlayer.act and the public MtgGame API.
## [member AiProfile.levels_boards] gates the pricing, so each behaviour
## is pinned twice: for a profile that prices the leveller and for one
## that casts it blind.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _lands(seat: int, land_name: String, count: int) -> void:
	for _i in count:
		put_battlefield(seat, land_name)


func _creatures(seat: int) -> int:
	var n := 0
	for inst in g.players[seat].battlefield:
		if inst.is_creature():
			n += 1
	return n


func _lands_of(seat: int) -> int:
	var n := 0
	for inst in g.players[seat].battlefield:
		if inst.is_land():
			n += 1
	return n


func _levelling() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.levels_boards = true
	return profile


func _blind() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.levels_boards = false
	return profile


# ------------------------------------------------ what it would cost us --

func test_balance_waits_when_we_are_the_one_with_more() -> void:
	var ai := _ai(_levelling())
	var balance := give_hand(0, "Balance")
	for _i in 4:
		give_hand(0, "Craw Wurm")   # a hand we would discard; no green to cast one
	_lands(0, "Plains", 14)
	_lands(1, "Forest", 10)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass", "four lands and four cards for nothing")
	assert_eq(balance.zone, Mtg.Zone.HAND)


func test_a_pilot_that_does_not_price_it_casts_balance_blind() -> void:
	# The null: the behaviour the measurement was taken against.
	var ai := _ai(_blind())
	give_hand(0, "Balance")
	for _i in 4:
		give_hand(0, "Craw Wurm")
	_lands(0, "Plains", 14)
	_lands(1, "Forest", 10)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "cast Balance")


# ------------------------------------------------- what it would cost them --

func test_balance_fires_when_the_board_is_theirs() -> void:
	var ai := _ai(_levelling())
	give_hand(0, "Balance")
	_lands(0, "Plains", 4)
	_lands(1, "Forest", 6)
	put_battlefield(1, "Serra Angel")
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	for _i in 3:
		give_hand(1, "Giant Growth")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "cast Balance")
	resolve_stack()
	# Down to our nothing: no creatures, no cards, four lands (CR 701.17
	# sacrifice — nothing regenerates out of it).
	assert_eq(_creatures(1), 0)
	assert_eq(g.players[1].hand.size(), 0)
	assert_eq(_lands_of(1), 4)
	assert_eq(_lands_of(0), 4)


func test_balance_for_one_card_of_theirs_is_no_reason() -> void:
	# Lands level, no creatures: the only pass that moves is the hand's,
	# and the leveller itself is on the stack by then. One card of
	# theirs for the one card is a trade, not a reason.
	var ai := _ai(_levelling())
	var balance := give_hand(0, "Balance")
	_lands(0, "Plains", 4)
	_lands(1, "Forest", 4)
	give_hand(1, "Giant Growth")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass", "one card for one card is no reason")
	assert_eq(balance.zone, Mtg.Zone.HAND)


func test_balance_is_the_two_for_one_at_an_empty_hand() -> void:
	# ...and two of theirs clears the bar (SWEEP_BAR: a Bears' worth).
	var ai := _ai(_levelling())
	give_hand(0, "Balance")
	_lands(0, "Plains", 4)
	_lands(1, "Forest", 4)
	give_hand(1, "Giant Growth")
	give_hand(1, "Giant Growth")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "cast Balance", "two for one")
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 0)


func test_balance_waits_at_one_creature_each_whatever_their_sizes() -> void:
	# One each: nobody sacrifices, whatever the sizes, so an Angel against
	# a Bears is no reason to cast it.
	var ai := _ai(_levelling())
	var balance := give_hand(0, "Balance")
	_lands(0, "Plains", 5)
	_lands(1, "Forest", 5)
	put_battlefield(0, "Serra Angel")
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass", "an Angel against a Bears: the level is one each")
	assert_eq(balance.zone, Mtg.Zone.HAND)


func test_balance_counts_the_creatures_over_the_fewest() -> void:
	# A second creature of theirs is the one that goes — their cheapest,
	# the choice being theirs — and a Bears for the card is a reason.
	# Our Angel stays: the pass is a count, not a comparison of sizes.
	var ai := _ai(_levelling())
	give_hand(0, "Balance")
	_lands(0, "Plains", 5)
	_lands(1, "Forest", 5)
	put_battlefield(0, "Serra Angel")
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "cast Balance")
	resolve_stack()
	assert_eq(_creatures(1), 1)
	assert_eq(_creatures(0), 1)
	assert_eq(g.players[0].battlefield.filter(func(i): return i.is_creature())[0].data.card_name,
		"Serra Angel")


func test_balance_weighs_our_losses_against_theirs() -> void:
	# Their two extra creatures against our three extra lands and two
	# extra cards: the swing is priced, not counted. Two Bears (a 2/2 is
	# worth 4 at W_BOARD 2.0 → 8 each side of the count) against three
	# lands at five each (W_LANDS, 1 + 3/5 → 1.6 → 4.8) and two cards
	# (W_HAND 1.5 → 3.0): 16 for 7.8, and it fires.
	var ai := _ai(_levelling())
	give_hand(0, "Balance")
	give_hand(0, "Craw Wurm")
	give_hand(0, "Craw Wurm")
	_lands(0, "Plains", 8)
	_lands(1, "Forest", 5)
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "cast Balance")
	resolve_stack()
	assert_eq(_creatures(1), 0)
	assert_eq(_lands_of(0), 5)
	assert_eq(g.players[0].hand.size(), 0)


func test_balance_does_not_trade_our_army_for_their_hand() -> void:
	# Their four cards (6.0) against our two extra creatures — a Serra
	# Angel and a Hill Giant, far more than a Bears' worth: it waits.
	var ai := _ai(_levelling())
	var balance := give_hand(0, "Balance")
	_lands(0, "Plains", 5)
	_lands(1, "Forest", 5)
	put_battlefield(0, "Serra Angel")
	put_battlefield(0, "Hill Giant")
	for _i in 4:
		give_hand(1, "Giant Growth")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass")
	assert_eq(balance.zone, Mtg.Zone.HAND)


# ------------------------------------------------------------- the ladder --

func test_the_ladder_levels_from_sorcerer_up() -> void:
	assert_false(AiProfile.apprentice().levels_boards)
	assert_false(AiProfile.magician().levels_boards)
	assert_true(AiProfile.sorcerer().levels_boards)
	assert_true(AiProfile.wizard().levels_boards)


func test_the_knob_reads_from_the_lab() -> void:
	var profile := AiProfile.wizard()
	assert_eq(profile.apply_overrides("levels_boards=off"), "")
	assert_false(profile.levels_boards)
	assert_eq(profile.apply_overrides("levels_boards=on"), "")
	assert_true(profile.levels_boards)

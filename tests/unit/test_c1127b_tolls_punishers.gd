extends GameTest
## PLAYER REPORT 2, 2026-11-26 — the computer and the punisher permanents
## (own_goal.gd: "the symmetric punisher", "the idle lands", and the land
## drop's rule in full):
##  1. a permanent that charges both seats (a land arriving, a land
##     tapped, an upkeep count) is cast only while the next turns of it
##     take more of their life than of ours; a deck built around it still
##     casts it early; the gate's null arm is the pilot as it was;
##  2. under "X damage … the number of untapped lands they controlled at
##     the beginning of this turn" the lands are tapped at their end step
##     where that is free (mana burn off), never where the mana would burn;
##     there a cast is worth the damage its taps save;
##  3. a heavy land toll is paid rather than a card discarded at the
##     cleanup, while it is affordable; a land we will not play is the
##     first card discarded;
##  4. the land drop's rule, tightened: a heavy toll is paid for a land
##     that is a step to a card in hand, and no toll at all for a land
##     nothing will use.

const OWN_GOAL := preload("res://engine/ai/own_goal.gd")


func after_each() -> void:
	g = null


func _ai(profile: AiProfile = null) -> AiPlayer:
	var p := profile if profile != null else AiProfile.wizard()
	p.develops_late = false
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func _null() -> AiProfile:
	var p := AiProfile.wizard()
	p.forecasts_tactics = false
	return p


func _rungs() -> Array:
	return [AiProfile.apprentice(), AiProfile.magician(), AiProfile.sorcerer(), AiProfile.wizard()]


func _drive(ai: AiPlayer, n := 8) -> void:
	for _i in n:
		var line := ai.act(g)
		if not g.stack.is_empty(): resolve_stack()
		if line == "" or line == "pass" or g.game_over: break


func _many(pid: int, card_name: String, n: int) -> void:
	for _i in n: put_battlefield(pid, card_name)


func _hand(pid: int, card_name: String, n: int) -> void:
	for _i in n: give_hand(pid, card_name)


# ------------------------------------------------ 1 the symmetric punisher --

func test_no_ankh_at_four_life_with_lands_still_to_play() -> void:
	for profile in _rungs():
		before_each()
		var ai := _ai(profile)
		advance_to_step(Mtg.Step.MAIN1)
		_many(0, "Forest", 2)
		_many(1, "Forest", 10)
		g.players[0].life = 4
		var ankh := give_hand(0, "Ankh of Mishra")
		_hand(0, "Forest", 3)
		assert_ne(ai._cast_gate(g, ankh), "", profile.profile_name)
		_drive(ai)
		assert_eq(ankh.zone, Mtg.Zone.HAND, profile.profile_name)


func test_null_arm_casts_the_ankh_as_before() -> void:
	var ai := _ai(_null())
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Forest", 2)
	_many(1, "Forest", 10)
	g.players[0].life = 4
	var ankh := give_hand(0, "Ankh of Mishra")
	_hand(0, "Forest", 3)
	assert_eq(ai._cast_gate(g, ankh), "")
	_drive(ai)
	assert_eq(ankh.zone, Mtg.Zone.BATTLEFIELD, "the gate off is the pilot as it was")


func test_the_ankh_deck_casts_its_ankh_early() -> void:
	var ai := _ai()
	var names: Array[String] = []
	for row in [["Atog", 4], ["Serendib Efreet", 4], ["Lightning Bolt", 4],
			["Chain Lightning", 4], ["Black Vise", 4], ["Ankh of Mishra", 4],
			["Mountain", 24]]:
		for _i in int(row[1]): names.append(String(row[0]))
	g.players[0].deck_names = names
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Mountain", 1)
	_many(1, "Forest", 1)
	_hand(1, "Forest", 6)
	var ankh := give_hand(0, "Ankh of Mishra")
	_hand(0, "Mountain", 2)
	give_hand(0, "Atog")
	_drive(ai)
	assert_eq(ankh.zone, Mtg.Zone.BATTLEFIELD, "early and gladly")
	assert_eq(g.players[0].life, 20, "the land went down before the Ankh")


func test_the_ankh_estimate() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Forest", 2)
	_many(1, "Forest", 2)
	_hand(1, "Forest", 5)
	var ankh := give_hand(0, "Ankh of Mishra")
	give_hand(0, "Forest")
	give_hand(0, "Craw Wurm")   # six mana: we still want our lands
	# Even: both seats still want lands, at twenty life each.
	assert_eq(OWN_GOAL.punisher_refusal(g, ai, ankh), "")
	# We are the one in reach of it.
	g.players[0].life = 5
	assert_ne(OWN_GOAL.punisher_refusal(g, ai, ankh), "")
	# They are: the toll is the last of their life, and not of ours.
	g.players[0].life = 20
	g.players[1].life = 4
	assert_eq(OWN_GOAL.punisher_refusal(g, ai, ankh), "")
	# The beatdown's Ankh: their life is what our attack leaves of it.
	g.players[0].life = 8
	g.players[1].life = 8
	_many(0, "Craw Wurm", 1)
	assert_eq(OWN_GOAL.punisher_refusal(g, ai, ankh), "")
	# No card that is not one of these is read.
	assert_eq(OWN_GOAL.punisher_refusal(g, ai, give_hand(0, "Howling Mine")), "")
	assert_eq(OWN_GOAL.punisher_refusal(g, ai, give_hand(0, "Black Vise")), "")
	assert_eq(OWN_GOAL.punisher_refusal(g, ai, give_hand(0, "Dingus Egg")), "")
	assert_eq(OWN_GOAL.punisher_refusal(g, ai, give_hand(0, "Grizzly Bears")), "")


func test_manabarbs_is_for_the_seat_that_taps_less() -> void:
	# A full hand of spells at five life, against a board that is done.
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Mountain", 4)
	_many(1, "Forest", 4)
	_many(1, "Grizzly Bears", 2)
	g.players[0].life = 5
	var barbs := give_hand(0, "Manabarbs")
	_hand(0, "Hill Giant", 2)
	assert_ne(ai._cast_gate(g, barbs), "")
	_drive(ai)
	assert_eq(barbs.zone, Mtg.Zone.HAND)
	# Our board is down and our hand is empty; theirs is full.
	before_each()
	ai = _ai()
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Mountain", 4)
	_many(0, "Hill Giant", 2)
	_many(1, "Forest", 4)
	_hand(1, "Forest", 6)
	barbs = give_hand(0, "Manabarbs")
	assert_eq(ai._cast_gate(g, barbs), "")
	_drive(ai)
	assert_eq(barbs.zone, Mtg.Zone.BATTLEFIELD)


func test_an_upkeep_count_is_cast_at_the_seat_that_has_the_things() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Swamp", 2)
	_many(0, "Plains", 4)
	_many(1, "Forest", 4)
	var karma := give_hand(0, "Karma")
	assert_ne(ai._cast_gate(g, karma), "", "our Swamps, none of theirs")
	_many(1, "Swamp", 4)
	assert_eq(ai._cast_gate(g, karma), "", "four of theirs to two of ours")
	assert_eq(_ai(_null())._cast_gate(g, karma), "")


func test_power_surge_is_cast_at_idle_lands() -> void:
	var ai := _ai()
	g.rules.mana_burn = true
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Mountain", 6)
	_many(1, "Forest", 2)
	_hand(1, "Forest", 7)
	var surge := give_hand(0, "Power Surge")
	assert_ne(ai._cast_gate(g, surge), "", "six idle lands of ours, none of theirs")
	before_each()
	ai = _ai()
	g.rules.mana_burn = true
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Mountain", 2)
	_many(1, "Forest", 8)
	give_hand(1, "Forest")
	surge = give_hand(0, "Power Surge")
	assert_eq(ai._cast_gate(g, surge), "", "eight lands and one card: theirs to pay")
	_drive(ai)
	assert_eq(surge.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------------- 2 the idle lands --

func _their_end_step_under_a_surge(burn: bool, profile: AiProfile = null) -> AiPlayer:
	var ai := _ai(profile)
	g.rules.mana_burn = burn
	advance_to_next_turn()   # seat 1's turn
	put_battlefield(1, "Power Surge")
	_many(0, "Forest", 3)
	advance_to_step(Mtg.Step.END)
	assert_ok(g.pass_priority(1))   # they are done: the last word is ours
	return ai


func _open_lands() -> int:
	var open := 0
	for inst in g.players[0].battlefield:
		if inst.is_land() and not inst.tapped: open += 1
	return open


func test_idle_lands_are_tapped_before_our_turn_where_that_is_free() -> void:
	var ai := _their_end_step_under_a_surge(false)
	assert_eq(g.active_player, 1)
	assert_eq(OWN_GOAL.idle_land_toll(g, 0), 1)
	var line := ai.act(g)
	assert_string_contains(line, "idle land")
	assert_eq(_open_lands(), 0)
	_drive(ai)
	advance_to_step(Mtg.Step.DRAW)
	assert_eq(g.active_player, 0)
	assert_eq(g.players[0].life, 20, "no land stood untapped as our turn began")


func test_null_arm_takes_the_surge() -> void:
	var ai := _their_end_step_under_a_surge(false, _null())
	_drive(ai)
	assert_eq(_open_lands(), 3)
	advance_to_step(Mtg.Step.DRAW)
	assert_eq(g.players[0].life, 17, "the gate off is the pilot as it was")


func test_lands_are_not_tapped_into_mana_burn() -> void:
	var ai := _their_end_step_under_a_surge(true)
	assert_eq(ai.act(g), "pass")
	assert_eq(g.players[0].life, 20)
	advance_to_step(Mtg.Step.DRAW)
	assert_eq(g.players[0].life, 17, "the surge's three, and nothing burned before it")


func test_a_painful_land_is_left_alone() -> void:
	var ai := _their_end_step_under_a_surge(false)
	var city := put_battlefield(0, "City of Brass")
	assert_string_contains(ai.act(g), "3 idle lands")
	assert_false(city.tapped, "its tap costs the point the surge would")
	assert_eq(_open_lands(), 1)
	assert_eq(g.players[0].life, 20)


func test_no_surge_no_tapping() -> void:
	var ai := _ai()
	g.rules.mana_burn = false
	advance_to_next_turn()
	put_battlefield(1, "Howling Mine")
	_many(0, "Forest", 3)
	advance_to_step(Mtg.Step.END)
	assert_ok(g.pass_priority(1))
	assert_eq(OWN_GOAL.idle_land_toll(g, 0), 0)
	_drive(ai)
	assert_eq(_open_lands(), 3)


func test_a_cast_is_worth_the_surge_it_saves() -> void:
	var ai := _ai()
	g.rules.mana_burn = true
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Forest", 3)
	var bears := give_hand(0, "Grizzly Bears")
	var plain: float = ai._cast_value(g, bears, [], 0)
	assert_eq(OWN_GOAL.idle_relief(g, ai, bears), 0.0)
	put_battlefield(1, "Power Surge")
	assert_gt(OWN_GOAL.idle_relief(g, ai, bears), 0.0)
	assert_gt(float(ai._cast_value(g, bears, [], 0)), plain)
	g.rules.mana_burn = false
	assert_eq(OWN_GOAL.idle_relief(g, ai, bears), 0.0, "tapped away for nothing instead")
	g.rules.mana_burn = true
	assert_eq(OWN_GOAL.idle_relief(g, _ai(_null()), bears), 0.0)


# ------------------------------------------- 3 the land or the discard --

func _eight_cards_under_an_ankh(life: int, profile: AiProfile = null) -> Array:
	var ai := _ai(profile)
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(1, "Ankh of Mishra")
	g.players[0].life = life
	var land := give_hand(0, "Forest")
	_hand(0, "Craw Wurm", 7)
	return [ai, land]


func test_a_heavy_toll_is_paid_rather_than_a_discard() -> void:
	var set_up := _eight_cards_under_an_ankh(8)
	var ai: AiPlayer = set_up[0]
	var land: CardInstance = set_up[1]
	_drive(ai)
	assert_eq(land.zone, Mtg.Zone.HAND, "first main: nothing to cast with it, it waits")
	advance_to_step(Mtg.Step.MAIN2)
	_drive(ai)
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD, "second main, eight cards: the land, not a discard")
	assert_eq(g.players[0].life, 6)


func test_seven_cards_hold_the_land() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN2)
	put_battlefield(1, "Ankh of Mishra")
	g.players[0].life = 8
	var land := give_hand(0, "Forest")
	_hand(0, "Craw Wurm", 6)
	_drive(ai)
	assert_eq(land.zone, Mtg.Zone.HAND, "no discard is coming")
	assert_eq(g.players[0].life, 8)


func test_a_toll_into_burn_range_is_not_paid_and_the_land_is_discarded() -> void:
	var set_up := _eight_cards_under_an_ankh(5)
	var ai: AiPlayer = set_up[0]
	var land: CardInstance = set_up[1]
	advance_to_step(Mtg.Step.MAIN2)
	_drive(ai)
	assert_eq(land.zone, Mtg.Zone.HAND, "three life is burn range")
	assert_eq(g.players[0].life, 5)
	assert_eq(ai.answer_discard(g, 0, 1), [land] as Array[CardInstance],
		"the land we will not play goes first")


func test_their_attack_is_burn_range_too() -> void:
	var set_up := _eight_cards_under_an_ankh(8)
	var ai: AiPlayer = set_up[0]
	var land: CardInstance = set_up[1]
	_many(1, "Craw Wurm", 1)
	advance_to_step(Mtg.Step.MAIN2)
	_drive(ai)
	assert_eq(land.zone, Mtg.Zone.HAND, "six life against six power")
	assert_eq(ai.answer_discard(g, 0, 1), [land] as Array[CardInstance])


func test_discard_without_a_toll_is_as_it_was() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN2)
	put_battlefield(1, "Howling Mine")
	g.players[0].life = 5
	var land := give_hand(0, "Forest")
	_hand(0, "Craw Wurm", 7)
	assert_false(OWN_GOAL.land_never_safe(g, ai, land))
	assert_ne(ai.answer_discard(g, 0, 1), [land] as Array[CardInstance],
		"a land-light hand keeps its land")
	var before := _ai(_null()).answer_discard(g, 0, 1)
	put_battlefield(1, "Ankh of Mishra")
	assert_eq(_ai(_null()).answer_discard(g, 0, 1), before,
		"the gate off is the pilot as it was")


# --------------------------------------------------- 4 the rule, tightened --

func test_a_heavy_toll_is_paid_for_a_step_to_a_cast() -> void:
	# Two Ankhs: four a land, a third of twelve. Two Forests down, two in
	# hand, and a Giant Spider they reach between them.
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Forest", 2)
	put_battlefield(1, "Ankh of Mishra")
	put_battlefield(1, "Ankh of Mishra")
	g.players[0].life = 12
	var first := give_hand(0, "Forest")
	var second := give_hand(0, "Forest")
	give_hand(0, "Giant Spider")
	_drive(ai)
	assert_true(first.zone == Mtg.Zone.BATTLEFIELD or second.zone == Mtg.Zone.BATTLEFIELD,
		"the third land of four")
	assert_eq(g.players[0].life, 8)
	# ...but not when the two lands would leave us in burn range.
	before_each()
	ai = _ai()
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Forest", 2)
	put_battlefield(1, "Ankh of Mishra")
	put_battlefield(1, "Ankh of Mishra")
	g.players[0].life = 10
	first = give_hand(0, "Forest")
	second = give_hand(0, "Forest")
	give_hand(0, "Giant Spider")
	_drive(ai)
	assert_eq(first.zone, Mtg.Zone.HAND)
	assert_eq(second.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].life, 10)


func test_no_toll_is_paid_for_a_land_nothing_will_use() -> void:
	var ai := _ai()
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Forest", 6)
	put_battlefield(1, "Ankh of Mishra")
	var land := give_hand(0, "Forest")
	give_hand(0, "Grizzly Bears")
	_drive(ai)
	assert_eq(land.zone, Mtg.Zone.HAND, "a seventh land for a hand of two-drops")
	assert_eq(g.players[0].life, 20)
	# An X spell has a use for every land.
	before_each()
	ai = _ai()
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Forest", 6)
	put_battlefield(1, "Ankh of Mishra")
	land = give_hand(0, "Forest")
	give_hand(0, "Stream of Life")
	_drive(ai)
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD)
	# And with no toll on the table every land is played, as ever.
	before_each()
	ai = _ai()
	advance_to_step(Mtg.Step.MAIN1)
	_many(0, "Forest", 6)
	land = give_hand(0, "Forest")
	_drive(ai)
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD)

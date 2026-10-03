extends GameTest
## INSTANT-ONLY MANA, A TWO-STEP MANA ENGINE AND THE TURN SKIPS (Pack 8,
## 2026-10-03; engine packages E6 and E8; [member
## AiProfile.forecasts_tactics]).
##
##  * LION'S EYE DIAMOND — "Discard your hand, Sacrifice this artifact: Add
##    three mana of any one color. Activate only as an instant". Never
##    auto-tapped (the planner skips it), never counted as a hand's mana by
##    the mulligan ([method AiMulligan.is_free_source]), and cracked only
##    into an EMPTY hand for an activated ability its three mana pay for
##    (mirage_tactics.gd `lion_eye_action`). No crash, no waste.
##  * VENTIFACT BOTTLE's X charge is a two-step plan the pilot does not
##    make: its X is unsized, so it is never paid for — no waste.
##  * CHRONATOG and AVIZOA ("you skip your next turn / untap step") stay
##    opaque — never bought for a pump — unless the pump is the lethal
##    damage this combat (`turn_skip_option`).


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-8", true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


func _ai() -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


# ------------------------------------------------------------- the diamond --

func test_the_mulligan_does_not_count_the_diamond_as_mana() -> void:
	var hand: Array[CardInstance] = []
	hand.append(give_hand(0, "Lion's Eye Diamond"))
	hand.append(give_hand(0, "Grizzly Bears"))
	assert_false(AiMulligan.is_free_source(hand[0]), "its mana costs the hand")
	assert_eq(AiMulligan.mana_sources(hand), 0)
	var mox := give_hand(0, "Mox Emerald")
	assert_true(AiMulligan.is_free_source(mox), "a Mox still is")


func test_the_diamond_is_never_cracked_with_cards_in_hand() -> void:
	var ai := _ai()
	var diamond := put_battlefield(0, "Lion's Eye Diamond")
	put_battlefield(0, "Rod of Ruin")
	give_hand(0, "Grizzly Bears")
	g.players[1].life = 1
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_eq(diamond.zone, Mtg.Zone.BATTLEFIELD, "the hand is worth more than the mana")
	assert_eq(g.players[0].hand.size(), 1)


func test_the_diamond_is_cracked_into_an_empty_hand_for_the_win() -> void:
	var ai := _ai()
	var diamond := put_battlefield(0, "Lion's Eye Diamond")
	put_battlefield(0, "Rod of Ruin")
	put_battlefield(0, "Mountain")
	g.players[1].life = 1
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "cracks Lion's Eye Diamond")
	assert_eq(diamond.zone, Mtg.Zone.GRAVEYARD)
	assert_string_contains(ai.act(g), "Rod of Ruin")
	resolve_stack()
	assert_true(g.game_over)


func test_the_diamond_is_left_alone_with_nothing_to_pay_for() -> void:
	var ai := _ai()
	var diamond := put_battlefield(0, "Lion's Eye Diamond")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_eq(diamond.zone, Mtg.Zone.BATTLEFIELD)


# ---------------------------------------------------------- the bottle --

func test_the_bottle_s_charge_is_never_paid_for() -> void:
	var ai := _ai()
	var bottle := put_battlefield(0, "Ventifact Bottle")
	var lands: Array = []
	for _i in 4: lands.append(put_battlefield(0, "Forest"))
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_false(ai._ability_available(g, bottle, 0, true), "an unsized X")
	for land in lands:
		assert_false(land.tapped, "no mana spent on it")


# ---------------------------------------------------------- the turn skips --

func _attack_unblocked(ids: Array) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, ids))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	var guard := 0
	while g.priority_player != 0 and guard < 5:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1


func test_chronatog_is_never_bought_for_a_pump() -> void:
	var ai := _ai()
	var tog := put_battlefield(0, "Chronatog")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	_attack_unblocked([tog.id])
	var said := ai.act(g)
	assert_false(said.contains("Chronatog"), "a turn for three damage: %s" % said)
	assert_eq(g.players[0].turns_to_skip, 0)


func test_chronatog_skips_a_turn_it_will_not_need() -> void:
	var ai := _ai()
	var tog := put_battlefield(0, "Chronatog")
	g.players[1].life = 4
	_attack_unblocked([tog.id])
	assert_string_contains(ai.act(g), "Chronatog")
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_true(g.game_over, "1 + 3 = 4")

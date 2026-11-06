extends GameTest
## Pack 10 (the Urza block), the fair AI's UPKEEP ANSWERS (stage 4,
## resolution; engine/ai/urza_spells.gd `echo_choice` and
## `unless_objects_answer`, [member AiProfile.forecasts_tactics]).
##
## Echo (CR 702.30a) asks at our first upkeep with the permanent whether to
## pay its cost again; the heuristic seat pays whatever it can afford
## ([method DecisionAgent.echo_hint]). The Urza AI weighs the permanent's
## worth to our board — a Bone Shredder's 1/1 body once its arrival is spent
## — against the echo priced like a rent and the cast this turn the payment
## would cost, so an arrival creature is let go and a Herald of Serra is
## kept. "Sacrifice it unless you discard a card / sacrifice an enchantment"
## (Masticore, Endless Wurm, Body Snatcher) is paid with our cheapest object
## while that is worth less than the source. Our own hand and the public
## board only: their hand and both libraries do not move an answer. With the
## gate off every echo is paid and every such payment made, as before.


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-10", true)
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(on := true) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func _lands(pid: int, land: String, n: int) -> void:
	for _i in n:
		put_battlefield(pid, land)


func _to_upkeep_resolved(turn: int) -> void:
	var guard := 0
	while not (g.turn_number == turn and g.current_step() == Mtg.Step.UPKEEP) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	resolve_stack()


# ------------------------------------------------------------------------- echo --

func test_an_arrival_creature_is_let_go_for_the_turns_cast() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 3)
	var shredder := put_battlefield(0, "Bone Shredder")
	give_hand(0, "Hypnotic Specter")
	advance_to_step(Mtg.Step.MAIN1)
	assert_false(ai.echo_hint(g, 0, shredder, ManaCost.parse("{2}{B}")),
		"a 1/1 flier for the Specter's cast")


func test_the_same_echo_is_paid_with_nothing_else_to_cast() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 3)
	var shredder := put_battlefield(0, "Bone Shredder")
	advance_to_step(Mtg.Step.MAIN1)
	assert_true(ai.echo_hint(g, 0, shredder, ManaCost.parse("{2}{B}")),
		"the mana has nothing better to do")


func test_a_big_body_is_kept_even_over_a_cast() -> void:
	var ai := _ai()
	_lands(0, "Plains", 4)
	var herald := put_battlefield(0, "Herald of Serra")
	give_hand(0, "White Knight")
	advance_to_step(Mtg.Step.MAIN1)
	assert_true(ai.echo_hint(g, 0, herald, ManaCost.parse("{2}{W}{W}")))


func test_an_anthem_over_its_squirrels_is_kept() -> void:
	var ai := _ai()
	_lands(0, "Forest", 6)
	var hermit := put_battlefield(0, "Deranged Hermit")
	advance_to_step(Mtg.Step.MAIN1)
	resolve_stack()
	assert_eq(g.players[0].creatures().size(), 5, "the Hermit and its four Squirrels")
	give_hand(0, "Craw Wurm")
	assert_true(ai.echo_hint(g, 0, hermit, ManaCost.parse("{3}{G}{G}")),
		"its leaving shrinks four Squirrels: worth more than the Wurm's turn")


func test_the_null_arm_pays_every_echo() -> void:
	var ai := _ai(false)
	_lands(0, "Swamp", 3)
	var shredder := put_battlefield(0, "Bone Shredder")
	give_hand(0, "Hypnotic Specter")
	advance_to_step(Mtg.Step.MAIN1)
	assert_true(ai.echo_hint(g, 0, shredder, ManaCost.parse("{2}{B}")),
		"gate off: DecisionAgent's default, as before Pack 10")


func test_the_shredder_is_sacrificed_at_the_upkeep() -> void:
	_ai()
	_lands(0, "Swamp", 3)
	var shredder := put_battlefield(0, "Bone Shredder")
	give_hand(0, "Hypnotic Specter")
	_to_upkeep_resolved(3)
	assert_eq(shredder.zone, Mtg.Zone.GRAVEYARD, "let go, the Specter cast instead")


func test_the_echo_answer_ignores_their_hand_and_both_libraries() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 3)
	var shredder := put_battlefield(0, "Bone Shredder")
	give_hand(0, "Hypnotic Specter")
	advance_to_step(Mtg.Step.MAIN1)
	var before := ai.echo_hint(g, 0, shredder, ManaCost.parse("{2}{B}"))
	give_hand(1, "Lightning Bolt")
	give_hand(1, "Terror")
	g.players[0].library.reverse()
	g.players[1].library.reverse()
	assert_eq(ai.echo_hint(g, 0, shredder, ManaCost.parse("{2}{B}")), before)


# ------------------------------------------------------- "unless you discard ..." --

const MASTICORE_ASK := "Masticore: discard a card? (otherwise sacrifice Masticore)"


func test_masticore_eats_a_spare_land() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 6)
	put_battlefield(0, "Masticore")
	give_hand(0, "Forest")
	assert_true(ai.answer_yes_no(g, 0, MASTICORE_ASK, true))


func test_masticore_is_let_go_for_a_card_worth_more() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 6)
	put_battlefield(0, "Masticore")
	give_hand(0, "Shivan Dragon")
	assert_false(ai.answer_yes_no(g, 0, MASTICORE_ASK, true), "the Dragon is worth more than the 4/4")


func test_the_null_arm_keeps_the_hint() -> void:
	var ai := _ai(false)
	_lands(0, "Mountain", 6)
	put_battlefield(0, "Masticore")
	give_hand(0, "Shivan Dragon")
	assert_true(ai.answer_yes_no(g, 0, MASTICORE_ASK, true))


func test_masticore_at_the_upkeep_discards_the_land() -> void:
	_ai()
	_lands(0, "Mountain", 6)
	var masticore := put_battlefield(0, "Masticore")
	var forest := give_hand(0, "Forest")
	_to_upkeep_resolved(3)
	assert_eq(masticore.zone, Mtg.Zone.BATTLEFIELD)
	assert_ne(forest.zone, Mtg.Zone.HAND)


func test_endless_wurm_eats_our_cheapest_enchantment() -> void:
	var ai := _ai()
	_lands(0, "Forest", 5)
	put_battlefield(0, "Endless Wurm")
	put_battlefield(0, "Castle")
	assert_true(ai.answer_yes_no(g, 0,
		"Endless Wurm: sacrifice an enchantment? (otherwise sacrifice Endless Wurm)", true))

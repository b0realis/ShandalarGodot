extends GameTest
## Pack 9 engine package E2 — THE FAIR AI PAYS BUYBACK WHEN IT IS WORTH IT
## ([method AiPlayer._buyback_row], gate [member AiProfile.forecasts_tactics]).
##
## The minimum the brief asks for, the rest of the policy being the Pack 9
## AI stage's (AI.md §2): the buyback row is paid when it is payable, its
## mana does not take the mana another card castable now needs, a land it
## sacrifices keeps the pilot at its land floor, the objects it eats are
## worth less than the card, and a life payment leaves ten life or more.
## With the gate off the pilot pays the printed row, as it did before
## Pack 9. The decision reads the pilot's own hand and the public board:
## the opponent's hand and either library may change without changing it.

const OC := preload("res://engine/additional_object_costs.gd")


static func _is_land(i: CardInstance) -> bool:
	return i.is_land()


func _ai(forecasts := true, seat := 0) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.forecasts_tactics = forecasts
	var ai := AiPlayer.new(seat, p)
	g.set_agent(seat, ai)
	return ai


func _whispers() -> CardData:
	return CardData.new("Test Whispers", "{U}", Mtg.CardType.INSTANT) \
		.spell(DrawEffect.new(1)) \
		.with_buyback({"mana": "{5}"})


func _touch() -> CardData:
	return CardData.new("Test Touch", "{R}", Mtg.CardType.INSTANT) \
		.spell(DamageEffect.new(1).any_target()) \
		.with_buyback({"mana": "{4}"})


func _mists() -> CardData:
	return CardData.new("Test Mists", "{G}", Mtg.CardType.INSTANT) \
		.spell(GainLifeEffect.new(2)) \
		.with_buyback({"object_costs": [OC.sacrificing("a land", _is_land)],
			"text": "Sacrifice a land"})


func _slaughter() -> CardData:
	return CardData.new("Test Slaughter", "{B}", Mtg.CardType.INSTANT) \
		.spell(GainLifeEffect.new(1)) \
		.with_buyback({"life": 4, "text": "Pay 4 life"})


func _forbid() -> CardData:
	return CardData.new("Test Forbid", "{1}{U}{U}", Mtg.CardType.INSTANT) \
		.spell(CounterEffect.new()) \
		.with_buyback({"object_costs": [OC.discarding("card", Callable(), 2)],
			"text": "Discard two cards"})


func _lands(pid: int, land: String, n: int) -> void:
	for _i in n:
		put_battlefield(pid, land)


## Advance into the OPPONENT's turn and hand seat 0 priority in [param step].
func _their_turn_at(step: int) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == step) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


# ------------------------------------------------------------ the action --

func test_it_buys_back_a_draw_at_their_end_step_with_spare_mana() -> void:
	var ai := _ai()
	_lands(0, "Island", 6)
	var whispers := give_synthetic(0, _whispers())
	_their_turn_at(Mtg.Step.END)
	var hand_before := g.players[0].hand.size()
	assert_string_contains(ai.act(g), "Test Whispers")
	assert_true(g.buyback_paid(whispers), "six Islands: {U} plus {5}")
	resolve_stack()
	assert_eq(whispers.zone, Mtg.Zone.HAND, "bought back")
	assert_eq(g.players[0].hand.size(), hand_before + 1, "and a card drawn")


func test_short_of_the_buyback_it_casts_the_printed_row() -> void:
	var ai := _ai()
	_lands(0, "Island", 3)
	var whispers := give_synthetic(0, _whispers())
	_their_turn_at(Mtg.Step.END)
	assert_string_contains(ai.act(g), "Test Whispers")
	assert_false(g.buyback_paid(whispers))
	resolve_stack()
	assert_eq(whispers.zone, Mtg.Zone.GRAVEYARD)


func test_the_null_arm_pays_the_printed_cost() -> void:
	var ai := _ai(false)
	_lands(0, "Island", 6)
	var whispers := give_synthetic(0, _whispers())
	assert_eq(ai._paying_mode(g, whispers.data), -1, "gate off: the printed row, as before Pack 9")


# --------------------------------------------------------- the decisions --

func test_it_pays_buyback_when_nothing_else_wants_the_mana() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 6)
	advance_to_step(Mtg.Step.MAIN1)
	var touch := give_synthetic(0, _touch())
	assert_eq(ai._paying_mode(g, touch.data), 1)


func test_it_declines_when_the_buyback_takes_a_creatures_mana() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 6)
	advance_to_step(Mtg.Step.MAIN1)
	var touch := give_synthetic(0, _touch())
	give_hand(0, "Hill Giant")
	assert_eq(ai._paying_mode(g, touch.data), -1, "{R} + {3}{R} fit six lands; {R}{4} + {3}{R} do not")


func test_a_card_that_never_fits_beside_it_costs_the_buyback_nothing() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 5)
	advance_to_step(Mtg.Step.MAIN1)
	var touch := give_synthetic(0, _touch())
	give_hand(0, "Shivan Dragon")
	assert_eq(ai._paying_mode(g, touch.data), 1, "the Dragon is not castable beside either row")


func test_it_cannot_buy_back_what_it_cannot_afford() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 4)
	var touch := give_synthetic(0, _touch())
	assert_eq(ai._paying_mode(g, touch.data), -1)


func test_it_never_sacrifices_a_land_below_its_floor() -> void:
	var ai := _ai()
	_lands(0, "Forest", 3)
	var mists := give_synthetic(0, _mists())
	assert_eq(ai._paying_mode(g, mists.data), -1, "three lands: the floor")
	_lands(0, "Forest", 2)
	assert_eq(ai._paying_mode(g, mists.data), 1, "five lands and nothing dear in hand")
	give_hand(0, "Craw Wurm")
	assert_eq(ai._paying_mode(g, mists.data), -1, "a six-drop in hand wants every land")


func test_it_keeps_ten_life_after_a_life_buyback() -> void:
	var ai := _ai()
	put_battlefield(0, "Swamp")
	var slaughter := give_synthetic(0, _slaughter())
	g.players[0].life = 13
	assert_eq(ai._paying_mode(g, slaughter.data), -1)
	g.players[0].life = 20
	assert_eq(ai._paying_mode(g, slaughter.data), 1)


func test_it_does_not_discard_good_cards_for_a_buyback() -> void:
	var ai := _ai()
	_lands(0, "Island", 3)
	var forbid := give_synthetic(0, _forbid())
	give_hand(0, "Shivan Dragon")
	give_hand(0, "Serra Angel")
	assert_eq(ai._paying_mode(g, forbid.data), -1)


func test_the_decision_ignores_hidden_information() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 6)
	advance_to_step(Mtg.Step.MAIN1)
	var touch := give_synthetic(0, _touch())
	var first := ai._paying_mode(g, touch.data)
	give_hand(1, "Lightning Bolt")
	give_hand(1, "Counterspell")
	g.players[1].library.reverse()
	g.players[0].library.reverse()
	assert_eq(ai._paying_mode(g, touch.data), first, "their hand and the libraries' order change nothing")

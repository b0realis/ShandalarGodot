extends GameTest
## Pack 9 bug pass (h2-1): a FREE payment row under our own cost reducer
## ([member AiProfile.forecasts_tactics]).
##
## Aluren's and Dream Halls' rows cost {0}; our own Emerald or Ruby
## Medallion makes the surcharge -1. The engine clamps a reduction at the
## cost's own generic (CR 601.2f), so the row stays free — but the AI
## planned {0} with -1 on top, got no plan, and its `surcharge == 0` test
## called the row unpayable: the Bears through Aluren, the Wurm and the
## end-step Bolt through Dream Halls were never cast
## ([method AiPlayer._free_at]). With the gate off the granted rows are
## not read at all ([method AiPlayer._paying_mode] answers -1), as before.
## The opponent's hidden hand never moves a decision.


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-9", true)
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


func _their_turn_at(step: int) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == step) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


func _tapped_lands(pid: int) -> int:
	var n := 0
	for inst in g.players[pid].battlefield:
		if inst.is_land() and inst.tapped: n += 1
	return n


func test_aluren_and_our_own_medallion_cast_the_bears_for_nothing() -> void:
	var ai := _ai()
	put_battlefield(1, "Aluren")
	put_battlefield(0, "Emerald Medallion")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	var bears := give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai._paying_mode(g, bears.data, bears), 1, "the AI picks the Aluren row")
	ai.act(g)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(_tapped_lands(0), 0, "the free row taps nothing")


func test_gate_off_casts_the_bears_through_the_printed_row() -> void:
	var ai := _ai(false)
	put_battlefield(1, "Aluren")
	put_battlefield(0, "Emerald Medallion")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	var bears := give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(_tapped_lands(0), 1, "gate off: {1}{G} less one, a Forest")


func test_dream_halls_and_our_own_medallion_cast_the_wurm() -> void:
	var ai := _ai()
	put_battlefield(0, "Dream Halls")
	put_battlefield(0, "Emerald Medallion")
	var wurm := give_hand(0, "Craw Wurm")
	var bears := give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "the Bears paid for it")


func test_gate_off_dream_halls_and_medallion_cast_nothing() -> void:
	var ai := _ai(false)
	put_battlefield(0, "Dream Halls")
	put_battlefield(0, "Emerald Medallion")
	var wurm := give_hand(0, "Craw Wurm")
	give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.HAND, "gate off: no granted row, no mana")


func test_a_bolt_at_their_end_step_through_dream_halls_and_our_ruby_medallion() -> void:
	var ai := _ai()
	put_battlefield(0, "Dream Halls")
	put_battlefield(0, "Ruby Medallion")
	var giant := put_battlefield(1, "Hill Giant")
	var bolt := give_hand(0, "Lightning Bolt")
	var raiders := give_hand(0, "Mons's Goblin Raiders")
	_their_turn_at(Mtg.Step.END)
	assert_string_contains(ai.act(g), "Lightning Bolt")
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(raiders.zone, Mtg.Zone.GRAVEYARD, "the 1/1 red card paid for it")


func test_the_free_row_under_our_medallion_ignores_their_hidden_hand() -> void:
	var outcomes: Array = []
	for hand in [["Counterspell", "Shivan Dragon"], ["Forest", "Forest"], []]:
		g = null
		before_each()
		var ai := _ai()
		put_battlefield(0, "Dream Halls")
		put_battlefield(0, "Emerald Medallion")
		var wurm := give_hand(0, "Craw Wurm")
		give_hand(0, "Grizzly Bears")
		for card_name in hand: give_hand(1, card_name)
		advance_to_step(Mtg.Step.MAIN1)
		ai.act(g)
		resolve_stack()
		outcomes.append(wurm.zone)
	assert_eq(outcomes, [Mtg.Zone.BATTLEFIELD, Mtg.Zone.BATTLEFIELD, Mtg.Zone.BATTLEFIELD])

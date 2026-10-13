extends GameTest
## THE AI AND THE WAITING SACRIFICE (campaign 2026-10-13 f-sac;
## [member AiProfile.forecasts_tactics]).
##
## With the rules option "Forced sacrifices wait on the chain" on
## (RulesOptions.sacrifice_clauses_wait), a Pirate Ship whose last Island
## goes is still on the battlefield while its sacrifice waits on the stack.
## AiPlayer._respond_action never answers its own object on top of the
## stack, so the pilot passed and let the Ship go without its last ping.
## Now its doomed permanent spends what it can do that outlasts it — a
## ping, not a pump of its own and not mana — priced as the mana sink is
## (AiPlayer._c2s_last_use), and a sacrifice it must make takes the doomed
## permanent first (AiPlayer._own_value). Gate off: the old pass. The
## opponent's hidden hand never moves the answer. With the option off the
## clause has already sacrificed the Ship: nothing to answer.


func after_each() -> void:
	g = null


func _ai(on: bool) -> AiPlayer:
	var p := AiProfile.wizard()
	p.mistake_chance = 0.0
	p.develops_late = false
	p.feeds_worst = true
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func _clause_pending(card: CardInstance) -> bool:
	return g.sacrifice_clause_pending(card)


## Seat 0's Pirate Ship loses its last Island with the option on; seat 1
## has a 1/1 the ping kills, and [param their_card] in hand.
func _doomed_ship(on: bool, their_card := "", wait := true) -> Dictionary:
	before_each()
	g.rules.set_preset(RulesOptions.DEFAULT_PRESET)
	g.rules.sacrifice_clauses_wait = wait
	advance_to_step(Mtg.Step.MAIN1)
	var ai := _ai(on)
	var elves := put_battlefield(1, "Llanowar Elves")
	if their_card != "":
		give_hand(1, their_card)
	var island := put_battlefield(0, "Island")
	var ship := put_battlefield(0, "Pirate Ship")
	g.check_state_based_actions()
	g.destroy(island, false)
	g.check_state_based_actions()
	return {"ai": ai, "ship": ship, "elves": elves}


func test_the_doomed_ship_pings_in_answer_to_its_own_sacrifice() -> void:
	var s := _doomed_ship(true)
	var ship: CardInstance = s.ship
	assert_true(_clause_pending(ship), "precondition: the sacrifice waits")
	assert_eq(g.priority_player, 0)
	var did: String = (s.ai as AiPlayer).act(g)
	assert_eq(did, "activated Pirate Ship", "one more ping")
	resolve_stack()
	assert_eq((s.elves as CardInstance).zone, Mtg.Zone.GRAVEYARD, "the 1/1 is the best target")
	assert_eq(ship.zone, Mtg.Zone.GRAVEYARD, "and the Ship still goes")


func test_gate_off_the_pilot_lets_it_go_unused() -> void:
	var s := _doomed_ship(false)
	assert_eq((s.ai as AiPlayer).act(g), "pass", "the old pass")
	resolve_stack()
	assert_eq((s.elves as CardInstance).zone, Mtg.Zone.BATTLEFIELD)
	assert_eq((s.ship as CardInstance).zone, Mtg.Zone.GRAVEYARD)


func test_with_the_option_off_there_is_nothing_to_answer() -> void:
	var s := _doomed_ship(true, "", false)
	assert_eq((s.ship as CardInstance).zone, Mtg.Zone.GRAVEYARD, "sacrificed at once")
	assert_true(g.stack.is_empty())
	assert_eq((s.elves as CardInstance).zone, Mtg.Zone.BATTLEFIELD)


func test_their_hidden_hand_does_not_move_the_answer() -> void:
	var answers: Array = []
	for their_card in ["", "Counterspell", "Forest", "Lightning Bolt"]:
		var s := _doomed_ship(true, their_card)
		answers.append((s.ai as AiPlayer).act(g))
		var top: StackItem = g.stack.back()
		answers.append(top.targets[0].instance_id == (s.elves as CardInstance).id \
			if not top.targets.is_empty() else -1)
	for i in range(2, answers.size()):
		assert_eq(answers[i], answers[i % 2], "the same answer whatever they hold (%d)" % i)


func test_on_their_turn_too() -> void:
	before_each()
	g.rules.set_preset(RulesOptions.DEFAULT_PRESET)
	g.rules.sacrifice_clauses_wait = true
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	var ai := _ai(true)
	put_battlefield(1, "Llanowar Elves")
	var island := put_battlefield(0, "Island")
	var ship := put_battlefield(0, "Pirate Ship")
	g.check_state_based_actions()
	g.destroy(island, false)
	g.check_state_based_actions()
	assert_true(_clause_pending(ship))
	if g.priority_player == 1:
		assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0, "the trigger's controller gets its chance")
	assert_eq(ai.act(g), "activated Pirate Ship")


func test_a_pump_of_its_own_or_mana_is_not_worth_a_last_use() -> void:
	before_each()
	g.rules.set_preset(RulesOptions.DEFAULT_PRESET)
	g.rules.sacrifice_clauses_wait = true
	advance_to_step(Mtg.Step.MAIN1)
	var ai := _ai(true)
	put_battlefield(1, "Llanowar Elves")
	var data := CardData.new("Test Drowning Drake", "{2}", Mtg.CardType.CREATURE) \
		.pt(2, 2).with_sacrifice_if_no_land("island") \
		.activated(ActivatedAbility.new("{R}", false, [PumpEffect.new(1, 0).self_buff()],
			"{R}: This creature gets +1/+0 until end of turn.")) \
		.mana(ManaAbility.new(Mtg.ManaColor.G)) \
		.oracle("{R}: This creature gets +1/+0 until end of turn.\n{T}: Add {G}.\n"
			+ "When you control no Islands, sacrifice this creature.")
	var island := put_battlefield(0, "Island")
	for k in 3: put_battlefield(0, "Mountain")
	var drake := put_synthetic(0, data)
	g.check_state_based_actions()
	g.destroy(island, false)
	g.check_state_based_actions()
	assert_true(_clause_pending(drake))
	assert_eq(ai.act(g), "pass", "nothing it can do outlasts it")
	resolve_stack()
	assert_eq(drake.zone, Mtg.Zone.GRAVEYARD)


func test_a_sacrifice_it_must_make_takes_the_doomed_permanent_first() -> void:
	for on in [true, false]:
		before_each()
		g.rules.set_preset(RulesOptions.DEFAULT_PRESET)
		g.rules.sacrifice_clauses_wait = true
		advance_to_step(Mtg.Step.MAIN1)
		var ai := _ai(on)
		var island := put_battlefield(0, "Island")
		var serpent := put_battlefield(0, "Sea Serpent")
		var bears := put_battlefield(0, "Grizzly Bears")
		g.check_state_based_actions()
		g.destroy(island, false)
		g.check_state_based_actions()
		assert_true(_clause_pending(serpent))
		var candidates: Array[CardInstance] = [bears, serpent]
		var pick := ai.answer_card(g, 0, candidates, "Sacrifice a creature")
		if on:
			assert_eq(pick, serpent, "the doomed Serpent is worth nothing to keep")
			assert_eq(ai._own_value(g, serpent), 0.0)
		else:
			assert_eq(pick, bears, "gate off: the old reading, the cheaper body")

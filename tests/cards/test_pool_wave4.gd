extends GameTest
## Wave-4 tests: the DecisionAgent choice system and the cards it unblocks.


## A scripted agent for tests: answers with pre-loaded choices.
class ScriptedAgent extends DecisionAgent:
	var discard_picks: Array = []
	var yes_no_answer := true
	var card_pick_name := ""

	# The EXTENSION POINTS are answer_*, never the choose_* funnel: the
	# funnel is what files each question on the game (§1.3), and overriding
	# it takes the question off the record — and breaks whenever the funnel
	# grows a parameter.
	func answer_discard(game: MtgGame, pid: int, count: int) -> Array[CardInstance]:
		if not discard_picks.is_empty():
			var out: Array[CardInstance] = []
			for inst in discard_picks:
				out.append(inst)
			return out
		return super(game, pid, count)

	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String, _hint: bool) -> bool:
		return yes_no_answer

	func answer_card(game: MtgGame, pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		for inst in candidates:
			if inst.data.card_name == card_pick_name:
				return inst
		return super(game, pid, candidates, prompt)


func test_cleanup_discard_uses_the_agent() -> void:
	var agent := ScriptedAgent.new()
	g.set_agent(0, agent)
	var keep_these: Array[CardInstance] = []
	for i in 9:
		keep_these.append(give_hand(0, "Forest"))
	var bolt := give_hand(0, "Lightning Bolt")   # 10 cards total
	agent.discard_picks = [keep_these[0], keep_these[1], bolt]
	advance_to_next_turn()   # through cleanup
	assert_eq(g.players[0].hand.size(), 7)
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD, "the agent's exact picks were discarded")


func test_demonic_tutor_fetches_the_agents_pick() -> void:
	var agent := ScriptedAgent.new()
	agent.card_pick_name = "Forest"   # library filler is all Forests
	g.set_agent(0, agent)
	var tutor := give_hand(0, "Demonic Tutor")
	var lib_before := g.players[0].library.size()
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, tutor, []))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 1, "found card in hand")
	assert_eq(g.players[0].hand[0].data.card_name, "Forest")
	assert_eq(g.players[0].library.size(), lib_before - 1)


func test_paralyze_locks_until_the_four_is_paid() -> void:
	var serra := put_battlefield(1, "Serra Angel")
	var paralyze := give_hand(0, "Paralyze")
	for i in 4:
		put_battlefield(1, "Swamp")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, paralyze, [TargetRef.card(serra)]))
	resolve_stack()
	assert_true(serra.tapped, "Paralyze taps on arrival")
	# P1's upkeep: their default agent follows the hint and pays the {4}.
	advance_to_next_turn()
	resolve_stack()
	assert_false(serra.tapped, "paid {4}: untapped")
	var tapped_lands := 0
	for inst in g.players[1].battlefield:
		if inst.data.is_land() and inst.tapped:
			tapped_lands += 1
	assert_eq(tapped_lands, 4, "four lands paid the ransom")


func test_paralyze_holds_when_the_player_declines() -> void:
	var agent := ScriptedAgent.new()
	agent.yes_no_answer = false
	g.set_agent(1, agent)
	var serra := put_battlefield(1, "Serra Angel")
	var paralyze := give_hand(0, "Paralyze")
	for i in 4:
		put_battlefield(1, "Swamp")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, paralyze, [TargetRef.card(serra)]))
	resolve_stack()
	advance_to_next_turn()
	resolve_stack()
	assert_true(serra.tapped, "declined: still locked (and doesn't untap)")


func test_scepter_lets_the_victim_choose() -> void:
	var agent := ScriptedAgent.new()
	g.set_agent(1, agent)
	var scepter := put_battlefield(0, "Disrupting Scepter")
	var keep := give_hand(1, "Shivan Dragon")
	var toss := give_hand(1, "Forest")
	agent.discard_picks = [toss]
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, scepter, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(toss.zone, Mtg.Zone.GRAVEYARD, "the victim's own choice went")
	assert_eq(keep.zone, Mtg.Zone.HAND, "the dragon stayed")


func test_mind_twist_rips_x_random_cards() -> void:
	for i in 5:
		give_hand(1, "Forest")
	var twist := give_hand(0, "Mind Twist")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, twist, [TargetRef.player(1)], 3))
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 2)
	assert_eq(g.players[1].graveyard.size(), 3)

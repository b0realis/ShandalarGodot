extends GameTest
## Fidelity lift of 2026-09-02: Takklemaggot's plague. The victim chooses
## among EVERY creature the Maggot could enchant — the Maggot controller's
## included — and may decline, in which case the Maggot returns as a
## NON-AURA enchantment that deals 1 damage to that player at the beginning
## of each of their upkeeps (MtgGame.return_aura_unattached +
## CardInstance.lost_enchant).


class Decliner extends DecisionAgent:
	func answer_card(_game: MtgGame, _pid: int, _candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		return null


class PickByName extends DecisionAgent:
	var wanted := ""

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		for inst in candidates:
			if inst.data.card_name == wanted:
				return inst
		return null if candidates.is_empty() else candidates[0]


func _infect(host: CardInstance) -> CardInstance:
	var maggot := give_hand(0, "Takklemaggot")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, maggot, [TargetRef.card(host)]))
	resolve_stack()
	assert_eq(maggot.attached_to, host.id)
	return maggot


func _kill(host: CardInstance) -> void:
	g.destroy(host, false)
	g.check_state_based_actions()
	resolve_stack()


func test_the_victim_may_send_the_plague_onto_the_maggot_controllers_creature() -> void:
	var host := put_battlefield(1, "Grizzly Bears")
	var runt := put_battlefield(1, "Mons's Goblin Raiders")
	var ours := put_battlefield(0, "Hill Giant")
	var maggot := _infect(host)
	_kill(host)
	assert_eq(maggot.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(maggot.attached_to, ours.id,
		"their heuristic sends it to OUR creature — the printed 'a creature this card could enchant' is any creature")
	assert_eq(runt.attachments.size(), 0)
	assert_eq(maggot.controller_id, 0, "still ours")


func test_the_victim_can_pick_any_legal_creature_by_hand() -> void:
	var agent := PickByName.new()
	agent.wanted = "Mons's Goblin Raiders"
	g.set_agent(1, agent)
	var host := put_battlefield(1, "Grizzly Bears")
	var runt := put_battlefield(1, "Mons's Goblin Raiders")
	put_battlefield(0, "Hill Giant")
	var maggot := _infect(host)
	_kill(host)
	assert_eq(maggot.attached_to, runt.id)


func test_declining_returns_the_maggot_as_a_non_aura_that_pings_the_victim() -> void:
	g.set_agent(1, Decliner.new())
	var host := put_battlefield(1, "Grizzly Bears")
	var spare := put_battlefield(1, "Hill Giant")
	var maggot := _infect(host)
	_kill(host)
	assert_eq(maggot.zone, Mtg.Zone.BATTLEFIELD, "it returns either way")
	assert_eq(maggot.attached_to, -1, "as a non-Aura enchantment")
	assert_true(maggot.lost_enchant)
	assert_false(maggot.is_aura())
	assert_false(maggot.cur_subtypes.has("aura"), "a non-Aura enchantment")
	assert_eq(maggot.controller_id, 0, "under YOUR control")
	assert_eq(spare.attachments.size(), 0)
	g.check_state_based_actions()
	assert_eq(maggot.zone, Mtg.Zone.BATTLEFIELD,
		"CR 704.5m does not sweep an enchantment that is no longer an Aura")
	var before := g.players[1].life
	advance_to_next_turn()   # P1's upkeep
	resolve_stack()
	assert_eq(g.players[1].life, before - 1, "1 damage at the beginning of THAT player's upkeep")
	assert_eq(spare.counters.get("-0/-1", 0), 0, "nothing is wasted any more")
	advance_to_next_turn()   # P0's upkeep: not that player
	resolve_stack()
	assert_eq(g.players[1].life, before - 1)
	assert_eq(g.players[0].life, 20)


func test_with_nothing_to_enchant_the_maggot_returns_as_a_non_aura() -> void:
	var host := put_battlefield(1, "Grizzly Bears")
	var maggot := _infect(host)
	_kill(host)
	assert_eq(maggot.zone, Mtg.Zone.BATTLEFIELD, "it used to stay in the graveyard")
	assert_eq(maggot.attached_to, -1)
	assert_true(maggot.lost_enchant)
	var before := g.players[1].life
	advance_to_next_turn()
	resolve_stack()
	assert_eq(g.players[1].life, before - 1)


func test_the_non_aura_maggot_forgets_when_it_leaves_the_battlefield() -> void:
	g.set_agent(1, Decliner.new())
	var host := put_battlefield(1, "Grizzly Bears")
	var maggot := _infect(host)
	_kill(host)
	assert_true(maggot.lost_enchant)
	g.return_to_hand(maggot)
	assert_false(maggot.lost_enchant, "CR 400.7: a new object in the hand")
	assert_true(maggot.data.is_aura(), "the printed card is still an Aura")
	assert_true(maggot.cur_subtypes.has("aura"))


func test_the_non_aura_maggot_is_not_an_aura_target_ban_source() -> void:
	# A non-Aura Maggot is no longer "an Aura" for anything that asks the
	# instance: the aura-orphan SBA, and CardInstance.is_aura().
	g.set_agent(1, Decliner.new())
	var host := put_battlefield(1, "Grizzly Bears")
	var maggot := _infect(host)
	_kill(host)
	for _i in 3:
		g.check_state_based_actions()
	assert_eq(maggot.zone, Mtg.Zone.BATTLEFIELD)

extends GameTest
## The fidelity ledger's "regenerates this way" row, lifted for every
## destruction a spell or ability causes: Matopi Golem, Debt of Loyalty
## (Pack 8) and Skeleton Scavengers (Pack 9).
##
## A regeneration shield now CARRIES its rider
## ([member CardInstance.regeneration_draws]) and the creature's controller
## chooses which shield a destruction uses (CR 616.1, [method
## MtgGame.destroy]): only the chosen shield's rider applies. The default
## answer is the old fixed order — a rider-free shield first for the
## Golem and the Debt, its own shield first for the Scavengers.

const C := Mtg.ManaColor.C


## Picks the first shield whose label contains [member want]; counts asks.
class ShieldSeat extends DecisionAgent:
	var want := ""
	var asked: Array = []
	func answer_option(game: MtgGame, pid: int, prompt: String,
			options: Array[String], hint: int) -> int:
		if prompt != "Which regeneration shield?":
			return super(game, pid, prompt, options, hint)
		asked.append(options.duplicate())
		for i in options.size():
			if options[i].contains(want):
				return i
		return hint


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardPacks.set_enabled("pack-9", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _seat(pid: int, want: String) -> ShieldSeat:
	var seat := ShieldSeat.new()
	seat.want = want
	g.agents[pid] = seat
	return seat


func _priority_to(pid: int) -> void:
	if g.priority_player != pid: assert_ok(g.pass_priority(g.priority_player))


func _cast(pid: int, card_name: String, targets: Array) -> void:
	_priority_to(pid)
	var card := give_hand(pid, card_name)
	for color in Mtg.WUBRG: add_mana(pid, color, 5)
	assert_ok(g.cast_spell(pid, card, targets))
	resolve_stack()
	g.players[pid].mana_pool.clear()


## A Golem with its own shield (the older) and a Death Ward's (the newer).
func _warded_golem() -> CardInstance:
	var golem := put_battlefield(0, "Matopi Golem")
	add_mana(0, C, 1)
	assert_ok(g.activate_ability(0, golem, 0, []))
	resolve_stack()
	_cast(0, "Death Ward", [TargetRef.card(golem)])
	assert_eq(golem.regeneration_shields, 2)
	return golem


func _minus(inst: CardInstance) -> int:
	return int(inst.counters.get("-1/-1", 0))


func _plus(inst: CardInstance) -> int:
	return int(inst.counters.get("+1/+1", 0))


# ------------------------------------------------------------ Matopi Golem --

func test_matopi_golem_controller_may_choose_its_own_shield() -> void:
	var golem := _warded_golem()
	var seat := _seat(0, "-1/-1")
	g.destroy(golem)
	resolve_stack()
	assert_eq(seat.asked.size(), 1, "the controller was asked which shield (CR 616.1)")
	assert_eq(seat.asked[0].size(), 2, "one option per shield")
	assert_eq(_minus(golem), 1, "it regenerated this way: the counter")
	assert_eq(golem.regeneration_shields, 1, "the Death Ward's shield is still up")
	g.destroy(golem)
	resolve_stack()
	assert_eq(golem.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(_minus(golem), 1, "the plain shield adds nothing")
	assert_eq(seat.asked.size(), 1, "a single shield is no choice")


func test_matopi_golem_default_spends_the_plain_shield_first() -> void:
	var golem := _warded_golem()
	g.destroy(golem)
	resolve_stack()
	assert_eq(_minus(golem), 0, "the default answer keeps the Golem whole")
	g.destroy(golem)
	resolve_stack()
	assert_eq(_minus(golem), 1, "its own shield was the one left")


func test_matopi_golem_rider_rides_its_own_shield_whatever_the_order() -> void:
	# The plain shield FIRST, the Golem's own after it.
	var golem := put_battlefield(0, "Matopi Golem")
	_cast(0, "Death Ward", [TargetRef.card(golem)])
	add_mana(0, C, 1)
	assert_ok(g.activate_ability(0, golem, 0, []))
	resolve_stack()
	var seat := _seat(0, "nothing more")
	g.destroy(golem)
	resolve_stack()
	assert_eq(_minus(golem), 0, "the plain shield was chosen")
	assert_eq(golem.regeneration_draws.size(), 1, "the rider stays with the shield left")
	g.destroy(golem)
	resolve_stack()
	assert_eq(_minus(golem), 1)
	assert_eq(seat.asked.size(), 1)


func test_two_matopi_shields_are_no_choice() -> void:
	var golem := put_battlefield(0, "Matopi Golem")
	add_mana(0, C, 2)
	assert_ok(g.activate_ability(0, golem, 0, []))
	assert_ok(g.activate_ability(0, golem, 0, []))
	resolve_stack()
	var seat := _seat(0, "-1/-1")
	g.destroy(golem)
	resolve_stack()
	assert_eq(seat.asked.size(), 0, "both shields are the same: nobody is asked")
	assert_eq(_minus(golem), 1)
	g.destroy(golem)
	resolve_stack()
	assert_eq(_minus(golem), 2)


func test_a_human_seat_is_asked_when_a_spell_destroys_the_golem() -> void:
	var golem := _warded_golem()
	var human := HumanAgent.new()
	g.agents[0] = human
	g.interactive_choices = true
	_priority_to(1)
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(golem)]))
	assert_ok(g.pass_priority(g.priority_player))
	if g.awaiting_choice == null and not g.stack.is_empty():
		assert_ok(g.pass_priority(g.priority_player))
	assert_not_null(g.awaiting_choice, "the Bolt's resolution is held on the shield choice")
	if g.awaiting_choice == null: return
	var question: PlayerChoice = g.awaiting_choice
	assert_eq(question.pid, 0)
	assert_eq(question.prompt, "Which regeneration shield?")
	assert_eq(question.options.size(), 2)
	assert_eq(golem.damage, 0, "nothing has happened yet")
	var own := 0 if String(question.options[0]).contains("-1/-1") else 1
	assert_ok(g.answer_choice(own))
	resolve_stack()
	assert_eq(golem.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(_minus(golem), 1, "the player's own answer: the Golem's shield")
	assert_eq(golem.regeneration_shields, 1)


func test_riders_leave_with_the_shields_at_cleanup() -> void:
	var golem := _warded_golem()
	advance_to_next_turn()
	assert_eq(golem.regeneration_shields, 0)
	assert_true(golem.regeneration_draws.is_empty(), "no rider outlives its shield")
	g.destroy(golem)
	assert_eq(golem.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.stack.is_empty())


# --------------------------------------------------------- Debt of Loyalty --

func _indebted_boa() -> CardInstance:
	var boa := put_battlefield(1, "River Boa")
	_cast(0, "Debt of Loyalty", [TargetRef.card(boa)])
	_priority_to(1)
	add_mana(1, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(1, boa, 0, []))
	resolve_stack()
	assert_eq(boa.regeneration_shields, 2)
	return boa


func test_debt_of_loyalty_controller_may_choose_the_debt_shield() -> void:
	var boa := _indebted_boa()
	var seat := _seat(1, "gains control")
	g.destroy(boa)
	assert_eq(seat.asked.size(), 1)
	assert_eq(boa.controller_id, 0, "it regenerated this way: the Debt's caster takes it")
	assert_eq(boa.regeneration_shields, 1, "the Boa's own shield is still up")
	g.destroy(boa)
	assert_eq(boa.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(boa.controller_id, 0)


func test_debt_of_loyalty_default_spends_the_own_shield_first() -> void:
	var boa := _indebted_boa()
	g.destroy(boa)
	assert_eq(boa.controller_id, 1, "the default keeps the creature")
	g.destroy(boa)
	assert_eq(boa.controller_id, 0, "the Debt shield was the last one")


# ----------------------------------------------------- Skeleton Scavengers --

func _warded_skeleton() -> CardInstance:
	var skeleton := put_battlefield(0, "Skeleton Scavengers")
	add_mana(0, C, 1)
	assert_ok(g.activate_ability(0, skeleton, 0, [], 1))
	resolve_stack()
	_cast(0, "Death Ward", [TargetRef.card(skeleton)])
	assert_eq(skeleton.regeneration_shields, 2)
	return skeleton


func test_skeleton_scavengers_controller_may_keep_its_own_shield_for_later() -> void:
	var skeleton := _warded_skeleton()
	var seat := _seat(0, "nothing more")
	g.destroy(skeleton)
	resolve_stack()
	assert_eq(seat.asked.size(), 1)
	assert_eq(_plus(skeleton), 1, "the plain shield: no counter, the next one stays cheap")
	g.destroy(skeleton)
	resolve_stack()
	assert_eq(_plus(skeleton), 2, "its own shield, used second")


func test_skeleton_scavengers_default_takes_the_counter_first() -> void:
	var skeleton := _warded_skeleton()
	g.destroy(skeleton)
	resolve_stack()
	assert_eq(_plus(skeleton), 2, "the default answer is its own shield")
	g.destroy(skeleton)
	resolve_stack()
	assert_eq(_plus(skeleton), 2)


# ------------------------------------------------------------- the journal --

func test_the_search_journal_puts_shield_and_rider_back() -> void:
	var golem := _warded_golem()
	var mark := g.make_mark()
	g.destroy(golem)
	assert_eq(golem.regeneration_shields, 1)
	g.unmake_to(mark)
	g.end_search()
	assert_eq(golem.regeneration_shields, 2)
	assert_eq(golem.regeneration_draws.size(), 1, "the rider is back on its shield")
	assert_true(golem.regeneration_draws.has(0), "the older shield, the Golem's own")


# ------------------------------------------- the row that is left (ledger) --

## docs/simplified-cards.md, the row these three cards keep: lethal COMBAT
## damage is no stack resolution, so a human seat is not held on the
## question and the default answer (the rider-free shield) is taken.
## Lifting that row means changing this test.
func test_combat_damage_takes_the_default_for_a_human_seat() -> void:
	var golem := _warded_golem()
	var wurm := put_battlefield(1, "Craw Wurm")
	g.agents[0] = HumanAgent.new()
	g.interactive_choices = true
	advance_to_next_turn()
	# Shields last one turn: put the same two up again in P1's turn.
	_priority_to(0)
	add_mana(0, C, 1)
	assert_ok(g.activate_ability(0, golem, 0, []))
	resolve_stack()
	g.players[0].mana_pool.clear()
	_cast(0, "Death Ward", [TargetRef.card(golem)])
	assert_eq(golem.regeneration_shields, 2)
	run_combat([wurm.id], {golem.id: wurm.id})
	assert_null(g.awaiting_choice, "combat damage does not hold the question")
	assert_eq(golem.zone, Mtg.Zone.BATTLEFIELD, "regenerated")
	assert_eq(golem.regeneration_shields, 1)
	assert_eq(_minus(golem), 0, "the default: the plain shield first")

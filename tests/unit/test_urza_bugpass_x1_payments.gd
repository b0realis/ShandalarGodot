extends GameTest
## Bug pass 0.60.19 (x1) — ENGINE-PAID COSTS AND THE MANA ABILITIES THAT ASK.
##
## [method MtgGame.try_pay] pays echo, an "unless pays", cumulative upkeep,
## an attack or block tax on a seat's behalf through the shared planner. A
## tap it makes may ASK (Pack 10 E8: Fertile Ground's colour, Mana Flare's
## type on a two-type land, Metalworker's count): for a human seat that ask
## used to be held as a COST question — which re-issues the mana ability
## alone — so the trigger it was paying for was lost (the echo creature
## sacrificed, the life lost, the attack refused) and the mana floated to
## burn. The plan that priced the tap now answers it: nothing held, nothing
## asked twice, nothing left floating (h1-1 / h4-1). A computer seat is
## asked as before; a player tapping by hand is held as before.
##
## Also: a tap that makes no mana fires no "tapped for mana" trigger and asks
## none of their questions (CR 106.12a), and Contamination has no mana to
## replace on it (CR 106.12b — h4-2); a plan reveals only the artifact
## cards its bill needs (h4-3); a held tap replays with the colour its plan
## chose (h4-4).


func before_each() -> void:
	CardPacks.set_enabled_many(["pack-9", "pack-10"] as Array[String], true)
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled_many(["pack-9", "pack-10"] as Array[String], false)


# ----------------------------------------------------------------- helpers --

func _human(pid := 0) -> HumanAgent:
	var human := HumanAgent.new()
	g.agents[pid] = human
	g.interactive_choices = true
	return human


static func _echo_beast(cost: String) -> CardData:
	var c := CardData.new("Test Echo Beast", cost, Mtg.CardType.CREATURE)
	c.pt(3, 3)
	return EchoAbility.attach(c, cost)


static func _aging_wall() -> CardData:
	var c := CardData.new("Test Aging Wall", "{1}", Mtg.CardType.ARTIFACT)
	CumulativeUpkeep.attach(c, "{2}")
	return c.oracle("Cumulative upkeep {2}")


static func _two_type_land() -> CardData:
	return CardData.new("Test Confluence", "", Mtg.CardType.LAND) \
		.mana(ManaAbility.new(Mtg.ManaColor.W).and_also(Mtg.ManaColor.U)) \
		.oracle("{T}: Add {W}{U}.")


static func _offers_blue_or_red(_g: MtgGame, _s: CardInstance) -> Array:
	return [Mtg.ManaColor.U, Mtg.ManaColor.R]


## A land whose colour is chosen as it is tapped (Reflecting Pool's shape).
static func _choice_land() -> CardData:
	return CardData.new("Test Pool", "", Mtg.CardType.LAND) \
		.mana(ManaAbility.new(Mtg.ManaColor.C).with_color_choice(_offers_blue_or_red)) \
		.oracle("{T}: Add {U} or {R}.")


func _fertile_on(land: CardInstance, pid := 0) -> CardInstance:
	var aura := give_hand(pid, "Fertile Ground")
	g.attach_aura_from_anywhere(aura, land, pid)
	g.recalculate()
	assert_eq(aura.attached_to, land.id)
	return aura


func _to_upkeep_of_turn(turn: int) -> void:
	var guard := 0
	while not (g.turn_number == turn and g.current_step() == Mtg.Step.UPKEEP) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)


## Play on like a player: yes to every yes/no, the hint to anything else,
## pass otherwise, until the stack is empty and nothing is asked. Returns
## the prompts asked.
func _drive(limit := 30) -> Array[String]:
	var asked: Array[String] = []
	for n in limit:
		if g.awaiting_choice != null:
			var q := g.awaiting_choice
			asked.append(q.prompt)
			var answer: Variant = true
			if q.kind == PlayerChoice.Kind.COLOR: answer = int(q.hint) if int(q.hint) > 0 else Mtg.ManaColor.G
			elif q.kind == PlayerChoice.Kind.OPTION: answer = int(q.hint)
			elif q.kind == PlayerChoice.Kind.CARD: answer = (q.candidates[0] as CardInstance).id
			assert_ok(g.answer_choice(answer))
			continue
		if g.stack.is_empty():
			break
		assert_ok(g.pass_priority(g.priority_player))
	return asked


# --------------------------------------------- h1-1 / h4-1: engine-paid costs --

func test_a_human_pays_echo_through_fertile_ground() -> void:
	_human(0)
	var forest := put_battlefield(0, "Forest")
	_fertile_on(forest)
	var beast := put_synthetic(0, _echo_beast("{1}{G}"))
	_to_upkeep_of_turn(3)
	var asked := _drive()
	assert_eq(asked.size(), 1, "only the echo question: %s" % str(asked))
	assert_string_contains(asked[0] if not asked.is_empty() else "", "Pay echo")
	assert_eq(beast.zone, Mtg.Zone.BATTLEFIELD, "the player said yes and the Forest pays {1}{G}")
	assert_true(forest.tapped)
	assert_eq(g.players[0].mana_pool.total(), 0, "nothing left floating")
	assert_null(g.awaiting_choice)
	assert_true(g.stack.is_empty())


func test_a_human_pays_echo_through_metalworker_revealing_only_what_it_needs() -> void:
	_human(0)
	var worker := put_battlefield(0, "Metalworker")
	give_hand(0, "Sol Ring")
	give_hand(0, "Ornithopter")
	var beast := put_synthetic(0, _echo_beast("{2}"))
	var shown: Array = []
	g.information_revealed.connect(func(_viewer: int, _title: String, names: Array) -> void:
		shown.append(names.duplicate()))
	_to_upkeep_of_turn(3)
	var asked := _drive()
	assert_eq(asked.size(), 1, "only the echo question: %s" % str(asked))
	assert_eq(beast.zone, Mtg.Zone.BATTLEFIELD, "one revealed artifact pays echo {2}")
	assert_true(worker.tapped)
	assert_eq(g.players[0].mana_pool.total(), 0, "one card revealed, not two")
	assert_eq(shown.size(), 1)
	assert_eq((shown[0] as Array).size() if not shown.is_empty() else -1, 1)


func test_a_human_pays_power_taint_through_fertile_ground() -> void:
	_human(0)
	var forest := put_battlefield(0, "Forest")
	_fertile_on(forest)
	var crusade := put_battlefield(0, "Crusade")
	var taint := give_hand(1, "Power Taint")
	g.attach_aura_from_anywhere(taint, crusade, 1)
	g.recalculate()
	_to_upkeep_of_turn(3)
	var life := g.players[0].life
	var asked := _drive()
	assert_eq(asked.size(), 1, "only Power Taint's question: %s" % str(asked))
	assert_eq(g.players[0].life, life, "paid {2}, so no life lost")
	assert_true(forest.tapped)
	assert_eq(g.players[0].mana_pool.total(), 0)
	assert_null(g.awaiting_choice)


func test_a_human_pays_cumulative_upkeep_through_fertile_ground() -> void:
	_human(0)
	var forest := put_battlefield(0, "Forest")
	_fertile_on(forest)
	var wall := put_synthetic(0, _aging_wall())
	_to_upkeep_of_turn(3)
	var asked := _drive()
	assert_eq(asked.size(), 1, "only the upkeep question: %s" % str(asked))
	assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD, "{2} paid by the Forest and its Aura")
	assert_true(forest.tapped)
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_a_human_pays_the_propaganda_tax_through_fertile_ground() -> void:
	_human(0)
	var forest := put_battlefield(0, "Forest")
	_fertile_on(forest)
	var bears := put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Propaganda")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bears.id]))
	assert_true(g.combat.attackers.has(bears.id), "the tax paid by Forest + Fertile Ground")
	assert_null(g.awaiting_choice, "no stray question left behind")
	assert_true(forest.tapped)
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_a_human_pays_iron_star_through_a_two_type_land_under_mana_flare() -> void:
	# An OLD card's "you may pay {1}" (Iron Star) — the two-type land's
	# Mana Flare question moved into the tap with Pack 10 E8.
	_human(0)
	put_battlefield(0, "Iron Star")
	put_battlefield(1, "Mana Flare")
	var land := put_synthetic(0, _two_type_land())
	var bolt := give_hand(1, "Lightning Bolt")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(1)]))
	var life := g.players[0].life
	var asked := _drive()
	assert_eq(asked.size(), 1, "only Iron Star's question: %s" % str(asked))
	assert_eq(g.players[0].life, life + 1, "paid {1} with the land and gained 1 life")
	assert_true(land.tapped)
	assert_eq(g.players[0].mana_pool.total(), 2, "the land and the Flare made three; one paid")
	assert_null(g.awaiting_choice)


func test_a_computer_seat_still_answers_its_own_tap_question() -> void:
	var forest := put_battlefield(0, "Forest")
	_fertile_on(forest)
	var beast := put_synthetic(0, _echo_beast("{1}{G}"))
	_to_upkeep_of_turn(3)
	var asked_before := g.choice_log.size()
	resolve_stack()
	assert_eq(beast.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].mana_pool.total(), 0)
	var colour_asked := false
	for i in range(asked_before, g.choice_log.size()):
		var q: PlayerChoice = g.choice_log[i]
		if q.kind == PlayerChoice.Kind.COLOR and q.pid == 0:
			colour_asked = true
	assert_true(colour_asked, "the computer seat is asked its colour, as before")


func test_a_cost_question_inside_a_resolution_is_never_held() -> void:
	# Drain Power taps the HUMAN's lands from inside its own resolution: the
	# Fertile Ground question can be neither held (the hold re-issues the tap
	# alone) nor pre-flown (its answer belongs to no stack item).
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	_human(0)
	var forest := put_battlefield(0, "Forest")
	_fertile_on(forest)
	var other := put_battlefield(0, "Forest")
	var drain := give_hand(1, "Drain Power")
	add_mana(1, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(1, drain, [TargetRef.player(0)]))
	var asked := _drive()
	assert_eq(asked.size(), 0, "nothing held: %s" % str(asked))
	assert_true(forest.tapped and other.tapped, "every land tapped")
	assert_eq(g.players[1].mana_pool.total(), 3, "the Forests' {G}{G} and the Aura's mana")
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_a_trigger_an_engine_payment_fires_is_put_when_priority_comes() -> void:
	# The computer pays its echo with a Sol Ring the human's Relic Bind
	# enchants: the Bind's mode and target are the human's to name — the
	# next time a player would receive priority (CR 603.3), not in the
	# middle of the payment, where a hold re-issued only the tap.
	_human(0)
	var ring := put_battlefield(1, "Sol Ring")
	var bind := give_hand(0, "Relic Bind")
	g.attach_aura_from_anywhere(bind, ring, 0)
	g.recalculate()
	var beast := put_synthetic(1, _echo_beast("{2}"))
	_to_upkeep_of_turn(2)
	var foe_life := g.players[1].life
	var asked := _drive()
	assert_eq(beast.zone, Mtg.Zone.BATTLEFIELD, "the echo was paid with the Ring")
	assert_true(ring.tapped)
	assert_false(asked.is_empty(), "the Bind's controller was asked")
	assert_true(g.stack.is_empty())
	assert_null(g.awaiting_choice)
	assert_eq(g.players[1].life, foe_life - 1, "the Bind's default: 1 damage to the opponent")


# --------------------------------------------- h4-2: a tap that makes nothing --

func test_an_empty_cradle_under_mana_flare_makes_nothing() -> void:
	put_battlefield(1, "Mana Flare")
	var cradle := put_battlefield(0, "Gaea's Cradle")
	var fired: Array = []
	g.event_occurred.connect(func(e: GameEvent) -> void:
		if e.type == Mtg.EventType.TAPPED_FOR_MANA: fired.append(e))
	assert_ok(g.tap_for_mana(0, cradle))
	assert_true(cradle.tapped)
	assert_eq(g.players[0].mana_pool.total(), 0, "CR 106.12a: no mana made, no trigger")
	assert_eq(fired.size(), 0)
	assert_true(g.players[0].tapped_land_for_mana_this_turn, "it was still tapped for mana (CR 106.12)")


func test_an_empty_academy_with_fertile_ground_asks_nothing_and_makes_nothing() -> void:
	_human(0)
	var academy := put_battlefield(0, "Tolarian Academy")
	_fertile_on(academy)
	assert_ok(g.tap_for_mana(0, academy))
	assert_null(g.awaiting_choice, "no colour to ask for a trigger that cannot fire")
	assert_true(academy.tapped)
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_an_empty_sanctum_under_manabarbs_deals_no_damage() -> void:
	put_battlefield(1, "Manabarbs")
	var sanctum := put_battlefield(0, "Serra's Sanctum")
	var life := g.players[0].life
	assert_ok(g.tap_for_mana(0, sanctum))
	resolve_stack()
	assert_eq(g.players[0].life, life)


func test_contamination_on_an_empty_cradle_makes_nothing() -> void:
	put_battlefield(0, "Contamination")
	var cradle := put_battlefield(0, "Gaea's Cradle")
	g.recalculate()
	for row in ManaPlanner.sources(g, 0):
		assert_ne(row[0], cradle, "no mana to plan")
	assert_ok(g.tap_for_mana(0, cradle))
	assert_eq(g.players[0].mana_pool.total(), 0, "CR 106.12b: no mana production event to replace")


func test_contamination_on_a_cradle_with_creatures_makes_one_black() -> void:
	put_battlefield(0, "Contamination")
	var cradle := put_battlefield(0, "Gaea's Cradle")
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Grizzly Bears")
	g.recalculate()
	assert_ok(g.tap_for_mana(0, cradle))
	assert_eq(g.players[0].mana_pool.total_of(Mtg.ManaColor.B), 1)
	assert_eq(g.players[0].mana_pool.total(), 1)


# ------------------------------------------------- h4-3: reveal what is owed --

func test_a_plan_reveals_only_the_cards_its_bill_needs() -> void:
	var worker := put_battlefield(0, "Metalworker")
	give_hand(0, "Sol Ring")
	give_hand(0, "Ornithopter")
	give_hand(0, "Rocket Launcher")
	var bill := ManaCost.parse("{2}")
	var plan := ManaPlanner.plan(g, 0, bill, 0)
	assert_eq(plan.size(), 1)
	assert_true(ManaPlanner.run_plan(g, 0, plan, bill))
	assert_true(worker.tapped)
	assert_eq(g.players[0].mana_pool.total(), 2, "one card revealed for {2}, not three")


func test_an_engine_payment_reveals_only_the_cards_its_bill_needs() -> void:
	put_battlefield(0, "Metalworker")
	give_hand(0, "Sol Ring")
	give_hand(0, "Ornithopter")
	give_hand(0, "Rocket Launcher")
	assert_true(g.try_pay(0, ManaCost.parse("{3}")))
	assert_eq(g.players[0].mana_pool.total(), 1, "two cards for {3}; four made, one left")


func test_a_human_auto_tap_offers_the_planned_count_first() -> void:
	_human(0)
	put_battlefield(0, "Metalworker")
	give_hand(0, "Sol Ring")
	give_hand(0, "Ornithopter")
	give_hand(0, "Rocket Launcher")
	var bill := ManaCost.parse("{4}")
	var plan := ManaPlanner.plan(g, 0, bill, 0)
	assert_false(ManaPlanner.run_plan(g, 0, plan, bill), "held on the count")
	var asked := g.awaiting_choice
	assert_not_null(asked)
	if asked == null: return
	assert_eq(asked.options.size(), 4, "still any number, 0 to 3")
	assert_eq(int(asked.hint), 2, "the default is what the bill needs")


func test_a_hand_tap_still_offers_every_card() -> void:
	_human(0)
	var worker := put_battlefield(0, "Metalworker")
	give_hand(0, "Sol Ring")
	give_hand(0, "Ornithopter")
	assert_ok(g.tap_for_mana(0, worker))
	assert_not_null(g.awaiting_choice)
	if g.awaiting_choice == null: return
	assert_eq(int(g.awaiting_choice.hint), 2)


# ---------------------------------------- h4-4: a replay keeps the plan's colour --

func test_a_held_tap_replays_with_the_colour_its_plan_chose() -> void:
	_human(0)
	var pool_land := put_synthetic(0, _choice_land())
	_fertile_on(pool_land)
	assert_ok(g.tap_for_mana(0, pool_land, 0, Mtg.ManaColor.R))
	var asked := g.awaiting_choice
	assert_not_null(asked, "held on Fertile Ground's colour")
	if asked == null: return
	assert_eq(asked.source, "Fertile Ground")
	assert_ok(g.answer_choice(Mtg.ManaColor.G))
	assert_null(g.awaiting_choice, "the replay did not ask the land's colour again")
	assert_true(pool_land.tapped)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.R), 1, "the colour the plan chose")
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.G), 1, "and the player's own")


# ------------------------------- the fifth-rules self-burn (routed from h5) --
# The audit's burns (Snap paid with a Tolarian Academy, a second Grim
# Monolith paid with the first's {C}{C}{C}, a Voltaic Key paid with a Grim
# Monolith) were traced tap by tap: each time the lump source was the only
# cover of the bill. When an exact payment exists the planner takes it —
# pinned here so it stays so.

func _pays_exactly(cost_text: String) -> void:
	var cost := ManaCost.parse(cost_text)
	assert_true(ManaPlanner.plan_and_pay(g, 0, cost), "payable: %s" % cost_text)
	assert_eq(g.players[0].mana_pool.total(), cost.mana_value(), "exact for %s" % cost_text)


func test_an_academy_pays_snap_alone_rather_than_beside_an_island() -> void:
	put_battlefield(0, "Tolarian Academy")
	put_battlefield(0, "Ornithopter")
	put_battlefield(0, "Ornithopter")
	put_battlefield(0, "Island")
	_pays_exactly("{1}{U}")


func test_islands_pay_before_a_monolith_that_would_float_one() -> void:
	put_battlefield(0, "Grim Monolith")
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	_pays_exactly("{2}")


func test_an_exact_three_is_found_among_a_dynamo_a_ring_and_an_island() -> void:
	put_battlefield(0, "Thran Dynamo")
	put_battlefield(0, "Sol Ring")
	put_battlefield(0, "Island")
	_pays_exactly("{3}")


func test_an_academy_pays_two_blue_pips_and_one_alone() -> void:
	put_battlefield(0, "Tolarian Academy")
	for n in 3:
		put_battlefield(0, "Ornithopter")
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	_pays_exactly("{1}{U}{U}")

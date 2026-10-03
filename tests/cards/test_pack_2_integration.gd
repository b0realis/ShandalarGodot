extends GameTest
## Second-pass regressions: real costs, response windows and object identity.

func before_each() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	super()

func after_each() -> void:
	g = null
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	CardPacks.set_enabled(CardPacks.ID, false)

func blink(inst: CardInstance) -> void:
	var pid := inst.controller_id
	g.return_to_hand(inst)
	g._put_on_battlefield(inst, pid)
	inst.summoning_sick = false

func test_seasinger_does_not_restart_after_untap_and_retap_before_resolution() -> void:
	put_battlefield(0, "Island")
	put_battlefield(1, "Island")
	var singer := put_battlefield(0, "Seasinger")
	var victim := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, singer, 0, [TargetRef.card(victim)]))
	g.untap_permanent(singer)
	g.tap_permanent(singer)
	resolve_stack()
	assert_eq(victim.controller_id, 1)

func test_champion_does_not_restart_after_control_changes_twice() -> void:
	var champion := put_battlefield(0, "Thrull Champion")
	var victim := put_battlefield(1, "Basal Thrull")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, champion, 0, [TargetRef.card(victim)]))
	g.change_control(champion, 1)
	g.change_control(champion, 0)
	resolve_stack()
	assert_eq(victim.controller_id, 1)

func test_spirit_shield_does_not_restart_after_untap_and_retap() -> void:
	var shield := put_battlefield(0, "Spirit Shield")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, shield, 0, [TargetRef.card(bear)]))
	g.untap_permanent(shield)
	g.tap_permanent(shield)
	resolve_stack()
	assert_eq(bear.cur_toughness, 2)

func test_continuity_counters_are_rewound_by_search() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	g.tap_permanent(bear)
	var untaps := bear.untap_sequence
	var controls := bear.control_sequence
	var mark := g.make_mark()
	g.untap_permanent(bear)
	g.change_control(bear, 1)
	assert_gt(bear.untap_sequence, untaps)
	assert_gt(bear.control_sequence, controls)
	g.unmake_to(mark)
	g.end_search()
	assert_eq(bear.untap_sequence, untaps)
	assert_eq(bear.control_sequence, controls)
	assert_true(bear.tapped)
	assert_eq(bear.controller_id, 0)

func test_old_spore_trigger_does_not_add_to_reentered_thallid() -> void:
	var thallid := put_battlefield(0, "Thallid")
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_next_turn()
	advance_to_step(Mtg.Step.UPKEEP)
	assert_false(g.stack.is_empty())
	blink(thallid)
	resolve_stack()
	assert_eq(int(thallid.counters.get("spore", 0)), 0)

func test_moneychanger_enter_damage_keeps_original_trigger_controller() -> void:
	var money := put_battlefield(0, "Icatian Moneychanger")
	g.change_control(money, 1)
	resolve_stack()
	assert_eq(g.players[0].life, 17)
	assert_eq(g.players[1].life, 20)

func test_breeding_pit_end_trigger_keeps_original_controller() -> void:
	var pit := put_battlefield(0, "Breeding Pit")
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_step(Mtg.Step.END)
	assert_false(g.stack.is_empty())
	g.change_control(pit, 1)
	resolve_stack()
	assert_eq(g.players[0].battlefield.size(), 1)
	assert_eq(g.players[0].battlefield[0].data.card_name, "Thrull")

func test_self_shroud_does_not_affect_reentered_deep_spawn() -> void:
	var spawn := put_battlefield(0, "Deep Spawn")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.activate_ability(0, spawn, 0))
	blink(spawn)
	resolve_stack()
	assert_false(spawn.cur_shroud)
	assert_false(spawn.tapped)

func test_thrull_retainer_cannot_regenerate_a_reentered_host() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := give_hand(0, "Thrull Retainer")
	g.attach_aura_from_anywhere(aura, bear, 0)
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, aura, 0))
	blink(bear)
	resolve_stack()
	g.destroy(bear)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)

func test_rainbow_vale_transfer_uses_stack_and_does_not_follow_a_blink() -> void:
	var vale := put_battlefield(0, "Rainbow Vale")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.tap_for_mana(0, vale))
	advance_to_step(Mtg.Step.END)
	assert_eq(vale.controller_id, 0)
	assert_eq(g.stack.size(), 1)
	blink(vale)
	resolve_stack()
	assert_eq(vale.controller_id, 0)

func test_fourth_conversion_sacrifice_is_responseable() -> void:
	var priest := put_battlefield(0, "Farrelite Priest")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 4)
	for _i in 4: assert_ok(g.tap_for_mana(0, priest))
	advance_to_step(Mtg.Step.END)
	assert_eq(priest.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(priest.zone, Mtg.Zone.GRAVEYARD)

func test_fourth_conversion_cannot_sacrifice_an_opponents_permanent() -> void:
	var priest := put_battlefield(0, "Farrelite Priest")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 4)
	for _i in 4: assert_ok(g.tap_for_mana(0, priest))
	g.change_control(priest, 1)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(priest.zone, Mtg.Zone.BATTLEFIELD)

func test_kites_flip_uses_stack_even_when_target_has_left() -> void:
	var kites := put_battlefield(0, "Goblin Kites")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, kites, 0, [TargetRef.card(bear)]))
	resolve_stack()
	g.return_to_hand(bear)
	advance_to_step(Mtg.Step.END)
	assert_eq(g.stack.size(), 1)
	var before := g.rng.state
	resolve_stack()
	assert_ne(g.rng.state, before, "the promised coin flip still happens")
	assert_eq(bear.zone, Mtg.Zone.HAND)

func prepare_cube_attack() -> Array:
	var cube := put_battlefield(0, "Delif's Cube")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, cube, 0, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	return [cube, bear]

func test_cube_gains_counter_even_when_unblocked_attacker_leaves() -> void:
	var pair := prepare_cube_attack()
	g.return_to_hand(pair[1])
	resolve_stack()
	assert_eq(int(pair[0].counters.get("cube", 0)), 1)

func test_cube_delayed_trigger_does_not_follow_reentered_attacker() -> void:
	var pair := prepare_cube_attack()
	blink(pair[1])
	resolve_stack()
	assert_eq(int(pair[0].counters.get("cube", 0)), 1)
	assert_false(pair[1].cur_assigns_no_combat_damage)

func test_old_flotilla_fee_does_not_watch_reentered_flotilla() -> void:
	var flotilla := put_battlefield(0, "Goblin Flotilla")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	assert_false(g.stack.is_empty())
	blink(flotilla)
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [flotilla.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bear.id: [flotilla.id]}))
	resolve_stack()
	assert_false(bear.has_keyword(Mtg.Keyword.FIRST_STRIKE))

func test_priest_and_initiates_plan_executable_colour_conversion_while_sick() -> void:
	for name in ["Farrelite Priest", "Initiates of the Ebon Hand"]:
		var converter := put_battlefield(0, name, true)
		g.tap_permanent(converter)
		var color := Mtg.ManaColor.W if name == "Farrelite Priest" else Mtg.ManaColor.B
		var cost := ManaCost.parse("{W}{W}" if color == Mtg.ManaColor.W else "{B}{B}")
		g.players[0].mana_pool.clear()
		add_mana(0, Mtg.ManaColor.R, 2)
		var random_state := g.rng.state
		var plan := ManaPlanner.plan(g, 0, cost, 0)
		assert_eq(g.rng.state, random_state)
		assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.R), 2)
		assert_eq(plan.size(), 2)
		for step in plan: assert_ok(g.tap_for_mana(0, step[0], step[1]))
		assert_true(g.players[0].mana_pool.can_pay(cost))
		g.return_to_hand(converter)

func test_converter_plan_orders_fuel_before_conversion_and_keeps_spare_sol_ring_mana() -> void:
	var ring := put_battlefield(0, "Sol Ring")
	var initiate := put_battlefield(0, "Initiates of the Ebon Hand")
	var cost := ManaCost.parse("{1}{B}")
	var plan := ManaPlanner.plan(g, 0, cost, 0)
	assert_eq(plan.size(), 2)
	assert_eq(plan[0][0], ring)
	assert_eq(plan[1][0], initiate)
	for step in plan: assert_ok(g.tap_for_mana(0, step[0], step[1]))
	assert_true(g.players[0].mana_pool.can_pay(cost))

func test_implements_pays_first_and_chooses_black_for_hymn() -> void:
	var forest := put_battlefield(0, "Forest")
	var implements := put_battlefield(0, "Implements of Sacrifice")
	var cost := ManaCost.parse("{B}{B}")
	var plan := ManaPlanner.plan(g, 0, cost, 0)
	assert_eq(plan.size(), 2)
	assert_eq(plan[0][0], forest)
	for step in plan: assert_ok(g.tap_for_mana(0, step[0], step[1]))
	assert_true(g.players[0].mana_pool.can_pay(cost))
	assert_eq(implements.zone, Mtg.Zone.GRAVEYARD)

func test_no_free_conversion_or_restricted_workshop_fuel() -> void:
	put_battlefield(0, "Initiates of the Ebon Hand")
	var cost := ManaCost.parse("{B}")
	assert_true(ManaPlanner.plan(g, 0, cost, 0).is_empty())
	var workshop := put_battlefield(0, "Mishra's Workshop")
	assert_true(ManaPlanner.plan(g, 0, cost, 0).is_empty())
	assert_ok(g.tap_for_mana(0, workshop))
	assert_true(ManaPlanner.plan(g, 0, cost, 0).is_empty())
	assert_true(ManaPlanner.plan(g, 0, cost, 0, ["artifact"]).is_empty(), "artifact-only mana cannot pay an intervening ability cost")

func test_converter_autotap_exclusion_is_honoured() -> void:
	var initiate := put_battlefield(0, "Initiates of the Ebon Hand")
	put_battlefield(0, "Forest")
	assert_true(ManaPlanner.plan(g, 0, ManaCost.parse("{B}"), 0, [], {initiate.id: true}).is_empty())

func test_rainbow_vale_plans_each_colour_without_a_guessing_callback() -> void:
	var vale := put_battlefield(0, "Rainbow Vale")
	for symbol in ["W", "U", "B", "R", "G"]:
		var cost := ManaCost.parse("{" + symbol + "}")
		var plan := ManaPlanner.plan(g, 0, cost, 0)
		assert_eq(plan.size(), 1)
		assert_ok(g.tap_for_mana(0, vale, plan[0][1]))
		assert_true(g.players[0].mana_pool.can_pay(cost))
		g.players[0].mana_pool.clear()
		g.untap_permanent(vale)

func test_old_self_pump_and_regeneration_cannot_affect_new_incarnation() -> void:
	var order := put_battlefield(0, "Order of the Ebon Hand")
	var fungus := put_battlefield(0, "Feral Thallid")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.activate_ability(0, order, 1))
	blink(order)
	resolve_stack()
	assert_eq(order.cur_power, 2)
	g.add_counters(fungus, "spore", 3)
	g.priority_player = 0
	assert_ok(g.activate_ability(0, fungus, 0))
	blink(fungus)
	resolve_stack()
	assert_eq(fungus.regeneration_shields, 0)

func test_ai_casts_hymn_using_initiates_conversion() -> void:
	put_battlefield(0, "Initiates of the Ebon Hand", true)
	put_battlefield(0, "Forest")
	put_battlefield(0, "Mountain")
	var hymn := give_hand(0, "Hymn to Tourach")
	for _i in 3: give_hand(1, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	var ai := AiPlayer.new(0, AiProfile.wizard())
	ai.profile.develops_late = false
	g.agents[0] = ai
	assert_eq(ai._try_cast_best(g), "cast Hymn to Tourach")
	assert_eq(g.stack.back().targets[0].player_id, 1)
	resolve_stack()
	assert_eq(hymn.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].hand.size(), 1)

func test_ai_kites_buys_lethal_evasion_without_peeking_at_coin() -> void:
	var kites := put_battlefield(0, "Goblin Kites")
	var bear := put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Craw Wurm")
	g.players[1].life = 2
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.agents[0] = ai
	var before := g.rng.state
	var choice := ai._ability_option(g, kites, 0, AiPlayer.Moment.MAIN)
	assert_false(choice.is_empty())
	assert_eq(g.rng.state, before)
	assert_eq(choice.targets[0].instance_id, bear.id)
	assert_ok(g.activate_ability(0, kites, 0, choice.targets))
	resolve_stack()
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING))
	assert_true(ai._ability_option(g, kites, 0, AiPlayer.Moment.MAIN).is_empty(), "no repeated coin risks for redundant flying")

func test_ai_kites_declines_unnecessary_or_still_blockable_flying() -> void:
	var kites := put_battlefield(0, "Goblin Kites")
	put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	var ai := AiPlayer.new(0, AiProfile.wizard())
	assert_true(ai._ability_option(g, kites, 0, AiPlayer.Moment.MAIN).is_empty())
	put_battlefield(1, "Giant Spider")
	g.players[1].life = 2
	assert_true(ai._ability_option(g, kites, 0, AiPlayer.Moment.MAIN).is_empty(), "reach still blocks")

func test_ai_kites_does_not_risk_a_valuable_engine_for_one_damage() -> void:
	var kites := put_battlefield(0, "Goblin Kites")
	put_battlefield(0, "Prodigal Sorcerer")
	put_battlefield(1, "Craw Wurm")
	advance_to_step(Mtg.Step.MAIN1)
	var ai := AiPlayer.new(0, AiProfile.wizard())
	assert_true(ai._ability_option(g, kites, 0, AiPlayer.Moment.MAIN).is_empty())

func test_ai_kites_cannot_unblock_an_already_blocked_attacker() -> void:
	var kites := put_battlefield(0, "Goblin Kites")
	var bear := put_battlefield(0, "Grizzly Bears")
	var enemy := put_battlefield(1, "Craw Wurm")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {enemy.id: [bear.id]}))
	g.players[1].life = 2
	var ai := AiPlayer.new(0, AiProfile.wizard())
	assert_true(ai._ability_option(g, kites, 0, AiPlayer.Moment.RESPONSE).is_empty())

func test_ai_holds_hymn_against_an_empty_hand() -> void:
	give_hand(0, "Hymn to Tourach")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	var ai := AiPlayer.new(0, AiProfile.wizard())
	ai.profile.develops_late = false
	assert_eq(ai._try_cast_best(g), "")
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 2)

func test_dwarf_gets_one_bonus_for_multiple_orc_blockers() -> void:
	var dwarf := put_battlefield(0, "Dwarven Soldier")
	var a := put_battlefield(1, "Orcish Veteran")
	var b := put_battlefield(1, "Orcish Veteran")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [dwarf.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {a.id: [dwarf.id], b.id: [dwarf.id]}))
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(dwarf.cur_toughness, 3)

func test_skirmishers_remember_the_band_when_the_source_leaves() -> void:
	var skirmishers := put_battlefield(0, "Icatian Skirmishers")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [skirmishers.id, bear.id], [[skirmishers.id, bear.id]]))
	g.return_to_hand(skirmishers)
	resolve_stack()
	assert_true(bear.has_keyword(Mtg.Keyword.FIRST_STRIKE))

func test_flotilla_first_strike_does_not_follow_a_reentered_blocker() -> void:
	var flotilla := put_battlefield(0, "Goblin Flotilla")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [flotilla.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bear.id: [flotilla.id]}))
	blink(bear)
	resolve_stack()
	assert_false(bear.has_keyword(Mtg.Keyword.FIRST_STRIKE))

func test_conversion_search_obeys_real_generic_colour_tie_order() -> void:
	put_battlefield(0, "Initiates of the Ebon Hand")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.R)
	var cost := ManaCost.parse("{B}{B}")
	# The engine's deterministic generic payment spends the first equal
	# colour (black here), so repeating this conversion makes no progress.
	assert_true(ManaPlanner.plan(g, 0, cost, 0).is_empty())
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.R), 1)

func test_conversion_search_does_not_need_to_activate_a_converter_when_plain_mana_suffices() -> void:
	var priest := put_battlefield(0, "Farrelite Priest")
	var plains := put_battlefield(0, "Plains")
	var plan := ManaPlanner.plan(g, 0, ManaCost.parse("{W}"), 0)
	assert_eq(plan.size(), 1)
	assert_eq(plan[0][0], plains)
	assert_eq(int(priest.memory.get("conversions", 0)), 0)

# Bug pass 2026-10-03: blocking one member of a band blocks every member
# (CR 702.22h), so a Dwarf declared on the Benalish Hero is also blocking
# the Orc banded with it.
func test_dwarf_blocking_a_band_with_an_orc_gets_the_bonus() -> void:
	var hero := put_battlefield(0, "Benalish Hero")
	var orc := put_battlefield(0, "Orcish Veteran")
	var dwarf := put_battlefield(1, "Dwarven Soldier")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [hero.id, orc.id], [[hero.id, orc.id]]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {dwarf.id: hero.id}))
	resolve_stack()
	assert_eq(dwarf.cur_toughness, 3)

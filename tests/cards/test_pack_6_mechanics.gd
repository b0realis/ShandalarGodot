extends GameTest

func before_each() -> void:
	CardPacks.set_enabled("pack-6", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)
func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
func cast(name: String, targets: Array = [], pid := 0, x := 0) -> CardInstance:
	var c := give_hand(pid, name)
	for color in Mtg.WUBRG: add_mana(pid, color, 20)
	if g.priority_player != pid: assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.cast_spell(pid, c, targets, x))
	resolve_stack()
	return c

func test_enter_life_and_optional_reanimation() -> void:
	cast("Venerable Monk")
	assert_eq(g.players[0].life, 22)
	cast("Spiritual Guardian")
	assert_eq(g.players[0].life, 26)
	cast("Serpent Warrior")
	assert_eq(g.players[0].life, 23)
	var dead := put_battlefield(0, "Grizzly Bears")
	g.destroy(dead)
	cast("Gravedigger")
	assert_eq(dead.zone, Mtg.Zone.HAND)

func test_death_returns_are_triggers_not_replacements() -> void:
	for name in ["Alabaster Dragon", "Endless Cockroaches", "Undying Beast"]:
		var c := put_battlefield(0, name)
		g.destroy(c)
		assert_eq(c.zone, Mtg.Zone.GRAVEYARD, name)
		assert_false(g.stack.is_empty(), name)
		resolve_stack()
		assert_eq(c.zone, Mtg.Zone.HAND if name == "Endless Cockroaches" else Mtg.Zone.LIBRARY, name)
		if name == "Undying Beast": assert_eq(g.players[0].library.back(), c)

func test_exiled_dead_card_is_not_returned_by_stale_trigger() -> void:
	var c := put_battlefield(0, "Endless Cockroaches")
	g.destroy(c)
	g.exile_from_graveyard(c)
	resolve_stack()
	assert_eq(c.zone, Mtg.Zone.EXILE)

func test_combat_only_portal_spell_requires_being_attacked_this_step() -> void:
	var blade := give_hand(1, "Assassin's Blade")
	add_mana(1, Mtg.ManaColor.B, 8)
	var attacker := put_battlefield(0, "Grizzly Bears")
	assert_refused(g.cast_spell(1, blade, [TargetRef.card(attacker)]))
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.B, 8)
	assert_ok(g.cast_spell(1, blade, [TargetRef.card(attacker)]))
	resolve_stack()
	assert_eq(attacker.zone, Mtg.Zone.GRAVEYARD)

func test_deep_wood_stops_attacker_damage_only_and_expires() -> void:
	var attacker := put_battlefield(0, "Hill Giant")
	var defender := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	cast("Deep Wood", [], 1)
	g.deal_damage(attacker, TargetRef.player(1), 3, true)
	assert_eq(g.players[1].life, 20)
	g.deal_damage(attacker, TargetRef.player(1), 1, false)
	assert_eq(g.players[1].life, 20, "also prevents noncombat damage from an attacking creature")
	g.deal_damage(attacker, TargetRef.card(defender), 1, false)
	assert_eq(defender.damage, 1)
	g.deal_damage(give_hand(0, "Lightning Bolt"), TargetRef.player(1), 3)
	assert_eq(g.players[1].life, 17)
	advance_to_next_turn()
	g.deal_damage(attacker, TargetRef.player(1), 1)
	assert_eq(g.players[1].life, 16, "combat was prevented; later nonattacking damage applies")

func test_harsh_justice_uses_combat_packet_and_expires_at_cleanup() -> void:
	var attacker := put_battlefield(0, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	cast("Harsh Justice", [], 1)
	g.deal_damage(attacker, TargetRef.player(1), 2, true)
	resolve_stack()
	assert_eq(g.players[0].life, 18)
	g.deal_damage(attacker, TargetRef.player(1), 1, false)
	resolve_stack()
	assert_eq(g.players[0].life, 18)
	advance_to_next_turn()
	assert_true(g.delayed_triggers.is_empty())

func test_one_blocker_limit_beats_lure_and_ai_repairs_the_group() -> void:
	var tiger := put_battlefield(0, "Stalking Tiger")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	cast("Alluring Scent", [TargetRef.card(tiger)])
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [tiger.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {a.id: tiger.id, b.id: tiger.id}), "more than")
	assert_refused(g.declare_blockers(1, {}), "must block")
	var repaired: Dictionary = preload("res://engine/core/combat_declaration.gd").repair_blocks(g, 1, {a.id: tiger.id, b.id: tiger.id})
	assert_eq(repaired.size(), 1)
	assert_ok(g.declare_blockers(1, repaired))

func test_time_ebb_moves_directly_to_owner_library_and_strips_aura() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var aura := cast("Holy Strength", [TargetRef.card(bear)])
	cast("Time Ebb", [TargetRef.card(bear)])
	assert_eq(bear.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[1].library.back(), bear)
	assert_false(g.players[1].hand.has(bear))
	assert_eq(aura.zone, Mtg.Zone.GRAVEYARD)

func test_tiger_with_menace_cannot_be_blocked_even_with_lure() -> void:
	CardPacks.set_enabled("pack-2", true)
	var tiger := put_battlefield(0, "Stalking Tiger")
	put_battlefield(0, "Goblin War Drums")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	cast("Alluring Scent", [TargetRef.card(tiger)])
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [tiger.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_false(g.can_meet_minimum_blockers(tiger, 1))
	var repaired: Dictionary = preload("res://engine/core/combat_declaration.gd").repair_blocks(g, 1, {a.id: tiger.id, b.id: tiger.id})
	assert_true(repaired.is_empty())
	assert_ok(g.declare_blockers(1, repaired))

func test_final_strike_remembers_sacrificed_live_power() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	cast("Monstrous Growth", [TargetRef.card(bear)])
	cast("Final Strike", [TargetRef.player(1)])
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 14)

func test_path_of_peace_gives_owner_life_even_after_control_change() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	g.change_control(bear, 0)
	cast("Path of Peace", [TargetRef.card(bear)])
	assert_eq(g.players[1].life, 24)
	assert_eq(g.players[0].life, 20)

func test_burning_cloak_pumps_and_damages_same_target() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	cast("Burning Cloak", [TargetRef.card(giant)])
	assert_eq(giant.cur_power, 5)
	assert_eq(giant.damage, 2)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)

func test_summer_bloom_adds_three_land_plays_and_expires() -> void:
	cast("Summer Bloom")
	for n in 4: assert_ok(g.play_land(0, give_hand(0, "Forest")))
	assert_refused(g.play_land(0, give_hand(0, "Forest")))
	advance_to_next_turn()
	assert_true(g.extra_land_plays.is_empty())

func test_false_peace_skips_target_next_combat_not_current_one() -> void:
	cast("False Peace", [TargetRef.player(1)])
	assert_false(g.skip_combat_this_turn)
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	assert_true(g.skip_combat_this_turn)
	assert_ok(g.pass_priority(1))
	assert_ok(g.pass_priority(0))
	assert_eq(g.current_step(), Mtg.Step.MAIN2)
	advance_to_next_turn()
	assert_false(g.skip_combat_this_turn)

func test_last_chance_loses_only_at_its_own_extra_turn_end() -> void:
	cast("Last Chance")
	cast("Time Walk")
	advance_to_next_turn()
	assert_eq(g.active_player, 0)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_false(g.game_over, "the later Time Walk is first, without a loss rider")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.END)
	assert_false(g.game_over, "the loss uses the stack")
	resolve_stack()
	assert_true(g.game_over)
	assert_eq(g.winner, 1)

func test_extra_turn_order_and_regular_turn_resume() -> void:
	g.add_extra_turn(0)
	g.add_extra_turn(1)
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	advance_to_next_turn()
	assert_eq(g.active_player, 0)
	advance_to_next_turn()
	assert_eq(g.active_player, 1)

func test_plant_elemental_requires_forest_and_primeval_requires_three() -> void:
	var plant := cast("Plant Elemental")
	assert_eq(plant.zone, Mtg.Zone.GRAVEYARD)
	for n in 3: put_battlefield(0, "Forest")
	var primeval := cast("Primeval Force")
	assert_eq(primeval.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].battlefield.size(), 1)

func test_wood_elves_searches_forest_subtype_including_dual_lands() -> void:
	var dual := give_hand(0, "Tropical Island")
	g.put_from_hand_on_top_of_library(dual)
	# Only the dual is eligible, so the choice cannot be accidental.
	for i in g.players[0].library.duplicate():
		if i != dual: g.exile_library_card(i)
	cast("Wood Elves")
	assert_eq(dual.zone, Mtg.Zone.BATTLEFIELD)
	assert_false(dual.tapped)

func test_spitting_earth_counts_live_mountains() -> void:
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Badlands")
	var giant := put_battlefield(1, "Hill Giant")
	cast("Spitting Earth", [TargetRef.card(giant)])
	assert_eq(giant.damage, 2)

func test_card_choices_and_turn_modifiers_undo_cleanly() -> void:
	var spell := give_hand(0, "False Peace")
	add_mana(0, Mtg.ManaColor.W)
	var mark := g.make_mark()
	assert_ok(g.cast_spell(0, spell, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.next_turn_statics.size(), 1)
	g.unmake_to(mark)
	g.end_search()
	assert_true(g.next_turn_statics.is_empty())
	assert_eq(spell.zone, Mtg.Zone.HAND)

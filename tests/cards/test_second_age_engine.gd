extends GameTest
## Extra combats, foreign-land mana and special combat assignment.

func before_each() -> void:
	CardPacks.set_enabled("pack-6", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func cast(name: String) -> void:
	var c := give_hand(0, name)
	for color in Mtg.WUBRG: add_mana(0, color, 10)
	assert_ok(g.cast_spell(0, c))
	resolve_stack()
	g.players[0].mana_pool.clear()

func test_piracy_borrows_land_not_control_and_mana_is_spells_only() -> void:
	var island := put_battlefield(1, "Island")
	assert_refused(g.tap_for_mana(0, island))
	cast("Piracy")
	assert_ok(g.tap_for_mana(0, island))
	assert_eq(island.controller_id, 1)
	assert_eq(g.players[1].mana_pool.total(), 0)
	assert_eq(g.players[0].mana_pool.total(), 1)
	assert_false(g.players[0].mana_pool.can_pay(ManaCost.parse("{U}")))
	var remove := give_hand(0, "Sleight of Hand")
	assert_ok(g.cast_spell(0, remove))
	resolve_stack()
	advance_to_next_turn()
	g.untap_permanent(island)
	assert_refused(g.tap_for_mana(0, island))

func test_piracy_auto_tap_respects_cost_use() -> void:
	var island := put_battlefield(1, "Island")
	cast("Piracy")
	assert_false(ManaPlanner.plan_from(ManaPlanner.sources(g, 0), ManaCost.parse("{U}"), 0, []).size() > 0)
	var spell := give_hand(0, "Sleight of Hand")
	assert_true(ManaPlanner.plan_and_pay(g, 0, spell.data.cost, 0, g.mana_usage_keys(spell.data, spell)))
	assert_true(island.tapped)
	assert_ok(g.cast_spell(0, spell))
	resolve_stack()

func test_relentless_assault_in_second_main_adds_combat_and_main_without_untap() -> void:
	var bear := put_battlefield(0, "Bear Cub")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.MAIN2)
	assert_true(bear.tapped)
	cast("Relentless Assault")
	assert_false(bear.tapped)
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	assert_eq(g.current_step(), Mtg.Step.COMBAT_BEGIN)
	assert_eq(g.active_player, 0)
	assert_eq(g.turn_number, 1)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(g.players[1].life, 16)
	assert_true(bear.tapped)

func test_two_extra_combats_and_undo_preserve_turn_order() -> void:
	var mark := g.make_mark()
	cast("Relentless Assault")
	cast("Relentless Assault")
	var combats := 0
	var turn := g.turn_number
	for n in 100:
		if g.turn_number != turn: break
		if g.current_step() == Mtg.Step.COMBAT_BEGIN and g.priority_player == 0: combats += 1
		if g.awaiting_attackers: assert_ok(g.declare_attackers(0, []))
		elif g.awaiting_discard: assert_ok(g.discard_to_hand_size(g.active_player, []))
		else: assert_ok(g.pass_priority(g.priority_player))
	assert_eq(combats, 3)
	g.unmake_to(mark)
	g.end_search()
	assert_eq(g.current_step(), Mtg.Step.MAIN1)
	assert_eq(g.turn_number, turn)

func test_lone_wolf_can_damage_player_while_still_taking_blocker_damage() -> void:
	var wolf := put_battlefield(0, "Lone Wolf")
	var blocker := put_battlefield(1, "Grizzly Bears")
	run_combat([wolf.id], {blocker.id: wolf.id})
	assert_eq(g.players[1].life, 18)
	assert_eq(wolf.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(blocker.zone, Mtg.Zone.BATTLEFIELD)

class DamageChooser extends DecisionAgent:
	func wants_to_assign_combat_damage() -> bool: return true

func test_cunning_giant_assignment_is_whole_damage_and_not_targeted() -> void:
	var giant := put_battlefield(0, "Cunning Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.set_agent(0, DamageChooser.new())
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_assignment)
	assert_eq(g.damage_assignment_request().special, "redirect")
	assert_refused(g.assign_combat_damage(0, {bear.id: 1, MtgGame.DAMAGE_TO_PLAYER: 3}))
	assert_ok(g.assign_combat_damage(0, {bear.id: 4}))
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 20)

func test_bypass_is_optional_and_banding_keeps_defenders_normal_division() -> void:
	var wolf := put_battlefield(0, "Deathcoil Wurm")
	var hero := put_battlefield(1, "Benalish Hero")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.set_agent(0, DamageChooser.new())
	g.set_agent(1, DamageChooser.new())
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wolf.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {hero.id: wolf.id, bear.id: wolf.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_eq(g.damage_assignment_request().assigner, 0)
	assert_ok(g.assign_combat_damage(0, {bear.id: 7}))
	assert_eq(g.damage_assignment_request().assigner, 1)
	assert_ok(g.assign_combat_damage(1, {hero.id: 7}))
	assert_eq(hero.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[1].life, 20)

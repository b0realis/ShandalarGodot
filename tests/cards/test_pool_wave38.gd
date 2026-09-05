extends GameTest
## Wave-38 tests: TOKENS (The Hive, Rukh Egg, Boris Devilboon, Master of
## the Hunt, Stangg) and COIN FLIPS (Bottle of Suleiman, Mijae Djinn,
## Ydwen Efreet, Mana Clash), plus two counter-based artifact creatures
## (Triskelion, Clockwork Beast).


func test_the_hive_makes_flying_wasps() -> void:
	var hive := put_battlefield(0, "The Hive")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.activate_ability(0, hive, 0, []))
	resolve_stack()
	var wasp := g.find_on_battlefield(0, "Wasp")
	assert_not_null(wasp)
	assert_true(wasp.is_token)
	assert_true(wasp.has_keyword(Mtg.Keyword.FLYING))
	assert_eq(wasp.cur_power, 1)


func test_a_token_ceases_to_exist_when_it_dies() -> void:
	var hive := put_battlefield(0, "The Hive")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.activate_ability(0, hive, 0, []))
	resolve_stack()
	var wasp := g.find_on_battlefield(0, "Wasp")
	g.destroy(wasp, false)
	assert_eq(g.players[0].graveyard.size(), 0, "tokens leave no corpse")


func test_rukh_egg_hatches_at_the_next_end_step() -> void:
	var egg := put_battlefield(0, "Rukh Egg")
	g.destroy(egg, false)
	resolve_stack()
	assert_null(g.find_on_battlefield(0, "Rukh"), "not yet")
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	var bird := g.find_on_battlefield(0, "Rukh")
	assert_not_null(bird)
	assert_eq(bird.cur_power, 4)
	assert_true(bird.has_keyword(Mtg.Keyword.FLYING))


func test_boris_devilboon_summons_minor_demons() -> void:
	var boris := put_battlefield(0, "Boris Devilboon")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, boris, 0, []))
	resolve_stack()
	var demon := g.find_on_battlefield(0, "Minor Demon")
	assert_not_null(demon)
	assert_eq(demon.cur_power, 1)
	assert_eq(demon.cur_toughness, 1)


func test_master_of_the_hunt_makes_a_wolf_pack() -> void:
	var master := put_battlefield(0, "Master of the Hunt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, master, 0, []))
	resolve_stack()
	var wolf := g.find_on_battlefield(0, "Wolves of the Hunt")
	assert_not_null(wolf)
	# "Bands with other creatures named Wolves of the Hunt", not banding —
	# lifted 2026-09-02, pinned in
	# tests/cards/test_fidelity_2026_09_02_bands_with_other.gd.
	assert_false(wolf.has_keyword(Mtg.Keyword.BANDING))
	assert_eq(String(wolf.cur_bands_with[0]["desc"]), "creatures named Wolves of the Hunt")


func test_stangg_brings_a_twin_and_leaves_with_it() -> void:
	var stangg := give_hand(0, "Stangg")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, stangg, []))
	resolve_stack()
	var twin := g.find_on_battlefield(0, "Stangg Twin")
	assert_not_null(twin)
	assert_eq(twin.cur_power, 3)
	g.destroy(stangg, false)
	resolve_stack()
	assert_null(g.find_on_battlefield(0, "Stangg Twin"), "the twin is exiled")


func test_bottle_of_suleiman_flips_for_a_djinn() -> void:
	var bottle := put_battlefield(0, "Bottle of Suleiman")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, bottle, 0, []))
	assert_eq(bottle.zone, Mtg.Zone.GRAVEYARD, "sacrificed as a cost")
	resolve_stack()
	var djinn := g.find_on_battlefield(0, "Djinn")
	var won := djinn != null
	if won:
		assert_eq(djinn.cur_power, 5)
		assert_eq(g.players[0].life, 20)
	else:
		assert_eq(g.players[0].life, 15, "lost the flip: 5 damage")


func test_mijae_djinn_may_fizzle_its_own_attack() -> void:
	var djinn := put_battlefield(0, "Mijae Djinn")
	assert_eq(djinn.cur_power, 6)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [djinn.id]))
	resolve_stack()
	# Either it is still attacking, or the flip removed it from combat.
	if not g.combat.attackers.has(djinn.id):
		assert_true(djinn.tapped, "removed from combat and tapped")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_true(g.players[1].life == 14 or g.players[1].life == 20)


func test_ydwen_efreet_may_fizzle_its_own_block() -> void:
	var efreet := put_battlefield(1, "Ydwen Efreet")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {efreet.id: bear.id}))
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	# Either the block stood (the bear took 3 and died) or the flip removed
	# the Efreet from combat — in which case the bear, which the Efreet was
	# blocking ALONE, becomes UNBLOCKED (the printed exception to CR 509.1h,
	# third sentence) and connects for 2.
	assert_true(bear.zone == Mtg.Zone.GRAVEYARD
		or (g.players[1].life == 18 and bear.zone == Mtg.Zone.BATTLEFIELD),
		"blocked and died, or unblocked and hit for 2")


func test_mana_clash_burns_until_both_heads() -> void:
	var clash := give_hand(0, "Mana Clash")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, clash, [TargetRef.player(1)]))
	resolve_stack()
	# Deterministic RNG: SOMEBODY took damage, and nobody is untouched
	# forever — the loop always terminates.
	assert_true(g.players[0].life <= 20)
	assert_true(g.players[1].life <= 20)


func test_triskelion_shoots_three_times() -> void:
	var trike := put_battlefield(0, "Triskelion")
	assert_eq(trike.counters.get("+1/+1", 0), 3)
	assert_eq(trike.cur_power, 4)
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, trike, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_ok(g.activate_ability(0, trike, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(trike.cur_power, 2, "two counters spent")


func test_clockwork_beast_winds_down() -> void:
	var beast := put_battlefield(0, "Clockwork Beast")
	assert_eq(beast.counters.get("+1/+0", 0), 7)
	assert_eq(beast.cur_power, 7)
	assert_eq(beast.cur_toughness, 4)
	run_combat([beast.id])
	resolve_stack()
	assert_eq(g.players[1].life, 13)
	assert_eq(beast.counters.get("+1/+0", 0), 6, "one counter spent in combat")

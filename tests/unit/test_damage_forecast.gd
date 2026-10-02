extends GameTest
## Forecasts must agree with real declared damage and leave all state intact.


func _blocks(attacker: CardInstance, blockers: Array) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	var map := {}
	for blocker in blockers:
		map[blocker.id] = attacker.id
	assert_ok(g.declare_blockers(1, map))


func _assert_round_trip(combat: bool, top := false) -> Dictionary:
	var snap := GameSnapshot.take(g)
	var before: Array = []
	for i in snap._objects.size():
		var n := 0
		for group in snap._props[i]:
			for prop in group:
				if prop != &"undo_log" and prop != &"journal":
					var value: Variant = snap._values[i][n]
					if value is Array or value is Dictionary or typeof(value) >= TYPE_PACKED_BYTE_ARRAY:
						value = value.duplicate(true) if value is Array or value is Dictionary else value.duplicate()
					before.append([snap._objects[i], prop, value])
				n += 1
	snap.restore()
	var rng_before := g.rng.state
	var future := g.forecast_damage(combat, top)
	for row in before:
		assert_eq(row[0].get(row[1]), row[2], "forecast changed %s" % row[1])
	assert_eq(g.rng.state, rng_before)
	return future


func test_gang_allocation_and_trample_match_actual_damage() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var force := put_battlefield(0, "Force of Nature")
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	_blocks(force, [bear, giant])
	var future := _assert_round_trip(true)
	assert_false(future["alive"].has(bear.id))
	assert_false(future["alive"].has(giant.id))
	assert_eq(future["life"][1], 17)
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_eq(g.players[1].life, future["life"][1])
	assert_eq(force.damage, future["damage"][force.id])


func test_nontrampling_overkill_is_not_discarded() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	bear.prevention = 2
	_blocks(giant, [bear])
	var future := _assert_round_trip(true)
	assert_eq(future["damage"][bear.id], 1, "all three points are assigned")
	assert_eq(future["incoming"][bear.id], 1, "incoming is after prevention")
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_eq(bear.damage, 1)


func test_defensive_banding_keeps_the_other_blocker_alive() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var hero := put_battlefield(1, "Benalish Hero")
	var bear := put_battlefield(1, "Grizzly Bears")
	_blocks(giant, [hero, bear])
	var future := _assert_round_trip(true)
	assert_false(future["alive"].has(hero.id))
	assert_true(future["alive"].has(bear.id))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


func test_offensive_banding_keeps_the_other_attacker_alive() -> void:
	# CR 702.22j: the attacking player divides the blocker's damage among
	# their band — the forecast, which runs the engine on a snapshot,
	# agrees with the real step (0.50.4).
	var hero := put_battlefield(0, "Benalish Hero")
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [hero.id, bear.id], [[hero.id, bear.id]]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {giant.id: bear.id}))
	var future := _assert_round_trip(true)
	assert_false(future["alive"].has(hero.id))
	assert_true(future["alive"].has(bear.id))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(hero.zone, Mtg.Zone.GRAVEYARD)


func test_shared_prevention_pool_is_spent_only_once() -> void:
	var giant := put_battlefield(0, "Two-Headed Giant of Foriys")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	giant.prevention = 1
	_blocks(giant, [a, b])
	var future := _assert_round_trip(true)
	assert_eq(future["damage"][giant.id], 3)
	assert_eq(giant.prevention, 1)


func test_first_strike_and_existing_regeneration_shield() -> void:
	var knight := put_battlefield(0, "White Knight")
	var troll := put_battlefield(1, "Uthden Troll")
	troll.regeneration_shields = 1
	_blocks(knight, [troll])
	var future := _assert_round_trip(true)
	assert_true(future["alive"].has(troll.id))
	assert_eq(future["damage"][troll.id], 0)
	assert_eq(troll.regeneration_shields, 1)
	assert_false(troll.tapped)


func test_indestructible_animated_land_survives_lethal_damage() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var ogre := put_battlefield(0, "Gray Ogre")
	var swamp := put_battlefield(1, "Swamp")
	put_battlefield(0, "Kormus Bell")
	var blessing := give_hand(0, "Consecrate Land")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, blessing, [TargetRef.card(swamp)]))
	resolve_stack()
	_blocks(ogre, [swamp])
	var future := _assert_round_trip(true)
	assert_true(future["alive"].has(swamp.id))
	assert_eq(future["damage"][swamp.id], 2)
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_eq(swamp.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(swamp.damage, 2)


func test_top_damage_resolution_and_death_trigger_are_undone() -> void:
	var vampire := put_battlefield(0, "Sengir Vampire")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.deal_damage(vampire, TargetRef.card(bear), 1)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	var future := _assert_round_trip(false, true)
	assert_false(future["alive"].has(bear.id))
	assert_eq(g.stack.size(), 1)
	assert_eq(g.stack.back().card, bolt)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


func test_nested_forecast_preserves_outer_journal() -> void:
	var ogre := put_battlefield(0, "Gray Ogre")
	var bear := put_battlefield(1, "Grizzly Bears")
	_blocks(ogre, [bear])
	var mark := g.make_mark()
	var journal := g.undo_log
	g.adjust_life(0, -1)
	_assert_round_trip(true)
	assert_same(g.undo_log, journal)
	assert_true(g.is_probing())
	assert_eq(g.players[0].life, 19)
	g.unmake_to(mark)
	g.end_search()
	assert_eq(g.players[0].life, 20)


func test_arbitrary_stack_effect_is_not_resolved() -> void:
	var recall := give_hand(0, "Ancestral Recall")
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, recall, [TargetRef.player(0)]))
	assert_false(g.can_forecast_damage_top())
	var future := _assert_round_trip(false, true)
	assert_eq(future["life"], [20, 20])
	assert_eq(g.stack.back().card, recall)


func test_marked_death_and_delayed_trigger_are_undone() -> void:
	var ogre := put_battlefield(0, "Gray Ogre")
	var bear := put_battlefield(1, "Grizzly Bears")
	var bird := put_battlefield(0, "Whippoorwill")
	g.mark_unpreventable_death(bear, bird, 0)
	_blocks(ogre, [bear])
	g.combat_damage_prevented = true
	var future := _assert_round_trip(true)
	assert_false(future["alive"].has(bear.id))
	assert_true(future["alive"].has(ogre.id))
	assert_eq(g.delayed_triggers.size(), 1)
	assert_true(g.stack.is_empty())
	assert_true(bear.damage_unpreventable_this_turn)

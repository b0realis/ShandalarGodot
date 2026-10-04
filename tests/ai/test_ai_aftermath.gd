extends GameTest


func test_only_reviewed_public_card_payloads_opt_into_aftermath() -> void:
	var opted: Array[String] = []
	for name in CardRegistry.all_names():
		var data := CardRegistry.get_card(name)
		for trigger in data.triggered_abilities + data.graveyard_triggers:
			if not trigger.forecast_safe: continue
			opted.append(name)
			# WAS_DEALT_DAMAGE: the victim's side of the same public damage
			# event (Fungusaur's "is dealt damage", Mirage bug pass 0.50.11).
			assert_has([Mtg.EventType.DAMAGE_DEALT, Mtg.EventType.WAS_DEALT_DAMAGE,
				Mtg.EventType.DIES], trigger.event_type)
			assert_null(trigger.target_spec)
			assert_true(trigger.modes.is_empty())
	opted.sort()
	assert_eq(opted, ["Dingus Egg", "Fungusaur", "Sengir Vampire"])


func test_sengir_death_trigger_is_included_in_both_editions() -> void:
	for edition in ["modern", "fifth"]:
		before_each()
		g.rules.set_edition(edition)
		var vampire := put_battlefield(0, "Sengir Vampire")
		var blocker := put_battlefield(1, "Giant Spider")
		advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
		assert_ok(g.declare_attackers(0, [vampire.id]))
		advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
		assert_ok(g.declare_blockers(1, {blocker.id: vampire.id}))
		var before := AiObservation.key(g, 0)
		var future := g.forecast_damage(true, false, true)
		assert_false(future.alive.has(blocker.id), edition)
		assert_eq(future.stats[vampire.id], Vector2i(5, 5), edition)
		assert_eq(AiObservation.key(g, 0), before)


func test_dingus_egg_forecasts_damage_from_an_animated_land_death() -> void:
	put_battlefield(0, "Kormus Bell")
	put_battlefield(0, "Dingus Egg")
	var land := put_battlefield(1, "Swamp")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(land)]))
	var before := AiObservation.key(g, 0)
	var future := g.forecast_damage(false, true, true)
	assert_eq(future.life[1], 18)
	assert_eq(future.aftermath.resolved, 1)
	assert_eq(AiObservation.key(g, 0), before)


func test_aftermath_has_a_hard_trigger_budget_and_restores_a_nested_probe() -> void:
	var trigger := TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT,
		func(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
			game.deal_damage(source, TargetRef.player(1), 1)).public_aftermath()
	put_synthetic(0, CardData.new("Test loop", "{1}", Mtg.CardType.ARTIFACT).triggered(trigger))
	g.players[1].life = 1000
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	var outer := g.make_mark()
	g.adjust_life(0, 2)
	var before := AiObservation.key(g, 0)
	var future := g.forecast_damage(false, true, true)
	assert_false(future.aftermath.complete)
	assert_eq(future.aftermath.resolved, 32)
	assert_eq(AiObservation.key(g, 0), before)
	assert_not_null(g.undo_log)
	g.unmake_to(outer)
	g.end_search()
	assert_eq(g.players[0].life, 20)


func test_fungusaur_forecast_grows_then_restores_the_live_board() -> void:
	var fungus := put_battlefield(1, "Fungusaur")
	var ping := give_hand(0, "Lightning Bolt")
	ping.data = CardData.new("Test ping", "{R}", Mtg.CardType.INSTANT) \
		.spell(DamageEffect.new(1).any_target())
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, ping, [TargetRef.card(fungus)]))
	var before := AiObservation.key(g, 0)
	var rng_before := g.rng.state
	var future := g.forecast_damage(false, true, true)
	assert_eq(future.stats[fungus.id], Vector2i(3, 3))
	assert_eq(future.aftermath.resolved, 1)
	assert_true(future.aftermath.complete)
	assert_eq(AiObservation.key(g, 0), before)
	assert_eq(g.rng.state, rng_before)
	assert_eq(fungus.cur_power, 2)
	assert_null(g.undo_log)


func test_unknown_draw_trigger_is_never_resolved() -> void:
	var draws := [0]
	var trigger := TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT,
		func(game: MtgGame, _source: CardInstance, _event: GameEvent) -> void:
			draws[0] += 1
			game.draw_cards(1, 1))
	var victim := put_synthetic(1, CardData.new("Unknown aftermath", "{1}", Mtg.CardType.CREATURE)
		.pt(4, 4).triggered(trigger))
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(victim)]))
	var before := AiObservation.key(g, 0)
	var future := g.forecast_damage(false, true, true)
	assert_false(future.aftermath.complete)
	assert_eq(draws[0], 0)
	assert_eq(AiObservation.key(g, 0), before)


func test_lethal_damage_does_not_grow_a_dead_fungusaur() -> void:
	var fungus := put_battlefield(1, "Fungusaur")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(fungus)]))
	var future := g.forecast_damage(false, true, true)
	assert_false(future.alive.has(fungus.id))
	assert_eq(fungus.zone, Mtg.Zone.BATTLEFIELD)


func test_aftermath_never_resolves_an_older_stack_item() -> void:
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	var before := AiObservation.key(g, 0)
	var future := g.forecast_damage(false, false, true)
	assert_eq(future.life[1], 20)
	assert_eq(future.aftermath.resolved, 0)
	assert_eq(AiObservation.key(g, 0), before)

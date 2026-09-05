extends GameTest
## Engine tests: turn structure, priority, the land rule, spell timing,
## stack ordering (LIFO), and fizzling.


func test_game_starts_in_turn_one_upkeep() -> void:
	assert_eq(g.turn_number, 1)
	assert_eq(g.active_player, 0)
	assert_eq(g.current_step(), Mtg.Step.UPKEEP)
	assert_eq(g.priority_player, 0)


func test_first_player_skips_first_draw() -> void:
	var lib0 := g.players[0].library.size()
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(g.players[0].library.size(), lib0, "no card drawn on turn 1")
	assert_eq(g.players[0].hand.size(), 0)
	var lib1 := g.players[1].library.size()
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	assert_eq(g.players[1].library.size(), lib1 - 1, "player 2 does draw")


func test_one_land_per_turn() -> void:
	var land1 := give_hand(0, "Forest")
	var land2 := give_hand(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.play_land(0, land1))
	assert_eq(land1.zone, Mtg.Zone.BATTLEFIELD)
	assert_refused(g.play_land(0, land2), "already played a land")


func test_land_timing_restriction() -> void:
	var land := give_hand(0, "Forest")
	# Turn 1 upkeep: not a main phase.
	assert_refused(g.play_land(0, land), "main phase")


func test_sorcery_speed_creature_timing() -> void:
	var bears := give_hand(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)   # P0's main phase
	assert_ok(g.pass_priority(0))     # P1 now holds priority — on P0's turn
	add_mana(1, Mtg.ManaColor.G, 2)
	assert_refused(g.cast_spell(1, bears, []), "main phase")


func test_cast_creature_resolves_to_battlefield() -> void:
	var bears := give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, bears, []))
	assert_eq(bears.zone, Mtg.Zone.STACK)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(bears.summoning_sick)
	assert_eq(bears.cur_power, 2)


func test_casting_needs_mana() -> void:
	var bears := give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.cast_spell(0, bears, []), "not enough mana")


func test_stack_resolves_lifo_bolt_beats_growth() -> void:
	# P0's Giant Growth on their bear; P1 responds with Lightning Bolt.
	# LIFO: Bolt resolves first, kills the 2/2, Growth fizzles.
	var bear := put_battlefield(0, "Grizzly Bears")
	var growth := give_hand(0, "Giant Growth")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "bear died to the bolt")
	assert_eq(growth.zone, Mtg.Zone.GRAVEYARD, "growth fizzled to the graveyard")


func test_growth_resolving_first_saves_the_bear() -> void:
	# Same duel, opposite order: Bolt on the stack first, Growth on top.
	var bear := put_battlefield(0, "Grizzly Bears")
	var growth := give_hand(0, "Giant Growth")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "5/5 bear survives 3 damage")
	assert_eq(bear.cur_power, 5)
	assert_eq(bear.damage, 3)


func test_pump_expires_at_cleanup() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var growth := give_hand(0, "Giant Growth")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_power, 5)
	advance_to_next_turn()
	assert_eq(bear.cur_power, 2, "until-end-of-turn effect expired")
	assert_eq(bear.damage, 0, "damage wore off at cleanup")


func test_mana_pool_empties_between_steps() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 3)
	advance_to_step(Mtg.Step.END)
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_priority_required_to_act() -> void:
	var bolt := give_hand(1, "Lightning Bolt")
	# Turn 1 upkeep: P0 holds priority; P1 cannot cast yet.
	add_mana(1, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(1, bolt, [TargetRef.player(0)]), "priority")

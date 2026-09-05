extends GameTest
## Wave-20 tests: the Legends spell book — targeted sweepers (Acid Rain,
## Cleanse, Hellfire), life-swinging burn (Syphon Soul, Storm Seeker,
## Typhoon, Jovial Evil), mass pumps (Hell Swarm, Shield Wall), the Fog
## reprints (Holy Day, Darkness) and the P/T switch (Transmutation).


func test_acid_rain_only_eats_forests() -> void:
	var forest := put_battlefield(1, "Forest")
	var island := put_battlefield(1, "Island")
	var mine := put_battlefield(0, "Forest")
	var rain := give_hand(0, "Acid Rain")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, rain, []))
	resolve_stack()
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD, "your own Forests drown too")
	assert_eq(island.zone, Mtg.Zone.BATTLEFIELD)


func test_cleanse_kills_only_black_creatures() -> void:
	var black := put_battlefield(1, "Drudge Skeletons")
	var green := put_battlefield(1, "Grizzly Bears")
	var cleanse := give_hand(0, "Cleanse")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, cleanse, []))
	resolve_stack()
	assert_eq(black.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(green.zone, Mtg.Zone.BATTLEFIELD)


func test_hellfire_spares_black_and_burns_its_caster() -> void:
	var black := put_battlefield(0, "Drudge Skeletons")
	var bear := put_battlefield(1, "Grizzly Bears")
	var lions := put_battlefield(1, "Savannah Lions")
	var hellfire := give_hand(0, "Hellfire")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 3)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, hellfire, []))
	resolve_stack()
	assert_eq(black.zone, Mtg.Zone.BATTLEFIELD, "black creatures survive")
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(lions.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 15, "2 died + 3 = 5 damage to the caster")


func test_syphon_soul_drains_and_gains() -> void:
	var syphon := give_hand(0, "Syphon Soul")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, syphon, []))
	resolve_stack()
	assert_eq(g.players[1].life, 18)
	assert_eq(g.players[0].life, 22)


func test_storm_seeker_counts_the_targets_hand() -> void:
	for i in 4:
		give_hand(1, "Forest")
	var seeker := give_hand(0, "Storm Seeker")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, seeker, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 16)


func test_typhoon_counts_their_islands() -> void:
	put_battlefield(1, "Island")
	put_battlefield(1, "Island")
	put_battlefield(0, "Island")   # yours don't count against you
	var typhoon := give_hand(0, "Typhoon")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, typhoon, []))
	resolve_stack()
	assert_eq(g.players[1].life, 18)
	assert_eq(g.players[0].life, 20)


func test_jovial_evil_doubles_their_white_creatures() -> void:
	put_battlefield(1, "Savannah Lions")
	put_battlefield(1, "White Knight")
	put_battlefield(1, "Grizzly Bears")   # not white
	var evil := give_hand(0, "Jovial Evil")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, evil, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 16, "two white creatures → 4 damage")


func test_jovial_evil_cannot_target_yourself() -> void:
	var evil := give_hand(0, "Jovial Evil")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.cast_spell(0, evil, [TargetRef.player(0)]), "Illegal target")


func test_hell_swarm_blunts_everything() -> void:
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Savannah Lions")
	var swarm := give_hand(0, "Hell Swarm")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, swarm, []))
	resolve_stack()
	assert_eq(mine.cur_power, 1)
	assert_eq(theirs.cur_power, 1)
	assert_eq(theirs.cur_toughness, 1, "toughness untouched")


func test_shield_wall_only_helps_your_side() -> void:
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Grizzly Bears")
	var wall := give_hand(0, "Shield Wall")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, wall, []))
	resolve_stack()
	assert_eq(mine.cur_toughness, 4)
	assert_eq(theirs.cur_toughness, 2)


func test_holy_day_fogs_the_attack() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var holy := give_hand(0, "Holy Day")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, holy, []))
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20, "no combat damage got through")


func test_darkness_fogs_the_attack() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var darkness := give_hand(0, "Darkness")
	advance_to_next_turn()   # player 1's turn
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {}))
	assert_ok(g.pass_priority(1))   # the attacker passes first
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, darkness, []))
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 20)


func test_transmutation_switches_power_and_toughness() -> void:
	var wall := put_battlefield(1, "Wall of Wood")
	var trans := give_hand(0, "Transmutation")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C)
	assert_eq(wall.cur_power, 0)
	assert_eq(wall.cur_toughness, 3)
	assert_ok(g.cast_spell(0, trans, [TargetRef.card(wall)]))
	resolve_stack()
	# 0/3 becomes 3/0 — zero toughness, so the wall dies to state-based
	# actions the moment the spell finishes resolving (CR 704.5a).
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD)


func test_transmutation_expires_at_cleanup() -> void:
	var bear := put_battlefield(1, "Hurloon Minotaur")   # 2/3
	var trans := give_hand(0, "Transmutation")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, trans, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_power, 3)
	assert_eq(bear.cur_toughness, 2)
	advance_to_next_turn()
	assert_eq(bear.cur_power, 2, "back to printed values")
	assert_eq(bear.cur_toughness, 3)

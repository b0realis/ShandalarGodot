extends GameTest
## Wave-40 tests: cost REDUCERS (Mana Matrix, Planar Gate, Stone
## Calendar), legendary lockdown (Arena of the Ancients), a death curse
## (Brine Hag), burn (Chain Lightning), upkeep rents (Elder Spawn, Mold
## Demon), a death replacement (Firestorm Phoenix), gaze effects
## (Infernal Medusa), forced Wall blocks (Marble Priest) and an untap
## trick (Reset).


func test_stone_calendar_shaves_a_generic_mana() -> void:
	put_battlefield(0, "Stone Calendar")
	var bear := give_hand(0, "Grizzly Bears")      # {1}{G}
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, bear, []), )
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


func test_a_reduction_cannot_eat_coloured_mana() -> void:
	put_battlefield(0, "Stone Calendar")
	var bolt := give_hand(0, "Lightning Bolt")     # {R}, no generic
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.cast_spell(0, bolt, [TargetRef.player(1)]), "not enough mana")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))


func test_mana_matrix_only_helps_instants_and_enchantments() -> void:
	put_battlefield(0, "Mana Matrix")
	var terror := give_hand(0, "Terror")           # {1}{B}
	var bear := give_hand(0, "Grizzly Bears")      # {1}{G}
	var victim := put_battlefield(1, "Savannah Lions")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, terror, [TargetRef.card(victim)]))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.G)
	assert_refused(g.cast_spell(0, bear, []), "not enough mana")


func test_planar_gate_only_helps_creatures() -> void:
	put_battlefield(0, "Planar Gate")
	var angel := give_hand(0, "Serra Angel")       # {3}{W}{W}
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, angel, []))
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.BATTLEFIELD)


func test_arena_of_the_ancients_freezes_the_legends() -> void:
	var legend := put_battlefield(1, "Jedit Ojanen")
	var bear := put_battlefield(1, "Grizzly Bears")
	var arena := give_hand(0, "Arena of the Ancients")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, arena, []))
	resolve_stack()
	assert_true(legend.tapped, "the arena taps every legend on arrival")
	assert_false(bear.tapped)
	advance_to_next_turn()
	assert_true(legend.tapped, "and they never untap")
	assert_false(bear.tapped)


func test_brine_hag_flattens_its_killers() -> void:
	# A first striker kills the Hag without taking damage back, so it
	# survives the curse and shows the 0/2 it leaves behind.
	var hag := put_battlefield(1, "Brine Hag")        # 2/2
	var knight := put_battlefield(0, "Black Knight")  # 2/2 first strike
	run_combat([knight.id], {hag.id: knight.id})
	resolve_stack()
	assert_eq(hag.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(knight.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(knight.cur_power, 0, "the Hag's curse flattens it to 0/2")
	assert_eq(knight.cur_toughness, 2)


func test_chain_lightning_burns_for_three() -> void:
	var bolt := give_hand(0, "Chain Lightning")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 17)


func test_elder_spawn_eats_an_island_or_you() -> void:
	var spawn := put_battlefield(0, "Elder Spawn")
	var island := put_battlefield(0, "Island")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.UPKEEP)
	resolve_stack()
	assert_eq(island.zone, Mtg.Zone.GRAVEYARD, "an Island was fed to it")
	assert_eq(spawn.zone, Mtg.Zone.BATTLEFIELD)
	advance_to_next_turn()
	advance_to_next_turn()   # no Islands left
	assert_eq(spawn.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 14)


func test_elder_spawn_dodges_red_blockers() -> void:
	put_battlefield(0, "Island")
	var spawn := put_battlefield(0, "Elder Spawn")
	var goblin := put_battlefield(1, "Mons's Goblin Raiders")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [spawn.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {goblin.id: spawn.id}), "red")


func test_firestorm_phoenix_comes_home_instead_of_dying() -> void:
	var phoenix := put_battlefield(0, "Firestorm Phoenix")
	assert_true(phoenix.has_keyword(Mtg.Keyword.FLYING))
	g.destroy(phoenix, false)
	assert_eq(phoenix.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].graveyard.size(), 0)


func test_infernal_medusa_gazes_its_blocker_down() -> void:
	var medusa := put_battlefield(1, "Infernal Medusa")   # 2/4
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {medusa.id: bear.id}))
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "gazed to death at end of combat")


func test_marble_priest_drags_every_wall_into_the_block() -> void:
	var priest := put_battlefield(0, "Marble Priest")   # 3/3
	var wall := put_battlefield(1, "Wall of Wood")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [priest.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {}), "must block")
	assert_ok(g.declare_blockers(1, {wall.id: priest.id}))
	assert_not_null(bear)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(priest.damage, 0, "Walls can't hurt it")


func test_mold_demon_demands_two_swamps() -> void:
	var demon := give_hand(0, "Mold Demon")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.cast_spell(0, demon, []))
	resolve_stack()
	assert_eq(demon.zone, Mtg.Zone.GRAVEYARD, "no Swamps, no Demon")


func test_mold_demon_stays_when_the_swamps_are_paid() -> void:
	var s1 := put_battlefield(0, "Swamp")
	var s2 := put_battlefield(0, "Swamp")
	var demon := give_hand(0, "Mold Demon")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.cast_spell(0, demon, []))
	resolve_stack()
	assert_eq(demon.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(s1.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(s2.zone, Mtg.Zone.GRAVEYARD)


func test_reset_untaps_your_lands() -> void:
	var l1 := put_battlefield(0, "Forest")
	var l2 := put_battlefield(0, "Forest")
	var theirs := put_battlefield(1, "Forest")
	var reset := give_hand(0, "Reset")
	g.tap_permanent(l1)
	g.tap_permanent(l2)
	# "Cast this spell only during an opponent's turn after their upkeep
	# step" — so this happens in player 1's main phase (their own untap
	# step has already been and gone, hence tapping their land here).
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	g.tap_permanent(theirs)
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, reset, []))
	resolve_stack()
	assert_false(l1.tapped)
	assert_false(l2.tapped)
	assert_true(theirs.tapped, "only yours")

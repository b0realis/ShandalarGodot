extends GameTest
## Wave-27 tests: Arabian Nights' lands and island-dwellers — utility
## lands (Bazaar of Baghdad, Diamond Valley, Elephant Graveyard, Desert,
## Island of Wak-Wak), the "no Islands, no creature" clause (Dandan,
## Merchant Ship, and the Sea Serpent/Pirate Ship rows it lifts), desert
## flavour (Desert Nomads), a landwalk aura (Fishliver Oil), base-power
## setters (Singing Tree, Sorceress Queen) and the fickle Ghazban Ogre.


func test_bazaar_of_baghdad_digs_and_dumps() -> void:
	var bazaar := put_battlefield(0, "Bazaar of Baghdad")
	give_hand(0, "Forest")
	give_hand(0, "Forest")
	assert_refused(g.tap_for_mana(0, bazaar), "no mana ability")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, bazaar, 0, []))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 1, "2 seeded + 2 drawn - 3 discarded")
	assert_eq(g.players[0].graveyard.size(), 3)


func test_diamond_valley_cashes_creatures_for_life() -> void:
	var valley := put_battlefield(0, "Diamond Valley")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, valley, 0, []), "no creature to sacrifice")
	var wall := put_battlefield(0, "Wall of Wood")   # 0/3
	assert_ok(g.activate_ability(0, valley, 0, []))
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[0].life, 23)


func test_elephant_graveyard_only_saves_elephants() -> void:
	var graveyard := put_battlefield(0, "Elephant Graveyard")
	var bear := put_battlefield(0, "Grizzly Bears")
	var mammoth := put_battlefield(0, "War Mammoth")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, graveyard, 0, [TargetRef.card(bear)]),
		"Illegal target")
	assert_ok(g.activate_ability(0, graveyard, 0, [TargetRef.card(mammoth)]))
	resolve_stack()
	g.destroy(mammoth)
	assert_eq(mammoth.zone, Mtg.Zone.BATTLEFIELD)


func test_desert_shoots_an_attacker_at_end_of_combat() -> void:
	var desert := put_battlefield(0, "Desert")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [bear.id]))
	assert_ok(g.pass_priority(1))
	assert_refused(g.activate_ability(0, desert, 0, [TargetRef.card(bear)]),
		"end of combat step")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_ok(g.pass_priority(1))
	assert_ok(g.activate_ability(0, desert, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.damage, 1)


func test_desert_still_taps_for_mana() -> void:
	var desert := put_battlefield(0, "Desert")
	assert_ok(g.tap_for_mana(0, desert))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 1)


func test_dandan_dies_without_islands() -> void:
	var dandan := put_battlefield(0, "Dandân")
	g.check_state_based_actions()
	assert_eq(dandan.zone, Mtg.Zone.GRAVEYARD, "no Islands, no fish")


func test_dandan_lives_and_needs_an_island_to_attack() -> void:
	put_battlefield(0, "Island")
	var dandan := put_battlefield(0, "Dandân")
	g.check_state_based_actions()
	assert_eq(dandan.zone, Mtg.Zone.BATTLEFIELD)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [dandan.id]), "Island")
	put_battlefield(1, "Island")
	assert_ok(g.declare_attackers(0, [dandan.id]))


func test_sea_serpent_now_drowns_without_islands() -> void:
	# The Sea Serpent / Pirate Ship ledger rows are lifted: the printed
	# "when you control no Islands, sacrifice this" now works.
	var island := put_battlefield(0, "Island")
	var serpent := put_battlefield(0, "Sea Serpent")
	g.check_state_based_actions()
	assert_eq(serpent.zone, Mtg.Zone.BATTLEFIELD)
	g.destroy(island, false)
	g.check_state_based_actions()
	assert_eq(serpent.zone, Mtg.Zone.GRAVEYARD)


func test_merchant_ship_pays_when_unblocked() -> void:
	put_battlefield(0, "Island")
	put_battlefield(1, "Island")
	var ship := put_battlefield(0, "Merchant Ship")
	run_combat([ship.id])
	assert_eq(g.players[0].life, 22)
	assert_eq(g.players[1].life, 20, "a 0/2 deals no damage")


func test_desert_nomads_walk_deserts_and_shrug_them_off() -> void:
	var nomads := put_battlefield(0, "Desert Nomads")
	assert_true(nomads.cur_landwalk.has("desert"))
	var desert := put_battlefield(1, "Desert")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [nomads.id]))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, desert, 0, [TargetRef.card(nomads)]))
	resolve_stack()
	assert_eq(nomads.damage, 0, "Deserts can't hurt them")


func test_fishliver_oil_grants_islandwalk() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var oil := give_hand(0, "Fishliver Oil")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, oil, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.cur_landwalk.has("island"))
	put_battlefield(1, "Island")
	var blocker := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {blocker.id: bear.id}), "islandwalk")


func test_island_of_wak_wak_grounds_a_fliers_power() -> void:
	var island := put_battlefield(0, "Island of Wak-Wak")
	var angel := put_battlefield(1, "Serra Angel")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, island, 0, [TargetRef.card(bear)]),
		"Illegal target")
	assert_ok(g.activate_ability(0, island, 0, [TargetRef.card(angel)]))
	resolve_stack()
	assert_eq(angel.cur_power, 0)
	assert_eq(angel.cur_toughness, 4, "toughness untouched")


func test_singing_tree_blanks_an_attacker() -> void:
	var tree := put_battlefield(0, "Singing Tree")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [bear.id]))
	assert_ok(g.pass_priority(1))
	assert_ok(g.activate_ability(0, tree, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_power, 0)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 20)


func test_sorceress_queen_shrinks_a_fatty() -> void:
	var queen := put_battlefield(0, "Sorceress Queen")
	var serra := put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, queen, 0, [TargetRef.card(queen)]),
		"Illegal target")
	assert_ok(g.activate_ability(0, queen, 0, [TargetRef.card(serra)]))
	resolve_stack()
	assert_eq(serra.cur_power, 0)
	assert_eq(serra.cur_toughness, 2)


func test_ghazban_ogre_defects_to_the_life_leader() -> void:
	var ogre := put_battlefield(0, "Ghazbán Ogre")
	g.adjust_life(1, 5)
	advance_to_next_turn()
	advance_to_next_turn()   # player 0's upkeep
	resolve_stack()
	assert_eq(ogre.controller_id, 1, "the richest player takes it")

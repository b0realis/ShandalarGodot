extends GameTest
## Wave-33 tests: The Dark's second shelf — graveyard hate on a body
## (Eater of the Dead), painful pumps (Electric Eel, Wormwood Treefolk),
## landwalk granting and stripping (Scarwood Hag, Hidden Path), tribal
## drawbacks and payoffs (Goblins of the Flarg, Orc General), spell-proof
## bodies (Lurker), targeted removal (Merfolk Assassin), a fight ability
## (Tracker) and two artifacts (Living Armor, Standing Stones).


func test_eater_of_the_dead_untaps_itself_for_free() -> void:
	var eater := put_battlefield(0, "Eater of the Dead")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.destroy(bear, false)
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, eater, 0, [TargetRef.card(bear)]),
		"only while it is tapped")
	g.tap_permanent(eater)
	assert_ok(g.activate_ability(0, eater, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.EXILE)
	assert_false(eater.tapped, "it untaps itself")


func test_electric_eel_shocks_its_controller() -> void:
	var eel := give_hand(0, "Electric Eel")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, eel, []))
	resolve_stack()
	assert_eq(g.players[0].life, 19, "the enters-the-battlefield sting")
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.activate_ability(0, eel, 0, []))
	resolve_stack()
	assert_eq(eel.cur_power, 3)
	assert_eq(g.players[0].life, 18)


func test_goblins_of_the_flarg_flee_from_dwarves() -> void:
	var goblins := put_battlefield(0, "Goblins of the Flarg")
	assert_true(goblins.cur_landwalk.has("mountain"))
	g.check_state_based_actions()
	assert_eq(goblins.zone, Mtg.Zone.BATTLEFIELD)
	put_battlefield(0, "Dwarven Warriors")
	g.check_state_based_actions()
	assert_eq(goblins.zone, Mtg.Zone.GRAVEYARD, "a Dwarf drives them off")


func test_hidden_path_lets_green_walk() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var lions := put_battlefield(0, "Savannah Lions")
	put_battlefield(0, "Hidden Path")
	g.recalculate()
	assert_true(bear.cur_landwalk.has("forest"))
	assert_false(lions.cur_landwalk.has("forest"), "white isn't green")


func test_living_armor_scales_with_the_target() -> void:
	var armor := put_battlefield(0, "Living Armor")
	var angel := put_battlefield(0, "Serra Angel")   # {3}{W}{W} = 5
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, armor, 0, [TargetRef.card(angel)]))
	assert_eq(armor.zone, Mtg.Zone.GRAVEYARD, "sacrificed as a cost")
	resolve_stack()
	assert_eq(angel.cur_toughness, 9, "4 + five +0/+1 counters")
	assert_eq(angel.cur_power, 4, "power untouched")


func test_lurker_cannot_be_targeted_before_it_fights() -> void:
	var lurker := put_battlefield(0, "Lurker")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_refused(g.cast_spell(1, bolt, [TargetRef.card(lurker)]), "Illegal target")


func test_lurker_becomes_targetable_after_attacking() -> void:
	var lurker := put_battlefield(0, "Lurker")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [lurker.id]))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(lurker)]))
	resolve_stack()
	assert_eq(lurker.zone, Mtg.Zone.GRAVEYARD, "3 damage on a 2/3")


func test_merfolk_assassin_only_kills_islandwalkers() -> void:
	var assassin := put_battlefield(0, "Merfolk Assassin")
	var bear := put_battlefield(1, "Grizzly Bears")
	var walker := put_battlefield(1, "Merfolk of the Pearl Trident")
	var oil := give_hand(1, "Fishliver Oil")
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.U)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, oil, [TargetRef.card(walker)]))
	resolve_stack()
	assert_ok(g.pass_priority(1))
	assert_refused(g.activate_ability(0, assassin, 0, [TargetRef.card(bear)]),
		"Illegal target")
	assert_ok(g.activate_ability(0, assassin, 0, [TargetRef.card(walker)]))
	resolve_stack()
	assert_eq(walker.zone, Mtg.Zone.GRAVEYARD)


func test_orc_general_eats_a_goblin_to_pump_the_orcs() -> void:
	var general := put_battlefield(0, "Orc General")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, general, 0, []),
		"no other Orc or Goblin to sacrifice")
	var goblin := put_battlefield(0, "Mons's Goblin Raiders")
	var orc := put_battlefield(0, "Orcish Artillery")
	assert_ok(g.activate_ability(0, general, 0, []))
	assert_eq(goblin.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(orc.cur_power, 2, "1/3 Artillery gets +1/+1")
	assert_eq(orc.cur_toughness, 4)
	assert_eq(general.cur_power, 2, "'other' Orcs only")


func test_scarwood_hag_gives_and_takes_forestwalk() -> void:
	var hag := put_battlefield(0, "Scarwood Hag")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 4)
	assert_ok(g.activate_ability(0, hag, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.cur_landwalk.has("forest"))
	g.untap_permanent(hag)
	assert_ok(g.activate_ability(0, hag, 1, [TargetRef.card(bear)]))
	resolve_stack()
	assert_false(bear.cur_landwalk.has("forest"), "the loss beats the grant")


func test_standing_stones_costs_mana_and_life() -> void:
	var stones := put_battlefield(0, "Standing Stones")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.tap_for_mana(0, stones), "not enough floating mana")
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.tap_for_mana(0, stones))
	assert_eq(g.players[0].life, 19)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.W), 1)


func test_tracker_fights() -> void:
	var tracker := put_battlefield(0, "Tracker")     # 2/2
	var minotaur := put_battlefield(1, "Hurloon Minotaur")   # 2/3
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.activate_ability(0, tracker, 0, [TargetRef.card(minotaur)]))
	resolve_stack()
	assert_eq(minotaur.damage, 2)
	assert_eq(tracker.zone, Mtg.Zone.GRAVEYARD, "the Minotaur hits back for 2")


func test_wormwood_treefolk_walks_at_a_price() -> void:
	var treefolk := put_battlefield(0, "Wormwood Treefolk")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.activate_ability(0, treefolk, 0, []))
	resolve_stack()
	assert_true(treefolk.cur_landwalk.has("forest"))
	assert_eq(g.players[0].life, 18)
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.activate_ability(0, treefolk, 1, []))
	resolve_stack()
	assert_true(treefolk.cur_landwalk.has("swamp"))
	assert_eq(g.players[0].life, 16)

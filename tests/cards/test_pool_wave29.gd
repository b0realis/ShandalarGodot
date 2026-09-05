extends GameTest
## Wave-29 tests: source-filtered damage immunity (Wall of Vapor, Wall of
## Shadows, Wall of Putrid Flesh, Argothian Pixies, Argothian Treefolk),
## a graveyard-scaling wall (Wall of Tombstones), the Elder Dragon cycle
## and its upkeep rent (Chromium, Nicol Bolas, Palladia-Mors, Vaevictis
## Asmadi, Arcades Sabboth) and the unkillable Clergy of the Holy Nimbus.


func test_wall_of_vapor_shrugs_off_what_it_blocks() -> void:
	var wall := put_battlefield(0, "Wall of Vapor")   # 0/1
	var attacker := put_battlefield(1, "Hurloon Minotaur")   # 2/3
	advance_to_next_turn()
	run_combat([attacker.id], {wall.id: attacker.id})
	assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD, "a 0/1 that survives a 2/3")
	assert_eq(wall.damage, 0)


func test_wall_of_vapor_still_takes_burn() -> void:
	var wall := put_battlefield(0, "Wall of Vapor")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(wall)]))
	resolve_stack()
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD, "only its blockees are shrugged off")


func test_wall_of_shadows_survives_anything_it_blocks() -> void:
	var wall := put_battlefield(0, "Wall of Shadows")   # 0/1
	var giant := put_battlefield(1, "Craw Giant")       # 6/4 trample
	advance_to_next_turn()
	run_combat([giant.id], {wall.id: giant.id})
	assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD)


func test_wall_of_putrid_flesh_ignores_enchanted_attackers() -> void:
	var wall := put_battlefield(0, "Wall of Putrid Flesh")   # 2/4
	var bear := put_battlefield(1, "Grizzly Bears")
	var aura := give_hand(1, "Unholy Strength")
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(1, aura, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_power, 4)
	run_combat([bear.id], {wall.id: bear.id})
	assert_eq(wall.damage, 0, "enchanted creatures can't hurt it")
	assert_eq(bear.damage, 2, "the wall still hits back")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "a 4/3 survives 2")


func test_wall_of_putrid_flesh_has_protection_from_white() -> void:
	var wall := put_battlefield(0, "Wall of Putrid Flesh")
	var swords := give_hand(1, "Swords to Plowshares")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(1, Mtg.ManaColor.W)
	assert_ok(g.pass_priority(0))
	assert_refused(g.cast_spell(1, swords, [TargetRef.card(wall)]), "Illegal target")


func test_wall_of_tombstones_grows_with_the_graveyard() -> void:
	var wall := put_battlefield(0, "Wall of Tombstones")
	assert_eq(wall.cur_toughness, 1, "1 plus an empty graveyard")
	var bear := put_battlefield(0, "Grizzly Bears")
	var lions := put_battlefield(0, "Savannah Lions")
	g.destroy(bear, false)
	g.destroy(lions, false)
	g.recalculate()
	assert_eq(wall.cur_toughness, 1,
		"the value is locked in at upkeep, not tracked continuously")
	advance_to_next_turn()
	advance_to_next_turn()
	resolve_stack()
	assert_eq(wall.cur_toughness, 3, "1 plus the two creature cards")


func test_argothian_pixies_dodge_artifact_creatures() -> void:
	var pixies := put_battlefield(0, "Argothian Pixies")   # 2/1
	var golem := put_battlefield(1, "Obsianus Golem")      # 4/6 artifact
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [golem.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {pixies.id: golem.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(pixies.zone, Mtg.Zone.BATTLEFIELD, "artifact damage bounces off")


func test_argothian_pixies_cant_be_blocked_by_artifacts() -> void:
	var pixies := put_battlefield(0, "Argothian Pixies")
	var golem := put_battlefield(1, "Obsianus Golem")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [pixies.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {golem.id: pixies.id}), "artifact")


func test_argothian_treefolk_ignores_artifact_sources() -> void:
	var treefolk := put_battlefield(0, "Argothian Treefolk")
	var tim := put_battlefield(1, "Rod of Ruin")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(1, Mtg.ManaColor.C, 3)
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, tim, 0, [TargetRef.card(treefolk)]))
	resolve_stack()
	assert_eq(treefolk.damage, 0)


func test_elder_dragons_pay_rent_or_die() -> void:
	var bolas := put_battlefield(0, "Nicol Bolas")
	assert_true(bolas.has_keyword(Mtg.Keyword.FLYING))
	advance_to_next_turn()
	advance_to_next_turn()   # back to player 0's upkeep with no mana
	assert_eq(bolas.zone, Mtg.Zone.GRAVEYARD, "no {U}{B}{R}, no dragon")


func test_nicol_bolas_empties_a_hand_on_connect() -> void:
	var bolas := put_battlefield(0, "Nicol Bolas")
	give_hand(1, "Forest")
	give_hand(1, "Forest")
	put_battlefield(0, "Island")
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Mountain")
	run_combat([bolas.id])
	assert_eq(g.players[1].life, 13)
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 0, "the whole hand is discarded")


func test_vaevictis_asmadi_pumps_three_ways() -> void:
	var vaevictis := put_battlefield(0, "Vaevictis Asmadi")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, vaevictis, 0, []))
	assert_ok(g.activate_ability(0, vaevictis, 1, []))
	assert_ok(g.activate_ability(0, vaevictis, 2, []))
	resolve_stack()
	assert_eq(vaevictis.cur_power, 10)


func test_arcades_sabboth_walls_up_the_team() -> void:
	var arcades := put_battlefield(0, "Arcades Sabboth")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_eq(bear.cur_toughness, 4, "untapped and not attacking: +0/+2")
	g.tap_permanent(bear)
	assert_eq(bear.cur_toughness, 2, "tapped creatures get nothing")


func test_palladia_mors_and_chromium_are_registered() -> void:
	assert_true(CardRegistry.get_card("Palladia-Mors").has_keyword(Mtg.Keyword.TRAMPLE))
	assert_eq(CardRegistry.get_card("Chromium").rampage, 2)


func test_clergy_of_the_holy_nimbus_keeps_coming_back() -> void:
	var clergy := put_battlefield(0, "Clergy of the Holy Nimbus")
	g.destroy(clergy)
	assert_eq(clergy.zone, Mtg.Zone.BATTLEFIELD, "it regenerates itself")
	g.untap_permanent(clergy)
	g.destroy(clergy)
	assert_eq(clergy.zone, Mtg.Zone.BATTLEFIELD, "every time")


func test_only_the_opponent_can_switch_off_the_clergy() -> void:
	var clergy := put_battlefield(0, "Clergy of the Holy Nimbus")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.activate_ability(0, clergy, 0, []), "only your opponents")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(1, clergy, 0, []))
	resolve_stack()
	g.destroy(clergy)
	assert_eq(clergy.zone, Mtg.Zone.GRAVEYARD)

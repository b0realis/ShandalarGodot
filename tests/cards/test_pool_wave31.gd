extends GameTest
## Wave-31 tests: Antiquities' artifact-matters shell — the Urzatron
## lands, graveyard recycling (Feldon's Cane), artifact sacrifice engines
## (Priest of Yawgmoth, Dwarven Weaponsmith, Ashnod's Transmogrant, Gate
## to Phyrexia), artifact-count bodies (Citanul Druid, Gaea's Avenger) and
## the tapped-artifact punishers (Powerleech, Haunting Wind).


func test_urza_lands_alone_make_one_mana() -> void:
	var mine := put_battlefield(0, "Urza's Mine")
	assert_ok(g.tap_for_mana(0, mine))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 1)


func test_full_urzatron_pays_seven() -> void:
	var mine := put_battlefield(0, "Urza's Mine")
	var plant := put_battlefield(0, "Urza's Power Plant")
	var tower := put_battlefield(0, "Urza's Tower")
	assert_ok(g.tap_for_mana(0, mine))
	assert_ok(g.tap_for_mana(0, plant))
	assert_ok(g.tap_for_mana(0, tower))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 7,
		"2 + 2 + 3 once all three are assembled")


func test_urzatron_needs_all_three_on_your_side() -> void:
	var tower := put_battlefield(0, "Urza's Tower")
	put_battlefield(0, "Urza's Mine")
	put_battlefield(1, "Urza's Power Plant")   # theirs doesn't help
	assert_ok(g.tap_for_mana(0, tower))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 1)


func test_feldons_cane_recycles_the_graveyard() -> void:
	var cane := put_battlefield(0, "Feldon's Cane")
	var bear := put_battlefield(0, "Grizzly Bears")
	g.destroy(bear, false)
	var library_before := g.players[0].library.size()
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, cane, 0, []))
	assert_eq(cane.zone, Mtg.Zone.EXILE, "exiled as part of the cost")
	resolve_stack()
	assert_eq(g.players[0].graveyard.size(), 0)
	assert_eq(g.players[0].library.size(), library_before + 1)


func test_priest_of_yawgmoth_scales_with_what_it_eats() -> void:
	var priest := put_battlefield(0, "Priest of Yawgmoth")
	var golem := put_battlefield(0, "Obsianus Golem")   # {6}
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.tap_for_mana(0, priest))
	assert_eq(golem.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 6)


func test_dwarven_weaponsmith_only_works_at_upkeep() -> void:
	var smith := put_battlefield(0, "Dwarven Weaponsmith")
	put_battlefield(0, "Sol Ring")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, smith, 0, [TargetRef.card(bear)]),
		"upkeep")
	advance_to_next_turn()              # player 1's turn
	advance_to_step(Mtg.Step.UPKEEP)    # …then player 0's own upkeep
	assert_ok(g.activate_ability(0, smith, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_power, 3)
	assert_eq(bear.cur_toughness, 3)


func test_ashnods_transmogrant_makes_an_artifact_creature() -> void:
	var transmogrant := put_battlefield(0, "Ashnod's Transmogrant")
	var bear := put_battlefield(1, "Grizzly Bears")
	var golem := put_battlefield(1, "Obsianus Golem")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, transmogrant, 0, [TargetRef.card(golem)]),
		"Illegal target")
	assert_ok(g.activate_ability(0, transmogrant, 0, [TargetRef.card(bear)]))
	assert_eq(transmogrant.zone, Mtg.Zone.GRAVEYARD, "sacrificed as a cost")
	resolve_stack()
	assert_eq(bear.cur_power, 3)
	assert_true(bear.is_type(Mtg.CardType.ARTIFACT), "and now an artifact")


func test_gate_to_phyrexia_eats_a_creature_for_an_artifact() -> void:
	var gate := put_battlefield(0, "Gate to Phyrexia")
	var bear := put_battlefield(0, "Grizzly Bears")
	var icy := put_battlefield(1, "Icy Manipulator")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, gate, 0, [TargetRef.card(icy)]), "upkeep")
	advance_to_next_turn()              # player 1's turn
	advance_to_step(Mtg.Step.UPKEEP)    # …then player 0's own upkeep
	assert_ok(g.activate_ability(0, gate, 0, [TargetRef.card(icy)]))
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "a creature was the cost")
	resolve_stack()
	assert_eq(icy.zone, Mtg.Zone.GRAVEYARD)
	assert_refused(g.activate_ability(0, gate, 0, [TargetRef.card(icy)]),
		"once each turn")


func test_citanul_druid_grows_off_their_artifacts() -> void:
	var druid := put_battlefield(0, "Citanul Druid")
	var ring := give_hand(1, "Sol Ring")
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, ring, []))
	resolve_stack()
	assert_eq(druid.cur_power, 2)
	assert_eq(druid.cur_toughness, 2)


func test_gaeas_avenger_counts_their_artifacts() -> void:
	var avenger := put_battlefield(0, "Gaea's Avenger")
	assert_eq(avenger.cur_power, 1, "1 plus nothing")
	put_battlefield(1, "Sol Ring")
	put_battlefield(1, "Icy Manipulator")
	put_battlefield(0, "Sol Ring")   # yours don't count
	g.recalculate()
	assert_eq(avenger.cur_power, 3)
	assert_eq(avenger.cur_toughness, 3)


func test_powerleech_pays_when_their_artifacts_tap() -> void:
	put_battlefield(0, "Powerleech")
	var theirs := put_battlefield(1, "Sol Ring")
	var mine := put_battlefield(0, "Sol Ring")
	assert_ok(g.tap_for_mana(0, mine))
	resolve_stack()
	assert_eq(g.players[0].life, 20, "your own artifacts pay nothing")
	advance_to_next_turn()
	assert_ok(g.tap_for_mana(1, theirs))
	resolve_stack()
	assert_eq(g.players[0].life, 21)


func test_haunting_wind_stings_everyone() -> void:
	put_battlefield(0, "Haunting Wind")
	var theirs := put_battlefield(1, "Sol Ring")
	var mine := put_battlefield(0, "Sol Ring")
	assert_ok(g.tap_for_mana(0, mine))
	resolve_stack()
	assert_eq(g.players[0].life, 19, "symmetric — even yours")
	advance_to_next_turn()
	assert_ok(g.tap_for_mana(1, theirs))
	resolve_stack()
	assert_eq(g.players[1].life, 19)

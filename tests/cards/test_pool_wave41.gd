extends GameTest
## Wave-41 tests: Fourth Edition's second shelf — untap-locked fatties
## (Colossus of Sardia, Magnetic Mountain), a doomsday clock (Armageddon
## Clock), targeted discard (Rag Man), artifact animation (Xenic
## Poltergeist), combat tricks (Ebony Horse, Time Elemental), land taxes
## (Erosion), hand-size and enters-tapped prisons (Cursed Rack, Kismet),
## carrion counters (Osai Vultures) and library peeking (Visions).


func test_colossus_of_sardia_never_untaps_on_its_own() -> void:
	var colossus := put_battlefield(0, "Colossus of Sardia")
	assert_true(colossus.has_keyword(Mtg.Keyword.TRAMPLE))
	g.tap_permanent(colossus)
	advance_to_next_turn()             # player 1's turn
	advance_to_step(Mtg.Step.UPKEEP)   # …then player 0's own upkeep
	assert_true(colossus.tapped, "it doesn't untap during your untap step")
	add_mana(0, Mtg.ManaColor.C, 9)
	assert_ok(g.activate_ability(0, colossus, 0, []))
	resolve_stack()
	assert_false(colossus.tapped)


func test_armageddon_clock_ticks_and_burns() -> void:
	var clock := put_battlefield(0, "Armageddon Clock")
	advance_to_next_turn()
	advance_to_next_turn()   # player 0's upkeep + draw
	resolve_stack()
	assert_eq(clock.counters.get("doom", 0), 1)
	assert_eq(g.players[0].life, 19, "one doom counter, one damage each")
	assert_eq(g.players[1].life, 19)


func test_armageddon_clock_can_be_wound_back() -> void:
	var clock := put_battlefield(0, "Armageddon Clock")
	g.add_counters(clock, "doom", 3)
	# The game opens in player 0's own upkeep, and the Clock arrived after
	# that upkeep's trigger window — so no tick happens here.
	advance_to_step(Mtg.Step.UPKEEP)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, clock, 0, []))
	resolve_stack()
	assert_eq(clock.counters.get("doom", 0), 2)


func test_rag_man_strips_a_creature_card() -> void:
	var rag := put_battlefield(0, "Rag Man")
	give_hand(1, "Grizzly Bears")
	give_hand(1, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_ok(g.activate_ability(0, rag, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 1, "the creature went")
	assert_eq(g.players[1].graveyard.size(), 1)


func test_xenic_poltergeist_animates_an_artifact() -> void:
	var poltergeist := put_battlefield(0, "Xenic Poltergeist")
	var golem := put_battlefield(1, "Obsianus Golem")   # already a creature
	var icy := put_battlefield(1, "Icy Manipulator")    # {4}
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, poltergeist, 0, [TargetRef.card(golem)]),
		"Illegal target")
	assert_ok(g.activate_ability(0, poltergeist, 0, [TargetRef.card(icy)]))
	resolve_stack()
	assert_true(icy.is_creature())
	assert_eq(icy.cur_power, 4)
	assert_eq(icy.cur_toughness, 4)


func test_ebony_horse_unwinds_an_attacker() -> void:
	var horse := put_battlefield(0, "Ebony Horse")
	var bear := put_battlefield(0, "Grizzly Bears")
	var blocker := put_battlefield(1, "Hurloon Minotaur")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	assert_true(bear.tapped)
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {blocker.id: bear.id}))
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, horse, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_false(bear.tapped, "untapped and ready to block")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bear.damage, 0, "and it takes no combat damage")
	assert_eq(blocker.damage, 0, "nor deals any")


func test_erosion_taxes_the_enchanted_land() -> void:
	var forest := put_battlefield(1, "Forest")
	var erosion := give_hand(0, "Erosion")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 3)
	assert_ok(g.cast_spell(0, erosion, [TargetRef.card(forest)]))
	resolve_stack()
	advance_to_next_turn()   # player 1's upkeep
	resolve_stack()
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD, "the {1} was paid with the land itself")
	assert_true(forest.tapped, "auto-tapped to pay the toll")


func test_magnetic_mountain_freezes_blue() -> void:
	put_battlefield(0, "Magnetic Mountain")
	var wizard := put_battlefield(1, "Prodigal Sorcerer")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.tap_permanent(wizard)
	g.tap_permanent(bear)
	advance_to_next_turn()
	assert_true(wizard.tapped, "blue creatures stay down")
	assert_false(bear.tapped)


func test_cursed_rack_shrinks_a_hand() -> void:
	var rack := give_hand(0, "Cursed Rack")
	for i in 6:
		give_hand(1, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, rack, []))
	resolve_stack()
	assert_eq(g.players[1].max_hand_size, 4)
	advance_to_next_turn()   # player 1's turn: they draw, then discard at cleanup
	advance_to_next_turn()
	assert_eq(g.players[1].hand.size(), 4)


func test_kismet_taps_what_they_play() -> void:
	put_battlefield(0, "Kismet")
	var land := give_hand(1, "Forest")
	advance_to_next_turn()
	assert_ok(g.play_land(1, land))
	resolve_stack()
	assert_true(land.tapped)
	var mine := give_hand(0, "Forest")
	advance_to_next_turn()
	assert_ok(g.play_land(0, mine))
	resolve_stack()
	assert_false(mine.tapped, "only your opponents")


func test_osai_vultures_feed_on_the_dead() -> void:
	var vultures := put_battlefield(0, "Osai Vultures")
	assert_true(vultures.has_keyword(Mtg.Keyword.FLYING))
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	g.destroy(a, false)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(vultures.counters.get("carrion", 0), 1)
	assert_refused(g.activate_ability(0, vultures, 0, []), "carrion counters to remove")
	g.destroy(b, false)
	advance_to_next_turn()
	advance_to_next_turn()
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(vultures.counters.get("carrion", 0), 1, "the second body was last turn")


func test_time_elemental_bounces_anything_unenchanted() -> void:
	var elemental := put_battlefield(0, "Time Elemental")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, elemental, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.HAND)


func test_time_elemental_immolates_itself_in_combat() -> void:
	var elemental := put_battlefield(0, "Time Elemental")
	run_combat([elemental.id])
	resolve_stack()
	assert_eq(elemental.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 15)


func test_visions_looks_without_touching() -> void:
	var visions := give_hand(0, "Visions")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	var library_before := g.players[1].library.size()
	assert_ok(g.cast_spell(0, visions, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].library.size(), library_before, "nothing moves")

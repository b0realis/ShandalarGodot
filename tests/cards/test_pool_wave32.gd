extends GameTest
## Wave-32 tests: Legends' utility legends and prevention shell —
## targeted removal (Ramses Overdark, Tetsuo Umezawa), aura-proof bodies
## (Bartel Runeaxe), aura payoffs (Rabid Wombat), land-count power
## (Dakkon Blackblade), reanimation and regeneration engines (Hell's
## Caretaker, Horror of Horrors), discard (Gwendlyn Di Corci), combat
## prevention (Angus Mackenzie, Lady Evangela, Horn of Deafening) and
## artifact tapping (Hyperion Blacksmith).


func test_ramses_overdark_kills_only_enchanted_creatures() -> void:
	var ramses := put_battlefield(0, "Ramses Overdark")
	var bear := put_battlefield(1, "Grizzly Bears")
	var lions := put_battlefield(1, "Savannah Lions")
	var aura := give_hand(0, "Unholy Strength")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	resolve_stack()
	assert_refused(g.activate_ability(0, ramses, 0, [TargetRef.card(lions)]),
		"Illegal target")
	assert_ok(g.activate_ability(0, ramses, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


func test_tetsuo_umezawa_kills_tapped_or_blocking() -> void:
	var tetsuo := put_battlefield(0, "Tetsuo Umezawa")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.activate_ability(0, tetsuo, 0, [TargetRef.card(bear)]),
		"Illegal target")
	g.tap_permanent(bear)
	assert_ok(g.activate_ability(0, tetsuo, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


func test_tetsuo_cannot_be_enchanted() -> void:
	var tetsuo := put_battlefield(0, "Tetsuo Umezawa")
	var aura := give_hand(0, "Holy Strength")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_refused(g.cast_spell(0, aura, [TargetRef.card(tetsuo)]), "Illegal target")


func test_bartel_runeaxe_shrugs_off_auras() -> void:
	var bartel := put_battlefield(0, "Bartel Runeaxe")
	assert_true(bartel.has_keyword(Mtg.Keyword.VIGILANCE))
	var paralyze := give_hand(1, "Paralyze")
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.B)
	assert_refused(g.cast_spell(1, paralyze, [TargetRef.card(bartel)]), "Illegal target")


func test_rabid_wombat_grows_per_aura() -> void:
	var wombat := put_battlefield(0, "Rabid Wombat")
	assert_eq(wombat.cur_power, 0)
	var aura := give_hand(0, "Holy Strength")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(wombat)]))
	resolve_stack()
	assert_eq(wombat.cur_power, 3, "0 +1 from the aura +2 from its own text")
	assert_eq(wombat.cur_toughness, 5, "1 +2 from the aura +2 from its own text")


func test_dakkon_blackblade_counts_lands() -> void:
	var dakkon := put_battlefield(0, "Dakkon Blackblade")
	assert_eq(dakkon.cur_power, 0, "no lands, no Dakkon")
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Island")
	put_battlefield(0, "Plains")
	put_battlefield(1, "Forest")   # theirs don't count
	g.recalculate()
	assert_eq(dakkon.cur_power, 3)
	assert_eq(dakkon.cur_toughness, 3)


func test_hells_caretaker_reanimates_at_upkeep() -> void:
	var caretaker := put_battlefield(0, "Hell's Caretaker")
	var fodder := put_battlefield(0, "Mons's Goblin Raiders")
	var angel := put_battlefield(0, "Serra Angel")
	g.destroy(angel, false)
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, caretaker, 0, [TargetRef.card(angel)]),
		"upkeep")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.UPKEEP)
	assert_ok(g.activate_ability(0, caretaker, 0, [TargetRef.card(angel)]))
	assert_eq(fodder.zone, Mtg.Zone.GRAVEYARD, "a creature was the cost")
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.BATTLEFIELD)


func test_horror_of_horrors_eats_swamps_to_save_black() -> void:
	var horror := put_battlefield(0, "Horror of Horrors")
	var zombies := put_battlefield(0, "Scathe Zombies")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, horror, 0, [TargetRef.card(zombies)]),
		"no Swamp to sacrifice")
	var swamp := put_battlefield(0, "Swamp")
	assert_refused(g.activate_ability(0, horror, 0, [TargetRef.card(bear)]),
		"Illegal target")
	assert_ok(g.activate_ability(0, horror, 0, [TargetRef.card(zombies)]))
	assert_eq(swamp.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	g.destroy(zombies)
	assert_eq(zombies.zone, Mtg.Zone.BATTLEFIELD)


func test_gwendlyn_di_corci_strips_a_card() -> void:
	var gwendlyn := put_battlefield(0, "Gwendlyn Di Corci")
	give_hand(1, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, gwendlyn, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 0)


func test_gwendlyn_only_works_on_your_turn() -> void:
	var gwendlyn := put_battlefield(0, "Gwendlyn Di Corci")
	give_hand(1, "Forest")
	advance_to_next_turn()
	assert_ok(g.pass_priority(1))
	assert_refused(g.activate_ability(0, gwendlyn, 0, [TargetRef.player(1)]),
		"only during your turn")


func test_angus_mackenzie_fogs_before_damage() -> void:
	var angus := put_battlefield(0, "Angus Mackenzie")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [bear.id]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.activate_ability(0, angus, 0, []))
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 20)


func test_angus_refuses_after_the_damage_step() -> void:
	var angus := put_battlefield(0, "Angus Mackenzie")
	advance_to_step(Mtg.Step.MAIN2)
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.U)
	assert_refused(g.activate_ability(0, angus, 0, []), "before the combat damage step")


func test_lady_evangela_blanks_one_attacker() -> void:
	var evangela := put_battlefield(0, "Lady Evangela")
	var bear := put_battlefield(1, "Grizzly Bears")
	var lions := put_battlefield(1, "Savannah Lions")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [bear.id, lions.id]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, evangela, 0, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 18, "only the Lions got through")


func test_horn_of_deafening_silences_a_creature() -> void:
	var horn := put_battlefield(0, "Horn of Deafening")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [bear.id]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, horn, 0, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 20)


func test_hyperion_blacksmith_taps_and_untaps_their_artifacts() -> void:
	var smith := put_battlefield(0, "Hyperion Blacksmith")
	var theirs := put_battlefield(1, "Sol Ring")
	var mine := put_battlefield(0, "Sol Ring")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, smith, 0, [TargetRef.card(mine)]),
		"Illegal target")
	assert_ok(g.activate_ability(0, smith, 0, [TargetRef.card(theirs)]))
	resolve_stack()
	assert_true(theirs.tapped)
	g.untap_permanent(smith)
	assert_ok(g.activate_ability(0, smith, 1, [TargetRef.card(theirs)]))
	resolve_stack()
	assert_false(theirs.tapped)

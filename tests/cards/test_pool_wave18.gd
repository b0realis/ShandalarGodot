extends GameTest
## Wave-18 tests: per-turn activation caps (Fire Drake, Vampire Bats),
## costed mana abilities (Coal Golem), sacrifice-another costs (Dark
## Heart of the Wood), one-shot untap locks (Barl's Cage), life-cost
## draw (Book of Rass), graveyard heists (Grave Robbers), artifact exile
## (Dust to Dust), hand attacks (Amnesia, Inquisition), mass shrink on a
## stick (Bone Flute) and the mountain-count burn (Eternal Flame).


func test_fire_drake_only_once_each_turn() -> void:
	var drake := put_battlefield(0, "Fire Drake")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.activate_ability(0, drake, 0, []))
	assert_refused(g.activate_ability(0, drake, 0, []), "once each turn")
	resolve_stack()
	assert_eq(drake.cur_power, 2)
	advance_to_next_turn()
	advance_to_next_turn()
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, drake, 0, []))


func test_vampire_bats_twice_each_turn() -> void:
	var bats := put_battlefield(0, "Vampire Bats")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_ok(g.activate_ability(0, bats, 0, []))
	assert_ok(g.activate_ability(0, bats, 0, []))
	assert_refused(g.activate_ability(0, bats, 0, []), "each turn")
	resolve_stack()
	assert_eq(bats.cur_power, 2, "0 + two pumps")


func test_coal_golem_burns_itself_for_mana() -> void:
	var golem := put_battlefield(0, "Coal Golem")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.tap_for_mana(0, golem), "not enough floating mana")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.tap_for_mana(0, golem))
	assert_eq(golem.zone, Mtg.Zone.GRAVEYARD, "sacrificed")
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.R), 3)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 0, "the {3} was spent")


func test_dark_heart_eats_forests_for_life() -> void:
	var heart := put_battlefield(0, "Dark Heart of the Wood")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, heart, 0, []), "no Forest to sacrifice")
	var forest := put_battlefield(0, "Forest")
	assert_ok(g.activate_ability(0, heart, 0, []))
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD, "the forest paid the price")
	resolve_stack()
	assert_eq(g.players[0].life, 23)


func test_barls_cage_skips_one_untap() -> void:
	var cage := put_battlefield(0, "Barl's Cage")
	var angel := put_battlefield(1, "Serra Angel")
	g.tap_permanent(angel)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, cage, 0, [TargetRef.card(angel)]))
	resolve_stack()
	advance_to_next_turn()   # the angel's controller's turn: no untap
	assert_true(angel.tapped, "caged through its untap step")
	advance_to_next_turn()
	advance_to_next_turn()   # their NEXT turn: untaps normally
	assert_false(angel.tapped, "the cage is a one-shot")


func test_book_of_rass_trades_life_for_cards() -> void:
	var book := put_battlefield(0, "Book of Rass")
	give_hand(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, book, 0, []))
	resolve_stack()
	assert_eq(g.players[0].life, 18)
	assert_eq(g.players[0].hand.size(), 2, "the seeded card + the drawn one")


func test_grave_robbers_heist() -> void:
	var robbers := put_battlefield(0, "Grave Robbers")
	var icy := put_battlefield(1, "Icy Manipulator")
	g.destroy(icy, false)
	assert_eq(icy.zone, Mtg.Zone.GRAVEYARD)
	var bear := put_battlefield(1, "Grizzly Bears")
	g.destroy(bear, false)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_refused(g.activate_ability(0, robbers, 0, [TargetRef.card(bear)]),
		"Illegal target")
	assert_ok(g.activate_ability(0, robbers, 0, [TargetRef.card(icy)]))
	resolve_stack()
	assert_eq(icy.zone, Mtg.Zone.EXILE, "the artifact is gone for good")
	assert_eq(g.players[0].life, 22)


func test_dust_to_dust_exiles_two_artifacts() -> void:
	var icy := put_battlefield(1, "Icy Manipulator")
	var disk := put_battlefield(1, "Sol Ring")
	var dust := give_hand(0, "Dust to Dust")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, dust, [TargetRef.card(icy), TargetRef.card(disk)]))
	resolve_stack()
	assert_eq(icy.zone, Mtg.Zone.EXILE)
	assert_eq(disk.zone, Mtg.Zone.EXILE)


func test_amnesia_wipes_the_spells_keeps_the_lands() -> void:
	give_hand(1, "Forest")
	give_hand(1, "Lightning Bolt")
	give_hand(1, "Grizzly Bears")
	var amnesia := give_hand(0, "Amnesia")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 3)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, amnesia, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 1, "only the Forest survives")
	assert_eq(g.players[1].graveyard.size(), 2)


func test_inquisition_counts_white_cards() -> void:
	give_hand(1, "Savannah Lions")
	give_hand(1, "Disenchant")
	give_hand(1, "Lightning Bolt")
	var inquisition := give_hand(0, "Inquisition")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, inquisition, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 18, "two white cards revealed")


func test_bone_flute_dampens_all_attacks() -> void:
	var flute := put_battlefield(0, "Bone Flute")
	var mine := put_battlefield(0, "War Mammoth")
	var theirs := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, flute, 0, []))
	resolve_stack()
	assert_eq(mine.cur_power, 2)
	assert_eq(theirs.cur_power, 1)


func test_eternal_flame_scales_with_mountains() -> void:
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	var flame := give_hand(0, "Eternal Flame")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	# "deals X damage to target opponent" — a real target since audit 2026-09.
	assert_ok(g.cast_spell(0, flame, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 17, "3 mountains → 3 damage")
	assert_eq(g.players[0].life, 18, "half X rounded up = 2 to the caster")

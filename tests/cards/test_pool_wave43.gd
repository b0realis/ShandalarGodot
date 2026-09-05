extends GameTest
## Wave-43 tests: the multi- and divided-targeting cluster — the first
## cards that need more than one TargetRef per effect. Pyrotechnics splits
## damage as you choose, Fireball splits it evenly (and pays for the
## privilege), Word of Binding and Winter Blast tap X bodies, Volcanic
## Eruption turns Mountains into a sweeper, Part Water hands out islandwalk
## by the armful, Candelabra of Tawnos untaps X lands, and Drafna's
## Restoration rebuilds a library's top from a graveyard.


func test_registry_loaded_wave43() -> void:
	for name in ["Pyrotechnics", "Word of Binding", "Winter Blast",
			"Volcanic Eruption", "Part Water", "Candelabra of Tawnos",
			"Drafna's Restoration"]:
		assert_not_null(CardRegistry.get_card(name), name)


# ------------------------------------------------------------ Pyrotechnics --

func test_pyrotechnics_splits_four_damage() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")     # 2/2
	var pyro := give_hand(0, "Pyrotechnics")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, pyro,
		[TargetRef.card(bear, 2), TargetRef.player(1, 2)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 18)


func test_pyrotechnics_cant_overspend_its_four() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var pyro := give_hand(0, "Pyrotechnics")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_refused(g.cast_spell(0, pyro,
		[TargetRef.card(bear, 3), TargetRef.player(1, 3)]), "add up to 4")


# ---------------------------------------------------------------- Fireball --

func test_fireball_divides_evenly_rounded_down() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var fireball := give_hand(0, "Fireball")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 6)   # X=5 plus {1} for the second target
	assert_ok(g.cast_spell(0, fireball,
		[TargetRef.card(bear), TargetRef.player(1)], 5))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "floor(5/2) = 2 kills a 2/2")
	assert_eq(g.players[1].life, 18, "the other half is 2 as well")


func test_fireball_charges_one_more_per_extra_target() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var fireball := give_hand(0, "Fireball")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_refused(g.cast_spell(0, fireball,
		[TargetRef.card(bear), TargetRef.player(1)], 4), "not enough mana")
	assert_ok(g.cast_spell(0, fireball, [TargetRef.player(1)], 4))
	resolve_stack()
	assert_eq(g.players[1].life, 16, "single target keeps all four")


# --------------------------------------------------------- Word of Binding --

func test_word_of_binding_taps_x_creatures() -> void:
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Hill Giant")
	var c := put_battlefield(1, "Mons's Goblin Raiders")
	var word := give_hand(0, "Word of Binding")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, word,
		[TargetRef.card(a), TargetRef.card(b), TargetRef.card(c)], 3))
	resolve_stack()
	assert_true(a.tapped and b.tapped and c.tapped)


# ------------------------------------------------------------ Winter Blast --

func test_winter_blast_taps_and_shoots_the_flyers() -> void:
	var flyer := put_battlefield(1, "Scryb Sprites")     # 1/1 flying
	var ground := put_battlefield(1, "Grizzly Bears")    # 2/2 no flying
	var blast := give_hand(0, "Winter Blast")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, blast,
		[TargetRef.card(flyer), TargetRef.card(ground)], 2))
	resolve_stack()
	assert_true(ground.tapped, "everything named gets tapped")
	assert_eq(ground.damage, 0, "but only the flyers take damage")
	assert_eq(flyer.zone, Mtg.Zone.GRAVEYARD, "2 damage kills the 1/1 flyer")


# ------------------------------------------------------- Volcanic Eruption --

func test_volcanic_eruption_blasts_for_the_mountains_it_buried() -> void:
	var m1 := put_battlefield(1, "Mountain")
	var m2 := put_battlefield(1, "Mountain")
	var bear := put_battlefield(1, "Grizzly Bears")
	var erupt := give_hand(0, "Volcanic Eruption")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 3)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, erupt, [TargetRef.card(m1), TargetRef.card(m2)], 2))
	resolve_stack()
	assert_eq(m1.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(m2.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "2 damage to each creature")
	assert_eq(g.players[0].life, 18, "and to each player, caster included")
	assert_eq(g.players[1].life, 18)


func test_volcanic_eruption_only_targets_mountains() -> void:
	var forest := put_battlefield(1, "Forest")
	var erupt := give_hand(0, "Volcanic Eruption")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 3)
	add_mana(0, Mtg.ManaColor.C, 1)
	# §6.10: `Illegal target (subtype).` — the card names the word itself
	# with `because()`, because "Mountain" is a land SUBTYPE.
	assert_refused(g.cast_spell(0, erupt, [TargetRef.card(forest)], 1),
		"Illegal target (subtype).")


# -------------------------------------------------------------- Part Water --

func test_part_water_hands_out_islandwalk() -> void:
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(0, "Hill Giant")
	put_battlefield(1, "Island")
	var part := give_hand(0, "Part Water")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 4)     # X=2 on {X}{X}{U} costs {4}{U}
	assert_ok(g.cast_spell(0, part, [TargetRef.card(a), TargetRef.card(b)], 2))
	resolve_stack()
	assert_true(a.cur_landwalk.has("island"))
	assert_true(b.cur_landwalk.has("island"))


func test_part_water_islandwalk_expires_at_cleanup() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var part := give_hand(0, "Part Water")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, part, [TargetRef.card(bear)], 1))
	resolve_stack()
	assert_true(bear.cur_landwalk.has("island"))
	advance_to_next_turn()
	assert_false(bear.cur_landwalk.has("island"))


# --------------------------------------------------- Candelabra of Tawnos --

func test_candelabra_untaps_x_lands() -> void:
	var candelabra := put_battlefield(0, "Candelabra of Tawnos")
	var a := put_battlefield(0, "Forest")
	var b := put_battlefield(0, "Island")
	g.tap_permanent(a)
	g.tap_permanent(b)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, candelabra, 0,
		[TargetRef.card(a), TargetRef.card(b)], 2))
	resolve_stack()
	assert_false(a.tapped)
	assert_false(b.tapped)


func test_candelabra_only_untaps_lands() -> void:
	var candelabra := put_battlefield(0, "Candelabra of Tawnos")
	var bear := put_battlefield(0, "Grizzly Bears")
	g.tap_permanent(bear)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_refused(g.activate_ability(0, candelabra, 0, [TargetRef.card(bear)], 1),
		"Illegal target (type).")


# ---------------------------------------------------- Drafna's Restoration --

func test_drafnas_restoration_stacks_the_library_top() -> void:
	var ring := give_hand(1, "Black Lotus")
	g.players[1].hand.erase(ring)
	ring.zone = Mtg.Zone.GRAVEYARD
	g.players[1].graveyard.append(ring)
	var drafna := give_hand(0, "Drafna's Restoration")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, drafna, [TargetRef.player(1), TargetRef.card(ring)]))
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[1].library.back(), ring, "it went on TOP")


func test_drafnas_restoration_only_takes_artifacts() -> void:
	var bear := give_hand(1, "Grizzly Bears")
	g.players[1].hand.erase(bear)
	bear.zone = Mtg.Zone.GRAVEYARD
	g.players[1].graveyard.append(bear)
	var drafna := give_hand(0, "Drafna's Restoration")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_refused(g.cast_spell(0, drafna, [TargetRef.player(1), TargetRef.card(bear)]),
		"Illegal target (type).")


func test_drafnas_restoration_may_take_none() -> void:
	var drafna := give_hand(0, "Drafna's Restoration")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, drafna, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(drafna.zone, Mtg.Zone.GRAVEYARD)

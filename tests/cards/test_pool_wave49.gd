extends GameTest
## Wave-49 tests: RESTRICTED MANA (CR 106.6) and TEXT CHANGES (CR 613
## layer 3) — two small engine systems that unblock a scattered handful of
## cards. Mana that may only be spent on one kind of spell now lives in its
## own keyed bucket in the pool; text changes ride on the instance and are
## re-applied at the top of every characteristics reset.


func test_registry_loaded_wave49() -> void:
	for name in ["Mishra's Workshop", "Metamorphosis", "Sunglasses of Urza",
			"North Star", "Magical Hack", "Sleight of Mind",
			"Quarum Trench Gnomes"]:
		assert_not_null(CardRegistry.get_card(name), name)


# ------------------------------------------------------- restricted mana --

func test_mishras_workshop_only_pays_for_artifacts() -> void:
	var shop := put_battlefield(0, "Mishra's Workshop")
	var bears := give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.tap_for_mana(0, shop))
	assert_eq(g.players[0].mana_pool.restricted_total("artifact"), 3)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 0,
		"none of it is loose mana")
	assert_refused(g.cast_spell(0, bears, []), "not enough mana")


func test_mishras_workshop_powers_out_an_artifact() -> void:
	var shop := put_battlefield(0, "Mishra's Workshop")
	var disk := give_hand(0, "Nevinyrral's Disk")   # {4}
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.tap_for_mana(0, shop))
	add_mana(0, Mtg.ManaColor.C)                    # one loose mana for the rest
	assert_ok(g.cast_spell(0, disk, []))
	resolve_stack()
	assert_eq(disk.zone, Mtg.Zone.BATTLEFIELD)


func test_restricted_mana_is_spent_before_loose_mana() -> void:
	var shop := put_battlefield(0, "Mishra's Workshop")
	var ring := give_hand(0, "Sol Ring")            # {1}
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.tap_for_mana(0, shop))
	add_mana(0, Mtg.ManaColor.G, 1)
	assert_ok(g.cast_spell(0, ring, []))
	resolve_stack()
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.G), 1,
		"the loose green survived — the restricted mana paid")
	assert_eq(g.players[0].mana_pool.restricted_total("artifact"), 2)


func test_metamorphosis_eats_a_creature_for_creature_mana() -> void:
	var fodder := put_battlefield(0, "Hill Giant")   # mana value 4
	var meta := give_hand(0, "Metamorphosis")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, meta, []))
	assert_eq(fodder.zone, Mtg.Zone.GRAVEYARD, "the cost is paid on casting")
	resolve_stack()
	assert_eq(g.players[0].mana_pool.restricted_total("creature"), 5,
		"1 plus the sacrificed creature's mana value")


func test_metamorphosis_needs_a_creature() -> void:
	var meta := give_hand(0, "Metamorphosis")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_refused(g.cast_spell(0, meta, []), "sacrifice")


# ------------------------------------------------------ Sunglasses of Urza --

func test_sunglasses_let_white_mana_pay_red() -> void:
	put_battlefield(0, "Sunglasses of Urza")
	var bolt := give_hand(0, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 17)


func test_without_sunglasses_white_cannot_pay_red() -> void:
	var bolt := give_hand(0, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_refused(g.cast_spell(0, bolt, [TargetRef.player(1)]), "not enough mana")


# ------------------------------------------------------------- North Star --

func test_north_star_pays_a_cost_with_any_mana() -> void:
	var star := put_battlefield(0, "North Star")
	var bolt := give_hand(0, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, star, 0, []))
	resolve_stack()
	assert_eq(g.players[0].any_color_spells, 1)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 17)
	assert_eq(g.players[0].any_color_spells, 0, "the charge was spent")


func test_north_stars_charge_expires_at_end_of_turn() -> void:
	var star := put_battlefield(0, "North Star")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, star, 0, []))
	resolve_stack()
	advance_to_next_turn()
	assert_eq(g.players[0].any_color_spells, 0)


# ------------------------------------------------------------ Magical Hack --

func test_magical_hack_retunes_a_land() -> void:
	put_battlefield(1, "Island")                 # what the opponent has
	var mountain := put_battlefield(1, "Mountain")
	var hack := give_hand(0, "Magical Hack")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, hack, [TargetRef.card(mountain)]))
	resolve_stack()
	assert_true(mountain.has_subtype("island"), "it is an Island now")
	assert_false(mountain.has_subtype("mountain"))
	assert_ok(g.tap_for_mana(1, mountain))
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.U), 1,
		"and it taps for blue")


func test_magical_hack_rewrites_landwalk() -> void:
	put_battlefield(1, "Island")
	var walker := put_battlefield(0, "Bog Wraith")   # swampwalk
	assert_true(walker.cur_landwalk.has("swamp"))
	var hack := give_hand(0, "Magical Hack")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, hack, [TargetRef.card(walker)]))
	resolve_stack()
	assert_true(walker.cur_landwalk.has("island"), "swampwalk became islandwalk")
	assert_false(walker.cur_landwalk.has("swamp"))


func test_magical_hack_needs_a_basic_land_word() -> void:
	var bears := put_battlefield(1, "Grizzly Bears")
	var hack := give_hand(0, "Magical Hack")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_refused(g.cast_spell(0, hack, [TargetRef.card(bears)]), "Illegal target")


# --------------------------------------------------------- Sleight of Mind --

func test_sleight_of_mind_repoints_protection() -> void:
	var knight := put_battlefield(1, "Black Knight")   # protection from white
	put_battlefield(0, "Plains")                       # we play white
	assert_true((knight.cur_protection & Mtg.ManaColor.W) != 0)
	var sleight := give_hand(0, "Sleight of Mind")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, sleight, [TargetRef.card(knight)]))
	resolve_stack()
	assert_eq(knight.cur_protection & Mtg.ManaColor.W, 0,
		"it no longer dodges our colour")
	assert_ne(knight.cur_protection, 0, "it still has protection from something")


func test_sleight_of_mind_needs_a_color_word() -> void:
	var bears := put_battlefield(1, "Grizzly Bears")
	var sleight := give_hand(0, "Sleight of Mind")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_refused(g.cast_spell(0, sleight, [TargetRef.card(bears)]),
		"Illegal target")


# --------------------------------------------------- Quarum Trench Gnomes --

func test_quarum_trench_gnomes_drain_a_plains() -> void:
	var gnomes := put_battlefield(0, "Quarum Trench Gnomes")
	var plains := put_battlefield(1, "Plains")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, gnomes, 0, [TargetRef.card(plains)]))
	resolve_stack()
	assert_ok(g.tap_for_mana(1, plains))
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.W), 0)
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.C), 1,
		"colorless instead of white")


func test_a_retuned_mana_ability_keeps_its_riders() -> void:
	# The "mana_color" change used to rebuild the ability from its colours
	# alone, dropping every rider — a Plains whose mana costs life, or
	# taps nothing, came out of the Gnomes' drain as a plain tap for {C}
	# (2026-09-02, latent: no Plains in the pool carries a rider yet).
	var gnomes := put_battlefield(0, "Quarum Trench Gnomes")
	var odd := CardData.new("Test Costly Plains", "", Mtg.CardType.LAND) \
		.with_subtypes(["plains"]) \
		.mana(ManaAbility.new(Mtg.ManaColor.W).with_life_cost(1)
			.and_also(Mtg.ManaColor.G))
	var land := put_synthetic(1, odd)
	assert_eq(land.cur_mana_abilities.size(), 1)
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, gnomes, 0, [TargetRef.card(land)]))
	resolve_stack()
	assert_eq(land.cur_mana_abilities.size(), 1, "still one ability")
	var kept: ManaAbility = land.cur_mana_abilities[0]
	assert_eq(kept.life_cost, 1, "and it still costs a life")
	assert_eq(kept.produces, [[Mtg.ManaColor.C, 1], [Mtg.ManaColor.G, 1]],
		"white became colourless; the green half is untouched")


func test_quarum_trench_gnomes_only_target_plains() -> void:
	var gnomes := put_battlefield(0, "Quarum Trench Gnomes")
	var forest := put_battlefield(1, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, gnomes, 0, [TargetRef.card(forest)]),
		"Illegal target")

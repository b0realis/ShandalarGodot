extends GameTest
## Wave-56 tests: Arabian Nights, Antiquities, Legends and promo
## remainders — the most famous land in the game, a free rock with a coin
## flip, an Aura that makes an artifact's abilities free, a Carpet against
## the ground war, and the Effigy chain.


func test_registry_loaded_wave56() -> void:
	for name in ["Library of Alexandria", "Jandor's Ring", "Camel",
			"Power Artifact", "Artifact Ward", "Mana Crypt", "Field of Dreams",
			"Revelation", "Greater Realm of Preservation", "Al-abara's Carpet",
			"Blazing Effigy", "Recall"]:
		assert_not_null(CardRegistry.get_card(name), name)


# ------------------------------------------------- Library of Alexandria --

func test_library_of_alexandria_draws_at_exactly_seven() -> void:
	var library := put_battlefield(0, "Library of Alexandria")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, library, 0, []), "exactly seven")
	for _i in 7:
		give_hand(0, "Grizzly Bears")
	assert_ok(g.activate_ability(0, library, 0, []))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 8)


func test_library_of_alexandria_still_taps_for_mana() -> void:
	var library := put_battlefield(0, "Library of Alexandria")
	assert_ok(g.tap_for_mana(0, library))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 1)


# ---------------------------------------------------------- Mana Crypt --

func test_mana_crypt_makes_two_for_free() -> void:
	var crypt := put_battlefield(0, "Mana Crypt")
	assert_ok(g.tap_for_mana(0, crypt))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 2)


func test_mana_crypt_flips_at_your_upkeep() -> void:
	put_battlefield(0, "Mana Crypt")
	advance_to_next_turn()
	advance_to_next_turn()      # our upkeep: the flip happens
	resolve_stack()
	assert_true(g.players[0].life == 20 or g.players[0].life == 17,
		"either the flip was won or it cost 3")


# ------------------------------------------------------- Power Artifact --

func test_power_artifact_discounts_its_host() -> void:
	var monolith := put_battlefield(0, "Basalt Monolith")   # {3}: untap
	var aura := give_hand(0, "Power Artifact")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(monolith)]))
	resolve_stack()
	assert_eq(monolith.cur_activated_abilities[0].cost.generic, 1,
		"{3} became {1}")


func test_power_artifact_leaves_other_artifacts_alone() -> void:
	var monolith := put_battlefield(0, "Basalt Monolith")
	var other := put_battlefield(0, "Basalt Monolith")
	var aura := give_hand(0, "Power Artifact")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(monolith)]))
	resolve_stack()
	assert_eq(other.cur_activated_abilities[0].cost.generic, 3)


# -------------------------------------------------------- Artifact Ward --

func test_artifact_ward_stops_artifact_blockers_and_damage() -> void:
	var warded := put_battlefield(0, "Grizzly Bears")
	var robot := put_battlefield(1, "Clockwork Beast")
	var aura := give_hand(0, "Artifact Ward")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(warded)]))
	resolve_stack()
	assert_false(warded.cur_block_restrictions.is_empty())
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [warded.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {robot.id: warded.id}),
		"can't be blocked except by")


# ------------------------------------------- Greater Realm of Preservation --

func test_greater_realm_stops_a_black_or_red_source() -> void:
	# In RESPONSE to the Bolt: "a black or red source of your choice" is
	# named as the ability resolves, and the Bolt on the stack is the one
	# it names (lifted 2026-09-02; tests/cards/test_fidelity_2026_09_02_sources.gd).
	var realm := put_battlefield(0, "Greater Realm of Preservation")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, realm, 0, []))
	resolve_stack()
	assert_eq(g.players[0].life, 20, "the shield ate the bolt")
	assert_true(g.choice_log.any(func(c: PlayerChoice) -> bool:
		return c.prompt == "Greater Realm of Preservation: Select a black or red source."),
		"the two-colour mask reads in card English")


# ------------------------------------------------------ Al-abara's Carpet --

func test_al_abaras_carpet_turns_aside_the_ground_war() -> void:
	var carpet := put_battlefield(1, "Al-abara's Carpet")
	var runner := put_battlefield(0, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [runner.id]))
	resolve_stack()
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.C, 5)
	assert_ok(g.activate_ability(1, carpet, 0, []))
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20, "the Giant hit a wall of silk")


# ---------------------------------------------------------- Blazing Effigy --

func test_blazing_effigy_burns_when_it_dies() -> void:
	var effigy := put_battlefield(0, "Blazing Effigy")
	var target := put_battlefield(1, "Hill Giant")   # 3/3
	g.destroy(effigy)
	g.check_state_based_actions()
	resolve_stack()
	assert_eq(target.zone, Mtg.Zone.GRAVEYARD, "3 damage kills the 3/3")


# ---------------------------------------------------------------- Recall --

func test_recall_trades_your_hand_for_your_graveyard() -> void:
	var buried := give_hand(0, "Serra Angel")
	g.players[0].hand.erase(buried)
	buried.zone = Mtg.Zone.GRAVEYARD
	g.players[0].graveyard.append(buried)
	give_hand(0, "Grizzly Bears")
	var recall := give_hand(0, "Recall")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, recall, [], 1))
	resolve_stack()
	assert_eq(buried.zone, Mtg.Zone.HAND, "the Angel came back")
	assert_eq(recall.zone, Mtg.Zone.EXILE, "and Recall exiled itself")


# ------------------------------------------------------------ Jandor's Ring --

func test_jandors_ring_cycles_a_card() -> void:
	# Lifted 2026-09-02: the cost is THE LAST CARD YOU DREW THIS TURN, so a
	# card merely in hand won't do (tests/cards/test_fidelity_2026_09_02_
	# draws.gd pins the rest).
	var ring := put_battlefield(0, "Jandor's Ring")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, ring, 0, []), "drawn a card this turn")
	give_hand(0, "Grizzly Bears")
	assert_refused(g.activate_ability(0, ring, 0, []), "drawn a card this turn")
	g.draw_cards(0, 1)
	assert_ok(g.activate_ability(0, ring, 0, []))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 2, "one out, one in")
	assert_eq(g.players[0].graveyard.size(), 1)


# ------------------------------------------------------------------- Camel --

func test_camel_bands_and_shelters_from_deserts() -> void:
	var camel := put_battlefield(0, "Camel")
	assert_true(camel.has_keyword(Mtg.Keyword.BANDING))
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [camel.id]))
	resolve_stack()
	assert_false(camel.cur_damage_immunity.is_empty(),
		"an attacking Camel shrugs off Deserts")


# ------------------------------------------------ the information effects --

func test_field_of_dreams_and_revelation_are_world_enchantments() -> void:
	var field := put_battlefield(0, "Field of Dreams")
	var revelation := put_battlefield(0, "Revelation")
	g.check_state_based_actions()
	# The world rule keeps only the NEWEST (CR 704.5k).
	assert_eq(field.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(revelation.zone, Mtg.Zone.BATTLEFIELD)

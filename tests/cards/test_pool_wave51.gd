extends GameTest
## Wave-51 tests: the last three small zones/results the 1997 pool needs —
## PHASING (CR 702.25, Oubliette), a game DRAW (CR 104.4, Divine
## Intervention), and FACE-DOWN / OUTSIDE-THE-GAME cards (Illusionary Mask,
## Knowledge Vault, Ring of Ma'rûf).


func test_registry_loaded_wave51() -> void:
	for name in ["Oubliette", "Divine Intervention", "Illusionary Mask",
			"Knowledge Vault", "Ring of Ma'rûf"]:
		assert_not_null(CardRegistry.get_card(name), name)


# ----------------------------------------------------------------- phasing --

func test_phased_out_permanents_dont_exist() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	g.phase_out(bear)
	assert_true(bear.phased_out)
	assert_eq(g.players[1].battlefield.size(), 0, "off the battlefield arrays")
	assert_false(g.all_battlefield().has(bear))
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(0, bolt, [TargetRef.card(bear)]), "Illegal target")


func test_phasing_in_restores_a_permanent() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	g.phase_out(bear)
	g.phase_in(bear, true)
	assert_false(bear.phased_out)
	assert_true(bear.tapped, "Oubliette taps it as it phases in")
	assert_true(g.players[1].battlefield.has(bear))


func test_oubliette_locks_a_creature_away() -> void:
	var victim := put_battlefield(1, "Serra Angel")
	var oubliette := give_hand(0, "Oubliette")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, oubliette, []))
	resolve_stack()
	assert_true(victim.phased_out, "the Angel is gone")
	assert_eq(g.players[1].battlefield.size(), 0)


func test_destroying_the_oubliette_frees_the_prisoner() -> void:
	var victim := put_battlefield(1, "Serra Angel")
	var oubliette := give_hand(0, "Oubliette")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, oubliette, []))
	resolve_stack()
	g.destroy(oubliette)
	g.check_state_based_actions()
	resolve_stack()
	assert_false(victim.phased_out, "it comes back")
	assert_true(victim.tapped, "tapped, as printed")
	assert_true(g.players[1].battlefield.has(victim))


func test_an_aura_phases_out_with_its_host() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var aura := give_hand(1, "Holy Strength")
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(1, aura, [TargetRef.card(bear)]))
	resolve_stack()
	g.phase_out(bear)
	assert_true(aura.phased_out, "auras go with their host")
	g.phase_in(bear)
	assert_false(aura.phased_out)


# ------------------------------------------------------- Divine Intervention --

func test_divine_intervention_draws_the_game() -> void:
	var divine := put_battlefield(0, "Divine Intervention")
	assert_eq(int(divine.counters.get("intervention", 0)), 2)
	advance_to_next_turn()      # their turn
	advance_to_next_turn()      # ours: one counter comes off
	resolve_stack()
	assert_eq(int(divine.counters.get("intervention", 0)), 1)
	assert_false(g.game_over)
	advance_to_next_turn()
	advance_to_next_turn()      # ours again: the last counter
	resolve_stack()
	assert_true(g.game_over)
	assert_true(g.is_draw)
	assert_eq(g.winner, -1, "nobody wins a draw")


# --------------------------------------------------------- Illusionary Mask --

func test_illusionary_mask_hides_a_creature() -> void:
	var mask := put_battlefield(0, "Illusionary Mask")
	var angel := give_hand(0, "Serra Angel")     # mana value 5
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.activate_ability(0, mask, 0, [], 5))
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(angel.face_down)
	assert_eq(angel.cur_power, 2, "a 2/2 while face down")
	assert_eq(angel.cur_toughness, 2)
	assert_false(angel.has_keyword(Mtg.Keyword.FLYING), "no abilities either")


func test_a_masked_creature_turns_up_when_damaged() -> void:
	var mask := put_battlefield(0, "Illusionary Mask")
	var angel := give_hand(0, "Serra Angel")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.activate_ability(0, mask, 0, [], 5))
	resolve_stack()
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(angel)]))
	resolve_stack()
	assert_false(angel.face_down, "it is turned face up first")
	assert_eq(angel.cur_toughness, 4, "and the damage hits a 4/4")
	assert_eq(angel.zone, Mtg.Zone.BATTLEFIELD)


func test_illusionary_mask_needs_a_big_enough_x() -> void:
	var mask := put_battlefield(0, "Illusionary Mask")
	var angel := give_hand(0, "Serra Angel")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, mask, 0, [], 2))
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.HAND, "X=2 can't cover a five-drop")


# ---------------------------------------------------------- Knowledge Vault --

func test_knowledge_vault_hoards_and_pays_out() -> void:
	var vault := put_battlefield(0, "Knowledge Vault")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, vault, 0, []))
	resolve_stack()
	assert_eq(g.players[0].exile.size(), 1)
	assert_true(g.players[0].exile[0].face_down)
	give_hand(0, "Grizzly Bears")
	assert_ok(g.activate_ability(0, vault, 1, []))
	resolve_stack()
	assert_eq(vault.zone, Mtg.Zone.GRAVEYARD, "it sacrificed itself")
	assert_eq(g.players[0].hand.size(), 1, "the old hand went away, the hoard came back")
	assert_eq(g.players[0].exile.size(), 0)


func test_knowledge_vault_buries_its_hoard_when_destroyed() -> void:
	var vault := put_battlefield(0, "Knowledge Vault")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, vault, 0, []))
	resolve_stack()
	var hoarded: CardInstance = g.players[0].exile[0]
	g.destroy(vault)
	g.check_state_based_actions()
	resolve_stack()
	assert_eq(hoarded.zone, Mtg.Zone.GRAVEYARD, "the hoard is lost")


# ---------------------------------------------------------- Ring of Ma'rûf --

func test_ring_of_maruf_fetches_from_outside_the_game() -> void:
	# Lifted 2026-09-02: the fetch REPLACES the next draw this turn
	# (tests/cards/test_fidelity_2026_09_02_draws.gd pins the rest).
	var ring := put_battlefield(0, "Ring of Ma'rûf")
	var wish := _make_instance(0, "Black Lotus")
	g.players[0].outside_the_game.append(wish)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.activate_ability(0, ring, 0, []))
	resolve_stack()
	g.draw_cards(0, 1)
	assert_eq(wish.zone, Mtg.Zone.HAND)
	assert_true(g.players[0].hand.has(wish))
	assert_eq(ring.zone, Mtg.Zone.EXILE, "the Ring exiles itself as a cost")


func test_ring_of_maruf_finds_nothing_in_a_plain_duel() -> void:
	var ring := put_battlefield(0, "Ring of Ma'rûf")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.activate_ability(0, ring, 0, []))
	resolve_stack()
	g.draw_cards(0, 1)
	assert_eq(g.players[0].hand.size(), 0, "the draw is replaced by nothing")

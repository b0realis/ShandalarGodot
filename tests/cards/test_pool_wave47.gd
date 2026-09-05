extends GameTest
## Wave-47 tests: COPYING. Copies of permanents (Clone, Copy Artifact,
## Vesuvan Doppelganger, Dance of Many's token) take the copiable values of
## what they copy, CR 707 — in this engine that is the definition the
## instance points at — and copies of spells (Fork, Chain Lightning's
## rider) go on the stack as objects that never become cards.


func test_registry_loaded_wave47() -> void:
	for name in ["Clone", "Copy Artifact", "Vesuvan Doppelganger", "Fork",
			"Dance of Many"]:
		assert_not_null(CardRegistry.get_card(name), name)


# ------------------------------------------------------------------- Clone --

func test_clone_enters_as_the_creature_it_copies() -> void:
	put_battlefield(1, "Serra Angel")             # 4/4 flying vigilance
	var clone := give_hand(0, "Clone")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, clone, []))
	resolve_stack()
	assert_eq(clone.zone, Mtg.Zone.BATTLEFIELD, "a 0/0 Clone never hit the table")
	assert_eq(clone.data.card_name, "Serra Angel")
	assert_eq(clone.cur_power, 4)
	assert_eq(clone.cur_toughness, 4)
	assert_true(clone.has_keyword(Mtg.Keyword.FLYING))
	assert_eq(clone.controller_id, 0, "it is still OURS")


func test_clone_with_nothing_to_copy_dies_as_a_zero_zero() -> void:
	var clone := give_hand(0, "Clone")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, clone, []))
	resolve_stack()
	assert_eq(clone.zone, Mtg.Zone.GRAVEYARD, "0 toughness, state-based action")


func test_a_clone_stops_being_a_copy_when_it_dies() -> void:
	put_battlefield(1, "Serra Angel")
	var clone := give_hand(0, "Clone")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, clone, []))
	resolve_stack()
	g.destroy(clone)
	g.check_state_based_actions()
	assert_eq(clone.data.card_name, "Clone", "the card in the graveyard is a Clone")


func test_a_cloned_pinger_brings_its_abilities() -> void:
	put_battlefield(1, "Prodigal Sorcerer")       # {T}: 1 damage
	var clone := give_hand(0, "Clone")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, clone, []))
	resolve_stack()
	clone.summoning_sick = false
	assert_ok(g.activate_ability(0, clone, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 19)


# ----------------------------------------------------------- Copy Artifact --

func test_copy_artifact_copies_a_mana_rock_and_stays_an_enchantment() -> void:
	put_battlefield(1, "Sol Ring")
	var copy := give_hand(0, "Copy Artifact")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, copy, []))
	resolve_stack()
	assert_eq(copy.data.card_name, "Sol Ring")
	assert_true(copy.is_type(Mtg.CardType.ARTIFACT))
	assert_true(copy.is_type(Mtg.CardType.ENCHANTMENT),
		"an enchantment in addition to its other types")
	assert_ok(g.tap_for_mana(0, copy))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 2)


# ---------------------------------------------------- Vesuvan Doppelganger --

func test_doppelganger_copies_but_keeps_its_own_colour() -> void:
	put_battlefield(1, "Grizzly Bears")           # green 2/2
	var doppel := give_hand(0, "Vesuvan Doppelganger")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, doppel, []))
	resolve_stack()
	assert_eq(doppel.data.card_name, "Grizzly Bears")
	assert_eq(doppel.cur_power, 2)
	assert_true(doppel.has_color(Mtg.ManaColor.U), "it is still blue")
	assert_false(doppel.has_color(Mtg.ManaColor.G), "it does NOT copy the colour")


func test_doppelganger_shifts_shape_at_your_upkeep() -> void:
	put_battlefield(1, "Grizzly Bears")
	var doppel := give_hand(0, "Vesuvan Doppelganger")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, doppel, []))
	resolve_stack()
	assert_eq(doppel.data.card_name, "Grizzly Bears")
	put_battlefield(1, "Serra Angel")             # a bigger shape appears
	advance_to_next_turn()                        # their turn
	advance_to_next_turn()                        # ours: the upkeep trigger
	resolve_stack()
	assert_eq(doppel.data.card_name, "Serra Angel", "it took the better body")
	assert_true(doppel.has_color(Mtg.ManaColor.U), "still blue")
	assert_false(doppel.data.triggered_abilities.is_empty(),
		"and it still has the shape-shifting ability")


# -------------------------------------------------------------------- Fork --

func test_fork_copies_a_bolt_back_at_its_caster() -> void:
	var bolt := give_hand(1, "Lightning Bolt")
	var fork := give_hand(0, "Fork")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))          # hand priority to the caster
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, fork, [TargetRef.card(bolt)]))
	resolve_stack()
	assert_eq(g.players[0].life, 17, "the original still hit us")
	assert_eq(g.players[1].life, 17, "and the copy hit them")


func test_fork_only_copies_instants_and_sorceries() -> void:
	var bears := give_hand(1, "Grizzly Bears")
	var fork := give_hand(0, "Fork")
	advance_to_next_turn()                 # player 1's main phase
	add_mana(1, Mtg.ManaColor.G)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, bears, []))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_refused(g.cast_spell(0, fork, [TargetRef.card(bears)]), "Illegal target")


func test_a_forked_copy_never_reaches_a_graveyard() -> void:
	var bolt := give_hand(1, "Lightning Bolt")
	var fork := give_hand(0, "Fork")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))          # hand priority to the caster
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, fork, [TargetRef.card(bolt)]))
	resolve_stack()
	var bolts := 0
	for inst in g.players[1].graveyard:
		if inst.data.card_name == "Lightning Bolt":
			bolts += 1
	assert_eq(bolts, 1, "only the real card went to a graveyard")


# --------------------------------------------------------- Chain Lightning --

func test_chain_lightning_can_be_paid_forward() -> void:
	# The victim has two Mountains, so the {R}{R} is affordable and the
	# engine's triggered-payment path taps them for the copy.
	put_battlefield(1, "Mountain")
	put_battlefield(1, "Mountain")
	var chain := give_hand(0, "Chain Lightning")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, chain, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 17, "the original hit them")
	assert_eq(g.players[0].life, 17, "and the chain came back at us")


func test_chain_lightning_stops_when_the_victim_cant_pay() -> void:
	var chain := give_hand(0, "Chain Lightning")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, chain, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 17)
	assert_eq(g.players[0].life, 20, "no red mana, no chain")


# ------------------------------------------------------------ Dance of Many --

func test_dance_of_many_makes_a_token_copy() -> void:
	put_battlefield(1, "Serra Angel")
	var dance := give_hand(0, "Dance of Many")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, dance, []))
	resolve_stack()
	var token := g.find_on_battlefield(0, "Serra Angel")
	assert_not_null(token)
	assert_true(token.is_token)
	assert_eq(token.cur_power, 4)


func test_dance_of_many_exiles_its_token_when_it_leaves() -> void:
	put_battlefield(1, "Serra Angel")
	var dance := give_hand(0, "Dance of Many")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, dance, []))
	resolve_stack()
	var token := g.find_on_battlefield(0, "Serra Angel")
	g.destroy(dance)
	g.check_state_based_actions()
	resolve_stack()
	assert_null(g.find_on_battlefield(0, "Serra Angel"), "the token is gone")
	assert_ne(token.zone, Mtg.Zone.BATTLEFIELD)


func test_dance_of_many_dies_with_its_token() -> void:
	put_battlefield(1, "Serra Angel")
	var dance := give_hand(0, "Dance of Many")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, dance, []))
	resolve_stack()
	var token := g.find_on_battlefield(0, "Serra Angel")
	g.destroy(token)
	g.check_state_based_actions()
	resolve_stack()
	assert_eq(dance.zone, Mtg.Zone.GRAVEYARD)


func test_dance_of_many_needs_its_upkeep_rent() -> void:
	put_battlefield(1, "Serra Angel")
	var dance := give_hand(0, "Dance of Many")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, dance, []))
	resolve_stack()
	advance_to_next_turn()      # their turn
	advance_to_next_turn()      # our upkeep — nothing to pay with
	resolve_stack()
	assert_eq(dance.zone, Mtg.Zone.GRAVEYARD, "unpaid rent sacrifices it")

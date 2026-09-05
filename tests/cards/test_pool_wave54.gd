extends GameTest
## Wave-54 tests: the Unlimited remainders — a rainbow rock, two Auras that
## rewrite what they sit on, a burn spell that exiles, a dragon with a fuse,
## a Helm, a Farmstead, a Library, and the two mana-stripping blue spells.
## Two new engine flags carry them: cur_indestructible (CR 700.4) and
## "exile it instead of dying this turn".


func test_registry_loaded_wave54() -> void:
	for name in ["Celestial Prism", "Consecrate Land", "Disintegrate",
			"Animate Artifact", "Dragon Whelp", "Helm of Chatzuk", "Earthbind",
			"Farmstead", "Library of Leng", "Mana Short", "Power Sink",
			"Power Surge"]:
		assert_not_null(CardRegistry.get_card(name), name)


# -------------------------------------------------------- Celestial Prism --

func test_celestial_prism_makes_any_colour() -> void:
	var prism := put_battlefield(0, "Celestial Prism")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.tap_for_mana(0, prism, 1))       # index 1 = blue
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 1)


func test_celestial_prism_needs_its_two() -> void:
	var prism := put_battlefield(0, "Celestial Prism")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.tap_for_mana(0, prism, 0), "floating mana")


# -------------------------------------------------------- Consecrate Land --

func test_consecrate_land_makes_a_land_indestructible() -> void:
	var land := put_battlefield(1, "Forest")
	var aura := give_hand(0, "Consecrate Land")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(land)]))
	resolve_stack()
	assert_true(land.cur_indestructible)
	g.destroy(land)
	g.check_state_based_actions()
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD, "destruction does nothing")


# ----------------------------------------------------------- Disintegrate --

func test_disintegrate_exiles_what_it_kills() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var spell := give_hand(0, "Disintegrate")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(bear)], 3))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.EXILE, "exiled, not buried")
	assert_eq(g.players[1].graveyard.size(), 0)


func test_disintegrate_beats_regeneration() -> void:
	var troll := put_battlefield(1, "Uthden Troll")
	var spell := give_hand(0, "Disintegrate")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(troll)], 4))
	resolve_stack()
	assert_eq(troll.zone, Mtg.Zone.EXILE)


# -------------------------------------------------------- Animate Artifact --

func test_animate_artifact_gives_a_rock_a_body() -> void:
	var ring := put_battlefield(1, "Sol Ring")     # mana value 1
	var aura := give_hand(0, "Animate Artifact")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(ring)]))
	resolve_stack()
	assert_true(ring.is_creature())
	assert_eq(ring.cur_power, 1)
	assert_eq(ring.cur_toughness, 1)


# ------------------------------------------------------------ Dragon Whelp --

func test_dragon_whelp_burns_out_after_four_breaths() -> void:
	var whelp := put_battlefield(0, "Dragon Whelp")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 4)
	for _i in 4:
		assert_ok(g.activate_ability(0, whelp, 0, []))
		resolve_stack()
	assert_eq(whelp.cur_power, 6, "2/3 base plus four breaths")
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(whelp.zone, Mtg.Zone.GRAVEYARD, "the fourth breath is fatal")


func test_dragon_whelp_survives_three_breaths() -> void:
	var whelp := put_battlefield(0, "Dragon Whelp")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 3)
	for _i in 3:
		assert_ok(g.activate_ability(0, whelp, 0, []))
		resolve_stack()
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(whelp.zone, Mtg.Zone.BATTLEFIELD)


# ---------------------------------------------------------------- Earthbind --

func test_earthbind_shoots_down_a_flyer() -> void:
	var angel := put_battlefield(1, "Serra Angel")    # 4/4 flying
	var aura := give_hand(0, "Earthbind")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(angel)]))
	resolve_stack()
	assert_eq(angel.damage, 2)
	assert_false(angel.has_keyword(Mtg.Keyword.FLYING), "grounded")


func test_earthbind_does_nothing_to_a_ground_creature() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var aura := give_hand(0, "Earthbind")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.damage, 0)


# ------------------------------------------------------- Helm of Chatzuk --

func test_helm_of_chatzuk_hands_out_banding() -> void:
	var helm := put_battlefield(0, "Helm of Chatzuk")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, helm, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.has_keyword(Mtg.Keyword.BANDING))


# ----------------------------------------------------------------- Farmstead --

func test_farmstead_buys_a_life_each_upkeep() -> void:
	var land := put_battlefield(0, "Plains")
	put_battlefield(0, "Plains")
	put_battlefield(0, "Plains")
	var aura := give_hand(0, "Farmstead")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 3)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(land)]))
	resolve_stack()
	advance_to_next_turn()
	advance_to_next_turn()      # our upkeep
	resolve_stack()
	assert_eq(g.players[0].life, 21)


# ------------------------------------------------------- Library of Leng --

func test_library_of_leng_lifts_the_hand_limit() -> void:
	put_battlefield(0, "Library of Leng")
	for _i in 10:
		give_hand(0, "Grizzly Bears")
	advance_to_next_turn()
	assert_eq(g.players[0].hand.size(), 10, "nothing was discarded at cleanup")


# ---------------------------------------------------------------- Mana Short --

func test_mana_short_taps_them_out() -> void:
	var a := put_battlefield(1, "Forest")
	var b := put_battlefield(1, "Island")
	add_mana(1, Mtg.ManaColor.G, 3)
	var short := give_hand(0, "Mana Short")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 2)   # {2}{U} — the printed cost (audit 2026-09)
	assert_ok(g.cast_spell(0, short, [TargetRef.player(1)]))
	resolve_stack()
	assert_true(a.tapped)
	assert_true(b.tapped)
	assert_eq(g.players[1].mana_pool.total(), 0)


# ---------------------------------------------------------------- Power Sink --

func test_power_sink_counters_and_strips() -> void:
	var land := put_battlefield(1, "Forest")
	var bears := give_hand(1, "Grizzly Bears")
	var sink := give_hand(0, "Power Sink")
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.G)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, bears, []))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.cast_spell(0, sink, [TargetRef.card(bears)], 5))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "countered")
	assert_true(land.tapped, "and their board is tapped out")
	assert_eq(g.players[1].mana_pool.total(), 0)


# --------------------------------------------------------------- Power Surge --

func test_power_surge_burns_the_untapped() -> void:
	put_battlefield(0, "Power Surge")
	put_battlefield(1, "Forest")
	put_battlefield(1, "Forest")
	advance_to_next_turn()      # their turn: two untapped lands at its start
	resolve_stack()
	assert_eq(g.players[1].life, 18)

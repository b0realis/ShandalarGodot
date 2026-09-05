extends GameTest
## Wave-34 tests: Fourth Edition's artifact shelf — the five mana
## batteries, Circle of Protection: Artifacts, artifact-hate and
## artifact-animation enchantments (Energy Flux, Titania's Song) and a
## handful of utility cards (Sindbad, Coral Helm, Energy Tap, Fortified
## Area).


func test_mana_battery_charges_and_discharges() -> void:
	var battery := put_battlefield(0, "Black Mana Battery")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, battery, 0, []))
	resolve_stack()
	assert_eq(battery.counters.get("charge", 0), 1)
	g.untap_permanent(battery)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, battery, 0, []))
	resolve_stack()
	assert_eq(battery.counters.get("charge", 0), 2)
	g.untap_permanent(battery)
	assert_ok(g.tap_for_mana(0, battery))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 3,
		"one plus one per charge counter")
	assert_eq(battery.counters.get("charge", 0), 0, "the counters are spent")


func test_every_battery_makes_its_colour() -> void:
	var pairs := {
		"White Mana Battery": Mtg.ManaColor.W, "Blue Mana Battery": Mtg.ManaColor.U,
		"Black Mana Battery": Mtg.ManaColor.B, "Red Mana Battery": Mtg.ManaColor.R,
		"Green Mana Battery": Mtg.ManaColor.G,
	}
	for name in pairs:
		var battery := put_battlefield(0, name)
		assert_ok(g.tap_for_mana(0, battery))
		assert_eq(g.players[0].mana_pool.amount_of(pairs[name]), 1, name)
		g.players[0].mana_pool.clear()


func test_cop_artifacts_blanks_an_artifact_source() -> void:
	var cop := put_battlefield(0, "Circle of Protection: Artifacts")
	var rod := put_battlefield(1, "Rod of Ruin")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, cop, 0, []))
	resolve_stack()
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(1, rod, 0, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].life, 20, "the artifact's damage was prevented")


func test_cop_artifacts_ignores_a_red_spell() -> void:
	var cop := put_battlefield(0, "Circle of Protection: Artifacts")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, cop, 0, []))
	resolve_stack()
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].life, 17)


func test_sindbad_keeps_lands_and_dumps_spells() -> void:
	var sindbad := put_battlefield(0, "Sindbad")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, sindbad, 0, []))
	resolve_stack()
	# The test deck is all Forests, so the draw is always kept.
	assert_eq(g.players[0].hand.size(), 1)
	assert_eq(g.players[0].graveyard.size(), 0)


func test_sindbad_discards_a_nonland() -> void:
	var sindbad := put_battlefield(0, "Sindbad")
	# Stack a Lightning Bolt on top of the library.
	var bolt := give_hand(0, "Lightning Bolt")
	g.players[0].hand.erase(bolt)
	bolt.zone = Mtg.Zone.LIBRARY
	g.players[0].library.append(bolt)
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, sindbad, 0, []))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].hand.size(), 0)


func test_coral_helm_costs_a_card_at_random() -> void:
	var helm := put_battlefield(0, "Coral Helm")
	var bear := put_battlefield(0, "Grizzly Bears")
	give_hand(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, helm, 0, [TargetRef.card(bear)]))
	assert_eq(g.players[0].hand.size(), 0, "the card was the cost")
	resolve_stack()
	assert_eq(bear.cur_power, 4)
	assert_eq(bear.cur_toughness, 4)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.activate_ability(0, helm, 0, [TargetRef.card(bear)]),
		"not enough cards in hand")


func test_energy_tap_turns_a_creature_into_mana() -> void:
	var angel := put_battlefield(0, "Serra Angel")   # mana value 5
	var tap := give_hand(0, "Energy Tap")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, tap, [TargetRef.card(angel)]))
	resolve_stack()
	assert_true(angel.tapped)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 5)


func test_fortified_area_arms_your_walls() -> void:
	var wall := put_battlefield(0, "Wall of Wood")   # 0/3
	var bear := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Wall of Wood")
	put_battlefield(0, "Fortified Area")
	g.recalculate()
	assert_eq(wall.cur_power, 1)
	assert_true(wall.has_keyword(Mtg.Keyword.BANDING))
	assert_eq(bear.cur_power, 2, "only Walls")
	assert_eq(theirs.cur_power, 0, "only yours")


func test_energy_flux_taxes_every_artifact() -> void:
	var ring := put_battlefield(1, "Sol Ring")
	put_battlefield(0, "Energy Flux")
	advance_to_next_turn()   # player 1's upkeep, no mana available
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD)


func test_energy_flux_spares_a_paid_artifact() -> void:
	var ring := put_battlefield(1, "Sol Ring")
	put_battlefield(1, "Forest")
	put_battlefield(1, "Forest")
	put_battlefield(0, "Energy Flux")
	advance_to_next_turn()
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.BATTLEFIELD, "{2} kept it alive")


func test_titanias_song_animates_and_silences_artifacts() -> void:
	var ring := put_battlefield(1, "Sol Ring")       # mana value 1
	var golem := put_battlefield(1, "Obsianus Golem")
	put_battlefield(0, "Titania's Song")
	g.recalculate()
	assert_true(ring.is_creature())
	assert_eq(ring.cur_power, 1)
	assert_eq(ring.cur_toughness, 1)
	assert_refused(g.tap_for_mana(1, ring), "no mana ability")
	assert_eq(golem.cur_power, 4, "artifact CREATURES are untouched")

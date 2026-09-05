extends GameTest
## Wave-23 tests: the Legends control shell — narrow counterspells (Flash
## Counter, Force Spike, Avoid Fate), the counter-everything enchantments
## (Nether Void, Presence of the Master, In the Eye of Chaos), punishment
## permanents (Underworld Dreams, Ichneumon Druid, Storm World, The Abyss)
## and the upkeep/tap lifegain pair (Spiritual Sanctuary, Lifeblood).


func test_flash_counter_hits_instants_only() -> void:
	var bolt := give_hand(1, "Lightning Bolt")
	var bears := give_hand(1, "Grizzly Bears")
	var flash := give_hand(0, "Flash Counter")
	advance_to_next_turn()   # player 1's turn, so they can cast a creature
	add_mana(1, Mtg.ManaColor.G)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, bears, []))
	assert_ok(g.pass_priority(1))   # the caster keeps priority (CR 117.3c)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(0, flash, [TargetRef.card(bears)]), "Illegal target")
	resolve_stack()
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, flash, [TargetRef.card(bolt)]))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 20, "the bolt never resolved")


func test_force_spike_taxes_a_tapped_out_opponent() -> void:
	var bolt := give_hand(1, "Lightning Bolt")
	var spike := give_hand(0, "Force Spike")
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, spike, [TargetRef.card(bolt)]))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD, "no mana left to pay the {1}")
	assert_eq(g.players[0].life, 20)


func test_force_spike_fizzles_against_open_mana() -> void:
	var bolt := give_hand(1, "Lightning Bolt")
	var spike := give_hand(0, "Force Spike")
	put_battlefield(1, "Mountain")
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, spike, [TargetRef.card(bolt)]))
	resolve_stack()
	assert_eq(g.players[0].life, 17, "the {1} was paid; the bolt resolved")


func test_avoid_fate_protects_your_own_permanents() -> void:
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Grizzly Bears")
	var terror := give_hand(1, "Terror")
	var avoid := give_hand(0, "Avoid Fate")
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.B)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, terror, [TargetRef.card(theirs)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.G)
	assert_refused(g.cast_spell(0, avoid, [TargetRef.card(terror)]),
		"Illegal target")
	resolve_stack()
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD)
	var terror2 := give_hand(1, "Terror")
	add_mana(1, Mtg.ManaColor.B)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, terror2, [TargetRef.card(mine)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, avoid, [TargetRef.card(terror2)]))
	resolve_stack()
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(terror2.zone, Mtg.Zone.GRAVEYARD)


func test_nether_void_taxes_every_spell() -> void:
	put_battlefield(0, "Nether Void")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 20, "countered — no {3} available")


func test_nether_void_lets_a_paid_spell_through() -> void:
	put_battlefield(0, "Nether Void")
	var bolt := give_hand(1, "Lightning Bolt")
	for i in 3:
		put_battlefield(1, "Mountain")
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].life, 17)


func test_presence_of_the_master_stops_enchantments() -> void:
	put_battlefield(0, "Presence of the Master")
	var crusade := give_hand(1, "Crusade")
	var bears := give_hand(1, "Grizzly Bears")
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.W, 2)
	assert_ok(g.cast_spell(1, crusade, []))
	resolve_stack()
	assert_eq(crusade.zone, Mtg.Zone.GRAVEYARD, "countered on the way in")
	add_mana(1, Mtg.ManaColor.G)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, bears, []))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "creatures are untouched")


func test_in_the_eye_of_chaos_taxes_instants_by_mana_value() -> void:
	put_battlefield(0, "In the Eye of Chaos")
	var bolt := give_hand(1, "Lightning Bolt")   # mana value 1
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD, "no mana left for the {1} tax")


func test_underworld_dreams_bleeds_the_opponent_on_every_draw() -> void:
	put_battlefield(0, "Underworld Dreams")
	g.draw_cards(1, 2)
	resolve_stack()
	assert_eq(g.players[1].life, 18)
	g.draw_cards(0, 2)
	resolve_stack()
	assert_eq(g.players[0].life, 20, "your own draws are free")


func test_ichneumon_druid_spares_the_first_instant() -> void:
	var druid := put_battlefield(0, "Ichneumon Druid")
	assert_not_null(druid)
	var bolt1 := give_hand(1, "Lightning Bolt")
	var bolt2 := give_hand(1, "Lightning Bolt")
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(1, bolt1, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[1].life, 20, "the first instant is free")
	assert_ok(g.cast_spell(1, bolt2, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[1].life, 16, "the second one costs 4")


func test_spiritual_sanctuary_pays_plains_players() -> void:
	put_battlefield(0, "Spiritual Sanctuary")
	put_battlefield(0, "Plains")
	advance_to_next_turn()   # player 1's upkeep — no Plains
	assert_eq(g.players[1].life, 20)
	advance_to_next_turn()   # back to player 0's upkeep
	assert_eq(g.players[0].life, 21)


func test_lifeblood_taxes_their_mountains() -> void:
	put_battlefield(0, "Lifeblood")
	var mountain := put_battlefield(1, "Mountain")
	var mine := put_battlefield(0, "Mountain")
	assert_ok(g.tap_for_mana(0, mine))
	resolve_stack()
	assert_eq(g.players[0].life, 20, "your own Mountains don't pay")
	advance_to_next_turn()
	assert_ok(g.tap_for_mana(1, mountain))
	resolve_stack()
	assert_eq(g.players[0].life, 21)


func test_storm_world_burns_the_empty_handed() -> void:
	put_battlefield(0, "Storm World")
	give_hand(0, "Forest")
	give_hand(0, "Forest")
	advance_to_next_turn()   # player 1's upkeep, empty hand → 4 damage
	assert_eq(g.players[1].life, 16)
	advance_to_next_turn()   # player 0's upkeep, 2 cards in hand → 2 damage
	assert_eq(g.players[0].life, 18)


func test_the_abyss_eats_a_creature_each_upkeep() -> void:
	put_battlefield(0, "The Abyss")
	var bear := put_battlefield(1, "Grizzly Bears")
	var icy := put_battlefield(1, "Icy Manipulator")
	advance_to_next_turn()   # player 1's upkeep
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(icy.zone, Mtg.Zone.BATTLEFIELD, "artifacts are safe")

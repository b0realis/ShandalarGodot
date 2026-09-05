extends GameTest
## Wave-24 tests: Antiquities' artifact economy — mass and targeted
## artifact answers (Shatterstorm, Artifact Blast), artifact recursion
## (Reconstruction, Argivian Archaeologist), sacrifice outlets (Ashnod's
## Altar, Atog, Sage of Lat-Nam, Orcish Mechanics) and the artifact
## toolbox (Jalum Tome, Staff of Zegon, Mightstone, Weakstone).


func test_shatterstorm_wipes_every_artifact() -> void:
	var mine := put_battlefield(0, "Sol Ring")
	var theirs := put_battlefield(1, "Icy Manipulator")
	var golem := put_battlefield(1, "Obsianus Golem")   # artifact creature
	var bear := put_battlefield(1, "Grizzly Bears")
	var storm := give_hand(0, "Shatterstorm")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, storm, []))
	resolve_stack()
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD, "symmetric — yours die too")
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(golem.zone, Mtg.Zone.GRAVEYARD, "artifact creatures included")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


func test_artifact_blast_counters_only_artifacts() -> void:
	var ring := give_hand(1, "Sol Ring")
	var bears := give_hand(1, "Grizzly Bears")
	var blast := give_hand(0, "Artifact Blast")
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.G)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, bears, []))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(0, blast, [TargetRef.card(bears)]), "Illegal target")
	resolve_stack()
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, ring, []))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, blast, [TargetRef.card(ring)]))
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD)


func test_reconstruction_only_fetches_artifacts() -> void:
	var ring := put_battlefield(0, "Sol Ring")
	var bear := put_battlefield(0, "Grizzly Bears")
	g.destroy(ring, false)
	g.destroy(bear, false)
	var recon := give_hand(0, "Reconstruction")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_refused(g.cast_spell(0, recon, [TargetRef.card(bear)]), "Illegal target")
	assert_ok(g.cast_spell(0, recon, [TargetRef.card(ring)]))
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.HAND)


func test_argivian_archaeologist_recurs_artifacts() -> void:
	var archaeologist := put_battlefield(0, "Argivian Archaeologist")
	var ring := put_battlefield(0, "Sol Ring")
	g.destroy(ring, false)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_ok(g.activate_ability(0, archaeologist, 0, [TargetRef.card(ring)]))
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.HAND)


func test_ashnods_altar_eats_creatures_for_mana() -> void:
	var altar := put_battlefield(0, "Ashnod's Altar")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.tap_for_mana(0, altar), "no creature to sacrifice")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_ok(g.tap_for_mana(0, altar))
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 2)
	assert_false(altar.tapped, "no {T} in the cost")


func test_atog_eats_artifacts() -> void:
	var atog := put_battlefield(0, "Atog")
	var ring := put_battlefield(0, "Sol Ring")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, atog, 0, []))
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(atog.cur_power, 3)
	assert_eq(atog.cur_toughness, 4)
	assert_refused(g.activate_ability(0, atog, 0, []), "no artifact to sacrifice")


func test_sage_of_lat_nam_cashes_artifacts_for_cards() -> void:
	var sage := put_battlefield(0, "Sage of Lat-Nam")
	var ring := put_battlefield(0, "Sol Ring")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, sage, 0, []))
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD)
	assert_true(sage.tapped)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 1)


func test_orcish_mechanics_flings_artifacts() -> void:
	var orcs := put_battlefield(0, "Orcish Mechanics")
	put_battlefield(0, "Sol Ring")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, orcs, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


func test_jalum_tome_loots() -> void:
	var tome := put_battlefield(0, "Jalum Tome")
	give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, tome, 0, []))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 1, "drew one, discarded one")
	assert_eq(g.players[0].graveyard.size(), 1)


func test_staff_of_zegon_blunts_an_attacker() -> void:
	var staff := put_battlefield(0, "Staff of Zegon")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, staff, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_power, 0)
	assert_eq(bear.cur_toughness, 2)


func test_mightstone_only_pumps_attackers() -> void:
	put_battlefield(0, "Mightstone")
	var attacker := put_battlefield(0, "Grizzly Bears")
	var idler := put_battlefield(0, "Savannah Lions")
	assert_eq(attacker.cur_power, 2, "nobody is attacking yet")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	assert_eq(attacker.cur_power, 3)
	assert_eq(idler.cur_power, 2)


func test_weakstone_blunts_attackers_on_both_sides() -> void:
	put_battlefield(0, "Weakstone")
	var theirs := put_battlefield(1, "Grizzly Bears")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [theirs.id]))
	assert_eq(theirs.cur_power, 1)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 19)

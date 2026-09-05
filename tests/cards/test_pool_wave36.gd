extends GameTest
## Wave-36 tests: the untap locks (Smoke, Winter Orb, Damping Field),
## Fastbond's extra land drops, forced blocking (Lure), untap-and-attack
## tricks (Instill Energy, Stone Giant, Berserk), the red mana doubler
## (Gauntlet of Might), corpse counters (Scavenging Ghoul), a filtered
## counterspell (Spell Blast) and pure information (Glasses of Urza).


func test_smoke_only_lets_one_creature_untap() -> void:
	put_battlefield(0, "Smoke")
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(0, "Grizzly Bears")
	var land := put_battlefield(0, "Forest")
	g.tap_permanent(a)
	g.tap_permanent(b)
	g.tap_permanent(land)
	advance_to_next_turn()
	advance_to_next_turn()   # back to player 0's untap
	var untapped := 0
	if not a.tapped:
		untapped += 1
	if not b.tapped:
		untapped += 1
	assert_eq(untapped, 1, "exactly one creature untaps")
	assert_false(land.tapped, "lands are unaffected")


func test_winter_orb_only_lets_one_land_untap() -> void:
	var orb := put_battlefield(0, "Winter Orb")
	var l1 := put_battlefield(0, "Forest")
	var l2 := put_battlefield(0, "Forest")
	var bear := put_battlefield(0, "Grizzly Bears")
	g.tap_permanent(l1)
	g.tap_permanent(l2)
	g.tap_permanent(bear)
	advance_to_next_turn()
	advance_to_next_turn()
	var untapped := 0
	if not l1.tapped:
		untapped += 1
	if not l2.tapped:
		untapped += 1
	assert_eq(untapped, 1)
	assert_false(bear.tapped, "creatures untap normally")
	assert_not_null(orb)


func test_winter_orb_stops_working_while_tapped() -> void:
	var orb := put_battlefield(0, "Winter Orb")
	var l1 := put_battlefield(0, "Forest")
	var l2 := put_battlefield(0, "Forest")
	g.tap_permanent(l1)
	g.tap_permanent(l2)
	g.tap_permanent(orb)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_false(l1.tapped)
	assert_false(l2.tapped, "a tapped Orb locks nothing")


func test_damping_field_locks_artifacts() -> void:
	put_battlefield(0, "Damping Field")
	var a := put_battlefield(0, "Sol Ring")
	var b := put_battlefield(0, "Sol Ring")
	g.tap_permanent(a)
	g.tap_permanent(b)
	advance_to_next_turn()
	advance_to_next_turn()
	var untapped := 0
	if not a.tapped:
		untapped += 1
	if not b.tapped:
		untapped += 1
	assert_eq(untapped, 1)


func test_fastbond_pays_for_extra_lands() -> void:
	put_battlefield(0, "Fastbond")
	var l1 := give_hand(0, "Forest")
	var l2 := give_hand(0, "Forest")
	var l3 := give_hand(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.play_land(0, l1))
	resolve_stack()
	assert_eq(g.players[0].life, 20, "the first land is free")
	assert_ok(g.play_land(0, l2))
	resolve_stack()
	assert_eq(g.players[0].life, 19)
	assert_ok(g.play_land(0, l3))
	resolve_stack()
	assert_eq(g.players[0].life, 18)


func test_lure_forces_every_able_blocker() -> void:
	var attacker := put_battlefield(0, "Grizzly Bears")
	var lure := give_hand(0, "Lure")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, lure, [TargetRef.card(attacker)]))
	resolve_stack()
	assert_true(attacker.cur_must_be_blocked)
	var wall := put_battlefield(1, "Wall of Wood")
	var lions := put_battlefield(1, "Savannah Lions")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {}), "must block")
	assert_refused(g.declare_blockers(1, {wall.id: attacker.id}), "must block")
	assert_ok(g.declare_blockers(1,
		{wall.id: attacker.id, lions.id: attacker.id}))


func test_instill_energy_grants_haste_and_an_untap() -> void:
	var bear := put_battlefield(0, "Grizzly Bears", true)   # summoning sick
	var energy := give_hand(0, "Instill Energy")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, energy, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.cur_attacks_as_if_hasty)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	assert_true(bear.tapped)
	advance_to_step(Mtg.Step.MAIN2)
	assert_ok(g.activate_ability(0, energy, 0, []))
	resolve_stack()
	assert_false(bear.tapped)
	assert_refused(g.activate_ability(0, energy, 0, []), "each turn")


func test_gauntlet_of_might_doubles_mountains_and_pumps_red() -> void:
	put_battlefield(0, "Gauntlet of Might")
	var goblin := put_battlefield(0, "Mons's Goblin Raiders")
	var bear := put_battlefield(0, "Grizzly Bears")
	g.recalculate()
	assert_eq(goblin.cur_power, 2, "red creatures get +1/+1")
	assert_eq(bear.cur_power, 2, "green ones don't")
	var mountain := put_battlefield(0, "Mountain")
	assert_ok(g.tap_for_mana(0, mountain))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.R), 2)


func test_scavenging_ghoul_banks_corpses() -> void:
	var ghoul := put_battlefield(0, "Scavenging Ghoul")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, ghoul, 0, []), "corpse counters to remove")
	g.destroy(a, false)
	g.destroy(b, false)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(ghoul.counters.get("corpse", 0), 2)
	assert_ok(g.activate_ability(0, ghoul, 0, []))
	resolve_stack()
	assert_eq(ghoul.counters.get("corpse", 0), 1, "one counter spent")
	g.destroy(ghoul)
	assert_eq(ghoul.zone, Mtg.Zone.BATTLEFIELD, "regenerated")


func test_stone_giant_launches_and_dooms_a_creature() -> void:
	var giant := put_battlefield(0, "Stone Giant")   # 3/4
	var lions := put_battlefield(0, "Savannah Lions")     # 2/1
	var minotaur := put_battlefield(0, "Hurloon Minotaur")   # 2/3 — too tough
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, giant, 0, [TargetRef.card(minotaur)]),
		"Illegal target")
	assert_ok(g.activate_ability(0, giant, 0, [TargetRef.card(lions)]))
	resolve_stack()
	assert_true(lions.has_keyword(Mtg.Keyword.FLYING))
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(lions.zone, Mtg.Zone.GRAVEYARD, "the Giant throws hard")


func test_berserk_doubles_power_and_kills_the_attacker() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var berserk := give_hand(0, "Berserk")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, berserk, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_power, 4)
	assert_true(bear.has_keyword(Mtg.Keyword.TRAMPLE))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 16)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "it attacked, so it dies")


func test_spell_blast_only_counters_the_right_cost() -> void:
	var bolt := give_hand(1, "Lightning Bolt")       # mana value 1
	var blast := give_hand(0, "Spell Blast")
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 2)
	# "with mana value X" is a TARGETING restriction (CR 115.4): a Blast for
	# 2 may not even be aimed at a one-mana spell (audit 2026-09; this test
	# used to let the cast through and watch it fizzle).
	assert_refused(g.cast_spell(0, blast, [TargetRef.card(bolt)], 2))
	resolve_stack()
	assert_eq(g.players[0].life, 17, "the bolt resolved; the Blast never did")


func test_glasses_of_urza_peeks_at_a_hand() -> void:
	var glasses := put_battlefield(0, "Glasses of Urza")
	give_hand(1, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, glasses, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 1, "looking changes nothing")

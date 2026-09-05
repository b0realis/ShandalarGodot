extends GameTest
## Wave-19 tests: the Legends "one activated ability" cycle — graveyard
## recursion (Adun Oakenshield), card flow (Xira Arien), legendary mana
## dorks (Princess Lucrezia, Riven Turnbull, Sunastian Falconer), combat
## tricks on a stick (Tuknir Deathlock, Pavel Maliki, Wall of Opposition),
## regeneration (Ragnar, Walking Dead), a shrinker (Ghosts of the Damned)
## and colour-hosed removal (Spinal Villain).


func test_adun_oakenshield_buys_a_corpse_back() -> void:
	var adun := put_battlefield(0, "Adun Oakenshield")
	var bear := put_battlefield(0, "Grizzly Bears")
	g.destroy(bear, false)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, adun, 0, [TargetRef.card(bear)]))
	assert_true(adun.tapped, "{T} is part of the cost")
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.HAND)


func test_adun_cannot_rob_the_other_graveyard() -> void:
	var adun := put_battlefield(0, "Adun Oakenshield")
	var theirs := put_battlefield(1, "Grizzly Bears")
	g.destroy(theirs, false)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.G)
	assert_refused(g.activate_ability(0, adun, 0, [TargetRef.card(theirs)]),
		"Illegal target")


func test_xira_arien_draws_for_either_player() -> void:
	var xira := put_battlefield(0, "Xira Arien")
	assert_true(xira.has_keyword(Mtg.Keyword.FLYING))
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, xira, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 1, "Xira can gift the draw to anyone")


func test_legendary_mana_dorks() -> void:
	var lucrezia := put_battlefield(0, "Princess Lucrezia")
	var riven := put_battlefield(0, "Riven Turnbull")
	var sunastian := put_battlefield(0, "Sunastian Falconer")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.tap_for_mana(0, lucrezia))
	assert_ok(g.tap_for_mana(0, riven))
	assert_ok(g.tap_for_mana(0, sunastian))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 1)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 1)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 2)


func test_mana_dork_has_summoning_sickness() -> void:
	var lucrezia := put_battlefield(0, "Princess Lucrezia", true)
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.tap_for_mana(0, lucrezia), "summoning sickness")


func test_tuknir_deathlock_pumps_a_friend() -> void:
	var tuknir := put_battlefield(0, "Tuknir Deathlock")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_true(tuknir.has_keyword(Mtg.Keyword.FLYING))
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, tuknir, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_power, 4)
	assert_eq(bear.cur_toughness, 4)


func test_pavel_maliki_pumps_himself_repeatedly() -> void:
	var pavel := put_battlefield(0, "Pavel Maliki")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.activate_ability(0, pavel, 0, []))
	assert_ok(g.activate_ability(0, pavel, 0, []))
	assert_false(pavel.tapped, "no tap in the cost")
	resolve_stack()
	assert_eq(pavel.cur_power, 7)
	assert_eq(pavel.cur_toughness, 3)


func test_ragnar_saves_a_creature_from_destruction() -> void:
	var ragnar := put_battlefield(0, "Ragnar")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.activate_ability(0, ragnar, 0, [TargetRef.card(bear)]))
	resolve_stack()
	g.destroy(bear)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "regenerated")
	assert_true(bear.tapped)


func test_wall_of_opposition_grows_for_a_mana_each() -> void:
	var wall := put_battlefield(0, "Wall of Opposition")
	assert_true(wall.has_keyword(Mtg.Keyword.DEFENDER))
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 4)
	for i in 4:
		assert_ok(g.activate_ability(0, wall, 0, []))
	resolve_stack()
	assert_eq(wall.cur_power, 4)
	assert_eq(wall.cur_toughness, 6, "toughness untouched")


func test_ghosts_of_the_damned_blunt_an_attacker() -> void:
	var ghosts := put_battlefield(0, "Ghosts of the Damned")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, ghosts, 0, [TargetRef.card(bear)]))
	assert_true(ghosts.tapped)
	resolve_stack()
	assert_eq(bear.cur_power, 1)
	assert_eq(bear.cur_toughness, 2, "only power shrinks")


func test_walking_dead_regenerates_itself() -> void:
	var dead := put_battlefield(0, "Walking Dead")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, dead, 0, []))
	resolve_stack()
	g.destroy(dead)
	assert_eq(dead.zone, Mtg.Zone.BATTLEFIELD)
	g.destroy(dead)
	assert_eq(dead.zone, Mtg.Zone.GRAVEYARD, "one shield, one save")


func test_spinal_villain_only_kills_blue() -> void:
	var villain := put_battlefield(0, "Spinal Villain")
	var bear := put_battlefield(1, "Grizzly Bears")
	var wizard := put_battlefield(1, "Prodigal Sorcerer")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, villain, 0, [TargetRef.card(bear)]),
		"Illegal target")
	assert_ok(g.activate_ability(0, villain, 0, [TargetRef.card(wizard)]))
	resolve_stack()
	assert_eq(wizard.zone, Mtg.Zone.GRAVEYARD)

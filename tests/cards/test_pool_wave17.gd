extends GameTest
## Wave-17 tests: Arabian Nights & The Dark starters — pump utility
## (Wyluli Wolf, Army of Allah), tribal-hate removal (King Suleiman,
## Exorcist), self-harm flyers (Juzám Djinn, Serendib Efreet), attack
## taxes (Hasran Ogress), death-count growth (Khabál Ghoul — engine's
## creatures_died_this_turn), regenerators (Drowned), wall-haters
## (Bog Rats, Goblin Digging Team) and the color-filtered sweep
## (Holy Light).


func test_wyluli_wolf_howls() -> void:
	var wolf := put_battlefield(0, "Wyluli Wolf")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, wolf, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_power, 3)
	assert_eq(bear.cur_toughness, 3)
	assert_true(wolf.tapped)


func test_army_of_allah_pumps_attackers_only() -> void:
	var lions := put_battlefield(0, "Savannah Lions")
	var home := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [lions.id]))
	var army := give_hand(0, "Army of Allah")
	add_mana(0, Mtg.ManaColor.W, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, army, []))
	resolve_stack()
	assert_eq(lions.cur_power, 4, "2 + 2")
	assert_eq(home.cur_power, 2)


func test_king_suleiman_banishes_djinn() -> void:
	var king := put_battlefield(0, "King Suleiman")
	var djinn := put_battlefield(1, "Mahamoti Djinn")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.activate_ability(0, king, 0, [TargetRef.card(bear)]),
		"Illegal target")
	assert_ok(g.activate_ability(0, king, 0, [TargetRef.card(djinn)]))
	resolve_stack()
	assert_eq(djinn.zone, Mtg.Zone.GRAVEYARD)


func test_juzam_djinn_gnaws_its_master() -> void:
	var juzam := put_battlefield(0, "Juzám Djinn")
	assert_eq(juzam.cur_power, 5)
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_step(Mtg.Step.UPKEEP)   # opponent's upkeep — silent
	resolve_stack()
	assert_eq(g.players[0].life, 20)
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_step(Mtg.Step.UPKEEP)   # OUR upkeep
	resolve_stack()
	assert_eq(g.players[0].life, 19, "the djinn takes its bite")


func test_serendib_efreet_same_deal_with_wings() -> void:
	var serendib := put_battlefield(0, "Serendib Efreet")
	assert_true(serendib.has_keyword(Mtg.Keyword.FLYING))
	assert_eq(serendib.cur_toughness, 4)
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_step(Mtg.Step.UPKEEP)
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_step(Mtg.Step.UPKEEP)
	resolve_stack()
	assert_eq(g.players[0].life, 19)


func test_hasran_ogress_taxes_the_attack() -> void:
	var ogress := put_battlefield(0, "Hasran Ogress")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [ogress.id]))
	resolve_stack()
	assert_eq(g.players[0].life, 17, "no {2} available — 3 damage")
	advance_to_next_turn()
	advance_to_next_turn()
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Swamp")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [ogress.id]))
	resolve_stack()
	assert_eq(g.players[0].life, 17, "paid {2} from the swamps — no damage")


func test_khabal_ghoul_feasts_on_the_fallen() -> void:
	var ghoul := put_battlefield(0, "Khabál Ghoul")
	var bear := put_battlefield(1, "Grizzly Bears")
	var lions := put_battlefield(1, "Savannah Lions")
	advance_to_step(Mtg.Step.MAIN1)
	g.destroy(bear, false)
	g.destroy(lions, false)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(ghoul.cur_power, 3, "1 + 2 corpses")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.END)   # a quiet end step adds nothing
	resolve_stack()
	assert_eq(ghoul.cur_power, 3, "counters persist, no new deaths")


func test_drowned_regenerates_off_color() -> void:
	var drowned := put_battlefield(0, "Drowned")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, drowned, 0, []))
	resolve_stack()
	g.destroy(drowned, true)
	assert_eq(drowned.zone, Mtg.Zone.BATTLEFIELD)


func test_exorcist_purges_black_creatures() -> void:
	var exorcist := put_battlefield(0, "Exorcist")
	var zombies := put_battlefield(1, "Scathe Zombies")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_refused(g.activate_ability(0, exorcist, 0, [TargetRef.card(bear)]),
		"Illegal target")
	assert_ok(g.activate_ability(0, exorcist, 0, [TargetRef.card(zombies)]))
	resolve_stack()
	assert_eq(zombies.zone, Mtg.Zone.GRAVEYARD)


func test_bog_rats_sidestep_walls() -> void:
	var rats := put_battlefield(0, "Bog Rats")
	var wall := put_battlefield(1, "Wall of Stone")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [rats.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {wall.id: rats.id}), "wall")
	assert_ok(g.declare_blockers(1, {bear.id: rats.id}))


func test_goblin_digging_team_trades_itself_for_a_wall() -> void:
	var team := put_battlefield(0, "Goblin Digging Team")
	var wall := put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, team, 0, [TargetRef.card(wall)]))
	assert_eq(team.zone, Mtg.Zone.GRAVEYARD, "sacrificed as part of the cost")
	resolve_stack()
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD)


func test_holy_light_spares_the_white() -> void:
	var lions := put_battlefield(1, "Savannah Lions")   # white 2/1
	var bear := put_battlefield(1, "Grizzly Bears")     # green 2/2
	var light := give_hand(0, "Holy Light")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, light, []))
	resolve_stack()
	assert_eq(lions.zone, Mtg.Zone.BATTLEFIELD, "white — untouched")
	assert_eq(lions.cur_power, 2)
	assert_eq(bear.cur_power, 1, "-1/-1")
	assert_eq(bear.cur_toughness, 1)

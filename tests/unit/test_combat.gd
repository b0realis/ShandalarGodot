extends GameTest
## Engine tests: combat — attack/block legality, keywords (flying, reach,
## vigilance, trample, haste via sickness), simultaneous damage, lethality.


func test_unblocked_attacker_hits_player() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	run_combat([bear.id])
	assert_eq(g.players[1].life, 18)
	assert_true(bear.tapped, "attacking taps non-vigilance creatures")


func test_summoning_sick_cannot_attack() -> void:
	var bear := put_battlefield(0, "Grizzly Bears", true)   # sick
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [bear.id]), "summoning sickness")


func test_vigilance_attacker_stays_untapped() -> void:
	var serra := put_battlefield(0, "Serra Angel")
	run_combat([serra.id])
	assert_false(serra.tapped)
	assert_eq(g.players[1].life, 16)


func test_two_two_trade_kills_both() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var zombies := put_battlefield(1, "Scathe Zombies")
	run_combat([bear.id], {zombies.id: bear.id})
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "simultaneous damage kills both")
	assert_eq(zombies.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 20, "blocked attacker deals no player damage")


func test_ground_creature_cannot_block_flyer() -> void:
	var elemental := put_battlefield(0, "Air Elemental")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [elemental.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {bear.id: elemental.id}), "flying")


func test_flyer_can_block_flyer() -> void:
	var elemental := put_battlefield(0, "Air Elemental")
	var serra := put_battlefield(1, "Serra Angel")
	run_combat([elemental.id], {serra.id: elemental.id})
	assert_eq(elemental.zone, Mtg.Zone.GRAVEYARD, "4 damage kills the 4/4")
	assert_eq(serra.zone, Mtg.Zone.GRAVEYARD)


func test_trample_carries_excess_damage() -> void:
	var mammoth := put_battlefield(0, "War Mammoth")     # 3/3 trample
	var lions := put_battlefield(1, "Savannah Lions")     # 2/1 blocker
	run_combat([mammoth.id], {lions.id: mammoth.id})
	assert_eq(lions.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 18, "1 lethal to the 2/1, 2 tramples through")
	assert_eq(mammoth.damage, 2, "lions hit back for 2")
	assert_eq(mammoth.zone, Mtg.Zone.BATTLEFIELD)


func test_no_trample_wastes_excess() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")       # 2/2, no trample
	var lions := put_battlefield(1, "Savannah Lions")      # 2/1 blocker
	run_combat([bear.id], {lions.id: bear.id})
	assert_eq(lions.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 20, "no trample: the excess point is wasted")
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "lions' 2 power still kills the bear")


func test_combat_lethal_ends_game() -> void:
	g.players[1].life = 2
	var bear := put_battlefield(0, "Grizzly Bears")
	run_combat([bear.id])
	assert_true(g.game_over)
	assert_eq(g.winner, 0)


func test_tapped_creature_cannot_block() -> void:
	var bear0 := put_battlefield(0, "Grizzly Bears")
	var bear1 := put_battlefield(1, "Grizzly Bears")
	bear1.tapped = true
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear0.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {bear1.id: bear0.id}), "tapped")


# --------------------------------------- NO ATTACKERS, NO COMBAT (CR 506.4) --

func test_declaring_no_attackers_skips_straight_to_end_of_combat() -> void:
	# CR 508.1 / 506.4: with no attacking creatures the declare-blockers
	# and combat-damage steps do not happen at all; the combat phase ends
	# at its end-of-combat step. The RULES half of the owner's 2026-09-03
	# playtest note, *"If no attackers are declared the combat subphases
	# should not show"* — the engine was already right, and this pins it
	# so the screen's half (CombatBar.shows_attack) is answering something
	# true.
	put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, []))
	assert_true(g.combat.attackers.is_empty())
	var seen: Array[int] = []
	for _i in 8:
		if g.current_step() == Mtg.Step.MAIN2:
			break
		g.pass_priority(g.priority_player)
		if not seen.has(g.current_step()):
			seen.append(g.current_step())
	assert_false(seen.has(Mtg.Step.DECLARE_BLOCKERS),
		"there are no blockers to declare against nothing")
	assert_false(seen.has(Mtg.Step.COMBAT_DAMAGE),
		"and no combat damage to deal")
	assert_true(seen.has(Mtg.Step.COMBAT_END),
		"the end-of-combat step still happens (CR 511)")

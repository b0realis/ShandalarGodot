extends GameTest
## Wave-48 tests: POISON counters and the GLYPH cycle. Both needed new
## per-turn history in the engine — poison lives on MtgPlayer and kills at
## ten (CR 704.5c); the Glyphs read CardInstance.blocked_ids_this_turn,
## the record of who a Wall stopped this turn and who controlled them.


func test_registry_loaded_wave48() -> void:
	for name in ["Pit Scorpion", "Marsh Viper", "Nafs Asp", "Serpent Generator",
			"Glyph of Life", "Glyph of Destruction", "Glyph of Doom",
			"Glyph of Delusion", "Glyph of Reincarnation"]:
		assert_not_null(CardRegistry.get_card(name), name)


# ------------------------------------------------------------------ poison --

func test_pit_scorpion_poisons_on_connection() -> void:
	var scorpion := put_battlefield(0, "Pit Scorpion")
	run_combat([scorpion.id])
	resolve_stack()
	assert_eq(g.players[1].poison, 1)
	assert_eq(g.players[1].life, 19, "the damage still happens")


func test_marsh_viper_poisons_twice() -> void:
	var viper := put_battlefield(0, "Marsh Viper")
	run_combat([viper.id])
	resolve_stack()
	assert_eq(g.players[1].poison, 2)


func test_ten_poison_counters_lose_the_game() -> void:
	g.add_poison(1, 9)
	assert_false(g.game_over)
	g.add_poison(1, 1)
	assert_true(g.game_over)
	assert_eq(g.winner, 0)


func test_poison_does_not_care_about_life() -> void:
	g.add_poison(1, 10)
	assert_true(g.players[1].has_lost)
	assert_eq(g.players[1].life, 20, "life was never touched")


func test_serpent_generator_makes_poisonous_snakes() -> void:
	var generator := put_battlefield(0, "Serpent Generator")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, generator, 0, []))
	resolve_stack()
	var snake := g.find_on_battlefield(0, "Snake")
	assert_not_null(snake)
	assert_true(snake.is_type(Mtg.CardType.ARTIFACT))
	assert_eq(snake.cur_power, 1)
	snake.summoning_sick = false
	run_combat([snake.id])
	resolve_stack()
	assert_eq(g.players[1].poison, 1)


# ---------------------------------------------------------------- Nafs Asp --

func test_nafs_asp_taxes_the_bitten_players_draw_step() -> void:
	var asp := put_battlefield(0, "Nafs Asp")
	run_combat([asp.id])
	resolve_stack()
	assert_eq(g.settleable_delayed_triggers(1).size(), 1,
		"the bite is a delayed trigger the bitten player may pay off")
	advance_to_next_turn()      # player 1's turn: their draw step collects
	resolve_stack()
	assert_eq(g.players[1].life, 18, "1 combat damage plus the unpaid 1")


func test_nafs_asp_debt_can_be_paid() -> void:
	var asp := put_battlefield(0, "Nafs Asp")
	put_battlefield(1, "Forest")
	run_combat([asp.id])
	resolve_stack()
	advance_to_next_turn()
	resolve_stack()
	assert_eq(g.players[1].life, 19, "they paid the {1} with their Forest")


# ------------------------------------------------------------ Glyph of Life --

func test_glyph_of_life_pays_for_every_hit_on_the_wall() -> void:
	var attacker := put_battlefield(0, "Hill Giant")     # 3/3
	var wall := put_battlefield(1, "Wall of Stone")      # 0/8
	var glyph := give_hand(1, "Glyph of Life")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: attacker.id}))
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(1, glyph, [TargetRef.card(wall)]))
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 23, "3 damage to the Wall, 3 life gained")


# ----------------------------------------------------- Glyph of Destruction --

func test_glyph_of_destruction_turns_a_wall_into_a_cannon() -> void:
	var attacker := put_battlefield(0, "Hill Giant")     # 3/3
	var wall := put_battlefield(1, "Wall of Stone")      # 0/8
	var glyph := give_hand(1, "Glyph of Destruction")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: attacker.id}))
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, glyph, [TargetRef.card(wall)]))
	resolve_stack()
	assert_eq(wall.cur_power, 10)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(attacker.zone, Mtg.Zone.GRAVEYARD, "10 power kills the Giant")
	assert_eq(wall.damage, 0, "all damage to the Wall was prevented")
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD, "and the Wall dies at end of turn")


func test_glyph_of_destruction_needs_a_blocking_wall() -> void:
	var wall := put_battlefield(1, "Wall of Stone")
	var glyph := give_hand(1, "Glyph of Destruction")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(1, glyph, [TargetRef.card(wall)]), "Illegal target")


# ------------------------------------------------------------ Glyph of Doom --

func test_glyph_of_doom_kills_what_the_wall_blocked() -> void:
	var attacker := put_battlefield(0, "Hill Giant")
	var wall := put_battlefield(1, "Wall of Stone")
	var glyph := give_hand(1, "Glyph of Doom")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: attacker.id}))
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(1, glyph, [TargetRef.card(wall)]))
	resolve_stack()
	assert_eq(attacker.zone, Mtg.Zone.BATTLEFIELD, "not yet")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(attacker.zone, Mtg.Zone.GRAVEYARD, "at end of combat it dies")


# -------------------------------------------------------- Glyph of Delusion --

func test_glyph_of_delusion_locks_a_blocked_attacker_down() -> void:
	var attacker := put_battlefield(0, "Hill Giant")     # 3 power → 3 counters
	var wall := put_battlefield(1, "Wall of Stone")
	var glyph := give_hand(1, "Glyph of Delusion")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: attacker.id}))
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(1, glyph, [TargetRef.card(attacker), TargetRef.card(wall)]))
	resolve_stack()
	assert_eq(int(attacker.counters.get("glyph", 0)), 3)
	assert_true(attacker.tapped, "it tapped to attack")
	advance_to_next_turn()      # their turn
	advance_to_next_turn()      # ours again: untap is skipped, one counter ticks
	assert_true(attacker.tapped, "the glyph counters hold it down")
	assert_eq(int(attacker.counters.get("glyph", 0)), 2)


func test_glyph_of_delusion_needs_a_creature_a_wall_blocked() -> void:
	var loose := put_battlefield(0, "Hill Giant")
	var wall := put_battlefield(1, "Wall of Stone")
	var glyph := give_hand(1, "Glyph of Delusion")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.U)
	assert_refused(g.cast_spell(1, glyph, [TargetRef.card(loose), TargetRef.card(wall)]),
		"Illegal target")


# --------------------------------------------------- Glyph of Reincarnation --

func test_glyph_of_reincarnation_trades_the_blocked_for_the_buried() -> void:
	var attacker := put_battlefield(0, "Hill Giant")
	var wall := put_battlefield(1, "Wall of Stone")
	# A body waiting in the ATTACKER's graveyard — that is the graveyard the
	# printed card reaches into.
	var dead := give_hand(0, "Serra Angel")
	g.players[0].hand.erase(dead)
	dead.zone = Mtg.Zone.GRAVEYARD
	g.players[0].graveyard.append(dead)
	var glyph := give_hand(1, "Glyph of Reincarnation")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: attacker.id}))
	advance_to_step(Mtg.Step.MAIN2)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(1, glyph, [TargetRef.card(wall)]))
	resolve_stack()
	# CORRECTED 2026-09-01 (docs/audit-vs-s30.md): the replacement body is
	# the GLYPH CONTROLLER's choice, not the graveyard owner's (CR 609.3 —
	# the card names whose graveyard, not who chooses). They pick the WORST
	# body in it, and after the destruction that is the Giant they just
	# killed, which is a legal answer and the reason the card is a trade
	# rather than a Wrath. The Angel stays buried.
	assert_eq(attacker.zone, Mtg.Zone.BATTLEFIELD,
		"the Giant died and was handed straight back — the cheapest body")
	assert_eq(dead.zone, Mtg.Zone.GRAVEYARD,
		"their Angel is not what the Glyph's controller would give them")
	assert_eq(attacker.controller_id, 0, "under its OWNER's control")


func test_glyph_of_reincarnation_only_after_combat() -> void:
	var wall := put_battlefield(1, "Wall of Stone")
	var glyph := give_hand(1, "Glyph of Reincarnation")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.G)
	assert_refused(g.cast_spell(1, glyph, [TargetRef.card(wall)]), "after combat")

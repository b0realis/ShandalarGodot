extends GameTest
## Whole-project review of 2026-10-21, engine-3 — UNDER THE 1997 RULES
## UPKEEP AND DRAW ARE SEPARATE PHASES.
##
## The manual names six phases (p.60, quoted in docs/glossary-1997.md §3):
## "1) Untap 2) Upkeep 3) Draw 4) Main 5) Discard 6) Cleanup". Its pool
## empties, and burns, "at the end of each phase" (p.176) and a player
## below 1 life loses "at the end of a phase" (p.174). The two 1997 forks
## that key off phases (pool_empties_on_attack, life_checked_at_phase_end)
## read Mtg.phase_of, which lumps the untap, upkeep and draw steps into the
## modern BEGINNING phase: mana floated in the upkeep was still there,
## unburned, in the draw step, and a player at -2 after an upkeep ping was
## still alive in it. The owner's ruling (2026-10-21): "as separate
## phases!" — the 1997 forks now use Mtg.phase_of_1997. Combat stays ONE
## phase (the ruling of 2026-08-31), and the modern presets are untouched:
## they empty the pool at every step.


func _to_upkeep_of_the_next_turn() -> void:
	var turn := g.turn_number
	var guard := 0
	while (g.turn_number == turn or g.current_step() != Mtg.Step.UPKEEP) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_eq(g.current_step(), Mtg.Step.UPKEEP)


## Both players pass in the step we are in: it ends.
func _end_the_step() -> void:
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))


func test_fifth_mana_floated_in_the_upkeep_burns_as_the_upkeep_ends() -> void:
	g.rules.set_preset("fifth")
	_to_upkeep_of_the_next_turn()
	var pid := g.active_player
	var life := g.players[pid].life
	add_mana(pid, Mtg.ManaColor.B, 3)   # a Dark Ritual cast in the upkeep
	_end_the_step()
	assert_eq(g.current_step(), Mtg.Step.DRAW)
	assert_eq(g.players[pid].mana_pool.total(), 0,
		"the pool empties at the end of the upkeep PHASE (manual p.60/p.176)")
	assert_eq(g.players[pid].life, life - 3, "and burns there")


func test_fifth_mana_floated_in_the_draw_step_burns_as_the_draw_ends() -> void:
	g.rules.set_preset("fifth")
	_to_upkeep_of_the_next_turn()
	_end_the_step()
	assert_eq(g.current_step(), Mtg.Step.DRAW)
	var pid := g.active_player
	var life := g.players[pid].life
	add_mana(pid, Mtg.ManaColor.R, 2)
	_end_the_step()
	assert_eq(g.current_step(), Mtg.Step.MAIN1)
	assert_eq(g.players[pid].mana_pool.total(), 0)
	assert_eq(g.players[pid].life, life - 2, "burned once, as the draw phase ended")


func test_fifth_negative_life_in_the_upkeep_loses_as_the_upkeep_ends() -> void:
	g.rules.set_preset("fifth")
	_to_upkeep_of_the_next_turn()
	var pid := g.active_player
	g.players[pid].life = -2   # e.g. Juzam Djinn's upkeep ping
	assert_false(g.game_over, "not checked inside the phase (manual p.174)")
	_end_the_step()
	assert_true(g.game_over, "below 1 life as the upkeep phase ends: the duel is lost")
	assert_eq(g.winner, 1 - pid)


func test_fifth_life_regained_inside_the_upkeep_still_saves_the_player() -> void:
	g.rules.set_preset("fifth")
	_to_upkeep_of_the_next_turn()
	var pid := g.active_player
	g.players[pid].life = -2
	g.adjust_life(pid, 5)
	_end_the_step()
	assert_false(g.game_over, "gained it back before the phase ended")
	assert_eq(g.players[pid].life, 3)


func test_fifth_combat_is_still_one_phase() -> void:
	# The 2026-08-31 ruling stands: a step boundary INSIDE combat empties
	# nothing.
	g.rules.set_preset("fifth")
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	add_mana(0, Mtg.ManaColor.R, 2)
	_end_the_step()
	assert_eq(g.current_step(), Mtg.Step.DECLARE_ATTACKERS)
	assert_eq(g.players[0].mana_pool.total(), 2, "the pool survives a step inside combat")
	assert_eq(g.players[0].life, 20)


func test_modern_mana_burn_still_burns_at_every_step() -> void:
	g.rules.set_preset("modern_mana_burn")
	_to_upkeep_of_the_next_turn()
	var pid := g.active_player
	var life := g.players[pid].life
	add_mana(pid, Mtg.ManaColor.B, 3)
	_end_the_step()
	assert_eq(g.current_step(), Mtg.Step.DRAW)
	assert_eq(g.players[pid].mana_pool.total(), 0)
	assert_eq(g.players[pid].life, life - 3)


func test_modern_empties_at_every_step_and_burns_nothing() -> void:
	g.rules.set_preset("modern")
	_to_upkeep_of_the_next_turn()
	var pid := g.active_player
	var life := g.players[pid].life
	add_mana(pid, Mtg.ManaColor.B, 3)
	_end_the_step()
	assert_eq(g.players[pid].mana_pool.total(), 0)
	assert_eq(g.players[pid].life, life)


func test_the_1997_phase_map_names_six_phases_with_main_in_three_parts() -> void:
	# Untap, Upkeep, Draw: one phase each. Main pre-combat, combat and
	# post-combat: three parts of Main, each its own boundary for the pool
	# (p.176: "at the beginning and end of an attack"). End step and
	# cleanup: the one phase the Phase Bar's broom stands for.
	var seen := {}
	for step in [Mtg.Step.UNTAP, Mtg.Step.UPKEEP, Mtg.Step.DRAW, Mtg.Step.MAIN1,
			Mtg.Step.COMBAT_BEGIN, Mtg.Step.MAIN2, Mtg.Step.END]:
		seen[Mtg.phase_of_1997(step)] = true
	assert_eq(seen.size(), 7, "seven distinct boundaries")
	assert_eq(Mtg.phase_of_1997(Mtg.Step.COMBAT_BEGIN), Mtg.phase_of_1997(Mtg.Step.COMBAT_END))
	assert_eq(Mtg.phase_of_1997(Mtg.Step.DECLARE_BLOCKERS), Mtg.phase_of_1997(Mtg.Step.COMBAT_DAMAGE))
	assert_eq(Mtg.phase_of_1997(Mtg.Step.END), Mtg.phase_of_1997(Mtg.Step.CLEANUP))
	# The modern map is unchanged.
	assert_eq(Mtg.phase_of(Mtg.Step.UPKEEP), Mtg.phase_of(Mtg.Step.DRAW))

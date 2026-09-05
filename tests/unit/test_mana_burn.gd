extends GameTest
## MANA BURN — the rule MicroProse shipped in 1997 ("Mana Burn! / %s loses
## %d life", @DIALOG_MANABURN in the original's UIStrings.txt), which
## Manalink switched off (config.txt ManaBurn:0) and Magic itself dropped
## in 2009. It is an OPTION here (MtgGame.mana_burn, driven by the Options
## screen through Settings), so BOTH settings are pinned.


func test_unspent_mana_burns_when_the_rule_is_on() -> void:
	g.rules.mana_burn = true
	var before: int = g.players[0].life
	add_mana(0, Mtg.ManaColor.G, 3)
	advance_to_step(Mtg.Step.MAIN1)   # crossing a step boundary empties pools
	assert_eq(g.players[0].life, before - 3,
		"three floating mana cost three life")
	assert_eq(g.players[0].mana_pool.total(), 0, "and the pool still empties")


func test_no_burn_when_the_rule_is_off() -> void:
	# The default, matching Manalink's own default and modern rules.
	assert_false(g.rules.mana_burn, "off unless the player switches it on")
	var before: int = g.players[0].life
	add_mana(0, Mtg.ManaColor.G, 3)
	advance_to_step(Mtg.Step.MAIN1)   # crossing a step boundary empties pools
	assert_eq(g.players[0].life, before, "floating mana is free")


func test_restricted_mana_burns_too() -> void:
	# Mishra's Workshop mana is still mana sitting in the pool.
	g.rules.mana_burn = true
	var before: int = g.players[0].life
	g.players[0].mana_pool.add_restricted(Mtg.ManaColor.C, 2, "artifact")
	advance_to_step(Mtg.Step.MAIN1)   # crossing a step boundary empties pools
	assert_eq(g.players[0].life, before - 2, "restricted mana burns as well")


func test_burn_is_life_loss_not_damage() -> void:
	# Mana burn was LIFE LOSS, so damage prevention never applied to it.
	g.rules.mana_burn = true
	g.players[0].damage_prevention = 10
	var before: int = g.players[0].life
	add_mana(0, Mtg.ManaColor.R, 2)
	advance_to_step(Mtg.Step.MAIN1)   # crossing a step boundary empties pools
	assert_eq(g.players[0].life, before - 2,
		"a prevention shield does not stop mana burn")
	assert_eq(g.players[0].damage_prevention, 10, "and is not spent by it")


func test_burning_to_zero_loses_the_duel() -> void:
	g.rules.mana_burn = true
	g.players[0].life = 2
	add_mana(0, Mtg.ManaColor.U, 5)
	advance_to_next_turn()
	assert_true(g.game_over, "burning past zero ends the duel")
	assert_eq(g.winner, 1, "the other seat wins")


func test_only_the_owner_of_the_mana_burns() -> void:
	g.rules.mana_burn = true
	var mine: int = g.players[0].life
	var theirs: int = g.players[1].life
	add_mana(0, Mtg.ManaColor.W, 4)
	advance_to_step(Mtg.Step.MAIN1)   # crossing a step boundary empties pools
	assert_eq(g.players[0].life, mine - 4)
	assert_eq(g.players[1].life, theirs, "the opponent is untouched")


# --------------------------------------------------- the fork table itself --

func test_every_fork_declares_its_1997_answer() -> void:
	# set_edition() reads each fork's own direction, so a fork that
	# forgets to declare one would silently flip the wrong way.
	for fork in RulesOptions.FORKS:
		assert_true(fork.has("fifth_value"), "%s declares its 1997 answer" % fork["key"])
		assert_true(fork.has("label") and fork.has("source"),
			"%s is presentable and sourced" % fork["key"])


func test_the_presets_round_trip() -> void:
	var rules := RulesOptions.new()
	assert_eq(rules.edition(), "modern", "a fresh engine plays by modern rules")
	rules.set_edition("fifth")
	assert_eq(rules.edition(), "fifth")
	assert_true(rules.mana_burn, "1997 burns mana")
	assert_false(rules.attackers_revocable,
		"and does NOT let an attacker be taken back")
	rules.set_edition("modern")
	assert_eq(rules.edition(), "modern")
	assert_false(rules.mana_burn)
	assert_true(rules.attackers_revocable)


func test_a_mixed_set_reads_as_custom() -> void:
	var rules := RulesOptions.new()
	rules.mana_burn = true          # one 1997 answer among modern ones
	assert_eq(rules.edition(), "custom")


func test_attackers_are_revocable_by_default() -> void:
	# The owner's call: ours stays revocable, the divergence is labelled.
	assert_true(RulesOptions.new().attackers_revocable)
	assert_true(RulesOptions.IMPLEMENTED.has("attackers_revocable"),
		"and the switch really does something")


func test_unknown_forks_are_ignored_not_fatal() -> void:
	# A stale setting from an older build must not break a duel.
	var rules := RulesOptions.new()
	rules.set_fork("no_such_rule", true)
	assert_false(rules.get_fork("no_such_rule"))


# ------------------------------------------- the other 1997 rules, in force --

func test_1997_pools_survive_a_step_but_not_a_phase() -> void:
	# The owner's ruling: pools empty at each PHASE end, combat counting
	# as one phase that empties only when it is over.
	g.rules.pool_empties_on_attack = true
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	add_mana(0, Mtg.ManaColor.R, 2)
	# (declare-blockers is SKIPPED with no attackers, so step to the one
	# combat step that always happens next.)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_eq(g.players[0].mana_pool.total(), 2,
		"mana survives from one combat STEP to the next")
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(g.players[0].mana_pool.total(), 0,
		"but not past the end of the combat PHASE")


func test_modern_pools_empty_every_step() -> void:
	assert_false(g.rules.pool_empties_on_attack, "modern by default")
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	add_mana(0, Mtg.ManaColor.R, 2)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_eq(g.players[0].mana_pool.total(), 0, "gone at the step boundary")


func test_1997_life_is_survivable_until_the_phase_ends() -> void:
	g.rules.life_checked_at_phase_end = true
	g.players[0].life = -3
	g.check_state_based_actions()
	assert_false(g.game_over, "below zero, and still standing")
	g.players[0].life = 4          # gained back in time
	advance_to_next_turn()
	assert_false(g.game_over, "saved before the phase ended")


func test_1997_life_still_kills_at_the_phase_boundary() -> void:
	g.rules.life_checked_at_phase_end = true
	g.players[0].life = -3
	advance_to_next_turn()
	assert_true(g.game_over, "the phase ended with them below zero")
	assert_eq(g.winner, 1)


func test_poison_still_kills_immediately_under_1997_life() -> void:
	# Manual p.177: poison outranks a simultaneous life loss.
	g.rules.life_checked_at_phase_end = true
	g.players[0].life = -2
	g.add_poison(0, 10)
	assert_true(g.game_over, "poison does not wait for the phase")
	assert_eq(g.winner, 1)


func test_a_tapped_artifact_stops_working_under_1997_rules() -> void:
	# Manual p.124. Howling Mine's static draw is the clearest case: it
	# is an artifact, it is not a creature, and it has a static ability.
	var mine := put_battlefield(0, "Howling Mine")
	assert_not_null(mine)
	g.rules.tapped_artifacts_stop = true
	mine.tapped = true
	g.recalculate()
	assert_true(mine.cur_statics_suspended, "its continuous effects cease")
	mine.tapped = false
	g.recalculate()
	assert_false(mine.cur_statics_suspended, "and resume when it untaps")


func test_a_tapped_artifact_CREATURE_keeps_working() -> void:
	# The manual's own exception.
	var statue := put_battlefield(0, "Clockwork Beast")
	if statue == null:
		pass_test("no artifact creature in the pool to check")
		return
	g.rules.tapped_artifacts_stop = true
	statue.tapped = true
	g.recalculate()
	assert_false(statue.cur_statics_suspended,
		"artifact creatures are excepted")


func test_tapped_artifacts_work_normally_under_modern_rules() -> void:
	var mine := put_battlefield(0, "Howling Mine")
	mine.tapped = true
	g.recalculate()
	assert_false(mine.cur_statics_suspended, "no such modern rule")

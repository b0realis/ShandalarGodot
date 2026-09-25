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


func _watch_burns() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	g.event_occurred.connect(func(event: GameEvent):
		if event.type == Mtg.EventType.MANA_BURN:
			events.append(event.data.duplicate()))
	return events


func test_burn_announces_only_actual_life_loss(params = use_parameters([
		[0, true, 3], [1, true, 2], [0, false, 3], [1, true, 0]])) -> void:
	var pid: int = params[0]
	var enabled: bool = params[1]
	var amount: int = params[2]
	g.rules.mana_burn = enabled
	var events := _watch_burns()
	add_mana(pid, Mtg.ManaColor.G, amount)
	advance_to_step(Mtg.Step.MAIN1)
	if enabled and amount > 0:
		assert_eq(events, [{"player": pid, "amount": amount}] as Array[Dictionary],
			"one public event for the burned seat and the actual amount")
	else:
		assert_true(events.is_empty(), "a boundary without a burn is silent")
	assert_eq(g.players[pid].life, 20 - amount if enabled else 20)
	assert_eq(g.players[pid].mana_pool.total(), 0)


func test_restricted_burn_is_announced_but_is_not_damage() -> void:
	g.rules.mana_burn = true
	g.players[0].damage_prevention = 10
	var events := _watch_burns()
	var damage: Array[GameEvent] = []
	g.event_occurred.connect(func(event: GameEvent):
		if event.type == Mtg.EventType.DAMAGE_DEALT:
			damage.append(event))
	g.players[0].mana_pool.add_restricted(Mtg.ManaColor.C, 2, "artifact")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(events, [{"player": 0, "amount": 2}] as Array[Dictionary])
	assert_true(damage.is_empty(), "burn must not trigger damage listeners")
	assert_eq(g.players[0].damage_prevention, 10)


func test_both_burns_are_applied_before_announcing_a_lethal_boundary() -> void:
	g.rules.set_edition("fifth")
	advance_to_step(Mtg.Step.MAIN1)
	g.players[0].life = 1
	g.players[1].life = 2
	add_mana(0, Mtg.ManaColor.R, 1)
	add_mana(1, Mtg.ManaColor.B, 2)
	var events := _watch_burns()
	var observed: Array = []
	g.event_occurred.connect(func(event: GameEvent):
		if event.type == Mtg.EventType.MANA_BURN:
			observed.append([g.players[0].life, g.players[1].life,
				g.players[0].mana_pool.total(), g.players[1].mana_pool.total()]))
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))
	assert_eq(events, [{"player": 0, "amount": 1},
		{"player": 1, "amount": 2}] as Array[Dictionary])
	assert_eq(observed, [[0, 0, 0, 0], [0, 0, 0, 0]],
		"observers see the completed boundary, not half of the life loss")
	assert_true(g.game_over, "the boundary still checks lethal life")
	assert_eq(g.winner, -1, "simultaneous lethal burns remain a draw")


func test_search_burns_do_not_reach_the_sound_layer() -> void:
	g.rules.mana_burn = true
	add_mana(0, Mtg.ManaColor.G, 2)
	var events := _watch_burns()
	var mark := g.make_mark()
	advance_to_step(Mtg.Step.MAIN1)
	assert_true(events.is_empty(), "speculative play cannot sound")
	g.unmake_to(mark)
	g.end_search()
	assert_eq(g.players[0].life, 20)
	assert_eq(g.players[0].mana_pool.total(), 2)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(events, [{"player": 0, "amount": 2}] as Array[Dictionary],
		"the same boundary sounds when played for real")


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
	assert_eq(rules.preset(), "modern", "a fresh engine plays by modern rules")
	rules.set_edition("fifth")
	assert_eq(rules.preset(), "fifth")
	assert_true(rules.mana_burn, "1997 burns mana")
	assert_false(rules.attackers_revocable,
		"and does NOT let an attacker be taken back")
	rules.set_edition("modern")
	assert_eq(rules.preset(), "modern")
	assert_false(rules.mana_burn)
	assert_true(rules.attackers_revocable)


func test_modern_with_mana_burn_is_a_named_preset() -> void:
	# The owner's word (2026-09-25): the player default — modern rules
	# with mana burn on — has a name of its own on the Options screen;
	# *"all other mix and match should be custom"*.
	var rules := RulesOptions.new()
	rules.mana_burn = true          # the one 1997 answer among modern ones
	assert_eq(rules.preset(), "modern_mana_burn")
	assert_eq(RulesOptions.preset_label("modern_mana_burn"), "Modern rules, mana burn on")
	assert_eq(RulesOptions.DEFAULT_PRESET, "modern_mana_burn", "and it is the player default")
	var named := RulesOptions.new()
	named.set_preset("modern_mana_burn")
	assert_true(named.matches(rules), "set_preset builds the same flags")
	named.set_preset("no such preset")
	assert_eq(named.preset(), "modern", "an unknown id is plain modern")


func test_any_other_mix_reads_as_custom() -> void:
	var rules := RulesOptions.new()
	rules.mana_burn = true
	rules.tapped_artifacts_stop = true      # a second 1997 answer
	assert_eq(rules.preset(), "custom")
	assert_eq(RulesOptions.preset_label(rules.preset()), "Custom")
	rules = RulesOptions.new()
	rules.attackers_revocable = false       # one 1997 answer, not mana burn
	assert_eq(rules.preset(), "custom", "only the mana-burn mix is named")
	rules.set_edition("fifth")
	rules.mana_burn = false                 # 1997 less one
	assert_eq(rules.preset(), "custom")


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

extends GameTest
## THE PRINTED TIMING RIDERS, one reading for every asker (2026-09-25).
## The owner: *"audit and fix (nettling imp plays like instant on the
## opponent turns only for example)"*. Nine card riders compared the step
## against the CANONICAL turn order, which knows nothing of the extra
## combat a Relentless Assault inserts; the engine's own `only_before_step`
## read the first occurrence of the step; and the AI carried two more
## copies of the same comparison. Now every "before X" asks
## `MtgGame.step_is_ahead` (an X step still to come this turn), every
## "after X" asks `MtgGame.step_is_behind` (every X of the turn taken),
## and the abilities' riders are one query, `ability_timing_refusal`,
## that `activate_ability`, the AI and the duel screen all put.


func before_each() -> void:
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids():
		CardPacks.set_enabled(id, false)


## Seat 0's turn: an extra combat and main after this main phase (the
## Portal Second Age card, pack 6), the way Relentless Assault gives it.
func _extra_combat() -> void:
	CardPacks.set_enabled("pack-6", true)
	var spell := give_hand(0, "Relentless Assault")
	for color in Mtg.WUBRG:
		add_mana(0, color, 3)
	assert_ok(g.cast_spell(0, spell))
	resolve_stack()
	g.players[0].mana_pool.clear()


## On to [param step] of seat 1's turn with the declarations made
## ([param attackers] are seat 1's) and seat 0 holding priority.
func _their_step(step: int, attackers: Array = []) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == step
			and not g.awaiting_attackers and not g.awaiting_blockers
			and g.priority_player == 0) and not g.game_over and guard < 400:
		if g.awaiting_attackers:
			assert_ok(g.declare_attackers(g.active_player,
				attackers if g.active_player == 1 else []))
		elif g.awaiting_blockers:
			assert_ok(g.declare_blockers(g.opponent_of(g.active_player), {}))
		else:
			assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_lt(guard, 400, "never reached their %s" % Mtg.step_name(step))


func _rider(name: String) -> String:
	return g.cast_timing_refusal(0, give_hand(0, name))


# ============================================================ the queries --

func test_step_is_ahead_reads_the_turn_from_here_on() -> void:
	assert_eq(g.current_step(), Mtg.Step.MAIN1)
	assert_true(g.step_is_ahead(Mtg.Step.DECLARE_ATTACKERS))
	assert_true(g.step_is_ahead(Mtg.Step.MAIN2))
	assert_false(g.step_is_ahead(Mtg.Step.MAIN1), "the step we are in is not ahead")
	assert_false(g.step_is_ahead(Mtg.Step.UPKEEP), "taken already")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_false(g.step_is_ahead(Mtg.Step.DECLARE_ATTACKERS))
	assert_true(g.step_is_ahead(Mtg.Step.MAIN2))
	assert_true(g.step_is_ahead(Mtg.Step.END))


func test_step_is_behind_needs_every_occurrence_taken() -> void:
	assert_true(g.step_is_behind(Mtg.Step.UPKEEP))
	assert_false(g.step_is_behind(Mtg.Step.MAIN1), "the step we are in is not behind")
	assert_false(g.step_is_behind(Mtg.Step.COMBAT_END))
	advance_to_step(Mtg.Step.MAIN2)
	assert_true(g.step_is_behind(Mtg.Step.COMBAT_END))


func test_an_extra_combat_puts_the_combat_steps_ahead_again() -> void:
	advance_to_step(Mtg.Step.MAIN2)
	assert_false(g.step_is_ahead(Mtg.Step.DECLARE_ATTACKERS))
	assert_true(g.step_is_behind(Mtg.Step.COMBAT_END))
	_extra_combat()
	assert_eq(g.current_step(), Mtg.Step.MAIN2)
	assert_true(g.step_is_ahead(Mtg.Step.DECLARE_ATTACKERS), "the next combat's")
	assert_true(g.step_is_ahead(Mtg.Step.COMBAT_DAMAGE))
	assert_false(g.step_is_behind(Mtg.Step.COMBAT_END), "one combat is still to come")
	advance_to_step(Mtg.Step.COMBAT_END)
	advance_to_step(Mtg.Step.MAIN2)
	assert_false(g.step_is_ahead(Mtg.Step.DECLARE_ATTACKERS))
	assert_true(g.step_is_behind(Mtg.Step.COMBAT_END), "the last combat is over")


# ========================================================== Nettling Imp --

func test_nettling_imp_is_refused_on_its_own_turn_in_every_step() -> void:
	var imp := put_battlefield(0, "Nettling Imp")
	var victim := put_battlefield(1, "Hill Giant")
	for step in [Mtg.Step.MAIN1, Mtg.Step.COMBAT_BEGIN, Mtg.Step.MAIN2, Mtg.Step.END]:
		advance_to_step(step)
		assert_eq(g.priority_player, 0)
		assert_refused(g.activate_ability(0, imp, 0, [TargetRef.card(victim)]),
			"opponent's turn")
		assert_string_contains(
			g.ability_timing_refusal(0, imp, imp.cur_activated_abilities[0]),
			"opponent's turn")


func test_nettling_imp_is_open_on_their_turn_until_attackers_are_declared() -> void:
	var imp := put_battlefield(0, "Nettling Imp")
	var victim := put_battlefield(1, "Hill Giant")
	var ability: ActivatedAbility = imp.cur_activated_abilities[0]
	_their_step(Mtg.Step.UPKEEP)
	assert_eq(g.ability_timing_refusal(0, imp, ability), "")
	_their_step(Mtg.Step.MAIN1)
	assert_eq(g.ability_timing_refusal(0, imp, ability), "")
	_their_step(Mtg.Step.COMBAT_BEGIN)
	assert_eq(g.ability_timing_refusal(0, imp, ability), "")
	assert_ok(g.activate_ability(0, imp, 0, [TargetRef.card(victim)]))
	resolve_stack()
	assert_true(victim.must_attack_this_turn)


func test_nettling_imp_is_refused_once_their_attackers_are_declared() -> void:
	var imp := put_battlefield(0, "Nettling Imp")
	var victim := put_battlefield(1, "Hill Giant")
	_their_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.activate_ability(0, imp, 0, [TargetRef.card(victim)]),
		"before attackers are declared")
	_their_step(Mtg.Step.MAIN2)
	assert_refused(g.activate_ability(0, imp, 0, [TargetRef.card(victim)]),
		"before attackers are declared")
	_their_step(Mtg.Step.END)
	assert_refused(g.activate_ability(0, imp, 0, [TargetRef.card(victim)]),
		"before attackers are declared")


func test_their_nettling_imp_is_refused_in_a_plain_second_main() -> void:
	var imp := put_battlefield(1, "Nettling Imp")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN2)
	assert_ok(g.pass_priority(0))
	assert_refused(g.activate_ability(1, imp, 0, [TargetRef.card(bear)]),
		"before attackers are declared")


func test_their_nettling_imp_conscripts_into_our_extra_combat() -> void:
	# Seat 0 casts Relentless Assault in Main 2; seat 1's Imp, refused in
	# a plain Main 2, is open in the main phase before the extra combat —
	# "before attackers are declared" is the NEXT declaration's.
	var imp := put_battlefield(1, "Nettling Imp")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN2)
	_extra_combat()
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, imp, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.must_attack_this_turn)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, []), "must attack")
	assert_ok(g.declare_attackers(0, [bear.id]))


# ================================================== the "before" spells --

func test_berserk_and_rapid_fire_are_legal_again_before_an_extra_combat() -> void:
	advance_to_step(Mtg.Step.MAIN2)
	assert_string_contains(_rider("Berserk"), "before the combat damage step")
	assert_string_contains(_rider("Rapid Fire"), "before blockers are declared")
	_extra_combat()
	assert_eq(_rider("Berserk"), "")
	assert_eq(_rider("Rapid Fire"), "")


func test_berserk_is_refused_from_the_combat_damage_step_on() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_eq(_rider("Berserk"), "")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	assert_eq(_rider("Berserk"), "")
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	assert_eq(_rider("Berserk"), "")
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_string_contains(_rider("Berserk"), "before the combat damage step")
	advance_to_step(Mtg.Step.END)
	assert_string_contains(_rider("Berserk"), "before the combat damage step")


func test_blaze_of_glory_and_disharmony_want_combat_before_blockers() -> void:
	var ogre := put_battlefield(1, "Gray Ogre")
	put_battlefield(0, "Wall of Stone")
	_their_step(Mtg.Step.MAIN1)
	assert_string_contains(_rider("Blaze of Glory"), "only during combat")
	assert_string_contains(_rider("Disharmony"), "only during combat")
	_their_step(Mtg.Step.COMBAT_BEGIN)
	assert_eq(_rider("Blaze of Glory"), "")
	assert_eq(_rider("Disharmony"), "")
	_their_step(Mtg.Step.DECLARE_ATTACKERS, [ogre.id])
	assert_eq(_rider("Blaze of Glory"), "")
	assert_eq(_rider("Disharmony"), "")
	_their_step(Mtg.Step.DECLARE_BLOCKERS, [ogre.id])
	assert_string_contains(_rider("Blaze of Glory"), "before blockers are declared")
	assert_string_contains(_rider("Disharmony"), "before blockers are declared")
	_their_step(Mtg.Step.MAIN2, [ogre.id])
	assert_string_contains(_rider("Blaze of Glory"), "only during combat")


# =================================================== the "after" spells --

func test_reset_waits_for_their_upkeep_to_pass() -> void:
	assert_string_contains(_rider("Reset"), "opponent's turn")
	_their_step(Mtg.Step.UPKEEP)
	assert_string_contains(_rider("Reset"), "after their upkeep")
	_their_step(Mtg.Step.DRAW)
	assert_eq(_rider("Reset"), "")
	_their_step(Mtg.Step.END)
	assert_eq(_rider("Reset"), "")


func test_glyph_of_reincarnation_waits_for_the_last_combat_of_the_turn() -> void:
	assert_string_contains(_rider("Glyph of Reincarnation"), "after combat")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_string_contains(_rider("Glyph of Reincarnation"), "after combat")
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(_rider("Glyph of Reincarnation"), "")
	_extra_combat()
	assert_string_contains(_rider("Glyph of Reincarnation"), "after combat")
	advance_to_step(Mtg.Step.COMBAT_END)
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(_rider("Glyph of Reincarnation"), "")


# ================================================ the engine's own rider --

func test_angus_mackenzie_before_step_reads_the_next_combat_damage() -> void:
	var angus := put_battlefield(0, "Angus Mackenzie")
	var bear := put_battlefield(0, "Grizzly Bears")
	var ability: ActivatedAbility = angus.cur_activated_abilities[0]
	assert_eq(g.ability_timing_refusal(0, angus, ability), "")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	assert_eq(g.ability_timing_refusal(0, angus, ability), "")
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_string_contains(g.ability_timing_refusal(0, angus, ability),
		"before the combat damage step")
	advance_to_step(Mtg.Step.MAIN2)
	assert_string_contains(g.ability_timing_refusal(0, angus, ability),
		"before the combat damage step")
	assert_refused(g.activate_ability(0, angus, 0), "before the combat damage step")
	_extra_combat()
	assert_eq(g.ability_timing_refusal(0, angus, ability), "", "the extra combat's")
	for color in Mtg.WUBRG:
		add_mana(0, color, 1)
	assert_ok(g.activate_ability(0, angus, 0))


func test_the_ai_reads_the_riders_through_the_same_query() -> void:
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	var imp := put_battlefield(0, "Nettling Imp")
	var angus := put_battlefield(0, "Angus Mackenzie")
	put_battlefield(1, "Hill Giant")
	assert_false(ai._ability_available(g, imp, 0), "the Imp on its own turn")
	assert_true(ai._ability_available(g, angus, 0), "Angus before combat damage")
	advance_to_step(Mtg.Step.MAIN2)
	assert_false(ai._ability_available(g, angus, 0), "Angus after combat")
	_their_step(Mtg.Step.UPKEEP)
	assert_true(ai._ability_available(g, imp, 0), "the Imp at their upkeep")
	assert_true(ai._ability_available(g, angus, 0))
	_their_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_false(ai._ability_available(g, imp, 0), "their attackers are declared")

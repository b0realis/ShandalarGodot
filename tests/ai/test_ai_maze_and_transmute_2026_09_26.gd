extends GameTest
## THE MAZE AND THE PRECONDITION (2026-09-26). Maze of Ith's {T} untaps
## an attacker out of their combat — a land whose only moment is their
## declare-blockers step, read through [member EffectIntent.fogs_attacker]
## and played under [member AiProfile.casts_timed_spells] at the COMBAT
## moment ([method AiPlayer._maze_pick]). Transmute Artifact with no
## artifact of ours resolves as a log line: the card declares the
## precondition ([member EffectIntent.needs_own]) and the cast is held
## under [member AiProfile.holds_duplicates], the second-legend knob.


func _wizard(seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, AiProfile.wizard())
	g.set_agent(seat, ai)
	return ai


func _their_step(step: int, attackers: Array = [], blocks: Dictionary = {}) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == step
			and not g.awaiting_attackers and not g.awaiting_blockers
			and g.priority_player == 0) and not g.game_over and guard < 400:
		if g.awaiting_attackers:
			assert_ok(g.declare_attackers(g.active_player,
				attackers if g.active_player == 1 else []))
		elif g.awaiting_blockers:
			assert_ok(g.declare_blockers(g.opponent_of(g.active_player),
				blocks if g.active_player == 1 else {}))
		else:
			assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_lt(guard, 400, "never reached their %s" % Mtg.step_name(step))


# ================================================================ the Maze --

func test_the_reader_flags_the_maze() -> void:
	var maze := put_battlefield(0, "Maze of Ith")
	var read := EffectIntent.read(maze.cur_activated_abilities[0].effects, "Maze of Ith")
	assert_true(read.fogs_attacker)
	assert_false(read.unknown)


func test_the_maze_takes_the_unblocked_attacker_out_of_the_combat() -> void:
	var ai := _wizard(0)
	var maze := put_battlefield(0, "Maze of Ith")
	var angel := put_battlefield(1, "Serra Angel")
	_their_step(Mtg.Step.DECLARE_BLOCKERS, [angel.id])
	var option := ai._ability_option(g, maze, 0, AiPlayer.Moment.COMBAT)
	assert_false(option.is_empty())
	assert_eq(option["targets"][0].instance_id, angel.id)
	assert_eq(float(option["value"]), 4.0 * 0.5 + 1.0, "four damage at twenty, plus one")
	assert_eq(ai.act(g), "activated Maze of Ith")
	resolve_stack()
	assert_true(maze.tapped)
	assert_false(angel.tapped, "the Angel is untapped out of the fight")
	advance_to_step(Mtg.Step.END)
	assert_eq(g.players[0].life, 20, "and dealt nothing")


func test_the_maze_is_the_game_against_a_lethal_swing() -> void:
	var ai := _wizard(0)
	var maze := put_battlefield(0, "Maze of Ith")
	var angel := put_battlefield(1, "Serra Angel")
	g.players[0].life = 4
	_their_step(Mtg.Step.DECLARE_BLOCKERS, [angel.id])
	var option := ai._ability_option(g, maze, 0, AiPlayer.Moment.COMBAT)
	assert_eq(float(option["value"]), AiPlayer.LETHAL_WORTH)
	assert_eq(ai.act(g), "activated Maze of Ith")


func test_the_maze_saves_the_blocker_that_would_die() -> void:
	var ai := _wizard(0)
	var maze := put_battlefield(0, "Maze of Ith")
	var bears := put_battlefield(0, "Grizzly Bears")
	var angel := put_battlefield(1, "Serra Angel")
	var pikemen := put_battlefield(1, "Pikemen")
	_their_step(Mtg.Step.DECLARE_BLOCKERS, [angel.id, pikemen.id], {bears.id: pikemen.id})
	var option := ai._ability_option(g, maze, 0, AiPlayer.Moment.COMBAT)
	assert_false(option.is_empty())
	assert_eq(option["targets"][0].instance_id, angel.id,
		"the unblocked Angel's four beat the blocked Pikemen's trade")


func test_the_maze_has_no_other_moment() -> void:
	var ai := _wizard(0)
	var maze := put_battlefield(0, "Maze of Ith")
	var angel := put_battlefield(1, "Serra Angel")
	_their_step(Mtg.Step.DECLARE_ATTACKERS, [angel.id])
	assert_true(ai._ability_option(g, maze, 0, AiPlayer.Moment.COMBAT).is_empty(),
		"not before the blocks are known")
	assert_true(ai._ability_option(g, maze, 0, AiPlayer.Moment.RESPONSE).is_empty())
	assert_eq(ai._try_activate(g, AiPlayer.Moment.MAIN), "")
	_their_step(Mtg.Step.DECLARE_BLOCKERS)
	ai.profile.casts_timed_spells = false
	assert_true(ai._ability_option(g, maze, 0, AiPlayer.Moment.COMBAT).is_empty(),
		"off, the combat moment is the sweeper's alone")
	assert_ne(ai.act(g), "activated Maze of Ith")


# ======================================================== the precondition --

func test_the_reader_carries_transmutes_precondition() -> void:
	var transmute := give_hand(0, "Transmute Artifact")
	var read := EffectIntent.read(transmute.data.spell_effects, "Transmute Artifact")
	assert_true(read.needs_own.is_valid())
	var vault := put_battlefield(0, "Time Vault")
	var bears := put_battlefield(0, "Grizzly Bears")
	assert_true(read.needs_own.call(vault))
	assert_false(read.needs_own.call(bears))


func test_transmute_is_held_with_no_artifact_to_give() -> void:
	var ai := _wizard(0)
	give_hand(0, "Transmute Artifact")
	for i in 3:
		put_battlefield(0, "Island")
	advance_to_step(Mtg.Step.MAIN2)
	assert_false(ai._has_own_passing(g, EffectIntent.read(
		g.players[0].hand[0].data.spell_effects, "Transmute Artifact").needs_own))
	assert_eq(ai._try_cast_best(g), "", "nothing to transmute: held")
	ai.profile.holds_duplicates = false
	assert_ne(ai._try_cast_best(g), "", "off, cast into the empty board as before")

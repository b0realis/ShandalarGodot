extends GameTest
## THE LIFE THAT KEEPS US ALIVE (2026-09-26, [member AiProfile.buys_life]).
## A Zuran Orb at four life against a Serra Angel was priced at 1.5
## against the main phase's bar of 3.0 and activated zero times in
## twenty-seven duels. On, the life-gain arm of [method
## AiPlayer._ability_option] reads the damage their combat is about to
## deal ([method AiPlayer._incoming_damage]) and prices the gain that
## keeps our life above it at [constant AiPlayer.LETHAL_WORTH], once per
## activation, in RESPONSE as their attack stands. Ice Age (Pack 3) is
## on for the script and off again after it.


func before_each() -> void:
	CardPacks.set_enabled(IceAgePack.ID, true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled(IceAgePack.ID, false)


func _wizard(seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, AiProfile.wizard())
	g.set_agent(seat, ai)
	return ai


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


func _lands(pid: int) -> int:
	var n := 0
	for inst in g.players[pid].battlefield:
		if inst.is_land():
			n += 1
	return n


func _board(life: int) -> Array:
	var ai := _wizard(0)
	var orb := put_battlefield(0, "Zuran Orb")
	for i in 6:
		put_battlefield(0, "Island")
	g.players[0].life = life
	var angel := put_battlefield(1, "Serra Angel")
	return [ai, orb, angel]


func test_the_orb_buys_the_life_that_survives_the_swing() -> void:
	var board := _board(4)
	var ai: AiPlayer = board[0]
	var orb: CardInstance = board[1]
	var angel: CardInstance = board[2]
	_their_step(Mtg.Step.DECLARE_BLOCKERS, [angel.id])
	assert_eq(ai._incoming_damage(g), 4, "the Angel is unblocked")
	var option := ai._ability_option(g, orb, 0, AiPlayer.Moment.RESPONSE)
	assert_false(option.is_empty())
	assert_gt(float(option["value"]), 100.0, "the land that keeps us alive is the game")
	assert_eq(ai.act(g), "activated Zuran Orb")
	resolve_stack()
	assert_eq(g.players[0].life, 6)
	assert_eq(_lands(0), 5, "one Island spent")
	assert_ne(ai.act(g), "activated Zuran Orb", "at six against four, the next Island is kept")


func test_at_twenty_life_the_orb_is_not_a_response() -> void:
	var board := _board(20)
	var ai: AiPlayer = board[0]
	var angel: CardInstance = board[2]
	_their_step(Mtg.Step.DECLARE_BLOCKERS, [angel.id])
	assert_eq(ai._try_activate(g, AiPlayer.Moment.RESPONSE), "",
		"two life for a land is not a response to four damage at twenty")
	assert_eq(_lands(0), 6)


func test_off_the_orb_is_priced_as_before() -> void:
	var board := _board(4)
	var ai: AiPlayer = board[0]
	var orb: CardInstance = board[1]
	var angel: CardInstance = board[2]
	ai.profile.buys_life = false
	_their_step(Mtg.Step.DECLARE_BLOCKERS, [angel.id])
	assert_true(ai._ability_option(g, orb, 0, AiPlayer.Moment.RESPONSE).is_empty(),
		"off, the response moment admits no life gain")
	assert_ne(ai.act(g), "activated Zuran Orb")
	assert_eq(_lands(0), 6)


func test_before_the_attack_no_life_is_bought() -> void:
	var board := _board(4)
	var ai: AiPlayer = board[0]
	var orb: CardInstance = board[1]
	_their_step(Mtg.Step.UPKEEP)
	assert_eq(ai._incoming_damage(g), 0, "nothing is coming yet")
	assert_true(ai._ability_option(g, orb, 0, AiPlayer.Moment.RESPONSE).is_empty())

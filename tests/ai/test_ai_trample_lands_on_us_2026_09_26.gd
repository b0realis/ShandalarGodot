extends GameTest
## THE TRAMPLER'S SPILL IS DAMAGE THAT IS COMING (2026-09-26). The first
## cut of [method AiPlayer._incoming_damage] summed the unblocked power
## once blocks were in and nothing else, so an 8/8 Force of Nature through
## a 2/2 Grizzly Bears read as 0 while the engine dealt 6 — a life reading
## that under-reads lethal, and a Zuran Orb that stays untapped for it.
## [method AiPlayer._declared_damage] now runs the engine's own division
## over each band ([method MtgGame.default_damage_split]), and the Maze's
## lethal check reads it too. Ice Age (Pack 3) is on for the Orb.


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


func _lands(pid: int) -> int:
	var n := 0
	for inst in g.players[pid].battlefield:
		if inst.is_land():
			n += 1
	return n


func test_a_blocked_trampler_lands_its_surplus() -> void:
	var ai := _wizard(0)
	var bears := put_battlefield(0, "Grizzly Bears")
	var force := put_battlefield(1, "Force of Nature")   # 8/8 trample
	_their_step(Mtg.Step.DECLARE_BLOCKERS, [force.id], {bears.id: force.id})
	assert_true(g.combat.was_blocked(g.combat.band_of(force.id)), "the Bears block")
	var landing := ai._declared_damage(g)
	assert_eq(int(landing.get(force.id, 0)), 6, "eight less the Bears' two tramples through")
	assert_eq(ai._incoming_damage(g), 6, "the reading is the engine's own division")


func test_a_blocked_body_without_trample_lands_nothing() -> void:
	var ai := _wizard(0)
	var bears := put_battlefield(0, "Grizzly Bears")
	var wurm := put_battlefield(1, "Craw Wurm")   # 6/4, no trample
	_their_step(Mtg.Step.DECLARE_BLOCKERS, [wurm.id], {bears.id: wurm.id})
	assert_false(ai._declared_damage(g).has(wurm.id), "a blocked Wurm lands nothing on us")
	assert_eq(ai._incoming_damage(g), 0)


func test_the_orb_answers_the_spill_that_kills() -> void:
	# Six through the Bears against five life: without the spill in the
	# reading the Orb priced two life at 1.0 and let the game end.
	var ai := _wizard(0)
	var orb := put_battlefield(0, "Zuran Orb")
	for i in 6:
		put_battlefield(0, "Island")
	var bears := put_battlefield(0, "Grizzly Bears")
	g.players[0].life = 5
	var force := put_battlefield(1, "Force of Nature")
	_their_step(Mtg.Step.DECLARE_BLOCKERS, [force.id], {bears.id: force.id})
	assert_eq(ai._incoming_damage(g), 6)
	var option := ai._ability_option(g, orb, 0, AiPlayer.Moment.RESPONSE)
	assert_false(option.is_empty(), "the Orb is offered against the spill")
	assert_gt(float(option["value"]), 100.0, "the land that keeps us alive is the game")
	assert_eq(ai.act(g), "activated Zuran Orb")
	resolve_stack()
	assert_eq(g.players[0].life, 7)
	assert_eq(_lands(0), 5, "one Island spent, seven against six")
	assert_ne(ai.act(g), "activated Zuran Orb", "the next Island is kept")


func test_the_maze_reads_the_spill_as_the_lethal_half() -> void:
	# A Maze of Ith against a blocked Force (six through) and an unblocked
	# Bears (two): at seven life the swing is lethal by the Force's spill
	# and not by the Bears, so the Maze goes on the trampler.
	var ai := _wizard(0)
	var maze := put_battlefield(0, "Maze of Ith")
	var mine := put_battlefield(0, "Grizzly Bears")
	g.players[0].life = 7
	var force := put_battlefield(1, "Force of Nature")
	var theirs := put_battlefield(1, "Grizzly Bears")
	_their_step(Mtg.Step.DECLARE_BLOCKERS, [force.id, theirs.id], {mine.id: force.id})
	assert_eq(ai._incoming_damage(g), 8, "six through the block and two unblocked")
	var option := ai._ability_option(g, maze, 0, AiPlayer.Moment.COMBAT)
	assert_false(option.is_empty())
	assert_eq(option["targets"][0].instance_id, force.id, "the trampler is the lethal half")
	assert_eq(float(option["value"]), AiPlayer.LETHAL_WORTH)
	assert_eq(ai.act(g), "activated Maze of Ith")
	resolve_stack()
	assert_false(force.tapped, "the Force is untapped out of the fight")
	advance_to_step(Mtg.Step.END)
	assert_eq(g.players[0].life, 5, "the Bears' two landed; the six did not")

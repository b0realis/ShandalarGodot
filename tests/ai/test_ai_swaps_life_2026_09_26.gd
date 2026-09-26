extends GameTest
## THE MIRROR (2026-09-26, [member AiProfile.swaps_life]). Mirror
## Universe's effect is card-local, so it was `unknown` to the reader and
## refused by the scorer's last `else`; and its only moment is OUR upkeep,
## which [method AiPlayer.act] reaches through the RESPONSE moment. The
## card declares its shape ([member EffectIntent.swaps_life], through
## [member EffectBase.ai_role] `swap_life`), the response gate admits it,
## and the swing is priced as the damage it deals them plus the life it
## hands us — against the artifact the activation sacrifices.


func _wizard(seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, AiProfile.wizard())
	g.set_agent(seat, ai)
	return ai


func _our_next_turn_step(step: int) -> void:
	var turn := g.turn_number
	var guard := 0
	while not (g.turn_number > turn and g.active_player == 0 and g.current_step() == step
			and not g.awaiting_attackers and not g.awaiting_blockers
			and g.priority_player == 0 and g.stack.is_empty()) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400, "never reached our %s" % Mtg.step_name(step))


func test_the_reader_flags_the_swap() -> void:
	var mirror := put_battlefield(0, "Mirror Universe")
	var read := EffectIntent.read(mirror.cur_activated_abilities[0].effects, "Mirror Universe")
	assert_true(read.swaps_life)
	assert_false(read.unknown, "a declared shape is not an unknown")
	assert_not_null(read.target_spec, "target opponent")


func test_at_three_against_thirty_the_mirror_is_the_game() -> void:
	var ai := _wizard(0)
	var mirror := put_battlefield(0, "Mirror Universe")
	g.players[0].life = 3
	g.players[1].life = 30
	_our_next_turn_step(Mtg.Step.UPKEEP)
	var option := ai._ability_option(g, mirror, 0, AiPlayer.Moment.RESPONSE)
	assert_false(option.is_empty())
	assert_gt(float(option["value"]), 50.0)
	assert_eq(ai.act(g), "activated Mirror Universe")
	resolve_stack()
	assert_eq(g.players[0].life, 30)
	assert_eq(g.players[1].life, 3)
	assert_eq(mirror.zone, Mtg.Zone.GRAVEYARD, "sacrificed as its cost")


func test_off_the_mirror_is_never_activated() -> void:
	var ai := _wizard(0)
	ai.profile.swaps_life = false
	var mirror := put_battlefield(0, "Mirror Universe")
	g.players[0].life = 3
	g.players[1].life = 30
	_our_next_turn_step(Mtg.Step.UPKEEP)
	assert_true(ai._ability_option(g, mirror, 0, AiPlayer.Moment.RESPONSE).is_empty())
	assert_ne(ai.act(g), "activated Mirror Universe")
	assert_eq(g.players[0].life, 3)


func test_a_two_point_swap_is_not_worth_the_artifact() -> void:
	var ai := _wizard(0)
	var mirror := put_battlefield(0, "Mirror Universe")
	g.players[0].life = 18
	g.players[1].life = 20
	_our_next_turn_step(Mtg.Step.UPKEEP)
	assert_eq(ai._try_activate(g, AiPlayer.Moment.RESPONSE), "",
		"two points against a six-mana artifact")
	assert_eq(mirror.zone, Mtg.Zone.BATTLEFIELD)
	g.players[1].life = 10
	assert_true(ai._ability_option(g, mirror, 0, AiPlayer.Moment.RESPONSE).is_empty(),
		"and never when theirs is the smaller")
	assert_ne(ai.act(g), "activated Mirror Universe")


func test_in_a_main_phase_the_mirror_waits_for_the_upkeep() -> void:
	var ai := _wizard(0)
	put_battlefield(0, "Mirror Universe")
	g.players[0].life = 3
	g.players[1].life = 30
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai._try_activate(g, AiPlayer.Moment.MAIN), "", "activate only during your upkeep")
	assert_eq(ai._try_activate(g, AiPlayer.Moment.RESPONSE), "")

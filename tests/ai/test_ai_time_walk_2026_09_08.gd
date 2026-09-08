extends GameTest
## TIME WALK'S DRAW STEP (2026-09-08, The Deck's third pass). The pilot
## that paced its Tomes, its Library and its tutors against the two
## library counts (AiProfile.paces_draws, "The Deck, second pass") still
## cast a Time Walk into a race it led by nothing: the extra turn is a
## draw step off our own library before theirs comes round, and the
## reader filed ExtraTurnEffect under "unknown". Now EffectIntent counts
## the extra turns a spell grants, the slack counts the extra turns
## already queued on the game (ours against the lead, theirs for it),
## and a Time Walk waits for a spare card the way a Tome's tick does.
## The turn's worth beyond the draw is still the printed one — a generic
## three — and that is written up as open. Each behaviour is pinned with
## the knob and without it.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _pacing() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.paces_draws = true
	return profile


func _not_pacing() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.paces_draws = false
	return profile


func _lands(seat: int, land_name: String, count: int) -> void:
	for _i in count:
		put_battlefield(seat, land_name)


## Test surgery: the two libraries at exactly these counts.
func _libraries(mine: int, theirs: int) -> void:
	g.players[0].library.resize(mine)
	g.players[1].library.resize(theirs)
	assert_eq(g.players[0].library.size(), mine)
	assert_eq(g.players[1].library.size(), theirs)


# ------------------------------------------------------------ the reader --

func test_the_reader_counts_the_extra_turn() -> void:
	var walk := CardRegistry.get_card("Time Walk")
	var intent := EffectIntent.read(walk.spell_effects, walk.card_name)
	assert_eq(intent.extra_turns, 1, "one extra turn")
	assert_false(intent.unknown, "no longer filed under unknown")
	assert_false(intent.searches)
	assert_eq(intent.draws, 0, "the draw step is not a draw effect")


func test_a_spell_without_an_extra_turn_reads_none() -> void:
	var recall := CardRegistry.get_card("Ancestral Recall")
	assert_eq(EffectIntent.read(recall.spell_effects, recall.card_name).extra_turns, 0)


# ----------------------------------------------- the queued turn's slack --

func test_our_queued_extra_turn_is_a_card_off_the_lead() -> void:
	# Our main phase, their draw step next: a lead of one is one spare
	# card — until an extra turn of ours is queued, when it is the card
	# that keeps the race level.
	var ai := _ai(_pacing())
	advance_to_step(Mtg.Step.MAIN1)
	_libraries(10, 9)
	assert_eq(ai._library_slack(g), 1)
	g.extra_turns.append(0)
	assert_eq(ai._library_slack(g), 0, "our extra draw step spends the spare card")
	g.extra_turns.append(0)
	assert_true(ai._library_slack(g) >= 1 << 20,
		"two of ours from a lead of one: the race is lost, not ours to protect")


func test_their_queued_extra_turn_is_a_card_for_the_lead() -> void:
	var ai := _ai(_pacing())
	advance_to_step(Mtg.Step.MAIN1)
	_libraries(9, 9)
	assert_eq(ai._library_slack(g), 0)
	g.extra_turns.append(1)
	assert_eq(ai._library_slack(g), 1, "their extra draw step is a card for us")


func test_a_pilot_that_does_not_pace_ignores_the_queue() -> void:
	var ai := _ai(_not_pacing())
	advance_to_step(Mtg.Step.MAIN1)
	_libraries(9, 9)
	g.extra_turns.append(0)
	assert_true(ai._library_slack(g) >= 1 << 20)


# ---------------------------------------------------------- the Time Walk --

func test_a_time_walk_waits_for_a_spare_card() -> void:
	var ai := _ai(_pacing())
	var walk := give_hand(0, "Time Walk")
	_lands(0, "Island", 2)
	advance_to_step(Mtg.Step.MAIN1)
	_libraries(9, 9)
	assert_eq(ai.act(g), "pass", "level with their draw next: the extra turn would lose it")
	assert_eq(walk.zone, Mtg.Zone.HAND)
	assert_true(g.extra_turns.is_empty())


func test_a_time_walk_spends_a_spare_card_of_the_lead() -> void:
	var ai := _ai(_pacing())
	give_hand(0, "Time Walk")
	_lands(0, "Island", 2)
	advance_to_step(Mtg.Step.MAIN1)
	_libraries(10, 9)
	assert_string_contains(ai.act(g), "cast Time Walk")
	resolve_stack()
	assert_eq(g.extra_turns, [0] as Array[int], "the turn is queued")


func test_a_time_walk_far_from_the_end_is_cast_level() -> void:
	# Beyond the horizon the libraries do not decide the game: a level
	# race at thirty cards is no reason to hold the best card in the pool.
	var ai := _ai(_pacing())
	give_hand(0, "Time Walk")
	_lands(0, "Island", 2)
	advance_to_step(Mtg.Step.MAIN1)
	_libraries(30, 30)
	assert_string_contains(ai.act(g), "cast Time Walk")


func test_a_pilot_that_does_not_pace_walks_the_race_away() -> void:
	var ai := _ai(_not_pacing())
	give_hand(0, "Time Walk")
	_lands(0, "Island", 2)
	advance_to_step(Mtg.Step.MAIN1)
	_libraries(9, 9)
	assert_string_contains(ai.act(g), "cast Time Walk")


func test_a_second_walk_needs_a_second_spare_card() -> void:
	# One Walk already queued off a lead of one: the next has no card.
	var ai := _ai(_pacing())
	var walk := give_hand(0, "Time Walk")
	_lands(0, "Island", 2)
	advance_to_step(Mtg.Step.MAIN1)
	_libraries(10, 9)
	g.extra_turns.append(0)
	assert_eq(ai.act(g), "pass", "the queued turn took the spare card")
	assert_eq(walk.zone, Mtg.Zone.HAND)


func test_a_second_walk_spends_the_second_spare_card() -> void:
	var ai := _ai(_pacing())
	give_hand(0, "Time Walk")
	_lands(0, "Island", 2)
	advance_to_step(Mtg.Step.MAIN1)
	_libraries(11, 9)
	g.extra_turns.append(0)
	assert_string_contains(ai.act(g), "cast Time Walk")


# ------------------------------------------------------------- the ladder --

func test_the_ladder_paces_from_sorcerer_up() -> void:
	assert_false(AiProfile.apprentice().paces_draws)
	assert_false(AiProfile.magician().paces_draws)
	assert_true(AiProfile.sorcerer().paces_draws)
	assert_true(AiProfile.wizard().paces_draws)

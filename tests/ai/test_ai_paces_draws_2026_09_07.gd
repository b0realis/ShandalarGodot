extends GameTest
## THE PACE (2026-09-07, "The Deck, second pass"). A library is the other
## clock in a game of Magic: the player who has to draw from an empty one
## loses (CR 704.5b), and every optional draw — a Tome tick, a Library of
## Alexandria at seven, an Ancestral for three, a Braingeyser sized for
## the hand, a tutor — is a card off that clock. The pilot that counted
## its hand (AiProfile.counts_cards) still drew itself out of the race: a
## sixty-card deck of card-drawers lost to forty-card starters on an
## empty library at twenty life and more. Measured on The Deck against
## the five shipped starters (docs/ROADMAP.md, "The Deck, second pass").
##
## The rule: the race is the two library counts and whose draw step
## comes next. When theirs does, they draw from nothing first as long as
## our library is no smaller than theirs; when ours does, ours has to be
## strictly larger. A seat that holds the race may spend its lead down
## to nothing and no further; a race already lost is not ours to
## protect; beyond the horizon the libraries do not decide the game. One
## knob gates it, [member AiProfile.paces_draws], so each behaviour is
## pinned twice: it happens for a profile that paces and does not for
## one that does not. Everything acts through AiPlayer.act and the public
## MtgGame API; the library counts are test surgery on the filler decks.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _lands(seat: int, land_name: String, count: int) -> void:
	for _i in count:
		put_battlefield(seat, land_name)


func _pacing() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.paces_draws = true
	return profile


func _not_pacing() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.paces_draws = false
	return profile


## Test surgery: the two libraries at exactly these counts, out of the
## harness's thirty filler Forests each. Applied at the moment of the
## decision, after the turn cycling has taken its draw steps.
func _libraries(mine: int, theirs: int) -> void:
	g.players[0].library.resize(mine)
	g.players[1].library.resize(theirs)
	assert_eq(g.players[0].library.size(), mine)
	assert_eq(g.players[1].library.size(), theirs)


## Advance into the OPPONENT's turn and hand seat 0 priority in [param step].
func _their_turn_at(step: int) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == step) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400, "never reached the opponent's %s" % Mtg.step_name(step))
	assert_eq(g.priority_player, 1, "the active player gets priority first")
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


# ------------------------------------------------------- the slack itself --

func test_with_their_draw_step_next_the_slack_is_the_whole_lead() -> void:
	# Our main phase: the next draw step is theirs, so level counts win.
	var ai := _ai(_pacing())
	advance_to_step(Mtg.Step.MAIN1)
	_libraries(10, 9)
	assert_eq(ai._library_slack(g), 1, "level after the draw: they empty first")
	_libraries(11, 9)
	assert_eq(ai._library_slack(g), 2)
	_libraries(30, 10)
	assert_eq(ai._library_slack(g), 20)
	_libraries(9, 9)
	assert_eq(ai._library_slack(g), 0, "level is the race as it stands: keep it")


func test_with_our_draw_step_next_the_slack_is_the_lead_less_one() -> void:
	# Their end step: our draw step comes first, so we need to stay ahead.
	var ai := _ai(_pacing())
	_their_turn_at(Mtg.Step.END)
	_libraries(10, 9)
	assert_eq(ai._library_slack(g), 0, "a lead of one is a lead to keep")
	_libraries(11, 9)
	assert_eq(ai._library_slack(g), 1, "one card of a lead of two is spare")
	_libraries(30, 10)
	assert_eq(ai._library_slack(g), 19)


func test_a_race_already_lost_is_not_ours_to_protect() -> void:
	var ai := _ai(_pacing())
	_their_turn_at(Mtg.Step.END)
	_libraries(5, 9)
	assert_true(ai._library_slack(g) >= 1 << 20, "behind: draw for value")
	_libraries(9, 9)
	assert_true(ai._library_slack(g) >= 1 << 20,
		"level with our draw step next: we empty first whatever we do")


func test_beyond_the_horizon_the_libraries_do_not_decide_the_game() -> void:
	var ai := _ai(_pacing())
	_their_turn_at(Mtg.Step.END)
	_libraries(30, 29)
	assert_eq(ai._library_slack(g), 30 - AiPlayer.PACE_HORIZON - 1,
		"a lead of one at thirty cards is worth nothing yet")
	_libraries(22, 21)
	assert_eq(ai._library_slack(g), 1, "the last spare card before the horizon")
	_libraries(21, 20)
	assert_eq(ai._library_slack(g), 0, "at the horizon the lead is the rule")


func test_a_pilot_that_does_not_pace_has_all_the_slack_in_the_world() -> void:
	var ai := _ai(_not_pacing())
	_their_turn_at(Mtg.Step.END)
	_libraries(10, 9)
	assert_true(ai._library_slack(g) >= 1 << 20)


# -------------------------------------------------------- the Tome's tick --

func test_a_tome_keeps_a_lead_of_one_at_their_end_step() -> void:
	var ai := _ai(_pacing())
	put_battlefield(0, "Jayemdae Tome")
	_lands(0, "Island", 4)
	_their_turn_at(Mtg.Step.END)
	_libraries(10, 9)
	assert_eq(ai.act(g), "pass", "the tick would level the race with our draw next")
	assert_eq(g.players[0].library.size(), 10)


func test_a_tome_spends_the_second_card_of_a_lead_of_two() -> void:
	var ai := _ai(_pacing())
	put_battlefield(0, "Jayemdae Tome")
	_lands(0, "Island", 4)
	_their_turn_at(Mtg.Step.END)
	_libraries(11, 9)
	assert_eq(ai.act(g), "activated Jayemdae Tome")
	resolve_stack()
	assert_eq(g.players[0].library.size(), 10, "still strictly ahead")


func test_a_tome_behind_in_the_race_draws_for_value() -> void:
	var ai := _ai(_pacing())
	put_battlefield(0, "Jayemdae Tome")
	_lands(0, "Island", 4)
	_their_turn_at(Mtg.Step.END)
	_libraries(5, 9)
	assert_eq(ai.act(g), "activated Jayemdae Tome", "nothing left to protect")


func test_a_tome_far_from_the_end_ticks_at_a_lead_of_one() -> void:
	var ai := _ai(_pacing())
	put_battlefield(0, "Jayemdae Tome")
	_lands(0, "Island", 4)
	_their_turn_at(Mtg.Step.END)
	_libraries(30, 29)
	assert_eq(ai.act(g), "activated Jayemdae Tome", "twenty turns away: value")


func test_a_tome_holds_a_level_race_in_our_own_main_phase() -> void:
	# Their draw step is next: at level they draw from nothing first.
	var ai := _ai(_pacing())
	put_battlefield(0, "Jayemdae Tome")
	_lands(0, "Island", 4)
	advance_to_step(Mtg.Step.MAIN1)
	_libraries(9, 9)
	assert_eq(ai.act(g), "pass")
	assert_eq(g.players[0].library.size(), 9)


func test_a_tome_ticks_a_lead_of_one_down_to_level_in_our_main_phase() -> void:
	# The same lead of one that their end step refuses: here the tick
	# leaves the race level with THEIR draw step next, which is a win.
	var ai := _ai(_pacing())
	put_battlefield(0, "Jayemdae Tome")
	_lands(0, "Island", 4)
	advance_to_step(Mtg.Step.MAIN1)
	_libraries(10, 9)
	assert_eq(ai.act(g), "activated Jayemdae Tome")
	resolve_stack()
	assert_eq(g.players[0].library.size(), 9)


func test_a_tome_holds_a_level_race_in_their_upkeep() -> void:
	# The tick before their draw step: level now is level after it
	# only if we do not draw; a tick here hands them the race.
	var ai := _ai(_pacing())
	put_battlefield(0, "Jayemdae Tome")
	_lands(0, "Island", 4)
	_their_turn_at(Mtg.Step.UPKEEP)
	_libraries(9, 9)
	assert_eq(ai.act(g), "pass")
	assert_eq(g.players[0].library.size(), 9)


func test_a_pilot_that_does_not_pace_ticks_in_their_upkeep() -> void:
	var ai := _ai(_not_pacing())
	put_battlefield(0, "Jayemdae Tome")
	_lands(0, "Island", 4)
	_their_turn_at(Mtg.Step.UPKEEP)
	_libraries(9, 9)
	assert_eq(ai.act(g), "activated Jayemdae Tome")


func test_a_pilot_that_does_not_pace_ticks_the_race_level() -> void:
	# The null: the behaviour the measurement was taken against.
	var ai := _ai(_not_pacing())
	put_battlefield(0, "Jayemdae Tome")
	_lands(0, "Island", 4)
	_their_turn_at(Mtg.Step.END)
	_libraries(10, 9)
	assert_eq(ai.act(g), "activated Jayemdae Tome")
	resolve_stack()
	assert_eq(g.players[0].library.size(), 9, "level, and our draw step is next")


func test_the_pace_does_not_need_the_count() -> void:
	# Independent knobs: a profile that paces without counting its hand
	# still refuses the tick that levels the race.
	var profile := _pacing()
	profile.counts_cards = false
	var ai := _ai(profile)
	put_battlefield(0, "Jayemdae Tome")
	_lands(0, "Island", 4)
	_their_turn_at(Mtg.Step.END)
	_libraries(10, 9)
	assert_eq(ai.act(g), "pass")


# ------------------------------------------------ the Library at seven --

func test_library_of_alexandria_keeps_a_lead_of_one() -> void:
	var ai := _ai(_pacing())
	put_battlefield(0, "Library of Alexandria")
	for _i in 7:
		give_hand(0, "Craw Wurm")
	_their_turn_at(Mtg.Step.END)
	_libraries(10, 9)
	assert_eq(ai.act(g), "pass", "a free card is still a card off the clock")


func test_library_of_alexandria_draws_the_spare_card() -> void:
	var ai := _ai(_pacing())
	put_battlefield(0, "Library of Alexandria")
	for _i in 7:
		give_hand(0, "Craw Wurm")
	_their_turn_at(Mtg.Step.END)
	_libraries(11, 9)
	assert_eq(ai.act(g), "activated Library of Alexandria")


# ---------------------------------------------------- the fixed draw of 3 --

func test_ancestral_recall_needs_a_lead_of_four_to_draw_three() -> void:
	var ai := _ai(_pacing())
	var recall := give_hand(0, "Ancestral Recall")
	_lands(0, "Island", 1)
	_their_turn_at(Mtg.Step.END)
	_libraries(12, 9)
	assert_eq(ai.act(g), "pass", "three of twelve leaves nine against nine")
	assert_eq(recall.zone, Mtg.Zone.HAND)


func test_ancestral_recall_draws_three_from_a_lead_of_four() -> void:
	var ai := _ai(_pacing())
	give_hand(0, "Ancestral Recall")
	_lands(0, "Island", 1)
	_their_turn_at(Mtg.Step.END)
	_libraries(13, 9)
	assert_string_contains(ai.act(g), "cast Ancestral Recall")
	assert_true(g.stack.back().targets[0].player_id == 0)
	resolve_stack()
	assert_eq(g.players[0].library.size(), 10)


func test_a_pilot_that_does_not_pace_draws_three_into_a_level_race() -> void:
	var ai := _ai(_not_pacing())
	give_hand(0, "Ancestral Recall")
	_lands(0, "Island", 1)
	_their_turn_at(Mtg.Step.END)
	_libraries(12, 9)
	assert_string_contains(ai.act(g), "cast Ancestral Recall")


# ------------------------------------------------------ the X draw's size --

func test_braingeyser_is_sized_to_the_spare_cards_of_the_lead() -> void:
	var ai := _ai(_pacing())
	give_hand(0, "Braingeyser")
	give_hand(0, "Craw Wurm")
	_lands(0, "Island", 12)   # {X}{U}{U}: X could be 10
	advance_to_step(Mtg.Step.MAIN1)
	_libraries(15, 12)
	assert_eq(ai.act(g), "cast Braingeyser")
	assert_eq(g.stack.back().x_value, 3, "a lead of three with their draw next")


func test_braingeyser_waits_when_the_lead_has_nothing_to_spare() -> void:
	var ai := _ai(_pacing())
	var geyser := give_hand(0, "Braingeyser")
	give_hand(0, "Craw Wurm")
	_lands(0, "Island", 12)
	advance_to_step(Mtg.Step.MAIN1)
	_libraries(12, 12)
	assert_eq(ai.act(g), "pass")
	assert_eq(geyser.zone, Mtg.Zone.HAND)


func test_braingeyser_still_empties_their_library_from_behind() -> void:
	# THE DRAW THAT WINS is aimed at them; the pace reads our own draws.
	var ai := _ai(_pacing())
	give_hand(0, "Braingeyser")
	_lands(0, "Island", 6)   # X could be 5
	advance_to_step(Mtg.Step.MAIN1)
	_libraries(2, 4)
	assert_eq(ai.act(g), "cast Braingeyser")
	var item = g.stack.back()
	assert_eq(item.x_value, 4, "exactly their library")
	assert_true(item.targets[0].is_player and item.targets[0].player_id == 1)


# ------------------------------------------------------------- the tutor --

func test_a_tutor_is_a_card_off_the_library_too() -> void:
	# Demonic Tutor here is the class: EffectIntent.searches, any search.
	var ai := _ai(_pacing())
	var tutor := give_hand(0, "Demonic Tutor")
	_lands(0, "Swamp", 2)
	advance_to_step(Mtg.Step.MAIN1)
	_libraries(9, 9)
	assert_eq(ai.act(g), "pass", "level with their draw next: the search would lose it")
	assert_eq(tutor.zone, Mtg.Zone.HAND)


func test_a_tutor_spends_a_spare_card_of_the_lead() -> void:
	var ai := _ai(_pacing())
	give_hand(0, "Demonic Tutor")
	_lands(0, "Swamp", 2)
	advance_to_step(Mtg.Step.MAIN1)
	_libraries(10, 9)
	assert_string_contains(ai.act(g), "cast Demonic Tutor")


func test_a_pilot_that_does_not_pace_tutors_the_race_away() -> void:
	var ai := _ai(_not_pacing())
	give_hand(0, "Demonic Tutor")
	_lands(0, "Swamp", 2)
	advance_to_step(Mtg.Step.MAIN1)
	_libraries(9, 9)
	assert_string_contains(ai.act(g), "cast Demonic Tutor")


# ------------------------------------------------------------- the ladder --

func test_the_ladder_paces_from_sorcerer_up() -> void:
	assert_false(AiProfile.apprentice().paces_draws)
	assert_false(AiProfile.magician().paces_draws)
	assert_true(AiProfile.sorcerer().paces_draws)
	assert_true(AiProfile.wizard().paces_draws)


func test_the_knob_reads_from_the_lab() -> void:
	var profile := AiProfile.wizard()
	assert_eq(profile.apply_overrides("paces_draws=off"), "")
	assert_false(profile.paces_draws)
	assert_eq(profile.apply_overrides("paces_draws=on"), "")
	assert_true(profile.paces_draws)

extends GutTest
## THE GAUNTLET RUN — [GauntletState], the outer loop of the 1997 mode
## `2&Gauntlet:Defeat as many opponents in a row as possible.`
##
## No screen and no duel here: what is pinned is the RUN — the opponent
## order and its twenty cap, the wraparound the original's own arithmetic
## produces, the round counter, the session record that is deliberately
## not the match's, the four end-of-duel branches, and the determinism
## that MicroProse's own patch note (*"The random selection of opponents
## in the Gauntlet is now fixed"*) says this mode has to have.


func _paths(n: int) -> Array[String]:
	var out: Array[String] = []
	for i in n:
		out.append("res://decks/deck_%02d.deck" % i)
	return out


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _run(deck_count: int, seed_value := 4242,
		limit := GauntletState.MAX_OPPONENTS) -> GauntletState:
	var state := GauntletState.new()
	state.begin(_paths(deck_count), _rng(seed_value), limit)
	return state


# ========================================================== the opponents ==

func test_a_run_is_as_long_as_the_deck_folder() -> void:
	assert_eq(_run(5).length(), 5)
	assert_eq(_run(1).length(), 1)
	assert_eq(_run(0).length(), 0, "no decks, no run")


func test_the_run_is_capped_at_twenty_opponents() -> void:
	# `if (0x13 < DAT_005f6288) { DAT_005f649c = 0x14; }` (0x49c2d0), and
	# the shuffle buffer behind it is `int aiStack_54[20]`.
	assert_eq(GauntletState.MAX_OPPONENTS, 20)
	assert_eq(_run(50).length(), 20, "deck 21 onward cannot be met")
	assert_eq(_run(20).length(), 20)


func test_num_opponents_can_shorten_a_run_but_never_lengthen_it() -> void:
	assert_eq(_run(50, 4242, 6).length(), 6, "a shorter run is allowed")
	assert_eq(_run(50, 4242, 40).length(), 20, "past twenty it is not")
	assert_eq(_run(3, 4242, 10).length(), 3, "nor past the decks on disk")


func test_every_opponent_in_the_order_is_a_different_deck() -> void:
	var state := _run(8)
	var seen := {}
	for path in state.order:
		seen[path] = true
	assert_eq(seen.size(), 8, "the shuffle permutes, it does not repeat")


func test_the_order_is_shuffled_and_not_the_folder_order() -> void:
	# Not a law of the universe — it is a law of THIS seed, which is what
	# a determinism test is for. Two hundred decks make an accidental
	# identity permutation impossible in practice.
	var state := _run(200)
	assert_ne(state.order, _paths(200).slice(0, 20),
		"the run is shuffled, not the first twenty in folder order")


func test_the_twenty_are_sampled_from_the_whole_folder() -> void:
	# `[QoL]`, `docs/gauntlet-design.md` §5.6: the original numbers only
	# the first twenty decks and shuffles those, so deck 21 is unreachable.
	# We shuffle first and cut second.
	var reached := {}
	for seed_value in 40:
		for path in _run(60, seed_value * 7 + 1).order:
			reached[path] = true
	assert_gt(reached.size(), 20,
		"a deck past the twentieth can still be met")


# ======================================================== the walk and wrap ==

func test_the_first_opponent_is_the_start_offset_plus_one() -> void:
	# The original's own arithmetic: a 1-based round added to a 0-based
	# offset (`local_5c = (DAT_005f6498 + DAT_005f6cb0) % n`, 0x4420a1).
	var state := _run(5)
	assert_eq(state.round_number, 1, "a run opens on round 1")
	assert_eq(state.opponent_index(), (state.start + 1) % 5)
	assert_eq(state.opponent(), state.order[state.opponent_index()])


func test_the_walk_wraps_and_meets_every_deck_exactly_once() -> void:
	var state := _run(5)
	var met := {}
	for _round in 5:
		met[state.opponent()] = true
		state.record_match(true)
	assert_eq(met.size(), 5, "five rounds, five different opponents")
	assert_true(state.over, "and the fifth was the last")


func test_an_empty_run_has_no_opponent_rather_than_a_crash() -> void:
	var state := _run(0)
	assert_eq(state.opponent_index(), -1)
	assert_eq(state.opponent(), "")
	assert_eq(state.opponent_name(), "")


func test_the_opponent_is_named_by_its_deck_and_falls_back_to_the_file() -> void:
	var state := _run(3)
	assert_eq(state.opponent_name(),
		state.opponent().get_file().get_basename(),
		"no names supplied: the file's stem is the name")
	state.names[state.opponent()] = "Big Green"
	assert_eq(state.opponent_name(), "Big Green",
		"and `Your next duel is against %s.` prints the DECK's own name")


# ============================================================== the rounds ==

func test_winning_a_match_advances_the_round() -> void:
	var state := _run(4)
	state.record_match(true)
	assert_eq(state.round_number, 2)
	assert_false(state.over)


func test_losing_a_match_ends_the_run() -> void:
	var state := _run(4)
	state.record_match(false)
	assert_true(state.over, "a gauntlet cannot be resumed after a loss")
	assert_false(state.completed)
	assert_eq(state.round_number, 1, "and it stopped where it stopped")


func test_winning_the_last_match_runs_the_gauntlet() -> void:
	var state := _run(3)
	for _i in 2:
		state.record_match(true)
	assert_true(state.is_final_round(), "round 3 of 3")
	assert_false(state.over)
	state.record_match(true)
	assert_true(state.over)
	assert_true(state.completed, "the only branch that sets it")


func test_quitting_ends_the_run_without_completing_it() -> void:
	var state := _run(3)
	state.quit()
	assert_true(state.over)
	assert_false(state.completed)


func test_a_finished_run_ignores_further_matches() -> void:
	var state := _run(3)
	state.record_match(false)
	state.record_match(true)
	assert_eq(state.round_number, 1, "nothing moves after the run is over")


# ============================================================== the record ==

func test_the_session_record_counts_duels_across_the_whole_run() -> void:
	# `0x5f76c0 / 0x5f6494 / 0x5f67fc` — three counters the match's own
	# pair (`0x5f6c58 / 0x5f67e8`) is zeroed against and these are not.
	var state := _run(4)
	state.record_duel(GauntletState.Outcome.WON)
	state.record_duel(GauntletState.Outcome.WON)
	state.record_duel(GauntletState.Outcome.LOST)
	state.record_match(true)
	state.record_duel(GauntletState.Outcome.TIED)
	assert_eq([state.wins, state.losses, state.ties], [2, 1, 1])
	assert_eq(state.round_number, 2,
		"the record survived the match that reset the match's own tally")
	assert_eq(GauntletState.RECORD % [state.wins, state.losses, state.ties],
		"Your record is 2/1/1")


func test_a_duel_outcome_is_read_from_the_human_seat() -> void:
	assert_eq(GauntletState.outcome_for(1, 1), GauntletState.Outcome.WON)
	assert_eq(GauntletState.outcome_for(0, 1), GauntletState.Outcome.LOST)
	assert_eq(GauntletState.outcome_for(-1, 1), GauntletState.Outcome.TIED,
		"-1 is the draw the duel screen and MatchState already carry")


# ============================================================ the messages ==

func test_the_ten_gauntlet_strings_are_the_originals() -> void:
	# `@GAUNTLET`, `Program/UIStrings.txt:1352-1363` =
	# `s30/assets/text/Uistrings.txt:1312-1323`, with the `\n` runs
	# dropped the way MatchState drops them.
	assert_eq(GauntletState.CONGRATULATIONS, "Congratulations!")
	assert_eq(GauntletState.TOO_BAD, "Too bad")
	assert_eq(GauntletState.DUEL_TIED, "Oh well... The duel ended in a tie")
	assert_eq(GauntletState.WON_MATCH, "You won the match.")
	assert_eq(GauntletState.NEXT_IS, "Your next duel is against %s.")
	assert_eq(GauntletState.CONTINUE_Q, "Do you wish to continue?")
	assert_eq(GauntletState.RAN_IT, "You've successfully run the gauntlet!")
	assert_eq(GauntletState.WON_DUEL, "You've won the duel!")
	assert_eq(GauntletState.LOST_RUN, "You lost the game.")
	assert_eq(GauntletState.CONTINUES, "The match continues...")
	# `@DIALOG_GAUNTLETENDDUEL`, `:520-525`.
	assert_eq(GauntletState.ROUND_LINE, "That was round %d")
	assert_eq(GauntletState.RECORD, "Your record is %d/%d/%d")
	assert_eq(GauntletState.NEXT_ROUND, "Next round")
	assert_eq(GauntletState.QUIT, "Quit Gauntlet")


func test_the_message_opens_with_the_duel_and_closes_with_the_record() -> void:
	var state := _run(4)
	var lines := state.end_of_duel_lines(GauntletState.Outcome.WON, false, false)
	assert_eq(lines[0], GauntletState.CONGRATULATIONS)
	assert_eq(lines[-2], "That was round 1")
	assert_eq(lines[-1], "Your record is 0/0/0")


func test_the_match_continues_branch() -> void:
	var state := _run(4)
	var lines := state.end_of_duel_lines(GauntletState.Outcome.LOST, false, false)
	assert_eq(lines[0], GauntletState.TOO_BAD)
	assert_eq(lines[1], GauntletState.CONTINUES)
	assert_false("\n".join(lines).contains(GauntletState.WON_MATCH))


func test_the_match_lost_branch_is_the_end_of_the_run() -> void:
	var state := _run(4)
	var lines := state.end_of_duel_lines(GauntletState.Outcome.LOST, true, false)
	assert_eq(lines[1], GauntletState.LOST_RUN)
	assert_eq(lines.size(), 4, "no next opponent is offered")


func test_the_match_won_branch_names_the_next_opponent() -> void:
	var state := _run(4)
	state.names[state.order[state.index_for_round(2)]] = "Blue Skies"
	var lines := state.end_of_duel_lines(GauntletState.Outcome.WON, true, true)
	assert_eq(lines[1], GauntletState.WON_MATCH)
	assert_eq(lines[2], "Your next duel is against Blue Skies.")
	assert_eq(lines[3], GauntletState.CONTINUE_Q)


func test_the_last_match_won_branch_runs_the_gauntlet() -> void:
	var state := _run(2)
	state.record_match(true)
	var lines := state.end_of_duel_lines(GauntletState.Outcome.WON, true, true)
	assert_eq(lines[1], GauntletState.RAN_IT)
	assert_eq(lines[2], "That was round 2")
	assert_false("\n".join(lines).contains("next duel"),
		"there is no next opponent to announce")


# =========================================================== determinism ==

func test_one_seed_is_one_run() -> void:
	# The whole reason this class takes an RNG rather than calling randi().
	var a := _run(12, 90210)
	var b := _run(12, 90210)
	assert_eq(a.order, b.order, "same seed, same opponents in the same order")
	assert_eq(a.start, b.start, "and the same point entered at")


func test_different_seeds_are_different_runs() -> void:
	var a := _run(12, 1)
	var b := _run(12, 2)
	assert_true(a.order != b.order or a.start != b.start,
		"the run is not the same every time")


func test_the_shuffle_never_reaches_for_the_global_rng() -> void:
	# CONTRIBUTING.md rule 7. If shuffle() called randi(), seeding the global
	# stream identically around it would not make two runs agree.
	seed(11)
	var a := GauntletState.shuffle(_paths(10), _rng(777))
	seed(99)
	var b := GauntletState.shuffle(_paths(10), _rng(777))
	assert_eq(a, b)


# ================================================ the next-opponent lines ==
#
# `@DIALOG_STARTEXP1MATCH_GAUNTLET` (`Program/UIStrings.txt:149-153` =
# `s30/assets/text/Uistrings.txt:149-153`), slice 4. MicroProse's own
# patch notes list this screen among three gauntlet fixes — *"The Next
# Opponent screen displays the correct name for the next opponent."* —
# so which line a round gets, and which name is on it, is exactly the
# thing that shipped wrong in 1997.

func test_the_three_announcements_are_the_originals() -> void:
	assert_eq(GauntletState.FIRST_OPPONENT,
		"Your first opponent in the gauntlet:")
	assert_eq(GauntletState.FINAL_OPPONENT,
		"Your final opponent in the gauntlet:")
	# The original is `You now meet opponent %1!d! (of %2!d!) in the
	# gauntlet:` — the Windows POSITIONAL printf, argument 1 then argument
	# 2, both `%d`. Nothing else about the sentence moves.
	assert_eq(GauntletState.NTH_OPPONENT,
		"You now meet opponent %d (of %d) in the gauntlet:")


func test_the_first_round_gets_the_first_opponent_line() -> void:
	var state := _run(4)
	assert_eq(state.round_number, 1)
	assert_eq(state.announcement(), GauntletState.FIRST_OPPONENT)


func test_a_middle_round_counts_itself_out_of_the_run() -> void:
	var state := _run(5)
	state.round_number = 3
	assert_eq(state.announcement(),
		"You now meet opponent 3 (of 5) in the gauntlet:")


func test_the_last_round_gets_the_final_opponent_line() -> void:
	var state := _run(5)
	state.round_number = 5
	assert_true(state.is_final_round())
	assert_eq(state.announcement(), GauntletState.FINAL_OPPONENT)


func test_a_one_opponent_run_is_announced_as_the_first_and_not_the_last() -> void:
	# Both sentences are true of it and no source settles which the
	# original showed; ours is `first`, because the announcement is made
	# as the run BEGINS. Pinned so the choice cannot drift silently.
	var state := _run(1)
	assert_eq(state.length(), 1)
	assert_true(state.is_final_round(), "and it IS the final round")
	assert_eq(state.announcement(), GauntletState.FIRST_OPPONENT)


func test_a_run_with_no_opponents_announces_nothing() -> void:
	assert_eq(_run(0).announcement(), "")


func test_the_announcement_can_be_asked_for_any_round() -> void:
	# The screen raises the window for the round it is about to play, but
	# the composer takes the round as an argument so a caller can look
	# ahead without moving the counter.
	var state := _run(6)
	assert_eq(state.announcement_for_round(1), GauntletState.FIRST_OPPONENT)
	assert_eq(state.announcement_for_round(6), GauntletState.FINAL_OPPONENT)
	assert_eq(state.announcement_for_round(4),
		"You now meet opponent 4 (of 6) in the gauntlet:")
	assert_eq(state.round_number, 1, "and asking did not advance the run")


# ============================================== the opponent-deck refusals ==
#
# `@GAUNTLETERRORS` entries 8-11 (`Program/UIStrings.txt:1374-1377` =
# `s30/assets/text/Uistrings.txt:1334-1337`).

func test_the_four_opponent_deck_messages_are_the_originals() -> void:
	assert_eq(GauntletState.DECK_INVALID, "Opponent's deck %s is invalid.")
	assert_eq(GauntletState.DECK_WRONG_VERSION,
		"Opponent's deck %s is invalid. Wrong version number.")
	assert_eq(GauntletState.DECK_TOO_SMALL,
		"Opponent's deck %s is invalid. Decks must have a minimum of 40 cards.")
	# THE DOUBLE SPACE IS THE ORIGINAL'S, in both copies of the table, so
	# it is a 1997 typo and not one of ours. Quoted, not tidied.
	assert_eq(GauntletState.DECK_TOO_BIG,
		"Opponent's deck %s  is invalid. Decks are limited to "
		+ "200 unique cards / 500 total cards.")


func _deck(count: int, distinct := 1) -> DeckList:
	var deck := DeckList.new()
	for i in count:
		deck.cards.append("Card %04d" % (i % maxi(distinct, 1)))
	return deck


func test_a_playable_deck_earns_no_message() -> void:
	assert_eq(GauntletState.opponent_deck_problem("res://decks/a.deck",
		_deck(40)), "")
	assert_eq(GauntletState.opponent_deck_problem("res://decks/a.deck",
		_deck(500, 200)), "", "exactly on both limits is legal")


func test_a_deck_that_will_not_load_is_simply_invalid() -> void:
	var broken := _deck(40)
	broken.errors.append("line 3: unknown/unimplemented card 'Nope'")
	assert_eq(GauntletState.opponent_deck_problem("res://decks/a.deck", broken),
		GauntletState.DECK_INVALID)
	assert_eq(GauntletState.opponent_deck_problem("res://decks/a.deck",
		_deck(0)), GauntletState.DECK_INVALID, "an empty library, too")
	assert_eq(GauntletState.opponent_deck_problem("", _deck(40)),
		GauntletState.DECK_INVALID, "and a round with nobody in it")
	assert_eq(GauntletState.opponent_deck_problem("res://decks/a.deck", null),
		GauntletState.DECK_INVALID)


func test_a_deck_under_forty_cards_is_named_as_such() -> void:
	assert_eq(GauntletState.opponent_deck_problem("res://decks/a.deck",
		_deck(39)), GauntletState.DECK_TOO_SMALL)
	assert_eq(DeckModel.MIN_CARDS, 40, "the string and the number agree")


func test_a_deck_past_the_two_hundred_or_five_hundred_limit() -> void:
	assert_eq(GauntletState.opponent_deck_problem("res://decks/a.deck",
		_deck(501, 1)), GauntletState.DECK_TOO_BIG, "501 total")
	assert_eq(GauntletState.opponent_deck_problem("res://decks/a.deck",
		_deck(201, 201)), GauntletState.DECK_TOO_BIG, "201 unique")
	assert_eq([DeckModel.MAX_UNIQUE, DeckModel.MAX_TOTAL], [200, 500],
		"the string and the two numbers agree")


func test_the_wrong_version_message_is_recorded_and_never_chosen() -> void:
	# THE DESIGN WAS WRONG ABOUT THIS ONE. Slice 4 asks for the four
	# opponent-deck messages; three are producible and this is not, because
	# neither deck format this project reads carries a version number (the
	# 55 shipped 1997 `.dck` files open with a bare name line and no
	# version field; the only numbered revision anywhere is Manalink 3's
	# `;%d` header, `shandalar-src/src/deck/deckdll.cpp:5522-5545`). The
	# string is kept so the group of four is complete; nothing may return
	# it, and this is the test that says so.
	var answers := [
		GauntletState.opponent_deck_problem("", _deck(40)),
		GauntletState.opponent_deck_problem("res://decks/a.deck", _deck(0)),
		GauntletState.opponent_deck_problem("res://decks/a.deck", _deck(39)),
		GauntletState.opponent_deck_problem("res://decks/a.deck", _deck(501)),
		GauntletState.opponent_deck_problem("res://decks/a.deck", _deck(40)),
	]
	assert_false(answers.has(GauntletState.DECK_WRONG_VERSION),
		"no deck this project can read is the wrong version of anything")

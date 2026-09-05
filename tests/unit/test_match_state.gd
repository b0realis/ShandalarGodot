extends GutTest
## THE MATCH — `&Best of:` and the record it keeps ([MatchState]).
##
## The arithmetic here is small and entirely load-bearing: it decides when
## a duel is the last one, and the 1997 sentences it prints are quoted
## from `@DIALOG_ENDEXP1DUEL_MATCHPROGRESS` rather than paraphrased, so a
## drifting word fails the suite.


func _match(best_of: int) -> MatchState:
	var state := MatchState.new()
	state.best_of = best_of
	return state


func test_free_play_is_one_duel_and_keeps_no_record() -> void:
	var state := _match(MatchState.FREE_PLAY)
	assert_false(state.is_over(), "before the duel")
	assert_eq(state.wins_needed(), 1)
	state.record(0)
	assert_true(state.is_over(), "one duel decides it")
	assert_eq(state.progress_line(), "", "free play keeps no record")
	assert_eq(state.verdict(), "", "and pronounces no match verdict")
	assert_eq(state.duel_heading(), "")


func test_best_of_three_needs_two_wins() -> void:
	var state := _match(3)
	assert_eq(state.wins_needed(), 2)
	state.record(0)
	assert_false(state.is_over(), "1-0 is not a match")
	state.record(0)
	assert_true(state.is_over(), "2-0 is")
	assert_eq(state.winner(), 0)
	assert_eq(state.duels_played(), 2, "the third duel is never played")


func test_best_of_five_needs_three_wins() -> void:
	var state := _match(5)
	assert_eq(state.wins_needed(), 3)
	for _i in 2:
		state.record(0)
		state.record(1)
	assert_false(state.is_over(), "2-2 goes to a fifth duel")
	state.record(1)
	assert_true(state.is_over())
	assert_eq(state.winner(), 1)


func test_a_match_full_of_draws_ends_tied() -> void:
	# Our engine really can end a duel with nobody winning (CR 104.4), and
	# the string table has a sentence for a tied match — so the two must
	# meet rather than the match running forever.
	var state := _match(3)
	for _i in 3:
		state.record(-1)
	assert_true(state.is_over(), "the duels ran out")
	assert_eq(state.winner(), -1)
	assert_eq(state.verdict(), MatchState.TIED)
	assert_eq(state.draws, 3)


func test_one_win_and_two_draws_still_takes_the_match() -> void:
	var state := _match(3)
	state.record(-1)
	state.record(0)
	state.record(-1)
	assert_true(state.is_over())
	assert_eq(state.winner(), 0, "more wins than the other seat")
	assert_eq(state.verdict(), MatchState.WON)


func test_the_record_line_is_the_1997_sentence() -> void:
	var state := _match(3)
	state.human_seat = 0
	state.record(0)
	state.record(1)
	assert_eq(state.progress_line(),
		"After 2 duel(s) in this best of 3 match, your record is 1/1/0")
	var five := _match(5)
	five.record(1)
	assert_eq(five.progress_line(),
		"After 1 duel(s) in this best of 5 match, your record is 0/1/0")


func test_the_record_is_written_from_the_seat_it_belongs_to() -> void:
	var state := _match(3)
	state.human_seat = 1
	state.record(1)
	assert_eq(state.progress_line(),
		"After 1 duel(s) in this best of 3 match, your record is 1/0/0")


func test_the_verdicts_are_the_1997_sentences() -> void:
	assert_eq(MatchState.WON, "You've won the match!")
	assert_eq(MatchState.LOST, "You've lost the match.")
	assert_eq(MatchState.TIED, "The match ends in a tie.")
	var state := _match(3)
	state.human_seat = 0
	state.record(1)
	assert_eq(state.verdict(), "", "still running")
	state.record(1)
	assert_eq(state.verdict(), MatchState.LOST)


func test_the_three_lengths_the_sources_offer() -> void:
	# 3 and 5 are the two the record sentence can NARRATE; 1 is the
	# gauntlet's `Best of &One` (`@DIALOG_GAUNTLETOPTIONS`,
	# `Program/UIStrings.txt:624-626`). docs/duel-todo.md §6.21.
	assert_eq(MatchState.LENGTHS, [1, 3, 5] as Array[int])
	for length in [3, 5]:
		assert_true(MatchState.PROGRESS.has(length),
			"best of %d has a record line to print" % length)
		assert_true(MatchState.PROGRESS[length].contains("best of %d" % length),
			"and the line says its own length, as the original wrote it")
	assert_false(MatchState.PROGRESS.has(1),
		"there is no `best of 1 match` sentence and we do not invent one")


func test_best_of_one_is_a_match_and_free_play_is_not() -> void:
	# The whole difference §6.21 draws: both are one duel, but only one of
	# them keeps a record. `Best of &One` is what the gauntlet's Match Size
	# offers, and the original put `&Save match` on its between-duels
	# window; `&Free play` is Manalink's word for the spinner at 1 and is
	# ours to define.
	var state := _match(1)
	assert_eq(state.wins_needed(), 1, "best_of / 2 + 1, unchanged")
	assert_false(state.is_over(), "before the duel")
	state.record(0)
	assert_true(state.is_over(), "one duel decides it")
	assert_eq(state.winner(), 0)
	assert_eq(state.verdict(), MatchState.WON, "and it pronounces a verdict")
	assert_eq(state.progress_line(), "",
		"with no progress line, because 1997 never wrote one")
	var free_play := _match(MatchState.FREE_PLAY)
	free_play.record(0)
	assert_eq(free_play.verdict(), "", "free play says nothing at all")


func test_the_last_duel_is_remembered_for_the_gauntlet() -> void:
	# The gauntlet's round window opens with a line about the DUEL, and a
	# match that ends by running out of duels need not have ended on a
	# decisive one.
	var state := _match(3)
	assert_eq(state.last_winner, MatchState.NO_DUEL, "nothing played yet")
	state.record(0)
	assert_eq(state.last_winner, 0)
	state.record(-1)
	assert_eq(state.last_winner, -1, "a draw is remembered as a draw")
	state.record(-1)
	assert_true(state.is_over(), "the duels ran out")
	assert_eq(state.winner(), 0, "and seat 0 took it 1-0-2")
	assert_eq(state.last_winner, -1,
		"while the duel that ended it was drawn")


func test_the_duel_heading_counts_up() -> void:
	var state := _match(5)
	assert_eq(state.duel_heading(), "Duel 1 of 5")
	state.record(0)
	assert_eq(state.duel_heading(), "Duel 2 of 5")


func test_a_bare_match_state_is_free_play() -> void:
	# So nothing that builds a DuelConfig without asking for a match gets
	# one — the Deck Lab and every test included.
	var state := MatchState.new()
	assert_eq(state.best_of, MatchState.FREE_PLAY)
	assert_false(state.sideboard_between_duels)

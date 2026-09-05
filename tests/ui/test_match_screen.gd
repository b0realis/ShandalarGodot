extends GutTest
## THE MATCH, RUNNING — [MatchScreen], the screen that appears instead of
## a bare duel when the setup screen's `&Best of:` is chosen.
##
## The duels themselves are not played here (there are tests for a duel);
## what is pinned is the SEQUENCE — that a finished duel is recorded, that
## the next one starts with a seed of its own, that the match stops at the
## right duel, and that `Side&board between duels` really moves cards
## between the two piles the deck file carries.


var runner: MatchScreen


func _config(best_of: int) -> DuelConfig:
	var config := DuelConfig.hotseat_default()
	config.best_of = best_of
	config.rng_seed = 31337
	# The shipped decks carry real `SB:` lines; use one so the sideboard
	# step has something to swap.
	var deck := DeckList.load_file("res://decks/white_knights.deck", true)
	config.decks[0] = deck.cards.duplicate()
	config.sideboards[0] = deck.sideboard.duplicate()
	return config


func _run(best_of: int) -> MatchScreen:
	var screen: MatchScreen = load("res://game/match_screen.tscn").instantiate()
	screen.config = _config(best_of)
	add_child_autofree(screen)
	return screen


# =========================================================== the sequence ==

func test_a_match_starts_its_first_duel() -> void:
	runner = _run(3)
	await get_tree().process_frame
	assert_not_null(runner._duel, "duel 1 is on screen")
	assert_eq(runner.state.best_of, 3)
	assert_eq(runner.state.duels_played(), 0)


func test_a_finished_duel_is_recorded_and_the_next_one_begins() -> void:
	runner = _run(3)
	await get_tree().process_frame
	var first: DuelScreen = runner._duel
	first.duel_finished.emit(0)
	await get_tree().process_frame
	assert_eq(runner.state.wins[0], 1, "the win went on the record")
	assert_eq(runner.state.duels_played(), 1)
	assert_ne(runner._duel, first, "and duel 2 is a new duel")
	assert_false(runner.state.is_over())


func test_the_match_stops_when_it_is_decided() -> void:
	runner = _run(3)
	await get_tree().process_frame
	for _i in 2:
		runner._duel.duel_finished.emit(0)
		await get_tree().process_frame
	assert_true(runner.state.is_over(), "2-0 takes a best of three")
	assert_eq(runner.state.duels_played(), 2, "the third duel is not played")
	assert_eq(runner.state.verdict(), MatchState.WON)


func test_a_drawn_duel_lands_in_the_record() -> void:
	runner = _run(3)
	await get_tree().process_frame
	runner._duel.duel_finished.emit(-1)
	await get_tree().process_frame
	assert_eq(runner.state.draws, 1)
	assert_eq(runner.state.wins, [0, 0] as Array[int])


# ============================================================ the seeds ==

func test_each_duel_gets_its_own_seed_drawn_from_the_match_seed() -> void:
	runner = _run(5)
	await get_tree().process_frame
	var seeds: Array[int] = []
	for _i in 3:
		seeds.append(runner._duel.config.rng_seed)
		runner._duel.duel_finished.emit(-1)
		await get_tree().process_frame
	assert_eq(seeds.size(), 3)
	for value in seeds:
		assert_ne(value, 0, "0 would mean 'roll one' and lose the replay")
	var unique := {}
	for value in seeds:
		unique[value] = true
	assert_eq(unique.size(), 3, "three different duels")


func test_the_same_match_seed_replays_the_same_duels() -> void:
	var first: Array[int] = []
	var second: Array[int] = []
	for pass_number in 2:
		var screen: MatchScreen = load("res://game/match_screen.tscn").instantiate()
		screen.config = _config(5)
		add_child_autofree(screen)
		await get_tree().process_frame
		for _i in 3:
			(first if pass_number == 0 else second).append(
				screen._duel.config.rng_seed)
			screen._duel.duel_finished.emit(-1)
			await get_tree().process_frame
	assert_eq(first, second, "one match seed, one sequence of duels")


func test_a_duel_inside_a_match_is_not_itself_a_match() -> void:
	runner = _run(3)
	await get_tree().process_frame
	assert_eq(runner._duel.config.best_of, MatchState.FREE_PLAY,
		"the match parameters do not travel into the duel")


# ========================================================= the sideboard ==

func test_the_shipped_decks_carry_a_sideboard_to_swap() -> void:
	for path in DeckStore.deck_paths_in(DeckStore.SHIPPED_DIR):
		var deck := DeckList.load_file(path, true)
		assert_true(deck.errors.is_empty(), path.get_file())
		assert_gt(deck.sideboard.size(), 0,
			"%s has `SB:` cards to swap in" % path.get_file())


func test_counting_a_pile_groups_and_sorts_it() -> void:
	var counted := MatchScreen.counted(["Plains", "Bolt", "Plains", "Plains"])
	assert_eq(counted.keys(), ["Bolt", "Plains"], "name order")
	assert_eq(counted["Plains"], 3)
	assert_eq(counted["Bolt"], 1)
	assert_eq(MatchScreen.counted([]).size(), 0, "an empty pile counts to nothing")


func test_a_card_moves_out_of_the_deck_and_into_the_sideboard() -> void:
	runner = _run(3)
	await get_tree().process_frame
	var before_main: int = (runner.config.decks[0] as Array).size()
	var before_side: int = (runner.config.sideboards[0] as Array).size()
	var card: String = String(runner.config.decks[0][0])
	assert_eq(runner.move_one(0, card, true), "", "the swap was allowed")
	assert_eq((runner.config.decks[0] as Array).size(), before_main - 1)
	assert_eq((runner.config.sideboards[0] as Array).size(), before_side + 1)
	# ...and back the other way.
	assert_eq(runner.move_one(0, card, false), "")
	assert_eq((runner.config.decks[0] as Array).size(), before_main)
	assert_eq((runner.config.sideboards[0] as Array).size(), before_side)


func test_moving_a_card_that_is_not_there_is_refused_not_crashed() -> void:
	runner = _run(3)
	await get_tree().process_frame
	var refusal := runner.move_one(0, "Nicol Bolas", true)
	assert_ne(refusal, "", "a refusal string, this project's convention")
	assert_true(refusal.contains("Nicol Bolas"), "and it names the card")


func test_a_swap_reaches_the_next_duel() -> void:
	# The point of the whole item: what you do between duels is what you
	# play with in the next one.
	runner = _run(3)
	await get_tree().process_frame
	var swapped_in: String = String(runner.config.sideboards[0][0])
	var swapped_out: String = String(runner.config.decks[0][0])
	runner.move_one(0, swapped_out, true)
	runner.move_one(0, swapped_in, false)
	runner._duel.duel_finished.emit(1)
	await get_tree().process_frame
	var next_deck: Array = runner._duel.config.decks[0]
	assert_true(next_deck.has(swapped_in),
		"the sideboard card is in the next duel's deck")


# ====================================================== the AI's sideboard ==
#
# The half `game/match_screen.gd` used to say it did not have: an AI seat
# that adapts between duels, on what it SAW and nothing else.


## A match against an AI seat 1 piloting a deck with a real `SB:` pile.
func _ai_config(profile: AiProfile = null) -> DuelConfig:
	var config := _config(3)
	config.sideboard_between_duels = true
	config.pilots[1] = profile if profile != null else AiProfile.wizard()
	var deck := DeckList.load_file("res://decks/black_red_raiders.deck", true)
	config.decks[1] = deck.cards.duplicate()
	config.sideboards[1] = deck.sideboard.duplicate()
	return config


func _run_vs_ai(profile: AiProfile = null) -> MatchScreen:
	var screen: MatchScreen = load("res://game/match_screen.tscn").instantiate()
	screen.config = _ai_config(profile)
	add_child_autofree(screen)
	return screen


## Show [param card_name] to the AI seat [param n] times, as spells the
## HUMAN cast — the same event stream the duel screen animates from, which
## is the only channel [AiMatchMemory] listens on.
func _show_to_the_ai(screen: MatchScreen, card_name: String, n: int) -> void:
	for i in n:
		var inst := CardInstance.new(CardRegistry.get_card(card_name),
			90000 + i, 0)
		screen._duel.game.dispatch_event(Mtg.EventType.SPELL_CAST,
			{"instance": inst, "controller": 0})


func test_only_an_ai_seat_gets_a_memory() -> void:
	runner = _run_vs_ai()
	await get_tree().process_frame
	assert_null(runner._memories[0], "a human seat remembers for itself")
	assert_not_null(runner._memories[1])


func test_the_memory_is_watching_the_duel_that_is_running() -> void:
	runner = _run_vs_ai()
	await get_tree().process_frame
	_show_to_the_ai(runner, "Counterspell", 2)
	assert_eq((runner._memories[1] as AiMatchMemory)._this_duel.get(
		"Counterspell", 0), 2, "the watch was connected before turn 1")


func test_the_ai_boards_against_what_it_saw() -> void:
	runner = _run_vs_ai()
	await get_tree().process_frame
	var before: Array = (runner.config.decks[1] as Array).duplicate()
	# Four blue spells: Red Elemental Blast is what a Black-Red sideboard
	# has for that, and it is in the pile.
	_show_to_the_ai(runner, "Counterspell", 4)
	runner._duel.duel_finished.emit(0)
	await get_tree().process_frame
	assert_ne(runner.config.decks[1], before, "the AI changed its deck")
	assert_true((runner.config.decks[1] as Array).has("Red Elemental Blast"),
		"and it brought in the answer to what it saw")
	assert_true((runner._duel.config.decks[1] as Array).has(
		"Red Elemental Blast"), "which is the deck duel 2 is played with")


func test_the_ai_deck_never_changes_size() -> void:
	runner = _run_vs_ai()
	await get_tree().process_frame
	var deck_size: int = (runner.config.decks[1] as Array).size()
	var board_size: int = (runner.config.sideboards[1] as Array).size()
	_show_to_the_ai(runner, "Counterspell", 4)
	runner._duel.duel_finished.emit(0)
	await get_tree().process_frame
	assert_eq((runner.config.decks[1] as Array).size(), deck_size)
	assert_eq((runner.config.sideboards[1] as Array).size(), board_size)


func test_the_ai_leaves_its_deck_alone_when_the_box_is_unticked() -> void:
	runner = _run_vs_ai()
	runner.config.sideboard_between_duels = false
	await get_tree().process_frame
	runner.state.sideboard_between_duels = false
	var before: Array = (runner.config.decks[1] as Array).duplicate()
	_show_to_the_ai(runner, "Counterspell", 4)
	runner._duel.duel_finished.emit(0)
	await get_tree().process_frame
	assert_eq(runner.config.decks[1], before,
		"`Side&board between duels` is a match parameter, not a default")


func test_the_apprentice_never_sideboards() -> void:
	runner = _run_vs_ai(AiProfile.apprentice())
	await get_tree().process_frame
	var before: Array = (runner.config.decks[1] as Array).duplicate()
	_show_to_the_ai(runner, "Counterspell", 4)
	runner._duel.duel_finished.emit(0)
	await get_tree().process_frame
	assert_eq(runner.config.decks[1], before,
		"difficulty scales through AiProfile and nothing else")


func test_free_play_never_reaches_this_screen() -> void:
	# MatchScreen would still run one duel, but the setup screen sends
	# free play straight to the duel — this pins the value it checks.
	assert_eq(MatchState.FREE_PLAY, 0)
	var setup: SetupScreen = load("res://game/setup_screen.tscn").instantiate()
	add_child_autofree(setup)
	await get_tree().process_frame
	assert_eq(setup.best_of(), MatchState.FREE_PLAY, "free play is the default")
	setup._best_of_check.button_pressed = true
	assert_eq(setup.best_of(), 3,
		"and `&Best of:` opens on three, not on the 1 that heads LENGTHS")


# ---------------------------- the duel under the window (2026-09-02) --

func test_a_finished_duel_stops_taking_input_under_the_owners_window() -> void:
	# The match's own window silenced the duel's KEYS (`_show_window`)
	# but not its mouse, and an owner that asked for the result — the
	# gauntlet, `reports_to_owner` — got no `_show_window` at all: under
	# either window a permanent on the finished table still answered a
	# click. A finished duel is a picture: nothing in it processes.
	runner = _run(1)
	runner.reports_to_owner = true
	await get_tree().process_frame
	var duel: DuelScreen = runner._duel
	assert_eq(duel.process_mode, Node.PROCESS_MODE_INHERIT, "live while it plays")
	duel.duel_finished.emit(0)
	assert_true(runner.state.is_over(), "1-0 takes a best of one")
	assert_true(is_instance_valid(duel), "the owner keeps the duel on screen")
	assert_eq(duel.process_mode, Node.PROCESS_MODE_DISABLED,
		"and it takes no input under the owner's window")

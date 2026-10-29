extends GutTest
## SAVED BETWEEN DUELS, ON THE SCREENS — [MatchScreen], [GauntletScreen] and
## Magic Battle's `Resume match` (the polish pass c18, P4; the owner,
## 2026-10-28: *"Saving: between duels (Gauntlet runs and matches save
## after each duel and resume); no mid-duel save"*). The files themselves
## are `tests/unit/test_p4_match_saves.gd`.
##
## What these pin:
##   1. a match from Magic Battle saves after each duel — the record, the
##      decks as they stand after a Sideboard window — and a decided match
##      drops its file; a match nobody asked to save writes nothing, and a
##      match that ends before it ever saved leaves the one saved before it;
##   2. a saved match taken up again plays on at the next duel with its
##      record, its stream and what the computer saw — its next duel dealt
##      afresh (never the deal that was quit), the resume counted in the
##      file; and the question for leaving a duel says it is saved;
##   3. a Gauntlet run saves after each duel with its match in play, after
##      each won match between matches, and drops its file when it ends;
##   4. a saved run taken up again plays on at its round (between matches
##      or in the middle of one), and its window offers Resume run / New
##      run / Exit — Resume greyed with the reason when a pack is off — and
##      says once that a damaged file was set aside;
##   5. Magic Battle offers `Resume match` only when a match is saved, and
##      its press takes that match up.

const DIR := "user://p4_resume_test"
const MATCH := DIR + "/saved_match.json"
const RUN := DIR + "/saved_gauntlet.json"
const DECK_A := "res://decks/big_green.deck"
const DECK_B := "res://decks/blue_skies.deck"
const DECK_C := "res://decks/mountain_artillery.deck"

## Screens a handover put beside this test, freed with it.
var _handed: Array[Node] = []


func before_each() -> void:
	_wipe()
	DirAccess.make_dir_recursive_absolute(DIR)
	MatchSaves.match_file = MATCH
	MatchSaves.gauntlet_file = RUN


func after_each() -> void:
	for node in _handed:
		if is_instance_valid(node):
			node.queue_free()
	_handed.clear()
	MatchSaves.match_file = MatchSaves.MATCH_FILE
	MatchSaves.gauntlet_file = MatchSaves.GAUNTLET_FILE
	_wipe()


func _wipe() -> void:
	var dir := DirAccess.open(DIR)
	if dir == null:
		return
	for name in dir.get_files():
		dir.remove(name)
	DirAccess.remove_absolute(DIR)


func _config(best_of := 3) -> DuelConfig:
	var config := DuelConfig.hotseat_default()
	config.best_of = best_of
	config.rng_seed = 31337
	var deck := DeckList.load_file("res://decks/white_knights.deck", true)
	config.decks[0] = deck.cards.duplicate()
	config.sideboards[0] = deck.sideboard.duplicate()
	config.sideboard_between_duels = true
	return config


## A match from Magic Battle — the one kind that keeps a save of its own.
func _match(best_of := 3, config: DuelConfig = null) -> MatchScreen:
	var runner: MatchScreen = load("res://game/match_screen.tscn").instantiate()
	runner.config = config if config != null else _config(best_of)
	runner.keeps_save = true
	add_child_autofree(runner)
	return runner


func _finish(runner: MatchScreen, winner: int) -> void:
	runner._duel.duel_finished.emit(winner)
	await get_tree().process_frame


# ===================================================== 1. a match saves ==

func test_a_match_from_magic_battle_saves_after_each_duel() -> void:
	var runner := _match()
	await get_tree().process_frame
	assert_false(FileAccess.file_exists(MATCH), "nothing before a duel has ended")
	await _finish(runner, 0)
	var found := MatchSaves.read_match()
	assert_eq(found["status"], MatchSaves.READY, "saved when duel 1 was recorded")
	var state: MatchState = found["match"]["state"]
	assert_eq(state.wins, [1, 0] as Array[int])
	assert_eq((found["match"]["config"] as DuelConfig).record_match,
		runner.config.record_match, "the match's own id")
	await _finish(runner, -1)
	state = MatchSaves.read_match()["match"]["state"]
	assert_eq([state.wins[0], state.wins[1], state.draws], [1, 0, 1], "and again after duel 2")
	assert_true(runner.saved)


func test_a_sideboard_window_closing_saves_the_deck_as_it_stands() -> void:
	var runner := _match()
	await get_tree().process_frame
	await _finish(runner, 1)
	var out := String(runner.config.decks[0][0])
	var into := String(runner.config.sideboards[0][0])
	runner._open_sideboard(0)
	runner._move_one(out, true)
	runner._move_one(into, false)
	runner._close_sideboard()
	await get_tree().process_frame
	var config: DuelConfig = MatchSaves.read_match()["match"]["config"]
	assert_eq(config.decks[0], runner.config.decks[0], "the swap is in the save")
	assert_true((config.sideboards[0] as Array).has(out))


func test_a_decided_match_drops_its_file() -> void:
	var runner := _match()
	await get_tree().process_frame
	await _finish(runner, 0)
	assert_true(FileAccess.file_exists(MATCH))
	await _finish(runner, 0)
	assert_true(runner.state.is_over())
	assert_false(FileAccess.file_exists(MATCH), "nothing is left to resume")


func test_a_match_nobody_asked_to_save_writes_nothing() -> void:
	var runner: MatchScreen = load("res://game/match_screen.tscn").instantiate()
	runner.config = _config()
	add_child_autofree(runner)
	await get_tree().process_frame
	await _finish(runner, 0)
	assert_false(FileAccess.file_exists(MATCH),
		"a test's or a tool's match leaves the player's save alone")


func test_a_match_ending_before_it_saved_leaves_the_saved_one() -> void:
	var first := _match()
	await get_tree().process_frame
	await _finish(first, 0)
	var kept := FileAccess.get_file_as_bytes(MATCH)
	var second := _match(1)              # a best of one: decided at once
	await get_tree().process_frame
	await _finish(second, 0)
	assert_true(second.state.is_over())
	assert_eq(FileAccess.get_file_as_bytes(MATCH), kept, "the other match is still saved")


# ================================================ 2. a match taken up ==

func test_a_saved_match_plays_on_at_its_next_duel() -> void:
	var first := _match(5)
	await get_tree().process_frame
	await _finish(first, 0)
	await _finish(first, 1)
	var dealt_next: int = first._duel.config.rng_seed     # duel 3, as played
	var found := MatchSaves.read_match()
	var again: MatchScreen = load("res://game/match_screen.tscn").instantiate()
	again.resume_from = found["match"]
	again.keeps_save = true
	add_child_autofree(again)
	await get_tree().process_frame
	assert_eq(again.state.wins, [1, 1] as Array[int], "the record goes on")
	assert_eq(again.state.best_of, 5)
	assert_not_null(again._duel, "duel 3 is up")
	assert_eq(again._duel.config.record_game, 3)
	assert_eq(again._duel.config.record_match, first.config.record_match,
		"filed with the duels before it")
	assert_ne(again._duel.config.rng_seed, dealt_next,
		"dealt afresh: never the deal that was quit")
	assert_eq(int(MatchSaves.read_match()["match"]["resumes"]), 1, "the resume is counted")
	# The same file taken up a second time deals afresh again…
	var twice: MatchScreen = load("res://game/match_screen.tscn").instantiate()
	twice.resume_from = MatchSaves.read_match()["match"]
	twice.keeps_save = true
	add_child_autofree(twice)
	await get_tree().process_frame
	assert_ne(twice._duel.config.rng_seed, again._duel.config.rng_seed)
	# …and the deal is the file's: the same point taken up the same way
	# deals the same duel.
	var same: MatchScreen = load("res://game/match_screen.tscn").instantiate()
	same.resume_from = found["match"]
	add_child_autofree(same)
	await get_tree().process_frame
	assert_eq(same._duel.config.rng_seed, again._duel.config.rng_seed)


func test_what_the_computer_saw_comes_back_with_the_match() -> void:
	var config := _config()
	config.pilots[1] = AiProfile.sorcerer()
	var first := _match(3, config)
	await get_tree().process_frame
	(first._memories[1] as AiMatchMemory).seen["Llanowar Elves"] = 2
	await _finish(first, 0)
	var again: MatchScreen = load("res://game/match_screen.tscn").instantiate()
	again.resume_from = MatchSaves.read_match()["match"]
	add_child_autofree(again)
	await get_tree().process_frame
	var memory: AiMatchMemory = again._memories[1]
	assert_not_null(memory)
	if memory != null:
		assert_eq(memory.copies_seen("Llanowar Elves"), 2)
		assert_eq(memory.duels, 1)
	assert_null(again._memories[0], "the person's seat has none")
	assert_eq((again.config.pilots[1] as AiProfile).profile_name, "Sorcerer")


func test_leaving_a_duel_of_a_saved_match_says_it_is_saved() -> void:
	var runner := _match()
	await get_tree().process_frame
	assert_eq(runner._duel.leave_question, MatchScreen.LEAVE_QUESTION,
		"duel 1: nothing is saved yet")
	await _finish(runner, 0)
	assert_eq(runner._duel.leave_question, MatchScreen.SAVED_LEAVE_QUESTION)
	assert_eq(runner._duel.menu_question, MatchScreen.SAVED_MENU_QUESTION)
	assert_string_contains(MatchScreen.SAVED_LEAVE_QUESTION, "Resume match")


func test_the_between_duels_window_says_the_match_is_saved() -> void:
	var runner := _match()
	await get_tree().process_frame
	await _finish(runner, 0)
	runner._show_window()
	assert_string_contains(_text_of(runner._window), MatchScreen.SAVED_NOTE)


# ================================================== 3. a gauntlet saves ==

func _gauntlet(decks: Array[String], size := 1, seed_value := 90210) -> GauntletScreen:
	var screen: GauntletScreen = load("res://game/duel/gauntlet_screen.tscn").instantiate()
	var config := DuelConfig.hotseat_default()
	config.rng_seed = seed_value
	screen.config = config
	screen.opponent_paths = decks
	screen.options.best_of = size
	screen.options.ante = false
	screen.options.your_deck = DECK_A
	return screen


func _finish_round_duel(screen: GauntletScreen, winner: int) -> void:
	screen._match._duel.duel_finished.emit(winner)
	await get_tree().process_frame


func test_a_run_saves_after_each_duel_with_its_match_in_play() -> void:
	var screen := _gauntlet([DECK_A, DECK_B, DECK_C], 3)
	add_child_autofree(screen)
	await get_tree().process_frame
	await _finish_round_duel(screen, 0)
	var found := MatchSaves.read_gauntlet()
	assert_eq(found["status"], MatchSaves.READY)
	var run: Dictionary = found["run"]
	assert_eq(run["id"], screen.run_id)
	assert_eq((run["state"] as GauntletState).round_number, 1)
	var in_play: Dictionary = run["match"]
	assert_false(in_play.is_empty(), "the match in play is in the save")
	assert_eq((in_play["state"] as MatchState).wins, [1, 0] as Array[int])
	assert_false(FileAccess.file_exists(MATCH), "a run's match keeps no file of its own")


func test_a_won_match_saves_the_run_between_matches() -> void:
	var screen := _gauntlet([DECK_A, DECK_B, DECK_C], 3)
	add_child_autofree(screen)
	await get_tree().process_frame
	await _finish_round_duel(screen, 0)
	await _finish_round_duel(screen, 0)
	assert_eq(screen.state.round_number, 2)
	var run: Dictionary = MatchSaves.read_gauntlet()["run"]
	assert_eq((run["state"] as GauntletState).round_number, 2)
	assert_eq((run["state"] as GauntletState).wins, 2)
	assert_true((run["match"] as Dictionary).is_empty(), "between matches")


func test_a_run_that_ends_drops_its_file() -> void:
	var screen := _gauntlet([DECK_A, DECK_B, DECK_C], 3)
	add_child_autofree(screen)
	await get_tree().process_frame
	await _finish_round_duel(screen, 1)
	assert_true(FileAccess.file_exists(RUN))
	await _finish_round_duel(screen, 1)          # 0-2: the match and the run lost
	assert_true(screen.state.over)
	assert_false(FileAccess.file_exists(RUN), "a run that is over cannot be taken up")


func test_leaving_a_duel_of_a_saved_run_says_it_is_saved() -> void:
	var screen := _gauntlet([DECK_A, DECK_B, DECK_C], 3)
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_string_contains(screen._match._duel.leave_question, "round 1",
		"nothing saved yet: the run's own question")
	await _finish_round_duel(screen, 0)
	assert_eq(screen._match._duel.leave_question, GauntletScreen.SAVED_QUESTION)


# ============================================== 4. a gauntlet taken up ==

func test_a_saved_run_plays_on_at_its_next_round() -> void:
	var first := _gauntlet([DECK_A, DECK_B, DECK_C], 1)
	add_child_autofree(first)
	await get_tree().process_frame
	await _finish_round_duel(first, 0)               # round 1 won
	var order := first.state.order.duplicate()
	var meets: String = first.state.opponent()        # round 2's opponent
	var again := _gauntlet([DECK_A], 1, 1)
	again.resume_from = MatchSaves.read_gauntlet()["run"]
	add_child_autofree(again)
	await get_tree().process_frame
	assert_eq(again.state.round_number, 2)
	assert_eq(again.state.order, order, "the same opponents, in the same order")
	assert_eq(again.state.wins, 1)
	assert_eq(again.run_id, first.run_id)
	assert_not_null(again._match, "round 2 is up")
	assert_eq(again._match.config.deck_names[1], again.state.opponent_name())
	assert_eq(again.state.opponent(), meets)
	assert_eq(int(MatchSaves.read_gauntlet()["run"]["resumes"]), 1, "the resume is counted")


func test_a_run_saved_in_the_middle_of_a_match_plays_on_inside_it() -> void:
	var first := _gauntlet([DECK_A, DECK_B, DECK_C], 3)
	add_child_autofree(first)
	await get_tree().process_frame
	await _finish_round_duel(first, 0)
	var again := _gauntlet([DECK_A], 1, 1)
	again.resume_from = MatchSaves.read_gauntlet()["run"]
	add_child_autofree(again)
	await get_tree().process_frame
	assert_eq(again.state.round_number, 1)
	assert_not_null(again._match)
	assert_eq(again._match.state.wins, [1, 0] as Array[int], "duel 2 of the same match")
	assert_eq(again._match.state.best_of, 3)
	assert_true(again._match.reports_to_owner)
	await _finish_round_duel(again, 0)               # 2-0: round 1 is the run's
	assert_eq(again.state.round_number, 2)
	assert_eq(again.state.wins, 2)


func test_the_resume_window_offers_resume_new_run_and_exit() -> void:
	var first := _gauntlet([DECK_A, DECK_B, DECK_C], 3)
	add_child_autofree(first)
	await get_tree().process_frame
	await _finish_round_duel(first, 0)
	var screen := _gauntlet([DECK_A, DECK_B, DECK_C], 3)
	add_child_autofree(screen)
	await get_tree().process_frame
	screen._show_resume(MatchSaves.read_gauntlet())
	var dialog: OriginalDialog = screen._window
	assert_eq(_foot_buttons(dialog), [GauntletScreen.RESUME_RUN, GauntletScreen.NEW_RUN,
		GauntletOptions.EXIT] as Array[String])
	var text := _text_of(dialog)
	assert_string_contains(text, "Round 1 of 3")
	assert_string_contains(text, "Your record is 1/0/0")
	_press(dialog, GauntletScreen.NEW_RUN)
	assert_not_null(screen._options_window, "New run: the options, to start one")


func test_resume_is_greyed_with_the_reason_when_a_pack_is_off() -> void:
	var first := _gauntlet([DECK_A, DECK_B, DECK_C], 3)
	add_child_autofree(first)
	await get_tree().process_frame
	await _finish_round_duel(first, 0)
	var found := MatchSaves.read_gauntlet()
	CardPacks.set_enabled("pack-9", false)
	(found["run"]["config"] as DuelConfig).decks[0].append("Mogg Fanatic")
	first._show_resume(found)
	var resume := _button(first._window, GauntletScreen.RESUME_RUN)
	assert_not_null(resume)
	if resume != null:
		assert_true(resume.disabled)
	assert_string_contains(_text_of(first._window), "Pack 9")


func test_a_damaged_run_file_is_set_aside_and_said_once() -> void:
	var screen := _gauntlet([DECK_A, DECK_B], 1)
	add_child_autofree(screen)
	await get_tree().process_frame
	var file := FileAccess.open(RUN, FileAccess.WRITE)
	file.store_string("not a run")
	file.close()
	screen._close_window()
	screen._offer_saved_run()
	assert_string_contains(_text_of(screen._window), "could not be read")
	assert_true(FileAccess.file_exists(RUN + ".bad"))
	assert_false(FileAccess.file_exists(RUN))


# ============================================ 5. Magic Battle's Resume ==

func _setup() -> SetupScreen:
	var setup: SetupScreen = load("res://game/setup_screen.tscn").instantiate()
	add_child_autofree(setup)
	await get_tree().process_frame
	return setup


func test_magic_battle_offers_resume_only_when_a_match_is_saved() -> void:
	var setup := await _setup()
	assert_null(setup._resume_button, "nothing saved: no Resume match")
	var runner := _match()
	await get_tree().process_frame
	await _finish(runner, 0)
	var again := await _setup()
	assert_not_null(again._resume_button)
	if again._resume_button == null:
		return
	assert_eq(again._resume_button.text, SetupScreen.RESUME_MATCH)
	assert_false(again._resume_button.disabled)
	var row: Node = again._resume_button.get_parent()
	assert_gt(row.get_index(), again._sideboard_check.get_index(), "with the match parameters")
	assert_string_contains(_text_of(row), "your record is 1/0/0")
	var taken: Array[Node] = []
	again.match_resumed.connect(func(screen: Control) -> void: taken.append(screen))
	again._resume_button.pressed.emit()
	assert_eq(taken.size(), 1, "the press takes the match up")
	if taken.is_empty():
		return
	_handed.append(taken[0])
	await get_tree().process_frame
	var resumed := taken[0] as MatchScreen
	assert_eq(resumed.state.wins, [1, 0] as Array[int])
	assert_true(resumed.keeps_save, "and it goes on saving")


func test_magic_battle_greys_resume_when_a_pack_is_off() -> void:
	var config := _config()
	config.record_match = "p4-pack"
	var state := MatchState.new()
	state.best_of = 3
	state.record(0)
	config.decks[1] = (config.decks[1] as Array).duplicate()
	config.decks[1].append("Mogg Fanatic")
	CardPacks.set_enabled("pack-9", false)
	assert_true(MatchSaves.write_match(MatchSaves.match_json(config, state, 7, 0, [null, null])))
	var setup := await _setup()
	assert_not_null(setup._resume_button)
	if setup._resume_button == null:
		return
	assert_true(setup._resume_button.disabled)
	assert_string_contains(_text_of(setup._resume_button.get_parent()), "Pack 9")


func test_magic_battle_says_once_that_a_damaged_save_was_set_aside() -> void:
	var file := FileAccess.open(MATCH, FileAccess.WRITE)
	file.store_string("not a match")
	file.close()
	var setup := await _setup()
	assert_null(setup._resume_button, "nothing to take up")
	assert_string_contains(_text_of(setup), "saved_match.json.bad")
	var again := await _setup()
	assert_false(_text_of(again).contains("could not be read"), "said once")


# ------------------------------------------------------------- helpers --

func _foot_buttons(dialog: OriginalDialog) -> Array[String]:
	var out: Array[String] = []
	for child in dialog._buttons.get_children():
		out.append((child as Button).text)
	return out


func _button(dialog: OriginalDialog, label: String) -> Button:
	for child in dialog._buttons.get_children():
		if (child as Button).text == label:
			return child as Button
	return null


func _press(dialog: OriginalDialog, label: String) -> void:
	var button := _button(dialog, label)
	if button == null:
		fail_test("no '%s' button on the dialog" % label)
		return
	button.pressed.emit()


func _text_of(node: Node) -> String:
	var out := ""
	for child in node.get_children():
		if child is Label:
			out += (child as Label).text + "\n"
		out += _text_of(child)
	return out

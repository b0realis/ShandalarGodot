extends GutTest
## SAVED BETWEEN DUELS, AT THE END OF DUEL WINDOW — the bug campaign of
## 0.50.65, group F4 (k4-1, k4-2, k4-4, k4-5). The P4 suites
## (`test_p4_match_resume.gd`, `tests/unit/test_p4_match_saves.gd`) pin the
## save points themselves; these pin the four holes the hunt found in them:
##
##   k4-1  a Gauntlet's DECIDING duel is recorded, and the run saved or
##         dropped, the moment it ends — with its End of Duel window still
##         up, the way a player meets it — so quitting at that window
##         (Pause → Return to main menu → Yes) brings back neither a lost
##         run nor a won duel undone; the round window still comes after;
##   k4-2  a saved run whose LATER opponent needs a pack switched off is
##         not offered (Resume run greyed, the pack named), and a round that
##         meets such a deck refuses without deleting the save;
##   k4-4  the questions of a finished duel's two doors say what is true
##         at its End of Duel window: saved with this duel, or over;
##   k4-5  an AI Demo match keeps no save, so it never replaces the
##         player's saved match.
##
## Headless, a match never waits for an End of Duel window (none opens);
## [member MatchScreen.waits_for_result_window] holds it there as a player
## meets it, and the duel's own `_result_pending` is the window up.

const DIR := "user://c19_f4_test"
const MATCH := DIR + "/saved_match.json"
const RUN := DIR + "/saved_gauntlet.json"
const DECK_A := "res://decks/big_green.deck"
const DECK_B := "res://decks/blue_skies.deck"
const DECK_C := "res://decks/mountain_artillery.deck"
## A deck of Pack 9's (Tempest block) cards, written for the k4-2 tests.
const PACK_DECK := DIR + "/tempest_goblins.deck"
const PACK := "pack-9"

var _pack_was_on := true


func before_each() -> void:
	_wipe()
	DirAccess.make_dir_recursive_absolute(DIR)
	MatchSaves.match_file = MATCH
	MatchSaves.gauntlet_file = RUN
	_pack_was_on = CardPacks.is_enabled(PACK)


func after_each() -> void:
	MatchSaves.match_file = MatchSaves.MATCH_FILE
	MatchSaves.gauntlet_file = MatchSaves.GAUNTLET_FILE
	if CardPacks.is_enabled(PACK) != _pack_was_on:
		CardPacks.set_enabled(PACK, _pack_was_on)
	_wipe()


func _wipe() -> void:
	var dir := DirAccess.open(DIR)
	if dir == null:
		return
	for name in dir.get_files():
		dir.remove(name)
	DirAccess.remove_absolute(DIR)


# ------------------------------------------------------------- helpers --

func _gauntlet(decks: Array[String], size := 3, seed_value := 90210) -> GauntletScreen:
	var screen: GauntletScreen = load("res://game/duel/gauntlet_screen.tscn").instantiate()
	var config := DuelConfig.hotseat_default()
	config.rng_seed = seed_value
	screen.config = config
	screen.opponent_paths = decks
	screen.options.best_of = size
	screen.options.ante = false
	screen.options.your_deck = DECK_A
	return screen


## A duel of [param runner] ended and its End of Duel window is up — the
## duel screen's own order: the window pending, then the verdict.
func _end_at_the_window(runner: MatchScreen, winner: int) -> DuelScreen:
	runner.waits_for_result_window = true
	var duel := runner._duel
	duel._result_pending = true
	duel.duel_finished.emit(winner)
	return duel


## Pause → `Return to main menu` over the End of Duel window: the question
## it asks, then `Yes, I'm sure`.
func _quit_to_menu(duel: DuelScreen) -> String:
	duel._ask_to_leave(true)
	var asked := _text_of(duel._leave_dialog)
	duel._confirm_leave()
	return asked


func _match(best_of := 3) -> MatchScreen:
	var runner: MatchScreen = load("res://game/match_screen.tscn").instantiate()
	var config := DuelConfig.hotseat_default()
	config.best_of = best_of
	config.rng_seed = 31337
	runner.config = config
	runner.keeps_save = true
	add_child_autofree(runner)
	return runner


# ===================== k4-1: the deciding duel, saved before its window ==

func test_a_lost_deciding_duel_drops_the_run_with_its_window_still_up() -> void:
	var screen := _gauntlet([DECK_A, DECK_B, DECK_C])
	add_child_autofree(screen)
	await get_tree().process_frame
	screen._match._duel.duel_finished.emit(1)            # 0-1, saved
	await get_tree().process_frame
	assert_eq(MatchSaves.read_gauntlet()["status"], MatchSaves.READY)
	var duel := _end_at_the_window(screen._match, 1)     # 0-2: the run is lost
	assert_true(duel.result_dialog_open(), "the End of Duel window is up")
	assert_eq(screen._match._duel, duel, "and the match waits on it")
	assert_true(screen.state.over, "the run is decided already")
	assert_false(FileAccess.file_exists(RUN), "and its file dropped already")
	var asked := _quit_to_menu(duel)
	assert_false(asked.contains("saved"), "the door does not promise a saved run: " + asked)
	assert_string_contains(asked, "over")
	await get_tree().process_frame
	assert_eq(MatchSaves.read_gauntlet()["status"], MatchSaves.NONE,
		"entering the Gauntlet again offers no lost run")


func test_a_won_deciding_duel_saves_the_next_round_with_its_window_still_up() -> void:
	var screen := _gauntlet([DECK_A, DECK_B, DECK_C])
	add_child_autofree(screen)
	await get_tree().process_frame
	screen._match._duel.duel_finished.emit(0)            # 1-0
	await get_tree().process_frame
	var duel := _end_at_the_window(screen._match, 0)     # 2-0: round 1 is won
	assert_true(duel.result_dialog_open())
	var run: Dictionary = MatchSaves.read_gauntlet()["run"]
	assert_false(run.is_empty(), "the run is saved")
	if run.is_empty():
		return
	assert_eq((run["state"] as GauntletState).round_number, 2, "at round 2")
	assert_eq((run["state"] as GauntletState).wins, 2, "both duels on the record")
	assert_true((run["match"] as Dictionary).is_empty(), "between matches")
	var asked := _quit_to_menu(duel)
	assert_string_contains(asked, "round 2")
	await get_tree().process_frame
	var again := _gauntlet([DECK_A], 3, 1)
	again.resume_from = MatchSaves.read_gauntlet()["run"]
	add_child_autofree(again)
	await get_tree().process_frame
	assert_eq(again.state.round_number, 2, "taken up at round 2, not at 1-0")
	assert_eq(again.state.wins, 2)
	assert_eq(again._match.state.duels_played(), 0, "a fresh match")


func test_a_best_of_one_run_saves_its_duel_with_the_window_still_up() -> void:
	var screen := _gauntlet([DECK_A, DECK_B, DECK_C], 1)
	add_child_autofree(screen)
	await get_tree().process_frame
	var duel := _end_at_the_window(screen._match, 0)
	assert_true(duel.result_dialog_open())
	var run: Dictionary = MatchSaves.read_gauntlet()["run"]
	assert_false(run.is_empty(), "the first duel of a best of one is saved at once")
	if not run.is_empty():
		assert_eq((run["state"] as GauntletState).round_number, 2)


func test_the_round_comes_after_the_window_and_is_recorded_once() -> void:
	var screen := _gauntlet([DECK_A, DECK_B, DECK_C])
	add_child_autofree(screen)
	await get_tree().process_frame
	screen._match._duel.duel_finished.emit(0)
	await get_tree().process_frame
	var first := screen._match
	var duel := _end_at_the_window(first, 0)
	await get_tree().process_frame
	assert_eq(screen._match, first, "the round does not move under the window")
	assert_null(screen._window, "no round window over the End of Duel window")
	duel._result_pending = false                          # its OK
	await get_tree().process_frame
	await get_tree().process_frame
	assert_ne(screen._match, first, "then the next round")
	assert_eq(screen.state.round_number, 2, "recorded once, not twice")
	assert_eq([screen.state.wins, screen.state.losses, screen.state.ties], [2, 0, 0])


# ========= k4-4: the doors over a finished duel's window say what is true ==

func test_the_doors_over_a_saved_duels_window_say_it_is_saved() -> void:
	var runner := _match()
	await get_tree().process_frame
	var duel := _end_at_the_window(runner, 0)            # 1-0, saved
	assert_eq(MatchSaves.read_match()["status"], MatchSaves.READY)
	for asked: String in [duel.leave_question, duel.menu_question]:
		assert_false(asked.contains("lost"), "nothing is lost: " + asked)
		assert_string_contains(asked, "Resume match")
		assert_string_contains(asked, "this duel")


func test_the_doors_over_a_decided_matchs_window_promise_no_resume() -> void:
	var runner := _match()
	await get_tree().process_frame
	runner._duel.duel_finished.emit(0)
	await get_tree().process_frame
	var duel := _end_at_the_window(runner, 0)            # 2-0: decided, dropped
	assert_false(FileAccess.file_exists(MATCH))
	for asked: String in [duel.leave_question, duel.menu_question]:
		assert_false(asked.contains("Resume match"), "no save to resume: " + asked)
		assert_string_contains(asked, "over")


func test_a_gauntlet_duels_doors_say_the_run_is_saved_with_it() -> void:
	var screen := _gauntlet([DECK_A, DECK_B, DECK_C])
	add_child_autofree(screen)
	await get_tree().process_frame
	var duel := _end_at_the_window(screen._match, 0)     # 1-0, saved
	assert_string_contains(duel.leave_question, "this duel's result")
	assert_eq(duel.menu_question, duel.leave_question)


# ============ k4-2: a pack switched off for an opponent still to come ==

## A forty-card deck of Pack 9's goblins, and a run saved at [param round]
## between matches whose opponents are [DECK_A, DECK_B, PACK_DECK] met in
## the order round 3, 1, 2 (`(start + round) % n`, start 0).
func _save_run_meeting_the_pack_deck_in_round_2(round_number: int) -> void:
	var file := FileAccess.open(PACK_DECK, FileAccess.WRITE)
	file.store_string("name: Tempest Goblins\n4 Mogg Fanatic\n36 Mountain\n")
	file.close()
	var state := GauntletState.new()
	state.order.assign([DECK_A, DECK_B, PACK_DECK])
	state.start = 0
	state.round_number = round_number
	state.wins = round_number - 1
	var config := DuelConfig.hotseat_default()
	config.best_of = 1
	config.rng_seed = 777
	var mine := DeckList.load_file(DECK_A, true)
	config.decks[0] = mine.cards.duplicate()
	config.sideboards[0] = mine.sideboard.duplicate()
	config.player_names[0] = "You"
	config.pilots[0] = null
	config.pilots[1] = AiProfile.sorcerer()
	var options := GauntletOptions.new()
	options.best_of = 1
	options.your_deck = DECK_A
	assert_true(MatchSaves.write_gauntlet(MatchSaves.gauntlet_json("c19-f4-run",
		state, config, options, 99, 0, {})), "the run is written")


func test_a_later_opponent_needing_a_pack_switched_off_greys_resume() -> void:
	_save_run_meeting_the_pack_deck_in_round_2(1)
	CardPacks.set_enabled(PACK, false)
	var found := MatchSaves.read_gauntlet()
	assert_eq(found["status"], MatchSaves.READY)
	assert_true(MatchSaves.gauntlet_card_names(found["run"]).has("Mogg Fanatic"),
		"round 2's deck is counted")
	var screen := _gauntlet([DECK_A, DECK_B, DECK_C])
	add_child_autofree(screen)
	await get_tree().process_frame
	screen._close_window()
	screen._show_resume(found)
	var resume := _button(screen._window, GauntletScreen.RESUME_RUN)
	assert_not_null(resume)
	if resume != null:
		assert_true(resume.disabled, "Resume run is greyed")
	assert_string_contains(_text_of(screen._window), "Pack 9")
	assert_true(FileAccess.file_exists(RUN), "and the run is kept")


func test_an_opponent_already_met_does_not_count() -> void:
	_save_run_meeting_the_pack_deck_in_round_2(3)        # round 2 is behind
	CardPacks.set_enabled(PACK, false)
	var found := MatchSaves.read_gauntlet()
	assert_false(MatchSaves.gauntlet_card_names(found["run"]).has("Mogg Fanatic"))
	assert_eq(MatchSaves.cards_refusal(MatchSaves.gauntlet_card_names(found["run"]),
		"This run"), "")


func test_a_round_refused_for_a_pack_switched_off_keeps_the_save() -> void:
	_save_run_meeting_the_pack_deck_in_round_2(2)        # round 2 is next
	CardPacks.set_enabled(PACK, false)
	var again := _gauntlet([DECK_A], 3, 1)
	again.resume_from = MatchSaves.read_gauntlet()["run"]
	add_child_autofree(again)
	await get_tree().process_frame
	assert_null(again._match, "the round is refused")
	var found := MatchSaves.read_gauntlet()
	assert_eq(found["status"], MatchSaves.READY, "and the run is not deleted")
	if found["status"] == MatchSaves.READY:
		assert_eq((found["run"]["state"] as GauntletState).round_number, 2,
			"it waits at round 2 for the pack")


func test_a_broken_opponent_deck_still_ends_the_run() -> void:
	# The control: `@GAUNTLETERRORS` for a deck that cannot be read at all
	# ends the run and drops its file, as 1997's message box ended it.
	_save_run_meeting_the_pack_deck_in_round_2(2)
	DirAccess.remove_absolute(PACK_DECK)
	var again := _gauntlet([DECK_A], 3, 1)
	again.resume_from = MatchSaves.read_gauntlet()["run"]
	add_child_autofree(again)
	await get_tree().process_frame
	assert_null(again._match)
	assert_true(again.state.over)
	assert_false(FileAccess.file_exists(RUN), "the same deck would end it again")


# =============================== k4-5: an AI Demo match keeps no save ==

func test_an_ai_demo_match_keeps_no_save_and_a_match_against_the_ai_does() -> void:
	var setup: SetupScreen = load("res://game/setup_screen.tscn").instantiate()
	add_child_autofree(setup)
	await get_tree().process_frame
	for mode in [SetupScreen.BattleMode.DEMO, SetupScreen.BattleMode.VS_AI,
			SetupScreen.BattleMode.HOTSEAT]:
		setup._apply_mode(mode)
		var config := DuelConfig.hotseat_default()
		config.best_of = 3
		var run: MatchScreen = setup._match_for(config)
		assert_eq(run.keeps_save, mode != SetupScreen.BattleMode.DEMO,
			"mode %d keeps a save: %s" % [mode, mode != SetupScreen.BattleMode.DEMO])
		run.free()


# ------------------------------------------------------------- helpers --

func _button(dialog: OriginalDialog, label: String) -> Button:
	if dialog == null:
		return null
	for child in dialog._buttons.get_children():
		if (child as Button).text == label:
			return child as Button
	return null


func _text_of(node: Node) -> String:
	if node == null:
		return ""
	var out := ""
	for child in node.get_children():
		if child is Label:
			out += (child as Label).text + "\n"
		out += _text_of(child)
	return out

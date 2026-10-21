extends GutTest
## LEAVING A DUEL THAT IS PART OF SOMETHING LONGER (review 2026-10-21,
## ui-1).
##
## The duel screen did not know who held it. Its pre-duel splash always
## offered `Reconfigure duel`, and that button and Pause → `Exit duel` both
## went straight to the battle-setup screen — so inside a Gauntlet one
## click on the five-second splash (round 1 or round 12) ended the whole
## run without a question and opened Magic Battle, a screen the gauntlet
## player never came from; on duel 2 of a best-of-three it dropped the 1-0.
##
## Now the screen that holds a duel says so ([member
## DuelScreen.leave_question], set by [MatchScreen], and through it by
## [GauntletScreen]). Both doors ask first, in the Concede question's own
## window and words, and a yes goes where the player came from: a match
## started on Magic Battle back to Magic Battle (the ROADMAP's own *"exit
## duel (return to duel config)"*), a Gauntlet to its own Gauntlet Options
## window with the run's parameters still set — the original's shape for
## every way a run ends. A plain Magic Battle duel and a Test hands duel
## are exactly as they were.
##
## Nothing here presses a door that changes the scene: that would replace
## the test runner's own scene.

const DECK_A := "res://decks/big_green.deck"
const DECK_B := "res://decks/blue_skies.deck"


func _gauntlet() -> GauntletScreen:
	var screen: GauntletScreen = \
		load("res://game/duel/gauntlet_screen.tscn").instantiate()
	var config := DuelConfig.hotseat_default()
	config.rng_seed = 90210
	screen.config = config
	screen.opponent_paths = [DECK_A, DECK_B] as Array[String]
	screen.options.best_of = 3
	screen.options.ante = false
	screen.options.your_deck = DECK_A
	add_child_autofree(screen)
	return screen


func _match() -> MatchScreen:
	var runner: MatchScreen = load("res://game/match_screen.tscn").instantiate()
	var config := DuelConfig.hotseat_default()
	config.best_of = 3
	config.rng_seed = 4242
	runner.config = config
	add_child_autofree(runner)
	return runner


func _buttons(node: Node) -> Array[String]:
	var out: Array[String] = []
	for button in node.find_children("*", "Button", true, false):
		out.append((button as Button).text)
	return out


func _press(node: Node, label: String) -> void:
	for button in node.find_children("*", "Button", true, false):
		if (button as Button).text == label:
			(button as Button).pressed.emit()
			return
	fail_test("no '%s' button" % label)


func _text_of(node: Node) -> String:
	var out := ""
	for child in node.find_children("*", "Label", true, false):
		out += (child as Label).text + "\n"
	return out


# ===================================================== who holds the duel ==

func test_a_plain_duel_is_held_by_nobody_and_keeps_its_splash() -> void:
	var duel: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	duel.config = DuelConfig.vs_ai_default(AiProfile.wizard())
	add_child_autofree(duel)
	await get_tree().process_frame
	assert_eq(duel.leave_question, "", "Magic Battle's free play asks nothing, as before")
	duel._run_intro()
	assert_true(_buttons(duel._intro_overlay).has("Reconfigure duel"))
	duel._intro_overlay.go_pressed.emit()
	await get_tree().process_frame


func test_a_matchs_duel_is_held_and_its_splash_still_reconfigures() -> void:
	var runner := _match()
	await get_tree().process_frame
	var duel := runner._duel
	assert_eq(duel.leave_question, MatchScreen.LEAVE_QUESTION)
	assert_eq(duel.leave_title, MatchScreen.TITLE)
	duel._run_intro()
	assert_true(_buttons(duel._intro_overlay).has("Reconfigure duel"),
		"a yes goes back to Magic Battle, which is what the button says")
	duel._intro_overlay.go_pressed.emit()
	await get_tree().process_frame


func test_a_gauntlets_duel_is_held_in_the_gauntlets_words() -> void:
	var screen := _gauntlet()
	await get_tree().process_frame
	var duel := screen._match._duel
	assert_eq(duel.leave_title, GauntletState.TITLE)
	assert_eq(duel.leave_label, GauntletState.QUIT)
	assert_string_contains(duel.leave_question, "round 1")
	duel._run_intro()
	var labels := _buttons(duel._intro_overlay)
	assert_true(labels.has(GauntletState.QUIT), "the splash's way out is the run's own")
	assert_false(labels.has("Reconfigure duel"), "never a door to Magic Battle")
	duel._intro_overlay.go_pressed.emit()
	await get_tree().process_frame


# ================================================ the gauntlet: it asks ==

func test_the_splash_asks_and_cancel_leaves_the_run_and_the_splash_alone() -> void:
	var screen := _gauntlet()
	await get_tree().process_frame
	var round_match := screen._match
	var duel := round_match._duel
	duel._run_intro()
	var intro := duel._intro_overlay
	_press(intro, GauntletState.QUIT)
	assert_true(duel.leave_question_open(), "the question is up")
	assert_false(intro.is_processing(), "and the five seconds have stopped under it")
	assert_string_contains(_text_of(duel._leave_dialog), "Quit the gauntlet?")
	assert_eq(_buttons(duel._leave_dialog), ["Yes, I'm sure", "Cancel"] as Array[String],
		"the Concede question's own two answers")
	_press(duel._leave_dialog, "Cancel")
	await get_tree().process_frame
	assert_false(duel.leave_question_open())
	assert_eq(screen._match, round_match, "the run is untouched")
	assert_false(screen.state.over)
	assert_true(is_instance_valid(intro) and duel._intro_overlay == intro,
		"and the splash still waits for Go!")
	intro.go_pressed.emit()
	await get_tree().process_frame


func test_exit_duel_asks_before_it_ends_the_run() -> void:
	var screen := _gauntlet()
	await get_tree().process_frame
	var round_match := screen._match
	var duel := round_match._duel
	var scene := get_tree().current_scene
	duel._on_pause_chosen(DuelPause.Action.EXIT_DUEL)
	assert_true(duel.leave_question_open(), "Exit duel asks first")
	assert_eq(screen._match, round_match, "nothing has gone yet")
	assert_eq(get_tree().current_scene, scene, "and no scene was changed")
	assert_false(screen.state.over)


func test_yes_ends_the_run_and_puts_gauntlet_options_back() -> void:
	var screen := _gauntlet()
	await get_tree().process_frame
	var duel := screen._match._duel
	var scene := get_tree().current_scene
	duel._on_pause_chosen(DuelPause.Action.EXIT_DUEL)
	_press(duel._leave_dialog, "Yes, I'm sure")
	await get_tree().process_frame
	assert_eq(get_tree().current_scene, scene, "never the battle-setup screen")
	assert_true(screen.state.over, "the run is over")
	assert_null(screen._match, "its match is gone")
	assert_not_null(screen._window, "and a window of the gauntlet's own is up")
	assert_string_contains(_text_of(screen._window), GauntletOptions.TITLE)
	assert_true(_buttons(screen._window).has(GauntletOptions.RUN))
	assert_eq(screen.options.best_of, 3, "the run's parameters still set")
	# `Run the gauntlet` again: a new run from round 1.
	screen.begin_run()
	await get_tree().process_frame
	assert_not_null(screen._match, "a new run is on")
	assert_false(screen.state.over)
	assert_eq(screen.state.round_number, 1)
	assert_string_contains(screen._match._duel.leave_question, "round 1")


func test_yes_on_the_splash_does_the_same() -> void:
	var screen := _gauntlet()
	await get_tree().process_frame
	var duel := screen._match._duel
	duel._run_intro()
	_press(duel._intro_overlay, GauntletState.QUIT)
	_press(duel._leave_dialog, "Yes, I'm sure")
	await get_tree().process_frame
	assert_true(screen.state.over)
	assert_null(screen._match)
	assert_string_contains(_text_of(screen._window), GauntletOptions.TITLE)


# ============================================ a match from Magic Battle ==

func test_a_matchs_exit_duel_asks_and_its_yes_is_not_passed_up() -> void:
	var runner := _match()
	await get_tree().process_frame
	runner._duel.duel_finished.emit(0)     # 1-0 on the record
	await get_tree().process_frame
	var duel := runner._duel
	watch_signals(runner)
	duel._on_pause_chosen(DuelPause.Action.EXIT_DUEL)
	assert_true(duel.leave_question_open(), "the record is not dropped unasked")
	assert_string_contains(_text_of(duel._leave_dialog), "Magic Battle")
	_press(duel._leave_dialog, "Yes, I'm sure")
	assert_signal_not_emitted(runner, "leave_confirmed",
		"nobody owns this match: it goes back to Magic Battle itself")
	assert_true(ResourceLoader.exists(MatchScreen.SETUP_SCREEN), "which exists")


# ============================================================ the keys ==

func test_escape_is_the_questions_cancel_on_the_table_and_on_the_splash() -> void:
	var screen := _gauntlet()
	await get_tree().process_frame
	var duel := screen._match._duel
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	duel._ask_to_leave()
	duel._unhandled_key_input(escape)
	assert_false(duel.leave_question_open(), "Esc over the table")
	assert_false(duel.is_paused(), "and it did not open the Pause window as well")
	await get_tree().process_frame
	duel._toss_active = true          # the splash and the coin are up
	duel._ask_to_leave()
	duel._last_stroke = {"action": "", "key": false, "device": 0, "ms": -1000000}
	duel._unhandled_key_input(escape)
	assert_false(duel.leave_question_open(), "Esc over the splash")
	assert_false(duel.is_paused())
	duel._toss_active = false


func test_the_verdict_takes_the_question_down() -> void:
	var duel: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	duel.config = DuelConfig.vs_ai_default(AiProfile.wizard())
	duel.leave_question = "Quit?"
	add_child_autofree(duel)
	await get_tree().process_frame
	duel._ask_to_leave()
	assert_true(duel.leave_question_open())
	duel.game.concede(0)
	assert_false(duel.leave_question_open(), "a duel that is over is not left by a question about it")

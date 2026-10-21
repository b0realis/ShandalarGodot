extends GutTest
## THE SECOND BUG HUNT (2026-10-21), the screens: a held duel's question
## asked over the pre-duel splash from the Pause window.
##
## WAS: in a match or a Gauntlet round, Pause → `Exit duel` or `Return to
## main menu` over the five-second splash asked "Quit this match?" (ui-1
## of the review the same day) — but only the splash's own button stopped
## the five seconds. They ran on under the question, and at zero the
## splash's `Go!` answered it no: the question vanished, the coin was
## tossed, and a "Yes" a moment later pressed nothing. NOW asking stops
## the countdown whichever door asked (`DuelScreen._ask_to_leave`); after
## `Cancel` the splash waits for `Go!`, as it does after its own button.


func _match() -> MatchScreen:
	var runner: MatchScreen = load("res://game/match_screen.tscn").instantiate()
	var config := DuelConfig.hotseat_default()
	config.best_of = 3
	config.rng_seed = 4242
	runner.config = config
	add_child_autofree(runner)
	return runner


## The splash's seconds run out, as frames would run them.
func _run_out(duel: DuelScreen) -> void:
	duel._intro_overlay._left = 0.01
	for i in 3:
		await get_tree().process_frame


func _end_the_splash(duel: DuelScreen) -> void:
	duel._cancel_leave()
	if is_instance_valid(duel._intro_overlay):
		duel._intro_overlay.go_pressed.emit()
	await get_tree().process_frame


func _ask_over_the_splash(action: int) -> DuelScreen:
	var runner := _match()
	await get_tree().process_frame
	var duel: DuelScreen = runner._duel
	duel._run_intro()
	duel._open_pause()
	duel._on_pause_chosen(action)
	assert_true(duel.leave_question_open(), "the held duel asks")
	return duel


func test_exit_duel_over_the_splash_keeps_asking() -> void:
	var duel := await _ask_over_the_splash(DuelPause.Action.EXIT_DUEL)
	await _run_out(duel)
	assert_true(duel.leave_question_open(), "still asking when the five seconds would be up")
	assert_true(is_instance_valid(duel._intro_overlay), "and the splash still up under it")
	await _end_the_splash(duel)


func test_main_menu_over_the_splash_keeps_asking() -> void:
	var duel := await _ask_over_the_splash(DuelPause.Action.MAIN_MENU)
	await _run_out(duel)
	assert_true(duel.leave_question_open())
	await _end_the_splash(duel)


func test_after_cancel_the_splash_waits_for_go() -> void:
	var duel := await _ask_over_the_splash(DuelPause.Action.EXIT_DUEL)
	duel._cancel_leave()
	await _run_out(duel)
	assert_true(is_instance_valid(duel._intro_overlay) and duel._intro_overlay != null,
		"touched, so it waits for Go! — as after its own button")
	await _end_the_splash(duel)


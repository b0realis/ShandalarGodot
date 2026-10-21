extends GutTest
## THE SECOND BUG HUNT (2026-10-21), the screens: leaving a duel while its
## opening (the splash, the coin, the play-or-draw and mulligan window)
## waits.
##
## WAS: Pause → `Exit duel` or `Return to main menu` changes the scene,
## which takes the duel screen out of the tree at once and frees it at the
## end of the frame — and the opening, waiting on frames, carried on in
## between. `OpeningWindow.ask` came back with no button pressed, which
## `OpeningHand.run` read as `Play first` and a keep at every question:
## the abandoned duel was STARTED, and the screen's refresh then asked a
## tree that was gone for the computer's timer (a script error). Left over
## the splash, `DuelScreen._first_of` asked the missing tree for its next
## frame (another). NOW an opening whose window has gone stops where it
## is, and the screen's waits end with the screen.

var host: Control
var game: MtgGame


func before_each() -> void:
	host = Control.new()
	add_child_autofree(host)
	game = MtgGame.new()
	var deck: Array = []
	for i in 17:
		deck.append("Forest")
	for i in 23:
		deck.append("Grizzly Bears")
	game.setup(deck, deck.duplicate(), "P0", "P1", 20, 20, 424242)
	game.deal_opening_hands(7)


func _asking(winner: int) -> OpeningHand:
	var opening := OpeningHand.new()
	host.add_child(opening)
	opening.run(game, winner, func(pid: int) -> bool: return pid == 0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_not_null(opening.window(), "control: the window asks")
	return opening


func _leave(opening: OpeningHand) -> void:
	host.remove_child(opening)
	await get_tree().process_frame
	await get_tree().process_frame


func test_left_at_play_or_draw_the_duel_does_not_start() -> void:
	var opening := await _asking(0)
	var announced: Array = []
	opening.announced.connect(func(line: String) -> void: announced.append(line))
	await _leave(opening)
	assert_eq(game.turn_number, 0, "no duel started for a screen that left")
	assert_true(game.mulligan_open, "the opening is where it was")
	assert_eq(announced, [], "and nobody was said to play first")
	opening.free()


func test_left_at_the_mulligan_the_hand_is_not_kept_for_the_player() -> void:
	var opening := await _asking(1)       # the computer won: the player is asked about the hand
	var window := opening.window()
	assert_true(window.button_labels().has(OpeningHand.MULLIGAN["take"]), "control: the mulligan question")
	await _leave(opening)
	assert_eq(game.turn_number, 0, "no duel started")
	opening.free()


func test_answered_in_the_tree_it_still_starts() -> void:
	var opening := await _asking(0)
	var window := opening.window()
	assert_true(window.press(OpeningHand.PLAY_OR_DRAW["play_first"]))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(window.press(OpeningHand.MULLIGAN["start"]))
	for i in 4:
		await get_tree().process_frame
	assert_eq(game.turn_number, 1, "the control: a duel answered in place begins")


func test_a_splash_left_mid_wait_asks_no_missing_tree() -> void:
	var duel: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	duel.config = DuelConfig.vs_ai_default(AiProfile.wizard())
	add_child(duel)
	await get_tree().process_frame
	duel._run_intro()
	remove_child(duel)
	# Any script error here fails the run (`run_tests.sh` reads every
	# `SCRIPT ERROR` line), which is the assertion.
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(duel.is_inside_tree())
	duel.free()


# ------------------------------------------ the opening window's keys --
## ALSO WAS: the splash's `Go!` held the keyboard focus and went with the
## splash, and the opening window never took it — Return and Space
## answered neither Play/Draw nor the mulligan, and a player at a keyboard
## had to reach for the mouse. NOW the last button of each row (`Play
## first`, `Start the duel`) holds it.

func test_each_question_holds_the_keyboard_focus() -> void:
	get_viewport().gui_release_focus()
	var opening := await _asking(0)
	var window := opening.window()
	var focus := get_viewport().gui_get_focus_owner()
	assert_not_null(focus, "the order question holds the focus")
	if focus == null:
		return
	assert_true(window.is_ancestor_of(focus), "on the window's own button")
	assert_eq((focus as Button).text, OpeningHand.PLAY_OR_DRAW["play_first"])
	(focus as Button).pressed.emit()   # what Return on it does
	await get_tree().process_frame
	await get_tree().process_frame
	focus = get_viewport().gui_get_focus_owner()
	assert_not_null(focus, "the hand question holds it too")
	if focus == null:
		return
	assert_eq((focus as Button).text, OpeningHand.MULLIGAN["start"], "on the keep")
	(focus as Button).pressed.emit()
	for i in 4:
		await get_tree().process_frame
	assert_eq(game.turn_number, 1, "answered from the keys alone, the duel begins")

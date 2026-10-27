extends GutTest
## THE MATCH'S AND THE GAUNTLET'S WINDOWS (the bug campaign c12, h4-5,
## h4-9 and h5-4): the between-duels window holds its whole button row and
## takes the keyboard — and gives it back after `Sideboard...` closes; the
## gauntlet's announcement and round windows take the keyboard too; Escape
## on Gauntlet Options is its `Exit`; and every duel of a match carries
## the match's format into its record.

const DECK_A := "res://decks/big_green.deck"
const DECK_B := "res://decks/blue_skies.deck"
const DECK_C := "res://decks/mountain_artillery.deck"


func _config(ai: bool, sideboard := true) -> DuelConfig:
	var config := DuelConfig.hotseat_default()
	if ai:
		config.pilots = [null, AiProfile.wizard()]
	config.best_of = 3
	config.sideboard_between_duels = sideboard
	config.rng_seed = 31337
	var deck := DeckList.load_file("res://decks/white_knights.deck", true)
	config.decks[0] = deck.cards.duplicate()
	config.sideboards[0] = deck.sideboard.duplicate()
	config.sideboards[1] = deck.sideboard.duplicate()
	return config


func _match(config: DuelConfig) -> MatchScreen:
	var runner: MatchScreen = load("res://game/match_screen.tscn").instantiate()
	runner.config = config
	add_child_autofree(runner)
	await get_tree().process_frame
	return runner


## The between-duels window raised by hand, as the match's own tests do:
## headless plays straight on and never raises it.
func _window_after_one_duel(runner: MatchScreen) -> OriginalDialog:
	runner.state.record(0)
	runner._show_window()
	for i in 3:
		await get_tree().process_frame
	return runner._window as OriginalDialog


func _foot(dialog: OriginalDialog) -> Array[Button]:
	var out: Array[Button] = []
	for child in dialog._buttons.get_children():
		if child is Button:
			out.append(child)
	return out


func _assert_row_inside(dialog: OriginalDialog, what: String) -> void:
	var frame := dialog.get_global_rect()
	for button in _foot(dialog):
		assert_true(frame.encloses(button.get_global_rect()),
			"%s: `%s` inside the window (%s in %s)" % [what, button.text,
				button.get_global_rect(), frame])


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


# ============================================================ h4-5: match ==

func test_the_window_holds_its_row_against_the_computer() -> void:
	var runner: MatchScreen = await _match(_config(true))
	var dialog: OriginalDialog = await _window_after_one_duel(runner)
	assert_eq(_foot(dialog).size(), 4, "Sideboard, Edit deck, Continue, Quit")
	_assert_row_inside(dialog, "against the computer")


func test_the_window_holds_its_row_in_hotseat() -> void:
	var runner: MatchScreen = await _match(_config(false))
	var dialog: OriginalDialog = await _window_after_one_duel(runner)
	assert_eq(_foot(dialog).size(), 5, "a Sideboard button for each seat")
	_assert_row_inside(dialog, "hotseat")
	assert_true(get_viewport().get_visible_rect().encloses(dialog.get_global_rect()),
		"and the window stays on the screen")


func test_continue_match_holds_the_keyboard() -> void:
	var runner: MatchScreen = await _match(_config(false))
	await _window_after_one_duel(runner)
	var owner := _focus()
	assert_not_null(owner, "something on the window has the focus")
	if owner != null:
		assert_eq((owner as Button).text, MatchScreen.CONTINUE,
			"Enter continues the match")


func test_the_last_windows_ok_holds_the_keyboard() -> void:
	var runner: MatchScreen = await _match(_config(true, false))
	runner.state.record(0)
	runner.state.record(0)
	assert_true(runner.state.is_over())
	runner._show_window()
	await get_tree().process_frame
	var owner := _focus()
	assert_not_null(owner)
	if owner != null:
		assert_eq((owner as Button).text, "OK")
		assert_true(runner._window.is_ancestor_of(owner))


func test_the_keyboard_comes_back_when_the_sideboard_closes() -> void:
	var runner: MatchScreen = await _match(_config(false))
	await _window_after_one_duel(runner)
	runner._open_sideboard(1)
	assert_true(runner._sb_dialog.is_ancestor_of(_focus()), "Done has it while it is open")
	runner._close_sideboard()
	await get_tree().process_frame
	var owner := _focus()
	assert_not_null(owner, "the keyboard is not left with nothing")
	if owner != null:
		assert_true(runner._window.is_ancestor_of(owner), "back on the between-duels window")
		assert_eq((owner as Button).text, MatchScreen.SIDEBOARD)
		assert_string_contains(owner.tooltip_text, runner.config.player_names[1],
			"on the seat's own button, the one that opened it")


# ============================================================= h5-4: format ==

func test_each_duel_of_a_match_carries_the_matchs_format() -> void:
	var config := _config(true)
	config.deck_format = DeckFormat.HIGHLANDER
	var runner: MatchScreen = await _match(config)
	assert_eq(runner._duel.config.deck_format, DeckFormat.HIGHLANDER, "duel 1")
	runner._duel.duel_finished.emit(0)
	await get_tree().process_frame
	assert_eq(runner._duel.config.deck_format, DeckFormat.HIGHLANDER, "and duel 2")


# ========================================================= h4-5: gauntlet ==

func _gauntlet() -> GauntletScreen:
	var screen: GauntletScreen = \
		load("res://game/duel/gauntlet_screen.tscn").instantiate()
	var config := DuelConfig.hotseat_default()
	config.rng_seed = 90210
	screen.config = config
	screen.opponent_paths = [DECK_A, DECK_B, DECK_C] as Array[String]
	screen.options.best_of = 1
	screen.options.ante = false
	screen.options.your_deck = DECK_A
	add_child_autofree(screen)
	await get_tree().process_frame
	return screen


func test_the_announcement_takes_the_keyboard() -> void:
	var screen: GauntletScreen = await _gauntlet()
	screen._show_announcement(screen._match.config)
	await get_tree().process_frame
	var owner := _focus()
	assert_not_null(owner, "Enter answers the window")
	if owner != null:
		assert_true(screen._window.is_ancestor_of(owner))
		assert_eq((owner as Button).text, "OK")
	_assert_row_inside(screen._window, "the announcement")


func test_the_round_window_takes_the_keyboard() -> void:
	var screen: GauntletScreen = await _gauntlet()
	screen._show_round_window(screen.state.end_of_duel_lines(
		GauntletState.Outcome.WON, true, true))
	await get_tree().process_frame
	var owner := _focus()
	assert_not_null(owner, "Enter answers the window")
	if owner != null:
		assert_true(screen._window.is_ancestor_of(owner))
		assert_eq((owner as Button).text, GauntletState.NEXT_ROUND)
	_assert_row_inside(screen._window, "the round window")


# ============================================================ h4-9: Escape ==

func _escape() -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = "ui_cancel"
		ev.pressed = pressed
		Input.parse_input_event(ev)
	for i in 2:
		await get_tree().process_frame


func test_escape_on_gauntlet_options_is_its_exit() -> void:
	var screen: GauntletScreen = await _gauntlet()
	# Headless begins the run at once; the window is raised over an empty
	# screen, as a player first meets it.
	screen._drop_match()
	await get_tree().process_frame
	screen._show_options()
	var options: OriginalDialog = screen._window
	var exits := [0]
	for button in options.find_children("*", "Button", true, false):
		if (button as Button).text == GauntletOptions.EXIT:
			(button as Button).pressed.connect(func() -> void: exits[0] += 1)
	await _escape()
	assert_eq(exits[0], 1, "Escape pressed Exit, once")
	assert_false(is_instance_valid(options) and not options.is_queued_for_deletion(),
		"and Exit closed the window")


func test_escape_leaves_the_gauntlets_other_windows_alone() -> void:
	var screen: GauntletScreen = await _gauntlet()
	screen._show_round_window(screen.state.end_of_duel_lines(
		GauntletState.Outcome.WON, true, true))
	var round_window: Control = screen._window
	await _escape()
	assert_true(is_instance_valid(round_window) and not round_window.is_queued_for_deletion(),
		"a key must not end a run unasked")
	assert_false(screen.state.over)

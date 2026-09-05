extends GutTest
## THE GAUNTLET, RUNNING — [GauntletScreen] and [GauntletOptions]: the
## outer loop that owns [MatchScreen]s, the two windows, and the one new
## signal on the match screen that lets a match hand its result upward.
##
## The duels are not played here (there are tests for a duel, and tests
## for a match): what is pinned is the RUN — that a won match advances the
## round and a lost one ends it, that the session record is the run's and
## not the match's, that the round window offers `Next round` /
## `Quit Gauntlet` while there is a round to offer and neither when there
## is not, and that one seed replays a whole gauntlet.


const DECK_A := "res://decks/big_green.deck"
const DECK_B := "res://decks/blue_skies.deck"
const DECK_C := "res://decks/mountain_artillery.deck"


## A gauntlet screen, built but NOT yet in the tree — `_ready` starts the
## run, so every parameter has to be set before it enters.
func _make(decks: Array[String], size := 1,
		seed_value := 90210) -> GauntletScreen:
	var screen: GauntletScreen = \
		load("res://game/duel/gauntlet_screen.tscn").instantiate()
	var config := DuelConfig.hotseat_default()
	config.rng_seed = seed_value
	screen.config = config
	screen.opponent_paths = decks
	screen.options.best_of = size
	screen.options.ante = false
	screen.options.your_deck = DECK_A
	return screen


func _screen(decks: Array[String], size := 1,
		seed_value := 90210) -> GauntletScreen:
	var screen := _make(decks, size, seed_value)
	add_child_autofree(screen)
	return screen


## End the duel that is running, the way [MatchScreen]'s own tests do —
## the duel screen's signal is the only thing the layer above it listens
## to. Seat 0 is the human seat in a gauntlet, by definition.
func _finish_duel(screen: GauntletScreen, winner: int) -> void:
	screen._match._duel.duel_finished.emit(winner)
	await get_tree().process_frame


## The labels on a dialog's own foot row — not every Button under it, an
## OptionButton being a Button too.
func _foot_buttons(dialog: OriginalDialog) -> Array[String]:
	var out: Array[String] = []
	for child in dialog._buttons.get_children():
		out.append((child as Button).text)
	return out


## Every [Label]'s text under [param node], joined — enough to assert a
## window says a thing without pinning its layout.
func _text_of(node: Node) -> String:
	var out := ""
	for child in node.get_children():
		if child is Label:
			out += (child as Label).text + "\n"
		out += _text_of(child)
	return out


## Press a dialog's own foot button by its label.
func _press(dialog: OriginalDialog, label: String) -> void:
	for child in dialog._buttons.get_children():
		if (child as Button).text == label:
			(child as Button).pressed.emit()
			return
	fail_test("no '%s' button on the dialog" % label)


func _checkbox(node: Node, label: String) -> CheckBox:
	for child in node.get_children():
		if child is CheckBox and (child as CheckBox).text == label:
			return child
		var found := _checkbox(child, label)
		if found != null:
			return found
	return null


# ================================================================ the run ==

func test_a_run_starts_its_first_match_against_a_shuffled_opponent() -> void:
	var screen := _screen([DECK_A, DECK_B])
	await get_tree().process_frame
	assert_eq(screen.state.length(), 2, "two decks, two opponents")
	assert_not_null(screen._match, "round 1 is a whole MatchScreen")
	assert_not_null(screen._match._duel, "and it has started its duel")
	assert_eq(screen.state.round_number, 1)
	assert_true([DECK_A, DECK_B].has(screen.state.opponent()))


func test_the_opponent_is_named_by_its_deck_on_the_duel() -> void:
	var screen := _screen([DECK_A, DECK_B])
	await get_tree().process_frame
	assert_eq(screen._match.config.player_names[1], screen.state.opponent_name(),
		"`Your next duel is against %s.` and the seat agree")
	assert_ne(screen.state.opponent_name(), "",
		"and the name is the deck's own, not the file's path")


func test_a_won_match_advances_the_run_to_the_next_opponent() -> void:
	var screen := _screen([DECK_A, DECK_B])
	await get_tree().process_frame
	var first := screen.state.opponent()
	await _finish_duel(screen, 0)
	assert_eq(screen.state.round_number, 2, "round 2 of 2")
	assert_false(screen.state.over)
	assert_ne(screen.state.opponent(), first, "a different deck")
	assert_not_null(screen._match._duel, "and a new match is under way")


func test_a_lost_match_ends_the_run_where_it_stands() -> void:
	var screen := _screen([DECK_A, DECK_B, DECK_C])
	await get_tree().process_frame
	await _finish_duel(screen, 1)
	assert_true(screen.state.over, "a gauntlet cannot be resumed after a loss")
	assert_false(screen.state.completed)
	assert_eq(screen.state.round_number, 1)


func test_winning_every_match_runs_the_gauntlet() -> void:
	var screen := _screen([DECK_A, DECK_B])
	await get_tree().process_frame
	await _finish_duel(screen, 0)
	await _finish_duel(screen, 0)
	assert_true(screen.state.over)
	assert_true(screen.state.completed,
		"the `You've successfully run the gauntlet!` branch")


func test_a_match_is_more_than_one_duel_when_the_size_says_so() -> void:
	# `Best of &Three`: the run must not advance on the first duel.
	var screen := _screen([DECK_A, DECK_B], 3)
	await get_tree().process_frame
	assert_eq(screen._match.state.best_of, 3, "the Match Size reached the match")
	var match_one := screen._match
	await _finish_duel(screen, 0)
	assert_eq(screen.state.round_number, 1, "1-0 is not a match")
	assert_eq(screen._match, match_one, "still the same round")
	await _finish_duel(screen, 0)
	assert_eq(screen.state.round_number, 2, "2-0 is")


func test_the_match_screen_hands_its_result_up_instead_of_leaving() -> void:
	# The one change the gauntlet needed in `game/match_screen.gd`: with a
	# listener, a finished match emits rather than showing its own last
	# window and changing scene.
	var screen := _screen([DECK_A, DECK_B])
	await get_tree().process_frame
	var finished := screen._match
	watch_signals(finished)
	# Not awaited: the whole hand-off is synchronous, and one frame later
	# this MatchScreen has been freed.
	finished._duel.duel_finished.emit(0)
	assert_signal_emit_count(finished, "match_finished", 1)
	assert_signal_emitted_with_parameters(finished, "match_finished", [0])
	await get_tree().process_frame   # let the freed round go, after the asserts


func test_a_gauntlets_match_knows_its_last_word_is_not_its_own() -> void:
	var screen := _screen([DECK_A, DECK_B])
	await get_tree().process_frame
	assert_true(screen._match.reports_to_owner)


func test_a_standalone_match_keeps_its_own_window_and_its_own_exit() -> void:
	# The flag, not the signal, is what switches the behaviour — a match
	# started from the battle-setup screen still announces itself, and
	# still ends on its own terms. (Counting connections would have made a
	# test that merely WATCHES the signal change the behaviour under it.)
	var runner: MatchScreen = load("res://game/match_screen.tscn").instantiate()
	var config := DuelConfig.hotseat_default()
	config.best_of = 1
	config.rng_seed = 4242
	runner.config = config
	add_child_autofree(runner)
	await get_tree().process_frame
	assert_false(runner.reports_to_owner, "nobody claimed this match")
	watch_signals(runner)
	runner._duel.duel_finished.emit(0)
	assert_signal_emit_count(runner, "match_finished", 1,
		"the fact is announced either way")
	assert_true(runner.state.is_over())
	assert_eq(runner.state.verdict(), MatchState.WON,
		"and a best of ONE is a match, with a verdict of its own")


# ============================================================= the record ==

func test_the_session_record_is_the_runs_and_not_the_matchs() -> void:
	# `0x5f76c0 / 0x5f6494 / 0x5f67fc` against the match's own pair, which
	# is zeroed every time a match ends while these are not. Folded in as
	# each match ends — the only moment the round window reads them.
	var screen := _screen([DECK_A, DECK_B, DECK_C], 3)
	await get_tree().process_frame
	await _finish_duel(screen, 0)
	await _finish_duel(screen, 1)
	await _finish_duel(screen, 0)          # 2-1: the match, and round 1
	assert_eq(screen.state.round_number, 2)
	assert_eq([screen.state.wins, screen.state.losses, screen.state.ties],
		[2, 1, 0], "three duels, all three on the run's record")
	assert_eq(screen._match.state.duels_played(), 0,
		"while round 2's own match starts from nothing")


func test_a_drawn_duel_lands_in_the_session_record() -> void:
	var screen := _screen([DECK_A, DECK_B, DECK_C], 3)
	await get_tree().process_frame
	await _finish_duel(screen, -1)
	await _finish_duel(screen, -1)
	await _finish_duel(screen, -1)         # the duels ran out: a tie
	assert_eq(screen.state.ties, 3)
	assert_true(screen.state.over, "a match you did not take ends the run")


# ======================================================== the round window ==

func test_the_round_window_says_the_message_the_round_and_the_record() -> void:
	var screen := _screen([DECK_A, DECK_B, DECK_C])
	await get_tree().process_frame
	screen.state.wins = 4
	screen.state.losses = 1
	screen.state.ties = 2
	var lines := screen.state.end_of_duel_lines(
		GauntletState.Outcome.WON, true, true)
	screen._show_round_window(lines)
	var text := _text_of(screen._window)
	assert_true(text.contains(GauntletState.TITLE), "the window names the mode")
	assert_true(text.contains("Congratulations!"))
	assert_true(text.contains("You won the match."))
	assert_true(text.contains("Your next duel is against"))
	assert_true(text.contains("That was round 1"))
	assert_true(text.contains("Your record is 4/1/2"))


func test_the_round_window_offers_the_next_round_and_the_way_out() -> void:
	var screen := _screen([DECK_A, DECK_B, DECK_C])
	await get_tree().process_frame
	screen._show_round_window(screen.state.end_of_duel_lines(
		GauntletState.Outcome.WON, true, true))
	assert_eq(_foot_buttons(screen._window),
		[GauntletState.NEXT_ROUND, GauntletState.QUIT] as Array[String])


func test_a_finished_run_HIDES_both_buttons_rather_than_greying_them() -> void:
	# The decompiled dialog `0xf6` hides `0x493`/`0x494` and shows the
	# lone OK it had hidden to make room for them. A dead-end dialog
	# offering a greyed `Next round` would be offering a round that does
	# not exist — §6.1's "grey what you cannot offer" is about menus.
	var screen := _screen([DECK_A, DECK_B, DECK_C])
	await get_tree().process_frame
	screen.state.over = true
	screen._show_round_window(screen.state.end_of_duel_lines(
		GauntletState.Outcome.LOST, true, false))
	var buttons := _foot_buttons(screen._window)
	assert_eq(buttons, ["OK"] as Array[String])
	assert_false(buttons.has(GauntletState.NEXT_ROUND), "absent, not disabled")


func test_pressing_next_round_closes_the_window_and_puts_a_match_up() -> void:
	# Headless never opens the window (it plays straight on and adds no
	# wait a headless run did not have), so the window is raised by hand
	# and the button's own handler driven — which is what a player
	# pressing `&Next round` calls.
	var screen := _screen([DECK_A, DECK_B, DECK_C])
	await get_tree().process_frame
	screen._show_round_window(screen.state.end_of_duel_lines(
		GauntletState.Outcome.WON, true, true))
	assert_not_null(screen._window)
	var before := screen._match
	screen._next_round()
	await get_tree().process_frame
	assert_null(screen._window, "the window is dismissed")
	assert_ne(screen._match, before, "and the round's match is on screen")
	assert_eq(screen._match.state.duels_played(), 0, "starting from nothing")


# =========================================================== determinism ==

func test_one_seed_replays_a_whole_run() -> void:
	var first: Array = []
	var second: Array = []
	for pass_number in 2:
		var screen := _screen([DECK_A, DECK_B, DECK_C], 1, 31337)
		await get_tree().process_frame
		var record := []
		for _round in 3:
			record.append(screen.state.opponent())
			record.append(screen._match.config.rng_seed)
			await _finish_duel(screen, 0)
		if pass_number == 0:
			first = record
		else:
			second = record
	assert_eq(first, second,
		"same seed: same opponents, in the same order, on the same seeds")


func test_a_different_seed_is_a_different_run() -> void:
	var seeds := {}
	for seed_value in [11, 22, 33, 44]:
		var screen := _screen([DECK_A, DECK_B, DECK_C], 1, seed_value)
		await get_tree().process_frame
		seeds[screen._match.config.rng_seed] = true
	assert_gt(seeds.size(), 1, "the run is not the same every time")


func test_every_match_gets_its_own_seed_and_never_zero() -> void:
	var screen := _screen([DECK_A, DECK_B, DECK_C])
	await get_tree().process_frame
	var seen := {}
	for _round in 3:
		var value: int = screen._match.config.rng_seed
		assert_ne(value, 0, "0 would mean 'roll one' and lose the replay")
		seen[value] = true
		await _finish_duel(screen, 0)
	assert_eq(seen.size(), 3, "three different matches")


# ====================================================== Gauntlet Options ==

func test_the_options_window_carries_the_dialogs_own_entries() -> void:
	var options := GauntletOptions.new()
	var dialog := options.window([DECK_A, DECK_B] as Array[String],
		func() -> void: pass, func() -> void: pass)
	add_child_autofree(dialog)
	var text := _text_of(dialog)
	for entry in [GauntletOptions.TITLE, GauntletOptions.MATCH_SIZE,
			GauntletOptions.ENEMY_LEVEL, GauntletOptions.NUM_OPPONENTS,
			GauntletOptions.YOUR_DECK]:
		assert_true(text.contains(entry), "the window says %s" % entry)
	for label in [GauntletOptions.BEST_OF_THREE, GauntletOptions.BEST_OF_ONE,
			GauntletOptions.ANTE, GauntletOptions.SIDEBOARD]:
		assert_not_null(_checkbox(dialog, label), "a control for %s" % label)
	for level in GauntletOptions.ENEMY_LEVELS:
		assert_not_null(_checkbox(dialog, level), "an Enemy Level %s" % level)
	assert_eq(_foot_buttons(dialog),
		[GauntletOptions.RUN, GauntletOptions.EXIT] as Array[String])


func test_the_options_window_never_offers_the_opponents_deck() -> void:
	# The decompiled startup screen DISABLES its opponent combo and
	# `Pick a deck` whenever `&Gauntlet` is chosen (`0x463`/`0x468`): in a
	# gauntlet you do not choose who you meet.
	var options := GauntletOptions.new()
	var dialog := options.window([DECK_A, DECK_B] as Array[String],
		func() -> void: pass, func() -> void: pass)
	add_child_autofree(dialog)
	assert_false(_text_of(dialog).to_lower().contains("opponent's deck"))


func test_the_match_size_pair_writes_the_wins_needed_the_original_sets() -> void:
	var options := GauntletOptions.new()
	var dialog := options.window([DECK_A] as Array[String],
		func() -> void: pass, func() -> void: pass)
	add_child_autofree(dialog)
	assert_eq(options.best_of, 3, "Best of Three is the default")
	_checkbox(dialog, GauntletOptions.BEST_OF_ONE).button_pressed = true
	assert_eq(options.best_of, 1)
	var state := MatchState.new()
	state.best_of = options.best_of
	assert_eq(state.wins_needed(), 1, "`0x456`/`0x457` -> 2 or 1, unchanged")
	_checkbox(dialog, GauntletOptions.BEST_OF_THREE).button_pressed = true
	assert_eq(options.best_of, 3)
	state.best_of = options.best_of
	assert_eq(state.wins_needed(), 2)


func test_the_four_enemy_levels_are_the_four_ai_profiles() -> void:
	assert_eq(GauntletOptions.ENEMY_LEVELS,
		["Apprentice", "Magician", "Sorcerer", "Wizard"] as Array[String])
	for i in GauntletOptions.ENEMY_LEVELS.size():
		assert_eq(GauntletOptions.profile(i).profile_name,
			GauntletOptions.ENEMY_LEVELS[i])


func test_the_enemy_level_reaches_the_opponents_seat() -> void:
	var screen := _make([DECK_A, DECK_B])
	screen.options.enemy_level = 0
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_eq(screen._match.config.pilots[1].profile_name, "Apprentice")
	assert_null(screen._match.config.pilots[0],
		"the gauntlet is single-seat: seat 0 is you")
	assert_eq(screen._match.state.human_seat, 0)


func test_the_difficulty_readout_is_a_number_and_one_of_five_bands() -> void:
	# `[QoL]` — the format string and the five band names are the shell
	# page's own (`Program/UIStrings.txt:63-68`); the number is ours.
	assert_eq(GauntletOptions.BANDS,
		["very easy", "easy", "normal", "hard", "very hard"] as Array[String])
	assert_eq(GauntletOptions.difficulty(0, false, 3, 0), 0, "the floor")
	assert_eq(GauntletOptions.band(0), "very easy")
	assert_eq(GauntletOptions.difficulty(3, true, 1, 20), 9 + 1 + 2 + 5)
	assert_eq(GauntletOptions.band(17), "very hard")
	# The one input rule any source gives us — manual p.138, *"Playing for
	# ante adds 1 to the Difficulty."*
	assert_eq(GauntletOptions.difficulty(2, true, 3, 4)
		- GauntletOptions.difficulty(2, false, 3, 4), 1)


func test_the_readout_line_is_the_shell_pages_own_format() -> void:
	var options := GauntletOptions.new()
	options.enemy_level = 2
	options.ante = false
	options.best_of = 3
	assert_eq(options.readout(0), "Gauntlet difficulty:   6 (normal)",
		"`Gauntlet difficulty: %3d (%s)`, width and all")


func test_num_opponents_shortens_a_run_and_never_lengthens_it() -> void:
	var options := GauntletOptions.new()
	assert_eq(options.run_length(5), 5, "0 means every deck there is")
	options.num_opponents = 2
	assert_eq(options.run_length(5), 2)
	options.num_opponents = 99
	assert_eq(options.run_length(5), 5, "never past the decks on disk")
	assert_eq(options.run_length(50), GauntletState.MAX_OPPONENTS,
		"nor past the twenty the original's buffer holds")


func test_the_run_is_as_long_as_num_opponents_says() -> void:
	var screen := _make([DECK_A, DECK_B, DECK_C])
	screen.options.num_opponents = 2
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_eq(screen.state.length(), 2, "a three-deck folder, a two-deck run")


# ============================================================== the way in ==

func test_the_title_screen_offers_the_gauntlet_under_magic_battle() -> void:
	# `@SHELLSCREEN_DUEL` numbers the shell's duel modes and the gauntlet
	# is entry 2, directly under `1Solo &Duel`.
	var menu: Control = load("res://game/main.tscn").instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame
	var labels: Array[String] = []
	var entry: Button = null
	for node in _walk(menu):
		if node is Button:
			labels.append((node as Button).text)
			if (node as Button).text == "Gauntlet":
				entry = node
	assert_not_null(entry, "the title screen has a Gauntlet button")
	if entry == null:
		return
	assert_eq(entry.tooltip_text,
		"Defeat as many opponents in a row as possible.",
		"the shell entry's own description, after the colon")
	assert_eq(labels.find("Gauntlet"), labels.find("Magic Battle") + 1,
		"directly under Magic Battle, which is `1Solo &Duel`")


func test_the_gauntlet_scene_the_button_opens_exists_and_runs() -> void:
	# The button is a scene path and a typo in it fails at runtime, not at
	# parse time — so the path itself is pinned.
	assert_true(ResourceLoader.exists("res://game/duel/gauntlet_screen.tscn"))
	var screen: GauntletScreen = \
		load("res://game/duel/gauntlet_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_not_null(screen.state, "and a bare scene run starts a real run")
	assert_gt(screen.state.length(), 0, "against the decks on disk")


func _walk(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out


# ================================================= the next-opponent window ==
#
# `@DIALOG_STARTEXP1MATCH_GAUNTLET` (`Program/UIStrings.txt:149-153`),
# slice 4. Headless never raises it — the run plays straight on, the way
# it never raises the round window — so it is raised by hand here, which
# is what the round window's own tests do one section down.

func test_the_next_opponent_window_announces_the_line_and_the_name() -> void:
	var screen := _screen([DECK_A, DECK_B, DECK_C])
	await get_tree().process_frame
	screen._show_announcement(screen._match.config)
	var text := _text_of(screen._window)
	assert_true(text.contains(GauntletState.TITLE), "the window names the mode")
	assert_true(text.contains(GauntletState.FIRST_OPPONENT),
		"round 1 gets `Your first opponent in the gauntlet:`")
	assert_true(text.contains(screen.state.opponent_name()),
		"over the opponent's own name, which is the deck's")
	assert_eq(_foot_buttons(screen._window), ["OK"] as Array[String])


func test_the_announcement_is_the_line_the_round_earns() -> void:
	var screen := _screen([DECK_A, DECK_B, DECK_C])
	await get_tree().process_frame
	screen.state.round_number = 2
	screen._show_announcement(screen._match.config)
	assert_true(_text_of(screen._window).contains(
		"You now meet opponent 2 (of 3) in the gauntlet:"),
		"the middle line counts the round out of the run")
	screen.state.round_number = 3
	screen._show_announcement(screen._match.config)
	assert_true(_text_of(screen._window).contains(
		GauntletState.FINAL_OPPONENT), "and the last round is announced as one")


func test_the_announcements_ok_is_what_puts_the_match_up() -> void:
	# The window stands between the round and its match: nothing is on
	# screen behind it until OK is pressed.
	var screen := _screen([DECK_A, DECK_B])
	await get_tree().process_frame
	screen._drop_match()
	await get_tree().process_frame
	screen._show_announcement(screen._config_for_this_round())
	assert_null(screen._match, "the round has not started yet")
	assert_not_null(screen._window)
	_press(screen._window as OriginalDialog, "OK")
	await get_tree().process_frame
	assert_null(screen._window, "the window is dismissed")
	assert_not_null(screen._match, "and the round's match is on screen")


func test_a_headless_run_never_raises_the_announcement() -> void:
	# Same contract the round window has: tests and CI play straight
	# through and add no wait a headless run did not have.
	var screen := _screen([DECK_A, DECK_B])
	await get_tree().process_frame
	assert_null(screen._window, "no window")
	assert_not_null(screen._match, "and round 1 is already being played")


# ==================================================== the opponent's deck ==

func test_an_unreadable_opponent_deck_ends_the_run() -> void:
	# `@GAUNTLETERRORS`: the original validates the opponent's deck EVERY
	# round and a failure returns it to the startup screen. A deck deleted
	# between the shuffle and the round is the case it guards.
	var screen := _screen([DECK_A, DECK_B])
	await get_tree().process_frame
	screen._drop_match()
	screen.state.order = ["res://decks/no_such_deck.deck"] as Array[String]
	screen.state.start = 0
	screen.state.round_number = 1        # (0 + 1) % 1 == 0
	screen._start_match()
	assert_true(screen.state.over, "the run cannot continue")
	assert_false(screen.state.completed, "and it was not RUN")
	assert_null(screen._match, "no match was started against nobody")


# ============================================================ your deck ==
# `@GAUNTLETERRORS` entries 1-5: YOUR deck is checked on `Run the
# gauntlet` in the `Player's deck %s is invalid.` words, and a deck that
# fails is REFUSED — not, as it was until 2026-09-02, silently swapped for
# the config's default so the player picked one deck and played another.

## A deck file under `user://decks/` — the one place a test may write a
## deck — holding [param text]; removed by [method _drop_deck].
func _write_deck(stem: String, text: String) -> String:
	var path := "user://decks/%s.deck" % stem
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(DeckStore.USER_DIR))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return path


func _drop_deck(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_a_deck_of_yours_that_cannot_be_read_refuses_the_run_by_name() -> void:
	var screen := _make([DECK_A, DECK_B])
	screen.options.your_deck = "res://decks/no_such_deck.deck"
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_null(screen._match, "no match was started")
	assert_false(screen._running, "the run has not begun")
	assert_eq(screen.last_refusal,
		GauntletState.YOUR_DECK_INVALID % "no_such_deck",
		"`@GAUNTLETERRORS` entry 2, naming the deck")
	assert_eq(screen.config.player_names[0], "White Wizard",
		"and the seat was NOT quietly handed the config's own default")


func test_a_deck_of_yours_holding_a_proxy_is_refused_not_swapped() -> void:
	# A proxy has no rules behind it; the strict load reports it as an
	# error and the setup screen refuses such a deck by name. The old
	# fall-through handed the seat the hotseat default instead.
	var path := _write_deck("_gut_gauntlet_proxy",
		"name: Proxy Probe\n36 Mountain\n4 Zzz Notional Behemoth\n")
	var screen := _make([DECK_A, DECK_B])
	screen.options.your_deck = path
	add_child_autofree(screen)
	await get_tree().process_frame
	_drop_deck(path)
	assert_null(screen._match, "no match against a deck that cannot be dealt")
	assert_eq(screen.last_refusal, GauntletState.YOUR_DECK_INVALID % "Proxy Probe")


func test_a_deck_of_yours_under_forty_cards_is_refused_in_the_originals_words() -> void:
	var path := _write_deck("_gut_gauntlet_small", "name: Too Small\n20 Mountain\n")
	var screen := _make([DECK_A, DECK_B])
	screen.options.your_deck = path
	add_child_autofree(screen)
	await get_tree().process_frame
	_drop_deck(path)
	assert_null(screen._match)
	assert_eq(screen.last_refusal, GauntletState.YOUR_DECK_TOO_SMALL % "Too Small",
		"`@GAUNTLETERRORS` entry 4")


func test_a_deck_of_yours_that_passes_is_the_one_you_play() -> void:
	var screen := _screen([DECK_A, DECK_B])
	await get_tree().process_frame
	assert_eq(screen.last_refusal, "")
	assert_not_null(screen._match)
	assert_eq(screen.config.player_names[0], "You")
	assert_eq(screen._match.config.decks[0].size(),
		DeckList.load_file(DECK_A, true).cards.size(), "seat 0 holds YOUR deck")


func test_random_deck_never_draws_one_the_run_would_refuse() -> void:
	# The setup screen's `_playable_paths` rule: the seed must never hand
	# a seat a deck the next line refuses. Every unplayable deck in the
	# pool is skipped, whatever the seed. (The same bad decks are still
	# OPPONENTS, and a round against one is refused in its own words —
	# that is the per-round check, not this one.)
	var bad := _write_deck("_gut_gauntlet_bad", "name: Bad\n20 Mountain\n")
	var found := {}
	for seed_value in [1, 2, 3, 4, 5, 6, 7, 8]:
		var screen := _make([bad, DECK_B, "res://decks/no_such_deck.deck"],
			1, seed_value)
		screen.options.your_deck = ""
		add_child_autofree(screen)
		await get_tree().process_frame
		assert_eq(screen.last_refusal, "", "seed %d: nothing to refuse" % seed_value)
		assert_true(screen._running, "seed %d: the run began" % seed_value)
		found[screen.config.decks[0].size()] = true
	_drop_deck(bad)
	assert_eq(found.keys(), [DeckList.load_file(DECK_B, true).cards.size()],
		"the one playable deck, every time")


func test_random_deck_with_nothing_playable_is_refused_with_entry_one() -> void:
	var bad := _write_deck("_gut_gauntlet_bad2", "name: Bad\n20 Mountain\n")
	var screen := _make([bad, "res://decks/no_such_deck.deck"])
	screen.options.your_deck = ""
	add_child_autofree(screen)
	await get_tree().process_frame
	_drop_deck(bad)
	assert_null(screen._match)
	assert_eq(screen.last_refusal, GauntletState.YOUR_DECK_ILLEGAL,
		"`Your selected deck is not a legal deck. Please select a new deck.`")


func test_your_deck_problem_answers_in_the_players_deck_strings() -> void:
	var ok := DeckList.load_file(DECK_A, true)
	assert_eq(GauntletState.your_deck_problem(DECK_A, ok), "")
	assert_eq(GauntletState.your_deck_problem("", DeckList.new()),
		GauntletState.YOUR_DECK_INVALID)
	var small := DeckList.new()
	for _i in 39:
		small.cards.append("Mountain")
	assert_eq(GauntletState.your_deck_problem("x.deck", small),
		GauntletState.YOUR_DECK_TOO_SMALL)
	var big := DeckList.new()
	for _i in DeckModel.MAX_TOTAL + 1:
		big.cards.append("Mountain")
	assert_eq(GauntletState.your_deck_problem("x.deck", big),
		GauntletState.YOUR_DECK_TOO_BIG)
	# The opponent's answers are the same three tests under the other name.
	assert_eq(GauntletState.opponent_deck_problem("x.deck", small),
		GauntletState.DECK_TOO_SMALL)


# ======================================================== &Create Deck... ==

func test_the_options_window_offers_the_startup_screens_create_deck() -> void:
	# `@DIALOG_GAUNTLETSTARTUP` entry 13 (`Program/UIStrings.txt:648` =
	# `s30/assets/text/Uistrings.txt:648`), which the original lists
	# between the deck pickers and `E&xit`.
	var options := GauntletOptions.new()
	var opened := [0]
	var dialog := options.window([DECK_A, DECK_B] as Array[String],
		func() -> void: pass, func() -> void: pass,
		func() -> void: opened[0] += 1)
	add_child_autofree(dialog)
	assert_eq(_foot_buttons(dialog), [GauntletOptions.RUN,
		GauntletOptions.CREATE_DECK, GauntletOptions.EXIT] as Array[String])
	_press(dialog, GauntletOptions.CREATE_DECK)
	assert_eq(opened[0], 1, "and it goes somewhere")


func test_create_deck_is_absent_when_there_is_nowhere_to_send_the_player() -> void:
	# A button that leads nowhere is worse than no button — §6.1's rule,
	# one step further along than greying it.
	var options := GauntletOptions.new()
	var dialog := options.window([DECK_A] as Array[String],
		func() -> void: pass, func() -> void: pass)
	add_child_autofree(dialog)
	assert_eq(_foot_buttons(dialog),
		[GauntletOptions.RUN, GauntletOptions.EXIT] as Array[String])


func test_the_scene_create_deck_opens_exists() -> void:
	# A scene path is a string: a typo in one fails at RUN time.
	assert_true(ResourceLoader.exists(GauntletScreen.DECK_BUILDER))
	assert_eq(GauntletOptions.CREATE_DECK, "Create Deck...",
		"`&Create Deck...` with the accelerator stripped, as every label here")

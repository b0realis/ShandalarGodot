extends GutTest
## §1.5 / §6.2 of docs/duel-todo.md — the OPENING HAND sequence, in the
## owner's order of 2026-09-08: the toss winner chooses play or draw, then
## looks at their hand and keeps or redraws (one card fewer each time,
## until they keep), then the other seat does the same, then the duel.
##
## Every string here is `@DIALOG_PLAYORDRAW` (Program/UIStrings.txt:487) or
## `@DIALOG_MULLIGAN` (:499). The rule itself is pinned in the engine suite
## (tests/unit/test_mulligan.gd); this pins the SEQUENCE and the WORDS.


var host: Control
var game: MtgGame


func before_each() -> void:
	host = Control.new()
	add_child_autofree(host)
	game = MtgGame.new()


func _deck(lands: int, spells: int) -> Array:
	var out: Array = []
	for i in lands:
		out.append("Forest")
	for i in spells:
		out.append("Grizzly Bears")
	return out


func _deal(deck0: Array, deck1: Array) -> void:
	game.setup(deck0, deck1, "P0", "P1", 20, 20, 424242)
	game.deal_opening_hands(7)


func test_the_strings_are_the_1997_tables_verbatim() -> void:
	# @DIALOG_PLAYORDRAW, nine entries.
	assert_eq(OpeningHand.PLAY_OR_DRAW["won"], "%s won the toss")
	assert_eq(OpeningHand.PLAY_OR_DRAW["will_play"], "and will play first.")
	assert_eq(OpeningHand.PLAY_OR_DRAW["chose_draw"],
		"and has chosen to draw first.")
	assert_eq(OpeningHand.PLAY_OR_DRAW["you_won"], "You won the coin toss.")
	assert_eq(OpeningHand.PLAY_OR_DRAW["ask"], "Would you like to:")
	assert_eq(OpeningHand.PLAY_OR_DRAW["play_first"], "Play first")
	assert_eq(OpeningHand.PLAY_OR_DRAW["draw_first"], "Draw first")
	assert_eq(OpeningHand.PLAY_OR_DRAW["they_play"], "%s will play first.")
	assert_eq(OpeningHand.PLAY_OR_DRAW["they_draw"],
		"%s has chosen to draw first.")
	# @DIALOG_MULLIGAN's announcements and its two buttons.
	assert_eq(OpeningHand.MULLIGAN["no_land"],
		"%s has no land and chose to take a mulligan")
	assert_eq(OpeningHand.MULLIGAN["all_land"],
		"%s has all land and will take a mulligan")
	assert_eq(OpeningHand.MULLIGAN["also"], "%s will also take a mulligan")
	assert_eq(OpeningHand.MULLIGAN["also_declined"],
		"%s decided not to take a mulligan")
	assert_eq(OpeningHand.MULLIGAN["declined"], "%s did not take a mulligan")


func test_each_kind_of_hand_gets_its_own_announcement() -> void:
	_deal(_deck(30, 0), _deck(0, 30))
	assert_eq(OpeningHand.announcement(game, 0, true, false),
		"P0 has all land and will take a mulligan")
	assert_eq(OpeningHand.announcement(game, 1, true, false),
		"P1 has no land and chose to take a mulligan")
	assert_eq(OpeningHand.announcement(game, 0, false, false),
		"P0 did not take a mulligan")
	# The second offer — the one that exists because the opponent redrew —
	# has its own pair of strings in the table.
	assert_eq(OpeningHand.announcement(game, 1, true, true),
		"P1 will also take a mulligan")
	assert_eq(OpeningHand.announcement(game, 1, false, true),
		"P1 decided not to take a mulligan")


func test_a_redraw_says_how_many_it_deals() -> void:
	# `[QoL]` — the 1997 table has no count because its redraw was always
	# seven; ours is one fewer each time, and the line says so.
	_deal(_deck(30, 0), _deck(0, 30))
	assert_eq(OpeningHand.MULLIGAN_COUNT, ", drawing %d")
	assert_eq(OpeningHand.announcement(game, 0, true, false, 6),
		"P0 has all land and will take a mulligan, drawing 6")
	assert_eq(OpeningHand.announcement(game, 1, true, true, 5),
		"P1 will also take a mulligan, drawing 5")
	assert_eq(OpeningHand.announcement(game, 0, false, false, 6),
		"P0 did not take a mulligan", "a keep deals nothing")


func test_the_toss_winners_decision_is_reported_in_the_tables_words() -> void:
	_deal(_deck(15, 15), _deck(15, 15))
	assert_eq(OpeningHand.play_or_draw_line(game, 1, true), "P1 will play first.")
	assert_eq(OpeningHand.play_or_draw_line(game, 1, false),
		"P1 has chosen to draw first.")


func _run_headless(winner: int) -> Array[String]:
	var opening := OpeningHand.new()
	host.add_child(opening)
	var lines: Array[String] = []
	opening.announced.connect(func(line: String) -> void: lines.append(line))
	# Neither seat is human: every offer is answered by its DecisionAgent
	# and no dialog is drawn, which is the whole sequence with no waiting.
	await opening.run(game, winner, func(_pid: int) -> bool: return false)
	return lines


func test_the_sequence_runs_and_starts_the_duel() -> void:
	_deal(_deck(30, 0), _deck(15, 15))
	var lines := await _run_headless(1)
	assert_eq(game.turn_number, 1, "the duel began")
	assert_eq(game.active_player, 1, "the toss winner took the play")
	assert_false(game.may_mulligan(0), "and the opening hand is settled")
	assert_false(game.may_mulligan(1))
	assert_true(lines.has("P1 will play first."))
	# The plain agent throws an all-land hand back until its floor: seven
	# Forests, six, five — and keeps four.
	assert_true(lines.has("P0 has all land and will take a mulligan, drawing 6"),
		"the heuristic agent redrew its all-land hand: %s" % str(lines))
	assert_true(lines.has("P0 has all land and will take a mulligan, drawing 4"))
	assert_false(lines.has("P0 has all land and will take a mulligan, drawing 3"))
	assert_eq(game.players[0].hand.size(), DecisionAgent.MULLIGAN_FLOOR)
	assert_eq(game.mulligans_taken, [3, 0])


func test_the_toss_winner_decides_first_and_the_other_seat_follows() -> void:
	_deal(_deck(30, 0), _deck(15, 15))
	var lines := await _run_headless(1)
	# P1 won and is asked first — before P0's redraws, so its line is the
	# plain one; P0's keep comes after P1's, and is the last line.
	assert_eq(lines[0], "P1 will play first.")
	assert_eq(lines[1], "P1 did not take a mulligan")
	assert_eq(lines[-1], "P0 did not take a mulligan")


func test_the_other_seat_gets_the_courtesy_words_after_a_redraw() -> void:
	_deal(_deck(30, 0), _deck(15, 15))
	var lines := await _run_headless(0)
	# P0 redrew, so P1's decision is told in the table's second pair — and
	# the default agent keeps a perfectly good hand.
	assert_true(lines.has("P1 decided not to take a mulligan"), str(lines))
	assert_false(lines.has("P1 did not take a mulligan"))


func test_both_seats_are_asked_even_with_ordinary_hands() -> void:
	# Any hand may go back now, so every seat is asked and every keep is
	# announced: the order line and the two keeps, nothing else.
	_deal(_deck(15, 15), _deck(15, 15))
	var lines := await _run_headless(0)
	assert_eq(lines, ["P0 will play first.", "P0 did not take a mulligan",
		"P1 did not take a mulligan"] as Array[String])
	assert_eq(game.turn_number, 1)


# ============================================================================
# THE OPENING WINDOW (§6.19) — one panel, on the classical line-art ground,
# carrying who leads, the opponent's mulligan status, BOTH ANTES as full
# cards, and the window's own two buttons.
# ============================================================================

func _staked() -> void:
	_deal(_deck(15, 15), _deck(15, 15))
	game.stake_ante(0)
	game.stake_ante(1)


func test_the_window_wears_the_1997_start_of_duel_ground() -> void:
	# `Winbk_Startduel.pic`, imported as `versus_background` — the same
	# picture the battle-setup screen already stands on. Measured 659x394
	# with a 3px baked bevel, hence a patch margin of 4.
	assert_true(OriginalDialog.PANELS.has("versus_background"),
		"the start-of-duel ground is a dialog ground like any other")
	assert_eq(OriginalDialog.PANELS["versus_background"]["margin"], 4)
	assert_false(OriginalDialog.PANELS["versus_background"]["tile"],
		"a picture is stretched, never tiled")
	assert_eq(OpeningWindow.GROUND, Vector2(659, 394),
		"the ground's measured native size")


func test_the_window_holds_two_full_size_cards_at_both_resolutions() -> void:
	# THE ONE-CARD-SIZE RULE (design doc, fortieth pass): the two antes are
	# CardPreviews at their own SIZE and the panel is built around them —
	# never the other way round. 977x584 fits inside 1280x800 and 1280x720.
	assert_eq(OpeningWindow.SIZE, Vector2(977, 584))
	assert_lt(OpeningWindow.SIZE.x, 1280.0, "fits the project's width")
	assert_lt(OpeningWindow.SIZE.y, 720.0,
		"and the shorter of the two supported heights, with 136px to spare")
	# The two cards, their gap and the panel's own margins really do fit.
	var needed := CardPreview.SIZE.x * 2.0 + OpeningWindow.CARD_GAP \
		+ OpeningWindow.COLUMN_MARGIN * 2.0
	assert_lt(needed, OpeningWindow.SIZE.x,
		"two enlarged cards side by side, unscaled")
	# And the panel keeps the picture's own aspect, so the line-art figures
	# scale uniformly instead of being stretched into a different shape.
	assert_almost_eq(OpeningWindow.SIZE.x / OpeningWindow.SIZE.y,
		OpeningWindow.GROUND.x / OpeningWindow.GROUND.y, 0.01)


func test_the_ante_captions_are_the_1997_tables_own_two() -> void:
	# `@DIALOG_MULLIGAN` entries 3-4, which are the same pair
	# `@DIALOG_VIEWANTES` (UIStrings.txt:588) gives `View both antes`.
	assert_eq(OpeningHand.MULLIGAN["your_ante"], "Your ante:")
	assert_eq(OpeningHand.MULLIGAN["their_ante"], "%s ante:")
	assert_eq(OpeningHand.MULLIGAN["take"], "Take mulligan")
	assert_eq(OpeningHand.MULLIGAN["start"], "Start the duel")


func test_the_window_shows_both_antes_from_the_viewers_seat() -> void:
	_staked()
	var window := OpeningWindow.new()
	host.add_child(window)
	await get_tree().process_frame
	window.show_antes(game, 0)
	assert_eq(window.caption_texts(),
		PackedStringArray(["Your ante:", "P1 ante:"]),
		"your stake first, theirs by name")
	assert_eq(window.card_names(),
		PackedStringArray([game.players[0].ante[0].data.card_name,
			game.players[1].ante[0].data.card_name]))
	# Turn it round (a hotseat asks the other seat next).
	window.show_antes(game, 1)
	assert_eq(window.caption_texts(),
		PackedStringArray(["Your ante:", "P0 ante:"]))
	# CardPreview un-parents its cost row before queueing it (its own
	# header explains why); let that queue drain before GUT counts orphans.
	await get_tree().process_frame


func test_a_duel_not_played_for_ante_shows_card_backs() -> void:
	_deal(_deck(15, 15), _deck(15, 15))
	var window := OpeningWindow.new()
	host.add_child(window)
	await get_tree().process_frame
	window.show_antes(game, 0)
	assert_eq(window.caption_texts(), PackedStringArray(["", ""]),
		"no stake, no caption")


func test_the_lead_line_is_the_tables_entries_one_and_two() -> void:
	_deal(_deck(15, 15), _deck(15, 15))
	assert_eq(OpeningHand.lead_line(game, 0, 0), "You will take the first turn")
	assert_eq(OpeningHand.lead_line(game, 1, 0), "P1 will start first")


func test_the_window_sits_at_the_top_with_the_hand_clear_below() -> void:
	# The owner, 2026-09-08: *"the winning player must see his hand (so
	# first hand stack should be seen besides starting window!)"*. A
	# centred 584 covered the fan hand at the foot of a 1280x800 screen;
	# at the top, TOP_MARGIN down, it leaves the fan (from ~690) whole.
	host.size = Vector2(1280, 800)
	var window := OpeningWindow.new()
	host.add_child(window)
	await get_tree().process_frame
	var rect := window.panel_rect()
	assert_eq(OpeningWindow.TOP_MARGIN, 8.0)
	assert_eq(rect.position.y, OpeningWindow.TOP_MARGIN, "hung from the top edge")
	assert_almost_eq(rect.position.x, (1280.0 - OpeningWindow.SIZE.x) / 2.0, 1.0,
		"centred across")
	assert_eq(rect.size, OpeningWindow.SIZE)
	assert_lt(rect.end.y, 690.0, "the fan hand's row is clear of it")
	assert_gt(rect.position.x, 150.0, "and so is the sidebar's showcase")


func _opening_with_player(winner: int) -> OpeningHand:
	var opening := OpeningHand.new()
	host.add_child(opening)
	# Seat 0 is the player; seat 1 answers through its DecisionAgent.
	opening.run(game, winner, func(pid: int) -> bool: return pid == 0)
	await get_tree().process_frame
	await get_tree().process_frame
	return opening


func _press(window: OpeningWindow, label: String) -> void:
	assert_true(window.press(label), "no such button up: %s" % label)
	await get_tree().process_frame
	await get_tree().process_frame


func test_the_order_is_asked_first_and_the_hand_second() -> void:
	# The owner's order of events, whole: `Draw first` / `Play first`
	# alone in the first row; then, over the hand, `Take mulligan` /
	# `Start the duel`; and the duel on the keep.
	_staked()
	var opening: OpeningHand = await _opening_with_player(0)
	var window := opening.window()
	assert_not_null(window, "one window, opened after the toss")
	assert_eq(window.lead_text(), "You won the coin toss.\nWould you like to:")
	assert_eq(window.button_labels(),
		PackedStringArray(["Draw first", "Play first"]),
		"the order, and nothing else, in the first row")
	assert_eq(window.card_names().size(), 2, "with both antes already up")
	await _press(window, "Play first")
	assert_eq(window.lead_text(), "You will take the first turn")
	assert_eq(window.button_labels(),
		PackedStringArray(["Take mulligan", "Start the duel"]),
		"then the hand: keep it or throw it back")
	assert_eq(game.turn_number, 0, "the duel waits on the hand")
	assert_true(game.may_mulligan(0), "any hand may go back")
	await _press(window, "Start the duel")
	assert_false(game.may_mulligan(0), "kept")
	# Seat 1's plain agent keeps its ordinary hand, which is not news: no
	# status line, no last look, the duel begins on the player's own press.
	assert_eq(window.status_text(), "")
	assert_eq(game.turn_number, 1, "and the duel began")
	assert_eq(game.active_player, 0)


func test_draw_first_gives_the_turn_away() -> void:
	_deal(_deck(15, 15), _deck(15, 15))
	var opening: OpeningHand = await _opening_with_player(0)
	var window := opening.window()
	await _press(window, "Draw first")
	assert_eq(window.lead_text(), "P1 will start first")
	assert_eq(window.button_labels(),
		PackedStringArray(["Take mulligan", "Start the duel"]),
		"the hand is still the winner's to judge, whoever leads")
	await _press(window, "Start the duel")
	assert_eq(game.turn_number, 1)
	assert_eq(game.active_player, 1, "drawing first gives the turn away")


func test_take_mulligan_deals_one_fewer_and_asks_again() -> void:
	# *"After each mulligan you draw one card less"* — and the row comes
	# straight back over the smaller hand, as often as the player likes.
	_deal(_deck(0, 30), _deck(15, 15))    # seat 0 draws no land at all
	var opening: OpeningHand = await _opening_with_player(0)
	var window := opening.window()
	var lines: Array[String] = []
	opening.announced.connect(func(line: String) -> void: lines.append(line))
	await _press(window, "Play first")
	await _press(window, "Take mulligan")
	assert_eq(game.players[0].hand.size(), 6, "seven back, six out")
	assert_eq(window.button_labels(),
		PackedStringArray(["Take mulligan", "Start the duel"]),
		"a new hand and the same question — the duel has NOT started")
	assert_eq(game.turn_number, 0)
	assert_true(lines.has("P0 has no land and chose to take a mulligan, drawing 6"),
		"named by the hand thrown away, with the count: %s" % str(lines))
	await _press(window, "Take mulligan")
	assert_eq(game.players[0].hand.size(), 5)
	assert_eq(window.button_labels(),
		PackedStringArray(["Take mulligan", "Start the duel"]))
	await _press(window, "Start the duel")
	assert_eq(game.mulligans_taken[0], 2)
	assert_eq(game.turn_number, 1)
	assert_eq(game.players[0].hand.size(), 5, "and plays on with five")


func test_seven_mulligans_run_the_hand_out_and_the_question_with_it() -> void:
	_deal(_deck(0, 30), _deck(15, 15))
	var opening: OpeningHand = await _opening_with_player(0)
	var window := opening.window()
	await _press(window, "Play first")
	for expected in [6, 5, 4, 3, 2, 1, 0]:
		await _press(window, "Take mulligan")
		assert_eq(game.players[0].hand.size(), expected)
	# Nothing is left to throw back, so the question is not asked again;
	# seat 1 keeps, and the window owes the player nothing more.
	assert_false(game.may_mulligan(0), "an empty hand is not offered a mulligan")
	assert_eq(game.mulligans_taken[0], 7)
	assert_eq(game.turn_number, 1)
	assert_eq(game.players[0].hand.size(), 0)


func test_the_opponents_mulligan_lands_in_the_head_band_and_costs_a_look() -> void:
	# The owner's 1997 screenshot: `Cromer has no land and chose to take a
	# mulligan` on the right, the two buttons below. The opponent decides
	# AFTER the player's keep here, so the window holds for one more
	# `Start the duel` — the player must be able to read it.
	_deal(_deck(15, 15), _deck(0, 30))   # seat 1 draws no land at all
	game.stake_ante(0)
	game.stake_ante(1)
	var opening: OpeningHand = await _opening_with_player(0)
	var window := opening.window()
	await _press(window, "Play first")
	await _press(window, "Start the duel")
	# The plain agent threw back seven, six and five of no land and kept
	# four: the band shows the LAST redraw, with its count.
	assert_eq(window.status_text(),
		"P1 has no land and chose to take a mulligan, drawing 4",
		"named by the hand they threw away, not the one they drew")
	assert_eq(window.button_labels(), PackedStringArray(["Start the duel"]),
		"the last look")
	assert_eq(game.turn_number, 0, "the duel waits on it")
	await _press(window, "Start the duel")
	assert_eq(game.turn_number, 1)
	assert_eq(game.players[1].hand.size(), 4)


func test_an_opponent_who_keeps_after_the_press_costs_no_click() -> void:
	# "One decision, one click" (the 2026-09-06 playtest): a keep is not
	# news, so it neither lands in the band nor holds the window.
	_deal(_deck(15, 15), _deck(15, 15))
	game.stake_ante(0)
	game.stake_ante(1)
	var opening: OpeningHand = await _opening_with_player(0)
	var window := opening.window()
	await _press(window, "Play first")
	await _press(window, "Start the duel")
	assert_eq(window.status_text(), "")
	assert_eq(game.turn_number, 1, "the duel started on that click")


func test_losing_the_toss_asks_only_about_the_hand() -> void:
	# A seat that did not win the toss is never asked the order: the AI
	# winner takes the play and judges its own hand first, then the
	# player's one row is the hand's — over the antes, as the 1997 window.
	_deal(_deck(15, 15), _deck(15, 15))
	game.stake_ante(0)
	game.stake_ante(1)
	var opening: OpeningHand = await _opening_with_player(1)
	var window := opening.window()
	assert_eq(window.lead_text(), "P1 will start first")
	assert_eq(window.button_labels(),
		PackedStringArray(["Take mulligan", "Start the duel"]))
	assert_false(game.may_mulligan(1), "the AI has already kept")
	await _press(window, "Start the duel")
	assert_eq(game.turn_number, 1)
	assert_eq(game.active_player, 1)


func test_the_ai_winners_redraw_is_up_before_the_player_decides() -> void:
	# When the AI wins and throws its hand back, the band already says so
	# by the time the player is asked — and their press is the last word.
	_deal(_deck(15, 15), _deck(0, 30))
	var opening: OpeningHand = await _opening_with_player(1)
	var window := opening.window()
	assert_eq(window.status_text(),
		"P1 has no land and chose to take a mulligan, drawing 4")
	assert_eq(window.button_labels(),
		PackedStringArray(["Take mulligan", "Start the duel"]))
	await _press(window, "Start the duel")
	assert_eq(game.turn_number, 1, "no second look: nothing happened after the press")


func test_a_hotseat_turns_the_window_round_for_the_second_seat() -> void:
	_staked()
	var opening := OpeningHand.new()
	host.add_child(opening)
	opening.run(game, 0, func(_pid: int) -> bool: return true)   # both human
	await get_tree().process_frame
	await get_tree().process_frame
	var window := opening.window()
	assert_eq(window.caption_texts(), PackedStringArray(["Your ante:", "P1 ante:"]))
	await _press(window, "Play first")
	await _press(window, "Start the duel")
	# Seat 1's turn to look: the window says `Your` to them now.
	assert_eq(window.caption_texts(), PackedStringArray(["Your ante:", "P0 ante:"]))
	assert_eq(window.lead_text(), "P0 will start first")
	assert_eq(window.button_labels(),
		PackedStringArray(["Take mulligan", "Start the duel"]))
	assert_eq(game.turn_number, 0)
	await _press(window, "Take mulligan")
	assert_eq(game.players[1].hand.size(), 6)
	await _press(window, "Start the duel")
	assert_eq(game.turn_number, 1, "the second seat's press is the last word")
	assert_eq(game.active_player, 0)
	await get_tree().process_frame


# ------------------------------------------------ the hand over the window --

func test_the_duel_screen_lifts_the_stack_over_the_window_for_the_opening() -> void:
	# The duel screen's half of "the hand stack should be seen besides
	# starting window": the stack-style hand window (z 60, under an
	# OriginalDialog's 200) is lifted over it while the opening runs and
	# put back after.
	var had := Settings.has_value("hand_style")
	var prior: String = Settings.hand_style()
	Settings.set_value("hand_style", "stack")
	var screen: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	if had:
		Settings.set_value("hand_style", prior)
	else:
		Settings.clear_value("hand_style")
	var stack: Control = screen._hand_rows[1]
	assert_true(stack is StackHand)
	assert_eq(stack.z_index, 60, "the ordinary height")
	assert_gt(DuelScreen.OPENING_HAND_Z, 200, "over an OriginalDialog")
	# Headless, the screen skipped the toss and began the duel; reopen the
	# hands so the window has a question to ask.
	screen.game.mulligan_open = true
	screen.game.mulligan_kept = [false, true]   # the AI seat has kept
	screen._run_opening_hand(0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(stack.z_index, DuelScreen.OPENING_HAND_Z, "lifted while the window is up")
	var window: OpeningWindow = screen.find_child("OpeningWindow", true, false)
	assert_not_null(window)
	await _press(window, "Play first")
	await _press(window, "Start the duel")
	# The window fades for 0.2s before the run returns — wall-clock time,
	# which headless frames outrun.
	await get_tree().create_timer(0.5).timeout
	assert_eq(stack.z_index, 60, "and put back when it is over")

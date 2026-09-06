extends GutTest
## §1.5 / §6.2 of docs/duel-todo.md — the OPENING HAND sequence: the toss
## winner chooses play or draw, then the Shandalar mulligan is offered.
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


func test_the_toss_winners_decision_is_reported_in_the_tables_words() -> void:
	_deal(_deck(15, 15), _deck(15, 15))
	assert_eq(OpeningHand.play_or_draw_line(game, 1, true), "P1 will play first.")
	assert_eq(OpeningHand.play_or_draw_line(game, 1, false),
		"P1 has chosen to draw first.")


func test_the_sequence_runs_and_starts_the_duel() -> void:
	_deal(_deck(30, 0), _deck(15, 15))
	var opening := OpeningHand.new()
	host.add_child(opening)
	var lines: Array[String] = []
	opening.announced.connect(func(line: String) -> void: lines.append(line))
	# Neither seat is human: every offer is answered by its DecisionAgent
	# and no dialog is drawn, which is the whole sequence with no waiting.
	await opening.run(game, 1, func(_pid: int) -> bool: return false)
	assert_eq(game.turn_number, 1, "the duel began")
	assert_eq(game.active_player, 1, "the toss winner took the play")
	assert_false(game.may_mulligan(0), "and the opening hand is settled")
	assert_false(game.may_mulligan(1))
	assert_true(lines.has("P1 will play first."))
	assert_true(lines.has("P0 has all land and will take a mulligan"),
		"the heuristic agent redrew its all-land hand: %s" % str(lines))


func test_the_opponent_gets_the_courtesy_offer_after_a_redraw() -> void:
	_deal(_deck(30, 0), _deck(15, 15))
	var opening := OpeningHand.new()
	host.add_child(opening)
	var lines: Array[String] = []
	opening.announced.connect(func(line: String) -> void: lines.append(line))
	await opening.run(game, 0, func(_pid: int) -> bool: return false)
	# P0 redrew, so P1 was offered one too — and the default agent keeps a
	# perfectly good hand.
	assert_true(lines.has("P1 decided not to take a mulligan"), str(lines))


func test_nobody_is_offered_anything_when_both_hands_are_ordinary() -> void:
	_deal(_deck(15, 15), _deck(15, 15))
	var opening := OpeningHand.new()
	host.add_child(opening)
	var lines: Array[String] = []
	opening.announced.connect(func(line: String) -> void: lines.append(line))
	await opening.run(game, 0, func(_pid: int) -> bool: return false)
	assert_eq(lines.size(), 1, "only the play-or-draw line: %s" % str(lines))
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


func test_the_whole_opening_happens_in_that_one_window() -> void:
	_staked()
	var opening := OpeningHand.new()
	host.add_child(opening)
	# Seat 0 is the player; seat 1 answers through its DecisionAgent.
	opening.run(game, 0, func(pid: int) -> bool: return pid == 0)
	await get_tree().process_frame
	await get_tree().process_frame
	var window := opening.window()
	assert_not_null(window, "one window, opened after the toss")
	# ONE ROW for the toss winner (the owner's correction, 2026-09-03):
	# the order and the redraw are the same decision about the same seven
	# cards. Neither hand qualifies here, so no `Take mulligan` — the row
	# offers it only while the rule allows one.
	assert_eq(window.button_labels(),
		PackedStringArray(["Draw first", "Play first"]))
	assert_eq(window.card_names().size(), 2, "with both antes already up")
	assert_true(window.press("Play first"))
	await get_tree().process_frame
	await get_tree().process_frame
	# Neither hand qualifies and nothing has happened since the press, so
	# that press was the last word and the duel begins on it. This used to
	# assert a second `Start the duel` row here; it was the 2026-09-06
	# defect, and the tests below this file's `one decision, one click`
	# banner carry the reasoning.
	assert_eq(window.lead_text(), "You will take the first turn")
	assert_eq(game.turn_number, 1, "and the duel began")
	assert_eq(game.active_player, 0)


func test_the_opponents_mulligan_lands_in_the_head_band() -> void:
	# The owner's 1997 screenshot: `Cromer has no land and chose to take a
	# mulligan` on the right, `Take mulligan` / `Start the duel` below.
	_deal(_deck(15, 15), _deck(0, 30))   # seat 1 draws no land at all
	game.stake_ante(0)
	game.stake_ante(1)
	var opening := OpeningHand.new()
	host.add_child(opening)
	opening.run(game, 0, func(pid: int) -> bool: return pid == 0)
	await get_tree().process_frame
	await get_tree().process_frame
	var window := opening.window()
	assert_true(window.press("Play first"))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(window.status_text(),
		"P1 has no land and chose to take a mulligan",
		"named by the hand they threw away, not the one they drew")
	assert_eq(window.button_labels(),
		PackedStringArray(["Take mulligan", "Start the duel"]),
		"and the courtesy offer is ours to take")
	assert_true(window.press("Start the duel"))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(game.turn_number, 1)


func test_the_toss_winner_is_asked_the_order_and_the_redraw_together() -> void:
	# The owner's 2026-09-03 correction, in full: win the toss with a hand
	# the rule lets you throw back, and the window's ONE row is
	# `Take mulligan`, `Draw first`, `Play first`.
	_deal(_deck(0, 30), _deck(15, 15))    # seat 0 draws no land at all
	game.stake_ante(0)
	game.stake_ante(1)
	var opening := OpeningHand.new()
	host.add_child(opening)
	opening.run(game, 0, func(pid: int) -> bool: return pid == 0)
	await get_tree().process_frame
	await get_tree().process_frame
	var window := opening.window()
	assert_eq(window.button_labels(), PackedStringArray(
		["Take mulligan", "Draw first", "Play first"]))
	# Redrawing does not answer the order, so the row comes back — without
	# the mulligan, which is spent.
	assert_true(window.press("Take mulligan"))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(window.button_labels(),
		PackedStringArray(["Draw first", "Play first"]))
	assert_true(window.press("Draw first"))
	await get_tree().process_frame
	await get_tree().process_frame
	# Seat 1 now gets the courtesy offer (its opponent redrew) and answers
	# through its own agent; the window then waits on the player's last
	# word, which is what the original's window closes on.
	assert_eq(window.button_labels(), PackedStringArray(["Start the duel"]))
	assert_true(window.press("Start the duel"))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(game.active_player, 1, "drawing first gives the turn away")


func test_choosing_the_order_also_waives_the_redraw() -> void:
	# Pressing `Play first` on a hand you were allowed to throw back is
	# the decline: one chance, used or waived (Duel.hlp, Mulligan).
	_deal(_deck(0, 30), _deck(15, 15))
	game.stake_ante(0)
	game.stake_ante(1)
	var opening := OpeningHand.new()
	host.add_child(opening)
	opening.run(game, 0, func(pid: int) -> bool: return pid == 0)
	await get_tree().process_frame
	await get_tree().process_frame
	var window := opening.window()
	assert_true(window.press("Play first"))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(game.may_mulligan(0), "the chance is spent")
	assert_eq(game.active_player, 0)


# ------------------------------------------- one decision, one click (§6.19) --
#
# THE DEFECT (playtest, 2026-09-06): *"In the duel, if you win the coin toss
# you get a choice of draw first or play first. If you click either button
# the duel should start — now you have to click an additional 'start duel'
# button, but you already decided in the previous button."*
#
# `OpeningHand.run`'s rule was right and its bookkeeping was not. The window
# owes the player a LAST LOOK — one more `Start the duel` whenever something
# happened after their last press, because the opponent's redraw lands in the
# head band and they must be able to read it. That is what `pressed_serial`
# is for. But `_ask_lead_and_mulligan` never wrote to it, so choosing the
# order left the counter at its "never pressed anything" -1 and the window
# always found itself owing a look nobody was owed.
#
# So the fix is not to drop the second row: it is to count the order button
# as the press it is. Both tests below are the same window; only what the
# opponent does between them differs.

func _straight_opening(winner: int) -> OpeningHand:
	var opening := OpeningHand.new()
	host.add_child(opening)
	opening.run(game, winner, func(pid: int) -> bool: return pid == 0)
	await get_tree().process_frame
	await get_tree().process_frame
	return opening


func test_choosing_the_order_starts_the_duel_with_no_second_click() -> void:
	# Nothing happens after the press — neither hand may be thrown back —
	# so `Play first` IS the last word and the duel begins on it.
	_deal(_deck(15, 15), _deck(15, 15))
	game.stake_ante(0)
	game.stake_ante(1)
	var opening: OpeningHand = await _straight_opening(0)
	var window := opening.window()
	assert_eq(window.button_labels(),
		PackedStringArray(["Draw first", "Play first"]))
	assert_true(window.press("Play first"))
	await get_tree().process_frame
	await get_tree().process_frame
	# The window never puts a second row up — it closes. (`ask` replaces
	# the row it is asked for; with nothing more to ask, the buttons the
	# player just answered are simply the last ones the window ever had.)
	assert_false(window.button_labels().has("Start the duel"),
		"no second row: the decision was made in the previous button")
	assert_eq(game.turn_number, 1, "the duel started on that one click")
	assert_eq(game.active_player, 0)


func test_draw_first_starts_the_duel_on_its_own_click_too() -> void:
	# The other half of the same row, and the seat it hands the turn to.
	_deal(_deck(15, 15), _deck(15, 15))
	var opening: OpeningHand = await _straight_opening(0)
	var window := opening.window()
	assert_true(window.press("Draw first"))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(window.button_labels().has("Start the duel"))
	assert_eq(game.turn_number, 1)
	assert_eq(game.active_player, 1, "drawing first gives the turn away")


func test_take_mulligan_still_deals_again_and_asks_again() -> void:
	# THE ASYMMETRY THAT MUST SURVIVE. `Take mulligan` is not a decision
	# about the order, so it deals a new hand and comes straight back with
	# the row — minus the redraw, which is spent (`Duel.hlp`, **Mulligan**:
	# one chance, used or waived).
	_deal(_deck(0, 30), _deck(15, 15))    # seat 0 draws no land at all
	var opening: OpeningHand = await _straight_opening(0)
	var window := opening.window()
	assert_eq(window.button_labels(), PackedStringArray(
		["Take mulligan", "Draw first", "Play first"]))
	assert_true(window.press("Take mulligan"))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(window.button_labels(),
		PackedStringArray(["Draw first", "Play first"]),
		"a new hand and the same question — the duel has NOT started")
	assert_eq(game.turn_number, 0, "and no turn has begun")


func test_the_last_look_survives_an_opponent_who_acts_after_the_press() -> void:
	# The rule `pressed_serial` exists for, and the one this fix must not
	# break: the opponent redrew AFTER `Play first`, the head band says so,
	# and the window holds for one `Start the duel` so the player reads it.
	_deal(_deck(15, 15), _deck(0, 30))    # seat 1 draws no land at all
	var opening: OpeningHand = await _straight_opening(0)
	var window := opening.window()
	assert_true(window.press("Play first"))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(window.status_text(),
		"P1 has no land and chose to take a mulligan")
	assert_eq(window.button_labels(),
		PackedStringArray(["Take mulligan", "Start the duel"]),
		"the courtesy offer, which is a question and not a repeat")
	assert_eq(game.turn_number, 0, "the duel waits on it")
	assert_true(window.press("Start the duel"))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(game.turn_number, 1)


func test_losing_the_toss_still_ends_on_start_the_duel() -> void:
	# The other asymmetry, unchanged: a seat that did not win the toss is
	# never asked the order, so its one press is `Start the duel` — the
	# button the 1997 window closes on, and the reason the antes are up.
	_deal(_deck(15, 15), _deck(15, 15))
	game.stake_ante(0)
	game.stake_ante(1)
	var opening: OpeningHand = await _straight_opening(1)
	var window := opening.window()
	assert_eq(window.button_labels(), PackedStringArray(["Start the duel"]))
	assert_eq(window.lead_text(), "P1 will start first")
	assert_true(window.press("Start the duel"))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(game.turn_number, 1)
	assert_eq(game.active_player, 1)

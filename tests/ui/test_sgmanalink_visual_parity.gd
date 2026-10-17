extends GameTest
## The online adapter preserves the shared table's appearance and presentation timing.

class ResultTable extends SgDuelView:
	var life_before_result: Array = []
	func _on_game_over(winner_id: int) -> void:
		life_before_result = _last_life.duplicate()
		super._on_game_over(winner_id)

var referee: SgPracticeMatch
var player_names := ["Azure Fox", "Amber Owl"]

func before_each() -> void:
	super.before_each()
	player_names = ["Azure Fox", "Amber Owl"]
	referee = SgPracticeMatch.new(42)
	referee.game = g

func _room(seat := 0) -> Dictionary:
	return {"id":"r1", "name":"Visual parity", "seat":seat,
		"names":player_names.duplicate(), "revision":1, "ready":[true,true],
		"connected":[true,true], "game":referee.view(seat),
		"deck_names":referee.deck_names.duplicate(), "deck":{}}

func _screen(seat := 0) -> ResultTable:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	var screen := ResultTable.new()
	screen.stops.from_masks(PackedInt32Array([255,255,255,255]))
	viewport.add_child(screen)
	screen.present(_room(seat), true, false)
	return screen

func test_online_uses_the_registered_decks_public_colors_for_either_seat() -> void:
	referee = SgPracticeMatch.new(42, [
		{"name":"Knights", "cards":Array(StarterDecks.WHITE_KNIGHTS), "sideboard":[]},
		{"name":"Raiders", "cards":Array(StarterDecks.BLACK_RED_RAIDERS), "sideboard":[]}])
	referee.game.start_duel(0)
	var expected := [DuelConfig.dominant_color(Array(StarterDecks.WHITE_KNIGHTS)),
		DuelConfig.dominant_color(Array(StarterDecks.BLACK_RED_RAIDERS))]
	for seat in 2:
		var screen := _screen(seat)
		assert_eq(Array(screen.config.panel_colors), [expected[seat], expected[1 - seat]])
		assert_eq(screen.config.decks[1], [], "cosmetic metadata must not include the opposing deck")

func test_command_waits_preserve_combat_instructions() -> void:
	var attacker := put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Gray Ogre")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	var screen := _screen(1)
	var prompt: String = screen._prompt_label.text
	assert_string_contains(prompt, "Choose blockers")
	screen.present(_room(1), true, true)
	assert_eq(screen._prompt_label.text, prompt, "an ordinary acknowledgement wait must not replace a phase instruction")
	assert_true(screen._pass_button.disabled)
	assert_eq(screen._network_badge.text, "Sending…")
	screen.present(_room(1), false, false)
	assert_eq(screen._prompt_label.text, prompt)
	assert_eq(screen._network_badge.text, "Reconnect")

func test_opponent_disconnect_preserves_prompt_and_names_waiting_player() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var screen := _screen()
	var prompt: String = screen._prompt_label.text
	var room := _room()
	room.connected[1] = false
	screen.present(room, true, false)
	assert_eq(screen._prompt_label.text, prompt)
	assert_eq(screen._network_badge.text, "Suspended")
	assert_string_contains(screen._network_badge.tooltip_text, "Amber Owl")

func test_result_runs_before_refresh_overwrites_the_previous_life_total() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var screen := _screen()
	var previous := g.players[1].life
	g.adjust_life(1, -22)
	assert_true(g.game_over)
	screen.present(_room(), true, false)
	assert_eq(screen.life_before_result[1], previous, "the local countdown needs the last painted life, not the final total")
	assert_true(screen._result_seen)
	screen.present(_room(), true, false)
	assert_eq(screen.life_before_result[1], previous, "a duplicate snapshot must not restart the result")

func test_opening_buttons_survive_snapshot_and_busy_updates() -> void:
	referee = SgPracticeMatch.new(42)
	var screen := _screen()
	screen._intro_overlay.go_pressed.emit()
	var opening := screen._network_opening
	assert_not_null(opening)
	var first: Button = opening._buttons[0]
	var second: Button = opening._buttons[1]
	screen.present(_room(), true, true)
	assert_same(opening._buttons[0], first)
	assert_same(opening._buttons[1], second)
	assert_true(first.disabled and second.disabled)
	screen.present(_room(), true, false)
	assert_same(opening._buttons[0], first)
	assert_same(opening._buttons[1], second)


func test_online_introduction_precedes_the_opening_decision() -> void:
	referee = SgPracticeMatch.new(42)
	var screen := _screen()
	assert_not_null(screen._intro_overlay, "online match information must precede play/draw and mulligans")
	assert_null(screen._network_opening, "opening decisions wait until the introduction is acknowledged")
	assert_true(screen._toss_active)
	assert_eq(screen._audio.recent.count("sfx_shuffle"), 1, "a new online duel keeps the local shuffle cue")
	var intro := screen._intro_overlay
	assert_true(screen._modal_open())
	assert_null(intro._hand, "reviewing public match information does not reveal the opening hand")
	for row in screen._hand_rows: assert_false(row.visible)
	var text := ""
	for label in intro.find_children("*", "Label", true, false): text += label.text + "\n"
	for expected in ["Azure Fox", "Amber Owl", "SGManalink", "Unrated", "Unrestricted", "Mana burn: On"]:
		assert_string_contains(text, expected)
	watch_signals(screen)
	screen._on_done()
	screen._opening_answer(0)
	assert_signal_not_emitted(screen, "action_requested")
	screen.present(_room(), false, false)
	assert_same(screen._intro_overlay, intro, "a disconnect does not rebuild the introduction")
	screen.present(_room(), true, false)
	intro.go_pressed.emit()
	assert_null(screen._intro_overlay)
	assert_not_null(screen._network_opening)
	screen.present(_room(), true, false)
	assert_null(screen._intro_overlay, "snapshots never replay a read introduction")
	assert_eq(screen._audio.recent.count("sfx_shuffle"), 1, "reconnecting must not replay opening audio")


func test_online_opening_has_no_fake_ante_cards() -> void:
	referee = SgPracticeMatch.new(42)
	var screen := _screen()
	screen._intro_overlay.go_pressed.emit()
	var opening := screen._network_opening
	assert_not_null(opening)
	for card in opening._cards:
		assert_false(card.is_visible_in_tree(), "a no-ante online duel must not display two unexplained stakes")
	assert_not_null(opening._hand, "the player's actual opening hand still appears")


func test_online_introduction_maps_both_players_and_contains_long_deck_names() -> void:
	referee = SgPracticeMatch.new(42)
	referee.deck_names = ["White Knights ".repeat(6).strip_edges(), "Black-Red Raiders ".repeat(5).strip_edges()]
	var screen := _screen(1)
	for i in 8: await get_tree().process_frame
	var intro := screen._intro_overlay
	assert_eq(screen.config.player_names, ["Amber Owl", "Azure Fox"])
	assert_eq(screen.config.deck_names, [referee.deck_names[1], referee.deck_names[0]])
	_assert_introduction_on_the_paper(intro)
	for title in intro._deck_titles:
		assert_eq(title.max_lines_visible, 3, "a title that fits under the body face gives nothing away")
	assert_null(intro._hand)
	for card in intro._cards: assert_false(card.is_visible_in_tree())


## Two long names over two long titles, the body face held at [param face]
## while the introduction lays itself out.
func _long_names_intro(face: Font) -> SgDuelOpening:
	var fonts := GameSkin._font_cache.duplicate()
	GameSkin._font_cache["font_body"] = face
	player_names = ["Azure Fox of the Northern Marches", "Amber Owl the Elder of Thune"]
	referee = SgPracticeMatch.new(42)
	referee.deck_names = ["White Knights ".repeat(6).strip_edges(), "Black-Red Raiders ".repeat(5).strip_edges()]
	var screen := _screen(1)
	for i in 8: await get_tree().process_frame
	GameSkin._font_cache = fonts
	return screen._intro_overlay


func test_long_deck_names_keep_three_lines_under_the_shipped_font_and_the_whole_name_in_the_tooltip() -> void:
	# The face every build sets since 2026-10-15: Spectral on the trimmed
	# lines `GameSkin.font` gives it. Two long names over two long titles
	# fit the slot with room over (measured that day: the column 354 px
	# of 420), so no title gives a line away; the tooltip still carries the
	# whole name a three-line title trims. (This test used to stand the
	# UNTRIMMED face in for "the plain build", under which the column left
	# its slot — no build ships that face now; the give-way is the next
	# test's.)
	var intro: SgDuelOpening = await _long_names_intro(
		GameSkin._tightened(GameSkin.our_font("font_body")))
	_assert_introduction_on_the_paper(intro)
	assert_eq(intro._deck_titles.size(), 2)
	for title in intro._deck_titles:
		assert_eq(title.max_lines_visible, 3, "the shipped face keeps every line: " + title.text)
		assert_eq(title.get_visible_line_count(), 3)
		assert_true(title.tooltip_text.begins_with(title.text.left(12)))
		assert_gt(title.tooltip_text.length(), 40, "the tooltip keeps the whole name")
	var note: Label = intro._column.get_child(intro._column.get_child_count() - 1)
	assert_true(note.text.begins_with("Temporary player names"))
	assert_eq(note.get_visible_line_count(), 2, "the note under the rules lost nothing")


func test_a_column_that_outgrows_its_slot_gives_way_a_title_line_at_a_time() -> void:
	# THE GIVE-WAY, which the shipped face no longer needs and the column
	# still has to have (another rules row, a taller face). A face with a
	# taller line stands in for that day: Spectral UNTRIMMED, the body face
	# until 2026-10-15, under which the same names leave the slot. Each
	# title gives up one line, not two; the tooltip keeps the whole name,
	# and nothing under the seats moves.
	var intro: SgDuelOpening = await _long_names_intro(GameSkin.our_font("font_body"))
	_assert_introduction_on_the_paper(intro)
	assert_eq(intro._deck_titles.size(), 2)
	for title in intro._deck_titles:
		assert_eq(title.max_lines_visible, 2, "a three-line title gives up one line, not two: " + title.text)
		assert_eq(title.get_visible_line_count(), 2)
		assert_true(title.tooltip_text.begins_with(title.text.left(12)))
		assert_gt(title.tooltip_text.length(), 40, "the tooltip keeps the whole name")
	var note: Label = intro._column.get_child(intro._column.get_child_count() - 1)
	assert_true(note.text.begins_with("Temporary player names"))
	assert_eq(note.get_visible_line_count(), 2, "the note under the rules lost nothing")


## Every word and both answer buttons stand on the dialog's paper — the
## window is pinned to the ground's size and grows for nothing.
func _assert_introduction_on_the_paper(intro: SgDuelOpening) -> void:
	var rect: Rect2 = intro._dialog.get_global_rect()
	for label in intro.find_children("*", "Label", true, false):
		if not label.is_visible_in_tree(): continue
		assert_true(rect.encloses(label.get_global_rect()), label.text)
	for button in intro._buttons:
		assert_true(rect.encloses(button.get_global_rect()), button.text)


func test_finished_snapshot_during_the_introduction_preserves_the_result() -> void:
	referee = SgPracticeMatch.new(42)
	var screen := _screen()
	assert_not_null(screen._intro_overlay)
	referee.game.adjust_life(1, -22)
	assert_true(referee.game.game_over)
	screen.present(_room(), true, false)
	assert_null(screen._intro_overlay)
	assert_null(screen._network_opening)
	assert_false(screen._toss_active)
	assert_true(screen._result_seen)
	assert_eq(screen.life_before_result[1], 20, "closing the introduction must not refresh away the previous life total")

func test_public_palette_is_stable_and_rejects_unknown_skin_values() -> void:
	var original: Array = referee.view(0).presentation.players.duplicate(true)
	give_hand(1, "Black Lotus")
	g.players[1].library.reverse()
	var snapshot := referee.view(0)
	assert_eq(snapshot.presentation.players, original)
	assert_false(JSON.stringify(snapshot).contains("Black Lotus"))
	for bad_value in ["../portrait", "neon", 42]:
		var invalid := snapshot.duplicate(true)
		invalid.presentation.players[0].color = bad_value
		assert_false(SgViewProtocol.game(invalid))

func test_connection_dialog_updates_without_reopening() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var screen := _screen()
	screen._show_connection()
	var label := screen._connection_status
	assert_string_contains(label.text, "Connected")
	screen.present(_room(), false, false)
	assert_same(screen._connection_status, label)
	assert_string_contains(label.text, "Reconnecting")
	var room := _room()
	room.connected[1] = false
	screen.present(room, true, false)
	assert_string_contains(label.text, "Amber Owl")

func test_first_snapshot_of_a_finished_duel_has_no_invented_previous_life() -> void:
	g.adjust_life(1, -22)
	assert_true(g.game_over)
	var screen := _screen()
	assert_eq(screen.life_before_result, [g.players[0].life, g.players[1].life])
	assert_true(screen._result_seen)

func test_connection_status_uses_the_remote_seat_mapping() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var screen := _screen(1)
	var room := _room(1)
	room.connected[0] = false
	screen.present(room, true, false)
	assert_string_contains(screen._connection_message(), "Azure Fox")
	room.connected = [true, false]
	screen.present(room, true, false)
	assert_string_contains(screen._connection_message(), "Restoring your seat")

func test_restored_combat_fits_the_board_after_layout_and_resize() -> void:
	var attacker := put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Gray Ogre")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	var screen := _screen(1)
	for i in 8: await get_tree().process_frame
	var combat := screen._combat_window
	assert_true(combat.visible)
	_assert_combat_inside_board(screen)
	var card: Node = combat._top_lane.get_child(0)
	var prompt: String = screen._prompt_label.text
	(screen.get_parent() as SubViewport).size = Vector2i(1100, 700)
	for i in 8: await get_tree().process_frame
	_assert_combat_inside_board(screen)
	assert_same(combat._top_lane.get_child(0), card, "layout correction must not rebuild the combat cards")
	assert_eq(screen._prompt_label.text, prompt)

func _assert_combat_inside_board(screen: SgDuelView) -> void:
	var board: Rect2 = screen._board_area()
	var combat: Rect2 = screen._combat_window.get_global_rect()
	assert_gte(combat.position.x, board.position.x, "the combat title must stay clear of the sidebar")
	assert_lte(combat.end.x, board.end.x)
	assert_almost_eq(combat.get_center().x, board.get_center().x, 1.0)

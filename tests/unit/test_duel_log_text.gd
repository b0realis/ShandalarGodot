extends GutTest
## THE SHAPE OF THE DUEL LOG — [DuelLogText], the one reading of the
## engine's lines that the log window and the running file share
## (2026-09-07, `[QoL]`): seat labels on acts, lazy step markers, the
## turn header naming the seat, a gap between turns, and
## [method DuelLogText.plain] printing it all as text.


func _meta(kind := "", pid := -1, turn := 1, step := -1) -> Dictionary:
	return {"turn": turn, "step": step, "pid": pid, "kind": kind, "card": "", "colors": 0}


func _shape(names: Array) -> DuelLogText:
	var shape := DuelLogText.new()
	shape.names = PackedStringArray(names)
	return shape


func test_a_seat_is_player_n_and_the_name_only_when_it_is_not_the_default() -> void:
	var shape := _shape(["Player 1", "HAL 9000"])
	assert_eq(shape.seat(0), "Player 1", "the default name never repeats itself")
	assert_eq(shape.seat(1), "Player 2 (HAL 9000)")
	assert_eq(shape.seat(-1), "Player 0", "nobody's seat still prints")
	assert_eq(_shape(["", "x"]).seat(0), "Player 1", "an empty name is the default")


func test_an_act_is_prefixed_by_its_seat_and_a_consequence_is_not() -> void:
	var shape := _shape(["Fred", "HAL 9000"])
	assert_eq(shape.attributed("HAL 9000 plays Island", _meta("play", 1)),
		"Player 2 (HAL 9000) plays Island")
	assert_eq(shape.attributed("Serra Angel is destroyed", _meta("", -1)),
		"Serra Angel is destroyed")
	assert_eq(shape.attributed("Fred's Serra Angel is destroyed", _meta("", -1)),
		"Fred's Serra Angel is destroyed", "a possessive keeps its shape")
	assert_eq(shape.attributed("Fred plays Plains", _meta("play", 1)),
		"Fred plays Plains", "the meta's seat must open the sentence to be swapped")


func test_a_step_is_marked_once_the_first_time_a_line_lands_in_it() -> void:
	var shape := _shape(["Player 1", "Player 2"])
	var first := shape.rows("Player 1 plays Forest", _meta("play", 0, 1, Mtg.Step.MAIN1))
	assert_eq(first.size(), 2, "a marker, then the line")
	assert_eq(first[0]["role"], "step")
	assert_eq(first[0]["text"], "[%s]" % Mtg.step_name(Mtg.Step.MAIN1))
	assert_eq(first[1]["role"], "line")
	assert_eq(first[1]["text"], DuelLogText.INDENT + "Player 1 plays Forest", "indented under the marker")
	var second := shape.rows("Player 1 casts Grizzly Bears", _meta("cast", 0, 1, Mtg.Step.MAIN1))
	assert_eq(second.size(), 1, "the same step is not marked twice")
	assert_eq(second[0]["role"], "line")
	var third := shape.rows("Player 1 attacks with Grizzly Bears", _meta("attack", 0, 1, Mtg.Step.DECLARE_ATTACKERS))
	assert_eq(third.size(), 2, "a new step gets its marker")
	assert_eq(third[0]["text"], "[%s]" % Mtg.step_name(Mtg.Step.DECLARE_ATTACKERS))


func test_the_same_step_of_a_later_turn_is_marked_again() -> void:
	var shape := _shape(["Player 1", "Player 2"])
	shape.rows("Player 1 plays Forest", _meta("play", 0, 1, Mtg.Step.MAIN1))
	var later := shape.rows("Player 2 plays Island", _meta("play", 1, 2, Mtg.Step.MAIN1))
	assert_eq(later.size(), 2, "turn 2's first main is not turn 1's")
	assert_eq(later[0]["role"], "step")


func test_a_line_before_the_first_turn_has_no_marker_and_no_indent() -> void:
	var shape := _shape(["Player 1", "Player 2"])
	var rows := shape.rows("Player 1 draws 7 cards", _meta("draw", 0, 0, -1))
	assert_eq(rows.size(), 1)
	assert_eq(rows[0]["text"], "Player 1 draws 7 cards")


func test_the_turn_header_names_the_seat_and_comes_after_a_gap() -> void:
	var shape := _shape(["Player 1", "HAL 9000"])
	var first := shape.rows("== Turn 1 — Player 1 ==", _meta("turn", 0, 1, -1))
	assert_eq(first.size(), 1, "no gap before the first header")
	assert_eq(first[0]["role"], "turn")
	assert_eq(first[0]["text"], "== Turn 1 — Player 1 ==")
	var second := shape.rows("== Turn 2 — HAL 9000 ==", _meta("turn", 1, 2, -1))
	assert_eq(second.size(), 2, "a gap, then the header")
	assert_eq(second[0]["role"], "gap")
	assert_eq(second[0]["text"], "")
	assert_eq(second[1]["text"], "== Turn 2 — Player 2 (HAL 9000) ==")


func test_a_turn_header_resets_the_step_so_the_first_step_is_marked_again() -> void:
	var shape := _shape(["Player 1", "Player 2"])
	shape.rows("== Turn 1 — Player 1 ==", _meta("turn", 0, 1, -1))
	shape.rows("Player 1 plays Forest", _meta("play", 0, 1, Mtg.Step.MAIN1))
	shape.rows("== Turn 2 — Player 2 ==", _meta("turn", 1, 2, -1))
	var rows := shape.rows("Player 2 plays Island", _meta("play", 1, 2, Mtg.Step.MAIN1))
	assert_eq(rows[0]["role"], "step")


func test_reset_starts_over() -> void:
	var shape := _shape(["Player 1", "Player 2"])
	shape.rows("== Turn 1 — Player 1 ==", _meta("turn", 0, 1, -1))
	shape.rows("Player 1 plays Forest", _meta("play", 0, 1, Mtg.Step.MAIN1))
	shape.reset()
	var header := shape.rows("== Turn 1 — Player 1 ==", _meta("turn", 0, 1, -1))
	assert_eq(header.size(), 1, "the first header again, no gap")
	var rows := shape.rows("Player 1 plays Forest", _meta("play", 0, 1, Mtg.Step.MAIN1))
	assert_eq(rows[0]["role"], "step", "the step is marked again")


func test_plain_prints_the_whole_log_one_row_per_line() -> void:
	var lines := PackedStringArray([
		"== Turn 1 — Player 1 ==",
		"Player 1 plays Forest",
		"HAL 9000 discards Island",
		"== Turn 2 — HAL 9000 ==",
		"Serra Angel is destroyed",
	])
	var metas: Array[Dictionary] = [
		_meta("turn", 0, 1, -1),
		_meta("play", 0, 1, Mtg.Step.MAIN1),
		_meta("", 1, 1, Mtg.Step.MAIN1),
		_meta("turn", 1, 2, -1),
		_meta("", -1, 2, Mtg.Step.COMBAT_DAMAGE),
	]
	var text := DuelLogText.plain(lines, metas, PackedStringArray(["Player 1", "HAL 9000"]))
	var expected := "\n".join(PackedStringArray([
		"== Turn 1 — Player 1 ==",
		"[%s]" % Mtg.step_name(Mtg.Step.MAIN1),
		"  Player 1 plays Forest",
		"  Player 2 (HAL 9000) discards Island",
		"",
		"== Turn 2 — Player 2 (HAL 9000) ==",
		"[%s]" % Mtg.step_name(Mtg.Step.COMBAT_DAMAGE),
		"  Serra Angel is destroyed",
	]))
	assert_eq(text, expected)


func test_plain_survives_a_short_meta_column() -> void:
	var lines := PackedStringArray(["one", "two"])
	var metas: Array[Dictionary] = [_meta()]
	var text := DuelLogText.plain(lines, metas, PackedStringArray(["Player 1", "Player 2"]))
	assert_eq(text, "one\ntwo", "a line without meta prints as itself")

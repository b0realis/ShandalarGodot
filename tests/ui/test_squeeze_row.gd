extends GutTest
## A BATTLEFIELD ROW SQUEEZES, IT DOES NOT WRAP — `docs/duel-todo.md` §2.13.
##
## s30 (`duel.go:1424-1434`) keeps one line per row and shrinks the pitch
## once the natural spacing overflows, so the cards slide under one
## another. Our rows were `HFlowContainer`s: the eleventh land started a
## second line, pushed the row below it down, and the three-row reading
## order §2.3 and §4.2 are both about stopped existing.


var row: SqueezeRow


func before_each() -> void:
	row = SqueezeRow.new()
	add_child_autofree(row)


func _box(width: float, height := 40.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, height)
	row.add_child(c)
	return c


func _sorted() -> void:
	row.queue_sort()
	await get_tree().process_frame


func test_an_underfull_row_lays_out_at_its_natural_pitch() -> void:
	row.size = Vector2(500, 60)
	var a := _box(50.0)
	var b := _box(50.0)
	await _sorted()
	assert_eq(a.position.x, 0.0)
	assert_eq(b.position.x, 50.0 + SqueezeRow.SEPARATION,
		"one card plus the gap")


func test_an_overfull_row_shrinks_the_pitch_instead_of_wrapping() -> void:
	# Ten 50px cards want 486px; the row has 200. s30's answer is a pitch
	# of (available - last width) / (n - 1).
	row.size = Vector2(200, 60)
	var kids: Array[Control] = []
	for _i in 10:
		kids.append(_box(50.0))
	await _sorted()
	var pitch := (200.0 - 50.0) / 9.0
	for i in kids.size():
		assert_almost_eq(kids[i].position.x, i * pitch, 0.51, "card %d" % i)
		assert_eq(kids[i].position.y, kids[0].position.y,
			"every card stays on ONE line")


func test_the_last_card_always_shows_in_full() -> void:
	# What makes a squeezed row still readable as "there are N of these":
	# the trailing card is never itself covered.
	row.size = Vector2(160, 60)
	var kids: Array[Control] = []
	for _i in 8:
		kids.append(_box(50.0))
	await _sorted()
	var last: Control = kids[-1]
	assert_almost_eq(last.position.x + last.size.x, 160.0, 0.51,
		"the last card ends flush with the row's right edge")


func test_a_row_of_mixed_widths_squeezes_from_the_real_widths() -> void:
	# s30 assumes one card width per row; our non-creature rows hold
	# CardPiles, which are wider than a single card. The pitch has to come
	# from the actual widths or the piles would overlap into rubble.
	row.size = Vector2(200, 60)
	var a := _box(50.0)
	var b := _box(120.0)
	var c := _box(120.0)
	await _sorted()
	assert_eq(a.position.x, 0.0)
	assert_true(b.position.x > a.position.x and c.position.x > b.position.x,
		"order is preserved")
	assert_almost_eq(c.position.x + c.size.x, 200.0, 0.51,
		"and the last one still lands flush")


func test_an_end_aligned_row_hugs_the_right_when_it_fits() -> void:
	# The land and artifact rows gather beside the hand window in the
	# owner's reference screenshots.
	row.align = SqueezeRow.Align.END
	row.size = Vector2(400, 60)
	var a := _box(50.0)
	var b := _box(50.0)
	await _sorted()
	assert_almost_eq(b.position.x + b.size.x, 400.0, 0.51)
	assert_almost_eq(a.position.x, 400.0 - 104.0, 0.51)


func test_alignment_stops_mattering_once_the_row_overflows() -> void:
	row.align = SqueezeRow.Align.END
	row.size = Vector2(100, 60)
	var a := _box(50.0)
	for _i in 5:
		_box(50.0)
	await _sorted()
	assert_eq(a.position.x, 0.0, "a full row starts at the left, either way")


func test_the_row_never_demands_more_width_than_its_widest_card() -> void:
	# A row that asked for its full natural width would push the board's
	# own container wider and the squeeze would never run.
	_box(50.0)
	_box(120.0)
	_box(50.0)
	assert_eq(row.get_combined_minimum_size().x, 120.0)


func test_the_row_is_as_tall_as_its_tallest_card() -> void:
	# A tapped permanent turns inside a taller holder; the row has to make
	# room for it.
	_box(50.0, 40.0)
	_box(50.0, 64.0)
	assert_eq(row.get_combined_minimum_size().y, 64.0)


func test_a_hidden_child_takes_no_room() -> void:
	row.size = Vector2(500, 60)
	var a := _box(50.0)
	var ghost := _box(50.0)
	ghost.visible = false
	var b := _box(50.0)
	await _sorted()
	assert_eq(b.position.x, a.position.x + 50.0 + SqueezeRow.SEPARATION,
		"the invisible card is not a gap")


func test_an_empty_row_lays_out_without_complaint() -> void:
	row.size = Vector2(300, 60)
	await _sorted()
	assert_eq(row.get_child_count(), 0)


# ------------------------------------------------- on the real board --

func test_the_board_rows_are_squeeze_rows() -> void:
	var screen: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	for pid in 2:
		for which in screen._field_rows[pid]:
			assert_true(screen._field_rows[pid][which] is SqueezeRow,
				"seat %d row %d" % [pid, which])

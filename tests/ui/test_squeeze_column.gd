extends GutTest
## A TERRITORY'S ROWS NEVER LEAVE THEIR HALF — the playtest defect of
## 2026-09-07: *"cards sometimes automatically go outside the playfield
## for me or the opponent"*.
##
## The three rows of a half sat in a [VBoxContainer], and a VBox whose
## rows want more height than the half has simply GROWS past it — a
## Control's size is never less than its minimum. With a turned pile, a
## tapped artifact and a row of attackers (140 each) the box was 431 tall
## in a 388 half and the creature row ran out through the half's
## `clip_contents`: the opponent's through the seam, the player's off the
## bottom of the screen. [SqueezeColumn] is [SqueezeRow] turned on its
## side: the overflow is shared over the seams between the rows and each
## earlier row slides under the next, the creatures always whole.


var column: SqueezeColumn


func before_each() -> void:
	column = SqueezeColumn.new()
	add_child_autofree(column)


func _box(height: float, width := 40.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, height)
	column.add_child(c)
	return c


func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(c)
	return c


func _sorted() -> void:
	column.queue_sort()
	await get_tree().process_frame


func _bottom(c: Control) -> float:
	return c.position.y + c.size.y


func test_rows_that_fit_lay_out_like_the_vbox_they_replaced() -> void:
	column.size = Vector2(300, 400)
	var lands := _box(100.0)
	var other := _box(100.0)
	var spacer := _spacer()
	var creatures := _box(100.0)
	column.squeezed = [lands, other, creatures]
	await _sorted()
	assert_eq(lands.position.y, 0.0)
	assert_eq(other.position.y, 100.0 + SqueezeColumn.SEPARATION,
		"one row plus the gap")
	assert_almost_eq(_bottom(creatures), 400.0, 0.51,
		"the spacer takes the slack and the creatures hug the far edge")
	assert_almost_eq(spacer.size.y, 400.0 - 300.0 - 3.0 * SqueezeColumn.SEPARATION,
		0.51, "which is all of it")
	assert_eq(lands.size.x, 300.0, "a row is the column's full width")


func test_rows_that_overflow_slide_under_one_another_and_stay_inside() -> void:
	# The owner's board: 153 + 140 + 140 in a 388 half, which the VBox
	# answered with a 431-tall box.
	column.size = Vector2(300, 388)
	var lands := _box(153.0)
	var other := _box(140.0)
	_spacer()
	var creatures := _box(140.0)
	column.squeezed = [lands, other, creatures]
	await _sorted()
	assert_eq(lands.position.y, 0.0)
	assert_true(other.position.y < _bottom(lands), "the other row overlaps the lands")
	assert_true(creatures.position.y < _bottom(other),
		"and the creatures overlap the other row")
	assert_almost_eq(_bottom(creatures), 388.0, 0.51,
		"the creatures end flush with the half — every row is INSIDE it")
	assert_eq(creatures.size.y, 140.0, "and the creature row is whole")
	assert_eq(lands.size.y, 153.0, "no row is squashed, only covered")


func test_the_overflow_is_shared_evenly_over_the_seams() -> void:
	# s30's uniform pitch is this rule for equal heights; our rows are not
	# equal, and a uniform pitch would put all of the overlap on one seam.
	column.size = Vector2(300, 388)
	var lands := _box(174.0)
	var other := _box(106.0)
	_spacer()
	var creatures := _box(140.0)
	column.squeezed = [lands, other, creatures]
	await _sorted()
	# The rows touch once they overflow — the gaps are for rows that fit.
	var deficit := 174.0 + 106.0 + 140.0 - 388.0
	assert_almost_eq(_bottom(lands) - other.position.y, deficit / 2.0, 0.51,
		"half the overflow at the first seam")
	assert_almost_eq(_bottom(other) - creatures.position.y, deficit / 2.0, 0.51,
		"half at the second")


func test_a_row_that_is_not_cards_keeps_its_whole_height() -> void:
	# The opponent's hand plate under their creatures, the player's fan
	# under theirs: chrome, not cards, and never slid under.
	column.size = Vector2(300, 388)
	var lands := _box(153.0)
	var other := _box(140.0)
	_spacer()
	var creatures := _box(140.0)
	var plate := _box(43.0)
	column.squeezed = [lands, other, creatures]
	await _sorted()
	assert_eq(plate.size.y, 43.0)
	assert_almost_eq(plate.position.y, _bottom(creatures) + SqueezeColumn.SEPARATION,
		0.51, "the plate sits under the creatures, not over them, with its gap")
	assert_almost_eq(_bottom(plate), 388.0, 0.51, "and ends flush with the half")


func test_the_column_never_demands_its_natural_height() -> void:
	# A minimum equal to the natural height is exactly how the VBox grew
	# out of the half.
	_box(153.0)
	_box(140.0)
	_box(140.0, 120.0)
	assert_eq(column.get_combined_minimum_size().y, 0.0)
	assert_eq(column.get_combined_minimum_size().x, 120.0,
		"as wide as its widest row")
	assert_almost_eq(column.natural_height(),
		153.0 + 140.0 + 140.0 + 2.0 * SqueezeColumn.SEPARATION, 0.01)


func test_a_hidden_row_takes_no_room() -> void:
	column.size = Vector2(300, 400)
	var a := _box(50.0)
	var ghost := _box(50.0)
	ghost.visible = false
	var b := _box(50.0)
	await _sorted()
	assert_eq(b.position.y, a.position.y + 50.0 + SqueezeColumn.SEPARATION)


func test_an_empty_column_lays_out_without_complaint() -> void:
	column.size = Vector2(300, 400)
	await _sorted()
	assert_eq(column.get_child_count(), 0)


# ------------------------------------------------- on the real board --

var screen: DuelScreen


func _mk(card_name: String, pid: int) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name),
		g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	return inst


func _summon(card_name: String, pid: int, tapped := false) -> CardInstance:
	var inst := _mk(card_name, pid)
	screen.game._put_on_battlefield(inst, pid)
	inst.summoning_sick = false
	inst.tapped = tapped
	return inst


## The screen at the reference 1280x800 whatever the test viewport is: it
## fills its parent, so its parent is a frame of that size.
func _board() -> void:
	var frame := Control.new()
	frame.size = Vector2(1280, 800)
	add_child_autofree(frame)
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	frame.add_child(screen)
	await get_tree().process_frame
	screen.stops.clear_all()


func test_the_board_rows_sit_in_squeeze_columns_on_z_steps() -> void:
	await _board()
	for pid in 2:
		assert_true(screen._half_rows[pid] is SqueezeColumn, "seat %d" % pid)
		var column_: SqueezeColumn = screen._half_rows[pid]
		assert_eq(column_.squeezed.size(), 3, "the three card rows slide")
		assert_eq(column_.squeezed[-1], screen._field_rows[pid][DuelScreen.Row.CREATURES],
			"and the creatures are the row that stays whole")
		for row in screen._field_rows[pid]:
			assert_eq(screen._field_rows[pid][row].z_index, row * DuelScreen.ROW_Z_STEP,
				"seat %d row %d stands on its step" % [pid, row])
		assert_eq(screen._free_layers[pid].z_index, DuelScreen.FREE_LAYER_Z)


func test_the_owners_crowded_board_stays_inside_both_halves() -> void:
	# Eight lands with two tapped (a flat pile and a turned one), a tapped
	# Sol Ring, a tapped attacker: the 2026-09-07 screenshots.
	await _board()
	var g: MtgGame = screen.game
	for i in 8:
		_summon("Plains", 0, i < 2)
		_summon("Swamp", 1, i < 2)
	_summon("Sol Ring", 0, true)
	_summon("Crusade", 0)
	_summon("Sol Ring", 1, true)
	_summon("Savannah Lions", 0, true)
	_summon("White Knight", 0)
	_summon("Serra Angel", 0)
	_summon("Hypnotic Specter", 1, true)
	_summon("Sengir Vampire", 1)
	g.recalculate()
	screen._refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	for pid in 2:
		var column_: SqueezeColumn = screen._half_rows[pid]
		var half: Rect2 = (column_.get_parent() as Control).get_global_rect()
		assert_gt(column_.natural_height(), column_.size.y,
			"seat %d: this board really does overflow its half" % pid)
		for row in screen._field_rows[pid]:
			var rect: Rect2 = screen._field_rows[pid][row].get_global_rect()
			assert_true(half.encloses(rect),
				"seat %d row %d %s is inside its half %s" % [pid, row, rect, half])
		var creatures: Control = screen._field_rows[pid][DuelScreen.Row.CREATURES]
		assert_eq(creatures.size.y, creatures.get_combined_minimum_size().y,
			"seat %d: the creature row is whole" % pid)

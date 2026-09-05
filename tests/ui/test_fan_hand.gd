extends GutTest
## The FANNED hand. One row while the hand fits; once it cannot be dealt
## at a readable overlap, the surplus goes to a SECOND ROW BEHIND the
## first (the owner's call — the fan may be truncated, but a big hand
## grows backwards rather than squeezing into an unreadable smear).


func _fan(card_count: int, width := 620.0) -> FanHand:
	var fan := FanHand.new()
	fan.size = Vector2(width, 200)
	add_child_autofree(fan)
	for i in card_count:
		var button := Button.new()   # a stand-in for a MiniCard
		fan.add_child(button)
	fan.relayout()
	return fan


func _rows_of(fan: FanHand) -> Array:
	var tops := {}
	for card in fan.get_children():
		tops[roundi(card.position.y / 10.0)] = true
	return tops.keys()


func test_a_small_hand_is_one_row() -> void:
	var fan := _fan(6)
	assert_true(fan.get_children().size() <= FanHand.row_capacity(fan.size.x),
		"six cards fit one row at this width")
	for card in fan.get_children():
		assert_true(card.z_index >= FanHand.FRONT_Z,
			"nothing is pushed behind")
	assert_almost_eq(fan.custom_minimum_size.y, FanHand.ONE_ROW_HEIGHT, 0.5)


func test_a_big_hand_opens_a_second_row_behind() -> void:
	var capacity := FanHand.row_capacity(620.0)
	var fan := _fan(capacity + 6)
	var behind := 0
	var front := 0
	for card in fan.get_children():
		if card.z_index < FanHand.FRONT_Z:
			behind += 1
		else:
			front += 1
	assert_gt(behind, 0, "the surplus went somewhere")
	assert_gt(front, 0, "and the rest stayed in front")
	assert_eq(behind + front, capacity + 6, "every card was dealt")


func test_the_back_row_sits_above_and_behind() -> void:
	var fan := _fan(FanHand.row_capacity(620.0) + 6)
	var back_y := 9999.0
	var front_y := -9999.0
	for card in fan.get_children():
		if card.z_index < FanHand.FRONT_Z:
			back_y = minf(back_y, card.position.y)
		else:
			front_y = maxf(front_y, card.position.y)
	assert_lt(back_y, front_y, "the back row peeks out ABOVE the front")
	assert_almost_eq(fan.custom_minimum_size.y,
		FanHand.ONE_ROW_HEIGHT + FanHand.BACK_ROW_RISE, 0.5,
		"and the fan grew by exactly one rise")


func test_rows_never_interleave_in_z() -> void:
	# A back card must never draw over a front card, whatever the counts —
	# and both rows stay at a POSITIVE z, or the back row disappears
	# behind the table (a negative z_index is relative to the parent).
	var fan := _fan(FanHand.row_capacity(620.0) + 9)
	var highest_back := -9999
	var lowest_front := 9999
	for card in fan.get_children():
		if card.z_index < FanHand.FRONT_Z:
			highest_back = maxi(highest_back, card.z_index)
		else:
			lowest_front = mini(lowest_front, card.z_index)
	assert_lt(highest_back, lowest_front, "the two rows keep their layers")
	assert_true(highest_back >= 0, "and neither row goes behind the table")


func test_a_narrow_fan_still_deals_every_card() -> void:
	var fan := _fan(14, 240.0)
	assert_eq(fan.get_children().size(), 14)
	for card in fan.get_children():
		# Sub-pixel drift comes from the tilt, so compare with tolerance.
		assert_almost_eq(card.size.x, FanHand.CARD_SIZE.x, 0.01,
			"no card was shrunk away")
		assert_almost_eq(card.size.y, FanHand.CARD_SIZE.y, 0.01)

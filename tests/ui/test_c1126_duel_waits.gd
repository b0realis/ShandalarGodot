extends GutTest
## THE DUEL'S TWO WAITS CAN BE HURRIED (campaign 2026-11-26, smoothness 9
## and 10): a confirm key, a pad's button or a click ends the coin's spin
## and then its verdict, and a press ends the dying total's count-down.

var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = DuelConfig.vs_ai_default(AiProfile.wizard())
	screen.config.pace = 1000.0
	add_child_autofree(screen)
	await get_tree().process_frame
	await get_tree().process_frame


func _key(action: String) -> InputEvent:
	var key := Controls.key_of(action).duplicate() as InputEventKey
	key.pressed = true
	screen._last_stroke["ms"] = -1000000   # no earlier stroke to be the double of
	return key


func _toss() -> CoinToss:
	var toss := CoinToss.new()
	screen.add_child(toss)
	toss.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen._toss_overlay = toss
	screen._toss_active = true
	return toss


func _end_toss(toss: CoinToss) -> void:
	screen._toss_overlay = null
	screen._toss_active = false
	toss.queue_free()
	await get_tree().process_frame


func test_a_confirm_key_ends_the_spin_on_the_winners_face() -> void:
	for winner in 2:
		var toss := _toss()
		var panel := toss._build_panel(CoinToss.PANEL)
		toss.add_child(panel)
		var done := [false]
		var spin := func() -> void:
			await toss._spin_coin(panel, screen.config, winner)
			done[0] = true
		spin.call()
		await get_tree().process_frame
		assert_true(toss._spin_playing, "control: the coin is in the air")
		assert_false(done[0])
		var started := Time.get_ticks_msec()
		screen._on_control(_key("duel_space" if winner == 0 else "duel_done"))
		assert_true(done[0], "the press set the coin down at once")
		assert_lt(Time.get_ticks_msec() - started, 200)
		var coin: Control = panel.get_child(panel.get_child_count() - 1)
		var up := -1
		for seat in 2:
			if (coin.get_child(seat) as Control).visible:
				assert_eq(up, -1, "one face up")
				up = seat
		assert_eq(up, winner, "on the face the toss was going to show")
		await _end_toss(toss)


func test_a_second_press_ends_the_verdict_and_not_the_first() -> void:
	var toss := _toss()
	var panel := toss._build_panel(CoinToss.PANEL)
	toss.add_child(panel)
	var stage := [0]
	var run := func() -> void:
		await toss._spin_coin(panel, screen.config, 0)
		stage[0] = 1
		toss._verdict_skip_requested = false
		toss._verdict_showing = true
		await toss._wait(30.0)
		stage[0] = 2
	run.call()
	await get_tree().process_frame
	assert_true(toss.hurry(), "the first press ends the spin")
	assert_eq(stage[0], 1, "and leaves the verdict standing")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(stage[0], 1, "control: the verdict holds")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	toss._input(click)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(stage[0], 2, "a click ends the verdict's hold")
	await _end_toss(toss)


func test_a_held_toss_is_not_hurried() -> void:
	var toss := _toss()
	toss._verdict_showing = true
	toss.hold(true)
	assert_false(toss.hurry(), "the Pause window's press is not the toss's")
	assert_false(toss._verdict_skip_requested)
	toss.hold(false)
	assert_true(toss.hurry())
	await _end_toss(toss)


func test_a_pad_button_hurries_the_toss_too() -> void:
	var toss := _toss()
	toss._verdict_showing = true
	var pad: InputEvent = null
	for event in InputMap.action_get_events("duel_space") + InputMap.action_get_events("duel_done"):
		if event is InputEventJoypadButton:
			pad = event.duplicate()
			break
	if pad == null:
		pass_test("no pad button is bound to a confirm action here")
		await _end_toss(toss)
		return
	(pad as InputEventJoypadButton).pressed = true
	screen._unhandled_input(pad)
	assert_true(toss._verdict_skip_requested, "the pad's confirm ends the verdict")
	await _end_toss(toss)


func _dying() -> void:
	screen._last_life[1] = 6
	screen.game.players[1].life = -2


func test_the_dying_total_counts_its_full_time_untouched() -> void:
	_dying()
	var started := Time.get_ticks_msec()
	await screen._run_death_countdown()
	assert_gt(Time.get_ticks_msec() - started, 1300, "control: 0.9 s of count and 0.5 s of hold")
	assert_false(screen.is_processing_input(), "and the screen stops listening for the press")


func test_a_click_ends_the_dying_totals_count() -> void:
	_dying()
	var done := [false]
	var count := func() -> void:
		await screen._run_death_countdown()
		done[0] = true
	var started := Time.get_ticks_msec()
	count.call()
	await get_tree().process_frame
	assert_true(screen._death_counting, "control: the count runs")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	screen._input(click)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(done[0], "the count is over")
	assert_lt(Time.get_ticks_msec() - started, 500)
	assert_true(screen._life_countdown.is_empty(), "and the total shown is the final one")


func test_a_confirm_key_ends_the_dying_totals_count() -> void:
	for action in ["duel_space", "duel_done"]:
		_dying()
		screen._life_countdown.clear()
		var done := [false]
		var count := func() -> void:
			await screen._run_death_countdown()
			done[0] = true
		count.call()
		await get_tree().process_frame
		screen._last_stroke["ms"] = -1000000
		screen._on_control(_key(action))
		await get_tree().process_frame
		await get_tree().process_frame
		assert_true(done[0], "%s ends the count" % action)

extends GutTest
## The vs-AI duel screen, end to end through real time: the human seat
## fast-forwards, the AI's pacing timer takes its turns, the game advances.


func test_vs_ai_duel_plays_real_turns() -> void:
	var screen: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = DuelConfig.vs_ai_default(AiProfile.wizard())
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_not_null(screen.game)
	assert_eq(screen.hidden_hands, [1] as Array[int], "AI hand hides")
	# Drive the human side mechanically; let AI timers fire in real time.
	for _i in 12:
		if screen.game.game_over or screen.game.turn_number >= 3:
			break
		if screen.mode == DuelScreen.Mode.ATTACKERS \
				or screen.mode == DuelScreen.Mode.BLOCKERS:
			screen._on_confirm()
		else:
			screen._on_pass_turn()
		await wait_seconds(0.6)
	assert_gte(screen.game.turn_number, 2,
		"the AI took its turn(s) on the pacing timer")
	# The log proves real turns happened; its exact length is wall-clock
	# sensitive (AI pacing timers), so only a floor is asserted.
	assert_gt(screen.game.log_lines.size(), 4, "a real game log accumulated")


func test_human_cannot_operate_ai_cards() -> void:
	var screen: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = DuelConfig.vs_ai_default(AiProfile.wizard())
	add_child_autofree(screen)
	await get_tree().process_frame
	var ai_land: CardInstance = null
	for inst in screen.game.players[1].hand:
		if inst.data.is_land():
			ai_land = inst
			break
	if ai_land == null:
		pass_test("no land in the AI's opener this seed")
		return
	screen._on_card_clicked(ai_land)
	assert_eq(ai_land.zone, Mtg.Zone.HAND, "clicking AI cards does nothing")

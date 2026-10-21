extends GutTest
## THE SECOND BUG HUNT (2026-10-21), the screens: what the duel screen
## had in hand when the duel ended, and what a question is drawn under.
##
## WAS, three things that outlived the verdict (`DuelScreen._on_game_over`
## closed only the mini help and the leave question):
##   * A QUESTION held for the player (Pause → Concede under it) stayed up
##     and live: its lines still answered — resolving the held spell on a
##     finished duel — and its key branch took Return and Esc from the End
##     of Duel window;
##   * AN AIM in progress (the AI's attack killed the player mid-aim, or a
##     concede) kept the targeting mode and the crosshair cursor over the
##     verdict;
##   * the CONCEDE QUESTION stayed up, waiting for a Yes the engine refuses.
## AND the question's window was drawn at z 390 (the scrim's 190 plus the
## dialog's own 200, z being relative): over the Pause window (270), the
## leave question and the End of Duel window, which — later in the tree —
## took the clicks. The player saw the question and clicked its lines; the
## hidden Pause window's buttons under them answered, `Exit game` among
## them. NOW the verdict takes all three down, a finished duel opens no
## question, and the question is drawn at its scrim's z, under every window
## that takes clicks before it.

var screen: DuelScreen


func before_each() -> void:
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]
	config.pace = 0.0
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.stops.clear_all()
	var g: MtgGame = screen.game
	g._probing = true
	for p in g.players:
		p.hand.clear()
	g.active_player = 0
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	g.awaiting_attackers = false
	g.awaiting_blockers = false
	g.priority_player = 0
	g._probing = false
	screen.mode = DuelScreen.Mode.NORMAL


func after_each() -> void:
	# The refresh drops old card widgets at once and frees them at frame end.
	await get_tree().process_frame
	await get_tree().process_frame


func _put(pid: int, card_name: String, zone: int) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name), g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	if zone == Mtg.Zone.BATTLEFIELD:
		g._put_on_battlefield(inst, pid)
		inst.summoning_sick = false
	else:
		inst.zone = Mtg.Zone.HAND
		g.players[pid].hand.append(inst)
	return inst


## A question held for seat 0, on the screen. (The screen opens none on a
## headless display by itself, so the test opens it as `_refresh` would.)
func _hold_a_question() -> PlayerChoice:
	var choice := PlayerChoice.new(PlayerChoice.Kind.YES_NO, 0, "Pay 1 life?")
	screen.game.awaiting_choice = choice
	screen._build_choice_overlay(choice)
	assert_not_null(screen._choice_overlay, "control: the question is up")
	return choice


## Where [param node] is drawn among its siblings' trees: its z with every
## relative parent's added.
static func _drawn_at(node: Node) -> int:
	var z := 0
	var at := node
	while at is CanvasItem:
		z += (at as CanvasItem).z_index
		if not (at as CanvasItem).z_as_relative:
			break
		at = at.get_parent()
	return z


func _highest_z_in(root: Node) -> int:
	var top := _drawn_at(root)
	for child in root.find_children("*", "CanvasItem", true, false):
		top = maxi(top, _drawn_at(child))
	return top


# ------------------------------------------------------ the verdict ends --

func test_the_verdict_takes_a_held_question_down() -> void:
	_hold_a_question()
	screen.game.concede(0)
	screen._refresh()
	assert_null(screen._choice_overlay, "no question over the End of Duel window")
	screen._open_choice_overlay()
	assert_null(screen._choice_overlay, "and a finished duel opens none")


func test_a_line_of_a_question_answers_nothing_once_the_duel_is_over() -> void:
	_hold_a_question()
	screen.game.concede(0)
	var lines_before := screen.game.log_lines.size()
	screen._on_choice_option(0)
	assert_not_null(screen.game.awaiting_choice, "the held question was not answered")
	assert_eq(screen.game.log_lines.size(), lines_before, "nothing happened after the verdict")


func test_the_verdict_ends_an_aim() -> void:
	_put(0, "Mountain", Mtg.Zone.BATTLEFIELD)
	var bolt := _put(0, "Lightning Bolt", Mtg.Zone.HAND)
	screen._refresh()
	screen._start_cast(bolt)
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING, "control: aiming")
	assert_true(screen._target_cursor_active, "control: the crosshair is up")
	screen.game.concede(0)
	screen._refresh()
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL, "no aiming at a finished duel")
	assert_null(screen._pending_card, "nothing pending")
	assert_false(screen._target_cursor_active, "the system cursor is back")


func test_the_verdict_takes_the_concede_question_down() -> void:
	screen._ask_to_concede()
	assert_not_null(screen._concede_dialog, "control: Concede asks")
	screen.game.concede(1)
	screen._refresh()
	await get_tree().process_frame
	assert_true(screen._concede_dialog == null or screen._concede_dialog.is_queued_for_deletion(),
		"the question goes with the duel")


# ------------------------------------------- the question's place on top --

func test_the_pause_window_is_drawn_over_the_question_it_takes_clicks_from() -> void:
	_hold_a_question()
	screen._open_pause()
	var kids := screen.get_children()
	assert_gt(kids.find(screen._pause_menu), kids.find(screen._choice_overlay),
		"control: the Pause window is later in the tree, so it takes the clicks")
	var question_top := _highest_z_in(screen._choice_overlay)
	for button in screen._pause_menu.find_children("*", "BaseButton", true, false):
		assert_gt(_drawn_at(button), question_top,
			"%s is drawn over the question too" % (button as BaseButton).text)
	screen._close_pause()
	screen.game.awaiting_choice = null
	screen._close_choice_overlay()


func test_the_question_is_still_drawn_over_the_table() -> void:
	_hold_a_question()
	assert_eq(_drawn_at(screen._choice_overlay.get_child(0)), screen._choice_overlay.z_index,
		"the dialog sits at its scrim's z")
	assert_gt(screen._choice_overlay.z_index, screen._chain_box.z_index, "over the chain")
	assert_gt(screen._choice_overlay.z_index, GraveyardView.Z, "and the graveyard view")
	screen.game.awaiting_choice = null
	screen._close_choice_overlay()

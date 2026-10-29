extends GutTest
## THE DUEL SCREEN'S FINDINGS of the 0.50.65 bug campaign (c19, k3-1 …
## k3-7, k3-5 apart in `test_c19_F3_lan_chain.gd`) — each pinned here as
## the defect a player met:
##
##  * k3-1 — two Enter or Space presses after a rebind in Duel Screen
##    Options took that key off Done or the one button: the capture kept
##    the focus, so the next accept press started a second capture.
##  * k3-2 — under the 1997 rule (attackers are final) one press of the
##    attack-all key committed every creature with no way back; now the
##    first press asks on the bar and a second commits.
##  * k3-3 — the UI scale missed the question window (its dialog stands on
##    a scrim) and the Pause window; the opening screens keep their size
##    and the switch's words say so.
##  * k3-4 — at 150% a long Situation Bar line ran off the screen.
##  * k3-6 — poison marks past twelve were drawn outside the register.
##  * k3-7 — the replay viewer's Spell Chain gadget did nothing.

var screen: DuelScreen
var _saved: Dictionary = {}
var KEYS: Array[String] = [DuelScreenOptions.UI_SCALE_KEY,
	DuelScreenOptions.ATTACK_ALL_KEY]


func before_each() -> void:
	_saved = {}
	for key in KEYS:
		_saved[key] = Settings.get_value(key, null) if Settings.has_value(key) else null
		Settings.clear_value(key)


func after_each() -> void:
	Controls.reset()   # the rebinding tests leave the map as they found it
	for key in KEYS:
		if _saved[key] == null:
			Settings.clear_value(key)
		else:
			Settings.set_value(key, _saved[key])
	await get_tree().process_frame


func _table(cards: Array, step := Mtg.Step.MAIN1, seed_value := 6060) -> MtgGame:
	var position := DuelPosition.new()
	for n in cards:
		position.add(0, DuelPosition.TABLE, n)
	position.add(1, DuelPosition.TABLE, "Grizzly Bears")
	position.active_player = 0
	position.step = step
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = DuelConfig.hotseat_default().for_test(position, seed_value)
	add_child_autofree(screen)
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.size = Vector2(1280, 800)
	await get_tree().process_frame
	return screen.game


# ================================================= k3-1: the key capture --

func _open_window() -> Button:
	await _table(["Forest"])
	screen._open_screen_options()
	await get_tree().process_frame
	var capture := screen._screen_options_dialog.find_child("AttackAllBinding", true, false) as Button
	assert_not_null(capture, "control: the key's own row")
	return capture


## A real key through the viewport, down and up — the path a player's
## keyboard takes, so a focused button's own accept handling is in it.
func _key(code: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = down
		get_viewport().push_input(ev)
	await get_tree().process_frame


func test_k3_1_enter_twice_after_a_rebind_leaves_done_its_key() -> void:
	var capture := await _open_window()
	capture.pressed.emit()        # the click on the key slot
	await _key(KEY_S)
	assert_eq(Controls.key_text(DuelScreenOptions.ATTACK_ALL_ACTION), "S", "control: S bound")
	assert_false(capture.has_focus(), "the slot lets go of the keyboard once bound")
	await _key(KEY_ENTER)
	assert_false(bool(capture.get("waiting")), "Enter does not start a second capture")
	await _key(KEY_ENTER)
	assert_eq(Controls.key_text("duel_done"), "Enter", "Return still means Done")
	assert_eq(Controls.key_text(DuelScreenOptions.ATTACK_ALL_ACTION), "S")


func test_k3_1_space_twice_after_a_rebind_leaves_the_one_button_its_key() -> void:
	var capture := await _open_window()
	capture.pressed.emit()
	await _key(KEY_S)
	await _key(KEY_SPACE)
	await _key(KEY_SPACE)
	assert_eq(Controls.key_text("duel_space"), "Space", "Space still presses the one button")
	assert_eq(Controls.key_text(DuelScreenOptions.ATTACK_ALL_ACTION), "S")


func test_k3_1_escape_gives_up_and_lets_go_too() -> void:
	var capture := await _open_window()
	capture.pressed.emit()
	assert_true(bool(capture.get("waiting")), "control: listening after the click")
	await _key(KEY_ESCAPE)
	assert_false(bool(capture.get("waiting")))
	assert_false(capture.has_focus(), "Escape lets go of the keyboard as a bind does")
	await _key(KEY_SPACE)
	assert_false(bool(capture.get("waiting")), "a later Space starts nothing")
	assert_eq(Controls.key_text(DuelScreenOptions.ATTACK_ALL_ACTION), "A", "the key there is stays")


# ================================== k3-2: attack-all under the 1997 rule --

func _attack_table(creatures: Array, final_rule: bool) -> MtgGame:
	var g := await _table(creatures, Mtg.Step.COMBAT_BEGIN, 515)
	g.rules.attackers_revocable = not final_rule
	for _i in 20:
		if g.awaiting_attackers:
			break
		g.pass_priority(g.priority_player)
	screen._refresh()
	assert_true(g.awaiting_attackers, "control: attackers are being chosen")
	assert_eq(screen.mode, DuelScreen.Mode.ATTACKERS)
	return g


func _press_attack_all() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_A
	ev.pressed = true
	screen._unhandled_key_input(ev)


func test_k3_2_under_the_1997_rule_the_first_press_asks() -> void:
	await _attack_table(["Grizzly Bears", "Hill Giant", "Serra Angel"], true)
	_press_attack_all()
	assert_eq(screen._selected_attackers.size(), 0, "nothing committed on one press")
	assert_eq(screen._prompt_label.text,
		"Press A again to attack with every creature — attackers are final.")
	_press_attack_all()
	assert_eq(screen._selected_attackers.size(), 3, "the second press commits all three")
	assert_eq(screen._prompt_label.text, DuelScreen.CHOOSE_ATTACKERS,
		"the question is answered: the bar goes back to its instruction")


func test_k3_2_the_question_lasts_one_declaration() -> void:
	var g := await _attack_table(["Grizzly Bears", "Hill Giant"], true)
	_press_attack_all()
	assert_eq(screen._selected_attackers.size(), 0)
	# The declaration ends without the second press (Done with nobody in).
	screen._clear_attack_lineup()
	screen._refresh()
	_press_attack_all()
	assert_eq(screen._selected_attackers.size(), 0,
		"a press after the lineup was cleared asks again rather than commits")
	assert_true(g.awaiting_attackers)


func test_k3_2_under_modern_timing_one_press_still_does_it() -> void:
	await _attack_table(["Grizzly Bears", "Hill Giant"], false)
	_press_attack_all()
	assert_eq(screen._selected_attackers.size(), 2, "attackers can be taken back: no question")


func test_k3_2_the_window_says_how_the_key_behaves_under_the_1997_rule() -> void:
	var dialog := DuelScreenOptions.window()
	add_child_autofree(dialog)
	var check := dialog.find_child("AttackAll", true, false) as CheckBox
	assert_not_null(check)
	assert_true(check.tooltip_text.contains("second press"), check.tooltip_text)


# ================================================= k3-3: the UI scale --

func _drawn_inside(control: Control) -> void:
	var rect := control.get_global_rect()
	var room: Vector2 = screen.get_viewport_rect().size
	assert_true(rect.position.x >= -0.5 and rect.end.x <= room.x + 0.5
		and rect.position.y >= -0.5 and rect.end.y <= room.y + 0.5,
		"drawn on the screen: %s in %s" % [rect, room])


func test_k3_3_the_question_window_wears_the_scale() -> void:
	DuelScreenOptions.set_ui_scale(1.5)
	await _table(["Forest"])
	var choice := PlayerChoice.new(PlayerChoice.Kind.OPTION, 0,
		"Force of Nature: pay {G}{G}{G}{G}, or it deals 8 damage to you?")
	choice.options.assign(["Pay {G}{G}{G}{G}", "Take 8 damage"])
	choice.source = "Force of Nature"
	screen._build_choice_overlay(choice)
	var dialog: OriginalDialog = null
	for child in screen._choice_overlay.get_children():
		if child is OriginalDialog:
			dialog = child
	assert_not_null(dialog, "control: the question's dialog")
	assert_almost_eq(dialog.scale.x, 1.5, 0.001, "the question at 150%")
	await get_tree().process_frame
	_drawn_inside(dialog)
	screen._close_choice_overlay()


## The Pause window's marble board: [VersusPanel]'s centred 500x400.
func _pause_board() -> Control:
	for child in screen._pause_menu.get_children():
		if child is Control and (child as Control).size == VersusPanel.SPLASH:
			return child
	return null


func test_k3_3_the_pause_window_wears_the_scale() -> void:
	DuelScreenOptions.set_ui_scale(1.5)
	await _table(["Forest"])
	screen._open_pause()
	await get_tree().process_frame
	var board := _pause_board()
	assert_not_null(board, "control: the Pause window's board")
	assert_almost_eq(board.scale.x, 1.5, 0.001, "the Pause window at 150%")
	_drawn_inside(board)
	screen._close_pause()


func test_k3_3_the_pause_window_keeps_100_percent_at_100_percent() -> void:
	await _table(["Forest"])
	screen._open_pause()
	assert_almost_eq(_pause_board().scale.x, 1.0, 0.001)
	screen._close_pause()


func test_k3_3_the_switch_names_what_keeps_its_size() -> void:
	var dialog := DuelScreenOptions.window()
	add_child_autofree(dialog)
	var scales := dialog.find_child("UiScale", true, false) as OptionButton
	assert_not_null(scales)
	for promised in ["question", "Pause window"]:
		assert_true(scales.tooltip_text.contains(promised), "grows: %s" % promised)
	assert_true(scales.tooltip_text.contains("opening hand"),
		"the opening screens keep their size and the words say so: %s" % scales.tooltip_text)


# ========================================== k3-4: the bar on the screen --

const LONG_REFUSAL := "Illegal blocker. can't block creatures whose power is at least this creature's toughness"


func _bar_right_edge() -> float:
	return screen._situation_bar.get_global_rect().end.x


func test_k3_4_a_long_line_at_150_percent_stays_on_the_screen() -> void:
	DuelScreenOptions.set_ui_scale(1.5)
	await _table(["Forest"])
	screen._set_prompt(LONG_REFUSAL)
	for _i in 3:
		await get_tree().process_frame
	assert_lte(_bar_right_edge(), 1280.5, "the bar ends on the screen")
	assert_eq(screen._prompt_label.text, LONG_REFUSAL, "every word kept")
	assert_gt(screen._prompt_label.get_line_count(), 1, "the sentence folds instead")


func test_k3_4_a_short_line_keeps_one_row() -> void:
	DuelScreenOptions.set_ui_scale(1.5)
	await _table(["Forest"])
	screen._set_prompt("Fast Effects?...Cast Lightning Bolt")
	for _i in 3:
		await get_tree().process_frame
	var one_row := screen._situation_bar.size.y
	assert_eq(screen._prompt_label.get_line_count(), 1)
	screen._set_prompt(LONG_REFUSAL)
	for _i in 3:
		await get_tree().process_frame
	screen._set_prompt("Fast Effects?...Cast Lightning Bolt")
	for _i in 3:
		await get_tree().process_frame
	assert_eq(screen._prompt_label.get_line_count(), 1, "back to one row")
	assert_almost_eq(screen._situation_bar.size.y, one_row, 0.5, "and back to its height")


func test_k3_4_at_100_percent_the_bar_is_as_it_was() -> void:
	await _table(["Forest"])
	screen._set_prompt("Combat phase: Choose attackers.")
	for _i in 3:
		await get_tree().process_frame
	assert_eq(screen._prompt_label.autowrap_mode, TextServer.AUTOWRAP_OFF,
		"a line that fits never folds")
	assert_almost_eq(screen._prompt_label.custom_minimum_size.x, 340.0, 0.5,
		"the sentence's own room as before")


# ====================================== k3-6: poison past the register --

func test_k3_6_marks_past_twelve_stay_on_the_register() -> void:
	var register := Vector2(185, 76)
	var cells := PoisonCounters.cells(register, 13)
	assert_eq(cells.size(), PoisonCounters.COLUMNS * PoisonCounters.ROWS,
		"the 1997 window's twelve cells, and no more")
	for cell in cells:
		assert_true(cell.end.y <= register.y and cell.end.x <= register.x,
			"%s on the %s register" % [cell, register])
	assert_eq(PoisonCounters.cells(register, 10).size(), 10, "ten as before")


# ================================ k3-7: the replay viewer's chain gadget --

func test_k3_7_the_replay_chain_gadget_minimizes_and_the_band_restores() -> void:
	var table: MpnDuelTable = MpnDuelTable.new()
	add_child_autofree(table)
	await get_tree().process_frame
	table._chain_gadget.pressed.emit()
	assert_true(table.chain_minimized(), "the gadget minimizes in a replay too")
	table._chain_gadget.pressed.emit()
	assert_false(table.chain_minimized(), "and restores")
	table._set_chain_minimized(true)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	table._chain_head.gui_input.emit(click)
	assert_false(table.chain_minimized(), "a click on the band restores it")


func test_k3_7_the_replay_band_opens_no_menu() -> void:
	var table: MpnDuelTable = MpnDuelTable.new()
	add_child_autofree(table)
	await get_tree().process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.global_position = Vector2(400, 140)
	table._chain_head.gui_input.emit(click)
	assert_false(table._chain_menu.visible, "a replay offers no menu: viewing only")

extends GutTest
## THE DUEL'S MINI HELP AS A PANEL (2026-10-13): how it closes, where the
## focus goes, that the duel stands still under it, and that it fits a
## 640x480 handheld and a 1280x720 window. The menus that open it are
## pinned in tests/ui/test_c2_f_minihelp_menus.gd, the SGManalink table in
## tests/ui/test_c2_f_minihelp_online.gd.

var screen: DuelScreen
const AT := Vector2(300, 200)


func before_each() -> void:
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]   # seat 1 is the opponent
	config.pace = 0.0
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	var g: MtgGame = screen.game
	g.active_player = 0
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))


func after_each() -> void:
	if screen != null and screen.mini_help_open():
		screen._mini_help.dismiss()
	if screen != null and screen.is_paused():
		screen._close_pause()
	await get_tree().process_frame   # what the redraws let go of is freed


func _open(subject := HelpPages.MINI_LIBRARY) -> DuelMiniHelp:
	screen._open_mini_help(subject, AT)
	assert_true(screen.mini_help_open(), "control: the mini help is up")
	# Past the opening press's settle, as a reader's click would be.
	screen._mini_help._opened_ms -= DuelMiniHelp.SETTLE_MS + 1
	return screen._mini_help


func _send_key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	screen._unhandled_key_input(ev)


func _send_pad(button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = true
	screen._unhandled_input(ev)


## A mouse button on [param target]: the catcher's own handler (its
## `_gui_input`) or, for a child, the signal its handler is connected to.
func _click(target: Control, button: MouseButton, pressed: bool, double := false) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.double_click = double
	ev.position = Vector2(4, 4)
	ev.global_position = Vector2(4, 4)
	if target is DuelMiniHelp:
		target._gui_input(ev)
	else:
		target.gui_input.emit(ev)


# ------------------------------------------------------------ closing --

func test_escape_closes_it_and_reaches_nothing_else() -> void:
	_open()
	_send_key(KEY_ESCAPE)
	assert_false(screen.mini_help_open(), "Escape closed it")
	assert_false(screen.is_paused(), "and was spent there: no Pause window")


func test_the_pads_b_closes_it() -> void:
	_open()
	_send_pad(JOY_BUTTON_B)
	assert_false(screen.mini_help_open(), "B closed it")
	assert_false(screen.is_paused(), "and opened nothing")


func test_a_b_doubled_by_an_escape_is_one_press() -> void:
	# The Steam Input button with two outputs (the 2026-09-28 Deck report):
	# the copy arriving a frame later must not open the Pause window.
	_open()
	_send_pad(JOY_BUTTON_B)
	_send_key(KEY_ESCAPE)
	assert_false(screen.mini_help_open())
	assert_false(screen.is_paused(), "the Escape riding on the same B was dropped")


func test_a_click_outside_closes_it_on_its_release() -> void:
	var help := _open()
	_click(help, MOUSE_BUTTON_LEFT, true)
	assert_true(screen.mini_help_open(), "the press alone closes nothing")
	_click(help, MOUSE_BUTTON_LEFT, false)
	assert_false(screen.mini_help_open(), "its release did")


func test_the_opening_press_arriving_twice_closes_nothing() -> void:
	screen._open_mini_help(HelpPages.MINI_LIBRARY, AT)
	var help := screen._mini_help
	_click(help, MOUSE_BUTTON_LEFT, true)
	_click(help, MOUSE_BUTTON_LEFT, false)
	assert_true(screen.mini_help_open(), "a press inside the settle is the opening one again")
	help._opened_ms -= DuelMiniHelp.SETTLE_MS + 1
	_click(help, MOUSE_BUTTON_LEFT, true, true)
	_click(help, MOUSE_BUTTON_LEFT, false)
	assert_true(screen.mini_help_open(), "a double click's second press is not a decision")


func test_the_menu_key_again_closes_it_inside_or_out() -> void:
	var help := _open()
	_click(help, MOUSE_BUTTON_RIGHT, true)
	assert_false(screen.mini_help_open(), "a right click outside")
	help = _open()
	_click(help._panel, MOUSE_BUTTON_RIGHT, true)
	assert_false(screen.mini_help_open(), "a right click on the panel itself")


func test_a_left_click_on_the_words_keeps_it_open() -> void:
	var help := _open()
	_click(help._panel, MOUSE_BUTTON_LEFT, true)
	_click(help._panel, MOUSE_BUTTON_LEFT, false)
	assert_true(screen.mini_help_open(), "reading (or a finger dragging the text) is not closing")


func test_the_close_button_closes_it() -> void:
	var help := _open()
	assert_eq(help._close.text, "Close")
	help._close.pressed.emit()
	assert_false(screen.mini_help_open())


func test_the_pause_key_closes_it_and_opens_the_pause_window() -> void:
	_open()
	_send_key(KEY_Q)
	assert_false(screen.mini_help_open(), "Q closed it")
	assert_true(screen.is_paused(), "and went on to the Pause window, as over the card reader")
	screen._close_pause()
	_open()
	screen._last_stroke["ms"] -= DuelScreen.DOUBLED_MS + 1   # a later press, not Q's copy
	_send_pad(JOY_BUTTON_START)
	assert_false(screen.mini_help_open())
	assert_true(screen.is_paused(), "the pad's Start the same")


func test_the_duels_keys_reach_nothing_while_it_is_up() -> void:
	_open()
	var g: MtgGame = screen.game
	var step := g.current_step()
	var turn := g.turn_number
	var folded: Array = []
	for row in screen._hand_rows:
		folded.append(row.is_collapsed() if row is StackHand else null)
	for code in [KEY_H, KEY_M, KEY_L, KEY_R]:
		_send_key(code)
	assert_true(screen.mini_help_open(), "still up")
	assert_null(screen._duel_log, "the log key opened no log")
	assert_false(GameAudio.is_hushed(), "the mute key muted nothing")
	assert_false(screen._fullscreen_card_open(), "the read key opened no reader")
	for i in screen._hand_rows.size():
		var row = screen._hand_rows[i]
		assert_eq(row.is_collapsed() if row is StackHand else null, folded[i],
			"the hand key folded no hand")
	_send_key(KEY_ENTER)
	assert_false(screen.mini_help_open(), "Return presses its Close")
	assert_eq(g.current_step(), step, "and armed no Done order")
	assert_eq(g.turn_number, turn)


# ------------------------------------------------------------ the focus --

func test_the_focus_starts_on_close_and_comes_back() -> void:
	var before: Control = screen._pass_button
	before.grab_focus()
	assert_true(before.has_focus(), "control: the Done button holds the focus")
	var help := _open()
	assert_true(help._close.has_focus(), "the ring is on the panel's Close")
	_send_key(KEY_ESCAPE)
	assert_true(before.has_focus(), "and back on Done when it closes")


func test_the_arrows_scroll_the_words_and_never_walk_the_focus_off() -> void:
	var help := _open(HelpPages.MINI_TERRITORY)
	for action in ["ui_up", "ui_down", "ui_left", "ui_right"]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = true
		help._close.gui_input.emit(ev)
	assert_true(help._close.has_focus(), "the ring stayed on the panel")
	var own := help._close.get_path_to(help._close)
	assert_eq(help._close.focus_neighbor_left, own)
	assert_eq(help._close.focus_neighbor_bottom, own)
	assert_eq(help._close.focus_next, own)


func test_a_second_help_replaces_the_first() -> void:
	var first := _open(HelpPages.MINI_LIBRARY)
	screen._open_mini_help(HelpPages.MINI_HAND, AT)
	assert_true(screen.mini_help_open())
	assert_eq(screen._mini_help.subject, HelpPages.MINI_HAND)
	assert_false(first.is_open(), "one panel at a time")


# ------------------------------------------------- the duel stands still --

func test_the_ai_clock_stops_and_starts_again() -> void:
	var g: MtgGame = screen.game
	g.active_player = 1
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	g.priority_player = 1
	screen.mode = DuelScreen.Mode.NORMAL
	_open()
	screen._ai_pending = false     # forget whatever the setup armed
	screen._maybe_schedule_ai()
	assert_false(screen._ai_pending, "no dwell is armed under the mini help")
	var turn := g.turn_number
	var step := g.current_step()
	var priority := g.priority_player
	for _i in 30:
		screen._ai_step()          # a dwell armed before it opened, firing
		screen._refresh()
	assert_eq(g.turn_number, turn, "the opponent took no turn")
	assert_eq(g.current_step(), step, "the duel did not move one step")
	assert_eq(g.priority_player, priority, "nobody passed")
	_send_key(KEY_ESCAPE)
	await get_tree().process_frame   # the closing redraw is deferred
	screen._ai_pending = false
	screen._maybe_schedule_ai()
	assert_true(screen._ai_pending, "closed: the AI's dwell is armed again")


func test_the_automatic_pass_waits() -> void:
	var g: MtgGame = screen.game
	g.active_player = 0
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.UPKEEP))
	g.priority_player = 0
	screen.mode = DuelScreen.Mode.NORMAL
	screen.stops.clear_all()
	assert_true(screen._auto_pass_applies(), "control: unstopped and quiet, it would go by itself")
	_open()
	assert_true(screen._modal_open(), "the mini help is modal against the table")
	assert_false(screen._auto_pass_applies(), "...so the phase does not sail past while you read")
	assert_false(screen._can_cancel(), "and the Situation Bar grows no Cancel under it")
	assert_false(screen._done_applies(), "nor lights its Done")
	_send_key(KEY_ESCAPE)
	assert_true(screen._auto_pass_applies(), "closed: the duel goes on exactly as before")


func test_a_standing_order_holds_and_resumes() -> void:
	var g: MtgGame = screen.game
	g.active_player = 0
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.UPKEEP))
	g.priority_player = 0
	screen.mode = DuelScreen.Mode.NORMAL
	screen.stops.clear_all()
	_open()
	screen._arm_advance(DuelScreen.Advance.DONE)
	var step := g.current_step()
	var priority := g.priority_player
	screen._drive_advance()
	screen._refresh()
	assert_eq(g.current_step(), step, "the order did not walk under the panel")
	assert_eq(g.priority_player, priority)
	_send_key(KEY_ESCAPE)
	await get_tree().process_frame   # the closing redraw drives the order on
	assert_true(g.current_step() != step or g.priority_player != priority,
		"closed: the order took the duel on")
	screen._cancel_advance()


# ---------------------------------------------------- how it looks --

func test_nothing_is_dimmed() -> void:
	# A hover help, not a modal veil: the catcher draws nothing, and its one
	# child is the panel.
	var help := _open()
	assert_eq(help.get_child_count(), 1)
	assert_eq(help.get_child(0), help._panel)
	assert_eq(help.mouse_filter, Control.MOUSE_FILTER_STOP, "but it takes the pointer")
	assert_eq(screen.get_child(screen.get_child_count() - 1), help,
		"last in the tree, so a click finds it before the table (picking is tree order)")


func test_it_opens_beside_where_the_menu_stood() -> void:
	var help := _open()
	await get_tree().process_frame
	var rect := help.panel_rect()
	assert_almost_eq(rect.position.x, AT.x + DuelMiniHelp.GAP, 0.5)
	assert_almost_eq(rect.position.y, AT.y, 0.5)


func test_reading_scale_grows_only_on_a_small_window() -> void:
	assert_eq(DuelMiniHelp.reading_scale(Vector2(1280, 800), Vector2(1280, 800)), 1.0, "a desk")
	assert_eq(DuelMiniHelp.reading_scale(Vector2(2560, 1600), Vector2(1280, 800)), 1.0,
		"never smaller than at a desk")
	assert_eq(DuelMiniHelp.reading_scale(Vector2(640, 480), Vector2(1280, 960)),
		DuelMiniHelp.MAX_SCALE, "a 640x480 handheld: the most it grows")
	assert_almost_eq(DuelMiniHelp.reading_scale(Vector2(1280, 720), Vector2(1422, 800)),
		1.111, 0.01, "a 1280x720 window")
	assert_eq(DuelMiniHelp.reading_scale(Vector2.ZERO, Vector2(1280, 800)), 1.0)


func test_place_keeps_it_inside_every_edge() -> void:
	var room := Vector2(640, 480)
	var panel := Vector2(380, 200)
	assert_eq(DuelMiniHelp.place(Vector2(10, 10), panel, room), Vector2(16, 10))
	var corner := DuelMiniHelp.place(Vector2(630, 470), panel, room)
	assert_eq(corner, Vector2(640 - 8 - 380, 480 - 8 - 200), "pulled in from the corner")
	var huge := DuelMiniHelp.place(Vector2(300, 300), Vector2(900, 900), room)
	assert_eq(huge, Vector2(8, 8), "never past the top-left either")


func _fit_case(size: Vector2i) -> void:
	var view := SubViewport.new()
	view.size = size
	add_child_autofree(view)
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]
	config.pace = 1000.0
	var duel: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	duel.config = config
	view.add_child(duel)
	await get_tree().process_frame
	var bounds := Rect2(Vector2.ZERO, Vector2(size))
	# Every subject, opened from the bottom-right corner — the worst place
	# a menu can stand — and the longest card help there is.
	var subjects := HelpPages.MINI_SUBJECTS.duplicate()
	for subject in subjects:
		duel._open_mini_help(subject, Vector2(size) - Vector2(4, 4))
		await get_tree().process_frame
		var help := duel._mini_help
		assert_true(bounds.encloses(help.panel_rect()),
			"%s at %s: the panel is on screen (%s)" % [subject, size, help.panel_rect()])
		assert_true(bounds.encloses(help._close.get_global_rect()),
			"%s at %s: Close is on screen" % [subject, size])
		help.dismiss()
	duel._show_mini_help("card_help", HelpPages.mini_card("Test", "Flying, first strike, "
		+ "trample, banding, protection from black"), Vector2(4, 4))
	await get_tree().process_frame
	var long_help := duel._mini_help
	assert_true(bounds.encloses(long_help.panel_rect()), "the longest help at %s" % size)
	var scroll := long_help._scroll
	var body := long_help._body
	assert_true(scroll.size.y + 0.5 >= body.size.y or scroll.get_v_scroll_bar().visible,
		"every line is reachable: it fits or it scrolls (%s / %s)" % [scroll.size.y, body.size.y])
	assert_lte(long_help.panel_rect().size.y, float(size.y) * DuelMiniHelp.MAX_HEIGHT_SHARE + 0.5,
		"it stays a small panel at %s" % size)
	long_help.dismiss()
	duel.queue_free()


func test_it_fits_a_640x480_handheld() -> void:
	await _fit_case(Vector2i(640, 480))


func test_it_fits_a_1280x720_window() -> void:
	await _fit_case(Vector2i(1280, 720))


func test_it_follows_a_resized_window() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(1280, 800)
	add_child_autofree(view)
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]
	config.pace = 1000.0
	var duel: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	duel.config = config
	view.add_child(duel)
	await get_tree().process_frame
	duel._open_mini_help(HelpPages.MINI_TERRITORY, Vector2(1200, 700))
	await get_tree().process_frame
	view.size = Vector2i(640, 480)
	for _i in 3:
		await get_tree().process_frame
	assert_true(Rect2(Vector2.ZERO, Vector2(640, 480)).encloses(duel._mini_help.panel_rect()),
		"still on screen after the window shrank (%s)" % duel._mini_help.panel_rect())
	duel._mini_help.dismiss()
	duel.queue_free()

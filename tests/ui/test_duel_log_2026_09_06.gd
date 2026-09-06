extends GutTest
## THE DUEL LOG — `L` during a duel ([DuelLog], and § THE DUEL LOG in
## `game/duel/duel_screen.gd`). `[QoL]`: the engine's audit trail, in a
## window the player can read, drag, copy and save.
##
## What is pinned: three doors onto ONE window (the key, the strip button,
## the window's own `×`) that never disagree about what is open; the
## window follows the log line by line; and it is NOT a modal — the table
## keeps every key and click with it up, which is the whole difference
## between a log and the Pause window.

var screen: DuelScreen


func before_each() -> void:
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]
	config.pace = 0.0
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame


func _send_key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	screen._unhandled_key_input(ev)


# ============================================================ the doors --

func test_l_opens_it_filled_with_the_log_so_far() -> void:
	var g: MtgGame = screen.game
	assert_false(screen.duel_log_is_open())
	var before := g.log_lines.size()
	assert_gt(before, 0, "a set-up game has already logged its seed")
	_send_key(KEY_L)
	assert_true(screen.duel_log_is_open(), "L opens the log")
	assert_eq(screen._duel_log.line_count(), before,
		"every line logged before the window opened is in it")
	assert_true(screen._duel_log.text().contains(g.log_lines[0]),
		"the first line is the first line")


func test_l_closes_it_again() -> void:
	_send_key(KEY_L)
	assert_true(screen.duel_log_is_open())
	_send_key(KEY_L)
	assert_false(screen.duel_log_is_open(), "L again closes it")
	assert_null(screen._duel_log)


func test_the_strip_button_is_the_same_switch() -> void:
	assert_not_null(screen._log_button, "the reserve strip carries the switch")
	assert_false(screen._log_button.button_pressed)
	screen._log_button.button_pressed = true      # fires `toggled`
	assert_true(screen.duel_log_is_open(), "pressing the button opens the window")
	screen._log_button.button_pressed = false
	assert_false(screen.duel_log_is_open(), "releasing it closes the window")


func test_the_button_follows_the_key_and_the_gadget() -> void:
	_send_key(KEY_L)
	assert_true(screen._log_button.button_pressed,
		"the key pressed the button too")
	screen._duel_log.dismiss()                    # the window's own ×
	await get_tree().process_frame
	assert_false(screen.duel_log_is_open())
	assert_false(screen._log_button.button_pressed,
		"the gadget released the button")
	_send_key(KEY_L)
	assert_true(screen.duel_log_is_open(), "and L opens a fresh one")
	_send_key(KEY_L)
	assert_false(screen._log_button.button_pressed)


func test_it_is_one_window_however_often_it_is_asked_for() -> void:
	_send_key(KEY_L)
	var first: DuelLog = screen._duel_log
	screen._open_duel_log()
	screen._log_button.button_pressed = true
	assert_eq(screen._duel_log, first, "a second open is a no-op")
	var count := 0
	for child in screen.get_children():
		if child is DuelLog:
			count += 1
	assert_eq(count, 1)


# ========================================================= it follows --

func test_it_follows_the_log_line_by_line() -> void:
	var g: MtgGame = screen.game
	_send_key(KEY_L)
	var window: DuelLog = screen._duel_log
	var before := window.line_count()
	g.log_line("SeatZero casts Grizzly Bears")
	g.log_line("== Turn 2 — SeatOne ==")
	assert_eq(window.line_count(), before + 2, "each line lands as it is logged")
	assert_true(window.text().ends_with("== Turn 2 — SeatOne ==\n")
		or window.text().ends_with("== Turn 2 — SeatOne =="),
		"the newest line is last: %s" % window.text().right(40))
	assert_true(window.title_text().contains(str(before + 2)),
		"the title counts the lines: %s" % window.title_text())


func test_a_bracket_in_a_line_is_text_not_markup() -> void:
	var g: MtgGame = screen.game
	_send_key(KEY_L)
	g.log_line("[decided for SeatZero] keeps [b]both[/b]")
	assert_true(screen._duel_log.text().contains("[b]both[/b]"),
		"the log is never parsed as BBCode")


func test_lines_logged_while_it_is_closed_are_there_when_it_opens() -> void:
	var g: MtgGame = screen.game
	_send_key(KEY_L)
	_send_key(KEY_L)
	g.log_line("SeatOne activates Strip Mine: Tundra")
	_send_key(KEY_L)
	assert_true(screen._duel_log.text().contains("Strip Mine: Tundra"),
		"the window is filled from the whole log, not from when it opened")
	assert_eq(screen._duel_log.line_count(), g.log_lines.size())


# ====================================================== not a modal --

func test_it_is_not_a_modal_and_not_a_dialog() -> void:
	_send_key(KEY_L)
	assert_false(screen._modal_open(), "the table is not held")
	assert_false(screen._dialogs_open(), "and it is no rung of the cancel ladder")
	assert_false(screen._can_cancel(), "nothing to cancel: the bar shows no Cancel")
	assert_false(screen.is_paused(), "and the duel is not paused")


func test_the_pause_key_still_works_under_it() -> void:
	_send_key(KEY_L)
	_send_key(KEY_Q)
	assert_true(screen.is_paused(), "Q reaches the table with the log open")
	assert_true(screen.duel_log_is_open(), "and the log stays where it was")
	_send_key(KEY_Q)
	assert_false(screen.is_paused())


func test_it_sits_under_every_question() -> void:
	# A log must never cover a dialog: dialogs are 200, the Pause 270.
	_send_key(KEY_L)
	assert_lt(screen._duel_log.z_index, 200)
	var combat := CombatWindow.new()
	var combat_z := combat.z_index
	combat.free()
	assert_gt(screen._duel_log.z_index, combat_z,
		"but over the combat window, which is furniture")
	assert_eq(screen._duel_log._text.focus_mode, Control.FOCUS_NONE,
		"the text never takes the keyboard from the table")


func test_it_opens_on_screen_and_clear_of_the_sidebar() -> void:
	_send_key(KEY_L)
	var window: DuelLog = screen._duel_log
	var room := screen.get_viewport_rect().size
	assert_true(window.position.x >= 0.0 and window.position.y >= 0.0)
	assert_true(window.position.x + window.size.x <= room.x + 0.5,
		"inside the viewport: %s in %s" % [window.position, room])
	assert_true(window.position.x > CardPreview.SIZE.x,
		"right of the sidebar's column")


# ==================================================== copy and save --

func test_save_writes_the_whole_log_beside_the_screenshots() -> void:
	var g: MtgGame = screen.game
	_send_key(KEY_L)
	g.log_line("SeatZero casts Lightning Bolt")
	var heard: Array[String] = []
	screen._duel_log.notice.connect(func(t: String) -> void: heard.append(t))
	var path := screen._duel_log.save_to_file()
	assert_true(path.begins_with(DuelLog.SAVE_PREFIX), path)
	assert_true(path.ends_with(".txt"))
	var file := FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "the file exists")
	var body := file.get_as_text()
	file.close()
	assert_true(body.contains("SeatZero casts Lightning Bolt"))
	assert_true(body.contains(g.log_lines[0]), "from the first line")
	assert_eq(body.split("\n", false).size(), g.log_lines.size(),
		"one line per log line")
	assert_eq(heard.size(), 1)
	assert_true(heard[0].begins_with("Duel log saved: "), heard[0])
	assert_eq(screen._prompt_label.text, heard[0],
		"the Situation Bar says where it went")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_copy_says_so_on_the_bar() -> void:
	_send_key(KEY_L)
	screen._duel_log.copy_to_clipboard()
	assert_true(screen._prompt_label.text.begins_with("Duel log copied"),
		screen._prompt_label.text)


# =========================================================== the strip --

func test_the_strip_button_wears_the_stone_and_a_glyph() -> void:
	var btn := screen._log_button
	assert_true(btn.toggle_mode)
	assert_eq(btn.focus_mode, Control.FOCUS_NONE,
		"a click on it never takes the keyboard from the table")
	assert_not_null(btn.icon)
	assert_eq(btn.custom_minimum_size, ArrangeButton.FACE,
		"the same face as its two neighbours")
	assert_true(btn.tooltip_text.contains("(L)"), "the tooltip names the key")
	# Beside Expand, not under it (the reserve has width and no height).
	assert_eq(btn.offset_top, screen._expand_button.offset_top)
	assert_lt(btn.offset_right, screen._expand_button.offset_left,
		"to the left of Expand with a gap")


func test_the_glyph_is_a_page_of_lines() -> void:
	var image := DuelLog.glyph().get_image()
	assert_eq(image.get_size(), DuelLog.GLYPH)
	var ink := 0
	var lit := 0
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a == 0.0:
				continue
			if c.is_equal_approx(DuelLog.GLYPH_INK):
				ink += 1
			elif c.is_equal_approx(DuelLog.GLYPH_LIT):
				lit += 1
	assert_gt(lit, ink, "a pale page carrying dark rules, not the other way")
	assert_gt(ink, 40, "the outline and four lines of text")

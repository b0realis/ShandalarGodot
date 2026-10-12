extends GutTest
## THE SITUATION BAR'S NOTES, THE PAUSE KEY AND THE KEY NAMES (campaign
## 2026-10-12, findings b6-2, b6-9, r3-9 and b6-5).
##
## b6-2: the pause key (Q, ArkOS Select, the pad's Start) opens the pause
## menu "whatever else is going on" — under a held question too, where it
## used to do nothing.
## b6-9: the notes the player asked for — "Sound muted", the screenshot's
## path, "Count library cards" — are held on the bar for a moment like a
## refusal (in the bar's own ink), instead of being wiped by the next
## redraw within a frame.
## r3-9: a screenshot or a saved duel log that could not be written says so
## in the refusal's red, instead of naming a file that is not there.
## b6-5: the menus and the duel log's buttons name the key the player has
## actually bound, not the default.

var screen: DuelScreen
var _saved_controls: Variant = null


func before_each() -> void:
	_saved_controls = Settings.get_value(Controls.SETTINGS_KEY, null) \
		if Settings.has_value(Controls.SETTINGS_KEY) else null
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]
	config.pace = 1000.0
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	var g: MtgGame = screen.game
	g.active_player = 1          # the computer's turn: redraws come by themselves
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	g.priority_player = 1


func after_each() -> void:
	GameAudio.set_hushed(false)
	Controls.reset()
	if _saved_controls != null:
		Settings.set_value(Controls.SETTINGS_KEY, _saved_controls)
		Controls.apply()


func _key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	screen._unhandled_key_input(ev)


func _held_question() -> PlayerChoice:
	var ask := PlayerChoice.new(PlayerChoice.Kind.YES_NO, 0, "Pay {B}{B} to keep Junún Efreet?", true)
	ask.source = "Junún Efreet"
	ask.step = Mtg.Step.UPKEEP
	screen.game.awaiting_choice = ask
	screen._build_choice_overlay(ask)
	return ask


func _drop_question() -> void:
	screen._close_choice_overlay()
	screen.game.awaiting_choice = null


# ------------------------------------------------- b6-2, the pause key --

func test_q_opens_the_pause_menu_under_a_held_question() -> void:
	_held_question()
	_key(KEY_Q)
	assert_true(screen.is_paused(), "Q opens the pause menu over the question")
	assert_not_null(screen.game.awaiting_choice, "the question is still there to answer")
	_key(KEY_Q)
	assert_false(screen.is_paused(), "and Q closes it again")
	assert_not_null(screen._choice_overlay, "back to the question")
	_drop_question()


func test_the_pads_start_opens_the_pause_menu_under_a_held_question() -> void:
	_held_question()
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_START
	pad.pressed = true
	screen._unhandled_input(pad)
	assert_true(screen.is_paused(), "Start opens the pause menu over the question")
	screen._close_pause()
	_drop_question()


## ...and over the full-size card reader: the reader sees every key first,
## and the pause key closes it and goes on to the duel's pause menu.
func test_q_closes_the_reader_and_opens_the_pause_menu() -> void:
	var bear := CardInstance.new(CardRegistry.get_card("Grizzly Bears"), 99001, 0)
	screen._card_preview.show_card(bear)
	assert_true(screen._fullscreen_card.open_card(true), "control: the reader opened")
	var ev := InputEventKey.new()
	ev.keycode = KEY_Q
	ev.pressed = true
	screen._fullscreen_card._input(ev)      # the reader's own pass comes first
	assert_false(screen._fullscreen_card.is_open(), "the pause key closed the reader")
	screen._unhandled_key_input(ev)         # ...and the key went on to the duel
	assert_true(screen.is_paused(), "the pause menu opened")
	screen._close_pause()


func test_the_pads_start_closes_the_reader_and_opens_the_pause_menu() -> void:
	var bear := CardInstance.new(CardRegistry.get_card("Grizzly Bears"), 99002, 0)
	screen._card_preview.show_card(bear)
	assert_true(screen._fullscreen_card.open_card(true), "control: the reader opened")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_START
	pad.pressed = true
	screen._unhandled_input(pad)
	assert_false(screen._fullscreen_card.is_open(), "Start closed the reader")
	assert_true(screen.is_paused(), "and opened the pause menu")
	screen._close_pause()


## Other keys still belong to the reader: Space does not reach the duel.
func test_other_keys_stay_with_the_reader() -> void:
	var bear := CardInstance.new(CardRegistry.get_card("Grizzly Bears"), 99003, 0)
	screen._card_preview.show_card(bear)
	assert_true(screen._fullscreen_card.open_card(true))
	_key(KEY_M)
	assert_true(screen._fullscreen_card.is_open(), "M is not the reader's way out")
	assert_false(GameAudio.is_hushed(), "and did not reach the duel's mute")
	screen._fullscreen_card.dismiss()


## The coin toss and the opening hand: the pause key still opens the pause
## menu (Exit, Main menu), Esc or the key closes it, and its Concede does
## nothing to a duel that has not begun.
func test_the_pause_key_answers_during_the_coin_toss() -> void:
	screen._toss_active = true
	_key(KEY_Q)
	assert_true(screen.is_paused(), "Q opens the pause menu over the toss")
	_key(KEY_ESCAPE)
	assert_false(screen.is_paused(), "Esc closes it")
	_key(KEY_SPACE)
	assert_false(screen.is_paused(), "and nothing else answers")
	_key(KEY_Q)
	assert_true(screen.is_paused())
	screen._on_pause_chosen(DuelPause.Action.CONCEDE)
	assert_false(screen.is_paused(), "the window closed")
	assert_null(screen._concede_dialog, "no concede question before the duel begins")
	assert_false(screen.game.game_over, "nothing conceded")
	assert_eq(screen._prompt_label.text, DuelScreen.TOSS_CONCEDE_NOTE)
	screen._toss_active = false


func test_the_number_keys_still_answer_under_the_question() -> void:
	_held_question()
	# The 1 key is the question's own: it is not the pause key, and the
	# overlay still owns the digits (s30's number keys).
	assert_eq(DuelScreen.choice_line_for_digit(screen.game.awaiting_choice, 1), 0)
	assert_false(screen.is_paused())
	_drop_question()


# ------------------------------------------------ b6-9, the bar's notes --

func test_the_mute_note_survives_the_next_redraw() -> void:
	_key(KEY_M)
	assert_eq(screen._prompt_label.text, "Sound muted", "control: the note went up")
	screen._refresh()
	assert_eq(screen._prompt_label.text, "Sound muted", "the note is still on the bar after a redraw")
	assert_ne(screen._prompt_label.get_theme_color("font_color"), DuelScreen.WARNING,
		"in the bar's own ink, not the refusal's red")


func test_the_library_count_survives_the_next_redraw() -> void:
	screen._library_menu.set_meta("pid", 1)
	screen._on_library_menu_chosen(0)
	var said := screen._prompt_label.text
	assert_string_contains(said, "cards", "control: the count went up")
	screen._refresh()
	assert_eq(screen._prompt_label.text, said, "the count is still on the bar after a redraw")


func test_a_note_gives_the_bar_back_when_it_runs_out() -> void:
	_key(KEY_M)
	screen._on_flash_expired()
	assert_ne(screen._prompt_label.text, "Sound muted", "the status line has the bar again")


# --------------------------------------- r3-9, saves that did not happen --

func test_a_screenshot_that_was_saved_is_named_on_the_bar() -> void:
	var image := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	var path := "user://c2_f_duel_shot.png"
	screen._save_screenshot(image, path)
	assert_true(FileAccess.file_exists(path), "control: the file was written")
	assert_eq(screen._prompt_label.text, "Screenshot: %s" % ProjectSettings.globalize_path(path))
	screen._refresh()
	assert_string_contains(screen._prompt_label.text, "Screenshot:", "held over the next redraw")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_a_screenshot_that_could_not_be_saved_says_so() -> void:
	var path := "user://c2_f_duel_never.png"
	screen._save_screenshot(Image.new(), path)
	assert_false(FileAccess.file_exists(path), "control: nothing was written")
	assert_string_contains(screen._prompt_label.text, "Screenshot could not be saved",
		"the bar says the screenshot failed (it reads '%s')" % screen._prompt_label.text)
	assert_false(screen._prompt_label.text.contains(ProjectSettings.globalize_path(path)),
		"and names no file")
	assert_eq(screen._prompt_label.get_theme_color("font_color"), DuelScreen.WARNING, "in red")


func test_a_duel_log_that_could_not_be_saved_says_so_in_red() -> void:
	screen._toggle_duel_log()
	var log_window: DuelLog = screen._duel_log
	assert_not_null(log_window, "control: the log window is up")
	var path := log_window.save_to_file("user://c2_no_such_folder/duel_log_")
	assert_eq(path, "", "nothing was saved")
	assert_string_contains(screen._prompt_label.text, "could not be saved")
	assert_eq(screen._prompt_label.get_theme_color("font_color"), DuelScreen.WARNING, "in red")


func test_a_duel_log_that_was_saved_is_named_on_the_bar() -> void:
	screen._toggle_duel_log()
	var log_window: DuelLog = screen._duel_log
	var path := log_window.save_to_file()
	assert_ne(path, "", "control: saved")
	assert_true(FileAccess.file_exists(path))
	assert_string_contains(screen._prompt_label.text, "Duel log saved")
	assert_ne(screen._prompt_label.get_theme_color("font_color"), DuelScreen.WARNING)
	screen._refresh()
	assert_string_contains(screen._prompt_label.text, "Duel log saved", "held over the next redraw")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# ---------------------------------------------- b6-5, the keys' names --

func test_the_menu_accelerator_follows_a_rebinding() -> void:
	assert_eq(OS.get_keycode_string(DuelOptions.menu_toggle_accelerator("ShowIDTagsOnCards")),
		"Ctrl+T", "control: the default")
	var f5 := InputEventKey.new()
	f5.keycode = KEY_F5
	f5.pressed = true
	assert_true(Controls.bind("duel_id_tags", f5), "control: the rebinding took")
	assert_eq(OS.get_keycode_string(DuelOptions.menu_toggle_accelerator("ShowIDTagsOnCards")),
		"F5", "the menu names the key that now toggles ID tags")


func test_a_dark_toggle_names_no_key() -> void:
	assert_eq(DuelOptions.menu_toggle_accelerator("ShowInvisibleEffectCards"), KEY_NONE)


func test_the_log_buttons_name_the_bound_key() -> void:
	var f6 := InputEventKey.new()
	f6.keycode = KEY_F6
	f6.pressed = true
	assert_true(Controls.bind("duel_log", f6), "control: the rebinding took")
	var strip := DuelLog.button(func(_on: bool) -> void: pass)
	assert_string_contains(strip.tooltip_text, "F6", "the strip button names the log's key")
	assert_false(strip.tooltip_text.contains("(L)"))
	strip.free()
	var window := DuelLog.new()
	add_child_autofree(window)
	var tips := PackedStringArray()
	for b in window.find_children("*", "BaseButton", true, false):
		tips.append((b as Control).tooltip_text)
	var joined := "\n".join(tips)
	assert_false(joined.contains("(L)"), "no button names the old key: %s" % joined)
	assert_string_contains(joined, "F6", "the close gadget names the log's key")

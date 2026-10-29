extends GutTest
## ONE DEDICATED BUTTON UNDER THE LARGE CARD (the polish pass, 2026-10-28;
## P3 item 1). The owner: *"All new duel screen options should be only
## accessible via a dedicated button under a large card in the duel
## screen."* — round "open items": *"every new duel-screen option reached
## only through ONE dedicated button under the large card"*.
##
## The reserve strip under the Showcase ([member DuelScreen._qol_reserve])
## carries it beside the log, Expand and Arrange; it opens ONE window
## ([DuelScreenOptions.window]) holding the four new switches; nothing else
## — the Options screen's lists, the mini-menus, the Pause window — names
## them.

var screen: DuelScreen
const SCREEN := Vector2(1280, 800)


func after_each() -> void:
	await get_tree().process_frame


func _open(test := false) -> void:
	var config := DuelConfig.hotseat_default()
	if test:
		var position := DuelPosition.new()
		position.add(0, DuelPosition.TABLE, "Forest")
		position.active_player = 0
		position.step = Mtg.Step.MAIN1
		config = config.for_test(position, 6060)
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.size = SCREEN
	await get_tree().process_frame
	await get_tree().process_frame


func _button() -> Button:
	return screen._qol_reserve.find_child("DuelScreenOptionsButton", true, false) as Button


func test_the_button_stands_under_the_large_card() -> void:
	await _open()
	var btn := _button()
	assert_not_null(btn, "the reserve strip carries the button")
	assert_eq(screen._screen_options_button, btn)
	var card: Rect2 = screen._card_preview.get_global_rect()
	var rect := btn.get_global_rect()
	assert_gte(rect.position.y, card.end.y - 0.5, "under the card")
	assert_true(rect.position.x >= card.position.x - 0.5 and rect.end.x <= card.end.x + 0.5,
		"within the card's column: %s under %s" % [rect, card])
	assert_eq(btn.tooltip_text, DuelScreenOptions.BUTTON_TIP)


func test_it_shares_the_row_with_the_other_three_without_touching_them() -> void:
	await _open(true)   # a test duel's strip is the fullest
	var mine := _button().get_global_rect()
	var others: Array = [screen._log_button, screen._expand_button, screen._arrange_button]
	var strip: Node = screen._qol_reserve.find_child("TestStrip", true, false)
	assert_not_null(strip, "control: a test duel's strip")
	for child in strip.get_children():
		others.append(child)
	for other in others:
		var rect: Rect2 = (other as Control).get_global_rect()
		assert_false(mine.intersects(rect),
			"clear of %s (%s vs %s)" % [(other as Node).name, mine, rect])
		assert_almost_eq(rect.position.y, mine.position.y, 8.0, "one row")


func test_it_opens_one_window_with_the_four_switches() -> void:
	await _open()
	_button().pressed.emit()
	await get_tree().process_frame
	var window: OriginalDialog = screen._screen_options_dialog
	assert_not_null(window, "the window is up")
	for node_name in ["LogTargets", "Colorblind", "UiScale", "AttackAll", "AttackAllBinding"]:
		assert_not_null(window.find_child(node_name, true, false), "it holds %s" % node_name)
	_button().pressed.emit()
	var count := 0
	for child in screen.get_children():
		if child is OriginalDialog and not child.is_queued_for_deletion():
			count += 1
	assert_eq(count, 1, "a second press opens no second window")


func test_escape_closes_it() -> void:
	await _open()
	_button().pressed.emit()
	await get_tree().process_frame
	screen._on_escape()
	assert_null(screen._screen_options_dialog, "Escape peels it like the 1997 panel")


func test_a_switch_writes_its_key_at_once() -> void:
	var had := Settings.has_value(DuelScreenOptions.COLORBLIND_KEY)
	var was: Variant = Settings.get_value(DuelScreenOptions.COLORBLIND_KEY, null)
	await _open()
	_button().pressed.emit()
	await get_tree().process_frame
	var check := screen._screen_options_dialog.find_child("Colorblind", true, false) as CheckBox
	check.button_pressed = not check.button_pressed
	assert_eq(DuelScreenOptions.colorblind_mana(), check.button_pressed)
	if had:
		Settings.set_value(DuelScreenOptions.COLORBLIND_KEY, was)
	else:
		Settings.clear_value(DuelScreenOptions.COLORBLIND_KEY)


func test_its_foot_opens_the_1997_panel() -> void:
	await _open()
	_button().pressed.emit()
	await get_tree().process_frame
	var door: Button = null
	for b in screen._screen_options_dialog.find_children("*", "Button", true, false):
		if (b as Button).text == DuelScreenOptions.DUEL_OPTIONS_DOOR:
			door = b
	assert_not_null(door, "a door onto the 1997 Duel Options")
	door.pressed.emit()
	await get_tree().process_frame
	assert_null(screen._screen_options_dialog, "this one closes")
	assert_not_null(screen._options_dialog, "the 1997 one opens")


func test_nothing_else_names_the_new_switches() -> void:
	var options := FileAccess.get_file_as_string("res://game/options_screen.gd")
	var pause := FileAccess.get_file_as_string("res://game/duel/duel_pause.gd")
	var menus := FileAccess.get_file_as_string("res://game/duel/card_menu.gd")
	var territory := FileAccess.get_file_as_string("res://game/duel/territory_menu.gd")
	for key in [DuelScreenOptions.LOG_TARGETS_KEY, DuelScreenOptions.COLORBLIND_KEY,
			DuelScreenOptions.UI_SCALE_KEY, DuelScreenOptions.ATTACK_ALL_KEY,
			"DuelScreenOptions"]:
		for text in [options, pause, menus, territory]:
			assert_false(text.contains(key), "%s is the button's alone" % key)


func test_the_replay_table_hides_it_with_the_other_strip_buttons() -> void:
	var table: MpnDuelTable = MpnDuelTable.new()
	add_child_autofree(table)
	await get_tree().process_frame
	assert_not_null(table._screen_options_button)
	assert_false(table._screen_options_button.visible,
		"a replay has no live duel to set up: hidden like the log and Arrange")

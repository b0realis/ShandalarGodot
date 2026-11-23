extends GutTest
## THE TITLE SINCE 0.70.9: the notice a game with no 1997 skin gives once
## a start.


func after_each() -> void:
	MainScreen.skin_warning = false
	MainScreen._no_skin_told = false
	Settings.clear_value(MainScreen.NO_SKIN_SETTING)


func _title() -> MainScreen:
	var title: MainScreen = load("res://game/main.tscn").instantiate()
	add_child_autofree(title)
	await get_tree().process_frame
	return title


func test_a_game_with_no_skin_says_so_once_a_start_and_can_be_told_to_stop() -> void:
	MainScreen.skin_warning = true
	var title := await _title()
	var notice := title.find_child("NoSkinNotice", true, false)
	if MainScreen.has_skin():
		assert_null(notice, "a skin is worn: nothing to say")
		return
	assert_not_null(notice)
	var said := "\n".join(notice.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text))
	assert_string_contains(said, "No 1997 skin")
	assert_string_contains(said, "Build from a 1997 install...")
	for label: Label in notice.find_children("*", "Label", true, false):
		assert_eq(label.get_theme_constant("shadow_offset_x"), 0, "plain letters")
	assert_not_null(notice.find_child("OK", true, false))
	# Once a start: the title built again says nothing.
	title.free()
	title = await _title()
	assert_null(title.find_child("NoSkinNotice", true, false))
	# Never again, when asked.
	MainScreen._no_skin_told = false
	title.free()
	title = await _title()
	(title.find_child("NoSkinNever", true, false) as Button).pressed.emit()
	assert_true(bool(Settings.get_value(MainScreen.NO_SKIN_SETTING, false)))
	MainScreen._no_skin_told = false
	title.free()
	title = await _title()
	assert_null(title.find_child("NoSkinNotice", true, false), "silenced for good")


func test_the_suite_itself_is_not_told() -> void:
	MainScreen.skin_warning = false
	var title := await _title()
	assert_null(title.find_child("NoSkinNotice", true, false))

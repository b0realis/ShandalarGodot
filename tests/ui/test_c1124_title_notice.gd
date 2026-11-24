extends GutTest
## THE NO-SKIN NOTICE (0.70.9), after the bug pass of 2026-11-24: it waits
## its turn behind another notice of the title, and it names a way the
## device really has.


func after_each() -> void:
	MainScreen.skin_warning = false
	MainScreen._no_skin_told = false
	Settings.clear_value(MainScreen.NO_SKIN_SETTING)


func _title() -> MainScreen:
	var title: MainScreen = load("res://game/main.tscn").instantiate()
	add_child_autofree(title)
	await get_tree().process_frame
	return title


func test_the_words_name_a_way_the_device_has() -> void:
	var here := MainScreen.no_skin_words(true)
	assert_string_contains(here, SkinBuilderWindow.OPTIONS_BUTTON, "the button Options really has")
	assert_string_contains(here, "next start")
	var elsewhere := MainScreen.no_skin_words(false)
	assert_false(elsewhere.contains("under Skin"), "no Build button on a phone or a web page")
	assert_string_contains(elsewhere, "on a computer")
	assert_string_contains(elsewhere, "Choose...")
	for words: String in [here, elsewhere]:
		assert_false(words.contains("tools"), "the game itself does it: no tool is the way")
		assert_false(words.contains(".py"))
		assert_string_contains(words, "Everything plays the same without it.")
	assert_eq(MainScreen.no_skin_words(), here if SkinBuilderWindow.offered() else elsewhere)


func test_it_waits_behind_another_notice_and_takes_the_ring_after() -> void:
	var title := await _title()
	if MainScreen.has_skin():
		assert_null(title.find_child("NoSkinNotice", true, false), "a skin is worn: nothing to say")
		return
	var earlier := UiChrome.explain_popup(title, "Options", "The settings file could not be read.")
	var earlier_ok := earlier.find_child("OK", true, false) as Button
	MainScreen.skin_warning = true
	title._tell_no_skin()
	title._tell_no_skin()
	await get_tree().process_frame
	assert_null(title.find_child("NoSkinNotice", true, false), "one notice at a time")
	assert_false(MainScreen._no_skin_told, "not said yet")
	assert_eq(get_viewport().gui_get_focus_owner(), earlier_ok, "the ring stays on the notice shown")
	earlier_ok.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var notice := title.find_child("NoSkinNotice", true, false)
	assert_not_null(notice, "its turn once the other has closed")
	if notice == null:
		return
	assert_eq(title.find_children("NoSkinNotice*", "", true, false).size(), 1, "once")
	assert_eq(get_viewport().gui_get_focus_owner(), notice.find_child("OK", true, false))
	assert_true(MainScreen._no_skin_told)


func test_a_title_that_leaves_with_a_notice_up_says_nothing_later() -> void:
	var title := await _title()
	if MainScreen.has_skin():
		pass_test("a skin is worn: nothing to say")
		return
	UiChrome.explain_popup(title, "Options", "The settings file could not be read.")
	MainScreen.skin_warning = true
	title._tell_no_skin()
	title.free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(MainScreen._no_skin_told, "kept for the next title")
	title = await _title()
	assert_not_null(title.find_child("NoSkinNotice", true, false))

extends GutTest
## THE CARD PACKS PAGE STAYS ALIVE (campaign 2026-11-26). Enable, Disable
## and Rescan rebuilt the card pool on the drawing thread: the window stood
## frozen 0.15 to 1.7 seconds a press with nothing said. The pool is now
## built on a thread, an hourglass and "Working..." beside Back, the
## buttons that change the packs held until it is in. And the foot note
## names `Get Card Packs...` only where Options has that button.

var _was_enabled: Array[String] = []


func before_each() -> void:
	_was_enabled = Settings.enabled_card_packs()
	CardPacks.set_enabled_many(CardPacks.available_ids(), false)
	CardPacks.set_current_deck_names([])
	CardRegistry.ensure_loaded()


func after_each() -> void:
	CardPacksScreen.on_web = OS.has_feature("web")
	CardPacks.set_current_deck_names([])
	Settings.set_enabled_card_packs(_was_enabled)
	CardPacks._configure_registry()
	CardRegistry.ensure_loaded()


func _page() -> CardPacksScreen:
	var screen: CardPacksScreen = load("res://game/card_packs_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	return screen


func _button(root: Node, node: String) -> Button:
	return root.find_child(node, true, false) as Button


## Frames until the page is done working (a bound on frames).
func _until_idle(page: CardPacksScreen) -> int:
	var frames := 0
	while page.is_working() and frames < 3000:
		await get_tree().process_frame
		frames += 1
	return frames


func _held(page: CardPacksScreen) -> bool:
	for node: String in ["Rescan", "AddPack", "EnablePack1", "DisablePack1", "EnablePack2", "DisablePack2",
			"EnablePack10", "DisablePack10"]:
		if not _button(page, node).disabled:
			return false
	return true


func test_enable_builds_the_pool_behind_an_hourglass() -> void:
	if not OS.has_feature("threads"):
		pass_test("no threads here: the pool is built in place, as before")
		return
	var page := await _page()
	var working := page.find_child("Working", true, false) as Control
	assert_false(working.visible, "nothing to wait for yet")
	assert_false(CardRegistry.has_card("Chaos Orb"))
	_button(page, "EnablePack1").pressed.emit()
	# The press came back with the pool still being built: no frozen frame.
	assert_true(page.is_working(), "the press does not wait for the pool")
	assert_true(CardPacks.is_enabled(CardPacks.ID), "the setting is written at once")
	assert_true(working.visible, "the hourglass and its words show")
	assert_not_null(working.find_child("Hourglass", true, false))
	assert_eq((working.find_child("WorkingWords", true, false) as Label).text, "Working...")
	assert_true(_held(page), "the buttons that change the packs are held")
	assert_false(_button(page, "Back").disabled, "Back is never held")
	var frames := await _until_idle(page)
	assert_gt(frames, 0, "the window drew frames meanwhile")
	assert_false(page.is_working())
	assert_false(working.visible)
	assert_true(CardRegistry.has_card("Chaos Orb"), "the pack's cards are in")
	assert_true(_button(page, "EnablePack1").disabled)
	assert_false(_button(page, "DisablePack1").disabled, "and the pack can be switched off again")
	assert_false(_button(page, "Rescan").disabled)
	assert_string_contains((page.find_child("Pack1Status", true, false) as Label).text, "Status: Enabled")


func test_disable_and_the_warnings_disable_anyway_go_the_same_way() -> void:
	if not OS.has_feature("threads"):
		pass_test("no threads here")
		return
	CardPacks.set_enabled(CardPacks.ID, true)
	var page := await _page()
	_button(page, "DisablePack1").pressed.emit()
	assert_true(page.is_working())
	assert_false(CardPacks.is_enabled(CardPacks.ID))
	await _until_idle(page)
	assert_false(CardRegistry.has_card("Chaos Orb"))
	assert_false(_button(page, "EnablePack1").disabled)
	# With a deck that needs it: the warning first, then the same wait.
	CardPacks.set_enabled(CardPacks.ID, true)
	CardPacks.set_current_deck_names(["Chaos Orb"])
	_button(page, "DisablePack1").pressed.emit()
	await get_tree().process_frame
	assert_true(is_instance_valid(page._warning))
	assert_false(page.is_working(), "the first click only warns")
	_button(page._warning, "DisableAnyway").pressed.emit()
	assert_false(CardPacks.is_enabled(CardPacks.ID))
	assert_true(page.is_working())
	await _until_idle(page)
	assert_false(CardRegistry.has_card("Chaos Orb"))


func test_rescan_goes_the_same_way() -> void:
	if not OS.has_feature("threads"):
		pass_test("no threads here")
		return
	CardPacks.set_enabled(CardPacks.ID, true)
	var page := await _page()
	var seen := [0]
	var count := func() -> void: seen[0] += 1
	CardPacks.rescanned.connect(count)
	_button(page, "Rescan").pressed.emit()
	# The hourglass first, the folder read once it has been drawn.
	assert_true(page.is_working())
	assert_true((page.find_child("Working", true, false) as Control).visible)
	assert_true(_held(page))
	assert_eq(seen[0], 0)
	await wait_process_frames(3)
	assert_eq(seen[0], 1, "the folder was read")
	assert_true(page.is_working(), "and the pool is built behind the hourglass")
	assert_true(CardRegistry.is_loading())
	assert_true(_held(page))
	await _until_idle(page)
	CardPacks.rescanned.disconnect(count)
	assert_eq(seen[0], 1, "once")
	assert_true(CardRegistry.has_card("Chaos Orb"))
	assert_false(_button(page, "Rescan").disabled)
	assert_false(_button(page, "DisablePack1").disabled)


func test_a_second_press_while_working_does_nothing() -> void:
	if not OS.has_feature("threads"):
		pass_test("no threads here")
		return
	var page := await _page()
	page._switch(CardPacks.ID, true)
	assert_true(page.is_working())
	page._switch(FallenEmpiresPack.ID, true)
	page._rescan()
	assert_false(CardPacks.is_enabled(FallenEmpiresPack.ID), "held, whatever calls it")
	await _until_idle(page)


func test_a_pool_built_by_someone_else_ends_the_wait_at_once() -> void:
	var page := await _page()
	_button(page, "EnablePack1").pressed.emit()
	# Something asks for a card and so builds the pool in place.
	CardRegistry.ensure_loaded()
	CardPacks.rescanned.emit()
	assert_false(page.is_working(), "the page saw that the pool is in")
	assert_false(_button(page, "DisablePack1").disabled)
	_button(page, "DisablePack1").pressed.emit()
	assert_false(CardPacks.is_enabled(CardPacks.ID), "and takes the next press")
	await _until_idle(page)


func test_a_page_left_while_working_leaves_a_whole_pool() -> void:
	var page := await _page()
	_button(page, "EnablePack1").pressed.emit()
	page.free()
	CardRegistry.ensure_loaded()
	assert_true(CardRegistry.has_card("Chaos Orb"))


func test_the_foot_note_names_the_button_only_where_options_has_it() -> void:
	CardPacksScreen.on_web = false
	var page := await _page()
	var note := (page.find_child("LocalOnly", true, false) as Label).text
	assert_string_contains(note, "Options > Get Card Packs... builds them here in the game. Or build them yourself with tools/pack_1_dotp_complete.py")
	page.free()
	CardPacksScreen.on_web = true
	page = await _page()
	note = (page.find_child("LocalOnly", true, false) as Label).text
	assert_eq(note.find("Get Card Packs"), -1, "a browser's Options has no such button")
	assert_string_contains(note, "Packs are not distributed with the game. Build them yourself with tools/pack_1_dotp_complete.py")
	assert_string_contains(note, "place the exact ZIP here, then Rescan.")


func test_back_stays_in_the_middle_of_its_row() -> void:
	var page := await _page()
	await get_tree().process_frame
	var back := _button(page, "Back")
	var row := back.get_parent() as Control
	assert_almost_eq(back.get_global_rect().get_center().x, row.get_global_rect().get_center().x, 1.5)
	var working := page.find_child("Working", true, false) as Control
	working.visible = true
	await get_tree().process_frame
	assert_almost_eq(back.get_global_rect().get_center().x, row.get_global_rect().get_center().x, 1.5,
		"the hourglass moves nothing")
	assert_true(row.get_global_rect().grow(1.0).encloses(working.get_global_rect()), "and stays in the row")

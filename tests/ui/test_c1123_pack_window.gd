extends GutTest
## THE CARD PACKS WINDOW (campaign 2026-11-23): eleven rows, a tick, OK —
## and a bar that says how far along it is. The window is run whole
## against a stand-in for the game and a transport that answers from a
## table (`tests/support/c1123_pack_fakes.gd`): no socket, no rescan of the
## real catalogue, no zip mounted, and a card folder in the test profile.

const Fakes := preload("res://tests/support/c1123_pack_fakes.gd")
const SCRATCH := "user://c1123_pack_window"

var _host: Fakes.Host
var _stage: Control


func before_each() -> void:
	Fakes.wipe(SCRATCH)
	_host = Fakes.host(SCRATCH)
	_host.free = 80 * 1024 * 1024 * 1024
	# Every reading of the clock is past the wait between two questions:
	# a frame of the window is a frame of work.
	_host.tick = 600
	_stage = Control.new()
	_stage.size = Vector2(1280, 800)
	add_child_autofree(_stage)


func after_each() -> void:
	PackRecipes.packaging = PackRecipes.PACKAGING
	Fakes.wipe(SCRATCH)


func _open() -> PackBuilderWindow:
	var window: PackBuilderWindow = PackBuilderWindow.open_on(_stage, _host)
	await wait_process_frames(2)
	return window


func _teach(ids: Array) -> void:
	for id: String in ids:
		_host.net.teach(PackRecipes.recipe(id)["jobs"])


func _check(window: Control, id: String) -> CheckBox:
	return window.find_child("Check_" + id, true, false) as CheckBox


func _check_named(window: Control, node: String) -> CheckBox:
	return window.find_child(node, true, false) as CheckBox


func _state(window: Control, id: String) -> String:
	return (window.find_child("State_" + id, true, false) as Label).text


func _text(window: Control, node: String) -> String:
	return (window.find_child(node, true, false) as Label).text


func _button(window: Control, node: String) -> Button:
	return window.find_child(node, true, false) as Button


## Frames until the window is back to choosing (a bound on frames).
func _until_done(window: PackBuilderWindow, most := 3000) -> void:
	var frames := 0
	while window.mode == "working" and frames < most:
		await get_tree().process_frame
		frames += 1


func _escape() -> void:
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	get_viewport().push_input(ev)


# ------------------------------------------------------------ the rows --

func test_eleven_rows_with_their_real_names_states_and_sizes() -> void:
	_host.states["pack-3"] = {"state": "installed", "note": ""}
	_host.states["pack-5"] = {"state": "refused", "note": "this is Pack 5 version 0.9.0"}
	_host.states["pack-7"] = {"state": "elsewhere", "note": ""}
	# Twelve pictures of Pack 6 left by an earlier, unfinished run.
	for i in 12:
		Fakes.write(_host.cache_root().path_join("pack-6/por/picture_%d.jpg" % i), Fakes.jpeg("x"))
	var window := await _open()
	var titles: Array = []
	for id: String in PackRecipes.ids():
		titles.append(_check(window, id).text)
	assert_eq(titles, ["1997 card pictures", "Pack 1: DotP Complete", "Pack 2: Fallen Empires",
		"Pack 3: Ice Age", "Pack 4: Homelands", "Pack 5: Alliances", "Pack 6: Portal & Second Age",
		"Pack 7: Fifth Edition", "Pack 8: The Mirage Block", "Pack 9: The Tempest Block",
		"Pack 10: The Urza Block"])
	assert_eq(_state(window, "base"), "Not here")
	assert_eq(_state(window, "pack-3"), "Installed")
	assert_true(_check(window, "pack-3").disabled, "what is installed is not built again")
	assert_eq(_state(window, "pack-5"), "Here, but refused")
	assert_eq((window.find_child("State_pack-5", true, false) as Label).tooltip_text, "this is Pack 5 version 0.9.0")
	assert_false(_check(window, "pack-5").disabled, "a refused pack can be built anew")
	assert_eq(_state(window, "pack-6"), "Part downloaded: 12 of 760")
	assert_eq(_state(window, "pack-7"), "In use from another place")
	assert_false(_check(window, "pack-7").disabled)
	assert_eq(_text(window, "Download_pack-2"), "204 pictures, 20 MB")
	assert_eq(_text(window, "Kept_pack-2"), "41 MB")
	assert_eq(_text(window, "Download_base"), "1794 pictures, 189 MB")
	var intro := _text(window, "Intro")
	assert_string_contains(intro, "Scryfall (scryfall.com)")
	assert_string_contains(intro, "internet")
	assert_string_contains(intro, GamePaths.shown(_host.folder()))
	assert_string_contains(intro, "about 960 MB to download and 1.5 GB on disk")


func test_opening_clears_what_a_closed_game_left_half_written() -> void:
	var work := _host.folder().path_join(PackBuildHost.BUILDING)
	for name: String in ["Pack-6-Portal.zip.part", "Pack-2-Fallen-Empires.zip"]:
		Fakes.write(work.path_join(name), "half".to_utf8_buffer())
	Fakes.write(_host.folder().path_join("my_own_art.zip"), "mine".to_utf8_buffer())
	await _open()
	assert_false(DirAccess.dir_exists_absolute(work), "the work folder and its leftovers are gone")
	assert_true(FileAccess.file_exists(_host.folder().path_join("my_own_art.zip")), "nothing else is touched")


func test_a_pack_this_build_cannot_make_is_said_and_cannot_be_ticked() -> void:
	PackRecipes.packaging = "res://packaging/no_such_folder/"
	var window := await _open()
	PackRecipes.packaging = PackRecipes.PACKAGING
	assert_eq(_state(window, "pack-1"), "Not in this build")
	assert_true(_check(window, "pack-1").disabled)
	assert_string_contains((window.find_child("State_pack-1", true, false) as Label).tooltip_text,
		"pack_1_dotp_complete/manifest.json")
	assert_eq(_state(window, "base"), "Not here", "the 1997 pictures need no pack list")
	assert_false(_check(window, "base").disabled)


func test_ok_waits_for_a_tick_and_the_line_says_what_it_costs() -> void:
	var window := await _open()
	assert_true(_button(window, "OK").disabled)
	assert_eq(_text(window, "Chosen"), "Nothing chosen.")
	_check(window, "pack-2").button_pressed = true
	_check(window, "pack-8").button_pressed = true
	assert_false(_button(window, "OK").disabled)
	assert_eq(window.chosen(), ["pack-2", "pack-8"] as Array[String])
	var cost := window.cost(window.chosen())
	assert_eq(int(cost["fetch_mb"]), 20 + 136)
	assert_eq(int(cost["need_mb"]), 41 + 266 + 136 + PackBuild.SPARE_MB)
	assert_eq(_text(window, "Chosen"),
		"Chosen: 2. 156 MB to download, about 6 minutes. Needs 507 MB free (80.0 GB are free).")
	assert_eq(PackBuilderWindow.span(30), "less than a minute")
	assert_eq(PackBuilderWindow.span(90), "2 minutes")
	assert_eq(PackBuilderWindow.span(3900), "1 hour 5 minutes")
	assert_eq(PackBuilderWindow.megabytes(999), "999 MB")
	assert_eq(PackBuilderWindow.megabytes(1640), "1.6 GB")


func test_a_locked_catalogue_locks_every_row_in_its_own_words() -> void:
	_host.locked = "Close SGManalink connections and stop hosting before changing or rescanning card packs."
	var window := await _open()
	for id: String in PackRecipes.ids():
		assert_true(_check(window, id).disabled, id)
	assert_true(_button(window, "OK").disabled)
	assert_string_contains(_text(window, "Intro"), _host.locked)
	assert_eq(get_viewport().gui_get_focus_owner(), _button(window, "Close"))


func test_too_little_room_is_said_before_anything_starts() -> void:
	_host.free = 100 * 1024 * 1024
	var window := await _open()
	_check(window, "pack-3").button_pressed = true
	_button(window, "OK").pressed.emit()
	await wait_process_frames(2)
	assert_eq(window.mode, "choose")
	assert_string_contains(_text(window, "Summary"), "Not enough free disk space")
	assert_string_contains(_text(window, "Summary"), "100 MB are free")
	assert_eq(_host.net.log, [] as Array[String])


# ------------------------------------------------------------ the work --

func test_two_packs_one_after_the_other_with_a_bar_and_a_summary() -> void:
	_teach(["pack-2", "pack-4"])
	var window := await _open()
	_check(window, "pack-2").button_pressed = true
	_check(window, "pack-4").button_pressed = true
	_button(window, "OK").pressed.emit()
	assert_eq(window.mode, "working")
	window._build.frame_usec = 0   # one small step a frame: time to look
	assert_true((window.find_child("Work", true, false) as Control).visible)
	assert_true(_button(window, "Stop").visible)
	assert_false(_button(window, "OK").visible)
	assert_false(_button(window, "Close").visible)
	assert_eq(get_viewport().gui_get_focus_owner(), _button(window, "Stop"))
	assert_true(_check(window, "base").disabled, "the rows are held while it works")
	var bar := window.find_child("Bar", true, false) as ProgressBar
	var seen := 0.0
	for n in 80:
		await get_tree().process_frame
		assert_gte(bar.value, seen, "the bar only goes forward")
		seen = bar.value
	assert_gt(seen, 0.0)
	assert_lt(seen, 0.8)
	assert_true(_text(window, "Line").begins_with("Pack 2: Fallen Empires — downloading "), _text(window, "Line"))
	assert_true(_text(window, "Line").ends_with(" of 204"), _text(window, "Line"))
	assert_true(_text(window, "Overall").begins_with("Pack 1 of 2"), _text(window, "Overall"))
	window._build.frame_usec = 4000
	var phases := {}
	var frames := 0
	while window.mode == "working" and frames < 3000:
		if window._build != null:
			phases[window._build.id + " " + window._build.phase] = _text(window, "Line")
			if window._build.id == "pack-4":
				assert_true(_text(window, "Overall").begins_with("Pack 2 of 2"))
		await get_tree().process_frame
		frames += 1
	assert_eq(window.mode, "choose")
	for wanted: String in ["pack-2 downloading", "pack-2 writing", "pack-2 checking", "pack-4 downloading"]:
		assert_true(phases.has(wanted), wanted + " was shown: " + str(phases.keys()))
	assert_true(String(phases["pack-2 writing"]).begins_with("Pack 2: Fallen Empires — writing "))
	assert_true(String(phases["pack-2 checking"]).begins_with("Pack 2: Fallen Empires — checking "))
	assert_eq(_text(window, "Summary"), "Installed: Pack 2: Fallen Empires, Pack 4: Homelands. "
		+ "Turn them on in Options > Card Packs. No restart is needed.")
	assert_true((window.find_child("Summary", true, false) as Control).visible)
	assert_eq(_host.settled, [["pack-2", "pack-4"]], "the catalogue is read again, once")
	assert_eq(_state(window, "pack-2"), "Installed")
	assert_true(_check(window, "pack-2").disabled)
	assert_false(_check(window, "pack-2").button_pressed)
	assert_true(bool(CardPacks.inspect(_host.folder().path_join("Pack-2-Fallen-Empires.zip")).get("ok", false)))
	assert_true(bool(CardPacks.inspect(_host.folder().path_join("Pack-4-Homelands.zip")).get("ok", false)))
	assert_false((window.find_child("Work", true, false) as Control).visible)
	assert_eq(get_viewport().gui_get_focus_owner(), _button(window, "Close"))
	assert_eq(_host.worn, 0)
	_button(window, "Close").pressed.emit()
	await wait_process_frames(2)
	assert_false(is_instance_valid(window), "Close closes")
	assert_eq(_host.worn, 0, "no card art was built: nothing to wear")


func test_stop_keeps_the_downloads_and_says_what_was_not_done() -> void:
	_teach(["pack-2", "pack-4"])
	var window := await _open()
	_check(window, "pack-2").button_pressed = true
	_check(window, "pack-4").button_pressed = true
	_button(window, "OK").pressed.emit()
	window._build.frame_usec = 0
	await wait_process_frames(120)
	_button(window, "Stop").pressed.emit()
	await _until_done(window)
	assert_eq(window.mode, "choose")
	var summary := _text(window, "Summary")
	assert_string_contains(summary, "Not finished: Pack 2: Fallen Empires. Stopped. What was downloaded is kept; choose it again to go on.")
	assert_string_contains(summary, "Not started: Pack 4: Homelands.")
	assert_false(summary.contains("Installed"))
	assert_false(FileAccess.file_exists(_host.folder().path_join("Pack-2-Fallen-Empires.zip")))
	assert_true(_state(window, "pack-2").begins_with("Part downloaded: "), _state(window, "pack-2"))
	assert_true(_state(window, "pack-2").ends_with(" of 204"))
	assert_eq(_state(window, "pack-4"), "Not here")
	assert_eq(_host.settled, [[]], "nothing came in")
	# Chosen again, it goes on and finishes.
	_check(window, "pack-2").button_pressed = true
	_button(window, "OK").pressed.emit()
	await _until_done(window)
	assert_eq(_text(window, "Summary"), "Installed: Pack 2: Fallen Empires. "
		+ "Turn it on in Options > Card Packs. No restart is needed.")


func test_a_failure_is_said_with_its_reason_and_the_next_pack_still_runs() -> void:
	_teach(["pack-4"])
	_host.net.scripted["\"set\":\"fem\""] = [Fakes.answer(429)]
	var window := await _open()
	_check(window, "pack-2").button_pressed = true
	_check(window, "pack-4").button_pressed = true
	_button(window, "OK").pressed.emit()
	await _until_done(window)
	var summary := _text(window, "Summary")
	assert_string_contains(summary, "Installed: Pack 4: Homelands. Turn it on in Options > Card Packs.")
	assert_string_contains(summary, "Not finished: Pack 2: Fallen Empires. Scryfall is busy")
	assert_eq(_host.settled, [["pack-4"]])


func test_the_1997_pictures_say_when_they_are_worn_and_are_worn_on_close() -> void:
	_teach(["base"])
	var window := await _open()
	_check(window, "base").button_pressed = true
	_button(window, "OK").pressed.emit()
	await _until_done(window)
	assert_eq(_text(window, "Summary"),
		"Installed: 1997 card pictures. The cards wear them from the next start of the game.")
	_host.restart = false
	assert_eq(window.summary(),
		"Installed: 1997 card pictures. The cards wear them as soon as this window closes.")
	assert_eq(_host.settled, [["base"]])
	assert_true(FileAccess.file_exists(_host.folder().path_join("cardart.zip")))
	assert_eq(_host.worn, 0, "not while the summary is read")
	_escape()
	await wait_process_frames(2)
	assert_false(is_instance_valid(window), "Escape closes")
	assert_eq(_host.worn, 1, "the game takes the zip as it takes a chosen one")


# ------------------------------------------------- keys, focus, lettering --

func test_escape_stops_a_build_and_then_closes() -> void:
	_teach(["pack-2"])
	var window := await _open()
	assert_eq(get_viewport().gui_get_focus_owner(), _check(window, "base"), "the first row has the ring")
	_check(window, "pack-2").button_pressed = true
	_button(window, "OK").pressed.emit()
	window._build.frame_usec = 0
	await wait_process_frames(30)
	_escape()
	await _until_done(window)
	assert_true(is_instance_valid(window), "the first Escape stops; the summary stays to be read")
	assert_string_contains(_text(window, "Summary"), "Stopped.")
	_escape()
	await wait_process_frames(2)
	assert_false(is_instance_valid(window))


func test_the_ring_walks_the_rows_and_the_buttons_and_stays_on_the_window() -> void:
	_host.states["pack-1"] = {"state": "installed", "note": ""}
	var window := await _open()
	var base := _check(window, "base")
	var second := _check(window, "pack-2")
	var last := _check(window, "pack-10")
	var close := _button(window, "Close")
	assert_eq(base.get_node(base.focus_neighbor_top), base, "up from the top stays")
	assert_eq(base.get_node(base.focus_neighbor_bottom), second, "an installed row is stepped over")
	assert_eq(base.get_node(base.focus_neighbor_left), base)
	var gentle := _check_named(window, "PackGentle")
	var why := _button(window, "PackGentleWhy")
	assert_eq(last.get_node(last.focus_neighbor_bottom), gentle, "under the rows, the tick")
	assert_eq(gentle.get_node(gentle.focus_neighbor_top), last)
	assert_eq(gentle.get_node(gentle.focus_neighbor_right), why, "and its ? to the right")
	assert_eq(why.get_node(why.focus_neighbor_left), gentle)
	assert_eq(why.get_node(why.focus_neighbor_top), last)
	assert_eq(gentle.get_node(gentle.focus_neighbor_bottom), close, "OK has nothing to start yet")
	assert_eq(why.get_node(why.focus_neighbor_bottom), close)
	assert_eq(close.get_node(close.focus_neighbor_top), gentle)
	assert_eq(close.get_node(close.focus_neighbor_bottom), close)
	for control: Control in [gentle, why]:
		for neighbor: NodePath in [control.focus_neighbor_top, control.focus_neighbor_bottom,
				control.focus_neighbor_left, control.focus_neighbor_right, control.focus_next, control.focus_previous]:
			assert_true(window.is_ancestor_of(control.get_node(neighbor)), "%s -> %s" % [control.name, neighbor])
	assert_eq(_check(window, "pack-1").focus_mode, Control.FOCUS_NONE)
	assert_true(window.is_in_group(UiChrome.POPUP_GROUP))
	assert_eq(UiChrome.open_popup(_stage), window, "a screen's own Escape finds it")
	UiChrome.dismiss_popup(window)
	await wait_process_frames(2)
	assert_false(is_instance_valid(window), "and its cancel is Close")


func test_plain_lettering_and_a_panel_that_fits_the_screen() -> void:
	var window := await _open()
	var lettered := window.find_children("*", "Label", true, false) \
		+ window.find_children("*", "Button", true, false)
	assert_gt(lettered.size(), 40)
	for node: Control in lettered:
		assert_eq(node.get_theme_constant("shadow_offset_x"), 0, node.name)
		assert_eq(node.get_theme_constant("shadow_offset_y"), 0, node.name)
		assert_eq(node.get_theme_constant("outline_size"), 0, node.name)
		assert_eq(node.get_theme_color("font_shadow_color").a, 0.0, node.name)
	var panel := window.find_child("Panel", true, false) as Control
	gut.p("the panel is %s on a stage of %s" % [panel.size, _stage.size])
	assert_eq(window.size, _stage.size, "the veil covers the screen it is opened on")
	assert_lte(panel.size.x, 1280.0 - 40.0)
	assert_lte(panel.size.y, 800.0 - 40.0, "eleven rows, the bar and a summary fit 1280x800")
	assert_gte(panel.position.y, 0.0)
	# With the bar and a three-line summary up it still fits.
	(window.find_child("Work", true, false) as Control).visible = true
	var summary := window.find_child("Summary", true, false) as Label
	summary.text = "Installed: Pack 2: Fallen Empires, Pack 4: Homelands. Turn them on in Options > Card Packs. No restart is needed.\nNot finished: Pack 6: Portal & Second Age. 3 cards could not be fetched (Alabaster Dragon: Scryfall has no such card). The rest is kept; choose it again to fetch what is missing.\nNot started: Pack 8: The Mirage Block, Pack 9: The Tempest Block."
	summary.visible = true
	await wait_process_frames(3)
	gut.p("with the bar and a long summary: %s" % panel.size)
	assert_lte(panel.size.y, 800.0 - 20.0, "and with the bar and a long summary")
	assert_gte(panel.get_global_rect().position.y, 0.0)
	assert_lte(panel.get_global_rect().end.y, 800.0)


func test_a_window_that_goes_with_its_screen_stops_cleanly() -> void:
	_teach(["pack-2"])
	var window := await _open()
	_check(window, "pack-2").button_pressed = true
	_button(window, "OK").pressed.emit()
	window._build.frame_usec = 0
	await wait_process_frames(40)
	window.queue_free()
	await wait_process_frames(2)
	assert_gt(_host.net.cancelled, 0)
	var left: Array = []
	var dir := DirAccess.open(_host.folder())
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			left.append(entry)
		entry = dir.get_next()
	assert_eq(left, [], "no zip and no work folder in the card folder")


# ------------------------------------------------------ over Options --

## The window is opened from Options (the owner, 2026-11-23): over that
## screen and its scrolling list it covers everything, takes the ring,
## keeps Escape to itself and gives the ring back to the button.
func test_over_the_options_screen_it_covers_takes_the_ring_and_gives_it_back() -> void:
	var options: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(options)
	options.set_anchors_preset(Control.PRESET_TOP_LEFT)
	options.size = Vector2(1280, 800)
	await wait_process_frames(3)
	var opener := options.find_child("GetCardPacks", true, false) as Button
	if opener == null:
		pass_test("this Options screen has no Get Card Packs... button")
		return
	opener.grab_focus()
	var window: PackBuilderWindow = PackBuilderWindow.open_on(options, _host)
	await wait_process_frames(3)
	assert_eq(window.get_parent(), options)
	assert_eq(window.get_global_rect(), options.get_global_rect(), "the veil covers the whole screen, list and all")
	assert_eq(options.get_child(options.get_child_count() - 1), window, "and lies over everything of it")
	assert_gte(window.z_index, 300)
	var panel := window.find_child("Panel", true, false) as Control
	assert_true(options.get_global_rect().encloses(panel.get_global_rect()), "the panel is whole on the screen")
	var ring := get_viewport().gui_get_focus_owner()
	assert_true(window.is_ancestor_of(ring), "the ring is on the window, not on a row of Options under it")
	# Nothing of Options is reachable by the arrows or Tab from the window.
	for control: Control in [_check(window, "base"), _button(window, "Close")]:
		for neighbor: NodePath in [control.focus_neighbor_top, control.focus_neighbor_bottom,
				control.focus_neighbor_left, control.focus_neighbor_right, control.focus_next, control.focus_previous]:
			assert_true(window.is_ancestor_of(control.get_node(neighbor)), "%s -> %s" % [control.name, neighbor])
	assert_eq(UiChrome.open_popup(options), window, "Options' own Escape would find it")
	# Escape closes the window and leaves Options where it is.
	_escape()
	await wait_process_frames(3)
	assert_false(is_instance_valid(window))
	assert_true(options.is_inside_tree(), "Options is still the screen")
	assert_eq(get_viewport().gui_get_focus_owner(), opener, "and the ring is back on Get Card Packs...")


# ------------------------------------------- go easy on the servers --

func test_the_tick_is_on_by_default_remembered_and_moves_the_estimate() -> void:
	var window := await _open()
	var gentle := _check_named(window, "PackGentle")
	var why := _button(window, "PackGentleWhy")
	assert_eq(gentle.text, "Go easy on Scryfall's servers")
	assert_true(gentle.button_pressed, "ticked unless the player unticked it")
	assert_eq(why.text, "?")
	assert_eq(why.tooltip_text, "Why?")
	assert_eq(why.focus_mode, Control.FOCUS_ALL)
	assert_gt(gentle.get_index(), -1)
	assert_eq(gentle.get_parent(), why.get_parent(), "the ? is right beside the tick")
	assert_gt(gentle.get_parent().get_index(), (window.find_child("Chosen", true, false) as Control).get_index() - 1,
		"under the Chosen line")
	_check(window, "pack-2").button_pressed = true
	_check(window, "pack-8").button_pressed = true
	assert_string_contains(_text(window, "Chosen"), "about 6 minutes")
	gentle.button_pressed = false
	assert_false(_host.gentle_kept, "kept the moment it is unticked")
	assert_string_contains(_text(window, "Chosen"), "about 3 minutes", "the estimate follows the tick")
	window.close()
	await wait_process_frames(2)
	var again := await _open()
	assert_false(_check_named(again, "PackGentle").button_pressed, "and remembered at the next opening")
	_check_named(again, "PackGentle").button_pressed = true
	assert_true(_host.gentle_kept)


func test_the_tick_is_held_while_a_build_runs_and_is_that_build_s_pace() -> void:
	_teach(["pack-2", "pack-4"])
	var window := await _open()
	var gentle := _check_named(window, "PackGentle")
	gentle.button_pressed = false
	_check(window, "pack-2").button_pressed = true
	_button(window, "OK").pressed.emit()
	window._build.frame_usec = 0
	assert_true(gentle.disabled, "it applies from the next start")
	assert_eq(gentle.focus_mode, Control.FOCUS_NONE)
	assert_false(window._build.gentle)
	assert_false(window._build.fetch.gentle, "this build runs without the pause")
	var stop := _button(window, "Stop")
	var why := _button(window, "PackGentleWhy")
	assert_false(why.disabled, "the ? can still be asked")
	assert_eq(stop.get_node(stop.focus_neighbor_top), why)
	assert_eq(why.get_node(why.focus_neighbor_bottom), stop)
	await _until_done(window)
	assert_false(gentle.disabled, "free again when the build is over")
	assert_false(gentle.button_pressed)
	gentle.button_pressed = true
	_check(window, "pack-4").button_pressed = true
	_button(window, "OK").pressed.emit()
	assert_true(window._build.fetch.gentle, "ticked again, the next build pauses again")
	await _until_done(window)


func test_the_question_mark_thanks_scryfall_first_then_asks_to_be_nice() -> void:
	var window := await _open()
	var why := _button(window, "PackGentleWhy")
	_check(window, "pack-2").grab_focus()
	why.pressed.emit()
	await wait_process_frames(2)
	var popup := window.find_child("PackGentleExplained", true, false) as Control
	assert_not_null(popup)
	assert_eq(UiChrome.open_popup(window), popup)
	var words := PackedStringArray()
	for label: Label in popup.find_children("*", "Label", true, false):
		words.append(label.text)
		assert_eq(label.get_theme_constant("shadow_offset_x"), 0)
		assert_eq(label.get_theme_constant("outline_size"), 0)
		assert_eq(label.get_theme_color("font_shadow_color").a, 0.0, "plain letters")
	assert_eq(words[0], "About the download")
	var body := words[1]
	assert_true(body.begins_with("Thank you, Scryfall! Every card picture here comes from scryfall.com"), body)
	assert_gt(body.find("Let's be nice to their servers"), body.find("Thank you"), "the thanks come first")
	assert_gt(body.find("Unticked, only the pause between pictures is dropped"), body.find("Let's be nice"))
	assert_string_contains(body, "still waits whenever Scryfall asks it to")
	assert_string_contains(body, "about half an hour")
	var ok := popup.find_child("OK", true, false) as Button
	assert_eq(get_viewport().gui_get_focus_owner(), ok, "the ring is on its OK")
	var shown := popup.get_child(popup.get_child_count() - 1) as Control
	assert_true(_stage.get_global_rect().encloses(shown.get_global_rect()), "the popup is whole on the screen")
	# Escape closes the popup and only the popup.
	_escape()
	await wait_process_frames(3)
	assert_false(is_instance_valid(popup))
	assert_true(is_instance_valid(window), "the window stays")
	assert_eq(get_viewport().gui_get_focus_owner(), why, "and the ring is back on the ?")
	# OK does the same; a second press while it is up opens no second one.
	why.pressed.emit()
	why.pressed.emit()
	await wait_process_frames(2)
	assert_eq(window.find_children("PackGentleExplained*", "", true, false).size(), 1)
	(window.find_child("PackGentleExplained", true, false).find_child("OK", true, false) as Button).pressed.emit()
	await wait_process_frames(3)
	assert_null(UiChrome.open_popup(window))
	assert_eq(get_viewport().gui_get_focus_owner(), why)


func test_escape_on_the_explanation_does_not_stop_a_build() -> void:
	_teach(["pack-2"])
	var window := await _open()
	_check(window, "pack-2").button_pressed = true
	_button(window, "OK").pressed.emit()
	window._build.frame_usec = 0
	_button(window, "PackGentleWhy").pressed.emit()
	await wait_process_frames(2)
	_escape()
	await wait_process_frames(3)
	assert_null(UiChrome.open_popup(window), "the popup is gone")
	assert_eq(window.mode, "working", "and the build goes on")
	assert_false(_button(window, "Stop").disabled)
	_escape()
	await _until_done(window)
	assert_string_contains(_text(window, "Summary"), "Stopped.")


func test_it_fits_the_small_windows_too_with_the_tick_and_its_popup() -> void:
	for size: Vector2 in [Vector2(1280, 800), Vector2(1280, 720), Vector2(960, 720)]:
		_stage.size = size
		var window := await _open()
		var panel := window.find_child("Panel", true, false) as Control
		(window.find_child("Work", true, false) as Control).visible = true
		var summary := window.find_child("Summary", true, false) as Label
		summary.text = "Installed: Pack 2: Fallen Empires, Pack 4: Homelands. Turn them on in Options > Card Packs. No restart is needed.\nNot finished: Pack 6: Portal & Second Age. 3 cards could not be fetched (Alabaster Dragon: Scryfall has no such card). The rest is kept; choose it again to fetch what is missing.\nNot started: Pack 8: The Mirage Block, Pack 9: The Tempest Block."
		summary.visible = true
		_button(window, "PackGentleWhy").pressed.emit()
		await wait_process_frames(3)
		gut.p("on %s the panel is %s" % [size, panel.size])
		assert_true(Rect2(Vector2.ZERO, size).encloses(panel.get_global_rect()),
			"the window with its bar and a long summary fits %s" % size)
		var popup := window.find_child("PackGentleExplained", true, false) as Control
		var shown := popup.get_child(popup.get_child_count() - 1) as Control
		assert_true(Rect2(Vector2.ZERO, size).encloses(shown.get_global_rect()), "and the explanation fits %s" % size)
		window.queue_free()
		await wait_process_frames(2)

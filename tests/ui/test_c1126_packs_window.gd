extends GutTest
## THE CARD PACKS WINDOW (campaign 2026-11-26): it waits for the card pool
## with a line of its own instead of freezing, removes the pictures kept
## for packs that are installed, and its long summary is read with the
## keyboard or a pad. Run against the stand-in game of the 2026-11-23
## tests: no socket, no rescan of the real catalogue.

const Fakes := preload("res://tests/support/c1123_pack_fakes.gd")
const SCRATCH := "user://c1126_packs_window"


## A game whose card pool takes a while to read the new packs.
class SlowPool extends Fakes.Host:
	var frames_left := 0
	var asked := 0

	func settle(ids: Array) -> void:
		super.settle(ids)
		frames_left = 6

	func settling() -> bool:
		asked += 1
		frames_left -= 1
		return frames_left > 0


var _host: SlowPool
var _stage: Control


func before_each() -> void:
	Fakes.wipe(SCRATCH)
	_host = SlowPool.new()
	_host.root = SCRATCH
	_host.net = Fakes.Transport.new()
	_host.net.clock = _host.peek
	DirAccess.make_dir_recursive_absolute(_host.folder())
	_host.free = 80 * 1024 * 1024 * 1024
	_host.tick = 600
	_stage = Control.new()
	_stage.size = Vector2(1280, 800)
	add_child_autofree(_stage)


func after_each() -> void:
	Fakes.wipe(SCRATCH)


func _open() -> PackBuilderWindow:
	var window: PackBuilderWindow = PackBuilderWindow.open_on(_stage, _host)
	await wait_process_frames(2)
	return window


func _button(window: Control, node: String) -> Button:
	return window.find_child(node, true, false) as Button


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	get_viewport().push_input(ev)
	ev = InputEventAction.new()
	ev.action = action
	ev.pressed = false
	get_viewport().push_input(ev)


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


func test_the_window_says_it_reads_the_new_packs_and_stays_alive() -> void:
	_host.net.teach(PackRecipes.recipe("pack-2")["jobs"])
	var window := await _open()
	(window.find_child("Check_pack-2", true, false) as CheckBox).button_pressed = true
	_button(window, "OK").pressed.emit()
	var frames := 0
	var said_first := false
	while _host.settled.is_empty() and frames < 3000:
		await get_tree().process_frame
		frames += 1
		if (window.find_child("Line", true, false) as Label).text == "Reading the new packs..." \
				and _host.settled.is_empty():
			said_first = true
	assert_true(said_first, "the line is up before the folder is read")
	assert_eq(_host.settled, [["pack-2"]])
	# The packs are in, the pool is reading them: the window still works.
	assert_eq(window.mode, "working")
	assert_eq((window.find_child("Line", true, false) as Label).text, "Reading the new packs...")
	assert_eq((window.find_child("Bar", true, false) as ProgressBar).value, 1.0)
	assert_true(_button(window, "Stop").disabled, "nothing is left to stop")
	assert_false(_button(window, "Close").visible)
	assert_false((window.find_child("Summary", true, false) as Control).visible)
	frames = 0
	while window.mode == "working" and frames < 60:
		await get_tree().process_frame
		frames += 1
	assert_between(frames, 3, 8, "it asked once a frame until the pool was in")
	assert_eq(window.mode, "choose")
	assert_string_contains((window.find_child("Summary", true, false) as Label).text, "Installed: Pack 2: Fallen Empires.")
	assert_true(_button(window, "Close").visible)
	assert_eq(_focus(), _button(window, "Close"))
	assert_false(window.is_processing(), "and rests")


func test_escape_while_the_pool_reads_neither_closes_nor_breaks() -> void:
	_host.net.teach(PackRecipes.recipe("pack-2")["jobs"])
	var window := await _open()
	(window.find_child("Check_pack-2", true, false) as CheckBox).button_pressed = true
	_button(window, "OK").pressed.emit()
	var frames := 0
	while _host.settled.is_empty() and frames < 3000:
		await get_tree().process_frame
		frames += 1
	_press("ui_cancel")
	assert_true(is_instance_valid(window) and not window.is_queued_for_deletion())
	await wait_process_frames(10)
	assert_eq(window.mode, "choose")
	assert_string_contains((window.find_child("Summary", true, false) as Label).text, "Installed: Pack 2")


func test_a_window_gone_before_the_folder_is_read_still_has_it_read() -> void:
	_host.net.teach(PackRecipes.recipe("pack-2")["jobs"])
	var window := await _open()
	(window.find_child("Check_pack-2", true, false) as CheckBox).button_pressed = true
	_button(window, "OK").pressed.emit()
	var frames := 0
	while (window.find_child("Line", true, false) as Label).text != "Reading the new packs..." and frames < 3000:
		await get_tree().process_frame
		frames += 1
	assert_eq(_host.settled, [], "not read yet")
	window.free()
	assert_eq(_host.settled, [["pack-2"]], "read as the window went")


func test_the_first_frames_of_a_pack_say_the_list_is_read() -> void:
	if not OS.has_feature("threads"):
		pass_test("no threads here")
		return
	_host.net.teach(PackRecipes.recipe("pack-2")["jobs"])
	var window := await _open()
	(window.find_child("Check_pack-2", true, false) as CheckBox).button_pressed = true
	_button(window, "OK").pressed.emit()
	assert_true(window._build.aside)
	assert_eq(window._build.phase, "preparing")
	assert_eq((window.find_child("Line", true, false) as Label).text, "Pack 2: Fallen Empires — reading the card list")
	assert_eq((window.find_child("Overall", true, false) as Label).text, "Pack 1 of 1")
	# Stop in that moment is a clean stop.
	window.stop()
	await wait_process_frames(12)
	assert_eq(window.mode, "choose")
	assert_string_contains((window.find_child("Summary", true, false) as Label).text, "Not finished: Pack 2: Fallen Empires. Stopped.")


func test_opening_the_window_removes_what_an_installed_pack_left_cached() -> void:
	# Pack 3 was stopped part-way, then its zip was put in by hand.
	for n in 1300:
		Fakes.write(_host.cache_root().path_join("pack-3/ice/card_%d.jpg" % n), Fakes.jpeg("i%d" % n))
	_host.states["pack-3"] = {"state": "installed", "note": ""}
	# Pack 6 is simply unfinished: kept, and said.
	for n in 12:
		Fakes.write(_host.cache_root().path_join("pack-6/por/card_%d.jpg" % n), Fakes.jpeg("p%d" % n))
	var window := await _open()
	assert_true(window.is_processing(), "a little each frame")
	var frames := 0
	while window.is_processing() and frames < 200:
		await get_tree().process_frame
		frames += 1
	assert_between(frames, 1, 30)
	assert_false(DirAccess.dir_exists_absolute(_host.cache_root().path_join("pack-3")), "gone")
	assert_true(FileAccess.file_exists(_host.cache_root().path_join("pack-6/por/card_0.jpg")), "kept")
	assert_eq((window.find_child("State_pack-6", true, false) as Label).text, "Part downloaded: 12 of %d" % int(
		PackRecipes.about("pack-6")["pictures"]))
	assert_eq((window.find_child("State_pack-3", true, false) as Label).text, "Installed")


func test_a_build_begun_while_the_sweep_runs_loses_neither() -> void:
	for n in 2100:
		Fakes.write(_host.cache_root().path_join("pack-3/ice/card_%d.jpg" % n), Fakes.jpeg("i"))
	_host.states["pack-3"] = {"state": "installed", "note": ""}
	_host.net.teach(PackRecipes.recipe("pack-2")["jobs"])
	var window := await _open()
	(window.find_child("Check_pack-2", true, false) as CheckBox).button_pressed = true
	_button(window, "OK").pressed.emit()
	var frames := 0
	while window.mode == "working" and frames < 3000:
		await get_tree().process_frame
		frames += 1
	await wait_process_frames(15)
	assert_eq(window.mode, "choose")
	assert_string_contains((window.find_child("Summary", true, false) as Label).text, "Installed: Pack 2")
	assert_false(DirAccess.dir_exists_absolute(_host.cache_root().path_join("pack-3")))
	assert_false(window.is_processing())


# ---------------------------------------------------------- the summary --

func _long() -> String:
	var lines := PackedStringArray()
	for n in 30:
		lines.append("Not finished: Pack %d. The connection was lost and the rest is kept; choose it again to go on." % n)
	return "\n".join(lines)


func test_a_short_summary_takes_no_ring() -> void:
	var window := await _open()
	window._summary.text = "Installed: Pack 2: Fallen Empires."
	window._summary.visible = true
	await wait_process_frames(3)
	var box := window.find_child("SummaryBox", true, false) as ScrollContainer
	assert_true(box.visible)
	assert_false(window.summary_scrolls())
	assert_eq(box.focus_mode, Control.FOCUS_NONE)
	var summary := window.find_child("Summary", true, false) as Label
	assert_almost_eq(summary.size.x, box.size.x, 1.0, "no scroll bar takes room from a summary that fits")


func test_a_long_summary_is_read_with_the_keys() -> void:
	var window := await _open()
	window._summary.text = _long()
	window._summary.visible = true
	await wait_process_frames(3)
	var box := window.find_child("SummaryBox", true, false) as ScrollContainer
	var close := _button(window, "Close")
	assert_true(window.summary_scrolls())
	assert_eq(box.focus_mode, Control.FOCUS_ALL)
	assert_almost_eq(box.size.y, PackBuilderWindow.SUMMARY_MOST, 1.0)
	# Up from the buttons is the summary.
	close.grab_focus()
	_press("ui_up")
	await get_tree().process_frame
	assert_eq(_focus(), box, "the ring is on the summary")
	assert_eq(box.scroll_vertical, 0)
	# At its top, Up moves the ring on to the row above.
	_press("ui_up")
	await get_tree().process_frame
	assert_ne(_focus(), box)
	assert_true(window.is_ancestor_of(_focus()))
	_press("ui_down")
	await get_tree().process_frame
	assert_eq(_focus(), box)
	# Down scrolls, the ring stays.
	_press("ui_down")
	await get_tree().process_frame
	assert_eq(box.scroll_vertical, PackBuilderWindow.SUMMARY_STEP)
	assert_eq(_focus(), box)
	_press("ui_up")
	await get_tree().process_frame
	assert_eq(box.scroll_vertical, 0)
	_press("ui_page_down")
	await get_tree().process_frame
	assert_gt(box.scroll_vertical, 100)
	assert_eq(_focus(), box)
	var after_page := box.scroll_vertical
	_press("ui_page_up")
	await get_tree().process_frame
	assert_lt(box.scroll_vertical, after_page)
	_press("ui_end")
	await get_tree().process_frame
	var bar := box.get_v_scroll_bar()
	assert_almost_eq(float(box.scroll_vertical), float(bar.max_value - bar.page), 1.0, "the last line")
	# At the end, Down moves the ring on to the buttons.
	_press("ui_down")
	await get_tree().process_frame
	assert_true(_focus() is Button, "the ring left for the buttons: %s" % _focus())
	_press("ui_up")
	await get_tree().process_frame
	assert_eq(_focus(), box)
	_press("ui_home")
	await get_tree().process_frame
	assert_eq(box.scroll_vertical, 0)
	# A new job hides it: the ring is not left on a box that is gone.
	box.grab_focus()
	window._summary.visible = false
	await wait_process_frames(2)
	assert_false(window.summary_scrolls())
	assert_eq(_focus(), close)

extends GutTest
## THE SKIN BUILDER'S WINDOW (builders 2026-11-23) — Options' `Build from
## a 1997 install...` and what it opens ([SkinBuilderWindow]): the player
## names the folder of their own 1997 game, is told what it is, builds the
## skin zip with a bar and a Stop, and the zip goes in by the door every
## skin zip comes in by. What these hold:
##
##   1. Options has the button, and it opens one window.
##   2. The window says what it does in plain letters, and its buttons are
##      only live when they can do something.
##   3. A folder that is no copy of the game is refused and not kept; a
##      copy is checked and can be built; two folders are read in order.
##   4. A build shows how far it is, can be stopped with nothing changed,
##      and when it ends well hands the zip over, says what was left out
##      and deletes its scratch file. Every way it can go wrong is said.
##
## The job is a stand-in but for one test, which builds a made-up install
## for real ([C1123SkinFixtures]); the door is always a stand-in — a skin
## mounted in the suite could not be taken off again.

const F := preload("res://tests/support/c1123_skin_fixtures.gd")
const ISO := preload("res://tests/support/c1123_skin_iso.gd")
const SCRATCH := "user://test_c1123_skin_window"

var root := ""
var install := ""
var host: Control
var pack: FakePack
var job: FakeJob


## The skins' door: takes what it is handed, at once or over some frames.
class FakePack extends RefCounted:
	signal changed(kind: String)
	var adopted: Array[String] = []
	var was_a_skin: Array[bool] = []
	var answer := true
	var arrives := true
	var frames := 0
	var busy_now := false
	## What the zip is as it is handed over, when a test asks.
	var look := Callable()
	var looks: Array = []

	func adopt(path: String) -> bool:
		adopted.append(path)
		was_a_skin.append(FileAccess.file_exists(path))
		if look.is_valid():
			looks.append(look.call(path))
		if not answer:
			return false
		if frames == 0:
			if arrives:
				changed.emit("skin")
			return true
		busy_now = true
		return true

	func busy() -> bool:
		if not busy_now:
			return false
		frames -= 1
		if frames <= 0:
			busy_now = false
			if arrives:
				changed.emit("skin")
		return true


## The build: five tasks, one a step, and a file where the zip would be.
class FakeJob extends RefCounted:
	var total := 5
	var done_now := 0
	var finished := false
	var stopped := false
	var open_ok := true
	var fails := ""
	var dest := ""
	var skipped: Array = []
	var missing: Array = []
	var steps_allowed := 1000

	func open(_index: SkinSourceIndex, to: String) -> bool:
		dest = to
		if not open_ok:
			finished = true
		return open_ok

	func start_thread() -> bool:
		return false

	func step(_usec: int) -> bool:
		if finished:
			return false
		if stopped or fails != "":
			finished = true
			return false
		if steps_allowed <= 0:
			return true
		steps_allowed -= 1
		done_now += 1
		if done_now >= total:
			finished = true
			var file := FileAccess.open(dest, FileAccess.WRITE)
			file.store_string("zip")
			file.close()
		return not finished

	func cancel() -> void:
		stopped = true

	func wait() -> void:
		pass

	func progress() -> Dictionary:
		return {"done": done_now, "total": total, "current": "file_%d.png" % done_now,
			"finished": finished}

	func result() -> Dictionary:
		var ok := finished and not stopped and fails == "" and open_ok
		return {"ok": ok, "why": "" if ok else ("Stopped." if stopped else
			(fails if fails != "" else "Nothing of the 1997 game was found there.")),
			"stopped": stopped, "dest": dest, "files": 613, "skipped": skipped, "missing": missing,
			"left_out": ["coin_toss_heads", "coin_toss_tails", "win_movie.ogv"]}


func before_each() -> void:
	root = ProjectSettings.globalize_path(SCRATCH)
	F.remove_tree(root)
	install = root.path_join("MagicTG")
	SkinBuilderWindow._last_dir = ""
	SkinBuilderWindow._last_sources = []
	host = Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child_autofree(host)
	pack = FakePack.new()
	job = FakeJob.new()


func after_each() -> void:
	SkinBuilderWindow._last_dir = ""
	SkinBuilderWindow._last_sources = []
	F.remove_tree(root)


func _open() -> SkinBuilderWindow:
	var window := SkinBuilderWindow.new()
	window.name = "SkinBuilderWindow"
	window.pack = pack
	window.make_job = func() -> RefCounted: return job
	window.scratch_dir = root.path_join("scratch")
	window.kept_zip = root.path_join("no_such_skin.zip")
	window._host = host
	host.add_child(window)
	await get_tree().process_frame
	return window


func _settle(window: SkinBuilderWindow, frames := 900) -> void:
	for _i in frames:
		if not window.busy():
			break
		await get_tree().process_frame
	await get_tree().process_frame


func _with_install(window: SkinBuilderWindow) -> void:
	F.make_install(install)
	window.add_folder(install)
	await _settle(window)


func _zip_path(window: SkinBuilderWindow) -> String:
	return window.scratch_dir.path_join(SkinBuilderWindow.SCRATCH_NAME)


# ----------------------------------------------------- 1. from Options --

func test_options_has_the_button_and_it_opens_one_window() -> void:
	var options: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(options)
	await get_tree().process_frame
	var button := options.find_child("BuildSkin", true, false) as Button
	if not SkinBuilderWindow.offered():
		assert_null(button, "no folders to read here")
		return
	assert_not_null(button)
	assert_eq(button.text, "Build from a 1997 install...")
	assert_ne(button.tooltip_text, "")
	var choose := options.find_child("Choose_skin", true, false) as Control
	assert_gt(button.get_parent().get_index(), choose.get_parent().get_index(),
		"under the skin row's Choose...")
	assert_lt(button.get_parent().get_index(),
		(options.find_child("Choose_cardart", true, false) as Control).get_parent().get_index(),
		"and above the card art's")
	button.pressed.emit()
	await get_tree().process_frame
	var window := options.find_child("SkinBuilderWindow", true, false) as SkinBuilderWindow
	assert_not_null(window)
	button.pressed.emit()
	await get_tree().process_frame
	assert_eq(options.find_children("SkinBuilderWindow", "", true, false).size(), 1, "one window")
	assert_same(SkinBuilderWindow.open_on(options), window)
	window.close()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_null(options.find_child("SkinBuilderWindow", true, false))
	assert_true(button.has_focus(), "the keyboard is back on the button that opened it")


func test_not_offered_where_there_are_no_folders() -> void:
	assert_eq(SkinBuilderWindow.offered(),
		not (OS.has_feature("web") or OS.has_feature("android") or OS.has_feature("ios")))


# ------------------------------------------------------- 2. the window --

func test_the_window_says_what_it_does_in_plain_letters() -> void:
	var window := await _open()
	var said := "\n".join(window.find_children("*", "Label", true, false).map(
		func(label: Label) -> String: return label.text))
	assert_string_contains(said, "Build a skin from the 1997 game")
	assert_string_contains(said, "your own copy of the 1997 game")
	assert_string_contains(said, "Magic: The Gathering by MicroProse")
	assert_string_contains(said, "the folder it was installed to, its CD, or a CD image (.iso, .bin/.cue)")
	assert_string_contains(said, "Nothing is uploaded")
	assert_string_contains(said, "needs no other program")
	assert_string_contains(said, "Nothing chosen yet")
	for label: Label in window.find_children("*", "Label", true, false):
		assert_eq(label.get_theme_constant("shadow_offset_x"), 0, "nothing drawn behind the letters")
		assert_eq(label.get_theme_constant("shadow_offset_y"), 0)
		assert_eq(label.get_theme_constant("outline_size"), 0)
		assert_eq(label.get_theme_color("font_shadow_color").a, 0.0)
	assert_eq([window.choose_button.text, window.image_button.text, window.build_button.text,
		window.stop_button.text, window.close_button.text],
		["Choose folder...", "Choose CD image...", "Build skin", "Stop", "Close"])
	assert_eq(window.image_button.get_parent(), window.choose_button.get_parent(), "beside Choose folder...")
	assert_eq(window.image_button.get_index(), window.choose_button.get_index() + 1)
	assert_false(window.choose_button.disabled)
	assert_false(window.image_button.disabled)
	assert_true(window.build_button.disabled, "nothing to build from yet")
	assert_true(window.stop_button.disabled)
	assert_true(window.clear_button.disabled)
	assert_false(window.close_button.disabled)
	assert_false(window.bar.visible)
	assert_true(window.choose_button.has_focus())


func test_the_window_and_its_buttons_stay_on_the_screen() -> void:
	var window := await _open()
	await _with_install(window)
	var screen_rect := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var stone := window.window.get_global_rect()
	assert_true(screen_rect.encloses(stone), "the window: %s in %s" % [stone, screen_rect])
	for button: Button in [window.choose_button, window.image_button, window.clear_button,
			window.build_button, window.stop_button, window.close_button]:
		assert_true(stone.encloses(button.get_global_rect()), button.name + " is on the stone")
	for label: Label in [window.folders_label, window.report_label]:
		assert_true(stone.grow(1.0).encloses(label.get_global_rect()), label.name + " is on the stone")
		assert_lte(label.get_global_rect().end.y, window.build_button.get_global_rect().position.y,
			label.name + " ends above the buttons")


func test_the_keys_walk_the_window_s_own_buttons() -> void:
	var window := await _open()
	for button: Button in [window.choose_button, window.image_button, window.clear_button,
			window.build_button, window.stop_button, window.close_button]:
		for side in ["focus_neighbor_left", "focus_neighbor_right", "focus_neighbor_top",
				"focus_neighbor_bottom", "focus_next", "focus_previous"]:
			var to := button.get_node_or_null(button.get(side) as NodePath)
			assert_true(to != null and window.is_ancestor_of(to), "%s %s" % [button.name, side])


func test_escape_closes_it_but_not_a_build() -> void:
	var window := await _open()
	await _with_install(window)
	job.steps_allowed = 2
	window.build()
	await get_tree().process_frame
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	window._unhandled_input(escape)
	await get_tree().process_frame
	assert_false(window.is_queued_for_deletion(), "a build is not left by a slip of a key")
	window.stop()
	await _settle(window)
	window._unhandled_input(escape)
	assert_true(window.is_queued_for_deletion())


# ------------------------------------------------------ 3. the folders --

func test_a_folder_that_is_no_copy_is_refused_and_not_kept() -> void:
	var other := root.path_join("Holiday")
	F.write_file(other.path_join("photo.png"), F.noise(50, 1))
	var window := await _open()
	window.add_folder(other)
	assert_true(window.busy(), "looking")
	assert_string_contains(window.report_label.text, "Looking in ")
	await _settle(window)
	assert_eq(window.sources, [] as Array[String])
	assert_string_contains(window.report_label.text, "is not a copy of the 1997 game")
	assert_string_contains(window.report_label.text, "Magic.exe or Shandalar.exe")
	assert_string_contains(window.report_label.text, "Holiday")
	assert_true(window.build_button.disabled)
	assert_string_contains(window.folders_label.text, "Nothing chosen yet")
	# A folder that is not there at all.
	window.add_folder(root.path_join("nowhere"))
	await _settle(window)
	assert_eq(window.sources, [] as Array[String])
	assert_string_contains(window.report_label.text, "is not a copy of the 1997 game")


func test_a_copy_is_checked_and_can_be_built() -> void:
	var window := await _open()
	await _with_install(window)
	assert_eq(window.sources, [install] as Array[String])
	assert_string_contains(window.folders_label.text, "1. ")
	assert_string_contains(window.folders_label.text, "MagicTG")
	var said := window.report_label.text
	assert_string_contains(said, "This is an installed copy of the 1997 game.")
	assert_string_contains(said, "Found: ")
	assert_string_contains(said, "the sounds")
	assert_string_contains(said, "Not found: ")
	assert_string_contains(said, "skin files the game uses")
	assert_false(window.build_button.disabled)
	assert_false(window.clear_button.disabled)
	assert_eq(SkinBuilderWindow.start_dir(), install, "the folder box opens where it was last")
	# The same folder again changes nothing.
	window.add_folder(install + "/")
	await _settle(window)
	assert_eq(window.sources, [install] as Array[String])
	# Clear forgets it.
	window.clear()
	assert_eq(window.sources, [] as Array[String])
	assert_true(window.build_button.disabled)
	assert_eq(window.report_label.text, "")


func test_two_folders_are_read_in_the_order_chosen() -> void:
	var cd := root.path_join("CD")
	F.write_file(cd.path_join("Sound/Dueltune.wav"), F.bytes([1, 2, 3]))
	F.write_file(cd.path_join("Sound/LocMus0.wav"), F.bytes([4]))
	var window := await _open()
	await _with_install(window)
	var before := int(window.report["files"])
	window.add_folder(cd)
	await _settle(window)
	assert_eq(window.sources, [install, cd] as Array[String])
	assert_string_contains(window.folders_label.text, "2. ")
	assert_eq(window.index.sources, [install, cd] as Array[String])
	assert_eq(window.index.find("dueltune.wav"), install.path_join("Sound/Dueltune.wav"),
		"the first one wins where both have a file")
	assert_eq(int(window.report["files"]), before + 1, "and the second adds what only it has")
	# A stranger after a copy is refused, and the copy's report stays.
	var other := root.path_join("Holiday")
	F.write_file(other.path_join("photo.png"), F.noise(50, 1))
	window.add_folder(other)
	await _settle(window)
	assert_eq(window.sources, [install, cd] as Array[String])
	assert_string_contains(window.report_label.text, "is not a copy of the 1997 game")
	assert_string_contains(window.report_label.text, "This is an installed copy")
	assert_false(window.build_button.disabled)


func test_the_folders_are_remembered_for_the_session() -> void:
	var window := await _open()
	await _with_install(window)
	window.close()
	await get_tree().process_frame
	var again := await _open()
	await _settle(again)
	assert_eq(again.sources, [install] as Array[String])
	assert_string_contains(again.report_label.text, "installed copy")
	# One that is gone since is dropped.
	again.close()
	await get_tree().process_frame
	F.remove_tree(install)
	var third := await _open()
	await _settle(third)
	assert_eq(third.sources, [] as Array[String])


# --------------------------------------------------- 3b. a CD image --

## Every file under [param folder], by its path from it.
func _tree(folder: String, under := "") -> Dictionary:
	var out := {}
	var here := folder if under == "" else folder.path_join(under)
	for name in DirAccess.get_files_at(here):
		var inner := name if under == "" else under + "/" + name
		out[inner] = FileAccess.get_file_as_bytes(folder.path_join(inner))
	for name in DirAccess.get_directories_at(here):
		out.merge(_tree(folder, name if under == "" else under + "/" + name))
	return out


## A made-up disc of the made-up install, at [param name] in the scratch.
func _disc(name: String, raw_mode := 0) -> String:
	if not DirAccess.dir_exists_absolute(install):
		F.make_install(install)
	var bytes: PackedByteArray = ISO.make(_tree(install), true)["bytes"]
	var path := root.path_join(name)
	F.write_file(path, ISO.raw(bytes, raw_mode) if raw_mode > 0 else bytes)
	return path


func test_a_cd_image_is_taken_like_a_folder() -> void:
	var disc := _disc("Magic 1997.iso")
	var window := await _open()
	window.add_source(disc)
	assert_true(window.busy())
	await _settle(window)
	assert_eq(window.sources, [disc] as Array[String])
	assert_string_contains(window.folders_label.text, "1. ")
	assert_string_contains(window.folders_label.text, "Magic 1997.iso (CD image)")
	var said := window.report_label.text
	assert_string_contains(said, "This is a CD image of the 1997 game.")
	assert_string_contains(said, "Found: ")
	assert_string_contains(said, "skin files the game uses")
	assert_string_contains(said, "Some of the game's files may be packed inside the CD's installer")
	assert_false(window.build_button.disabled)
	assert_eq(SkinBuilderWindow.start_dir(), root, "the box opens beside the image next time")
	# The installed folder after it: both in the list, the image first.
	window.add_folder(install)
	await _settle(window)
	assert_eq(window.sources, [disc, install] as Array[String])
	assert_string_contains(window.folders_label.text, "2. ")
	assert_false(window.folders_label.text.split("\n")[1].contains("(CD image)"))
	assert_string_contains(window.report_label.text, "This is an installed copy of the 1997 game.")
	assert_eq(window.index.find("title.pic"), disc.path_join("Title.PIC"), "the first one wins")


func test_a_file_that_is_no_cd_image_is_refused_in_words() -> void:
	var window := await _open()
	var noise := root.path_join("holiday.iso")
	F.write_file(noise, F.noise(40 * 2048, 1))
	window.add_source(noise)
	await _settle(window)
	assert_eq(window.sources, [] as Array[String])
	assert_string_contains(window.report_label.text, "holiday.iso could not be read as a CD image: it is not a CD image the game can read.")
	assert_true(window.build_button.disabled)
	# An image that reads, with nothing of the game on it.
	var other := root.path_join("photos.iso")
	F.write_file(other, ISO.make({"photo.png": F.noise(50, 1)}, true)["bytes"])
	window.add_source(other)
	await _settle(window)
	assert_eq(window.sources, [] as Array[String])
	assert_string_contains(window.report_label.text, "photos.iso is not a CD image of the 1997 game: none of its files were found in it.")
	# A sheet that points out of its folder.
	var sheet := root.path_join("bad.cue")
	F.write_file(sheet, ISO.cue("../photos.iso"))
	window.add_source(sheet)
	await _settle(window)
	assert_eq(window.sources, [] as Array[String])
	assert_string_contains(window.report_label.text, "bad.cue could not be read as a CD image: its .cue names a file outside its own folder")
	assert_eq(SkinBuilderWindow.refusal("x", false, ""), SkinBuilderWindow.NOT_A_COPY % "x")


func test_a_real_build_from_a_raw_image_s_cue_reaches_the_door() -> void:
	_disc("disc.bin", 2)
	F.write_file(root.path_join("disc.cue"), ISO.cue("disc.bin", 2))
	var window := await _open()
	window.make_job = func() -> RefCounted: return SkinBuildJob.new()
	pack.look = func(path: String) -> Dictionary: return SkinPack.inspect(path)
	window.add_source(root.path_join("disc.cue"))
	await _settle(window)
	assert_string_contains(window.folders_label.text, "disc.cue (CD image)")
	window.build()
	await _settle(window, 3000)
	assert_eq(pack.adopted.size(), 1)
	assert_true(pack.looks[0]["ok"])
	assert_eq([pack.looks[0]["kind"], pack.looks[0]["files"]], ["skin", 29])
	assert_string_contains(window.report_label.text, "The skin is built and put on as classic_no-video.zip: 29 files.")


## The window in a screen of [param size], an image and a folder chosen.
func _in_screen(size: Vector2i) -> SkinBuilderWindow:
	var viewport := SubViewport.new()
	viewport.size = size
	add_child_autofree(viewport)
	var ground := Control.new()
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(ground)
	var window := SkinBuilderWindow.new()
	window.pack = pack
	window.make_job = func() -> RefCounted: return job
	window.scratch_dir = root.path_join("scratch")
	window.kept_zip = root.path_join("no_such_skin.zip")
	window._host = ground
	ground.add_child(window)
	await get_tree().process_frame
	return window


func test_the_window_fits_smaller_screens_at_its_fullest() -> void:
	var disc := _disc("A CD image with a rather long name, as they have.iso")
	for size: Vector2i in [Vector2i(1280, 800), Vector2i(1280, 720), Vector2i(960, 720)]:
		pack = FakePack.new()
		job = FakeJob.new()
		for i in 8:
			job.skipped.append({"name": "picture_%d.png" % i, "file": "Pic%d.pic" % i, "why": "it is cut short"})
		job.missing = ["sfx_tap.wav"]
		SkinBuilderWindow._last_sources = []
		var window := await _in_screen(size)
		var screen_rect := Rect2(Vector2.ZERO, Vector2(size))
		window.add_source(disc)
		await _settle(window)
		window.add_source(install)
		await _settle(window)
		for stage in ["checked", "built"]:
			if stage == "built":
				window.build()
				await _settle(window)
				assert_string_contains(window.report_label.text, "8 files would not decode")
			await get_tree().process_frame
			await get_tree().process_frame
			var stone := window.window.get_global_rect()
			assert_true(screen_rect.encloses(stone), "%s, %s: the window %s is on the screen" % [size, stage, stone])
			for button: Button in [window.choose_button, window.image_button, window.clear_button,
					window.build_button, window.stop_button, window.close_button]:
				assert_true(stone.encloses(button.get_global_rect()),
					"%s, %s: %s is on the stone" % [size, stage, button.name])
			assert_lte(window.choose_button.get_global_rect().end.y,
				window.build_button.get_global_rect().position.y, "the rows do not run into the foot")
		window.get_viewport().queue_free()


# -------------------------------------------------------- 4. the build --

func test_a_build_shows_how_far_it_is_and_ends_with_the_skin_on() -> void:
	var window := await _open()
	await _with_install(window)
	job.steps_allowed = 2
	window.build()
	assert_true(window.busy())
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(window.bar.visible)
	assert_almost_eq(window.bar.value, 0.4, 0.001)
	assert_eq(window.progress_label.text, "2 of 5: file_2.png")
	assert_true(window.progress_label.visible)
	assert_false(window.stop_button.disabled)
	assert_true(window.close_button.disabled, "not left while it builds")
	assert_true(window.choose_button.disabled)
	assert_true(window.image_button.disabled)
	assert_true(window.build_button.disabled)
	assert_eq(job.dest, _zip_path(window))
	assert_eq(pack.adopted, [] as Array[String])
	job.steps_allowed = 1000
	await _settle(window)
	assert_eq(pack.adopted, [_zip_path(window)] as Array[String], "handed to the skins' door")
	assert_eq(pack.was_a_skin, [true] as Array[bool], "whole, when it was handed over")
	assert_false(FileAccess.file_exists(_zip_path(window)), "the scratch copy is gone")
	assert_false(DirAccess.dir_exists_absolute(window.scratch_dir), "and its folder with it")
	var said := window.report_label.text
	assert_string_contains(said, "The skin is built and put on as classic_no-video.zip: 613 files.")
	assert_string_contains(said, "from the next start")
	assert_string_contains(said, "Left out: the coin-toss and ending movies")
	assert_string_contains(said, "Everything else is complete.")
	assert_false(window.bar.visible)
	assert_false(window.close_button.disabled)
	assert_true(window.stop_button.disabled)
	assert_false(window.build_button.disabled, "and it can be built again")


func test_stop_ends_it_with_nothing_changed() -> void:
	var window := await _open()
	await _with_install(window)
	job.steps_allowed = 2
	window.build()
	await get_tree().process_frame
	await get_tree().process_frame
	window.stop_button.pressed.emit()
	await _settle(window)
	assert_true(job.stopped)
	assert_eq(window.report_label.text, "Stopped. Nothing was changed.")
	assert_eq(pack.adopted, [] as Array[String])
	assert_false(FileAccess.file_exists(_zip_path(window)))
	assert_false(DirAccess.dir_exists_absolute(window.scratch_dir), "no scratch folder left either")
	assert_false(window.close_button.disabled)
	assert_false(window.build_button.disabled)


func test_what_was_skipped_is_named_at_the_end() -> void:
	var window := await _open()
	await _with_install(window)
	for i in 8:
		job.skipped.append({"name": "picture_%d.png" % i, "file": "Pic%d.pic" % i, "why": "it is cut short"})
	job.missing = ["sfx_tap.wav"]
	window.build()
	await _settle(window)
	var said := window.report_label.text
	assert_string_contains(said, "8 files would not decode and were left out: picture_0.png (Pic0.pic: it is cut short)")
	assert_string_contains(said, "picture_5.png")
	assert_does_not_have(said.split(" "), "picture_6.png")
	assert_string_contains(said, "and 2 more")
	assert_string_contains(said, "1 file the game can wear was not in your copy; the game draws it itself.")
	assert_string_contains(said, "The rest is complete.")
	assert_false(said.contains("Everything else is complete."))


func test_the_summary_s_words() -> void:
	var plain := SkinBuilderWindow.summary({"files": 613, "left_out": ["coin_toss_heads"]})
	assert_eq(plain, "The skin is built and put on as classic_no-video.zip: 613 files. It dresses the game from the next start.\n"
		+ SkinBuilderWindow.LEFT_OUT + "\nEverything else is complete.")
	var no_movies := SkinBuilderWindow.summary({"files": 20})
	assert_false(no_movies.contains("Left out"), "nothing was left out when the movies were never there")
	var one := SkinBuilderWindow.summary({"files": 1, "skipped": [{"name": "a.png", "file": "A.pic", "why": "it is cut short"}],
		"missing": ["x", "y"]}, true)
	assert_string_contains(one, "1 file would not decode and was left out: a.png (A.pic: it is cut short).")
	assert_string_contains(one, "2 files the game can wear were not in your copy; the game draws those itself.")
	assert_string_contains(one, "switch it off to wear this skin")
	assert_eq(SkinBuilderWindow.progress_line(3, 10, "title_background.png"), "3 of 10: title_background.png")
	assert_eq(SkinBuilderWindow.progress_line(3, 10, ""), "3 of 10")
	assert_eq(SkinBuilderWindow.progress_line(0, 0, "x"), "")


func test_a_build_that_fails_says_why() -> void:
	var window := await _open()
	await _with_install(window)
	job.fails = "The skin could not be written (is the disk full?)."
	window.build()
	await _settle(window)
	assert_eq(window.report_label.text, "The skin could not be written (is the disk full?).")
	assert_eq(pack.adopted, [] as Array[String])
	assert_false(window.close_button.disabled)
	# One that cannot even start.
	job = FakeJob.new()
	job.open_ok = false
	window.build()
	await _settle(window)
	assert_eq(window.report_label.text, "Nothing of the 1997 game was found there.")
	assert_false(window.bar.visible)


func test_a_full_disk_is_said_before_anything_is_built() -> void:
	assert_eq(SkinBuilderWindow.room_refusal(0), "", "a system that does not say is not refused")
	assert_eq(SkinBuilderWindow.room_refusal(SkinBuilderWindow.ROOM_NEEDED), "")
	assert_eq(SkinBuilderWindow.room_refusal(40 << 20),
		"The disk is too full: the skin needs about 300 MB while it is built, and 40 MB are free.")


func test_another_pack_still_coming_in_is_waited_for() -> void:
	var window := await _open()
	await _with_install(window)
	pack.busy_now = true
	pack.frames = 1000
	pack.arrives = false
	window.build()
	assert_false(window.busy(), "not started")
	assert_string_contains(window.report_label.text, "Another pack is still being copied in")
	assert_eq(job.dest, "")


func test_a_zip_copied_in_over_some_frames() -> void:
	var window := await _open()
	await _with_install(window)
	pack.frames = 4
	window.build()
	for _i in 60:
		if not pack.adopted.is_empty():
			break
		await get_tree().process_frame
	assert_eq(window.report_label.text, "Putting the skin on...")
	assert_true(window.close_button.disabled, "not left while the zip is copied in")
	assert_true(window.build_button.disabled)
	await _settle(window)
	assert_string_contains(window.report_label.text, "The skin is built and put on")
	assert_false(FileAccess.file_exists(_zip_path(window)))
	assert_false(window.close_button.disabled)


func test_a_zip_the_game_will_not_take_is_kept_and_named() -> void:
	for refusal in ["at the door", "in the copy"]:
		pack = FakePack.new()
		job = FakeJob.new()
		var window := await _open()
		if window.sources.is_empty():
			await _with_install(window)
		else:
			await _settle(window)
		if refusal == "at the door":
			pack.answer = false
		else:
			pack.frames = 3
			pack.arrives = false
		window.build()
		await _settle(window)
		assert_eq(pack.adopted.size(), 1, refusal)
		assert_string_contains(window.report_label.text, "The skin was built, but the game could not take it.")
		assert_string_contains(window.report_label.text, "classic_no-video.zip")
		assert_string_contains(window.report_label.text, "Choose... in Options")
		assert_true(FileAccess.file_exists(_zip_path(window)), "kept for the player to choose by hand")
		assert_false(window.close_button.disabled)
		window.close()
		await get_tree().process_frame


func test_a_window_taken_away_mid_build_stops_the_build() -> void:
	var window := await _open()
	await _with_install(window)
	job.steps_allowed = 1
	window.build()
	await get_tree().process_frame
	window.free()
	assert_true(job.stopped, "nothing goes on building behind a screen that is gone")


func test_a_real_build_of_a_made_up_install_reaches_the_door() -> void:
	var window := await _open()
	window.make_job = func() -> RefCounted: return SkinBuildJob.new()
	pack.look = func(path: String) -> Dictionary: return SkinPack.inspect(path)
	await _with_install(window)
	window.build()
	assert_true(window.busy())
	await _settle(window, 3000)
	assert_eq(pack.adopted, [_zip_path(window)] as Array[String])
	assert_eq(pack.looks.size(), 1)
	assert_true(pack.looks[0]["ok"], "what is handed over is a skin zip the game takes")
	assert_eq(pack.looks[0]["kind"], "skin")
	assert_eq(pack.looks[0]["files"], 29)
	assert_string_contains(window.report_label.text, "The skin is built and put on as classic_no-video.zip: 29 files.")
	assert_string_contains(window.report_label.text, "Left out: the coin-toss and ending movies")
	assert_false(FileAccess.file_exists(_zip_path(window)))
	assert_false(FileAccess.file_exists(_zip_path(window) + SkinBuildJob.PART_TAIL))

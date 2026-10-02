extends GutTest
## THE SHARED-STORAGE CORNER ON ANDROID — [AndroidCorner] (2026-09-29, the
## first Meta Quest report: *"app starts, no cards, no skin, no music"*).
##
## A folder made in the app's corner FROM THE SHELL (`adb shell mkdir`)
## is the shell's — `rwxrws---`, owner `shell` — and the game may not
## enter it: it opens, will not list, and holds nothing as far as the
## game can see. So the game makes its folders itself at every start,
## says in the log what it sees there, and traces the first input event
## of each class for the pointer work. Every function takes the corner
## as a parameter, so this suite runs them on a scratch corner on a desk.
## What these pin:
##
##   1. The four folders by their word, where [method GamePaths.player_place]
##      and [method GameSkin.portable_dir_for] put them; nothing for "".
##   2. `prepare` makes them with a README each, once — a second run
##      keeps a README the player edited and the files pushed in.
##   3. `listing`: `missing` where no folder is, `unlistable` where it
##      opens but will not list (a folder with no read bit, the desk's
##      likeness of the shell's), `ok` with the sorted names otherwise.
##   4. `line_for` / `report`: the log lines, the cure named on an
##      unlistable folder; "no shared-storage corner" for "".
##   5. `device_line` and `describe`: the display's side and one line
##      per event with its device (`-1` named as the mouse emulated from
##      a touch).
##   6. The tracer prints the device line at ready and the first event of
##      each class once, up to TRACED_CLASSES, consuming nothing.

var _corner := ""


func before_each() -> void:
	_corner = ProjectSettings.globalize_path("user://android_corner_test").path_join("files")
	_remove_tree(_corner.get_base_dir())
	DirAccess.make_dir_recursive_absolute(_corner)


func after_each() -> void:
	_remove_tree(_corner.get_base_dir())


# 1. The folders.

func test_the_four_folders_by_their_word() -> void:
	var folders := AndroidCorner.folders(_corner)
	assert_eq(folders.keys(), [AndroidCorner.SKIN, AndroidCorner.CARDPACKS,
		AndroidCorner.PORTRAITS, AndroidCorner.MUSIC])
	assert_eq(folders[AndroidCorner.SKIN], _corner.path_join("skin"))
	assert_eq(folders[AndroidCorner.CARDPACKS], _corner.path_join("cardpacks"))
	assert_eq(folders[AndroidCorner.PORTRAITS], _corner.path_join("portraits"))
	assert_eq(folders[AndroidCorner.MUSIC], _corner.path_join("music"))
	assert_eq(folders[AndroidCorner.CARDPACKS],
		GamePaths.player_place(GamePaths.DEFAULT_CARDPACKS, _corner))
	assert_eq(folders[AndroidCorner.SKIN], GameSkin.portable_dir_for(_corner))
	assert_eq(AndroidCorner.prepare(""), {}, "no corner, nothing made")


# 2. prepare.

func test_prepare_makes_the_folders_with_a_readme_each_once() -> void:
	var made := AndroidCorner.prepare(_corner)
	assert_eq(made, AndroidCorner.folders(_corner))
	var readmes := {
		AndroidCorner.SKIN: [AndroidCorner.README_NAME, AndroidCorner.SKIN_README],
		AndroidCorner.CARDPACKS: [SkinPack.CARD_README_NAME, SkinPack.CARD_README],
		AndroidCorner.PORTRAITS: [PortraitLibrary.README_NAME, PortraitLibrary.README],
		AndroidCorner.MUSIC: [MusicLibrary.README_NAME, MusicLibrary.README],
	}
	for word in made:
		assert_true(DirAccess.dir_exists_absolute(made[word]), word)
		var readme: String = made[word].path_join(readmes[word][0])
		assert_eq(FileAccess.get_file_as_string(readme), readmes[word][1], word)
	assert_true(AndroidCorner.SKIN_README.contains("adb push skin/original_skin.zip"))
	assert_true(AndroidCorner.SKIN_README.contains("adb push skin/cardart.zip"))
	assert_true(AndroidCorner.SKIN_README.contains("adb shell rm -rf"))
	# A second run keeps what is there.
	var skin_readme: String = made[AndroidCorner.SKIN].path_join(AndroidCorner.README_NAME)
	var file := FileAccess.open(skin_readme, FileAccess.WRITE)
	file.store_string("my notes")
	file.close()
	file = FileAccess.open(made[AndroidCorner.CARDPACKS].path_join("Pack-2-Fallen-Empires.zip"),
		FileAccess.WRITE)
	file.store_string("pushed")
	file.close()
	assert_eq(AndroidCorner.prepare(_corner), made)
	assert_eq(FileAccess.get_file_as_string(skin_readme), "my notes")
	assert_true(FileAccess.file_exists(
		made[AndroidCorner.CARDPACKS].path_join("Pack-2-Fallen-Empires.zip")))


# 3. listing.

func test_listing_missing_and_ok() -> void:
	assert_eq(AndroidCorner.listing(_corner.path_join("nowhere")),
		{"state": AndroidCorner.MISSING, "names": []})
	var folder := _corner.path_join("cardpacks")
	DirAccess.make_dir_recursive_absolute(folder)
	assert_eq(AndroidCorner.listing(folder), {"state": AndroidCorner.OK_LISTED, "names": []})
	for name in ["b.zip", "README.txt", "a.zip"]:
		var file := FileAccess.open(folder.path_join(name), FileAccess.WRITE)
		file.store_string(name)
		file.close()
	var found := AndroidCorner.listing(folder)
	assert_eq(found["state"], AndroidCorner.OK_LISTED)
	assert_eq(found["names"], ["README.txt", "a.zip", "b.zip"], "sorted")


func test_listing_unlistable_where_a_folder_opens_but_will_not_list() -> void:
	if not OS.get_name() in ["Linux", "macOS"]:
		pass_test("mode bits are the desk's likeness of the shell's folder; not here")
		return
	var folder := _corner.path_join("skin")
	DirAccess.make_dir_recursive_absolute(folder)
	var file := FileAccess.open(folder.path_join("original_skin.zip"), FileAccess.WRITE)
	file.store_string("pushed")
	file.close()
	# Enterable, not readable: the folder opens and its listing fails —
	# what the game saw on the headset.
	OS.execute("chmod", ["311", folder])
	var found := AndroidCorner.listing(folder)
	OS.execute("chmod", ["755", folder])
	if found["state"] == AndroidCorner.OK_LISTED:
		pass_test("this user reads every folder (root); the desk cannot pose as the shell")
		return
	assert_eq(found, {"state": AndroidCorner.UNLISTABLE, "names": []})


# 4. The lines.

func test_line_for_and_report() -> void:
	var folder := _corner.path_join("music")
	assert_eq(AndroidCorner.line_for("music", folder, {"state": "missing", "names": []}),
		"android: music %s: missing" % folder)
	assert_eq(AndroidCorner.line_for("music", folder, {"state": "ok", "names": []}),
		"android: music %s: ok, 0 entries" % folder)
	assert_eq(AndroidCorner.line_for("music", folder,
		{"state": "ok", "names": ["README.txt", "a.ogg"]}),
		"android: music %s: ok, 2 entries (README.txt, a.ogg)" % folder)
	var cure := AndroidCorner.line_for("music", folder, {"state": "unlistable", "names": []})
	assert_true(cure.begins_with("android: music %s: NOT LISTABLE" % folder), cure)
	assert_true(cure.contains('adb shell rm -rf "%s"' % folder), cure)
	assert_true(cure.contains("start the game once, then push"), cure)
	assert_eq(AndroidCorner.report(""), ["android: no shared-storage corner"])
	var lines := AndroidCorner.report(_corner)
	assert_eq(lines.size(), 5)
	assert_eq(lines[0], "android: corner %s" % _corner)
	for i in 4:
		assert_true(lines[i + 1].ends_with(": missing"), lines[i + 1])
	AndroidCorner.prepare(_corner)
	lines = AndroidCorner.report(_corner)
	assert_eq(lines[1], "android: skin %s: ok, 1 entries (README.txt)" % _corner.path_join("skin"))
	assert_eq(lines[2], "android: cardpacks %s: ok, 1 entries (README.txt)" % _corner.path_join("cardpacks"))
	assert_eq(lines[3], "android: portraits %s: ok, 1 entries (README.txt)" % _corner.path_join("portraits"))
	assert_eq(lines[4], "android: music %s: ok, 1 entries (README.txt)" % _corner.path_join("music"))


# 5. The display's side.

func test_device_line() -> void:
	var line := AndroidCorner.device_line()
	assert_true(line.begins_with("android: window %dx%d, touchscreen " % [
		DisplayServer.window_get_size().x, DisplayServer.window_get_size().y]), line)
	assert_true(line.contains(", handheld "), line)
	assert_true(line.ends_with("]"), line)
	assert_true(line.contains(", pads ["), line)


func test_describe_names_the_event_and_its_device() -> void:
	var click := InputEventMouseButton.new()
	click.device = InputEvent.DEVICE_ID_EMULATION
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(10.7, 20.2)
	assert_eq(AndroidCorner.describe(click),
		"android: first InputEventMouseButton: device -1 (mouse emulated from a touch), button 1 down at 10,20")
	var motion := InputEventMouseMotion.new()
	motion.device = 0
	motion.position = Vector2(3, 4)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	assert_eq(AndroidCorner.describe(motion),
		"android: first InputEventMouseMotion: device 0, at 3,4, buttons 1")
	var touch := InputEventScreenTouch.new()
	touch.index = 2
	touch.pressed = false
	touch.position = Vector2(5, 6)
	assert_eq(AndroidCorner.describe(touch),
		"android: first InputEventScreenTouch: device 0, finger 2 up at 5,6")
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = Vector2(7, 8)
	assert_eq(AndroidCorner.describe(drag),
		"android: first InputEventScreenDrag: device 0, finger 1 at 7,8")
	var button := InputEventJoypadButton.new()
	button.device = 4097
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	var by_pad := AndroidCorner.describe(button)
	assert_true(by_pad.begins_with("android: first InputEventJoypadButton: device 4097, button 0 down on "), by_pad)
	var axis := InputEventJoypadMotion.new()
	axis.axis = JOY_AXIS_LEFT_X
	axis.axis_value = 0.5
	assert_true(AndroidCorner.describe(axis).begins_with(
		"android: first InputEventJoypadMotion: device 0, axis 0 at 0.50 on "))
	var key := InputEventKey.new()
	key.device = 0
	key.keycode = KEY_ESCAPE
	key.pressed = true
	assert_eq(AndroidCorner.describe(key),
		"android: first InputEventKey: device 0, key Escape down")
	assert_eq(AndroidCorner.describe(InputEventAction.new()),
		"android: first InputEventAction: device 0")


# 6. The tracer.

func test_the_start_lines() -> void:
	var version := String(ProjectSettings.get_setting("application/config/version"))
	var line := AndroidCorner.version_line()
	assert_true(line.begins_with("android: Shandalar %s, started " % version), line)
	var when := RegEx.create_from_string("started \\d{4}-\\d\\d-\\d\\d \\d\\d:\\d\\d:\\d\\d$")
	assert_not_null(when.search(line), "the moment, so a report is placed: " + line)
	line = AndroidCorner.ready_line()
	assert_true(line.begins_with("android: tree ready after "), line)
	assert_true(line.ends_with(" ms"), line)
	assert_gt(int(line.trim_prefix("android: tree ready after ").trim_suffix(" ms")), 0)


## What the tracer notes after its own two lines: the skin's and the
## card packs' lines, as the autoloads hold them at this moment — and
## the card pool's, when its build is done by then.
func _autoload_notes() -> Array[String]:
	var out: Array[String] = []
	if SkinPack.mounted.is_empty():
		out.append("skin pack: nothing mounted")
	out.append_array(SkinPack.report_lines)
	out.append_array(CardPacks.report_lines)
	if not CardRegistry.pool_report().is_empty():
		out.append(CardRegistry.pool_report())
	return out


func test_the_tracer_says_the_start_then_each_class_once() -> void:
	CardRegistry.ensure_loaded()
	var tracer := AndroidCorner.new()
	add_child_autofree(tracer)
	var notes := _autoload_notes()
	assert_true(notes.back().begins_with("card pool: "), "the pool's line is the last note at ready")
	assert_false(tracer.is_processing(), "nothing left to wait for")
	var head := 2 + notes.size()
	# The viewport's handled flag is only ever reset by a real push_input:
	# a UI script before this one in the shard leaves it as its last click
	# left it (CI's four-way split put test_tutor_payment there, 2026-10-02),
	# so the tracer is held to leaving it as found, not to a flag it never
	# touched being false.
	var handled_before := get_viewport().is_input_handled()
	assert_eq(tracer.traced.size(), head)
	assert_true(tracer.traced[0].begins_with("android: tree ready after "), tracer.traced[0])
	assert_eq(tracer.traced[1], AndroidCorner.device_line())
	assert_eq(tracer.traced.slice(2), notes, "the autoloads' own lines, for the report")
	assert_true(notes.size() > 0, "the wrapper's packs are found, or nothing is mounted")
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(1, 1)
	tracer._input(motion)
	assert_eq(tracer.traced.size(), head + 1)
	assert_eq(tracer.traced[head], AndroidCorner.describe(motion))
	var again := InputEventMouseMotion.new()
	again.position = Vector2(2, 2)
	tracer._input(again)
	assert_eq(tracer.traced.size(), head + 1, "a class is reported once")
	tracer._input(InputEventMouseButton.new())
	assert_eq(tracer.traced.size(), head + 2)
	assert_eq(get_viewport().is_input_handled(), handled_before, "nothing consumed")
	# Up to TRACED_CLASSES classes, then quiet.
	var classes: Array = [InputEventScreenTouch, InputEventScreenDrag,
		InputEventJoypadButton, InputEventJoypadMotion, InputEventKey,
		InputEventAction, InputEventMagnifyGesture, InputEventPanGesture,
		InputEventMIDI, InputEventShortcut]
	for cls in classes:
		tracer._input(cls.new())
	assert_eq(tracer.traced.size(), head + AndroidCorner.TRACED_CLASSES)


## The pool builds on a thread while the tracer comes up (2026-09-30):
## its line is noted the frame the thread is done — noted, not said,
## since the loader printed it with the log's own timestamp.
func test_the_tracer_notes_the_pool_when_its_thread_is_done() -> void:
	CardRegistry.unload()
	assert_true(CardRegistry.load_in_background())
	var tracer := AndroidCorner.new()
	add_child_autofree(tracer)
	var head := tracer.traced.size()
	if CardRegistry.is_loading():
		assert_true(tracer.is_processing(), "waiting for the thread")
		for line in tracer.traced:
			assert_false(line.begins_with("card pool: "), line)
	var started := Time.get_ticks_msec()
	while tracer.is_processing() and Time.get_ticks_msec() - started < 30000:
		await get_tree().process_frame
	assert_false(tracer.is_processing(), "the thread finished within the limit")
	var pool_lines := tracer.traced.filter(func(line: String) -> bool:
		return line.begins_with("card pool: "))
	assert_eq(pool_lines.size(), 1, "one line, once")
	assert_lte(tracer.traced.size(), head + 1)
	assert_true(tracer.traced.back().begins_with("card pool: "), tracer.traced.back())
	assert_true(tracer.traced.back().ends_with(" (background)"), tracer.traced.back())
	assert_eq(CardRegistry.size(), CardRegistry._cards.size())


func test_the_report_file_follows_every_line() -> void:
	# The second headset report (2026-09-29): `adb logcat -d` after the
	# fact had lost the whole start — Android's main log buffer is a ring
	# the headset shell fills in minutes. So every line goes to a file
	# in the corner as it is said, and the file is the last start.
	var path := _corner.path_join(AndroidCorner.REPORT_NAME)
	var tracer := AndroidCorner.new()
	tracer.say("android: one")
	assert_false(FileAccess.file_exists(path), "no corner, no file")
	tracer.corner = _corner
	tracer.say("android: two")
	assert_eq(FileAccess.get_file_as_string(path), "android: one\nandroid: two\n")
	add_child_autofree(tracer)
	assert_eq(FileAccess.get_file_as_string(path), "\n".join(tracer.traced) + "\n",
		"the start lines follow")
	var motion := InputEventMouseMotion.new()
	tracer._input(motion)
	assert_true(FileAccess.get_file_as_string(path).ends_with(AndroidCorner.describe(motion) + "\n"),
		"and each first event, as it comes")
	assert_eq(tracer.traced[0], "android: one", "the log line and the file line are one")
	# The next start's file replaces this one.
	var lines: Array[String] = ["android: next start"]
	assert_true(AndroidCorner.write_report(_corner, lines))
	assert_eq(FileAccess.get_file_as_string(path), "android: next start\n")
	assert_false(AndroidCorner.write_report("", lines), "a desk has no corner")
	assert_false(AndroidCorner.write_report(_corner.path_join("nowhere"), lines),
		"a corner that is not there takes nothing")


func test_lifecycle_makes_the_corner_before_the_autoloads_read_it() -> void:
	var source := FileAccess.get_file_as_string("res://game/lifecycle.gd")
	assert_true(source.contains('if OS.has_feature("android"):'))
	assert_true(source.contains("AndroidCorner.prepare(corner)"))
	assert_true(source.contains("AndroidCorner.report(corner)"))
	assert_true(source.contains("tracer.corner = corner"), "the report goes to the corner")
	assert_true(source.contains("tracer.say(AndroidCorner.version_line())"), "headed by the version")
	assert_lt(source.find("tracer.say(AndroidCorner.version_line())"),
		source.find("AndroidCorner.report(corner)"), "before the corner's lines")
	assert_true(source.contains("add_child.call_deferred(tracer)"))
	var order := FileAccess.get_file_as_string("res://project.godot")
	assert_lt(order.find("Lifecycle="), order.find("SkinPack="), "Lifecycle boots first")
	assert_lt(order.find("SkinPack="), order.find("CardPacks="))


static func _remove_tree(folder: String) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var child := folder.path_join(name)
		if dir.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(child)
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(folder)

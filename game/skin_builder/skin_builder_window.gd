class_name SkinBuilderWindow
extends Control
## THE SKIN BUILT IN THE GAME — the window behind Options' `Build from a
## 1997 install...` (the owner, 2026-11-23: *"a skin tool … that would
## scrape a 1997 install for a skin we use directly within a game using
## godot engine"*, *"without any external dependencies"*). [QoL]: until
## now a player ran two Python tools beside the game for the same zip.
##
## The player names the folder their own 1997 game is in, or its CD — or
## both, one after the other, the first named winning where both hold a
## file. The window says what the folder is ([SkinInstallCheck]), builds
## the skin zip from it ([SkinBuildJob], on a thread, a bar and a line
## saying how far it is, `Stop` ending it with nothing changed), and
## hands the zip to the door every chosen skin zip comes in by ([method
## SkinPack.adopt]): copied into the skins folder, worn, and the usual
## "The skin is in." notice with its restart. Nothing leaves the machine
## and no other program is run.
##
## WHAT THE PLAYER IS TOLD AT THE END: how many files the skin holds, that
## the coin-toss and ending movies were left out (they need a converter
## the game does not carry), every file that was there and would not
## decode, by name and reason, and that the rest is complete.
##
## REFUSED IN PLAIN WORDS: a folder that is no copy of the 1997 game (it
## is not added), too little room on the disk, a zip that could not be
## written. A build stopped or failed leaves no file behind.
##
## The zip is built in a folder of the game's own ([member scratch_dir])
## and deleted from there once the skins folder has its copy.
##
## A CD IMAGE IS A SOURCE LIKE A FOLDER (the owner, 2026-11-23: *"Can skin
## be built also from 1997 Shandalar CD or its iso image?"*, *"Yes choose
## iso add it."*): `Choose CD image...` beside `Choose folder...` takes an
## `.iso`, a raw `.bin`/`.img`/`.mdf` or the `.cue` that points at one
## ([SkinIsoImage]); it is read in place, nothing unpacked, and joins the
## list like a folder — an image and the installed folder together, say.
##
## Not offered in a browser, which has no folders, nor on Android, where
## a folder a player picks cannot be read by path ([method offered]).

const TITLE := "Build a skin from the 1997 game"
const INTRO := "This reads your own copy of the 1997 game — Magic: The Gathering by MicroProse — from the folder it was installed to, its CD, or a CD image (.iso, .bin/.cue), and makes the skin zip the game wears. Nothing is uploaded, and it needs no other program."
const NO_FOLDER := "Nothing chosen yet. You can add more than one: the first one wins where two have a file."
const CHOOSE := "Choose folder..."
const CHOOSE_IMAGE := "Choose CD image..."
const PICK_IMAGE_TITLE := "Choose a CD image of the 1997 game"
const IMAGE_FILTERS: Array[String] = ["*.iso, *.bin, *.img, *.cue, *.mdf ; CD images", "* ; All files"]
const IMAGE_TAG := " (CD image)"
const NOT_AN_IMAGE := "%s is not a CD image of the 1997 game: none of its files were found in it."
const UNREADABLE_IMAGE := "%s could not be read as a CD image: %s."
const CLEAR := "Clear"
const BUILD := "Build skin"
const STOP := "Stop"
const CLOSE := "Close"
const OPTIONS_BUTTON := "Build from a 1997 install..."
const OPTIONS_TIP := "Make the skin zip here, in the game, from your own copy of the 1997 game: its installed folder, its CD or a CD image. Nothing is uploaded."
const PICK_TITLE := "Choose the 1997 game's folder"
const LOOKING := "Looking in %s..."
const NOT_A_COPY := "%s is not a copy of the 1997 game: none of its files were found there. Choose the folder that holds Magic.exe or Shandalar.exe, or the game's CD."
const NO_ROOM := "The disk is too full: the skin needs about %d MB while it is built, and %d MB are free."
const BUSY := "Another pack is still being copied in. Try again in a moment."
const STOPPED := "Stopped. Nothing was changed."
const WEARING := "Putting the skin on..."
const NOT_WORN := "The skin was built, but the game could not take it. It is kept at %s: choose it with Choose... in Options."
const FOLDER_SWITCH := "Options has \"Use the skin folder instead of the zip\" switched on: switch it off to wear this skin."
## What the game cannot make itself, and where the whole skin is made (the
## owner, 2026-11-23: "have a message to the player and direct him/her
## towards our Python tools for complete skin").
const LEFT_OUT := "Left out: the coin-toss and ending movies, which the game cannot convert. It shows its own coin toss, and the ending plays without its film. " \
	+ "For the complete skin with both movies, use the Python tool that comes with the game: python3 tools/mtg_assets.py --install <your 1997 game folder> (setup.txt, section 5, says how)."
const WINDOW_SIZE := Vector2(660, 430)
## Free room asked for before a build: the zip in its scratch place and
## its copy in the skins folder, with some to spare (a whole 1997 skin is
## 113 MB).
const ROOM_NEEDED := 300 << 20
## The most skipped files named one by one at the end.
const SKIPPED_SHOWN := 6
const SCRATCH_NAME := "original_skin.zip"

## The session's memory: where the folder box opens, and the folders
## chosen. Written nowhere.
static var _last_dir := ""
static var _last_sources: Array[String] = []

## Where the zip is built before the skins folder takes it.
var scratch_dir := "user://skin_builder"
## The door a finished zip goes in by: an object with `adopt(path) ->
## bool`, `busy() -> bool` and a `changed(kind)` signal — the [SkinPack]
## autoload, found when the window opens; a test gives its own.
var pack: Object = null
## What makes the job: a [SkinBuildJob], or a test's stand-in with the
## same methods.
var make_job: Callable = func() -> RefCounted: return SkinBuildJob.new()
## Microseconds a frame spent walking a folder's names.
var walk_usec := 4000

var sources: Array[String] = []
var index: SkinSourceIndex = null
var report: Dictionary = {}
## The finished build's [method SkinBuildJob.result], once there is one.
var outcome: Dictionary = {}

var window: OriginalDialog
var choose_button: Button
var image_button: Button
var clear_button: Button
var build_button: Button
var stop_button: Button
var close_button: Button
var folders_label: Label
var report_label: Label
var progress_label: Label
var bar: ProgressBar

var _host: Control
var _opener := "BuildSkin"
var _walk: SkinSourceIndex = null
var _probing := ""
var _job: RefCounted = null
var _stepping := false
var _dest := ""
var _wearing := false
var _waiting_to_wear := false
var _arrived := false
var _picker: FileDialog = null


## Whether this machine can build a skin at all: not a browser (no
## folders) and not a phone (a picked folder cannot be read by its path).
static func offered() -> bool:
	return not (OS.has_feature("web") or OS.has_feature("android") or OS.has_feature("ios"))


## Open the window over [param host] (the Options screen); the one
## already open there, when there is one.
static func open_on(host: Control) -> Control:
	for child in host.get_children():
		if child is SkinBuilderWindow and not child.is_queued_for_deletion():
			return child
	var built := SkinBuilderWindow.new()
	built.name = "SkinBuilderWindow"
	built._host = host
	host.add_child(built)
	return built


## The Options row: the button that opens the window, at the row's end.
static func options_row(host: Control) -> Control:
	var row := HBoxContainer.new()
	row.name = "BuildSkinRow"
	row.alignment = BoxContainer.ALIGNMENT_END
	var button := UiChrome.menu_button(OPTIONS_BUTTON, Vector2(216, 26), 13)
	button.name = "BuildSkin"
	button.tooltip_text = OPTIONS_TIP
	button.pressed.connect(func() -> void: SkinBuilderWindow.open_on(host))
	row.add_child(button)
	return row


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 150
	if pack == null:
		pack = get_node_or_null(^"/root/SkinPack")
	if pack != null and pack.has_signal(&"changed"):
		pack.connect(&"changed", _on_pack_changed)
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	window = _build_window()
	add_child(window)
	_fence([choose_button, image_button, clear_button, build_button, stop_button, close_button])
	_refresh()
	choose_button.grab_focus()
	# The folders chosen earlier this session, looked at afresh.
	if not _last_sources.is_empty():
		sources = _last_sources.duplicate()
		_start_walk(sources, "")


func _build_window() -> OriginalDialog:
	var dialog := OriginalDialog.create("", WINDOW_SIZE)
	dialog.name = "Window"
	var box := dialog.body()
	var head := line(TITLE, 18)
	head.name = "Title"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	var intro := line(INTRO, 13)
	intro.name = "Intro"
	box.add_child(intro)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	choose_button = GauntletOptions.fit(OriginalDialog.button(CHOOSE, Vector2(120, 26)))
	choose_button.name = "ChooseFolder"
	choose_button.pressed.connect(choose)
	row.add_child(choose_button)
	image_button = GauntletOptions.fit(OriginalDialog.button(CHOOSE_IMAGE, Vector2(120, 26)))
	image_button.name = "ChooseImage"
	image_button.pressed.connect(choose_image)
	row.add_child(image_button)
	clear_button = GauntletOptions.fit(OriginalDialog.button(CLEAR, Vector2(64, 26)))
	clear_button.name = "ClearFolders"
	clear_button.pressed.connect(clear)
	row.add_child(clear_button)
	box.add_child(row)

	folders_label = line("", 13)
	folders_label.name = "Folders"
	box.add_child(folders_label)
	box.add_child(HSeparator.new())
	report_label = line("", 13)
	report_label.name = "Report"
	box.add_child(report_label)

	bar = ProgressBar.new()
	bar.name = "Bar"
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	var trough := StyleBoxFlat.new()
	trough.bg_color = Color8(20, 18, 20)
	trough.border_color = OriginalDialog.SHADOW
	trough.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiChrome.CHOSEN
	bar.add_theme_stylebox_override("background", trough)
	bar.add_theme_stylebox_override("fill", fill)
	bar.visible = false
	box.add_child(bar)
	progress_label = line("", 13)
	progress_label.name = "Progress"
	progress_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	progress_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	progress_label.visible = false
	box.add_child(progress_label)

	build_button = GauntletOptions.fit(dialog.add_button(BUILD))
	build_button.name = "Build"
	build_button.pressed.connect(build)
	stop_button = GauntletOptions.fit(dialog.add_button(STOP))
	stop_button.name = "Stop"
	stop_button.pressed.connect(stop)
	close_button = GauntletOptions.fit(dialog.add_button(CLOSE))
	close_button.name = "Close"
	close_button.pressed.connect(close)
	return dialog


## One line of the window: pale letters on the dark stone, folded at the
## window's edge, and nothing drawn behind them.
static func line(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", OriginalDialog.CHOICE_LIT)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	label.add_theme_constant_override("outline_size", 0)
	var face := GameSkin.font("font_body")
	if face != null:
		label.add_theme_font_override("font", face)
	return label


## The keyboard and a pad walk the window's own buttons and nothing under
## it.
static func _fence(ring: Array) -> void:
	var count := ring.size()
	for i in count:
		var here: Control = ring[i]
		var before: Control = ring[(i - 1 + count) % count]
		var after: Control = ring[(i + 1) % count]
		for side in ["focus_neighbor_left", "focus_neighbor_top", "focus_previous"]:
			here.set(side, here.get_path_to(before))
		for side in ["focus_neighbor_right", "focus_neighbor_bottom", "focus_next"]:
			here.set(side, here.get_path_to(after))


# ------------------------------------------------------------ the folders --

## Whether a walk, a build or the wearing is under way.
func busy() -> bool:
	return _walk != null or _job != null or _wearing or _waiting_to_wear


## The folder box: the system's own, for a folder.
func choose() -> void:
	if busy() or is_instance_valid(_picker):
		return
	var box := FileDialog.new()
	box.name = "FolderChooser"
	box.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	# After the mode: setting the mode retitles the box.
	box.title = PICK_TITLE
	box.access = FileDialog.ACCESS_FILESYSTEM
	box.use_native_dialog = true
	box.size = Vector2i(760, 520)
	box.current_dir = start_dir()
	box.dir_selected.connect(func(path: String) -> void:
		box.queue_free()
		add_folder(path))
	box.canceled.connect(box.queue_free)
	_picker = box
	add_child(box)
	box.popup_centered()


## The file box for a CD image: an `.iso`, a raw image, or its `.cue`.
func choose_image() -> void:
	if busy() or is_instance_valid(_picker):
		return
	var box := FileDialog.new()
	box.name = "ImageChooser"
	box.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	box.title = PICK_IMAGE_TITLE
	box.access = FileDialog.ACCESS_FILESYSTEM
	box.filters = PackedStringArray(IMAGE_FILTERS)
	box.use_native_dialog = true
	box.size = Vector2i(760, 520)
	box.current_dir = start_dir()
	box.file_selected.connect(func(path: String) -> void:
		box.queue_free()
		add_source(path))
	box.canceled.connect(box.queue_free)
	_picker = box
	add_child(box)
	box.popup_centered()


## Where the folder box opens: the last folder chosen this session, else
## the player's home.
static func start_dir() -> String:
	if _last_dir != "" and DirAccess.dir_exists_absolute(_last_dir):
		return _last_dir
	var home := OS.get_environment("USERPROFILE" if OS.has_feature("windows") else "HOME")
	return home if home != "" else OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)


## Add [param path] to the folders read: looked at first on its own, and
## taken only when it holds something of the 1997 game.
func add_folder(path: String) -> void:
	add_source(path)


## The same for a folder or a CD image, whichever [param path] is.
func add_source(path: String) -> void:
	if busy():
		return
	var clean := path.simplify_path()
	if clean == "" or sources.has(clean):
		return
	_last_dir = clean if DirAccess.dir_exists_absolute(clean) else clean.get_base_dir()
	outcome = {}
	_start_walk([clean], clean)


## Forget every folder chosen.
func clear() -> void:
	if _job != null or _wearing or _waiting_to_wear:
		return
	if _walk != null:
		_walk.cancel()
		_walk = null
	_probing = ""
	sources = []
	_last_sources = []
	index = null
	report = {}
	outcome = {}
	_say("")
	_refresh()


func _start_walk(folders: Array, probing: String) -> void:
	_probing = probing
	_walk = SkinSourceIndex.new()
	_walk.begin(folders)
	_say(LOOKING % GamePaths.shown(String(folders.back())))
	_refresh()


func _walk_over() -> void:
	var walked := _walk
	_walk = null
	if _probing != "":
		var probed := _probing
		_probing = ""
		if not walked.sources.has(probed) or not SkinInstallCheck.is_copy(walked, probed):
			_say(refusal(GamePaths.shown(probed), walked.is_image(probed),
				String(walked.problems.get(probed, ""))))
			if index != null:
				report_label.text += "\n\n" + "\n".join(PackedStringArray(report.get("lines", [])))
			_refresh()
			return
		sources.append(probed)
		_last_sources = sources.duplicate()
		if sources.size() > 1:
			# Every folder again, in their order: the first wins.
			_start_walk(sources, "")
			return
	else:
		# Folders remembered from earlier that are gone or empty now.
		for gone in walked.not_folders:
			sources.erase(gone)
		_last_sources = sources.duplicate()
	index = walked
	report = SkinInstallCheck.survey(index)
	_say("\n".join(PackedStringArray(report["lines"])))
	_refresh()


## Why a source was not taken: a file that would not open as a CD image
## ([param problem] says why), an image with nothing of the game in it, or
## a folder with nothing of it.
static func refusal(shown: String, image: bool, problem: String) -> String:
	if problem != "":
		return UNREADABLE_IMAGE % [shown, problem]
	return (NOT_AN_IMAGE if image else NOT_A_COPY) % shown


# -------------------------------------------------------------- the build --

## Start the build of the folders chosen.
func build() -> void:
	if busy() or index == null or not bool(report.get("buildable", false)):
		return
	if pack != null and pack.has_method(&"busy") and pack.call(&"busy"):
		_say(BUSY)
		return
	DirAccess.make_dir_recursive_absolute(scratch_dir)
	var room := room_refusal(free_bytes(scratch_dir))
	if room != "":
		_say(room)
		return
	_dest = scratch_dir.path_join(SCRATCH_NAME)
	_remove_scratch(true)
	outcome = {}
	_arrived = false
	_job = make_job.call()
	if not _job.call(&"open", index, _dest):
		_build_over()
		return
	_stepping = not _job.call(&"start_thread")
	bar.value = 0.0
	_refresh()


## Why a build cannot start with [param free] bytes of room, or "" (0
## bytes: the system does not say, and the build finds out).
static func room_refusal(free: int) -> String:
	if free <= 0 or free >= ROOM_NEEDED:
		return ""
	return NO_ROOM % [ROOM_NEEDED >> 20, free >> 20]


static func free_bytes(folder: String) -> int:
	var dir := DirAccess.open(folder)
	return dir.get_space_left() if dir != null else 0


## Stop the build under way: nothing is kept.
func stop() -> void:
	if _job != null:
		_job.call(&"cancel")


func _process(_delta: float) -> void:
	if _walk != null:
		if not _walk.step(walk_usec):
			_walk_over()
		return
	if _job != null:
		if _stepping:
			_job.call(&"step", 8000)
		var now: Dictionary = _job.call(&"progress")
		_show_progress(now)
		if bool(now.get("finished", false)):
			_build_over()
		return
	if _waiting_to_wear:
		if not (pack.has_method(&"busy") and pack.call(&"busy")):
			_waiting_to_wear = false
			_wear()
		return
	if _wearing and not (pack.has_method(&"busy") and pack.call(&"busy")):
		_worn(_arrived)


func _show_progress(now: Dictionary) -> void:
	var total := int(now.get("total", 0))
	var done_now := int(now.get("done", 0))
	bar.value = float(done_now) / float(total) if total > 0 else 0.0
	progress_label.text = progress_line(done_now, total, String(now.get("current", "")))


## The line under the bar.
static func progress_line(done_now: int, total: int, current: String) -> String:
	if total <= 0:
		return ""
	if current == "":
		return "%d of %d" % [done_now, total]
	return "%d of %d: %s" % [done_now, total, current]


func _build_over() -> void:
	var job := _job
	_job = null
	job.call(&"wait")
	outcome = job.call(&"result")
	if bool(outcome.get("ok", false)):
		if pack == null:
			_say(NOT_WORN % GamePaths.shown(_dest))
		elif pack.has_method(&"busy") and pack.call(&"busy"):
			_waiting_to_wear = true
			_say(WEARING)
		else:
			_wear()
	else:
		_remove_scratch()
		_say(STOPPED if bool(outcome.get("stopped", false)) else String(outcome.get("why", "")))
	_refresh()


## Hand the zip to the skins' door.
func _wear() -> void:
	_say(WEARING)
	_wearing = true
	_arrived = false
	if not pack.call(&"adopt", _dest):
		_worn(false)
		return
	# Taken at once, or being copied in a piece a frame: [method _process]
	# sees the end of that.
	if _arrived or not (pack.has_method(&"busy") and pack.call(&"busy")):
		_worn(_arrived)
	_refresh()


func _on_pack_changed(kind: String) -> void:
	if _wearing and kind == "skin":
		_arrived = true
		# Now, not a frame later: on the title screen the pack reloads the
		# scene, and this window with it.
		_remove_scratch()


func _worn(took: bool) -> void:
	_wearing = false
	if took:
		_remove_scratch()
		_say(summary(outcome, GamePaths.use_skin_folder()))
	else:
		_say(NOT_WORN % GamePaths.shown(_dest))
	_refresh()


## What the player is told once the skin is in.
static func summary(result: Dictionary, folder_switch := false) -> String:
	var lines: Array[String] = ["The skin is built and put on: %d files. It dresses the game from the next start."
		% int(result.get("files", 0))]
	if folder_switch:
		lines.append(FOLDER_SWITCH)
	var rest := "Everything else is complete."
	var skipped: Array = result.get("skipped", [])
	if not skipped.is_empty():
		var named := PackedStringArray()
		for row: Dictionary in skipped.slice(0, SKIPPED_SHOWN):
			named.append("%s (%s: %s)" % [row.get("name", ""), row.get("file", ""), row.get("why", "")])
		var more := skipped.size() - named.size()
		lines.append("%d file%s would not decode and %s left out: %s%s."
			% [skipped.size(), "" if skipped.size() == 1 else "s",
			"was" if skipped.size() == 1 else "were", "; ".join(named),
			"; and %d more" % more if more > 0 else ""])
		rest = "The rest is complete."
	var missing: Array = result.get("missing", [])
	if not missing.is_empty():
		lines.append("%d file%s the game can wear %s not in your copy; the game draws %s itself."
			% [missing.size(), "" if missing.size() == 1 else "s",
			"was" if missing.size() == 1 else "were", "it" if missing.size() == 1 else "those"])
		rest = "The rest is complete."
	if not (result.get("left_out", []) as Array).is_empty():
		lines.append(LEFT_OUT)
	lines.append(rest)
	return "\n".join(PackedStringArray(lines))


## The scratch zip deleted, and its folder with it when nothing else is
## in it (kept with [param keep_folder], for the build about to start).
func _remove_scratch(keep_folder := false) -> void:
	if _dest == "":
		return
	for path: String in [_dest, _dest + SkinBuildJob.PART_TAIL]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var folder := _dest.get_base_dir()
	if not keep_folder and DirAccess.dir_exists_absolute(folder) \
			and DirAccess.get_files_at(folder).is_empty() \
			and DirAccess.get_directories_at(folder).is_empty():
		DirAccess.remove_absolute(folder)


# -------------------------------------------------------------- the looks --

func _say(text: String) -> void:
	report_label.text = text
	_fit.call_deferred()


func _fit() -> void:
	if is_instance_valid(window) and window.is_inside_tree():
		window.fit_height()


func _refresh() -> void:
	var building := _job != null
	var wearing := _wearing or _waiting_to_wear
	if sources.is_empty():
		folders_label.text = NO_FOLDER
	else:
		var shown := PackedStringArray()
		for i in sources.size():
			shown.append("%d. %s%s" % [i + 1, GamePaths.shown(sources[i]),
				"" if DirAccess.dir_exists_absolute(sources[i]) else IMAGE_TAG])
		folders_label.text = "\n".join(shown)
	choose_button.disabled = busy()
	image_button.disabled = busy()
	clear_button.disabled = building or wearing or (sources.is_empty() and _walk == null)
	build_button.disabled = busy() or index == null or not bool(report.get("buildable", false))
	stop_button.disabled = not building
	close_button.disabled = building or wearing
	bar.visible = building
	progress_label.visible = building
	if not building:
		progress_label.text = ""
	# A button gone grey cannot hold the keyboard.
	var owner_of_focus := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if owner_of_focus is BaseButton and (owner_of_focus as BaseButton).disabled \
			and is_ancestor_of(owner_of_focus):
		for button: Button in [stop_button, build_button, choose_button, image_button, close_button]:
			if not button.disabled:
				button.grab_focus()
				break
	_fit.call_deferred()


## Close: Options as it was, the keyboard and the pad on the button that
## opened the window. Not while a build or the wearing is under way.
func close() -> void:
	if _job != null or _wearing or _waiting_to_wear:
		return
	if is_instance_valid(_host):
		var opener := _host.find_child(_opener, true, false) as Control
		if opener != null and opener.is_visible_in_tree():
			opener.grab_focus()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _exit_tree() -> void:
	if _walk != null:
		_walk.cancel()
		_walk = null
	if _job != null:
		# The game closing, or the screen changed under the window: the
		# build ends with nothing kept.
		_job.call(&"cancel")
		_job.call(&"wait")
		_job = null
		_remove_scratch()

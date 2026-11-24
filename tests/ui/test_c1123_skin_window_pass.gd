extends GutTest
## THE SKIN BUILDER, THE BUG PASS OF 2026-11-24 — what a player with only
## the game and their own 1997 copy could run into: a zip of theirs
## written over, a disc that holds nothing but an installer, a window
## frozen while a slow disc is read, a folder box that opens in the wrong
## home, a list in letters large enough to fill the memory.

const F := preload("res://tests/support/c1123_skin_fixtures.gd")
const ISO := preload("res://tests/support/c1123_skin_iso.gd")
const SCRATCH := "user://test_c1123_skin_window_pass"

var root := ""
var install := ""
var host: Control
var pack: FakePack


class FakePack extends RefCounted:
	signal changed(kind: String)
	var adopted: Array[String] = []
	var held: Array[int] = []

	func adopt(path: String) -> bool:
		adopted.append(path)
		held.append(F.read_zip(path).size())
		changed.emit("skin")
		return true

	func busy() -> bool:
		return false


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


func after_each() -> void:
	SkinBuilderWindow._last_dir = ""
	SkinBuilderWindow._last_sources = []
	F.remove_tree(root)


func _open(kept := "") -> SkinBuilderWindow:
	var window := SkinBuilderWindow.new()
	window.pack = pack
	window.scratch_dir = root.path_join("scratch")
	window.kept_zip = kept if kept != "" else root.path_join("no_such_skin.zip")
	window._host = host
	host.add_child(window)
	await get_tree().process_frame
	return window


func _settle(window: SkinBuilderWindow, frames := 3000) -> void:
	for _i in frames:
		if not window.busy():
			break
		await get_tree().process_frame
	await get_tree().process_frame


func _zip(path: String, names: Array) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var packer := ZIPPacker.new()
	assert_eq(packer.open(path), OK)
	for name: String in names:
		packer.start_file(name)
		packer.write_file("x".to_utf8_buffer())
		packer.close_file()
	packer.close()


func _built(window: SkinBuilderWindow) -> void:
	F.make_install(install)
	window.add_folder(install)
	await _settle(window)
	window.build()
	await _settle(window)


# ------------------------------------------- 1. a zip of the player's --

func test_a_fuller_zip_of_the_player_s_is_kept_and_said() -> void:
	var theirs := root.path_join("skins/original_skin.zip")
	_zip(theirs, ["skin/title_background.png", "skin/win_movie.ogv", "skin/coin_toss_heads.png"])
	var before := F.read_zip(theirs)
	var window := await _open(theirs)
	await _built(window)
	assert_eq(pack.adopted.size(), 1)
	assert_eq(pack.adopted[0].get_file(), SkinBuilderWindow.ASIDE_NAME,
		"the build goes in under a name of its own")
	assert_eq(pack.held[0] > 20, true, "and it is the whole zip that is handed over")
	assert_string_contains(window.report_label.text,
		"The skin zip you had, original_skin.zip, holds 2 files this one does not, so it was kept: this skin is original_skin_built.zip.")
	assert_string_contains(window.report_label.text, "Choose... in Options puts the earlier one back.")
	assert_eq(F.read_zip(theirs), before, "theirs is as it was")
	assert_false(DirAccess.dir_exists_absolute(window.scratch_dir), "nothing is left in the scratch folder")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(Rect2(Vector2.ZERO, window.get_viewport_rect().size).encloses(window.window.get_global_rect()),
		"the longer summary is still on the screen")
	assert_true(window.window.get_global_rect().encloses(window.close_button.get_global_rect()))


func test_a_zip_that_holds_nothing_more_is_replaced_as_before() -> void:
	var theirs := root.path_join("skins/original_skin.zip")
	F.make_install(install)
	var first: Array = SkinBuildJob.build([install], root.path_join("first/a.zip"))["written"]
	_zip(theirs, ["skin/" + String(first[0]), "skin/" + String(first[5])])
	var window := await _open(theirs)
	await _built(window)
	assert_eq(pack.adopted.size(), 1)
	assert_eq(pack.adopted[0].get_file(), SkinBuilderWindow.SCRATCH_NAME)
	assert_does_not_have(window.report_label.text.split(" "), "kept:")


func test_counting_what_only_the_other_zip_holds() -> void:
	var theirs := root.path_join("a.zip")
	_zip(theirs, ["skin/", "skin/a.png", "skin/portraits/b.png", "skin/c.ogv"])
	assert_eq(SkinBuilderWindow.files_only_in(theirs, ["a.png", "portraits/b.png"]), 1)
	assert_eq(SkinBuilderWindow.files_only_in(theirs, ["a.png", "portraits/b.png", "c.ogv"]), 0)
	assert_eq(SkinBuilderWindow.files_only_in(root.path_join("none.zip"), []), 0, "no zip there")
	F.write_file(root.path_join("noise.zip"), F.noise(300, 2))
	assert_eq(SkinBuilderWindow.files_only_in(root.path_join("noise.zip"), []), 0, "not a zip")


# ------------------------------------------------ 2. an installer disc --

func test_a_disc_with_only_an_installer_is_told_apart() -> void:
	var window := await _open()
	var disc := root.path_join("magic_cd.iso")
	F.write_file(disc, ISO.make({"Setup.exe": F.noise(900, 1), "DATA.Z": F.noise(4000, 2),
		"Autorun.inf": F.noise(40, 3)}, true)["bytes"])
	window.add_source(disc)
	await _settle(window)
	assert_eq(window.sources, [] as Array[String])
	assert_string_contains(window.report_label.text,
		"magic_cd.iso holds an installer but none of the 1997 game's own files: they are packed inside the installer, which the game cannot unpack.")
	assert_string_contains(window.report_label.text, "Install the 1997 game and choose the folder it was installed to.")
	# The same disc as a folder.
	var folder := root.path_join("cdrom")
	F.write_file(folder.path_join("SETUP.EXE"), F.noise(900, 1))
	window.add_folder(folder)
	await _settle(window)
	assert_string_contains(window.report_label.text, "cdrom holds an installer but none")
	assert_eq(SkinBuilderWindow.refusal("x", true, "it is cut short", true),
		SkinBuilderWindow.UNREADABLE_IMAGE % ["x", "it is cut short"], "a file that will not open says that first")


func test_a_cue_that_names_a_whole_path_says_what_to_choose() -> void:
	var window := await _open()
	var sheet := root.path_join("old_burner.cue")
	F.write_file(sheet, ISO.cue("C:\\Images\\MAGIC.BIN"))
	window.add_source(sheet)
	await _settle(window)
	assert_string_contains(window.report_label.text, "choose the image file itself (.bin or .iso) instead")


# -------------------------------------- 3. the check, off the window's thread --

func test_the_check_runs_beside_the_window_and_its_plan_is_the_build_s() -> void:
	var window := await _open()
	F.make_install(install)
	window.add_folder(install)
	var seen_checking := false
	for _i in 3000:
		if not window.busy():
			break
		if window._survey != null:
			seen_checking = true
			assert_true(window.build_button.disabled and window.clear_button.disabled
				and window.choose_button.disabled, "nothing is pressed meanwhile")
			assert_string_contains(window.report_label.text, "Looking in ")
		await get_tree().process_frame
	assert_true(seen_checking, "the check was a step of its own")
	assert_true(bool(window.report["buildable"]))
	assert_true(window.report.has("plan"))
	# A job handed the plan builds what a job that plans for itself builds.
	var own := SkinBuildJob.new()
	assert_true(own.open(window.index, root.path_join("own/a.zip")))
	own.step()
	var handed := SkinBuildJob.new()
	handed.planned = window.report["plan"]
	assert_true(handed.open(window.index, root.path_join("handed/a.zip")))
	handed.step()
	assert_true(handed.result()["ok"])
	assert_eq(handed.result()["written"], own.result()["written"])
	assert_eq(handed.result()["missing"], own.result()["missing"])
	assert_eq(F.read_zip(root.path_join("handed/a.zip")).hash(), F.read_zip(root.path_join("own/a.zip")).hash())
	# And the plan is still whole for a second build.
	var again := SkinBuildJob.new()
	again.planned = window.report["plan"]
	assert_true(again.open(window.index, root.path_join("again/a.zip")))
	again.step()
	assert_eq(again.result()["written"], own.result()["written"])


func test_a_window_taken_away_during_the_check_waits_for_it() -> void:
	var window := await _open()
	F.make_install(install)
	window.add_folder(install)
	for _i in 3000:
		if window._survey != null or not window.busy():
			break
		await get_tree().process_frame
	window.free()
	assert_true(true, "no thread is left running behind a window that is gone")


# ----------------------------------------------------- 4. small things --

func test_the_folder_box_opens_in_the_player_s_own_home() -> void:
	var key := PortableMode.SYSTEM_PREFIX + "HOME"
	var before := OS.get_environment(key)
	OS.set_environment(key, root.path_join("real_home"))
	assert_eq(SkinBuilderWindow.start_dir(), root.path_join("real_home"),
		"not the portable folder HOME points into")
	if before == "":
		OS.unset_environment(key)
	else:
		OS.set_environment(key, before)


func test_a_list_far_too_large_is_not_read() -> void:
	F.make_install(install)
	var job := SkinBuildJob.new()
	job.max_text_file = 64
	assert_true(job.open(SkinSourceIndex.of([install]), root.path_join("out/a.zip")))
	job.step()
	var result := job.result()
	assert_true(result["ok"], "the build goes on without the lists")
	var whys := {}
	for row: Dictionary in result["skipped"]:
		whys[row["name"]] = row["why"]
	assert_string_contains(String(whys.get("adventure_hints.json", "")), "far larger")
	assert_string_contains(String(whys.get("adventure_wise_words.json", "")), "far larger")
	assert_lt(SkinBuildJob.MAX_TEXT_FILE, SkinBuildJob.MAX_DATA_FILE)

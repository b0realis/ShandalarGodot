extends GutTest
## THE SKIN PACK'S ARRIVALS, the bug campaign of 0.50.66 (fixer X4):
##  - h5-1 "Restart now" is offered on the title and in Options alone —
##    anywhere else (the Deck Builder with a deck unsaved, the world, a
##    duel) the notice says "from the next start" with a plain OK;
##  - h5-2 the relaunch repeats the launch whole, and a handheld quits
##    ("Quit and start again") for its launcher to start it again;
##  - h5-3 the skin zip beside the game, chosen back, is worn where it is:
##    nothing copied, the key cleared, the player's copies retired;
##  - h5-4 a chosen zip is copied a piece a frame, the transfer line saying so.
## Tiny zips are built here ([ZIPPacker]); the skins folder's own zips are
## put aside for each test and back after, as test_skin_pack.gd does.

const Pack := preload("res://tests/unit/test_skin_pack.gd")
const SCRATCH := "user://c21_x4_skin_pack"
const GOOD := SCRATCH + "/probe.zip"
const SHIPPED := SCRATCH + "/beside/original_skin.zip"
const BIG := SCRATCH + "/big_probe.zip"
const ASIDE := SCRATCH + "/aside"
const PACKS := SCRATCH + "/cardpacks"
const KEYS: Array[String] = [GamePaths.KEY_CARDPACKS, GamePaths.KEY_SKIN_ZIP,
	GamePaths.KEY_USE_SKIN_FOLDER, GamePaths.KEY_SKIN_FOLDER]
const HANDHELD := "SHANDALAR_HANDHELD"

var _was_mounted := false
var _was_worn := false
var _aside: Array[String] = []
var _saved: Dictionary = {}
var _scene_was: Node = null
var _stand_in: Node = null
var _handheld_was := ""


func before_each() -> void:
	_was_mounted = GameSkin.pack_mounted
	_was_worn = GameSkin.zip_worn
	_handheld_was = OS.get_environment(HANDHELD)
	OS.unset_environment(HANDHELD)
	for folder in [SCRATCH, ASIDE, PACKS, SHIPPED.get_base_dir()]:
		DirAccess.make_dir_recursive_absolute(folder)
	_saved = {}
	for key in KEYS:
		_saved[key] = Settings.get_value(key, null) if Settings.has_value(key) else null
		Settings.clear_value(key)
	Settings.set_value(GamePaths.KEY_CARDPACKS, PACKS)
	_aside = []
	for path in SkinPack._zips_in(SkinPack.USER_DIR):
		DirAccess.rename_absolute(path, ASIDE.path_join(path.get_file()))
		_aside.append(path)
	DirAccess.remove_absolute(SkinPack.RETIRED)
	Pack._zip(GOOD, {"skin/zz_x4_probe.png": Pack._png()})
	Pack._zip(SHIPPED, {"skin/zz_x4_shipped.png": Pack._png()})
	_scene_was = get_tree().current_scene


func after_each() -> void:
	if _handheld_was == "":
		OS.unset_environment(HANDHELD)
	else:
		OS.set_environment(HANDHELD, _handheld_was)
	get_tree().current_scene = _scene_was
	if _stand_in != null:
		_stand_in.queue_free()
		_stand_in = null
	SkinPack.copy_block = SkinPack.CHUNK
	SkinPack.copy_frame_usec = 8000
	SkinPack.shipped_for_tests = ""
	SkinPack._exit_tree()
	GameSkin.pack_mounted = _was_mounted
	GameSkin.zip_worn = _was_worn
	GameSkin.clear_caches()
	PortraitLibrary.refresh()
	MusicLibrary.refresh()
	SkinPack._hide_notice()
	DirAccess.remove_absolute(SkinPack.RETIRED)
	for path in SkinPack._zips_in(SkinPack.USER_DIR):
		DirAccess.remove_absolute(path)
	for path in _aside:
		DirAccess.rename_absolute(ASIDE.path_join(path.get_file()), path)
	for key in KEYS:
		if _saved[key] == null:
			Settings.clear_value(key)
		else:
			Settings.set_value(key, _saved[key])
	for folder in [PACKS, ASIDE, SHIPPED.get_base_dir(), SCRATCH]:
		for name in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(name))
		DirAccess.remove_absolute(folder)


## The tree's current scene pinned to a stand-in for [param scene_path].
func _on_screen(scene_path: String) -> void:
	_stand_in = Node.new()
	_stand_in.scene_file_path = scene_path
	get_tree().root.add_child(_stand_in)
	get_tree().current_scene = _stand_in


func _labels(node: Node, into: Array[String] = []) -> Array[String]:
	if node is Label:
		into.append((node as Label).text)
	for child in node.get_children():
		_labels(child, into)
	return into


func _button(name: String) -> Button:
	return SkinPack.notice().find_child(name, true, false) as Button \
		if SkinPack.notice() != null else null


# ------------------------------------------------- h5-1: a safe restart --

func test_the_restart_is_offered_on_the_title_and_in_options_alone() -> void:
	assert_true(SkinPack.restart_offered_on(SkinPack.TITLE_SCENE))
	assert_true(SkinPack.restart_offered_on(SkinPack.OPTIONS_SCENE))
	assert_eq(SkinPack.OPTIONS_SCENE, "res://game/options_screen.tscn")
	for elsewhere in ["res://game/deck_builder/deck_builder_screen.tscn",
			"res://game/duel/duel_screen.tscn", "res://game/adventure/world/world_screen.tscn", ""]:
		assert_false(SkinPack.restart_offered_on(elsewhere), elsewhere)


func test_a_zip_dropped_on_the_deck_builder_offers_no_restart() -> void:
	_on_screen("res://game/deck_builder/deck_builder_screen.tscn")
	assert_true(SkinPack.adopt(ProjectSettings.globalize_path(GOOD)))
	assert_not_null(SkinPack.notice(), "the arrival is told")
	assert_null(_button("Restart"), "no restart past an unsaved deck")
	var ok := _button("Later")
	assert_not_null(ok)
	if ok != null:
		assert_eq(ok.text, "OK", "a plain OK")
	if SkinPack.notice() != null:
		assert_string_contains(" ".join(_labels(SkinPack.notice())), "from the next start")


func test_a_zip_chosen_in_options_still_offers_the_restart() -> void:
	_on_screen(SkinPack.OPTIONS_SCENE)
	assert_true(SkinPack.adopt(ProjectSettings.globalize_path(GOOD)))
	var go := _button("Restart")
	assert_not_null(go, "Options: nothing is left unsaved there")
	if go != null:
		assert_eq(go.text, "Restart now")
	var later := _button("Later")
	assert_eq(later.text if later != null else "", "Later")


# ------------------------------------------ h5-2: the relaunch, whole --

func test_the_command_line_is_read_without_its_program() -> void:
	var raw := PackedByteArray()
	for arg in ["./Shandalar.x86_64", "--max-fps", "30", "--", "--perf-log"]:
		raw.append_array(String(arg).to_utf8_buffer())
		raw.append(0)
	assert_eq(SkinPack.args_after_program(raw),
		PackedStringArray(["--max-fps", "30", "--", "--perf-log"]))
	assert_eq(SkinPack.args_after_program(PackedByteArray()), PackedStringArray())
	var only := "./game".to_utf8_buffer()
	only.append(0)
	assert_eq(SkinPack.args_after_program(only), PackedStringArray(), "the program alone: nothing")


func test_the_relaunch_keeps_the_engines_own_options() -> void:
	var args := SkinPack.relaunch_args()
	for arg in OS.get_cmdline_args():
		assert_has(args, arg, "the engine's hand-on: %s" % arg)
	if OS.get_name() != "Linux":
		pass_test("the process's own command line is read on Linux")
		return
	# The suite runs `godot --headless --path . -s …`: the engine takes
	# `--headless` for itself, and get_cmdline_args() never hands it on.
	assert_does_not_have(OS.get_cmdline_args(), "--headless")
	assert_has(args, "--headless", "the launch's own options, every one")
	assert_has(args, "--path")


func test_a_handheld_quits_for_its_launcher_to_start_it_again() -> void:
	assert_eq(SkinPack.restart_way(false, ""), "relaunch")
	assert_eq(SkinPack.restart_way(false, "steam-deck"), "quit")
	assert_eq(SkinPack.restart_way(false, "arkos"), "quit")
	assert_eq(SkinPack.restart_way(false, "android"), "quit")
	assert_eq(SkinPack.restart_way(true, ""), "reload")
	assert_eq(SkinPack.restart_label("quit"), "Quit and start again")
	assert_eq(SkinPack.restart_label("relaunch"), "Restart now")
	assert_eq(SkinPack.restart_label("reload"), "Reload the page")
	OS.set_environment(HANDHELD, "arkos")
	_on_screen(SkinPack.TITLE_SCENE)
	SkinPack._show_notice("The skin is in.", "It dresses the game from the next start.", true)
	var go := _button("Restart")
	assert_not_null(go)
	if go != null:
		assert_eq(go.text, "Quit and start again", "the launcher's options are its to give")


# ------------------------------- h5-3: the zip beside the game, chosen back --

func test_the_zip_beside_the_game_chosen_back_is_worn_where_it_is() -> void:
	SkinPack.shipped_for_tests = SHIPPED
	# The player's copy of an older zip beside the game, worn this run.
	DirAccess.make_dir_recursive_absolute(SkinPack.USER_DIR)
	DirAccess.copy_absolute(GOOD, SkinPack.USER_ZIP)
	assert_true(SkinPack.mount(SkinPack.USER_ZIP, true))
	_on_screen("res://game/duel/duel_screen.tscn")
	assert_true(SkinPack.adopt(ProjectSettings.globalize_path(SHIPPED)))
	assert_eq(SkinPack._zips_in(SkinPack.USER_DIR), [SkinPack.USER_ZIP] as Array[String],
		"nothing copied: only the old copy, still read this run")
	assert_eq(SkinPack.mounted.front(), ProjectSettings.globalize_path(SHIPPED),
		"mounted where it is, first")
	assert_false(Settings.has_value(GamePaths.KEY_SKIN_ZIP))
	assert_eq(SkinPack._retired(), ["original_skin.zip"] as Array[String],
		"the copy worn this run goes at the next start")
	# The next start, before anything is mounted.
	SkinPack.settle_retired()
	assert_false(FileAccess.file_exists(SkinPack.USER_ZIP), "the copy is gone")
	assert_false(FileAccess.file_exists(SkinPack.RETIRED), "and the list with it")
	assert_false(FileAccess.file_exists(SkinPack.own_skin_zip()),
		"no zip of the player's left to be worn over the one beside the game")


func test_a_copy_not_worn_this_run_goes_at_once() -> void:
	SkinPack.shipped_for_tests = SHIPPED
	var hires := SkinPack.USER_DIR + "/zz_x4_hires.zip"
	DirAccess.make_dir_recursive_absolute(SkinPack.USER_DIR)
	DirAccess.copy_absolute(GOOD, hires)
	Settings.set_value(GamePaths.KEY_SKIN_ZIP, hires)
	var other := SkinPack.USER_DIR + "/zz_x4_other.zip"
	DirAccess.copy_absolute(GOOD, other)
	_on_screen("res://game/duel/duel_screen.tscn")
	assert_true(SkinPack.adopt(ProjectSettings.globalize_path(SHIPPED)))
	assert_false(FileAccess.file_exists(hires), "the copy the key named, unmounted: deleted now")
	assert_true(FileAccess.file_exists(other), "a zip nothing would wear is the player's to keep")
	assert_false(Settings.has_value(GamePaths.KEY_SKIN_ZIP))
	assert_false(FileAccess.file_exists(SkinPack.RETIRED), "nothing left for the next start")


func test_a_zip_chosen_again_before_the_next_start_is_kept() -> void:
	SkinPack._retire(SkinPack.USER_ZIP)
	assert_eq(SkinPack._retired(), ["original_skin.zip"] as Array[String])
	SkinPack._wear("skin", SkinPack.USER_DIR + "/original_skin.next-1.zip")
	assert_false(FileAccess.file_exists(SkinPack.RETIRED), "its successor is worn: kept")
	SkinPack._retire(SkinPack.USER_DIR + "/zz_x4_kept.zip")
	DirAccess.make_dir_recursive_absolute(SkinPack.USER_DIR)
	DirAccess.copy_absolute(GOOD, SkinPack.USER_DIR + "/zz_x4_kept.zip")
	Settings.set_value(GamePaths.KEY_SKIN_ZIP, SkinPack.USER_DIR + "/zz_x4_kept.zip")
	SkinPack.settle_retired()
	assert_true(FileAccess.file_exists(SkinPack.USER_DIR + "/zz_x4_kept.zip"),
		"the key names it: never deleted")


# ------------------------------------- h5-4: a piece a frame, and said so --

func _big_zip() -> void:
	var noise := PackedByteArray()
	var rng := RandomNumberGenerator.new()
	rng.seed = 6604
	for i in 48 * 1024:
		noise.append(rng.randi() & 255)
	Pack._zip(BIG, {"skin/zz_x4_noise.bin": noise})


func test_a_chosen_zip_is_copied_a_piece_a_frame() -> void:
	_big_zip()
	SkinPack.copy_block = 4096
	SkinPack.copy_frame_usec = 0
	_on_screen(SkinPack.OPTIONS_SCENE)
	var told := [0.0]
	var watch := func(fraction: float) -> void:
		told[0] = maxf(told[0], fraction)
	SkinPack.fetch_progressed.connect(watch)
	assert_true(SkinPack.adopt(ProjectSettings.globalize_path(BIG)), "under way")
	var kept := SkinPack.USER_DIR + "/big_probe.zip"
	assert_true(SkinPack.busy(), "the copy takes more than one frame")
	assert_false(FileAccess.file_exists(kept), "nothing in the kept place before it is whole")
	assert_string_contains(SkinPack.transfer_line(SkinPack.fetch_progress()), "Copying big_probe.zip…")
	assert_string_contains(SkinPack.transfer_line(0.5), "50%")
	assert_null(SkinPack.notice(), "no notice until it is in")
	await wait_for_signal(SkinPack.changed, 5.0)
	SkinPack.fetch_progressed.disconnect(watch)
	assert_false(SkinPack.busy())
	assert_true(told[0] > 0.0, "the line moved")
	assert_eq(FileAccess.get_sha256(kept), FileAccess.get_sha256(BIG), "byte for byte")
	assert_has(SkinPack.mounted, kept)
	assert_eq(String(Settings.get_value(GamePaths.KEY_SKIN_ZIP, "")), kept, "worn from now on")
	assert_not_null(_button("Restart"), "the arrival told as before")
	assert_eq(_pending_beside(kept), [], "no pending copy left")


func test_a_zip_arriving_while_one_is_copied_is_refused_and_said_so() -> void:
	_big_zip()
	SkinPack.copy_block = 4096
	SkinPack.copy_frame_usec = 0
	assert_true(SkinPack.adopt(ProjectSettings.globalize_path(BIG)))
	assert_false(SkinPack.adopt(ProjectSettings.globalize_path(GOOD)))
	var head := Pack._first_label(SkinPack.notice()) if SkinPack.notice() != null else null
	assert_eq(head.text if head != null else "", "probe.zip is not a skin.")
	await wait_for_signal(SkinPack.changed, 5.0)


func test_a_copy_cut_short_by_the_close_leaves_nothing() -> void:
	_big_zip()
	SkinPack.copy_block = 4096
	SkinPack.copy_frame_usec = 0
	assert_true(SkinPack.adopt(ProjectSettings.globalize_path(BIG)))
	var kept := SkinPack.USER_DIR + "/big_probe.zip"
	assert_eq(_pending_beside(kept).size(), 1, "the copy is in flight under its pending name")
	SkinPack._exit_tree()      # as the tree tells it on the way out
	assert_false(SkinPack.busy())
	assert_eq(_pending_beside(kept), [], "the half copy is deleted")
	assert_false(FileAccess.file_exists(kept))


func test_a_small_zip_is_in_at_once_as_before() -> void:
	assert_true(SkinPack.adopt(ProjectSettings.globalize_path(GOOD)))
	assert_false(SkinPack.busy(), "one frame's piece holds it all")
	assert_has(SkinPack.mounted, SkinPack.USER_DIR + "/probe.zip")


## The pending copies beside [param kept] ([method Settings.pending_path]).
func _pending_beside(kept: String) -> Array:
	var out := []
	for name in DirAccess.get_files_at(kept.get_base_dir()):
		if name.begins_with(kept.get_file() + Settings.PENDING_TAIL):
			out.append(name)
	return out

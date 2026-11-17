extends GutTest
## THE PORTABLE GAME (0.70.1) — the owner, 2026-11-17: *"all data for game
## working are in the game folder itself ... in portable folder under main
## game folder! So easy to copy and take around."* [PortableMode]: where
## the engine's data folder goes, what a start does, the copy and the
## folder's retirement. The launchers' own lines are held to the same
## variables by tools/test_package_release.py (PortableLinesTest).

const ROOT := "user://portable_mode_test"

var _root := ""


func before_each() -> void:
	_root = ProjectSettings.globalize_path(ROOT)
	_wipe(_root)
	DirAccess.make_dir_recursive_absolute(_root)


func after_each() -> void:
	_wipe(_root)
	PortableMode.available_override = -1
	PortableMode.folder_override = ""
	PortableMode.start_note = ""
	PortableMode.start_problem = ""


## Delete [param dir], which must be this test's own.
func _wipe(dir: String) -> void:
	if not dir.contains("portable_mode_test") or not DirAccess.dir_exists_absolute(dir):
		return
	var here := DirAccess.open(dir)
	here.include_hidden = true
	for sub in here.get_directories():
		_wipe(dir.path_join(sub))
	for name in here.get_files():
		DirAccess.remove_absolute(dir.path_join(name))
	DirAccess.remove_absolute(dir)


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


# ------------------------------------------------------------ the places --

func test_inside_is_by_whole_folder_names_and_the_systems_letter_case() -> void:
	assert_true(PortableMode.inside("/g/portable/godot/app_userdata/Shandalar", "/g/portable", "linux"))
	assert_true(PortableMode.inside("/g/portable", "/g/portable/", "linux"))
	assert_false(PortableMode.inside("/g/portable2/x", "/g/portable", "linux"), "a longer name is not inside")
	assert_false(PortableMode.inside("/G/Portable/x", "/g/portable", "linux"), "Linux minds letter case")
	assert_true(PortableMode.inside("C:\\Games\\Shandalar\\portable\\Godot", "c:/games/shandalar/portable", "windows"))
	assert_true(PortableMode.inside("/Users/you/Games/PORTABLE/Library", "/Users/you/Games/portable", "macos"))
	assert_false(PortableMode.inside("", "/g/portable", "linux"))


func test_user_dir_in_the_portable_folder_keeps_the_engines_last_three_names() -> void:
	assert_eq(PortableMode.user_dir_in("windows", "C:/Games/S/portable",
		"C:/Users/you/AppData/Roaming/Godot/app_userdata/Shandalar"),
		"C:/Games/S/portable/Godot/app_userdata/Shandalar")
	assert_eq(PortableMode.user_dir_in("linux", "/g/portable", "/home/you/.local/share/godot/app_userdata/Shandalar"),
		"/g/portable/godot/app_userdata/Shandalar")
	assert_eq(PortableMode.user_dir_in("macos", "/Users/you/G/portable",
		"/Users/you/Library/Application Support/Godot/app_userdata/Shandalar"),
		"/Users/you/G/portable/Library/Application Support/Godot/app_userdata/Shandalar")


func test_env_points_each_system_into_the_folder_and_keeps_its_own_values() -> void:
	var win := PortableMode.env_for("windows", "C:/Games/S/portable",
		{"APPDATA": "C:\\Users\\you\\AppData\\Roaming", "LOCALAPPDATA": "C:\\Users\\you\\AppData\\Local"})
	assert_eq(win["APPDATA"], "C:\\Games\\S\\portable", "Windows' own separators")
	assert_eq(win["LOCALAPPDATA"], "C:\\Games\\S\\portable")
	assert_eq(win["SHANDALAR_SYSTEM_APPDATA"], "C:\\Users\\you\\AppData\\Roaming")
	assert_eq(win["SHANDALAR_SYSTEM_LOCALAPPDATA"], "C:\\Users\\you\\AppData\\Local")
	assert_eq(win[PortableMode.ENV_PORTABLE], "C:\\Games\\S\\portable")
	var linux := PortableMode.env_for("linux", "/g/portable", {"XDG_DATA_HOME": ""})
	assert_eq(linux["XDG_DATA_HOME"], "/g/portable")
	assert_eq(linux["XDG_CACHE_HOME"], "/g/portable/cache")
	assert_eq(linux["SHANDALAR_SYSTEM_XDG_DATA_HOME"], "", "unset stays unset")
	var mac := PortableMode.env_for("macos", "/Users/you/G/portable", {"HOME": "/Users/you"})
	assert_eq(mac["HOME"], "/Users/you/G/portable")
	assert_eq(mac["SHANDALAR_SYSTEM_HOME"], "/Users/you")
	# A start already inside (the launcher set it) keeps the system's value.
	var again := PortableMode.env_for("macos", "/Users/you/G/portable",
		{"HOME": "/Users/you/G/portable", "SHANDALAR_SYSTEM_HOME": "/Users/you"})
	assert_eq(again["SHANDALAR_SYSTEM_HOME"], "/Users/you")


func test_env_restored_gives_the_system_back_its_values() -> void:
	var back := PortableMode.env_restored("windows", {"APPDATA": "C:\\G\\portable",
		"SHANDALAR_SYSTEM_APPDATA": "C:\\Users\\you\\AppData\\Roaming", "SHANDALAR_SYSTEM_LOCALAPPDATA": ""})
	assert_eq(back["APPDATA"], "C:\\Users\\you\\AppData\\Roaming")
	assert_eq(back["LOCALAPPDATA"], "", "was not set: unset")
	assert_eq(back["SHANDALAR_SYSTEM_APPDATA"], "")
	assert_eq(back[PortableMode.ENV_PORTABLE], "")


func test_the_systems_own_folder_from_the_kept_values_or_its_defaults() -> void:
	var user := "C:/G/portable/Godot/app_userdata/Shandalar"
	assert_eq(PortableMode.system_user_dir("windows", user, {"SHANDALAR_SYSTEM_APPDATA": "C:\\Users\\you\\AppData\\Roaming"}),
		"C:/Users/you/AppData/Roaming/Godot/app_userdata/Shandalar")
	assert_eq(PortableMode.system_user_dir("windows", user, {"USERPROFILE": "C:\\Users\\you"}),
		"C:/Users/you/AppData/Roaming/Godot/app_userdata/Shandalar", "a portable folder made by hand")
	var linux := "/g/portable/godot/app_userdata/Shandalar"
	assert_eq(PortableMode.system_user_dir("linux", linux, {"HOME": "/home/you"}),
		"/home/you/.local/share/godot/app_userdata/Shandalar")
	assert_eq(PortableMode.system_user_dir("linux", linux, {"HOME": "/home/you", "SHANDALAR_SYSTEM_XDG_DATA_HOME": "/data"}),
		"/data/godot/app_userdata/Shandalar")
	var mac := "/G/portable/Library/Application Support/Godot/app_userdata/Shandalar"
	assert_eq(PortableMode.system_user_dir("macos", mac, {"SHANDALAR_SYSTEM_HOME": "/Users/you"}),
		"/Users/you/Library/Application Support/Godot/app_userdata/Shandalar")
	assert_eq(PortableMode.system_user_dir("macos", mac, {"USER": "you"}),
		"/Users/you/Library/Application Support/Godot/app_userdata/Shandalar")
	assert_eq(PortableMode.system_user_dir("linux", linux, {}), "", "no home known: no guess")


# ------------------------------------------------------------- the start --

func test_the_start_enters_only_a_folder_it_is_not_in_and_never_twice() -> void:
	var user := "/home/you/.local/share/godot/app_userdata/Shandalar"
	var dir := "/g/portable"
	assert_eq(PortableMode.plan("", true, user, dir, "", true), "stay", "not a desktop")
	assert_eq(PortableMode.plan("linux", false, user, dir, "", true), "stay", "no folder")
	assert_eq(PortableMode.plan("linux", true, user, dir, "", true), "enter")
	assert_eq(PortableMode.plan("linux", true, "/g/portable/godot/app_userdata/Shandalar", dir, "", true),
		"stay", "inside already")
	assert_eq(PortableMode.plan("linux", true, "/link/g/portable/godot/app_userdata/Shandalar", dir,
		"/link/g/portable", true), "stay", "inside the folder its launcher named")
	assert_eq(PortableMode.plan("linux", true, user, dir, "/g/portable", true), "failed",
		"sent inside and not there: never again")
	assert_eq(PortableMode.plan("linux", true, user, dir, "", false), "failed", "a folder that cannot be written")


func test_no_start_in_a_checkout_a_tool_or_a_test_is_portable() -> void:
	assert_false(PortableMode.available(), "the editor's binary is no exported game")
	PortableMode.enter_at_start()
	assert_eq(PortableMode.start_problem, "", "and the start did nothing")
	var lifecycle := FileAccess.get_file_as_string("res://game/lifecycle.gd")
	assert_string_contains(lifecycle, "func _init() -> void:\n\tPortableMode.enter_at_start()")


func test_a_folder_that_cannot_be_written_says_why() -> void:
	# A folder the system will not let the game write in (made read-only
	# here; a read-only USB stick or a macOS download run in place).
	var locked := _root.path_join("locked/portable")
	DirAccess.make_dir_recursive_absolute(locked)
	FileAccess.set_unix_permissions(locked, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_EXECUTE_OWNER)
	assert_false(PortableMode.can_write(locked))
	FileAccess.set_unix_permissions(locked, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER
		| FileAccess.UNIX_EXECUTE_OWNER)
	assert_string_contains(PortableMode.write_problem("/x/AppTranslocation/y/portable"), "Move the game folder")
	assert_string_contains(PortableMode.write_problem("/opt/Shandalar/portable"), "cannot be written")
	assert_true(PortableMode.can_write(_root.path_join("game/portable")))
	assert_false(FileAccess.file_exists(_root.path_join("game/portable/.shandalar-write-test")), "the probe is gone")


func test_apply_env_sets_and_unsets() -> void:
	PortableMode.apply_env({"SHANDALAR_PORTABLE_TEST": "1"})
	assert_eq(OS.get_environment("SHANDALAR_PORTABLE_TEST"), "1")
	PortableMode.apply_env({"SHANDALAR_PORTABLE_TEST": ""})
	assert_false(OS.has_environment("SHANDALAR_PORTABLE_TEST"))


func test_tilde_stays_the_players_home_on_a_portable_mac() -> void:
	var kept := OS.get_environment("SHANDALAR_SYSTEM_HOME")
	OS.set_environment("SHANDALAR_SYSTEM_HOME", "/Users/you")
	assert_eq(GamePaths.expand("~/Music"), "/Users/you/Music")
	if kept == "":
		OS.unset_environment("SHANDALAR_SYSTEM_HOME")
	else:
		OS.set_environment("SHANDALAR_SYSTEM_HOME", kept)


# -------------------------------------------------------------- the copy --

func test_the_copy_takes_everything_but_the_logs_and_touches_nothing_else() -> void:
	var from := _root.path_join("system/Shandalar")
	var to := _root.path_join("game/portable/godot/app_userdata/Shandalar")
	_write(from.path_join("settings.cfg"), "[options]\nx=1\n")
	_write(from.path_join("adventures/a.autosave.json"), "{}")
	_write(from.path_join("decks/deep/one.deck"), "4 Lightning Bolt\n")
	_write(from.path_join(".hidden"), "h")
	_write(from.path_join("logs/godot.log"), "running")
	_write(to.path_join("settings.cfg"), "old")
	_write(to.path_join("theirs.txt"), "kept")
	var found := PortableMode.measure(from)
	assert_eq(found["files"], [".hidden", "adventures/a.autosave.json", "decks/deep/one.deck", "settings.cfg"])
	var job := PortableMode.start_copy(from, to, false)
	var p := job.progress()
	assert_true(p["finished"])
	assert_eq(p["error"], "")
	assert_eq(p["files"], 4)
	assert_eq(p["bytes"], int(found["bytes"]))
	assert_eq(FileAccess.get_file_as_string(to.path_join("settings.cfg")), "[options]\nx=1\n", "replaced")
	assert_eq(FileAccess.get_file_as_string(to.path_join("decks/deep/one.deck")), "4 Lightning Bolt\n")
	assert_eq(FileAccess.get_file_as_string(to.path_join("theirs.txt")), "kept", "nothing else touched")
	assert_false(FileAccess.file_exists(to.path_join("logs/godot.log")), "the running log stays")
	assert_eq(FileAccess.get_file_as_string(from.path_join("settings.cfg")), "[options]\nx=1\n", "the source stays")


func test_the_copy_runs_on_a_worker_and_says_how_far_it_got() -> void:
	var from := _root.path_join("a")
	for i in 20:
		_write(from.path_join("f%02d.txt" % i), "x".repeat(1000))
	var job := PortableMode.start_copy(from, _root.path_join("b"))
	job.wait()
	var p := job.progress()
	assert_true(p["finished"])
	assert_eq(p["files"], 20)
	assert_eq(PortableMode.progress_line(p), "Copying: 20 of 20 files, 20 KB of 20 KB.")
	assert_eq(PortableMode.size_words(3 * 1024 * 1024 * 1024 / 2), "1.5 GB")
	assert_eq(PortableMode.size_words(5 * 1048576), "5 MB")


# ------------------------------------------------------- the retirement --

func test_a_folder_that_stops_being_portable_is_renamed_never_deleted() -> void:
	var game := _root.path_join("game")
	_write(game.path_join("portable/godot/app_userdata/Shandalar/settings.cfg"), "a")
	assert_true(PortableMode.retire(game.path_join("portable")))
	assert_false(DirAccess.dir_exists_absolute(game.path_join("portable")))
	assert_eq(FileAccess.get_file_as_string(game.path_join("portable-off/godot/app_userdata/Shandalar/settings.cfg")), "a")
	assert_string_contains(PortableMode.start_note, "renamed portable-off")
	_write(game.path_join("portable/x.txt"), "b")
	assert_true(PortableMode.retire(game.path_join("portable")))
	assert_true(FileAccess.file_exists(game.path_join("portable-off-2/x.txt")), "the next free name")
	assert_true(PortableMode.retire(game.path_join("portable")), "nothing to rename is done")

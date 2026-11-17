extends GutTest
## THE PORTABLE GAME IN OPTIONS (0.70.1) — the owner, 2026-11-17: *"Lets
## implement a portable option in menu! That means that all data for game
## working are in the game folder itself."* The `Portable game:` section
## (`_add_portable_section` in game/options_screen.gd, [PortableMode]): only on
## a desktop game; one line saying where everything is kept; the button
## that asks before it copies; a window that says why when the game folder
## cannot be written. The copy and the restart themselves are
## tests/unit/test_portable_mode.gd's (a restart would end this run).

const ROOT := "user://portable_options_test"
const OPTIONS := preload("res://game/options_screen.gd")

var _root := ""


func before_each() -> void:
	_root = ProjectSettings.globalize_path(ROOT)
	DirAccess.make_dir_recursive_absolute(_root)
	PortableMode.folder_override = _root.path_join("game/portable")


func after_each() -> void:
	PortableMode.available_override = -1
	PortableMode.folder_override = ""
	_wipe(_root)


func _wipe(dir: String) -> void:
	if not dir.contains("portable_options_test") or not DirAccess.dir_exists_absolute(dir):
		return
	var here := DirAccess.open(dir)
	here.include_hidden = true
	for sub in here.get_directories():
		_wipe(dir.path_join(sub))
	for name in here.get_files():
		DirAccess.remove_absolute(dir.path_join(name))
	DirAccess.remove_absolute(dir)


func _open() -> Control:
	var screen: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	return screen


func test_no_section_where_a_game_cannot_be_portable() -> void:
	PortableMode.available_override = 0
	var screen: Control = await _open()
	assert_null(screen.find_child("PortableButton", true, false))
	assert_null(screen.find_child("PortableLine", true, false))


func test_a_desktop_game_says_where_it_keeps_everything_and_offers_to_be_portable() -> void:
	PortableMode.available_override = 1
	var screen: Control = await _open()
	var button := screen.find_child("PortableButton", true, false) as Button
	assert_not_null(button)
	assert_eq(button.text, OPTIONS.PORTABLE_MAKE)
	var line := screen.find_child("PortableLine", true, false) as Label
	assert_string_contains(line.text, GamePaths.shown(OS.get_user_data_dir()))
	assert_string_contains(line.text, "portable folder inside the game folder")
	assert_null(screen.find_child("PortableBring", true, false), "only a portable game brings games in")
	assert_false(DirAccess.dir_exists_absolute(PortableMode.folder()), "looking makes no folder")


func test_the_button_asks_first_and_cancel_changes_nothing() -> void:
	PortableMode.available_override = 1
	var screen: Control = await _open()
	(screen.find_child("PortableButton", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	var window := screen.find_child("PortableWindow", true, false)
	assert_not_null(window)
	var words := window.find_child("PortableWords", true, false) as Label
	assert_string_contains(words.text, "copied")
	assert_string_contains(words.text, "What is on this computer stays where it is")
	assert_string_contains(words.text, GamePaths.shown(PortableMode.user_dir_in(PortableMode.platform(),
		PortableMode.folder(), OS.get_user_data_dir())))
	assert_not_null(window.find_child("PortableGo", true, false), "Copy and restart")
	for button in window.find_children("*", "Button", true, false):
		if (button as Button).text == "Cancel":
			(button as Button).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_null(screen.find_child("PortableWindow", true, false))
	assert_false(OS.has_environment(PortableMode.ENV_PORTABLE), "nothing switched")


func test_a_game_folder_that_cannot_be_written_says_why_and_offers_no_copy() -> void:
	PortableMode.available_override = 1
	var locked := _root.path_join("locked")
	DirAccess.make_dir_recursive_absolute(locked)
	FileAccess.set_unix_permissions(locked, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_EXECUTE_OWNER)
	PortableMode.folder_override = locked
	var screen: Control = await _open()
	screen.ask_portable("make")
	await get_tree().process_frame
	var window := screen.find_child("PortableWindow", true, false)
	assert_not_null(window)
	assert_string_contains((window.find_child("PortableWords", true, false) as Label).text, "cannot be written")
	assert_null(window.find_child("PortableGo", true, false))
	FileAccess.set_unix_permissions(locked, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER
		| FileAccess.UNIX_EXECUTE_OWNER)


func test_the_lines_and_questions_say_what_happens() -> void:
	var off: String = OPTIONS.portable_line(false, "~/.local/share/godot/app_userdata/Shandalar", "", "")
	assert_string_contains(off, "kept in ~/.local/share/godot/app_userdata/Shandalar")
	var on: String = OPTIONS.portable_line(true, "/g/portable/godot/app_userdata/Shandalar", "",
		"The portable folder was renamed portable-off; delete it when you no longer need it.")
	assert_string_contains(on, "This game is portable")
	assert_string_contains(on, "Copy the whole game folder")
	assert_string_contains(on, "renamed portable-off")
	var stop: String = OPTIONS.portable_question("stop", "12 files, 3 MB", "~/x")
	assert_string_contains(stop, "copied back to this computer, into ~/x")
	assert_string_contains(stop, "Nothing is deleted")
	assert_string_contains(OPTIONS.portable_question("bring", "1 files, 1 KB", ""), "into the portable folder")

extends GutTest
## A SETTINGS FILE THE GAME COULD NOT READ OR SAVE IS SAID ON THE SCREEN
## (robustness campaign of 2026-10-12). Both used to reach stderr only,
## which a Steam Deck, an ArkOS handheld or the Quest never shows:
##
##   * a hand-edited settings.cfg that will not parse (the Windows path
##     the docs warn about) is kept aside as settings.cfg.bad and every
##     option below the bad line starts from its default;
##   * a save that fails (a full or read-only card, a read-only file)
##     leaves the change pending in memory — the switch looks saved and
##     is gone at the next start.
##
## [method Settings.problem] says which, the title screen shows it once,
## and the Options screen carries it as a line while it holds.

const PATH := "user://settings.cfg"

var _had := false
var _old := PackedByteArray()


func before_all() -> void:
	Settings.flush()
	_had = FileAccess.file_exists(PATH)
	if _had:
		_old = FileAccess.get_file_as_bytes(PATH)


func after_each() -> void:
	Engine.print_error_messages = true
	var global := ProjectSettings.globalize_path(PATH)
	if FileAccess.file_exists(global):
		FileAccess.set_unix_permissions(global, 420)
	if _had:
		Settings.write_atomically(PATH, _old)
	elif FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(global)
	for name in DirAccess.get_files_at("user://"):
		if name.begins_with("settings.cfg.bad"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + name))
	Settings.reload_file()


static func _posix() -> bool:
	return OS.get_name() in ["Linux", "macOS", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]


func _write_plain(text: String) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## A start reading [param text], with Godot's own parse complaint kept off
## the log (the run fails on any engine ERROR line, and this one is the
## point of the test).
func _boot_quietly(text: String) -> void:
	_write_plain(text)
	Engine.print_error_messages = false
	Settings.reload_file()
	Settings.has_value("hand_style")
	Engine.print_error_messages = true


func _options() -> Control:
	var screen: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	return screen


func _title() -> Control:
	var screen: Control = load("res://game/main.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	return screen


## The texts of every label under [param root] that is on screen.
static func _shown(root: Node) -> Array[String]:
	var out: Array[String] = []
	for label in root.find_children("*", "Label", true, false):
		if (label as Label).is_visible_in_tree() and (label as Label).text != "":
			out.append((label as Label).text)
	return out


static func _any_contains(texts: Array[String], part: String) -> bool:
	for text in texts:
		if text.contains(part):
			return true
	return false


func test_nothing_wrong_nothing_said() -> void:
	Settings.write_atomically(PATH, "[options]\nsound_enabled=true\n".to_utf8_buffer())
	Settings.reload_file()
	assert_eq(Settings.problem(), "")
	var options := await _options()
	var line := options.find_child("SettingsProblem", true, false) as Label
	assert_not_null(line, "the line is there, waiting")
	assert_false(line.is_visible_in_tree(), "and hidden")
	var title := await _title()
	assert_false(_any_contains(_shown(title), "settings.cfg"), "the title says nothing")


func test_a_save_that_fails_is_said_on_the_options_screen_until_one_goes_through() -> void:
	if not _posix():
		pass_test("mode bits are how a desk test makes a file read-only; not here")
		return
	Settings.write_atomically(PATH, "[options]\nsound_enabled=true\n".to_utf8_buffer())
	Settings.reload_file()
	var options := await _options()
	FileAccess.set_unix_permissions(ProjectSettings.globalize_path(PATH), 292)
	Settings.set_value("sound_enabled", false)      # what the Sound switch does
	await get_tree().process_frame
	assert_true(Settings.is_dirty(), "the change is pending")
	assert_string_contains(FileAccess.get_file_as_string(PATH), "sound_enabled=true",
		"the read-only file is as it was")
	var line := options.find_child("SettingsProblem", true, false) as Label
	assert_true(line.is_visible_in_tree(), "the Options screen says so")
	assert_string_contains(line.text, "could not be saved")
	assert_string_contains(line.text, "read-only")
	FileAccess.set_unix_permissions(ProjectSettings.globalize_path(PATH), 420)
	Settings.flush()
	await get_tree().process_frame
	assert_false(Settings.is_dirty())
	assert_false(line.is_visible_in_tree(), "and stops saying it once a save goes through")
	assert_eq(Settings.problem(), "")


func test_a_kept_aside_file_is_said_once_on_the_title_and_on_options() -> void:
	_boot_quietly("[options]\nsound_enabled=false\nmusic_folder=\"C:\\Users\\me\\Music\"\nhand_style=\"fan\"\n")
	var problem := Settings.problem()
	assert_string_contains(problem, "settings.cfg.bad", "the copy is named")
	assert_string_contains(problem, ProjectSettings.globalize_path("user://settings.cfg.bad"),
		"where the player can find it")
	var first := await _title()
	assert_true(_any_contains(_shown(first), "settings.cfg.bad"), "the title says it")
	first.queue_free()
	await get_tree().process_frame
	var second := await _title()
	assert_false(_any_contains(_shown(second), "settings.cfg.bad"), "once")
	var options := await _options()
	var line := options.find_child("SettingsProblem", true, false) as Label
	assert_true(line.is_visible_in_tree(), "Options carries it")
	assert_string_contains(line.text, "settings.cfg.bad")


func test_a_file_that_cannot_be_read_is_said() -> void:
	if not _posix():
		pass_test("mode bits are how a desk test makes a file unreadable; not here")
		return
	_write_plain("[options]\nhand_style=\"fan\"\n")
	FileAccess.set_unix_permissions(ProjectSettings.globalize_path(PATH), 0)
	if FileAccess.open(PATH, FileAccess.READ) != null:
		pass_test("this user reads every file (root); the test cannot pose the case")
		return
	Engine.print_error_messages = false
	Settings.reload_file()
	Settings.has_value("hand_style")
	Engine.print_error_messages = true
	var problem := Settings.problem()
	assert_string_contains(problem, "could not be read")
	assert_string_contains(problem, "not saved", "and options set now will not be kept")
	FileAccess.set_unix_permissions(ProjectSettings.globalize_path(PATH), 420)

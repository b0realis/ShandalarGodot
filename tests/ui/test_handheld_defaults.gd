extends GutTest
## THE HANDHELD'S DEFAULTS AND THE POWER SAVER — `Settings.handheld`,
## `Settings.default_for` (`game/settings.gd`), `GameDisplay.apply_settings`
## and the power saver (`game/display.gd`), and the Options screen's
## `Power saver` row (`game/options_screen.gd`).
##
## `[QoL]`, 2026-09-27, the Steam Deck release: the launchers under
## `packaging/handhelds/` export `SHANDALAR_HANDHELD`, and a settings
## file that has never been written opens on a handheld's defaults —
## full screen, the click-to-enlarge card reader and the power saver on.
## What these pin:
##
##   1. Without the word, nothing changes: every default is the desktop's
##      and nothing is written.
##   2. With it, the three keys read the handheld's defaults while
##      unwritten, and a written choice — even `false` — wins over them.
##      Nothing is written by reading.
##   3. The power saver is `OS.low_processor_usage_mode`: off by default
##      on a desk, applied at once by the row and at boot with the
##      window mode, and remembered.
##   4. The launcher's own `--fullscreen` is respected: the boot never
##      puts an unwritten "windowed" over it.

const ENV := Settings.HANDHELD_ENV
const KEYS := ["fullscreen", "fullscreen_cards", "power_saver"]

var _had_env := false
var _env := ""
var _saved := {}
var _saved_mode := false


func before_each() -> void:
	_had_env = OS.has_environment(ENV)
	_env = OS.get_environment(ENV) if _had_env else ""
	OS.unset_environment(ENV)
	_saved.clear()
	for key in KEYS:
		if Settings.has_value(key):
			_saved[key] = Settings.get_value(key, null)
		Settings.clear_value(key)
	_saved_mode = OS.low_processor_usage_mode


func after_each() -> void:
	for key in KEYS:
		if _saved.has(key):
			Settings.set_value(key, _saved[key])
		else:
			Settings.clear_value(key)
	if _had_env:
		OS.set_environment(ENV, _env)
	else:
		OS.unset_environment(ENV)
	OS.low_processor_usage_mode = _saved_mode


func _options() -> Control:
	var screen: Control = load("res://game/options_screen.tscn").instantiate()
	add_child_autofree(screen)
	return screen


# ================================================== the desktop's word (1) ==

func test_without_the_word_every_default_is_the_desktops() -> void:
	assert_eq(Settings.handheld(), "", "no launcher named a device")
	assert_false(Settings.fullscreen())
	assert_false(Settings.fullscreen_cards())
	assert_false(Settings.power_saver())
	for key in KEYS:
		assert_false(Settings.has_value(key), "%s: reading writes nothing" % key)
	assert_eq(Settings.default_for("fullscreen", false), false)
	assert_eq(Settings.default_for("anything_else", 7), 7, "a key with no handheld word keeps its own")


func test_the_launchers_export_the_word() -> void:
	assert_eq(ENV, "SHANDALAR_HANDHELD")
	for launcher in ["steam-deck.sh", "arkos.sh"]:
		var text := FileAccess.get_file_as_string("res://packaging/handhelds/" + launcher)
		assert_string_contains(text, "export SHANDALAR_HANDHELD=",
			"%s names the device before it starts the game" % launcher)
	assert_string_contains(FileAccess.get_file_as_string("res://packaging/handhelds/steam-deck.sh"),
		"SHANDALAR_HANDHELD=steam-deck")
	assert_string_contains(FileAccess.get_file_as_string("res://packaging/handhelds/arkos.sh"),
		"SHANDALAR_HANDHELD=arkos")


# ================================================= the handheld's word (2) ==

func test_with_the_word_the_unwritten_keys_read_the_handhelds_defaults() -> void:
	OS.set_environment(ENV, "steam-deck")
	assert_eq(Settings.handheld(), "steam-deck")
	assert_true(Settings.fullscreen(), "full screen on a 7-inch screen")
	assert_true(Settings.fullscreen_cards(), "and the card reader, for the small print")
	assert_true(Settings.power_saver(), "and the power saver, for the battery")
	for key in KEYS:
		assert_false(Settings.has_value(key), "%s: still nothing written" % key)
	assert_eq(Settings.HANDHELD_DEFAULTS.keys(), KEYS, "the three, and only the three")


func test_any_word_is_a_handheld_and_blank_is_none() -> void:
	OS.set_environment(ENV, "arkos")
	assert_true(Settings.power_saver())
	OS.set_environment(ENV, "   ")
	assert_eq(Settings.handheld(), "", "whitespace is no word")
	assert_false(Settings.power_saver())


func test_a_written_choice_wins_over_the_handhelds_default() -> void:
	OS.set_environment(ENV, "steam-deck")
	Settings.set_value("fullscreen", false, false)
	Settings.set_value("fullscreen_cards", false, false)
	Settings.set_value("power_saver", false, false)
	assert_false(Settings.fullscreen(), "the player asked for a window on the Deck: a window")
	assert_false(Settings.fullscreen_cards())
	assert_false(Settings.power_saver())
	Settings.clear_value("power_saver")
	assert_true(Settings.power_saver(), "cleared, the handheld's default is back")


func test_the_options_rows_open_on_the_handhelds_defaults() -> void:
	OS.set_environment(ENV, "steam-deck")
	var screen := _options()
	await get_tree().process_frame
	assert_true((screen.find_child("FullscreenCards", true, false) as CheckButton).button_pressed)
	assert_true((screen.find_child("PowerSaver", true, false) as CheckButton).button_pressed)
	for key in KEYS:
		assert_false(Settings.has_value(key), "%s: opening the screen writes nothing" % key)


# ====================================================== the power saver (3) ==

func test_the_power_saver_is_off_on_a_desk_and_written_only_when_asked() -> void:
	var screen := _options()
	await get_tree().process_frame
	var row := screen.find_child("PowerSaver", true, false) as CheckButton
	assert_not_null(row, "the Display rows carry a Power saver switch")
	assert_false(row.button_pressed)
	assert_false(Settings.has_value("power_saver"))
	assert_eq(GameDisplay.POWER_KEY, "power_saver")


func test_the_row_applies_at_once_and_is_remembered() -> void:
	var screen := _options()
	await get_tree().process_frame
	var row := screen.find_child("PowerSaver", true, false) as CheckButton
	OS.low_processor_usage_mode = false
	row.button_pressed = true
	assert_true(OS.low_processor_usage_mode, "the engine rests between frames from now on")
	assert_eq(Settings.get_value("power_saver", null), true, "and the file has it")
	Settings.reload_file()
	assert_true(Settings.power_saver(), "on disk")
	row.button_pressed = false
	assert_false(OS.low_processor_usage_mode)
	assert_eq(Settings.get_value("power_saver", null), false)


func test_apply_settings_puts_the_stored_saver_on_the_engine() -> void:
	Settings.set_value("power_saver", true, false)
	OS.low_processor_usage_mode = false
	GameDisplay.apply_settings()
	assert_true(OS.low_processor_usage_mode, "applied with the window mode, headless too")
	Settings.set_value("power_saver", false, false)
	GameDisplay.apply_settings()
	assert_false(OS.low_processor_usage_mode)
	OS.set_environment(ENV, "steam-deck")
	Settings.clear_value("power_saver")
	GameDisplay.apply_settings()
	assert_true(OS.low_processor_usage_mode, "the handheld's default reaches the engine the same way")


func test_a_fresh_options_screen_shows_what_is_stored() -> void:
	Settings.set_value("power_saver", true, false)
	var screen := _options()
	await get_tree().process_frame
	assert_true((screen.find_child("PowerSaver", true, false) as CheckButton).button_pressed)


# =================================================== the launcher's flag (4) ==

func test_the_suite_was_not_started_with_the_launchers_flag() -> void:
	assert_false(GameDisplay.launcher_asked_fullscreen(),
		"run_tests.sh passes no --fullscreen; the rule is read from the source below")


func test_an_unwritten_window_mode_never_overrides_the_launchers_fullscreen() -> void:
	# ArkOS starts the game with `--fullscreen`; before 2026-09-27 the
	# boot read the unwritten key as "windowed" and undid the flag. The
	# source is what can be pinned headless: the early return sits
	# between the headless guard and the window call, and it is gated
	# on the key being UNWRITTEN — a player's own choice still wins.
	var source: String = (GameDisplay as GDScript).source_code
	var apply := source.find("static func apply_settings()")
	var guard := source.find("not Settings.has_value(KEY) and launcher_asked_fullscreen()", apply)
	var call := source.find("DisplayServer.window_set_mode(wanted)", apply)
	assert_gt(guard, apply, "the launcher's flag is read in apply_settings")
	assert_gt(call, guard, "and read before the window is touched")
	assert_true(source.contains('args.has("--fullscreen") or args.has("-f")'),
		"both spellings of the engine's flag")


## THE ENGINE EATS THE FLAG (bug pass 2026-10-03). Godot consumes
## `--fullscreen`/`-f` itself — neither `OS.get_cmdline_args()` nor the
## user args ever carry it (measured under Xvfb: args `["-s", …]`, the
## window already full screen at the first script line) — so the check
## above never fired and the boot put the window straight back. What CAN
## be read is the flag's effect: a window that is full screen although
## the project opens windowed. Headless there is no window to read, so
## the rule is pinned through its pure half.
func test_the_launchers_flag_is_read_from_the_window_it_left() -> void:
	var none := PackedStringArray()
	var windowed := DisplayServer.WINDOW_MODE_WINDOWED
	var full := DisplayServer.WINDOW_MODE_FULLSCREEN
	assert_true(GameDisplay.launcher_fullscreen_from(none, full, windowed),
		"a full-screen window the project did not ask for is the launcher's")
	assert_true(GameDisplay.launcher_fullscreen_from(none,
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN, windowed))
	assert_false(GameDisplay.launcher_fullscreen_from(none, windowed, windowed),
		"a window is a window")
	assert_false(GameDisplay.launcher_fullscreen_from(none, full, full),
		"a project that opens full screen asked for it itself")
	assert_true(GameDisplay.launcher_fullscreen_from(
		PackedStringArray(["--fullscreen"]), windowed, windowed),
		"a flag that did reach the args still counts")
	assert_string_contains(FileAccess.get_file_as_string("res://packaging/handhelds/arkos.sh"),
		"--fullscreen", "ArkOS is the launcher that passes it")
